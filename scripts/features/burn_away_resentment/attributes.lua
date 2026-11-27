-- Private attributes ownership for Burn Away the Resentment.
return function(Neverbirth, deps)
    local Installers = {}
    local Config = deps.Config
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local Queries = deps.Queries

    local function RefreshCache(player)
        if not player or not player.AddCacheFlags or not CacheFlag then
            return
        end
        local flags = 0
        if CacheFlag.CACHE_DAMAGE then flags = flags | CacheFlag.CACHE_DAMAGE end
        if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
        if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
        if flags ~= 0 then
            player:AddCacheFlags(flags)
            if player.EvaluateItems then
                player:EvaluateItems()
            end
        end
    end

    function Neverbirth:EvaluateBurnAwayResentment(player, cacheFlag)
        if not Queries.PlayerHas(player) or not CacheFlag then
            return
        end
        local state = Neverbirth.BurnAwayResentment.states[GetFolkPlayerKey(player)]
        if type(state) ~= "table" then
            return
        end
        if cacheFlag == CacheFlag.CACHE_SPEED and player.MoveSpeed ~= nil then
            local penalty = (tonumber(state.currentLayers) or 0) * Config.SpeedPenaltyPerLayer
            player.MoveSpeed = math.max(Config.MinimumSpeed, player.MoveSpeed - penalty)
        elseif cacheFlag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + (tonumber(state.currentFloorClarity) or 0) * Config.DamagePerClarity
        elseif cacheFlag == CacheFlag.CACHE_FIREDELAY and player.MaxFireDelay ~= nil then
            player.MaxFireDelay = player.MaxFireDelay - (tonumber(state.currentFloorClarity) or 0) * Config.TearsPerClarity
        end
    end

    function Installers.Cache()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateBurnAwayResentment)
    end

    return {
        RefreshCache = RefreshCache,
        EvaluateBurnAwayResentment = Neverbirth.EvaluateBurnAwayResentment,
        Installers = Installers,
    }
end
