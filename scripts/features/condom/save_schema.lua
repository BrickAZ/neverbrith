-- This owner declares only the existing first-load save shape.
-- Run/version validation and lifecycle resets stay in the existing feature.
return {
    Name = 'condom',
    Initialize = function(region)
        if type(region.banned) ~= 'table' then region.banned = {} end
    end,
}
