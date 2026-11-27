-- This owner declares only the existing first-load save shape.
-- Run/version validation and lifecycle resets stay in the existing feature.
return {
    Name = 'crazyCoconut',
    Initialize = function(region)
        if type(region.players) ~= 'table' then region.players = {} end
        if type(region.playerCounts) ~= 'table' then region.playerCounts = {} end
        if type(region.pending) ~= 'table' then region.pending = {} end
        if type(region.naturalDamage) ~= 'table' then region.naturalDamage = {} end
    end,
}
