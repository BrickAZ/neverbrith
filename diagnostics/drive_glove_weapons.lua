-- Opt-in native weapon probe. Synthetic controls, native weapon updates/emission.
return function(mod)
    local started,age,index=false,0,0
    local inputs,heldItem={},nil
    local cases={CollectibleType.COLLECTIBLE_BRIMSTONE,CollectibleType.COLLECTIBLE_MONSTROS_LUNG,
        CollectibleType.COLLECTIBLE_TECH_X,CollectibleType.COLLECTIBLE_MOMS_KNIFE,
        CollectibleType.COLLECTIBLE_CHOCOLATE_MILK,CollectibleType.COLLECTIBLE_CURSED_EYE,
        CollectibleType.COLLECTIBLE_NEPTUNUS,CollectibleType.COLLECTIBLE_SPIRIT_SWORD}
    local peak,maxDelay,startShot=0,0,0
    local checks,failures,shotCount=0,0,0
    local function log(s) Isaac.DebugString('[Drive Glove runtime] '..s) end
    local function check(label,value,detail)
        checks=checks+1; if not value then failures=failures+1 end
        log((value and 'PASS ' or 'FAIL ')..label..' '..tostring(detail or ''))
    end
    local native=Input.GetActionValue
    Input.GetActionValue=function(a,c)
        if started and c==Isaac.GetPlayer(0).ControllerIndex then return inputs[a] or 0 end
        return native(a,c)
    end
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,900000,function(_,_,hook,a)
        if not started then return end
        return hook==InputHook.GET_ACTION_VALUE and (inputs[a] or 0) or (inputs[a] or 0)>0
    end)
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,function(_,_,amount,owner,w)
        if owner:ToPlayer() and amount>0 then
            shotCount=shotCount+1
            log('EMISSION item='..tostring(heldItem)..' age='..age..' type='..w:GetWeaponType()..' charge='..w:GetCharge())
        end
    end)
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end; started=true
        log('START weapon measurement'); Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1
        if age<100 then return end
        local phase=(age-100)%150
        local p=Isaac.GetPlayer(0); local api=mod.DriveGlove
        if phase==0 then
            index=index+1
            if index>#cases then
                inputs={}; if index==#cases+1 then log('DONE checks='..checks..' failures='..failures) end
                return
            end
            for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do e:Remove() end
            if mod.RingOfSevenCursesTestAPI then
                mod.RingOfSevenCursesTestAPI.ResetForTest(); p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
            end
            if heldItem then p:RemoveCollectible(heldItem) end
            if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
            heldItem=cases[index]; p:AddCollectible(heldItem)
            local s,t=api.GetState(p); api.Core.SetGauge(s,t,6); api.Core.End(t,'probe'); t.reward=nil; t.gift=nil
            peak,maxDelay=0,0
            inputs=heldItem==CollectibleType.COLLECTIBLE_NEPTUNUS and {} or {[ButtonAction.ACTION_SHOOTRIGHT]=1}
        end
        if index>#cases then return end
        local w=p:GetWeapon(1); if not w then return end
        if phase<=110 then peak=math.max(peak,w:GetCharge()); maxDelay=w:GetMaxFireDelay() end
        if phase==110 then
            log('CHARGE item='..heldItem..' type='..w:GetWeaponType()..' mods='..w:GetModifiers()..' peak='..peak..' maxdelay='..maxDelay)
            inputs={}
        elseif phase==112 then
            p:RemoveCollectible(heldItem)
            for _,e in ipairs(Isaac.GetRoomEntities()) do
                if e.Type==EntityType.ENTITY_TEAR or e.Type==EntityType.ENTITY_LASER or e.Type==EntityType.ENTITY_KNIFE then e:Remove() end
            end
        elseif phase==114 then p:AddCollectible(heldItem)
        elseif phase==116 then
            local s,t=api.GetState(p); t.reward=nil; t.gift=nil; api.Core.GrantReward(s,t,Game():GetFrameCount()); w:SetCharge(0)
        elseif phase==118 then
            log('GIFT item='..heldItem..' charge='..w:GetCharge()..' nativePeak='..peak)
            check('gift full charge '..heldItem,math.abs(w:GetCharge()-peak)<1,w:GetCharge())
            startShot=shotCount; inputs={[ButtonAction.ACTION_SHOOTRIGHT]=1}
        elseif phase==121 then inputs={}
        elseif phase==145 then
            local _,t=api.GetState(p)
            check('gift native emission '..heldItem,shotCount>startShot,shotCount-startShot)
            check('reward after emission '..heldItem,t.reward and t.reward.started~=nil)
        end
    end)
end
