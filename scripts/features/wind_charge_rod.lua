-- Independent upgrade identity and instant reverse-launch eligibility.
return function(itemId, hasCollectible)
    local id = tonumber(itemId) or -1
    return {
        ItemId = id,
        IsHeld = function(player) return hasCollectible(player, id) end,
    }
end
