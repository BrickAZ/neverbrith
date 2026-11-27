-- Owns entering, paging, returning and room lifecycle.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local GetPlayers = assert(deps.GetPlayers)
    local DebugLog = assert(deps.Log)
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local GetCertificateCarrier = assert(deps.GetCertificateCarrier)
    local HOUSE = deps.Config.HOUSE
    local SPECIAL_ROOM_INDEX = deps.Config.SPECIAL_ROOM_INDEX
    local SPECIAL_ROOM_COMMAND = deps.Config.SPECIAL_ROOM_COMMAND
    local NO_DIRECTION = deps.Config.NO_DIRECTION
    local TELEPORT_ANIMATION = deps.Config.TELEPORT_ANIMATION
    local PAGE_PRESS_FRAMES = deps.Config.PAGE_PRESS_FRAMES
    local RETURN_PRESS_FRAMES = deps.Config.RETURN_PRESS_FRAMES
    local CONTROL_COOLDOWN_FRAMES = deps.Config.CONTROL_COOLDOWN_FRAMES
    local CONTROL_TRIGGER_ORDER = deps.Config.CONTROL_TRIGGER_ORDER
    local call = deps.Room.call
    local currentGame = deps.Room.currentGame
    local findPlayer = deps.Room.findPlayer
    local restorePlayerPositions = deps.Room.restorePlayerPositions
    local getPersistentData = deps.ledger.getPersistentData
    local save = deps.ledger.save
    local buildCandidates = deps.ledger.buildCandidates
    local roomContext = deps.ledger.roomContext
    local scanCurrentRoom = deps.ledger.scanCurrentRoom
    local getPageCount = deps.ledger.getPageCount
    local getVirtualEdges = deps.ledger.getVirtualEdges
    local createRuntimeSession = deps.ledger.createRuntimeSession
    local getControlVariant = deps.gallery.getControlVariant
    local controlData = deps.gallery.controlData
    local playControlAnimation = deps.gallery.playControlAnimation
    local findControl = deps.gallery.findControl
    local removeOwnedControls = deps.gallery.removeOwnedControls
    local removeOwnedPedestals = deps.gallery.removeOwnedPedestals
    local spawnSelectionRoom = deps.gallery.spawnSelectionRoom
    local updateControlTouchLatches = deps.gallery.updateControlTouchLatches

    local function executeSpecialRoomCommand()
        if not Isaac or type(Isaac.ExecuteCommand) ~= "function" then return false end
        return pcall(function() Isaac.ExecuteCommand(SPECIAL_ROOM_COMMAND) end) == true
    end

    local function clearSession(runData, session)
        if runData and runData.session == session then runData.session = nil end
        state.pending = {}
        removeOwnedControls(session)
        state.transition = nil
        state.controlEntities = {}
        save()
    end

    local function restoreCertificateParent(session)
        local api = GetCertificateCarrier()
        if not session or not session.parentCertificateToken or not api or not api.RestoreCurrent then return false end
        return api.RestoreCurrent(session.parentCertificateToken) == true
    end

    local function finishInOrigin(runData, session)
        restorePlayerPositions(session)
        clearSession(runData, session)
        if session.parentCertificateToken then restoreCertificateParent(session) end
        return true
    end

    local function beginReturn(runData, session)
        if not session or session.returnStarted then return false end
        session.returnStarted = true
        removeOwnedPedestals(session)
        removeOwnedControls(session)
        state.transition = nil
        local context = roomContext()
        if context and tonumber(context.roomIndex) == tonumber(session.originRoomIndex)
            and tonumber(context.dimension) == tonumber(session.originDimension) then
            return finishInOrigin(runData, session)
        end
        session.phase = "returning"
        save()
        local game = currentGame()
        local player = findPlayer(session.initiatorKey)
        local ok, result = pcall(function()
            local targetRoom = tonumber(session.originSafeGridIndex) or session.originRoomIndex
            return game:StartRoomTransition(targetRoom, NO_DIRECTION, TELEPORT_ANIMATION,
                player, session.originDimension)
        end)
        if not ok or result == false then
            session.returnStarted = false
            local failedContext = roomContext()
            if failedContext and failedContext.roomIndex == SPECIAL_ROOM_INDEX then
                session.phase = "active"
                spawnSelectionRoom(session)
            else
                clearSession(runData, session)
                restoreCertificateParent(session)
            end
            DebugLog("[neverbirth][HouseVsElephant] failed to return to origin")
            return false
        end
        return true
    end

    local function beginPageChange(session, targetPage)
        if not session or state.transition or session.interactionLocked == true then return false end
        targetPage = math.floor(tonumber(targetPage) or 0)
        local edges = getVirtualEdges(session, session.pageIndex)
        if targetPage ~= edges.previous and targetPage ~= edges.next then return false end
        local role = targetPage == edges.previous and "previous" or "next"
        local control = findControl(session, role)
        local data = controlData(control)
        if not control or not data or data.NeverbirthHouseControlEnabled ~= true then return false end
        session.interactionLocked = true
        session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
        removeOwnedPedestals(session)
        state.transition = {
            mode = "page", token = session.token, targetPage = targetPage,
            readyFrame = state.frame + PAGE_PRESS_FRAMES,
        }
        playControlAnimation(control, "press")
        return true
    end

    local function beginControlReturn(session)
        if not session or state.transition or session.interactionLocked == true then return false end
        local control = findControl(session, "return")
        local data = controlData(control)
        if not control or not data or data.NeverbirthHouseControlEnabled ~= true then return false end
        session.interactionLocked = true
        session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
        removeOwnedPedestals(session)
        state.transition = {
            mode = "return", token = session.token,
            readyFrame = state.frame + RETURN_PRESS_FRAMES,
        }
        playControlAnimation(control, "press")
        return true
    end

    local function processControlTransition(runData, session)
        local transition = state.transition
        if type(transition) ~= "table" or state.frame < (tonumber(transition.readyFrame) or math.huge) then return false end
        if not session or session.token ~= transition.token then state.transition = nil; return false end
        if transition.mode == "return" then
            state.transition = nil
            removeOwnedControls(session)
            return beginReturn(runData, session)
        end
        if transition.mode ~= "page" then state.transition = nil; return false end
        session.pageIndex = math.max(1, math.min(getPageCount(session), math.floor(tonumber(transition.targetPage) or 1)))
        state.transition = nil
        return spawnSelectionRoom(session)
    end

    local function triggerControl(session, role)
        local control = findControl(session, role)
        local data = controlData(control)
        if not control or not data or data.NeverbirthHouseControlEnabled ~= true then return false end
        if role == "return" then return beginControlReturn(session) end
        local target = getVirtualEdges(session, session.pageIndex)[role]
        return target ~= nil and beginPageChange(session, target) or false
    end

    local function processControls(runData, session)
        if state.transition then processControlTransition(runData, session); return end
        if not session or session.phase ~= "active" then return end
        local touching = updateControlTouchLatches(session)
        if next(state.pending) ~= nil or session.interactionLocked == true
            or state.frame < (tonumber(session.controlArmedFrame) or 0)
            or state.frame < (tonumber(session.controlCooldownUntil) or 0) then return end
        for _, role in ipairs(CONTROL_TRIGGER_ORDER) do
            if touching[role] and session.controlTouchLatch[role] ~= true then
                session.controlTouchLatch[role] = true
                if triggerControl(session, role) then return end
            end
        end
    end

    local function noConsume(showAnimation)
        return { Discharge = false, Remove = false, ShowAnim = showAnimation == true }
    end

    local function consumeNow()
        return { Discharge = false, Remove = true, ShowAnim = true }
    end

    local function useItem(_, itemId, rng, player, useFlags, activeSlot, customVarData)
        if not lifetime.running then return { Discharge = false, Remove = false, ShowAnim = false } end
        if itemId ~= HOUSE then return nil end
        local runData = getPersistentData()
        if runData.session then return noConsume(false) end
        local context = roomContext()
        if not context or not player then return noConsume(false) end
        if not getControlVariant() then
            DebugLog("[neverbirth][HouseVsElephant] use refused: gallery control entity unresolved")
            return noConsume(false)
        end
        -- Include pedestals spawned this update, before their first update hook.
        scanCurrentRoom()
        local candidates = buildCandidates(runData.encounters, GetPlayers())
        local parentToken = nil
        if context.roomIndex == SPECIAL_ROOM_INDEX then
            local api = GetCertificateCarrier()
            if api and api.SuspendCurrent then parentToken = api.SuspendCurrent() end
            if not parentToken then
                DebugLog("[neverbirth][HouseVsElephant] use refused: special-room carrier has no supported owner")
                return noConsume(false)
            end
        end
        local _, session = createRuntimeSession(player, activeSlot, candidates, context, parentToken)
        if parentToken then
            if spawnSelectionRoom(session) then return consumeNow() end
        elseif executeSpecialRoomCommand() then
            return consumeNow()
        end
        runData.session = nil
        if parentToken then restoreCertificateParent(session) end
        save()
        DebugLog("[neverbirth][HouseVsElephant] failed to enter special room")
        return noConsume(false)
    end
    function callbackInstallers.useItem()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, useItem, HOUSE)
    end

    local function resumeInterruptedSession(stale)
        if type(stale) ~= "table" then return false end
        local context = roomContext()
        if not context or context.roomIndex ~= SPECIAL_ROOM_INDEX then return false end
        local game = currentGame()
        local player = findPlayer(stale.initiatorKey)
        local ok = pcall(function()
            removeOwnedPedestals(stale)
            local targetRoom = tonumber(stale.originSafeGridIndex) or stale.originRoomIndex
            removeOwnedControls(stale)
            game:StartRoomTransition(targetRoom, NO_DIRECTION, TELEPORT_ANIMATION,
                player, stale.originDimension)
        end)
        return ok
    end

    local function newRoom(_, fromGameStart)
        if not lifetime.running then return nil end
        -- Native NEW_ROOM runs before GAME_STARTED on the first frame.
        if not fromGameStart and select(1, call(currentGame(), "GetFrameCount")) == 0 then return nil end
        local runData = getPersistentData()
        local session = runData.session
        local context = roomContext()
        state.encounterContext = context
        if state.returningAfterContinue then
            local stale = state.returningAfterContinue
            state.returningAfterContinue = nil
            resumeInterruptedSession(stale)
            return nil
        end
        if not session then
            scanCurrentRoom()
            return nil
        end
        if session.phase == "returning" and context
            and tonumber(context.roomIndex) == tonumber(session.originRoomIndex)
            and tonumber(context.dimension) == tonumber(session.originDimension) then
            finishInOrigin(runData, session)
            return nil
        end
        if context and context.roomIndex == SPECIAL_ROOM_INDEX
            and (session.phase == "entering" or session.phase == "active") then
            spawnSelectionRoom(session)
            return nil
        end
        if session.phase == "active" then
            beginReturn(runData, session)
            return nil
        end
        return nil
    end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local CarrierAPI = {
        IsActive = function()
            if not lifetime.running then return false end
            local value = getPersistentData()
            return type(value.session) == "table"
        end,
    }

    return {
        clearSession = clearSession,
        beginReturn = beginReturn,
        processControls = processControls,
        useItem = useItem,
        newRoom = newRoom,
        CarrierAPI = CarrierAPI,
        Installers = callbackInstallers,
    }
end
