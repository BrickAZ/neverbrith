-- Engine-free input state. Times are unpaused game seconds, not callback counts.
local C = {}
local EPS = 1e-9
local bits = {1,2,4,8}
local names = {[1]='left',[2]='right',[4]='up',[8]='down'}
local vectors = {left={-1,0},right={1,0},up={0,-1},down={0,1}}
local dirs = {[-1]={[-1]=7,[0]=4,[1]=1},[0]={[-1]=8,[0]=5,[1]=2},[1]={[-1]=9,[0]=6,[1]=3}}
local xy = {[1]={-1,1},[2]={0,1},[3]={1,1},[4]={-1,0},[5]={0,0},[6]={1,0},[7]={-1,-1},[8]={0,-1},[9]={1,-1}}
local windows = {reverse_qcf=.6,dp=.6,circle_360=.8,circle_720=1.5,double_wave_tap=1.2}
local patterns = {reverse_qcf={{2,1,4},{2,4},{1,4}},dp={{6,2,3},{6,2,6},{3,2,3}}}
local circle = {[6]=0,[2]=1,[4]=2,[8]=3}
local cardDirs = {[0]=6,[1]=2,[2]=4,[3]=8}
C.Profiles = {wave_tap=true,double_wave_tap=true,reverse_qcf=true,dp=true,charge_back_forward=true,circle_360=true,circle_720=true}
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function mask(n) return type(n)=='number' and math.floor(n)&15 or 0 end
local function facing(n) return vectors[n] and n or 'down' end
local function updateOrder(order, old, new, seq)
    for _,b in ipairs(bits) do if new&b~=0 and old&b==0 then order[b]=seq end end
end
local function axis(m, neg, pos, order)
    local a,b=m&neg~=0,m&pos~=0
    if a and b then
        local x,y=order[neg] or 0,order[pos] or 0
        return x==y and 0 or (x>y and -1 or 1)
    end
    return a and -1 or (b and 1 or 0)
end
local function world(m, order) return axis(m,1,2,order),axis(m,4,8,order) end
local function relative(x,y,f)
    local v=vectors[f];return dirs[x*v[1]+y*v[2]][-x*v[2]+y*v[1]]
end
local function shotDirection(m,order)
    local best,stamp,tied=nil,-1,false
    for _,b in ipairs(bits) do if m&b~=0 then
        local t=order[b] or 0
        if t>stamp then best,stamp,tied=names[b],t,false elseif t==stamp then tied=true end
    end end
    return not tied and best or nil
end
local function edgeDirection(m)
    if names[m] then return names[m] end
end
local function event(out,kind,s,reason,extra)
    local e={kind=kind,profile=s.profile,facing=s.attempt and s.attempt.facing or s.lastFacing,serial=s.serial,reason=reason}
    if extra then for k,v in pairs(extra) do e[k]=v end end
    out[#out+1]=e;return e
end
function C.Reset(s, baseline, reason)
    local serial=s.serial or 0
    local previousShot=s.lastShotFacing
    for k in pairs(s) do s[k]=nil end
    baseline=baseline or {}
    s.serial=serial;s.profile=baseline.profile;s.active=not not baseline.activeHeld
    s.odRequested=not not baseline.odRequested
    s.time=finite(baseline.time) and baseline.time or 0;s.sequence=baseline.sequence or 0
    s.moveMask=mask(baseline.moveMask);s.shootMask=mask(baseline.shootMask)
    s.moveOrder={};s.shootOrder={}
    updateOrder(s.moveOrder,0,s.moveMask,s.sequence);updateOrder(s.shootOrder,0,s.shootMask,s.sequence)
    s.lastShotFacing=shotDirection(s.shootMask,s.shootOrder)
        or (vectors[baseline.lastShotFacing] and baseline.lastShotFacing) or previousShot
    s.lastFacing=s.lastShotFacing or facing(baseline.headFacing)
    local x,y=world(s.moveMask,s.moveOrder);s.lastWorld=dirs[x][y];s.reason=reason
    -- BEGIN approved720shortcut: reset baselines never synthesize a held edge.
    s.shortcutHeld=s.active and s.profile=='circle_720'and s.moveMask&12==12 or nil
    -- END approved720shortcut
end
function C.New(baseline) local s={};C.Reset(s,baseline,'initial');return s end
local function ordinary(p) return p~='wave_tap' and p~='double_wave_tap' end
local function clearAttempt(s,reason) s.attempt=nil;s.reason=reason;s.waitChange=true end
local function complete(s,out,t,availability)
    local f=s.attempt.facing;s.serial=s.serial+1;s.attempt=nil;s.waitChange=false
    if ordinary(s.profile) then s.needsNeutral=true;s.rearmAt=nil end
    local data={facing=f,serial=s.serial,odRequested=not not s.odRequested}
    if availability=='ready' then event(out,'execute',s,nil,data)
    elseif availability=='recovery' then
        s.pending={facing=f,serial=s.serial,deadline=t+.2,profile=s.profile,odRequested=data.odRequested}
        event(out,'pending',s,'recovery',data)
    else event(out,'failure',s,availability or 'unavailable',data) end
end
local function begin(s,d,t,lockedFacing)
    local a={start=t,facing=lockedFacing or s.lastFacing,last=d,count=1}
    if patterns[s.profile] then
        a.paths={}
        for _,p in ipairs(patterns[s.profile]) do if p[1]==d then a.paths[#a.paths+1]={pattern=p,index=1} end end
        if #a.paths==0 then return end
    elseif s.profile=='circle_360' or s.profile=='circle_720' then
        a.card=circle[d];a.count=a.card~=nil and 1 or 0
    elseif s.profile=='charge_back_forward' then
        if not (d==1 or d==4 or d==7) then return end
        a.held=0;a.lastRear=true;a.chargeTime=t
    end
    s.attempt=a;s.waitChange=false;return a
end
local function bridge(last,wanted,d)
    local a,b,c=xy[last],xy[wanted],xy[d]
    return a and b and c and a[1]*a[2]==0 and b[1]*b[2]==0
        and a[1]*b[1]+a[2]*b[2]==0 and c[1]==a[1]+b[1] and c[2]==a[2]+b[2]
end
local function advance(s,a,d)
    if patterns[s.profile] then
        if d==a.last then return 'ignore' end
        local nextPaths,bridged={},false
        for _,path in ipairs(a.paths) do
            local wanted=path.pattern[path.index+1]
            if wanted==d then
                if path.index+1==#path.pattern then return 'complete' end
                nextPaths[#nextPaths+1]={pattern=path.pattern,index=path.index+1}
            elseif bridge(a.last,wanted,d) then bridged=true end
        end
        if #nextPaths>0 then a.paths=nextPaths;a.previous=a.last;a.last=d;a.count=a.count+1;return 'progress' end
        if bridged then return 'ignore' end
    else
        local c=circle[d]
        if c==nil then
            if a.card==nil then return 'ignore' end
            for _,delta in ipairs(a.spin and {a.spin} or {1,3}) do
                local nextCard=(a.card+delta)%4
                if bridge(cardDirs[a.card],cardDirs[nextCard],d) then
                    if a.bridgeNext and a.bridgeNext~=nextCard then return 'invalid' end
                    a.bridgeNext=nextCard;return 'ignore'
                end
            end
            return 'invalid'
        end
        if c==a.card then a.bridgeNext=nil;return 'ignore' end
        if a.card==nil then a.card=c;a.last=d;a.count=1;return 'progress' end
        if a.bridgeNext and c~=a.bridgeNext then return 'invalid' end
        local delta=(c-a.card)%4
        if (not a.spin and (delta==1 or delta==3)) or delta==a.spin then
            a.bridgeNext=nil;a.spin=a.spin or delta;a.card=c;a.previous=a.last;a.last=d;a.count=a.count+1
            return a.count==(s.profile=='circle_360' and 4 or 8) and 'complete' or 'progress'
        end
    end
    return 'invalid'
end
local function charge(s,a,d,t,out,availability,x,y)
    local rear=d==1 or d==4 or d==7
    local forward=d==3 or d==6 or d==9
    if a.lastRear then a.held=a.held+math.max(0,t-a.chargeTime) end
    a.chargeTime=t;a.lastRear=rear
    if a.held>=.5-EPS then
        if a.releaseAt and t-a.releaseAt>.2+EPS then
            clearAttempt(s,'charge_expired');begin(s,relative(x,y,s.lastFacing),t);return
        end
        if rear then
            a.releaseAt=nil
        else
            a.releaseAt=a.releaseAt or t
            if forward then complete(s,out,t,availability) end
        end
    elseif d==5 then
        a.neutralAt=a.neutralAt or t
        if t-a.neutralAt>.1+EPS then clearAttempt(s,'charge_gap') end
    elseif rear then
        a.neutralAt=nil
    else clearAttempt(s,'charge_incomplete') end
end
function C.Step(s,input)
    local out={};input=input or {}
    local t,seq=input.time,input.sequence
    if not finite(t) or not finite(seq) then return out end
    if t<s.time-EPS then C.Reset(s,input,'clock_reset');return out end
    if seq<=s.sequence then return out end
    local oldMove,oldShoot=s.moveMask,s.shootMask
    local move,shoot=mask(input.moveMask),mask(input.shootMask)
    updateOrder(s.moveOrder,oldMove,move,seq);updateOrder(s.shootOrder,oldShoot,shoot,seq)
    s.lastShotFacing=shotDirection(shoot,s.shootOrder) or s.lastShotFacing
    s.lastFacing=s.lastShotFacing or facing(input.headFacing)
    local click=edgeDirection(shoot&(~oldShoot))
    local x,y=world(move,s.moveOrder);local wd=dirs[x][y]
    local changed=wd~=s.lastWorld
    local activated=input.activeHeld and not s.active
    s.time=t;s.sequence=seq;s.moveMask=move;s.shootMask=shoot;s.lastWorld=wd
    s.active=not not input.activeHeld
    s.odRequested=not not input.odRequested
    -- BEGIN approved720shortcut: raw opposite arrows precede SOCD resolution.
    if not s.active or move&12~=12 then s.shortcutHeld=nil end
    -- END approved720shortcut
    if s.profile~=input.profile then C.Reset(s,input,'profile_changed');return out end
    if not s.active or not C.Profiles[s.profile] then
        s.attempt=nil;s.pending=nil;s.needsNeutral=false;s.rearmAt=nil;s.waitChange=false;return out
    end
    if s.needsNeutral then
        if wd==5 then s.rearmAt=s.rearmAt or t
            if t-s.rearmAt>=.1-EPS then s.needsNeutral=false;s.waitChange=false end
        else
            if s.rearmAt and t-s.rearmAt>=.1-EPS then s.needsNeutral=false;s.waitChange=false end
            s.rearmAt=nil
        end
    end
    local availability=input.availability or 'ready'
    if s.pending then
        local p=s.pending
        if t>p.deadline+EPS then s.pending=nil;event(out,'failure',s,'buffer_expired',p)
        elseif availability=='ready' then s.pending=nil;event(out,'execute',s,nil,p)
        elseif availability~='recovery' then s.pending=nil;event(out,'failure',s,availability,p) end
        return out
    end
    -- BEGIN approved720shortcut: share completion, resource failure and buffer.
    if s.profile=='circle_720' and move&12==12 then
        if not s.shortcutHeld and not s.needsNeutral then
            s.shortcutHeld=true;s.attempt={facing=s.lastFacing}
            complete(s,out,t,availability)
        end
        return out
    end
    -- END approved720shortcut
    if s.profile=='wave_tap' then
        if click then s.attempt={facing=click};complete(s,out,t,availability) end
        return out
    elseif s.profile=='double_wave_tap' then
        if s.attempt and t-s.attempt.start>1.2+EPS then clearAttempt(s,'timeout') end
        if click then
            if s.attempt and s.attempt.facing==click then complete(s,out,t,availability)
            else s.attempt={start=t,facing=click,count=1};event(out,'progress',s,nil,{count=1}) end
        end
        return out
    end
    if s.needsNeutral then return out end
    local a=s.attempt
    if a and windows[s.profile] and t-a.start>windows[s.profile]+EPS then clearAttempt(s,'timeout');a=nil end
    local d=relative(x,y,a and a.facing or s.lastFacing)
    if a and s.profile=='charge_back_forward' then
        if a.held<.5-EPS and a.neutralAt and t-a.neutralAt>.1+EPS then
            clearAttempt(s,'charge_gap');a=nil;d=relative(x,y,s.lastFacing)
        else charge(s,a,d,t,out,availability,x,y);return out end
    end
    if a and a.bounce and t-a.bounce.time>2/30+EPS then
        local b=a.bounce;clearAttempt(s,'reverse')
        begin(s,relative(b.x,b.y,b.facing),b.time,b.facing);a=s.attempt
        d=relative(x,y,a and a.facing or s.lastFacing)
    end
    if a and a.neutralAt and t-a.neutralAt>.2+EPS then
        clearAttempt(s,'neutral_timeout');a=nil;d=relative(x,y,s.lastFacing)
    end
    if d==5 then if a then a.neutralAt=a.neutralAt or t end;return out end
    if a then
        a.neutralAt=nil
        if a.bounce and d==a.bounce.dir then return out end
        a.bounce=nil
        local result=advance(s,a,d)
        if result=='complete' then complete(s,out,t,availability)
        elseif result=='progress' then event(out,'progress',s,nil,{count=a.count})
        elseif result=='invalid' then
            if d==a.previous then a.bounce={dir=d,time=t,x=x,y=y,facing=s.lastFacing}
            else clearAttempt(s,'wrong_direction');begin(s,relative(x,y,s.lastFacing),t) end
        end
    elseif not s.waitChange or changed or activated then
        if begin(s,d,t) then event(out,'progress',s,nil,{count=s.attempt.count}) end
    end
    return out
end
function C.View(s)
    return {profile=s.profile,facing=s.attempt and s.attempt.facing or s.lastFacing,
        count=s.attempt and s.attempt.count or 0,pending=s.pending~=nil,serial=s.serial,reason=s.reason,
        charge=s.attempt and s.attempt.held or nil,needsNeutral=not not s.needsNeutral}
end
return C
