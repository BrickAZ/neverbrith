-- Exercise every current feature import and every registration through the real entry.
local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local modules, seen, registrationCount={}, {}, 0
local priorGlobal={name='previous Neverbirth export'}
_G.Neverbirth=priorGlobal
local initial=loadMod({OnInclude=function(name)
    if name:match('^scripts%.features%.') and not seen[name] then seen[name]=true;modules[#modules+1]=name end
end,AfterRegister=function()registrationCount=registrationCount+1 end})
assert(#modules>=38 and registrationCount>400,'complete entry fixture must load the currently migrated modules')
local function assertRolledBack(mod, callbacks, marker)
    for event,entries in pairs(callbacks) do assert(#entries==0,marker..' retained callback '..event) end
    assert(_G.Neverbirth==priorGlobal,marker..' did not restore the previous global mod export')
    assert(mod.UseMusicbox==nil and mod.UseBossOrder==nil and mod.GoodGirl==nil,marker..' retained partial feature exports')
end
for _,target in ipairs(modules)do
    local mod,callbacks
    _G.Neverbirth=priorGlobal
    local ok,err=pcall(loadMod,{OnModCreated=function(m,c)mod,callbacks=m,c end,
        OnInclude=function(name)if name==target then error('injected missing feature '..target)end end})
    assert(not ok and tostring(err):find('injected missing feature '..target,1,true),target)
    assertRolledBack(mod,callbacks,target)
end
-- Early, middle and final mutations test the enclosing transaction, not only the last factory.
for _,failAt in ipairs({1,math.floor(registrationCount/2),registrationCount})do
    local mod,callbacks,count
    count=0;_G.Neverbirth=priorGlobal
    local ok,err=pcall(loadMod,{OnModCreated=function(m,c)mod,callbacks=m,c end,
        AfterRegister=function()count=count+1;if count==failAt then error('injected registration '..failAt)end end})
    assert(not ok and tostring(err):find('injected registration '..failAt,1,true))
    assertRolledBack(mod,callbacks,'registration '..failAt)
end
local fresh=loadMod()
assert(Neverbirth.UseBossOrder and Neverbirth.ApplyMeatLumpLife and Neverbirth.UseDevilbox)
assert(#fresh.callbacks[ModCallbacks.MC_USE_ITEM]>0,'fresh bootstrap must still load after failure probes')
print('thin entry installation: '..#modules..' real feature import failures, 3 mutated registration failures, global/mod/callback restoration and fresh load')
