local base = 'reports/framework-closure/2026-11-27/baseline/'
local oldInitialize=dofile(base..'scripts/runtime/legacy_save_schema.lua')
local Persistence=dofile('scripts/runtime/persistence.lua')
local baselinePersistence=dofile(base..'scripts/runtime/persistence.lua')
local compose=dofile('scripts/runtime/legacy_save_schema.lua')
local declarations={
    dofile('scripts/features/musicbox/save_schema.lua'),
    dofile('scripts/features/boxes/angelbox_save_schema.lua'),
    dofile('scripts/features/boxes/devilbox_save_schema.lua'),
    dofile('scripts/features/between_death_and_life/save_schema.lua'),
    dofile('scripts/systems/dice_set/save_schema.lua'),
    dofile('scripts/features/condom/save_schema.lua'),
    dofile('scripts/features/utility_knife/save_schema.lua'),
    dofile('scripts/features/crazy_coconut/save_schema.lua'),
    dofile('scripts/features/black_taisui/save_schema.lua'),
    dofile('scripts/features/certificate_of_neverbirth/save_schema.lua'),
    dofile('scripts/features/house_vs_elephant/save_schema.lua'),
    dofile('scripts/features/everchanging/save_schema.lua'),
    dofile('scripts/features/dog_food_series/save_schema.lua'),
    dofile('scripts/features/big_dog_bark/save_schema.lua'),
    dofile('scripts/features/yins_curse/save_schema.lua'),
    dofile('scripts/features/revive_my_love/save_schema.lua'),
    dofile('scripts/features/memory_disorder/save_schema.lua'),
    dofile('scripts/features/ring_of_the_seven_curses/save_schema.lua'),
    dofile('scripts/features/night_of_the_cowards/save_schema.lua'),
}
local initialize=compose(declarations)
local function clone(value)
    if type(value)~='table' then return value end
    local result={};for k,v in pairs(value)do result[k]=clone(v)end;return result
end
local function serialize(value)
    if type(value)~='table' then return type(value)..':'..tostring(value) end
    local keys={};for k in pairs(value)do keys[#keys+1]=k end
    table.sort(keys,function(a,b)return tostring(a)<tostring(b)end)
    local out={};for _,k in ipairs(keys)do out[#out+1]=serialize(k)..'='..serialize(value[k])end
    return '{'..table.concat(out,',')..'}'
end
local names={};for _,d in ipairs(declarations)do names[#names+1]=d.Name end
local full={unknown={keep=false,version=91}}
oldInitialize(full)
for _,name in ipairs(names) do
    full[name].unknown={keep=false,version=42,seed='old-run'}
    for field in pairs(full[name]) do
        if field~='unknown' then full[name][field]={old=false,count=7,history={1,2,3}} end
    end
end
local cases={{name='empty',data={}},{name='populated',data=full}}
for _,name in ipairs(names)do
    for _,value in ipairs({false,true,42,'invalid'})do
        local data=clone(full);data[name]=value
        cases[#cases+1]={name=name..':'..tostring(value),data=data}
    end
    local data=clone(full);data[name]=nil
    cases[#cases+1]={name=name..':missing',data=data}
end
local nested=clone(full)
for _,name in ipairs(names)do
    for field in pairs(nested[name])do if field~='unknown' then nested[name][field]=false end end
end
cases[#cases+1]={name='invalid-nested-fields',data=nested}
local function evaluate(P,init,data,hasData)
    local sequence,written={},{}
    local decoded=clone(data)
    local mod={
        HasData=function()sequence[#sequence+1]='has-data';return hasData end,
        LoadData=function()sequence[#sequence+1]='load';return 'original-json'end,
        SaveData=function(_,payload)sequence[#sequence+1]='write';written[#written+1]=payload end,
    }
    local store=P.Create(mod,{Json={
        decode=function(payload)assert(payload=='original-json');sequence[#sequence+1]='decode';return decoded end,
        encode=function(root)sequence[#sequence+1]='encode';return serialize(root)end,
    },Initialize=function(root)sequence[#sequence+1]='initialize';return init(root)end})
    assert(#sequence==0)
    assert(store.Save())
    local root=store.GetRoot()
    root.extension=false
    assert(store.Save())
    return serialize(root),table.concat(sequence,','),table.concat(written,'\n')
end
for _,case in ipairs(cases)do
    local old=clone(case.data);oldInitialize(old)
    local new=clone(case.data);initialize(new)
    assert(serialize(old)==serialize(new),case.name..': initialization differs')
    for _,hasData in ipairs({false,true}) do
        local a,b,c=evaluate(baselinePersistence,oldInitialize,case.data,hasData)
        local x,y,z=evaluate(Persistence,initialize,case.data,hasData)
        assert(a==x and b==y and c==z,case.name..': load/first-save/second-save differs')
    end
end
print(('old/new owner schema comparison passed: %d data fixtures, %d save sequences, 19 regions'):format(#cases,#cases*2))
