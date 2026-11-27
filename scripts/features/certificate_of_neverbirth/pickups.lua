-- Owns the item pickup confirmation and quota policy.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local state = assert(deps.State)
    local lifetime = assert(deps.Lifetime)
    local PICKUP_ENTITY = deps.Config.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.Config.COLLECTIBLE_PICKUP
    local CONTROL_COOLDOWN_FRAMES = deps.Config.CONTROL_COOLDOWN_FRAMES
    local getPersistentData = deps.ledger.getPersistentData
    local save = deps.ledger.save

    local function clearPendingForSession(token)
        for key, pending in pairs(state.pendingPickups) do
            if pending.sessionToken == token then state.pendingPickups[key] = nil end
        end
    end

    local function pickupCollision(_, pickup, collider)
        if not lifetime.running then return nil end
        if not pickup or pickup.Type ~= PICKUP_ENTITY or pickup.Variant ~= COLLECTIBLE_PICKUP then return nil end
        local data = pickup.GetData and pickup:GetData() or nil
        if not data or not data.NeverbirthCertificateSessionToken then return nil end
        local persistent = getPersistentData()
        local session = persistent.stack[#persistent.stack]
        if not session or session.token ~= data.NeverbirthCertificateSessionToken
            or session.selected == true or session.interactionLocked == true then return nil end
        local player = collider and collider.ToPlayer and collider:ToPlayer() or nil
        if not player then return nil end
        local key = tostring(session.token) .. ":" .. tostring(pickup.InitSeed or data.NeverbirthCertificateLocalId)
        if not state.pendingPickups[key] then
            local before = player.GetCollectibleNum and tonumber(player:GetCollectibleNum(pickup.SubType)) or 0
            state.pendingPickups[key] = {
                pickup = pickup, player = player, runtimeId = tonumber(pickup.SubType),
                beforeCount = before or 0, expires = state.frame + 3, sessionToken = session.token,
            }
            session.interactionLocked = true
            session.pickupLockKey = key
        end
        return nil
    end
    function callbackInstallers.pickupCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, pickupCollision, COLLECTIBLE_PICKUP)
    end

    local function finishSelection(session, runtimeId)
        if not session or state.transition then return false end
        session.pickupLockKey = nil
        clearPendingForSession(session.token)
        session.interactionLocked = false
        session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
        save()
        return true
    end

    local function processPendingPickups()
        for key, pending in pairs(state.pendingPickups) do
            local exists = true
            if pending.pickup and pending.pickup.Exists then
                local ok, value = pcall(function() return pending.pickup:Exists() end)
                exists = ok and value == true
            end
            local count = pending.player and pending.player.GetCollectibleNum
                and tonumber(pending.player:GetCollectibleNum(pending.runtimeId)) or pending.beforeCount
            local persistent = getPersistentData()
            local session = persistent.stack[#persistent.stack]
            if not exists or count > pending.beforeCount then
                state.pendingPickups[key] = nil
                if session and session.token == pending.sessionToken then finishSelection(session, pending.runtimeId) end
            elseif state.frame >= pending.expires then
                state.pendingPickups[key] = nil
                if session and session.token == pending.sessionToken and session.pickupLockKey == key then
                    session.pickupLockKey = nil
                    session.interactionLocked = false
                    session.controlCooldownUntil = state.frame + CONTROL_COOLDOWN_FRAMES
                end
            end
        end
    end

    return {
        pickupCollision = pickupCollision,
        processPendingPickups = processPendingPickups,
        Installers = callbackInstallers,
    }
end
