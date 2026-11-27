-- Owns the item pickup confirmation and quota policy.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local PICKUP_ENTITY = deps.Config.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.Config.COLLECTIBLE_PICKUP
    local CONFIRM_FRAMES = deps.Config.CONFIRM_FRAMES
    local playerKey = deps.Room.playerKey
    local getPersistentData = deps.ledger.getPersistentData
    local save = deps.ledger.save
    local markSelected = deps.ledger.markSelected
    local adoptSessionSpawnedPedestals = deps.gallery.adoptSessionSpawnedPedestals
    local beginReturn = deps.flow.beginReturn

    local function queuedCollectibleId(player)
        local queued = player and player.QueuedItem
        local item = queued and queued.Item
        return tonumber(item and item.ID) or 0
    end

    local function pickupCollision(_, pickup, collider)
        if not lifetime.running then return nil end
        if not pickup or tonumber(pickup.Type) ~= PICKUP_ENTITY
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP then return nil end
        local data = pickup.GetData and pickup:GetData() or nil
        if not data or not data.NeverbirthHouseSessionToken then return nil end
        local runData = getPersistentData()
        local session = runData.session
        if not session or data.NeverbirthHouseSessionToken ~= session.token then return nil end
        local player = collider and collider.ToPlayer and collider:ToPlayer() or nil
        if not player then return nil end
        -- Reserve team quota before the engine can accept another collision in
        -- this update. Controls and returning sessions cannot admit new picks.
        if session.phase ~= "active" or session.interactionLocked == true or state.transition
            or session.selectedCount >= 3 then return true end
        local candidateIndex = math.floor(tonumber(data.NeverbirthHouseCandidateIndex) or 0)
        if candidateIndex <= 0 then return nil end
        if session.selected[tostring(candidateIndex)] then return true end
        local itemId = tonumber(pickup.SubType) or 0
        if itemId <= 0 then return true end
        local ownerKey = playerKey(player)
        local key = tostring(session.token) .. ":" .. tostring(candidateIndex)
        local pending = state.pending[key]
        if pending then
            if pending.playerKey ~= ownerKey or queuedCollectibleId(player) > 0 then return true end
            return nil
        end
        if queuedCollectibleId(player) > 0 then return true end
        local reserved = 0
        for _, entry in pairs(state.pending) do
            reserved = reserved + 1
            -- One player's single item queue cannot own two pending pedestals.
            if entry.playerKey == ownerKey then return true end
        end
        if session.selectedCount + reserved >= 3 then return true end
        local before = player.GetCollectibleNum and tonumber(player:GetCollectibleNum(itemId)) or 0
        state.pending[key] = {
            pickup = pickup, player = player, playerKey = ownerKey, itemId = itemId,
            candidateIndex = candidateIndex, beforeCount = before or 0,
            expires = state.frame + CONFIRM_FRAMES,
        }
        return nil
    end
    function callbackInstallers.pickupCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, pickupCollision, COLLECTIBLE_PICKUP)
    end

    local function processPending()
        local runData = getPersistentData()
        local session = runData.session
        if not session or session.phase ~= "active" then state.pending = {}; return end
        for key, pending in pairs(state.pending) do
            local exists = true
            if pending.pickup and pending.pickup.Exists then
                local ok, value = pcall(function() return pending.pickup:Exists() end)
                exists = ok and value == true
            end
            local count = pending.player and pending.player.GetCollectibleNum
                and tonumber(pending.player:GetCollectibleNum(pending.itemId)) or pending.beforeCount
            local queued = queuedCollectibleId(pending.player) == pending.itemId
            if queued then pending.queued = true end
            local consumed = not exists or tonumber(pending.pickup and pending.pickup.SubType) == 0
            -- An empty pedestal may remain throughout the pickup animation.
            -- Keep the reservation while queued; settle only an actual grant
            -- tied to this pickup, never room cleanup or an unrelated grant.
            if count > pending.beforeCount and (pending.queued or consumed) then
                state.pending[key] = nil
                adoptSessionSpawnedPedestals(session)
                if markSelected(session, pending.candidateIndex) then
                    beginReturn(runData, session)
                    return
                end
                save()
            elseif not queued and (pending.queued or consumed
                or tonumber(pending.pickup and pending.pickup.SubType) ~= pending.itemId
                or state.frame >= pending.expires) then
                state.pending[key] = nil
            end
        end
    end

    return {
        pickupCollision = pickupCollision,
        processPending = processPending,
        Installers = callbackInstallers,
    }
end
