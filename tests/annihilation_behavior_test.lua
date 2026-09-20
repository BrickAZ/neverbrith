local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

local function assertNear(actual, expected, epsilon, message)
    epsilon = epsilon or 0.000001
    if math.abs(actual - expected) > epsilon then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local VectorMt = {}
VectorMt.__index = VectorMt
function VectorMt.__sub(left, right)
    return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y }, VectorMt)
end
function VectorMt:LengthSquared() return self.X * self.X + self.Y * self.Y end
function VectorMt.__eq(left, right) return left.X == right.X and left.Y == right.Y end
Vector = setmetatable({}, {
    __call = function(_, x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, VectorMt)
    end,
})
Vector.Zero = Vector(0, 0)

ModCallbacks = {
    MC_USE_ITEM = 1,
    MC_POST_UPDATE = 2,
    MC_EVALUATE_CACHE = 3,
    MC_POST_FIRE_TEAR = 4,
    MC_POST_NPC_INIT = 5,
    MC_POST_NPC_DEATH = 6,
    MC_POST_ENTITY_KILL = 7,
    MC_POST_NEW_ROOM = 8,
    MC_POST_GAME_STARTED = 9,
    MC_PRE_GAME_EXIT = 10,
    MC_NPC_UPDATE = 11,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_NPC = 10, ENTITY_EFFECT = 1000 }
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2 }
EntityCollisionClass = { ENTCOLL_NONE = 0 }
GridCollisionClass = { COLLISION_NONE = 0 }
CacheFlag = { CACHE_FIREDELAY = 1, CACHE_RANGE = 2 }
CollectibleType = { COLLECTIBLE_CAR_BATTERY = 356 }
ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2, SLOT_POCKET2 = 3 }

local function makeSprite()
    local sprite = { loadCount = 0, playCount = 0, Rotation = 99, Scale = Vector(3, 3) }
    function sprite:Load(path)
        self.loadCount = self.loadCount + 1
        self.path = path
    end
    function sprite:Play(animation)
        self.playCount = self.playCount + 1
        self.animation = animation
    end
    return sprite
end

local function makeEffect(variant, position, spawner)
    local effect = {
        Type = EntityType.ENTITY_EFFECT,
        Variant = variant,
        Position = position,
        Velocity = Vector.Zero,
        SpawnerEntity = spawner,
        sprite = makeSprite(),
        data = {},
        removed = false,
    }
    function effect:GetSprite() return self.sprite end
    function effect:GetData() return self.data end
    function effect:Exists() return not self.removed end
    function effect:Remove() self.removed = true end
    return effect
end

local function makePlayer(seed, position)
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = seed,
        Position = position or Vector(100, 100),
        Damage = 10,
        TearRange = 100,
        MaxFireDelay = 9,
        cacheFlags = 0,
        evaluateCalls = 0,
        dead = false,
        collectibles = {},
        activeItems = {
            [ActiveSlot.SLOT_PRIMARY] = 6001,
            [ActiveSlot.SLOT_SECONDARY] = 6002,
            [ActiveSlot.SLOT_POCKET] = 6003,
        },
        activeCharges = {
            [ActiveSlot.SLOT_PRIMARY] = 0,
            [ActiveSlot.SLOT_SECONDARY] = 0,
            [ActiveSlot.SLOT_POCKET] = 0,
        },
    }
    function player:ToPlayer() return self end
    function player:Exists() return true end
    function player:IsDead() return self.dead end
    function player:AddCacheFlags(flags) self.cacheFlags = self.cacheFlags | flags end
    function player:EvaluateItems() self.evaluateCalls = self.evaluateCalls + 1 end
    function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
    function player:GetActiveItem(slot) return self.activeItems[slot] or 0 end
    function player:GetActiveCharge(slot) return self.activeCharges[slot] or 0 end
    function player:SetActiveCharge() error("manual charging is forbidden") end
    function player:AddActiveCharge(charge, slot, flashHud, overcharge, force)
        self.nativeChargeCalls = self.nativeChargeCalls or {}
        self.nativeChargeCalls[#self.nativeChargeCalls + 1] = { charge, slot, flashHud, overcharge, force }
        if self.nativeChargeError then error("native charge failure") end
        if self.nativeChargeResult ~= nil then return self.nativeChargeResult end
        local config = self.nativeConfigs[self.activeItems[slot] or 0]
        local maximum = config and config.MaxCharges or 0
        -- Match the current engine's charge-type gate before its capacity clamp.
        local chargeType = config and config.ChargeType or 0
        if charge > 0 and not force then
            if chargeType == 2 then return 0 end
            if chargeType == 1 then charge = maximum end
        end
        local added = math.max(0, math.min(charge, maximum - (self.activeCharges[slot] or 0)))
        self.activeCharges[slot] = (self.activeCharges[slot] or 0) + added
        return added
    end
    return player
end

local function makeNpc(options)
    options = options or {}
    local npc = {
        Type = EntityType.ENTITY_NPC,
        InitSeed = options.seed or 1001,
        Position = options.position or Vector(140, 100),
        Size = options.size or 10,
        flags = options.flags or 0,
        active = options.active ~= false,
        vulnerable = options.vulnerable ~= false,
        dead = false,
        removed = false,
        data = {},
        damageEvents = {},
    }
    function npc:ToNPC() return self end
    function npc:GetData() return self.data end
    function npc:Exists() return not self.removed end
    function npc:IsDead() return self.dead end
    function npc:IsActiveEnemy() return self.active end
    function npc:IsVulnerableEnemy() return self.vulnerable end
    function npc:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function npc:TakeDamage(amount, flags, source, countdown)
        self.damageEvents[#self.damageEvents + 1] = {
            amount = amount,
            flags = flags,
            source = source,
            countdown = countdown,
        }
        return true
    end
    return npc
end

local function makeTear(player)
    local tear = { SpawnerEntity = player, removed = false }
    function tear:Remove() self.removed = true end
    return tear
end

function EntityRef(entity) return { Entity = entity } end
function GetPtrHash(entity) return entity.ptr or entity.InitSeed end

local function makeEnvironment(options)
    options = options or {}
    local callbacks = {}
    local players = { makePlayer(1, Vector(100, 100)), makePlayer(2, Vector(300, 100)) }
    local effects = {}
    local roomEntities = {}
    local frame = 0
    local mod = {}
    local collectibleConfigs = {
        [6001] = { MaxCharges = 3 },
        [6002] = { MaxCharges = 5 },
        [6003] = { MaxCharges = 5 },
    }
    for _, player in ipairs(players) do player.nativeConfigs = collectibleConfigs end

    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    local initialize = assert(dofile("annihilation.lua"))
    local settings = {
        ItemId = 9053,
        Variants = { Aura = 3022, Shockwave = 3023, Activate = 3024 },
        GetPlayers = function() return players end,
        GetRoomEntities = function() return roomEntities end,
        GetFrameCount = function() return frame end,
        GetCollectibleConfig = function(itemId) return collectibleConfigs[itemId] end,
        SpawnEffect = function(variant, position, spawner)
            local effect = makeEffect(variant, position, spawner)
            effects[#effects + 1] = effect
            return effect
        end,
    }
    for key, value in pairs(options) do settings[key] = value end
    if options.NativeSpawn then settings.SpawnEffect = nil end
    local api = initialize(mod, settings)

    local function getCallbacks(id)
        local result = {}
        for _, callback in ipairs(callbacks) do
            if callback.id == id then result[#result + 1] = callback end
        end
        return result
    end

    local function invoke(id, entity, ...)
        local result = nil
        for _, callback in ipairs(getCallbacks(id)) do
            if callback.param == nil
                or callback.param == entity
                or (type(entity) == "table" and callback.param == entity.Type)
            then
                local value = callback.fn(mod, entity, ...)
                if value ~= nil then result = value end
            end
        end
        return result
    end

    return {
        api = api,
        players = players,
        effects = effects,
        roomEntities = roomEntities,
        collectibleConfigs = collectibleConfigs,
        use = function(player)
            local result
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_USE_ITEM)) do
                if callback.param == 9053 then
                    result = callback.fn(mod, 9053, nil, player, 0, 0, 0)
                end
            end
            return result
        end,
        update = function(count)
            for _ = 1, count or 1 do
                frame = frame + 1
                for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback.fn(mod) end
            end
        end,
        getFrame = function() return frame end,
        fireTear = function(tear) return invoke(ModCallbacks.MC_POST_FIRE_TEAR, tear) end,
        npcInit = function(npc) return invoke(ModCallbacks.MC_POST_NPC_INIT, npc) end,
        npcUpdate = function(npc) return invoke(ModCallbacks.MC_NPC_UPDATE, npc) end,
        npcDeath = function(npc)
            npc.dead = true
            return invoke(ModCallbacks.MC_POST_NPC_DEATH, npc)
        end,
        entityKill = function(npc) return invoke(ModCallbacks.MC_POST_ENTITY_KILL, npc) end,
        newRoom = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback.fn(mod) end
        end,
        gameStarted = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do callback.fn(mod, false) end
        end,
        preExit = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_GAME_EXIT)) do callback.fn(mod, true) end
        end,
        evaluate = function(player, cacheFlag)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
                callback.fn(mod, player, cacheFlag)
            end
        end,
    }
end

-- Native API mock proves invocation/return handling only, not engine HUD semantics.
for _, chargeType in ipairs({ 1, 2 }) do
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibles[356] = 1
    env.collectibleConfigs[6001].ChargeType = chargeType
    env.collectibleConfigs[6002].ChargeType = chargeType
    env.use(player)
    assertEquals(env.api.ChargeCarBatterySynergy(player), 2, "timed/special main and secondary accept one charge")
    assertEquals(player:GetActiveCharge(0), 1, "timed/special primary gains exactly one charge")
    assertEquals(player:GetActiveCharge(1), 1, "timed/special secondary gains exactly one charge")
    assertEquals(player:GetActiveCharge(2), 0, "timed/special charging never touches the pocket")
end
do
    local logs = {}
    local env = makeEnvironment({ DebugLog = function(message) logs[#logs + 1] = message end })
    local player = env.players[1]
    player.collectibles[356] = 1
    assertEquals(env.api.ChargeCarBatterySynergy(player), 0, "inactive owner cannot charge")
    env.use(player)
    assertEquals(env.api.ChargeCarBatterySynergy(player), 2, "native calls should charge both slots")
    assertEquals(#(player.nativeChargeCalls or {}), 2, "must use AddActiveCharge for each slot")
    for i, call in ipairs(player.nativeChargeCalls) do
        assertEquals(call[1], 1, "exactly one native charge")
        assertEquals(call[2], i - 1, "only primary and secondary")
        assertEquals(call[3], true, "flash HUD requested")
        assertEquals(call[4], false, "no forced overcharge; native extra capacity still applies")
        assertEquals(call[5], true, "fixed charge bypasses native type conversion but not the capacity clamp")
    end
    assertEquals(player:GetActiveCharge(2), 0, "pocket untouched")
    for _, value in ipairs({ 0, -1, false, "not a number" }) do
        player.nativeChargeResult = value
        assertEquals(env.api.ChargeCarBatterySynergy(player), 0, "no positive native result means no charge")
    end
    player.nativeChargeResult = 0.5
    assertEquals(env.api.ChargeCarBatterySynergy(player), 2, "positive actual amount counts")
    player.nativeChargeResult = nil
    player.activeItems[0] = 0
    player.activeCharges[1] = 5
    assertEquals(env.api.ChargeCarBatterySynergy(player), 0, "empty and full slots are delegated to native API")
    env.collectibleConfigs[6002].MaxCharges = 6
    assertEquals(env.api.ChargeCarBatterySynergy(player), 1, "dynamic native maximum is respected")
    player.activeItems[1] = 999999
    assertEquals(env.api.ChargeCarBatterySynergy(player), 0, "unknown active with zero capacity rejects charging")
    player.nativeChargeError = true
    env.api.ChargeCarBatterySynergy(player)
    env.api.ChargeCarBatterySynergy(player)
    assertEquals(#logs, 1, "native charge exception logs once")
end
do
    local logs = {}
    local env = makeEnvironment({ DebugLog = function(message) logs[#logs + 1] = message end })
    local player = env.players[1]
    player.collectibles[356] = 1
    env.use(player)
    player.AddActiveCharge = nil
    assertEquals(env.api.ChargeCarBatterySynergy(player), 0, "missing native API must not fall back")
    assertEquals(env.api.ChargeCarBatterySynergy(player), 0, "repeated missing native API remains safe")
    assertEquals(#logs, 1, "missing native API logs once")
end

local function countDamage(npc, amount)
    local count = 0
    for _, event in ipairs(npc.damageEvents) do
        if math.abs(event.amount - amount) < 0.000001 then count = count + 1 end
    end
    return count
end

local function test_activation_is_independent_and_exactly_150_frames()
    local env = makeEnvironment()
    local player = env.players[1]
    assertEquals(env.use(player), true, "first use should let the engine discharge normally")
    local state = env.api.GetState(player)
    assertTruthy(state, "activation should create a player-owned state")
    assertEquals(state.remaining, 150, "initial duration")
    assertEquals(#env.effects, 2, "activation should create one aura and one activation flash")
    assertEquals(env.effects[1].Variant, 3022, "aura variant")
    assertEquals(env.effects[1].sprite.path, "gfx/Effects/Annihilation/AnnihilationAura.anm2", "aura path")
    assertEquals(env.effects[1].sprite.animation, "AuraLoop", "aura animation")
    assertEquals(env.effects[1].sprite.loadCount, 1, "aura should load once")
    assertTruthy((env.effects[1].DepthOffset or 0) < 0, "aura should draw beneath the player")
    assertEquals(env.effects[2].sprite.animation, "Activate", "activation animation")

    local repeatResult = env.use(player)
    assertEquals(type(repeatResult), "table", "repeat use should return a no-discharge contract")
    assertEquals(repeatResult.Discharge, false, "repeat use must not spend charge")
    assertEquals(#env.effects, 2, "repeat use must not duplicate visuals")
    assertEquals(env.api.GetState(player).remaining, 150, "repeat use must not refresh or stack the timer")

    env.update(149)
    assertTruthy(env.api.GetState(player), "state should still exist through update 149")
    env.update(1)
    assertEquals(env.api.GetState(player), nil, "state should end after update 150")
    assertTruthy(env.effects[1].removed, "ending should remove the persistent aura")
end

local function test_aura_ticks_every_four_frames_with_live_damage_and_collision_radius()
    local env = makeEnvironment()
    local player = env.players[1]
    local touching = makeNpc({ position = Vector(181, 100), size = 7 })
    local outside = makeNpc({ position = Vector(183, 100), size = 7, seed = 1002 })
    env.roomEntities[1], env.roomEntities[2] = touching, outside
    env.use(player)

    env.update(3)
    assertEquals(#touching.damageEvents, 0, "aura must not tick before frame 4")
    env.update(1)
    assertEquals(countDamage(touching, 4), 1, "frame 4 should deal 40% of current damage")
    assertEquals(#outside.damageEvents, 0, "enemy collision circle outside 75 px must not be hit")
    assertEquals(touching.damageEvents[1].source.Entity, player, "aura damage should be attributed to the owner")

    player.Damage = 20
    env.update(4)
    assertEquals(countDamage(touching, 8), 1, "later ticks must read live damage")
end

local function test_enemy_deaths_extend_once_without_any_cap_and_extend_all_active_players()
    local env = makeEnvironment()
    local first, second = env.players[1], env.players[2]
    env.use(first)
    env.use(second)
    local enemy = makeNpc({ seed = 2001 })
    env.npcInit(enemy)
    env.npcDeath(enemy)
    env.entityKill(enemy)
    assertEquals(env.api.GetState(first).remaining, 159, "one death should add 9 frames to first player")
    assertEquals(env.api.GetState(second).remaining, 159, "one death should add 9 frames to second player")

    for index = 1, 100 do
        local nextEnemy = makeNpc({ seed = 2100 + index })
        env.npcInit(nextEnemy)
        env.npcDeath(nextEnemy)
    end
    assertEquals(env.api.GetState(first).remaining, 1059, "death extensions must not be capped")
    assertEquals(env.api.GetState(second).remaining, 1059, "co-op extensions must remain independent and uncapped")
end

local function test_boss_deaths_count_but_friendly_deaths_do_not()
    local env = makeEnvironment()
    local player = env.players[1]
    env.use(player)

    local boss = makeNpc({ seed = 2501 })
    boss.IsBoss = function() return true end
    env.npcInit(boss)
    env.npcDeath(boss)
    assertEquals(env.api.GetState(player).remaining, 159, "a hostile Boss death must extend the state")

    local friendly = makeNpc({ seed = 2502 })
    env.npcInit(friendly)
    friendly.flags = EntityFlag.FLAG_FRIENDLY
    env.npcDeath(friendly)
    env.entityKill(friendly)
    assertEquals(env.api.GetState(player).remaining, 159, "a friendly death must never extend the state")
end

local function test_new_room_ends_every_state_and_temporary_cache_exactly()
    local env = makeEnvironment()
    local player = env.players[1]
    env.use(player)
    env.evaluate(player, CacheFlag.CACHE_RANGE)
    env.evaluate(player, CacheFlag.CACHE_FIREDELAY)
    assertNear(player.TearRange, 45, nil, "active range should be 45%")
    assertNear(player.MaxFireDelay, (9 + 1) / 0.60 - 1, nil, "active fire frequency should be 60%")
    assertTruthy((player.cacheFlags & CacheFlag.CACHE_RANGE) ~= 0, "activation should request range cache")
    assertTruthy((player.cacheFlags & CacheFlag.CACHE_FIREDELAY) ~= 0, "activation should request fire-delay cache")

    env.newRoom()
    assertEquals(env.api.GetState(player), nil, "room transition must end the state")
    player.TearRange = 100
    player.MaxFireDelay = 9
    env.evaluate(player, CacheFlag.CACHE_RANGE)
    env.evaluate(player, CacheFlag.CACHE_FIREDELAY)
    assertEquals(player.TearRange, 100, "inactive range cache must not linger")
    assertEquals(player.MaxFireDelay, 9, "inactive fire delay must not linger")
end

local function test_tears_are_replaced_by_one_radial_wave_per_shot()
    local env = makeEnvironment()
    local player = env.players[1]
    local enemy = makeNpc({ position = Vector(200, 100), size = 10, seed = 3001 })
    env.roomEntities[1] = enemy
    env.use(player)

    local first = makeTear(player)
    local multishotSibling = makeTear(player)
    env.fireTear(first)
    env.fireTear(multishotSibling)
    assertTruthy(first.removed and multishotSibling.removed, "all base tears from the shot must be removed")
    assertEquals(#env.api.GetState(player).shockwaves, 1, "same-frame multishot callbacks should create one wave")
    local waveEffect = env.api.GetState(player).shockwaves[1].effect
    assertEquals(waveEffect.sprite.path, "gfx/Effects/Annihilation/AnnihilationShockwave.anm2", "wave path")
    assertEquals(waveEffect.sprite.animation, "Shockwave", "wave animation")

    player.Damage = 20
    env.update(8)
    assertEquals(countDamage(enemy, 20), 1, "a wave must use the owner's live damage when its wavefront hits")
    assertEquals(#env.api.GetState(player).shockwaves, 0, "finished waves should clean themselves up")

    player.Damage = 10
    local nextShot = makeTear(player)
    env.fireTear(nextShot)
    env.update(8)
    assertEquals(countDamage(enemy, 10), 1, "a later wave may hit the same enemy again with newly read damage")
end

local function test_car_battery_aura_hits_charge_primary_and_secondary_once_per_enemy()
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibles[CollectibleType.COLLECTIBLE_CAR_BATTERY] = 1
    local first = makeNpc({ position = Vector(140, 100), seed = 3501 })
    local second = makeNpc({ position = Vector(160, 100), seed = 3502 })
    env.roomEntities[1], env.roomEntities[2] = first, second
    env.use(player)

    env.update(4)
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 2, "two aura hits should add two primary charges")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_SECONDARY), 2, "two aura hits should add two secondary charges")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_POCKET), 0, "pocket active must not receive the synergy charge")

    env.update(4)
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 3, "primary charge must clamp to its item maximum")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_SECONDARY), 4, "each later aura hit should remain an independent charge event")

    player.collectibles[CollectibleType.COLLECTIBLE_CAR_BATTERY] = 0
    env.update(4)
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 3, "losing Car Battery must immediately stop primary charging")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_SECONDARY), 4, "losing Car Battery must immediately stop secondary charging")
end

local function test_car_battery_shockwave_charges_only_the_qualifying_owner()
    local env = makeEnvironment()
    local qualified, unqualified = env.players[1], env.players[2]
    qualified.collectibles[CollectibleType.COLLECTIBLE_CAR_BATTERY] = 1
    local enemy = makeNpc({ position = Vector(200, 100), size = 10, seed = 3601 })
    env.roomEntities[1] = enemy
    env.use(qualified)
    env.use(unqualified)

    env.fireTear(makeTear(qualified))
    env.fireTear(makeTear(unqualified))
    env.update(8)

    assertEquals(qualified:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 1, "one shockwave hit should add one primary charge")
    assertEquals(qualified:GetActiveCharge(ActiveSlot.SLOT_SECONDARY), 1, "one shockwave hit should add one secondary charge")
    assertEquals(unqualified:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "another active player without Car Battery must not charge")
    assertEquals(unqualified:GetActiveCharge(ActiveSlot.SLOT_SECONDARY), 0, "the synergy must remain owner-scoped in co-op")
end

local function test_inactive_players_are_not_modified_or_extended()
    local env = makeEnvironment()
    local active, inactive = env.players[1], env.players[2]
    env.use(active)
    local inactiveTear = makeTear(inactive)
    env.fireTear(inactiveTear)
    assertEquals(inactiveTear.removed, false, "another player's tear must remain untouched")

    local enemy = makeNpc({ seed = 4001 })
    env.npcInit(enemy)
    env.npcDeath(enemy)
    assertEquals(env.api.GetState(inactive), nil, "a death must not create state for inactive players")
    assertEquals(env.api.GetState(active).remaining, 159, "active player should still receive the extension")
end

local function test_late_enemy_activation_parent_owner_and_player_death_cleanup()
    local env = makeEnvironment()
    local player = env.players[1]
    local lateEnemy = makeNpc({ position = Vector(150, 100), active = false, seed = 5001 })
    env.use(player)
    env.npcInit(lateEnemy)
    lateEnemy.active = true
    env.npcUpdate(lateEnemy)
    env.update(4)
    assertEquals(countDamage(lateEnemy, 4), 1, "an enemy that becomes active after init must enter the room cache")

    local parentOnlyTear = makeTear(nil)
    parentOnlyTear.Parent = player
    env.fireTear(parentOnlyTear)
    assertTruthy(parentOnlyTear.removed, "base tears exposed through Parent must still be replaced")

    player.dead = true
    env.update(1)
    assertEquals(env.api.GetState(player), nil, "a dead player must not leave an active aura behind")
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function test_registration_and_resource_contract()
    local items = readFile("content/items.xml")
    local itemsEn = readFile("content/items.en_us.xml")
    local itemsZh = readFile("content/items.zh_cn.xml")
    local pools = readFile("content/itempools.xml")
    local poolsEn = readFile("content/itempools.en_us.xml")
    local poolsZh = readFile("content/itempools.zh_cn.xml")
    local entities = readFile("content/entities2.xml")
    local main = readFile("main.lua")

    assertTruthy(items:find('<active name="Annihilation" cache="firedelay range" maxcharges="8" description="Feel my pain!" gfx="Annihilation.png" id="53" quality="3" tags="offensive" />', 1, true), "active registration")
    assertTruthy(itemsEn:find('name="Annihilation"', 1, true), "English item name")
    assertTruthy(itemsZh:find('name="诛"', 1, true), "Chinese item name")
    assertTruthy(itemsZh:find('description="感受！我的痛苦！"', 1, true), "Chinese subtitle")
    assertTruthy(pools:find('<Item Name="Annihilation" Weight="1" DecreaseBy="1" RemoveOn="0.1"/>', 1, true), "treasure pool entry")
    assertTruthy(pools:find('<Item Name="Annihilation" Weight="0.4" DecreaseBy="1" RemoveOn="0.1"/>', 1, true), "shop pool entry")
    assertTruthy(poolsEn:find('Name="Annihilation" Weight="0.4"', 1, true), "English shop weight")
    assertTruthy(poolsZh:find('Name="诛" Weight="0.4"', 1, true), "Chinese shop weight")
    assertTruthy(entities:find('variant="3022"', 1, true) and entities:find('Effects/Annihilation/AnnihilationAura.anm2', 1, true), "aura entity registration")
    assertTruthy(entities:find('variant="3023"', 1, true) and entities:find('Effects/Annihilation/AnnihilationShockwave.anm2', 1, true), "shockwave entity registration")
    assertTruthy(entities:find('variant="3024"', 1, true) and entities:find('Effects/Annihilation/AnnihilationActivate.anm2', 1, true), "activate entity registration")
    assertTruthy(main:find('Annihilation = { "Annihilation", "诛" }', 1, true), "main item lookup")
    assertTruthy(main:find('include("annihilation")', 1, true), "main module bootstrap")
    assertTruthy(main:find('{{Collectible356}}车载电池', 1, true), "Chinese Car Battery synergy EID")
    assertTruthy(main:find('{{Collectible356}} Car Battery', 1, true), "English Car Battery synergy EID")
    for _, path in ipairs({
        "resources/gfx/Items/Collectibles/Annihilation.png",
        "resources/gfx/Effects/Annihilation/AnnihilationAura.anm2",
        "resources/gfx/Effects/Annihilation/AnnihilationShockwave.anm2",
        "resources/gfx/Effects/Annihilation/AnnihilationActivate.anm2",
    }) do
        local file = io.open(path, "rb")
        assertTruthy(file, "missing resource: " .. path)
        if file then file:close() end
    end
end

local function fresh(entity)
    return setmetatable({}, { __index = entity, __newindex = entity })
end

local function test_callable_entityref()
    local original = EntityRef
    local calls = 0
    EntityRef = setmetatable({}, { __call = function(_, entity)
        calls = calls + 1
        return { Entity = entity }
    end })
    local env = makeEnvironment()
    env.roomEntities[1] = makeNpc()
    env.use(env.players[1])
    env.update(4)
    EntityRef = original
    assertEquals(calls, 1, "callable EntityRef must execute")
end

local function test_fresh_wrapper_identity()
    local env = makeEnvironment()
    local player = env.players[1]
    player.ControllerIndex = 0
    env.players[2].ControllerIndex = 0
    env.use(player)
    local wrapper = fresh(player)
    assertEquals(env.api.GetState(wrapper), env.api.GetState(player), "fresh wrapper state")
    assertEquals(env.use(wrapper).Discharge, false, "fresh wrapper repeat use")
    env.evaluate(wrapper, CacheFlag.CACHE_RANGE)
    assertEquals(player.TearRange, 45, "fresh cache wrapper")
    local tear = makeTear(fresh(player))
    env.fireTear(tear)
    assertTruthy(tear.removed, "fresh tear owner")
    assertEquals(env.api.GetState(env.players[2]), nil, "same controller isolation")
    local npc = makeNpc({ size = 100 })
    env.npcInit(npc)
    env.npcUpdate(fresh(npc))
    env.update(2)
    assertEquals(countDamage(npc, 10), 1, "fresh NPC wave deduplication")
    env.npcDeath(fresh(npc))
    env.entityKill(fresh(npc))
    assertEquals(env.api.GetState(player).remaining, 157, "fresh death deduplication")
    env.newRoom()
    assertEquals(env.api.GetState(wrapper), nil, "fresh cleanup")
end

local function test_native_spawn_failure_and_diagnostics()
    local oldIsaac = Isaac
    local converted, effects, logs = 0, {}, {}
    Isaac = { Spawn = function(_, variant, _, position, velocity, owner)
        assertEquals(getmetatable(position), VectorMt, "native typed position")
        assertEquals(getmetatable(velocity), VectorMt, "native typed velocity")
        local effect = makeEffect(variant, position, owner)
        effects[#effects + 1] = effect
        return { ToEffect = function() converted = converted + 1; return effect end }
    end }
    local env = makeEnvironment({ NativeSpawn = true })
    env.use(env.players[1])
    assertEquals(converted, 2, "native spawn ToEffect conversion")
    env.newRoom()
    assertTruthy(effects[1].removed, "converted aura cleanup")
    Isaac.Spawn = function() error("original spawn failure") end
    env = makeEnvironment({ NativeSpawn = true, Diagnostics = true,
        DebugLog = function(message) logs[#logs + 1] = message end })
    env.roomEntities[1] = makeNpc()
    assertEquals(env.use(env.players[1]), true, "failed visuals preserve damage state")
    env.update(4)
    env.fireTear(makeTear(env.players[1]))
    env.newRoom()
    assertEquals(countDamage(env.roomEntities[1], 4), 1, "damage survives spawn failure")
    assertEquals(env.use(env.players[1]), true, "failure cannot leave stuck state")
    local text = table.concat(logs, "\n")
    for _, phase in ipairs({ "init", "use", "first-update", "first-damage", "first-shot", "end:room" }) do
        assertTruthy(text:find(phase, 1, true), "diagnostics phase " .. phase)
    end
    Isaac = oldIsaac
end

local function test_constructor_and_damage_errors_are_once_only()
    local original = EntityRef
    local logs, hits = {}, 0
    local env = makeEnvironment({ DebugLog = function(message) logs[#logs + 1] = message end })
    local player, npc = env.players[1], makeNpc()
    player.collectibles[356] = 1
    function npc:TakeDamage(_, _, source)
        assertTruthy(source and source.Entity, "native source required")
        hits = hits + 1
        if self.throws then error("original damage failure") end
        return self.result
    end
    env.roomEntities[1] = npc
    env.use(player)
    EntityRef = function() error("original constructor failure") end
    env.update(8)
    assertEquals(hits, 0, "constructor error skips damage")
    assertEquals(#logs, 1, "constructor failure logs once")
    assertTruthy(logs[1]:find("original constructor failure", 1, true), "preserves constructor error")
    EntityRef = original
    npc.result = false
    env.update(4)
    assertEquals(player:GetActiveCharge(0), 0, "cancelled damage no charge")
    npc.throws = true
    env.update(8)
    assertEquals(#logs, 2, "damage error logs once")
    assertEquals(player:GetActiveCharge(0), 0, "throwing damage no charge")
    npc.throws = false
    npc.result = true
    env.update(4)
    assertEquals(player:GetActiveCharge(0), 1, "valid damage charges primary")
    assertEquals(player:GetActiveCharge(1), 1, "valid damage charges secondary")
end

local function test_visual_setup_errors_and_foreign_tears()
    for _, failure in ipairs({ "sprite", "load", "play", "update" }) do
        local effects = {}
        local env = makeEnvironment({ SpawnEffect = function(variant, position, owner)
            local effect = makeEffect(variant, position, owner)
            effects[#effects + 1] = effect
            if failure == "sprite" then effect.GetSprite = function() error("sprite failure") end end
            if failure == "load" then effect.sprite.Load = function() return false end end
            if failure == "play" then effect.sprite.Play = function() error("play failure") end end
            return effect
        end })
        local player, npc = env.players[1], makeNpc()
        env.roomEntities[1] = npc
        env.use(player)
        if failure == "update" then
            effects[1].Position = nil
            setmetatable(effects[1], { __newindex = function(_, key) error("invalid visual write " .. key) end })
        end
        env.update(4)
        assertEquals(countDamage(npc, 4), 1, "visual errors preserve aura damage: " .. failure)
        env.newRoom()
        assertEquals(env.use(player), true, "visual errors permit reuse")
    end
    local env = makeEnvironment()
    local player = env.players[1]
    env.use(player)
    local tear = makeTear({ Type = 3, Parent = player })
    tear.Parent = player
    env.fireTear(tear)
    assertEquals(tear.removed, false, "familiar-spawned tears remain untouched")
    local missing = makePlayer(99)
    missing.InitSeed = nil
    assertEquals(env.use(missing).Discharge, false, "missing stable identity refuses activation")
    player.activeItems = {}
    env.update(4)
    assertTruthy(env.api.GetState(player), "losing active does not cancel state")
end

local function test_invalid_owner_cleanup_uses_saved_identity(boundary)
    local originalHash = GetPtrHash
        local env = makeEnvironment()
        local player = env.players[1]
        env.use(player)
        env.fireTear(makeTear(player))
        assertEquals(#env.effects, 3, "aura activation and wave are live")
        player.Exists = function() return false end
        GetPtrHash = function(entity)
            if entity == player then error("owner native handle no longer valid") end
            return originalHash(entity)
        end
        if boundary == "update" then env.update(1) else env.newRoom() end
        GetPtrHash = originalHash
        assertEquals(next(env.api.Runtime.states), nil, boundary .. " must remove invalid owner state")
        assertEquals(next(env.api.Runtime.roomNpcs), nil, boundary .. " must clear NPC collection")
        for _, effect in ipairs(env.effects) do
            assertTruthy(effect.removed, boundary .. " must remove every invalid owner visual")
        end
end

local function test_native_toeffect_failure_removes_raw_entity()
    local originalIsaac = Isaac
    for _, failure in ipairs({ "nil", "throw" }) do
        local raws = {}
        Isaac = { Spawn = function()
            local raw = { removed = false }
            function raw:Exists() return not self.removed end
            function raw:Remove() self.removed = true end
            function raw:ToEffect()
                if failure == "throw" then error("original ToEffect failure") end
                return nil
            end
            raws[#raws + 1] = raw
            return raw
        end }
        local env = makeEnvironment({ NativeSpawn = true })
        local npc = makeNpc()
        env.roomEntities[1] = npc
        assertEquals(env.use(env.players[1]), true, "failed ToEffect preserves activation")
        env.update(4)
        assertEquals(countDamage(npc, 4), 1, "failed ToEffect preserves damage")
        for _, raw in ipairs(raws) do assertTruthy(raw.removed, "failed ToEffect raw entity cleanup") end
    end
    Isaac = originalIsaac
end

local tests = {
    function() test_invalid_owner_cleanup_uses_saved_identity("update") end,
    function() test_invalid_owner_cleanup_uses_saved_identity("room") end,
    test_native_toeffect_failure_removes_raw_entity,
    test_visual_setup_errors_and_foreign_tears,
    test_native_spawn_failure_and_diagnostics,
    test_constructor_and_damage_errors_are_once_only,
    test_callable_entityref,
    test_fresh_wrapper_identity,
    test_activation_is_independent_and_exactly_150_frames,
    test_aura_ticks_every_four_frames_with_live_damage_and_collision_radius,
    test_enemy_deaths_extend_once_without_any_cap_and_extend_all_active_players,
    test_boss_deaths_count_but_friendly_deaths_do_not,
    test_new_room_ends_every_state_and_temporary_cache_exactly,
    test_tears_are_replaced_by_one_radial_wave_per_shot,
    test_car_battery_aura_hits_charge_primary_and_secondary_once_per_enemy,
    test_car_battery_shockwave_charges_only_the_qualifying_owner,
    test_inactive_players_are_not_modified_or_extended,
    test_late_enemy_activation_parent_owner_and_player_death_cleanup,
    test_registration_and_resource_contract,
}

local failures = 0
for _, test in ipairs(tests) do
    local ok, err = pcall(test)
    if not ok then failures = failures + 1; print("FAIL: " .. tostring(err)) end
end
assertEquals(failures, 0, "test failures")
print("annihilation_behavior_test: ok")
