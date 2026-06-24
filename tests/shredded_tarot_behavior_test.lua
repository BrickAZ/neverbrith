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
    }
    local players = {}
    local roomEntities = {}

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
    EntityFlag = { FLAG_CHARM = 1 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5 }
    PickupVariant = {
        PICKUP_HEART = 10,
        PICKUP_PILL = 70,
        PICKUP_COLLECTIBLE = 100,
        PICKUP_TAROTCARD = 300,
    }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = {
        POOL_TREASURE = 0,
        POOL_DEVIL = 3,
        POOL_ANGEL = 4,
    }
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
        CARD_FOOL = 1,
        CARD_JOKER = 31,
        RUNE_HAGALAZ = 32,
        RUNE_BLACK = 41,
        RUNE_SHARD = 55,
        CARD_REVERSE_FOOL = 56,
        CARD_WILD = 80,
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

    local room = {
        center = nil,
        spawnSeed = 2000,
    }
    function room:GetCenterPos()
        return self.center or Vector(320, 280)
    end
    function room:FindFreePickupSpawnPosition(position)
        return position
    end
    function room:GetSpawnSeed()
        return self.spawnSeed
    end
    function room:GetType()
        return RoomType.ROOM_DEFAULT
    end
    function room:IsClear()
        return true
    end

    local itemPool = {
        requests = {},
        treasureItems = { 101, 102, 103 },
    }
    function itemPool:GetCollectible(poolType, decrease, seed, defaultItem)
        self.requests[#self.requests + 1] = {
            poolType = poolType,
            decrease = decrease,
            seed = seed,
            defaultItem = defaultItem,
        }
        return self.treasureItems[#self.requests] or self.treasureItems[#self.treasureItems]
    end

    local spawned = {}
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
            GetLevel = function()
                return level
            end,
            GetRoom = function()
                return room
            end,
            GetItemPool = function()
                return itemPool
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
            GetStateFlag = function()
                return false
            end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
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
            local entities = {}
            for _, entity in ipairs(roomEntities) do
                entities[#entities + 1] = entity
            end
            return entities
        end,
        FindByType = function()
            local entities = {}
            for _, player in ipairs(players) do
                entities[#entities + 1] = player
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

    local function getCallback(callbackId, param)
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                return registration.fn
            end
        end

        error("callback not found: " .. tostring(callbackId) .. " param=" .. tostring(param), 2)
    end

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end

        return found
    end

    local function runPostUpdates(frames)
        for _ = 1, frames do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do
                callback(mod)
            end
        end
    end

    local function runPostNewLevel()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_LEVEL)) do
            callback(mod)
        end
    end

    local function runEvaluateCache(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
            callback(mod, player, cacheFlag)
        end
    end

    local function newPlayer(options)
        options = options or {}
        local player = {
            InitSeed = options.initSeed or 1234,
            Position = Vector(0, 0),
            Luck = options.luck or 0,
            TearFlags = 0,
            activeItems = options.activeItems or { [ActiveSlot.SLOT_PRIMARY] = itemIds.ShreddedTarot },
            activeCharges = options.activeCharges or {},
            cacheFlags = {},
            removeCalls = {},
        }

        function player:ToPlayer()
            return self
        end

        function player:GetCollectibleNum(itemId)
            if itemId == itemIds.ShreddedTarot then
                for _, activeItemId in pairs(self.activeItems) do
                    if activeItemId == itemId then
                        return 1
                    end
                end
            end
            return 0
        end

        function player:GetActiveItem(slot)
            return self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:GetActiveCharge(slot)
            return self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end

        function player:SetActiveCharge(charge, slot)
            self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] = charge
        end

        function player:RemoveCollectible(itemId, ignoreModifiers, slot, removeFromPlayerForm)
            self.removeCalls[#self.removeCalls + 1] = {
                itemId = itemId,
                ignoreModifiers = ignoreModifiers,
                slot = slot,
                removeFromPlayerForm = removeFromPlayerForm,
            }
            self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] = 0
        end

        function player:AddCacheFlags(flags)
            self.cacheFlags[#self.cacheFlags + 1] = flags
        end

        function player:EvaluateItems()
            self.evaluated = (self.evaluated or 0) + 1
        end

        players[#players + 1] = player
        return player
    end

    local function newCardPickup(subtype)
        local pickup = {
            Type = EntityType.ENTITY_PICKUP,
            Variant = PickupVariant.PICKUP_TAROTCARD,
            SubType = subtype or Card.CARD_FOOL,
            Position = Vector(100, 100),
            removed = false,
        }

        function pickup:Remove()
            self.removed = true
        end

        roomEntities[#roomEntities + 1] = pickup
        return pickup
    end

    local function newPillPickup()
        local pickup = {
            Type = EntityType.ENTITY_PICKUP,
            Variant = PickupVariant.PICKUP_PILL,
            SubType = 1,
            Position = Vector(120, 100),
            removed = false,
        }

        function pickup:Remove()
            self.removed = true
        end

        roomEntities[#roomEntities + 1] = pickup
        return pickup
    end

    return {
        mod = mod,
        items = itemIds,
        level = level,
        room = room,
        roomEntities = roomEntities,
        itemPool = itemPool,
        spawned = spawned,
        getCallback = getCallback,
        getCallbacks = getCallbacks,
        runPostUpdates = runPostUpdates,
        runPostNewLevel = runPostNewLevel,
        runEvaluateCache = runEvaluateCache,
        newPlayer = newPlayer,
        newCardPickup = newCardPickup,
        newPillPickup = newPillPickup,
    }
end

local function runUseShreddedTarot(env, player, slot)
    local use = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.ShreddedTarot)
    return use(env.mod, env.items.ShreddedTarot, nil, player, 0, slot or ActiveSlot.SLOT_PRIMARY, 0)
end

local function test_fewer_than_three_cards_fails_without_consuming()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local first = env.newCardPickup(Card.CARD_FOOL)
    local second = env.newCardPickup(Card.CARD_MAGICIAN or 2)

    local result = runUseShreddedTarot(env, player)

    assertEquals(result, false, "use with fewer than three cards should fail")
    assertEquals(#env.spawned, 0, "failed use should not spawn collectibles")
    assertEquals(first.removed, false, "failed use should not remove first card")
    assertEquals(second.removed, false, "failed use should not remove second card")
    assertEquals(player:GetActiveItem(ActiveSlot.SLOT_PRIMARY), env.items.ShreddedTarot, "failed use should not consume the active item")
end

local function test_empty_use_still_disappears_on_next_floor()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    env.runPostUpdates(1)
    local result = runUseShreddedTarot(env, player)
    env.level.stage = 2
    env.runPostNewLevel()

    assertEquals(result, false, "empty use should fail")
    assertEquals(player:GetActiveItem(ActiveSlot.SLOT_PRIMARY), 0, "unused Shredded Tarot should disappear on the next floor")
    assertEquals(#player.removeCalls, 1, "next floor should remove the unused item")
end

local function test_three_cards_spawn_one_treasure_item()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local pickups = {
        env.newCardPickup(Card.CARD_FOOL),
        env.newCardPickup(Card.CARD_MAGICIAN or 2),
        env.newCardPickup(Card.CARD_JOKER),
    }

    local result = runUseShreddedTarot(env, player)

    assertEquals(result, true, "three cards should make the use successful")
    assertEquals(#env.spawned, 1, "three cards should spawn one pedestal")
    assertEquals(env.spawned[1].Type, EntityType.ENTITY_PICKUP, "reward should be a pickup")
    assertEquals(env.spawned[1].Variant, PickupVariant.PICKUP_COLLECTIBLE, "reward should be a collectible pedestal")
    assertEquals(env.spawned[1].SubType, 101, "reward should come from the treasure item pool")
    assertEquals(env.itemPool.requests[1].poolType, ItemPoolType.POOL_TREASURE, "reward should request the treasure pool")
    for _, pickup in ipairs(pickups) do
        assertEquals(pickup.removed, true, "successful use should remove card pickup")
    end
end

local function test_six_cards_spawn_two_treasure_items()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    for index = 1, 6 do
        env.newCardPickup(index)
    end

    runUseShreddedTarot(env, player)

    assertEquals(#env.spawned, 2, "six cards should spawn two pedestals")
    assertEquals(env.spawned[1].SubType, 101, "first reward should use first treasure result")
    assertEquals(env.spawned[2].SubType, 102, "second reward should use second treasure result")
end

local function test_ten_cards_remove_all_but_spawn_at_most_three_items()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local pickups = {}

    for index = 1, 10 do
        pickups[#pickups + 1] = env.newCardPickup(index)
    end

    runUseShreddedTarot(env, player)

    assertEquals(#env.spawned, 3, "ten cards should be capped at three pedestals")
    for _, pickup in ipairs(pickups) do
        assertEquals(pickup.removed, true, "successful use should remove every card, including leftover cards")
    end
end

local function test_runes_soul_stones_and_pills_do_not_count_as_cards()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local tarot = env.newCardPickup(Card.CARD_FOOL)
    local rune = env.newCardPickup(Card.RUNE_HAGALAZ)
    local soulStone = env.newCardPickup(Card.CARD_SOUL_ISAAC)
    local pill = env.newPillPickup()

    local result = runUseShreddedTarot(env, player)

    assertEquals(result, false, "runes, soul stones, and pills should not count toward the three-card threshold")
    assertEquals(tarot.removed, false, "failed use should leave tarot card")
    assertEquals(rune.removed, false, "failed use should leave rune")
    assertEquals(soulStone.removed, false, "failed use should leave soul stone")
    assertEquals(pill.removed, false, "failed use should leave pill")
end

local function test_successful_use_removes_active_item()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    for index = 1, 3 do
        env.newCardPickup(index)
    end

    runUseShreddedTarot(env, player)

    assertEquals(player:GetActiveItem(ActiveSlot.SLOT_PRIMARY), 0, "successful use should remove Shredded Tarot")
    assertEquals(player.removeCalls[1].itemId, env.items.ShreddedTarot, "successful use should remove the correct item")
    assertEquals(player.removeCalls[1].slot, ActiveSlot.SLOT_PRIMARY, "successful use should remove from the used active slot")
end

local function test_held_item_grants_luck_and_lost_item_stops_granting_luck()
    local env = loadNeverbirth()
    local player = env.newPlayer({ luck = 1 })

    env.runEvaluateCache(player, CacheFlag.CACHE_LUCK)
    assertEquals(player.Luck, 4, "held Shredded Tarot should add three luck")

    player.activeItems[ActiveSlot.SLOT_PRIMARY] = 0
    player.Luck = 1
    env.runEvaluateCache(player, CacheFlag.CACHE_LUCK)
    assertEquals(player.Luck, 1, "lost Shredded Tarot should stop adding luck")
end

local function test_multiplayer_floor_and_success_state_are_independent()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111 })
    local playerB = env.newPlayer({ initSeed = 222 })

    env.runPostUpdates(1)
    for index = 1, 3 do
        env.newCardPickup(index)
    end

    runUseShreddedTarot(env, playerA)
    env.level.stage = 2
    env.runPostNewLevel()

    assertEquals(playerA:GetActiveItem(ActiveSlot.SLOT_PRIMARY), 0, "successful player should already have consumed their item")
    assertEquals(#playerA.removeCalls, 1, "successful player should only be removed by successful use")
    assertEquals(playerB:GetActiveItem(ActiveSlot.SLOT_PRIMARY), 0, "unused second player's item should disappear on next floor")
    assertEquals(#playerB.removeCalls, 1, "second player's unused state should be tracked independently")
end

test_fewer_than_three_cards_fails_without_consuming()
test_empty_use_still_disappears_on_next_floor()
test_three_cards_spawn_one_treasure_item()
test_six_cards_spawn_two_treasure_items()
test_ten_cards_remove_all_but_spawn_at_most_three_items()
test_runes_soul_stones_and_pills_do_not_count_as_cards()
test_successful_use_removes_active_item()
test_held_item_grants_luck_and_lost_item_stops_granting_luck()
test_multiplayer_floor_and_success_state_are_independent()

print("shredded tarot behavior tests passed")
