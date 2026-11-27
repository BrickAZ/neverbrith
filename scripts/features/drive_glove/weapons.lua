-- Private Drive Glove weapons; instantiated once by init.lua.
return function(mod, deps)
    local callbackInstallers = {}
    local C,records,now=deps.Core,deps.State,deps.Now
    local data,state,key,held=records.Data,records.Get,records.Key,records.IsHeld
    local W,shooting,flush=deps.Rules,deps.Input.Shooting,deps.Flush
    local function restoreShoot(p,t)
        if deps.Shooting then return deps.Shooting.Restore(t,'shootScope',deps.Exists) end
        if t.shootScope~=nil then p:SetCanShoot(t.shootScope); t.shootScope=nil end
    end
    local function refresh(p,t)
        if t.cacheDirty then
            t.cacheDirty=false
            p:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY); p:EvaluateItems()
        end
    end
    local function currentWeapon(p)
        return p:GetWeapon(1)
    end
    local function weaponIdentity(w)
        return w and (w:GetWeaponType()..':'..w:GetModifiers()) or nil
    end
    local function charge(p,s,t)
        -- Never retain a Weapon userdata across updates: native weapon changes can
        -- destroy it. Only a primitive identity is retained, then checked afresh.
        local w=currentWeapon(p)
        if t.chargeConsumed then t.gift=nil; t.chargeConsumed=nil end
        if t.gift and weaponIdentity(w)~=t.gift.identity then t.gift=nil end
        if t.gift and (s.burnout or not t.reward) then
            if w and weaponIdentity(w)==t.gift.identity then w:SetCharge(math.min(w:GetCharge(),t.gift.before)) end
            t.rushShot=nil
            t.gift=nil
        end
        -- After firing input, native release/launch may clear charge several
        -- frames before emission (Brimstone). Re-filling then restarts its windup.
        if t.gift and w and not t.gift.armed then w:SetCharge(math.max(w:GetCharge(),t.gift.full)) end
        if not t.grantCharge then return end
        t.grantCharge=nil
        if s.burnout or not t.reward or not w then return end
        local full=W.Full(w)
        if full<=0 then return end
        local before=w:GetCharge()
        w:SetCharge(math.max(before,full)); w:SetFireDelay(0)
        t.gift={identity=weaponIdentity(w),before=before,full=full}
    end
    local function weaponFired(_,_,amount,entity,w)
        local p=entity and entity:ToPlayer(); if not p or amount<=0 or not records.IsReady() then return end
        local s=data(p); if not s then return end
        local t=state(p)
        -- Actual native weapon emission, never an old tear hitting or a familiar.
        local intent=shooting(p) or t.gift and t.gift.armed or t.firePending and t.fireIntentAt and now()-t.fireIntentAt<=60
        if not intent or t.mode=='blue' or t.mode=='recovery' or t.mode=='startup' then return end
        t.firePending=false
        if t.rushShot and w and W.ReleaseBurst(w) then
            -- Cursed Eye's native burst is aborted by a new held press. Keep the
            -- release through its consecutive emissions, not just the first tear.
            t.rushShot.finishing=true;t.rushShot.emittedAt=now()
        else t.rushShot=nil end
        if t.mode=='rush' then
            if t.moveFrames<5 then return end
            C.End(t,'shot'); t.planned=nil
        end
        C.Shot(s,t,now()); flush(p,s,t)
    end
    function callbackInstallers.weaponFired()
        return mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,weaponFired)
    end
    local function evaluate(_,p,flag)
        if not records.IsReady() then return end
        local s=data(p); if not s then return end
        local t=records.Peek(p)
        if flag==CacheFlag.CACHE_DAMAGE and s.burnout then p.Damage=p.Damage*.75 end
        if flag==CacheFlag.CACHE_FIREDELAY then
            p.MaxFireDelay=C.Tears(p.MaxFireDelay,s.burnout,t and t.reward and t.reward.started~=nil)
        end
    end
    function callbackInstallers.evaluate()
        return mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,30000,evaluate)
    end
    function callbackInstallers.postWeaponFire()
    mod:AddCallback(ModCallbacks.MC_POST_WEAPON_FIRE,function(_,w,_,isShooting,isInterpolated)
        local e=w:GetOwner();local p=e and e:ToPlayer()
        local t=p and records.Peek(p)
        if t and t.mode=='rush' and t.rushShot and isShooting and not isInterpolated
            and t.rushShot.identity==weaponIdentity(w) then
            if t.rushShot.charge then w:SetCharge(t.rushShot.charge); t.rushShot.charge=nil end
            t.rushShot.primed=true
        end
    end)
    end

    return {
        Install = callbackInstallers,
        RestoreShoot=restoreShoot, Refresh=refresh, Charge=charge,
        Current=currentWeapon, Identity=weaponIdentity,

    }
end
