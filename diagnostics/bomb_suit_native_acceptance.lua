-- Temporary native runner; normal gameplay never includes this file.
return function(mod,options)
    local function log(s)Isaac.DebugString('[Bomb Suit native] '..s)end
    local id=Isaac.GetItemIdByName('Bomb Suit');if id<0 then id=Isaac.GetItemIdByName('炸弹套装')end
    local C=CollectibleType
    local cases={{name='ordinary'},{name='mr-mega',items={C.COLLECTIBLE_MR_MEGA}},
        {name='sad-hot',items={C.COLLECTIBLE_SAD_BOMBS,C.COLLECTIBLE_HOT_BOMBS}},
        {name='scatter',items={C.COLLECTIBLE_SCATTER_BOMBS}},
        {name='remote',items={C.COLLECTIBLE_REMOTE_DETONATOR}},
        {name='brimstone',items={C.COLLECTIBLE_BRIMSTONE_BOMBS}},
        {name='bomber',items={C.COLLECTIBLE_BOMBER_BOY}},
        {name='blood',items={C.COLLECTIBLE_BLOOD_BOMBS}},
        {name='ghost',items={C.COLLECTIBLE_GHOST_BOMBS}},
        {name='iv-during',iv=true},{name='iv-idle',idleIV=true}}
    local scatterCases={cases[4],{name='mega-scatter',items={C.COLLECTIBLE_MR_MEGA,C.COLLECTIBLE_SCATTER_BOMBS}},
        {name='hot-scatter',items={C.COLLECTIBLE_HOT_BOMBS,C.COLLECTIBLE_SCATTER_BOMBS}}}
    if options and options.Case=='scatter'then cases=scatterCases
    else cases[#cases+1]=scatterCases[2];cases[#cases+1]=scatterCases[3]end
    local phase,index,ticks,passed,total='menu',0,0,0,0
    local current,expected,observed,expectedHits,hits,targets={},nil,nil,{},{},{}
    local healthAfter,bombCount,baseSpeed,shootChecked,startFrame
    local forceBomb=false
    local function check(name,ok,detail)
        total=total+1;if ok then passed=passed+1 end
        log((ok and 'PASS 'or'FAIL ')..current.name..': '..name..' '..tostring(detail or ''))
    end
    local function config(b)return {damage=b.ExplosionDamage,flags=tostring(b.Flags),radius=b.RadiusMultiplier,
        fetus=b.IsFetus,variant=b.Variant,seed=b.InitSeed,frame=Game():GetFrameCount(),x=b.Position.X,y=b.Position.Y}end
    local function prepareTargets(p,center)
        center=center or p.Position
        for _,t in ipairs(targets)do if t:Exists()then t:Remove()end end;targets={}
        for _,d in ipairs({30,100,140})do
            local t=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,center+Vector(d,0),Vector.Zero,nil):ToNPC()
            t.MaxHitPoints=10000;t.HitPoints=10000
            t.CollisionDamage=0
            t:AddFreeze(EntityRef(p),900)
            t:AddEntityFlags(EntityFlag.FLAG_FREEZE|EntityFlag.FLAG_NO_KNOCKBACK|EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
            t:GetData().bombSuitDistance=d;targets[#targets+1]=t
        end
    end
    local bootRenders=0
    -- MC_PRE_RENDER is the verified Manager::Render hook, including intro.
    -- The menu button-layout hook cannot run while this host stalls in intro.
    mod:AddCallback(ModCallbacks.MC_PRE_RENDER,function()
        if phase~='menu'then return end
        bootRenders=bootRenders+1;if bootRenders<15 then return end;phase='starting'
        log('START version='..REPENTOGON.Version..' local-id=63 runtime-id='..id)
        Isaac.StartNewGame(0,0,0,31415926)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,999999,function()
        phase='wait';ticks=0;current={name='startup'};check('module-loaded',mod.BombSuit~=nil)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,-999999,function(_,entity,hook,action)
        if forceBomb and entity and entity:ToPlayer()and action==ButtonAction.ACTION_BOMB then
            return hook==InputHook.GET_ACTION_VALUE and 1 or true
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_PLAYER_USE_BOMB,function(_,p,b)
        if phase~='baseline'then return end
        expected=config(b);b:GetData().bombSuitBaseline=true;b:SetExplosionCountdown(1)
        log('CONTROL origin='..b.Position.X..','..b.Position.Y..' player='..p.Position.X..','..p.Position.Y)
        log('CONTROL target age='..targets[1].FrameCount..' size='..targets[1].Size)
        forceBomb=false;phase='control';ticks=0
        check('ordinary-control-not-fetus',not b.IsFetus)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-30000,function(_,p,amount,flags,ref)
        if phase=='run'and (flags&DamageFlag.DAMAGE_EXPLOSION)~=0 then
            local s=ref and ref.Entity
            log('PLAYER-BLAST amount='..amount..' age='..tostring(mod.BombSuit.GetAge(p))
                ..' source='..tostring(s and s.Type)..'.'..tostring(s and s.Variant)
                ..' owner='..tostring(s and s:GetData().NeverbirthBombSuitOwner)
                ..' spawner='..tostring(s and s.SpawnerEntity and s.SpawnerEntity.Type)
                ..' parent='..tostring(s and s.Parent and s.Parent.Type))
        end
        if phase=='baseline'or phase=='control'then return false end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_BOMB_UPDATE,999999,function(_,b)
        if phase=='run'and not observed and b:GetData().NeverbirthBombSuitOwner then observed=config(b)end
    end)
    mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN,function(_,kind,variant,subtype,pos,vel,spawner,seed)
        if phase=='run'and current.name:find('scatter')and kind==EntityType.ENTITY_BOMBDROP then
            log('SPAWN bomb seed='..seed..' variant='..variant..' spawnerType='..tostring(spawner and spawner.Type)
                ..' spawnerOwner='..tostring(spawner and spawner:GetData().NeverbirthBombSuitOwner)
                ..' pos='..pos.X..','..pos.Y..' vel='..vel.X..','..vel.Y)
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_BOMB_UPDATE,30000,function(_,b)
        if phase=='run'and current.name:find('scatter')and b.FrameCount<=1 then
            log('BOMB-CANDIDATE seed='..b.InitSeed..' variant='..b.Variant..' damage='..b.ExplosionDamage
                ..' scale='..b:GetScale()..' flags='..tostring(b.Flags)..' frame='..b.FrameCount
                ..' countdown='..b:GetExplosionCountdown()..' fetus='..tostring(b.IsFetus)
                ..' owner='..tostring(b:GetData().NeverbirthBombSuitOwner))
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,999999,function(_,p)
        if phase=='run'and mod.BombSuit.IsActive(p)and not shootChecked then
            check('native-shoot-disabled',not p:CanShoot());shootChecked=true
        end
        if phase=='baseline'or phase=='control'or phase=='run'then
            p.Position=Game():GetRoom():GetCenterPos();p.Velocity=Vector.Zero
        end
    end)
    mod:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,function(_,target,damage,flags,ref)
        local d=target:GetData().bombSuitDistance
        if not d or (flags&DamageFlag.DAMAGE_EXPLOSION)==0 then return end
        log('TARGET-BLAST '..current.name..' '..phase..' nominal='..d..' actual='..
            (target.Position-Game():GetRoom():GetCenterPos()):Length()..' damage='..damage)
        local s=ref and ref.Entity
        if phase=='control'and expected and s and s.InitSeed==expected.seed then expectedHits[d]=expectedHits[d]or damage
        elseif phase=='run'and observed and s and s.InitSeed==observed.seed then hits[d]=hits[d]or damage end
    end,EntityType.ENTITY_GAPER)
    local function arm(p)
        prepareTargets(p);p:AddCollectible(id,0,true);p:AddHearts(24);p:ResetDamageCooldown()
        observed=nil;hits={};shootChecked=false;bombCount=p:GetNumBombs();baseSpeed=p.MoveSpeed
        local hp=p:GetHearts();phase='run';ticks=0;startFrame=Game():GetFrameCount()
        p:TakeDamage(1,DamageFlag.DAMAGE_INVINCIBLE|DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(nil),0)
        healthAfter=p:GetHearts()
        check('first-hit-lands',hp>healthAfter,hp..'->'..healthAfter)
        check('armed',mod.BombSuit.IsActive(p))
        check('speed-plus-half',math.abs(p.MoveSpeed-baseSpeed-0.5)<0.001,p.MoveSpeed)
    end
    local function setup(p)
        while p:HasCollectible(id)do p:RemoveCollectible(id)end
        for _,c in ipairs(cases)do for _,item in ipairs(c.items or {})do
            while p:HasCollectible(item)do p:RemoveCollectible(item)end
        end end
        for _,item in ipairs(current.items or {})do p:AddCollectible(item,0,true)end
        p:AddMaxHearts(12-p:GetMaxHearts(),true);p:AddHearts(12);p:ResetDamageCooldown()
        p.Position=Game():GetRoom():GetCenterPos();p.Velocity=Vector.Zero
        if current.idleIV then
            p:AddCollectible(id,0,true);local hp=p:GetHearts();phase='idle';ticks=0;observed=nil
            p:UseActiveItem(C.COLLECTIBLE_IV_BAG,UseFlag.USE_NOANIM|UseFlag.USE_NOANNOUNCER)
            check('idle-IV-does-not-arm',not mod.BombSuit.IsActive(p));check('IV-pays-health',p:GetHearts()<hp)
        else
            prepareTargets(p);expectedHits={};expected=nil;observed=nil
            p:AddBombs(1);p:SetBombPlaceDelay(0);p.ControlsEnabled=false
            phase='baselineWait';ticks=0;forceBomb=false
        end
    end
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        if phase=='menu'or phase=='starting'or phase=='done'then return end
        ticks=ticks+1;local p=Isaac.GetPlayer(0)
        p.ControlsEnabled=phase=='baseline'
        if phase=='wait'and ticks>=35 then
            index=index+1;current=cases[index]
            if not current then phase='done';log('DONE passed='..passed..' total='..total);return end
            log('CASE '..current.name);setup(p)
        elseif phase=='baselineWait'and ticks>=15 then
            phase='baseline';ticks=0;forceBomb=true;p.ControlsEnabled=true
        elseif phase=='control'and ticks>=60 then
            check('ordinary-control-exploded',expectedHits[30]~=nil,expectedHits[30]);arm(p)
        elseif phase=='baseline'and ticks>40 then
            check('ordinary-control-spawn',false);phase='wait';ticks=34;forceBomb=false
        elseif phase=='idle'and ticks>=95 then
            check('idle-IV-no-delayed-bomb',observed==nil);phase='wait';ticks=34
        elseif phase=='run'then
            if ticks==20 then
                local hp=p:GetHearts();p:ResetDamageCooldown()
                p:TakeDamage(1,DamageFlag.DAMAGE_INVINCIBLE|DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(nil),0)
                check('forced-hit-immune',p:GetHearts()==hp)
                if current.iv then
                    p:UseActiveItem(C.COLLECTIBLE_IV_BAG,UseFlag.USE_NOANIM|UseFlag.USE_NOANNOUNCER)
                    check('IV-pays-during-fuse',p:GetHearts()<hp);healthAfter=p:GetHearts()
                end
            elseif ticks==89 then check('no-early-carrier',observed==nil)
            elseif ticks==91 then
                check('carrier-created',observed~=nil)
                if observed then
                    check('exact-90-frame-trigger',observed.frame-startFrame==90,observed.frame-startFrame)
                    check('ordinary-damage',observed.damage==expected.damage,observed.damage..' control='..expected.damage)
                    check('ordinary-flags',observed.flags==expected.flags,observed.flags)
                    check('ordinary-radius-field',observed.radius==expected.radius,observed.radius)
                    check('normal-not-fetus',not observed.fetus)
                end
                check('fuse-ended',not mod.BombSuit.IsActive(p));check('speed-restored',math.abs(p.MoveSpeed-baseSpeed)<0.001)
                check('bomb-resource-preserved',p:GetNumBombs()==bombCount)
            elseif ticks==105 then
                check('actual-explosion-damages-near-target',hits[30]~=nil,hits[30])
                for _,d in ipairs({30,100,140})do
                    check('ordinary-hit-at-distance-'..d,hits[d]==expectedHits[d],tostring(hits[d])..' control='..tostring(expectedHits[d]))
                end
            elseif ticks>=135 then
                check('no-root-or-late-self-damage',p:GetHearts()>=healthAfter,p:GetHearts()..' before='..healthAfter)
                check('no-self-retrigger',not mod.BombSuit.IsActive(p));phase='wait';ticks=34
            end
        end
    end)
end
