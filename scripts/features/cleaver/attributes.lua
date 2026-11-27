-- Private attributes ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local lifetime = deps.Lifetime

    local function RefreshCleaverCache(player)
        if not player or not player.AddCacheFlags or not CacheFlag
            or (player.Exists and not player:Exists()) then return end
        local flags = 0
        for _, name in ipairs({ "CACHE_DAMAGE", "CACHE_FIREDELAY", "CACHE_RANGE", "CACHE_SHOTSPEED" }) do
            flags = flags | (CacheFlag[name] or 0)
        end
        if flags ~= 0 then
            player:AddCacheFlags(flags)
            if player.EvaluateItems then player:EvaluateItems() end
        end
    end

    local function Clamp(value, minimum, maximum)
        return math.max(minimum, math.min(maximum, tonumber(value) or 0))
    end

    local function GetConversion(state)
        local config = Neverbirth.Cleaver.Config
        local caps = config.ConversionCaps
        local tears = Clamp(0.40 * ((tonumber(state.rawTears) or config.BaseTears) - config.BaseTears), caps.minimum, caps.maximum)
        local range = Clamp(0.10 * ((tonumber(state.rawRange) or config.BaseRange) - config.BaseRange), caps.minimum, caps.maximum)
        local shotSpeed = Clamp(0.50 * ((tonumber(state.rawShotSpeed) or config.BaseShotSpeed) - config.BaseShotSpeed), caps.minimum, caps.maximum)
        local positive = math.min(caps.positiveTotal, math.max(0, tears) + math.max(0, range) + math.max(0, shotSpeed))
        local negative = math.min(0, tears) + math.min(0, range) + math.min(0, shotSpeed)
        return positive + negative
    end

    local function QueueDamageRefresh(player, state)
        if player and state then
            state.needsDamageRefresh = true
        end
    end

    local function GetRawTears(maxFireDelay)
        local delay = tonumber(maxFireDelay)
        if delay == nil or delay <= -0.99 then
            return Neverbirth.Cleaver.Config.BaseTears
        end
        return 30 / (delay + 1)
    end

    local function GetMaxFireDelay(tears)
        return 30 / math.max(0.01, tears) - 1
    end

    local function CaptureRawCacheStat(state, rawKey, appliedKey, value, fallback)
        value = tonumber(value)
        if value == nil then return tonumber(state[rawKey]) or fallback end
        local previousApplied = tonumber(state[appliedKey])
        if previousApplied ~= nil and math.abs(value - previousApplied) <= 0.0001 and state[rawKey] ~= nil then
            return tonumber(state[rawKey]) or fallback
        end
        state[rawKey] = value
        return value
    end

    function Neverbirth:EvaluateCleaverCharacter(player, cacheFlag)
        if not lifetime.runtimeActive or lifetime.restoringCache then return end
        if not Neverbirth.Cleaver.IsEnabled(player) or not CacheFlag then return end
        local state = Neverbirth.Cleaver.GetState(player)
        local config = Neverbirth.Cleaver.Config
        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            local rawDamage = CaptureRawCacheStat(state, "rawDamage", "appliedDamage", player.Damage, config.IsaacBaseDamage)
            player.Damage = config.BaseDamage + (rawDamage - config.IsaacBaseDamage) + GetConversion(state)
            state.appliedDamage = player.Damage
        elseif cacheFlag == CacheFlag.CACHE_FIREDELAY and player.MaxFireDelay ~= nil then
            local rawDelay = CaptureRawCacheStat(state, "rawMaxFireDelay", "appliedMaxFireDelay", player.MaxFireDelay, GetMaxFireDelay(config.BaseTears))
            state.rawTears = GetRawTears(rawDelay)
            player.MaxFireDelay = GetMaxFireDelay(math.min(state.rawTears, config.BaseTears))
            state.appliedMaxFireDelay = player.MaxFireDelay
            QueueDamageRefresh(player, state)
        elseif cacheFlag == CacheFlag.CACHE_RANGE and player.TearRange ~= nil then
            local rawRangePixels = CaptureRawCacheStat(state, "rawRangePixels", "appliedRangePixels", player.TearRange, config.BaseRange * 40)
            state.rawRange = rawRangePixels / 40
            player.TearRange = math.min(state.rawRange, config.BaseRange) * 40
            state.appliedRangePixels = player.TearRange
            QueueDamageRefresh(player, state)
        elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED and player.ShotSpeed ~= nil then
            state.rawShotSpeed = CaptureRawCacheStat(state, "rawShotSpeed", "appliedShotSpeed", player.ShotSpeed, config.BaseShotSpeed)
            player.ShotSpeed = math.min(state.rawShotSpeed, config.BaseShotSpeed)
            state.appliedShotSpeed = player.ShotSpeed
            QueueDamageRefresh(player, state)
        end
    end
    function Installers.Cache()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateCleaverCharacter)
    end

    return {
        RefreshCleaverCache = RefreshCleaverCache,
        Clamp = Clamp,
        GetConversion = GetConversion,
        QueueDamageRefresh = QueueDamageRefresh,
        GetRawTears = GetRawTears,
        GetMaxFireDelay = GetMaxFireDelay,
        CaptureRawCacheStat = CaptureRawCacheStat,
        EvaluateCleaverCharacter = Neverbirth.EvaluateCleaverCharacter,
        Installers = Installers,
    }
end
