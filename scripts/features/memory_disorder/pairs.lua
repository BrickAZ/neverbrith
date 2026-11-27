-- Native partner preflight, parking, ownership proxies and restoration.
return function(Neverbirth, context, deps)
    local diagnosticOnce = deps.diagnosticOnce
    local safeCall = deps.safeCall
    local numberCall = deps.numberCall
    local copyTable = deps.copyTable
    local runtimePlayerKey = deps.runtimePlayerKey
    local getPlayers = deps.getPlayers
    local playerExists = deps.playerExists
    local getPlayerType = deps.getPlayerType
    local getCollectibleCount = deps.getCollectibleCount
    local pairPartner = deps.pairPartner
    local profileForType = deps.profileForType
    local readHealth = deps.readHealth
    local applyHealth = deps.applyHealth
    local captureSlots = deps.captureSlots
    local capturePockets = deps.capturePockets
    local restoreSlot = deps.restoreSlot
    local ITEM_ID = deps.ITEM_ID
    local SLOT_PRIMARY = deps.SLOT_PRIMARY
    local SLOT_SECONDARY = deps.SLOT_SECONDARY
    local SLOT_POCKET = deps.SLOT_POCKET
    local POCKET_PRIMARY = deps.POCKET_PRIMARY
    local POCKET_SECONDARY = deps.POCKET_SECONDARY

    local function collectibleSnapshot(player)
        local list, ok = safeCall(player, "GetCollectiblesList")
        if not ok or type(list) ~= "table" then return nil end
        local result = {}
        for id, count in pairs(list) do
            id, count = tonumber(id), tonumber(count)
            if id and count and id > 0 and count > 0 then result[tostring(id)] = count end
        end
        return result
    end

    local function snapshotPartner(player)
        -- Normal Forgotten forms share inventory and are native subplayers,
        -- not co-op actors. Their combined health is handled by read/applyHealth.
        if getPlayerType(player) == 16 then return nil end
        local other = pairPartner(player)
        if not other then return nil end
        local inventory = collectibleSnapshot(other)
        if not inventory then return nil, "partner inventory API unavailable" end
        return {
            player = other, runtimeKey = runtimePlayerKey(other), mainType = getPlayerType(player),
            snapshot = { playerType = getPlayerType(other), health = readHealth(other),
                collectibles = inventory, slots = captureSlots(other), pockets = capturePockets(other),
                smeltedTrinkets = copyTable(safeCall(other, "GetSmeltedTrinkets")),
                trinkets = { numberCall(other, "GetTrinket", 0), numberCall(other, "GetTrinket", 1) } },
        }
    end

    local function canSwitchPair(player, targetType)
        if getPlayerType(player) == targetType then return true end
        if (targetType == 19 or targetType == 35)
            and not (PlayerManager and type(PlayerManager.RemoveCoPlayer) == "function") then return false end
        local other = pairPartner(player)
        if other and getPlayerType(player) ~= 16 then
            if not (PlayerManager and type(PlayerManager.RemoveCoPlayer) == "function") then
                diagnosticOnce("pair-remove-api", "Pair switch skipped: safe extra-player removal API unavailable")
                return false
            end
            if not collectibleSnapshot(other) then
                diagnosticOnce("pair-inventory-api", "Pair switch skipped: cannot preserve partner inventory")
                return false
            end
        end
        return true
    end

    local function parkPartner(player, state, prior)
        if not prior then return end
        local key = tostring(prior.mainType)
        state.pairSnapshots[key] = prior.snapshot
        -- Carry the item's ownership while its original holder is parked. The
        -- rest of that partner's inventory remains in its own saved snapshot.
        local count = tonumber(prior.snapshot.collectibles[tostring(ITEM_ID)]) or 0
        if count > 0 then
            local before = getCollectibleCount(player, ITEM_ID)
            for _ = 1, count do safeCall(player, "AddCollectible", ITEM_ID, 0, false) end
            state.pairProxies[key] = (state.pairProxies[key] or 0) + math.max(0, getCollectibleCount(player, ITEM_ID) - before)
        end
    end

    local function removeFormerPartner(player, prior)
        if not prior or prior.mainType == 16 then return true end
        -- Reacquire a live wrapper after ChangePlayerType. Never call Remove on
        -- a stale userdata, the main player, or an unrelated co-op participant.
        for _, candidate in ipairs(getPlayers()) do
            if runtimePlayerKey(candidate) == prior.runtimeKey and playerExists(candidate)
                and getPlayerType(candidate) == prior.snapshot.playerType
                and runtimePlayerKey(candidate) ~= runtimePlayerKey(player) then
                local ok = pcall(PlayerManager.RemoveCoPlayer, candidate)
                if not ok then return false end
            end
        end
        for _, candidate in ipairs(getPlayers()) do
            if runtimePlayerKey(candidate) == prior.runtimeKey and playerExists(candidate) then return false end
        end
        return true
    end

    local function ensureNativePair(player)
        local kind = getPlayerType(player)
        if kind ~= 19 and kind ~= 35 then return true end
        if pairPartner(player) then return true end
        -- A surviving former partner can prevent native target-pair creation.
        -- Retry only after that exact former partner has been removed.
        safeCall(player, "ChangePlayerType", kind)
        return pairPartner(player) ~= nil
    end

    local function restorePartner(player, state, losingItem)
        local other = pairPartner(player)
        if not other then return end
        local key = tostring(getPlayerType(player))
        local saved = state.pairSnapshots[key]
        if not saved then return end -- First native creation supplies its kit.
        local desired = copyTable(saved.collectibles)
        local proxy = tonumber(state.pairProxies[key]) or 0
        local returned = math.min(proxy, getCollectibleCount(player, ITEM_ID))
        if proxy > 0 then
            for _ = 1, returned do safeCall(player, "RemoveCollectible", ITEM_ID) end
            desired[tostring(ITEM_ID)] = losingItem and 0 or returned
            state.pairProxies[key] = nil
        elseif losingItem then
            desired[tostring(ITEM_ID)] = 0
        end
        for _, slot in ipairs({ SLOT_PRIMARY, SLOT_SECONDARY, SLOT_POCKET }) do
            restoreSlot(other, slot, saved.slots[slot] or saved.slots[tostring(slot)])
        end
        local actual = collectibleSnapshot(other) or {}
        for id, count in pairs(actual) do
            for _ = 1, math.max(0, count - (desired[id] or 0)) do safeCall(other, "RemoveCollectible", tonumber(id)) end
        end
        for id, count in pairs(desired) do
            for _ = 1, math.max(0, count - getCollectibleCount(other, tonumber(id))) do
                safeCall(other, "AddCollectible", tonumber(id), 0, false)
            end
        end
        for _, slot in ipairs({ POCKET_PRIMARY, POCKET_SECONDARY }) do
            safeCall(other, "SetCard", slot, saved.pockets.cards[slot] or saved.pockets.cards[tostring(slot)] or 0)
            safeCall(other, "SetPill", slot, saved.pockets.pills[slot] or saved.pockets.pills[tostring(slot)] or 0)
        end
        for slot = 0, 1 do
            local current = numberCall(other, "GetTrinket", slot)
            if current ~= 0 then safeCall(other, "TryRemoveTrinket", current) end
        end
        for _, id in ipairs(saved.trinkets or {}) do if id ~= 0 then safeCall(other, "AddTrinket", id, false) end end
        local smelted = safeCall(other, "GetSmeltedTrinkets") or {}
        for id, counts in pairs(saved.smeltedTrinkets or {}) do
            local current = smelted[tonumber(id)] or smelted[tostring(id)] or {}
            for _, entry in ipairs({ {"trinketAmount", 0}, {"goldenTrinketAmount", 32768} }) do
                for _ = 1, math.max(0, (counts[entry[1]] or 0) - (current[entry[1]] or 0)) do
                    safeCall(other, "AddSmeltedTrinket", tonumber(id) + entry[2], false)
                end
            end
        end
        applyHealth(other, saved.health, profileForType(saved.playerType))
        state.pairSnapshots[key] = nil -- A live partner is now authoritative.
    end

    return {
        snapshotPartner = snapshotPartner,
        canSwitchPair = canSwitchPair,
        parkPartner = parkPartner,
        removeFormerPartner = removeFormerPartner,
        ensureNativePair = ensureNativePair,
        restorePartner = restorePartner,
    }
end
