-- Private state responsibilities for bomb_suit; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = {active={}, before={}, shootScopes={}, bombScopes={}, pendingScatter={}, scopeFrame=-1, ready=false}
    local ID = context.ItemId
    local Shooting = deps.Shooting

    local function key(entity)
        if not entity then return nil end
        if GetPtrHash then return tostring(GetPtrHash(entity)) end
        return tostring(entity.InitSeed)
    end

    local function exists(entity) return entity and (not entity.Exists or entity:Exists()) end

    local function alive(player)
        return exists(player) and not player:IsDead() and not player:HasMortalDamage()
    end

    local function held(player) return alive(player) and player:HasCollectible(ID) end

    local function refresh(player)
        if exists(player) then player:AddCacheFlags(CacheFlag.CACHE_SPEED); player:EvaluateItems() end
    end

    local function restoreShoot(k)
        Shooting.Restore(data.shootScopes, k, exists)
    end

    local function stop(k)
        local state = data.active[k]; data.active[k], data.before[k] = nil, nil
        restoreShoot(k)
        if state then refresh(state.player) end
    end

    local function clear()
        local keys = {}; for k in pairs(data.active) do keys[#keys+1] = k end
        for _, k in ipairs(keys) do stop(k) end
        for k in pairs(data.shootScopes) do restoreShoot(k) end
        data.before = {}
        data.bombScopes, data.pendingScatter, data.scopeFrame = {}, {}, -1
    end
    function callbackInstallers.clear()
        return mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD, clear)
    end

    local function stateFor(player)
        local k = key(player); local state = k and data.active[k]
        if state and not held(player) then stop(k); return nil end
        return data.ready and state or nil
    end

    return {
        Data = data,
        Installers = callbackInstallers,
        key = key,
        exists = exists,
        alive = alive,
        held = held,
        refresh = refresh,
        restoreShoot = restoreShoot,
        stop = stop,
        clear = clear,
        stateFor = stateFor,
    }
end
