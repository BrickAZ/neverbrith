local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local imports = {}
local env = loadMod({ OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end })
for _, name in ipairs({ 'boss_order', 'between_death_and_life', 'boxes.shared', 'boxes.angelbox', 'boxes.devilbox',
    'boxes.heart_bonuses', 'boxes.active_charge', 'boxes.reward_selection' }) do
    assert(imports['scripts.features.' .. name] == 1, name .. ' must be loaded exactly once')
end
local owners = {
    UseBossOrder = 'boss_order.lua', UpdateBossOrderEncounters = 'boss_order.lua',
    ResetBossOrderRun = 'boss_order.lua', ResetBossOrderPendingEncounters = 'boss_order.lua',
    ExitBossOrder = 'boss_order.lua', UnloadBossOrder = 'boss_order.lua',
    UseBetweenDeathAndLife = 'between_death_and_life.lua', ResetBetweenDeathLifeState = 'between_death_and_life.lua',
    UseAngelbox = 'boxes/angelbox.lua', UseDevilbox = 'boxes/devilbox.lua',
    HandleBoxHeartPickupInit = 'boxes/heart_bonuses.lua',
}
for name, file in pairs(owners) do
    local handler = assert(Neverbirth[name], 'missing public handler ' .. name)
    assert(debug.getinfo(handler, 'S').source:gsub('\\', '/'):find('scripts/features/' .. file, 1, true), name .. ' wrong owner')
    local registrations = 0
    for _, entries in pairs(env.callbacks) do
        for _, entry in ipairs(entries) do if entry.fn == handler then registrations = registrations + 1 end end
    end
    assert(registrations == 1, name .. ' registrations: ' .. registrations)
end
-- Starting resumes the instance; exiting now has its own stop-and-clear handler.
-- Both original events remain mandatory, with exactly one handler per event.
for event, handler in pairs({
    [ModCallbacks.MC_POST_GAME_STARTED] = Neverbirth.ResetBossOrderRun,
    [ModCallbacks.MC_PRE_GAME_EXIT] = Neverbirth.ExitBossOrder,
    [ModCallbacks.MC_PRE_MOD_UNLOAD] = Neverbirth.UnloadBossOrder,
}) do
    local n = 0
    for _, entry in ipairs(env.callbacks[event] or {}) do if entry.fn == handler then n = n + 1 end end
    assert(n == 1, 'Boss Order lifecycle binding missing or duplicated: ' .. event)
end
print('batch3 loading: four item owners, shared instances and callback counts passed')
