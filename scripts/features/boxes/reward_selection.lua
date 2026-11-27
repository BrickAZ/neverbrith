-- One selection algorithm; each box owns its pool, quality and fallback policy.
return function(world)
    return function(policy)
        local function fallbackReward(baseSeed, rewardIndex, selectedItems)
            local items = policy.FallbackItems
            local listSize = #items
            if listSize <= 0 then return policy.EmptyFallback end
            local startIndex = ((tonumber(baseSeed) or 0) + (tonumber(rewardIndex) or 1) - 1) % listSize + 1
            local duplicateCandidate
            for offset = 0, listSize - 1 do
                local itemId = items[((startIndex + offset - 1) % listSize) + 1]
                if world.IsCollectibleQuality(itemId, policy.Quality) then
                    if not world.IsRewardAlreadySelected(selectedItems, itemId) then return itemId end
                    duplicateCandidate = duplicateCandidate or itemId
                end
            end
            return duplicateCandidate or items[startIndex] or policy.FinalFallback
        end

        return function(rewardIndex, selectedItems)
            local game = world.GetGame()
            local itemPool = game and game.GetItemPool and game:GetItemPool()
            local room = world.GetRoom()
            local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
            if not itemPool or not itemPool.GetCollectible then return fallbackReward(seed, rewardIndex, selectedItems) end
            local duplicateCandidate
            for attempt = 1, world.RewardAttempts do
                local itemId = itemPool:GetCollectible(policy.Pool, false, world.GetRewardSeed(seed, rewardIndex, attempt), world.NullItem)
                if world.IsCollectibleQuality(itemId, policy.Quality) then
                    if not world.IsRewardAlreadySelected(selectedItems, itemId) then return itemId end
                    duplicateCandidate = duplicateCandidate or itemId
                end
            end
            return duplicateCandidate or fallbackReward(seed, rewardIndex, selectedItems)
        end
    end
end
