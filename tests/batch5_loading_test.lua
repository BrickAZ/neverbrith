local imports = {}
local env = dofile('tests/support/neverbirth_fixture.lua')({
    OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end,
})
for _, name in ipairs({ 'black_taisui', 'black_taisui.growth', 'black_taisui.survival',
    'black_taisui.purification', 'black_taisui.presentation', 'black_taisui.lifecycle',
    'meat_lump', 'meat_lump.ledger', 'meat_lump.presentation', 'cleansed_wavy_cap' }) do
    assert(imports['scripts.features.' .. name] == 1, name .. ' must be loaded once')
end
local owners = {
    GetBlackTaisuiStage = 'black_taisui/growth.lua', HandleBlackTaisuiDamage = 'black_taisui/survival.lua',
    FilterBlackTaisuiCurses = 'black_taisui/purification.lua',
    RenderBlackTaisuiLifeHud = 'black_taisui/presentation.lua', UpdateBlackTaisui = 'black_taisui/lifecycle.lua',
    UseCleansedWavyCap = 'cleansed_wavy_cap.lua', HandleMeatLumpDamage = 'meat_lump.lua',
}
for name, file in pairs(owners) do
    assert(debug.getinfo(Neverbirth[name], 'S').source:gsub('\\', '/'):find('scripts/features/' .. file, 1, true), name .. ' wrong owner')
end
for _, name in ipairs({ 'HandleBlackTaisuiDamage', 'RenderBlackTaisuiLifeHud', 'UpdateBlackTaisui',
    'UseCleansedWavyCap', 'HandleMeatLumpDamage', 'GrantMeatLumpOneUp' }) do
    local count = 0
    for _, entries in pairs(env.callbacks) do for _, entry in ipairs(entries) do
        if entry.fn == Neverbirth[name] then count = count + 1 end
    end end
    assert(count == 1, name .. ' registration changed: ' .. count)
end
print('batch5 loading: ten modules installed once, actual owners and unique item callbacks passed')
