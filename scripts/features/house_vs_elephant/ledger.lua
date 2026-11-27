-- Owns the item ledger and candidate rules.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local Store = assert(deps.Store)
    local GetCurrentRunSeed = assert(deps.GetCurrentRunSeed)
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local Room = assert(deps.Room)
    local MILK = deps.Config.MILK
    local ACTIVE_ITEM_TYPE = deps.Config.ACTIVE_ITEM_TYPE
    local PICKUP_ENTITY = deps.Config.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.Config.COLLECTIBLE_PICKUP
    local SPECIAL_ROOM_INDEX = deps.Config.SPECIAL_ROOM_INDEX
    local ITEMS_PER_PAGE = deps.Config.ITEMS_PER_PAGE
    local call = deps.Room.call
    local playerKey = deps.Room.playerKey
    local currentGame = deps.Room.currentGame
    local currentDimension = deps.Room.currentDimension
    local capturePlayerPositions = deps.Room.capturePlayerPositions

    local function clearTransient()
        state.pending, state.controlEntities = {}, {}
        state.returningAfterContinue, state.transition, state.frame = nil, nil, 0
        state.encounterContext = nil
    end

    local function newRunData(runSeed)
        return { runSeed = tostring(runSeed or "unknown"), encounters = {}, seenKeys = {}, nextSequence = 1,
            nextSessionToken = 1, session = nil }
    end

    local function normalizeRunData(value, runSeed, clearSession)
        runSeed = tostring(runSeed or "unknown")
        if type(value) ~= "table" or tostring(value.runSeed or "") ~= runSeed then
            return newRunData(runSeed)
        end
        value.encounters = type(value.encounters) == "table" and value.encounters or {}
        value.seenKeys = type(value.seenKeys) == "table" and value.seenKeys or {}
        value.nextSequence = math.max(1, math.floor(tonumber(value.nextSequence) or (#value.encounters + 1)))
        value.nextSessionToken = math.max(1, math.floor(tonumber(value.nextSessionToken) or 1))
        if clearSession == true then value.session = nil end
        return value
    end

    local function getPersistentData()

        local value = normalizeRunData(Store.Get(), GetCurrentRunSeed(), false)
        Store.Replace(value)
        return value
    end

    local function save()
        Store.Save()
    end

    local function encounterKey(roomContext, pickup)
        if type(roomContext) ~= "table" or not pickup then return nil end
        local initSeed = tonumber(pickup.InitSeed)
        if not initSeed then return nil end
        return table.concat({
            tostring(tonumber(roomContext.stage) or 0),
            tostring(tonumber(roomContext.stageType) or 0),
            tostring(tonumber(roomContext.dimension) or 0),
            tostring(tonumber(roomContext.safeGridIndex) or 0),
            tostring(math.floor(initSeed)),
        }, ":")
    end

    local function recordEncounter(runData, roomContext, pickup)
        if type(runData) ~= "table" or not pickup
            or tonumber(pickup.Type) ~= PICKUP_ENTITY
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
            or (tonumber(pickup.SubType) or 0) <= 0 then return false end
        local entityData = pickup.GetData and pickup:GetData() or nil
        if entityData and (entityData.NeverbirthHouseSessionToken
            or entityData.NeverbirthCertificateSessionToken) then return false end
        runData.encounters = type(runData.encounters) == "table" and runData.encounters or {}
        runData.seenKeys = type(runData.seenKeys) == "table" and runData.seenKeys or {}
        local key = encounterKey(roomContext, pickup)
        if not key or runData.seenKeys[key] then return false end
        local sequence = math.max(1, math.floor(tonumber(runData.nextSequence) or (#runData.encounters + 1)))
        runData.nextSequence = sequence + 1
        runData.seenKeys[key] = true
        runData.encounters[#runData.encounters + 1] = {
            encounterKey = key, itemId = math.floor(tonumber(pickup.SubType)), sequence = sequence,
        }
        return true
    end

    local function buildCandidates(encounters, players, hasCollectible, isActiveItem)
        players = type(players) == "table" and players or {}
        hasCollectible = hasCollectible or function(player, itemId)
            return player and player.HasCollectible and player:HasCollectible(itemId)
        end
        isActiveItem = isActiveItem or function(itemId)
            if not Isaac or type(Isaac.GetItemConfig) ~= "function" then return false end
            local okConfig, config = pcall(Isaac.GetItemConfig)
            if not okConfig or not config or type(config.GetCollectible) ~= "function" then return false end
            local okItem, item = pcall(config.GetCollectible, config, itemId)
            return okItem and item ~= nil and tonumber(item.Type) == ACTIVE_ITEM_TYPE
        end
        local held = {}
        local active = {}
        for _, encounter in ipairs(encounters or {}) do
            local itemId = math.floor(tonumber(encounter.itemId) or 0)
            if itemId > 0 and active[itemId] == nil then
                local ok, value = pcall(isActiveItem, itemId)
                active[itemId] = ok and value == true
            end
            if itemId > 0 and held[itemId] == nil then
                held[itemId] = false
                for _, player in ipairs(players) do
                    local ok, value = pcall(hasCollectible, player, itemId)
                    if ok and value == true then held[itemId] = true; break end
                end
            end
        end
        local candidates = {}
        for index, encounter in ipairs(encounters or {}) do
            local itemId = math.floor(tonumber(encounter.itemId) or 0)
            if itemId > 0 and held[itemId] ~= true and active[itemId] ~= true then
                candidates[#candidates + 1] = {
                    itemId = itemId, encounterKey = tostring(encounter.encounterKey or index),
                    sourceSequence = tonumber(encounter.sequence) or index, isMilkFallback = false,
                }
            end
        end
        while #candidates < 3 do
            candidates[#candidates + 1] = {
                itemId = MILK, encounterKey = "milk-fallback:" .. tostring(#candidates + 1),
                sourceSequence = nil, isMilkFallback = true,
            }
        end
        return candidates
    end

    local function newSession(token, candidates)
        local copied = {}
        for index, candidate in ipairs(candidates or {}) do
            copied[index] = {
                itemId = math.floor(tonumber(candidate.itemId) or 0),
                encounterKey = tostring(candidate.encounterKey or index),
                sourceSequence = candidate.sourceSequence,
                isMilkFallback = candidate.isMilkFallback == true,
            }
        end
        return {
            token = tostring(token or ""), candidates = copied, selected = {}, selectedCount = 0,
            pageIndex = 1, pageCount = math.max(1, math.ceil(#copied / ITEMS_PER_PAGE)),
            controlTouchLatch = {}, interactionLocked = false, controlCooldownUntil = 0,
            phase = "created",
        }
    end

    local function markSelected(session, candidateIndex)
        if type(session) ~= "table" or session.phase == "completed" then return false end
        session.selected = type(session.selected) == "table" and session.selected or {}
        local key = tostring(math.floor(tonumber(candidateIndex) or 0))
        if key == "0" or session.selected[key] then return false end
        session.selected[key] = true
        session.selectedCount = math.max(0, math.floor(tonumber(session.selectedCount) or 0)) + 1
        if session.selectedCount >= 3 then session.phase = "completed"; return true end
        return false
    end

    local function roomContext()
        local game = currentGame()
        local level = game and select(1, call(game, "GetLevel")) or nil
        local descriptor = level and select(1, call(level, "GetCurrentRoomDesc")) or nil
        local roomIndex = level and select(1, call(level, "GetCurrentRoomIndex")) or nil
        if not level or roomIndex == nil then return nil end
        local stage = select(1, call(level, "GetStage"))
        local stageType = select(1, call(level, "GetStageType"))
        return {
            stage = tonumber(stage) or 0,
            stageType = tonumber(stageType) or 0,
            dimension = currentDimension(level, descriptor),
            safeGridIndex = tonumber(descriptor and (descriptor.SafeGridIndex or descriptor.GridIndex) or roomIndex) or roomIndex,
            roomIndex = tonumber(roomIndex),
        }
    end

    local function scanCurrentRoom()
        local context = roomContext()
        if not context or context.roomIndex == SPECIAL_ROOM_INDEX then return 0 end
        local runData = getPersistentData()
        local added = 0
        local entities = Isaac and Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}
        for _, entity in ipairs(entities) do
            if recordEncounter(runData, context, entity) then added = added + 1 end
        end
        if added > 0 then save() end
        return added
    end

    local function pickupUpdate(_, pickup)
        if not lifetime.running then return nil end
        if not pickup or tonumber(pickup.Type) ~= PICKUP_ENTITY
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
            or (tonumber(pickup.SubType) or 0) <= 0 then return nil end
        local context = state.encounterContext
        if not context or context.roomIndex == SPECIAL_ROOM_INDEX then return nil end
        local data = pickup.GetData and pickup:GetData() or nil
        if not data or data.NeverbirthHouseSessionToken or data.NeverbirthCertificateSessionToken
            or data.NeverbirthHouseEncounterContext == context then return nil end
        local runData = getPersistentData()
        if runData.session then return nil end
        -- POST_PICKUP_UPDATE also sees rewards/chest contents born after entry.
        -- Cache observation per room visit; persistent instance keys still own
        -- de-duplication across visits and continue. No per-frame room scan.
        if recordEncounter(runData, context, pickup) then save() end
        data.NeverbirthHouseEncounterContext = context
        return nil
    end
    function callbackInstallers.pickupUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, pickupUpdate, COLLECTIBLE_PICKUP)
    end

    local function getPageCount(session)
        return math.max(1, math.ceil(#(session and session.candidates or {}) / ITEMS_PER_PAGE))
    end

    local function getPageEntries(session, pageIndex)
        local result = {}
        if not session then return result end
        session.selected = type(session.selected) == "table" and session.selected or {}
        pageIndex = math.max(1, math.floor(tonumber(pageIndex) or 1))
        local first = (pageIndex - 1) * ITEMS_PER_PAGE + 1
        local last = math.min(#(session.candidates or {}), first + ITEMS_PER_PAGE - 1)
        for candidateIndex = first, last do
            local candidate = session.candidates[candidateIndex]
            if candidate and session.selected[tostring(candidateIndex)] ~= true then
                result[#result + 1] = { candidateIndex = candidateIndex, candidate = candidate }
            end
        end
        return result
    end

    local function getVirtualEdges(session, pageIndex)
        return Room.pageEdges(getPageCount(session), pageIndex)
    end

    local function createRuntimeSession(player, activeSlot, candidates, context, parentToken)
        local runData = getPersistentData()
        local token = tostring(runData.runSeed) .. ":house:" .. tostring(runData.nextSessionToken)
            .. ":" .. playerKey(player)
        runData.nextSessionToken = runData.nextSessionToken + 1
        local session = newSession(token, candidates)
        session.initiatorKey = playerKey(player)
        session.activeSlot = activeSlot
        session.originStage = context.stage
        session.originStageType = context.stageType
        session.originDimension = context.dimension
        session.originRoomIndex = context.roomIndex
        session.originSafeGridIndex = context.safeGridIndex
        session.originPlayerPositions = capturePlayerPositions()
        session.parentCertificateToken = parentToken
        session.phase = "entering"
        runData.session = session
        save()
        return runData, session
    end

    return {
        clearTransient = clearTransient,
        newRunData = newRunData,
        normalizeRunData = normalizeRunData,
        getPersistentData = getPersistentData,
        save = save,
        encounterKey = encounterKey,
        recordEncounter = recordEncounter,
        buildCandidates = buildCandidates,
        newSession = newSession,
        markSelected = markSelected,
        roomContext = roomContext,
        scanCurrentRoom = scanCurrentRoom,
        pickupUpdate = pickupUpdate,
        getPageCount = getPageCount,
        getPageEntries = getPageEntries,
        getVirtualEdges = getVirtualEdges,
        createRuntimeSession = createRuntimeSession,
        Installers = callbackInstallers,
    }
end
