local load = dofile('tests/support/neverbirth_fixture.lua')
local completeSurface = dofile('tests/support/batch16_engine_surface.lua')
local parts={
    i_am_a_god={'config','state','health','presentation','combat','lifecycle'},
    god_complex={'config','state','targeting','presentation','combat','lifecycle'},
    bomb_suit={'config','state','bombs','presentation','damage','lifecycle'},
}
local imports, registrations={},{}
local function owner(fn)
    return debug.getinfo(fn,'S').source:match('/features/(i_am_a_god)/')
        or debug.getinfo(fn,'S').source:match('/features/(god_complex)/')
        or debug.getinfo(fn,'S').source:match('/features/(bomb_suit)/')
end
load({OnModCreated=completeSurface,OnInclude=function(name) imports[name]=(imports[name] or 0)+1 end,
    AfterRegister=function(_,event,fn)
        local item=owner(fn)
        if item then registrations[item]=(registrations[item] or 0)+1 end
    end})
for item, names in pairs(parts) do
    for _, name in ipairs(names) do
        assert(imports['scripts.features.'..item..'.'..name]==1,item..'.'..name..' loaded once')
    end
    assert((registrations[item] or 0)>15,item..' actually registered')
    for failAt=1,registrations[item] do
        local previous=Neverbirth;local mod,rows;local seen=0
        local ok,err=pcall(load,{
            OnModCreated=function(m,c)completeSurface();mod,rows=m,c end,
            AfterRegister=function(_,event,fn)
                if owner(fn)==item then
                    seen=seen+1
                    if seen==failAt then error('batch16 injected failure') end
                end
            end,
        })
        assert(not ok and tostring(err):find('batch16 injected failure',1,true),item..' stage '..failAt)
        assert(Neverbirth==previous and mod.BombSuit==nil,'failed install exports leaked')
        for _,list in pairs(rows) do assert(#list==0,'failed install callback leaked') end
    end
    print('batch16 loading: '..item..' '..registrations[item]..' registration failures rolled back')
end
load({OnModCreated=completeSurface})
assert(Neverbirth.BombSuit and type(Neverbirth.BombSuit.GetAge)=='function')
print('batch16 loading: all 18 private modules loaded once; fresh full load passed')
