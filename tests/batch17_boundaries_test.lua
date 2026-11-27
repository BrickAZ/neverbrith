local function eq(a,b,label)assert(a==b,(label or '')..': '..tostring(a)..' ~= '..tostring(b))end
local revive=dofile('tests/support/revive_my_love_fixture.lua')
local e=revive();local p=e.player(2);local q=e.player();e.call(2,false)
-- Provider is installed after revival and remains replaceable, as in main.lua.
local queries=0
e.mod.AvadaKedavra={IsFailureDeath=function(player)queries=queries+1;return player==p end}
p.dead=true;e.call(1051,p)
eq(queries,1);eq(p.revives,0);eq(p.removed,0);eq(#e.effects,0)
q.dead=true;e.call(1051,q);eq(q.revives,1,'other player still revives')
e.mod.AvadaKedavra={IsFailureDeath=function()return false end}
e.call(1051,p);eq(p.revives,1,'replacement provider is read at call time')
e.call(3,true);eq(p.ControlsEnabled,true);eq(q.ControlsEnabled,true)
-- Removing the entity clears only its sequence; other player still completes.
e=revive();p=e.player();q=e.player();e.call(2,false)
p.dead=true;q.dead=true;e.call(1051,p);e.call(1051,q)
p.Exists=function()return false end;e.call(6)
eq(e.effects[1].removed,true);eq(e.effects[2].removed,false)
e.effects[2].sprite.finished=true;e.call(4,e.effects[2]);eq(q.ControlsEnabled,true)

local sleep=dofile('tests/support/healthy_sleep_fixture.lua')
-- Install the real Seven Curses callbacks alongside the real sleep callbacks.
local f=sleep();p=f:addPlayer(11,true);q=f:addPlayer(22,false)
f:call('MC_POST_GAME_STARTED',false);f:tick(0)
local curseRoot={ringOfSevenCurses={runSeed='RUN',players={['11']={active=true}}}}
dofile('ring_of_the_seven_curses.lua')(f.mod,{ItemId=901,GetSaveRoot=function()return curseRoot end,
    Save=function()end,GetCurrentRunSeed=function()return 'RUN'end,GetPlayers=function()return f.players end})
local bed=f.entities[1]
eq(f:call('MC_PRE_PICKUP_COLLISION',bed,p,false),false,'curse blocks native sleep')
f:call('MC_POST_PICKUP_COLLISION',bed,p,false)
eq(f.root.healthySleep.floor.bed.sleep,nil,'veto creates no sleeper')
eq(f:call('MC_PRE_PLAYER_UPDATE',p),nil,'veto creates no control lock')
eq(f:call('MC_PRE_PICKUP_COLLISION',{Variant=380,SubType=10},p,false),nil,'story bed exception')
eq(f:call('MC_PRE_PICKUP_COLLISION',bed,q,false),nil,'unaffected teammate may sleep')
bed.Target=q;ItemOverlay.Show(33);f:call('MC_POST_PICKUP_COLLISION',bed,q,false)
eq(f:call('MC_PRE_PLAYER_UPDATE',q),true);eq(f:call('MC_PRE_PLAYER_UPDATE',p),nil)
f:tick(28800);eq(q.soul,6);eq(p.soul,0)

for _,event in ipairs({'room','death','game-end','unload'})do
    sleep=dofile('tests/support/healthy_sleep_fixture.lua');f=sleep();p=f:addPlayer(11,true)
    f:call('MC_POST_GAME_STARTED',false);f:tick(0);f:contact(p);f:call('MC_POST_RENDER')
    eq(f.overlay.Color.A,0)
    if event=='room'then f.roomIndex=2;f:call('MC_POST_NEW_ROOM')
    elseif event=='death'then p.IsDead=function()return true end;f:tick(1)
    elseif event=='game-end'then f:call('MC_POST_GAME_END')
    else f:call('MC_PRE_MOD_UNLOAD',{});eq(f.overlay.Color.A,0);f:call('MC_PRE_MOD_UNLOAD',f.mod)end
    eq(f.overlay.Color.A,1,event..' restores overlay')
    eq(f:call('MC_PRE_PLAYER_UPDATE',p),nil,event..' releases lock')
    eq(p.soul,0,event..' does not reward')
end
print('batch17 boundaries: dynamic Avada veto, co-op owner removal, real Seven Curses bed veto and four cleanup paths passed')
