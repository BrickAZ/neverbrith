-- Item-owned rewards; the entry coordinates installation of the callback owners.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local GetFolkRandomInt = dependencies.World.GetFolkRandomInt
    local FOLK_ENTITY_PICKUP = dependencies.World.FOLK_ENTITY_PICKUP
    local FOLK_PICKUP_HEART = dependencies.World.FOLK_PICKUP_HEART
    local TheMoonIsBeautifulId = dependencies.TheMoonIsBeautifulId
    local GetPlayers = dependencies.GetPlayers
    local Cards = dependencies.Cards

    private.GetItemPool = Cards.GetItemPool

    private.GetItemConfig = Cards.GetItemConfig

    function Neverbirth.Moon.GetRewardSeed(player, attempt)
        return Cards.RewardSeed(player, attempt, GetFolkRoom, 53)
    end

    function Neverbirth.Moon.IsKnownCardSubtype(subtype)
        subtype = math.floor(tonumber(subtype) or 0)
        if subtype < 1 or subtype > private.Config.MaxReasonableCardSubtype then return false end
        if not Cards.HasDisplayData(private.GetItemConfig(), subtype) then return false end
        local cardVariant = (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300
        return Cards.HasEIDDescription(FOLK_ENTITY_PICKUP, function() return cardVariant end, subtype, true)
    end

    function private.AddCardCandidate(candidates, seen, subtype)
        return Cards.AddCandidate(candidates, seen, subtype, Neverbirth.Moon.IsKnownCardSubtype)
    end

    function Neverbirth.Moon.CollectRewardCardCandidates()
        return Cards.CollectCandidates(function(...) return private.AddCardCandidate(...) end)
    end

    function Neverbirth.Moon.GetPoolCardSubtype(player, attempt)
        local itemPool = private.GetItemPool()
        if not itemPool or not itemPool.GetCard then
            return nil
        end

        local seed = Neverbirth.Moon.GetRewardSeed(player, attempt)
        return Cards.RollPool(itemPool, seed, function(subtype) return Neverbirth.Moon.IsKnownCardSubtype(subtype) end)
    end

    function Neverbirth.Moon.GetRewardCardSubtype(player)
        for attempt = 0, private.Config.CardPickRetries - 1 do
            local subtype = Neverbirth.Moon.GetPoolCardSubtype(player, attempt)
            if subtype then
                return subtype
            end
        end

        local candidates = Neverbirth.Moon.CollectRewardCardCandidates()
        if #candidates > 0 then
            local seed = Neverbirth.Moon.GetRewardSeed(player, 0)
            return candidates[(seed % #candidates) + 1]
        end

        local fallback = (Card and Card.CARD_FOOL) or 1
        if Neverbirth.Moon.IsKnownCardSubtype(fallback) then
            return fallback
        end
        return nil
    end

    function Neverbirth.Moon.SpawnReward(entity, player)
        local position = entity and entity.Position or Vector(320, 280)
        local room = GetFolkRoom()
        if room and room.FindFreePickupSpawnPosition then
            local ok, found = pcall(function()
                return room:FindFreePickupSpawnPosition(position, 40, true, false)
            end)
            if ok and found then
                position = found
            end
        end

        local rewards = {
            { FOLK_ENTITY_PICKUP, FOLK_PICKUP_HEART, (HeartSubType and HeartSubType.HEART_FULL) or 2 },
            { FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_COIN) or 20, (CoinSubType and CoinSubType.COIN_PENNY) or 1 },
            { FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_KEY) or 30, (KeySubType and KeySubType.KEY_NORMAL) or 1 },
            { FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_BOMB) or 40, (BombSubType and BombSubType.BOMB_NORMAL) or 1 },
            { FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_PILL) or 70, 0 },
        }
        local cardSubtype = Neverbirth.Moon.GetRewardCardSubtype(player)
        if cardSubtype then
            rewards[#rewards + 1] = { FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300, cardSubtype }
        end

        local reward = rewards[GetFolkRandomInt(player, TheMoonIsBeautifulId, #rewards) + 1] or rewards[1]
        Isaac.Spawn(reward[1], reward[2], reward[3], position, Vector(0, 0), player or entity)
        private.SpawnVisual("Reward", nil, position)
    end

    function private.HandleMarkedDeath(entity)
        if not private.IsRuntimeActive() then return end
        local data = entity and entity.GetData and entity:GetData() or nil
        if type(data) ~= "table" or data.NeverbirthMoonRewardEligible ~= true then
            return
        end

        data.NeverbirthMoonRewardEligible = false
        private.RemoveVisual(data.NeverbirthMoonMarkVisual)
        data.NeverbirthMoonMarkVisual = nil

        local player = private.GetTriggeringPlayer(private.roomState) or GetPlayers()[1]
        if GetFolkRandomInt(player, TheMoonIsBeautifulId, 100) < private.Config.RewardChance then
            Neverbirth.Moon.SpawnReward(entity, player)
        end
    end

end
