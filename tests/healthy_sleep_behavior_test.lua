-- Engine boundary doubles: these tests do not prove native bed/co-op behavior.
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 0.000001),tostring(a)..' ~= '..tostring(b)) end
local names={'MC_POST_GAME_STARTED','MC_POST_NEW_ROOM','MC_POST_NEW_LEVEL','MC_POST_UPDATE','MC_PRE_GAME_EXIT','MC_POST_GAME_END','MC_PRE_MOD_UNLOAD','MC_PRE_PICKUP_COLLISION','MC_POST_PICKUP_COLLISION','MC_PRE_PLAYER_ADD_HEARTS','MC_PRE_PLAYER_UPDATE','MC_INPUT_ACTION','MC_POST_RENDER','MC_PRE_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_SHOW','MC_POST_ITEM_OVERLAY_UPDATE'}
ModCallbacks={}; for i,n in ipairs(names) do ModCallbacks[n]=i end
PickupVariant={PICKUP_BED=380}; EntityType={ENTITY_PICKUP=5}; Giantbook={SLEEP=33}
AddHealthType={RED=1,SOUL=4}; InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
ButtonAction={ACTION_LEFT=0,ACTION_RIGHT=1,ACTION_UP=2,ACTION_DOWN=3,ACTION_SHOOTLEFT=4,ACTION_SHOOTRIGHT=5,ACTION_SHOOTUP=6,ACTION_SHOOTDOWN=7,ACTION_BOMB=8,ACTION_ITEM=9,ACTION_PILLCARD=10,ACTION_DROP=11,ACTION_PAUSE=12}
Vector=setmetatable({Zero={X=0,Y=0}}, {__call=function(_,x,y) return {X=x,Y=y} end})
Color=function(r,g,b,a,ro,go,bo) return {R=r,G=g,B=b,A=a,RO=ro or 0,GO=go or 0,BO=bo or 0} end
local function copy(t) if type(t)~='table' then return t end local o={} for k,v in pairs(t) do o[k]=copy(v) end return o end
local function fixture(saved)
    local f={root=saved or {},now=0,frame=0,floor=1,roomIndex=0,paused=false,hudVisible=true,spawnCount=0,entities={},players={},draws={}}
    local callbacks={}; local mod={}
    function mod:AddCallback(id,fn,filter) callbacks[id]=callbacks[id] or {}; table.insert(callbacks[id],{fn=fn,filter=filter}) end
    function mod:AddPriorityCallback(id,priority,fn,filter) self:AddCallback(id,fn,filter) end
    function f:call(name,...) local r; for _,cb in ipairs(callbacks[ModCallbacks[name]] or {}) do local v=cb.fn(mod,...) if v~=nil then r=v end end return r end
    local level={GetStage=function() return f.floor end,GetStageType=function() return 0 end,GetDungeonPlacementSeed=function() return 100+f.floor end,GetStartingRoomIndex=function() return 0 end,GetCurrentRoomIndex=function() return f.roomIndex end,GetDimension=function() return 0 end}
    local room={GetCenterPos=function() return Vector(320,280) end,FindFreePickupSpawnPosition=function(_,p) return p end,GetRenderMode=function() return 0 end}
    Game=function() return {GetLevel=function() return level end,GetRoom=function() return room end,GetFrameCount=function() return f.overlayPause and 0 or f.frame end,IsPaused=function() return f.paused or f.overlayPause end,IsPauseMenuOpen=function() return f.paused end,GetHUD=function() return {IsVisible=function() return f.hudVisible end} end} end
    local overlay={id=0,frame=0,event=false,playing=false,Color=Color(1,1,1,1)}
    function overlay:GetFrame() return self.frame end
    function overlay:IsPlaying() return self.playing end
    function overlay:IsEventTriggered(n) return self.event and n=='SleepFillHP' end
    function overlay:Render(p) eq(p.X,320);eq(p.Y,240);f.draws[#f.draws+1]={text='native-art',alpha=self.Color.A} end
    function overlay:SetLastFrame() self.frame=181;self.playing=false end
    ItemOverlay={GetOverlayID=function() return overlay.id end,GetSprite=function() return overlay end,GetPlayer=function() return f.players[1] end,
        GetDelay=function() return 0 end,
        Show=function(id) f:call('MC_PRE_ITEM_OVERLAY_SHOW',id,0,nil);overlay.id=id;overlay.playing=true;overlay.frame=0;f:call('MC_POST_ITEM_OVERLAY_SHOW',id,0,nil) end}; f.overlay=overlay
    Isaac={GetTime=function() return f.now end,GetFrameCount=function() return f.frame end,GetScreenWidth=function() return 640 end,GetScreenHeight=function() return 480 end,FindByType=function() local es={} for _,e in ipairs(f.entities) do if not e.removed then es[#es+1]=e end end return es end,
      Spawn=function(t,v,s,p,velocity,spawner) eq(t,5);eq(v,380);eq(s,0); f.spawnCount=f.spawnCount+1; local e={Type=t,Variant=v,SubType=s,Position=p,InitSeed=800+f.spawnCount,data={},State=0}
        function e:GetData() return self.data end; function e:ToPickup() return self end; function e:Exists() return not self.removed end;function e:Remove() self.removed=true end
        f.entities[#f.entities+1]=e;return e end}
    Input={IsActionPressed=function(a,c) local p=f.players[c+1];local binds=p.input[a] or {};return binds[1] or binds[2] or false end}
    function mod:RenderRuntimeText(_,text,x,y) f.draws[#f.draws+1]={text=text,x=x,y=y} end
    function f:addPlayer(seed,holds)
        local p={InitSeed=seed,ControllerIndex=#self.players,owned=holds,input={},Position=Vector(100,120),Velocity=Vector(0,0),hearts=2,maxHearts=6,soul=0,grants={}}
        function p:HasCollectible() return self.owned end;function p:ToPlayer() return self end;function p:IsDead() return false end
        function p:GetHearts() return self.hearts end;function p:GetEffectiveMaxHearts() return self.maxHearts end
        function p:AddHearts(n) self.grants[#self.grants+1]='red';self.hearts=math.min(self.maxHearts,self.hearts+n) end
        function p:AddSoulHearts(n) self.grants[#self.grants+1]='soul';self.soul=self.soul+n end
        local sprite={};function sprite:GetAnimation() return 'Sleep' end;function sprite:GetFrame() return 12 end;function sprite:SetFrame(a,n) self.held={a,n} end
        function p:GetSprite() return sprite end
        self.players[#self.players+1]=p;return p
    end
    local loader=loadfile('healthy_sleep.lua'); assert(loader,'健康睡眠生产模块尚未实现')
    loader()(mod,{ItemId=900,GetSaveRoot=function() return f.root end,Save=function() f.saved=copy(f.root) end,GetCurrentRunSeed=function() return 'RUN' end,GetPlayers=function() return f.players end})
    f.mod=mod
    function f:tick(seconds) self.now=self.now+seconds*1000;self.frame=self.frame+1;self:call('MC_POST_UPDATE');self:call('MC_POST_ITEM_OVERLAY_UPDATE') end
    function f:contact(target)
        local bed=self.entities[#self.entities]
        eq(self:call('MC_PRE_PICKUP_COLLISION',bed,self.players[1],false),nil)
        bed.Touched=true;bed.Target=target or self.players[1]
        ItemOverlay.Show(33)
        self:call('MC_POST_PICKUP_COLLISION',bed,self.players[1],false)
    end
    function f:nativeEffect()
        self.overlay.event=true;self.overlay.frame=73
        for _,bed in ipairs(self.entities) do
            local target=bed.Target
            if target then
                if target.maxHearts>0 then target.hearts=target.maxHearts
                else target:AddSoulHearts(6) end
                bed.Target=nil
            end
        end
        self.overlay.event=false
    end
    function f:begin(recipients)
        local target=recipients and recipients[1] or self.players[1]
        local hp,soul=target.hearts,target.soul
        self:contact(target)
        -- 1.7.9b bed red-heal writes health directly; it never calls AddHearts.
        self:nativeEffect()
        eq(target.hearts,hp,'native direct full-heal must be deferred')
        eq(target.soul,soul,'native soul reward must be deferred')
        self.overlay.event=false;self.overlay.playing=false;self:tick(0)
    end
    return f
end

-- Removing the durable floor latch would duplicate beds after re-entry/continue.
local f=fixture();local p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);eq(f.spawnCount,1)
for i=1,4 do f:call('MC_POST_NEW_ROOM');f:tick(0) end;eq(f.spawnCount,1)
f:call('MC_PRE_GAME_EXIT',true)
local resumed=fixture(copy(f.saved));resumed:addPlayer(11,true);resumed:call('MC_POST_GAME_STARTED',true);resumed:tick(0);eq(resumed.spawnCount,0,'continue never creates a second bed')

-- Native-selected recipients, not item holders, own the deferred award.
f=fixture();p=f:addPlayer(11,true);local other=f:addPlayer(22,false);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:begin({other})
eq(f:call('MC_PRE_PLAYER_UPDATE',p),nil);eq(f:call('MC_PRE_PLAYER_UPDATE',other),true)
for _,a in pairs(ButtonAction) do if a<12 then eq(f:call('MC_INPUT_ACTION',other,0,a),false);eq(f:call('MC_INPUT_ACTION',other,1,a),false);eq(f:call('MC_INPUT_ACTION',other,2,a),0) end end
eq(f:call('MC_INPUT_ACTION',other,0,12),nil,'pause still works')
eq(f:call('MC_PRE_PLAYER_ADD_HEARTS',other,2,1,false),nil,'ordinary healing unaffected')
f:tick(28800);eq(other.hearts,6);eq(other.soul,6);eq(p.soul,0);eq(table.concat(other.grants,','),'red,soul')
f:tick(50);eq(other.soul,6,'once only')

-- Real elapsed seconds and independently computed n=0/1/2/4 boundary values.
for _,case in ipairs({{0,28800},{1,8},{2,5.6573145294328},{4,4.0005556327268}}) do
    f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:begin()
    for a=0,case[1]-1 do p.input[a]={true,true} end -- same action has two bindings
    for i=1,14 do f:tick(0) end
    eq(f.root.healthySleep.floor.bed.sleep.multiplier,1,'14 frames not mature')
    f:tick(0)
    near(28800/f.root.healthySleep.floor.bed.sleep.multiplier,case[2],0.000002)
    f:tick(case[2]-0.01);eq(p.soul,0);f:tick(0.02);eq(p.soul,6)
end

-- Pause clock reset and serialized progress, without time spent outside the run.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:begin();f:tick(100)
f.paused=true;f.now=f.now+500000;f:call('MC_POST_RENDER');f.paused=false;f:tick(0)
near(f.root.healthySleep.floor.bed.sleep.elapsed,100)
f:call('MC_PRE_GAME_EXIT',true);local snapshot=copy(f.saved)
resumed=fixture(snapshot);p=resumed:addPlayer(11,true);resumed.now=9000000;resumed:call('MC_POST_GAME_STARTED',true);resumed:tick(0)
near(resumed.root.healthySleep.floor.bed.sleep.elapsed,100);resumed:tick(28700);eq(p.soul,6)
resumed.floor=2;resumed:call('MC_POST_NEW_LEVEL');resumed:tick(0);eq(resumed.spawnCount,1);eq(resumed.root.healthySleep.floor.bed.sleep,nil)

-- Loss cleans owned bed and sleep but keeps the per-floor tombstone.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:begin();p.owned=false;f:tick(1)
eq(f:call('MC_PRE_PLAYER_UPDATE',p),nil);p.owned=true;f:tick(1);eq(f.spawnCount,1)
f:call('MC_POST_GAME_STARTED',false);f:tick(0);eq(f.spawnCount,2,'same-seed fresh run resets latch')
-- A later natural bedroom/home sleep must not join an earlier owned sleep.
f=fixture();p=f:addPlayer(11,true);other=f:addPlayer(22,false);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:begin({p})
f.overlay.playing=true;f.overlay.event=true
eq(f:call('MC_PRE_PLAYER_ADD_HEARTS',other,6,4,false),nil,'natural bed reward not captured')
eq(f:call('MC_PRE_PLAYER_ADD_HEARTS',p,6,4,false),nil,'later event cannot alter original cohort')

-- Save during native entry: keep its selected target and progress, no second movie.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0)
local bed=f.entities[1];f:contact(p)
f:call('MC_PRE_GAME_EXIT',true)
resumed=fixture(copy(f.saved));resumed:addPlayer(11,true);resumed:call('MC_POST_GAME_STARTED',true)
eq(resumed.overlay.playing,false);eq(resumed.spawnCount,0)
eq(resumed:call('MC_PRE_PLAYER_UPDATE',resumed.players[1]),true)

-- An ineligible native collision must not create sleep, lock controls or grant.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);bed=f.entities[1]
f:call('MC_PRE_PICKUP_COLLISION',bed,p,false);f:call('MC_POST_PICKUP_COLLISION',bed,p,false)
eq(f.root.healthySleep.floor.bed.sleep,nil);eq(f:call('MC_PRE_PLAYER_UPDATE',p),nil)

-- Late acquisition waits for the existing starting room; no room-generation edits.
f=fixture();p=f:addPlayer(11,false);f.roomIndex=5;f:call('MC_POST_GAME_STARTED',false);p.owned=true;f:tick(0);eq(f.spawnCount,0)
f.roomIndex=0;f:call('MC_POST_NEW_ROOM');f:tick(0);eq(f.spawnCount,1)
f.roomIndex=5;p.owned=false;f:call('MC_POST_NEW_ROOM');f:tick(0)
f.roomIndex=0;p.owned=true;f:call('MC_POST_NEW_ROOM');f:tick(0);eq(f.entities[1].removed,true,'lost-item bed removed on revisit')

-- No cap at 4; release resets each action independently, aliases do not stack.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:begin()
for a=0,11 do p.input[a]={true,true} end
for i=1,15 do f:tick(0) end
near(f.root.healthySleep.floor.bed.sleep.multiplier,12468.301712880778,0.000002)
p.input[0]={};f:tick(0);near(f.root.healthySleep.floor.bed.sleep.multiplier,11937.532620488979,0.000002)

-- Repeated engine update in the same frame may neither advance time nor holds.
local before=f.root.healthySleep.floor.bed.sleep.elapsed;f.now=f.now+500;f:call('MC_POST_UPDATE');eq(f.root.healthySleep.floor.bed.sleep.elapsed,before)
f:call('MC_PRE_GAME_EXIT',true);snapshot=copy(f.saved);snapshot.healthySleep.floor.bed.sleep.elapsed='broken'
resumed=fixture(snapshot);p=resumed:addPlayer(11,true);resumed:call('MC_POST_GAME_STARTED',true);resumed:tick(0)
eq(resumed.spawnCount,0);eq(resumed:call('MC_PRE_PLAYER_UPDATE',p),nil,'corrupt progress fails closed')
-- Native entry time is included; only native-selected players' input history counts.
f=fixture();p=f:addPlayer(11,true);other=f:addPlayer(22,false);f:call('MC_POST_GAME_STARTED',false);f:tick(0)
bed=f.entities[1];f:contact(other)
for a=0,11 do p.input[a]={true,true} end
for i=1,15 do f:tick(1/30) end
f:nativeEffect();f.overlay.playing=false;f:tick(0)
near(f.root.healthySleep.floor.bed.sleep.elapsed,0.5)
eq(f.root.healthySleep.floor.bed.sleep.multiplier,1,'nonparticipant cannot accelerate native entry')
f:call('MC_POST_RENDER');eq(f.draws[#f.draws].text,'00:00 / 08:00')
f:tick(28799.5);eq(other.soul,6);f:call('MC_POST_RENDER');eq(f.draws[#f.draws].text,'08:00 / 08:00')
-- Giantbook pauses the room update/frame counter, but its own callback must tick.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:contact(p)
f.overlayPause=true;f.hudVisible=false
local function movieTick(seconds)
    f.now=f.now+seconds*1000;f.frame=f.frame+1;f:call('MC_POST_ITEM_OVERLAY_UPDATE')
end
movieTick(2);near(f.root.healthySleep.floor.bed.sleep.elapsed,2)
eq(p.hearts,2);eq(p.soul,0)
f:call('MC_POST_RENDER')
eq(f.draws[1].text,'native-art');eq(f.draws[1].alpha,1)
eq(f.draws[#f.draws].text,'00:00 / 08:00','clock drawn after native movie with hidden room HUD')
eq(f.overlay.Color.A,0,'later engine copy cannot cover clock')
f:call('MC_POST_RENDER');eq(f.draws[4].alpha,1,'next frame retains original movie opacity')
f.paused=true;f.now=f.now+500000;f:call('MC_POST_RENDER');movieTick(1)
near(f.root.healthySleep.floor.bed.sleep.elapsed,2) -- pause menu does not count
f.paused=false;movieTick(0);movieTick(1)
near(f.root.healthySleep.floor.bed.sleep.elapsed,3)
f:nativeEffect();eq(p.hearts,2,'movie event cannot finish the extended sleep')
f.overlay.playing=false;f.overlayPause=false;f.hudVisible=true;f:tick(1)
eq(f.overlay.Color.A,1,'movie ending restores the shared sprite')
f:tick(20);near(f.root.healthySleep.floor.bed.sleep.elapsed,24)
eq(f:call('MC_PRE_PLAYER_UPDATE',p),true,'sleep outlives original movie')

-- Other native beds keep their exact pending target/effect, including no-red players.
f=fixture();p=f:addPlayer(11,true);p.maxHearts=0;p.hearts=0
other=f:addPlayer(22,false);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:contact(p)
local natural=Isaac.Spawn(5,380,0,Vector.Zero,Vector.Zero,nil);natural.Target=other
f:nativeEffect();eq(p.soul,0);eq(other.hearts,6,'natural bed red effect still runs')
f.overlay.playing=false;f:tick(0);f:tick(28800);eq(p.soul,6);eq(other.soul,0)

-- Finishing early closes only the owned movie and restores its original color.
f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:contact(p)
f.overlay.Color=Color(0.8,0.7,0.6,0.9,0.1,0.2,0.3)
f:call('MC_POST_RENDER');eq(f.overlay.Color.A,0)
for a=0,3 do p.input[a]={true} end
for i=1,15 do f:tick(0) end
f:tick(4.01);eq(p.hearts,6);eq(p.soul,6);eq(f.overlay.playing,false)
near(f.overlay.Color.A,0.9);near(f.overlay.Color.GO,0.2)
f:nativeEffect();f:tick(10);eq(p.soul,6,'late native effect never pays a second time')

-- Replacing an overlay and exiting never leave the shared engine sprite invisible.
for _,event in ipairs({'foreign-overlay','MC_PRE_GAME_EXIT','MC_POST_NEW_LEVEL'}) do
    f=fixture();p=f:addPlayer(11,true);f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:contact(p)
    f:call('MC_POST_RENDER');eq(f.overlay.Color.A,0)
    if event=='foreign-overlay' then ItemOverlay.Show(1)
    elseif event=='MC_POST_NEW_LEVEL' then f.floor=2;f:call(event)
    else f:call(event,true) end
    eq(f.overlay.Color.A,1,event..' restores color')
end
print('healthy_sleep_behavior_test: PASS (Lua orchestration; engine behavior not verified)')
