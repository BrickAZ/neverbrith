-- Optional, protected queries only. Callers needing error propagation keep
-- their direct Room/Level calls; this module never caches engine objects.
local World = {}

function World.TryGame()
    if not Game then return nil end
    local ok, game = pcall(Game)
    if ok then return game end
    return nil
end

function World.TryMethod(object, method)
    if object and object[method] then
        local ok, value = pcall(function() return object[method](object) end)
        if ok then return value end
    end
    return nil
end

function World.TryItemConfig()
    if Isaac and Isaac.GetItemConfig then
        local ok, config = pcall(function() return Isaac.GetItemConfig() end)
        if ok then return config end
    end
    return nil
end

-- This is the legacy run/stage/stage-type identity, not a universal room key.
function World.RunFloorKey(level, getRunSeed)
    if not level then return getRunSeed() .. ":unknown" end
    local stage = level.GetStage and level:GetStage() or "unknown"
    local stageType = level.GetStageType and level:GetStageType() or "unknown"
    return getRunSeed() .. ":" .. tostring(stage) .. ":" .. tostring(stageType)
end

-- Room-local index, then spawn seed. Deliberately excludes floor/run identity.
-- The room is queried only if the level cannot provide an index.
function World.RoomIndexOrSeed(getLevel, getRoom)
    local level = getLevel()
    if level and level.GetCurrentRoomIndex then
        local ok, index = pcall(function() return level:GetCurrentRoomIndex() end)
        if ok and index ~= nil then return "idx:" .. tostring(index) end
    end
    local room = getRoom()
    if room and room.GetSpawnSeed then
        local ok, seed = pcall(function() return room:GetSpawnSeed() end)
        if ok and seed ~= nil then return "seed:" .. tostring(seed) end
    end
    return "unknown"
end

return World
