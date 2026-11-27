-- Private kamikaze_squad responsibility: targets. No registration until an installer is called.
return function(Neverbirth, deps)
    local runtime = deps.Runtime
    local entityKey = deps.entityKey
    local isValidHostile = deps.isValidHostile
    local getRoomEntities = deps.getRoomEntities

    local function trackEnemy(entity)
        local key = entityKey(entity)
        if not key or not isValidHostile(entity) or runtime.hostileSet[key] then return false end
        runtime.hostileSet[key] = true
        runtime.hostiles[#runtime.hostiles + 1] = entity
        return true
    end

    local function removeTrackedEnemy(entity)
        local key = entityKey(entity)
        if not key or not runtime.hostileSet[key] then return end
        runtime.hostileSet[key] = nil
        for index = #runtime.hostiles, 1, -1 do
            if entityKey(runtime.hostiles[index]) == key then
                table.remove(runtime.hostiles, index)
                break
            end
        end
    end

    local function pruneHostiles()
        for index = #runtime.hostiles, 1, -1 do
            local entity = runtime.hostiles[index]
            if not isValidHostile(entity) then
                local key = entityKey(entity)
                if key then runtime.hostileSet[key] = nil end
                table.remove(runtime.hostiles, index)
            end
        end
    end

    local function seedRoomHostiles()
        if runtime.roomSeeded then return end
        runtime.roomSeeded = true
        for _, entity in ipairs(getRoomEntities()) do trackEnemy(entity) end
    end

    local function nearestHostile(position)
        pruneHostiles()
        local nearest = nil
        local nearestDistance = math.huge
        for _, enemy in ipairs(runtime.hostiles) do
            local delta = enemy.Position - position
            local distance = delta.LengthSquared and delta:LengthSquared() or math.huge
            if distance < nearestDistance then
                nearest = enemy
                nearestDistance = distance
            end
        end
        return nearest
    end

    return {
        trackEnemy = trackEnemy,
        removeTrackedEnemy = removeTrackedEnemy,
        pruneHostiles = pruneHostiles,
        seedRoomHostiles = seedRoomHostiles,
        nearestHostile = nearestHostile,
    }
end
