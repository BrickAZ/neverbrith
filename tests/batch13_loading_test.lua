local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local counts={};local ownCallbacks=0
local schemaLoads=0
local function family(name)
    return (name:match('^scripts%.features%.big_dog_bark') and name~='scripts.features.big_dog_bark.save_schema')
        or name=='scripts.features.echo_shard' or name=='scripts.features.wind_charge_rod'
end
local function own(fn)
    local source=debug.getinfo(fn,'S').source:gsub('\\','/')
    return source:find('/big_dog_bark/',1,true) or source:find('/echo_shard.lua',1,true)
end
loadMod({OnModCreated=function()ModCallbacks.MC_POST_GET_COLLECTIBLE=9003 end,
    OnInclude=function(name)
        if name=='scripts.features.big_dog_bark.save_schema' then schemaLoads=schemaLoads+1 end
        if family(name)then counts[name]=(counts[name]or 0)+1 end
    end,
    AfterRegister=function(_,_,fn)if own(fn)then ownCallbacks=ownCallbacks+1 end end})
local modules=0;for _,count in pairs(counts)do assert(count==1);modules=modules+1 end
assert(modules==17,'three item entries and fourteen private modules must load exactly once')
assert(schemaLoads==1,'the owner save declaration must load exactly once, outside the seventeen gameplay modules')
assert(counts['scripts.features.big_dog_bark'] and counts['scripts.features.wind_charge_rod'] and counts['scripts.features.echo_shard'])
assert(ownCallbacks==16,'the family retains sixteen native registrations')
local prior={name='previous mod'}
for failAt=1,ownCallbacks do
    local seen,mod,callbacks=0
    _G.Neverbirth=prior
    local ok,err=pcall(loadMod,{OnModCreated=function(m,c)mod,callbacks=m,c;ModCallbacks.MC_POST_GET_COLLECTIBLE=9003 end,
        AfterRegister=function(_,_,fn)
            if own(fn)then seen=seen+1;if seen==failAt then error('batch13 registration failure')end end
        end})
    assert(not ok and tostring(err):find('batch13 registration failure',1,true))
    for _,entries in pairs(callbacks)do assert(#entries==0,'partial callbacks retained')end
    assert(mod.BigDogBarkTestAPI==nil and _G.Neverbirth==prior,'partial family export retained')
end
local fixture=dofile('tests/support/big_dog_fixture.lua')
local first=fixture();local second=fixture()
assert(first.api.Runtime~=second.api.Runtime and first.api.Constants~=second.api.Constants)
local p=first.player(13);first.api.GetPlayerRecord(p).foodPickups=3
assert(second.api.GetPlayerRecord(p).foodPickups==0,'separate installation state must not alias')
print('batch13 loading: 17 gameplay modules and one save declaration once, 16 registration rollback stages, independent instances passed')
