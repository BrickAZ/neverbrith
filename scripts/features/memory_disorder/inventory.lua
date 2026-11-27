-- Temporary starting components and permanent slot/pocket reconciliation.
return function(Neverbirth, context, deps)
    local diagnosticOnce = deps.diagnosticOnce
    local safeCall = deps.safeCall
    local numberCall = deps.numberCall
    local playerKey = deps.playerKey
    local getCollectibleCount = deps.getCollectibleCount
    local seedHash = deps.seedHash
    local SLOT_PRIMARY = deps.SLOT_PRIMARY
    local SLOT_SECONDARY = deps.SLOT_SECONDARY
    local SLOT_POCKET = deps.SLOT_POCKET
    local POCKET_PRIMARY = deps.POCKET_PRIMARY
    local POCKET_SECONDARY = deps.POCKET_SECONDARY

    local function slotSnapshot(player, slot)
        return {
            item = numberCall(player, "GetActiveItem", slot),
            charge = numberCall(player, "GetActiveCharge", slot),
            battery = numberCall(player, "GetBatteryCharge", slot),
        }
    end

    local function captureSlots(player)
        return {
            [SLOT_PRIMARY] = slotSnapshot(player, SLOT_PRIMARY),
            [SLOT_SECONDARY] = slotSnapshot(player, SLOT_SECONDARY),
            [SLOT_POCKET] = slotSnapshot(player, SLOT_POCKET),
        }
    end

    local function capturePockets(player)
        return {
            cards = {
                [POCKET_PRIMARY] = numberCall(player, "GetCard", POCKET_PRIMARY),
                [POCKET_SECONDARY] = numberCall(player, "GetCard", POCKET_SECONDARY),
            },
            pills = {
                [POCKET_PRIMARY] = numberCall(player, "GetPill", POCKET_PRIMARY),
                [POCKET_SECONDARY] = numberCall(player, "GetPill", POCKET_SECONDARY),
            },
        }
    end

    local function updatePermanentSlots(player, state)
        for _, slot in ipairs({ SLOT_PRIMARY, SLOT_SECONDARY, SLOT_POCKET }) do
            local current = slotSnapshot(player, slot)
            local temporary = state.temporaryActiveSlots[slot]
            if not temporary or current.item ~= temporary.id then
                state.permanentSlots[slot] = current
            end
        end
        for _, slot in ipairs({ POCKET_PRIMARY, POCKET_SECONDARY }) do
            local temporary = state.temporaryPocketCards[slot]
            local currentCard = numberCall(player, "GetCard", slot)
            local currentPill = numberCall(player, "GetPill", slot)
            if not temporary or (currentCard ~= temporary.card and currentPill ~= temporary.pill) then
                state.permanentPockets.cards[slot] = currentCard
                state.permanentPockets.pills[slot] = currentPill
            end
        end
    end

    local function reconcileTemporaryCopies(player, state)
        for itemId, temporaryCount in pairs(state.temporaryCopies) do
            local baseline = tonumber(state.permanentCounts[itemId]) or 0
            local actual = getCollectibleCount(player, tonumber(itemId) or itemId)
            local expected = baseline + temporaryCount
            if actual > expected then
                state.permanentCounts[itemId] = baseline + (actual - expected)
            elseif actual < expected then
                local missing = expected - actual
                local removedTemporary = math.min(temporaryCount, missing)
                state.temporaryCopies[itemId] = temporaryCount - removedTemporary
                missing = missing - removedTemporary
                if missing > 0 then state.permanentCounts[itemId] = math.max(0, baseline - missing) end
            end
        end
    end

    local function removeSlotItem(player, itemId, slot)
        if not itemId or itemId == 0 then return end
        safeCall(player, "RemoveCollectible", itemId, true, slot, false)
        if numberCall(player, "GetActiveItem", slot) == itemId then
            safeCall(player, "RemoveCollectibleFromSlot", slot)
        end
    end

    local function restoreSlot(player, slot, snapshot)
        snapshot = snapshot or { item = 0, charge = 0, battery = 0 }
        local current = numberCall(player, "GetActiveItem", slot)
        if current ~= 0 and current ~= snapshot.item then
            removeSlotItem(player, current, slot)
        end
        if snapshot.item and snapshot.item ~= 0 then
            local after = numberCall(player, "GetActiveItem", slot)
            if after ~= snapshot.item then
                safeCall(player, "AddCollectible", snapshot.item, snapshot.charge or 0, false, slot)
            end
            safeCall(player, "SetActiveCharge", (snapshot.charge or 0) + (snapshot.battery or 0), slot)
        end
    end

    local function removeTemporaryComponents(player, state)
        updatePermanentSlots(player, state)
        reconcileTemporaryCopies(player, state)

        for slot, temporary in pairs(state.temporaryActiveSlots) do
            local current = numberCall(player, "GetActiveItem", slot)
            if current == temporary.id then
                removeSlotItem(player, temporary.id, slot)
                local temporaryCount = tonumber(state.temporaryCopies[temporary.id]
                    or state.temporaryCopies[tostring(temporary.id)]) or 0
                state.temporaryCopies[tostring(temporary.id)] = nil
                if temporaryCount > 0 then state.temporaryCopies[temporary.id] = temporaryCount - 1 end
            end
        end
        for itemId, count in pairs(state.temporaryCopies) do
            for _ = 1, math.max(0, tonumber(count) or 0) do
                safeCall(player, "RemoveCollectible", tonumber(itemId) or itemId)
            end
        end
        for slot, temporary in pairs(state.temporaryPocketCards) do
            local card = numberCall(player, "GetCard", slot)
            local pill = numberCall(player, "GetPill", slot)
            if temporary.card and card == temporary.card then safeCall(player, "SetCard", slot, 0) end
            if temporary.pill and pill == temporary.pill then safeCall(player, "SetPill", slot, 0) end
        end

        state.temporaryCopies = {}
        state.permanentCounts = {}
        state.temporaryActiveSlots = {}
        state.temporaryPocketCards = {}

        for _, slot in ipairs({ SLOT_PRIMARY, SLOT_SECONDARY, SLOT_POCKET }) do
            restoreSlot(player, slot, state.permanentSlots[slot])
        end
        for _, slot in ipairs({ POCKET_PRIMARY, POCKET_SECONDARY }) do
            -- Cards and pills occupy the same native pocket. A zero setter also
            -- clears that pocket, so restore exactly one kind (or one empty slot).
            local card = state.permanentPockets.cards[slot] or 0
            if card ~= 0 then
                safeCall(player, "SetCard", slot, card)
            else
                safeCall(player, "SetPill", slot, state.permanentPockets.pills[slot] or 0)
            end
        end
    end

    local function temporaryCount(state, itemId)
        return tonumber(state.temporaryCopies[itemId] or state.temporaryCopies[tostring(itemId)]) or 0
    end

    local function recordTemporaryCopy(state, itemId, before, after)
        local added = math.max(0, (after or 0) - (before or 0))
        if added <= 0 then return 0 end
        state.permanentCounts[tostring(itemId)] = nil
        state.permanentCounts[itemId] = before or 0
        local tracked = temporaryCount(state, itemId)
        state.temporaryCopies[tostring(itemId)] = nil
        state.temporaryCopies[itemId] = tracked + added
        return added
    end

    local function addTemporaryCollectible(player, state, itemId, charge, slot)
        local before = getCollectibleCount(player, itemId)
        safeCall(player, "AddCollectible", itemId, charge or 0, false, slot)
        local after = getCollectibleCount(player, itemId)
        if after <= before then return false end
        recordTemporaryCopy(state, itemId, before, after)
        if slot ~= nil then state.temporaryActiveSlots[slot] = { id = itemId } end
        return true
    end

    local function addProfileComponents(player, state, profile)
        local required = {}
        local function nextRequired(itemId)
            required[itemId] = (required[itemId] or 0) + 1
            return required[itemId]
        end

        for _, itemId in ipairs(profile.collectibles or {}) do
            local desired = nextRequired(itemId)
            if temporaryCount(state, itemId) < desired then
                addTemporaryCollectible(player, state, itemId, 0, nil)
            end
        end
        for _, active in ipairs(profile.actives or {}) do
            local slot = active.slot or SLOT_PRIMARY
            local desired = nextRequired(active.id)
            if temporaryCount(state, active.id) < desired then
                addTemporaryCollectible(player, state, active.id, active.charge or 0, slot)
            else
                state.temporaryActiveSlots[slot] = { id = active.id }
                safeCall(player, "SetActiveCharge", active.charge or 0, slot)
            end
        end
        for _, active in ipairs(profile.pocketActives or {}) do
            local slot = active.slot or SLOT_POCKET
            local desired = nextRequired(active.id)
            if temporaryCount(state, active.id) < desired then
                local before = getCollectibleCount(player, active.id)
                safeCall(player, "SetPocketActiveItem", active.id, slot, false)
                local after = getCollectibleCount(player, active.id)
                if after > before then recordTemporaryCopy(state, active.id, before, after) end
            end
            state.temporaryActiveSlots[slot] = { id = active.id }
            safeCall(player, "SetActiveCharge", active.charge or 0, slot)
        end
        for slot, card in pairs(profile.pocketCards or {}) do
            safeCall(player, "SetCard", slot, card)
            state.temporaryPocketCards[slot] = { card = card }
        end
        if profile.randomPill then
            local pill = 0
            if context.GetRandomPill then
                pill = context.GetRandomPill(player, state.switchSerial) or 0
            elseif Game then
                local ok, value = pcall(function()
                    local game = Game()
                    local pool = game:GetItemPool()
                    return pool:GetPill(seedHash(playerKey(player) .. ":" .. state.switchSerial))
                end)
                if ok then pill = value or 0 end
            end
            if pill ~= 0 then
                safeCall(player, "SetPill", POCKET_PRIMARY, pill)
                state.temporaryPocketCards[POCKET_PRIMARY] = { pill = pill }
            end
        end
        if type(profile.onApply) == "function" then
            local ok, errorMessage = pcall(profile.onApply, player, state, context)
            if not ok then diagnosticOnce("profile-apply-" .. tostring(profile.id), "profile " .. tostring(profile.id) .. " apply failed: " .. tostring(errorMessage)) end
        end
    end

    return {
        captureSlots = captureSlots,
        capturePockets = capturePockets,
        updatePermanentSlots = updatePermanentSlots,
        reconcileTemporaryCopies = reconcileTemporaryCopies,
        restoreSlot = restoreSlot,
        removeTemporaryComponents = removeTemporaryComponents,
        recordTemporaryCopy = recordTemporaryCopy,
        addProfileComponents = addProfileComponents,
    }
end
