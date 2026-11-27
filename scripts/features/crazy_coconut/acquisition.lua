-- Owns handlers and native bindings; the entry schedules installation.
return function(Neverbirth, dependencies)
-- Native bindings are declared here; the entry chooses their installation phase.
local callbackInstallers = {}
local Store = assert(dependencies.Store)
local Items = assert(dependencies.Items)
local GetPlayers = assert(dependencies.GetPlayers)
local IsValidItemId = assert(dependencies.IsValidItemId)
local DebugLog = assert(dependencies.Log)
local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
local COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local Ledger = assert(dependencies.Ledger)
local runtime = assert(dependencies.Runtime)
local RefreshCache = assert(dependencies.RefreshCache)

local function TraceCrazyCoconut(self, stage, player, details)
    local playerKey = player and tostring(player.InitSeed or '?') or 'unresolved'
    DebugLog('[neverbirth][CrazyCoconut][' .. tostring(stage) .. '] player=' .. playerKey .. ' ' .. tostring(details or ''))
end

local function ShouldCrazyCoconutRewardCollectible(self, itemId)
    return IsValidItemId(itemId)
end

local function GetCrazyCoconutPickupSourceKey(self, playerKey, pickup, itemId, beforeCount)
    local pickupSeed = pickup and pickup.InitSeed
    return tostring(playerKey) .. ":" .. tostring(pickupSeed or (tostring(itemId) .. ":" .. tostring(beforeCount)))
end

local function IsCrazyCoconutPickupSourceAlive(self, sourceKey)
    local source = self.CrazyCoconutPickupSources[sourceKey]
    if not source then
        return false
    end

    local ok, exists = pcall(function()
        return source:Exists()
    end)
    return ok and exists == true
end

local function GetCrazyCoconutQueuedCollectibleId(self, player)
    local queuedItem = player and player.QueuedItem
    local queuedConfig = queuedItem and queuedItem.Item
    return tonumber(queuedConfig and queuedConfig.ID) or 0
end

local function QueueCrazyCoconutCandidate(self, player, pickup, itemId)
    if not runtime.running or runtime.disposed then return end
    if not player or not player.GetCollectibleNum or not ShouldCrazyCoconutRewardCollectible(self, itemId) then
        return
    end

    local coconutCount = math.max(0, tonumber(player:GetCollectibleNum(Items.CrazyCoconut)) or 0)
    if coconutCount <= 0 or itemId == Items.CrazyCoconut then
        return
    end

    local data = self:GetCrazyCoconutData()
    local key = tostring(player.InitSeed or "")
    local pending = data.pending[key] or {}
    local beforeCount = math.max(0, tonumber(player:GetCollectibleNum(itemId)) or 0)
    local sourceKey = GetCrazyCoconutPickupSourceKey(self, key, pickup, itemId, beforeCount)

    for _, candidate in ipairs(pending) do
        if candidate.sourceKey == sourceKey then
            if not candidate.remainingUpdates then
                candidate.beforeDamage = self:GetCrazyCoconutNaturalDamage(player, data, key)
                candidate.coconutCount = coconutCount
            end
            self.CrazyCoconutPickupSources[sourceKey] = pickup
            return
        end
    end

    local token = tostring(itemId) .. ":" .. tostring(beforeCount) .. ":" .. tostring(#pending + 1)
    pending[#pending + 1] = {
        itemId = itemId,
        beforeCount = beforeCount,
        beforeDamage = self:GetCrazyCoconutNaturalDamage(player, data, key),
        coconutCount = coconutCount,
        sourceKey = sourceKey,
        traceToken = token,
    }
    data.pending[key] = pending
    self.CrazyCoconutPickupSources[sourceKey] = pickup
    TraceCrazyCoconut(self, "queued", player, token)
end

function Neverbirth:HandleCrazyCoconutCollectiblePickup(pickup, collider)
    if not runtime.running or runtime.disposed then return nil end
    local player = collider and collider:ToPlayer()
    if not player or not pickup or pickup.Type ~= PICKUP_ENTITY or pickup.Variant ~= COLLECTIBLE_VARIANT then
        return nil
    end

    local itemId = tonumber(pickup.SubType) or 0
    if itemId == Items.CrazyCoconut or not ShouldCrazyCoconutRewardCollectible(self, itemId) then
        return nil
    end

    if not player.GetCollectibleNum or player:GetCollectibleNum(Items.CrazyCoconut) <= 0 then
        return nil
    end

    TraceCrazyCoconut(self, 'pre-pickup-collision', player, tostring(itemId))
    QueueCrazyCoconutCandidate(self, player, pickup, itemId)
    return nil
end
function callbackInstallers.InstallPickup(COLLECTIBLE_VARIANT)
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, Neverbirth.HandleCrazyCoconutCollectiblePickup, COLLECTIBLE_VARIANT)
end

-- A collision is only a candidate. Confirm inventory/queue completion before
-- starting the original two-update delay; do not settle inside the collision.
local function AdvanceCandidates(self, player, data, key, pending)
    local due = {}
    local nextPending = {}
    for _, candidate in ipairs(pending) do
        local countAfterPickup = math.max(0, tonumber(player:GetCollectibleNum(candidate.itemId)) or 0)
        local queuedItemId = GetCrazyCoconutQueuedCollectibleId(self, player)
        if not candidate.remainingUpdates then
            if candidate.queueSeen then
                if queuedItemId == candidate.itemId then
                    nextPending[#nextPending + 1] = candidate
                elseif countAfterPickup > candidate.beforeCount then
                    candidate.remainingUpdates = 2
                    nextPending[#nextPending + 1] = candidate
                    TraceCrazyCoconut(self, "pickup-confirmed", player, candidate.traceToken)
                else
                    candidate.queueFlushUpdates = (tonumber(candidate.queueFlushUpdates) or 0) + 1
                    if candidate.queueFlushUpdates <= 2 then
                        nextPending[#nextPending + 1] = candidate
                    else
                        TraceCrazyCoconut(self, "queue-flush-not-confirmed", player, candidate.traceToken)
                    end
                end
            elseif queuedItemId == candidate.itemId then
                candidate.queueSeen = true
                candidate.queueFlushUpdates = 0
                nextPending[#nextPending + 1] = candidate
                TraceCrazyCoconut(self, "queue-seen", player, candidate.traceToken)
            elseif not candidate.sourceKey or not IsCrazyCoconutPickupSourceAlive(self, candidate.sourceKey) then
                if candidate.sourceKey then
                    self.CrazyCoconutPickupSources[candidate.sourceKey] = nil
                end
                if candidate.sourceKey and countAfterPickup > candidate.beforeCount then
                    candidate.remainingUpdates = 2
                    nextPending[#nextPending + 1] = candidate
                    TraceCrazyCoconut(self, "pickup-confirmed", player, candidate.traceToken)
                else
                    TraceCrazyCoconut(self, "pickup-not-confirmed", player, candidate.traceToken)
                end
            else
                nextPending[#nextPending + 1] = candidate
            end
        else
            candidate.remainingUpdates = math.max(0, (tonumber(candidate.remainingUpdates) or 0) - 1)
            if candidate.remainingUpdates <= 0 then
                due[#due + 1] = candidate
            else
                nextPending[#nextPending + 1] = candidate
            end
        end
        -- Confirmed/settled and discarded candidates no longer need a pedestal.
        -- Keep a source only while this exact candidate is still awaiting pickup.
        if candidate.sourceKey and (candidate.remainingUpdates
            or nextPending[#nextPending] ~= candidate) then
            self.CrazyCoconutPickupSources[candidate.sourceKey] = nil
        end
    end
    data.pending[key] = nextPending

    return due
end

-- Every candidate due this update sees the same natural-damage sample, even
-- when settling an earlier candidate refreshes the player's cache again.
local function SettleCandidates(self, player, data, key, due)
    local changed = false
    if #due > 0 then
        RefreshCache(player)
        local damageAfterPickup = self:GetCrazyCoconutNaturalDamage(player, data, key)
        for _, candidate in ipairs(due) do
            local damageBeforePickup = tonumber(candidate.beforeDamage) or damageAfterPickup
            local reward = damageAfterPickup <= damageBeforePickup + 0.001
            TraceCrazyCoconut(self, 'cache-settlement', player, candidate.traceToken .. ':reward=' .. tostring(reward))
            if reward then
                Ledger.AddRewardLayers(data, key, candidate.coconutCount)
                RefreshCache(player)
                changed = true
            end
        end
    end

    return changed
end

function Neverbirth:TrackCrazyCoconutCopies()
    if not runtime.running or runtime.disposed then return end
    if not IsValidItemId(Items.CrazyCoconut) then
        return
    end

    local data = self:GetCrazyCoconutData()
    local changed = false

    for _, player in ipairs(GetPlayers()) do
        if player and player.GetCollectibleNum then
            local key = tostring(player.InitSeed or "")
            local currentCount = math.max(0, tonumber(player:GetCollectibleNum(Items.CrazyCoconut)) or 0)
            if Ledger.TrackCopies(self, player, data, key, currentCount) then
                changed = true
            end

            local pending = data.pending[key] or {}
            if currentCount <= 0 then
                if #pending > 0 then
                    for _, candidate in ipairs(pending) do
                        if candidate.sourceKey then self.CrazyCoconutPickupSources[candidate.sourceKey] = nil end
                    end
                    data.pending[key] = {}
                    changed = true
                end
                data.naturalDamage[key] = nil
            else
                local due = AdvanceCandidates(self, player, data, key, pending)
                if SettleCandidates(self, player, data, key, due) then changed = true end

                data.naturalDamage[key] = self:GetCrazyCoconutNaturalDamage(player, data, key)
            end
        end
    end

    if changed then
        Store.Save()
    end
end
function callbackInstallers.InstallTrackCopies()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackCrazyCoconutCopies)
end

return { InstallTrackCopies = callbackInstallers.InstallTrackCopies, InstallPickup = callbackInstallers.InstallPickup }
end
