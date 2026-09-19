-- Runs the actual installed 1.0.12a Lua dispatcher, not a simulated HP pipeline.
local sourcePath = arg[1] or "E:/Isaac - Repentance/resources/scripts/main_ex.lua"
local file = assert(io.open(sourcePath, "r"))
local source = file:read("*a")
file:close()
assert(source:find('["Version"] = "1.0.12a"', 1, true), "dispatcher evidence must match selected 1.0.12a")
local first = assert(source:find("function _RunEntityTakeDmgCallback(", 1, true))
local last = assert(source:find("-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH", first, true))
local dispatchSource = source:sub(first, last - 1)
local handlers = {}
local env = setmetatable({
    GetCallbackIterator = function()
        local index = 0
        return function() index = index + 1; return handlers[index] end
    end,
    RunCallbackInternal = function(_, callback, ...)
        return callback(nil, ...)
    end,
}, { __index = _G })
assert(load(dispatchSource, "@installed-1.0.12a-damage-dispatch", "t", env))()

dofile("tests/localization_test.lua")
local ace = assert(Neverbirth.ACEAntiCheatTestAPI)
local player = {
    InitSeed = 777,
    ToPlayer = function(self) return self end,
    GetCollectibleNum = function(_, id) return id == ace.ItemId and 1 or 0 end,
    TakeDamage = function() error("no replacement damage event allowed") end,
}
local saveRoot = { ringOfSevenCurses = {
    runSeed = "chain", players = { ["777"] = { active = true } },
} }
local ringMod = { AddCallback = function() end, AddPriorityCallback = function() end }
dofile("ring_of_the_seven_curses.lua")(ringMod, {
    ItemId = 9999,
    GetSaveRoot = function() return saveRoot end,
    GetCurrentRunSeed = function() return "chain" end,
})
local ring = ringMod.RingOfSevenCursesTestAPI.Callbacks.EntityTakeDamage
local sourceRef = { Entity = player }
local downstreamCalls = 0
local function downstream(_, entity, damage, flags, sourceValue, countdown)
    downstreamCalls = downstreamCalls + 1
    assert(entity == player and damage == 8, "two independent modifiers must propagate x4")
    assert(flags == 17 and sourceValue == sourceRef and countdown == 23, "unchanged fields must propagate")
end
local function dispatch()
    return env._RunEntityTakeDmgCallback(11, 1, player, 2, 17, sourceRef, 23)
end
for _, pair in ipairs({ { ace.Callbacks.PlayerDamage, ring }, { ring, ace.Callbacks.PlayerDamage } }) do
    handlers = { pair[1], function() return true end, pair[2], downstream }
    assert(dispatch().Damage == 8, "true must not terminate same-hit propagation")
    for cancelPosition = 1, 4 do
        local before = downstreamCalls
        handlers = { pair[1], pair[2], function() return true end, downstream }
        table.insert(handlers, cancelPosition, function() return false end)
        assert(dispatch() == false, "any false must cancel the entire chain")
        assert(downstreamCalls == before, "no downstream callback after cancellation")
    end
end
assert(downstreamCalls == 2, "one downstream observation per non-cancelled chain")
print("REPENTOGON 1.0.12a native Lua damage dispatch tests passed")
