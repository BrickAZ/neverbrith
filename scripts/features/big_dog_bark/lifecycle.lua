-- Private lifecycle responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local runtime = deps.State.Runtime
    local currentRunSeed = deps.State.currentRunSeed
    local save = deps.State.save
    local resetSavedState = deps.State.resetSavedState
    local getSavedState = deps.State.getSavedState
    local clearChargeSoundSchedule = deps.Audio.clearChargeSoundSchedule
    local removeEntity = deps.Effects.removeEntity
    local scanCurrentRoomTargets = deps.Targets.scanCurrentRoomTargets
    local cleanupExpiredTrails = deps.Trails.cleanupExpiredTrails
    local applyTrailCandidates = deps.Trails.applyTrailCandidates
    local removeOwnerFromTrails = deps.Trails.removeOwnerFromTrails
    local clearAllTrails = deps.Trails.clearAllTrails
    local settleFoodPickups = deps.Food.settleFoodPickups

    local function clearPlayerTransient(state, removeTrails)
        if type(state) ~= "table" then
            return
        end
        removeEntity(state.dog)
        removeEntity(state.echoEntity)
        state.dog = nil
        state.echoEntity = nil
        state.echoData = nil
        state.echoActive = false
        state.dash = nil
        state.mode = "follow"
        state.chargeStartFrame = nil
        state.chargeFrames = nil
        state.chargeSlot = nil
        state.chargeSawHeld = false
        state.chargeReady = false
        clearChargeSoundSchedule(state)
        state.chargeBarPhase = nil
        state.chargeBarVisible = false
        state.chewTarget = nil
        state.chewTargetKey = nil
        state.chewPauseUntil = nil
        state.chewSearchPending = true
        state.lastChewSearchVersion = -1
        state.nextChewSearchFrame = 0
        state.chewPath = nil
        state.chewPathNode = 1
        state.chewPathTargetKey = nil
        state.nextChewPathFrame = 0
        state.chewPathFailureCount = 0
        state.chewMoveVelocity = nil
        state.chewSafePosition = nil
        state.nextChewSafeFrame = 0
        state.chewWindupDirection = nil
        state.chewLungeDirection = nil
        state.chewLungeStart = nil
        state.chewLungeTravel = nil
        state.chewHitConsumed = false
        state.chewAnimation = nil
        if removeTrails then
            removeOwnerFromTrails(state.key)
        end
    end

    local function newRoom()
        runtime.pendingFood = {}
        clearAllTrails()
        for _, state in pairs(runtime.players) do
            removeEntity(state.dog)
            removeEntity(state.echoEntity)
            state.dog = nil
            state.echoEntity = nil
            state.echoData = nil
            state.echoActive = false
            state.dash = nil
            state.mode = "follow"
            state.chargeStartFrame = nil
            state.chargeFrames = nil
            state.chargeSlot = nil
            state.chargeSawHeld = false
            state.chargeReady = false
            clearChargeSoundSchedule(state)
            state.chargeBarPhase = nil
            state.chargeBarVisible = false
            state.chewTarget = nil
            state.chewTargetKey = nil
            state.chewPauseUntil = nil
            state.chewSearchPending = true
            state.lastChewSearchVersion = -1
            state.nextChewSearchFrame = 0
            state.chewPath = nil
            state.chewPathNode = 1
            state.chewPathTargetKey = nil
            state.nextChewPathFrame = 0
            state.chewPathFailureCount = 0
            state.chewMoveVelocity = nil
            state.chewSafePosition = nil
            state.nextChewSafeFrame = 0
            state.chewWindupDirection = nil
            state.chewLungeDirection = nil
            state.chewLungeStart = nil
            state.chewLungeTravel = nil
            state.chewHitConsumed = false
            state.chewAnimation = nil
            state.roomChewed = {}
        end
        scanCurrentRoomTargets()
        return nil
    end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function newLevel()
        -- MC_POST_NEW_ROOM already reset the new floor's starting room.
        return nil
    end
    function callbackInstallers.newLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
    end

    local function postUpdate()
        applyTrailCandidates(runtime.frame)
        runtime.frame = runtime.frame + 1

        settleFoodPickups(runtime.frame)
        cleanupExpiredTrails(runtime.frame)
        return nil
    end
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    end

    local function gameStarted(_, isContinued)
        clearAllTrails()
        runtime.frame = 0
        runtime.serial = 0
        runtime.trailSerial = 0
        runtime.players = {}
        runtime.pendingFood = {}
        runtime.roomTargets = {}
        runtime.roomTargetKeys = {}
        runtime.roomTargetVersion = 0
        runtime.chewSearchCount = 0
        runtime.savedAtExit = false
        runtime.testRunSeed = nil

        if isContinued ~= true then
            resetSavedState(currentRunSeed())
            save()
        else
            getSavedState()
        end
        scanCurrentRoomTargets()
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        runtime.savedAtExit = true
        save()
        return nil
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    local function resetForTest(seed)
        clearAllTrails()
        runtime.frame = 0
        runtime.serial = 0
        runtime.trailSerial = 0
        runtime.players = {}
        runtime.pendingFood = {}
        runtime.roomTargets = {}
        runtime.roomTargetKeys = {}
        runtime.roomTargetVersion = 0
        runtime.chewSearchCount = 0
        runtime.trails = {}
        runtime.trailById = {}
        runtime.trailCandidates = {}
        runtime.lastTrailAppliedFrame = nil
        runtime.fallbackSaveRoot = {}
        runtime.testRunSeed = tostring(seed or "test")
        runtime.savedAtExit = false
        resetSavedState(runtime.testRunSeed)
        return runtime
    end

    return {
        clearPlayerTransient = clearPlayerTransient,
        newRoom = newRoom,
        newLevel = newLevel,
        postUpdate = postUpdate,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        resetForTest = resetForTest,
        Installers = callbackInstallers,
    }
end
