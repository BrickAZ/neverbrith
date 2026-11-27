-- Native wrappers with one pointer share attribution; new spawns cannot inherit it.
include=function(name)return dofile(name..'.lua')end
local identity=include('scripts/systems/entity_identity')
local a={InitSeed=7,ptr=100};local b={InitSeed=7,ptr=100}
GetPtrHash=function(e)return e.ptr end
assert(identity(a)=='100:7' and identity(a)==identity(b))
b.InitSeed=8;assert(identity(a)~=identity(b))
assert(identity({ptr=3})=='3:0')
GetPtrHash=function()return nil end;assert(identity(a)=='nil:7')
GetPtrHash=nil;assert(identity(a)==tostring(a)..':7')
GetPtrHash=function()error('native identity failure')end
assert(not pcall(identity,a),'native failure must propagate')
GetPtrHash=function(e)return e.ptr end
local gate=include('motion_input_shooting').New()
local p={Type=1,InitSeed=4,ptr=40};function p:ToPlayer()return self end
gate:Update(p,true)
local alias={Type=1,InitSeed=4,ptr=40};function alias:ToPlayer()return self end
assert(gate:IsRestricted(alias),'player wrapper uses the same identity')
local npc={Type=10,InitSeed=9,ptr=90};function npc:ToPlayer()end
local wrapper={Type=10,InitSeed=9,ptr=90};function wrapper:ToPlayer()end
gate:StatusApplied(npc,{Entity=p},1)
assert(gate:ShouldBlockDamage(wrapper,nil,1),'unmarked status damage remains restricted across wrappers')
wrapper.InitSeed=10
assert(not gate:ShouldBlockDamage(wrapper,nil,1),'new spawn cannot inherit old status attribution')
wrapper.InitSeed=9;gate:ForgetEntity(wrapper)
assert(not gate:ShouldBlockDamage(npc,nil,1),'removal clears the matching entity identity')
local custom=include('motion_input_shooting').New({Key=function(e)return e.InitSeed end,EntityKey=function()return 'custom' end})
custom:Update(p,true);custom:StatusApplied(npc,p,1)
assert(custom:ShouldBlockDamage(wrapper,nil,1),'injected key policies retain priority')
print('batch21 identity: pointer wrappers, spawn isolation, fallback/errors and real shooting attribution passed')
