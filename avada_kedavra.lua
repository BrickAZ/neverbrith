-- REPENTOGON 1.0.12a native Weapon bridge. No custom lasers, animation,
-- collision ticks, range, lifetime, or real C118/C222 inventory grants.
return function(mod, context)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local itemId = assert(context.ItemId)
    if itemId <= 0 then
        (context.DebugLog or Isaac.DebugString)("[Avada Kedavra] item lookup failed; module not enabled")
        return
    end
    local state = { states = {}, npcs = {}, collisions = {}, damageBefore = {}, pendingDeaths = {},
        nextCast = 0, seeded = false, nativeEffect = nil, traceEnabled = false, failures = {} }
    local MARK = "NeverbirthAvadaCast"
    local CHARGE_FRAMES = 30
    local shooting = {
        [ButtonAction.ACTION_SHOOTLEFT] = {-1, 0},
        [ButtonAction.ACTION_SHOOTRIGHT] = {1, 0},
        [ButtonAction.ACTION_SHOOTUP] = {0, -1},
        [ButtonAction.ACTION_SHOOTDOWN] = {0, 1},
    }
    local Queries = include("scripts.features.avada_kedavra.queries")(mod, {
        State = state,
        Context = context,
        itemId = itemId,
    })
    local Weapon = include("scripts.features.avada_kedavra.weapon")(mod, {
        Queries = Queries,
    })
    local Casts = include("scripts.features.avada_kedavra.casts")(mod, {
        State = state,
        Queries = Queries,
        Weapon = Weapon,
    })
    local Entities = include("scripts.features.avada_kedavra.entities")(mod, {
        State = state,
        MARK = MARK,
        Queries = Queries,
    })
    local Hits = include("scripts.features.avada_kedavra.hits")(mod, {
        State = state,
        Queries = Queries,
        Entities = Entities,
    })
    local Controls = include("scripts.features.avada_kedavra.controls")(mod, {
        State = state,
        CHARGE_FRAMES = CHARGE_FRAMES,
        shooting = shooting,
        Queries = Queries,
        Weapon = Weapon,
        Casts = Casts,
    })
    local Runtime = include("scripts.features.avada_kedavra.runtime")(mod, {
        State = state,
        Context = context,
        CHARGE_FRAMES = CHARGE_FRAMES,
        Queries = Queries,
        Weapon = Weapon,
        Casts = Casts,
        Entities = Entities,
        Hits = Hits,
    })
    mod.AvadaKedavra = {
        OwnsAttack = Queries.held,
        IsFailureDeath = function(p) local s=Queries.stateFor(p); return s and s.failed == true or false end,
        Status = function(p)
            local s, count = Queries.stateFor(p), 0
            if s then for _ in pairs(s.casts) do count=count+1 end end
            return {charge=s and Weapon.nativeCharge(s) or 0,casts=count,failed=s and s.failed or false,
                nativePasses=s and s.nativePasses or 0,pending=s and s.pending~=nil or false,
                phase=s and (s.failed and "failed" or s.phase) or "not_initialized",
                peakCharge=s and s.peakCharge or 0}
        end,
    }

    local function add(name, fn, priority, filter)
        assert(ModCallbacks[name], "Avada requires REPENTOGON callback " .. name)
        mod:AddPriorityCallback(ModCallbacks[name], priority or 0, fn, filter)
    end
    Controls.Installers.evaluateCache(add)
    Controls.Installers.prePlayer(add)
    Controls.Installers.postWeapon(add)
    Controls.Installers.inputAction(add)
    Queries.Installers.trackNpc(add)
    Entities.Installers.effectInit(add)
    Entities.Installers.preEffect(add)
    Entities.Installers.postEffect(add)
    Entities.Installers.laserInit(add)
    Entities.Installers.postFireBrimstone(add)
    Hits.Installers.preLaserCollision(add)
    Hits.Installers.postLaserCollision(add)
    Hits.Installers.preDamage(add)
    Hits.Installers.acceptedDamage(add)
    Hits.Installers.entityKilled(add)
    Hits.Installers.npcUpdated(add)
    Runtime.Installers.removed(add)
    Runtime.Installers.update(add)
    Runtime.Installers.newRoom(add)
    Runtime.Installers.reset(add)
    Runtime.Installers.reset2(add)
    Runtime.Installers.prePlayerRevive(add)
    Runtime.Installers.command(add)
    for _, callback in ipairs({"MC_POST_FIRE_TEAR","MC_POST_FIRE_KNIFE","MC_POST_FIRE_BONE_CLUB","MC_POST_FIRE_SWORD","MC_POST_FIRE_BOMB"}) do
        Entities.Installers.suppressForeign(add, callback)
    end
end
