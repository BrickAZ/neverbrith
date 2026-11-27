function include(name) return dofile(name:gsub('%.', '/') .. '.lua') end
local World = include('scripts.runtime.world_queries')
local trace = {}
Game = function() error('not in game') end
assert(World.TryGame() == nil)
Game = function() return false end
assert(World.TryGame() == false, 'protected query preserves a successful false result')
assert(World.TryMethod({ GetRoom = function() error('room unavailable') end }, 'GetRoom') == nil)
assert(World.TryMethod({ GetRoom = function() return false end }, 'GetRoom') == false)
local level = { GetCurrentRoomIndex = function() trace[#trace+1]='index'; return 0 end }
local room = { GetSpawnSeed = function() trace[#trace+1]='seed'; return 17 end }
local function getLevel() trace[#trace+1]='level'; return level end
local function getRoom() trace[#trace+1]='room'; return room end
assert(World.RoomIndexOrSeed(getLevel,getRoom) == 'idx:0' and table.concat(trace,',') == 'level,index')
trace={}; level.GetCurrentRoomIndex=function() error('index unavailable') end
assert(World.RoomIndexOrSeed(getLevel,getRoom) == 'seed:17' and table.concat(trace,',') == 'level,room,seed')
room.GetSpawnSeed=function() error('seed unavailable') end
assert(World.RoomIndexOrSeed(getLevel,getRoom) == 'unknown')
level.GetStage=function() error('required stage') end
assert(not pcall(World.RunFloorKey,level,function() return 'run' end), 'required stage errors must propagate')
assert(World.RunFloorKey(nil,function() return 'run' end) == 'run:unknown')

local slots=include('scripts.systems.active_slots')
ActiveSlot=nil; assert(table.concat(slots(),',') == '0,1,2,3')
ActiveSlot={ SLOT_PRIMARY=0,SLOT_POCKET2=7 }; assert(table.concat(slots(),',')=='0,7')
ActiveSlot={}; assert(#slots()==0, 'partial enums do not invent slots')

local Rolls=include('scripts.systems.collectible_rng')
local queries,rolls,roomReads=0,0,0
local rng={RandomInt=function(_,max) rolls=rolls+1;assert(max==4);return 2.8 end}
local p={GetCollectibleRNG=function(_,id)queries=queries+1;assert(id==11);return rng end}
local acquired=Rolls.Get(p,11,'RandomInt')
assert(acquired==rng and queries==1 and rolls==0, 'getting RNG consumes no draws')
assert(Rolls.IntOrMath(acquired,4)==2.8, 'coercing stream keeps the original fractional boundary')
local getSeedRoom=function()roomReads=roomReads+1;return {GetSpawnSeed=function()return 11 end}end
assert(Rolls.IntOrRoomSeed(acquired,4,getSeedRoom)==2 and roomReads==0)
rng.RandomInt=function()error('RNG error')end
assert(Rolls.IntOrRoomSeed(acquired,4,getSeedRoom)==3 and roomReads==1)
local oldRandom=math.random; local fallbackCalls=0
math.random=function(max)fallbackCalls=fallbackCalls+1;assert(max==4);return 2 end
assert(Rolls.IntOrMath(acquired,4)==1 and fallbackCalls==1)
math.random=oldRandom
assert(Rolls.Get({GetCollectibleRNG=function()error('missing RNG')end},11)==nil)

local createRunSection=include('scripts.runtime.run_section')
local seed,root,seedReads,creates,saves='a',{},0,0,0
local function store(name)return {Get=function()return root[name]end,Replace=function(v)root[name]=v end,Save=function()saves=saves+1 end}end
local function getSeed()seedReads=seedReads+1;return seed end
local function create()creates=creates+1;return {runSeed=getSeed(),records={}}end
local a=createRunSection(store('a'),getSeed,create,{'records'})
local b=createRunSection(store('b'),getSeed,create,{'records'})
local original=a();assert(creates==1 and seedReads==1 and saves==0)
original.extension=17;original.records.owner='a';assert(b()~=original and b().records.owner==nil)
assert(a()==original and original.extension==17)
root.a={runSeed='a',records='invalid',extension=23}
assert(a()==root.a and type(root.a.records)=='table' and root.a.extension==23, 'live replacement and field repair')
seed='b';assert(a().runSeed=='b' and a()~=original and original.records.owner=='a')
assert(saves==0, 'query initialization does not acquire save authority')

local newRun=include('scripts.runtime.new_run_reset')
trace={}
local reset=newRun({GetPlayers=function()trace[#trace+1]='players';return {1,2}end,
    Players={function(id)trace[#trace+1]='costume'..id end,function(id)trace[#trace+1]='effect'..id end},
    Reset={function()trace[#trace+1]='state' end,function()trace[#trace+1]='save' end}})
reset({},true);assert(#trace==0, 'continue does not enumerate or clear players')
reset({},false);assert(table.concat(trace,',')=='players,costume1,effect1,costume2,effect2,state,save')
trace={};local fail=newRun({Reset={function()error('cleanup failure')end,function()trace[#trace+1]='incorrect' end}})
assert(not pcall(fail,{},false) and #trace==0, 'cleanup failure stops later mutations')

local Source=include('scripts.systems.combat_source')
local entity={ToPlayer=function()return p end};assert(Source.Entity({Entity=entity})==entity and Source.TryPlayer(entity)==p)
assert(Source.Entity({Entity=false}).Entity==false)
assert(Source.TryPlayer({ToPlayer=function()error('removed')end})==nil)
local addTears=include('scripts.systems.fire_rate')
assert(addTears(9,0)==9 and math.abs(addTears(9,0.5)-(30/3.5-1))<1e-10)
assert(addTears(-1,0.5)==addTears(-9,0.5), 'legacy lower bound')
print('shared capabilities contracts: optional/required errors, room identity, slots, RNG streams, live saves, cleanup order and source facts passed')
