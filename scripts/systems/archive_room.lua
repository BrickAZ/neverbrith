-- Shared geometry and world facts for the two archive-room consumers.
-- No callbacks, session ownership or save operations. See docs/api/archive-rooms.md.
local Archive = {}

-- Archive callers historically reject callable tables and false results;
-- world_queries.TryGame has a different optional-query contract.
function Archive.CurrentGame()
    if type(Game) ~= "function" then return nil end
    local ok, game = pcall(Game)
    return ok and game or nil
end

-- Method invocation: first result plus success; a successful false/nil is retained.
function Archive.Call(object, method, ...)
    if not object or type(object[method]) ~= "function" then return nil, false end
    local ok, value = pcall(object[method], object, ...)
    if not ok then return nil, false end
    return value, true
end

function Archive.VectorXY(value)
    if not value then return 0, 0 end
    return tonumber(value.X or value.x) or 0, tonumber(value.Y or value.y) or 0
end

function Archive.CurrentDimension(level, descriptor)
    if not level or not descriptor then return 0 end
    local currentIndex = select(1, Archive.Call(level, "GetCurrentRoomIndex"))
    if type(GetPtrHash) == "function" then
        local descriptorIndex = tonumber(descriptor.SafeGridIndex or descriptor.GridIndex or currentIndex)
        if descriptorIndex then
            for dimension = 0, 2 do
                local candidate = select(1, Archive.Call(level, "GetRoomByIdx", descriptorIndex, dimension))
                local okLeft, left = pcall(GetPtrHash, descriptor)
                local okRight, right = pcall(GetPtrHash, candidate)
                if okLeft and okRight and candidate and left == right then return dimension end
            end
        end
    end
    return 0
end

function Archive.PageEdges(count, pageIndex)
    pageIndex = math.max(1, math.min(count, math.floor(tonumber(pageIndex) or 1)))
    return {
        previous = pageIndex > 1 and pageIndex - 1 or nil,
        next = pageIndex < count and pageIndex + 1 or nil,
    }
end

-- Returns bounds or nil plus "unavailable" / "too_small". Does not log.
function Archive.SafeBounds(room, edgeMargin, controlReserve)
    local topLeft, hasTopLeft = Archive.Call(room, "GetTopLeftPos")
    local bottomRight, hasBottomRight = Archive.Call(room, "GetBottomRightPos")
    if not hasTopLeft or not hasBottomRight or not topLeft or not bottomRight then
        return nil, "unavailable"
    end
    local left, top = Archive.VectorXY(topLeft)
    local right, bottom = Archive.VectorXY(bottomRight)
    left, right = left + edgeMargin, right - edgeMargin
    top, bottom = top + edgeMargin, bottom - edgeMargin
    if right <= left or bottom <= top + controlReserve then return nil, "too_small" end
    return { left = left, right = right, top = top, bottom = bottom,
        galleryBottom = bottom - controlReserve }
end

-- Each feature owns its dependency-bound instance. It retains no world objects.
function Archive.Create(getPlayers, vectorErrorPrefix)
    local function makeVector(x, y)
        local ok, value = pcall(function() return Vector(x, y) end)
        if ok and value ~= nil then return value end
        error(vectorErrorPrefix .. " Vector constructor unavailable: " .. tostring(value), 2)
    end
    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end
    local function findPlayer(key)
        for _, player in ipairs(getPlayers()) do
            if playerKey(player) == tostring(key or "") then return player end
        end
        return nil
    end
    local function capturePlayerPositions()
        local result = {}
        for _, player in ipairs(getPlayers()) do
            local x, y = Archive.VectorXY(player and player.Position)
            result[#result + 1] = { key = playerKey(player), x = x, y = y }
        end
        return result
    end
    local function restorePlayerPositions(session)
        for _, entry in ipairs(session and session.originPlayerPositions or {}) do
            local player = findPlayer(entry.key)
            if player then player.Position = makeVector(tonumber(entry.x) or 0, tonumber(entry.y) or 0) end
        end
    end
    -- The caller chooses count and optional legality filtering. Rejected slots
    -- compact in the result, as Certificate's previous row/column loop did.
    local function gridPositions(room, bounds, count, accepts)
        local result = {}
        local width = bounds.right - bounds.left
        local height = bounds.galleryBottom - bounds.top
        for index = 1, count do
            local column = (index - 1) % 3
            local row = math.floor((index - 1) / 3)
            local position = makeVector(bounds.left + (column + 0.5) * width / 3,
                bounds.top + (row + 0.5) * height / 2)
            if not accepts or accepts(room, position, 18) then result[#result + 1] = position end
        end
        return result
    end
    local function controlPosition(bounds, role)
        local centerX = (bounds.left + bounds.right) / 2
        local gap = math.max(48, math.min(112, (bounds.right - bounds.left) / 4))
        local x = centerX
        if role == "previous" then x = centerX - gap elseif role == "next" then x = centerX + gap end
        return makeVector(x, bounds.bottom)
    end
    return {
        call = Archive.Call, vectorXY = Archive.VectorXY, currentGame = Archive.CurrentGame,
        currentDimension = Archive.CurrentDimension, makeVector = makeVector,
        playerKey = playerKey, findPlayer = findPlayer,
        capturePlayerPositions = capturePlayerPositions, restorePlayerPositions = restorePlayerPositions,
        gridPositions = gridPositions, controlPosition = controlPosition,
        safeBounds = Archive.SafeBounds, pageEdges = Archive.PageEdges,
    }
end

return Archive
