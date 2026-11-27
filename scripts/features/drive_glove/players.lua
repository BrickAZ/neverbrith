-- Private Drive Glove players; instantiated once by init.lua.
return function(mod, deps)
    local callbackInstallers = {}
    local C,records,now=deps.Core,deps.State,deps.Now
    local data,state,key,held=records.Data,records.Get,records.Key,records.IsHeld
    local freeze,flush,W=deps.Freeze,deps.Flush,deps.WeaponRules
    local controls,weapon=deps.Input,deps.Weapons
    local movement,shooting,raw,selected=controls.Movement,controls.Shooting,controls.Raw,controls.Selected
    local start,canControl,busy,rushing=controls.Start,controls.CanControl,controls.Busy,controls.Rushing
    local restoreShoot,currentWeapon,weaponIdentity=weapon.RestoreShoot,weapon.Current,weapon.Identity
    local game=deps.Game
    local function prePlayer(_,p)
        if not records.IsReady() then return end
        freeze.ThawExpired()
        local s=data(p)
        if not s then return freeze.Entity(p) end
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
        if before~='startup' and t.mode=='startup' then freeze.Begin() end
        if p:IsDead() or not held(p) then
            if busy(t) then C.End(t,'unavailable') end
            if t.reward then t.reward=nil; t.cacheDirty=true end
        end
        flush(p,s,t)
        if freeze.Entity(p) then return true end
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
        if blockFire then
            if deps.Shooting then deps.Shooting.Block(t,'shootScope',p)
            else t.shootScope=p:CanShoot(); p:SetCanShoot(false) end
        end
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
    function callbackInstallers.prePlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE,-30000,prePlayer)
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
        if not records.IsReady() then return end
        local t=records.Peek(p); if not t then return end
        restoreShoot(p,t)
        local s=data(p); if not s then return end
        if freeze.IsActive() then flush(p,s,t); return end
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
    function callbackInstallers.postPlayer()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,30000,postPlayer)
    end

    return {
        Install = callbackInstallers,

    }
end
