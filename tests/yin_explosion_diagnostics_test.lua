-- Execute the opt-in diagnostic with fake game objects, no native game proof.
ModCallbacks={MC_PRE_PLAYER_EXPLOSION_IMMUNITY=1485,MC_PRE_PLAYER_ADD_HEARTS=1009,
    MC_POST_PLAYER_ADD_HEARTS=1010,MC_POST_ENTITY_TAKE_DMG=1006}
local callbacks,logs={},{}
Isaac={GetPlayerExplosionImmunityAPIVersion=function()return 1 end,
    DebugString=function(s)logs[#logs+1]=s end,GetCallbacks=function(id)return callbacks[id]or{} end}
setmetatable(Isaac,{__newindex=function(_,key)error("no writable variable '"..key.."'")end})
Game=function()return {GetSeeds=function()return {GetStartSeed=function()return 42 end} end} end
local mod={}
function mod:AddPriorityCallback(id,priority,fn)callbacks[id]=callbacks[id]or{};table.insert(callbacks[id],fn)end
function mod:RemoveCallback(id,fn)for i=#callbacks[id],1,-1 do if callbacks[id][i]==fn then table.remove(callbacks[id],i)end end end
local initialize=dofile('diagnostics/yin_explosion_immunity_acceptance.lua')
NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=false;initialize(mod);assert(next(callbacks)==nil,'off switch must register nothing')
NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true;initialize(mod);initialize(mod)
local p={InitSeed=123,GetPlayerType=function()return 0 end,GetHearts=function()return 5 end,GetSoulHearts=function()return 0 end}
local start=#logs
for _,fn in ipairs(callbacks[1010])do fn(mod,p,1,1)end
local count=0;for i=start+1,#logs do if logs[i]:find('heal-return',1,true)then count=count+1 end end
assert(count==1,'one actual post-hearts event must produce exactly one heal-return, got '..count)
for id in pairs(ModCallbacks)do local numeric=ModCallbacks[id];assert(#callbacks[numeric]==1,'each observation registers once')end
mod.YinExplosionDiagnostics.Disable();assert(Isaac._PlayerExplosionImmunityDebug==false)
for _,list in pairs(callbacks)do assert(#list==0,'Disable removes all diagnostic observers')end
NEVERBIRTH_YIN_EXPLOSION_DIAGNOSTICS=true;initialize(mod)
for _,list in pairs(callbacks)do assert(#list==1,'Re-enable must register once')end
mod.YinExplosionDiagnostics.Disable()
print('PASS opt_in_only, repeated_load_unique, one_heal_return, disable_and_reenable')
