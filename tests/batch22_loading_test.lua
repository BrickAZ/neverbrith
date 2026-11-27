local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local source='scripts/features/debug_controller.lua'
local function target(fn) return debug.getinfo(fn,'S').source:gsub('\\','/'):find(source,1,true)~=nil end
local count,imports=0,0
local function prepare(name)
    if name=='scripts.features.debug_controller' then ModCallbacks.MC_POST_FIRE_TEAR=6001 end
end
loadMod({OnInclude=function(name) prepare(name); if name=='scripts.features.debug_controller' then imports=imports+1 end end,
    AfterRegister=function(_,_,fn)if target(fn)then count=count+1 end end})
assert(imports==1 and count==8,'complete entry must install one controller through eight bindings')
local previous=Neverbirth
local function failure(options,marker)
    local callbacks,mod
    local requested=options.OnInclude
    options.OnInclude=function(name)prepare(name);if requested then requested(name)end end
    options.OnModCreated=function(m,c)mod,callbacks=m,c end
    local ok,err=pcall(loadMod,options)
    assert(not ok and tostring(err):find(marker,1,true),tostring(err))
    assert(Neverbirth==previous and mod.DebugController==nil,'failed replacement must not publish controller state')
    for _,rows in pairs(callbacks)do assert(#rows==0,'failed controller leaves callbacks')end
end
failure({OnInclude=function(name)if name=='scripts.features.debug_controller' then error('batch22 missing module')end end},'batch22 missing module')
for failAt=1,count do
    local seen=0
    failure({AfterRegister=function(_,_,fn)
        if target(fn)then seen=seen+1;if seen==failAt then error('batch22 registration failure')end end
    end},'batch22 registration failure')
end
loadMod()
assert(Neverbirth~=previous and Neverbirth.DebugController)
print('batch22 loading: one owner, missing module, eight registration rollback stages and fresh install passed')
