-- This owner declares only the existing first-load save shape.
-- Run/version validation and lifecycle resets stay in the existing feature.
return {
    Name = 'blackTaisui',
    Initialize = function(region)
        if type(region.players) ~= 'table' then region.players = {} end
    end,
}
