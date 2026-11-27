-- Owns the item ledger and candidate rules.
return function(Neverbirth, deps)
    local Store = assert(deps.Store)
    local GetCurrentRunSeed = assert(deps.GetCurrentRunSeed)
    local DebugLog = assert(deps.Log)
    local state = assert(deps.State)
    local Room = assert(deps.Room)
    local ITEMS_PER_PAGE = deps.Config.ITEMS_PER_PAGE
    local vectorXY = deps.Room.vectorXY
    local makeVector = deps.Room.makeVector
    local playerKey = deps.Room.playerKey
    local capturePlayerPositions = deps.Room.capturePlayerPositions

    local generatedRows = {}
    local generatedOk, generatedResult = pcall(function()
        return include("generated.neverbirth_collectibles")
    end)
    if generatedOk and type(generatedResult) == "table" then
        generatedRows = generatedResult
    else
        DebugLog("[neverbirth][Certificate] generated registry unavailable: " .. tostring(generatedResult))
    end

    local function clearTransient()
        state.pendingPickups, state.controlEntities = {}, {}
        state.transition, state.frame = nil, 0
        state.nextTransientToken = 1
    end

    local function getPersistentData()

        local runSeed = GetCurrentRunSeed()
        local value = Store.Get()
        if type(value) ~= "table" or value.runSeed ~= runSeed then
            value = { runSeed = runSeed, nextToken = 1, stack = {} }
            Store.Replace(value)
        end
        if type(value.stack) ~= "table" then value.stack = {} end
        value.nextToken = math.max(1, math.floor(tonumber(value.nextToken) or 1))

        return value
    end

    local function save()
        Store.Save()
    end

    local function resolveRegistry(resolver)
        local resolved, missing, seen = {}, {}, {}
        resolver = resolver or function(name) return Isaac.GetItemIdByName(name) end
        for _, row in ipairs(generatedRows) do
            local runtimeId = nil
            local names = type(row.names) == "table" and row.names or { row.englishName }
            for _, name in ipairs(names) do
                local ok, value = pcall(resolver, name)
                value = ok and tonumber(value) or nil
                if value and value > 0 then runtimeId = math.floor(value); break end
            end
            if runtimeId and not seen[runtimeId] then
                seen[runtimeId] = true
                resolved[#resolved + 1] = {
                    localId = math.floor(tonumber(row.localId) or 0),
                    englishName = tostring(row.englishName or ""), runtimeId = runtimeId,
                }
            else
                missing[#missing + 1] = {
                    localId = math.floor(tonumber(row.localId) or 0),
                    englishName = tostring(row.englishName or ""), runtimeId = runtimeId,
                    reason = runtimeId and "duplicate runtime ID" or "unresolved name",
                }
            end
        end
        table.sort(resolved, function(a, b) return a.localId < b.localId end)
        table.sort(missing, function(a, b) return a.localId < b.localId end)
        return resolved, missing
    end

    local function rowsToIdText(rows)
        local ids = {}
        for _, row in ipairs(rows or {}) do ids[#ids + 1] = tostring(row.localId) end
        return table.concat(ids, ",")
    end

    local function refreshRegistry()
        state.registry, state.missing = resolveRegistry()
        DebugLog("[neverbirth][Certificate] scan source=content/items.xml count=" .. tostring(#state.registry)
            .. " localIds=" .. rowsToIdText(state.registry))
        if #state.missing > 0 then
            DebugLog("[neverbirth][Certificate] unresolved local IDs=" .. rowsToIdText(state.missing))
        end
        return #state.missing == 0 and #state.registry == #generatedRows
    end

    local function copyRows(rows)
        local result = {}
        for _, row in ipairs(rows or {}) do
            result[#result + 1] = { localId = row.localId, englishName = row.englishName, runtimeId = row.runtimeId }
        end
        return result
    end

    local function newSession(initiatorKey, originRoomIndex, originDimension, originPosition, rows)
        local token = "transient:" .. tostring(state.nextTransientToken)
        state.nextTransientToken = state.nextTransientToken + 1
        local x, y = vectorXY(originPosition)
        return {
            token = token, initiatorKey = tostring(initiatorKey or ""),
            originRoomIndex = tonumber(originRoomIndex) or 0, originDimension = tonumber(originDimension) or 0,
            originPlayerPositions = { { key = tostring(initiatorKey or ""), x = x, y = y } },
            rows = copyRows(rows), collected = {}, galleryPageIndex = 1,
            galleryPageCount = math.max(1, math.ceil(#(rows or {}) / ITEMS_PER_PAGE)),
            galleryPortalPositions = {}, controlTouchLatch = {}, interactionLocked = false,
            controlCooldownUntil = 0, selected = false, phase = "created",
        }
    end

    local function getRemainingRows(session)
        local result = {}
        if not session then return result end
        session.collected = type(session.collected) == "table" and session.collected or {}
        for _, row in ipairs(session.rows or state.registry) do
            if session.collected[tostring(row.localId)] ~= true then result[#result + 1] = row end
        end
        table.sort(result, function(a, b) return a.localId < b.localId end)
        return result
    end

    local function getPageCount(session)
        local rows = session and session.rows or state.registry
        return math.max(1, math.ceil(#(rows or {}) / ITEMS_PER_PAGE))
    end

    local function getPageRows(session, pageIndex)
        local result = {}
        if not session then return result end
        local rows = session.rows or state.registry
        session.collected = type(session.collected) == "table" and session.collected or {}
        pageIndex = math.max(1, math.floor(tonumber(pageIndex) or 1))
        local first = (pageIndex - 1) * ITEMS_PER_PAGE + 1
        local last = math.min(#rows, first + ITEMS_PER_PAGE - 1)
        for index = first, last do
            local row = rows[index]
            if row then result[#result + 1] = row end
        end
        return result
    end

    local function getVirtualEdges(session, pageIndex)
        return Room.pageEdges(getPageCount(session), pageIndex)
    end

    local function markCollected(session, runtimeId)
        if not session then return false end
        session.collected = type(session.collected) == "table" and session.collected or {}
        runtimeId = tonumber(runtimeId)
        for _, row in ipairs(session.rows or state.registry) do
            if row.runtimeId == runtimeId then
                local key = tostring(row.localId)
                if session.collected[key] then return false end
                session.collected[key] = true
                return true
            end
        end
        return false
    end

    local function makeTestPositions(count)
        local result = {}
        for index = 1, math.max(0, math.floor(tonumber(count) or 0)) do result[index] = makeVector(index, index) end
        return result
    end

    local function assignPositions(rows, positions)
        rows, positions = rows or {}, positions or {}
        if #positions < #rows then
            local overflow = {}
            for index = #positions + 1, #rows do overflow[#overflow + 1] = rows[index] end
            return {}, overflow
        end
        local assignments = {}
        for index, row in ipairs(rows) do assignments[index] = { row = row, position = positions[index] } end
        return assignments, {}
    end

    local function createRuntimeSession(player, originRoomIndex, originDimension)
        local persistent = getPersistentData()
        local token = tostring(persistent.runSeed) .. ":" .. tostring(persistent.nextToken)
        persistent.nextToken = persistent.nextToken + 1
        local position = player and player.Position or makeVector(0, 0)
        local session = newSession(playerKey(player), originRoomIndex, originDimension, position, state.registry)
        session.token = token
        session.seed = player and player.InitSeed or persistent.nextToken
        session.originPlayerPositions = capturePlayerPositions()
        session.phase = "entering"
        persistent.stack[#persistent.stack + 1] = session
        return session
    end

    return {
        clearTransient = clearTransient,
        getPersistentData = getPersistentData,
        save = save,
        resolveRegistry = resolveRegistry,
        rowsToIdText = rowsToIdText,
        refreshRegistry = refreshRegistry,
        newSession = newSession,
        getRemainingRows = getRemainingRows,
        getPageCount = getPageCount,
        getPageRows = getPageRows,
        getVirtualEdges = getVirtualEdges,
        markCollected = markCollected,
        makeTestPositions = makeTestPositions,
        assignPositions = assignPositions,
        createRuntimeSession = createRuntimeSession,
        generatedRows = generatedRows,
    }
end
