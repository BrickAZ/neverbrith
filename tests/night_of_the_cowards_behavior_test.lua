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
function VectorMt:LengthSquared() return self.X * self.X + self.Y * self.Y end
function VectorMt.__sub(left, right)
    return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y }, VectorMt)
end
function VectorMt.__eq(left, right) return left.X == right.X and left.Y == right.Y end
Vector = setmetatable({}, {
    __call = function(_, x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, VectorMt)
    end,
})
Vector.Zero = Vector(0, 0)

ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_NPC_UPDATE = 2,
    MC_POST_EFFECT_UPDATE = 3,
    MC_INPUT_ACTION = 4,
    MC_POST_NEW_ROOM = 5,
    MC_POST_GAME_STARTED = 6,
    MC_PRE_GAME_EXIT = 7,
    MC_EVALUATE_CACHE = 8,
    MC_POST_PLAYER_RENDER = 9,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_EFFECT = 1000, ENTITY_HOST = 27 }
EffectVariant = { EFFECT_NULL = 0, HALO = 123 }
CollectibleType = { COLLECTIBLE_TRANSCENDENCE = 20 }
CacheFlag = { CACHE_FLYING = 1 }
EntityPartition = { ENEMY = 1 }
EntityCollisionClass = { ENTCOLL_NONE = 0 }
GridCollisionClass = { COLLISION_NONE = 0 }
InputHook = { IS_ACTION_PRESSED = 0, IS_ACTION_TRIGGERED = 1, GET_ACTION_VALUE = 2 }
ButtonAction = {
    ACTION_SHOOTLEFT = 4,
    ACTION_SHOOTRIGHT = 5,
    ACTION_SHOOTUP = 6,
    ACTION_SHOOTDOWN = 7,
    ACTION_LEFT = 8,
}
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2, FLAG_FEAR = 4, FLAG_RENDER_FLOOR = 8 }

local function makeSprite()
    local sprite = {
        loadCount = 0,
        playCount = 0,
        updateCount = 0,
        renderCount = 0,
        Rotation = 99,
        Scale = Vector(4, 4),
    }
    function sprite:Load(path)
        self.loadCount = self.loadCount + 1
        self.path = path
    end
    function sprite:Play(animation)
        self.playCount = self.playCount + 1
        self.animation = animation
    end
    function sprite:Update() self.updateCount = self.updateCount + 1 end
    function sprite:Render(position)
        self.renderCount = self.renderCount + 1
        self.renderPosition = position
    end
    return sprite
end

local function makeNpc(options)
    options = options or {}
    local npc = {
        Type = options.type or 10,
        Variant = options.variant or 0,
        SubType = options.subtype or 0,
        InitSeed = options.seed or 101,
        Position = options.position or Vector(100, 100),
        dead = false,
        boss = options.boss == true,
        vulnerable = options.vulnerable ~= false,
        active = options.active ~= false,
        flags = options.flags or 0,
        data = {},
        morphCalls = 0,
        champion = options.champion or -1,
    }
    function npc:ToNPC() return self end
    function npc:GetData() return self.data end
    function npc:Exists() return not self.removed end
    function npc:IsDead() return self.dead end
    function npc:IsBoss() return self.boss end
    function npc:IsVulnerableEnemy() return self.vulnerable end
    function npc:IsActiveEnemy() return self.active end
    function npc:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function npc:GetChampionColorIdx() return self.champion end
    function npc:Morph(entityType, variant, subtype, champion)
        self.morphCalls = self.morphCalls + 1
        self.Type, self.Variant, self.SubType, self.morphChampion = entityType, variant, subtype, champion
    end
    return npc
end

local function makePlayer(seed, count, position)
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = seed,
        collectibleCount = count or 0,
        Position = position or Vector(100, 100),
        data = {},
        fearCalls = 0,
        flags = 0,
        CanFly = false,
        collectibleCounts = {},
        addCollectibleCalls = {},
    }
    function player:ToPlayer() return self end
    function player:GetCollectibleNum(itemId)
        if itemId == 9001 then return self.collectibleCount end
        return self.collectibleCounts[itemId] or 0
    end
    function player:AddCollectible(itemId, charge, firstTimePickingUp)
        self.collectibleCounts[itemId] = (self.collectibleCounts[itemId] or 0) + 1
        self.addCollectibleCalls[#self.addCollectibleCalls + 1] = {
            itemId = itemId,
            charge = charge,
            firstTimePickingUp = firstTimePickingUp,
        }
    end
    function player:GetData() return self.data end
    function player:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function player:AddFear(source, duration)
        self.fearCalls = self.fearCalls + 1
        self.fearSource = source
        self.fearDuration = duration
        self.flags = self.flags | EntityFlag.FLAG_FEAR
    end
    return player
end

local function makeEnvironment()
    local callbacks = {}
    local players = { makePlayer(1, 1, Vector(100, 100)), makePlayer(2, 0, Vector(300, 300)) }
    local effects = {}
    local nearby = {}
    local luaSprites = {}
    local saveRoot = {}
    local saveCalls = 0

    local mod = {}
    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    Isaac = {
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            local effect = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                Velocity = velocity,
                SpawnerEntity = spawner,
                sprite = makeSprite(),
                data = {},
                removed = false,
            }
            function effect:GetSprite() return self.sprite end
            function effect:GetData() return self.data end
            function effect:Exists() return not self.removed end
            function effect:Remove() self.removed = true end
            function effect:AddEntityFlags(flag) self.addedFlags = (self.addedFlags or 0) | flag end
            effect.DepthOffset = 0
            setmetatable(effect, {
                __newindex = function(target, key, value)
                    if key == "Timeout" then
                        error("no member named 'Timeout'", 2)
                    end
                    rawset(target, key, value)
                end,
            })
            effects[#effects + 1] = effect
            return effect
        end,
        FindInRadius = function() return nearby end,
        WorldToScreen = function(position) return Vector(position.X, position.Y) end,
    }
    Sprite = setmetatable({}, {
        __call = function()
            local sprite = makeSprite()
            luaSprites[#luaSprites + 1] = sprite
            return sprite
        end,
    })
    function EntityRef(entity) return { Entity = entity } end

    local initialize = assert(dofile("night_of_the_cowards.lua"))
    local api = initialize(mod, {
        ItemId = 9001,
        AuraVariant = EffectVariant.HALO,
        AuraSubtype = 3,
        FlightItemId = CollectibleType.COLLECTIBLE_TRANSCENDENCE,
        GetPlayers = function() return players end,
        GetSaveRoot = function() return saveRoot end,
        GetCurrentRunSeed = function() return 12345 end,
        Save = function() saveCalls = saveCalls + 1 end,
    })

    local function getCallbacks(id)
        local found = {}
        for _, callback in ipairs(callbacks) do
            if callback.id == id then found[#found + 1] = callback end
        end
        return found
    end

    local function invoke(id, entity)
        for _, callback in ipairs(getCallbacks(id)) do
            if callback.param == nil or callback.param == entity.Variant then
                callback.fn(mod, entity)
            end
        end
    end

    return {
        api = api,
        players = players,
        effects = effects,
        luaSprites = luaSprites,
        getSaveCalls = function() return saveCalls end,
        setNearby = function(value) nearby = value end,
        update = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback.fn(mod) end
        end,
        updateNpc = function(npc) invoke(ModCallbacks.MC_NPC_UPDATE, npc) end,
        updateEffect = function(effect) invoke(ModCallbacks.MC_POST_EFFECT_UPDATE, effect) end,
        newRoom = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback.fn(mod) end
        end,
        input = function(player, hook, action)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_INPUT_ACTION)) do
                if callback.param == nil or callback.param == hook then
                    local result = callback.fn(mod, player, hook, action)
                    if result ~= nil then return result end
                end
            end
            return nil
        end,
        renderPlayer = function(player, renderOffset)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_PLAYER_RENDER)) do
                callback.fn(mod, player, renderOffset or Vector.Zero)
            end
        end,
        evaluateCache = function(player, cacheFlag)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
                if callback.param == nil or callback.param == cacheFlag then
                    callback.fn(mod, player, cacheFlag)
                end
            end
        end,
    }
end

local function test_normal_enemy_transforms_and_receives_one_cached_aura()
    local env = makeEnvironment()
    env.update()
    local enemy = makeNpc({ seed = 101 })

    env.updateNpc(enemy)
    assertEquals(enemy.Type, EntityType.ENTITY_HOST, "normal enemies should morph into Host type")
    assertTruthy(enemy.Variant == 0 or enemy.Variant == 1 or enemy.Variant == 3,
        "Host variant must be Host, Red Host, or Hard Host")
    assertEquals(enemy.morphCalls, 1, "each enemy should morph once")
    assertEquals(#env.effects, 1, "each enemy should own one aura")

    local aura = env.effects[1]
    assertEquals(aura.Variant, EffectVariant.HALO, "aura must reuse the original Halo Effect variant")
    assertEquals(aura.SubType, 3, "aura must reuse the original Curse Halo subtype")
    assertEquals(aura.sprite.loadCount, 0, "the engine-owned original Halo ANM2 must not be reloaded")
    assertEquals(aura.sprite.playCount, 0, "the engine-owned original Halo animation must start itself")
    assertEquals(aura.removed, false, "the aura must survive without a Repentogon-only FollowParent method")
    assertEquals(aura.sprite.PlaybackSpeed, 1.0, "the persistent aura must use the vanilla 1.0 playback rate")
    assertEquals((aura.addedFlags or 0) & EntityFlag.FLAG_RENDER_FLOOR, 0,
        "a moving aura must never enter the persistent floor-render layer")
    assertEquals(aura.SpriteScale, Vector(0.75, 0.75),
        "the Curse Halo must reuse the native cursed-head 75% visual footprint")
    assertEquals(aura.SpriteOffset, Vector(0, -16),
        "the Curse Halo must reuse the native cursed-head vertical anchor")
    assertTruthy(aura.DepthOffset < 0, "the attached aura must render beneath its owner by depth, not as floor paint")

    env.updateNpc(enemy)
    assertEquals(#env.effects, 1, "repeated NPC updates must reuse the cached aura")
    assertEquals(aura.removed, false, "repeated NPC updates must not delete and respawn the aura")
    assertEquals(aura.sprite.loadCount, 0, "NPC updates must never reload the original ANM2")
end

local function test_original_cursed_death_head_keeps_its_native_single_aura()
    local env = makeEnvironment()
    env.update()
    local cursedDeathHead = makeNpc({ type = 212, variant = 2, vulnerable = false })

    env.updateNpc(cursedDeathHead)
    assertEquals(cursedDeathHead.Type, 212,
        "the original Cursed Death's Head must keep its native entity identity")
    assertEquals(cursedDeathHead.Variant, 2,
        "the original Cursed Death's Head must keep its native variant")
    assertEquals(cursedDeathHead.morphCalls, 0,
        "the original Cursed Death's Head must not be replaced before its native aura renders")
    assertEquals(#env.effects, 0,
        "the original Cursed Death's Head already owns a native aura and must not receive a duplicate")

    env.setNearby({ cursedDeathHead })
    env.update()
    assertEquals(env.input(env.players[1], InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "the native Cursed Death's Head aura must still apply the shared fear gameplay state")
    assertEquals(#env.luaSprites, 1, "the native aura must still create the player's Fear feedback sprite")
end

local function test_boss_keeps_identity_but_still_gets_an_aura()
    local env = makeEnvironment()
    env.update()
    local boss = makeNpc({ boss = true, type = 20, variant = 2 })
    env.updateNpc(boss)
    assertEquals(boss.Type, 20, "bosses must not morph")
    assertEquals(boss.morphCalls, 0, "bosses must not be transformed")
    assertEquals(#env.effects, 1, "all hostile enemies, including bosses, should emit the aura")
end

local function test_aura_follows_owner_and_cleans_up_on_loss()
    local env = makeEnvironment()
    env.update()
    local enemy = makeNpc()
    env.updateNpc(enemy)
    local aura = env.effects[1]

    enemy.Position = Vector(220, 180)
    env.updateEffect(aura)
    assertEquals(aura.Position, enemy.Position, "the single non-floor aura should follow its owner without respawning")

    env.players[1].collectibleCount = 0
    env.update()
    assertTruthy(aura.removed, "losing the last team copy should remove owned auras")
end

local function test_original_fear_visual_and_shoot_input_blocking()
    local env = makeEnvironment()
    assertEquals(type(Sprite), "table",
        "the regression fixture must model an engine-callable Sprite constructor")
    env.update()
    local enemy = makeNpc({ position = Vector(100, 100) })
    env.updateNpc(enemy)
    env.setNearby({ enemy })
    env.update()

    local player = env.players[1]
    assertEquals(player.fearCalls, 0, "the unsupported Player:AddFear route must not be used")
    assertEquals(#env.luaSprites, 1, "one cached player Fear sprite should be created on entry")
    local fearSprite = env.luaSprites[1]
    assertEquals(fearSprite.path, "gfx/statuseffects.anm2", "player feedback must reuse vanilla status art")
    assertEquals(fearSprite.animation, "Fear", "player feedback must play the vanilla Fear animation")
    env.renderPlayer(player, Vector(200, -100))
    assertEquals(fearSprite.renderCount, 1, "the Fear status sprite must render while inside the aura")
    assertEquals(fearSprite.renderPosition.X, player.Position.X,
        "the Fear sprite must convert its world anchor exactly once")
    assertEquals(fearSprite.renderPosition.Y, player.Position.Y - 24,
        "the Fear sprite must use the standard-size player head anchor and ignore callback render offsets")
    env.update()
    assertEquals(fearSprite.loadCount, 1, "the player Fear sprite must be loaded only once")
    assertEquals(fearSprite.playCount, 1, "the player Fear animation must not restart every update")
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "held shoot input should be blocked")
    assertEquals(env.input(player, InputHook.IS_ACTION_TRIGGERED, ButtonAction.ACTION_SHOOTRIGHT), false,
        "triggered shoot input should be blocked")
    assertEquals(env.input(player, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTUP), 0,
        "analog shoot value should be zeroed")
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_LEFT), nil,
        "movement input should remain untouched")
end

local function test_fear_gameplay_radius_matches_the_scaled_visual_radius()
    local env = makeEnvironment()
    env.update()
    local player = env.players[1]
    local enemy = makeNpc({ position = Vector(player.Position.X + 47, player.Position.Y) })
    env.updateNpc(enemy)
    env.setNearby({ enemy })

    env.update()
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "a player inside the 48px aura must be shoot-locked")

    enemy.Position = Vector(player.Position.X + 49, player.Position.Y)
    env.update()
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), nil,
        "a player outside the 48px aura must not remain shoot-locked")
end

local function test_holder_receives_one_real_transcendence_collectible()
    local env = makeEnvironment()
    local holder = env.players[1]
    local nonHolder = env.players[2]

    env.update()
    assertEquals(#holder.addCollectibleCalls, 1, "the holder should receive exactly one real collectible")
    assertEquals(holder.addCollectibleCalls[1].itemId, CollectibleType.COLLECTIBLE_TRANSCENDENCE,
        "the granted collectible must be c20 Transcendence")
    assertEquals(holder.collectibleCounts[CollectibleType.COLLECTIBLE_TRANSCENDENCE], 1,
        "c20 must exist in the holder's actual inventory")
    assertEquals(#nonHolder.addCollectibleCalls, 0, "c20 must not leak to non-holders")
    assertEquals(holder.CanFly, false, "Night of the Cowards must no longer write CanFly directly")

    env.update()
    assertEquals(#holder.addCollectibleCalls, 1, "repeated updates must not grant duplicate c20 copies")
    assertEquals(env.getSaveCalls(), 1, "the one-time c20 grant marker must be persisted")
end

local function test_room_change_removes_old_auras_and_shoot_lock()
    local env = makeEnvironment()
    env.update()
    local enemy = makeNpc({ position = Vector(100, 100) })
    env.updateNpc(enemy)
    env.setNearby({ enemy })
    env.update()

    local aura = env.effects[1]
    assertEquals(env.input(env.players[1], InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "the player should initially be shoot-locked inside the aura")

    env.newRoom()
    assertTruthy(aura.removed, "room changes should remove the previous room's owned aura entities")
    assertEquals(env.input(env.players[1], InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), nil,
        "room changes should clear stale shoot-lock state")
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function test_registration_and_asset_contract()
    local items = readFile("content/items.xml")
    local english = readFile("content/items.en_us.xml")
    local chinese = readFile("content/items.zh_cn.xml")
    local pools = readFile("content/itempools.xml")
    local englishPools = readFile("content/itempools.en_us.xml")
    local chinesePools = readFile("content/itempools.zh_cn.xml")
    local entities = readFile("content/entities2.xml")
    local source = readFile("night_of_the_cowards.lua")

    assertTruthy(items:find('<passive name="Night of the Cowards"', 1, true), "base item registration")
    assertEquals(items:find('name="Night of the Cowards" cache="flying"', 1, true), nil,
        "base item must not provide scripted flight")
    assertEquals(english:find('name="Night of the Cowards" cache="flying"', 1, true), nil,
        "English item must not provide scripted flight")
    assertEquals(chinese:find('name="胆小鬼之夜" cache="flying"', 1, true), nil,
        "Chinese item must not provide scripted flight")
    assertTruthy(english:find('name="Night of the Cowards"', 1, true), "English localization")
    assertTruthy(chinese:find('name="胆小鬼之夜"', 1, true), "Chinese localization")
    assertTruthy(pools:find('<Pool Name="devil">', 1, true) and pools:find('Name="Night of the Cowards"', 1, true),
        "base Devil pool")
    assertTruthy(englishPools:find('<Pool Name="greedDevil">', 1, true) and englishPools:find('Name="Night of the Cowards"', 1, true),
        "English Greed Devil pool")
    assertTruthy(chinesePools:find('<Pool Name="greedDevil">', 1, true) and chinesePools:find('Name="胆小鬼之夜"', 1, true),
        "Chinese Greed Devil pool")
    assertEquals(entities:find('variant="3021"', 1, true), nil,
        "the obsolete custom Fear Aura Effect must be unregistered")
    assertTruthy(source:find("EffectVariant.HALO", 1, true),
        "enemy auras must reuse the original Halo Effect")
    assertEquals(source:find("FollowParent", 1, true), nil,
        "base Repentance does not expose Effect:FollowParent and must not depend on it")
    assertTruthy(source:find("PlaybackSpeed", 1, true),
        "the reused vanilla Halo must explicitly retain the original playback rate")
    assertEquals(source:find("FLAG_RENDER_FLOOR", 1, true), nil,
        "moving enemy auras must never use the persistent floor-render flag")
    assertTruthy(source:find("AuraSubtype", 1, true),
        "enemy auras must select the original Curse Halo subtype")
    assertEquals(source:find("AddFear", 1, true), nil,
        "the unsupported Player:AddFear route must be removed")
    assertEquals(source:find("player.CanFly", 1, true), nil,
        "Night of the Cowards must not write CanFly directly")
    assertEquals(source:find("EFFECT_NULL", 1, true), nil, "the aura must not use the unregistered null Effect carrier")
    assertEquals(source:find("effect.Timeout", 1, true), nil, "the aura must not write an invalid Timeout member")
    assertTruthy(source:find("gfx/statuseffects.anm2", 1, true),
        "player Fear feedback must reuse the original status ANM2")
    assertTruthy(source:find("COLLECTIBLE_TRANSCENDENCE", 1, true),
        "flight must be granted through the original c20 collectible")
end

local tests = {
    test_normal_enemy_transforms_and_receives_one_cached_aura,
    test_original_cursed_death_head_keeps_its_native_single_aura,
    test_boss_keeps_identity_but_still_gets_an_aura,
    test_aura_follows_owner_and_cleans_up_on_loss,
    test_original_fear_visual_and_shoot_input_blocking,
    test_fear_gameplay_radius_matches_the_scaled_visual_radius,
    test_holder_receives_one_real_transcendence_collectible,
    test_room_change_removes_old_auras_and_shoot_lock,
    test_registration_and_asset_contract,
}

for _, test in ipairs(tests) do test() end
print("night_of_the_cowards_behavior_test: ok")
