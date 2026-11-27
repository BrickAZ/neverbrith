return function(Neverbirth, dependencies)
    local Rolls = include("scripts.systems.collectible_rng")
    local Collectibles = include("scripts.systems.collectible_stats")(dependencies.IsValidItemId)
    local WorldQueries = include("scripts.runtime.world_queries")
    local IsValidItemId = dependencies.IsValidItemId

    local FOLK_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local FOLK_PICKUP_HEART = (PickupVariant and PickupVariant.PICKUP_HEART) or 10

    local function GetFolkGame()
        return WorldQueries.TryGame() or nil
    end

    local function GetFolkRoom()
        return WorldQueries.TryMethod(GetFolkGame(), "GetRoom")
    end

    local function GetFolkRoomKey()
        local game = GetFolkGame()
        if not game or not game.GetLevel then
            return "0:0:0"
        end

        local ok, level = pcall(function()
            return game:GetLevel()
        end)
        if not ok or not level then
            return "0:0:0"
        end

        local stage = level.GetStage and level:GetStage() or 0
        local stageType = level.GetStageType and level:GetStageType() or 0
        local roomIndex = level.GetCurrentRoomIndex and level:GetCurrentRoomIndex() or 0
        return tostring(stage) .. ":" .. tostring(stageType) .. ":" .. tostring(roomIndex)
    end

    local function GetFolkFloorKey()
        local game = GetFolkGame()
        if not game or not game.GetLevel then
            return "0:0"
        end

        local ok, level = pcall(function()
            return game:GetLevel()
        end)
        if not ok or not level then
            return "0:0"
        end

        local stage = level.GetStage and level:GetStage() or 0
        local stageType = level.GetStageType and level:GetStageType() or 0
        return tostring(stage) .. ":" .. tostring(stageType)
    end

    local function GetFolkPlayerKey(player)
        return tostring((player and player.InitSeed) or "0")
    end

    local function PlayerHasCollectible(player, itemId)
        return Collectibles.Has(player, itemId)
    end

    local function GetPlayerCoins(player)
        if player and player.GetNumCoins then
            local ok, coins = pcall(function()
                return player:GetNumCoins()
            end)
            if ok then
                return tonumber(coins) or 0
            end
        end

        return tonumber(player and player.coins) or 0
    end

    local function AddPlayerCoins(player, amount)
        if player and player.AddCoins then
            pcall(function()
                player:AddCoins(amount)
            end)
        end
    end

    local function GetFolkRandomInt(player, itemId, max)
        max = tonumber(max) or 1
        if max <= 1 then return 0 end
        return Rolls.IntOrMath(Rolls.Get(player, itemId, "RandomInt"), max)
    end

    local function IsVulnerableEnemy(entity)
        if not entity or entity.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) then
            return false
        end

        if entity.IsVulnerableEnemy then
            local ok, result = pcall(function()
                return entity:IsVulnerableEnemy()
            end)
            if ok then
                return result == true
            end
        end

        return false
    end

    local function SpawnFolkEffect(variant, position, spawner)
        if Isaac.Spawn then
            return Isaac.Spawn((EntityType and EntityType.ENTITY_EFFECT) or 1000, variant, 0, position or Vector(320, 280), Vector(0, 0), spawner)
        end

        return nil
    end

    return {
        GetFolkGame = GetFolkGame,
        GetFolkRoom = GetFolkRoom,
        GetFolkRoomKey = GetFolkRoomKey,
        GetFolkFloorKey = GetFolkFloorKey,
        GetFolkPlayerKey = GetFolkPlayerKey,
        PlayerHasCollectible = PlayerHasCollectible,
        GetPlayerCoins = GetPlayerCoins,
        AddPlayerCoins = AddPlayerCoins,
        GetFolkRandomInt = GetFolkRandomInt,
        IsVulnerableEnemy = IsVulnerableEnemy,
        SpawnFolkEffect = SpawnFolkEffect,
        FOLK_ENTITY_PICKUP = FOLK_ENTITY_PICKUP,
        FOLK_PICKUP_HEART = FOLK_PICKUP_HEART,
    }
end
