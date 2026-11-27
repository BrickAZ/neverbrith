-- Shared settlement order, positioning and distinct reward selection. The box
-- supplies the room policy and selector; a failed native spawn keeps legacy
-- consumption semantics, rather than silently inventing a retry contract.
return function(dependencies)
    local Shared, Ledger = dependencies.Shared, dependencies.Ledger
    local GetGame, GetRoom = Shared.GetGame, Shared.GetRoom
    local PickupEntity, CollectibleVariant = Shared.PickupEntity, Shared.CollectibleVariant
    return function()
        if not Ledger.HasPending() then return false end
        local game = GetGame()
        local room = GetRoom()
        if not game or not game.Spawn or not room or not room.GetType or room:GetType() ~= dependencies.RoomType then
            return false
        end
        local rewardCount = Ledger.Count()
        local center = room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
        local seed = room.GetSpawnSeed and room:GetSpawnSeed() or 0
        local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
        local selectedItems = {}
        for index = 1, rewardCount do
            local position = center
            if Vector then position = center + Vector((index - (rewardCount + 1) / 2) * 40, 0) end
            if room.FindFreePickupSpawnPosition then
                position = room:FindFreePickupSpawnPosition(position, 40, true, false)
            end
            local itemId = dependencies.Select(index, selectedItems)
            selectedItems[itemId] = true
            local reward = game:Spawn(PickupEntity, CollectibleVariant, position, velocity, nil, itemId, seed + index)
            dependencies.Log("[neverbirth][Boxes] reward box=" .. dependencies.Name .. " item=" .. itemId .. " spawned=" .. tostring(reward ~= nil))
        end
        Ledger.ClearPending()
        dependencies.Save()
        return true
    end
end
