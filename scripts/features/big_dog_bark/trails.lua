-- Private trails responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local TRAIL_VARIANT = deps.TRAIL_VARIANT
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local newVector = deps.Queries.newVector
    local distanceSquared = deps.Queries.distanceSquared
    local copyVector = deps.Queries.copyVector
    local entityExists = deps.Queries.entityExists
    local playerKey = deps.Queries.playerKey
    local entityKey = deps.Queries.entityKey
    local playerIsDead = deps.Queries.playerIsDead
    local findPlayerByKey = deps.State.findPlayerByKey
    local removeEntity = deps.Effects.removeEntity
    local getSprite = deps.Effects.getSprite
    local dealEnemyDamage = deps.Effects.dealEnemyDamage
    local markEffectCollisionFree = deps.Effects.markEffectCollisionFree
    local spawnOwnedEffect = deps.Effects.spawnOwnedEffect
    local isEligibleEnemy = deps.Targets.isEligibleEnemy
    local getNearbyEnemies = deps.Targets.getNearbyEnemies

    local function removeTrailVisuals(trail)
        for _, node in ipairs((type(trail) == "table" and trail.nodes) or {}) do
            removeEntity(node.entity)
        end
    end

    local function cleanupExpiredTrails(frame)
        local kept = {}
        for _, trail in ipairs(runtime.trails) do
            local expired = math.floor(tonumber(trail.expiresFrame) or 0) <= frame
            if expired then
                removeTrailVisuals(trail)
                runtime.trailById[trail.id] = nil
            else
                local nodes = {}
                for _, node in ipairs(trail.nodes or {}) do
                    if node.entity == nil or entityExists(node.entity) then
                        nodes[#nodes + 1] = node
                    end
                end
                trail.nodes = nodes
                local first = nodes[1]
                trail.entity = first and first.entity or nil
                trail.position = first and first.position or trail.position
                if #nodes == 0 then
                    runtime.trailById[trail.id] = nil
                else
                    kept[#kept + 1] = trail
                end
            end
        end
        runtime.trails = kept
    end

    local function syncTrailVisualScale(node)
        if type(node) ~= "table" or not entityExists(node.entity) then
            return false
        end
        local sprite = getSprite(node.entity)
        if not sprite then
            return false
        end
        local scale = math.max(
            0.01,
            Constants.TRAIL_VISUAL_SCALE
                * (tonumber(node.radius) or Constants.TRAIL_RADIUS)
                / Constants.TRAIL_RADIUS
        )
        local ok = pcall(function()
            sprite.Scale = newVector(scale, scale)
        end)
        return ok
    end

    local function addTrailVisualNode(trail, owner, position, radius)
        trail.nextNodeId = math.floor(tonumber(trail.nextNodeId) or 0) + 1
        local nodeId = trail.nextNodeId
        local entity = spawnOwnedEffect(TRAIL_VARIANT, position, owner, "NeverbirthBigDogTrail")
        local node = {
            id = nodeId,
            entity = entity,
            position = copyVector(position),
            radius = radius,
        }
        trail.nodes[#trail.nodes + 1] = node
        trail.entity = trail.entity or entity
        trail.position = trail.position or node.position
        if entity and type(entity.GetData) == "function" then
            local okData, data = pcall(entity.GetData, entity)
            if okData and type(data) == "table" then
                data.NeverbirthBigDogTrailId = trail.id
                data.NeverbirthBigDogTrailNodeId = nodeId
                data.NeverbirthBigDogTrailRadius = radius
                data.NeverbirthBigDogTrailExpires = trail.expiresFrame
            end
            local sprite = getSprite(entity)
            if sprite and type(sprite.Play) == "function" then
                pcall(sprite.Play, sprite, "Appear", false)
            end
        end
        syncTrailVisualScale(node)
        return node
    end

    local function spawnOrRefreshTrail(owner, position, radius, frame)
        frame = math.floor(tonumber(frame) or runtime.frame)
        radius = math.max(1, tonumber(radius) or Constants.TRAIL_RADIUS)
        cleanupExpiredTrails(frame)
        local merge = nil
        for _, trail in ipairs(runtime.trails) do
            for _, node in ipairs(trail.nodes or {}) do
                local threshold = (tonumber(node.radius) or 0) + radius
                if distanceSquared(node.position, position) <= threshold * threshold then
                    merge = trail
                    break
                end
            end
            if merge then
                break
            end
        end
        local ownerKey = playerKey(owner)
        if merge then
            merge.radius = math.max(tonumber(merge.radius) or 0, radius)
            merge.expiresFrame = frame + Constants.TRAIL_LIFETIME_FRAMES
            merge.contributors[ownerKey] = { player = owner }
            local contained = false
            for _, node in ipairs(merge.nodes or {}) do
                local nodeRadius = tonumber(node.radius) or 0
                local centerDistance = math.sqrt(distanceSquared(node.position, position))
                if centerDistance + radius <= nodeRadius then
                    contained = true
                end
                if entityExists(node.entity) and type(node.entity.GetData) == "function" then
                    local okData, data = pcall(node.entity.GetData, node.entity)
                    if okData and type(data) == "table" then
                        data.NeverbirthBigDogTrailExpires = merge.expiresFrame
                    end
                end
                if entityExists(node.entity) and node.entity.Color ~= nil and type(Color) ~= "nil" then
                    local okColor, tint = pcall(Color, 1, 1, 1, 1, 0, 0, 0)
                    if okColor then
                        node.entity.Color = tint
                    end
                end
            end
            if not contained then
                addTrailVisualNode(merge, owner, position, radius)
            end
            return merge
        end

        runtime.trailSerial = runtime.trailSerial + 1
        local id = runtime.trailSerial
        local trail = {
            id = id,
            radius = radius,
            expiresFrame = frame + Constants.TRAIL_LIFETIME_FRAMES,
            nodes = {},
            nextNodeId = 0,
            contributors = {
                [ownerKey] = { player = owner },
            },
        }
        runtime.trails[#runtime.trails + 1] = trail
        runtime.trailById[id] = trail
        addTrailVisualNode(trail, owner, position, radius)
        return trail
    end

    local function highestTrailOwner(trail)
        local bestPlayer = nil
        local bestDamage = -math.huge
        for key, contributor in pairs(trail.contributors or {}) do
            local player = contributor and contributor.player or findPlayerByKey(key)
            if entityExists(player) and not playerIsDead(player) then
                contributor.player = player
                local damage = math.max(0, tonumber(player.Damage) or 0) * 0.01
                if damage > bestDamage then
                    bestDamage = damage
                    bestPlayer = player
                end
            end
        end
        return bestPlayer, bestDamage
    end

    local function submitTrailCandidates(trail, frame, enemies)
        if type(trail) ~= "table" or math.floor(tonumber(trail.expiresFrame) or 0) <= frame then
            return 0
        end
        local owner, damage = highestTrailOwner(trail)
        if not owner or damage < 0 then
            return 0
        end
        local count = 0
        for _, enemy in ipairs(enemies or {}) do
            if isEligibleEnemy(enemy) then
                local key = entityKey(enemy)
                if key ~= "" then
                    local candidate = runtime.trailCandidates[key]
                    if not candidate or candidate.frame ~= frame or damage > candidate.damage then
                        runtime.trailCandidates[key] = {
                            frame = frame,
                            entity = enemy,
                            damage = damage,
                            owner = owner,
                        }
                    end
                    count = count + 1
                end
            end
        end
        return count
    end

    local function applyTrailCandidates(frame)
        frame = math.floor(tonumber(frame) or runtime.frame)
        if runtime.lastTrailAppliedFrame == frame then
            return 0
        end
        runtime.lastTrailAppliedFrame = frame
        local applied = 0
        local remaining = {}
        for key, candidate in pairs(runtime.trailCandidates) do
            if candidate.frame == frame then
                local enemy = candidate.entity
                if isEligibleEnemy(enemy) then
                    local damaged, source = dealEnemyDamage(enemy, candidate.damage, candidate.owner)
                    if damaged then
                        if type(enemy.AddSlowing) == "function" then
                            local tint = nil
                            if type(Color) == "function" or (type(Color) == "table" and getmetatable(Color)) then
                                local okColor, value = pcall(Color, 0.45, 0.65, 0.2, 1, 0, 0, 0)
                                if okColor then
                                    tint = value
                                end
                            end
                            pcall(
                                enemy.AddSlowing,
                                enemy,
                                source,
                                Constants.TRAIL_SLOW_DURATION,
                                Constants.TRAIL_SLOW_MULTIPLIER,
                                tint
                            )
                        end
                        applied = applied + 1
                    end
                end
            elseif candidate.frame > frame then
                remaining[key] = candidate
            end
        end
        runtime.trailCandidates = remaining
        return applied
    end

    local function removeOwnerFromTrails(ownerKey)
        local kept = {}
        for _, trail in ipairs(runtime.trails) do
            trail.contributors[ownerKey] = nil
            if next(trail.contributors) == nil then
                removeTrailVisuals(trail)
                runtime.trailById[trail.id] = nil
            else
                kept[#kept + 1] = trail
            end
        end
        runtime.trails = kept
    end

    local function updateTrail(_, effect)
        if not effect or type(effect.GetData) ~= "function" then
            return nil
        end
        local okData, data = pcall(effect.GetData, effect)
        if not okData or type(data) ~= "table" or data.NeverbirthBigDogTrail ~= true then
            return nil
        end
        local trail = runtime.trailById[tonumber(data.NeverbirthBigDogTrailId)]
        if not trail or runtime.frame >= trail.expiresFrame then
            removeEntity(effect)
            return nil
        end
        local nodeId = tonumber(data.NeverbirthBigDogTrailNodeId)
        local node = nil
        for _, candidate in ipairs(trail.nodes or {}) do
            if candidate.id == nodeId then
                node = candidate
                break
            end
        end
        if not node then
            removeEntity(effect)
            return nil
        end
        node.entity = effect
        node.position = copyVector(effect.Position or node.position)
        markEffectCollisionFree(effect)
        local remaining = trail.expiresFrame - runtime.frame
        if effect.Color ~= nil and type(Color) ~= "nil" then
            local alpha = remaining <= 30 and math.max(0, remaining / 30) or 1
            local okColor, tint = pcall(Color, 1, 1, 1, alpha, 0, 0, 0)
            if okColor then
                effect.Color = tint
            end
        end
        submitTrailCandidates(
            trail,
            runtime.frame,
            getNearbyEnemies(effect.Position or node.position, node.radius)
        )
        return nil
    end
    function callbackInstallers.updateTrail()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, updateTrail, TRAIL_VARIANT)
    end

    local function clearAllTrails()
        for _, trail in ipairs(runtime.trails) do
            removeTrailVisuals(trail)
        end
        runtime.trails = {}
        runtime.trailById = {}
        runtime.trailCandidates = {}
        runtime.lastTrailAppliedFrame = nil
    end

    return {
        removeTrailVisuals = removeTrailVisuals,
        cleanupExpiredTrails = cleanupExpiredTrails,
        syncTrailVisualScale = syncTrailVisualScale,
        addTrailVisualNode = addTrailVisualNode,
        spawnOrRefreshTrail = spawnOrRefreshTrail,
        highestTrailOwner = highestTrailOwner,
        submitTrailCandidates = submitTrailCandidates,
        applyTrailCandidates = applyTrailCandidates,
        removeOwnerFromTrails = removeOwnerFromTrails,
        updateTrail = updateTrail,
        clearAllTrails = clearAllTrails,
        Installers = callbackInstallers,
    }
end
