-- Opt-in native input/weapon/state/audio probe, loaded only by the state-safe runner.
return function(mod)
    local started,age,checks,failures=false,0,0,0
    local inputs,ids,counts={},{},{}
    local fired,blueWeaponLeaks,blueInputLeaks=0,0,0
    local origin,regenAt,exitAt
    local sfx=SFXManager()
    local function log(s)Isaac.DebugString('[Drive Glove runtime] '..s)end
    local function check(name,ok,detail)
        checks=checks+1;if not ok then failures=failures+1 end
        log((ok and 'PASS ' or 'FAIL ')..name..' '..tostring(detail or ''))
    end
    for _,name in ipairs({'Blue Start','Rush Start','Burnout Enter','Burnout Exit'}) do
        local id=Isaac.GetSoundIdByName('Drive Glove '..name);ids[name]=id;counts[id]=0
    end
    local function state()return mod.DriveGlove.GetState(Isaac.GetPlayer(0))end
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_SFX_PLAY,-900000,function(_,id)
        if not counts[id] then return false end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_SFX_PLAY,function(_,id,volume,delay,loop,pitch)
        if counts[id] then
            counts[id]=counts[id]+1
            log('AUDIO id='..id..' count='..counts[id]..' frame='..Game():GetFrameCount())
            check('original pitch nonlooping native SFX',volume==1 and delay==0 and not loop and pitch==1)
            if id==ids['Burnout Exit'] then exitAt=Game():GetFrameCount() end
        end
    end)
    local originalValue=Input.GetActionValue
    Input.GetActionValue=function(action,controller)
        if started and controller==Isaac.GetPlayer(0).ControllerIndex then return inputs[action] or 0 end
        return originalValue(action,controller)
    end
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,900000,function(_,_,hook,action)
        if not started then return end
        local v=inputs[action] or 0
        return hook==InputHook.GET_ACTION_VALUE and v or v>0
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,900000,function(_,p)
        if not started or age<101 then return end
        local _,t=state()
        if t.mode=='blue' then
            if p:CanShoot() then blueWeaponLeaks=blueWeaponLeaks+1 end
            -- Calling the callback dispatcher directly exercises the production
            -- input interceptor without the raw-reader override used by this probe.
            for _,action in ipairs({ButtonAction.ACTION_RIGHT,ButtonAction.ACTION_SHOOTRIGHT}) do
                local v=Isaac.RunCallback(ModCallbacks.MC_INPUT_ACTION,p,InputHook.GET_ACTION_VALUE,action)
                if v~=0 then blueInputLeaks=blueInputLeaks+1 end
            end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,function(_,_,amount,entity)
        if started and age>=100 and entity and entity:ToPlayer() and amount>0 then fired=fired+amount end
    end)
    local function setup()
        local p=Isaac.GetPlayer(0);local api=mod.DriveGlove
        for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do e:Remove() end
        if mod.RingOfSevenCursesTestAPI then
            mod.RingOfSevenCursesTestAPI.ResetForTest();p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
        end
        if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
        p.Position=Game():GetRoom():GetCenterPos();p.Velocity=Vector(0,0)
        local s,t=state();api.Core.End(t,'probe');s.gauge=6;s.burnout=false;t.cacheDirty=true
        t.needsRelease=false;t.lastPressed=false;t.lastTick=nil;t.pressedActions={}
        t.reward=nil;t.gift=nil;t.grantCharge=nil;t.events={};t.action=ButtonAction.ACTION_ITEM;t.slot=0
        inputs={[ButtonAction.ACTION_ITEM]=1}
        return p,s,t
    end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true
        for name,id in pairs(ids) do check(name..' resolves',id>0,id) end
        log('START burnout_input '..tostring(REPENTOGON.Version));Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1
        if age==100 then
            local p=setup();p.Velocity=Vector(7,3);inputs[ButtonAction.ACTION_SHOOTRIGHT]=1
        elseif age==102 then
            local p=Isaac.GetPlayer(0);local _,t=state();origin=p.Position
            check('held active enters stationary blue',t.mode=='blue' and p.Velocity:Length()<.001)
        elseif age==105 then Isaac.GetPlayer(0).Velocity=Vector(8,0)
        elseif age==130 then
            check('blue stops drift and inertia',(Isaac.GetPlayer(0).Position-origin):Length()<.01)
            check('blue held fire emits no tears',fired==0,fired)
        elseif age==140 then Isaac.GetPlayer(0):AddCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE)
        elseif age==145 then
            local w=Isaac.GetPlayer(0):GetWeapon(1)
            check('native brimstone equipped',w and w:GetWeaponType()==WeaponType.WEAPON_BRIMSTONE)
            if w then w:SetCharge(include('drive_glove_weapon').Full(w)) end
        elseif age==170 then
            check('blue blocks a fully charged native weapon',fired==0,fired)
            check('blue still immobile',(Isaac.GetPlayer(0).Position-origin):Length()<.01)
        elseif age==180 then inputs[ButtonAction.ACTION_SHOOTRIGHT]=0;inputs[ButtonAction.ACTION_RIGHT]=1
        elseif age==181 then
            local _,t=state();check('single direction immediately enters startup',t.mode=='startup' and t.moveFrames==0,t.mode)
            check('single rush sound',counts[ids['Rush Start']]==1)
        elseif age==186 then
            local _,t=state();check('five frame stop then movement',t.mode=='rush' and t.moveFrames>0,t.mode)
        elseif age==190 then inputs[ButtonAction.ACTION_RIGHT]=0;inputs[ButtonAction.ACTION_LEFT]=1
        elseif age==191 then
            local _,t=state();check('reverse still brakes',t.mode=='idle',t.mode)
            check('blue and unrequested charged shot remain silent',fired==0,fired)
        elseif age==220 then
            setup();inputs[ButtonAction.ACTION_LEFT]=1;inputs[ButtonAction.ACTION_UP]=1
        elseif age==221 then
            local _,t=state();check('already held diagonal starts rush',t.mode=='startup' and math.abs(t.heading+135)<.001,t.heading)
            check('held direction second rush once',counts[ids['Rush Start']]==2)
        elseif age==250 then
            check('held direction cannot repeatedly rush',counts[ids['Rush Start']]==2)
        elseif age==260 then setup()
        elseif age==262 then
            local s,t=state();mod.DriveGlove.Core.Parry(s,t,Game():GetFrameCount())
        elseif age==264 then check('perfect refill is not burnout recovery',counts[ids['Burnout Exit']]==0)
        elseif age==280 then local s=state();s.gauge=.01
        elseif age==282 then
            local s,t=state();check('hold drain enters burnout',s.burnout and t.mode=='recovery' and not t.reward)
            check('burnout entry once',counts[ids['Burnout Enter']]==1)
            check('burnout native voice playing',sfx:IsPlaying(ids['Burnout Enter']))
        elseif age==328 then inputs[ButtonAction.ACTION_ITEM]=0
        elseif age==330 then inputs[ButtonAction.ACTION_ITEM]=1
        elseif age==332 then check('burnout retry adds no entry sound',counts[ids['Burnout Enter']]==1)
        elseif age==891 then local s=state();check('natural recovery not prematurely complete',s.burnout,s.gauge)
        elseif age==894 then
            local s=state();check('natural recovery reaches full',not s.burnout and s.gauge==6,s.gauge)
            check('burnout recovery once',counts[ids['Burnout Exit']]==1)
            check('recovery native voice playing',sfx:IsPlaying(ids['Burnout Exit']))
            check('recovery takes 600 idle ticks',exitAt and regenAt and exitAt-regenAt==599,tostring(exitAt)..' '..tostring(regenAt))
        elseif age==960 then
            check('native blue shoot lock observed',blueWeaponLeaks==0,blueWeaponLeaks)
            check('native blue input lock observed',blueInputLeaks==0,blueInputLeaks)
            check('entry and exit never replay at full',counts[ids['Burnout Enter']]==1 and counts[ids['Burnout Exit']]==1)
            log('DONE checks='..checks..' failures='..failures)
        end
        if age>282 and age<320 then
            local s,t=state();if s.burnout and t.mode=='idle' and not regenAt then regenAt=Game():GetFrameCount() end
        end
    end)
end
