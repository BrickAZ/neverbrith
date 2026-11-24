-- All times here are 30 Hz logic ticks. Native damage cooldowns have their own unit.
local C = {MAX=6, SPEED=260/18, TURN=15}
local EPS=1e-8
local function event(t,kind,from,to) t.events[#t.events+1]={kind=kind,from=from,to=to} end
function C.Runtime()
    return {mode='idle',moveFrames=0,events={},needsRelease=false}
end
function C.Record(root,seed,key,held)
    if not root.driveGlove or root.driveGlove.seed~=seed then root.driveGlove={seed=seed,players={}} end
    local players=root.driveGlove.players
    if not players[key] and held then players[key]={gauge=6,burnout=false} end
    return players[key]
end
function C.SetGauge(s,t,value,kind)
    local old,was=s.gauge,s.burnout
    s.gauge=math.max(0,math.min(6,value))
    if s.gauge<EPS then s.gauge=0; s.burnout=true end
    if s.gauge>=6-EPS then s.gauge=6; s.burnout=false end
    if s.burnout then t.reward=nil end
    if kind and math.abs(old-s.gauge)>EPS then event(t,kind,old,s.gauge) end
    if was~=s.burnout then
        t.cacheDirty=true
        event(t,s.burnout and 'BurnoutEnter' or 'Refill',old,s.gauge)
        -- Refill also belongs to Perfect Parry. Only this transition ends burnout.
        if not s.burnout then event(t,'BurnoutExit',old,s.gauge) end
    end
    if old~=s.gauge then t.saveDirty=true end
end
function C.GrantReward(s,t,now)
    if s.burnout or t.reward then return false end
    t.reward={granted=now}; t.grantCharge=true; return true
end
function C.Shot(s,t,now)
    if s.burnout or not t.reward or t.reward.started then return end
    t.reward.started=now; t.cacheDirty=true; t.chargeConsumed=true
end
function C.End(t,reason)
    if t.mode=='rush' or t.mode=='startup' then event(t,'RushEnd') end
    -- A release that ended blue (or was held through recovery) already rearmed
    -- the button. Do not require an extra release after returning to idle.
    t.mode='idle'; t.reason=reason; t.needsRelease=t.inputHeld~=false
end
function C.Recovery(t,now)
    t.mode='recovery'; t.recoveryAt=now; t.needsRelease=true
    event(t,'Recovery')
end
function C.StartBlue(s,t,now)
    if s.burnout or t.mode~='idle' or t.needsRelease then return false end
    C.SetGauge(s,t,s.gauge-.5,'Spend')
    t.needsRelease=true
    if s.burnout then return false end
    t.mode='blue'; t.blueAt=now; t.successAt=nil
    event(t,'Blue'); return true
end
function C.Parry(s,t,now)
    if s.burnout or t.mode~='blue' then return end
    local perfect=now-t.blueAt<3
    local kind=perfect and 'PerfectParry' or 'Parry'
    C.SetGauge(s,t,perfect and 6 or s.gauge+.5,perfect and 'Refill' or 'Gain')
    -- Refill also flashes when already full; it is not reward deduplication.
    if perfect then event(t,'Refill',s.gauge,s.gauge); C.GrantReward(s,t,now) end
    t.successAt=now; event(t,kind); return kind
end
function C.Guard(s,t,amount)
    if s.burnout then return false end
    C.SetGauge(s,t,s.gauge-amount,'Spend'); event(t,'Guard'); return true
end
function C.Budget(x,y)
    local length=math.sqrt(x*x+y*y); if length<EPS then return 0 end
    x,y=math.abs(x/length),math.abs(y/length)
    return math.min(x>EPS and 260/x or math.huge,y>EPS and 140/y or math.huge)
end
function C.StartRush(s,t,now,x,y)
    if s.burnout or t.mode~='blue' or x*x+y*y<EPS then return false end
    local enough=s.gauge>=.5-EPS
    C.SetGauge(s,t,s.gauge-.5,'Spend')
    if not enough then C.Recovery(t,now); return false end
    t.mode='startup'; t.rushAt=now; t.moveFrames=0; t.heading=math.deg(math.atan(y,x)); t.remaining=C.Budget(x,y)
    t.needsRelease=true; C.GrantReward(s,t,now); event(t,'RushStart'); return true
end
function C.GuardDirection(ix,iy,dx,dy)
    local a,b=math.sqrt(ix*ix+iy*iy),math.sqrt(dx*dx+dy*dy)
    return a>EPS and b>EPS and (ix*dx+iy*dy)/(a*b)>=math.sqrt(.5)-EPS
end
function C.Tick(s,t,now,input,heldItem)
    t.inputHeld=input.held
    if t.lastTick==now then return end
    t.lastTick=now
    if t.reward and t.reward.started and now-t.reward.started>=90 then t.reward=nil; t.cacheDirty=true end
    if not heldItem then
        if t.reward then t.reward=nil; t.cacheDirty=true end
        if t.mode~='idle' then C.End(t,'removed') end
        return
    end
    if not input.held and t.mode=='idle' then t.needsRelease=false end
    if t.mode=='recovery' then
        if now-t.recoveryAt>=12 then C.End(t,'recovered') end
        return
    end
    if t.mode=='startup' then
        if now-t.rushAt>=5 then t.mode='rush' end
        return
    end
    if t.mode~='blue' then return end
    local freeExit=t.successAt and now-t.successAt<6
    if not input.held and (freeExit or now-t.blueAt>=6) then
        if freeExit then C.End(t,'success') else C.Recovery(t,now) end
        return
    end
    -- Any effective movement input commits to rush, including an already held
    -- direction when entering blue. Keep the analog heading, with the same deadzone.
    if input.x*input.x+input.y*input.y>=.04 then
        C.StartRush(s,t,now,input.x,input.y); return
    end
    if now>t.blueAt then
        C.SetGauge(s,t,s.gauge-.01)
        if s.burnout then C.Recovery(t,now) end
    end
end
function C.RushStep(t,x,y)
    if t.mode~='rush' then return end
    if x*x+y*y>=.04 then
        local target=math.deg(math.atan(y,x))
        local difference=(target-t.heading+180)%360-180
        if math.abs(difference)>=135-EPS then
            if t.moveFrames>=4 then C.End(t,'brake'); return end
            -- Early backwards input remains available to guard but does not steer.
        else
            t.heading=t.heading+math.max(-C.TURN,math.min(C.TURN,difference))
        end
    end
    return math.min(C.SPEED,t.remaining)
end
function C.CommitMove(t,distance)
    if t.mode~='rush' then return end
    t.remaining=math.max(0,t.remaining-distance); t.moveFrames=t.moveFrames+1
    if t.remaining<EPS then C.End(t,'distance') end
end
function C.Regen(s,t,walking)
    if t.mode~='idle' then return end
    C.SetGauge(s,t,s.gauge+(s.burnout and .3 or .1)/30*(walking and 1.5 or 1))
end
function C.Tears(delay,burnout,reward)
    local tears=30/(math.max(-.99,delay)+1)
    if burnout then tears=tears*.75 elseif reward then tears=math.max(tears,4) end
    return 30/tears-1
end
return C
