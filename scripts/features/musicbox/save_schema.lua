-- This owner declares only the existing first-load save shape.
-- Run/version validation and lifecycle resets stay in the existing feature.
return {
    Name = 'musicboxDeathDebt',
    Initialize = function(region)
        if type(region.debts) ~= 'table' then region.debts = {} end
    end,
}
