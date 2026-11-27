local loader=dofile('tests/support/neverbirth_fixture.lua')
local names={'needletick','chunyao','uncut_cord','shredded_tarot','blood_skull_gu',
    'sterilization_certificate','empty_cradle','utility_knife'}
local function owner(fn)
    local source=debug.getinfo(fn,'S').source:gsub('\\','/')
    for _,name in ipairs(names)do if source:find('scripts/features/'..name..'.lua',1,true)then return name end end
    return nil
end
local function checkRollback(mod,callbacks)
    local kept=0
    for _,entries in pairs(callbacks)do
        for _,record in ipairs(entries)do
            assert(not owner(record.fn),'failed batch retained callback from '..tostring(owner(record.fn)))
            kept=kept+1
        end
    end
    assert(kept==0,'whole-entry transaction must remove every callback from a failed bootstrap')
    for _,method in ipairs({'MarkNeedletickTearOnFire','UseChunyao','HandleUncutCordDamage','UseShreddedTarot',
        'UseBloodSkullGu','UpdateSterilizationCertificate','HandleEmptyCradleDamage','EvaluateUtilityKnife'})do
        assert(mod[method]==nil,'failed batch retained export '..method)
    end
end
for _,target in ipairs(names)do
    local mod,callbacks,count
    count=0
    local ok,err=pcall(loader,{
        OnModCreated=function(m,c)mod,callbacks=m,c end,
        AfterRegister=function(_,_,fn)
            if owner(fn)==target then
                count=count+1
                if count==2 then error('injected '..target..' registration failure')end
            end
        end,
    })
    assert(not ok and count==2 and tostring(err):find('injected '..target,1,true),tostring(err))
    checkRollback(mod,callbacks)
end
-- A missing provider must not leave earlier consumers with nil captured providers.
local mod,callbacks
local ok,err=pcall(loader,{
    OmitModule='scripts.features.blood_skull_gu',
    OnModCreated=function(m,c)mod,callbacks=m,c end,
})
assert(not ok and tostring(err):find('BloodSkullGu query missing',1,true))
checkRollback(mod,callbacks)
local fresh=loader()
assert(Neverbirth.UseChunyao and Neverbirth.HandleUncutCordDamage and #fresh.callbacks[ModCallbacks.MC_USE_ITEM]>0)
print('batch2 installation failure passed: eight real installers, delayed UtilityKnife registration, provider failure, unrelated callbacks and fresh bootstrap')
