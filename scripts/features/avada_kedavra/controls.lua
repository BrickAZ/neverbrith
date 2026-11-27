-- Private controls ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local state = deps.State
    local CHARGE_FRAMES = deps.CHARGE_FRAMES
    local shooting = deps.shooting
    local key = deps.Queries.key
    local frame = deps.Queries.frame
    local held = deps.Queries.held
    local ghost = deps.Queries.ghost
    local seedNpcs = deps.Queries.seedNpcs
    local hasEnemy = deps.Queries.hasEnemy
    local stateFor = deps.Queries.stateFor
    local resetCharge = deps.Weapon.resetCharge
    local ensureWeapon = deps.Weapon.ensureWeapon
    local dropState = deps.Casts.dropState
    local beginCast = deps.Casts.beginCast

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
            state.states[k] = s
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
    function callbackInstallers.prePlayer(add)
        return add("MC_PRE_PLAYER_UPDATE",prePlayer,-1000)
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
    function callbackInstallers.postWeapon(add)
        return add("MC_POST_WEAPON_FIRE",postWeapon,1000,WeaponType.WEAPON_BRIMSTONE)
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
    function callbackInstallers.inputAction(add)
        return add("MC_INPUT_ACTION",inputAction,-1000)
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
    function callbackInstallers.evaluateCache(add)
        return add("MC_EVALUATE_CACHE",evaluateCache,10000)
    end

    return {
        prePlayer = prePlayer,
        postWeapon = postWeapon,
        inputAction = inputAction,
        evaluateCache = evaluateCache,
        Installers = callbackInstallers,
    }
end
