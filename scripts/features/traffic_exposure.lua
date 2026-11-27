-- Owns the current-room pool reward and its original fallback.
return function(dependencies)
local EXPOSURE, spawnPedestal, IsValidItemId = dependencies.ItemId, dependencies.SpawnPedestal, dependencies.IsValidItemId
    local function exposure(position)
        local game = Game(); local room = game:GetRoom(); local pool = game:GetItemPool()
        if not room or not pool or not pool.GetPoolForRoom or not pool.GetCollectible then spawnPedestal(EXPOSURE, position); return false end
        local roomType = room.GetType and room:GetType() or 0; local seed = room.GetSpawnSeed and room:GetSpawnSeed() or 0
        local okPool, poolType = pcall(function() return pool:GetPoolForRoom(roomType, seed) end)
        if not okPool or type(poolType) ~= "number" or poolType < 0 then spawnPedestal(EXPOSURE, position); return false end
        local okItem, itemId = pcall(function() return pool:GetCollectible(poolType, true, seed, (CollectibleType and CollectibleType.COLLECTIBLE_BREAKFAST) or 25) end)
        if not okItem or not IsValidItemId(itemId) then spawnPedestal(EXPOSURE, position); return false end
        spawnPedestal(itemId, position); return true
    end

return { Grant = exposure }
end
