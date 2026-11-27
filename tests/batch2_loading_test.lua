local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local modules={chunyao='UseChunyao',utility_knife='EvaluateUtilityKnife',needletick='MarkNeedletickTearOnFire',
    sterilization_certificate='UpdateSterilizationCertificate',shredded_tarot='UseShreddedTarot',
    blood_skull_gu='UseBloodSkullGu',uncut_cord='HandleUncutCordDamage',empty_cradle='HandleEmptyCradleDamage'}
local function verify(env,counts)
    assert(counts['scripts.runtime.feature_installation']==1,'one shared installation scope per bootstrap')
    for _,method in ipairs({'ResetChunyaoState','ExitChunyao','UnloadChunyao','ExitUncutCord','UnloadUncutCord'})do
        local total=0
        for _,entries in pairs(env.callbacks)do for _,entry in ipairs(entries)do if entry.fn==Neverbirth[method]then total=total+1 end end end
        assert(type(Neverbirth[method])=='function' and total==1,method..' must register once')
    end
    assert(ModCallbacks.MC_POST_TEAR_UPDATE,'complete fixture must cover the native tear update event')
    local needleUpdates=0
    for _,entry in ipairs(env.callbacks[ModCallbacks.MC_POST_TEAR_UPDATE] or {})do
        if entry.fn==Neverbirth.UpdateNeedletickTear then needleUpdates=needleUpdates+1 end
    end
    assert(needleUpdates==1,'needle death update must register exactly once')
    for name,method in pairs(modules) do
        assert(counts['scripts.features.'..name]==1,name..' module must load once')
        local fn=Neverbirth[method];assert(type(fn)=='function',method..' missing')
        local total=0
        for _,entries in pairs(env.callbacks) do for _,entry in ipairs(entries) do if entry.fn==fn then total=total+1 end end end
        assert(total==1,method..' must register exactly once')
    end
end
local function load(omit)
    local counts={}
    local env=loadMod({OmitModule=omit,OnInclude=function(name)counts[name]=(counts[name] or 0)+1 end})
    return env,counts
end
for _=1,2 do
    local env,counts=load();verify(env,counts)
    local entries=env.callbacks[ModCallbacks.MC_USE_ITEM]
    entries[#entries+1]={fn=Neverbirth.UseChunyao,param=env.itemIds.Aphrodisiac}
    assert(not pcall(verify,env,counts),'duplicate callback must be detected')
end
for name in pairs(modules) do
    local ok=pcall(function()local env,counts=load('scripts.features.'..name);verify(env,counts)end)
    assert(not ok,'omitted '..name..' must fail complete-entry verification')
end
print('batch2 loading passed: eight real modules once, repeated installations, omitted modules and duplicate callbacks')
