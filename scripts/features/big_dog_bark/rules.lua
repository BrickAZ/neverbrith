-- Private rules responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local newVector = deps.Queries.newVector
    local vectorAdd = deps.Queries.vectorAdd
    local vectorScale = deps.Queries.vectorScale
    local vectorLengthSquared = deps.Queries.vectorLengthSquared
    local vectorLength = deps.Queries.vectorLength
    local normalized = deps.Queries.normalized
    local entityKey = deps.Queries.entityKey

    local busyModes = {
        charging = true,
        dash = true,
        echo_wait = true,
        echo = true,
        chew = true,
        chew_pause = true,
        bite_windup = true,
        bite_lunge = true,
        bite_recover = true,
    }


    local function getChargeSeconds(tears)
        local currentTears = math.max(0.0001, tonumber(tears) or 0.0001)
        return math.max(0.1, 0.5 * 2.73 / currentTears)
    end

    local function getChargeFrames(tears)
        return math.ceil(getChargeSeconds(tears) * 30 - 0.0000001)
    end

    local function resolveDirection(currentMovement, rememberedDirection, reverse)
        local current = currentMovement
        local remembered = rememberedDirection
        if vectorLengthSquared(current) > 0.000001 then
            remembered = normalized(current)
        end
        local direction = normalized(remembered, newVector(1, 0))
        if reverse == true then
            direction = vectorScale(direction, -1)
        end
        return direction, remembered
    end

    local function isBusy(mode)
        return busyModes[tostring(mode or "")] == true
    end

    local function computeDashDamage(targetMaxHitPoints, ownerDamage, multiplier)
        local base = 5
            + math.max(0, tonumber(targetMaxHitPoints) or 0) * 0.05
            + math.max(0, tonumber(ownerDamage) or 0) * 0.20
        return base * math.max(0, tonumber(multiplier) or 1)
    end

    local function computeChewDamage(targetMaxHitPoints)
        return math.max(0, tonumber(targetMaxHitPoints) or 0) * 0.10
    end

    local function applyVelocityImpulse(currentVelocity, direction, impulse, speedCap)
        local value = vectorAdd(currentVelocity, vectorScale(normalized(direction), tonumber(impulse) or 0))
        local cap = math.max(0, tonumber(speedCap) or 0)
        local length = vectorLength(value)
        if cap > 0 and length > cap then
            value = vectorScale(value, cap / length)
        end
        return value
    end

    local function registerHit(hitMap, entity)
        if type(hitMap) ~= "table" or not entity then
            return false
        end
        local key = entityKey(entity)
        if key == "" or hitMap[key] then
            return false
        end
        hitMap[key] = true
        return true
    end

    return {
        getChargeSeconds = getChargeSeconds,
        getChargeFrames = getChargeFrames,
        resolveDirection = resolveDirection,
        isBusy = isBusy,
        computeDashDamage = computeDashDamage,
        computeChewDamage = computeChewDamage,
        applyVelocityImpulse = applyVelocityImpulse,
        registerHit = registerHit,
    }
end
