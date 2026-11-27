-- Both boxes use special charge. Item identity and charge cap remain item policy.
return function(itemId, maxCharge, activeSlots)
    local function findSlot(player, preferredSlot)
        if not player or not player.GetActiveItem then return nil end
        if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == itemId then return preferredSlot end
        for _, slot in ipairs(activeSlots) do
            if player:GetActiveItem(slot) == itemId then return slot end
        end
        return nil
    end

    local function getCharge(player, slot)
        if player and player.GetActiveCharge then return player:GetActiveCharge(slot) or 0 end
        return 0
    end

    local function setCharge(player, slot, charge)
        if not player then return end
        local clampedCharge = math.max(0, math.min(charge or 0, maxCharge))
        if player.SetActiveCharge then
            player:SetActiveCharge(clampedCharge, slot)
        elseif clampedCharge <= 0 and player.DischargeActiveItem then
            player:DischargeActiveItem(slot)
        elseif clampedCharge >= maxCharge and player.FullCharge then
            player:FullCharge(slot)
        end
    end

    local function addCharge(player, slot, amount)
        if not player or not player.GetActiveItem or player:GetActiveItem(slot) ~= itemId
            or type(player.AddActiveCharge) ~= 'function' then return 0 end
        -- Force bypasses special charge's gate, not the native maximum.
        -- Only the currently owned slot is credited; the native accepted amount wins.
        return tonumber(player:AddActiveCharge(amount, slot, true, false, true)) or 0
    end

    return { FindSlot = findSlot, Get = getCharge, Set = setCharge, Add = addCharge }
end
