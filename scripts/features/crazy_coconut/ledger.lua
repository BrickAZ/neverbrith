-- Item-owned implementation; the entry owns callback installation.
return function(Neverbirth, dependencies)
local Store = assert(dependencies.Store)
local Items = assert(dependencies.Items)
local GetPlayers = assert(dependencies.GetPlayers)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
local IsValidItemId = assert(dependencies.IsValidItemId)

local RefreshCache = assert(dependencies.RefreshCache)

local getRunData = include("scripts.runtime.run_section")(Store, GetCurrentRunSeed,
    function() return { runSeed = GetCurrentRunSeed(), players = {}, playerCounts = {}, pending = {}, naturalDamage = {}, nextTraceToken = 1 } end, { "players", "playerCounts", "pending", "naturalDamage" })
function Neverbirth:GetCrazyCoconutData()
    return getRunData()
end

local function ResetRun()
    -- Seed equality does not mean this is a continued run.
    local data = Store.Get()
    data.runSeed = GetCurrentRunSeed()
    data.players = {}
    data.playerCounts = {}
    data.pending = {}
    data.naturalDamage = {}
    data.nextTraceToken = 1
    Store.Save()
end

local function TrackCopies(self, player, data, key, currentCount)
    local changed = false
    local previousCount = math.max(0, tonumber(data.playerCounts[key]) or 0)

    if currentCount > previousCount then
        data.players[key] = math.max(0, tonumber(data.players[key]) or 0) + (currentCount - previousCount)
        RefreshCache(player)
        changed = true
    end
    if currentCount ~= previousCount then
        data.playerCounts[key] = currentCount
        if currentCount < previousCount then RefreshCache(player) end
        changed = true
    end

    return changed
end

local function AddRewardLayers(data, key, count)
    data.players[key] = math.max(0, tonumber(data.players[key]) or 0) + math.max(0, tonumber(count) or 0)
end

return { TrackCopies = TrackCopies, AddRewardLayers = AddRewardLayers, ResetRun = ResetRun }
end
