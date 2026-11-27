-- This item's stat rule; acquisition and health grants use the shared food system.
return function(dependencies)
local ItemId, Stats = dependencies.ItemId, dependencies.Stats
local FLAG = (CacheFlag and CacheFlag.CACHE_DAMAGE) or 1
return { key = "ProteinStrip", itemId = ItemId, cache = "damage", amount = 0.15, Evaluate = function(player, cacheFlag)
    if cacheFlag ~= FLAG then return end
    local count = Stats.Count(player, ItemId)
    if count > 0 and type(player.Damage) == "number" then
        player.Damage = player.Damage + 0.15 * count
    end
end }
end
