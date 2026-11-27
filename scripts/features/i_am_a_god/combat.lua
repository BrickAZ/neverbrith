-- Private combat responsibilities for i_am_a_god; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local ITEM_ID = context.ItemId
    local TEARS = deps.Config.TEARS
    local NO_USE = deps.Config.NO_USE
    local VISUALS = deps.Config.VISUALS
    local samePlayer = deps.State.samePlayer
    local players = deps.State.players
    local location = deps.State.location
    local saved = deps.State.saved
    local refresh = deps.State.refresh
    local ordinaryDoor = deps.State.ordinaryDoor
    local holdDoor = deps.State.holdDoor
    local stop = deps.State.stop
    local validActive = deps.State.validActive
    local clearCooldown = deps.Health.clearCooldown
    local purgeHearts = deps.Health.purgeHearts
    local capture = deps.Health.capture
    local reconcile = deps.Health.reconcile
    local visual = deps.Presentation.visual
    local playDeclarationSound = deps.Presentation.playDeclarationSound
    local addBurst = deps.Presentation.addBurst
    local alive = deps.State.alive

    local function combatEnemies()
        -- The older BurnAway helper requires vulnerability, which loses buried
        -- enemies and invulnerable boss phases. Keep its alive/friendly checks
        -- but use IsActiveEnemy(false), independent of current vulnerability.
        for _,e in ipairs(Isaac.GetRoomEntities()) do
            if e:Exists() and not e:IsDead() and e:IsActiveEnemy(false)
                and not e:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
                and not e:HasEntityFlags(EntityFlag.FLAG_CHARM) then return true end
        end
        return false
    end

    local function settle()
        local a=data.active
        -- Require the native clear flag as well, so a zero-entity boss phase
        -- transition / dormant wave cannot become an early successful verdict.
        local success=Game():GetRoom():IsClear() and not combatEnemies()
        stop()
        if success then
            addBurst(VISUALS.Success,"Success",a.player,30)
            local room=Game():GetRoom()
            local pos=room:FindFreePickupSpawnPosition(room:GetCenterPos(),0,true)
            Isaac.Spawn(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_LOCKEDCHEST,0,pos,Vector.Zero,a.player)
        else
            addBurst(VISUALS.Crown,"Fail",a.player,20)
            addBurst(VISUALS.Fail,"FailShatter",a.player,30)
            if alive(a.player) then
                clearCooldown(a.player)
                data.judgment={player=a.player,entered=false}
                local flags=DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_NO_MODIFIERS | DamageFlag.DAMAGE_INVINCIBLE
                local ok,err=pcall(a.player.TakeDamage,a.player,4,flags,EntityRef(a.player),0)
                data.judgment=nil
                if not ok then error(err) end
            end
        end
    end

    local function evaluate(_,p,flag)
        if not data.active or not samePlayer(data.active.player,p) then return end
        if flag==CacheFlag.CACHE_DAMAGE then p.Damage=p.Damage*3
        elseif flag==CacheFlag.CACHE_SPEED then p.MoveSpeed=p.MoveSpeed+0.30
        elseif flag==CacheFlag.CACHE_RANGE then p.TearRange=p.TearRange+160 -- 40 world units per displayed range unit
        elseif flag==CacheFlag.CACHE_SHOTSPEED then p.ShotSpeed=p.ShotSpeed+0.25
        elseif flag==CacheFlag.CACHE_TEARFLAG then
            data.active.addedTearFlags=TEARS & ~p.TearFlags
            p.TearFlags=p.TearFlags | TEARS
        end
    end
    function callbackInstallers.evaluate()
        return mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,20000,evaluate)
    end

    local function trackTear(_,tear)
        if not data.active then return end
        local parent=tear.SpawnerEntity
        local p=parent and parent:ToPlayer()
        if not samePlayer(p,data.active.player) then return end
        local bits=data.active.addedTearFlags or 0
        tear:AddTearFlags(TEARS)
        data.active.tears[tear]=(data.active.tears[tear] or 0) | bits
    end
    function callbackInstallers.trackTear()
        return mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,trackTear)
    end

    local function use(_,id,rng,p,flags,slot,vardata)
        if not data.ready or data.active or Game():IsPaused() or not alive(p) or p:HasMortalDamage()
            or p.ControlsEnabled==false or not p:AreControlsEnabled()
            or Game():GetRoom():GetFrameCount()<=0 or Game():GetRoom():IsClear()
            or (flags & UseFlag.USE_CARBATTERY)~=0 or not combatEnemies() then return NO_USE end
        local floor,key=location()
        if floor~=data.currentFloor or key~=data.currentKey then return NO_USE end
        data.active={player=p,room=data.currentKey,age=0,lastFrame=Game():GetFrameCount(),doors={},tears={}}
        local a=data.active
        saved().rooms[data.currentKey]=true
        data.marked=true
        for _,other in ipairs(players()) do capture(other);clearCooldown(other) end
        purgeHearts()
        for s=0,7 do
            local door=Game():GetRoom():GetDoor(s)
            if ordinaryDoor(door) then a.doors[s]={target=door.TargetRoomIndex,open=door:IsOpen()};holdDoor(nil,door) end
        end
        context.Save()
        refresh(p)
        a.crown=visual(VISUALS.Crown,"Declare")
        playDeclarationSound()
        return {Discharge=true,Remove=false,ShowAnim=true}
    end
    function callbackInstallers.use()
        return mod:AddCallback(ModCallbacks.MC_USE_ITEM,use,ITEM_ID)
    end

    local function preDamage(_,p)
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    function callbackInstallers.preDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-10000,preDamage)
    end

    local function damage(_,entity,amount,flags,source,countdown)
        local p=entity:ToPlayer()
        if not p then return end
        if data.judgment and samePlayer(data.judgment.player,p) and not data.judgment.entered
            and source and samePlayer(source.Entity,p) and (flags & DamageFlag.DAMAGE_NO_MODIFIERS)~=0 then
            data.judgment.entered=true
            return {Damage=4,DamageCountdown=0}
        end
        if validActive() and (flags & DamageFlag.DAMAGE_FAKE)==0 then
            return {Damage=amount*2,DamageCountdown=0}
        end
    end
    function callbackInstallers.damage()
        return mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-50,damage,EntityType.ENTITY_PLAYER)
    end

    local function postDamage(_,entity)
        local p=entity:ToPlayer()
        if not p then return end
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    function callbackInstallers.postDamage()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,10000,postDamage,EntityType.ENTITY_PLAYER)
    end

    return {
        Installers = callbackInstallers,
        combatEnemies = combatEnemies,
        settle = settle,
        evaluate = evaluate,
        trackTear = trackTear,
        use = use,
        preDamage = preDamage,
        damage = damage,
        postDamage = postDamage,
    }
end
