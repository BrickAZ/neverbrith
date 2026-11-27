-- Private ledger ownership for Annihilation.
return function(Neverbirth, deps)
    local runtime = deps.State
    local FIREDELAY_CACHE = deps.Config.FIREDELAY_CACHE
    local RANGE_CACHE = deps.Config.RANGE_CACHE
    local entityKey = deps.Queries.entityKey
    local toNpc = deps.Queries.toNpc
    local isHostileNpc = deps.Queries.isHostileNpc
    local getRoomEntities = deps.Queries.getRoomEntities

    local function getState(player)
        local key = entityKey(player)
        local state = key and runtime.states[key]
        if state then state.player = player end
        return state
    end

    local function anyStateActive()
        return next(runtime.states) ~= nil
    end

    local function trackNpc(entity)
        local npc = toNpc(entity)
        if npc and isHostileNpc(npc, false) then
            local key = entityKey(npc)
            if not key then return nil end
            runtime.roomNpcs[key] = npc
            return npc
        end
        return nil
    end

    local function seedRoomNpcs()
        for _, entity in ipairs(getRoomEntities()) do trackNpc(entity) end
    end

    local function refreshTemporaryCaches(player)
        if not player or type(player.AddCacheFlags) ~= "function" or type(player.EvaluateItems) ~= "function" then
            return
        end
        local flags = 0
        if FIREDELAY_CACHE then flags = flags | FIREDELAY_CACHE end
        if RANGE_CACHE then flags = flags | RANGE_CACHE end
        if flags == 0 then return end
        pcall(player.AddCacheFlags, player, flags)
        pcall(player.EvaluateItems, player)
    end

    return {
        getState = getState,
        anyStateActive = anyStateActive,
        trackNpc = trackNpc,
        seedRoomNpcs = seedRoomNpcs,
        refreshTemporaryCaches = refreshTemporaryCaches,
    }
end
