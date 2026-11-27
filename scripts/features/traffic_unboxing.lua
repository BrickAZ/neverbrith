-- Owns the chest granted when the shared pickup animation finishes (or cannot be created).
return function()
local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
local CHEST_PICKUP = (PickupVariant and PickupVariant.PICKUP_CHEST) or 50
local CLOSED_CHEST = (ChestSubType and ChestSubType.CHEST_CLOSED) or 0
return { Grant = function(position) return Isaac.Spawn(PICKUP_ENTITY, CHEST_PICKUP, CLOSED_CHEST, position, Vector(0, 0), nil) end }
end
