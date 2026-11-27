-- Owns update, game-start, exit and unload callbacks.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local GetHouseCarrier = assert(deps.GetHouseCarrier)
    local CONTROL_TRIGGER_ORDER = deps.Config.CONTROL_TRIGGER_ORDER
    local clearTransient = deps.ledger.clearTransient
    local getPersistentData = deps.ledger.getPersistentData
    local save = deps.ledger.save
    local refreshRegistry = deps.ledger.refreshRegistry
    local updateControlTouchLatches = deps.gallery.updateControlTouchLatches
    local processVirtualTransition = deps.flow.processVirtualTransition
    local newRoom = deps.flow.newRoom
    local triggerControl = deps.flow.triggerControl
    local processPendingPickups = deps.pickups.processPendingPickups

    local function update()
        if not lifetime.running then return nil end
        local externalOwner = GetHouseCarrier()
        if externalOwner and externalOwner.IsActive and externalOwner.IsActive() then return nil end
        state.frame = state.frame + 1
        processPendingPickups()
        if state.transition then
            processVirtualTransition()
            return nil
        end
        local persistent = getPersistentData()
        local session = persistent.stack[#persistent.stack]
        if not session or session.phase ~= "active" then return nil end
        local touching = updateControlTouchLatches(session)
        if session.interactionLocked == true
            or state.frame < (tonumber(session.portalArmedFrame) or 0)
            or state.frame < (tonumber(session.controlCooldownUntil) or 0) then return nil end
        for _, role in ipairs(CONTROL_TRIGGER_ORDER) do
            if touching[role] and session.controlTouchLatch[role] ~= true then
                session.controlTouchLatch[role] = true
                if triggerControl(session, role) then return nil end
            end
        end
        return nil
    end
    function callbackInstallers.update()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    end

    local function gameStarted(_, isContinued)
        if lifetime.disposed then return nil end
        lifetime.running = true
        clearTransient()
        refreshRegistry()
        local persistent = getPersistentData()
        if isContinued ~= true then
            persistent.stack = {}
            persistent.nextToken = 1
            save()
        end
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
