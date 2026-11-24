-- Opt-in regression probe. Actual native rendering, weapon and collision paths.
return function(mod)
    local started,age=false,0
    local inputs={}
    local checks,failures,shots,npcHits=0,0,0,0
    local target,phase,caseAt,baseShots,baseHits
    local minScale,maxScale,renders=math.huge,0,0
    local function log(s) Isaac.DebugString('[Drive Glove runtime] '..s) end
    local function check(label,value,detail)
        checks=checks+1;if not value then failures=failures+1 end
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
    mod:AddCallback(ModCallbacks.MC_POST_TRIGGER_WEAPON_FIRED,function(_,_,n,p)
        if phase and p:ToPlayer() and n>0 then shots=shots+1 end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG,900000,function(_,e,n,flags,src)
        if target and GetPtrHash(e)==GetPtrHash(target) then
            npcHits=npcHits+1
            log('CONTACT phase='..tostring(phase)..' amount='..n..' flags='..flags..' source='..tostring(src.Type))
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_RENDER,900000,function(_,p)
        if phase=='blue' then
            minScale=math.min(minScale,p.SpriteScale.Y);maxScale=math.max(maxScale,p.SpriteScale.Y);renders=renders+1
        elseif phase=='burnout' then
            local c=p.Color:GetColorize()
            if renders==0 then check('burnout gray native color',c.A==1 and c.R==c.G and c.G==c.B) end
            renders=renders+1
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,-900000,function(_,p)
        if target and target:Exists() then
            -- Keep actual overlapping native bodies, without injecting damage.
            target.Position=Game():GetRoom():GetCenterPos();target.Velocity=Vector.Zero
            p.Position=target.Position;p.Velocity=Vector.Zero
            if phase=='blueFan' then
                for _,f in ipairs(Isaac.FindByType(EntityType.ENTITY_FAMILIAR)) do f.Position=p.Position;f.Velocity=Vector.Zero end
            end
        end
    end)
    mod:AddCallback(ModCallbacks.MC_MAIN_MENU_RENDER,function()
        if started then return end;started=true
        log('START visual/contact regression');Isaac.StartNewGame(0,0,0,123456789)
    end)
    local phases={'idle','blue','cooldown','noshoot','both','blueFan','burnout','refilled'}
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,900000,function()
        age=age+1;if age<80 then return end
        local p=Isaac.GetPlayer(0);local api=mod.DriveGlove
        local step=(age-80)%90
        if step==0 then
            if target then target:Remove();target=nil end
            if phase then
                log('RESULT '..phase..' shots='..(shots-baseShots)..' npcHits='..(npcHits-baseHits)..' scale='..p.SpriteScale.Y)
                if phase=='blue' then
                    check('blue no contact damage',npcHits==baseHits,npcHits-baseHits)
                    check('blue no shots',shots==baseShots,shots-baseShots)
                    check('blue scale stable',renders>60 and math.abs(minScale-.96)<.001 and math.abs(maxScale-.96)<.001,minScale..'..'..maxScale)
                    check('blue render restored scale',math.abs(p.SpriteScale.Y-1)<.001,p.SpriteScale.Y)
                elseif phase=='blueFan' then check('Obsessed Fan can damage during blue',npcHits>baseHits,npcHits-baseHits)
                elseif phase=='burnout' then check('burnout rendered',renders>60,renders)
                elseif phase=='refilled' then
                    check('refill restores scale/color',math.abs(p.SpriteScale.Y-1)<.001 and p.Color:GetColorize().A==0)
                end
            end
            local index=math.floor((age-80)/90)+1
            phase=phases[index]
            if not phase then
                inputs={};p:SetCanShoot(true)
                log('DONE checks='..checks..' failures='..failures);return
            end
            for _,e in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do e:Remove() end
            if mod.RingOfSevenCursesTestAPI then mod.RingOfSevenCursesTestAPI.ResetForTest();p:RemoveCollectible(mod.RingOfSevenCursesTestAPI.ItemId) end
            if not p:HasCollectible(api.ItemId) then p:AddCollectible(api.ItemId,0,true,0) end
            p:RemoveCollectible(CollectibleType.COLLECTIBLE_OBSESSED_FAN)
            local s,t=api.GetState(p);api.Core.End(t,'probe');api.Core.SetGauge(s,t,6)
            t.needsRelease=false;t.lastPressed=false;t.pressedActions={};t.action=ButtonAction.ACTION_ITEM;t.slot=0;t.reward=nil;t.gift=nil
            p:SetCanShoot(true);p:ResetDamageCooldown();p:AddHearts(12)
            inputs={};baseShots=shots;baseHits=npcHits;renders=0
            if phase=='idle' then
                local scale=p.SpriteScale;local x,y=scale.X,scale.Y
                p.SpriteScale=Vector(x,y*.9)
                log('NATIVE SpriteScale reference aliases setter='..tostring(math.abs(scale.Y-y*.9)<.001))
                p.SpriteScale=Vector(x,y)
            end
            if phase=='blue' or phase=='blueFan' then
                inputs={[ButtonAction.ACTION_ITEM]=1,[ButtonAction.ACTION_SHOOTRIGHT]=1};api.Core.StartBlue(s,t,Game():GetFrameCount())
            end
            if phase=='blueFan' then p:AddCollectible(CollectibleType.COLLECTIBLE_OBSESSED_FAN) end
            if phase=='burnout' then api.Core.SetGauge(s,t,0) end
            if phase~='burnout' and phase~='refilled' then
                target=Isaac.Spawn(EntityType.ENTITY_GAPER,0,0,Game():GetRoom():GetCenterPos(),Vector.Zero,nil):ToNPC()
                target.MaxHitPoints=10000;target.HitPoints=10000;target:AddEntityFlags(EntityFlag.FLAG_NO_KNOCKBACK|EntityFlag.FLAG_NO_PHYSICS_KNOCKBACK)
            end
        end
        if phase=='cooldown' or phase=='both' then p:SetMinDamageCooldown(60) end
        if phase=='noshoot' or phase=='both' then p:SetCanShoot(false) end
    end)
end
