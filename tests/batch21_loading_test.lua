-- Exercise the real bootstrap, item specification identity and rollback at each
-- target callback mutation. Missing modules must not silently disable an item.
local loadMod=dofile('tests/support/neverbirth_fixture.lua')
local imports,registrations={},0
local function target(fn)
    local src=debug.getinfo(fn,'S').source:gsub('\\','/')
    return src:find('/drive_glove/',1,true) or src:match('[/@]drive_glove_visuals%.lua$')
        or src:match('[/@]motion_[^/]+%.lua$')
end
local first=loadMod({OnInclude=function(name)imports[name]=(imports[name]or 0)+1 end,
    AfterRegister=function(_,_,fn)if target(fn)then registrations=registrations+1 end end})
local modules={}
for _,part in ipairs({'init','state','freeze','input','players','weapons','damage','attribution','lifecycle'})do
    modules[#modules+1]='scripts/features/drive_glove/'..part
end
for _,part in ipairs({'piledriver_360','ultimate_720','motion_wave','dragon_punch'})do
    modules[#modules+1]='scripts/features/motion_items/'..part
end
for _,name in ipairs(modules)do assert(imports[name]==1,name..' must be loaded exactly once')end
assert(registrations>70,'fixture must execute real drive and motion bindings')
assert(#Neverbirth.MotionCombat.Specifications==4 and #Neverbirth.MotionItems.registered==4)
for _,spec in ipairs(Neverbirth.MotionCombat.Specifications)do
    local binding=Neverbirth.MotionInput.bindings['motion_item:'..spec.key]
    assert(binding and binding.profile==spec.profile and binding.anyDirection==spec.anyDirection)
    assert(spec.combat.normal and binding.collectibleId==first.itemIds[spec.field])
end
local previous=Neverbirth
local function failure(options,marker)
    local mod,callbacks
    options.OnModCreated=function(m,c)mod,callbacks=m,c end
    local ok,err=pcall(loadMod,options)
    assert(not ok and tostring(err):find(marker,1,true),tostring(err))
    assert(Neverbirth==previous,'global entry export must survive failed replacement')
    for _,rows in pairs(callbacks)do assert(#rows==0,'failed installation leaves callbacks')end
    for _,name in ipairs({'DriveGlove','MotionInput','MotionPresentation','MotionCombat','MotionSAHUD','MotionItems'})do
        assert(mod[name]==nil,'failed installation publishes '..name)
    end
end
for _,name in ipairs(modules)do
    failure({OnInclude=function(path)if path==name then error('batch21 missing '..name)end end},'batch21 missing')
end
for failAt=1,registrations do
    local count=0
    failure({AfterRegister=function(_,_,fn)
        if target(fn)then count=count+1;if count==failAt then error('batch21 registration failure')end end
    end},'batch21 registration failure')
end
loadMod()
assert(Neverbirth.DriveGlove and #Neverbirth.MotionItems.registered==4)
print('batch21 loading: 13 imports once, four live owners, '..registrations..' callback rollback stages, fresh bootstrap passed')
