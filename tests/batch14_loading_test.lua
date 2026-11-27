local load=dofile('tests/support/neverbirth_fixture.lua')
local imports={}
local function complete() ModCallbacks.MC_POST_KNIFE_UPDATE=9001;ModCallbacks.MC_PRE_KNIFE_COLLISION=9002 end
local e=load({OnModCreated=complete,OnInclude=function(name)imports[name]=(imports[name]or 0)+1 end})
local expected={annihilation={'queries','ledger','presentation','combat','runtime'},avada_kedavra={'queries','weapon','casts','entities','hits','controls','runtime'},cleaver={'queries','attributes','geometry','presentation','shadows','controls','combat','runtime'}}
for feature,parts in pairs(expected)do for _,part in ipairs(parts)do
    assert(imports['scripts.features.'..feature..'.'..part]==1,feature..'.'..part..' imports once')
end end
local function ours(fn)
    local source=debug.getinfo(fn,'S').source
    for feature in pairs(expected)do if source:find('/features/'..feature..'/',1,true)then return true end end
    return false
end
local registered={};local n=0
for _,rows in pairs(e.callbacks)do for _,row in ipairs(rows)do if ours(row.fn)then
    n=n+1;registered[row.fn]=(registered[row.fn]or 0)+1
end end end
assert(n==49,'expected 49 callbacks, got '..n)
-- A few original handlers intentionally share a function across different events.
for _,fn in pairs(Neverbirth.AnnihilationTestAPI.Callbacks)do assert(registered[fn]==1)end
for failAt=1,n do
    local previous=Neverbirth;local mod,rows;local count=0
    local ok,err=pcall(load,{OnModCreated=function(m,c)mod,rows=m,c;complete()end,AfterRegister=function(_,_,fn)
        if ours(fn)then count=count+1;if count==failAt then error('batch14 rollback injection')end end
    end})
    assert(not ok and tostring(err):find('batch14 rollback injection',1,true),'failure stage '..failAt)
    assert(Neverbirth==previous and mod.AnnihilationTestAPI==nil and mod.AvadaKedavra==nil and mod.Cleaver==nil)
    for _,list in pairs(rows)do assert(#list==0,'callback survived rollback '..failAt)end
end
local ownership=dofile('scripts/systems/attack_ownership.lua')
assert(ownership.AvadaOwnsAttack({}, {})==nil)
local mod={AvadaKedavra=false};assert(ownership.AvadaOwnsAttack(mod,{})==false)
local player={};local token={};mod.AvadaKedavra={OwnsAttack=function(p)assert(p==player);return token end}
assert(ownership.AvadaOwnsAttack(mod,player)==token)
mod.AvadaKedavra={OwnsAttack=function()return false end};assert(ownership.AvadaOwnsAttack(mod,player)==false)
local reads=0;mod=setmetatable({},{__index=function(_,key)
    assert(key=='AvadaKedavra');reads=reads+1;return {OwnsAttack=function()return reads end}
end});assert(ownership.AvadaOwnsAttack(mod,player)==2 and reads==2)
mod.AvadaKedavra={OwnsAttack=function()error('expected native error')end}
local ok,err=pcall(ownership.AvadaOwnsAttack,mod,player);assert(not ok and tostring(err):find('expected native error',1,true))
assert(not pcall(ownership.AvadaOwnsAttack,nil,player),'invalid mod must not silently allow attack')
assert(not pcall(ownership.AvadaOwnsAttack,{AvadaKedavra={}},player),'missing method must not silently allow attack')
local seen='unset';assert(ownership.AvadaOwnsAttack({AvadaKedavra={OwnsAttack=function(p)seen=p;return 'kept' end}},nil)=='kept' and seen==nil)
load()
print('batch14 loading: 20 private modules once; 49 ordered failure stages rolled back; shared query boundaries passed')
