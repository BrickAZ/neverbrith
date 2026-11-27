-- This item's stat rule; acquisition and health grants use the shared food system.
return function(dependencies)
local ItemId, Stats = dependencies.ItemId, dependencies.Stats
local FLAG = (CacheFlag and CacheFlag.CACHE_SPEED) or 8
return { key = "LeanCan", itemId = ItemId, cache = "speed", amount = 0.10, Evaluate = function(player, cacheFlag)
    if cacheFlag ~= FLAG then return end
    local count = Stats.Count(player, ItemId)
    if count > 0 and type(player.MoveSpeed) == "number" then
        player.MoveSpeed = player.MoveSpeed + 0.10 * count
    end
end }
end
