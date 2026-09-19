-- Real mod registrations and installed 1.0.12a PRE dispatcher.
-- Native queue / HP operations below are explicit doubles, NOT game proof.
-- --strict-player exposes still-unfixed player bookkeeping counterexamples.
local function read(path)
    local file = assert(io.open(path, "r"))
    local value = file:read("*a"); file:close(); return value
end
local function section(source, first, last)
    local start = assert(source:find(first, 1, true))
    return source:sub(start, assert(source:find(last, start, true)) - 1)
end
local function eq(actual, expected, label)
    assert(actual == expected, label .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end
local native = read("E:/Isaac - Repentance/resources/scripts/main_ex.lua")
assert(native:find('["Version"] = "1.0.12a"', 1, true), "audit is pinned to 1.0.12a")
local comparator = assert(load(section(native, "local function CallbackComparator(",
    "-- Normally if you execute") .. "\nreturn CallbackComparator"))()
local fixture = read("tests/localization_test.lua")
local loader = assert(load(fixture:sub(1, assert(fixture:find("local expectedXmlItems =", 1, true)) - 1)
    .. "\nreturn loadNeverbirthWithEID"))()
local env = loader()
local mod, registrations = Neverbirth, env.callbacks
local ace = assert(mod.ACEAntiCheatTestAPI)
local handlers = {}
local dispatchEnv = setmetatable({
    GetCallbackIterator = function()
        local i = 0
        return function() i = i + 1; return handlers[i] end
    end,
    RunCallbackInternal = function(_, record, ...)
        return record.Function(record.Mod, ...)
    end,
}, { __index = _G })
assert(load(section(native, "function _RunEntityTakeDmgCallback(",
    "-- Custom handling for MC_PRE_TRIGGER_PLAYER_DEATH"), "@installed-damage-dispatch", "t", dispatchEnv))()
local function selectedRecords(callbackId, fn)
    local found = {}
    for _, record in ipairs(registrations[callbackId] or {}) do
        if record.Function == fn then found[#found + 1] = record end
    end
    table.sort(found, comparator)
    return found
end
local function acceptedRequest(entity, amount, flags, fn, lateResult)
    handlers = selectedRecords(ModCallbacks.MC_ENTITY_TAKE_DMG, fn)
    if lateResult ~= nil then
        handlers[#handlers + 1] = {
            Mod = mod, Priority = CallbackPriority.LATE, AddOrder = 100000,
            Function = function() return lateResult end,
        }
        table.sort(handlers, comparator)
    end
    local source = { Entity = nil }
    local result = dispatchEnv._RunEntityTakeDmgCallback(
        ModCallbacks.MC_ENTITY_TAKE_DMG, entity.Type, entity, amount, flags or 0, source, 0)
    if result == false then return false end
    local finalAmount = type(result) == "table" and result.Damage or amount
    -- NPC native POST follows successful queue insertion, before HP commit.
    for _, record in ipairs(selectedRecords(ModCallbacks.MC_POST_ENTITY_TAKE_DMG, fn)) do
        record.Function(record.Mod, entity, finalAmount, flags or 0, source, 0)
    end
    return finalAmount
end
local nextSeed = 93000
local function npc(options)
    options = options or {}
    nextSeed = nextSeed + 1
    return {
        Type = 10, InitSeed = nextSeed, HitPoints = 10, MaxHitPoints = 10,
        _data = {}, _dead = false, _pending = 0,
        ToNPC = function(self) return self end,
        GetData = function(self) return self._data end,
        Exists = function() return true end,
        IsDead = function(self) return self._dead end,
        IsEnemy = function() return true end,
        IsVulnerableEnemy = function() return true end,
        IsActiveEnemy = function() return true end,
        IsBoss = function() return options.boss == true end,
        GetBossID = function() return options.miniBoss and 9 or 0 end,
        HasEntityFlags = function() return false end,
        HasMortalDamage = function(self) return self._pending >= self.HitPoints end,
    }
end
local function reset()
    ace.ResetAll(); ace.Runtime.active = true
end
local function count(entity) return entity._data.NeverbirthACEDamageEvents or 0 end
local function request(entity, amount, lateResult, flags)
    return acceptedRequest(entity, amount, flags, ace.Callbacks.NpcDamage, lateResult)
end
local function commit(entity, amount)
    entity.HitPoints = entity.HitPoints - amount
    entity._pending = 0; entity._dead = entity.HitPoints <= 0
    ace.SettlePendingForEntity(entity)
end
local tests = {}
tests[#tests + 1] = { "cancelled then valid same-frame hit", function()
    reset(); local enemy = npc(); ace.MonitorNpc(enemy)
    eq(request(enemy, 3, false), false, "late PRE cancels")
    request(enemy, 3); commit(enemy, 3)
    eq(count(enemy), 1, "cancelled request must not borrow the valid hit's HP loss")
end }
tests[#tests + 1] = { "final zero then valid hit", function()
    reset(); local enemy = npc(); ace.MonitorNpc(enemy)
    eq(request(enemy, 3, { Damage = 0 }), 0, "dispatcher propagates final zero")
    request(enemy, 3); commit(enemy, 3)
    eq(count(enemy), 1, "final zero must not borrow the valid hit's HP loss")
end }
tests[#tests + 1] = { "only one POST observer is registered", function()
    eq(#selectedRecords(ModCallbacks.MC_ENTITY_TAKE_DMG, ace.Callbacks.NpcDamage), 0, "no PRE candidate creation")
    local post = selectedRecords(ModCallbacks.MC_POST_ENTITY_TAKE_DMG, ace.Callbacks.NpcDamage)
    eq(#post, 1, "one global observer, not one per holder")
    eq(post[1].param, nil, "unfiltered observer checks ToNPC itself")
    eq(post[1].Priority, CallbackPriority.IMPORTANT, "early queue observation")
end }
tests[#tests + 1] = { "nonpositive final requests", function()
    reset(); local enemy = npc(); ace.MonitorNpc(enemy)
    request(enemy, 0); request(enemy, -1); request(enemy, 3, { Damage = -1 })
    eq(#ace.Runtime.pendingDamage, 0, "nonpositive final amounts are not candidates")
end }
tests[#tests + 1] = { "POST is not HP commit", function()
    reset(); local enemy = npc(); ace.MonitorNpc(enemy)
    request(enemy, 3)
    eq(enemy.HitPoints, 10, "no scripted damage")
    eq(count(enemy), 0, "queue insertion alone is not a confirmed hit")
    ace.SettlePendingForEntity(enemy)
    eq(count(enemy), 0, "no HP change means no confirmed hit in existing settlement")
end }
tests[#tests + 1] = { "two accepted committed hits", function()
    reset(); local enemy = npc(); ace.MonitorNpc(enemy)
    request(enemy, 2); request(enemy, 3); commit(enemy, 5)
    eq(count(enemy), 2, "both explicitly committed fixture hits count")
end }
tests[#tests + 1] = { "late monitoring and queued lethal hit", function()
    reset(); local enemy = npc(); enemy._pending = 10
    request(enemy, 10)
    eq(#ace.Runtime.pendingDamage, 1, "HasMortalDamage must not exclude queued lethal hit")
    commit(enemy, 10); eq(count(enemy), 1, "one lethal hit")
end }
tests[#tests + 1] = { "NPC fake flag is not player fake semantics", function()
    reset(); local enemy = npc(); ace.MonitorNpc(enemy)
    request(enemy, 2, nil, 0x200000); commit(enemy, 2)
    eq(count(enemy), 1, "do not apply player-only fake semantics to NPC queue")
end }
tests[#tests + 1] = { "boss exclusions unchanged", function()
    reset()
    for _, enemy in ipairs({ npc({ boss = true }), npc({ miniBoss = true }) }) do
        request(enemy, 10); commit(enemy, 10)
        eq(count(enemy), 0, "excluded target")
    end
    eq(#ace.Runtime.pendingDamage, 0, "no excluded candidates")
end }
tests[#tests + 1] = { "entity isolation and room cleanup", function()
    reset(); local first, second = npc(), npc()
    ace.MonitorNpc(first); ace.MonitorNpc(second)
    request(first, 2); request(second, 2); commit(first, 2)
    eq(count(first), 1, "first target committed"); eq(count(second), 0, "other target unchanged")
    ace.ResetRoomState()
    eq(#ace.Runtime.pendingDamage, 0, "room exit drops outstanding candidates")
    commit(second, 2); eq(count(second), 0, "old-room candidate cannot settle later")
end }
for _, killFirst in ipairs({ false, true }) do
    local order = killFirst
    tests[#tests + 1] = { order and "kill then death notification" or "death then kill notification", function()
        reset(); local enemy = npc(); ace.MonitorNpc(enemy)
        request(enemy, 10)
        enemy.HitPoints = 0; enemy._dead = true
        local death = selectedRecords(ModCallbacks.MC_POST_NPC_DEATH, ace.Callbacks.NpcDeath)
        local kill = selectedRecords(ModCallbacks.MC_POST_ENTITY_KILL, ace.Callbacks.EntityKill)
        eq(#death, 1, "one registered NPC death handler")
        eq(#kill, 1, "one registered entity kill handler")
        local first, second = order and kill[1] or death[1], order and death[1] or kill[1]
        first.Function(first.Mod, enemy)
        eq(count(enemy), 1, "first notification settles the pending lethal hit")
        eq(#ace.Runtime.pendingDamage, 0, "pending candidate removed")
        eq(ace.Runtime.roomOneHitKills, 1, "first death increments once")
        second.Function(second.Mod, enemy)
        eq(count(enemy), 1, "second notification cannot count damage again")
        eq(ace.Runtime.roomOneHitKills, 1, "second notification cannot count death again")
    end }
end
if arg and arg[1] == "--strict-player" then
    tests = {}
    local function player(item)
        nextSeed = nextSeed + 1
        return {
            Type = EntityType.ENTITY_PLAYER, InitSeed = nextSeed, Position = Vector(0, 0),
            ToPlayer = function(self) return self end,
            GetCollectibleNum = function(_, id) return id == item and 1 or 0 end,
            GetHearts = function() return 6 end, GetMaxHearts = function() return 6 end,
            GetSoulHearts = function() return 0 end, GetBlackHearts = function() return 0 end,
            GetBoneHearts = function() return 0 end,
            AddCacheFlags = function() end, EvaluateItems = function() end,
        }
    end
    local function cradleState(p)
        for index = 1, 30 do
            local name, value = debug.getupvalue(mod.HandleEmptyCradleDamage, index)
            if name == "GetEmptyCradleState" then return value(p) end
            if not name then break end
        end
        error("cradle state getter not found")
    end
    tests[#tests + 1] = { "cradle cancelled first hit must not consume floor chance", function()
        local p = player(env.itemIds.EmptyCradle)
        eq(acceptedRequest(p, 1, 0, mod.HandleEmptyCradleDamage, false), false, "late cancel")
        eq(cradleState(p).usedThisFloor, false, "cancelled first hit")
    end }
    tests[#tests + 1] = { "cradle cancelled second hit must not downgrade reward", function()
        local p = player(env.itemIds.EmptyCradle)
        acceptedRequest(p, 1, 0, mod.HandleEmptyCradleDamage)
        acceptedRequest(p, 1, 0, mod.HandleEmptyCradleDamage, false)
        eq(cradleState(p).upgraded, true, "cancelled second hit")
    end }
    tests[#tests + 1] = { "taisui cancelled red damage must not add parasite", function()
        local p = player(env.itemIds.BlackTaisui)
        local before = mod:GetBlackTaisuiParasiteValue(p)
        eq(acceptedRequest(p, 1, DamageFlag.DAMAGE_RED_HEARTS, mod.HandleBlackTaisuiDamage, false), false, "late cancel")
        eq(mod:GetBlackTaisuiParasiteValue(p), before, "cancelled red damage")
    end }
elseif arg and arg[1] == "--strict-queue" then
    tests = { { "accepted but uncommitted record must not borrow another hit's HP loss", function()
        reset(); local enemy = npc(); ace.MonitorNpc(enemy)
        request(enemy, 2); request(enemy, 3)
        -- Deliberately commit only one accepted record: reproduces the remaining
        -- observation ambiguity, not a claim to execute the native queue here.
        commit(enemy, 3)
        eq(count(enemy), 1, "one explicitly committed record, two POST candidates")
    end } }
end
local failures = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(test[2]); print((ok and "PASS: " or "FAIL: ") .. test[1])
    if not ok then failures = failures + 1; print(err) end
end
assert(failures == 0, failures .. " failed / " .. #tests .. " cases (Lua doubles, not in-game)")
print("Damage acceptance: " .. #tests .. " passed (Lua doubles, not in-game)")
