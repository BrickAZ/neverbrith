-- Item-owned rewards; the entry coordinates installation of the callback owners.
return function(Neverbirth, dependencies)
    local VisualEffects = assert(dependencies.VisualEffects)
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local GetFolkRandomInt = dependencies.World.GetFolkRandomInt
    local FOLK_ENTITY_PICKUP = dependencies.World.FOLK_ENTITY_PICKUP
    local FOLK_PICKUP_HEART = dependencies.World.FOLK_PICKUP_HEART
    local GoodGirlOfBabylonId = dependencies.GoodGirlOfBabylonId
    local GOOD_GIRL_HALF_SOUL = (HeartSubType and HeartSubType.HEART_HALF_SOUL) or 8
    local GOOD_GIRL_COIN = (CoinSubType and CoinSubType.COIN_PENNY) or 1
    local Cards = dependencies.Cards

    local GetGoodGirlItemPool = Cards.GetItemPool

    local GetGoodGirlItemConfig = Cards.GetItemConfig

    local function GetGoodGirlRewardSeed(player, attempt)
        return Cards.RewardSeed(player, attempt, GetFolkRoom, 37)
    end

    local function IsGoodGirlKnownCardSubtype(subtype)
        subtype = math.floor(tonumber(subtype) or 0)
        if subtype < 1 or subtype > Neverbirth.GoodGirl.MaxReasonableCardSubtype then return false end
        if not Cards.HasDisplayData(GetGoodGirlItemConfig(), subtype) then return false end
        return Cards.HasEIDDescription(FOLK_ENTITY_PICKUP,
            function() return (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300 end, subtype, false)
    end

    local function AddGoodGirlCardCandidate(candidates, seen, subtype)
        return Cards.AddCandidate(candidates, seen, subtype, IsGoodGirlKnownCardSubtype)
    end

    local function CollectGoodGirlCardCandidates()
        return Cards.CollectCandidates(AddGoodGirlCardCandidate)
    end

    local function GetGoodGirlRewardCardSubtype(player)
        local itemPool = GetGoodGirlItemPool()
        if itemPool and itemPool.GetCard then
            for attempt = 0, Neverbirth.GoodGirl.CardPickRetries - 1 do
                local seed = GetGoodGirlRewardSeed(player, attempt)
                local subtype = Cards.RollPool(itemPool, seed, IsGoodGirlKnownCardSubtype)
                if subtype then return subtype end
            end
        end

        local candidates = CollectGoodGirlCardCandidates()
        if #candidates <= 0 then
            return (Card and Card.CARD_FOOL) or 1
        end

        local seed = GetGoodGirlRewardSeed(player, 0)
        return candidates[(seed % #candidates) + 1]
    end

    local function SpawnGoodGirlReward(player)
        local position = player and player.Position or Vector(320, 280)
        local room = GetFolkRoom()
        if room and room.FindFreePickupSpawnPosition then
            position = room:FindFreePickupSpawnPosition(position, 40, true, false)
        end

        local reward = GetFolkRandomInt(player, GoodGirlOfBabylonId, 3)
        if reward == 0 then
            Isaac.Spawn(FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300, GetGoodGirlRewardCardSubtype(player), position, Vector(0, 0), player)
        elseif reward == 1 then
            Isaac.Spawn(FOLK_ENTITY_PICKUP, FOLK_PICKUP_HEART, GOOD_GIRL_HALF_SOUL, position, Vector(0, 0), player)
        else
            Isaac.Spawn(FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_COIN) or 20, GOOD_GIRL_COIN, position, Vector(0, 0), player)
        end
        VisualEffects:Spawn("GoodGirlReward", position, player)
    end

    return {
        GetGoodGirlItemPool = GetGoodGirlItemPool,
        GetGoodGirlItemConfig = GetGoodGirlItemConfig,
        GetGoodGirlRewardSeed = GetGoodGirlRewardSeed,
        IsGoodGirlKnownCardSubtype = IsGoodGirlKnownCardSubtype,
        AddGoodGirlCardCandidate = AddGoodGirlCardCandidate,
        CollectGoodGirlCardCandidates = CollectGoodGirlCardCandidates,
        GetGoodGirlRewardCardSubtype = GetGoodGirlRewardCardSubtype,
        SpawnGoodGirlReward = SpawnGoodGirlReward,
    }
end
