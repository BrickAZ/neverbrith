-- Private combat ownership for Annihilation.
return function(Neverbirth, deps)
    local runtime = deps.State
    local CAR_BATTERY_ID = deps.Config.CAR_BATTERY_ID
    local CAR_BATTERY_CHARGE_PER_HIT = deps.Config.CAR_BATTERY_CHARGE_PER_HIT
    local CAR_BATTERY_ACTIVE_SLOTS = deps.Config.CAR_BATTERY_ACTIVE_SLOTS
    local AURA_RADIUS = deps.Config.AURA_RADIUS
    local AURA_DAMAGE_MULTIPLIER = deps.Config.AURA_DAMAGE_MULTIPLIER
    local SHOCKWAVE_RADIUS = deps.Config.SHOCKWAVE_RADIUS
    local SHOCKWAVE_DAMAGE_MULTIPLIER = deps.Config.SHOCKWAVE_DAMAGE_MULTIPLIER
    local SHOCKWAVE_FRAMES = deps.Config.SHOCKWAVE_FRAMES
    local trace = deps.Queries.trace
    local failOnce = deps.Queries.failOnce
    local entityExists = deps.Queries.entityExists
    local entityIsDead = deps.Queries.entityIsDead
    local isHostileNpc = deps.Queries.isHostileNpc
    local circlesIntersect = deps.Queries.circlesIntersect
    local distanceBetween = deps.Queries.distanceBetween
    local getState = deps.Ledger.getState
    local removeEffect = deps.Presentation.removeEffect

    local function playerHasCarBattery(player)
        if not player or not CAR_BATTERY_ID or CAR_BATTERY_ID <= 0
            or type(player.HasCollectible) ~= "function"
        then
            return false
        end
        local ok, hasBattery = pcall(player.HasCollectible, player, CAR_BATTERY_ID)
        return ok and hasBattery == true
    end

    local function chargeActiveSlot(player, slot)
        if not player or type(player.AddActiveCharge) ~= "function" then
            failOnce("nativeCharge", "AddActiveCharge unavailable; active charging skipped")
            return false
        end
        -- Fixed per-hit gain must not become a timed full recharge or reject special actives.
        local ok, added = pcall(player.AddActiveCharge, player, CAR_BATTERY_CHARGE_PER_HIT, slot, true, false, true)
        if not ok then
            failOnce("nativeCharge", "AddActiveCharge failed; active charging skipped")
            return false
        end
        return (tonumber(added) or 0) > 0
    end

    local function chargeCarBatterySynergy(player)
        if not getState(player) or not playerHasCarBattery(player) then return 0 end
        local chargedSlots = 0
        for _, slot in ipairs(CAR_BATTERY_ACTIVE_SLOTS) do
            if chargeActiveSlot(player, slot) then chargedSlots = chargedSlots + 1 end
        end
        return chargedSlots
    end

    local function damageNpc(npc, amount, player)
        if amount <= 0 or not isHostileNpc(npc, true) or type(npc.TakeDamage) ~= "function" then return false end
        local sourceOk, source = pcall(function() return EntityRef(player) end)
        if not sourceOk or not source then
            failOnce("EntityRef", sourceOk and "constructor returned nil" or source)
            return false
        end
        local ok, result = pcall(npc.TakeDamage, npc, amount, 0, source, 0)
        if not ok then failOnce("TakeDamage", result) end
        local hitSucceeded = ok and result ~= false
        local state = getState(player)
        if state and not state.damageObserved then
            state.damageObserved = true
            trace("first-damage:" .. tostring(hitSucceeded))
        end
        if hitSucceeded then chargeCarBatterySynergy(player) end
        return hitSucceeded
    end

    local function applyAuraDamage(state)
        local player = state and state.player
        if not player or not player.Position then return end
        local amount = math.max(0, tonumber(player.Damage) or 0) * AURA_DAMAGE_MULTIPLIER
        for key, npc in pairs(runtime.roomNpcs) do
            if not entityExists(npc) or entityIsDead(npc) then
                runtime.roomNpcs[key] = nil
            elseif circlesIntersect(player.Position, AURA_RADIUS, npc) then
                damageNpc(npc, amount, player)
            end
        end
    end

    local function updateShockwave(state, wave)
        local previousRadius = SHOCKWAVE_RADIUS * math.min(wave.age, SHOCKWAVE_FRAMES) / SHOCKWAVE_FRAMES
        wave.age = wave.age + 1
        local currentRadius = SHOCKWAVE_RADIUS * math.min(wave.age, SHOCKWAVE_FRAMES) / SHOCKWAVE_FRAMES
        local player = state.player
        local amount = math.max(0, tonumber(player and player.Damage) or 0) * SHOCKWAVE_DAMAGE_MULTIPLIER

        for key, npc in pairs(runtime.roomNpcs) do
            if not entityExists(npc) or entityIsDead(npc) then
                runtime.roomNpcs[key] = nil
            elseif not wave.hit[key] and isHostileNpc(npc, true) and npc.Position then
                local distance = distanceBetween(wave.origin, npc.Position)
                local size = math.max(0, tonumber(npc.Size) or 0)
                if distance - size <= currentRadius and distance + size >= previousRadius then
                    wave.hit[key] = true
                    damageNpc(npc, amount, player)
                end
            end
        end

        if wave.age >= SHOCKWAVE_FRAMES then
            removeEffect(wave.effect)
            return false
        end
        return true
    end

    return {
        playerHasCarBattery = playerHasCarBattery,
        chargeActiveSlot = chargeActiveSlot,
        chargeCarBatterySynergy = chargeCarBatterySynergy,
        damageNpc = damageNpc,
        applyAuraDamage = applyAuraDamage,
        updateShockwave = updateShockwave,
    }
end
