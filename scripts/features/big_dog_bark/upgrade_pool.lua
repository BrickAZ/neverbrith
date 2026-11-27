-- Private upgrade_pool responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local rerollingUpgrade = false
    local WIND_CHARGE_ROD_ID = deps.WIND_CHARGE_ROD_ID
    local ECHO_SHARD_ID = deps.ECHO_SHARD_ID
    local debugLog = deps.Queries.debugLog
    local getPlayers = deps.Queries.getPlayers
    local hasBigDogActive = deps.Queries.hasBigDogActive

    local function isDogUpgrade(itemId)
        return (WIND_CHARGE_ROD_ID > 0 and itemId == WIND_CHARGE_ROD_ID)
            or (ECHO_SHARD_ID > 0 and itemId == ECHO_SHARD_ID)
    end

    local function postGetCollectible(_, selected, poolType, decrease, seed)
        if rerollingUpgrade or not isDogUpgrade(selected) then
            return nil
        end
        -- Shared pool: read current active slots, with no permanent unlock flag.
        for _, player in ipairs(getPlayers()) do
            if hasBigDogActive(player) then return nil end
        end

        local fallback = (CollectibleType and CollectibleType.COLLECTIBLE_BREAKFAST) or 25
        local rejected = {}
        if decrease then rejected[selected] = true end
        local itemPool
        rerollingUpgrade = true
        local ok, replacement = pcall(function()
            itemPool = Game():GetItemPool()
            -- Preserve the requested pool (including native Chaos handling)
            -- and depletion. Retry seeds never consume the global RNG stream.
            local retrySeed = math.floor(tonumber(seed) or 0) % 2147483647
            for attempt = 1, 32 do
                retrySeed = retrySeed % 2147483646 + 1
                local candidate = itemPool:GetCollectible(poolType, decrease, retrySeed)
                if not isDogUpgrade(candidate) then return candidate end
                if decrease then rejected[candidate] = true end
            end
            return fallback
        end)
        rerollingUpgrade = false

        -- These upgrades have one-draw depletion (weight/decreaseBy = 1).
        -- Restore rejected decreasing draws only, after finding the reward;
        -- otherwise they could run out before anyone obtains the dog.
        -- Allowed draws and nondecreasing previews must never be reset.
        -- ResetCollectible is supported by the required REPENTOGON 1.0.12a.
        if itemPool then
            for itemId in pairs(rejected) do
                local restored, err = pcall(itemPool.ResetCollectible, itemPool, itemId)
                if not restored then debugLog("upgrade pool restore failed: " .. tostring(err)) end
            end
        end
        if not ok then
            debugLog("upgrade pool draw failed: " .. tostring(replacement))
            return fallback
        end
        return tonumber(replacement) or fallback
    end
    function callbackInstallers.postGetCollectible()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, postGetCollectible)
    end

    return {
        isDogUpgrade = isDogUpgrade,
        postGetCollectible = postGetCollectible,
        Installers = callbackInstallers,
    }
end
