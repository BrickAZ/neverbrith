-- Update, room, start/continue and exit ownership. Bindings remain beside their handlers.
return function(Neverbirth, context, deps)
    local installers = {}
    local currentRunSeed = deps.currentRunSeed
    local runtimePlayerKey = deps.runtimePlayerKey
    local getPlayers = deps.getPlayers
    local playerExists = deps.playerExists
    local playerIsDead = deps.playerIsDead
    local pairMain = deps.pairMain
    local captureHealthLedger = deps.captureHealthLedger
    local updatePermanentSlots = deps.updatePermanentSlots
    local reconcileTemporaryCopies = deps.reconcileTemporaryCopies
    local ensureSavedState = deps.ensureSavedState
    local save = deps.save
    local persistState = deps.persistState
    local importIconHistory = deps.importIconHistory
    local syncIconHistory = deps.syncIconHistory
    local iconIsEligible = deps.iconIsEligible
    local chooseIcon = deps.chooseIcon
    local registerIconDescription = deps.registerIconDescription
    local onOwnershipUpdate = deps.onOwnershipUpdate
    local beginRoomTransitions = deps.beginRoomTransitions
    local advanceFrame = deps.advanceFrame
    local trySpawnVoidPortal = deps.trySpawnVoidPortal
    local liveRoomContext = deps.liveRoomContext
    local SAVE_VERSION = deps.SAVE_VERSION
    local runtime = deps.runtime

    local function onPostUpdate()
        registerIconDescription()
        local livePlayers = {}
        local stateChanged = false
        for _, player in ipairs(getPlayers()) do
            if not runtime.iconHistoryPlayers[runtimePlayerKey(player)] then importIconHistory(player) end
            player = pairMain(player)
            local key = runtimePlayerKey(player)
            livePlayers[key] = true
            onOwnershipUpdate(player)
            local state = runtime.states[key]
            if state and runtime.iconHistoryDirty and not iconIsEligible(state.currentIconId) then
                chooseIcon(player)
                persistState(state)
            end
            if state and playerIsDead(player) and state.transition then
                state.transition = nil
                persistState(state)
                stateChanged = true
            end
        end
        for key, state in pairs(runtime.states) do
            if not livePlayers[key] or not playerExists(state.player) then
                persistState(state)
                runtime.states[key] = nil
                stateChanged = true
            end
        end
        if stateChanged or runtime.iconHistoryDirty then save() end
        runtime.iconHistoryDirty = false
        advanceFrame()
        local roomContext = liveRoomContext()
        if roomContext then trySpawnVoidPortal(roomContext) end
    end
    function installers.onPostUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, onPostUpdate)
    end

    local function onNewRoom()
        syncIconHistory()
        runtime.portalSpawnedThisRoom = false
        runtime.terminalKind = nil
        for _, player in ipairs(getPlayers()) do onOwnershipUpdate(player) end
        beginRoomTransitions("room:" .. tostring(runtime.roomSerial + 1))
    end
    function installers.onNewRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, onNewRoom)
    end

    local function onGameStarted(continued)
        runtime.states = {}
        runtime.roomSerial = 0
        runtime.portalSpawnedThisRoom = false
        runtime.terminalKind = nil
        runtime.diagnostics = {}
        runtime.iconCandidates = nil
        runtime.iconConfigs = {}
        runtime.collectibleGfx = {}
        runtime.iconHistoryPlayers = {}
        runtime.iconHistoryDirty = false
        local root = context.GetSaveRoot and context.GetSaveRoot() or {}
        if not continued then
            root.memoryDisorder = {
                version = SAVE_VERSION,
                runSeed = currentRunSeed(),
                memoryDisorderVoidUnlockedThisRun = false,
                players = {},
                pickedIconItems = {},
                pedestalIconIds = {},
            }
            save()
        else
            ensureSavedState()
            syncIconHistory()
            for _, player in ipairs(getPlayers()) do onOwnershipUpdate(player) end
        end
        syncIconHistory()
    end
    function installers.onGameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, continued) onGameStarted(continued) end)
    end

    local function onPreGameExit()
        syncIconHistory()
        for _, state in pairs(runtime.states) do
            local player = state.player
            captureHealthLedger(player, state)
            reconcileTemporaryCopies(player, state)
            updatePermanentSlots(player, state)
            persistState(state)
        end
        save()
        runtime.states = {}
    end
    function installers.onPreGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, onPreGameExit)
    end

    return {
        onGameStarted = onGameStarted,
        onPreGameExit = onPreGameExit,
        Installers = installers,
    }
end
