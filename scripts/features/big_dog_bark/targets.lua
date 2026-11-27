-- Private targets responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local EFFECT_ENTITY = deps.EFFECT_ENTITY
    local PICKUP_ENTITY = deps.PICKUP_ENTITY
    local ENEMY_PARTITION = deps.ENEMY_PARTITION
    local FRIENDLY_FLAG = deps.FRIENDLY_FLAG
    local CHARM_FLAG = deps.CHARM_FLAG
    local runtime = deps.State.Runtime
    local newVector = deps.Queries.newVector
    local vectorX = deps.Queries.vectorX
    local vectorY = deps.Queries.vectorY
    local vectorAdd = deps.Queries.vectorAdd
    local vectorSubtract = deps.Queries.vectorSubtract
    local vectorScale = deps.Queries.vectorScale
    local vectorLengthSquared = deps.Queries.vectorLengthSquared
    local vectorLength = deps.Queries.vectorLength
    local distanceSquared = deps.Queries.distanceSquared
    local entityExists = deps.Queries.entityExists
    local entityIsDead = deps.Queries.entityIsDead
    local entityKey = deps.Queries.entityKey
    local getPlayerRuntime = deps.State.getPlayerRuntime
    local dealEnemyDamage = deps.Effects.dealEnemyDamage

    local function hasExcludedEnemyFlag(npc)
        if not npc or type(npc.HasEntityFlags) ~= "function" then
            return false
        end
        if FRIENDLY_FLAG ~= 0 then
            local ok, present = pcall(npc.HasEntityFlags, npc, FRIENDLY_FLAG)
            if ok and present == true then
                return true
            end
        end
        if CHARM_FLAG ~= 0 then
            local ok, present = pcall(npc.HasEntityFlags, npc, CHARM_FLAG)
            if ok and present == true then
                return true
            end
        end
        return false
    end

    local function isEligibleEnemy(entity)
        if not entityExists(entity) or entityIsDead(entity) then
            return false
        end
        local npc = entity
        if type(entity.ToNPC) == "function" then
            local ok, converted = pcall(entity.ToNPC, entity)
            if not ok or not converted then
                return false
            end
            npc = converted
        elseif tonumber(entity.Type) == EFFECT_ENTITY or tonumber(entity.Type) == PICKUP_ENTITY then
            return false
        end
        if type(npc.IsVulnerableEnemy) == "function" then
            local ok, vulnerable = pcall(npc.IsVulnerableEnemy, npc)
            if not ok or vulnerable ~= true then
                return false
            end
        end
        if type(npc.IsActiveEnemy) == "function" then
            local ok, active = pcall(npc.IsActiveEnemy, npc, false)
            if not ok or active ~= true then
                return false
            end
        end
        if hasExcludedEnemyFlag(npc) then
            return false
        end
        return true
    end

    local function isPotentialEnemy(entity)
        if not entityExists(entity) or entityIsDead(entity) then
            return false
        end
        local npc = entity
        if type(entity.ToNPC) == "function" then
            local ok, converted = pcall(entity.ToNPC, entity)
            if not ok or not converted then
                return false
            end
            npc = converted
        elseif tonumber(entity.Type) == EFFECT_ENTITY or tonumber(entity.Type) == PICKUP_ENTITY then
            return false
        end
        return true
    end

    local function makeEntityReference(entity, key)
        local reference = {
            NeverbirthBigDogEntityReference = true,
            key = key or entityKey(entity),
            entity = entity,
            pointer = nil,
        }
        if EntityPtr ~= nil then
            local ok, pointer = pcall(function()
                return EntityPtr(entity)
            end)
            if ok and pointer then
                reference.pointer = pointer
                reference.entity = nil
            end
        end
        return reference
    end

    local function resolveEntityReference(reference)
        if type(reference) ~= "table" or reference.NeverbirthBigDogEntityReference ~= true then
            return reference
        end
        if reference.pointer then
            local ok, entity = pcall(function()
                return reference.pointer.Ref
            end)
            return ok and entity or nil
        end
        return reference.entity
    end

    local function entityReferenceKey(reference, entity)
        if type(reference) == "table" and reference.NeverbirthBigDogEntityReference == true then
            return tostring(reference.key or "")
        end
        return entityKey(entity or reference)
    end

    local function registerRoomTarget(entity)
        if not isPotentialEnemy(entity) then
            return false
        end
        local key = entityKey(entity)
        if key == "" or runtime.roomTargetKeys[key] then
            return false
        end
        runtime.roomTargetKeys[key] = true
        runtime.roomTargets[#runtime.roomTargets + 1] = makeEntityReference(entity, key)
        runtime.roomTargetVersion = runtime.roomTargetVersion + 1
        return true
    end

    local function selectChewTarget(player, enemies)
        runtime.chewSearchCount = runtime.chewSearchCount + 1
        local state = getPlayerRuntime(player, true)
        if not state then
            return nil
        end
        local origin = (state.dog and state.dog.Position) or player.Position or newVector(0, 0)
        local best = nil
        local bestDistance = math.huge
        for _, reference in ipairs(enemies or runtime.roomTargets) do
            local entity = resolveEntityReference(reference)
            local key = entityReferenceKey(reference, entity)
            if key ~= "" and not state.roomChewed[key] and isEligibleEnemy(entity) and entity.Position then
                local value = distanceSquared(origin, entity.Position)
                if value < bestDistance then
                    best = entity
                    bestDistance = value
                end
            end
        end
        return best
    end

    local function getNearbyEnemies(position, radius)
        if not Isaac or type(Isaac.FindInRadius) ~= "function" then
            return {}
        end
        local ok, entities = pcall(Isaac.FindInRadius, position, radius, ENEMY_PARTITION)
        return ok and type(entities) == "table" and entities or {}
    end

    local function damageEnemy(enemy, amount, owner)
        if not isEligibleEnemy(enemy) then
            return false
        end
        local damaged = dealEnemyDamage(enemy, amount, owner)
        return damaged == true
    end

    local function damageOnce(hitMap, enemy, amount, owner)
        if type(hitMap) ~= "table" or not enemy then
            return false
        end
        local key = entityKey(enemy)
        if key == "" or hitMap[key] then
            return false
        end
        if not damageEnemy(enemy, amount, owner) then
            return false
        end
        hitMap[key] = true
        return true
    end

    local function pointSegmentDistanceSquared(point, segmentStart, segmentEnd)
        local segment = vectorSubtract(segmentEnd, segmentStart)
        local lengthSquared = vectorLengthSquared(segment)
        if lengthSquared <= 0.000001 then
            return distanceSquared(point, segmentStart)
        end
        local offset = vectorSubtract(point, segmentStart)
        local projection = (
            vectorX(offset) * vectorX(segment)
            + vectorY(offset) * vectorY(segment)
        ) / lengthSquared
        projection = math.max(0, math.min(1, projection))
        local closest = vectorAdd(segmentStart, vectorScale(segment, projection))
        return distanceSquared(point, closest)
    end

    local function getEnemiesAlongSegment(segmentStart, segmentEnd, radius)
        radius = math.max(0, tonumber(radius) or 0)
        local midpoint = vectorScale(vectorAdd(segmentStart, segmentEnd), 0.5)
        local queryRadius = vectorLength(vectorSubtract(segmentEnd, segmentStart)) * 0.5 + radius
        local enemies = {}
        for _, enemy in ipairs(getNearbyEnemies(midpoint, queryRadius)) do
            local contactRadius = radius + math.max(0, tonumber(enemy and enemy.Size) or 0)
            if pointSegmentDistanceSquared(enemy.Position, segmentStart, segmentEnd) <= contactRadius * contactRadius then
                enemies[#enemies + 1] = enemy
            end
        end
        return enemies
    end

    local function npcInit(_, npc)
        registerRoomTarget(npc)
        return nil
    end
    function callbackInstallers.npcInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
    end

    local function entityRemove(_, entity)
        local key = entityKey(entity)
        if key == "" or runtime.roomTargetKeys[key] ~= true then
            return nil
        end
        runtime.roomTargetKeys[key] = nil
        local kept = {}
        for _, reference in ipairs(runtime.roomTargets) do
            if entityReferenceKey(reference) ~= key then
                kept[#kept + 1] = reference
            end
        end
        runtime.roomTargets = kept
        runtime.roomTargetVersion = runtime.roomTargetVersion + 1
        for _, state in pairs(runtime.players) do
            state.roomChewed[key] = nil
            if state.chewTargetKey == key then
                state.chewTarget = nil
                state.chewTargetKey = nil
                state.chewSearchPending = true
            end
        end
        return nil
    end
    function callbackInstallers.entityRemove()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, entityRemove)
    end

    local function scanCurrentRoomTargets()
        runtime.roomTargets = {}
        runtime.roomTargetKeys = {}
        runtime.roomTargetVersion = runtime.roomTargetVersion + 1
        if not Isaac or type(Isaac.GetRoomEntities) ~= "function" then
            return
        end
        local ok, entities = pcall(Isaac.GetRoomEntities)
        if not ok or type(entities) ~= "table" then
            return
        end
        for _, entity in ipairs(entities) do
            registerRoomTarget(entity)
        end
    end

    return {
        hasExcludedEnemyFlag = hasExcludedEnemyFlag,
        isEligibleEnemy = isEligibleEnemy,
        isPotentialEnemy = isPotentialEnemy,
        makeEntityReference = makeEntityReference,
        resolveEntityReference = resolveEntityReference,
        entityReferenceKey = entityReferenceKey,
        registerRoomTarget = registerRoomTarget,
        selectChewTarget = selectChewTarget,
        getNearbyEnemies = getNearbyEnemies,
        damageEnemy = damageEnemy,
        damageOnce = damageOnce,
        pointSegmentDistanceSquared = pointSegmentDistanceSquared,
        getEnemiesAlongSegment = getEnemiesAlongSegment,
        npcInit = npcInit,
        entityRemove = entityRemove,
        scanCurrentRoomTargets = scanCurrentRoomTargets,
        Installers = callbackInstallers,
    }
end
