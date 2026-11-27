local create=dofile('scripts/features/boxes/reward_ledger.lua')
local function fresh()return {players={},pendingRewards={},entered={},appliedChanceFloors={}}end
local roots={a=fresh(),b=fresh()}
local run,floor,roomType='run-a','floor-a',1
local deltas={}
local function build(name,room,legacy,clear)
    return create({GetData=function()return roots[name]end,GetRunSeed=function()return run end,
        GetFloorKey=function()return floor end,GetRoom=function()return {GetType=function()return roomType end}end,
        GetLevel=function()return {AddAngelRoomChance=function(_,delta)deltas[#deltas+1]=delta end}end,
        RoomType=room,EnteredField='entered',LegacyChance=legacy,ClearChance=clear})
end
local angel=build('a',15,0.5,function(v)return v<=0 end)
local devil=build('b',14,-0.5,function(v)return v>=0 end)
local p={InitSeed=7}
local record,key=angel.PlayerRecord(p);assert(key=='7' and not record.firstUseDone)
record.firstUseDone=true;assert(not devil.PlayerRecord(p).firstUseDone)
assert(angel.MarkPending(p) and angel.MarkPending(p) and angel.Count()==1, 'one pending reward per player')
roots.a.pendingRewards[floor]=2;assert(angel.Count()==2 and angel.Pending().legacy1 and angel.Pending().legacy2)
roomType=15;assert(not angel.MarkPending({InitSeed=8}) and angel.MarkEntered() and not angel.MarkEntered())
roomType=1;assert(angel.HasEntered() and not devil.HasEntered())
floor='floor-b';assert(not angel.HasEntered() and angel.Count()==0)
roots.a.appliedChanceFloors[floor]=true;roots.b.appliedChanceFloors[floor]=true
assert(angel.SetChance(0) and devil.SetChance(0))
assert(deltas[1]==-0.5 and deltas[2]==0.5 and roots.a.appliedChanceFloors[floor]==nil and roots.b.appliedChanceFloors[floor]==nil)
assert(not angel.SetChance(0) and #deltas==2, 'undo exactly once')
assert(angel.SetChance(0.5) and devil.SetChance(-0.5))
assert(roots.a.appliedChanceFloors[floor]==0.5 and roots.b.appliedChanceFloors[floor]==-0.5)
local old=roots.a;roots.a=fresh();assert(not angel.PlayerRecord(p).firstUseDone and old.players['7'].firstUseDone)
run='run-b';assert(angel.PlayerRecord(p).runSeed=='run-b')

-- Settlement retains ordering and existing failure behavior. A failed native
-- spawn is consumed; an exception stops before clearing/saving the entitlement.
local events={}
local vectorMT={__add=function(a,b)return setmetatable({X=a.X+b.X,Y=a.Y+b.Y},getmetatable(a))end}
function Vector(x,y)return setmetatable({X=x,Y=y},vectorMT)end
local game={Spawn=function(_,kind,variant,pos,velocity,owner,item,seed)
    events[#events+1]='spawn:'..item..':'..seed;return nil
end}
local room={GetType=function()return 15 end,GetCenterPos=function()return Vector(100,200)end,GetSpawnSeed=function()return 90 end,
    FindFreePickupSpawnPosition=function(_,pos)events[#events+1]='position:'..pos.X;return pos end}
local ledger={HasPending=function()return true end,Count=function()return 2 end,ClearPending=function()events[#events+1]='clear'end}
local delivery=dofile('scripts/features/boxes/reward_delivery.lua')({
    Shared={GetGame=function()return game end,GetRoom=function()return room end,PickupEntity=5,CollectibleVariant=100},
    Ledger=ledger,RoomType=15,Name='test',Select=function(index,seen)
        if index==2 then assert(seen[101])end;events[#events+1]='select:'..index;return 100+index
    end,Log=function()events[#events+1]='log'end,Save=function()events[#events+1]='save'end})
assert(delivery())
assert(table.concat(events,',')=='position:80.0,select:1,spawn:101:91,log,position:120.0,select:2,spawn:102:92,log,clear,save')
events={};game.Spawn=function()error('native spawn failure')end
assert(not pcall(delivery) and #events==2, 'no clear/save after a thrown spawn')
print('shared box ledger: owner/floor isolation, live sections, legacy migration, signed chance deltas and settlement failure semantics passed')
