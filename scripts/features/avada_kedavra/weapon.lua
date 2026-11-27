-- Private weapon ownership for Avada Kedavra.
return function(mod, deps)
    local callbackInstallers = {}
    local failOnce = deps.Queries.failOnce
    local trace = deps.Queries.trace
    local exists = deps.Queries.exists
    local key = deps.Queries.key

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

    return {
        nativeCharge = nativeCharge,
        resetCharge = resetCharge,
        restoreWeapon = restoreWeapon,
        ensureWeapon = ensureWeapon,
        Installers = callbackInstallers,
    }
end
