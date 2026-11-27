-- Owns handlers and native bindings; the entry schedules installation.
return function(Neverbirth, dependencies)


-- Native bindings are declared here; the entry chooses their installation phase.
local callbackInstallers = {}
local REPLACEMENT_ATTEMPTS = 20
local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
local COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local IsBannedCollectible = assert(dependencies.IsBannedCollectible)
function Neverbirth:RollCondomReplacement(originalItemId)
    local game = Game()
    local itemPool = game and game.GetItemPool and game:GetItemPool()
    if not itemPool or not itemPool.GetCollectible then
        return nil
    end

    for _ = 1, REPLACEMENT_ATTEMPTS do
        local candidate = itemPool:GetCollectible(ItemPoolType and ItemPoolType.POOL_TREASURE or 0, true, 0, 0)
        if type(candidate) == "number"
            and candidate > 0
            and candidate ~= originalItemId
            and not IsBannedCollectible(candidate) then
            return candidate
        end
    end

    return nil
end

function Neverbirth:ReplaceCondomBannedPickup(pickup)
    if not pickup or pickup.Type ~= PICKUP_ENTITY or pickup.Variant ~= COLLECTIBLE_VARIANT then
        return
    end

    local currentSubtype = pickup.SubType
    if not IsBannedCollectible(currentSubtype) then
        return
    end

    local pickupData = pickup.GetData and pickup:GetData() or nil
    if pickupData and pickupData.neverbirthCondomReplacing then
        return
    end
    if pickupData then
        pickupData.neverbirthCondomReplacing = true
    end

    local replacement = self:RollCondomReplacement(currentSubtype)
    if replacement then
        if pickup.Morph then
            pickup:Morph(PICKUP_ENTITY, COLLECTIBLE_VARIANT, replacement, true, true, false)
        else
            pickup.SubType = replacement
        end
    elseif pickup.Remove then
        pickup:Remove()
    end

    if pickupData then
        pickupData.neverbirthCondomReplacing = nil
    end
end
function callbackInstallers.InstallPickupInit()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, Neverbirth.ReplaceCondomBannedPickup, COLLECTIBLE_VARIANT)
end
function callbackInstallers.InstallPickupMorph()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_MORPH, Neverbirth.ReplaceCondomBannedPickup)
end

return { InstallPickupInit = callbackInstallers.InstallPickupInit, InstallPickupMorph = callbackInstallers.InstallPickupMorph }
end
