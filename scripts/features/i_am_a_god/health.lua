-- Private health responsibilities for i_am_a_god; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local HEALTH = deps.Config.HEALTH
    local BLOCK_HEALTH = deps.Config.BLOCK_HEALTH
    local alive = deps.State.alive
    local playerKey = deps.State.playerKey
    local roomMark = deps.State.roomMark
    local validActive = deps.State.validActive

    local function clearCooldown(p)
        if not alive(p) then return end
        -- SetMinDamageCooldown(0) only sets a minimum and does NOT lower an
        -- existing timer. ResetDamageCooldown is the native reset operation.
        p:ResetDamageCooldown()
        if p.SetDamageCountdown then p:SetDamageCountdown(0) end
        if p.SetFireDamageCooldown then p:SetFireDamageCooldown(0) end
    end

    local function removeHeart(_,pickup)
        if pickup.Variant==PickupVariant.PICKUP_HEART and roomMark() then pickup:Remove() end
    end
    function callbackInstallers.removeHeart()
        return mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,removeHeart,PickupVariant.PICKUP_HEART)
    end
    function callbackInstallers.removeHeart2()
        return mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE,removeHeart,PickupVariant.PICKUP_HEART)
    end

    local function purgeHearts()
        for _,p in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_HEART,-1,false,false)) do
            removeHeart(nil,p)
        end
    end

    local function capture(p)
        local h={player=p}
        for _,t in ipairs(HEALTH) do h[t.key]=p[t.get](p) end
        data.snapshots[playerKey(p)]=h
        return h
    end

    local function reconcile(p)
        if data.reconciling or not data.ready or not data.marked then return end
        local banned,sameRoom=roomMark()
        if not banned or not sameRoom then return end
        local key=playerKey(p)
        if not alive(p) or p:HasMortalDamage() then
            data.snapshots[key]=nil
            return -- never reconstruct death or strip native revival health
        end
        if data.reviving[key] then return end
        local h=data.snapshots[key]
        if not h then capture(p);return end
        data.reconciling=true
        for _,t in ipairs(HEALTH) do
            local now=p[t.get](p)
            if now>h[t.key] then p[t.add](p,h[t.key]-now) end
            -- Only a decreasing ceiling: damage can NEVER be restored here.
            h[t.key]=math.min(h[t.key],p[t.get](p))
        end
        data.reconciling=false
    end

    local function beforeHealth(_,p,amount,kind)
        if data.reconciling or not roomMark() or not alive(p) or p:HasMortalDamage()
            or data.reviving[playerKey(p)] then return end
        reconcile(p)
        if amount>0 and (kind & BLOCK_HEALTH)~=0 then return 0 end
        -- MAX is deliberately allowed. Any associated red/soul fill is blocked
        -- separately. Bone/rotten additions are rejected as indivisible health.
    end
    function callbackInstallers.beforeHealth()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_ADD_HEARTS,-10000,beforeHealth)
    end

    local function afterHealth(_,p) reconcile(p) end
    function callbackInstallers.afterHealth()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_ADD_HEARTS,10000,afterHealth)
    end

    local function beforePlayer(_,p)
        if not data.ready then return end
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    function callbackInstallers.beforePlayer()
        return mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,beforePlayer)
    end

    local function afterPlayer(_,p)
        if not data.ready then return end
        local key=playerKey(p)
        if data.reviving[key] and alive(p) and not p:HasMortalDamage() then
            data.reviving[key]=nil;capture(p) -- baseline after native revival initialization
        end
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    function callbackInstallers.afterPlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,10000,afterPlayer)
    end

    local function heartCollision(_,pickup)
        if roomMark() then removeHeart(nil,pickup);return true end
    end
    function callbackInstallers.heartCollision()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,-10000,heartCollision,PickupVariant.PICKUP_HEART)
    end

    return {
        Installers = callbackInstallers,
        clearCooldown = clearCooldown,
        removeHeart = removeHeart,
        purgeHearts = purgeHearts,
        capture = capture,
        reconcile = reconcile,
        beforeHealth = beforeHealth,
        afterHealth = afterHealth,
        beforePlayer = beforePlayer,
        afterPlayer = afterPlayer,
        heartCollision = heartCollision,
    }
end
