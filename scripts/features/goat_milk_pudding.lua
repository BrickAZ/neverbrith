-- The extra half soul heart is an item-owned parameter consumed by shared pickup accounting.
return function(dependencies)
return { key = "GoatMilkPudding", itemId = dependencies.ItemId, cache = nil, soulHeartHalfUnits = 1 }
end
