local baseLoad = dofile('tests/support/neverbirth_fixture.lua')
local function load(options)
    options=options or {}
    local created=options.OnModCreated
    options.OnModCreated=function(mod,callbacks)
        InputHook={IS_ACTION_PRESSED=0,IS_ACTION_TRIGGERED=1,GET_ACTION_VALUE=2}
        ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD=ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD or 90001
        if created then created(mod,callbacks)end
    end
    return baseLoad(options)
end
local imports = {}
local e = load({ OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end })
local parts = {
    night_of_the_cowards = {'queries','grants','aura','fear','runtime'},
    kamikaze_squad = {'queries','targets','units','runtime'},
}
local paths = {}
for item, names in pairs(parts) do
    paths[#paths+1] = 'scripts.features.' .. item
    for _, name in ipairs(names) do paths[#paths+1] = 'scripts.features.' .. item .. '.' .. name end
end
for _, path in ipairs(paths) do assert(imports[path] == 1, path .. ' loaded once') end
local counts = {night_of_the_cowards=0,kamikaze_squad=0}
local unique = {}
for _, rows in pairs(e.callbacks) do
    for _, row in ipairs(rows) do
        local source = debug.getinfo(row.fn,'S').source
        for item in pairs(parts) do
            if source:find('/'..item..'/',1,true) then
                counts[item]=counts[item]+1
                local key=tostring(row.fn)..':'..tostring(row.param)
                assert(not unique[key],'duplicate binding');unique[key]=true
            end
        end
    end
end
assert(counts.night_of_the_cowards==10 and counts.kamikaze_squad==10,'native callback counts')
for _, path in ipairs(paths) do
    local previous=Neverbirth;local mod,rows
    local ok,err=pcall(load,{
        OnModCreated=function(m,c)mod,rows=m,c end,
        OnInclude=function(name)if name==path then error('batch18 missing '..name)end end,
    })
    assert(not ok and tostring(err):find('batch18 missing',1,true),path)
    assert(Neverbirth==previous and mod.NightOfTheCowardsTestAPI==nil,'failed publication restored')
    for _, list in pairs(rows)do assert(#list==0,'missing module leaves callbacks')end
end
for failAt=1,20 do
    local previous=Neverbirth;local mod,rows;local count=0
    local ok,err=pcall(load,{
        OnModCreated=function(m,c)mod,rows=m,c end,
        AfterRegister=function(_,_,fn)
            local source=debug.getinfo(fn,'S').source
            if source:find('/night_of_the_cowards/',1,true) or source:find('/kamikaze_squad/',1,true) then
                count=count+1;if count==failAt then error('batch18 register failure')end
            end
        end,
    })
    assert(not ok and tostring(err):find('batch18 register failure',1,true),'failure stage '..failAt)
    assert(Neverbirth==previous and mod.NightOfTheCowardsTestAPI==nil)
    for _, list in pairs(rows)do assert(#list==0,'registration failure leaves callbacks')end
end
load()
print('batch18 loading: 11 modules once, 20 bindings, 11 missing-module and 20 registration rollback cases passed')
