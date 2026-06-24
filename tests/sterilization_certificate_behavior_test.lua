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

local function loadNeverbirth()
    local callbacks = {}
    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        ds4 = 739,
        UncutCord = 740,
        ShreddedTarot = 741,
        SterilizationCertificate = 742,
    }
    local players = {}
    local roomEntities = {}
    local spawnedEffects = {}
    local nextSeed = 1000
    local getRoomEntitiesCalls = 0

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
    }
    DamageFlag = {
        DAMAGE_RED_HEARTS = 1,
        DAMAGE_NOKILL = 2,
        DAMAGE_INVINCIBLE = 4,
    }
    EntityFlag = {
        FLAG_CHARM = 1,
        FLAG_FRIENDLY = 2,
    }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = {
        ENTITY_PLAYER = 1,
        ENTITY_PICKUP = 5,
        ENTITY_EFFECT = 1000,
        ENTITY_FLY = 13,
        ENTITY_MULLIGAN = 16,
        ENTITY_DUKE = 67,
    }
    EffectVariant = { POOF01 = 15 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
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

    local room = {
        spawnSeed = 100,
    }
    function room:GetSpawnSeed()
        return self.spawnSeed
    end
    function room:GetType()
        return RoomType.ROOM_DEFAULT
    end
    function room:IsClear()
        return true
    end

    local level = {
        stage = 1,
        stageType = 0,
    }
    function level:GetStage()
        return self.stage
    end
    function level:GetStageType()
        return self.stageType
    end
    function level:AddAngelRoomChance() end
    function level:InitializeDevilAngelRoom() end

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
                spawnedEffects[#spawnedEffects + 1] = {
                    Type = entityType,
                    Variant = variant,
                    Position = position,
                    Velocity = velocity,
                    Spawner = spawner,
                    SubType = subtype,
                    Seed = seed,
                }
            end,
            SetStateFlag = function() end,
            GetStateFlag = function()
                return false
            end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
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
        DebugString = function() end,
        GetRoomEntities = function()
            getRoomEntitiesCalls = getRoomEntitiesCalls + 1
            local entities = {}
            for _, entity in ipairs(roomEntities) do
                entities[#entities + 1] = entity
            end
            return entities
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
        WorldToScreen = function(position)
            return position
        end,
        RenderText = function() end,
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
    }
    function Vector(x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, vectorMeta)
    end

    function EntityRef(entity)
        return { Entity = entity }
    end

    local mod
    function RegisterMod(name, version)
        mod = {
            Name = name,
            Version = version,
        }

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
            if param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end

        return found
    end

    local function runCallbacks(callbackId)
        for _, callback in ipairs(getCallbacks(callbackId)) do
            callback(mod)
        end
    end

    local function runPostUpdate()
        runCallbacks(ModCallbacks.MC_POST_UPDATE)
    end

    local function runPostNewRoom()
        runCallbacks(ModCallbacks.MC_POST_NEW_ROOM)
    end

    local function nextInitSeed()
        nextSeed = nextSeed + 1
        return nextSeed
    end

    local function newPlayer(options)
        options = options or {}
        local player = {
            InitSeed = options.initSeed or nextInitSeed(),
            Position = Vector(0, 0),
            collectibles = options.collectibles or {},
            activeItems = {},
            activeCharges = {},
        }

        function player:ToPlayer()
            return self
        end

        function player:GetCollectibleNum(itemId)
            return self.collectibles[itemId] or 0
        end

        function player:GetActiveItem(slot)
            return self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:GetActiveCharge(slot)
            return self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:AddCacheFlags() end
        function player:EvaluateItems() end

        players[#players + 1] = player
        return player
    end

    local function newEnemy(options)
        options = options or {}
        local enemy = {
            Type = options.type or EntityType.ENTITY_FLY,
            Variant = options.variant or 0,
            SubType = options.subtype or 0,
            InitSeed = options.initSeed or nextInitSeed(),
            Position = options.position or Vector(80, 80),
            MaxHitPoints = options.maxHp or 100,
            HitPoints = options.hp or options.maxHp or 100,
            SpawnerEntity = options.spawner,
            Parent = options.parent,
            flags = options.flags or 0,
            removed = false,
            isBoss = options.isBoss == true,
            damageCalls = {},
            colors = {},
        }

        function enemy:ToPlayer()
            return nil
        end

        function enemy:ToNPC()
            return self
        end

        function enemy:IsVulnerableEnemy()
            return not self.removed
        end

        function enemy:IsBoss()
            return self.isBoss == true
        end

        function enemy:HasEntityFlags(flag)
            return (self.flags & flag) ~= 0
        end

        function enemy:TakeDamage(amount, flags, source, countdown)
            self.damageCalls[#self.damageCalls + 1] = {
                amount = amount,
                flags = flags,
                source = source,
                countdown = countdown,
            }
            self.HitPoints = self.HitPoints - amount
        end

        function enemy:Remove()
            self.removed = true
        end

        function enemy:SetColor(color, duration, priority, fadeout, share)
            self.colors[#self.colors + 1] = {
                color = color,
                duration = duration,
                priority = priority,
                fadeout = fadeout,
                share = share,
            }
        end

        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    local function newPickup(options)
        options = options or {}
        local pickup = {
            Type = EntityType.ENTITY_PICKUP,
            Variant = options.variant or PickupVariant.PICKUP_COLLECTIBLE,
            SubType = options.subtype or 1,
            InitSeed = options.initSeed or nextInitSeed(),
            Position = Vector(120, 120),
            SpawnerEntity = options.spawner,
            removed = false,
        }

        function pickup:ToPlayer()
            return nil
        end

        function pickup:Remove()
            self.removed = true
        end

        roomEntities[#roomEntities + 1] = pickup
        return pickup
    end

    local function clearRoomEntities()
        for i = #roomEntities, 1, -1 do
            roomEntities[i] = nil
        end
    end

    return {
        items = itemIds,
        players = players,
        roomEntities = roomEntities,
        spawnedEffects = spawnedEffects,
        getCallbacks = getCallbacks,
        runPostUpdate = runPostUpdate,
        runPostNewRoom = runPostNewRoom,
        newPlayer = newPlayer,
        newEnemy = newEnemy,
        newPickup = newPickup,
        clearRoomEntities = clearRoomEntities,
        getRoomEntitiesCalls = function()
            return getRoomEntitiesCalls
        end,
    }
end

local function giveSterilizationCertificate(env, player)
    player.collectibles[env.items.SterilizationCertificate] = 1
end

local function test_no_holder_update_does_not_scan_room_entities()
    local env = loadNeverbirth()
    env.newPlayer()
    env.newEnemy({ type = EntityType.ENTITY_MULLIGAN })

    env.runPostUpdate()

    assertEquals(env.getRoomEntitiesCalls(), 0, "without a holder, Sterilization Certificate update should not scan room entities")
end

local function test_without_item_spawn_is_allowed()
    local env = loadNeverbirth()
    env.newPlayer()
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN, maxHp = 100 })
    env.runPostNewRoom()
    local minion = env.newEnemy({ type = EntityType.ENTITY_FLY, spawner = source })

    env.runPostUpdate()

    assertEquals(minion.removed, false, "without Sterilization Certificate, spawned minion should remain")
    assertEquals(#source.damageCalls, 0, "without item, source should not take backlash")
end

local function test_whitelisted_spawner_spawn_is_removed()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    giveSterilizationCertificate(env, player)
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN, maxHp = 100 })
    env.runPostNewRoom()
    local minion = env.newEnemy({ type = EntityType.ENTITY_FLY, spawner = source })

    env.runPostUpdate()

    assertEquals(minion.removed, true, "whitelisted spawner minion should be removed")
    assertEquals(#env.spawnedEffects, 1, "blocked spawn should create one poof effect")
end

local function test_blocked_spawn_deals_backlash_to_source()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    giveSterilizationCertificate(env, player)
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN, maxHp = 200 })
    env.runPostNewRoom()
    env.newEnemy({ type = EntityType.ENTITY_FLY, spawner = source })

    env.runPostUpdate()

    assertEquals(#source.damageCalls, 1, "blocked spawn should backlash exactly once")
    assertEquals(source.damageCalls[1].amount, 20, "normal backlash should be 10 + 5% max HP")
end

local function test_boss_spawn_is_partially_weakened_not_fully_broken()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    giveSterilizationCertificate(env, player)
    local boss = env.newEnemy({ type = EntityType.ENTITY_DUKE, isBoss = true, maxHp = 500 })
    env.runPostNewRoom()
    local ordinaryMinion = env.newEnemy({ type = EntityType.ENTITY_FLY, spawner = boss })
    local phaseEntity = env.newEnemy({ type = EntityType.ENTITY_DUKE, variant = 1, spawner = boss, isBoss = true })

    env.runPostUpdate()

    assertEquals(ordinaryMinion.removed, true, "ordinary boss minion should be suppressed")
    assertEquals(phaseEntity.removed, false, "boss phase or story entities should not be deleted")
    assertEquals(#boss.damageCalls, 1, "boss should take only one backlash for the blocked ordinary minion")
    assertEquals(boss.damageCalls[1].amount, 8, "boss backlash should be 3 + 1% max HP")
end

local function test_initial_room_spawn_is_not_removed()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    giveSterilizationCertificate(env, player)
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN })
    local initialMinion = env.newEnemy({ type = EntityType.ENTITY_FLY, spawner = source })

    env.runPostNewRoom()
    env.runPostUpdate()

    assertEquals(initialMinion.removed, false, "initial room entities should be remembered and ignored")
    assertEquals(#source.damageCalls, 0, "initial room entities should not create backlash")
end

local function test_friendly_summons_are_not_removed()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    giveSterilizationCertificate(env, player)
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN })
    env.runPostNewRoom()
    local friendly = env.newEnemy({
        type = EntityType.ENTITY_FLY,
        spawner = source,
        flags = EntityFlag.FLAG_FRIENDLY,
    })

    env.runPostUpdate()

    assertEquals(friendly.removed, false, "friendly summons should not be removed")
    assertEquals(#source.damageCalls, 0, "friendly summons should not create backlash")
end

local function test_pickups_and_pedestals_are_not_affected()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    giveSterilizationCertificate(env, player)
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN })
    env.runPostNewRoom()
    local pedestal = env.newPickup({ spawner = source })

    env.runPostUpdate()

    assertEquals(pedestal.removed, false, "pickup pedestals should not be removed")
    assertEquals(#source.damageCalls, 0, "pickups should not create backlash")
end

local function test_multiplayer_any_holder_triggers_once()
    local env = loadNeverbirth()
    env.newPlayer({ initSeed = 111 })
    local holder = env.newPlayer({ initSeed = 222 })
    giveSterilizationCertificate(env, holder)
    local source = env.newEnemy({ type = EntityType.ENTITY_MULLIGAN, maxHp = 100 })
    env.runPostNewRoom()
    local minion = env.newEnemy({ type = EntityType.ENTITY_FLY, spawner = source })

    env.runPostUpdate()
    env.runPostUpdate()

    assertEquals(minion.removed, true, "any player holding the item should enable the room effect")
    assertEquals(#source.damageCalls, 1, "same spawn event should only backlash once")
    assertEquals(#env.spawnedEffects, 1, "same spawn event should only poof once")
end

test_without_item_spawn_is_allowed()
test_no_holder_update_does_not_scan_room_entities()
test_whitelisted_spawner_spawn_is_removed()
test_blocked_spawn_deals_backlash_to_source()
test_boss_spawn_is_partially_weakened_not_fully_broken()
test_initial_room_spawn_is_not_removed()
test_friendly_summons_are_not_removed()
test_pickups_and_pedestals_are_not_affected()
test_multiplayer_any_holder_triggers_once()

print("sterilization certificate behavior tests passed")
