-- Private state ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local DebugLog = deps.DebugLog
    local Items = deps.Items

    local lifetime = { running = true, disposed = false }
    local ITEM_ID = Items.ACEAntiCheatSystem
    local AUDIT_DURATION_MS = 5000
    local AUDIT_PRESENTATION_STEP = 10
    local AUDIT_FRAME_BUDGET_MS = 300
    local AUDIT_MAX_SPIN_ITERATIONS = 20000000
    local DEATH_THRESHOLD = 3
    local FATAL_MESSAGE = "ACE Anti-Cheat: suspicious combat behavior detected."

    local DATA_MONITORED = "NeverbirthACEMonitored"
    local DATA_DAMAGE_EVENTS = "NeverbirthACEDamageEvents"
    local DATA_DEATH_PROCESSED = "NeverbirthACEDeathProcessed"

    -- Ordinary Repentance has no verified target-FPS or safe process-exit API.
    -- ACE therefore combines the supported Broken Watch slowdown with a
    -- deliberately expensive but strictly bounded main-thread workload.
    -- The time budget and iteration guard prevent an infinite loop. The fatal
    -- fallback is a real team wipe, not a Lua error that disables the mod.
    local capabilities = {
        sameHitDamageRewrite = true,
        guardedDamageReplacement = false,
        targetFps = false,
        safeRoomSlowdown = true,
        boundedFrameThrottle = true,
        fatalProcessExit = false,
        fatalLuaError = false,
        fatalTeamKill = true,
    }

    local runtime = {
        active = false,
        frame = 0,
        pendingDamage = {},
        roomOneHitKills = 0,
        lockUntilMs = 0,
        fatalTriggered = false,
        lastFatalMessage = nil,
        slowRoom = nil,
        previousBrokenWatchState = nil,
        lastKilledPlayers = 0,
        presentationPulses = 0,
        workloadCalls = 0,
        workloadIterations = 0,
        workloadSink = 0,
        warnings = {},
    }


    local function logOnce(key, message)
        if runtime.warnings[key] then return end
        runtime.warnings[key] = true
        DebugLog(message)
    end

    local function realTimeMs()
        if not Isaac or type(Isaac.GetTime) ~= "function" then
            logOnce("clock", "[neverbirth][ACE] Isaac.GetTime is unavailable; real-time audits are disabled")
            return nil
        end
        local ok, value = pcall(Isaac.GetTime)
        if not ok or type(value) ~= "number" then
            logOnce("clock", "[neverbirth][ACE] Isaac.GetTime failed; real-time audits are disabled")
            return nil
        end
        return value
    end

    return {
        logOnce = logOnce,
        realTimeMs = realTimeMs,
        lifetime = lifetime,
        ITEM_ID = ITEM_ID,
        AUDIT_DURATION_MS = AUDIT_DURATION_MS,
        AUDIT_PRESENTATION_STEP = AUDIT_PRESENTATION_STEP,
        AUDIT_FRAME_BUDGET_MS = AUDIT_FRAME_BUDGET_MS,
        AUDIT_MAX_SPIN_ITERATIONS = AUDIT_MAX_SPIN_ITERATIONS,
        DEATH_THRESHOLD = DEATH_THRESHOLD,
        FATAL_MESSAGE = FATAL_MESSAGE,
        DATA_MONITORED = DATA_MONITORED,
        DATA_DAMAGE_EVENTS = DATA_DAMAGE_EVENTS,
        DATA_DEATH_PROCESSED = DATA_DEATH_PROCESSED,
        capabilities = capabilities,
        runtime = runtime,
    }
end
