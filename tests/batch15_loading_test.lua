local load = dofile('tests/support/neverbirth_fixture.lua')
local groups = {
    yins_curse = { api = 'YinsCurseTestAPI', parts = {'state','queries','pedestals','acquisition','runtime'}, count = 9 },
    ring_of_the_seven_curses = { api = 'RingOfSevenCursesTestAPI', parts = {'state','inventory','world','rewards','runtime'}, count = 15 },
    ace_anti_cheat_system = { api = 'ACEAntiCheatTestAPI', parts = {'state','queries','audit','combat','runtime'}, count = 11 },
}
local function enableExplosionApi()
    ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY = 1485
    ModCallbacks.MC_POST_CURSE_EVAL = 1486
    ModCallbacks.MC_POST_GET_COLLECTIBLE = 1487
    Isaac.GetPlayerExplosionImmunityAPIVersion = function() return 1 end
end
local imports, records = {}, {}
local env = load({ OnModCreated = enableExplosionApi,
    OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end,
    AfterRegister = function(_, _, fn) records[#records + 1] = fn end,
})
for group, spec in pairs(groups) do
    for _, part in ipairs(spec.parts) do
        assert(imports['scripts.features.' .. group .. '.' .. part] == 1, group .. '/' .. part)
    end
    local count = 0
    for _, fn in ipairs(records) do
        if debug.getinfo(fn, 'S').source:find('/' .. group .. '/', 1, true) then count = count + 1 end
    end
    assert(count == spec.count, group .. ' callback count: ' .. count)
    for name, fn in pairs(Neverbirth[spec.api].Callbacks) do
        local occurrences = 0
        for _, registered in ipairs(records) do if registered == fn then occurrences = occurrences + 1 end end
        assert(occurrences == 1, group .. '/' .. name .. ' function identity')
    end
    for failAt = 1, spec.count do
        local previous, mod, callbacks, seen = Neverbirth, nil, nil, 0
        local ok, err = pcall(load, {
            OnModCreated = function(m, c) mod, callbacks = m, c; enableExplosionApi() end,
            AfterRegister = function(_, _, fn)
                if debug.getinfo(fn, 'S').source:find('/' .. group .. '/', 1, true) then
                    seen = seen + 1
                    if seen == failAt then error('batch15 registration failure') end
                end
            end,
        })
        assert(not ok and tostring(err):find('batch15 registration failure', 1, true))
        assert(Neverbirth == previous and mod[spec.api] == nil, 'failed installation exports')
        for _, rows in pairs(callbacks) do assert(#rows == 0, 'failed installation callback leak') end
    end
    for _, part in ipairs(spec.parts) do
        local previous = Neverbirth
        local target = 'scripts.features.' .. group .. '.' .. part
        local ok, err = pcall(load, {OnInclude = function(name)
            if name == target then error('batch15 missing ' .. target) end
        end})
        assert(not ok and tostring(err):find('batch15 missing ' .. target, 1, true))
        assert(Neverbirth == previous, 'missing module replaces previous instance')
    end
end
load()
print('batch15 loading: 15 modules once, 35 registration rollback stages, 15 missing-module failures, fresh load passed')
