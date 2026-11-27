-- This item's stat rule; acquisition and health grants use the shared food system.
return function(dependencies)
local ItemId, Stats = dependencies.ItemId, dependencies.Stats
local FLAG = (CacheFlag and CacheFlag.CACHE_RANGE) or 64
return { key = "DHAFishOil", itemId = ItemId, cache = "range", amount = 16, Evaluate = function(player, cacheFlag)
    if cacheFlag ~= FLAG then return end
    local count = Stats.Count(player, ItemId)
    if count > 0 and type(player.TearRange) == "number" then
        player.TearRange = player.TearRange + 16 * count
    end
end }
end
