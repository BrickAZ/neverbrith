local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"), path .. " should exist")
    local text = file:read("*a")
    file:close()
    return text
end

local function newNpc(options)
    options = options or {}
    local npc = {
        Type = options.type or 10,
        Variant = options.variant or 0,
        SubType = options.subType or 0,
        HitPoints = options.hitPoints or 10,
        MaxHitPoints = options.maxHitPoints or 10,
        GroupIdx = options.groupIdx or 0,
        ParentNPC = options.parentNpc,
        ChildNPC = options.childNpc,
        SpawnerEntity = options.spawnerEntity,
        _data = {},
        _boss = options.boss == true,
        _bossId = options.bossId or 0,
        _enemy = options.enemy ~= false,
        _vulnerable = options.vulnerable ~= false,
        _active = options.active ~= false,
        _flags = options.flags or {},
        _exists = true,
        _dead = false,
    }

    function npc:ToNPC() return self end
    function npc:GetData() return self._data end
    function npc:IsBoss() return self._boss end
    function npc:GetBossID() return self._bossId end
    function npc:IsEnemy() return self._enemy end
    function npc:IsVulnerableEnemy() return self._vulnerable end
    function npc:IsActiveEnemy() return self._active end
    function npc:HasEntityFlags(flag) return self._flags[flag] == true end
    function npc:Exists() return self._exists end
    function npc:IsDead() return self._dead end
    function npc:HasMortalDamage() return self._dead or self.HitPoints <= 0 end
    return npc
end

local xml = readFile("content/items.xml")
local xmlEn = readFile("content/items.en_us.xml")
local xmlZh = readFile("content/items.zh_cn.xml")
local pools = readFile("content/itempools.xml")
local source = readFile("main.lua")

assertTruthy(xml:find('<passive name="ACE Anti%-Cheat System"[^>]-id="46"[^>]-quality="0"'), "default XML should register ACE as local ID 46 quality 0")
assertTruthy(xmlEn:find('<passive name="ACE Anti%-Cheat System"[^>]-id="46"[^>]-quality="0"'), "English XML should register ACE")
assertTruthy(xmlZh:find('<passive name="ACE 反作弊系统"[^>]-id="46"[^>]-quality="0"'), "Chinese XML should register ACE")
assertTruthy(xml:find('gfx="ace_anti_cheat_blue.png"', 1, true), "ACE should use the approved blue icon")
assertTruthy(xmlEn:find('gfx="ace_anti_cheat_blue.png"', 1, true), "English ACE should use the approved blue icon")
assertTruthy(xmlZh:find('gfx="ace_anti_cheat_blue.png"', 1, true), "Chinese ACE should use the approved blue icon")
assertTruthy(xml:find('description="Built on 20%+ years of experience"'), "default subtitle should be registered")
assertTruthy(xmlZh:find('description="基于20%+年的经验沉淀"'), "Chinese subtitle should be registered")
assertEquals(pools:find("ACE Anti-Cheat System", 1, true), nil, "ACE must not be in any item pool yet")

local block = source:match("%-%- ACE_ANTI_CHEAT_SYSTEM_BEGIN(.-)%-%- ACE_ANTI_CHEAT_SYSTEM_END")
assertTruthy(block, "main.lua should contain an isolated ACE runtime block")
assertTruthy(block:find("ACEAntiCheatTestAPI", 1, true), "ACE should expose deterministic behavior helpers")
assertTruthy(block:find("MC_ENTITY_TAKE_DMG", 1, true), "ACE should listen for player and NPC damage")
assertTruthy(block:find("MC_POST_NPC_INIT", 1, true), "ACE should monitor newly spawned NPCs")
assertTruthy(block:find("MC_POST_NPC_DEATH", 1, true), "ACE should settle eligible NPC deaths")
assertTruthy(block:find("MC_POST_ENTITY_KILL", 1, true), "ACE should deduplicate the fallback kill callback")
assertTruthy(block:find("MC_POST_NEW_ROOM", 1, true), "ACE should reset room-owned state")
assertTruthy(block:find("MC_POST_NEW_LEVEL", 1, true), "ACE should reset floor-owned state")
assertTruthy(block:find("MC_PRE_GAME_EXIT", 1, true), "ACE should reset run state on exit")
assertTruthy(block:find(":TakeDamage", 1, true), "ordinary Repentance fallback should replace the original hit with one guarded doubled hit")
assertEquals(block:find("os.execute", 1, true), nil, "ACE must not invoke external programs")
assertEquals(block:find("while true", 1, true), nil, "ACE must not use a busy loop")
assertTruthy(block:find("AUDIT_FRAME_BUDGET_MS", 1, true), "ACE should centrally define its bounded per-frame workload budget")
assertTruthy(block:find("AUDIT_MAX_SPIN_ITERATIONS", 1, true), "ACE workload must have a secondary iteration guard")
assertTruthy(block:find("runAuditWorkload", 1, true), "ACE should expose a bounded main-thread workload during the audit")
assertEquals(block:find("error(FATAL_MESSAGE", 1, true), nil, "ACE must not disable the mod with a Lua error")
assertTruthy(block:find("SetBrokenWatchState", 1, true), "ACE should use the native room-wide slowdown for its severe audit state")
assertTruthy(block:find(':Kill()', 1, true), "the room's third one-hit kill should force every player to die")
assertEquals(block:find("FindByType", 1, true), nil, "ACE must not scan all entities every frame")

dofile("tests/localization_test.lua")

local api = assert(Neverbirth and Neverbirth.ACEAntiCheatTestAPI, "ACE runtime API should load through main.lua")
local runtime = assert(api.Runtime, "ACE runtime state should be exposed")

assertEquals(api.Capabilities.sameHitDamageRewrite, false, "ordinary Repentance cannot rewrite the amount of the same damage event")
assertEquals(api.Capabilities.guardedDamageReplacement, true, "ordinary Repentance fallback should cancel and replace the hit with doubled damage")
assertEquals(api.Capabilities.targetFps, false, "ordinary Repentance has no verified target-FPS API")
assertEquals(api.Capabilities.safeRoomSlowdown, true, "the supported room-wide slowdown fallback should be enabled")
assertEquals(api.Capabilities.boundedFrameThrottle, true, "ACE should deliberately block each audit update within a strict time and iteration budget")
assertEquals(api.Capabilities.fatalProcessExit, false, "ordinary Repentance has no verified safe process-crash API")
assertEquals(api.Capabilities.fatalLuaError, false, "ACE must not disable the mod with a Lua callback error")
assertEquals(api.Capabilities.fatalTeamKill, true, "the supported fatal audit should kill the whole team")
assertEquals(api.FatalMessage, "ACE Anti-Cheat: suspicious combat behavior detected.", "fatal audit text should stay fixed")

local playerTakeDamageCalls = 0
local replacementArgs = nil
local reentryResult = "unset"
local player = {
    InitSeed = 12345,
    ToPlayer = function(self) return self end,
    GetCollectibleNum = function(_, itemId) return itemId == api.ItemId and 1 or 0 end,
    TakeDamage = function(self, amount, flags, source, countdown)
        playerTakeDamageCalls = playerTakeDamageCalls + 1
        replacementArgs = { amount, flags, source, countdown }
        reentryResult = api.Callbacks.PlayerDamage(nil, self, amount, flags, source, countdown)
    end,
}
local sourceRef = { Entity = {} }
assertEquals(api.Callbacks.PlayerDamage(nil, player, 0.5, 17, sourceRef, 23), false, "eligible original damage should be cancelled after the doubled replacement succeeds")
assertEquals(playerTakeDamageCalls, 1, "player damage fallback should apply exactly one replacement damage event")
assertEquals(replacementArgs[1], 1, "half-heart damage should become one heart of damage")
assertEquals(replacementArgs[2], 17, "replacement damage should preserve flags")
assertEquals(replacementArgs[3], sourceRef, "replacement damage should preserve the source reference")
assertEquals(replacementArgs[4], 23, "replacement damage should preserve the countdown")
assertEquals(reentryResult, nil, "owned replacement damage must pass through without recursive doubling")

local secondPlayerCalls = 0
local secondPlayer = {
    InitSeed = 67890,
    ToPlayer = function(self) return self end,
    GetCollectibleNum = function(_, itemId) return itemId == api.ItemId and 1 or 0 end,
    TakeDamage = function() secondPlayerCalls = secondPlayerCalls + 1 end,
}
player.TakeDamage = function(self, amount, flags, source, countdown)
    playerTakeDamageCalls = playerTakeDamageCalls + 1
    assertEquals(api.Callbacks.PlayerDamage(nil, secondPlayer, 1, flags, source, countdown), false, "another co-op player should have an independent replacement guard")
end
assertEquals(api.Callbacks.PlayerDamage(nil, player, 1, 0, sourceRef, 0), false, "first co-op player's original hit should still be replaced")
assertEquals(secondPlayerCalls, 1, "nested co-op damage should be doubled independently")

local noAcePlayer = {
    InitSeed = 24680,
    ToPlayer = function(self) return self end,
    GetCollectibleNum = function() return 0 end,
    TakeDamage = function() error("non-holder must not receive replacement damage") end,
}
assertEquals(api.Callbacks.PlayerDamage(nil, noAcePlayer, 1, 0, sourceRef, 0), nil, "non-holder damage should remain untouched")
assertEquals(api.Callbacks.PlayerDamage(nil, player, 0, 0, sourceRef, 0), nil, "zero damage should remain untouched")

local normal = newNpc()
local summon = newNpc({ spawnerEntity = {} })
local splitChild = newNpc({ spawnerEntity = {} })
local boss = newNpc({ boss = true })
local miniBoss = newNpc({ bossId = 9 })
local invulnerable = newNpc({ vulnerable = false })
local decoration = newNpc({ active = false })
local segmentedMain = newNpc({ childNpc = {} })
local turretFlags = {}
if EntityFlag and EntityFlag.FLAG_NO_KNOCKBACK then turretFlags[EntityFlag.FLAG_NO_KNOCKBACK] = true end
local fixedTurret = newNpc({ flags = turretFlags })

assertEquals(api.IsEligibleNpc(normal), true, "ordinary enemy should be monitored")
assertEquals(api.IsEligibleNpc(summon), true, "summoned ordinary enemy should be monitored")
assertEquals(api.IsEligibleNpc(splitChild), true, "ordinary split child should be monitored")
assertEquals(api.IsEligibleNpc(boss), false, "boss should be excluded")
assertEquals(api.IsEligibleNpc(miniBoss), false, "mini-boss should be excluded")
assertEquals(api.IsEligibleNpc(invulnerable), false, "invulnerable entity should be excluded")
assertEquals(api.IsEligibleNpc(decoration), false, "inactive decoration should be excluded")
assertEquals(api.IsEligibleNpc(segmentedMain), false, "segmented main body should be excluded")
if EntityFlag and EntityFlag.FLAG_NO_KNOCKBACK then
    assertEquals(api.IsEligibleNpc(fixedTurret), false, "fixed turret should be excluded")
end

local brokenWatchState = 2
local brokenWatchWrites = {}
local auditRoom = {
    GetBrokenWatchState = function()
        return brokenWatchState
    end,
    SetBrokenWatchState = function(_, state)
        brokenWatchState = state
        brokenWatchWrites[#brokenWatchWrites + 1] = state
    end,
}
local auditPlayers = {
    {
        InitSeed = 901,
        _kills = 0,
        ToPlayer = function(self) return self end,
        Kill = function(self) self._kills = self._kills + 1 end,
    },
    {
        InitSeed = 902,
        _kills = 0,
        ToPlayer = function(self) return self end,
        Kill = function(self) self._kills = self._kills + 1 end,
    },
}
Game = function()
    return {
        GetRoom = function() return auditRoom end,
        GetNumPlayers = function() return #auditPlayers end,
        AddPixelation = function() end,
        Darken = function() end,
    }
end
Isaac.GetPlayer = function(index)
    return auditPlayers[index + 1]
end

api.ResetAll()
runtime.active = true
api.MonitorNpc(normal)
assertEquals(api.Callbacks.NpcDamage(nil, normal, 0, 0, nil, 0), nil, "zero damage should be ignored")
api.SettlePendingForEntity(normal)
assertEquals(normal._data.NeverbirthACEDamageEvents, 0, "zero damage should not count")

api.Callbacks.NpcDamage(nil, normal, 3, 0, nil, 0)
normal.HitPoints = 7
api.SettlePendingForEntity(normal)
assertEquals(normal._data.NeverbirthACEDamageEvents, 1, "accepted non-zero damage should count once")

api.HandleNpcDeath(normal, 1000)
assertEquals(runtime.lockUntilMs, 6000, "one-hit death should start a five-second audit window")
assertEquals(runtime.roomOneHitKills, 1, "one-hit death should increment the current room's one-hit counter")
assertEquals(brokenWatchState, 1, "one-hit death should immediately apply the native room-wide slowdown")

local fakeNow = 1000
local function advancingClock()
    fakeNow = fakeNow + 25
    return fakeNow
end
local workloadIterations = api.RunAuditWorkload(advancingClock, 300, 1000)
assertTruthy(workloadIterations > 0, "active audit should execute deliberate main-thread work")
assertTruthy(workloadIterations <= 1000, "workload should stay under its explicit iteration guard")
assertEquals(runtime.workloadCalls, 1, "workload call count should record one bounded frame stall")

runtime.lockUntilMs = 6000
local guardedIterations = api.RunAuditWorkload(function() return 1000 end, 300, 7)
assertEquals(guardedIterations, 7, "a stalled clock must still exit through the maximum iteration guard")
assertEquals(runtime.workloadCalls, 2, "guarded workload should still be recorded once")

local second = newNpc()
api.MonitorNpc(second)
api.Callbacks.NpcDamage(nil, second, 10, 0, nil, 0)
second.HitPoints = 0
second._dead = true
api.SettlePendingForEntity(second)
api.HandleNpcDeath(second, 2000)
assertEquals(runtime.lockUntilMs, 7000, "another one-hit death should refresh, not stack, the five-second window")
assertEquals(runtime.roomOneHitKills, 2, "the second one-hit death in the room should increment the shared counter")
api.UpdateAuditState(7000)
assertEquals(runtime.lockUntilMs, 0, "real-time expiry should clear the audit window")
assertEquals(brokenWatchState, 2, "audit expiry should restore the room's previous Broken Watch state")

api.ResetAll()
runtime.active = true
for index = 1, 3 do
    local enemy = newNpc()
    api.MonitorNpc(enemy)
    enemy._data.NeverbirthACEDamageEvents = 1
    local ok, result = pcall(api.HandleNpcDeath, enemy, 1000 + index)
    assertEquals(ok, true, "one-hit kill settlement must not raise a Lua error")
    assertEquals(result, true, "each accepted one-hit death should settle once")
end
assertEquals(runtime.fatalTriggered, true, "the third one-hit kill in the same room should trigger the fatal audit once")
assertEquals(runtime.lastFatalMessage, api.FatalMessage, "fatal audit should record the fixed error text")
assertEquals(auditPlayers[1]._kills, 1, "the third one-hit kill should kill player one exactly once")
assertEquals(auditPlayers[2]._kills, 1, "the third one-hit kill should kill player two exactly once")
assertEquals(runtime.lockUntilMs, 0, "fatal team death should cancel the slowdown timer")
assertEquals(brokenWatchState, 2, "fatal team death should restore the previous room slowdown state")
local oneHitCountAfterFatal = runtime.roomOneHitKills
local sixth = newNpc()
api.MonitorNpc(sixth)
sixth._data.NeverbirthACEDamageEvents = 1
assertEquals(pcall(api.HandleNpcDeath, sixth, 2000), true, "fatal audit guard should prevent repeated team death")
assertEquals(runtime.roomOneHitKills, oneHitCountAfterFatal, "fatal audit guard should prevent repeated settlement and log spam")
assertEquals(auditPlayers[1]._kills, 1, "fatal audit guard should not kill player one twice")
assertEquals(auditPlayers[2]._kills, 1, "fatal audit guard should not kill player two twice")

api.ResetAll()
runtime.active = true
for index = 1, 4 do
    local enemy = newNpc()
    api.MonitorNpc(enemy)
    enemy._data.NeverbirthACEDamageEvents = 2
    api.HandleNpcDeath(enemy, index)
end
assertEquals(runtime.fatalTriggered, false, "multi-hit deaths must not count toward the one-hit room threshold")
assertEquals(runtime.roomOneHitKills, 0, "multi-hit deaths must leave the one-hit room counter unchanged")

for index = 1, 2 do
    local enemy = newNpc()
    api.MonitorNpc(enemy)
    enemy._data.NeverbirthACEDamageEvents = 1
    assertEquals(pcall(api.HandleNpcDeath, enemy, 100 + index), true, "two one-hit kills before leaving should remain below threshold")
end
assertEquals(runtime.roomOneHitKills, 2, "room counter should retain one-hit kills until room exit")
api.ResetRoomState()
assertEquals(runtime.roomOneHitKills, 0, "entering another room must clear the room-owned one-hit counter")
local nextRoomEnemy = newNpc()
api.MonitorNpc(nextRoomEnemy)
nextRoomEnemy._data.NeverbirthACEDamageEvents = 1
assertEquals(pcall(api.HandleNpcDeath, nextRoomEnemy, 200), true, "the first one-hit kill in the next room must not inherit the previous room count")
assertEquals(runtime.fatalTriggered, false, "room transition must prevent cross-room fatal audits")
assertEquals(runtime.roomOneHitKills, 1, "the new room should start its own one-hit counter")

api.Deactivate()
assertEquals(runtime.active, false, "item removal should stop new audits")
assertEquals(runtime.lockUntilMs, 0, "item removal should cancel the active severe-slowdown audit")
assertEquals(brokenWatchState, 2, "item removal should restore the room's previous Broken Watch state")
assertEquals(runtime.roomOneHitKills, 0, "item removal should clear the room one-hit counter")

print("ACE anti-cheat behavior test passed")
