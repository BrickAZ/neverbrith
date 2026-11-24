-- Opt-in native input -> accepted action -> SFX probe. Never in the normal loader.
return function(mod)
    local started,age,checks,failures=false,0,0,0
    local inputs,counts,ids={},{},{}
    local sfx=SFXManager()
    local function log(s) Isaac.DebugString('[Drive Glove runtime] '..s) end
    local function check(label,value,detail)
        checks=checks+1;if not value then failures=failures+1 end
        log((value and 'PASS ' or 'FAIL ')..label..' '..tostring(detail or ''))
    end
    for _,name in ipairs({'Blue Start','Rush Start'}) do
        local id=Isaac.GetSoundIdByName('Drive Glove '..name)
        ids[name]=id;counts[id]=0
    end
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_SFX_PLAY,-900000,function(_,id)
        if not counts[id] then return false end
    end)
    mod:AddCallback(ModCallbacks.MC_POST_SFX_PLAY,function(_,id,volume,delay,loop,pitch)
        if counts[id] then
            counts[id]=counts[id]+1
            log('AUDIO id='..id..' count='..counts[id]..' frame='..Game():GetFrameCount())
            check('native pitch and one shot',volume==1 and delay==0 and not loop and pitch==1)
        end
    end)
    local nativeActionValue=Input.GetActionValue
    Input.GetActionValue=function(action,controller)
        if started and controller==Isaac.GetPlayer(0).ControllerIndex then return inputs[action] or 0 end
        return nativeActionValue(action,controller)
    end
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,900000,function(_,_,hook,action)
        if not started then return end
        local value=inputs[action] or 0
        return hook==InputHook.GET_ACTION_VALUE and value or value>0
    end)
    local function state()return mod.DriveGlove.GetState(Isaac.GetPlayer(0))end
    local function setup()
        local p=Isaac.GetPlayer(0);local api=mod.DriveGlove
        for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do e:Remove() end
        if mod.RingOfSevenCursesTestAPI then
            mod.RingOfSevenCursesTestAPI.ResetForTest()
            p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
        end
        if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
        p:ResetDamageCooldown();p:SetDamageCountdown(0);p:SetFireDamageCooldown(0)
        p.Position=Game():GetRoom():GetCenterPos();p.Velocity=Vector(0,0)
        local s,t=state()
        api.Core.SetGauge(s,t,6);api.Core.End(t,'probe')
        t.needsRelease=false;t.lastPressed=false;t.lastMoveDir=nil;t.lastTick=nil;t.pressedActions={}
        t.reward=nil;t.gift=nil;t.action=ButtonAction.ACTION_ITEM;t.slot=0;t.events={}
        inputs={[ButtonAction.ACTION_ITEM]=1}
        return s,t
    end
    local function blueCount(n)check('blue entry count',counts[ids['Blue Start']]==n,counts[ids['Blue Start']])end
    local function rushCount(n)check('rush entry count',counts[ids['Rush Start']]==n,counts[ids['Rush Start']])end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true
        for name,id in pairs(ids) do check(name..' resolves custom ID',id>0,id) end
        log('START audio_start_rush '..tostring(REPENTOGON.Version))
        Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1
        if age==100 or age==220 or age==340 or age==460 then setup()
        elseif age==102 or age==222 or age==342 or age==462 then
            local _,t=state();check('input enters blue',t.mode=='blue');blueCount(math.floor((age-102)/120)+1)
            check('blue native voice playing',sfx:IsPlaying(ids['Blue Start']))
        elseif age==170 then
            local _,t=state();check('long hold stays blue without replay',t.mode=='blue');blueCount(1);inputs={}
        elseif age==277 or age==397 or age==517 then
            local s=state()
            if age==397 then s.gauge=.5 elseif age==517 then s.gauge=.49 end
            inputs[ButtonAction.ACTION_RIGHT]=1
        elseif age==278 or age==398 then
            local s,t=state();check('single direction enters startup freeze',t.mode=='startup',t.mode)
            rushCount(age==278 and 1 or 2)
            check('rush native voice playing',sfx:IsPlaying(ids['Rush Start']))
            if age==398 then check('paid final rush enters burnout and clears reward',s.burnout and not t.reward) end
        elseif age==284 or age==404 then
            local _,t=state();check('startup becomes movement',t.mode=='rush',t.mode)
            rushCount(age==284 and 1 or 2)
            if age==284 then inputs[ButtonAction.ACTION_DOWN]=1 end
        elseif age==288 or age==408 then
            inputs[ButtonAction.ACTION_DOWN]=0;inputs[ButtonAction.ACTION_RIGHT]=0;inputs[ButtonAction.ACTION_LEFT]=1
        elseif age==289 or age==409 then
            local _,t=state();check('reverse brake exits with no extra audio',t.mode=='idle',t.mode)
            rushCount(age==289 and 1 or 2)
        elseif age==518 then
            local s,t=state();check('unaffordable rush denied',s.burnout and t.mode=='recovery',t.mode);rushCount(2)
        elseif age==550 then
            local s=setup();s.gauge=.49
        elseif age==552 then
            local s,t=state();check('unaffordable blue denied',s.burnout and t.mode~='blue');blueCount(4)
        elseif age==600 then
            inputs={};blueCount(4);rushCount(2)
            log('DONE checks='..checks..' failures='..failures)
        end
    end)
end
