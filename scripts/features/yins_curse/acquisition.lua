-- Private acquisition ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local ITEM_ID = deps.State.ITEM_ID
    local BLACK_CANDLE_ID = deps.State.BLACK_CANDLE_ID
    local COLLECTIBLE_PICKUP = deps.State.COLLECTIBLE_PICKUP
    local PENDING_PICKUP_TIMEOUT = deps.State.PENDING_PICKUP_TIMEOUT
    local runtime = deps.State.runtime
    local save = deps.State.save
    local getSavedState = deps.State.getSavedState
    local playerKey = deps.Queries.playerKey
    local toPlayer = deps.Queries.toPlayer
    local hasCollectible = deps.Queries.hasCollectible
    local collectibleCount = deps.Queries.collectibleCount
    local getPlayers = deps.Queries.getPlayers
    local processCurrentRoom = deps.Pedestals.processCurrentRoom

    local function recordFirstAcquisition(player, blackCandleSnapshot)
        local state = getSavedState()
        if not state or state.yinCurseActive then
            return false
        end
        local hadBlackCandle = blackCandleSnapshot
        if hadBlackCandle == nil then
            hadBlackCandle = hasCollectible(player, BLACK_CANDLE_ID)
        end
        state.yinCurseActive = true
        state.q4Mode = hadBlackCandle and "bonus_root" or "replace_root"
        state.firstQ4Resolved = false
        save()
        if processCurrentRoom then
            processCurrentRoom()
        end
        return true
    end

    local function prePickupCollision(_, pickup, collider, low)
        if ITEM_ID <= 0
            or not pickup
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
            or tonumber(pickup.SubType) ~= ITEM_ID
        then
            return nil
        end
        local player = toPlayer(collider)
        if not player then
            return nil
        end
        local key = playerKey(player)
        if runtime.pending[key] == nil then
            runtime.serial = runtime.serial + 1
            runtime.pending[key] = {
                player = player,
                beforeCount = collectibleCount(player),
                hadBlackCandle = hasCollectible(player, BLACK_CANDLE_ID),
                frame = runtime.frame,
                serial = runtime.serial,
            }
        end
        return nil
    end
    function callbackInstallers.prePickupCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, prePickupCollision, COLLECTIBLE_PICKUP)
    end

    local function postAddCollectible(_, itemId, charge, firstTime, slot, varData, player)
        if itemId ~= ITEM_ID or not player then
            return nil
        end
        local current = collectibleCount(player)
        if current <= 0 then
            return nil
        end
        local key = playerKey(player)
        local pending = runtime.pending[key]
        local hadBlackCandle
        if pending and current > pending.beforeCount then
            hadBlackCandle = pending.hadBlackCandle
        end
        -- REPENTOGON 1.0.12a calls POST_ADD after native AddCollectible.
        -- Commit before another callback can remove Yin or change Black Candle.
        -- Normal pedestals retain their pre-collision Black Candle snapshot.
        recordFirstAcquisition(player, hadBlackCandle)
        runtime.playerCounts[key] = current
        runtime.pending[key] = nil
        return nil
    end
    function callbackInstallers.postAddCollectible()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, postAddCollectible, ITEM_ID)
    end

    local function settleAcquisitions()
        local pending = {}
        for key, entry in pairs(runtime.pending) do
            entry.key = key
            pending[#pending + 1] = entry
        end
        table.sort(pending, function(left, right)
            return (tonumber(left.serial) or 0) < (tonumber(right.serial) or 0)
        end)
        for _, entry in ipairs(pending) do
            local current = collectibleCount(entry.player)
            if current > (tonumber(entry.beforeCount) or 0) then
                recordFirstAcquisition(entry.player, entry.hadBlackCandle)
                runtime.playerCounts[entry.key] = current
                runtime.pending[entry.key] = nil
            elseif runtime.frame - (tonumber(entry.frame) or runtime.frame) > PENDING_PICKUP_TIMEOUT then
                runtime.pending[entry.key] = nil
            end
        end

        for _, player in ipairs(getPlayers()) do
            local key = playerKey(player)
            local current = collectibleCount(player)
            local previous = runtime.playerCounts[key]
            if previous == nil then
                previous = 0
            end
            if current > previous and runtime.pending[key] == nil then
                recordFirstAcquisition(player, nil)
            end
            runtime.playerCounts[key] = current
        end
    end

    local function initializePlayerCounts()
        runtime.playerCounts = {}
        for _, player in ipairs(getPlayers()) do
            runtime.playerCounts[playerKey(player)] = collectibleCount(player)
        end
    end

    return {
        recordFirstAcquisition = recordFirstAcquisition,
        prePickupCollision = prePickupCollision,
        postAddCollectible = postAddCollectible,
        settleAcquisitions = settleAcquisitions,
        initializePlayerCounts = initializePlayerCounts,
        Installers = callbackInstallers,
    }
end
