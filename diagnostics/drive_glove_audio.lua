-- Opt-in probe: actual native damage -> settled events -> SFX engine.
-- Included only by the backup/restore runner, never by the normal loader.
return function(mod)
    local started,age,checks,failures=false,0,0,0
    local inputs,counts,ids={},{},{}
    local sfx=SFXManager()
    local function log(s) Isaac.DebugString('[Drive Glove runtime] '..s) end
    local function check(label,value,detail)
        checks=checks+1;if not value then failures=failures+1 end
        log((value and 'PASS ' or 'FAIL ')..label..' '..tostring(detail or ''))
    end
    for _,name in ipairs({'Guard','Parry','Perfect Parry'}) do
        local id=Isaac.GetSoundIdByName('Drive Glove '..name)
        ids[name]=id;counts[id]=0
    end
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_SFX_PLAY,-900000,function(_,id)
        if not counts[id] then return false end -- Keep the diagnostic recording clean.
    end)
    mod:AddCallback(ModCallbacks.MC_POST_SFX_PLAY,function(_,id,volume,delay,loop,pitch)
        if counts[id] then
            counts[id]=counts[id]+1
            log('AUDIO id='..id..' count='..counts[id]..' frame='..Game():GetFrameCount())
            check('native original pitch and one shot',volume==1 and delay==0 and not loop and pitch==1)
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
    local firstReward,lastId
    local function setup()
        local p=Isaac.GetPlayer(0);local api=mod.DriveGlove
        for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do e:Remove() end
        if mod.RingOfSevenCursesTestAPI then
            mod.RingOfSevenCursesTestAPI.ResetForTest()
            p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
        end
        if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
        p:ResetDamageCooldown();p:SetDamageCountdown(0);p:SetFireDamageCooldown(0)
        p:AddHearts(12);p.Position=Game():GetRoom():GetCenterPos();p.Velocity=Vector(0,0)
        local s,t=api.GetState(p)
        api.Core.SetGauge(s,t,6);api.Core.End(t,'probe');t.needsRelease=false;t.lastPressed=false
        t.reward=nil;t.gift=nil;t.action=ButtonAction.ACTION_ITEM;t.slot=0;t.events={}
        inputs={}
        return p,s,t,api.Core
    end
    local function trigger(kind,repeatReward)
        local p,s,t,C=setup()
        if kind=='Guard' then inputs[ButtonAction.ACTION_RIGHT]=1
        else
            inputs[ButtonAction.ACTION_ITEM]=1
            if repeatReward then t.reward=firstReward end
            C.StartBlue(s,t,Game():GetFrameCount()-(kind=='Parry' and 4 or 0))
        end
        local e=Isaac.Spawn(EntityType.ENTITY_PROJECTILE,0,0,p.Position-Vector(50,0),Vector(5,0),nil)
        e.EntityCollisionClass=EntityCollisionClass.ENTCOLL_NONE
        local before=p:GetHearts();local id=ids[kind];local n=counts[id]
        p:TakeDamage(1,DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(e),0)
        check(kind..' native defense',p:GetHearts()==before)
        check(kind..' one native SFX event',counts[id]==n+1,counts[id])
        p:TakeDamage(1,DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(e),0)
        check(kind..' repeated hit is silent',counts[id]==n+1,counts[id])
        if kind=='Perfect Parry' then
            if repeatReward then check('reward dedup does not dedup SFX',t.reward==firstReward)
            else firstReward=t.reward end
        end
        lastId=id;e:Remove()
    end
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true
        for name,id in pairs(ids) do check(name..' resolves custom ID',id>0,id) end
        log('START audio '..tostring(REPENTOGON.Version))
        Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1
        if age==100 then trigger('Guard')
        elseif age==220 then trigger('Parry')
        elseif age==340 then trigger('Perfect Parry')
        elseif age==460 then trigger('Perfect Parry',true)
        elseif age==101 or age==221 or age==341 or age==461 then
            check('native SFX voice playing',sfx:IsPlaying(lastId),lastId)
        elseif age==560 then
            inputs={}
            check('total guard events',counts[ids.Guard]==1)
            check('total parry events',counts[ids.Parry]==1)
            check('total perfect events',counts[ids['Perfect Parry']]==2)
            log('DONE checks='..checks..' failures='..failures)
        end
    end)
end
