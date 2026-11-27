-- Private queries responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local context = deps.Context
    local BIG_DOG_BARK_ID = deps.BIG_DOG_BARK_ID

    local function debugLog(message)
        local text = "[neverbirth][Big Dog Bark] " .. tostring(message)
        if type(context.DebugLog) == "function" then
            pcall(context.DebugLog, text)
        elseif Isaac and type(Isaac.DebugString) == "function" then
            pcall(Isaac.DebugString, text)
        end
    end

    local function newVector(x, y)
        local valueX = tonumber(x) or 0
        local valueY = tonumber(y) or 0
        if Vector ~= nil then
            local ok, value = pcall(function()
                return Vector(valueX, valueY)
            end)
            if ok and value then
                return value
            end
        end
        return { X = valueX, Y = valueY }
    end

    local function vectorX(value)
        return tonumber(value and value.X) or 0
    end

    local function vectorY(value)
        return tonumber(value and value.Y) or 0
    end

    local function vectorAdd(left, right)
        return newVector(vectorX(left) + vectorX(right), vectorY(left) + vectorY(right))
    end

    local function vectorSubtract(left, right)
        return newVector(vectorX(left) - vectorX(right), vectorY(left) - vectorY(right))
    end

    local function vectorScale(value, amount)
        local scalar = tonumber(amount) or 0
        return newVector(vectorX(value) * scalar, vectorY(value) * scalar)
    end

    local function vectorLengthSquared(value)
        local x = vectorX(value)
        local y = vectorY(value)
        return x * x + y * y
    end

    local function vectorLength(value)
        return math.sqrt(vectorLengthSquared(value))
    end

    local function normalized(value, fallback)
        local length = vectorLength(value)
        if length <= 0.000001 then
            if fallback ~= nil then
                return normalized(fallback, nil)
            end
            return newVector(1, 0)
        end
        return newVector(vectorX(value) / length, vectorY(value) / length)
    end

    local function distanceSquared(left, right)
        return vectorLengthSquared(vectorSubtract(left, right))
    end

    local function copyVector(value)
        return newVector(vectorX(value), vectorY(value))
    end

    local function entityExists(entity)
        if not entity then
            return false
        end
        if type(entity.Exists) == "function" then
            local ok, exists = pcall(entity.Exists, entity)
            return ok and exists == true
        end
        return entity.removed ~= true
    end

    local function entityIsDead(entity)
        if not entity then
            return true
        end
        if type(entity.IsDead) == "function" then
            local ok, dead = pcall(entity.IsDead, entity)
            if ok then
                return dead == true
            end
        end
        return entity.dead == true
    end

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function entityKey(entity)
        if not entity then
            return ""
        end
        if type(GetPtrHash) == "function" then
            local ok, value = pcall(GetPtrHash, entity)
            if ok and value ~= nil then
                return "ptr:" .. tostring(value)
            end
        end
        return table.concat({
            "seed",
            tostring(entity.InitSeed or ""),
            tostring(entity.Type or ""),
            tostring(entity.Variant or ""),
            tostring(entity.SubType or ""),
        }, ":")
    end

    local function getPlayers()
        if type(context.GetPlayers) == "function" then
            local ok, players = pcall(context.GetPlayers)
            if ok and type(players) == "table" then
                return players
            end
        end
        return {}
    end

    local function hasCollectible(player, itemId)
        if not player or (tonumber(itemId) or -1) <= 0 or type(player.HasCollectible) ~= "function" then
            return false
        end
        local ok, held = pcall(player.HasCollectible, player, itemId)
        return ok and held == true
    end

    local function collectibleCount(player, itemId)
        if not player or (tonumber(itemId) or -1) <= 0 or type(player.GetCollectibleNum) ~= "function" then
            return 0
        end
        local ok, count = pcall(player.GetCollectibleNum, player, itemId)
        if not ok then
            return 0
        end
        return math.max(0, math.floor(tonumber(count) or 0))
    end

    local function playerIsDead(player)
        if not player then
            return true
        end
        if type(player.IsDead) == "function" then
            local ok, dead = pcall(player.IsDead, player)
            if ok then
                return dead == true
            end
        end
        return false
    end

    local function getCollectibleConfig(itemId)
        if type(context.GetCollectibleConfig) == "function" then
            local ok, config = pcall(context.GetCollectibleConfig, itemId)
            if ok and config then
                return config
            end
        end
        if not Isaac or type(Isaac.GetItemConfig) ~= "function" then
            return nil
        end
        local okConfig, itemConfig = pcall(Isaac.GetItemConfig)
        if not okConfig or not itemConfig or type(itemConfig.GetCollectible) ~= "function" then
            return nil
        end
        local okItem, config = pcall(itemConfig.GetCollectible, itemConfig, itemId)
        return okItem and config or nil
    end

    local function isFoodConfig(config)
        if not config then
            return false
        end
        local foodTag = ItemConfig and ItemConfig.TAG_FOOD
        if not foodTag then
            return false
        end
        if type(config.HasTags) == "function" then
            local ok, tagged = pcall(config.HasTags, config, foodTag)
            if ok then
                return tagged == true
            end
        end
        local tags = tonumber(config.Tags)
        local numericTag = tonumber(foodTag)
        if tags and numericTag then
            return (tags & numericTag) ~= 0
        end
        return false
    end

    local function hasBigDogActive(player)
        if not player or BIG_DOG_BARK_ID <= 0 then
            return false
        end
        if type(player.GetActiveItem) ~= "function" then
            return false
        end
        local slots = {
            ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0,
            ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1,
            ActiveSlot and ActiveSlot.SLOT_POCKET or 2,
            ActiveSlot and ActiveSlot.SLOT_POCKET2 or 3,
        }
        for _, slot in ipairs(slots) do
            local ok, itemId = pcall(player.GetActiveItem, player, slot)
            if ok and tonumber(itemId) == BIG_DOG_BARK_ID then
                return true
            end
        end
        return false
    end

    local function getCurrentRoom()
        if type(Game) ~= "function" then
            return nil
        end
        local okGame, game = pcall(Game)
        if not okGame or not game or type(game.GetRoom) ~= "function" then
            return nil
        end
        local okRoom, room = pcall(game.GetRoom, game)
        return okRoom and room or nil
    end

    return {
        debugLog = debugLog,
        newVector = newVector,
        vectorX = vectorX,
        vectorY = vectorY,
        vectorAdd = vectorAdd,
        vectorSubtract = vectorSubtract,
        vectorScale = vectorScale,
        vectorLengthSquared = vectorLengthSquared,
        vectorLength = vectorLength,
        normalized = normalized,
        distanceSquared = distanceSquared,
        copyVector = copyVector,
        entityExists = entityExists,
        entityIsDead = entityIsDead,
        playerKey = playerKey,
        entityKey = entityKey,
        getPlayers = getPlayers,
        hasCollectible = hasCollectible,
        collectibleCount = collectibleCount,
        playerIsDead = playerIsDead,
        getCollectibleConfig = getCollectibleConfig,
        isFoodConfig = isFoodConfig,
        hasBigDogActive = hasBigDogActive,
        getCurrentRoom = getCurrentRoom,
    }
end
