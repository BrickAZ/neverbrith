local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local imports={}
local env=loadMod({OnModCreated=function()ModCallbacks.MC_POST_PICKUP_MORPH=9003 end,
    OnInclude=function(name)imports[name]=(imports[name] or 0)+1 end})
for item,parts in pairs({condom={'bans','replacement','presentation'},crazy_coconut={'ledger','attributes','acquisition'},
    fortune_rivalling_heaven_gu={'audit','registry','runtime'}}) do
    assert(imports['scripts.features.'..item]==1)
    for _,part in ipairs(parts)do assert(imports['scripts.features.'..item..'.'..part]==1)end
end
local owners={UseCondom='condom/bans.lua',ReplaceCondomBannedPickup='condom/replacement.lua',
    EvaluateCrazyCoconut='crazy_coconut/attributes.lua',TrackCrazyCoconutCopies='crazy_coconut/acquisition.lua',
    HandleCrazyCoconutCollectiblePickup='crazy_coconut/acquisition.lua',
    EvaluateFortuneCustomCache='fortune_rivalling_heaven_gu/runtime.lua',
    TrackFortuneRivallingHeavenGuLuckSources='fortune_rivalling_heaven_gu/runtime.lua'}
for name,file in pairs(owners)do
    assert(debug.getinfo(Neverbirth[name],'S').source:gsub('\\','/'):find('scripts/features/'..file,1,true))
    local count=0
    for _,records in pairs(env.callbacks)do for _,r in ipairs(records)do if r.fn==Neverbirth[name]then count=count+1 end end end
    assert(count==(name=='ReplaceCondomBannedPickup' and 2 or 1),name..' registration count')
    local previous,partial,callbacks=Neverbirth
    local ok,err=pcall(loadMod,{
        OnModCreated=function(m,c)partial,callbacks=m,c end,
        AfterRegister=function(m,_,fn)if fn==m[name]then error('batch9 failure '..name)end end,
    })
    assert(not ok and tostring(err):find('batch9 failure '..name,1,true))
    assert(Neverbirth==previous and partial.CrazyCoconutPickupSources==nil and partial.FortuneRivallingHeavenGu==nil)
    for _,records in pairs(callbacks)do assert(#records==0)end
end
loadMod()
print('batch9 loading: twelve imports, original callback multiplicity, seven registration rollback points and fresh load passed')
