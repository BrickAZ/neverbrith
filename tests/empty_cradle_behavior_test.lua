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

local function assertIn(value, expectedValues, message)
    for _, expected in ipairs(expectedValues) do
        if value == expected then
            return
        end
    end

    error((message or "unexpected value") .. ": got " .. tostring(value), 2)
end

local function readFile(path)
    local file = assert(io.open(path, "r"), path .. " should exist")
    local content = file:read("*a")
    file:close()
    return content
end

local function readFileIfExists(path)
    local file = io.open(path, "r")
    if not file then
        return nil
    end

    local content = file:read("*a")
    file:close()
    return content
end

local function loadNeverbirth(options)
    options = options or {}
    local callbacks = {}
    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        UncutCord = 735,
        SterilizationCertificate = 736,
        EmptyCradle = 737,
        ShreddedTarot = 738,
        Chunyao = 739,
        Musicbox = 740,
        Angelbox = 741,
        Devilbox = 742,
        ds4 = 743,
    }
    local players = {}
    local spawned = {}
    local roomEntities = {}
    local debugStrings = {}

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function()
                return "{}"
            end,
            decode = function()
                return {}
            end,
        }
    end

    ModCallbacks = {
        MC_POST_UPDATE = 1,
        MC_USE_ITEM = 2,
        MC_EVALUATE_CACHE = 3,
        MC_POST_RENDER = 4,
        MC_ENTITY_TAKE_DMG = 5,
        MC_PRE_USE_ITEM = 6,
        MC_PRE_PICKUP_COLLISION = 7,
        MC_POST_NEW_ROOM = 8,
        MC_POST_NEW_LEVEL = 9,
        MC_POST_GAME_STARTED = 10,
        MC_FAMILIAR_UPDATE = 11,
        MC_FAMILIAR_INIT = 12,
        MC_POST_ADD_COLLECTIBLE = 13,
    }

    CollectibleType = {
        COLLECTIBLE_NULL = 0,
        COLLECTIBLE_PLAN_C = 475,
    }
    CacheFlag = {
        CACHE_DAMAGE = 1,
        CACHE_SHOTSPEED = 2,
        CACHE_TEARCOLOR = 4,
        CACHE_SPEED = 8,
        CACHE_FIREDELAY = 16,
        CACHE_TEARFLAG = 32,
        CACHE_LUCK = 1024,
        CACHE_FAMILIARS = 2048,
    }
    DamageFlag = {
        DAMAGE_NOKILL = 1,
        DAMAGE_RED_HEARTS = 32,
        DAMAGE_INVINCIBLE = 8192,
        DAMAGE_CURSED_DOOR = 131072,
        DAMAGE_IV_BAG = 262144,
        DAMAGE_FAKE = 2097152,
        DAMAGE_DEVIL = 33554432,
    }
    EntityFlag = {
        FLAG_CHARM = 1,
        FLAG_FEAR = 2,
        FLAG_FRIENDLY = 4,
    }
    EntityCollisionClass = {
        ENTCOLL_NONE = 0,
    }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = {
        ENTITY_PLAYER = 1,
        ENTITY_TEAR = 2,
        ENTITY_FAMILIAR = 3,
        ENTITY_PICKUP = 5,
        ENTITY_EFFECT = 1000,
    }
    EffectVariant = { POOF01 = 15 }
    PickupVariant = {
        PICKUP_HEART = 10,
        PICKUP_COIN = 20,
        PICKUP_KEY = 30,
        PICKUP_BOMB = 40,
        PICKUP_COLLECTIBLE = 100,
        PICKUP_TAROTCARD = 300,
    }
    HeartSubType = {
        HEART_FULL = 1,
        HEART_HALF = 2,
        HEART_SOUL = 3,
        HEART_BLACK = 6,
        HEART_HALF_SOUL = 8,
    }
    CoinSubType = { COIN_PENNY = 1 }
    KeySubType = { KEY_NORMAL = 1 }
    BombSubType = { BOMB_NORMAL = 1 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = {
        ROOM_DEFAULT = 1,
        ROOM_CURSE = 10,
        ROOM_SACRIFICE = 13,
        ROOM_DEVIL = 14,
        ROOM_ANGEL = 15,
    }
    GameStateFlag = {
        STATE_DEVILROOM_SPAWNED = 5,
        STATE_DEVILROOM_VISITED = 6,
    }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }
    Card = {
        RUNE_HAGALAZ = 32,
        RUNE_BLACK = 41,
        RUNE_SHARD = 55,
        CARD_SOUL_ISAAC = 81,
        CARD_SOUL_JACOB = 97,
    }

    function MusicManager()
        return {
            GetCurrentMusicID = function()
                return 1
            end,
            Play = function() end,
            Fadeout = function() end,
        }
    end

    local level = { stage = 1, stageType = 0, currentRoomIndex = 1 }
    function level:GetStage()
        return self.stage
    end
    function level:GetStageType()
        return self.stageType
    end
    function level:GetCurrentRoomIndex()
        return self.currentRoomIndex
    end
    function level:AddAngelRoomChance() end
    function level:InitializeDevilAngelRoom() end

    local room = {
        spawnSeed = 1000,
        center = nil,
        clear = false,
        roomType = RoomType.ROOM_DEFAULT,
    }
    function room:GetSpawnSeed()
        return self.spawnSeed
    end
    function room:GetType()
        return self.roomType
    end
    function room:IsClear()
        return self.clear
    end
    function room:GetCenterPos()
        return self.center or Vector(320, 280)
    end
    function room:FindFreePickupSpawnPosition(position)
        return position
    end

    local seeds = {
        GetStartSeedString = function()
            return "TEST RUN"
        end,
    }
    function Game()
        return {
            GetSeeds = function()
                return seeds
            end,
            GetNumPlayers = function()
                return #players
            end,
            GetRoom = function()
                return room
            end,
            GetLevel = function()
                return level
            end,
            GetItemPool = function()
                return {
                    GetCollectible = function()
                        return CollectibleType.COLLECTIBLE_NULL
                    end,
                }
            end,
            Spawn = function(_, entityType, variant, position, velocity, spawner, subtype, seed)
                local entity = {
                    Type = entityType,
                    Variant = variant,
                    Position = position,
                    Velocity = velocity,
                    Spawner = spawner,
                    SubType = subtype,
                    Seed = seed,
                }
                spawned[#spawned + 1] = entity
                return entity
            end,
            SetStateFlag = function() end,
            GetStateFlag = function()
                return false
            end,
        }
    end

    local rngValues = options.rngValues or {}
    local rngIndex = 0
    local function nextRngValue()
        rngIndex = rngIndex + 1
        return rngValues[rngIndex] or 0
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Empty Cradle" or name == "空摇篮" then
                return itemIds.EmptyCradle
            end
            if name == "Sterilization Certificate" or name == "绝育证明" then
                return itemIds.SterilizationCertificate
            end
            if name == "Uncut Cord" or name == "未剪断的脐带" then
                return itemIds.UncutCord
            end
            if name == "Shredded Tarot" or name == "剪碎的塔罗" then
                return itemIds.ShreddedTarot
            end
            return itemIds[name] or -1
        end,
        GetMusicIdByName = function(name)
            if name == "MusicboxTheme" then
                return 736
            end
            return -1
        end,
        DebugString = function(message)
            debugStrings[#debugStrings + 1] = message
        end,
        GetRoomEntities = function()
            return roomEntities
        end,
        FindByType = function(entityType)
            local entities = {}
            if entityType == EntityType.ENTITY_PLAYER then
                for _, player in ipairs(players) do
                    entities[#entities + 1] = player
                end
            end
            return entities
        end,
        GetPlayer = function(index)
            return players[(index or 0) + 1]
        end,
        Spawn = function(entityType, variant, subtype, position, velocity, spawner, seed)
            local entity = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                Velocity = velocity,
                Spawner = spawner,
                Seed = seed,
            }
            spawned[#spawned + 1] = entity
            return entity
        end,
        GetItemConfig = function()
            return {
                GetCollectible = function()
                    return { Quality = 4 }
                end,
            }
        end,
    }

    Color = setmetatable({}, {
        __call = function(_, r, g, b, a, ro, go, bo)
            return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo }
        end,
    })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)

    local vectorMeta = {
        __add = function(left, right)
            return Vector(left.X + right.X, left.Y + right.Y)
        end,
        __sub = function(left, right)
            return Vector(left.X - right.X, left.Y - right.Y)
        end,
        __mul = function(left, right)
            if type(left) == "number" then
                return Vector(right.X * left, right.Y * left)
            end
            return Vector(left.X * right, left.Y * right)
        end,
    }
    function Vector(x, y)
        local value = setmetatable({ X = x or 0, Y = y or 0 }, vectorMeta)
        function value:Distance(other)
            local dx = self.X - other.X
            local dy = self.Y - other.Y
            return math.sqrt(dx * dx + dy * dy)
        end
        function value:Resized(length)
            local current = self:Distance(Vector(0, 0))
            if current <= 0 then
                return Vector(0, 0)
            end
            return Vector(self.X / current * length, self.Y / current * length)
        end
        return value
    end

    function EntityRef(entity)
        return { Entity = entity }
    end

    local mod
    function RegisterMod(name, version)
        mod = { Name = name, Version = version }

        function mod:AddCallback(callbackId, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
        end
        function mod:HasData()
            return false
        end
        function mod:LoadData()
            return "{}"
        end
        function mod:SaveData() end

        return mod
    end

    dofile("main.lua")

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end
        return found
    end

    local function runEvaluateCache(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE, cacheFlag)) do
            callback(mod, player, cacheFlag)
        end
    end

    local function runCallbacks(callbackId, ...)
        for _, callback in ipairs(getCallbacks(callbackId)) do
            callback(mod, ...)
        end
    end

    local function runPostUpdate(frames)
        for _ = 1, frames or 1 do
            runCallbacks(ModCallbacks.MC_POST_UPDATE)
        end
    end

    local function runPostNewLevel()
        runCallbacks(ModCallbacks.MC_POST_NEW_LEVEL)
    end

    local function runDamageCallbacks(player, amount, flags, source)
        local result = nil
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER)) do
            local callbackResult = callback(mod, player, amount, flags or 0, source or EntityRef(player), 0)
            if callbackResult ~= nil then
                result = callbackResult
                if callbackResult == false then
                    return false
                end
            end
        end
        return result
    end

    local function newPlayer(optionsForPlayer)
        optionsForPlayer = optionsForPlayer or {}
        local player = {
            InitSeed = optionsForPlayer.initSeed or (#players + 100),
            Position = optionsForPlayer.position or Vector(100, 100),
            collectibles = optionsForPlayer.collectibles or {},
            hearts = optionsForPlayer.hearts or 2,
            soulHearts = optionsForPlayer.soulHearts or 0,
            blackHearts = optionsForPlayer.blackHearts or 0,
            Damage = optionsForPlayer.damage or 3.5,
            cacheFlags = {},
            evaluated = 0,
        }

        function player:ToPlayer()
            return self
        end
        function player:GetCollectibleNum(itemId)
            return self.collectibles[itemId] or 0
        end
        function player:GetCollectibleRNG(itemId)
            return {
                ItemId = itemId,
                RandomInt = function(_, max)
                    return math.floor(nextRngValue() * max)
                end,
            }
        end
        function player:GetHearts()
            return self.hearts
        end
        function player:GetSoulHearts()
            return self.soulHearts
        end
        function player:GetBlackHearts()
            return self.blackHearts
        end
        function player:AddCacheFlags(flag)
            self.cacheFlags[#self.cacheFlags + 1] = flag
        end
        function player:EvaluateItems()
            self.evaluated = self.evaluated + 1
            local flags = self.cacheFlags
            self.cacheFlags = {}
            for _, flag in ipairs(flags) do
                runEvaluateCache(self, flag)
            end
        end
        function player:GetActiveItem(slot)
            return 0
        end
        function player:GetActiveCharge(slot)
            return 0
        end

        players[#players + 1] = player
        return player
    end

    return {
        items = itemIds,
        players = players,
        spawned = spawned,
        roomEntities = roomEntities,
        debugStrings = debugStrings,
        level = level,
        room = room,
        rngValues = rngValues,
        runPostUpdate = runPostUpdate,
        runPostNewLevel = runPostNewLevel,
        runDamageCallbacks = runDamageCallbacks,
        runEvaluateCache = runEvaluateCache,
        getCallbacks = getCallbacks,
        newPlayer = newPlayer,
    }
end

local function giveEmptyCradle(env, player)
    player.collectibles[env.items.EmptyCradle] = 1
end

local function clearRoom(env)
    env.room.clear = true
    env.runPostUpdate(1)
end

local function countSpawns(env, variant, subtype)
    local count = 0
    for _, spawn in ipairs(env.spawned) do
        if (variant == nil or spawn.Variant == variant) and (subtype == nil or spawn.SubType == subtype) then
            count = count + 1
        end
    end
    return count
end

local function test_xml_no_longer_uses_familiar_cache_or_entity()
    local items = readFile("content/items.xml")
    local zh = readFile("content/items.zh_cn.xml")
    local en = readFile("content/items.en_us.xml")

    assertTruthy(not items:find('name="Empty Cradle"%s+cache="familiars"'), "default Empty Cradle should not use familiar cache")
    assertTruthy(not zh:find('name="空摇篮"%s+cache="familiars"'), "zh Empty Cradle should not use familiar cache")
    assertTruthy(not en:find('name="Empty Cradle"%s+cache="familiars"'), "en Empty Cradle should not use familiar cache")
    local entities = readFileIfExists("content/entities2.xml")
    assertTruthy(entities == nil or not entities:find("Empty Cradle Baby", 1, true), "entities2 should not register Empty Cradle Baby")
end

local function test_red_damage_upgraded_reward_spawns_full_heart_type()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer({ hearts = 4, soulHearts = 0 })
    giveEmptyCradle(env, player)

    local result = env.runDamageCallbacks(player, 2, DamageFlag.DAMAGE_RED_HEARTS)
    clearRoom(env)

    assertEquals(result, nil, "Empty Cradle should never block damage")
    assertEquals(#env.spawned, 1, "upgraded red reward should spawn one pickup")
    assertEquals(env.spawned[1].Variant, PickupVariant.PICKUP_HEART, "red reward should be a heart pickup")
    assertIn(env.spawned[1].SubType, { HeartSubType.HEART_FULL, HeartSubType.HEART_SOUL, HeartSubType.HEART_BLACK }, "upgraded red reward should be full red, soul, or black heart")
end

local function test_red_damage_basic_reward_excludes_half_black_heart()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer({ hearts = 4, soulHearts = 0 })
    giveEmptyCradle(env, player)

    env.runDamageCallbacks(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    env.runDamageCallbacks(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    clearRoom(env)

    assertEquals(#env.spawned, 1, "basic red reward should spawn one pickup")
    assertEquals(env.spawned[1].Variant, PickupVariant.PICKUP_HEART, "basic red reward should be a heart pickup")
    assertIn(env.spawned[1].SubType, { HeartSubType.HEART_HALF, HeartSubType.HEART_HALF_SOUL }, "basic red reward should only be half red or half soul")
end

local function test_soul_damage_basic_reward_spawns_resources()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer({ hearts = 0, soulHearts = 4, blackHearts = 0 })
    giveEmptyCradle(env, player)

    env.runDamageCallbacks(player, 2, 0)
    env.runDamageCallbacks(player, 1, 0)
    clearRoom(env)

    assertEquals(countSpawns(env, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY), 3, "coin resource reward should spawn three pennies")
end

local function test_soul_damage_upgraded_reward_rolls_twice()
    local env = loadNeverbirth({ rngValues = { 0.4, 0.8 } })
    local player = env.newPlayer({ hearts = 0, soulHearts = 4, blackHearts = 0 })
    giveEmptyCradle(env, player)

    env.runDamageCallbacks(player, 2, 0)
    clearRoom(env)

    assertEquals(#env.spawned, 2, "upgraded soul reward should generate two resource rewards")
    assertEquals(countSpawns(env, PickupVariant.PICKUP_KEY, KeySubType.KEY_NORMAL), 1, "second resource bucket can be key")
    assertEquals(countSpawns(env, PickupVariant.PICKUP_BOMB, BombSubType.BOMB_NORMAL), 1, "third resource bucket can be bomb")
end

local function test_black_damage_basic_and_upgraded_damage_bonus()
    local env = loadNeverbirth()
    local basicPlayer = env.newPlayer({ initSeed = 111, hearts = 0, soulHearts = 4, blackHearts = 1, damage = 3.5 })
    giveEmptyCradle(env, basicPlayer)

    env.runDamageCallbacks(basicPlayer, 1, 0)
    env.runDamageCallbacks(basicPlayer, 1, 0)
    clearRoom(env)
    assertEquals(basicPlayer.Damage, 4.0, "basic black reward should grant +0.5 damage")

    local upgradedEnv = loadNeverbirth()
    local upgradedPlayer = upgradedEnv.newPlayer({ hearts = 0, soulHearts = 4, blackHearts = 1, damage = 3.5 })
    giveEmptyCradle(upgradedEnv, upgradedPlayer)
    upgradedEnv.runDamageCallbacks(upgradedPlayer, 1, 0)
    clearRoom(upgradedEnv)
    assertEquals(upgradedPlayer.Damage, 4.5, "upgraded black reward should grant +1.0 damage")
end

local function test_once_per_floor_and_new_floor_reset()
    local env = loadNeverbirth({ rngValues = { 0, 0 } })
    local player = env.newPlayer({ hearts = 4, soulHearts = 0 })
    giveEmptyCradle(env, player)

    env.runDamageCallbacks(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    clearRoom(env)
    env.room.clear = false
    env.level.currentRoomIndex = 2
    env.runDamageCallbacks(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    clearRoom(env)
    assertEquals(#env.spawned, 1, "same floor should trigger only once")

    env.level.stage = 2
    env.level.currentRoomIndex = 1
    env.room.clear = false
    env.runPostNewLevel()
    env.runDamageCallbacks(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    clearRoom(env)
    assertEquals(#env.spawned, 2, "next floor should allow Empty Cradle to trigger again")
end

local function test_new_floor_clears_black_damage_bonus()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 0, soulHearts = 4, blackHearts = 1, damage = 3.5 })
    giveEmptyCradle(env, player)

    env.runDamageCallbacks(player, 1, 0)
    clearRoom(env)
    assertEquals(player.Damage, 4.5, "black reward should apply before floor change")

    env.level.stage = 2
    env.runPostNewLevel()
    player.Damage = 3.5
    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    player:EvaluateItems()
    assertEquals(player.Damage, 3.5, "new floor should clear Empty Cradle damage bonus")
end

local function test_cost_damage_does_not_trigger()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 4, soulHearts = 0 })
    giveEmptyCradle(env, player)

    env.runDamageCallbacks(player, 1, DamageFlag.DAMAGE_IV_BAG)
    clearRoom(env)

    assertEquals(#env.spawned, 0, "IV bag style cost damage should not trigger Empty Cradle")
end

local function test_multiplayer_states_are_independent()
    local env = loadNeverbirth({ rngValues = { 0, 0 } })
    local playerA = env.newPlayer({ initSeed = 111, hearts = 4, soulHearts = 0 })
    local playerB = env.newPlayer({ initSeed = 222, hearts = 4, soulHearts = 0 })
    giveEmptyCradle(env, playerA)
    giveEmptyCradle(env, playerB)

    env.runDamageCallbacks(playerA, 1, DamageFlag.DAMAGE_RED_HEARTS)
    env.runDamageCallbacks(playerB, 1, DamageFlag.DAMAGE_RED_HEARTS)
    clearRoom(env)

    assertEquals(#env.spawned, 2, "each player should receive their own Empty Cradle reward")
end

test_xml_no_longer_uses_familiar_cache_or_entity()
test_red_damage_upgraded_reward_spawns_full_heart_type()
test_red_damage_basic_reward_excludes_half_black_heart()
test_soul_damage_basic_reward_spawns_resources()
test_soul_damage_upgraded_reward_rolls_twice()
test_black_damage_basic_and_upgraded_damage_bonus()
test_once_per_floor_and_new_floor_reset()
test_new_floor_clears_black_damage_bonus()
test_cost_damage_does_not_trigger()
test_multiplayer_states_are_independent()

print("empty cradle reward conversion tests passed")
