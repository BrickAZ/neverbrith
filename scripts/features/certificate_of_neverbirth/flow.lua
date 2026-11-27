-- Owns entering, paging, returning and room lifecycle.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local DebugLog = assert(deps.Log)
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local GetHouseCarrier = assert(deps.GetHouseCarrier)
    local CERTIFICATE = deps.Config.CERTIFICATE
    local GALLERY_ROOM_INDEX = deps.Config.GALLERY_ROOM_INDEX
    local GALLERY_ROOM_COMMAND = deps.Config.GALLERY_ROOM_COMMAND
    local PAGE_PRESS_FRAMES = deps.Config.PAGE_PRESS_FRAMES
    local RETURN_PRESS_FRAMES = deps.Config.RETURN_PRESS_FRAMES
    local CONTROL_COOLDOWN_FRAMES = deps.Config.CONTROL_COOLDOWN_FRAMES
    local TELEPORT_ANIMATION = deps.Config.TELEPORT_ANIMATION
    local NO_DIRECTION = deps.Config.NO_DIRECTION
    local call = deps.Room.call
    local currentGame = deps.Room.currentGame
    local currentDimension = deps.Room.currentDimension
    local findPlayer = deps.Room.findPlayer
    local restorePlayerPositions = deps.Room.restorePlayerPositions
    local getPersistentData = deps.ledger.getPersistentData
    local save = deps.ledger.save
    local rowsToIdText = deps.ledger.rowsToIdText
    local refreshRegistry = deps.ledger.refreshRegistry
    local getVirtualEdges = deps.ledger.getVirtualEdges
    local createRuntimeSession = deps.ledger.createRuntimeSession
    local getPortalVariant = deps.gallery.getPortalVariant
    local portalData = deps.gallery.portalData
    local removeGalleryPortals = deps.gallery.removeGalleryPortals
    local findPortal = deps.gallery.findPortal
    local removeGalleryPedestals = deps.gallery.removeGalleryPedestals
    local playPortalAnimation = deps.gallery.playPortalAnimation
    local spawnGallery = deps.gallery.spawnGallery
    local generatedRows = deps.ledger.generatedRows

    local function executeGalleryCommand()
        if not Isaac or type(Isaac.ExecuteCommand) ~= "function" then return false end
        return pcall(function() Isaac.ExecuteCommand(GALLERY_ROOM_COMMAND) end) == true
    end

    local function noConsume(showAnimation)
        return { Discharge = false, Remove = false, ShowAnim = showAnimation == true }
    end

    local function committedUse(showAnimation)
        return { Discharge = false, Remove = false, ShowAnim = showAnimation == true }
    end

    local function useItem(_, itemId, rng, player, useFlags, activeSlot, customVarData)
        if not lifetime.running then return noConsume(false) end
        if itemId ~= CERTIFICATE then return nil end
        local externalOwner = GetHouseCarrier()
        if externalOwner and externalOwner.IsActive and externalOwner.IsActive() then return noConsume(false) end
        if state.transition then return noConsume(false) end
        if #state.registry == 0 then refreshRegistry() end
        if #state.missing > 0 or #state.registry ~= #generatedRows then
            DebugLog("[neverbirth][Certificate] use refused: registry unresolved local IDs=" .. rowsToIdText(state.missing))
            return noConsume(false)
        end
        if not getPortalVariant() then
            DebugLog("[neverbirth][Certificate] use refused: gallery mechanism entity unresolved")
            return noConsume(false)
        end
        local game = currentGame()
        local level = game and select(1, call(game, "GetLevel")) or nil
        local room = game and select(1, call(game, "GetRoom")) or nil
        local descriptor = level and select(1, call(level, "GetCurrentRoomDesc")) or nil
        local roomIndex = level and select(1, call(level, "GetCurrentRoomIndex")) or nil
        if not game or not level or not room or roomIndex == nil or not player then
            DebugLog("[neverbirth][Certificate] use refused: current room or player unavailable")
            return noConsume(false)
        end
        local originDimension = currentDimension(level, descriptor)
        local persistent = getPersistentData()
        local parent = persistent.stack[#persistent.stack]
        local nested = parent and tonumber(roomIndex) == GALLERY_ROOM_INDEX
            and (parent.phase == "active" or parent.phase == "capacity_failure")
        if nested then
            removeGalleryPedestals(parent, false)
            removeGalleryPortals(parent)
        end
        local session = createRuntimeSession(player, roomIndex, originDimension)
        state.transition = { mode = "enter", token = session.token }
        save()
        if nested then
            state.transition = nil
            if spawnGallery(session) then return committedUse(true) end
        elseif executeGalleryCommand() then
            return committedUse(true)
        end
        do
            if persistent.stack[#persistent.stack] == session then table.remove(persistent.stack, #persistent.stack) end
            state.transition = nil
            save()
            DebugLog("[neverbirth][Certificate] failed to enter virtual gallery carrier")
        end
        return noConsume(false)
    end
    function callbackInstallers.useItem()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, useItem, CERTIFICATE)
    end

    local function finishReturnInCurrentRoom(session)
        local persistent = getPersistentData()
        if persistent.stack[#persistent.stack] == session then table.remove(persistent.stack, #persistent.stack) end
        restorePlayerPositions(session)
        state.transition = nil
        state.pendingPickups = {}
        local previous = persistent.stack[#persistent.stack]
        if previous then spawnGallery(previous) else removeGalleryPortals(session) end
        save()
        return true
    end

    local function beginReturn(session)
        if not session or state.transition or session.returnTriggered == true then return false end
        session.returnTriggered = true
        local game = currentGame()
        local level = game and select(1, call(game, "GetLevel")) or nil
        local descriptor = level and select(1, call(level, "GetCurrentRoomDesc")) or nil
        local roomIndex = level and select(1, call(level, "GetCurrentRoomIndex")) or nil
        local dimension = level and currentDimension(level, descriptor) or 0
        removeGalleryPedestals(session, false)
        removeGalleryPortals(session)
        if tonumber(roomIndex) == tonumber(session.originRoomIndex)
            and tonumber(dimension) == tonumber(session.originDimension) then
            return finishReturnInCurrentRoom(session)
        end
        session.phase = "returning"
        state.transition = { mode = "return", token = session.token }
        save()
        local player = findPlayer(session.initiatorKey)
        local called, result = pcall(function()
            return game:StartRoomTransition(session.originRoomIndex, NO_DIRECTION, TELEPORT_ANIMATION,
                player, session.originDimension)
        end)
        if not called or result == false then
            state.transition = nil
            session.phase = "active"
            session.returnTriggered = false
            spawnGallery(session)
            DebugLog("[neverbirth][Certificate] failed to return to origin room")
            return false
        end
        return true
    end

    local function beginVirtualRoomChange(session, targetPage)
        if not session or state.transition or session.interactionLocked == true then return false end
        targetPage = math.floor(tonumber(targetPage) or 0)
        local edges = getVirtualEdges(session, session.galleryPageIndex)
        if targetPage ~= edges.previous and targetPage ~= edges.next then return false end
        local role = targetPage == edges.previous and "previous" or "next"
        local control = findPortal(session, role)
        local data = portalData(control)
        if not control or not data or data.NeverbirthCertificatePortalEnabled ~= true then return false end
        session.interactionLocked = true
        session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
        removeGalleryPedestals(session, false)
        state.transition = {
            mode = "virtual", phase = "pressing", token = session.token, targetPage = targetPage,
            previousPage = session.galleryPageIndex, controlRole = role,
            readyFrame = state.frame + PAGE_PRESS_FRAMES,
        }
        playPortalAnimation(control, "press")
        return true
    end

    local function beginControlReturn(session)
        if not session or state.transition or session.interactionLocked == true then return false end
        local control = findPortal(session, "return")
        local data = portalData(control)
        if not control or not data or data.NeverbirthCertificatePortalEnabled ~= true then return false end
        session.interactionLocked = true
        session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
        removeGalleryPedestals(session, false)
        state.transition = {
            mode = "control_return", phase = "pressing", token = session.token,
            controlRole = "return", readyFrame = state.frame + RETURN_PRESS_FRAMES,
        }
        playPortalAnimation(control, "press")
        return true
    end

    local function processVirtualTransition()
        local transition = state.transition
        if type(transition) ~= "table"
            or (transition.mode ~= "virtual" and transition.mode ~= "control_return")
            or state.frame < (tonumber(transition.readyFrame) or math.huge) then return false end
        local persistent = getPersistentData()
        local session = persistent.stack[#persistent.stack]
        if not session or session.token ~= transition.token then
            state.transition = nil
            return false
        end
        if transition.mode == "control_return" then
            state.transition = nil
            removeGalleryPortals(session)
            return beginReturn(session)
        end
        if transition.phase ~= "pressing" then
            state.transition = nil
            session.interactionLocked = false
            return false
        end
        removeGalleryPedestals(session, false)
        removeGalleryPortals(session)
        session.galleryPageIndex = transition.targetPage
        state.transition = nil
        local spawned = spawnGallery(session)
        if spawned then save() end
        return spawned
    end

    local function abortSession(persistent, session, roomIndex)
        DebugLog("[neverbirth][Certificate] independent gallery session aborted token="
            .. tostring(session and session.token) .. " room=" .. tostring(roomIndex))
        if persistent.stack[#persistent.stack] == session then table.remove(persistent.stack, #persistent.stack) end
        state.transition = nil
        state.pendingPickups = {}
        removeGalleryPedestals(session, false)
        removeGalleryPortals(session)
        save()
    end

    local function newRoom(_, fromGameStart)
        if not lifetime.running then return nil end
        local game = currentGame()
        -- The first NEW_ROOM precedes GAME_STARTED. Wait for its new/Continue decision.
        if not fromGameStart and select(1, call(game, "GetFrameCount")) == 0 then return nil end
        state.controlEntities = {}
        local externalOwner = GetHouseCarrier()
        if externalOwner and externalOwner.IsActive and externalOwner.IsActive() then return nil end
        local level = game and select(1, call(game, "GetLevel")) or nil
        local room = game and select(1, call(game, "GetRoom")) or nil
        local descriptor = level and select(1, call(level, "GetCurrentRoomDesc")) or nil
        local roomIndex = level and select(1, call(level, "GetCurrentRoomIndex")) or nil
        local dimension = level and currentDimension(level, descriptor) or 0
        local persistent = getPersistentData()
        local session = persistent.stack[#persistent.stack]
        if not session or roomIndex == nil then
            if not session then
                removeGalleryPedestals(nil, false)
                removeGalleryPortals(nil)
            end
            return nil
        end
        if session.phase == "returning" and tonumber(roomIndex) == tonumber(session.originRoomIndex)
            and tonumber(dimension) == tonumber(session.originDimension) then
            finishReturnInCurrentRoom(session)
            return nil
        end
        if tonumber(roomIndex) == GALLERY_ROOM_INDEX
            and (session.phase == "entering" or session.phase == "active"
                or session.phase == "capacity_failure") then
            state.transition = nil
            spawnGallery(session)
            return nil
        end
        if session.phase == "active" or session.phase == "capacity_failure" then
            state.transition = nil
            beginReturn(session)
            return nil
        end
        abortSession(persistent, session, roomIndex)
        return nil
    end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function triggerControl(session, role)
        local control = findPortal(session, role)
        local data = portalData(control)
        if not control or not data or data.NeverbirthCertificatePortalEnabled ~= true then return false end
        if role == "return" then return beginControlReturn(session) end
        local target = getVirtualEdges(session, session.galleryPageIndex)[role]
        return target ~= nil and beginVirtualRoomChange(session, target) or false
    end

    local CarrierAPI = {
        SuspendCurrent = function()
            if not lifetime.running then return nil end
            local persistent = getPersistentData()
            local session = persistent.stack[#persistent.stack]
            if not session or (session.phase ~= "active" and session.phase ~= "capacity_failure") then return nil end
            removeGalleryPedestals(session, false)
            removeGalleryPortals(session)
            return session.token
        end,
        RestoreCurrent = function(token)
            if not lifetime.running then return false end
            local persistent = getPersistentData()
            local session = persistent.stack[#persistent.stack]
            if not session or session.token ~= token then return false end
            return spawnGallery(session)
        end,
        IsCurrent = function(token)
            if not lifetime.running then return false end
            local persistent = getPersistentData()
            local session = persistent.stack[#persistent.stack]
            return session ~= nil and (token == nil or session.token == token)
        end,
    }

    return {
        useItem = useItem,
        processVirtualTransition = processVirtualTransition,
        newRoom = newRoom,
        triggerControl = triggerControl,
        CarrierAPI = CarrierAPI,
        Installers = callbackInstallers,
    }
end
