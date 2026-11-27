-- Private queries ownership for Annihilation.
return function(Neverbirth, deps)
    local context = deps.Context
    local runtime = deps.State
    local PLAYER_ENTITY = deps.Config.PLAYER_ENTITY
    local FRIENDLY_FLAG = deps.Config.FRIENDLY_FLAG
    local CHARM_FLAG = deps.Config.CHARM_FLAG
    local failures = {}
    local diagnostics = context.Diagnostics == true

    local function debugLog(message)
        if type(context.DebugLog) == "function" then
            context.DebugLog("[Annihilation] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[Annihilation] " .. tostring(message))
        end
    end

    local function trace(phase)
        if diagnostics then debugLog(phase) end
    end

    local function failOnce(kind, err)
        if failures[kind] then return end
        failures[kind] = tostring(err)
        debugLog(kind .. ": " .. tostring(err))
    end

    local function entityKey(entity)
        if not entity then return nil end
        local ok, hash = pcall(function() return GetPtrHash(entity) end)
        if not ok or hash == nil or entity.InitSeed == nil then
            failOnce("identity", ok and "missing GetPtrHash/InitSeed" or hash)
            return nil
        end
        return tostring(hash) .. ":" .. tostring(entity.InitSeed)
    end

    local function zeroVector()
        if Vector then
            local ok, value = pcall(function() return Vector.Zero end)
            if ok and value then return value end
        end
        if type(Vector) == "function" then return Vector(0, 0) end
        return nil
    end

    local function copyPosition(position)
        if position then
            local ok, value = pcall(function() return Vector(position.X, position.Y) end)
            if ok then return value end
            failOnce("Vector", value)
        end
        return nil
    end

    local function getData(entity)
        if not entity or type(entity.GetData) ~= "function" then return nil end
        local ok, data = pcall(entity.GetData, entity)
        return ok and type(data) == "table" and data or nil
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

    local function playerIsDead(player)
        return player and type(player.IsDead) == "function" and entityIsDead(player) or false
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

    local function toNpc(entity)
        if not entity then return nil end
        if type(entity.ToNPC) == "function" then
            local ok, npc = pcall(entity.ToNPC, entity)
            if ok and npc then return npc end
        end
        if type(entity.IsActiveEnemy) == "function" then return entity end
        return nil
    end

    local function hasEntityFlag(entity, flag)
        if not flag or not entity or type(entity.HasEntityFlags) ~= "function" then return false end
        local ok, value = pcall(entity.HasEntityFlags, entity, flag)
        return ok and value == true
    end

    local function isHostileNpc(entity, requireVulnerable)
        local npc = toNpc(entity)
        if not npc or not entityExists(npc) or entityIsDead(npc) then return false end
        if hasEntityFlag(npc, FRIENDLY_FLAG) or hasEntityFlag(npc, CHARM_FLAG) then return false end
        if type(npc.IsActiveEnemy) == "function" then
            local ok, active = pcall(npc.IsActiveEnemy, npc, false)
            if not ok or active ~= true then return false end
        end
        if requireVulnerable and type(npc.IsVulnerableEnemy) == "function" then
            local ok, vulnerable = pcall(npc.IsVulnerableEnemy, npc)
            if not ok or vulnerable ~= true then return false end
        end
        return true
    end

    local function getPlayers()
        if type(context.GetPlayers) ~= "function" then return {} end
        local ok, players = pcall(context.GetPlayers)
        return ok and type(players) == "table" and players or {}
    end

    local function getRoomEntities()
        if type(context.GetRoomEntities) == "function" then
            local ok, entities = pcall(context.GetRoomEntities)
            if ok and type(entities) == "table" then return entities end
        end
        if Isaac and type(Isaac.GetRoomEntities) == "function" then
            local ok, entities = pcall(Isaac.GetRoomEntities)
            if ok and type(entities) == "table" then return entities end
        end
        return {}
    end

    local function getFrameCount()
        if type(context.GetFrameCount) == "function" then
            local ok, frame = pcall(context.GetFrameCount)
            if ok then return math.floor(tonumber(frame) or runtime.logicalFrame) end
        end
        if Game then
            local ok, game = pcall(Game)
            if ok and game and type(game.GetFrameCount) == "function" then
                local frameOk, frame = pcall(game.GetFrameCount, game)
                if frameOk then return math.floor(tonumber(frame) or runtime.logicalFrame) end
            end
        end
        return runtime.logicalFrame
    end

    local function circlesIntersect(origin, radius, npc)
        if not origin or not npc or not npc.Position then return false end
        local dx = (tonumber(origin.X) or 0) - (tonumber(npc.Position.X) or 0)
        local dy = (tonumber(origin.Y) or 0) - (tonumber(npc.Position.Y) or 0)
        local combined = radius + math.max(0, tonumber(npc.Size) or 0)
        return dx * dx + dy * dy <= combined * combined
    end

    local function distanceBetween(left, right)
        local dx = (tonumber(left and left.X) or 0) - (tonumber(right and right.X) or 0)
        local dy = (tonumber(left and left.Y) or 0) - (tonumber(right and right.Y) or 0)
        return math.sqrt(dx * dx + dy * dy)
    end

    return {
        debugLog = debugLog,
        trace = trace,
        failOnce = failOnce,
        entityKey = entityKey,
        zeroVector = zeroVector,
        copyPosition = copyPosition,
        getData = getData,
        entityExists = entityExists,
        entityIsDead = entityIsDead,
        playerIsDead = playerIsDead,
        toPlayer = toPlayer,
        toNpc = toNpc,
        hasEntityFlag = hasEntityFlag,
        isHostileNpc = isHostileNpc,
        getPlayers = getPlayers,
        getRoomEntities = getRoomEntities,
        getFrameCount = getFrameCount,
        circlesIntersect = circlesIntersect,
        distanceBetween = distanceBetween,
        Failures = failures,
        SetDiagnostics = function(enabled) diagnostics = enabled == true end,
    }
end
