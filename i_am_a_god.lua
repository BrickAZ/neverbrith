-- I Am a God: a timed, team-wide risk and a floor-owned no-healing room.
-- Requires the project's REPENTOGON gate; no weapon replacement.
return function(mod, context)
    local ITEM_ID = context.ItemId
    if not ITEM_ID or ITEM_ID <= 0 then return end
    local required = { "MC_PRE_PLAYER_TAKE_DMG", "MC_POST_ENTITY_TAKE_DMG",
        "MC_PRE_PLAYER_ADD_HEARTS", "MC_POST_PLAYER_ADD_HEARTS", "MC_PRE_PLAYER_UPDATE",
        "MC_POST_GRID_ENTITY_DOOR_UPDATE", "MC_PRE_TRIGGER_PLAYER_DEATH" }
    for _, name in ipairs(required) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog("[我即神明] 当前运行环境缺少必要接口，已停止此道具初始化。") end
            return
        end
    end

    local DURATION, OVERLOAD = 180, 121
    local CACHE = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_SPEED | CacheFlag.CACHE_RANGE
        | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_TEARFLAG
    local TEARS = TearFlags.TEAR_PIERCING | TearFlags.TEAR_SPECTRAL
    local NO_USE = { Discharge=false, Remove=false, ShowAnim=false }
    local VISUALS = {
        Crown = "gfx/Effects/IAmAGod/IAmAGodCrown.anm2",
        Success = "gfx/Effects/IAmAGod/IAmAGodSuccessBurst.anm2",
        Fail = "gfx/Effects/IAmAGod/IAmAGodFailShatter.anm2",
    }
    local ready, active, currentKey, currentFloor, marked = false, nil, nil, nil, false
    local snapshots, reviving, bursts, badVisuals = {}, {}, {}, {}
    local reconciling, judgment = false, nil
    local declarationSoundId, soundWarning

    local function alive(p)
        return p and p:Exists() and not p:IsDead() and not p:IsCoopGhost()
    end
    local function playerKey(p) return tostring(GetPtrHash(p)) .. ":" .. tostring(p.InitSeed) end
    local function samePlayer(a,b)
        -- Native callbacks may wrap the same entity in different Lua userdata.
        return a and b and playerKey(a)==playerKey(b)
    end
    local function players()
        -- GetPlayers owns ordinary co-op enumeration. Include the Forgotten's
        -- inactive health body as well; it is not always in Game:GetNumPlayers().
        local result, seen = {}, {}
        local function add(p)
            if p and p:Exists() then
                local key=playerKey(p)
                if not seen[key] then seen[key]=true;result[#result+1]=p end
            end
        end
        for _, p in ipairs(context.GetPlayers()) do
            add(p)
            if p.GetSubPlayer then add(p:GetSubPlayer()) end
        end
        return result
    end
    local function location()
        local level=Game():GetLevel()
        local floor=table.concat({tostring(context.GetCurrentRunSeed()),level:GetStage(),
            level:GetStageType(),level:GetDungeonPlacementSeed()}, ":")
        local desc=level:GetCurrentRoomDesc()
        -- Dimension + descriptor identity separates mirror/Death Certificate
        -- rooms, negative-grid rooms and distinct placements on the same floor.
        local key=table.concat({floor,level:GetDimension(),desc.ListIndex,
            desc.SafeGridIndex,desc.SpawnSeed}, ":")
        return floor,key
    end
    local function saved()
        local root=context.GetSaveRoot()
        local run=tostring(context.GetCurrentRunSeed())
        if type(root.iAmAGod)~="table" or root.iAmAGod.run~=run then
            root.iAmAGod={version=1,run=run,floor=currentFloor,rooms={}}
        end
        local s=root.iAmAGod
        if s.floor~=currentFloor or type(s.rooms)~="table" then s.floor=currentFloor;s.rooms={} end
        return s
    end
    local function roomMark()
        if not ready then return false, false end
        local floor,key=location()
        if floor==currentFloor and key==currentKey then return marked,true end
        -- Pickups and health callbacks can precede MC_POST_NEW_ROOM. Look up
        -- the destination without mutating cached room state or saved floors.
        local s=context.GetSaveRoot().iAmAGod
        return type(s)=="table" and s.run==tostring(context.GetCurrentRunSeed())
            and s.floor==floor and type(s.rooms)=="table" and s.rooms[key]==true, false
    end
    local function refresh(p)
        if p and p:Exists() then p:AddCacheFlags(CACHE);p:EvaluateItems() end
    end
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
    local function purgeHearts()
        for _,p in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP,PickupVariant.PICKUP_HEART,-1,false,false)) do
            removeHeart(nil,p)
        end
    end

    local HEALTH = {
        {key="bone",get="GetBoneHearts",add="AddBoneHearts"},
        {key="rotten",get="GetRottenHearts",add="AddRottenHearts"},
        {key="red",get="GetHearts",add="AddHearts"},
        -- GetSoulHearts includes black hearts; do not count/subtract them twice.
        {key="soul",get="GetSoulHearts",add="AddSoulHearts"},
        {key="eternal",get="GetEternalHearts",add="AddEternalHearts"},
    }
    local BLOCK_HEALTH = AddHealthType.RED | AddHealthType.SOUL | AddHealthType.BLACK
        | AddHealthType.ETERNAL | AddHealthType.BONE | AddHealthType.ROTTEN
    local function capture(p)
        local h={player=p}
        for _,t in ipairs(HEALTH) do h[t.key]=p[t.get](p) end
        snapshots[playerKey(p)]=h
        return h
    end
    local function reconcile(p)
        if reconciling or not ready or not marked then return end
        local banned,sameRoom=roomMark()
        if not banned or not sameRoom then return end
        local key=playerKey(p)
        if not alive(p) or p:HasMortalDamage() then
            snapshots[key]=nil
            return -- never reconstruct death or strip native revival health
        end
        if reviving[key] then return end
        local h=snapshots[key]
        if not h then capture(p);return end
        reconciling=true
        for _,t in ipairs(HEALTH) do
            local now=p[t.get](p)
            if now>h[t.key] then p[t.add](p,h[t.key]-now) end
            -- Only a decreasing ceiling: damage can NEVER be restored here.
            h[t.key]=math.min(h[t.key],p[t.get](p))
        end
        reconciling=false
    end
    local function beforeHealth(_,p,amount,kind)
        if reconciling or not roomMark() or not alive(p) or p:HasMortalDamage()
            or reviving[playerKey(p)] then return end
        reconcile(p)
        if amount>0 and (kind & BLOCK_HEALTH)~=0 then return 0 end
        -- MAX is deliberately allowed. Any associated red/soul fill is blocked
        -- separately. Bone/rotten additions are rejected as indivisible health.
    end
    local function afterHealth(_,p) reconcile(p) end

    local function ordinaryDoor(d)
        if not d or d.TargetRoomIndex<0 or d.TargetRoomType~=RoomType.ROOM_DEFAULT
            or d:IsLocked() or d:IsBusted() then return false end
        local variant=d:GetVariant()
        return variant==DoorVariant.DOOR_UNSPECIFIED or variant==DoorVariant.DOOR_UNLOCKED
    end
    local function holdDoor(_,door)
        local a=active
        if not a or a.room~=currentKey or select(2,location())~=a.room then return end
        local record=a.doors[door.Slot]
        if record and record.target==door.TargetRoomIndex and ordinaryDoor(door) then door:Close(true) end
    end
    local function releaseDoors(a)
        if not a or a.room~=currentKey or select(2,location())~=a.room then return end
        local room=Game():GetRoom()
        for slot,record in pairs(a.doors) do
            local door=room:GetDoor(slot)
            if door and door.TargetRoomIndex==record.target and ordinaryDoor(door)
                and (room:IsClear() or record.open) then door:Open() end
        end
        -- Closed native combat doors remain under the engine's control on
        -- failure. No lock bit, room clear bit, descriptor or door is replaced.
    end
    local function clearTears(a)
        for tear,bits in pairs(a.tears) do
            if tear:Exists() then tear:ClearTearFlags(bits) end
        end
    end
    local function stop()
        local a=active
        active=nil -- cache evaluation and damage must see the cleared state
        if a then releaseDoors(a);clearTears(a);refresh(a.player) end
        return a
    end
    local function validActive()
        if not active then return false end
        if select(2,location())~=currentKey then stop();return false end
        if active.room~=currentKey or not alive(active.player) or active.player:HasMortalDamage()
            or not active.player:HasCollectible(ITEM_ID) then stop();return false end
        return true
    end

    local function visual(path,animation)
        if badVisuals[path] then return nil end
        local ok,sprite=pcall(function()
            local s=Sprite();s:Load(path,true)
            s:Play(animation,true)
            if s:GetAnimation()~=animation then error("animation missing") end
            return s
        end)
        if ok then return sprite end
        badVisuals[path]=true
        if context.DebugLog then context.DebugLog("[我即神明] 特效资源不可用，机制继续运行："..path) end
    end
    local function playDeclarationSound()
        local ok,err=pcall(function()
            if not declarationSoundId then
                local id=Isaac.GetSoundIdByName("I Am a God Declaration")
                if not id or id<=0 then error("I Am a God Declaration is not registered") end
                declarationSoundId=id
            end
            SFXManager():Play(declarationSoundId,1,0,false,1)
        end)
        if not ok and not soundWarning then
            soundWarning=true
            if context.DebugLog then context.DebugLog("[我即神明] 宣言语音不可用，机制继续运行："..tostring(err)) end
        end
    end
    local function headPosition(p)
        -- Same world-anchor adapter as the existing BurnAway overhead sprite.
        if context.GetPlayerHeadWorldPosition then return context.GetPlayerHeadWorldPosition(p) end
        return p.Position+Vector(0,-math.max(18,(p.Size or 20)+4))
    end
    local function addBurst(path,animation,p,timeout)
        local s=visual(path,animation)
        if s then bursts[#bursts+1]={sprite=s,animation=animation,player=p,position=headPosition(p),
            room=currentKey,age=0,timeout=timeout} end
    end
    local function settle()
        local a=active
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
                judgment={player=a.player,entered=false}
                local flags=DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_NO_MODIFIERS | DamageFlag.DAMAGE_INVINCIBLE
                local ok,err=pcall(a.player.TakeDamage,a.player,4,flags,EntityRef(a.player),0)
                judgment=nil
                if not ok then error(err) end
            end
        end
    end
    local function evaluate(_,p,flag)
        if not active or not samePlayer(active.player,p) then return end
        if flag==CacheFlag.CACHE_DAMAGE then p.Damage=p.Damage*3
        elseif flag==CacheFlag.CACHE_SPEED then p.MoveSpeed=p.MoveSpeed+0.30
        elseif flag==CacheFlag.CACHE_RANGE then p.TearRange=p.TearRange+160 -- 40 world units per displayed range unit
        elseif flag==CacheFlag.CACHE_SHOTSPEED then p.ShotSpeed=p.ShotSpeed+0.25
        elseif flag==CacheFlag.CACHE_TEARFLAG then
            active.addedTearFlags=TEARS & ~p.TearFlags
            p.TearFlags=p.TearFlags | TEARS
        end
    end
    local function trackTear(_,tear)
        if not active then return end
        local parent=tear.SpawnerEntity
        local p=parent and parent:ToPlayer()
        if not samePlayer(p,active.player) then return end
        local bits=active.addedTearFlags or 0
        tear:AddTearFlags(TEARS)
        active.tears[tear]=(active.tears[tear] or 0) | bits
    end
    local function use(_,id,rng,p,flags,slot,vardata)
        if not ready or active or Game():IsPaused() or not alive(p) or p:HasMortalDamage()
            or p.ControlsEnabled==false or not p:AreControlsEnabled()
            or Game():GetRoom():GetFrameCount()<=0 or Game():GetRoom():IsClear()
            or (flags & UseFlag.USE_CARBATTERY)~=0 or not combatEnemies() then return NO_USE end
        local floor,key=location()
        if floor~=currentFloor or key~=currentKey then return NO_USE end
        active={player=p,room=currentKey,age=0,lastFrame=Game():GetFrameCount(),doors={},tears={}}
        local a=active
        saved().rooms[currentKey]=true
        marked=true
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
    local function preDamage(_,p)
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    local function damage(_,entity,amount,flags,source,countdown)
        local p=entity:ToPlayer()
        if not p then return end
        if judgment and samePlayer(judgment.player,p) and not judgment.entered
            and source and samePlayer(source.Entity,p) and (flags & DamageFlag.DAMAGE_NO_MODIFIERS)~=0 then
            judgment.entered=true
            return {Damage=4,DamageCountdown=0}
        end
        if validActive() and (flags & DamageFlag.DAMAGE_FAKE)==0 then
            return {Damage=amount*2,DamageCountdown=0}
        end
    end
    local function postDamage(_,entity)
        local p=entity:ToPlayer()
        if not p then return end
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    local function beforePlayer(_,p)
        if not ready then return end
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    local function afterPlayer(_,p)
        if not ready then return end
        local key=playerKey(p)
        if reviving[key] and alive(p) and not p:HasMortalDamage() then
            reviving[key]=nil;capture(p) -- baseline after native revival initialization
        end
        if validActive() then clearCooldown(p) end
        reconcile(p)
    end
    local function update()
        if not ready or Game():IsPaused() then return end
        if validActive() then
            local frame=Game():GetFrameCount()
            if active.lastFrame~=frame then
                active.lastFrame=frame;active.age=active.age+1
                if active.age>=DURATION then settle()
                elseif active.crown then
                    local s=active.crown
                    if active.age>=OVERLOAD and s:GetAnimation()~="Overload" then s:Play("Overload",true)
                    elseif s:IsFinished("Declare") then s:Play("Idle",true) end
                    s:Update()
                end
            end
        end
        if marked or active then
            for _,p in ipairs(players()) do
                if active then clearCooldown(p) end
                reconcile(p)
            end
        end
        for i=#bursts,1,-1 do
            local b=bursts[i];b.age=b.age+1;b.sprite:Update()
            if b.room~=currentKey or b.age>=b.timeout or b.sprite:IsFinished(b.animation) then table.remove(bursts,i) end
        end
    end
    local function render()
        if not ready or not Isaac.WorldToScreen then return end
        -- MC_POST_RENDER runs once after room/entity passes. GetRenderMode is
        -- RENDER_NULL here; requiring RENDER_NORMAL hides every owned sprite.
        -- Reflection/refraction filtering belongs in entity-render callbacks.
        if active and active.crown and alive(active.player) then active.crown:Render(Isaac.WorldToScreen(headPosition(active.player))) end
        for _,b in ipairs(bursts) do
            local position=alive(b.player) and headPosition(b.player) or b.position
            b.sprite:Render(Isaac.WorldToScreen(position))
        end
    end
    local function enterRoom()
        if not ready then return end
        -- Never release old-room handles against a newly loaded room.
        local floor,key=location()
        if key~=currentKey then currentKey=nil end
        stop();bursts={};snapshots={};reviving={}
        currentFloor,currentKey=floor,key
        marked=saved().rooms[key]==true
        if marked then
            for _,p in ipairs(players()) do capture(p) end
            purgeHearts()
        end
    end
    local function newLevel()
        if not ready then return end
        currentKey=nil;stop();bursts={};snapshots={};reviving={}
        currentFloor,currentKey=location()
        local s=saved();s.rooms={};marked=false;context.Save()
    end
    local function started(_,continued)
        stop();ready=true;bursts={};snapshots={};reviving={}
        if not continued then context.GetSaveRoot().iAmAGod=nil end
        enterRoom()
    end
    local function exitGame()
        stop();bursts={};snapshots={};reviving={}
        if ready then context.Save() end
        ready=false;marked=false
    end
    local function death(_,p)
        if not ready then return end
        if active and samePlayer(active.player,p) then stop() end
        reviving[playerKey(p)]=true;snapshots[playerKey(p)]=nil
        -- nil: preserve every native death/revival decision.
    end
    local function removed(_,p,id)
        if id==ITEM_ID and active and samePlayer(active.player,p) and not p:HasCollectible(ITEM_ID) then stop() end
    end
    local function heartCollision(_,pickup)
        if roomMark() then removeHeart(nil,pickup);return true end
    end
    mod:AddCallback(ModCallbacks.MC_USE_ITEM,use,ITEM_ID)
    mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,20000,evaluate)
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,-50,damage,EntityType.ENTITY_PLAYER)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-10000,preDamage)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,10000,postDamage,EntityType.ENTITY_PLAYER)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_ADD_HEARTS,-10000,beforeHealth)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_ADD_HEARTS,10000,afterHealth)
    mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,beforePlayer)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,10000,afterPlayer)
    mod:AddCallback(ModCallbacks.MC_PRE_TRIGGER_PLAYER_DEATH,death)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED,removed,ITEM_ID)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT,removeHeart,PickupVariant.PICKUP_HEART)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE,removeHeart,PickupVariant.PICKUP_HEART)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,-10000,heartCollision,PickupVariant.PICKUP_HEART)
    mod:AddCallback(ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE,holdDoor)
    mod:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR,trackTear)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,update)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER,render)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,enterRoom)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL,newLevel)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,started)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,exitGame)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_END,exitGame)
    mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exitGame() end end)
end
