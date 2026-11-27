-- Private food responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local PICKUP_ENTITY = deps.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.COLLECTIBLE_PICKUP
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local entityExists = deps.Queries.entityExists
    local playerKey = deps.Queries.playerKey
    local entityKey = deps.Queries.entityKey
    local collectibleCount = deps.Queries.collectibleCount
    local getCollectibleConfig = deps.Queries.getCollectibleConfig
    local isFoodConfig = deps.Queries.isFoodConfig
    local save = deps.State.save
    local getPlayerRecord = deps.State.getPlayerRecord

    local function getQueuedItemId(player)
        if not player then
            return nil
        end
        local queued = player.QueuedItem
        if type(player.GetQueuedItem) == "function" then
            local ok, value = pcall(player.GetQueuedItem, player)
            if ok and value ~= nil then
                queued = value
            end
        end
        local item = queued and queued.Item
        return tonumber(item and (item.ID or item.Id))
    end

    local function captureFoodPickup(pickup, player, frame)
        if not pickup or not player
            or tonumber(pickup.Type) ~= PICKUP_ENTITY
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
        then
            return false
        end
        local itemId = math.floor(tonumber(pickup.SubType) or 0)
        if itemId <= 0 or not isFoodConfig(getCollectibleConfig(itemId)) then
            return false
        end
        if not entityExists(pickup) then
            return false
        end
        local key = playerKey(player) .. ":" .. entityKey(pickup)
        if runtime.pendingFood[key] then
            return false
        end
        runtime.serial = runtime.serial + 1
        runtime.pendingFood[key] = {
            key = key,
            serial = runtime.serial,
            frame = math.floor(tonumber(frame) or runtime.frame),
            player = player,
            playerKey = playerKey(player),
            pickup = pickup,
            itemId = itemId,
            beforeCount = collectibleCount(player, itemId),
            queueSeen = getQueuedItemId(player) == itemId,
        }
        return true
    end

    local function settleFoodPickups(frame)
        frame = math.floor(tonumber(frame) or runtime.frame)
        local ordered = {}
        for _, entry in pairs(runtime.pendingFood) do
            ordered[#ordered + 1] = entry
        end
        table.sort(ordered, function(left, right)
            return (tonumber(left.serial) or 0) < (tonumber(right.serial) or 0)
        end)
        local settled = 0
        for _, entry in ipairs(ordered) do
            local age = frame - (tonumber(entry.frame) or frame)
            if age >= Constants.FOOD_SETTLE_DELAY_FRAMES then
                local current = collectibleCount(entry.player, entry.itemId)
                local queuedItemId = getQueuedItemId(entry.player)
                if queuedItemId == entry.itemId then
                    entry.queueSeen = true
                end
                local sourceGone = not entityExists(entry.pickup)
                local confirmed = current > (tonumber(entry.beforeCount) or 0)
                    or (entry.queueSeen == true and sourceGone and queuedItemId ~= entry.itemId)
                if confirmed then
                    local record = getPlayerRecord(entry.player)
                    if record then
                        record.foodPickups = record.foodPickups + 1
                        if record.foodPickups >= 4 then
                            record.chewUnlocked = true
                        end
                        save()
                        settled = settled + 1
                    end
                    runtime.pendingFood[entry.key] = nil
                elseif entry.queueSeen == true and queuedItemId ~= entry.itemId then
                    -- The pickup entered the real queued-item flow but did not
                    -- increase the inventory and its pedestal still exists.
                    -- Treat that as a cancelled/finished queue so a later real
                    -- collision can establish a fresh snapshot.
                    runtime.pendingFood[entry.key] = nil
                elseif entry.queueSeen ~= true
                    and entityExists(entry.pickup)
                    and age > Constants.FOOD_SETTLE_TIMEOUT_FRAMES
                then
                    -- Only an unqueued collision against a still-existing
                    -- pedestal is allowed to expire by age. Queued pickup
                    -- animations may legitimately last longer than ten frames.
                    runtime.pendingFood[entry.key] = nil
                elseif entry.queueSeen ~= true and sourceGone then
                    -- The source vanished without ever entering the player's
                    -- pickup queue and without a collectible-count increase.
                    -- It was not a confirmed player pickup.
                    runtime.pendingFood[entry.key] = nil
                end
            end
        end
        return settled
    end

    local function prePickupCollision(_, pickup, collider, low)
        local player = collider
        if collider and type(collider.ToPlayer) == "function" then
            local ok, converted = pcall(collider.ToPlayer, collider)
            if ok then
                player = converted
            end
        end
        if player then
            captureFoodPickup(pickup, player, runtime.frame)
        end
        return nil
    end
    function callbackInstallers.prePickupCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, prePickupCollision, COLLECTIBLE_PICKUP)
    end

    return {
        getQueuedItemId = getQueuedItemId,
        captureFoodPickup = captureFoodPickup,
        settleFoodPickups = settleFoodPickups,
        prePickupCollision = prePickupCollision,
        Installers = callbackInstallers,
    }
end
