-- Complete bootstrap: all acquisition/selection owners use one actual service,
-- each feature registers once, and partial installation cannot remain active.
local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local function setupLowGrade(name)
    if name ~= 'pending_content_integration' then return end
    TrinketType = {TRINKET_GOLDEN_FLAG=32768}
    PickupVariant.PICKUP_TRINKET = 350
    ModCallbacks.MC_POST_TRIGGER_TRINKET_ADDED = 1096
    ModCallbacks.MC_POST_TRIGGER_TRINKET_REMOVED = 1097
    ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD = 5099
    for i,event in ipairs({'MC_PRE_ADD_COLLECTIBLE','MC_FAMILIAR_INIT','MC_FAMILIAR_UPDATE','MC_POST_FAMILIAR_FIRE_PROJECTILE'}) do
        ModCallbacks[event] = ModCallbacks[event] or (6000+i)
    end
    Isaac.GetTrinketIdByName = function(value) return value == 'Low Grade' and 201 or -1 end
    local variant = Isaac.GetEntityVariantByName
    Isaac.GetEntityVariantByName = function(value)
        if value == 'Echo Baby Familiar' then return 777 end
        return variant and variant(value) or -1
    end
end
local paths = {'divine_left_hand','echo_baby','blinky','low_grade','inventory_selector',
    'pending_content_integration','scripts.systems.acquisition_state',
    'scripts.features.inventory_selector.text','scripts.features.inventory_selector.entries',
    'scripts.features.divine_left_hand.notices','scripts.runtime.plain_data'}
local function target(fn)
    local src = debug.getinfo(fn,'S').source:gsub('\\','/')
    for _,name in ipairs({'divine_left_hand','echo_baby','blinky','low_grade','inventory_selector','acquisition_state'}) do
        if src:match('[/@]' .. name .. '%.lua$') then return true end
    end
    return src:find('/divine_left_hand/notices.lua',1,true) ~= nil
end
local imports, count = {}, 0
loadMod({OnInclude=function(name) setupLowGrade(name); imports[name]=(imports[name] or 0)+1 end,
    AfterRegister=function(_,_,fn) if target(fn) then count=count+1 end end})
for _,name in ipairs(paths) do
    local expected = name == 'scripts.runtime.plain_data' and 4 or 1
    assert(imports[name] == expected, name .. ' unexpected executions: ' .. tostring(imports[name]))
end
for _,name in ipairs({'PendingContentState','DivineLeftHand','EchoBaby','Blinky','LowGrade','InventorySelector'}) do
    assert(type(Neverbirth[name]) == 'table', name .. ' did not install')
end
assert(count >= 50, 'fixture did not execute all feature bindings')
local prior = Neverbirth
local function failure(options, marker)
    local mod, callbacks
    local requested = options.OnInclude
    options.OnInclude = function(name) setupLowGrade(name); if requested then requested(name) end end
    options.OnModCreated = function(m,c) mod,callbacks=m,c end
    local ok,err = pcall(loadMod,options)
    assert(not ok and tostring(err):find(marker,1,true), tostring(err))
    assert(Neverbirth == prior, 'failed installation replaced the published instance')
    for _,rows in pairs(callbacks) do assert(#rows == 0, 'partial callback remains') end
    for _,name in ipairs({'PendingContentState','DivineLeftHand','EchoBaby','Blinky','LowGrade','InventorySelector'}) do
        assert(mod[name] == nil, 'failed installation published ' .. name)
    end
end
for _,missing in ipairs(paths) do
    failure({OnInclude=function(name) if name==missing then error('batch19 missing '..missing) end end}, 'batch19 missing')
end
for failAt=1,count do
    local seen=0
    failure({AfterRegister=function(_,_,fn)
        if target(fn) then seen=seen+1; if seen==failAt then error('batch19 callback failure') end end
    end}, 'batch19 callback failure')
end
loadMod({OnInclude=setupLowGrade})
assert(Neverbirth ~= prior and Neverbirth.LowGrade)
print('batch19 loading: 11 dependency paths, four real copy consumers, '..count..' registration rollback stages and fresh install passed')
