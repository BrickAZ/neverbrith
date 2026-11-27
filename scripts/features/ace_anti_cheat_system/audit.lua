-- Private audit ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local GetPlayers = deps.GetPlayers
    local DebugLog = deps.DebugLog
    local AUDIT_DURATION_MS = deps.State.AUDIT_DURATION_MS
    local AUDIT_PRESENTATION_STEP = deps.State.AUDIT_PRESENTATION_STEP
    local AUDIT_FRAME_BUDGET_MS = deps.State.AUDIT_FRAME_BUDGET_MS
    local AUDIT_MAX_SPIN_ITERATIONS = deps.State.AUDIT_MAX_SPIN_ITERATIONS
    local DEATH_THRESHOLD = deps.State.DEATH_THRESHOLD
    local FATAL_MESSAGE = deps.State.FATAL_MESSAGE
    local runtime = deps.State.runtime
    local logOnce = deps.State.logOnce
    local realTimeMs = deps.State.realTimeMs
    local safeCall = deps.Queries.safeCall
    local currentGame = deps.Queries.currentGame
    local currentRoom = deps.Queries.currentRoom

    local function readWorkloadClock(clock)
        if type(clock) ~= "function" then return nil end
        local ok, value = pcall(clock)
        if not ok then return nil end
        return tonumber(value)
    end

    local function runAuditWorkload(clock, budgetMs, maxIterations)
        if not runtime.active or runtime.lockUntilMs <= 0 then return 0 end

        local workloadClock = clock
        if type(workloadClock) ~= "function" then
            workloadClock = Isaac and Isaac.GetTime or nil
        end

        local startedAt = readWorkloadClock(workloadClock)
        if startedAt == nil then
            logOnce("workload_clock", "[neverbirth][ACE] Audit workload clock is unavailable")
            return 0
        end

        local requestedBudget = tonumber(budgetMs) or AUDIT_FRAME_BUDGET_MS
        local frameBudget = math.min(AUDIT_FRAME_BUDGET_MS, math.max(0, requestedBudget))
        local remaining = math.max(0, runtime.lockUntilMs - startedAt)
        local deadline = startedAt + math.min(frameBudget, remaining)
        if deadline <= startedAt then return 0 end

        local requestedLimit = math.floor(tonumber(maxIterations) or AUDIT_MAX_SPIN_ITERATIONS)
        local iterationLimit = math.min(AUDIT_MAX_SPIN_ITERATIONS, math.max(1, requestedLimit))
        local iterations = 0
        local current = startedAt
        local sink = tonumber(runtime.workloadSink) or 0

        -- Deliberately waste one main-thread time slice. The clock condition,
        -- per-frame budget and iteration limit are all mandatory exit paths.
        while current < deadline and iterations < iterationLimit do
            iterations = iterations + 1
            sink = (sink + (iterations % 997) * 17) % 2147483647
            if iterations % 64 == 0 then
                current = readWorkloadClock(workloadClock) or deadline
            end
        end

        runtime.workloadSink = sink
        runtime.workloadCalls = math.max(0, tonumber(runtime.workloadCalls) or 0) + 1
        runtime.workloadIterations = math.max(0, tonumber(runtime.workloadIterations) or 0) + iterations
        return iterations
    end

    local function restoreRoomSlowdown()
        local room = runtime.slowRoom
        local previousState = tonumber(runtime.previousBrokenWatchState) or 0
        runtime.slowRoom = nil
        runtime.previousBrokenWatchState = nil
        if not room then return false end

        local _, ok = safeCall(room, "SetBrokenWatchState", previousState)
        if not ok then
            logOnce("slow_restore", "[neverbirth][ACE] Failed to restore the room''s previous Broken Watch state")
        end
        return ok
    end

    local function applyRoomSlowdown()
        local room = currentRoom()
        if not room then
            logOnce("slow_room", "[neverbirth][ACE] Current room is unavailable; severe slowdown cannot be applied")
            return false
        end

        if runtime.slowRoom ~= room then
            restoreRoomSlowdown()
            local previousState, stateOk = safeCall(room, "GetBrokenWatchState")
            runtime.slowRoom = room
            runtime.previousBrokenWatchState = stateOk and (tonumber(previousState) or 0) or 0
        end

        local _, ok = safeCall(room, "SetBrokenWatchState", 1)
        if not ok then
            logOnce("slow_apply", "[neverbirth][ACE] Room:SetBrokenWatchState(1) is unavailable")
        end
        return ok
    end

    local function pulseAuditPresentation(force)
        if not force and runtime.frame % AUDIT_PRESENTATION_STEP ~= 0 then return false end
        local game = currentGame()
        if not game then return false end

        -- These short pulses create a deliberately choppy presentation without
        -- a busy loop or artificial CPU/memory pressure.
        safeCall(game, "AddPixelation", 2)
        safeCall(game, "Darken", 0.35, 2)
        runtime.presentationPulses = math.max(0, tonumber(runtime.presentationPulses) or 0) + 1
        return true
    end

    local function clearAuditState()
        runtime.lockUntilMs = 0
        restoreRoomSlowdown()
    end

    local function killTeam()
        local killed = 0
        for _, player in ipairs(GetPlayers()) do
            local dead, deadOk = safeCall(player, "IsDead")
            if not deadOk or dead ~= true then
                local ok = pcall(function()
                    player:Kill()
                end)
                if ok then killed = killed + 1 end
            end
        end
        runtime.lastKilledPlayers = killed
        return killed
    end

    local function updateAuditState(now, force)
        if runtime.lockUntilMs <= 0 then return false end
        local timestamp = tonumber(now)
        if timestamp == nil then timestamp = realTimeMs() end
        if timestamp == nil then return false end

        if timestamp >= runtime.lockUntilMs then
            clearAuditState()
            return true
        end

        if force or runtime.frame % AUDIT_PRESENTATION_STEP == 0 then
            applyRoomSlowdown()
            pulseAuditPresentation(force == true)
        end
        return false
    end

    local function triggerOneHitAudit(now)
        if type(now) ~= "number" then return false end
        runtime.lockUntilMs = now + AUDIT_DURATION_MS
        applyRoomSlowdown()
        pulseAuditPresentation(true)
        logOnce("fps", "[neverbirth][ACE] Applying a bounded 300ms main-thread workload per update for five real seconds")
        return true
    end

    local function requestFatalAudit()
        if runtime.fatalTriggered then return false end
        runtime.fatalTriggered = true
        runtime.lastFatalMessage = FATAL_MESSAGE
        clearAuditState()
        local killed = killTeam()
        DebugLog(FATAL_MESSAGE .. " Forced team death for " .. tostring(killed) .. " player(s).")
        return true
    end

    local function recordOneHitDeath()
        if runtime.fatalTriggered then return false end
        runtime.roomOneHitKills = math.max(0, tonumber(runtime.roomOneHitKills) or 0) + 1
        if runtime.roomOneHitKills >= DEATH_THRESHOLD then
            return requestFatalAudit()
        end
        return false
    end

    return {
        readWorkloadClock = readWorkloadClock,
        runAuditWorkload = runAuditWorkload,
        restoreRoomSlowdown = restoreRoomSlowdown,
        applyRoomSlowdown = applyRoomSlowdown,
        pulseAuditPresentation = pulseAuditPresentation,
        clearAuditState = clearAuditState,
        killTeam = killTeam,
        updateAuditState = updateAuditState,
        triggerOneHitAudit = triggerOneHitAudit,
        requestFatalAudit = requestFatalAudit,
        recordOneHitDeath = recordOneHitDeath,
    }
end
