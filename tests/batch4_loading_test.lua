local imports = {}
local env = dofile('tests/support/neverbirth_fixture.lua')({
    OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end,
    OnModCreated = function() ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD = 9001 end,
})
for _, name in ipairs({ 'little_leather_shoes.init', 'little_leather_shoes.rules',
    'little_leather_shoes.rewards', 'little_leather_shoes.presentation', 'little_leather_shoes.runtime_views',
    'traffic_heat', 'traffic_unboxing', 'traffic_exposure' }) do
    assert(imports['scripts.features.' .. name] == 1, name .. ' must be loaded once')
end
local api = Neverbirth.LittleLeatherShoesTestAPI
local expected = {
    GetTier = 'little_leather_shoes/rules.lua',
    ProcessTrafficInventory = 'little_leather_shoes/rewards.lua',
    Render = 'little_leather_shoes/presentation.lua', AddHeat = 'traffic_heat.lua',
    Update = 'little_leather_shoes/init.lua',
}
for name, owner in pairs(expected) do
    assert(debug.getinfo(api[name], 'S').source:gsub('\\', '/'):find('scripts/features/' .. owner, 1, true), name .. ' wrong owner')
end
local counts = {}
for event, entries in pairs(env.callbacks) do
    for _, entry in ipairs(entries) do
        local source = debug.getinfo(entry.fn, 'S').source:gsub('\\', '/')
        if source:find('scripts/features/little_leather_shoes/', 1, true) or source:find('scripts/features/traffic_heat.lua', 1, true) then
            counts[event] = (counts[event] or 0) + 1
        end
    end
end
local total = 0
for event, count in pairs(counts) do
    assert(count == 1, 'duplicate callback')
    if event ~= ModCallbacks.MC_PRE_GAME_EXIT and event ~= ModCallbacks.MC_PRE_MOD_UNLOAD then
        total = total + count
    end
end
assert(total == 11, 'traffic callback surface changed: ' .. total)
assert(counts[ModCallbacks.MC_PRE_GAME_EXIT] == 1, 'traffic exit cleanup missing')
assert(counts[ModCallbacks.MC_PRE_MOD_UNLOAD] == 1, 'traffic unload cleanup missing')
print('batch4 loading: eight modules, original eleven callbacks and two lifecycle callbacks passed')
