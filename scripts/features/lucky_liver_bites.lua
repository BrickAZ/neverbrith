-- This item's stat rule; acquisition and health grants use the shared food system.
return function(dependencies)
local ItemId, Stats = dependencies.ItemId, dependencies.Stats
local FLAG = (CacheFlag and CacheFlag.CACHE_LUCK) or 1024
return { key = "LuckyLiverBites", itemId = ItemId, cache = "luck", amount = 0.25, Evaluate = function(player, cacheFlag)
    if cacheFlag ~= FLAG then return end
    local count = Stats.Count(player, ItemId)
    if count > 0 and type(player.Luck) == "number" then
        player.Luck = player.Luck + 0.25 * count
    end
end }
end
