-- This owner declares only the existing first-load save shape.
-- Run/version validation and lifecycle resets stay in the existing feature.
return {
    Name = 'angelbox',
    Initialize = function(region)
        if type(region.players) ~= 'table' then region.players = {} end
        if type(region.pendingRewards) ~= 'table' then region.pendingRewards = {} end
        if type(region.enteredAngelFloors) ~= 'table' then region.enteredAngelFloors = {} end
        if type(region.appliedChanceFloors) ~= 'table' then region.appliedChanceFloors = {} end
        if type(region.forcedAngelFloors) ~= 'table' then region.forcedAngelFloors = {} end
    end,
}
