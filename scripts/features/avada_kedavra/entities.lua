-- Private entities ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local state = deps.State
    local MARK = deps.MARK
    local trace = deps.Queries.trace
    local exists = deps.Queries.exists
    local key = deps.Queries.key
    local sameEntity = deps.Queries.sameEntity
    local held = deps.Queries.held
    local stateFor = deps.Queries.stateFor

    local function directOwner(e)
        if not e then return nil end
        return (e.SpawnerEntity and e.SpawnerEntity:ToPlayer())
            or (e.Parent and e.Parent:ToPlayer())
    end

    local function castOf(e)
        if not e then return nil end
        local marker = e:GetData()[MARK]
        if marker then
            local s = state.states[marker.owner]
            return s and s.casts[marker.id]
        end
    end

    local function mark(e, cast)
        if not exists(e) or not cast or cast.cancelled then return end
        e:GetData()[MARK] = {owner=key(cast.state.player),id=cast.id}
        cast.entities[key(e)] = e
        cast.outputSeen = true
        e.CollisionDamage = cast.damage
        trace("cast " .. cast.id .. " native entity " .. e.Type .. "." .. e.Variant)
    end

    local function effectInit(_, e)
        if e.Variant ~= EffectVariant.BRIMSTONE_SWIRL then return end
        local parentCast = castOf(e.Parent) or castOf(e.SpawnerEntity)
        if parentCast then
            parentCast.rootSeen = true
            mark(e, parentCast)
            return
        end
        local p = directOwner(e)
        local s = p and stateFor(p)
        if s and s.pending then
            s.pending.rootSeen = true
            mark(e, s.pending)
        end
    end
    function callbackInstallers.effectInit(add)
        return add("MC_POST_EFFECT_INIT",effectInit,-1000,EffectVariant.BRIMSTONE_SWIRL)
    end

    local function preEffect(_, e)
        if not castOf(e) then effectInit(nil, e) end
        local cast = castOf(e)
        if cast then
            e.CollisionDamage = cast.damage
            state.nativeEffect = e
        end
    end
    function callbackInstallers.preEffect(add)
        return add("MC_PRE_EFFECT_UPDATE",preEffect,-1000,EffectVariant.BRIMSTONE_SWIRL)
    end

    local function postEffect(_, e)
        if sameEntity(state.nativeEffect, e) then state.nativeEffect = nil end
    end
    function callbackInstallers.postEffect(add)
        return add("MC_POST_EFFECT_UPDATE",postEffect,1000,EffectVariant.BRIMSTONE_SWIRL)
    end

    local function laserInit(_, laser, initialized)
        local cast = castOf(laser) or castOf(laser.Parent) or castOf(laser.SpawnerEntity)
        if not cast and state.nativeEffect then
            local candidate = castOf(state.nativeEffect)
            if candidate and sameEntity(directOwner(laser), candidate.state.player) then cast = candidate end
        end
        if not cast and initialized then
            local p = directOwner(laser)
            local s = p and stateFor(p)
            -- A native primary output may be initialized before its swirl.
            -- The base Weapon callback can already have run. Keep ownership
            -- open for this armed release while the original laser's first
            -- native update creates and attaches the swirl.
            if s and s.pending then cast = s.pending end
        end
        if cast then
            if laser.Variant ~= LaserVariant.THICK_RED then
                -- Native secondary Tech/Tech-X combinations must not acquire a
                -- castId merely because the owning swirl was updating.
                laser:Remove()
                return
            end
            mark(laser, cast)
            return
        end
        -- Defensive event-level guard, secondary to the input/native Weapon
        -- override. Do not touch familiar/teammate attacks.
        -- INIT can run before Parent/SpawnerEntity is populated; do not delete
        -- the native output before POST_FIRE_BRIMSTONE can identify it.
        local p = directOwner(laser)
        if initialized and p and held(p) then laser:Remove() end
    end
    function callbackInstallers.laserInit(add)
        return add("MC_POST_LASER_INIT",laserInit,-1000)
    end

    local function suppressForeign(_, attack)
        local p = directOwner(attack)
        if p and held(p) and not castOf(attack) then attack:Remove() end
    end
    function callbackInstallers.suppressForeign(add, callback)
        return add(callback,suppressForeign,-1000)
    end

    function callbackInstallers.postFireBrimstone(add)
        add("MC_POST_FIRE_BRIMSTONE",function(_, laser) laserInit(nil, laser, true) end,-1000)
    end

    return {
        directOwner = directOwner,
        castOf = castOf,
        mark = mark,
        effectInit = effectInit,
        preEffect = preEffect,
        postEffect = postEffect,
        laserInit = laserInit,
        suppressForeign = suppressForeign,
        Installers = callbackInstallers,
    }
end
