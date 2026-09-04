local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

local VectorMt = {}
VectorMt.__index = VectorMt
function VectorMt.__add(left, right)
    return setmetatable({ X = left.X + right.X, Y = left.Y + right.Y }, VectorMt)
end
function VectorMt.__sub(left, right)
    return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y }, VectorMt)
end
function VectorMt.__mul(left, right)
    if type(left) == "number" then left, right = right, left end
    return setmetatable({ X = left.X * right, Y = left.Y * right }, VectorMt)
end
function VectorMt:LengthSquared() return self.X * self.X + self.Y * self.Y end
function VectorMt:Length() return math.sqrt(self:LengthSquared()) end
function VectorMt:Normalized()
    local length = self:Length()
    if length <= 0 then return Vector(0, 0) end
    return Vector(self.X / length, self.Y / length)
end

Vector = setmetatable({}, {
    __call = function(_, x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, VectorMt)
    end,
})
Vector.Zero = Vector(0, 0)

ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_NPC_UPDATE = 2,
    MC_POST_NPC_INIT = 3,
    MC_POST_NPC_DEATH = 4,
    MC_POST_ENTITY_REMOVE = 5,
    MC_PRE_SPAWN_CLEAN_AWARD = 6,
    MC_POST_NEW_ROOM = 7,
    MC_POST_NEW_LEVEL = 8,
    MC_POST_GAME_STARTED = 9,
    MC_PRE_GAME_EXIT = 10,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_NPC = 10, ENTITY_MULLIGAN = 16 }
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2 }
TearFlags = { TEAR_NORMAL = 0 }
DamageFlag = { DAMAGE_EXPLOSION = 1 }
Color = { Default = {} }

function EntityRef(entity) return { Entity = entity } end
local currentGame = nil
function Game() return currentGame end

local function makePlayer(seed, position)
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = seed,
        Position = position,
        Size = 10,
        collectibles = { [9054] = 1 },
        dead = false,
        removed = false,
    }
    function player:ToPlayer() return self end
    function player:Exists() return not self.removed end
    function player:IsDead() return self.dead end
    function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
    function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
    return player
end

local function makeNpc(options)
    options = options or {}
    local npc = {
        Type = options.type or EntityType.ENTITY_NPC,
        Variant = options.variant or 0,
        SubType = options.subtype or 0,
        InitSeed = options.seed or 1000,
        Position = options.position or Vector(200, 100),
        Velocity = Vector.Zero,
        Size = options.size or 10,
        active = options.active ~= false,
        vulnerable = options.vulnerable ~= false,
        dead = false,
        removed = false,
        flags = options.flags or 0,
        data = {},
        pathCalls = {},
    }
    npc.Pathfinder = {
        FindGridPath = function(_, targetPosition, speed, pathMarker, direct)
            npc.pathCalls[#npc.pathCalls + 1] = {
                targetPosition = targetPosition,
                speed = speed,
                pathMarker = pathMarker,
                direct = direct,
            }
        end,
    }
    function npc:ToNPC() return self end
    function npc:GetData() return self.data end
    function npc:Exists() return not self.removed end
    function npc:IsDead() return self.dead end
    function npc:IsActiveEnemy() return self.active end
    function npc:IsVulnerableEnemy() return self.vulnerable end
    function npc:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function npc:AddEntityFlags(flag) self.flags = self.flags | flag end
    function npc:AddCharmed(source, duration)
        self.charmSource = source
        self.charmDuration = duration
        self.flags = self.flags | EntityFlag.FLAG_CHARM
    end
    function npc:Remove() self.removed = true end
    return npc
end

local function makeEnvironment(options)
    options = options or {}
    local callbacks = {}
    local players = {
        makePlayer(1, Vector(100, 100)),
        makePlayer(2, Vector(300, 100)),
    }
    local roomEntities = {}
    local spawned = {}
    local explosions = {}
    local nativeExplosions = {}
    local frame = 0
    local mod = {}

    currentGame = {
        BombExplosionEffects = function(_, position, damage, tearFlags, color, source,
                radiusMultiplier, lineCheck, damageSource, damageFlags)
            nativeExplosions[#nativeExplosions + 1] = {
                position = position,
                damage = damage,
                tearFlags = tearFlags,
                color = color,
                source = source,
                radiusMultiplier = radiusMultiplier,
                lineCheck = lineCheck,
                damageSource = damageSource,
                damageFlags = damageFlags,
            }
        end,
    }

    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    local initialize = assert(dofile("kamikaze_squad.lua"))
    local moduleContext = {
        ItemId = 9054,
        GetPlayers = function() return players end,
        GetRoomEntities = function() return roomEntities end,
        GetFrameCount = function() return frame end,
        GetFreeNearPosition = function(position) return position + Vector(16, 0) end,
        SpawnMulliboom = function(position, owner)
            local unit = makeNpc({
                type = EntityType.ENTITY_MULLIGAN,
                variant = 2,
                seed = 5000 + #spawned,
                position = position,
            })
            unit.SpawnerEntity = owner
            spawned[#spawned + 1] = unit
            return unit
        end,
    }
    if not options.useNativeExplosion then
        moduleContext.TriggerExplosion = function(position, damage, radiusMultiplier, owner)
            explosions[#explosions + 1] = {
                position = position,
                damage = damage,
                radiusMultiplier = radiusMultiplier,
                owner = owner,
            }
        end
    end
    local api = initialize(mod, moduleContext)

    local function invoke(id, entity, ...)
        local result
        for _, callback in ipairs(callbacks) do
            if callback.id == id
                and (callback.param == nil
                    or callback.param == entity
                    or (type(entity) == "table" and callback.param == entity.Type))
            then
                local value = callback.fn(mod, entity, ...)
                if value ~= nil then result = value end
            end
        end
        return result
    end

    local function update(count)
        for _ = 1, count or 1 do
            frame = frame + 1
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_UPDATE then callback.fn(mod) end
            end
            for _, unit in ipairs(spawned) do
                if not unit.removed then invoke(ModCallbacks.MC_NPC_UPDATE, unit) end
            end
        end
    end

    return {
        api = api,
        players = players,
        roomEntities = roomEntities,
        spawned = spawned,
        explosions = explosions,
        nativeExplosions = nativeExplosions,
        update = update,
        npcInit = function(npc) return invoke(ModCallbacks.MC_POST_NPC_INIT, npc) end,
        npcDeath = function(npc)
            npc.dead = true
            return invoke(ModCallbacks.MC_POST_NPC_DEATH, npc)
        end,
        npcRemove = function(npc)
            npc.removed = true
            return invoke(ModCallbacks.MC_POST_ENTITY_REMOVE, npc)
        end,
        npcUpdate = function(npc) return invoke(ModCallbacks.MC_NPC_UPDATE, npc) end,
        cleanAward = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then callback.fn(mod) end
            end
        end,
        newRoom = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_NEW_ROOM then callback.fn(mod) end
            end
        end,
        newLevel = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_NEW_LEVEL then callback.fn(mod) end
            end
        end,
        gameStarted = function(isContinued)
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_GAME_STARTED then callback.fn(mod, isContinued) end
            end
        end,
    }
end

local function addEnemy(env, seed, position)
    local enemy = makeNpc({ seed = seed, position = position })
    env.roomEntities[#env.roomEntities + 1] = enemy
    env.npcInit(enemy)
    return enemy
end

local function test_spawns_every_90_frames_only_with_enemies_and_caps_each_owner_at_two()
    local env = makeEnvironment()
    env.players[2].collectibles[9054] = 0
    addEnemy(env, 1001, Vector(600, 100))
    env.update(89)
    assertEquals(#env.spawned, 0, "must not spawn before frame 90")
    env.update(1)
    assertEquals(#env.spawned, 1, "frame 90 should spawn one Mulliboom")
    env.update(90)
    assertEquals(#env.spawned, 2, "frame 180 should spawn the second Mulliboom")
    env.update(180)
    assertEquals(#env.spawned, 2, "one holder must never exceed two live units")

    env.spawned[1]:Remove()
    env.update(89)
    assertEquals(#env.spawned, 2, "cap-paused timer should restart only after a slot opens")
    env.update(1)
    assertEquals(#env.spawned, 3, "a freed slot should permit a later 90-frame spawn")
end

local function test_multiplayer_owners_have_independent_timers_caps_and_markers()
    local env = makeEnvironment()
    addEnemy(env, 1101, Vector(600, 100))
    env.update(180)
    assertEquals(#env.spawned, 4, "two holders should each reach their own cap of two")
    assertEquals(env.api.GetLiveCount(env.players[1]), 2, "player one live count")
    assertEquals(env.api.GetLiveCount(env.players[2]), 2, "player two live count")
    for _, unit in ipairs(env.spawned) do
        local data = unit:GetData()
        assertTruthy(data.NeverbirthKamikazeSquadOwned, "spawn must carry the item-owned marker")
        assertTruthy(data.NeverbirthKamikazeSquadOwner == env.players[1]
            or data.NeverbirthKamikazeSquadOwner == env.players[2], "spawn must carry its exact player owner")
    end

    env.spawned[1]:Remove()
    env.update(90)
    assertEquals(env.api.GetLiveCount(env.players[1]), 2, "only the owner with a free slot may respawn")
    assertEquals(env.api.GetLiveCount(env.players[2]), 2, "other player's cap must stay independent")
end

local function test_no_enemy_never_spawns_and_natural_mulliboom_is_untouched()
    local env = makeEnvironment()
    env.update(300)
    assertEquals(#env.spawned, 0, "empty room must not spawn squad members")

    local natural = makeNpc({ type = EntityType.ENTITY_MULLIGAN, variant = 2, seed = 1201 })
    env.roomEntities[1] = natural
    env.npcInit(natural)
    env.npcUpdate(natural)
    assertEquals(natural.flags, 0, "natural Mulliboom must not be made friendly")
    assertEquals(natural:GetData().NeverbirthKamikazeSquadOwned, nil, "natural Mulliboom must not be tagged")
    assertEquals(natural.removed, false, "natural Mulliboom must not be removed")
end

local function test_spawn_is_vanilla_friendly_and_retargets_nearest_valid_enemy()
    local env = makeEnvironment()
    env.players[2].collectibles[9054] = 0
    local far = addEnemy(env, 1301, Vector(500, 100))
    local near = addEnemy(env, 1302, Vector(220, 100))
    env.update(90)
    local unit = env.spawned[1]
    assertEquals(unit.Type, EntityType.ENTITY_MULLIGAN, "must spawn the vanilla Mulligan entity type")
    assertEquals(unit.Variant, 2, "must spawn vanilla Mulliboom variant 2")
    assertTruthy(unit:HasEntityFlags(EntityFlag.FLAG_FRIENDLY), "spawn must receive native friendly state")
    assertTruthy(unit:HasEntityFlags(EntityFlag.FLAG_CHARM), "spawn must receive permanent native charm/heart state")
    assertEquals(unit.charmSource.Entity, env.players[1], "friendly charm must be attributed to its owner")
    assertEquals(unit.Target, near, "unit should lock the nearest valid enemy")
    assertTruthy(#unit.pathCalls > 0, "unit should actively path toward its target")

    env.npcDeath(near)
    env.npcUpdate(unit)
    assertEquals(unit.Target, far, "unit must immediately retarget when the old target dies")
end

local function test_contact_and_clean_room_use_one_normal_damage_double_radius_explosion()
    local env = makeEnvironment()
    env.players[2].collectibles[9054] = 0
    local enemy = addEnemy(env, 1401, Vector(150, 100))
    env.update(90)
    local unit = env.spawned[1]
    unit.Position = Vector(140, 100)
    env.npcUpdate(unit)
    assertEquals(#env.explosions, 1, "contact must trigger exactly one scripted native explosion")
    assertEquals(env.explosions[1].damage, 40, "explosion damage must match vanilla Mulliboom damage")
    assertEquals(env.explosions[1].radiusMultiplier, 2, "explosion radius multiplier must be exactly two")
    assertEquals(env.explosions[1].owner, env.players[1], "explosion must be attributed to the holder")
    assertTruthy(unit.removed, "item-owned NPC must be removed without a second death explosion")
    env.npcUpdate(unit)
    env.npcRemove(unit)
    assertEquals(#env.explosions, 1, "the same unit must never explode twice")

    enemy.dead = false
    enemy.removed = false
    env.api.TrackEnemy(enemy)
    env.update(90)
    local remaining = env.spawned[#env.spawned]
    env.cleanAward()
    assertTruthy(remaining.removed, "clean-room unit must explode and be removed")
    assertEquals(#env.explosions, 2, "clean-room path must use the same single explosion contract")
    assertEquals(env.explosions[2].damage, 40, "clean-room damage")
    assertEquals(env.explosions[2].radiusMultiplier, 2, "clean-room radius")
end

local function test_real_bomb_explosion_path_preserves_all_native_semantic_arguments()
    local env = makeEnvironment({ useNativeExplosion = true })
    env.players[2].collectibles[9054] = 0
    addEnemy(env, 1451, Vector(150, 100))
    env.update(90)
    local unit = env.spawned[1]
    unit.Position = Vector(140, 100)
    env.npcUpdate(unit)

    assertEquals(#env.nativeExplosions, 1, "real engine path must call BombExplosionEffects exactly once")
    local call = env.nativeExplosions[1]
    assertEquals(call.damage, 40, "real engine path damage")
    assertEquals(call.tearFlags, TearFlags.TEAR_NORMAL, "real engine path tear flags")
    assertEquals(call.color, Color.Default, "real engine path color")
    assertEquals(call.source, env.players[1], "real engine path source")
    assertEquals(call.radiusMultiplier, 2, "real engine path radius multiplier")
    assertEquals(call.lineCheck, true, "real engine path line check")
    assertEquals(call.damageSource, true, "explosion must be able to hurt the holder/source")
    assertEquals(call.damageFlags, DamageFlag.DAMAGE_EXPLOSION, "native explosion immunity and shields require explosion damage semantics")
    assertTruthy(unit.removed, "native explosion path must still remove the Mulliboom before the one explosion")
end

local function test_last_enemy_death_triggers_fallback_explosion_without_clean_award()
    local env = makeEnvironment()
    env.players[2].collectibles[9054] = 0
    local enemy = addEnemy(env, 1471, Vector(500, 100))
    env.update(90)
    local unit = env.spawned[1]
    env.npcDeath(enemy)
    env.update(1)
    assertTruthy(unit.removed, "last enemy death must detonate remaining units on the ordinary update fallback")
    assertEquals(#env.explosions, 1, "fallback room-clear path must explode once")
    env.cleanAward()
    assertEquals(#env.explosions, 1, "later clean-award callback must not repeat the explosion")
end

local function test_player_death_and_item_loss_silently_clear_and_restart_full_timer()
    local deathEnv = makeEnvironment()
    deathEnv.players[2].collectibles[9054] = 0
    addEnemy(deathEnv, 1481, Vector(500, 100))
    deathEnv.update(90)
    local deathUnit = deathEnv.spawned[1]
    deathEnv.players[1].dead = true
    deathEnv.update(1)
    assertTruthy(deathUnit.removed, "player death must silently remove owned units")
    assertEquals(#deathEnv.explosions, 0, "player death cleanup must not explode")
    assertEquals(deathEnv.api.GetLiveCount(deathEnv.players[1]), 0, "player death must clear live count")
    deathEnv.players[1].dead = false
    deathEnv.update(89)
    assertEquals(#deathEnv.spawned, 1, "revived holder must restart from a full spawn interval")
    deathEnv.update(1)
    assertEquals(#deathEnv.spawned, 2, "revived holder may spawn after a fresh 90 frames")

    local lossEnv = makeEnvironment()
    lossEnv.players[2].collectibles[9054] = 0
    addEnemy(lossEnv, 1482, Vector(500, 100))
    lossEnv.update(90)
    local lossUnit = lossEnv.spawned[1]
    lossEnv.players[1].collectibles[9054] = 0
    lossEnv.update(1)
    assertTruthy(lossUnit.removed, "reroll/removal must silently remove owned units")
    assertEquals(#lossEnv.explosions, 0, "item loss cleanup must not explode")
    assertEquals(lossEnv.api.GetLiveCount(lossEnv.players[1]), 0, "item loss must clear live count")
    lossEnv.players[1].collectibles[9054] = 1
    lossEnv.update(89)
    assertEquals(#lossEnv.spawned, 1, "reacquisition must restart from a full spawn interval")
    lossEnv.update(1)
    assertEquals(#lossEnv.spawned, 2, "reacquired item may spawn after a fresh 90 frames")
end

local function test_room_and_run_lifecycle_clear_units_counts_and_timers_without_exploding()
    local env = makeEnvironment()
    env.players[2].collectibles[9054] = 0
    addEnemy(env, 1501, Vector(500, 100))
    env.update(90)
    local first = env.spawned[1]
    env.newRoom()
    assertTruthy(first.removed, "door transition must silently remove owned units")
    assertEquals(#env.explosions, 0, "door cleanup must not create a cross-room explosion")
    assertEquals(env.api.GetLiveCount(env.players[1]), 0, "door transition must clear owner counts")

    env.update(45)
    local nextEnemy = addEnemy(env, 1502, Vector(500, 100))
    env.update(44)
    assertEquals(#env.spawned, 1, "new room timer must restart from zero")
    env.update(1)
    assertEquals(#env.spawned, 2, "new room should spawn only after a fresh 90 frames")
    local second = env.spawned[2]
    env.newLevel()
    assertTruthy(second.removed, "new level must remove owned units")
    assertEquals(env.api.GetLiveCount(env.players[1]), 0, "new level must clear counts")

    nextEnemy.removed = true
    env.gameStarted(true)
    assertEquals(env.api.GetLiveCount(env.players[1]), 0, "continued game must start without stale tracked units")
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function test_registration_text_pool_icon_and_no_custom_entity_contract()
    local items = readFile("content/items.xml")
    local itemsEn = readFile("content/items.en_us.xml")
    local itemsZh = readFile("content/items.zh_cn.xml")
    local pools = readFile("content/itempools.xml")
    local poolsEn = readFile("content/itempools.en_us.xml")
    local poolsZh = readFile("content/itempools.zh_cn.xml")
    local entities = readFile("content/entities2.xml")
    local main = readFile("main.lua")

    local registration = '<passive name="Kamikaze Squad" description="For victory! Sacrifice!" gfx="KamikazeSquad.png" id="54" quality="0" tags="offensive summonable" />'
    assertTruthy(items:find(registration, 1, true), "base passive registration")
    assertTruthy(itemsEn:find(registration, 1, true), "English passive registration")
    assertTruthy(itemsZh:find('<passive name="神风特攻队" description="为胜利！献身！" gfx="KamikazeSquad.png" id="54" quality="0" tags="offensive summonable" />', 1, true), "Chinese passive registration")
    assertTruthy(pools:find('<Pool Name="treasure">', 1, true)
        and pools:find('<Item Name="Kamikaze Squad" Weight="1" DecreaseBy="1" RemoveOn="0.1"/>', 1, true), "treasure entry")
    local greedPool = pools:match('<Pool Name="greedTreasure">(.-)</Pool>')
    local greedPoolEn = poolsEn:match('<Pool Name="greedTreasure">(.-)</Pool>')
    local greedPoolZh = poolsZh:match('<Pool Name="greedTreasure">(.-)</Pool>')
    assertTruthy(greedPool and greedPool:find('<Item Name="Kamikaze Squad" Weight="1"', 1, true), "base greed treasure entry")
    assertTruthy(greedPoolEn and greedPoolEn:find('<Item Name="Kamikaze Squad" Weight="1"', 1, true), "English greed treasure entry")
    assertTruthy(greedPoolZh and greedPoolZh:find('<Item Name="神风特攻队" Weight="1"', 1, true), "Chinese greed treasure entry")
    assertEquals(entities:find("KamikazeSquad", 1, true), nil, "item must not register a custom NPC or effect")
    assertTruthy(main:find('KamikazeSquad = { "Kamikaze Squad", "神风特攻队" }', 1, true), "main item lookup")
    assertTruthy(main:find('include("kamikaze_squad")', 1, true), "main module bootstrap")
    assertTruthy(main:find('Items.KamikazeSquad, "Kamikaze Squad", "For victory! Sacrifice!", "神风特攻队", "为胜利！献身！"', 1, true), "pickup banner text")
    local icon = io.open("resources/gfx/Items/Collectibles/KamikazeSquad.png", "rb")
    assertTruthy(icon, "missing handed-off collectible icon")
    if icon then icon:close() end
end

local tests = {
    test_spawns_every_90_frames_only_with_enemies_and_caps_each_owner_at_two,
    test_multiplayer_owners_have_independent_timers_caps_and_markers,
    test_no_enemy_never_spawns_and_natural_mulliboom_is_untouched,
    test_spawn_is_vanilla_friendly_and_retargets_nearest_valid_enemy,
    test_contact_and_clean_room_use_one_normal_damage_double_radius_explosion,
    test_real_bomb_explosion_path_preserves_all_native_semantic_arguments,
    test_last_enemy_death_triggers_fallback_explosion_without_clean_award,
    test_player_death_and_item_loss_silently_clear_and_restart_full_timer,
    test_room_and_run_lifecycle_clear_units_counts_and_timers_without_exploding,
    test_registration_text_pool_icon_and_no_custom_entity_contract,
}

for _, test in ipairs(tests) do test() end
print("kamikaze_squad_behavior_test: ok")
