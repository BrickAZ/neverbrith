-- Private queries ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local state = deps.State
    local context = deps.Context
    local itemId = deps.itemId

    local function log(text)
        (context.DebugLog or Isaac.DebugString)("[Avada Kedavra] " .. text)
    end

    local function failOnce(kind)
        if state.failures[kind] then return end
        state.failures[kind] = true
        log("UNVERIFIED native bridge: " .. kind .. "; no substitute attack or failure death was manufactured")
    end

    local function trace(text) if state.traceEnabled then log(text) end end

    local function exists(e) return e and e:Exists() end

    local function key(e) return tostring(GetPtrHash(e)) .. ":" .. tostring(e.InitSeed) end

    local function sameEntity(a, b) return a and b and key(a) == key(b) end

    local function frame() return Game():GetFrameCount() end

    local function held(p) return exists(p) and p:HasCollectible(itemId) end

    local function ghost(p) return p.IsCoopGhost and p:IsCoopGhost() end

    local function hostile(e, allowDead)
        return exists(e) and e:ToNPC() and (allowDead or not e:IsDead())
            and e:IsActiveEnemy(false) and (allowDead or e:IsVulnerableEnemy())
            and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY | EntityFlag.FLAG_CHARM)
    end

    local function trackNpc(_, npc)
        if exists(npc) and npc:ToNPC() then state.npcs[key(npc)] = npc end
    end
    function callbackInstallers.trackNpc(add)
        return add("MC_POST_NPC_INIT",trackNpc)
    end

    local function seedNpcs()
        if state.seeded then return end
        state.seeded = true
        -- One room snapshot on first acquisition / room entry, never per frame.
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            if e:ToNPC() then trackNpc(nil, e) end
        end
    end

    local function hasEnemy()
        for k, e in pairs(state.npcs) do
            if not exists(e) then state.npcs[k] = nil
            elseif hostile(e, false) then return true end
        end
        return false
    end

    local function stateFor(p)
        if next(state.states) == nil then return nil end
        return p and state.states[key(p)]
    end

    return {
        log = log,
        failOnce = failOnce,
        trace = trace,
        exists = exists,
        key = key,
        sameEntity = sameEntity,
        frame = frame,
        held = held,
        ghost = ghost,
        hostile = hostile,
        trackNpc = trackNpc,
        seedNpcs = seedNpcs,
        hasEnemy = hasEnemy,
        stateFor = stateFor,
        Installers = callbackInstallers,
    }
end
