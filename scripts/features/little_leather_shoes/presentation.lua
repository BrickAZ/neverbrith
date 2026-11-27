-- Owns visual state and completion notifications, never item rewards or cache writes.
return function(dependencies)
    -- Native bindings are declared here; the entry chooses their installation phase.
    local callbackInstallers = {}
    local state = assert(dependencies.Runtime)
    local trafficAnm2 = assert(dependencies.Animations)
    local copyPosition = assert(dependencies.CopyPosition)
    local trafficTier, nextTrafficTarget = dependencies.Rules.GetTier, dependencies.Rules.GetNextTrafficTarget
    state.hudFonts = state.hudFonts or {}
    local function resetFloor()
        state.choiceLinks, state.visuals = {}, {}
        state.hudSprite, state.hudTier = nil, nil
    end
    local function createChoiceLink(id, left, right)
        local sprite
        if Sprite then local ok, value = pcall(Sprite); if ok then sprite = value; pcall(function() sprite:Load("gfx/Effects/traffic_choice_link.anm2", true); sprite:Play("Idle", true) end) end end
        state.choiceLinks[id] = { sprite = sprite, position = Vector((left.X + right.X) / 2, (left.Y + right.Y) / 2) }
    end
    local function queuePickup(itemId, position, chest)
        local path = trafficAnm2[itemId]
        if not path or not Sprite then return chest end
        local ok, sprite = pcall(Sprite); if not ok or not sprite then return end
        if not pcall(function() sprite:Load(path, true); sprite:Play("Pickup", true) end) then return end
        state.visuals[#state.visuals + 1] = { sprite = sprite, position = copyPosition(position), frames = 0, chest = chest == true }
    end

    local function advancePickups(onFinished)
        for index = #state.visuals, 1, -1 do
            local value = state.visuals[index]; value.frames = value.frames + 1
            if value.sprite.Update then pcall(function() value.sprite:Update() end) end
            local finished = false; if value.sprite.IsFinished then local ok, done = pcall(function() return value.sprite:IsFinished("Pickup") end); finished = ok and done == true end
            if finished or value.frames >= 8 then onFinished(value); table.remove(state.visuals, index) end
        end
    end

    local trafficHudFontPaths = {
        zh = "resources-dlc3.zh/font/teammeatfontextended10.fnt",
        en = "font/teammeatfont10.fnt",
    }

    local function trafficHudLocale()
        return Options and Options.Language == "zh" and "zh" or "en"
    end

    local function trafficHudFont(locale)
        state.hudFonts = state.hudFonts or {}
        local cached = state.hudFonts[locale]
        if cached ~= nil then return cached or nil end
        state.hudFonts[locale] = false
        if not Font then return nil end
        local okFont, font = pcall(Font)
        if not okFont or not font or type(font.Load) ~= "function" then return nil end
        local okLoad, loaded = pcall(function() return font:Load(trafficHudFontPaths[locale]) end)
        if not okLoad or loaded == false then return nil end
        state.hudFonts[locale] = font
        return font
    end

    local function renderTrafficHudText(traffic, tier)
        local _, remaining = nextTrafficTarget(traffic)
        local locale = trafficHudLocale()
        local maximum = tier >= 3
        local localized = maximum and (locale == "zh" and ("流量 " .. traffic .. " 最高等级") or ("Traffic " .. traffic .. " MAX"))
            or (locale == "zh" and ("流量 " .. traffic .. " 还差 " .. remaining) or ("Traffic " .. traffic .. " Next +" .. remaining))
        local fallback = maximum and ("Traffic " .. traffic .. " MAX") or ("Traffic " .. traffic .. " Next +" .. remaining)
        local font = trafficHudFont(locale)
        if font and KColor then
            local okColor, color = pcall(KColor, 1, 1, 1, 1)
            local method = locale == "zh" and font.DrawStringUTF8 or font.DrawString
            if okColor and color and type(method) == "function" then
                local drawn = pcall(method, font, localized, 64, 37, color, 0, false)
                if drawn then return true end
            end
        end
        if Isaac and Isaac.RenderText then pcall(Isaac.RenderText, fallback, 64, 37, 1, 1, 1, 1) end
        return false
    end

    local function render()
        local enabled, amount = dependencies.GetHudState()
        if not enabled then return end
        local traffic = math.max(0, math.floor(tonumber(amount) or 0)); local tier = trafficTier(traffic)
        if tier > 0 and Sprite then
            if not state.hudSprite then local ok, sprite = pcall(Sprite); if ok then state.hudSprite = sprite; pcall(function() sprite:Load("gfx/UI/traffic_meter.anm2", true) end) end end
            if state.hudSprite and state.hudTier ~= tier then state.hudTier = tier; pcall(function() state.hudSprite:Play("Level" .. tier, true) end) end
            if state.hudSprite then pcall(function() state.hudSprite:Render(Vector(42, 42)) end) end
        end
        renderTrafficHudText(traffic, tier)
        for _, link in pairs(state.choiceLinks) do if link.sprite then pcall(function() link.sprite:Update(); link.sprite:Render(Isaac.WorldToScreen and Isaac.WorldToScreen(link.position) or link.position) end) end end
        for _, value in ipairs(state.visuals) do if value.sprite then pcall(function() value.sprite:Render(Isaac.WorldToScreen and Isaac.WorldToScreen(value.position) or value.position) end) end end
    end
    function callbackInstallers.InstallRender(Neverbirth)
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, render)
    end

    local function resetRun()
        resetFloor()
        state.hudFonts = {}
    end

    return { ResetFloor = resetFloor, ResetRun = resetRun, CreateChoiceLink = createChoiceLink, RemoveChoiceLink = function(id) state.choiceLinks[id] = nil end,
        QueuePickup = queuePickup, AdvancePickups = advancePickups, Render = render,
        InstallRender = callbackInstallers.InstallRender,
    }
end
