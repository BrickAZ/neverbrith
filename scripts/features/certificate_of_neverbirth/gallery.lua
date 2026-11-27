-- Owns the item pedestal and control policies.
return function(Neverbirth, deps)
    local GetPlayers = assert(deps.GetPlayers)
    local DebugLog = assert(deps.Log)
    local state = assert(deps.State)
    local Room = assert(deps.Room)
    local Controls = assert(deps.Controls)
    local PICKUP_ENTITY = deps.Config.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.Config.COLLECTIBLE_PICKUP
    local PORTAL_ENTITY = deps.Config.PORTAL_ENTITY
    local PORTAL_NAME = deps.Config.PORTAL_NAME
    local PORTAL_TRIGGER_RADIUS = deps.Config.PORTAL_TRIGGER_RADIUS
    local GALLERY_ROOM_INDEX = deps.Config.GALLERY_ROOM_INDEX
    local CONTROL_COOLDOWN_FRAMES = deps.Config.CONTROL_COOLDOWN_FRAMES
    local ARRIVAL_LOCKOUT_FRAMES = deps.Config.ARRIVAL_LOCKOUT_FRAMES
    local ROOM_EDGE_MARGIN = deps.Config.ROOM_EDGE_MARGIN
    local CONTROL_ROW_RESERVE = deps.Config.CONTROL_ROW_RESERVE
    local CONTROL_SUBTYPE = deps.Config.CONTROL_SUBTYPE
    local CONTROL_ROLES = deps.Config.CONTROL_ROLES
    local CONTROL_ANIMATIONS = deps.Config.CONTROL_ANIMATIONS
    local call = deps.Room.call
    local vectorXY = deps.Room.vectorXY
    local makeVector = deps.Room.makeVector
    local currentGame = deps.Room.currentGame
    local save = deps.ledger.save
    local rowsToIdText = deps.ledger.rowsToIdText
    local getPageCount = deps.ledger.getPageCount
    local getPageRows = deps.ledger.getPageRows
    local getVirtualEdges = deps.ledger.getVirtualEdges
    local assignPositions = deps.ledger.assignPositions

    local portalVariant = nil

    local function getPortalVariant()
        if portalVariant ~= nil then return portalVariant or nil end
        portalVariant = false
        if Isaac and type(Isaac.GetEntityVariantByName) == "function" then
            local ok, value = pcall(Isaac.GetEntityVariantByName, PORTAL_NAME)
            value = ok and tonumber(value) or nil
            if value and value > 0 then portalVariant = math.floor(value) end
        end
        return portalVariant or nil
    end

    local function entityIsActive(entity)
        if not entity then return false end
        if entity.Exists then
            local ok, exists = pcall(function() return entity:Exists() end)
            if ok then return exists == true end
        end
        return entity.Removed ~= true and entity.removed ~= true
    end

    local function portalData(entity)
        return entity and entity.GetData and entity:GetData() or nil
    end

    local function controlBucket(session, create)
        if not session then return nil end
        local bucket = state.controlEntities[session.token]
        if type(bucket) ~= "table" and create then
            bucket = {}
            state.controlEntities[session.token] = bucket
        end
        return bucket
    end

    local function removeGalleryPortals(session)
        if Isaac.GetRoomEntities then
            for _, entity in ipairs(Isaac.GetRoomEntities() or {}) do
                local data = portalData(entity)
                local owned = data and data.NeverbirthCertificateGalleryPortal == true
                local matches = not session or data.NeverbirthCertificateSessionToken == session.token
                if owned and matches and entity.Remove then pcall(function() entity:Remove() end) end
            end
        end
        if session then state.controlEntities[session.token] = nil else state.controlEntities = {} end
    end

    local function findPortal(session, role)
        if not session then return nil end
        local bucket = controlBucket(session, false)
        local cached = bucket and bucket[role] or nil
        if entityIsActive(cached) then return cached end
        if not Isaac.GetRoomEntities then return nil end
        for _, entity in ipairs(Isaac.GetRoomEntities() or {}) do
            local data = portalData(entity)
            if entityIsActive(entity) and entity.Type == PORTAL_ENTITY
                and data and data.NeverbirthCertificateGalleryPortal == true
                and data.NeverbirthCertificateSessionToken == session.token
                and data.NeverbirthCertificatePortalRole == role then
                controlBucket(session, true)[role] = entity
                return entity
            end
        end
        return nil
    end

    local function removeGalleryPedestals(session, removeUnknown)
        if not Isaac.GetRoomEntities then return end
        for _, entity in ipairs(Isaac.GetRoomEntities() or {}) do
            if entity and entity.Type == PICKUP_ENTITY and entity.Variant == COLLECTIBLE_PICKUP then
                local data = entity.GetData and entity:GetData() or nil
                local owned = data and data.NeverbirthCertificateSessionToken ~= nil
                local matches = not session or data.NeverbirthCertificateSessionToken == session.token
                if (owned and matches) or removeUnknown then pcall(function() entity:Remove() end) end
            end
        end
    end

    local function prepareGalleryRoom(room, descriptor)
        if descriptor then
            pcall(function() descriptor.NoReward = true end)
            pcall(function() descriptor.Clear = true end)
        end
        call(room, "SetClear", true)
    end

    local function roomSafeBounds(room)
        local bounds, reason = Room.safeBounds(room, ROOM_EDGE_MARGIN, CONTROL_ROW_RESERVE)
        if reason == "unavailable" then
            DebugLog("[neverbirth][Certificate] room bounds unavailable for gallery layout")
        elseif reason == "too_small" then
            DebugLog("[neverbirth][Certificate] room safe area too small for gallery controls")
        end
        return bounds
    end

    local function positionIsSafe(room, position, margin)
        local inside, checkedInside = call(room, "IsPositionInRoom", position, margin or 18)
        return not checkedInside or inside == true
    end

    local function makeGalleryPositions(room)
        local bounds = roomSafeBounds(room)
        if not bounds then return {} end
        return Room.gridPositions(room, bounds, 6, positionIsSafe)
    end

    local function choosePortalPosition(room, role)
        local bounds = roomSafeBounds(room)
        if not bounds then return nil end
        local position = Room.controlPosition(bounds, role)
        if positionIsSafe(room, position, 18) then return position end
        DebugLog("[neverbirth][Certificate] no legal position for control role=" .. tostring(role))
        return nil
    end

    local function controlEnabled(session, role)
        if role == "return" then return true end
        return getVirtualEdges(session, session and session.galleryPageIndex or 1)[role] ~= nil
    end

    local function playPortalAnimation(effect, mode)
        local data = portalData(effect)
        local role = data and data.NeverbirthCertificatePortalRole or nil
        local animations = role and CONTROL_ANIMATIONS[role] or nil
        local requested = animations and animations[mode] or nil
        if data then data.NeverbirthCertificateRequestedAnimation = requested end
        local ok, attempted = Controls.PlayAnimation(effect, requested, function(name)
            DebugLog("[neverbirth][Certificate] missing archive control animation=" .. tostring(name))
        end)
        if attempted and data then data.NeverbirthCertificatePlayedAnimation = ok and requested or nil end
        return ok
    end

    local function spawnPortal(room, session, role)
        local variant = getPortalVariant()
        local subtype = CONTROL_SUBTYPE[role]
        if not variant or subtype == nil then return nil end
        local position = choosePortalPosition(room, role)
        if not position then return nil end
        local ok, effect = pcall(function()
            return Isaac.Spawn(PORTAL_ENTITY, variant, subtype, position, makeVector(0, 0), nil)
        end)
        if not ok or not effect then
            DebugLog("[neverbirth][Certificate] failed to spawn control role=" .. tostring(role) .. ": " .. tostring(effect))
            return nil
        end
        local enabled = controlEnabled(session, role)
        local data = portalData(effect)
        if data then
            data.NeverbirthCertificateGalleryPortal = true
            data.NeverbirthCertificateSessionToken = session.token
            data.NeverbirthCertificatePortalRole = role
            data.NeverbirthCertificatePortalEnabled = enabled
            data.NeverbirthCertificateTargetPage = getVirtualEdges(session, session.galleryPageIndex)[role]
        end
        Controls.MakeHarmless(effect)
        controlBucket(session, true)[role] = effect
        playPortalAnimation(effect, enabled and "idle" or "disabled")
        local px, py = vectorXY(position)
        session.galleryPortalPositions[role] = { x = px, y = py }
        return effect
    end

    local function spawnGalleryPortals(room, session)
        removeGalleryPortals(session)
        session.galleryPortalPositions = {}
        session.controlTouchLatch = type(session.controlTouchLatch) == "table" and session.controlTouchLatch or {}
        session.portalArmedFrame = state.frame + ARRIVAL_LOCKOUT_FRAMES
        session.controlCooldownUntil = math.max(tonumber(session.controlCooldownUntil) or 0,
            state.frame + CONTROL_COOLDOWN_FRAMES)
        session.interactionLocked = false
        session.returnTriggered = false
        local allSpawned = true
        for _, role in ipairs(CONTROL_ROLES) do
            if not spawnPortal(room, session, role) then allSpawned = false end
        end
        if not allSpawned then
            DebugLog("[neverbirth][Certificate] one or more archive controls failed to spawn")
        end
        return allSpawned
    end

    local function logCapacityFailure(remaining, positions)
        local overflow = {}
        for index = #positions + 1, #remaining do overflow[#overflow + 1] = remaining[index] end
        DebugLog("[neverbirth][Certificate] gallery room capacity insufficient: required=" .. tostring(#remaining)
            .. " available=" .. tostring(#positions) .. " missingLocalIds=" .. rowsToIdText(overflow))
        return overflow
    end

    local function spawnGallery(session)
        local game = currentGame()
        local level = game and select(1, call(game, "GetLevel")) or nil
        local room = game and select(1, call(game, "GetRoom")) or nil
        local descriptor = level and select(1, call(level, "GetCurrentRoomDesc")) or nil
        local roomIndex = level and select(1, call(level, "GetCurrentRoomIndex")) or nil
        if not room or not level or not session or tonumber(roomIndex) ~= GALLERY_ROOM_INDEX then return false end
        session.galleryPageCount = getPageCount(session)
        session.galleryPageIndex = math.max(1,
            math.min(session.galleryPageCount, math.floor(tonumber(session.galleryPageIndex) or 1)))
        prepareGalleryRoom(room, descriptor)
        removeGalleryPedestals(session, false)
        removeGalleryPortals(session)
        local pageRows = getPageRows(session, session.galleryPageIndex)
        local positions = makeGalleryPositions(room)
        local assignments, overflow = assignPositions(pageRows, positions)
        if #overflow > 0 then
            logCapacityFailure(pageRows, positions)
            spawnGalleryPortals(room, session)
            session.phase = "capacity_failure"
            state.transition = nil
            save()
            return false
        end
        for _, assignment in ipairs(assignments) do
            local spawned = Isaac.Spawn(PICKUP_ENTITY, COLLECTIBLE_PICKUP, assignment.row.runtimeId,
                assignment.position, makeVector(0, 0), nil)
            if spawned then
                local data = spawned.GetData and spawned:GetData() or nil
                if data then
                    data.NeverbirthCertificateSessionToken = session.token
                    data.NeverbirthCertificateLocalId = assignment.row.localId
                end
            end
        end
        spawnGalleryPortals(room, session)
        session.phase = "active"
        state.transition = nil
        save()
        return true
    end

    local function portalEntered(session, role)
        if not session then return false end
        return Controls.AnyPlayerWithin(findPortal(session, role), PORTAL_TRIGGER_RADIUS, GetPlayers, vectorXY)
    end

    local function updateControlTouchLatches(session)
        return Controls.UpdateTouchLatches(session, CONTROL_ROLES, portalEntered)
    end

    return {
        getPortalVariant = getPortalVariant,
        portalData = portalData,
        removeGalleryPortals = removeGalleryPortals,
        findPortal = findPortal,
        removeGalleryPedestals = removeGalleryPedestals,
        controlEnabled = controlEnabled,
        playPortalAnimation = playPortalAnimation,
        spawnGallery = spawnGallery,
        updateControlTouchLatches = updateControlTouchLatches,
    }
end
