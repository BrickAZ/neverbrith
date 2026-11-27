local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local imports={}
local env=loadMod({OnInclude=function(name)imports[name]=(imports[name] or 0)+1 end})
for _,name in ipairs({'strong_laxative','strong_laxative.creep_variants','strong_laxative.players',
    'strong_laxative.creep','strong_laxative.poop','strong_laxative.presentation','strong_laxative.synergies',
    'tower_of_babel','tower_of_babel.creep_variants'}) do
    assert(imports['scripts.features.'..name]==1,name..' installed once')
end
assert(imports.strong_laxative_synergies==nil,'production must load the item-owned synergy path directly')
local owners={UpdateStrongLaxativePlayers='strong_laxative/players.lua',
    ResetStrongLaxativeRoomState='strong_laxative/players.lua',
    UpdateStrongLaxativeCreep='strong_laxative/creep.lua',
    BlockStrongLaxativeCreepDamage='strong_laxative/creep.lua',
    RefreshStrongLaxativeOnPickup='strong_laxative/presentation.lua'}
for name,file in pairs(owners) do
    local fn,count=Neverbirth[name],0
    assert(debug.getinfo(fn,'S').source:gsub('\\','/'):find('scripts/features/'..file,1,true),name..' owner')
    for _,records in pairs(env.callbacks)do for _,r in ipairs(records)do if r.fn==fn then count=count+1 end end end
    assert(count==1,name..' registered once')
end
for _,name in ipairs({'RemoveTowerOfBabelCreepOnInit','UpdateStrongLaxativePlayers',
    'UpdateStrongLaxativeCreep','RefreshStrongLaxativeOnPickup','ResetStrongLaxativeRoomState'}) do
    local previous,partial,callbacks=Neverbirth
    local ok,err=pcall(loadMod,{
        OnModCreated=function(m,c)
            partial,callbacks=m,c
            ModCallbacks.MC_POST_EFFECT_INIT=9002
            EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL=54
        end,
        AfterRegister=function(m,_,fn)if m[name]==fn then error('batch7 failure '..name)end end,
    })
    assert(not ok and tostring(err):find('batch7 failure '..name,1,true),name)
    assert(Neverbirth==previous,'restore previous mod after '..name)
    assert(partial.StrongLaxative==nil and partial.TowerOfBabel==nil,'no partial namespaces')
    for event,records in pairs(callbacks)do assert(#records==0,'retained callback '..event)end
end
loadMod()
print('batch7 loading: nine imports, five unique item callbacks, five failure phases and fresh load passed')
