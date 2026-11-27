return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local IsValidItemId = assert(dependencies.IsValidItemId)
local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
local COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
Neverbirth.PickupBannerTexts = {}

function Neverbirth:RegisterPickupBannerText(itemId, enName, enSubtitle, zhName, zhSubtitle)
    if not IsValidItemId(itemId) then
        return
    end

    self.PickupBannerTexts[itemId] = {
        en_us = { name = enName, subtitle = enSubtitle },
        zh_cn = { name = zhName, subtitle = zhSubtitle },
    }
end

Neverbirth.PickupBannerState = Neverbirth.PickupBannerState or { pending = {} }

function Neverbirth:GetPickupBannerLocale()
    return self:GetRuntimeLocale()
end

function Neverbirth:GetPickupBannerQueuedItemId(player)
    local queued = player and player.QueuedItem
    local item = queued and queued.Item
    return item and tonumber(item.ID or item.Id) or nil
end

function Neverbirth:GetPickupBannerSourceKey(pickup)
    if pickup and pickup.InitSeed ~= nil then
        return "seed:" .. tostring(pickup.InitSeed)
    end
    return tostring(pickup)
end

function Neverbirth:IsPickupBannerSourceAlive(candidate)
    local pickup = candidate and candidate.pickup
    if not pickup or tonumber(pickup.SubType) ~= candidate.itemId then
        return false
    end
    if pickup.Exists then
        local ok, exists = pcall(function()
            return pickup:Exists()
        end)
        return ok and exists == true
    end
    return true
end

function Neverbirth:TrackLocalizedPickupBannerCollision(pickup, collider)
    if not pickup or pickup.Type ~= PICKUP_ENTITY
        or pickup.Variant ~= COLLECTIBLE_VARIANT then
        return nil
    end

    if self:GetPickupBannerLocale() ~= "zh_cn" then
        return nil
    end

    local itemId = tonumber(pickup.SubType) or 0
    if not self.PickupBannerTexts[itemId] then
        return nil
    end

    local player = collider and collider.ToPlayer and collider:ToPlayer() or nil
    if not player or not player.GetCollectibleNum then
        return nil
    end

    local playerKey = tostring(player.InitSeed or player)
    local pendingKey = playerKey .. "|" .. self:GetPickupBannerSourceKey(pickup)
    local pending = self.PickupBannerState.pending
    if not pending[pendingKey] then
        pending[pendingKey] = {
            pickup = pickup,
            player = player,
            itemId = itemId,
            beforeCount = math.max(0, tonumber(player:GetCollectibleNum(itemId)) or 0),
        }
    end

    return nil
end
function callbackInstallers.Neverbirth_TrackLocalizedPickupBannerCollision()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, Neverbirth.TrackLocalizedPickupBannerCollision, COLLECTIBLE_VARIANT)
end

function Neverbirth:ShowLocalizedPickupBanner(itemId)
    local localized = self.PickupBannerTexts[itemId]
    if not localized then
        return false
    end
    localized = localized[self:GetPickupBannerLocale()] or localized.en_us
    if not localized then
        return false
    end

    local gameOk, game = pcall(Game)
    local hudOk, hud = false, nil
    if gameOk and game and game.GetHUD then
        hudOk, hud = pcall(function()
            return game:GetHUD()
        end)
    end
    if not hudOk or not hud or type(hud.ShowItemText) ~= "function" then
        return false
    end

    return pcall(function()
        hud:ShowItemText(localized.name or "", localized.subtitle or "")
    end)
end

function Neverbirth:UpdateLocalizedPickupBanners()
    local pending = self.PickupBannerState.pending
    for pendingKey, candidate in pairs(pending) do
        local player = candidate.player
        local currentCount = player and player.GetCollectibleNum
            and math.max(0, tonumber(player:GetCollectibleNum(candidate.itemId)) or 0)
            or candidate.beforeCount
        local queuedItemId = self:GetPickupBannerQueuedItemId(player)

        if currentCount > candidate.beforeCount or queuedItemId == candidate.itemId then
            self:ShowLocalizedPickupBanner(candidate.itemId)
            pending[pendingKey] = nil
        elseif not self:IsPickupBannerSourceAlive(candidate) then
            pending[pendingKey] = nil
        end
    end
end
function callbackInstallers.Neverbirth_UpdateLocalizedPickupBanners()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateLocalizedPickupBanners)
end

function Neverbirth:ResetLocalizedPickupBanners()
    self.PickupBannerState.pending = {}
end
function callbackInstallers.Neverbirth_ResetLocalizedPickupBanners()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetLocalizedPickupBanners)
end

return {
InstallUpdate = function() callbackInstallers.Neverbirth_UpdateLocalizedPickupBanners() end,
InstallReset = function() callbackInstallers.Neverbirth_ResetLocalizedPickupBanners() end,
InstallPickup = function() callbackInstallers.Neverbirth_TrackLocalizedPickupBannerCollision() end,
}
end
