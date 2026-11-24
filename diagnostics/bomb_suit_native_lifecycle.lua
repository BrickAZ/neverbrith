-- Temporary native lifecycle checks; only the backed-up launcher includes this.
return function(mod)
    local id=Isaac.GetItemIdByName('Bomb Suit')
    if id<0 then id=Isaac.GetItemIdByName('炸弹套装')end
    local phase,ticks,passed,total='menu',0,0,0
    local p,baseSpeed,oldRoom,targetRoom,beforeBombs,ageBefore
    local bombs,loads=0,0
    local function log(s)Isaac.DebugString('[Bomb Suit native] '..s)end
    local function check(name,ok,detail)
        total=total+1;if ok then passed=passed+1 end
        log((ok and 'PASS 'or'FAIL ')..name..' '..tostring(detail or ''))
    end
    local function nextPhase(name)phase=name;ticks=0 end
    local function arm()
        p:AddHearts(24);p:ResetDamageCooldown();p:EvaluateItems();baseSpeed=p.MoveSpeed
        beforeBombs=bombs
        p:TakeDamage(1,DamageFlag.DAMAGE_INVINCIBLE|DamageFlag.DAMAGE_NO_MODIFIERS,EntityRef(nil),0)
        check(phase..': armed',mod.BombSuit.IsActive(p))
    end
    mod:AddCallback(ModCallbacks.MC_PRE_RENDER,function()
        if phase~='menu'then return end;ticks=ticks+1
        if ticks==15 then nextPhase('starting');Isaac.StartNewGame(0,0,0,31415926)end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED,999999,function()
        p=Isaac.GetPlayer(0);p.ControlsEnabled=false
        log('START lifecycle version='..REPENTOGON.Version..' runtime-id='..id)
        nextPhase('copies')
    end)
    mod:AddCallback(ModCallbacks.MC_POST_BOMB_INIT,function(_,b)
        -- The marker is assigned after INIT, so count once at first POST update.
        b:GetData().bombSuitLifecycleCounted=false
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_BOMB_UPDATE,999999,function(_,b)
        local data=b:GetData()
        if data.NeverbirthBombSuitOwner and not data.bombSuitLifecycleCounted then
            data.bombSuitLifecycleCounted=true;bombs=bombs+1
        end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD,999999,function()loads=loads+1 end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG,-30000,function(_,who,amount,flags)
        if (flags&DamageFlag.DAMAGE_NO_MODIFIERS)==0 and not mod.BombSuit.IsActive(who)then return false end
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,999999,function(_,who)
        who.ControlsEnabled=false;who.Position=Game():GetRoom():GetCenterPos();who.Velocity=Vector.Zero
    end)
    mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE,999999,function()
        if phase=='menu'or phase=='starting'or phase=='done'then return end
        ticks=ticks+1
        if phase=='copies'then
            if ticks==35 then p:AddCollectible(id,0,true);p:AddCollectible(id,0,true);arm()
            elseif ticks==55 then
                ageBefore=mod.BombSuit.GetAge(p);p:RemoveCollectible(id)
                check('one-copy-removed: remains-active',mod.BombSuit.IsActive(p))
                check('one-copy-removed: no-countdown-refresh',mod.BombSuit.GetAge(p)==ageBefore)
                p:RemoveCollectible(id)
                check('last-copy-removed: cancelled',not mod.BombSuit.IsActive(p))
                check('last-copy-removed: speed-restored',math.abs(p.MoveSpeed-baseSpeed)<0.001)
                nextPhase('copies-wait')
            end
        elseif phase=='copies-wait'and ticks==100 then
            check('last-copy-removed: no-delayed-bomb',bombs==beforeBombs)
            p:AddCollectible(id,0,true)
            oldRoom=Game():GetLevel():GetCurrentRoomIndex()
            for slot=0,7 do local door=Game():GetRoom():GetDoor(slot)
                if door and door.TargetRoomIndex>=0 then targetRoom=door.TargetRoomIndex;break end
            end
            check('native-room-target-available',targetRoom~=nil)
            if not targetRoom then nextPhase('done');log('DONE passed='..passed..' total='..total);return end
            nextPhase('room-fuse');arm()
        elseif phase=='room-fuse'and ticks==20 then
            ageBefore=mod.BombSuit.GetAge(p);Game():ChangeRoom(targetRoom)
            check('ordinary-room-change: remains-active',mod.BombSuit.IsActive(p))
            check('ordinary-room-change: no-countdown-refresh',mod.BombSuit.GetAge(p)==ageBefore)
            nextPhase('room-wait')
        elseif phase=='room-wait'and ticks==100 then
            check('ordinary-room-change: current-room',Game():GetLevel():GetCurrentRoomIndex()==targetRoom)
            check('ordinary-room-change: one-bomb',bombs==beforeBombs+1)
            check('ordinary-room-change: fuse-ended',not mod.BombSuit.IsActive(p))
            nextPhase('hourglass-fuse');arm()
        elseif phase=='hourglass-fuse'and ticks==20 then
            check('hourglass: active-before-rewind',mod.BombSuit.IsActive(p))
            p:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS,UseFlag.USE_NOANIM|UseFlag.USE_NOANNOUNCER)
            nextPhase('hourglass-wait')
        elseif phase=='hourglass-wait'and ticks==100 then
            check('hourglass: native-load-observed',loads>0,loads)
            check('hourglass: returned-to-original-room',Game():GetLevel():GetCurrentRoomIndex()==oldRoom)
            check('hourglass: cancelled',not mod.BombSuit.IsActive(p))
            check('hourglass: speed-restored',math.abs(p.MoveSpeed-baseSpeed)<0.001,p.MoveSpeed)
            check('hourglass: no-delayed-bomb',bombs==beforeBombs)
            if not p:HasCollectible(id)then p:AddCollectible(id,0,true)end
            nextPhase('death-fuse');arm()
        elseif phase=='death-fuse'and ticks==20 then
            p:Kill()
            check('death: native-death',p:IsDead())
            check('death: fuse-cancelled',not mod.BombSuit.IsActive(p))
            check('death: no-bomb-at-cancellation',bombs==beforeBombs)
            nextPhase('done');log('DONE passed='..passed..' total='..total)
        end
    end)
end
