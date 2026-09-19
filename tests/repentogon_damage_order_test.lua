-- Real main/include registration order, installed comparator and damage dispatcher.
-- Player/engine surfaces are doubles; this is not native HP or in-game proof.
local function read(path)
    local file = assert(io.open(path, "r"))
    local value = file:read("*a"); file:close(); return value
end
local native = read("E:/Isaac - Repentance/resources/scripts/main_ex.lua")
assert(native:find('["Version"] = "1.0.12a"', 1, true))
local function section(source, first, last)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start, true)) - 1)
end
local comparator = assert(load(section(native, "local function CallbackComparator(",
    "-- Normally if you execute") .. "\nreturn CallbackComparator"))()
local enums = read("E:/Isaac - Repentance/resources/scripts/enums.lua")
assert(load(section(enums, "CallbackPriority = {", "EntityType = {")))()
assert(CallbackPriority.EARLY == -100 and CallbackPriority.DEFAULT == 0)
local fixture = read("tests/localization_test.lua")
local loader = assert(load(fixture:sub(1, assert(fixture:find("local expectedXmlItems =", 1, true)) - 1)
    .. "\nreturn loadNeverbirthWithEID"))()
local registrations = loader().callbacks
local mod = Neverbirth
local ace = assert(mod.ACEAntiCheatTestAPI)
local ring = assert(mod.RingOfSevenCursesTestAPI)
local selected = {
    [ace.Callbacks.PlayerDamage] = "ACE",
    [ring.Callbacks.EntityTakeDamage] = "ring",
    [mod.HandleMeatLumpDamage] = "meat",
    [mod.PreventMusicboxDamage] = "musicbox",
}
local registered = {}
for _, record in ipairs(registrations[ModCallbacks.MC_ENTITY_TAKE_DMG]) do
    if selected[record.fn] then registered[#registered + 1] = record end
end
assert(#registered == 4, "all four handlers must come from actual main/include registration")
-- Do not hand-place modifiers: sort captured records using the installed comparator.
table.sort(registered, comparator)
local handlers, observations = {}, {}
local dispatchEnv = setmetatable({
    GetCallbackIterator = function()
        local i = 0
        return function() i = i + 1; return handlers[i] end
    end,
    RunCallbackInternal = function(_, record, ...)
        observations[#observations + 1] = { name = selected[record.Function], amount = select(2, ...) }
        return record.Function(record.Mod, ...)
    end,
}, { __index = _G })
assert(load(section(native, "function _RunEntityTakeDmgCallback(",
    "-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH"), "@installed-damage-dispatch", "t", dispatchEnv))()
local nextSeed, replayCalls, passed, failures = 90000, 0, 0, {}
local function scenario(aceHeld, ringActive, guard, lethal)
    nextSeed = nextSeed + 1
    local mult = (aceHeld and 2 or 1) * (ringActive and 2 or 1)
    local hearts = lethal and mult or mult + 1
    local data, removed = {}, 0
    local player = {
        Type = EntityType.ENTITY_PLAYER, InitSeed = nextSeed, ControllerIndex = 0,
        Position = Vector(0, 0),
        ToPlayer = function(self) return self end,
        GetData = function() return data end,
        GetHearts = function() return hearts end,
        GetMaxHearts = function() return hearts end,
        GetSoulHearts = function() return 0 end,
        GetBoneHearts = function() return 0 end,
        HasMortalDamage = function() return false end,
        GetCollectibleNum = function(_, id) return id == ace.ItemId and aceHeld and 1 or 0 end,
        GetActiveItem = function(_, slot) return guard == "musicbox" and slot == 0 and 736 or 0 end,
        GetActiveCharge = function() return 0 end,
        AddCacheFlags = function() end,
        EvaluateItems = function() end,
        RemoveCollectible = function(_, id) assert(id == 736); removed = removed + 1 end,
        AddHearts = function(_, count) hearts = hearts + count end,
        SetMinDamageCooldown = function(_, frames) assert(frames > 0, "successful save grants native immunity") end,
        TakeDamage = function() replayCalls = replayCalls + 1; error("TakeDamage replay forbidden") end,
    }
    ring.GetSavedState().players[tostring(nextSeed)] = { active = ringActive }
    mod:AddMeatLumpLife(player, guard == "meat" and 1 or 0)
    handlers, observations = {}, {}
    for _, record in ipairs(registered) do handlers[#handlers + 1] = record end
    local downstream = 0
    local sourceRef = { Entity = player }
    handlers[#handlers + 1] = { Mod = mod, Function = function(_, entity, amount, flags, source, countdown)
        downstream = downstream + 1
        assert(entity == player and amount == mult, "downstream must see both multipliers")
        assert(flags == 0 and source == sourceRef and countdown == 23, "other damage fields unchanged")
    end }
    -- Ordinary contact is lethal-capable; numeric 17 includes native DAMAGE_NOKILL.
    local result = dispatchEnv._RunEntityTakeDmgCallback(11, 1, player, 1, 0, sourceRef, 23)
    local label = (aceHeld and "ACE" or "") .. (ringActive and "+ring" or "") .. "/" .. guard .. "/" .. tostring(lethal)
    local consumed = guard == "meat" and (1 - mod:GetMeatLumpLifeCount(player)) or removed
    if lethal then
        assert(result == false, label .. ": lethal multiplied damage must be cancelled; got " .. tostring(result))
        assert(consumed == 1 and downstream == 0, label .. ": exactly one guard consumption; false stops downstream")
    else
        assert(result.Damage == mult and consumed == 0 and downstream == 1, label .. ": nonlethal must not consume guard")
    end
    for _, observed in ipairs(observations) do
        if observed.name == guard then assert(observed.amount == mult, label .. ": guard receives multiplied amount") end
    end
end
for _, combination in ipairs({ { true, false }, { false, true }, { true, true } }) do
    for _, guard in ipairs({ "meat", "musicbox" }) do
        for _, lethal in ipairs({ true, false }) do
            local ok, err = pcall(scenario, combination[1], combination[2], guard, lethal)
            if ok then passed = passed + 1 else failures[#failures + 1] = err end
        end
    end
end
assert(replayCalls == 0, "no TakeDamage replay")
for _, failure in ipairs(failures) do print("FAIL: " .. failure) end
assert(#failures == 0, tostring(#failures) .. " damage-order cases failed; " .. passed .. " passed")
print("REPENTOGON 1.0.12a real-registration damage order: " .. passed .. " passed")
