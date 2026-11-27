-- Pure rules shared by enemy settlement, reward selection and the HUD.
return function(dependencies)
    local UNBOXING, EXPOSURE, HEAT = dependencies.Items.TrafficUnboxing, dependencies.Items.TrafficExposure, dependencies.Items.TrafficHeat
    local function returnChance(deathCount)
        return ({ 33, 22, 11 })[math.floor(tonumber(deathCount) or 0)] or 0
    end

    local function shouldReturn(roll, deathCount)
        return math.floor(tonumber(roll) or 100) < returnChance(deathCount)
    end

    local function trafficTier(traffic)
        traffic = math.max(0, math.floor(tonumber(traffic) or 0))
        if traffic >= 12 then return 3 end
        if traffic >= 8 then return 2 end
        if traffic >= 6 then return 1 end
        return 0
    end

    local function nextTrafficTarget(traffic)
        traffic = math.max(0, math.floor(tonumber(traffic) or 0))
        if traffic < 6 then return 6, 6 - traffic end
        if traffic < 8 then return 8, 8 - traffic end
        if traffic < 12 then return 12, 12 - traffic end
        return nil, 0
    end

    local function roomTraffic(chains)
        local maximum
        for _, chain in pairs(chains or {}) do
            local deaths = type(chain) == "number" and chain or type(chain) == "table" and tonumber(chain.deaths) or nil
            local excluded = type(chain) == "table" and chain.excluded == true
            if deaths and deaths > 0 and not excluded then maximum = maximum and math.max(maximum, deaths) or deaths end
        end
        return math.max(0, math.floor(maximum or 0))
    end

    local function rewardItemsForTier(tier)
        if tier == 1 then return { UNBOXING } end
        if tier == 2 then return { EXPOSURE } end
        if tier == 3 then return { EXPOSURE, HEAT } end
        return {}
    end

    local function rewardItems(traffic) return rewardItemsForTier(trafficTier(traffic)) end
    return { GetReturnChance = returnChance, ShouldReturn = shouldReturn, GetTier = trafficTier, GetNextTrafficTarget = nextTrafficTarget, GetRoomTraffic = roomTraffic, GetRewardItems = rewardItems, GetRewardItemsForTier = rewardItemsForTier }
end
