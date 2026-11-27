return function(Items, IsValidItemId, DebugLog)
local DEBUG_PRINT_ITEM_IDS = true
local function PrintItemDebugCommands()
    if not DEBUG_PRINT_ITEM_IDS then
        return
    end

    DebugLog("[neverbirth] Mod item console commands:")
    for itemKey, itemId in pairs(Items) do
        if IsValidItemId(itemId) then
            DebugLog("[neverbirth] " .. itemKey .. " id=" .. tostring(itemId) .. " | giveitem c" .. tostring(itemId) .. " | spawn 5.100." .. tostring(itemId))
        else
            DebugLog("[neverbirth] " .. itemKey .. " id not found")
        end
    end
end

PrintItemDebugCommands()

end
