-- This owner declares only the existing first-load save shape.
-- Run/version validation and lifecycle resets stay in the existing feature.
return {
    Name = 'deathTrial',
    Initialize = function(region)
        if type(region.spawnedByFloor) ~= 'table' then region.spawnedByFloor = {} end
        if type(region.preActivationBossClearedFloors) ~= 'table' then region.preActivationBossClearedFloors = {} end
    end,
}
