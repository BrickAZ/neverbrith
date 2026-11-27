-- Private night_of_the_cowards responsibility: queries. No registration until an installer is called.
return function(Neverbirth, deps)
    local context = deps.Context
    local ITEM_ID = deps.Config.ITEM_ID
    local PLAYER_ENTITY = deps.Config.PLAYER_ENTITY
    local HOST_ENTITY = deps.Config.HOST_ENTITY
    local CURSED_DEATH_HEAD_TYPE = deps.Config.CURSED_DEATH_HEAD_TYPE
    local CURSED_DEATH_HEAD_VARIANT = deps.Config.CURSED_DEATH_HEAD_VARIANT
    local FRIENDLY_FLAG = deps.Config.FRIENDLY_FLAG
    local CHARM_FLAG = deps.Config.CHARM_FLAG
    local HOST_VARIANTS = deps.Config.HOST_VARIANTS

    local function zeroVector()
        if Vector then
            local ok, value = pcall(function() return Vector.Zero end)
            if ok and value then return value end
        end
        if type(Vector) == "function" then return Vector(0, 0) end
        return nil
    end

    local function debugLog(message)
        if type(context.DebugLog) == "function" then
            context.DebugLog("[Night of the Cowards] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[Night of the Cowards] " .. tostring(message))
        end
    end

    local function getPlayers()
        if type(context.GetPlayers) ~= "function" then return {} end
        local ok, players = pcall(context.GetPlayers)
        return ok and type(players) == "table" and players or {}
    end

    local function makeVector(x, y)
        if type(Vector) == "function" or type(Vector) == "table" then
            local ok, value = pcall(Vector, tonumber(x) or 0, tonumber(y) or 0)
            if ok and value then return value end
        end
        return { X = tonumber(x) or 0, Y = tonumber(y) or 0 }
    end

    local function playerKey(player)
        return tostring(math.floor(tonumber(player and player.InitSeed) or -1))
    end

    local function collectibleCount(player)
        if ITEM_ID <= 0 or not player then return 0 end
        if type(player.GetCollectibleNum) == "function" then
            local ok, count = pcall(player.GetCollectibleNum, player, ITEM_ID)
            if ok then return math.max(0, math.floor(tonumber(count) or 0)) end
        end
        if type(player.HasCollectible) == "function" then
            local ok, held = pcall(player.HasCollectible, player, ITEM_ID)
            if ok and held == true then return 1 end
        end
        return 0
    end

    local function anyPlayerHasItem()
        for _, player in ipairs(getPlayers()) do
            if collectibleCount(player) > 0 then return true end
        end
        return false
    end

    local function entityExists(entity)
        if not entity then return false end
        if type(entity.Exists) == "function" then
            local ok, exists = pcall(entity.Exists, entity)
            return ok and exists == true
        end
        return true
    end

    local function entityIsDead(entity)
        if not entity or type(entity.IsDead) ~= "function" then return false end
        local ok, dead = pcall(entity.IsDead, entity)
        return ok and dead == true
    end

    local function toNpc(entity)
        if not entity then return nil end
        if type(entity.ToNPC) == "function" then
            local ok, npc = pcall(entity.ToNPC, entity)
            if ok and npc then return npc end
        end
        if type(entity.IsActiveEnemy) == "function" then return entity end
        return nil
    end

    local function toPlayer(entity)
        if not entity then return nil end
        if type(entity.ToPlayer) == "function" then
            local ok, player = pcall(entity.ToPlayer, entity)
            if ok and player then return player end
        end
        if tonumber(entity.Type) == PLAYER_ENTITY then return entity end
        return nil
    end

    local function hasEntityFlag(entity, flag)
        if not flag or not entity or type(entity.HasEntityFlags) ~= "function" then return false end
        local ok, result = pcall(entity.HasEntityFlags, entity, flag)
        return ok and result == true
    end

    local function isAuraEnemy(entity)
        local npc = toNpc(entity)
        if not npc or not entityExists(npc) or entityIsDead(npc) then return false end
        if hasEntityFlag(npc, FRIENDLY_FLAG) or hasEntityFlag(npc, CHARM_FLAG) then return false end
        if type(npc.IsActiveEnemy) == "function" then
            local ok, active = pcall(npc.IsActiveEnemy, npc, false)
            if not ok or active ~= true then return false end
        end
        return true
    end

    local function isNativeCursedDeathHead(entity)
        local npc = toNpc(entity)
        return npc ~= nil
            and tonumber(npc.Type) == CURSED_DEATH_HEAD_TYPE
            and tonumber(npc.Variant) == CURSED_DEATH_HEAD_VARIANT
    end

    local function isBoss(npc)
        if not npc or type(npc.IsBoss) ~= "function" then return false end
        local ok, result = pcall(npc.IsBoss, npc)
        return ok and result == true
    end

    local function isVulnerable(npc)
        if not npc or type(npc.IsVulnerableEnemy) ~= "function" then return true end
        local ok, result = pcall(npc.IsVulnerableEnemy, npc)
        return ok and result == true
    end

    local function isTransformableEnemy(entity)
        local npc = toNpc(entity)
        return isAuraEnemy(npc)
            and not isNativeCursedDeathHead(npc)
            and not isBoss(npc)
            and isVulnerable(npc)
            and tonumber(npc.Type) ~= HOST_ENTITY
    end

    local function getData(entity)
        if not entity or type(entity.GetData) ~= "function" then return nil end
        local ok, data = pcall(entity.GetData, entity)
        return ok and type(data) == "table" and data or nil
    end

    local function stableHostVariant(npc)
        local seed = math.abs(math.floor(tonumber(npc and npc.InitSeed) or 0))
        return HOST_VARIANTS[(seed % #HOST_VARIANTS) + 1]
    end

    local function distanceSquared(left, right)
        local dx = (tonumber(left and left.X) or 0) - (tonumber(right and right.X) or 0)
        local dy = (tonumber(left and left.Y) or 0) - (tonumber(right and right.Y) or 0)
        return dx * dx + dy * dy
    end

    return {
        zeroVector = zeroVector,
        debugLog = debugLog,
        getPlayers = getPlayers,
        makeVector = makeVector,
        playerKey = playerKey,
        collectibleCount = collectibleCount,
        anyPlayerHasItem = anyPlayerHasItem,
        entityExists = entityExists,
        entityIsDead = entityIsDead,
        toNpc = toNpc,
        toPlayer = toPlayer,
        hasEntityFlag = hasEntityFlag,
        isAuraEnemy = isAuraEnemy,
        isNativeCursedDeathHead = isNativeCursedDeathHead,
        isBoss = isBoss,
        isVulnerable = isVulnerable,
        isTransformableEnemy = isTransformableEnemy,
        getData = getData,
        stableHostVariant = stableHostVariant,
        distanceSquared = distanceSquared,
    }
end
