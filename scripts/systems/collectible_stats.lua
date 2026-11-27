return function(IsValidItemId)
    local AddTears = include("scripts.systems.fire_rate")
    local function itemCount(player, itemId)
        if not player or not player.GetCollectibleNum or not IsValidItemId(itemId) then
            return 0
        end
        local ok, count = pcall(function() return player:GetCollectibleNum(itemId) end)
        return ok and math.max(0, math.floor(tonumber(count) or 0)) or 0
    end

    local function addTears(maxFireDelay, amount)
        return AddTears(maxFireDelay, amount)
    end

    local function PlayerHasCollectible(player, itemId)
        if not player or not IsValidItemId(itemId) then
            return false
        end

        if player.HasCollectible then
            local ok, result = pcall(function()
                return player:HasCollectible(itemId)
            end)
            if ok then
                return result == true
            end
        end

        if player.GetCollectibleNum then
            local ok, count = pcall(function()
                return player:GetCollectibleNum(itemId)
            end)
            return ok and (tonumber(count) or 0) > 0
        end

        return false
    end

return { Count = itemCount, Has = PlayerHasCollectible, AddTears = addTears }
end
