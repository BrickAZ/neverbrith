-- Isolated factories with the existing engine-value fixture.
local savedArg=arg;arg={'--fixture'}
local fixture=dofile('tests/strong_laxative_behavior_test.lua');arg={};fixture();arg=savedArg
local originalInclude=include
local imports=0
include=function(name)
    assert(name=='scripts.features.strong_laxative.synergies','legacy shim must only export the factory')
    imports=imports+1;return dofile(name:gsub('%.','/')..'.lua')
end
local factory=dofile('strong_laxative_synergies.lua');include=originalInclude
assert(type(factory)=='function' and imports==1,'compatibility path must not create gameplay state')

local buildCatalog=dofile('scripts/features/tower_of_babel/creep_variants.lua')
local source={54,54,9999};local catalog=buildCatalog(source)
assert(catalog[1]==54 and catalog[2]==9999 and #source==3,'dedupe without mutating the injected policy')
local seen={};for _,v in ipairs(catalog)do assert(not seen[v]);seen[v]=true end
source[1]=8888
assert(catalog[1]==54,'catalog owns its copy')
local second=buildCatalog({7777});assert(second~=catalog and second[1]==7777,'independent catalog construction')

local events,registrations={},{}
local mod={StrongLaxative={}}
function mod:AddCallback(id,fn,filter) registrations[#registrations+1]={id,fn,filter} end
local player={InitSeed=11,Velocity=Vector(1,0),GetCollectibleNum=function()return 1 end}
local api=mod.StrongLaxative
api.ApplyCostume=function()events[#events+1]='costume'end
api.SpawnCreep=function()events[#events+1]='creep';return true end
api.TryPoopRoll=function()events[#events+1]='poop'end
local players=dofile('scripts/features/strong_laxative/players.lua')(mod,{
    Config={CreepInterval=6,PoopRollInterval=60}, ItemId=1,
    GetPlayerKey=function(p)return tostring(p.InitSeed)end,GetPlayers=function()return {player}end,
    IsValidItemId=function()return true end,PlayerHasCollectible=function()return true end,
    ResetPoopRoom=function()events[#events+1]='reset';assert(api.GetState(player).poopTimer==17)end,
})
assert(#registrations==0,'constructing state must not register early callbacks')
local state=api.GetState(player);state.poopTimer=59
mod:UpdateStrongLaxativePlayers()
assert(table.concat(events,',')=='costume,creep,poop' and state.creepCooldown==6 and state.poopTimer==0,'original update order')
state.poopTimer=17;state.custom='keep';mod:ResetStrongLaxativeRoomState()
assert(state.poopTimer==0 and state.creepCooldown==0 and state.custom=='keep','reset only owned timers after room allowance')
-- Existing public methods must still dispatch dynamically, not capture stale implementations.
api.SpawnCreep=function()events[#events+1]='replacement';return nil end
mod:UpdateStrongLaxativePlayers()
assert(events[#events]=='replacement' and state.creepCooldown==0,'public replacement and failed spawn remain observable')
players.InstallUpdateCallback();players.InstallRoomCallback()
assert(#registrations==2 and registrations[1][2]==mod.UpdateStrongLaxativePlayers and registrations[2][2]==mod.ResetStrongLaxativeRoomState)
print('batch7 dependencies: compatibility export, independent policy catalogs, update/reset order and dynamic public dispatch passed')
