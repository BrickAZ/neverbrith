-- Owns parasite progression, health observations and the one-time stage-three reward.
return function(Neverbirth, dependencies)
    local Runtime = assert(dependencies.Runtime)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local CleansedWavyCap = dependencies.CleansedWavyCap
    local VisualEffects = dependencies.VisualEffects
    local GetFolkGame = dependencies.GetFolkGame
    local GetFolkPlayerKey = dependencies.GetFolkPlayerKey
    local BlackTaisuiId = dependencies.BlackTaisuiId
    local MeatLumpId = dependencies.MeatLumpId
    local IsValidItemId = dependencies.IsValidItemId
    local PlayerHasCollectible = dependencies.PlayerHasCollectible
    local ParasiteState = dependencies.ParasiteState
    local Store = dependencies.Store
    Neverbirth.GetBlackTaisuiData = ParasiteState.GetSaveData
    function Neverbirth:GetBlackTaisuiRuntimeState(player)
        return ParasiteState.GetRuntimeState(player)
    end

    function Neverbirth:GetBlackTaisuiSavedPlayer(player)
        local key = GetFolkPlayerKey(player)
        local data = Neverbirth.GetBlackTaisuiData()
        local saved = data.players[key]
        if type(saved) ~= "table" then
            saved = { parasite = 0 }
            data.players[key] = saved
        end
        saved.parasite = math.max(0, tonumber(saved.parasite) or 0)
        return saved
    end

    function Neverbirth:GetBlackTaisuiParasiteValue(player)
        return tonumber(Neverbirth:GetBlackTaisuiSavedPlayer(player).parasite) or 0
    end

    function Neverbirth:SetBlackTaisuiParasiteValue(player, value)
        local oldStage = Neverbirth:GetBlackTaisuiStage(player)
        Neverbirth:GetBlackTaisuiSavedPlayer(player).parasite = math.max(0, tonumber(value) or 0)
        VisualEffects:Spawn("BlackTaisuiPulse", player and player.Position or Vector(320, 280), player)
        Store.Save()
        Runtime:RefreshBlackTaisuiCache(player)
        if Neverbirth:GetBlackTaisuiStage(player) > oldStage then
            Runtime:TriggerBlackTaisuiSpores(player, "stage-set:" .. tostring(value), true)
        end
        if Neverbirth:GetBlackTaisuiStage(player) >= 2 then
            Runtime:SuppressBlackTaisuiLevelCurses(player)
            Runtime:RevealBlackTaisuiRoomCollectibles(player, "stage-set")
        end
        Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
    end

    function Neverbirth:GetBlackTaisuiStage(player)
        local parasite = Neverbirth:GetBlackTaisuiParasiteValue(player)
        if parasite >= Runtime.BlackTaisuiStageThreeThreshold then
            return 3
        elseif parasite >= Runtime.BlackTaisuiStageTwoThreshold then
            return 2
        end
        return 1
    end

    function Runtime:SpawnBlackTaisuiMeatLump(player)
        if not player or not PlayerHasCollectible(player, BlackTaisuiId) or Neverbirth:GetBlackTaisuiStage(player) < 3 then
            return false
        end
        local saved = Neverbirth:GetBlackTaisuiSavedPlayer(player)
        if saved.meatLumpSpawned then
            return false
        end
        if not IsValidItemId(MeatLumpId) or not Isaac or not Isaac.Spawn or not EntityType or not PickupVariant then
            return false
        end

        local position = player.Position or Vector(320, 280)
        local game = GetFolkGame()
        local room = game and game.GetRoom and game:GetRoom() or nil
        if room and room.FindFreePickupSpawnPosition then
            pcall(function()
                position = room:FindFreePickupSpawnPosition(position, 40, true, false)
            end)
        end

        local ok, spawned = pcall(function()
            return Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, MeatLumpId, position, Vector(0, 0), player)
        end)
        if ok and spawned then
            saved.meatLumpSpawned = true
            Store.Save()
            Runtime:TriggerBlackTaisuiSpores(player, "meat-lump:" .. tostring(GetFolkPlayerKey(player)), true)
            return true
        end
        return false
    end

    function Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
        Runtime:SpawnBlackTaisuiMeatLump(player)
    end

    function Runtime:RefreshBlackTaisuiCache(player)
        if not player or not player.AddCacheFlags or not CacheFlag then
            return
        end
        local flags = 0
        if CacheFlag.CACHE_DAMAGE then flags = flags | CacheFlag.CACHE_DAMAGE end
        if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
        if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
        if CacheFlag.CACHE_RANGE then flags = flags | CacheFlag.CACHE_RANGE end
        if CacheFlag.CACHE_LUCK then flags = flags | CacheFlag.CACHE_LUCK end
        player:AddCacheFlags(flags)
        if player.EvaluateItems then
            player:EvaluateItems()
        end
    end

    function Runtime:AddBlackTaisuiParasite(player, amount, reason)
        if not player or not PlayerHasCollectible(player, BlackTaisuiId) then
            return
        end
        amount = tonumber(amount) or 0
        if amount <= 0 then
            return
        end
        local saved = Neverbirth:GetBlackTaisuiSavedPlayer(player)
        local oldStage = Neverbirth:GetBlackTaisuiStage(player)
        saved.parasite = math.max(0, (tonumber(saved.parasite) or 0) + amount)
        VisualEffects:Spawn("BlackTaisuiPulse", player.Position or Vector(320, 280), player)
        Store.Save()
        Runtime:RefreshBlackTaisuiCache(player)
        if Neverbirth:GetBlackTaisuiStage(player) > oldStage then
            Runtime:TriggerBlackTaisuiSpores(player, "stage:" .. tostring(reason or saved.parasite), true)
        end
        Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
    end

    function Runtime:GetBlackTaisuiHealthSnapshot(player)
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        state.maxHearts = player and player.GetMaxHearts and player:GetMaxHearts() or tonumber(player and player.maxHearts) or 0
        state.hearts = player and player.GetHearts and player:GetHearts() or tonumber(player and player.hearts) or 0
        state.soulHearts = player and player.GetSoulHearts and player:GetSoulHearts() or tonumber(player and player.soulHearts) or 0
        state.blackHearts = player and player.GetBlackHearts and player:GetBlackHearts() or tonumber(player and player.blackHearts) or 0
        state.snapshotReady = true
        return state
    end

    function Runtime:UpdateBlackTaisuiParasiteFromHealth(player)
        if not player or not PlayerHasCollectible(player, BlackTaisuiId) then
            if player then Neverbirth:GetBlackTaisuiRuntimeState(player).snapshotReady = false end
            return
        end
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or tonumber(player.maxHearts) or 0
        local hearts = player.GetHearts and player:GetHearts() or tonumber(player.hearts) or 0
        local soulHearts = player.GetSoulHearts and player:GetSoulHearts() or tonumber(player.soulHearts) or 0
        if not state.snapshotReady then
            Runtime:GetBlackTaisuiHealthSnapshot(player)
            return
        end

        local gainedContainers = math.max(0, maxHearts - (tonumber(state.maxHearts) or 0))
        if gainedContainers > 0 then
            Runtime:AddBlackTaisuiParasite(player, (gainedContainers / 2) * 4, "container")
        end

        if maxHearts > 0 then
            local redHealing = math.max(0, hearts - (tonumber(state.hearts) or 0))
            if redHealing > 0 then
                Runtime:AddBlackTaisuiParasite(player, redHealing, "red-heal")
            end
        else
            -- In Repentance, GetBlackHearts is a bitmask, while GetSoulHearts is
            -- the real soul/black layer amount. Use the layer amount to avoid
            -- treating black-heart masks as extra health.
            local soulHealing = math.max(0, soulHearts - (tonumber(state.soulHearts) or 0))
            if soulHealing > 0 then
                Runtime:AddBlackTaisuiParasite(player, soulHealing * 0.5, "soul-heal")
            end
        end

        Runtime:GetBlackTaisuiHealthSnapshot(player)
    end

    function Neverbirth:EvaluateBlackTaisui(player, cacheFlag)
        if not Runtime.running or Runtime.disposed then return end
        if not player or not CacheFlag or not PlayerHasCollectible(player, BlackTaisuiId) then
            return
        end
        local copies = player.GetCollectibleNum and (tonumber(player:GetCollectibleNum(BlackTaisuiId)) or 0) or 1
        if copies <= 0 then
            return
        end

        local stage = Neverbirth:GetBlackTaisuiStage(player)
        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            if stage >= 3 then
                player.Damage = player.Damage + (Runtime.BlackTaisuiStageThreeDamageBonus * copies)
            else
                local penalty = stage >= 2 and Runtime.BlackTaisuiStageTwoDamagePenalty or (Runtime.BlackTaisuiStageOneDamagePenalty * copies)
                if player.Damage > Runtime.BlackTaisuiDamageFloor then
                    player.Damage = math.max(Runtime.BlackTaisuiDamageFloor, player.Damage - penalty)
                end
            end
        elseif cacheFlag == CacheFlag.CACHE_SPEED then
            if stage == 1 and player.MoveSpeed and player.MoveSpeed > Runtime.BlackTaisuiSpeedFloor then
                player.MoveSpeed = math.max(Runtime.BlackTaisuiSpeedFloor, player.MoveSpeed - Runtime.BlackTaisuiStageOneSpeedPenalty * copies)
            end
            CleansedWavyCap.ApplySpeed(player)
        elseif cacheFlag == CacheFlag.CACHE_LUCK then
            if stage == 1 then
                player.Luck = player.Luck - Runtime.BlackTaisuiStageOneLuckPenalty * copies
            end
        elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            local stacks = tonumber(state.wavySuppressedStacks) or 0
            if stage >= 2 and stacks > 0 and player.MaxFireDelay then
                player.MaxFireDelay = player.MaxFireDelay - (Runtime.BlackTaisuiWavyCapTearsBonus * stacks)
            end
            CleansedWavyCap.ApplyTears(player)
        elseif cacheFlag == CacheFlag.CACHE_RANGE then
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            local stacks = tonumber(state.wavySuppressedStacks) or 0
            if stage >= 2 and stacks > 0 and player.TearRange then
                player.TearRange = player.TearRange + (Runtime.BlackTaisuiWavyCapRangeBonus * stacks)
            end
        end
    end
    function callbackInstallers.Neverbirth_EvaluateBlackTaisui()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateBlackTaisui)
    end

    local function InstallCacheCallback()
        callbackInstallers.Neverbirth_EvaluateBlackTaisui()
    end


    return { InstallCacheCallback = InstallCacheCallback }
end
