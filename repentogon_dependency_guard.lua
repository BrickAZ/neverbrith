-- Failure-only bootstrap. All APIs here are available in vanilla Repentance.
-- Legacy REPENTOGON 1.0.12a cannot conditionally hide content XML: disable Lua
-- gameplay at the entrypoint, then exclude the already registered drops here.
return function(mod)
    local game = Game()
    local active = true -- Also works when Lua is reloaded during an existing run.
    local collectibleIds = {}
    -- Pure generated data; never include gameplay modules from this branch.
    for _, entry in ipairs(include("generated.neverbirth_collectibles")) do
        for _, name in ipairs(entry.names) do
            local id = Isaac.GetItemIdByName(name)
            if id > 0 then
                collectibleIds[id] = true
                break
            end
        end
    end
    local sealId = Isaac.GetTrinketIdByName("Seven Curses Slot Seal")
    local pillIds = {}
    for _, name in ipairs({ "Wind Charge Potion", "蓄风药剂" }) do
        local id = Isaac.GetPillEffectByName(name)
        if id >= 0 then pillIds[id] = true end
    end

    local function removeFromPools()
        local pool = game:GetItemPool()
        for id in pairs(collectibleIds) do pool:RemoveCollectible(id) end
        if sealId > 0 then pool:RemoveTrinket(sealId) end
    end

    local function replacementCollectible(_, id)
        if collectibleIds[id] then return CollectibleType.COLLECTIBLE_BREAKFAST end
    end

    local function replacementTrinket(_, id)
        local goldenFlag = TrinketType.TRINKET_GOLDEN_FLAG
        if sealId > 0 and id % goldenFlag == sealId then
            return TrinketType.TRINKET_PAPER_CLIP + (id >= goldenFlag and goldenFlag or 0)
        end
    end

    local function replacePickup(_, pickup)
        local replacement
        if pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE then
            replacement = replacementCollectible(nil, pickup.SubType)
        elseif pickup.Variant == PickupVariant.PICKUP_TRINKET then
            replacement = replacementTrinket(nil, pickup.SubType)
        end
        if replacement then
            -- Covers scripted spawns, saved pedestals and later Morph/reroll paths.
            local optionsIndex = pickup.OptionsPickupIndex
            pickup:Morph(EntityType.ENTITY_PICKUP, pickup.Variant, replacement, true, true, true)
            pickup.OptionsPickupIndex = optionsIndex
        end
    end

    local texts = {
        zh = {
            "未生已停用：缺少或不兼容忏悔龙",
            "需要 REPENTOGON 1.0.12a 或更新稳定版",
            "请安装或更新后重启游戏",
        },
        en = {
            "neverbirth disabled: REPENTOGON required",
            "Requires REPENTOGON 1.0.12a or newer stable",
            "Install or update, then restart the game",
        },
    }
    local fontPaths = {
        zh = "resources-dlc3.zh/font/teammeatfontextended10.fnt",
        en = "font/terminus.fnt",
    }
    local fonts = {}
    local shadow = KColor(0, 0, 0, 0.9)
    local colors = { KColor(1, 0.3, 0.25, 1), KColor(1, 0.85, 0.35, 1), KColor(1, 1, 1, 1) }
    local function getFont(locale)
        if fonts[locale] == nil then
            local font = Font()
            local ok = pcall(function() font:Load(fontPaths[locale]) end)
            fonts[locale] = ok and font:IsLoaded() and font or false
        end
        return fonts[locale]
    end

    local function renderWarning()
        if not active or game:GetNumPlayers() == 0 then return end
        local level = game:GetLevel()
        if level:GetCurrentRoomIndex() ~= level:GetStartingRoomIndex() then return end

        local locale = Options.Language == "zh" and "zh" or "en"
        local font = getFont(locale)
        if not font then locale, font = "en", getFont("en") end
        local scale, lineHeight = 0.75, 14
        for index = 0, game:GetNumPlayers() - 1 do
            local player = Isaac.GetPlayer(index)
            -- Logical world anchor, converted once; no player-render callback offsets.
            local position = Isaac.WorldToScreen(player.Position)
            local top = math.max(6, position.Y - 76)
            for line, text in ipairs(texts[locale]) do
                local width = font and font:GetStringWidthUTF8(text) * scale or #text * 5
                local x = math.max(4, math.min(position.X - width / 2, Isaac.GetScreenWidth() - width - 4))
                local y = top + (line - 1) * lineHeight
                if font then
                    font:DrawStringScaledUTF8(text, x + 1, y + 1, scale, scale, shadow, 0, false)
                    font:DrawStringScaledUTF8(text, x, y, scale, scale, colors[line], 0, false)
                else
                    -- A missing language/font asset must never make the error invisible.
                    Isaac.RenderText(text, x, y, 1, 0.5, 0.3, 1)
                end
            end
        end
    end

    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, removeFromPools)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function()
        active = true
        removeFromPools()
    end)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, removeFromPools)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function() active = false end)
    mod:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, replacementCollectible)
    mod:AddCallback(ModCallbacks.MC_GET_TRINKET, replacementTrinket)
    mod:AddCallback(ModCallbacks.MC_GET_PILL_EFFECT, function(_, effect)
        if pillIds[effect] then return PillEffect.PILLEFFECT_BAD_GAS end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, replacePickup, PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, replacePickup, PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, replacePickup, PickupVariant.PICKUP_TRINKET)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, replacePickup, PickupVariant.PICKUP_TRINKET)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, renderWarning)
end
