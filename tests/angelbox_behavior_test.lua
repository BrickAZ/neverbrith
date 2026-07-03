local function deepcopy(value)
    if type(value) ~= "table" then
        return value
    end

    local copy = {}
    for key, child in pairs(value) do
        copy[deepcopy(key)] = deepcopy(child)
    end
    return copy
end

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

local function loadNeverbirth(savedStore)
    savedStore = savedStore or { text = nil, snapshot = nil }

    local callbacks = {}
    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        ds4 = 739,
    }

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function(value)
                savedStore.snapshot = deepcopy(value)
                return "<json>"
            end,
            decode = function()
                return deepcopy(savedStore.snapshot or {})
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
        MC_POST_PICKUP_INIT = 10,
    }

    CollectibleType = {
        COLLECTIBLE_NULL = 0,
        COLLECTIBLE_PLAN_C = 475,
        COLLECTIBLE_SACRED_HEART = 182,
        COLLECTIBLE_HOLY_MANTLE = 313,
        COLLECTIBLE_GODHEAD = 331,
        COLLECTIBLE_CROWN_OF_LIGHT = 415,
        COLLECTIBLE_REVELATION = 643,
        COLLECTIBLE_SACRED_ORB = 691,
        COLLECTIBLE_BRIMSTONE = 118,
        COLLECTIBLE_MOMS_KNIFE = 114,
        COLLECTIBLE_INCUBUS = 360,
        COLLECTIBLE_TWISTED_PAIR = 698,
        COLLECTIBLE_DARK_BUM = 278,
        COLLECTIBLE_SATANIC_BIBLE = 292,
        COLLECTIBLE_MAW_OF_THE_VOID = 399,
        COLLECTIBLE_SUCCUBUS = 417,
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
    EntityType = {
        ENTITY_PLAYER = 1,
        ENTITY_PICKUP = 5,
    }
    PickupVariant = {
        PICKUP_HEART = 10,
        PICKUP_COLLECTIBLE = 100,
    }
    HeartSubType = {
        HEART_SOUL = 3,
        HEART_BLACK = 6,
        HEART_HALF_SOUL = 8,
    }
    ItemPoolType = {
        POOL_DEVIL = 3,
        POOL_ANGEL = 4,
    }
    RoomType = {
        ROOM_DEFAULT = 1,
        ROOM_DEVIL = 14,
        ROOM_ANGEL = 15,
    }
    GameStateFlag = {
        STATE_DEVILROOM_SPAWNED = 5,
        STATE_DEVILROOM_VISITED = 6,
    }
    GridRooms = {
        ROOM_DEVIL_IDX = -1,
    }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }

    local musicState = {
        current = 1,
        plays = {},
        fadeouts = 0,
    }

    function MusicManager()
        return {
            GetCurrentMusicID = function()
                return musicState.current
            end,
            Play = function(_, musicId)
                musicState.current = musicId
                musicState.plays[#musicState.plays + 1] = musicId
            end,
            Fadeout = function()
                musicState.fadeouts = musicState.fadeouts + 1
            end,
        }
    end

    local seeds = {
        GetStartSeedString = function()
            return "TEST RUN"
        end,
    }

    local level = {
        stage = 1,
        stageType = 0,
        angelRoomChanceDelta = 0,
        initializeCalls = {},
        dealRoomDesc = { Data = { Type = RoomType.ROOM_ANGEL } },
        dataWasClearedBeforeInitialize = false,
    }

    function level:GetStage()
        return self.stage
    end

    function level:GetStageType()
        return self.stageType
    end

    function level:AddAngelRoomChance(amount)
        self.angelRoomChanceDelta = self.angelRoomChanceDelta + amount
    end

    function level:InitializeDevilAngelRoom(forceAngel, forceDevil)
        self.dataWasClearedBeforeInitialize = self.dealRoomDesc.Data == nil
        self.initializeCalls[#self.initializeCalls + 1] = {
            forceAngel = forceAngel,
            forceDevil = forceDevil,
        }
        self.dealRoomDesc.Data = {
            Type = forceDevil and RoomType.ROOM_DEVIL or RoomType.ROOM_ANGEL,
        }
    end

    function level:GetRoomByIdx(index)
        if index == GridRooms.ROOM_DEVIL_IDX then
            return self.dealRoomDesc
        end

        return nil
    end

    local room = {
        roomType = RoomType.ROOM_DEFAULT,
        center = nil,
    }

    function room:GetType()
        return self.roomType
    end

    function room:GetCenterPos()
        return self.center or Vector(320, 280)
    end

    function room:FindFreePickupSpawnPosition(position)
        return position
    end

    function room:GetSpawnSeed()
        return 123456
    end

    local itemPool = {
        requests = {},
        angelItems = { CollectibleType.COLLECTIBLE_SACRED_HEART },
        devilItems = { CollectibleType.COLLECTIBLE_BRIMSTONE },
        fallbackItem = CollectibleType.COLLECTIBLE_SACRED_HEART,
        devilFallbackItem = CollectibleType.COLLECTIBLE_BRIMSTONE,
        seedOrderItems = nil,
        devilSeedOrderItems = nil,
        seedOrder = {},
        devilSeedOrder = {},
        seedOrderCount = 0,
        devilSeedOrderCount = 0,
    }

    function itemPool:GetCollectible(poolType, decrease, seed, defaultItem)
        self.requests[#self.requests + 1] = {
            poolType = poolType,
            decrease = decrease,
            seed = seed,
            defaultItem = defaultItem,
        }

        if poolType == ItemPoolType.POOL_DEVIL then
            if self.devilSeedOrderItems then
                if not self.devilSeedOrder[seed] then
                    self.devilSeedOrderCount = self.devilSeedOrderCount + 1
                    self.devilSeedOrder[seed] = self.devilSeedOrderCount
                end

                return self.devilSeedOrderItems[self.devilSeedOrder[seed]] or self.devilSeedOrderItems[#self.devilSeedOrderItems]
            end

            return self.devilItems[#self.requests] or self.devilFallbackItem
        end

        if self.seedOrderItems then
            if not self.seedOrder[seed] then
                self.seedOrderCount = self.seedOrderCount + 1
                self.seedOrder[seed] = self.seedOrderCount
            end

            return self.seedOrderItems[self.seedOrder[seed]] or self.seedOrderItems[#self.seedOrderItems]
        end
        return self.angelItems[#self.requests] or self.fallbackItem
    end

    local spawned = {}
    local gameStateFlags = {
        [GameStateFlag.STATE_DEVILROOM_SPAWNED] = true,
        [GameStateFlag.STATE_DEVILROOM_VISITED] = true,
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
            GetStateFlag = function(_, flag)
                return gameStateFlags[flag] == true
            end,
            SetStateFlag = function(_, flag, value)
                gameStateFlags[flag] = value == true
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
        }
    end

    local players = {}
    local roomEntities = {}

    Isaac = {
        GetItemIdByName = function(name)
            return itemIds[name] or -1
        end,
        GetMusicIdByName = function(name)
            if name == "MusicboxTheme" then
                return 736
            end
            return -1
        end,
        GetItemConfig = function()
            local qualityFour = {
                [CollectibleType.COLLECTIBLE_SACRED_HEART] = true,
                [CollectibleType.COLLECTIBLE_HOLY_MANTLE] = true,
                [CollectibleType.COLLECTIBLE_GODHEAD] = true,
                [CollectibleType.COLLECTIBLE_CROWN_OF_LIGHT] = true,
                [CollectibleType.COLLECTIBLE_REVELATION] = true,
                [CollectibleType.COLLECTIBLE_SACRED_ORB] = true,
                [CollectibleType.COLLECTIBLE_BRIMSTONE] = true,
                [CollectibleType.COLLECTIBLE_MOMS_KNIFE] = true,
                [CollectibleType.COLLECTIBLE_INCUBUS] = true,
                [CollectibleType.COLLECTIBLE_TWISTED_PAIR] = true,
            }
            local qualityThree = {
                [CollectibleType.COLLECTIBLE_DARK_BUM] = true,
                [CollectibleType.COLLECTIBLE_SATANIC_BIBLE] = true,
                [CollectibleType.COLLECTIBLE_MAW_OF_THE_VOID] = true,
                [CollectibleType.COLLECTIBLE_SUCCUBUS] = true,
            }

            return {
                GetCollectible = function(_, itemId)
                    if qualityFour[itemId] then
                        return { Quality = 4 }
                    end
                    if qualityThree[itemId] then
                        return { Quality = 3 }
                    end
                    return { Quality = 1 }
                end,
            }
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

        function mod:SaveData(text)
            savedStore.text = text
        end

        function mod:LoadData()
            return savedStore.text
        end

        function mod:HasData()
            return savedStore.text ~= nil
        end

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

    local function newPlayer(options)
        options = options or {}
        local player = {
            InitSeed = options.initSeed or 1234,
            Position = Vector(0, 0),
            TearFlags = 0,
            killCount = 0,
            cacheFlags = {},
            activeItems = options.activeItems or { [ActiveSlot.SLOT_PRIMARY] = itemIds.Angelbox },
            activeCharges = options.activeCharges or { [ActiveSlot.SLOT_PRIMARY] = 4 },
            collectibles = options.collectibles or {},
            maxHearts = options.maxHearts or 6,
            effectiveMaxHearts = options.effectiveMaxHearts,
            soulHearts = options.soulHearts or 0,
            blackHearts = options.blackHearts or 0,
            heartLimit = options.heartLimit or 24,
            addedSoulHearts = 0,
            addedBlackHearts = 0,
            Luck = options.luck or 0,
        }

        function player:ToPlayer()
            return self
        end

        function player:AddCacheFlags(flags)
            self.cacheFlags[#self.cacheFlags + 1] = flags
        end

        function player:EvaluateItems()
            self.evaluated = (self.evaluated or 0) + 1
        end

        function player:GetCollectibleNum(itemId)
            if itemId == itemIds.Angelbox and self.hasAngelboxCollectibleCount then
                return self.hasAngelboxCollectibleCount
            end
            if itemId == itemIds.Devilbox and self.hasDevilboxCollectibleCount then
                return self.hasDevilboxCollectibleCount
            end
            if self.collectibles[itemId] then
                return self.collectibles[itemId]
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

        function player:DischargeActiveItem(slot)
            self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] = 0
        end

        function player:NeedsCharge(slot)
            return self:GetActiveCharge(slot) < 4
        end

        function player:GetMaxHearts()
            return self.maxHearts
        end

        function player:GetEffectiveMaxHearts()
            return self.effectiveMaxHearts or self.maxHearts
        end

        function player:GetHeartLimit()
            return self.heartLimit
        end

        function player:GetSoulHearts()
            return self.soulHearts
        end

        function player:AddSoulHearts(amount)
            self.addedSoulHearts = self.addedSoulHearts + amount
            self.soulHearts = self.soulHearts + amount
        end

        function player:AddBlackHearts(amount)
            self.addedBlackHearts = self.addedBlackHearts + amount
            self.blackHearts = self.blackHearts + amount
            self.soulHearts = self.soulHearts + amount
        end

        function player:GetHearts()
            return 2
        end

        function player:GetBoneHearts()
            return 0
        end

        function player:Kill()
            self.killCount = self.killCount + 1
        end

        function player:WillPlayerRevive()
            return false
        end

        players[#players + 1] = player
        return player
    end

    local nextPickupSeed = 1000
    local function newHeartPickup(subtype, initSeed)
        nextPickupSeed = nextPickupSeed + 1
        local pickup = {
            InitSeed = initSeed or nextPickupSeed,
            Type = EntityType.ENTITY_PICKUP,
            Variant = PickupVariant.PICKUP_HEART,
            SubType = subtype or HeartSubType.HEART_SOUL,
            Position = Vector(40, 40),
            removed = false,
            pickupSounds = 0,
        }

        function pickup:Remove()
            self.removed = true
        end

        function pickup:PlayPickupSound()
            self.pickupSounds = self.pickupSounds + 1
        end

        return pickup
    end

    local function newSoulHeartPickup(subtype, initSeed)
        return newHeartPickup(subtype or HeartSubType.HEART_SOUL, initSeed)
    end

    local function newBlackHeartPickup(initSeed)
        return newHeartPickup(HeartSubType.HEART_BLACK, initSeed)
    end

    return {
        mod = mod,
        items = itemIds,
        savedStore = savedStore,
        callbacks = callbacks,
        level = level,
        room = room,
        itemPool = itemPool,
        spawned = spawned,
        gameStateFlags = gameStateFlags,
        getCallback = getCallback,
        getCallbacks = getCallbacks,
        newPlayer = newPlayer,
        newHeartPickup = newHeartPickup,
        newSoulHeartPickup = newSoulHeartPickup,
        newBlackHeartPickup = newBlackHeartPickup,
    }
end

local function runPostUpdates(env, frames)
    local updates = env.getCallbacks(ModCallbacks.MC_POST_UPDATE)
    for _ = 1, frames do
        for _, update in ipairs(updates) do
            update(env.mod)
        end
    end
end

local function runPostNewRoom(env)
    for _, callback in ipairs(env.getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do
        callback(env.mod)
    end
end

local function runPickupCollision(env, pickup, player)
    for _, callback in ipairs(env.getCallbacks(ModCallbacks.MC_PRE_PICKUP_COLLISION, PickupVariant.PICKUP_HEART)) do
        local result = callback(env.mod, pickup, player, false)
        if result ~= nil then
            return result
        end
    end

    return nil
end

local function runPostPickupInit(env, pickup)
    for _, callback in ipairs(env.getCallbacks(ModCallbacks.MC_POST_PICKUP_INIT, PickupVariant.PICKUP_HEART)) do
        callback(env.mod, pickup)
    end
end

local function getItemXmlAttribute(itemName, attribute)
    local file = assert(io.open("content/items.xml", "r"))
    local text = file:read("*a")
    file:close()

    local block = text:match('<active%s+name="' .. itemName .. '"(.-)/>')
    assertTruthy(block, "items.xml should contain active item " .. itemName)
    return block:match(attribute .. '="([^"]+)"')
end

local function getItemXmlQuality(itemName)
    return getItemXmlAttribute(itemName, "quality")
end

local function test_devilbox_is_quality_four_and_angelbox_stays_quality_three()
    assertEquals(getItemXmlQuality("Devilbox"), "4", "Devilbox should be a quality 4 item")
    assertEquals(getItemXmlQuality("Angelbox"), "3", "Angelbox should remain a quality 3 item")
end

local function test_angelbox_grants_three_luck_while_held()
    local env = loadNeverbirth()
    local player = env.newPlayer({ luck = 1 })
    local evaluateCallbacks = env.getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)

    for _, callback in ipairs(evaluateCallbacks) do
        callback(env.mod, player, CacheFlag.CACHE_LUCK)
    end
    assertEquals(player.Luck, 4, "Angelbox should grant +3 Luck while held")

    player.activeItems[ActiveSlot.SLOT_PRIMARY] = 0
    player.Luck = 1
    for _, callback in ipairs(evaluateCallbacks) do
        callback(env.mod, player, CacheFlag.CACHE_LUCK)
    end
    assertEquals(player.Luck, 1, "Angelbox Luck bonus should disappear when not held")
end

local function test_box_heart_spawn_bonus_rolls_are_independent_and_non_recursive()
    local env = loadNeverbirth()
    env.newPlayer({ activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Angelbox } })
    env.newPlayer({
        initSeed = 222,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })

    runPostPickupInit(env, env.newHeartPickup(HeartSubType.HEART_SOUL, 5))
    assertEquals(#env.spawned, 2, "seed below both thresholds should spawn both bonus hearts")
    assertEquals(env.spawned[1].Variant, PickupVariant.PICKUP_HEART, "Angelbox bonus should be a heart pickup")
    assertEquals(env.spawned[1].SubType, HeartSubType.HEART_SOUL, "Angelbox bonus should be a full soul heart")
    assertEquals(env.spawned[2].SubType, HeartSubType.HEART_BLACK, "Devilbox bonus should be a black heart")

    runPostPickupInit(env, env.spawned[1])
    runPostPickupInit(env, env.spawned[2])
    assertEquals(#env.spawned, 2, "bonus hearts should not recursively create more bonus hearts")
end

local function test_angelbox_heart_bonus_miss_and_devilbox_hit_thresholds()
    local angelEnv = loadNeverbirth()
    angelEnv.newPlayer({ activeItems = { [ActiveSlot.SLOT_PRIMARY] = angelEnv.items.Angelbox } })
    runPostPickupInit(angelEnv, angelEnv.newHeartPickup(HeartSubType.HEART_SOUL, 60))
    assertEquals(#angelEnv.spawned, 0, "Angelbox 60% bonus should miss at roll 60")

    local devilEnv = loadNeverbirth()
    devilEnv.newPlayer({
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = devilEnv.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    runPostPickupInit(devilEnv, devilEnv.newHeartPickup(HeartSubType.HEART_SOUL, 72))
    assertEquals(#devilEnv.spawned, 1, "Devilbox 80% bonus should hit below 80")
    assertEquals(devilEnv.spawned[1].SubType, HeartSubType.HEART_BLACK, "Devilbox bonus should be a black heart")

    runPostPickupInit(devilEnv, devilEnv.newHeartPickup(HeartSubType.HEART_SOUL, 73))
    assertEquals(#devilEnv.spawned, 1, "Devilbox 80% bonus should miss at roll 80")
end

local function test_multiple_same_box_holders_do_not_stack_same_bonus()
    local env = loadNeverbirth()
    env.newPlayer({ initSeed = 111, activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Angelbox } })
    env.newPlayer({ initSeed = 222, activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Angelbox } })

    runPostPickupInit(env, env.newHeartPickup(HeartSubType.HEART_SOUL, 5))
    assertEquals(#env.spawned, 1, "multiple Angelbox holders should only roll one Angelbox bonus")
    assertEquals(env.spawned[1].SubType, HeartSubType.HEART_SOUL, "single Angelbox bonus should be a full soul heart")
end

local function test_box_xml_charges_are_four_and_start_full()
    assertEquals(getItemXmlAttribute("Angelbox", "maxcharges"), "4", "Angelbox max charge should be 4")
    assertEquals(getItemXmlAttribute("Angelbox", "initcharge"), "4", "Angelbox initial charge should be full at 4")
    assertEquals(getItemXmlAttribute("Devilbox", "maxcharges"), "4", "Devilbox max charge should be 4")
    assertEquals(getItemXmlAttribute("Devilbox", "initcharge"), "4", "Devilbox initial charge should be full at 4")
end

local function test_first_use_grants_one_full_soul_heart_per_red_container()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    local result = useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(result, true, "first Angelbox use should succeed")
    assertEquals(player.addedSoulHearts, 6, "three red heart containers should grant three full soul hearts")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "first Angelbox use should spend its charge")
end

local function test_first_use_is_tracked_per_player()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111, maxHearts = 6 })
    local playerB = env.newPlayer({ initSeed = 222, maxHearts = 4 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    useAngelbox(env.mod, env.items.Angelbox, nil, playerA, 0, ActiveSlot.SLOT_PRIMARY, 0)
    playerB:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    local playerBResult = useAngelbox(env.mod, env.items.Angelbox, nil, playerB, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(playerBResult, true, "another player's first Angelbox use should succeed")
    assertEquals(playerA.addedSoulHearts, 6, "player A should receive their own first-use soul hearts")
    assertEquals(playerB.addedSoulHearts, 4, "player B should still receive their own first-use soul hearts")
    assertEquals(#env.level.initializeCalls, 0, "player B's first use should not force an angel room")
end

local function test_soul_heart_pickups_only_charge_overflow()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 20, soulHearts = 0, activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 } })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)
    local collide = env.getCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, PickupVariant.PICKUP_HEART)

    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    player.soulHearts = 0
    player.addedSoulHearts = 0
    player:SetActiveCharge(0, ActiveSlot.SLOT_PRIMARY)
    local pickupWithRoom = env.newSoulHeartPickup(HeartSubType.HEART_SOUL)
    local resultWithRoom = collide(env.mod, pickupWithRoom, player, false)
    assertEquals(resultWithRoom, nil, "soul hearts that fit should use vanilla pickup logic")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "fitting soul hearts should not charge Angelbox")
    assertEquals(pickupWithRoom.removed, false, "fitting soul hearts should not be removed by Angelbox")

    player.soulHearts = 3
    player.addedSoulHearts = 0
    player:SetActiveCharge(0, ActiveSlot.SLOT_PRIMARY)
    local partialPickup = env.newSoulHeartPickup(HeartSubType.HEART_SOUL)
    local partialResult = collide(env.mod, partialPickup, player, false)
    assertEquals(partialResult, true, "overflow pickup should skip vanilla pickup logic")
    assertEquals(player.addedSoulHearts, 1, "only the fitting half soul heart should be added to health")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 1, "overflow half soul heart should add one Angelbox charge")
    assertEquals(partialPickup.removed, true, "handled overflow pickup should be consumed")

    player.soulHearts = 4
    player.addedSoulHearts = 0
    player:SetActiveCharge(0, ActiveSlot.SLOT_PRIMARY)
    local fullOverflowPickup = env.newSoulHeartPickup(HeartSubType.HEART_SOUL)
    local fullOverflowResult = collide(env.mod, fullOverflowPickup, player, false)
    assertEquals(fullOverflowResult, true, "full overflow pickup should be handled by Angelbox")
    assertEquals(player.addedSoulHearts, 0, "full overflow pickup should not add health")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 2, "full soul heart overflow should add two Angelbox charges")
    assertEquals(fullOverflowPickup.removed, true, "full overflow pickup should be consumed")

    player.soulHearts = 4
    player:SetActiveCharge(2, ActiveSlot.SLOT_PRIMARY)
    collide(env.mod, env.newSoulHeartPickup(HeartSubType.HEART_SOUL), player, false)
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 4, "two full overflowing soul hearts should fully charge Angelbox")
end

local function test_charged_repeat_use_forces_angel_room_and_spawns_one_quality_four_reward()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6, activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 } })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    env.itemPool.angelItems = {
        72,
        CollectibleType.COLLECTIBLE_GODHEAD,
    }

    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)

    local repeatResult = useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(repeatResult, true, "charged repeat Angelbox use should succeed")
    assertEquals(#env.level.initializeCalls, 1, "repeat Angelbox use should initialize the deal room")
    assertEquals(env.level.initializeCalls[1].forceAngel, true, "repeat Angelbox use should force angel room")
    assertEquals(env.level.initializeCalls[1].forceDevil, false, "repeat Angelbox use should not force devil room")
    assertEquals(env.level.angelRoomChanceDelta, 1, "repeat Angelbox use should push this floor's deal chance toward guaranteed angel room")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "repeat Angelbox use should spend charge")

    env.room.roomType = RoomType.ROOM_ANGEL
    runPostNewRoom(env)
    assertEquals(#env.spawned, 1, "entering angel room should spawn one extra reward")
    assertEquals(env.spawned[1].Type, EntityType.ENTITY_PICKUP, "extra reward should be a pickup")
    assertEquals(env.spawned[1].Variant, PickupVariant.PICKUP_COLLECTIBLE, "extra reward should be a collectible pedestal")
    assertEquals(env.spawned[1].SubType, CollectibleType.COLLECTIBLE_GODHEAD, "extra reward should use a random quality four angel item from the pool")
    assertEquals(env.itemPool.requests[1].seed == env.itemPool.requests[2].seed, false, "quality-four search should vary item pool seeds")

    runPostNewRoom(env)
    assertEquals(#env.spawned, 1, "angel room reward should only spawn once per charged use")
end

local function test_three_charge_repeat_angelbox_use_does_not_fire()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6, activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 } })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(3, ActiveSlot.SLOT_PRIMARY)

    local repeatResult = useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(repeatResult, false, "Angelbox should require all 4 charges for repeat use")
    assertEquals(#env.level.initializeCalls, 0, "undercharged Angelbox should not force angel room")
end

local function test_angelbox_reward_fallback_is_not_fixed_to_sacred_heart()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    env.itemPool.angelItems = {}
    env.itemPool.fallbackItem = 72
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    env.room.roomType = RoomType.ROOM_ANGEL
    runPostNewRoom(env)

    assertEquals(#env.spawned, 1, "fallback should still spawn one reward")
    assertEquals(env.spawned[1].SubType == CollectibleType.COLLECTIBLE_SACRED_HEART, false, "fallback should not be hardwired to Sacred Heart")
end

local function test_different_players_can_each_add_one_angel_room_reward()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111, maxHearts = 6 })
    local playerB = env.newPlayer({ initSeed = 222, maxHearts = 4 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    env.itemPool.seedOrderItems = {
        CollectibleType.COLLECTIBLE_GODHEAD,
        CollectibleType.COLLECTIBLE_REVELATION,
    }

    useAngelbox(env.mod, env.items.Angelbox, nil, playerA, 0, ActiveSlot.SLOT_PRIMARY, 0)
    playerA:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, playerA, 0, ActiveSlot.SLOT_PRIMARY, 0)

    useAngelbox(env.mod, env.items.Angelbox, nil, playerB, 0, ActiveSlot.SLOT_PRIMARY, 0)
    playerB:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, playerB, 0, ActiveSlot.SLOT_PRIMARY, 0)

    env.room.roomType = RoomType.ROOM_ANGEL
    runPostNewRoom(env)
    assertEquals(#env.spawned, 2, "two different players should each contribute one extra angel reward")
    assertEquals(env.spawned[1].SubType, CollectibleType.COLLECTIBLE_GODHEAD, "first reward should use the first quality-four candidate")
    assertEquals(env.spawned[2].SubType, CollectibleType.COLLECTIBLE_REVELATION, "second reward should prefer a different quality-four candidate")
end

local function test_same_player_only_adds_one_angel_room_reward_per_floor()
    local env = loadNeverbirth()
    local player = env.newPlayer({ initSeed = 111, maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    env.room.roomType = RoomType.ROOM_ANGEL
    runPostNewRoom(env)
    assertEquals(#env.spawned, 1, "the same player should only contribute one extra angel reward per floor")
end

local function test_repeat_use_after_angel_room_was_entered_does_not_add_reward()
    local env = loadNeverbirth()
    local player = env.newPlayer({ initSeed = 111, maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    env.room.roomType = RoomType.ROOM_ANGEL
    runPostNewRoom(env)

    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    runPostNewRoom(env)

    assertEquals(#env.spawned, 0, "using Angelbox after this floor's angel room was entered should not add a reward")
end

local function test_angelbox_deal_chance_is_applied_once_and_removed_when_lost()
    local env = loadNeverbirth()
    local player = env.newPlayer({ activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Angelbox } })

    runPostUpdates(env, 2)
    assertEquals(env.level.angelRoomChanceDelta, 0.5, "held Angelbox should add one angel room chance modifier")

    player.activeItems[ActiveSlot.SLOT_PRIMARY] = 0
    runPostUpdates(env, 1)
    assertEquals(env.level.angelRoomChanceDelta, 0, "losing Angelbox should remove its angel room chance modifier")
end

local function test_first_use_does_not_upgrade_held_chance_to_guaranteed_angel_room()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    runPostUpdates(env, 1)
    assertEquals(env.level.angelRoomChanceDelta, 0.5, "held Angelbox should convert half the deal direction to angel")

    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    runPostUpdates(env, 1)

    assertEquals(env.level.angelRoomChanceDelta, 0.5, "first Angelbox use should not force 100% angel room")
    assertEquals(#env.level.initializeCalls, 0, "first Angelbox use should not initialize the deal room")
end

local function test_repeat_use_upgrades_held_chance_to_one_without_stacking()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    runPostUpdates(env, 1)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(env.level.angelRoomChanceDelta, 1, "repeat use should upgrade total Angelbox chance modifier to one, not stack to 1.5")
end

local function test_repeat_use_keeps_guaranteed_angel_room_after_losing_angelbox()
    local env = loadNeverbirth()
    local player = env.newPlayer({ maxHearts = 6 })
    local useAngelbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Angelbox)

    runPostUpdates(env, 1)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useAngelbox(env.mod, env.items.Angelbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player.activeItems[ActiveSlot.SLOT_PRIMARY] = 0
    runPostUpdates(env, 1)

    assertEquals(env.level.angelRoomChanceDelta, 1, "forced Angelbox chance should stay for the floor after losing the item")
end

local function test_devilbox_first_use_grants_one_full_black_heart_per_red_container()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        maxHearts = 6,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local useDevilbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Devilbox)

    local result = useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    assertEquals(result, true, "first Devilbox use should succeed")
    assertEquals(player.addedBlackHearts, 6, "three red heart containers should grant three full black hearts")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "first Devilbox use should spend its charge")
end

local function test_black_heart_pickups_only_charge_devilbox_overflow()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        maxHearts = 20,
        soulHearts = 0,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local useDevilbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Devilbox)

    useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)

    player.soulHearts = 0
    player.addedBlackHearts = 0
    player:SetActiveCharge(0, ActiveSlot.SLOT_PRIMARY)
    local pickupWithRoom = env.newBlackHeartPickup()
    local resultWithRoom = runPickupCollision(env, pickupWithRoom, player)
    assertEquals(resultWithRoom, nil, "black hearts that fit should use vanilla pickup logic")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "fitting black hearts should not charge Devilbox")

    player.soulHearts = 3
    player.addedBlackHearts = 0
    player:SetActiveCharge(0, ActiveSlot.SLOT_PRIMARY)
    local partialPickup = env.newBlackHeartPickup()
    local partialResult = runPickupCollision(env, partialPickup, player)
    assertEquals(partialResult, true, "overflow black heart should skip vanilla pickup logic")
    assertEquals(player.addedBlackHearts, 1, "only the fitting half black heart should be added to health")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 1, "overflow half black heart should add one Devilbox charge")

    player.soulHearts = 4
    player.addedBlackHearts = 0
    player:SetActiveCharge(0, ActiveSlot.SLOT_PRIMARY)
    local fullOverflowPickup = env.newBlackHeartPickup()
    local fullOverflowResult = runPickupCollision(env, fullOverflowPickup, player)
    assertEquals(fullOverflowResult, true, "full overflow black heart should be handled by Devilbox")
    assertEquals(player.addedBlackHearts, 0, "full overflow black heart should not add health")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 2, "full black heart overflow should add two Devilbox charges")

    player.soulHearts = 4
    player:SetActiveCharge(2, ActiveSlot.SLOT_PRIMARY)
    runPickupCollision(env, env.newBlackHeartPickup(), player)
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 4, "two full overflowing black hearts should fully charge Devilbox")
end

local function test_devilbox_repeat_use_forces_devil_room_and_spawns_quality_three_reward()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        maxHearts = 6,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local useDevilbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Devilbox)
    env.itemPool.devilItems = {
        CollectibleType.COLLECTIBLE_INCUBUS,
        72,
        CollectibleType.COLLECTIBLE_DARK_BUM,
    }

    useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)

    local repeatResult = useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(repeatResult, true, "charged repeat Devilbox use should succeed")
    assertEquals(#env.level.initializeCalls, 1, "repeat Devilbox use should initialize the deal room")
    assertEquals(env.level.initializeCalls[1].forceAngel, false, "repeat Devilbox use should not force angel room")
    assertEquals(env.level.initializeCalls[1].forceDevil, true, "repeat Devilbox use should force devil room")
    assertEquals(env.level.angelRoomChanceDelta, -1, "repeat Devilbox use should push this floor's deal chance toward guaranteed devil room")
    assertEquals(env.level.dataWasClearedBeforeInitialize, true, "repeat Devilbox use should clear any pre-initialized deal room before forcing devil room")
    assertEquals(env.level.dealRoomDesc.Data.Type, RoomType.ROOM_DEVIL, "repeat Devilbox use should leave the initialized deal room as devil")
    assertEquals(env.gameStateFlags[GameStateFlag.STATE_DEVILROOM_SPAWNED], false, "repeat Devilbox use should reset spawned state so angel direction is stripped")
    assertEquals(env.gameStateFlags[GameStateFlag.STATE_DEVILROOM_VISITED], false, "repeat Devilbox use should reset visited state so the floor points back to devil")

    env.room.roomType = RoomType.ROOM_DEVIL
    runPostNewRoom(env)
    assertEquals(#env.spawned, 1, "entering devil room should spawn one extra reward")
    assertEquals(env.spawned[1].Variant, PickupVariant.PICKUP_COLLECTIBLE, "extra devil reward should be a collectible pedestal")
    assertEquals(env.spawned[1].SubType, CollectibleType.COLLECTIBLE_DARK_BUM, "extra devil reward should use a random quality three devil item from the pool")
    assertEquals(env.itemPool.requests[1].seed == env.itemPool.requests[2].seed, false, "devil quality-three search should vary item pool seeds")
end

local function test_three_charge_repeat_devilbox_use_does_not_fire()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        maxHearts = 6,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local useDevilbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Devilbox)

    useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(3, ActiveSlot.SLOT_PRIMARY)

    local repeatResult = useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(repeatResult, false, "Devilbox should require all 4 charges for repeat use")
    assertEquals(#env.level.initializeCalls, 0, "undercharged Devilbox should not force devil room")
end

local function test_different_players_can_each_add_one_devil_room_reward()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({
        initSeed = 111,
        maxHearts = 6,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local playerB = env.newPlayer({
        initSeed = 222,
        maxHearts = 4,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local useDevilbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Devilbox)

    env.itemPool.devilSeedOrderItems = {
        CollectibleType.COLLECTIBLE_DARK_BUM,
        CollectibleType.COLLECTIBLE_SATANIC_BIBLE,
    }

    useDevilbox(env.mod, env.items.Devilbox, nil, playerA, 0, ActiveSlot.SLOT_PRIMARY, 0)
    playerA:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useDevilbox(env.mod, env.items.Devilbox, nil, playerA, 0, ActiveSlot.SLOT_PRIMARY, 0)

    useDevilbox(env.mod, env.items.Devilbox, nil, playerB, 0, ActiveSlot.SLOT_PRIMARY, 0)
    playerB:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useDevilbox(env.mod, env.items.Devilbox, nil, playerB, 0, ActiveSlot.SLOT_PRIMARY, 0)

    env.room.roomType = RoomType.ROOM_DEVIL
    runPostNewRoom(env)
    assertEquals(#env.spawned, 2, "two different players should each contribute one extra devil reward")
    assertEquals(env.spawned[1].SubType, CollectibleType.COLLECTIBLE_DARK_BUM, "first devil reward should use the first quality-three candidate")
    assertEquals(env.spawned[2].SubType, CollectibleType.COLLECTIBLE_SATANIC_BIBLE, "second devil reward should prefer a different quality-three candidate")
end

local function test_devilbox_held_and_forced_chance_do_not_stack_wrong()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        maxHearts = 6,
        activeItems = { [ActiveSlot.SLOT_PRIMARY] = env.items.Devilbox },
        activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 4 },
    })
    local useDevilbox = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.Devilbox)

    runPostUpdates(env, 1)
    assertEquals(env.level.angelRoomChanceDelta, -0.5, "held Devilbox should convert half the deal direction to devil")

    useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    player:SetActiveCharge(4, ActiveSlot.SLOT_PRIMARY)
    useDevilbox(env.mod, env.items.Devilbox, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    assertEquals(env.level.angelRoomChanceDelta, -1, "repeat Devilbox use should upgrade total modifier to -1, not stack to -1.5")

    player.activeItems[ActiveSlot.SLOT_PRIMARY] = 0
    runPostUpdates(env, 1)
    assertEquals(env.level.angelRoomChanceDelta, -1, "forced Devilbox chance should stay for the floor after losing the item")
end

test_devilbox_is_quality_four_and_angelbox_stays_quality_three()
test_angelbox_grants_three_luck_while_held()
test_box_heart_spawn_bonus_rolls_are_independent_and_non_recursive()
test_angelbox_heart_bonus_miss_and_devilbox_hit_thresholds()
test_multiple_same_box_holders_do_not_stack_same_bonus()
test_box_xml_charges_are_four_and_start_full()
test_first_use_grants_one_full_soul_heart_per_red_container()
test_first_use_is_tracked_per_player()
test_soul_heart_pickups_only_charge_overflow()
test_charged_repeat_use_forces_angel_room_and_spawns_one_quality_four_reward()
test_three_charge_repeat_angelbox_use_does_not_fire()
test_angelbox_reward_fallback_is_not_fixed_to_sacred_heart()
test_different_players_can_each_add_one_angel_room_reward()
test_same_player_only_adds_one_angel_room_reward_per_floor()
test_repeat_use_after_angel_room_was_entered_does_not_add_reward()
test_angelbox_deal_chance_is_applied_once_and_removed_when_lost()
test_first_use_does_not_upgrade_held_chance_to_guaranteed_angel_room()
test_repeat_use_upgrades_held_chance_to_one_without_stacking()
test_repeat_use_keeps_guaranteed_angel_room_after_losing_angelbox()
test_devilbox_first_use_grants_one_full_black_heart_per_red_container()
test_black_heart_pickups_only_charge_devilbox_overflow()
test_devilbox_repeat_use_forces_devil_room_and_spawns_quality_three_reward()
test_three_charge_repeat_devilbox_use_does_not_fire()
test_different_players_can_each_add_one_devil_room_reward()
test_devilbox_held_and_forced_chance_do_not_stack_wrong()

print("angelbox behavior tests passed")
