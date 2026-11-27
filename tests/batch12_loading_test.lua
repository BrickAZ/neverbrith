local load = dofile('tests/support/neverbirth_fixture.lua')
local imports = {}
local e = load({ OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end })
for _, part in ipairs({'registry','state','selection','resources','player_anm2','presentation','runtime'}) do
    assert(imports['scripts.features.everchanging.' .. part] == 1, part .. ' loaded once')
end
for name, fn in pairs(Neverbirth.EverchangingTestAPI.Callbacks) do
    assert(debug.getinfo(fn, 'S').source:find('/everchanging/runtime.lua', 1, true))
    local n = 0; for _, rows in pairs(e.callbacks) do for _, row in ipairs(rows) do if row.fn == fn then n = n + 1 end end end
    assert(n == 1, name .. ' registered once')
end
for failAt = 1, 8 do
    local previous = Neverbirth; local mod, rows; local count = 0
    local ok, err = pcall(load, {
        OnModCreated = function(m, c) mod, rows = m, c end,
        AfterRegister = function(_, _, fn)
            if debug.getinfo(fn, 'S').source:find('/everchanging/', 1, true) then
                count = count + 1; if count == failAt then error('batch12 injected registration failure') end
            end
        end,
    })
    assert(not ok and tostring(err):find('batch12 injected registration failure', 1, true))
    assert(Neverbirth == previous and mod.EverchangingTestAPI == nil)
    for _, list in pairs(rows) do assert(#list == 0, 'failed installation leaves callback') end
end
load()
print('batch12 loading: seven modules once, callback identity, eight rollback stages and fresh load passed')
