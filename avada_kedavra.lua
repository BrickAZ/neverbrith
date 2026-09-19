-- REPENTOGON 1.0.12a native Weapon bridge. No custom lasers, animation,
-- collision ticks, range, lifetime, or real C118/C222 inventory grants.
return function(mod, context)
    local itemId = assert(context.ItemId)
    if itemId <= 0 then
        (context.DebugLog or Isaac.DebugString)("[Avada Kedavra] item lookup failed; module not enabled")
        return
    end
    local states, npcs, collisions = {}, {}, {}
    local damageBefore, pendingDeaths = {}, {}
    local nextCast, seeded, nativeEffect = 0, false, nil
    local traceEnabled, failures = false, {}
    local MARK = "NeverbirthAvadaCast"
    local CHARGE_FRAMES = 30
    local shooting = {
        [ButtonAction.ACTION_SHOOTLEFT] = {-1, 0},
        [ButtonAction.ACTION_SHOOTRIGHT] = {1, 0},
        [ButtonAction.ACTION_SHOOTUP] = {0, -1},
        [ButtonAction.ACTION_SHOOTDOWN] = {0, 1},
    }
    local function log(text)
        (context.DebugLog or Isaac.DebugString)("[Avada Kedavra] " .. text)
    end
    local function failOnce(kind)
        if failures[kind] then return end
        failures[kind] = true
        log("UNVERIFIED native bridge: " .. kind .. "; no substitute attack or failure death was manufactured")
    end
    local function trace(text) if traceEnabled then log(text) end end
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
        if exists(npc) and npc:ToNPC() then npcs[key(npc)] = npc end
    end
    local function seedNpcs()
        if seeded then return end
        seeded = true
        -- One room snapshot on first acquisition / room entry, never per frame.
        for _, e in ipairs(Isaac.GetRoomEntities()) do
            if e:ToNPC() then trackNpc(nil, e) end
        end
    end
    local function hasEnemy()
        for k, e in pairs(npcs) do
            if not exists(e) then npcs[k] = nil
            elseif hostile(e, false) then return true end
        end
        return false
    end
    local function stateFor(p)
        if next(states) == nil then return nil end
        return p and states[key(p)]
    end
    local function nativeCharge(s)
        local p = s.player
        local w = exists(p) and p:GetWeapon(1)
        return w and w:GetWeaponType() == WeaponType.WEAPON_BRIMSTONE and w:GetCharge() or 0
    end
    local function resetCharge(s)
        -- Only explicit cancellation writes charge. Ordinary charging, full
        -- charge feedback, aim changes and release belong to native Fire.
        local p = s.player
        local w = s.ownsWeapon and exists(p) and p:GetWeapon(1)
        if w and w:GetWeaponType() == WeaponType.WEAPON_BRIMSTONE then w:SetCharge(0) end
    end
    local function clearAttacks(s)
        for _, cast in pairs(s.casts) do
            cast.cancelled = true
            for targetKey in pairs(cast.pendingDeaths) do pendingDeaths[targetKey] = nil end
            for _, e in pairs(cast.entities) do if exists(e) then e:Remove() end end
        end
        s.casts, s.pending = {}, nil
        resetCharge(s)
        s.allowFire, s.releaseFrame = false, nil
        s.phase, s.peakCharge = "idle", 0
    end
    local function restoreWeapon(s)
        local p = s.player
        if not exists(p) or not s.ownsWeapon then return end
        s.ownsWeapon = false
        -- Never retain a Weapon userdata across a cache rebuild: its pointer can
        -- have been destroyed by the engine. Reacquire each currently bound slot.
        for slot = 0, 4 do
            local w = p:GetWeapon(slot)
            if w then Isaac.DestroyWeapon(w) end
        end
        p:EnableWeaponType(WeaponType.WEAPON_BRIMSTONE, false)
        p:AddCacheFlags(CacheFlag.CACHE_WEAPON | CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_DAMAGE)
        if not p:IsDead() then p:EvaluateItems() end
        if s.canShootBefore ~= nil then p:SetCanShoot(s.canShootBefore) end
    end
    local function dropState(k, s)
        clearAttacks(s)
        restoreWeapon(s)
        states[k] = nil
    end
    local function ensureWeapon(s)
        local p = s.player
        local w = p:GetWeapon(1)
        local allowed = WeaponModifier.ANTI_GRAVITY | WeaponModifier.BRIMSTONE
        if not w or w:GetWeaponType() ~= WeaponType.WEAPON_BRIMSTONE
            or (w:GetModifiers() & ~allowed) ~= 0 then
            if w then Isaac.DestroyWeapon(w) end
            w = Isaac.CreateWeapon(WeaponType.WEAPON_BRIMSTONE, p)
            if not w then failOnce("CreateWeapon returned nil"); return nil end
            p:SetWeapon(w, 1)
            -- SetWeapon binds a slot; the player's native weapon-type flag is
            -- separate. CACHE_WEAPON restores native flags when ownership ends.
            p:EnableWeaponType(WeaponType.WEAPON_BRIMSTONE, true)
            trace("native Weapon created for " .. key(p))
        end
        -- SetModifiers ORs its argument in 1.0.12a; the clean instance above is
        -- essential. C222's native modifier, not a fake Brimstone Ball effect.
        w:SetModifiers(WeaponModifier.ANTI_GRAVITY)
        for slot = 0, 4 do
            if slot ~= 1 then
                local extra = p:GetWeapon(slot)
                if extra then Isaac.DestroyWeapon(extra) end
            end
        end
        s.ownsWeapon = true
        return w
    end
    local function beginCast(s)
        nextCast = nextCast + 1
        local cast = { id=nextCast, state=s, damage=s.player.Damage,
            entities={}, pendingDeaths={}, success=false, started=frame(), rootSeen=false }
        s.casts[cast.id], s.pending = cast, cast
        trace("cast " .. cast.id .. " native release observed; damage=" .. cast.damage)
        return cast
    end
    local function prePlayer(_, p)
        local k, s = key(p), stateFor(p)
        if s and s.failed then
            s.allowFire = false
            resetCharge(s)
            if ghost(p) then dropState(k, s) end
            return
        end
        if not held(p) or p:IsDead() or ghost(p) then
            if s then dropState(k, s) end
            return
        end
        if not s then
            s = {player=p,casts={},canShootBefore=p:CanShoot(),peakCharge=0}
            states[k] = s
            p:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_FIREDELAY)
            p:EvaluateItems()
            seedNpcs()
        end
        local w = ensureWeapon(s)
        s.allowFire = false
        if not w then s.phase = "weapon_unavailable"; return end
        if not p.ControlsEnabled then s.phase = "controls_disabled"
        elseif Game():IsPaused() then s.phase = "paused"
        elseif not hasEnemy() then s.phase = "no_enemy"
        else
            -- Do not rewrite analog values or IS_ACTION_TRIGGERED. The game
            -- reads the real controller and advances its own Brimstone charge.
            s.allowFire = true
            return
        end
        resetCharge(s)
    end
    local function postWeapon(_, w, direction, isShooting, isInterpolated)
        if not w then return end
        local owner = w:GetOwner()
        local p = owner and owner:ToPlayer()
        local s = p and stateFor(p)
        if not s or s.failed or not s.allowFire or w:GetWeaponType() ~= WeaponType.WEAPON_BRIMSTONE then return end
        s.nativePasses = (s.nativePasses or 0) + 1
        -- 1.0.12a calls this after BASE Weapon::Fire, before Brimstone::Fire.
        -- Observe a fully charged native release to establish ownership before
        -- its primary laser initializes. Never arm/advance/reset the weapon.
        if not isInterpolated and not isShooting and not s.pending
            and s.releaseFrame ~= frame() and w:GetCharge() >= math.max(0.001, w:GetMaxFireDelay()) then
            s.releaseFrame = frame()
            local cast = beginCast(s)
            cast.nativePassed = true
        end
    end
    local function inputAction(_, entity, hook, action)
        if not shooting[action] or not entity then return end
        local p = entity:ToPlayer()
        if not p or not held(p) then return end
        local s = stateFor(p)
        if s and s.allowFire and not s.failed then return end
        -- The combat gate only cancels disallowed input; no normal input is
        -- quantized, synthesized, or replaced with a held/triggered state.
        if hook == InputHook.GET_ACTION_VALUE then return 0 end
        if hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then return false end
    end
    local function directOwner(e)
        if not e then return nil end
        return (e.SpawnerEntity and e.SpawnerEntity:ToPlayer())
            or (e.Parent and e.Parent:ToPlayer())
    end
    local function castOf(e)
        if not e then return nil end
        local marker = e:GetData()[MARK]
        if marker then
            local s = states[marker.owner]
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
    local function preEffect(_, e)
        if not castOf(e) then effectInit(nil, e) end
        local cast = castOf(e)
        if cast then
            e.CollisionDamage = cast.damage
            nativeEffect = e
        end
    end
    local function postEffect(_, e)
        if sameEntity(nativeEffect, e) then nativeEffect = nil end
    end
    local function laserInit(_, laser, initialized)
        local cast = castOf(laser) or castOf(laser.Parent) or castOf(laser.SpawnerEntity)
        if not cast and nativeEffect then
            local candidate = castOf(nativeEffect)
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
    local function suppressForeign(_, attack)
        local p = directOwner(attack)
        if p and held(p) and not castOf(attack) then attack:Remove() end
    end
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
        collisions[key(target)] = c
    end
    local function preDamage(_, target)
        if next(states) == nil or not target:ToNPC() then return end
        damageBefore[key(target)] = snapshotDamage(target)
    end
    local function clearDeath(targetKey)
        local receipt = pendingDeaths[targetKey]
        if receipt then
            receipt.cast.pendingDeaths[targetKey] = nil
            pendingDeaths[targetKey] = nil
        end
    end
    local function confirmDeath(targetKey)
        local receipt = pendingDeaths[targetKey]
        if not receipt then return end
        if not receipt.cast.cancelled then
            receipt.cast.success = true
            trace("cast " .. receipt.cast.id .. " confirmed direct kill")
        end
        clearDeath(targetKey)
    end
    local function acceptedDamage(_, target, amount, flags, source)
        if next(states) == nil or not target:ToNPC() then return end
        local targetKey = key(target)
        local c = collisions[targetKey]
        if c and c.frame ~= frame() then c = nil end
        local before = damageBefore[targetKey] or c
        damageBefore[targetKey] = nil
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
        pendingDeaths[targetKey] = {cast=cast, target=target, updates=0}
        cast.pendingDeaths[targetKey] = true
        trace("cast " .. cast.id .. " accepted lethal hit; awaiting death")
        if before.killed or target:IsDead() or target.HitPoints <= 0 then confirmDeath(targetKey) end
    end
    local function postLaserCollision(_, laser, target)
        local c = collisions[key(target)]
        if c and sameEntity(c.laser, laser) then collisions[key(target)] = nil end
    end
    local function entityKilled(_, target)
        if not target:ToNPC() then return end
        local targetKey = key(target)
        -- Also handle a synchronous native kill before POST_TAKE_DMG.
        if damageBefore[targetKey] then damageBefore[targetKey].killed = true end
        confirmDeath(targetKey)
    end
    local function npcUpdated(_, target)
        local targetKey = key(target)
        local receipt = pendingDeaths[targetKey]
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
    local function removed(_, e)
        local ekey = key(e)
        npcs[ekey] = nil
        if pendingDeaths[ekey] then
            if e:IsDead() or e.HitPoints <= 0 then confirmDeath(ekey) else clearDeath(ekey) end
        end
        damageBefore[ekey], collisions[ekey] = nil, nil
        local cast = castOf(e)
        if cast then cast.entities[key(e)] = nil end
    end
    local function failCast(s, cast)
        if s.failed or not exists(s.player) or s.player:IsDead() or ghost(s.player) then return end
        s.failed = true -- installed BEFORE Kill or any recursive native callback.
        clearAttacks(s)
        log("cast " .. cast.id .. " failed: normal owner-only death")
        s.player:Kill() -- not damage: does not trigger our lethal-hit shields.
    end
    local function update()
        -- Cancelled TakeDamage has no POST callback. Its pre-hit snapshot
        -- must not leak into a later hit or room.
        damageBefore, collisions = {}, {}
        for targetKey, receipt in pairs(pendingDeaths) do
            if not exists(receipt.target) then clearDeath(targetKey)
            elseif receipt.target:IsDead() or receipt.target.HitPoints <= 0 then confirmDeath(targetKey) end
        end
        for k, s in pairs(states) do
            if not exists(s.player) then dropState(k, s)
            elseif not s.failed then
                local charge = nativeCharge(s)
                s.peakCharge = math.max(s.peakCharge or 0, charge)
                if s.allowFire then
                    s.phase = s.pending and "waiting_native" or
                        (charge >= CHARGE_FRAMES and "charged" or (charge > 0 and "charging" or "idle"))
                end
                if s.pending then
                    local pending = s.pending
                    if pending.rootSeen then s.pending = nil
                    elseif frame() > pending.started + 1 then
                        s.pending = nil
                        if pending.outputSeen then
                            -- A missing/delayed swirl receipt must never erase
                            -- a real shot or bypass its eventual miss penalty.
                            trace("cast " .. pending.id .. " emitted; awaiting native lifetime without swirl receipt")
                        else
                            pending.cancelled = true
                            s.casts[pending.id] = nil
                            failOnce("no native attack after release; nativePassed="
                                .. tostring(pending.nativePassed == true))
                        end
                    end
                end
                for id, cast in pairs(s.casts) do
                    local alive = false
                    for ekey, e in pairs(cast.entities) do
                        if exists(e) then alive = true else cast.entities[ekey] = nil end
                    end
                    if alive or next(cast.pendingDeaths) then cast.emptyFrame = nil
                    elseif cast.outputSeen and s.pending ~= cast and not cast.cancelled then
                        -- A removal and native child creation can happen in the
                        -- same update. Only settle after the next complete pass.
                        if not cast.emptyFrame then cast.emptyFrame = frame()
                        elseif frame() > cast.emptyFrame then
                            s.casts[id] = nil
                            if cast.success then trace("cast " .. id .. " succeeded")
                            else failCast(s, cast); break end
                        end
                    end
                end
            end
        end
    end
    local function evaluateCache(_, p, flag)
        if not held(p) then return end
        if flag == CacheFlag.CACHE_DAMAGE then
            -- Native cache starts from current base stats each evaluation.
            -- Casts read this panel value directly, with no second multiplier.
            p.Damage = p.Damage * 5
        elseif flag == CacheFlag.CACHE_FIREDELAY then
            -- Native player update copies MaxFireDelay into Weapon+0x10.
            -- Brimstone uses that same threshold for charging and native UI.
            -- This fixes the parameter, not charge progress or release timing.
            p.MaxFireDelay = CHARGE_FRAMES
        elseif flag == CacheFlag.CACHE_TEARFLAG then
            -- WeaponModifier controls charging, but Laser::Update requires
            -- TEAR_WAIT (bit 17) to create the vanilla BRIMSTONE_SWIRL itself.
            p.TearFlags = p.TearFlags | TearFlags.TEAR_WAIT
        end
    end
    local function newRoom()
        for _, s in pairs(states) do clearAttacks(s) end
        npcs, collisions, damageBefore, pendingDeaths, nativeEffect, seeded = {}, {}, {}, {}, nil, false
        for _, s in pairs(states) do if not s.failed then seedNpcs(); break end end
    end
    local function reset()
        for k, s in pairs(states) do dropState(k, s) end
        states, npcs, collisions, damageBefore, pendingDeaths = {}, {}, {}, {}, {}
        nativeEffect, seeded = nil, false
    end
    mod.AvadaKedavra = {
        OwnsAttack = held,
        IsFailureDeath = function(p) local s=stateFor(p); return s and s.failed == true or false end,
        Status = function(p)
            local s, count = stateFor(p), 0
            if s then for _ in pairs(s.casts) do count=count+1 end end
            return {charge=s and nativeCharge(s) or 0,casts=count,failed=s and s.failed or false,
                nativePasses=s and s.nativePasses or 0,pending=s and s.pending~=nil or false,
                phase=s and (s.failed and "failed" or s.phase) or "not_initialized",
                peakCharge=s and s.peakCharge or 0}
        end,
    }
    local function command(_, cmd, params)
        if cmd == "avada_trace" then
            traceEnabled = params == "on"
            log("trace=" .. tostring(traceEnabled))
        elseif cmd == "avada_status" then
            for index, p in ipairs(context.GetPlayers()) do
                local v=mod.AvadaKedavra.Status(p)
                Isaac.ConsoleOutput(string.format("Avada player %d: charge=%.2f/30 peak=%.2f phase=%s casts=%d nativePasses=%d pending=%s failed=%s\n",index,v.charge,v.peakCharge,v.phase,v.casts,v.nativePasses,tostring(v.pending),tostring(v.failed)))
            end
        end
    end
    local function add(name, fn, priority, filter)
        assert(ModCallbacks[name], "Avada requires REPENTOGON callback " .. name)
        mod:AddPriorityCallback(ModCallbacks[name], priority or 0, fn, filter)
    end
    add("MC_EVALUATE_CACHE",evaluateCache,10000)
    add("MC_PRE_PLAYER_UPDATE",prePlayer,-1000)
    add("MC_POST_WEAPON_FIRE",postWeapon,1000,WeaponType.WEAPON_BRIMSTONE)
    add("MC_INPUT_ACTION",inputAction,-1000)
    add("MC_POST_NPC_INIT",trackNpc)
    add("MC_POST_EFFECT_INIT",effectInit,-1000,EffectVariant.BRIMSTONE_SWIRL)
    add("MC_PRE_EFFECT_UPDATE",preEffect,-1000,EffectVariant.BRIMSTONE_SWIRL)
    add("MC_POST_EFFECT_UPDATE",postEffect,1000,EffectVariant.BRIMSTONE_SWIRL)
    add("MC_POST_LASER_INIT",laserInit,-1000)
    add("MC_POST_FIRE_BRIMSTONE",function(_, laser) laserInit(nil, laser, true) end,-1000)
    add("MC_PRE_LASER_COLLISION",preLaserCollision,1000)
    add("MC_POST_LASER_COLLISION",postLaserCollision,1000)
    add("MC_ENTITY_TAKE_DMG",preDamage,1000)
    add("MC_POST_ENTITY_TAKE_DMG",acceptedDamage,1000)
    add("MC_POST_ENTITY_KILL",entityKilled,1000)
    add("MC_NPC_UPDATE",npcUpdated,1000)
    add("MC_POST_ENTITY_REMOVE",removed)
    add("MC_POST_UPDATE",update)
    add("MC_POST_NEW_ROOM",newRoom)
    add("MC_POST_GAME_STARTED",reset)
    add("MC_PRE_GAME_EXIT",reset)
    add("MC_PRE_PLAYER_REVIVE",function(_,p) if mod.AvadaKedavra.IsFailureDeath(p) then return false end end,-1000)
    add("MC_EXECUTE_CMD",command)
    for _, callback in ipairs({"MC_POST_FIRE_TEAR","MC_POST_FIRE_KNIFE","MC_POST_FIRE_BONE_CLUB","MC_POST_FIRE_SWORD","MC_POST_FIRE_BOMB"}) do
        add(callback,suppressForeign,-1000)
    end
end
