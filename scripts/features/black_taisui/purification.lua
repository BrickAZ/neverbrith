-- Owns stage-two curse/reveal rules and conversion of the original Wavy Cap.
return function(Neverbirth, dependencies)
    local Runtime = assert(dependencies.Runtime)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local VisualEffects = dependencies.VisualEffects
    local GetFolkGame = dependencies.GetFolkGame
    local GetFolkRoomKey = dependencies.GetFolkRoomKey
    local GetFolkFloorKey = dependencies.GetFolkFloorKey
    local GetFolkPlayerKey = dependencies.GetFolkPlayerKey
    local GetPlayers = dependencies.GetPlayers
    local BlackTaisuiId = dependencies.BlackTaisuiId
    local CleansedWavyCapId = dependencies.CleansedWavyCapId
    local IsValidItemId = dependencies.IsValidItemId
    local PlayerHasCollectible = dependencies.PlayerHasCollectible
    local DebugLog = dependencies.DebugLog
    function Runtime:GetBlackTaisuiTemporaryEffects(player)
        if not player or not player.GetEffects then
            return nil
        end
        local ok, effects = pcall(function()
            return player:GetEffects()
        end)
        if ok then
            return effects
        end
        return nil
    end

    function Runtime:GetBlackTaisuiWavyCapEffectCount(player)
        local effects = Runtime:GetBlackTaisuiTemporaryEffects(player)
        if not effects then
            return 0
        end
        local itemId = Runtime.BlackTaisuiWavyCap
        if effects.GetCollectibleEffectNum then
            local ok, count = pcall(function()
                return effects:GetCollectibleEffectNum(itemId)
            end)
            if ok then
                return tonumber(count) or 0
            end
        end
        if effects.HasCollectibleEffect then
            local ok, has = pcall(function()
                return effects:HasCollectibleEffect(itemId)
            end)
            if ok then
                return has and 1 or 0
            end
        end
        return 0
    end

    function Runtime:RemoveBlackTaisuiWavyCapEffects(player, count)
        local effects = Runtime:GetBlackTaisuiTemporaryEffects(player)
        count = math.max(0, math.floor(tonumber(count) or 0))
        if not effects or count <= 0 or not effects.RemoveCollectibleEffect then
            return 0
        end

        local removed = 0
        local ok = pcall(function()
            effects:RemoveCollectibleEffect(Runtime.BlackTaisuiWavyCap, count)
        end)
        if ok then
            removed = count
        else
            for _ = 1, count do
                local oneOk = pcall(function()
                    effects:RemoveCollectibleEffect(Runtime.BlackTaisuiWavyCap, 1)
                end)
                if oneOk then
                    removed = removed + 1
                else
                    break
                end
            end
        end
        return removed
    end

    function Runtime:GetBlackTaisuiCurseMask()
        local mask = 0
        if LevelCurse then
            mask = ((LevelCurse.CURSE_OF_BLIND or LevelCurse.CURSE_OF_THE_BLIND or 0)
                | (LevelCurse.CURSE_OF_LOST or LevelCurse.CURSE_OF_THE_LOST or 0)
                | (LevelCurse.CURSE_OF_UNKNOWN or LevelCurse.CURSE_OF_THE_UNKNOWN or 0))
        end
        return mask
    end

    function Neverbirth:FilterBlackTaisuiCurses(curses)
        if not Runtime.running or Runtime.disposed then return curses end
        local result = tonumber(curses) or 0
        local mask = Runtime:GetBlackTaisuiCurseMask()
        if mask == 0 or (result & mask) == 0 then
            return result
        end
        for _, player in ipairs(GetPlayers()) do
            if PlayerHasCollectible(player, BlackTaisuiId) and Neverbirth:GetBlackTaisuiStage(player) >= 2 then
                Runtime:TriggerBlackTaisuiSpores(player, "curse:" .. tostring(result), false)
                VisualEffects:Spawn("BlackTaisuiCurseDevour", player.Position or Vector(320, 280), player)
                return result & (~mask)
            end
        end
        return result
    end
    function callbackInstallers.Neverbirth_FilterBlackTaisuiCurses()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, Neverbirth.FilterBlackTaisuiCurses)
    end

    function Runtime:SuppressBlackTaisuiLevelCurses(player)
        local mask = Runtime:GetBlackTaisuiCurseMask()
        if mask == 0 then
            return false
        end
        local game = GetFolkGame()
        local level = game and game.GetLevel and game:GetLevel() or nil
        if not level then
            return false
        end

        local current = nil
        if level.GetCurses then
            local ok, value = pcall(function()
                return level:GetCurses()
            end)
            if ok then
                current = tonumber(value) or 0
                if (current & mask) == 0 then
                    return false
                end
            end
        end

        local changed = false
        if level.RemoveCurses then
            local ok = pcall(function()
                level:RemoveCurses(mask)
            end)
            changed = changed or ok
        end
        if level.RemoveCurse and LevelCurse then
            local curseList = {
                LevelCurse.CURSE_OF_BLIND or LevelCurse.CURSE_OF_THE_BLIND,
                LevelCurse.CURSE_OF_LOST or LevelCurse.CURSE_OF_THE_LOST,
                LevelCurse.CURSE_OF_UNKNOWN or LevelCurse.CURSE_OF_THE_UNKNOWN,
            }
            for _, curse in ipairs(curseList) do
                if curse and curse ~= 0 then
                    local ok = pcall(function()
                        level:RemoveCurse(curse)
                    end)
                    changed = changed or ok
                end
            end
        end
        if current ~= nil and level.SetCurses then
            local ok = pcall(function()
                level:SetCurses(current & (~mask))
            end)
            changed = changed or ok
        end

        if changed and player then
            Runtime:TriggerBlackTaisuiSpores(player, "curse-active:" .. tostring(GetFolkFloorKey()), false)
            VisualEffects:Spawn("BlackTaisuiCurseDevour", player.Position or Vector(320, 280), player)
        end
        return changed
    end

    if ModCallbacks.MC_POST_CURSE_EVAL then
        callbackInstallers.Neverbirth_FilterBlackTaisuiCurses()
    end

    function Runtime:AnyBlackTaisuiStageAtLeast(stage)
        for _, player in ipairs(GetPlayers()) do
            if PlayerHasCollectible(player, BlackTaisuiId) and Neverbirth:GetBlackTaisuiStage(player) >= stage then
                return true, player
            end
        end
        return false, nil
    end

    function Runtime:GetBlackTaisuiCollectibleGfx(subtype)
        if not Isaac or not Isaac.GetItemConfig then
            return nil
        end
        local ok, config = pcall(function()
            return Isaac.GetItemConfig()
        end)
        if not ok or not config or not config.GetCollectible then
            return nil
        end
        local itemOk, collectible = pcall(function()
            return config:GetCollectible(subtype)
        end)
        if itemOk and collectible and collectible.GfxFileName and collectible.GfxFileName ~= "" then
            return collectible.GfxFileName
        end
        return nil
    end

    function Runtime:ApplyBlackTaisuiCollectibleSprite(pickup, subtype)
        if not pickup or not pickup.GetSprite then
            return false
        end
        local gfx = Runtime:GetBlackTaisuiCollectibleGfx(subtype)
        if not gfx then
            return false
        end
        local ok, sprite = pcall(function()
            return pickup:GetSprite()
        end)
        if not ok or not sprite then
            return false
        end
        local animation = "Idle"
        if sprite.GetAnimation then
            local animOk, currentAnimation = pcall(function()
                return sprite:GetAnimation()
            end)
            if animOk and currentAnimation == "ShopIdle" then
                animation = "ShopIdle"
            end
        end
        local replaced = false
        if sprite.ReplaceSpritesheet then
            local replaceOk = pcall(function()
                sprite:ReplaceSpritesheet(1, gfx)
            end)
            replaced = replaced or replaceOk
        end
        if sprite.LoadGraphics then
            pcall(function()
                sprite:LoadGraphics()
            end)
        end
        if replaced then
            if pickup.hidden ~= nil then
                pickup.hidden = false
            end
            if pickup.Hidden ~= nil then
                pickup.Hidden = false
            end
            local data = pickup.GetData and pickup:GetData() or nil
            if type(data) == "table" then
                data.NeverbirthBlackTaisuiSpriteApplied = true
                data.NeverbirthBlackTaisuiSpriteSubtype = subtype
            end
        end
        return replaced
    end

    function Runtime:RevealBlackTaisuiCollectiblePickup(pickup, player, reason)
        if not pickup or not PickupVariant or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
            return false
        end

        local subtype = tonumber(pickup.SubType) or 0
        if subtype <= 0 then
            local data = pickup.GetData and pickup:GetData() or nil
            if type(data) == "table" and not data.NeverbirthBlackTaisuiUnknownLogged then
                data.NeverbirthBlackTaisuiUnknownLogged = true
                DebugLog("[neverbirth] Black Taisui skipped unknown collectible pedestal without subtype")
            end
            return false
        end

        local data = pickup.GetData and pickup:GetData() or nil
        local firstReveal = true
        if type(data) == "table" then
            local key = tostring(GetFolkFloorKey()) .. ":" .. tostring(GetFolkRoomKey()) .. ":" .. tostring(subtype)
            if data.NeverbirthBlackTaisuiRevealedKey == key then
                firstReveal = false
            else
                data.NeverbirthBlackTaisuiRevealedKey = key
            end
        end

        local refreshed = false

        refreshed = Runtime:ApplyBlackTaisuiCollectibleSprite(pickup, subtype) or refreshed

        if refreshed and firstReveal and player then
            Runtime:TriggerBlackTaisuiSpores(player, "reveal:" .. tostring(reason or GetFolkRoomKey()), false)
            VisualEffects:Spawn("BlackTaisuiReveal", pickup.Position or (player and player.Position) or Vector(320, 280), player)
        end
        if refreshed and firstReveal then
            DebugLog("[neverbirth] Black Taisui refreshed collectible pedestal subtype=" .. tostring(subtype))
        end
        return refreshed
    end

    function Runtime:RevealBlackTaisuiRoomCollectibles(player, reason)
        if not Isaac.GetRoomEntities then
            return 0
        end
        local count = 0
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            local pickup = entity
            if entity and entity.ToPickup then
                local ok, converted = pcall(function()
                    return entity:ToPickup()
                end)
                if ok and converted then
                    pickup = converted
                end
            end
            if Runtime:RevealBlackTaisuiCollectiblePickup(pickup, player, reason) then
                count = count + 1
            end
        end
        return count
    end

    function Neverbirth:RevealBlackTaisuiPickupOnInit(pickup)
        if not Runtime.running or Runtime.disposed then return end
        local active, player = Runtime:AnyBlackTaisuiStageAtLeast(2)
        if active then
            Runtime:RevealBlackTaisuiCollectiblePickup(pickup, player, "pickup-init")
        end
    end

    if ModCallbacks.MC_POST_PICKUP_INIT and PickupVariant then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, Neverbirth.RevealBlackTaisuiPickupOnInit, PickupVariant.PICKUP_COLLECTIBLE)
    end

    function Runtime:SuppressBlackTaisuiWavyCapSideEffects(player)
        local removed = 0
        local effectCount = Runtime:GetBlackTaisuiWavyCapEffectCount(player)
        if effectCount > 0 then
            removed = Runtime:RemoveBlackTaisuiWavyCapEffects(player, effectCount)
            if removed > 0 then
                local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
                state.wavySuppressedStacks = (tonumber(state.wavySuppressedStacks) or 0) + removed
                Runtime:RefreshBlackTaisuiCache(player)
            end
        end

        if MusicManager then
            local ok, music = pcall(MusicManager)
            if ok and music then
                if music.PitchSlide then
                    pcall(function()
                        music:PitchSlide(1)
                    end)
                elseif music.SetPitch then
                    pcall(function()
                        music:SetPitch(1)
                    end)
                end
            end
        end

        local game = GetFolkGame()
        if game and game.ShakeScreen then
            pcall(function()
                game:ShakeScreen(0)
            end)
        end

        if removed > 0 then
            Runtime:TriggerBlackTaisuiSpores(player, "wavy:" .. tostring(GetFolkRoomKey()) .. ":" .. tostring(removed), false)
        end
    end

    function Runtime:ReplaceBlackTaisuiWavyCap(player)
        if not player or not PlayerHasCollectible(player, BlackTaisuiId) or Neverbirth:GetBlackTaisuiStage(player) < 2 then
            return false
        end
        if not IsValidItemId(CleansedWavyCapId) or not PlayerHasCollectible(player, Runtime.BlackTaisuiWavyCap) then
            return false
        end

        local count = player.GetCollectibleNum and (tonumber(player:GetCollectibleNum(Runtime.BlackTaisuiWavyCap)) or 0) or 1
        count = math.max(1, math.floor(count))
        local replaced = 0
        for _ = 1, count do
            local removed = false
            if player.RemoveCollectible then
                removed = pcall(function()
                    player:RemoveCollectible(Runtime.BlackTaisuiWavyCap)
                end)
            end
            if removed then
                replaced = replaced + 1
                if player.AddCollectible then
                    pcall(function()
                        player:AddCollectible(CleansedWavyCapId, 0, true)
                    end)
                end
            end
        end

        if replaced > 0 then
            Runtime:SuppressBlackTaisuiWavyCapSideEffects(player)
            VisualEffects:Spawn("BlackTaisuiHallucinationEat", player.Position or Vector(320, 280), player)
            Runtime:TriggerBlackTaisuiSpores(player, "wavy-replace:" .. tostring(GetFolkPlayerKey(player)), false)
            return true
        end
        return false
    end

end
