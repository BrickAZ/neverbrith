return function(mod,context)
    local C=include('drive_glove_core')
    local D=include('drive_glove_damage')
    local W=include('drive_glove_weapon')
    local game,ID=Game(),context.ItemId
    if not ID or ID<=0 then return end
    local audio=include('drive_glove_audio')()
    local runtime,readingInput,freezeUntil,frozen={},0,-1,{}
    local hits={}
    local attackOwners={}
    local nativeAttribution=Isaac.GetStatusAttributionAPIVersion and Isaac.GetStatusAttributionAPIVersion()==1
    local statusOwnerFields={'poisonOwner','burnOwner','bleedOwner'}
    local ready=false
    local visuals
    local function now() return game:GetFrameCount() end
    local function players() return context.GetPlayers() end
    local function key(p) return mod.PendingContentState.InventoryPlayerKey(p) end
    local function exists(e) return e and e:Exists() end
    local function held(p) return p:HasCollectible(ID) end
    local function data(p)
        return C.Record(context.GetSaveRoot(),context.GetCurrentRunSeed(),key(p),held(p))
    end
    local function state(p)
        local k=key(p)
        if not runtime[k] then runtime[k]=C.Runtime(); runtime[k].player=p end
        return runtime[k]
    end
    local function raw(p,action)
        readingInput=readingInput+1
        local result=Input.GetActionValue(action,p.ControllerIndex)
        readingInput=readingInput-1
        return result
    end
    local function movement(p)
        return Vector(raw(p,ButtonAction.ACTION_RIGHT)-raw(p,ButtonAction.ACTION_LEFT),
            raw(p,ButtonAction.ACTION_DOWN)-raw(p,ButtonAction.ACTION_UP))
    end
    local function shooting(p)
        return raw(p,ButtonAction.ACTION_SHOOTLEFT)>.2 or raw(p,ButtonAction.ACTION_SHOOTRIGHT)>.2
            or raw(p,ButtonAction.ACTION_SHOOTUP)>.2 or raw(p,ButtonAction.ACTION_SHOOTDOWN)>.2
    end
    local function actionForSlot(slot)
        return slot>=2 and ButtonAction.ACTION_PILLCARD or ButtonAction.ACTION_ITEM
    end
    local function selected(p,action)
        if action==ButtonAction.ACTION_ITEM then
            if p:GetActiveItem(0)==ID then return 0 end
            return
        end
        -- Holding a pocket active does not mean Q currently selects it: cards
        -- and pills share this input and can be in the front pocket instead.
        local pocket=p:GetPocketItem(PillCardSlot.PRIMARY)
        if pocket and pocket:GetType()==PocketItemType.ACTIVE_ITEM then
            local slot=pocket:GetSlot()-1
            if slot>=2 and slot<=3 and p:GetActiveItem(slot)==ID then return slot end
        end
    end
    local function busy(t) return t and t.mode~='idle' end
    local function rushing(t) return t and (t.mode=='rush' or t.mode=='startup') end
    local function restoreShoot(p,t)
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
    local function flush(p,s,t)
        charge(p,s,t); refresh(p,t)
        if visuals then visuals.Events(p,s,t) end
        audio.Events(t)
        t.events={}
    end
    local function save()
        if context.Save then context.Save() end
        for _,t in pairs(runtime) do t.saveDirty=false end
    end
    local function thaw()
        for _,v in pairs(frozen) do
            if exists(v.entity) then
                v.entity.Velocity=v.velocity
                if v.spriteFlag then v.entity:ClearEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE) end
            end
        end
        frozen={}
    end
    local function freeze(e)
        if now()>=freezeUntil then return end
        local hash=GetPtrHash(e)
        if not frozen[hash] then
            local added=not e:HasEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE)
            frozen[hash]={entity=e,velocity=e.Velocity,position=e.Position,spriteFlag=added}
            if added then e:AddEntityFlags(EntityFlag.FLAG_NO_SPRITE_UPDATE) end
        end
        e.Velocity=Vector(0,0)
        return true
    end
    local function beginFreeze()
        freezeUntil=math.max(freezeUntil,now()+5)
        game:GetRoom():SetPauseTimer(5)
        for _,e in ipairs(Isaac.GetRoomEntities()) do freeze(e) end
    end
    local function canControl(p)
        return not p:IsDead() and not p:IsCoopGhost() and p:AreControlsEnabled()
            and not (mod.InventorySelector and mod.InventorySelector.IsBlocking(p))
    end
    local function start(p,slot)
        local s,t=data(p),state(p)
        if not s or not canControl(p) or now()<freezeUntil then return false end
        t.slot=slot; t.action=actionForSlot(slot)
        if C.StartBlue(s,t,now()) then
            t.firePending=false; t.fireIntentAt=nil
            flush(p,s,t); return true
        end
        flush(p,s,t); return false
    end
    local function restoreAll()
        thaw(); freezeUntil=-1
        for _,t in pairs(runtime) do
            if exists(t.player) then restoreShoot(t.player,t) end
        end
    end
    local function cancelRoom()
        restoreAll()
        hits={}; attackOwners={}
        for _,t in pairs(runtime) do
            if busy(t) then C.End(t,'room') end
            t.planned=nil; t.walkOrigin=nil; t.damageReceipts={}; t.rushShot=nil
        end
        if visuals then visuals.ClearRoom() end
    end
    local function prePlayer(_,p)
        if not ready then return end
        if now()>=freezeUntil and next(frozen) then thaw() end
        local s=data(p)
        if not s then return freeze(p) end
        local t=state(p)
        restoreShoot(p,t)
        if t.mode~='rush' and not (t.mode=='idle' and t.rushShot and t.rushShot.finishing) then t.rushShot=nil end
        local input=movement(p)
        t.input=input; t.planned=nil
        if t.walkFrame~=now() then t.walkFrame=now(); t.walking=false end
        t.pressedActions=t.pressedActions or {}
        local slot,pressed=nil,false
        for _,action in ipairs({ButtonAction.ACTION_ITEM,ButtonAction.ACTION_PILLCARD}) do
            local down=raw(p,action)>.2
            local selectedSlot=selected(p,action)
            if selectedSlot~=nil and down then
                pressed=true
                if not t.pressedActions[action] then slot=slot or selectedSlot end
            end
            t.pressedActions[action]=down
        end
        if t.mode=='idle' and slot~=nil and canControl(p) then start(p,slot) end
        t.lastPressed=pressed
        local hold=t.action and raw(p,t.action)>.2 or false
        local before=t.mode
        C.Tick(s,t,now(),{held=hold,x=input.X,y=input.Y},held(p))
        if before~='startup' and t.mode=='startup' then beginFreeze() end
        if p:IsDead() or not held(p) then
            if busy(t) then C.End(t,'unavailable') end
            if t.reward then t.reward=nil; t.cacheDirty=true end
        end
        flush(p,s,t)
        if freeze(p) then return true end
        if not canControl(p) then
            if rushing(t) then C.End(t,'controls') end
            return
        end
        local fireAllowed=t.mode=='idle' or t.mode=='rush' and t.moveFrames>=5
        -- Release weapons need one native held-direction update before release.
        -- Prime that direction without charge while fire is still locked.
        local w=currentWeapon(p)
        if t.rushShot and t.rushShot.identity~=weaponIdentity(w) then t.rushShot=nil end
        local prime=t.mode=='rush' and t.moveFrames>=3 and t.moveFrames<5 and shooting(p) and w and W.Release(w)
            and w:GetCharge()>=W.Full(w) and not t.rushShot
        if prime then
            t.rushShot={identity=weaponIdentity(w),charge=w:GetCharge()}
            w:SetCharge(0)
        end
        if fireAllowed and shooting(p) then
            t.fireIntentAt=now(); t.firePending=true
            if t.gift then t.gift.armed=true end
            if t.mode=='rush' and not t.rushShot and w and W.Release(w) and w:GetCharge()>=W.Full(w) then
                t.rushShot={identity=weaponIdentity(w)}
            end
        end
        -- Release weapons interpret a pre-filled charge and no held direction as
        -- a shot. Keep the gift dormant until the player actually operates fire.
        local blockFire=t.mode=='blue' or t.mode=='recovery' or (t.mode=='rush' and t.moveFrames<5)
            or t.gift and not t.gift.armed
        if t.mode=='rush' and t.rushShot and t.rushShot.charge then blockFire=false end
        if blockFire then t.shootScope=p:CanShoot(); p:SetCanShoot(false) end
        t.walkOrigin=p.Position; t.walkMode=t.mode
        if t.mode=='blue' or t.mode=='recovery' then p.Velocity=Vector(0,0) end
        if t.mode=='rush' then p.Velocity=Vector(0,0) end
        if t.mode=='rush' and t.moveUpdateFrame~=now() then
            t.moveUpdateFrame=now()
            local distance=C.RushStep(t,input.X,input.Y)
            if distance then
                t.planned={origin=Vector(p.Position.X,p.Position.Y),distance=distance,direction=Vector.FromAngle(t.heading)}
                p.Velocity=Vector(0,0)
            end
        end
    end
    local function passable(p,pos)
        local room=game:GetRoom()
        if not room:IsPositionInRoom(pos,math.min(p.Size,12)) then return false end
        if p.GridCollisionClass==EntityGridCollisionClass.GRIDCOLL_NONE then return true end
        local radius=math.min(10,p.Size*.65)
        for _,offset in ipairs({Vector(0,0),Vector(radius,0),Vector(-radius,0),Vector(0,radius),Vector(0,-radius)}) do
            local c=room:GetGridCollisionAtPos(pos+offset)
            if c==GridCollisionClass.COLLISION_WALL or c==GridCollisionClass.COLLISION_WALL_EXCEPT_PLAYER then
                if c==GridCollisionClass.COLLISION_WALL then return false end
            elseif c~=GridCollisionClass.COLLISION_NONE and not p.CanFly
                and p.GridCollisionClass~=EntityGridCollisionClass.GRIDCOLL_WALLS then
                local ignoresPit=c==GridCollisionClass.COLLISION_PIT
                    and p.GridCollisionClass==EntityGridCollisionClass.GRIDCOLL_NOPITS
                if not ignoresPit then return false end
            end
        end
        return true
    end
    local function postPlayer(_,p)
        if not ready then return end
        local t=runtime[key(p)]; if not t then return end
        restoreShoot(p,t)
        local s=data(p); if not s then return end
        if now()<freezeUntil then flush(p,s,t); return end
        if t.mode=='rush' and t.planned then
            local move=t.planned
            -- Native walking is blocked and velocity is zero here. A changed
            -- position belongs to another effect/collision, even for a short warp.
            if (p.Position-move.origin):LengthSquared()>.0001 or not p:AreControlsEnabled() then C.End(t,'takeover')
            else
                local travel=0
                -- Small swept segments avoid skipping thin obstacles at rush speed.
                while travel<move.distance do
                    local nextTravel=math.min(move.distance,travel+2)
                    if not passable(p,move.origin+move.direction*nextTravel) then break end
                    travel=nextTravel
                end
                p.Position=move.origin+move.direction*travel; p.Velocity=Vector(0,0)
                C.CommitMove(t,travel)
                if travel<move.distance-.001 then C.End(t,'obstacle') end
            end
        elseif t.mode=='blue' or t.mode=='recovery' then
            p.Velocity=Vector(0,0)
        end
        if t.walkOrigin and t.walkMode=='idle' and t.mode=='idle' and held(p) and canControl(p) then
            local delta=p.Position-t.walkOrigin
            -- Require commanded displacement, not merely a held key during recoil.
            t.walking=t.walking or t.input:LengthSquared()>.04 and delta:LengthSquared()>.0025
                and p:GetKnockbackCountdown()<=0
                and delta:Length()<=math.max(10,p.MoveSpeed*10) and delta:Dot(t.input)>0
        end
        t.planned=nil
        flush(p,s,t)
    end
    local paymentItems={}
    for _,name in ipairs({'COLLECTIBLE_IV_BAG','COLLECTIBLE_RAZOR_BLADE','COLLECTIBLE_BLOOD_RIGHTS',
        'COLLECTIBLE_BREATH_OF_LIFE','COLLECTIBLE_POTATO_PEELER','COLLECTIBLE_MAGIC_SKIN'}) do
        if CollectibleType[name] then paymentItems[CollectibleType[name]]=true end
    end
    local function payment(p,flags,source)
        local t=runtime[key(p)]
        return D.Payment(p,flags,source,game:GetRoom(),t and t.paymentFrame==now())
    end
    local function earlyDamage(_,p,amount,flags,source,countdown)
        if not ready or amount<=0 then return end
        local s=data(p); if not s or not held(p) then return end
        local t=state(p)
        if payment(p,flags,source) then return end
        if D.Invulnerable(p,flags) then return end
        if s.burnout then return end
        local normalAmount=D.NormalAmount(p,amount,flags,game)
        if context.IncomingDamageMultiplier then normalAmount=normalAmount*context.IncomingDamageMultiplier(p) end
        local defended
        if t.mode=='blue' and not D.Bomb(flags,source) then
            defended=C.Parry(s,t,now())
        else
            local direction=D.NormalDirection(p,flags,source)
            local input=movement(p)
            if direction and C.GuardDirection(input.X,input.Y,direction.X,direction.Y) then
                defended=C.Guard(s,t,normalAmount)
                -- A bomb can overdraw the meter during blue and force recovery.
                if s.burnout and t.mode=='blue' then C.Recovery(t,now()) end
            end
        end
        if not defended then return end
        -- Native invulnerability is based on the incoming amount, before Womb,
        -- Wafer and coin-heart normalization; the gauge uses final heart damage.
        D.Cooldown(p,amount,flags,countdown)
        t.impactKind,t.impactAngle=D.Impact(p,flags,source)
        flush(p,s,t)
        return false
    end
    local function lateDamage(_,entity,amount,flags,source,countdown)
        local p=entity:ToPlayer(); if not p or not ready then return end
        local t=runtime[key(p)]
        if not t or not rushing(t) or payment(p,flags,source) or D.Flag(flags,'DAMAGE_FAKE') then return end
        t.damageReceipts=t.damageReceipts or {}
        t.damageReceipts[#t.damageReceipts+1]={health=D.Health(p),frame=now(),flags=flags,source=source and source.Entity}
        -- REPENTOGON's in-place argument override; no recursive second TakeDamage.
        return {Damage=amount*2}
    end
    local function postDamage(_,entity)
        local p=entity:ToPlayer(); if not p then return end
        local t=runtime[key(p)]; if not t or not t.damageReceipts then return end
        local receipt=table.remove(t.damageReceipts)
        if receipt and receipt.frame==now() and D.LostHealth(receipt.health,p) then
            C.End(t,'damage'); t.planned=nil
            if now()<freezeUntil then freezeUntil=now(); thaw() end
        end
    end
    local function owner(entity,depth,seen)
        if not exists(entity) or (depth or 0)>10 then return end
        seen=seen or {}; local hash=GetPtrHash(entity); if seen[hash] then return end; seen[hash]=true
        local p=entity:ToPlayer(); if p then return p end
        local familiar=entity:ToFamiliar(); if familiar then return familiar.Player end
        return owner(entity.Parent,(depth or 0)+1,seen) or owner(entity.SpawnerEntity,(depth or 0)+1,seen)
    end
    local function ownerKey(entity)
        if not entity then return end
        local id=GetPtrHash(entity)..':'..entity.InitSeed
        local p=owner(entity)
        if p then attackOwners[id]={entity=entity,key=key(p)}
        elseif exists(entity) and (exists(entity.Parent) or exists(entity.SpawnerEntity)) then
            -- A real replacement source can revoke ownership. A disappeared
            -- familiar merely clears native pointers; retain its projectile's
            -- creation snapshot until that projectile itself is removed.
            attackOwners[id]={entity=entity,key=false}
        end
        return p and key(p) or attackOwners[id] and attackOwners[id].key
    end
    local function hitRecord(e)
        -- Native death may expose a new GetData table. Keep attribution outside
        -- that table, scoped to this room and the entity's pointer plus InitSeed.
        local id=GetPtrHash(e)..':'..e.InitSeed
        local d=hits[id]
        if not d or d.type~=e.Type or d.variant~=e.Variant then
            d={entity=e,type=e.Type,variant=e.Variant};hits[id]=d
        end
        return d
    end
    local function statusApplied(_,e,source,kind)
        if not ready or not exists(e) or not e:ToNPC() or not statusOwnerFields[kind] then return end
        -- Emitted only after native eligibility and payload selection. Store a
        -- player key now, while a tear/familiar source is still alive.
        local k=ownerKey(source and source.Entity)
        hitRecord(e)[statusOwnerFields[kind]]=k or false
    end
    local function statusCopied(_,from,to,overwrite)
        if not ready or not exists(from) or not exists(to) or not to:ToNPC() then return end
        local a,b=hitRecord(from),hitRecord(to)
        for _,info in ipairs({{'poisonOwner',EntityFlag.FLAG_POISON,'GetPoisonDamage'},
            {'burnOwner',EntityFlag.FLAG_BURN,'GetBurnDamage'},
            {'bleedOwner',EntityFlag.FLAG_BLEED_OUT,'GetBleedingCountdown'}}) do
            -- Match native CopyStatusEffects payload overwrite/nonzero rules.
            if overwrite or from[info[3]] and from[info[3]](from)~=0 then
                b[info[1]]=from:HasEntityFlags(info[2]) and a[info[1]] or false
            end
        end
    end
    local function npcAttackSource(_,e,_,_,source)
        if e:ToNPC() then ownerKey(source and source.Entity) end
    end
    local function npcDamage(_,e,amount,flags,source)
        if not e:ToNPC() or amount<=0 or D.Flag(flags,'DAMAGE_FAKE') then return end
        local d=hitRecord(e)
        local k=ownerKey(source and source.Entity)
        local kind=nativeAttribution and source and Isaac.GetCurrentDotDamageKind(e,source) or 0
        if statusOwnerFields[kind] then
            d.NeverbirthDriveLastHit=d[statusOwnerFields[kind]] or false
            return
        end
        -- Unscoped/sourceless synthetic damage is not a native status tick.
        -- Never infer its owner from active flags or the last ordinary attacker.
        -- Clear stale ownership on a genuine environmental final hit.
        d.NeverbirthDriveLastHit=k or false
    end
    local function died(_,npc)
        local d=hits[GetPtrHash(npc)..':'..npc.InitSeed]
        if not d then return end
        if d.NeverbirthDrivePaid or not npc:IsEnemy() or npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return end
        d.NeverbirthDrivePaid=true
        local k=d.NeverbirthDriveLastHit
        if not k then return end
        for _,p in ipairs(players()) do
            if key(p)==k and held(p) then
                local s,t=data(p),state(p); C.SetGauge(s,t,s.gauge+1,'Gain'); flush(p,s,t); return
            end
        end
    end
    local function input(_,entity,hook,action)
        if readingInput>0 or not entity or not ready then return end
        local p=entity:ToPlayer(); if not p then return end
        local t=runtime[key(p)]
        local blocked=now()<freezeUntil
        if t then
            if t.rushShot and t.rushShot.primed and (t.mode=='rush' or t.mode=='idle' and t.rushShot.finishing)
                and action>=ButtonAction.ACTION_SHOOTLEFT and action<=ButtonAction.ACTION_SHOOTDOWN then
                blocked=true
            end
            if t.mode=='recovery' then
                blocked=action>=ButtonAction.ACTION_LEFT and action<=ButtonAction.ACTION_DROP
            elseif t.mode=='rush' then
                blocked=blocked or action>=ButtonAction.ACTION_LEFT and action<=ButtonAction.ACTION_DOWN
                if t.moveFrames<5 and not (t.rushShot and t.rushShot.charge and not t.rushShot.primed) then
                    blocked=blocked or action>=ButtonAction.ACTION_SHOOTLEFT and action<=ButtonAction.ACTION_SHOOTDOWN
                end
            elseif t.mode=='blue' then
                -- The raw reader still sees direction for rush; native movement
                -- and shooting receive no input while holding blue.
                blocked=blocked or action>=ButtonAction.ACTION_LEFT and action<=ButtonAction.ACTION_SHOOTDOWN
            end
            -- A long Drop press can discard an active for some characters. Permit
            -- only Schoolbag's fresh switch edge while blue/rushing, never the hold.
            if busy(t) and action==ButtonAction.ACTION_DROP and t.mode~='recovery' then
                blocked=blocked or hook~=InputHook.IS_ACTION_TRIGGERED
            end
        end
        if blocked then return hook==InputHook.GET_ACTION_VALUE and 0 or false end
    end
    local function preUse(_,used,_,p)
        local t=runtime[key(p)]
        if now()<freezeUntil or (t and t.mode=='recovery') then return true end
        if paymentItems[used] and t then t.paymentFrame=now() end
    end
    local function use(_,item,_,p,flags,slot)
        if item~=ID then return end
        if flags & UseFlag.USE_CARBATTERY==0 then
            local t=state(p)
            if not t.lastPressed then start(p,slot or 0) end
        end
        return {Discharge=false,Remove=false,ShowAnim=false}
    end
    local function pickup(_,item,collider)
        local p=collider:ToPlayer(); if not p or item.Variant~=PickupVariant.PICKUP_COLLECTIBLE then return end
        local t=runtime[key(p)]; if not busy(t) then return end
        local config=Isaac.GetItemConfig():GetCollectible(item.SubType)
        if config and config.Type==ItemType.ITEM_ACTIVE and p:GetActiveItem(0)==ID then
            if p:HasCollectible(CollectibleType.COLLECTIBLE_SCHOOLBAG) and p:GetActiveItem(1)==0 then return end
            return true
        end
    end
    local function weaponFired(_,_,amount,entity,w)
        local p=entity and entity:ToPlayer(); if not p or amount<=0 or not ready then return end
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
    local function evaluate(_,p,flag)
        if not ready then return end
        local s=data(p); if not s then return end
        local t=runtime[key(p)]
        if flag==CacheFlag.CACHE_DAMAGE and s.burnout then p.Damage=p.Damage*.75 end
        if flag==CacheFlag.CACHE_FIREDELAY then
            p.MaxFireDelay=C.Tears(p.MaxFireDelay,s.burnout,t and t.reward and t.reward.started~=nil)
        end
    end
    local function postUpdate()
        if not ready or game:IsPaused() then return end
        if now()>=freezeUntil and next(frozen) then thaw() end
        for _,v in pairs(frozen) do if exists(v.entity) then v.entity.Position=v.position; v.entity.Velocity=Vector(0,0) end end
        for id,hit in pairs(hits) do
            if not exists(hit.entity) then hits[id]=nil
            else
                if not hit.entity:HasEntityFlags(EntityFlag.FLAG_POISON) then hit.poisonOwner=nil end
                if not hit.entity:HasEntityFlags(EntityFlag.FLAG_BURN) then hit.burnOwner=nil end
                if not hit.entity:HasEntityFlags(EntityFlag.FLAG_BLEED_OUT) then hit.bleedOwner=nil end
            end
        end
        for id,attack in pairs(attackOwners) do
            if not exists(attack.entity) then attackOwners[id]=nil end
        end
        for _,t in pairs(runtime) do
            if exists(t.player) then
                restoreShoot(t.player,t)
                if t.rushShot and t.rushShot.finishing and t.rushShot.emittedAt<now() then t.rushShot=nil end
                t.damageReceipts={}
                local s=data(t.player)
                if s then
                    if held(t.player) and canControl(t.player) and now()>=freezeUntil then C.Regen(s,t,t.walking) end
                    flush(t.player,s,t)
                end
            end
        end
        if visuals then visuals.Update() end
        if now()%30==0 then
            for _,t in pairs(runtime) do if t.saveDirty then save(); break end end
        end
    end
    local function started(_,continued)
        restoreAll(); runtime={}; hits={}; attackOwners={}; ready=true
        if not continued then context.GetSaveRoot().driveGlove=nil end
        for _,p in ipairs(players()) do
            local s=data(p)
            if s then local t=state(p); t.cacheDirty=true; refresh(p,t) end
        end
        if visuals then visuals.ClearRoom() end
    end
    local function exit()
        restoreAll(); if ready then save() end; ready=false; runtime={}; hits={}; attackOwners={}
        if visuals then visuals.ClearRoom() end
    end
    local api={ItemId=ID,GetState=function(p) return data(p),state(p) end,
        IsActive=function(p) return busy(runtime[key(p)]) end,Core=C,Damage=D}
    mod.DriveGlove=api
    local function peek(p)
        local saved=context.GetSaveRoot().driveGlove
        local k=key(p)
        return saved and saved.players[k],runtime[k]
    end
    visuals=include('drive_glove_visuals')(mod,{GetState=peek,GetPlayers=players,IsHeld=held,
        IsReady=function() return ready end,Key=key})
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,-30000,prePlayer)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,30000,postPlayer)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-30000,earlyDamage)
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,30000,lateDamage,EntityType.ENTITY_PLAYER)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,30000,postDamage,EntityType.ENTITY_PLAYER)
    -- PRE only captures a live attack chain. Credit is committed by the native
    -- accepted-damage POST, so a later canceller cannot steal a queued death.
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,30000,npcAttackSource)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_TAKE_DMG,30000,npcDamage)
    mod:AddCallback(ModCallbacks.MC_POST_NPC_DEATH,died)
    if nativeAttribution then
        mod:AddCallback('REPENTOGON_POST_DOT_APPLIED',statusApplied)
        mod:AddCallback('REPENTOGON_POST_DOT_COPY',statusCopied)
        for _,name in ipairs({'MC_POST_TEAR_INIT','MC_POST_LASER_INIT','MC_POST_KNIFE_INIT','MC_POST_BOMB_INIT','MC_POST_EFFECT_INIT'}) do
            if ModCallbacks[name] then mod:AddCallback(ModCallbacks[name],function(_,entity) ownerKey(entity) end) end
        end
    else
        Isaac.DebugString('[Drive Glove] Status attribution API unavailable; sourceless DOT kills are not guessed.')
    end
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-30000,input)
    mod:AddCallback(ModCallbacks.MC_PRE_USE_ITEM,preUse)
    mod:AddCallback(ModCallbacks.MC_USE_ITEM,use,ID)
    mod:AddCallback(ModCallbacks.MC_PRE_USE_CARD,function(_,_,p)
        if now()<freezeUntil or state(p).mode=='recovery' then return true end
    end)
    mod:AddCallback(ModCallbacks.MC_PRE_USE_PILL,function(_,_,_,p)
        if now()<freezeUntil or state(p).mode=='recovery' then return true end
    end)
    mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION,pickup,PickupVariant.PICKUP_COLLECTIBLE)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,weaponFired)
    mod:AddCallback(ModCallbacks.MC_POST_WEAPON_FIRE,function(_,w,_,isShooting,isInterpolated)
        local e=w:GetOwner();local p=e and e:ToPlayer()
        local t=p and runtime[key(p)]
        if t and t.mode=='rush' and t.rushShot and isShooting and not isInterpolated
            and t.rushShot.identity==weaponIdentity(w) then
            if t.rushShot.charge then w:SetCharge(t.rushShot.charge); t.rushShot.charge=nil end
            t.rushShot.primed=true
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_EVALUATE_CACHE,30000,evaluate)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE,postUpdate)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED,started)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT,exit)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM,function() if ready then cancelRoom(); save() end end)
    mod:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD,cancelRoom)
    mod:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE,function(_,item,_,_,_,_,p)
        if item==ID and ready then data(p); save() end
    end,ID)
    for _,name in ipairs({'MC_PRE_TEAR_UPDATE','MC_PRE_FAMILIAR_UPDATE','MC_PRE_BOMB_UPDATE',
        'MC_PRE_PICKUP_UPDATE','MC_PRE_KNIFE_UPDATE','MC_PRE_PROJECTILE_UPDATE','MC_PRE_LASER_UPDATE',
        'MC_PRE_EFFECT_UPDATE','MC_PRE_NPC_UPDATE','MC_PRE_SLOT_UPDATE'}) do
        mod:AddPriorityCallback(ModCallbacks[name],-30000,function(_,e) if ready then return freeze(e) end end)
    end
    mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD,function(_,unloaded) if unloaded==mod then exit() end end)
    mod:AddCallback(ModCallbacks.MC_EXECUTE_CMD,function(_,command,args)
        if command~='driveglove' then return end
        local mode,arg=(args or ''):match('^(%S+)%s*(.*)$')
        local p=players()[1]; if not p then return end
        if mode=='give' then p:AddCollectible(ID,0,true,0); data(p); save() end
        local s,t=data(p),state(p)
        if mode=='meter' and tonumber(arg) and s then C.SetGauge(s,t,tonumber(arg),'Gain'); flush(p,s,t); save() end
        if s and (mode=='status' or mode=='give' or mode=='meter') then
            Isaac.ConsoleOutput(string.format('Drive Glove v1: id=%d meter=%.4f burnout=%s mode=%s moves=%d remaining=%.3f reward=%s\n',
                ID,s.gauge,tostring(s.burnout),t.mode,t.moveFrames,t.remaining or 0,t.reward and (t.reward.started and 'active' or 'pending') or 'none'))
        else Isaac.ConsoleOutput('driveglove give / status / meter 0..6 (debug meter only)\n') end
    end)
    return api
end
