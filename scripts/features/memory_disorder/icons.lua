-- Pickup/history/held/EID disguises. Installers bind native callbacks only when the entry schedules them.
return function(Neverbirth, context, deps)
    local installers = {}
    local safeCall = deps.safeCall
    local numberCall = deps.numberCall
    local runtimePlayerKey = deps.runtimePlayerKey
    local getPlayers = deps.getPlayers
    local pairMain = deps.pairMain
    local randomIndex = deps.randomIndex
    local ensureSavedState = deps.ensureSavedState
    local ITEM_ID = deps.ITEM_ID
    local FALLBACK_ICON_ID = deps.FALLBACK_ICON_ID
    local QUESTION_MARK_GFX = deps.QUESTION_MARK_GFX
    local runtime = deps.runtime

    local eidIconOwner

    local function getCollectibleConfigs()
        if context.GetCollectibleConfigs then return context.GetCollectibleConfigs() end
        if Isaac and Isaac.GetItemConfig then
            local config = Isaac.GetItemConfig()
            if config and config.GetCollectibles then return config:GetCollectibles() end
        end
        return nil
    end

    local function buildIconCandidates()
        local result = {}
        runtime.iconConfigs = {}
        runtime.collectibleGfx = {}
        local configs = getCollectibleConfigs()
        local function consider(config)
            if not config then return end
            local id = tonumber(config.ID)
            local gfx = config.GfxFileName or config.GfxFile or config.gfx
            local hidden = config.Hidden == true or config.Hidden == 1
            if id and id > 0 and type(gfx) == "string" and gfx ~= "" then
                runtime.collectibleGfx[id] = gfx
            end
            if id and id > 0 and id ~= ITEM_ID and not hidden
                and config.Type == (ItemType and ItemType.ITEM_PASSIVE or 1)
                and type(gfx) == "string" and gfx ~= "" then
                result[#result + 1] = id
                runtime.iconConfigs[id] = config
            end
        end
        -- ItemConfigList:Get returns opaque userdata. Use Size only for the ID range
        -- and GetCollectible for typed ItemConfig.Item values (including modded IDs).
        if configs and configs.Size then
            local itemConfig = Isaac and Isaac.GetItemConfig and Isaac.GetItemConfig()
            if itemConfig then
                for id = 1, configs.Size - 1 do consider(itemConfig:GetCollectible(id)) end
            end
        elseif type(configs) == "table" then
            for _, config in pairs(configs) do consider(config) end
        end
        table.sort(result)
        runtime.iconCandidates = result
        return result
    end

    local function rememberPickedIcon(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then return end
        local seen = ensureSavedState().pickedIconItems
        local key = tostring(itemId) -- JSON object keys must survive a save/load round trip.
        if not seen[key] then
            seen[key] = true
            runtime.iconHistoryDirty = true
        end
    end
    function installers.rememberPickedIcon()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, function(_, id) rememberPickedIcon(id) end)
    end

    local function importIconHistory(player)
        if not player then return end
        local history = safeCall(player, "GetHistory")
        local entries = safeCall(history, "GetCollectiblesHistory")
        for _, entry in ipairs(type(entries) == "table" and entries or {}) do
            if safeCall(entry, "IsTrinket") ~= true then
                rememberPickedIcon(safeCall(entry, "GetItemID"))
            end
        end
        -- Also include starting items and real inventory missing from the history HUD.
        for _, id in ipairs(runtime.iconCandidates or buildIconCandidates()) do
            if numberCall(player, "GetCollectibleNum", id, true) > 0 then rememberPickedIcon(id) end
        end
        runtime.iconHistoryPlayers[runtimePlayerKey(player)] = true
    end

    local function syncIconHistory()
        for _, player in ipairs(getPlayers()) do importIconHistory(player) end
    end

    local function iconIsEligible(id)
        return runtime.iconConfigs[id] ~= nil and not ensureSavedState().pickedIconItems[tostring(id)]
    end

    local function selectIcon(player, salt, previous)
        local available, alternatives = {}, {}
        for _, id in ipairs(runtime.iconCandidates or buildIconCandidates()) do
            if iconIsEligible(id) then
                available[#available + 1] = id
                if id ~= previous then alternatives[#alternatives + 1] = id end
            end
        end
        if #alternatives > 0 then available = alternatives end
        if #available == 0 then return FALLBACK_ICON_ID end
        return available[randomIndex(#available, player, salt)]
    end

    local function chooseIcon(player)
        syncIconHistory()
        local state = runtime.states[runtimePlayerKey(pairMain(player))]
        local salt = "icon:" .. runtime.roomSerial .. ":" .. (state and state.switchSerial or 0)
        local selected = selectIcon(player, salt, state and state.currentIconId)
        if state then state.currentIconId = selected end
        return selected
    end

    local function iconGfx(id)
        local config = runtime.iconConfigs[id]
        return config and (config.GfxFileName or config.GfxFile or config.gfx) or QUESTION_MARK_GFX
    end

    local function pickupIconRecord(pickup)
        local data = safeCall(pickup, "GetData")
        return data and data.NeverbirthMemoryDisorderIcon, data
    end

    local function pickupIsBlind(pickup)
        if safeCall(pickup, "IsBlind") == true then return true end
        if Game and LevelCurse then
            local level = Game():GetLevel()
            local curses = numberCall(level, "GetCurses")
            return (curses & (LevelCurse.CURSE_OF_BLIND or 0)) ~= 0
        end
        return false
    end

    local function updatePickupIcon(pickup)
        if not pickup then return end
        local record, data = pickupIconRecord(pickup)
        if pickup.SubType ~= ITEM_ID then
            if record then
                -- A rerolled pedestal must stop wearing our old disguise.
                -- ReloadGraphics is not part of REPENTOGON 1.0.12a.
                -- Restore only a layer still bearing our replacement; otherwise
                -- preserve the engine's new artwork (including blind/empty states).
                local sprite = safeCall(pickup, "GetSprite")
                local layer = safeCall(sprite, "GetLayer", 1)
                local actual = safeCall(layer, "GetSpritesheetPath")
                local gfx = runtime.collectibleGfx[pickup.SubType]
                if gfx and record.appliedGfx and actual == record.appliedGfx then
                    if pickupIsBlind(pickup) then gfx = QUESTION_MARK_GFX end
                    local _, replaced = safeCall(sprite, "ReplaceSpritesheet", 1, gfx)
                    if replaced then safeCall(sprite, "LoadGraphics") end
                end
                data.NeverbirthMemoryDisorderIcon = nil
            end
            return
        end
        if not data then return end
        for _, player in ipairs(getPlayers()) do
            if not runtime.iconHistoryPlayers[runtimePlayerKey(player)] then importIconHistory(player) end
        end
        local roomSeed = Game and numberCall(Game():GetRoom(), "GetSpawnSeed") or 0
        local key = tostring(roomSeed) .. ":" .. tostring(pickup.InitSeed)
        local savedIcons = ensureSavedState().pedestalIconIds
        if not record and savedIcons[key] ~= nil then record = { id = savedIcons[key] } end
        if not record or (record.id ~= FALLBACK_ICON_ID and not iconIsEligible(record.id)) then
            local salt = "pedestal:" .. key
            local previous = record and record.id
            record = { id = selectIcon(nil, salt, previous) }
            savedIcons[key] = record.id
            runtime.iconHistoryDirty = true
        end
        data.NeverbirthMemoryDisorderIcon = record
    end
    function installers.updatePickupIcon()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, function(_, pickup) updatePickupIcon(pickup) end, 100)
    end

    local function renderPickupIcon(pickup)
        if not pickup or pickup.SubType ~= ITEM_ID then return end
        local record = pickupIconRecord(pickup)
        if not record then return end
        local blind = pickupIsBlind(pickup)
        local gfx = (blind or not iconIsEligible(record.id)) and QUESTION_MARK_GFX or iconGfx(record.id)
        local sprite = safeCall(pickup, "GetSprite")
        -- REPENTOGON layer state lets us notice engine graphic reloads without
        -- reloading a spritesheet on every render. Never restart its animation.
        local layer = safeCall(sprite, "GetLayer", 1)
        local actual = safeCall(layer, "GetSpritesheetPath")
        if actual ~= gfx and (actual ~= nil or record.appliedGfx ~= gfx) then
            local _, replaced = safeCall(sprite, "ReplaceSpritesheet", 1, gfx)
            if replaced then
                safeCall(sprite, "LoadGraphics")
                record.appliedGfx = gfx
            end
        end
    end
    function installers.renderPickupIcon()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_RENDER, function(_, pickup) renderPickupIcon(pickup) end, 100)
    end

    local function capturePickupIcon(pickup, collider)
        if not pickup or pickup.SubType ~= ITEM_ID then return end
        local player = safeCall(collider, "ToPlayer")
        local data = safeCall(player, "GetData")
        local record = pickupIconRecord(pickup)
        if data and record then data.NeverbirthMemoryDisorderHeldIcon = record.id end
        -- No return: this callback never authorizes, cancels or grants a pickup.
    end
    function installers.capturePickupIcon()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, pickup, collider) capturePickupIcon(pickup, collider) end, 100)
    end

    local function renderHeldIcon(player)
        local queued = player and player.QueuedItem
        if not queued or not queued.Item or queued.Item.ID ~= ITEM_ID then return end
        local data = safeCall(player, "GetData")
        local state = runtime.states[runtimePlayerKey(pairMain(player))]
        local id = data and data.NeverbirthMemoryDisorderHeldIcon or (state and state.currentIconId)
        if not iconIsEligible(id) then id = state and state.currentIconId end
        if not iconIsEligible(id) then id = FALLBACK_ICON_ID end
        local sprite = safeCall(player, "GetHeldSprite")
        local gfx = iconGfx(id)
        local layer = safeCall(sprite, "GetLayer", 0)
        if safeCall(layer, "GetSpritesheetPath") ~= gfx then
            local _, replaced = safeCall(sprite, "ReplaceSpritesheet", 0, gfx)
            if replaced then safeCall(sprite, "LoadGraphics") end
        end
    end
    function installers.renderHeldIcon()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player) renderHeldIcon(player) end)
    end

    local function registerIconDescription()
        if not EID or EID == eidIconOwner or type(EID.addDescriptionModifier) ~= "function"
            or type(EID.createItemIconObject) ~= "function" then return end
        EID:addDescriptionModifier("neverbirth Memory Disorder icon", function(desc)
            return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == ITEM_ID
        end, function(desc)
            local record = desc.Entity and pickupIconRecord(desc.Entity)
            local player = desc.Player or desc.PlayerEntity or EID.player
            local state = player and runtime.states[runtimePlayerKey(pairMain(player))]
            local id = record and record.id or (state and state.currentIconId)
            if desc.Entity and pickupIsBlind(desc.Entity) then id = FALLBACK_ICON_ID end
            if iconIsEligible(id) then
                desc.Icon = EID:createItemIconObject("Collectible" .. id)
            elseif EID.InlineIcons then
                desc.Icon = EID.InlineIcons.QuestionMark
            end
            return desc
        end)
        eidIconOwner = EID
    end

    return {
        rememberPickedIcon = rememberPickedIcon,
        importIconHistory = importIconHistory,
        syncIconHistory = syncIconHistory,
        iconIsEligible = iconIsEligible,
        chooseIcon = chooseIcon,
        registerIconDescription = registerIconDescription,
        Installers = installers,
    }
end
