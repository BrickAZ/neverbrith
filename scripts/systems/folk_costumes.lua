return function(Neverbirth, dependencies)
    function Neverbirth:TryRemoveCollectibleCostume(player, itemId)
        if not player or not itemId or not Isaac or not Isaac.GetItemConfig then
            return
        end
        local ok, config = pcall(function()
            local itemConfig = Isaac.GetItemConfig()
            return itemConfig and itemConfig.GetCollectible and itemConfig:GetCollectible(itemId) or nil
        end)
        if not ok or not config then
            return
        end
        if player.TryRemoveCollectibleCostume then
            pcall(function() player:TryRemoveCollectibleCostume(config, true) end)
            pcall(function() player:TryRemoveCollectibleCostume(config, false) end)
        end
        if player.RemoveCostume then
            pcall(function() player:RemoveCostume(config) end)
        end
    end
end
