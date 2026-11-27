-- Private runtime ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local lifetime = deps.State.lifetime
    local runtime = deps.State.runtime
    local logOnce = deps.State.logOnce
    local itemCount = deps.Queries.itemCount
    local anyHolder = deps.Queries.anyHolder
    local runAuditWorkload = deps.Audit.runAuditWorkload
    local clearAuditState = deps.Audit.clearAuditState
    local updateAuditState = deps.Audit.updateAuditState
    local monitorCurrentRoom = deps.Combat.monitorCurrentRoom
    local settleAllPending = deps.Combat.settleAllPending

    local function resetRoomState()
        runtime.pendingDamage = {}
        runtime.roomOneHitKills = 0
    end

    local function resetAll()
        clearAuditState()
        runtime.active = false
        runtime.frame = 0
        runtime.pendingDamage = {}
        runtime.roomOneHitKills = 0
        runtime.fatalTriggered = false
        runtime.lastFatalMessage = nil
        runtime.lastKilledPlayers = 0
        runtime.presentationPulses = 0
        runtime.workloadCalls = 0
        runtime.workloadIterations = 0
        runtime.workloadSink = 0
        runtime.warnings = {}
    end

    local function activate()
        resetRoomState()
        runtime.active = true
        runtime.fatalTriggered = false
        runtime.lastFatalMessage = nil
        monitorCurrentRoom(true)
        logOnce("damage", "[neverbirth][ACE] REPENTOGON rewrites incoming damage in the same hit; no replacement damage event")
    end

    local function deactivate()
        resetAll()
    end

    local function playerDamage(_, entity, amount, flags, source, countdown)
        if not lifetime.running then return nil end
        local player = entity and entity.ToPlayer and entity:ToPlayer() or nil
        local damageAmount = tonumber(amount) or 0
        if not player or itemCount(player) <= 0 or damageAmount <= 0 then return nil end

        return { Damage = damageAmount * 2 }
    end
    function callbackInstallers.playerDamage()
        return Neverbirth:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, CallbackPriority.EARLY, playerDamage, EntityType and EntityType.ENTITY_PLAYER or 1)
    end

    local function postUpdate()
        if not lifetime.running then return nil end
        runtime.frame = runtime.frame + 1
        local held = anyHolder()
        if held and not runtime.active then
            activate()
        elseif not held and runtime.active then
            deactivate()
            return nil
        end
        if not runtime.active then return nil end

        settleAllPending()
        updateAuditState()
        runAuditWorkload()
        return nil
    end
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    end

    local function newRoom()
        if not lifetime.running then return nil end
        resetRoomState()
        if anyHolder() then
            runtime.active = true
            monitorCurrentRoom(true)
            updateAuditState(nil, true)
        else
            deactivate()
        end
        return nil
    end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function newLevel()
        return newRoom()
    end
    function callbackInstallers.newLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
    end

    local function gameStarted()
        if lifetime.disposed then return nil end
        lifetime.running = true
        resetAll()
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        lifetime.running = false
        resetAll()
        return nil
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    local function preModUnload(_, unloaded)
        if unloaded ~= Neverbirth or lifetime.disposed then return end
        lifetime.disposed = true
        preGameExit()
    end
    function callbackInstallers.preModUnload()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, preModUnload)
    end

    return {
        resetRoomState = resetRoomState,
        resetAll = resetAll,
        activate = activate,
        deactivate = deactivate,
        playerDamage = playerDamage,
        postUpdate = postUpdate,
        newRoom = newRoom,
        newLevel = newLevel,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        preModUnload = preModUnload,
        Installers = callbackInstallers,
    }
end
