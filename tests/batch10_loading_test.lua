local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local imports={}
local env=loadMod({OnInclude=function(name)imports[name]=(imports[name] or 0)+1 end})
for _,item in ipairs({'certificate_of_neverbirth','house_vs_elephant'})do
    assert(imports['scripts.features.'..item]==1)
    for _,part in ipairs({'ledger','gallery','flow','pickups','runtime'})do
        assert(imports['scripts.features.'..item..'.'..part]==1)
    end
end
assert(imports['scripts.systems.archive_room']==2 and imports['scripts.systems.archive_controls']==2)
for _,name in ipairs({'CertificateOfNeverbirthTestAPI','HouseVsElephantTestAPI'})do
    local item=name=='CertificateOfNeverbirthTestAPI' and 'certificate_of_neverbirth' or 'house_vs_elephant'
    for callback,fn in pairs(Neverbirth[name].Callbacks)do
        local file=debug.getinfo(fn,'S').source:gsub('\\','/')
        assert(file:find('scripts/features/'..item..'/',1,true),'callback must belong to private module')
        local n=0;for _,records in pairs(env.callbacks)do for _,r in ipairs(records)do if r.fn==fn then n=n+1 end end end
        assert(n==1,callback..' registration count')
    end
end
local stages=0
for _,name in ipairs({'CertificateOfNeverbirthTestAPI','HouseVsElephantTestAPI'})do
    for _,callback in ipairs({'UseItem','NewRoom','PickupCollision','Update','GameStarted','PreGameExit'})do
        local previous,partial,callbacks=Neverbirth
        local ok,err=pcall(loadMod,{
            OnModCreated=function(m,c)partial,callbacks=m,c end,
            AfterRegister=function(m,_,fn)
                if m[name] and m[name].Callbacks[callback]==fn then error('batch10 registration failure')end
            end,
        })
        assert(not ok and tostring(err):find('batch10 registration failure',1,true))
        assert(Neverbirth==previous and partial.CertificateOfNeverbirthCarrierAPI==nil and partial.HouseVsElephantCarrierAPI==nil)
        for _,records in pairs(callbacks)do assert(#records==0)end
        stages=stages+1
    end
end
loadMod()
print('batch10 loading: once-only feature imports, callback owners and '..stages..' registration rollback stages passed')
