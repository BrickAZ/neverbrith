-- Owns the item pedestal and control policies.
return function(Neverbirth, deps)
    local GetPlayers = assert(deps.GetPlayers)
    local DebugLog = assert(deps.Log)
    local state = assert(deps.State)
    local Room = assert(deps.Room)
    local Controls = assert(deps.Controls)
    local PICKUP_ENTITY = deps.Config.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.Config.COLLECTIBLE_PICKUP
    local SPECIAL_ROOM_INDEX = deps.Config.SPECIAL_ROOM_INDEX
    local PORTAL_ENTITY = deps.Config.PORTAL_ENTITY
    local PORTAL_NAME = deps.Config.PORTAL_NAME
    local ITEMS_PER_PAGE = deps.Config.ITEMS_PER_PAGE
    local CONTROL_TRIGGER_RADIUS = deps.Config.CONTROL_TRIGGER_RADIUS
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
    local getPageCount = deps.ledger.getPageCount
    local getPageEntries = deps.ledger.getPageEntries
    local getVirtualEdges = deps.ledger.getVirtualEdges

    local function roomSafeBounds(room)
        local bounds, reason = Room.safeBounds(room, ROOM_EDGE_MARGIN, CONTROL_ROW_RESERVE)
        return bounds
    end

    local function makePositions(room, count)
        local bounds = roomSafeBounds(room)
        if not bounds then return {} end
        count = math.min(ITEMS_PER_PAGE, math.max(0, math.floor(tonumber(count) or 0)))
        return Room.gridPositions(room, bounds, count)
    end

    local function chooseControlPosition(room, role)
        local bounds = roomSafeBounds(room)
        if not bounds then return nil end
        return Room.controlPosition(bounds, role)
    end

    local function getControlVariant()
        if not Isaac or type(Isaac.GetEntityVariantByName) ~= "function" then return nil end
        local ok, variant = pcall(Isaac.GetEntityVariantByName, PORTAL_NAME)
        variant = ok and tonumber(variant) or nil
        return variant and variant >= 0 and math.floor(variant) or nil
    end

    local function controlData(entity)
        return entity and entity.GetData and entity:GetData() or nil
    end

    local function playControlAnimation(effect, mode)
        local data = controlData(effect)
        local role = data and data.NeverbirthHouseControlRole or nil
        local requested = role and CONTROL_ANIMATIONS[role] and CONTROL_ANIMATIONS[role][mode] or nil
        local played = Controls.PlayAnimation(effect, requested)
        return played
    end

    local function controlEnabled(session, role)
        if role == "return" then return true end
        return getVirtualEdges(session, session and session.pageIndex or 1)[role] ~= nil
    end

    local function findControl(session, role)
        local control = state.controlEntities and state.controlEntities[role] or nil
        local data = controlData(control)
        if not control or not data or not session or data.NeverbirthHouseSessionToken ~= session.token then return nil end
        if control.Exists then
            local ok, exists = pcall(function() return control:Exists() end)
            if not ok or exists ~= true then return nil end
        end
        return control
    end

    local function removeOwnedControls(session)
        for _, entity in ipairs(Isaac and Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}) do
            local data = controlData(entity)
            if data and data.NeverbirthHouseGalleryControl == true
                and (not session or data.NeverbirthHouseSessionToken == session.token) and entity.Remove then
                entity:Remove()
            end
        end
        state.controlEntities = {}
    end

    local function spawnControl(room, session, role)
        local variant = getControlVariant()
        local subtype = CONTROL_SUBTYPE[role]
        local position = chooseControlPosition(room, role)
        if not variant or subtype == nil or not position then return nil end
        local effect = Isaac.Spawn(PORTAL_ENTITY, variant, subtype, position, makeVector(0, 0), nil)
        if not effect then return nil end
        local enabled = controlEnabled(session, role)
        local data = controlData(effect)
        if data then
            data.NeverbirthHouseGalleryControl = true
            data.NeverbirthHouseSessionToken = session.token
            data.NeverbirthHouseControlRole = role
            data.NeverbirthHouseControlEnabled = enabled
        end
        Controls.MakeHarmless(effect)
        state.controlEntities[role] = effect
        playControlAnimation(effect, enabled and "idle" or "disabled")
        return effect
    end

    local function spawnControls(room, session)
        removeOwnedControls(session)
        session.controlTouchLatch = {}
        session.controlArmedFrame = state.frame + ARRIVAL_LOCKOUT_FRAMES
        session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
        session.interactionLocked = false
        local allSpawned = true
        for _, role in ipairs(CONTROL_ROLES) do
            if not spawnControl(room, session, role) then allSpawned = false end
        end
        return allSpawned
    end

    local function removeOwnedPedestals(session)
        local entities = Isaac and Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}
        for _, entity in ipairs(entities) do
            if tonumber(entity.Type) == PICKUP_ENTITY and tonumber(entity.Variant) == COLLECTIBLE_PICKUP then
                local data = entity.GetData and entity:GetData() or nil
                local owned = data and session and data.NeverbirthHouseSessionToken == session.token
                if owned and entity.Remove then entity:Remove() end
            end
        end
    end

    local function adoptSessionSpawnedPedestals(session)
        if not session then return end
        session.preexistingPickupSeeds = type(session.preexistingPickupSeeds) == "table"
            and session.preexistingPickupSeeds or {}
        for _, entity in ipairs(Isaac and Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}) do
            if tonumber(entity.Type) == PICKUP_ENTITY and tonumber(entity.Variant) == COLLECTIBLE_PICKUP then
                local data = entity.GetData and entity:GetData() or nil
                local seedKey = tostring(entity.InitSeed or "")
                if data and not data.NeverbirthHouseSessionToken
                    and not data.NeverbirthCertificateSessionToken
                    and not session.preexistingPickupSeeds[seedKey] then
                    data.NeverbirthHouseSessionToken = session.token
                    data.NeverbirthHouseSessionExtra = true
                end
            end
        end
    end

    local function prepareRoom(room)
        if room and room.SetClear then pcall(function() room:SetClear(true) end) end
    end

    local function spawnSelectionRoom(session)
        local game = currentGame()
        local level = game and select(1, call(game, "GetLevel")) or nil
        local room = game and select(1, call(game, "GetRoom")) or nil
        local index = level and select(1, call(level, "GetCurrentRoomIndex")) or nil
        if not session or not room or tonumber(index) ~= SPECIAL_ROOM_INDEX then return false end
        removeOwnedPedestals(session)
        removeOwnedControls(session)
        prepareRoom(room)
        session.pageCount = getPageCount(session)
        session.pageIndex = math.max(1, math.min(session.pageCount, math.floor(tonumber(session.pageIndex) or 1)))
        session.preexistingPickupSeeds = {}
        for _, entity in ipairs(Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}) do
            if tonumber(entity.Type) == PICKUP_ENTITY and tonumber(entity.Variant) == COLLECTIBLE_PICKUP then
                session.preexistingPickupSeeds[tostring(entity.InitSeed or "")] = true
            end
        end
        local entries = getPageEntries(session, session.pageIndex)
        local positions = makePositions(room, #entries)
        if #positions < #entries then
            DebugLog("[neverbirth][HouseVsElephant] selection room capacity insufficient page=" .. tostring(session.pageIndex))
            return false
        end
        for slot, entry in ipairs(entries) do
            local candidateIndex, candidate = entry.candidateIndex, entry.candidate
            local entity = Isaac.Spawn(PICKUP_ENTITY, COLLECTIBLE_PICKUP, candidate.itemId,
                positions[slot], makeVector(0, 0), nil)
            local data = entity and entity.GetData and entity:GetData() or nil
            if data then
                data.NeverbirthHouseSessionToken = session.token
                data.NeverbirthHouseCandidateIndex = candidateIndex
                data.NeverbirthHouseMilkFallback = candidate.isMilkFallback == true
            end
        end
        spawnControls(room, session)
        session.phase = "active"
        state.pending = {}
        state.transition = nil
        save()
        return true
    end

    local function controlEntered(session, role)
        return Controls.AnyPlayerWithin(findControl(session, role), CONTROL_TRIGGER_RADIUS, GetPlayers, vectorXY)
    end

    local function updateControlTouchLatches(session)
        return Controls.UpdateTouchLatches(session, CONTROL_ROLES, controlEntered)
    end

    return {
        makePositions = makePositions,
        getControlVariant = getControlVariant,
        controlData = controlData,
        playControlAnimation = playControlAnimation,
        findControl = findControl,
        removeOwnedControls = removeOwnedControls,
        removeOwnedPedestals = removeOwnedPedestals,
        adoptSessionSpawnedPedestals = adoptSessionSpawnedPedestals,
        spawnSelectionRoom = spawnSelectionRoom,
        updateControlTouchLatches = updateControlTouchLatches,
    }
end
