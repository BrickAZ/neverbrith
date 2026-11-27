-- Existing enum slots only. A missing enum uses the original four-slot fallback;
-- a partial enum must NOT synthesize its missing members.
return function()
    if not ActiveSlot then return { 0, 1, 2, 3 } end
    local slots = {}
    for _, name in ipairs({ "SLOT_PRIMARY", "SLOT_SECONDARY", "SLOT_POCKET", "SLOT_POCKET2" }) do
        if ActiveSlot[name] ~= nil then slots[#slots + 1] = ActiveSlot[name] end
    end
    return slots
end
