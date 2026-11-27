local loadMod = dofile('tests/support/neverbirth_fixture.lua')
local imports = {}
local env = loadMod({ OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end })
for _, name in ipairs({ 'coin_sewn_sword', 'coin_sewn_sword.rules', 'coin_sewn_sword.aiming',
    'coin_sewn_sword.input', 'coin_sewn_sword.attack', 'coin_sewn_sword.qi', 'coin_sewn_sword.presentation',
    'coin_faced_mask', 'coin_faced_mask.state', 'coin_faced_mask.settlement', 'coin_faced_mask.presentation' }) do
    assert(imports['scripts.features.' .. name] == 1, name .. ' must have one instance')
end
local owners = {
    UseCoinSewnSword = 'coin_sewn_sword/input.lua',
    UpdateCoinSewnSwordHold = 'coin_sewn_sword/input.lua',
    CoinSwordInputAction = 'coin_sewn_sword/input.lua',
    UpdateCoinSwordQi = 'coin_sewn_sword/qi.lua',
    RenderCoinSwordQiDebug = 'coin_sewn_sword/presentation.lua',
    HandleCoinFacedMaskDamage = 'coin_faced_mask/settlement.lua',
    EvaluateCoinFacedMask = 'coin_faced_mask/settlement.lua',
    RefreshCoinFacedMaskRoom = 'coin_faced_mask.lua',
}
for name, file in pairs(owners) do
    local fn, count = Neverbirth[name], 0
    assert(debug.getinfo(fn, 'S').source:gsub('\\', '/'):find('scripts/features/' .. file, 1, true), name .. ' owner')
    for _, entries in pairs(env.callbacks) do for _, record in ipairs(entries) do
        if record.fn == fn then count = count + 1 end
    end end
    assert(count == 1, name .. ' must register exactly once')
end
-- Fail after a real mutation at each separated callback phase, including late hold setup.
for _, target in ipairs({ 'UpdateCoinSwordQi', 'RenderCoinSwordQiDebug', 'UseCoinSewnSword', 'HandleCoinFacedMaskDamage' }) do
    local failedMod, callbacks
    local previous = Neverbirth
    local ok, err = pcall(loadMod, {
        OnModCreated = function(m, c) failedMod, callbacks = m, c end,
        AfterRegister = function(m, _, fn)
            if m[target] == fn then error('batch6 registration failure: ' .. target) end
        end,
    })
    assert(not ok and tostring(err):find('batch6 registration failure: ' .. target, 1, true), target)
    assert(Neverbirth == previous, 'restore prior global after ' .. target)
    for name in pairs(owners) do assert(failedMod[name] == nil, 'partial export ' .. name) end
    for event, records in pairs(callbacks) do assert(#records == 0, 'partial callback ' .. event) end
end
loadMod()
print('batch6 loading: eleven modules installed once, callback ownership, four registration failure phases and recovery passed')
