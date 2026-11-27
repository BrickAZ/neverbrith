local load=dofile('tests/support/neverbirth_fixture.lua')
local imports={}
local e=load({OnInclude=function(name)imports[name]=(imports[name] or 0)+1 end})
for _,part in ipairs({'queries','attributes','ledger','presentation','combat','runtime'})do
    assert(imports['scripts.features.burn_away_resentment.'..part]==1,part..' loaded once')
end
for _,name in ipairs({'UpdateBurnAwayResentment','EvaluateBurnAwayResentment','HandleBurnAwayResentmentDamage'})do
    local fn=Neverbirth[name];assert(debug.getinfo(fn,'S').source:find('/burn_away_resentment/',1,true))
    local n=0;for _,rows in pairs(e.callbacks)do for _,r in ipairs(rows)do if r.fn==fn then n=n+1 end end end
    assert(n==1,name..' registered once')
end
for failAt=1,9 do
    local previous=Neverbirth;local mod,rows;local count=0
    local ok,err=pcall(load,{
        OnModCreated=function(m,c)mod,rows=m,c end,
        AfterRegister=function(_,_,fn)
            if debug.getinfo(fn,'S').source:find('/burn_away_resentment/',1,true) then
                count=count+1;if count==failAt then error('batch11 injected registration failure')end
            end
        end,
    })
    assert(not ok and tostring(err):find('batch11 injected registration failure',1,true))
    assert(Neverbirth==previous and mod.BurnAwayResentment==nil and mod.UpdateBurnAwayResentment==nil)
    for _,list in pairs(rows)do assert(#list==0,'failed installation leaves callback')end
end
load()
print('batch11 loading: six modules once, named callback identity, nine registration rollback stages and fresh load passed')
