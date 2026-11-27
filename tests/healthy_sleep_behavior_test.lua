-- Engine boundary doubles: these tests do not prove native bed/co-op behavior.
local function eq(a,b,label) assert(a==b,(label or 'value')..': expected '..tostring(b)..', got '..tostring(a)) end
local function near(a,b,tolerance) assert(math.abs(a-b)<(tolerance or 0.000001),tostring(a)..' ~= '..tostring(b)) end
local function copy(t) if type(t)~='table' then return t end local o={} for k,v in pairs(t) do o[k]=copy(v) end return o end
local fixture = dofile('tests/support/healthy_sleep_fixture.lua')

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
