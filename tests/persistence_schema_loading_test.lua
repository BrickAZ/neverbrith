local realDofile=dofile
local loadMod=realDofile('tests/support/neverbirth_fixture.lua')
local expectedNames={'musicboxDeathDebt','angelbox','devilbox','deathTrial','diceSet','condom','utilityKnife','crazyCoconut','blackTaisui','certificateOfNeverbirth','houseVsElephant','everchanging','dogFoodSeries','bigDogBark','yinCurse','reviveMyLove','memoryDisorder','ringOfSevenCurses','nightOfTheCowards'}
local paths={
    'scripts.features.musicbox.save_schema',
    'scripts.features.boxes.angelbox_save_schema',
    'scripts.features.boxes.devilbox_save_schema',
    'scripts.features.between_death_and_life.save_schema',
    'scripts.systems.dice_set.save_schema',
    'scripts.features.condom.save_schema',
    'scripts.features.utility_knife.save_schema',
    'scripts.features.crazy_coconut.save_schema',
    'scripts.features.black_taisui.save_schema',
    'scripts.features.certificate_of_neverbirth.save_schema',
    'scripts.features.house_vs_elephant.save_schema',
    'scripts.features.everchanging.save_schema',
    'scripts.features.dog_food_series.save_schema',
    'scripts.features.big_dog_bark.save_schema',
    'scripts.features.yins_curse.save_schema',
    'scripts.features.revive_my_love.save_schema',
    'scripts.features.memory_disorder.save_schema',
    'scripts.features.ring_of_the_seven_curses.save_schema',
    'scripts.features.night_of_the_cowards.save_schema',
}
local imports, composed = {}, 0
_G.dofile=function(path)
    local value=realDofile(path)
    if path=='scripts/runtime/legacy_save_schema.lua' then
        return function(declarations)
            composed=composed+1
            assert(#declarations==#expectedNames, 'complete owner schema set')
            for i,name in ipairs(expectedNames)do assert(declarations[i].Name==name, 'old initialization order at '..i)end
            return value(declarations)
        end
    end
    return value
end
local ok,err=pcall(loadMod,{OnInclude=function(path)imports[path]=(imports[path]or 0)+1 end})
_G.dofile=realDofile
assert(ok,err)
assert(composed==1)
for _,path in ipairs(paths)do assert(imports[path]==1,path..' must have one declaration load')end
local previous=Neverbirth
for _,path in ipairs(paths)do
    local callbacks
    local success,message=pcall(loadMod,{
        OnInclude=function(name)if name==path then error('missing owner schema '..path)end end,
        OnModCreated=function(_,records)callbacks=records end,
    })
    assert(not success and tostring(message):find('missing owner schema',1,true),path)
    assert(Neverbirth==previous,'failed schema load replaced the running instance')
    for _,records in pairs(callbacks)do assert(#records==0,'partial installation retained for '..path)end
end
print('persistence schema loading: 19 owner declarations in old order, one installation and 19 missing-module rollback cases passed')
