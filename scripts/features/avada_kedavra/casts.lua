-- Private casts ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local state = deps.State
    local log = deps.Queries.log
    local trace = deps.Queries.trace
    local exists = deps.Queries.exists
    local frame = deps.Queries.frame
    local ghost = deps.Queries.ghost
    local resetCharge = deps.Weapon.resetCharge
    local restoreWeapon = deps.Weapon.restoreWeapon

    local function clearAttacks(s)
        for _, cast in pairs(s.casts) do
            cast.cancelled = true
            for targetKey in pairs(cast.pendingDeaths) do state.pendingDeaths[targetKey] = nil end
            for _, e in pairs(cast.entities) do if exists(e) then e:Remove() end end
        end
        s.casts, s.pending = {}, nil
        resetCharge(s)
        s.allowFire, s.releaseFrame = false, nil
        s.phase, s.peakCharge = "idle", 0
    end

    local function dropState(k, s)
        clearAttacks(s)
        restoreWeapon(s)
        state.states[k] = nil
    end

    local function beginCast(s)
        state.nextCast = state.nextCast + 1
        local cast = { id=state.nextCast, state=s, damage=s.player.Damage,
            entities={}, pendingDeaths={}, success=false, started=frame(), rootSeen=false }
        s.casts[cast.id], s.pending = cast, cast
        trace("cast " .. cast.id .. " native release observed; damage=" .. cast.damage)
        return cast
    end

    local function failCast(s, cast)
        if s.failed or not exists(s.player) or s.player:IsDead() or ghost(s.player) then return end
        s.failed = true -- installed BEFORE Kill or any recursive native callback.
        clearAttacks(s)
        log("cast " .. cast.id .. " failed: normal owner-only death")
        s.player:Kill() -- not damage: does not trigger our lethal-hit shields.
    end

    return {
        clearAttacks = clearAttacks,
        dropState = dropState,
        beginCast = beginCast,
        failCast = failCast,
        Installers = callbackInstallers,
    }
end
