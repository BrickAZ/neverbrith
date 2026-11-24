-- Opt-in native acceptance probe. Never included by the normal mod loader.
return function(mod)
    local started,age,index=false,0,0
    local inputs={}
    -- Direct Lua reads do not dispatch MC_INPUT_ACTION. Feed both surfaces for
    -- this synthetic-input probe; damage, movement and weapons remain native.
    local nativeActionValue=Input.GetActionValue
    Input.GetActionValue=function(action,controller)
        if started and controller==Isaac.GetPlayer(0).ControllerIndex then return inputs[action] or 0 end
        return nativeActionValue(action,controller)
    end
    local failures,checks=0,0
    local function log(s) Isaac.DebugString('[Drive Glove runtime] '..s) end
    local function check(label,value,detail)
        checks=checks+1; if not value then failures=failures+1 end
        log((value and 'PASS ' or 'FAIL ')..label..' '..tostring(detail or ''))
    end
    local function input(action,value) inputs[action]=value end
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,900000,function(_,_,hook,action)
        if not started then return end
        local value=inputs[action] or 0
        return hook==InputHook.GET_ACTION_VALUE and value or value>0
    end)
    local function setup()
        local p=Isaac.GetPlayer(0); local api=mod.DriveGlove
        -- The mod spawns Seven Curses at the starting-room centre. Teleporting
        -- our fixture there otherwise collects it between cases.
        for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do e:Remove() end
        if mod.RingOfSevenCursesTestAPI then
            mod.RingOfSevenCursesTestAPI.ResetForTest()
            p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
        end
        if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
        p:ResetDamageCooldown(); p:SetDamageCountdown(0); p:SetFireDamageCooldown(0)
        p:AddHearts(12); p.Position=Game():GetRoom():GetCenterPos(); p.Velocity=Vector(0,0)
        local s,t=api.GetState(p)
        api.Core.SetGauge(s,t,6); api.Core.End(t,'probe'); t.needsRelease=false; t.lastPressed=false
        t.reward=nil; t.gift=nil; t.action=ButtonAction.ACTION_ITEM; t.slot=0
        inputs={}
        return p,s,t,api.Core
    end
    local function projectile(p)
        local e=Isaac.Spawn(EntityType.ENTITY_PROJECTILE,0,0,p.Position-Vector(50,0),Vector(5,0),nil)
        e.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE
        return e
    end
    local function hit(p,e,flags,amount) return p:TakeDamage(amount or 1,flags or DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(e),0) end
    local pendingKill
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,900000,function(_,e,amount,flags,source)
        if e:ToNPC() and flags & DamageFlag.DAMAGE_POISON_BURN~=0 then
            log('DOT SOURCE type='..tostring(source.Type)..' entity='..tostring(source.Entity and source.Entity.Type)..' amount='..amount)
        end
    end)
    local cases={
        function()
            local p,s=setup(); input(ButtonAction.ACTION_RIGHT,1); local e=projectile(p); local before=p:GetHearts()
            hit(p,e); check('normal guard health',p:GetHearts()==before,p:GetHearts()); check('normal guard cost',s.gauge==5,s.gauge)
            check('native iframe',p:GetDamageCooldown()==60,p:GetDamageCooldown()); hit(p,e); check('iframe no second fee',s.gauge==5,s.gauge); e:Remove()
        end,
        function()
            local p,s,t,C=setup(); input(ButtonAction.ACTION_ITEM,1); C.StartBlue(s,t,Game():GetFrameCount()); local e=projectile(p)
            hit(p,e); check('perfect refill',s.gauge==6,s.gauge); check('perfect reward',t.reward~=nil)
            check('perfect success window recorded',t.successAt==Game():GetFrameCount()); e:Remove()
        end,
        function()
            local p,s,t,C=setup(); input(ButtonAction.ACTION_ITEM,1); C.StartBlue(s,t,Game():GetFrameCount()-4); local e=projectile(p)
            hit(p,e); check('ordinary blue returns .5',s.gauge==6,s.gauge); check('ordinary no reward',t.reward==nil); e:Remove()
        end,
        function()
            local p,s,t,C=setup(); C.SetGauge(s,t,.5); input(ButtonAction.ACTION_RIGHT,1); local e=projectile(p); local before=p:GetHearts()
            hit(p,e); check('overdraw guard health',p:GetHearts()==before); check('overdraw burnout',s.gauge==0 and s.burnout)
            check('burnout damage modifier',math.abs(p.Damage-2.625)<.01,p.Damage); e:Remove()
        end,
        function()
            local p,s,t,C=setup(); input(ButtonAction.ACTION_ITEM,1); C.StartBlue(s,t,Game():GetFrameCount()); local before=p:GetHearts()
            hit(p,p,DamageFlag.DAMAGE_IV_BAG|DamageFlag.DAMAGE_INVINCIBLE|DamageFlag.DAMAGE_NO_MODIFIERS)
            check('payment really paid',p:GetHearts()<before); check('payment no reward',not t.reward)
        end,
        function()
            local p,s,t,C=setup(); input(ButtonAction.ACTION_ITEM,1); C.StartBlue(s,t,Game():GetFrameCount())
            local bomb=Isaac.Spawn(EntityType.ENTITY_BOMBDROP,0,0,p.Position-Vector(60,0),Vector(0,0),p)
            local before=p:GetHearts(); hit(p,bomb,DamageFlag.DAMAGE_EXPLOSION|DamageFlag.DAMAGE_NO_MODIFIERS)
            check('bomb bypasses blue',p:GetHearts()<before); bomb:Remove()
        end,
        function()
            local p,s,t,C=setup(); C.StartBlue(s,t,Game():GetFrameCount()); C.StartRush(s,t,Game():GetFrameCount(),1,0)
            local before=p:GetHearts(); local e=projectile(p); hit(p,e)
            check('rush damage doubled',before-p:GetHearts()==2,before-p:GetHearts()); check('actual hurt stops rush',t.mode=='idle',t.mode); e:Remove()
        end,
        function()
            local p,s,t,C=setup(); p:AddCollectible(CollectibleType.COLLECTIBLE_HOLY_MANTLE,0,true)
            C.StartBlue(s,t,Game():GetFrameCount()); C.StartRush(s,t,Game():GetFrameCount(),1,0)
            local before=p:GetHearts(); local e=projectile(p); hit(p,e)
            check('mantle health preserved',p:GetHearts()==before); check('mantle allows rush',t.mode=='startup',t.mode)
            p:RemoveCollectible(CollectibleType.COLLECTIBLE_HOLY_MANTLE); e:Remove()
        end,
        function()
            local p,s,t,C=setup(); C.SetGauge(s,t,1); p:RemoveCollectible(mod.DriveGlove.ItemId)
            p:AddCollectible(mod.DriveGlove.ItemId,0,false); check('reacquire no refill',s.gauge==1,s.gauge)
        end,
        function()
            local p,s=setup()
            p:AddCollectible(CollectibleType.COLLECTIBLE_HOLY_MANTLE)
            p:AddCollectible(CollectibleType.COLLECTIBLE_BLOODY_LUST)
            local damage=p.Damage; local e=projectile(p); input(ButtonAction.ACTION_RIGHT,1)
            hit(p,e)
            check('guard before native mantle',p:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_HOLY_MANTLE))
            check('guard no Bloody Lust hurt benefit',p.Damage==damage,p.Damage)
            p:RemoveCollectible(CollectibleType.COLLECTIBLE_HOLY_MANTLE);p:RemoveCollectible(CollectibleType.COLLECTIBLE_BLOODY_LUST);e:Remove()
        end,
        function()
            local p,s,t,C=setup(); C.SetGauge(s,t,2); C.StartBlue(s,t,Game():GetFrameCount())
            local e=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,p.Position+Vector(90,0),Vector(0,0),nil)
            e.HitPoints=1; e:TakeDamage(100,DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(p),0)
            input(ButtonAction.ACTION_ITEM,1); pendingKill={state=s,enemy=e}
        end,
        function()
            -- Native NPC death finalizes on its later update, not TakeDamage's
            -- return. Blue drains .01 per tick while waiting for that update.
            check('native owned kill during blue',pendingKill.state.gauge>2 and pendingKill.state.gauge<2.6,pendingKill.state.gauge)
        end,
        function()
            local p,s,t,C=setup(); C.SetGauge(s,t,2); C.StartBlue(s,t,Game():GetFrameCount())
            local familiar=Isaac.Spawn(EntityType.ENTITY_FAMILIAR,FamiliarVariant.BROTHER_BOBBY,0,p.Position,Vector(0,0),p):ToFamiliar()
            familiar.Player=p
            local tear=Isaac.Spawn(EntityType.ENTITY_TEAR,0,0,p.Position,Vector(0,0),familiar)
            local e=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,p.Position+Vector(90,0),Vector(0,0),nil)
            e.HitPoints=1;e:TakeDamage(100,DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(tear),0)
            tear:Remove();familiar:Remove()
            input(ButtonAction.ACTION_ITEM,1);pendingKill={state=s,enemy=e}
        end,
        function()
            check('native familiar tear kill during blue',pendingKill.state.gauge>2 and pendingKill.state.gauge<2.6,pendingKill.state.gauge)
        end,
        function()
            local p,s,t,C=setup();C.SetGauge(s,t,2);C.StartBlue(s,t,Game():GetFrameCount())
            local e=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,p.Position+Vector(90,0),Vector(0,0),nil)
            e.HitPoints=1
            local tear=p:FireTear(e.Position,Vector(0,0),false,false,false)
            tear.CollisionDamage=.1;tear.TearFlags=tear.TearFlags | TearFlags.TEAR_POISON
            input(ButtonAction.ACTION_ITEM,1);pendingKill={state=s,enemy=e}
        end,
        function()
            check('native poison tear kill',pendingKill.state.gauge>2 and pendingKill.state.gauge<2.6,pendingKill.state.gauge)
        end,
    }
    local travel,travelStarted,travelChecked,firstMoveAt,freezeOrigin
    local function movementProbe()
        local p,s,t,C=mod.DriveGlove.GetState and Isaac.GetPlayer(0)
        if not travelStarted then
            p,s,t,C=setup(); travelStarted=Game():GetFrameCount(); travel=0
            input(ButtonAction.ACTION_ITEM,1)
            return
        end
        p=Isaac.GetPlayer(0); s,t=mod.DriveGlove.GetState(p)
        local tick=Game():GetFrameCount()-travelStarted
        if tick<22 then log('MOVE tick='..tick..' mode='..t.mode..' n='..t.moveFrames..' reason='..tostring(t.reason)..' xy='..p.Position.X..','..p.Position.Y) end
        if tick==1 or tick==3 then input(ButtonAction.ACTION_RIGHT,1) end
        if tick==2 then input(ButtonAction.ACTION_RIGHT,0) end
        if t.mode=='startup' and not freezeOrigin then freezeOrigin=p.Position end
        if t.mode=='startup' then check('startup native position '..tick,(p.Position-freezeOrigin):Length()<.01) end
        if t.mode=='rush' and not firstMoveAt then
            firstMoveAt=Game():GetFrameCount()
            check('startup exactly five ticks',firstMoveAt-t.rushAt==5,firstMoveAt-t.rushAt)
        end
        if t.mode=='rush' and t.moveFrames==4 then
            travel=(p.Position-freezeOrigin):Length(); inputs={[ButtonAction.ACTION_LEFT]=1}
        elseif travel>0 and not travelChecked then
            travelChecked=true
            check('native four movement frames',math.abs(travel-4*260/18)<.02,travel)
            check('native reverse brake',t.mode=='idle' and t.reason=='brake',t.mode..':'..tostring(t.reason))
        end
        if tick==28 then
            check('input path reached rush and brake',travelChecked==true)
            p,s,t,C=setup(); C.SetGauge(s,t,3); input(ButtonAction.ACTION_LEFT,1)
        end
        if tick>28 and tick<36 then log('WALK tick='..tick..' walking='..tostring(t.walking)..' gauge='..s.gauge..' x='..p.Position.X) end
        if tick==36 then
            check('walking adds fifty percent',s.gauge>3.03,s.gauge)
            inputs={}; log('DONE checks='..checks..' failures='..failures)
        end
    end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end; started=true
        log('START native candidate '..tostring(REPENTOGON.Version))
        Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1
        if index>=#cases then if not travelStarted or Game():GetFrameCount()-travelStarted<=36 then movementProbe() end; return end
        if age<100 or age%30~=0 then return end
        index=index+1
        local ok,err=pcall(cases[index]); if not ok then check('case '..index..' exception',false,err) end
        if index==#cases then inputs={} end
    end)
end
