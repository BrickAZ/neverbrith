-- Private hits ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local state = deps.State
    local trace = deps.Queries.trace
    local key = deps.Queries.key
    local sameEntity = deps.Queries.sameEntity
    local frame = deps.Queries.frame
    local hostile = deps.Queries.hostile
    local castOf = deps.Entities.castOf

    local function snapshotDamage(target)
        return {mortal=target:HasMortalDamage(), hp=target.HitPoints,
            eligible=hostile(target, false), frame=frame()}
    end

    local function preLaserCollision(_, laser, target)
        local cast = castOf(laser)
        if not cast or not hostile(target, false) then return end
        -- 1.0.12a passes the laser's parent as Source, so keep the exact
        -- collision receipt. Compare engine identity, not Lua wrapper identity.
        local c = snapshotDamage(target)
        c.cast, c.laser = cast, laser
        state.collisions[key(target)] = c
    end
    function callbackInstallers.preLaserCollision(add)
        return add("MC_PRE_LASER_COLLISION",preLaserCollision,1000)
    end

    local function preDamage(_, target)
        if next(state.states) == nil or not target:ToNPC() then return end
        state.damageBefore[key(target)] = snapshotDamage(target)
    end
    function callbackInstallers.preDamage(add)
        return add("MC_ENTITY_TAKE_DMG",preDamage,1000)
    end

    local function clearDeath(targetKey)
        local receipt = state.pendingDeaths[targetKey]
        if receipt then
            receipt.cast.pendingDeaths[targetKey] = nil
            state.pendingDeaths[targetKey] = nil
        end
    end

    local function confirmDeath(targetKey)
        local receipt = state.pendingDeaths[targetKey]
        if not receipt then return end
        if not receipt.cast.cancelled then
            receipt.cast.success = true
            trace("cast " .. receipt.cast.id .. " confirmed direct kill")
        end
        clearDeath(targetKey)
    end

    local function acceptedDamage(_, target, amount, flags, source)
        if next(state.states) == nil or not target:ToNPC() then return end
        local targetKey = key(target)
        local c = state.collisions[targetKey]
        if c and c.frame ~= frame() then c = nil end
        local before = state.damageBefore[targetKey] or c
        state.damageBefore[targetKey] = nil
        if amount <= 0 or (flags & (DamageFlag.DAMAGE_POISON_BURN | DamageFlag.DAMAGE_FAKE)) ~= 0 then return end
        if not before or not before.eligible or before.mortal or before.hp <= 0 then return end
        local src = source and source.Entity
        local cast = castOf(src)
        if not cast and c and (sameEntity(src, c.cast.state.player) or sameEntity(src, c.laser)) then cast = c.cast end
        if not cast or cast.cancelled then return end
        -- TakeDamage queues damage; HitPoints often stays unchanged until
        -- the next entity update. Only a new lethal transition owns a kill.
        if not target:HasMortalDamage() and not target:IsDead() and target.HitPoints > 0 then return end
        clearDeath(targetKey)
        state.pendingDeaths[targetKey] = {cast=cast, target=target, updates=0}
        cast.pendingDeaths[targetKey] = true
        trace("cast " .. cast.id .. " accepted lethal hit; awaiting death")
        if before.killed or target:IsDead() or target.HitPoints <= 0 then confirmDeath(targetKey) end
    end
    function callbackInstallers.acceptedDamage(add)
        return add("MC_POST_ENTITY_TAKE_DMG",acceptedDamage,1000)
    end

    local function postLaserCollision(_, laser, target)
        local c = state.collisions[key(target)]
        if c and sameEntity(c.laser, laser) then state.collisions[key(target)] = nil end
    end
    function callbackInstallers.postLaserCollision(add)
        return add("MC_POST_LASER_COLLISION",postLaserCollision,1000)
    end

    local function entityKilled(_, target)
        if not target:ToNPC() then return end
        local targetKey = key(target)
        -- Also handle a synchronous native kill before POST_TAKE_DMG.
        if state.damageBefore[targetKey] then state.damageBefore[targetKey].killed = true end
        confirmDeath(targetKey)
    end
    function callbackInstallers.entityKilled(add)
        return add("MC_POST_ENTITY_KILL",entityKilled,1000)
    end

    local function npcUpdated(_, target)
        local targetKey = key(target)
        local receipt = state.pendingDeaths[targetKey]
        if not receipt then return end
        if target:IsDead() or target.HitPoints <= 0 then
            confirmDeath(targetKey)
        else
            receipt.updates = receipt.updates + 1
            -- The native buffer resolves on an entity update. A surviving
            -- shield/phase is not a kill; do not retain stale credit forever.
            if not target:HasMortalDamage() or receipt.updates >= 2 then clearDeath(targetKey) end
        end
    end
    function callbackInstallers.npcUpdated(add)
        return add("MC_NPC_UPDATE",npcUpdated,1000)
    end

    return {
        snapshotDamage = snapshotDamage,
        preLaserCollision = preLaserCollision,
        preDamage = preDamage,
        clearDeath = clearDeath,
        confirmDeath = confirmDeath,
        acceptedDamage = acceptedDamage,
        postLaserCollision = postLaserCollision,
        entityKilled = entityKilled,
        npcUpdated = npcUpdated,
        Installers = callbackInstallers,
    }
end
