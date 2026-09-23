-- Execute the real entrypoint: failed checks may register only the dependency guard.
local cases = {
    { label = "missing" },
    { label = "false", runtime = false },
    { label = "old base", runtime = { Real = true, Version = "1.0.12" } },
    { label = "old patch", runtime = { Real = true, Version = "1.0.11z" } },
    { label = "minimum", runtime = { Real = true, Version = "1.0.12a" }, supported = true },
    { label = "new suffix", runtime = { Real = true, Version = "1.0.12b" }, supported = true },
    { label = "new stable", runtime = { Real = true, Version = "1.1.0" }, supported = true },
    { label = "fake table", runtime = { Real = false, Version = "1.0.12a" } },
    { label = "version alone", runtime = { Version = "1.0.12a" } },
    { label = "missing damage dispatcher", runtime = { Real = true, Version = "1.0.12a" }, noDispatcher = true },
    { label = "dev", runtime = { Real = true, Version = "dev build", MeetsVersion = function() return true end } },
    { label = "unknown", runtime = { Real = true, Version = "1.0.12a-custom" } },
    { label = "leading zero", runtime = { Real = true, Version = "1.00.12a" } },
    { label = "not table", runtime = true },
}
for _, case in ipairs(cases) do
    local registrations, includes, messages = 0, 0, {}
    local env = setmetatable({ REPENTOGON = case.runtime }, { __index = _G })
    env._G = env
    env._RunEntityTakeDmgCallback = not case.noDispatcher and function() end or false
    local warningRegistrations = 0
    env.RegisterMod = function(name)
        registrations = registrations + 1
        assert(name == "neverbirth", "keep one mod registration owner")
        if case.supported then error("REGISTRATION_BOUNDARY") end
        return { dependencyWarningOnly = true }
    end
    env.include = function(name)
        includes = includes + 1
        assert(name == "repentogon_dependency_guard", "must not load gameplay on failure")
        return function(mod)
            assert(mod.dependencyWarningOnly)
            warningRegistrations = warningRegistrations + 1
        end
    end
    env.Isaac = {
        ConsoleOutput = function(message) messages[#messages + 1] = message end,
        DebugString = function() error("must prefer visible console output when available") end,
    }
    env.print = function(message) messages[#messages + 1] = message end
    for attempt = 1, 2 do
        local ok, err = pcall(assert(loadfile("main.lua", "t", env)))
        if case.supported then
            assert(not ok and tostring(err):find("REGISTRATION_BOUNDARY", 1, true), case.label .. " should reach registration")
        else
            assert(ok, case.label .. " should stop gameplay initialization cleanly: " .. tostring(err))
        end
    end
    assert(includes == (case.supported and 0 or 2), case.label .. " diagnostic-only module loading")
    assert(warningRegistrations == (case.supported and 0 or 2), case.label .. " visible warning registration")
    assert(registrations == 2, case.label .. " registration count")
    assert(env.Neverbirth == nil, "must not expose an initialized gameplay API on failure")
    assert(#messages == (case.supported and 0 or 1), case.label .. " must emit exactly one failure message")
    if not case.supported then
        assert(messages[1]:find("1.0.12a", 1, true) and messages[1]:find("停止", 1, true)
            and messages[1]:find("stopped", 1, true), "bilingual actionable dependency message")
    end
end
print("REPENTOGON bootstrap tests passed (14 cases, repeated loads)")
