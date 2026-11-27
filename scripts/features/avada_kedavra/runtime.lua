-- Private runtime ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local state = deps.State
    local context = deps.Context
    local CHARGE_FRAMES = deps.CHARGE_FRAMES
    local log = deps.Queries.log
    local failOnce = deps.Queries.failOnce
    local trace = deps.Queries.trace
    local exists = deps.Queries.exists
    local key = deps.Queries.key
    local frame = deps.Queries.frame
    local seedNpcs = deps.Queries.seedNpcs
    local nativeCharge = deps.Weapon.nativeCharge
    local clearAttacks = deps.Casts.clearAttacks
    local dropState = deps.Casts.dropState
    local failCast = deps.Casts.failCast
    local castOf = deps.Entities.castOf
    local clearDeath = deps.Hits.clearDeath
    local confirmDeath = deps.Hits.confirmDeath

    local function removed(_, e)
        local ekey = key(e)
        state.npcs[ekey] = nil
        if state.pendingDeaths[ekey] then
            if e:IsDead() or e.HitPoints <= 0 then confirmDeath(ekey) else clearDeath(ekey) end
        end
        state.damageBefore[ekey], state.collisions[ekey] = nil, nil
        local cast = castOf(e)
        if cast then cast.entities[key(e)] = nil end
    end
    function callbackInstallers.removed(add)
        return add("MC_POST_ENTITY_REMOVE",removed)
    end

    local function update()
        -- Cancelled TakeDamage has no POST callback. Its pre-hit snapshot
        -- must not leak into a later hit or room.
        state.damageBefore, state.collisions = {}, {}
        for targetKey, receipt in pairs(state.pendingDeaths) do
            if not exists(receipt.target) then clearDeath(targetKey)
            elseif receipt.target:IsDead() or receipt.target.HitPoints <= 0 then confirmDeath(targetKey) end
        end
        for k, s in pairs(state.states) do
            if not exists(s.player) then dropState(k, s)
            elseif not s.failed then
                local charge = nativeCharge(s)
                s.peakCharge = math.max(s.peakCharge or 0, charge)
                if s.allowFire then
                    s.phase = s.pending and "waiting_native" or
                        (charge >= CHARGE_FRAMES and "charged" or (charge > 0 and "charging" or "idle"))
                end
                if s.pending then
                    local pending = s.pending
                    if pending.rootSeen then s.pending = nil
                    elseif frame() > pending.started + 1 then
                        s.pending = nil
                        if pending.outputSeen then
                            -- A missing/delayed swirl receipt must never erase
                            -- a real shot or bypass its eventual miss penalty.
                            trace("cast " .. pending.id .. " emitted; awaiting native lifetime without swirl receipt")
                        else
                            pending.cancelled = true
                            s.casts[pending.id] = nil
                            failOnce("no native attack after release; nativePassed="
                                .. tostring(pending.nativePassed == true))
                        end
                    end
                end
                for id, cast in pairs(s.casts) do
                    local alive = false
                    for ekey, e in pairs(cast.entities) do
                        if exists(e) then alive = true else cast.entities[ekey] = nil end
                    end
                    if alive or next(cast.pendingDeaths) then cast.emptyFrame = nil
                    elseif cast.outputSeen and s.pending ~= cast and not cast.cancelled then
                        -- A removal and native child creation can happen in the
                        -- same update. Only settle after the next complete pass.
                        if not cast.emptyFrame then cast.emptyFrame = frame()
                        elseif frame() > cast.emptyFrame then
                            s.casts[id] = nil
                            if cast.success then trace("cast " .. id .. " succeeded")
                            else failCast(s, cast); break end
                        end
                    end
                end
            end
        end
    end
    function callbackInstallers.update(add)
        return add("MC_POST_UPDATE",update)
    end

    local function newRoom()
        for _, s in pairs(state.states) do clearAttacks(s) end
        state.npcs, state.collisions, state.damageBefore, state.pendingDeaths, state.nativeEffect, state.seeded = {}, {}, {}, {}, nil, false
        for _, s in pairs(state.states) do if not s.failed then seedNpcs(); break end end
    end
    function callbackInstallers.newRoom(add)
        return add("MC_POST_NEW_ROOM",newRoom)
    end

    local function reset()
        for k, s in pairs(state.states) do dropState(k, s) end
        state.states, state.npcs, state.collisions, state.damageBefore, state.pendingDeaths = {}, {}, {}, {}, {}
        state.nativeEffect, state.seeded = nil, false
    end
    function callbackInstallers.reset(add)
        return add("MC_POST_GAME_STARTED",reset)
    end
    function callbackInstallers.reset2(add)
        return add("MC_PRE_GAME_EXIT",reset)
    end

    local function command(_, cmd, params)
        if cmd == "avada_trace" then
            state.traceEnabled = params == "on"
            log("trace=" .. tostring(state.traceEnabled))
        elseif cmd == "avada_status" then
            for index, p in ipairs(context.GetPlayers()) do
                local v=mod.AvadaKedavra.Status(p)
                Isaac.ConsoleOutput(string.format("Avada player %d: charge=%.2f/30 peak=%.2f phase=%s casts=%d nativePasses=%d pending=%s failed=%s\n",index,v.charge,v.peakCharge,v.phase,v.casts,v.nativePasses,tostring(v.pending),tostring(v.failed)))
            end
        end
    end
    function callbackInstallers.command(add)
        return add("MC_EXECUTE_CMD",command)
    end

    function callbackInstallers.prePlayerRevive(add)
        add("MC_PRE_PLAYER_REVIVE",function(_,p) if mod.AvadaKedavra.IsFailureDeath(p) then return false end end,-1000)
    end

    return {
        removed = removed,
        update = update,
        newRoom = newRoom,
        reset = reset,
        command = command,
        Installers = callbackInstallers,
    }
end
