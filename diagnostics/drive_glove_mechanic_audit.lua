-- Opt-in native comparison: ordinary damage vs guard, and held-fire rush cancel.
return function(mod)
    local started,age,checks,failures=false,0,0,0
    local inputs={}
    local weaponItem,shot,firstMoves,firstAt,rushAt,activeCase
    local damageCases={
        {name='basement half',stage=1,amount=1},
        {name='basement full',stage=1,amount=2},
        {name='fraction half',stage=1,amount=.5},
        {name='fraction one and half',stage=1,amount=1.5},
        {name='fraction two and half',stage=1,amount=2.5},
        {name='womb half input',stage=7,amount=1},
        {name='womb wafer',stage=7,amount=1,wafer=true},
        {name='basement wafer full input',stage=1,amount=2,wafer=true},
        {name='raw three',stage=7,amount=3,flags=DamageFlag.DAMAGE_NO_MODIFIERS},
        {name='womb red hearts',stage=7,amount=1,flags=DamageFlag.DAMAGE_RED_HEARTS},
        {name='blind rage half',stage=1,amount=1,trinket=TrinketType.TRINKET_BLIND_RAGE},
        {name='blind rage full',stage=7,amount=1,trinket=TrinketType.TRINKET_BLIND_RAGE},
        {name='gold blind rage',stage=1,amount=1,trinket=TrinketType.TRINKET_BLIND_RAGE+32768},
        {name='blind rage two',stage=1,amount=2,trinket=TrinketType.TRINKET_BLIND_RAGE},
        {name='gold blind rage two',stage=1,amount=2,trinket=TrinketType.TRINKET_BLIND_RAGE+32768},
        {name='blind rage moms box',stage=1,amount=1,trinket=TrinketType.TRINKET_BLIND_RAGE,box=true},
        {name='gold blind rage moms box',stage=1,amount=1,trinket=TrinketType.TRINKET_BLIND_RAGE+32768,box=true},
        {name='keeper',stage=1,amount=1,player=PlayerType.PLAYER_KEEPER},
        {name='keeper wafer',stage=1,amount=2,player=PlayerType.PLAYER_KEEPER,wafer=true},
        {name='keeper raw three',stage=1,amount=3,player=PlayerType.PLAYER_KEEPER,flags=DamageFlag.DAMAGE_NO_MODIFIERS},
        {name='tainted keeper',stage=1,amount=1,player=PlayerType.PLAYER_KEEPER_B},
        {name='tainted magdalene',stage=1,amount=1,player=PlayerType.PLAYER_MAGDALENE_B},
    }
    local weapons={0,CollectibleType.COLLECTIBLE_BRIMSTONE,CollectibleType.COLLECTIBLE_MONSTROS_LUNG,
        CollectibleType.COLLECTIBLE_TECH_X,CollectibleType.COLLECTIBLE_MOMS_KNIFE,
        CollectibleType.COLLECTIBLE_CHOCOLATE_MILK,CollectibleType.COLLECTIBLE_CURSED_EYE,
        CollectibleType.COLLECTIBLE_NEPTUNUS,CollectibleType.COLLECTIBLE_SPIRIT_SWORD}
    local function log(s)Isaac.DebugString('[Drive Glove runtime] '..s)end
    local function check(name,ok,detail)
        checks=checks+1;if not ok then failures=failures+1 end
        log((ok and 'PASS ' or 'FAIL ')..name..' '..tostring(detail or ''))
    end
    local raw=Input.GetActionValue
    Input.GetActionValue=function(a,c)
        if started and c==Isaac.GetPlayer(0).ControllerIndex then return inputs[a] or 0 end
        return raw(a,c)
    end
    mod:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION,900000,function(_,_,hook,a)
        if not started then return end
        return hook==InputHook.GET_ACTION_VALUE and (inputs[a] or 0) or (inputs[a] or 0)>0
    end)
    local function health(p)return p:GetHearts()+p:GetSoulHearts() end
    local function clean(p)
        if mod.RingOfSevenCursesTestAPI then
            mod.RingOfSevenCursesTestAPI.ResetForTest();p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId)
        end
        for _,e in ipairs(Isaac.GetRoomEntities()) do
            if e.Type==EntityType.ENTITY_PICKUP or e.Type==EntityType.ENTITY_TEAR or e.Type==EntityType.ENTITY_LASER
                or e.Type==EntityType.ENTITY_KNIFE or e.Type==EntityType.ENTITY_PROJECTILE then e:Remove() end
        end
        p:ResetDamageCooldown();p:SetDamageCountdown(0);p:SetFireDamageCooldown(0)
        p.Position=Game():GetRoom():GetCenterPos()+Vector(-120,0);p.Velocity=Vector(0,0)
    end
    local function reset(p)
        local api=mod.DriveGlove
        if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
        local s,t=api.GetState(p);api.Core.End(t,'probe');s.gauge=6;s.burnout=false
        t.reward=nil;t.gift=nil;t.grantCharge=nil;t.events={};t.cacheDirty=true;t.inputHeld=false
        t.needsRelease=false;t.lastPressed=false;t.lastTick=nil;t.pressedActions={};t.action=ButtonAction.ACTION_ITEM
        return s,t
    end
    local function damageCase(c)
        local p=Isaac.GetPlayer(0);inputs={};p:ChangePlayerType(c.player or PlayerType.PLAYER_ISAAC);clean(p)
        p:RemoveCollectible(mod.DriveGlove.ItemId);p:RemoveCollectible(CollectibleType.COLLECTIBLE_WAFER)
        p:RemoveCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX)
        p:TryRemoveTrinket(TrinketType.TRINKET_BLIND_RAGE);p:TryRemoveTrinket(TrinketType.TRINKET_BLIND_RAGE+32768)
        Game():GetLevel():SetStage(c.stage,StageType.STAGETYPE_ORIGINAL)
        p:AddMaxHearts(24);p:AddHearts(24)
        if c.wafer then p:AddCollectible(CollectibleType.COLLECTIBLE_WAFER) end
        if c.box then p:AddCollectible(CollectibleType.COLLECTIBLE_MOMS_BOX,0,true,1) end
        if c.trinket then p:AddTrinket(c.trinket) end
        local e=Isaac.Spawn(EntityType.ENTITY_PROJECTILE,0,0,p.Position+Vector(-30,0),Vector(5,0),nil)
        local before=health(p);p:TakeDamage(c.amount,c.flags or 0,EntityRef(e),0)
        local native=before-health(p);local cooldown=p:GetDamageCooldown()
        p:AddHearts(24);p:ResetDamageCooldown();p:SetDamageCountdown(0);p:SetFireDamageCooldown(0)
        local s,t=reset(p);inputs={[ButtonAction.ACTION_RIGHT]=1}
        local protected=health(p);p:TakeDamage(c.amount,c.flags or 0,EntityRef(e),0)
        log('COMPARE '..c.name..' native='..native..' guard='..(6-s.gauge)..' nativeCooldown='..cooldown..' guardCooldown='..p:GetDamageCooldown())
        check(c.name..' fee matches native',math.abs((6-s.gauge)-native)<.001)
        check(c.name..' preserves life',health(p)==protected)
        check(c.name..' cooldown matches native',p:GetDamageCooldown()==cooldown)
        e:Remove();inputs={}
    end
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,function(_,_,amount,e)
        if not activeCase or not e or not e:ToPlayer() or amount<=0 then return end
        local _,t=mod.DriveGlove.GetState(e:ToPlayer())
        if not firstAt then firstAt=Game():GetFrameCount();firstMoves=t.moveFrames end
        shot=shot+amount
        log('HELD_EMIT item='..weaponItem..' moves='..t.moveFrames..' mode='..t.mode..' at='..Game():GetFrameCount())
    end)
    mod:AddCallback(ModCallbacks.MC_POST_WEAPON_FIRE,function(_,w,dir,fire,interp)
        if activeCase and weaponItem==CollectibleType.COLLECTIBLE_BRIMSTONE then
            local _,t=mod.DriveGlove.GetState(Isaac.GetPlayer(0))
            if t.mode=='rush' then log('WINDUP moves='..t.moveFrames..' charge='..w:GetCharge()..' delay='..w:GetFireDelay()..' fire='..tostring(fire)..' interp='..tostring(interp)) end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true;log('START mechanic audit');Isaac.StartNewGame(0,0,0,123456789)
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1
        if age>=100 and age<100+#damageCases*10 and (age-100)%10==0 then damageCase(damageCases[(age-100)//10+1]) end
        local base=100+#damageCases*10+20
        if age<base then return end
        local idx=(age-base)//50+1;local phase=(age-base)%50
        local p=Isaac.GetPlayer(0)
        if idx>#weapons then
            if phase==0 and idx==#weapons+1 then inputs={};activeCase=nil;log('DONE checks='..checks..' failures='..failures) end
            return
        end
        if phase==0 then
            activeCase=nil;inputs={};p:ChangePlayerType(PlayerType.PLAYER_ISAAC);clean(p)
            p:RemoveCollectible(CollectibleType.COLLECTIBLE_WAFER)
            p:TryRemoveTrinket(TrinketType.TRINKET_BLIND_RAGE);p:TryRemoveTrinket(TrinketType.TRINKET_BLIND_RAGE+32768)
            if weaponItem and weaponItem>0 then p:RemoveCollectible(weaponItem) end
            weaponItem=weapons[idx];if weaponItem>0 then p:AddCollectible(weaponItem) end
            Game():GetLevel():SetStage(1,0);reset(p);shot=0;firstAt=nil;firstMoves=nil;rushAt=nil
        elseif phase==4 then
            activeCase=idx;inputs={[ButtonAction.ACTION_ITEM]=1,[ButtonAction.ACTION_RIGHT]=1,[ButtonAction.ACTION_SHOOTRIGHT]=1}
        elseif phase==6 then
            local _,t=mod.DriveGlove.GetState(p);rushAt=t.rushAt
            check('weapon '..weaponItem..' rush starts',t.mode=='startup')
        elseif phase==32 then
            local _,t=mod.DriveGlove.GetState(p)
            log('HELD_RESULT item='..weaponItem..' shots='..shot..' firstMoves='..tostring(firstMoves)..' delay='..tostring(firstAt and firstAt-rushAt)..' reason='..tostring(t.reason))
            check('weapon '..weaponItem..' held fire cancels rush',shot>0 and t.reason=='shot')
            -- controls-01 measured the same 4f Brimstone windup without the glove.
            local expected=weaponItem==CollectibleType.COLLECTIBLE_BRIMSTONE and 9 or 5
            check('weapon '..weaponItem..' earliest native emission',firstMoves==expected,firstMoves)
            check('weapon '..weaponItem..' reward begins at emission',firstAt~=nil and t.reward and t.reward.started==firstAt)
            if weaponItem==CollectibleType.COLLECTIBLE_CURSED_EYE then check('full cursed eye burst completes while held',shot==5,shot) end
            inputs={}
        end
    end)
end
