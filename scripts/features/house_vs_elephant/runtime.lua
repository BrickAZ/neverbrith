-- Owns update, game-start, exit and unload callbacks.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local Store = assert(deps.Store)
    local GetCurrentRunSeed = assert(deps.GetCurrentRunSeed)
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local clearTransient = deps.ledger.clearTransient
    local normalizeRunData = deps.ledger.normalizeRunData
    local getPersistentData = deps.ledger.getPersistentData
    local save = deps.ledger.save
    local processControls = deps.flow.processControls
    local newRoom = deps.flow.newRoom
    local processPending = deps.pickups.processPending

    local function update()
        if not lifetime.running then return nil end
        state.frame = state.frame + 1
        processPending()
        local runData = getPersistentData()
        local session = runData.session
        processControls(runData, session)
        return nil
    end
    function callbackInstallers.update()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    end

    local function gameStarted(_, isContinued)
        if lifetime.disposed then return nil end
        lifetime.running = true
        clearTransient()
        local old = Store.Get()
        local stale = type(old) == "table" and old.session or nil
        local value = normalizeRunData(old, GetCurrentRunSeed(), isContinued == true)
        if isContinued ~= true then
            value.encounters, value.seenKeys = {}, {}
            value.nextSequence, value.nextSessionToken = 1, 1
            value.session = nil
        end
        Store.Replace(value)
        state.pending = {}
        if isContinued == true and stale then state.returningAfterContinue = stale else state.returningAfterContinue = nil end
        state.transition = nil
        state.controlEntities = {}
        save()
        newRoom(nil, true)
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        if not lifetime.running then return nil end
        save()
        lifetime.running = false
        clearTransient()
        return nil
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    local function preModUnload(_, unloaded)
        if unloaded ~= Neverbirth or lifetime.disposed then return end
        lifetime.disposed, lifetime.running = true, false
        clearTransient()
    end
    function callbackInstallers.preModUnload()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, preModUnload)
    end

    return {
        update = update,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        preModUnload = preModUnload,
        Installers = callbackInstallers,
    }
end
