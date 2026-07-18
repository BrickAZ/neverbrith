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

local function loadNeverbirth(options)
    options = options or {}
    local callbacks = {}
    local savedData = options.savedData or "{}"
    local players = {}
    local roomEntities = {}
    local hudMessages = {}
    local debugMessages = {}
    local itemIds = {
        Condom = 746,
        UtilityKnife = 747,
        CrazyCoconut = 748,
        FortuneRivallingHeavenGu = 749,
        Needletick = 750,
        BabyA = 101,
        DamageItem = 202,
        DamageDeclaredNonDamage = 203,
        BabyB = 102,
        BabyC = 103,
        NonBaby = 201,
    }

    local decodedData = options.decodedData or {}
    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function(value)
                savedData = value
                return "<json>"
            end,
            decode = function()
                return decodedData
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
        MC_POST_PICKUP_INIT = 11,
        MC_POST_ADD_COLLECTIBLE = 13,
    }
    CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_PLAN_C = 475 }
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SHOTSPEED = 2, CACHE_TEARCOLOR = 4, CACHE_SPEED = 8, CACHE_FIREDELAY = 16, CACHE_TEARFLAG = 32, CACHE_RANGE = 64, CACHE_LUCK = 1024 }
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_NOKILL = 2, DAMAGE_INVINCIBLE = 4 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_EFFECT = 1000 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
    GameStateFlag = { STATE_DEVILROOM_SPAWNED = 5, STATE_DEVILROOM_VISITED = 6 }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2, SLOT_POCKET2 = 3 }
    ItemConfig = { TAG_BABY = 1 }
    Card = { RUNE_HAGALAZ = 32, RUNE_BLACK = 41, RUNE_SHARD = 55, CARD_SOUL_ISAAC = 81, CARD_SOUL_JACOB = 97 }
    Options = { Language = options.language or "en" }

    local itemConfigs = {
        [itemIds.BabyA] = { ID = itemIds.BabyA, Tags = ItemConfig.TAG_BABY },
        [itemIds.BabyB] = { ID = itemIds.BabyB, Tags = ItemConfig.TAG_BABY },
        [itemIds.BabyC] = { ID = itemIds.BabyC, Tags = ItemConfig.TAG_BABY },
        [itemIds.NonBaby] = { ID = itemIds.NonBaby, Tags = 0, CacheFlags = 0 },
        [itemIds.DamageItem] = { ID = itemIds.DamageItem, Tags = 0, CacheFlags = CacheFlag.CACHE_DAMAGE },
        [itemIds.DamageDeclaredNonDamage] = { ID = itemIds.DamageDeclaredNonDamage, Tags = 0, CacheFlags = CacheFlag.CACHE_DAMAGE },
        [itemIds.CrazyCoconut] = { ID = itemIds.CrazyCoconut, Tags = 0, CacheFlags = CacheFlag.CACHE_DAMAGE },
        [itemIds.FortuneRivallingHeavenGu] = { ID = itemIds.FortuneRivallingHeavenGu, Tags = 0, CacheFlags = CacheFlag.CACHE_LUCK },
    }

    local poolSequence = options.poolSequence or { itemIds.BabyB, itemIds.NonBaby }
    local poolIndex = 0

    function MusicManager()
        return { GetCurrentMusicID = function() return 1 end, Play = function() end, Fadeout = function() end }
    end

    function Game()
        return {
            GetSeeds = function()
                return { GetStartSeedString = function() return "TEST RUN" end }
            end,
            GetNumPlayers = function()
                return #players
            end,
            GetItemPool = function()
                return {
                    GetCollectible = function()
                        poolIndex = poolIndex + 1
                        return poolSequence[poolIndex] or itemIds.NonBaby
                    end,
                }
            end,
            GetHUD = function()
                return {
                    ShowItemText = function(_, title, subtitle)
                        hudMessages[#hudMessages + 1] = { title = title, subtitle = subtitle }
                    end,
                }
            end,
            GetRoom = function()
                return { GetSpawnSeed = function() return 5000 end, GetType = function() return RoomType.ROOM_DEFAULT end, IsClear = function() return false end }
            end,
            GetLevel = function()
                return { GetStage = function() return 1 end, GetStageType = function() return 0 end, GetCurrentRoomIndex = function() return 0 end, AddAngelRoomChance = function() end, InitializeDevilAngelRoom = function() end }
            end,
            Spawn = function() end,
            GetStateFlag = function() return false end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Condom" or name == "避孕套" then
                return itemIds.Condom
            end
            if name == "Utility Knife" or name == "美工刀" then
                return itemIds.UtilityKnife
            end
            if name == "Crazy Coconut" or name == "疯狂的椰子" then
                return itemIds.CrazyCoconut
            end
            if name == "Fortune Rivalling Heaven Gu" or name == "鸿运齐天蛊" then
                return itemIds.FortuneRivallingHeavenGu
            end
            if name == "Needletick" or name == "虚空针尖" then
                return itemIds.Needletick
            end
            return itemIds[name] or -1
        end,
        GetMusicIdByName = function(name)
            if name == "MusicboxTheme" then
                return 736
            end
            return -1
        end,
        GetPlayer = function(index)
            return players[(index or 0) + 1]
        end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then
                return players
            end
            return {}
        end,
        GetRoomEntities = function()
            return roomEntities
        end,
        DebugString = function(message) debugMessages[#debugMessages + 1] = tostring(message) end,
        Spawn = function() end,
        GetItemConfig = function()
            return {
                GetCollectible = function(_, itemId)
                    return itemConfigs[itemId]
                end,
                GetCollectibles = function()
                    return {
                        Size = 749,
                        itemConfigs[itemIds.BabyA],
                        itemConfigs[itemIds.BabyB],
                        itemConfigs[itemIds.BabyC],
                        itemConfigs[itemIds.NonBaby],
                        itemConfigs[itemIds.DamageItem],
                        itemConfigs[itemIds.DamageDeclaredNonDamage],
                        itemConfigs[itemIds.CrazyCoconut],
                    }
                end,
            }
        end,
    }

    Color = setmetatable({}, { __call = function(_, r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo } end })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)
    local vectorMeta = { __add = function(left, right) return Vector(left.X + right.X, left.Y + right.Y) end }
    function Vector(x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, vectorMeta)
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
            return options.hasData == true
        end
        function mod:LoadData()
            return "{}"
        end
        function mod:SaveData(data)
            savedData = data
        end
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

    local function runUseCondom(player)
        local callback = getCallbacks(ModCallbacks.MC_USE_ITEM, itemIds.Condom)[1]
        assertTruthy(callback, "Condom use callback should be registered")
        return callback(mod, itemIds.Condom, nil, player, 0, ActiveSlot.SLOT_PRIMARY, 0)
    end

    local function runEvaluate(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
            callback(mod, player, cacheFlag)
        end
    end

    local function runPostAddUtilityKnife(player)
        local callback = getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemIds.UtilityKnife)[1]
        assertTruthy(callback, "Utility Knife pickup callback should be registered")
        callback(mod, itemIds.UtilityKnife, 0, true, ActiveSlot.SLOT_PRIMARY, 0, player)
    end

    local function runPostAddCollectible(itemId, player)
        local ran = false
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemId)) do
            callback(mod, itemId, 0, true, ActiveSlot.SLOT_PRIMARY, 0, player)
            ran = true
        end
        assertTruthy(ran, "post-add collectible callback should run")
    end

    local function runPostAddCollectibleWithoutPlayer(itemId)
        local ran = false
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemId)) do
            callback(mod, itemId, 0, true, ActiveSlot.SLOT_PRIMARY, 0)
            ran = true
        end
        assertTruthy(ran, "post-add collectible callback without player should run")
    end

    local function runPickupInit(pickup)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_PICKUP_INIT, PickupVariant.PICKUP_COLLECTIBLE)) do
            callback(mod, pickup)
        end
    end

    local function runCollectiblePickup(pickup, player)
        local result = nil
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_PICKUP_COLLISION, PickupVariant.PICKUP_COLLECTIBLE)) do
            result = callback(mod, pickup, player, false)
        end
        return result
    end

    local function runPostUpdate()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do
            callback(mod)
        end
    end

    local function newPlayer(optionsForPlayer)
        optionsForPlayer = optionsForPlayer or {}
        local player = {
            InitSeed = optionsForPlayer.initSeed or (#players + 100),
            Position = Vector(100, 100),
            Damage = optionsForPlayer.damage or 3.5,
            Luck = optionsForPlayer.luck or 0,
            collectibles = optionsForPlayer.collectibles or {},
            trinkets = optionsForPlayer.trinkets or {},
            QueuedItem = { Item = nil },
            brokenHearts = 0,
            rngSequence = optionsForPlayer.rngSequence or { 0, 0, 0 },
            rngIndex = 0,
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:GetTrinketMultiplier(trinketId) return self.trinkets[trinketId] or 0 end
        function player:HasTrinket(trinketId) return (self.trinkets[trinketId] or 0) > 0 end
        function player:IsItemQueueEmpty() return self.QueuedItem.Item == nil end
        function player:GetCollectibleRNG()
            return {
                RandomInt = function(_, max)
                    player.rngIndex = player.rngIndex + 1
                    return (player.rngSequence[player.rngIndex] or 0) % max
                end,
            }
        end
        function player:AddBrokenHearts(amount) self.brokenHearts = self.brokenHearts + amount end
        function player:AddCacheFlags() end
        function player:EvaluateItems() end
        function player:GetActiveItem() return 0 end
        function player:GetActiveCharge() return 0 end
        players[#players + 1] = player
        return player
    end

    local function newPickup(subtype)
        local pickup = {
            Type = EntityType.ENTITY_PICKUP,
            Variant = PickupVariant.PICKUP_COLLECTIBLE,
            SubType = subtype,
            Position = Vector(120, 120),
            morphs = {},
        }
        function pickup:ToPickup() return self end
        function pickup:GetData() self.data = self.data or {}; return self.data end
        function pickup:Exists() return not self.removed end
        function pickup:Remove() self.removed = true end
        function pickup:Morph(entityType, variant, subtype, seed, preservePrice, preserveSeed, ignoreModifiers)
            self.morphs[#self.morphs + 1] = { entityType = entityType, variant = variant, subtype = subtype, seed = seed, preservePrice = preservePrice, preserveSeed = preserveSeed, ignoreModifiers = ignoreModifiers }
            self.SubType = subtype
        end
        return pickup
    end

    return {
        items = itemIds,
        hudMessages = hudMessages,
        debugMessages = debugMessages,
        newPlayer = newPlayer,
        newPickup = newPickup,
        callbackRegistrations = callbacks,
        runUseCondom = runUseCondom,
        runEvaluate = runEvaluate,
        runPostAddUtilityKnife = runPostAddUtilityKnife,
        runPostAddCollectible = runPostAddCollectible,
        runPostAddCollectibleWithoutPlayer = runPostAddCollectibleWithoutPlayer,
        runPostUpdate = runPostUpdate,
        runPickupInit = runPickupInit,
        runCollectiblePickup = runCollectiblePickup,
        savedData = function() return savedData end,
        mod = mod,
    }
end

local function test_xml_registers_requested_items_and_pools()
    local items = readFile("content/items.xml")
    local pools = readFile("content/itempools.xml")
    local main = readFile("main.lua")

    assertTruthy(items:find('<active%s+name="Condom".-maxcharges="3".-description="It does not count".-gfx="Condom.png".-quality="0"', 1), "Condom XML should be a 3-charge quality 0 active")
    assertTruthy(items:find('<passive%s+name="Utility Knife".-cache="damage".-description="Painful scars".-gfx="UtilityKnife.png".-quality="2".-tags="offensive summonable"', 1), "Utility Knife XML should be a damage passive with requested tags")
    assertTruthy(pools:find('<Pool Name="oldChest".-<Item Name="Condom" Weight="1"', 1), "Condom should be in oldChest pool")
    assertTruthy(pools:find('<Pool Name="boss".-<Item Name="Utility Knife" Weight="1"', 1), "Utility Knife should be in boss pool")
    assertTruthy(items:find('<passive%s+name="Crazy Coconut".-cache="damage".-description="King of hollow earth".-gfx="CrazyCoconut.png".-quality="4".-tags="offensive"', 1), "Crazy Coconut XML should be a quality 4 damage-cache passive")
    assertTruthy(pools:find('<Pool Name="treasure".-<Item Name="Crazy Coconut" Weight="1"', 1), "Crazy Coconut should be in treasure pool")
    assertTruthy(main:find('eidDescription = "{{Damage}} Each copy: +3 permanent damage#Afterwards, every pedestal item that does not increase actual damage grants +3 permanent damage per copy"', 1, true),
        "Crazy Coconut English EID should describe per-copy rewards and actual damage comparison")
    assertTruthy(main:find('eidDescription = "{{Damage}} 每个副本永久+3攻击力#之后，从道具底座拿到的每个实际不增加攻击力的道具：每个副本永久+3攻击力"', 1, true),
        "Crazy Coconut Chinese EID should describe per-copy rewards and pedestal scope")
end

local function test_utility_knife_adds_damage_and_grants_one_broken_heart_per_pickup()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.UtilityKnife] = 1 } })

    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 4.5, "Utility Knife should add +1 damage")

    env.runPostAddUtilityKnife(player)
    env.runPostAddUtilityKnife(player)
    assertEquals(player.brokenHearts, 2, "Utility Knife should grant one broken heart every time it is picked up")
end

local function test_utility_knife_pickup_accepts_wrapped_player_argument()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.UtilityKnife] = 1 } })
    local wrapper = {
        ToPlayer = function()
            return player
        end,
    }

    env.mod:GrantUtilityKnifeBrokenHeart(env.items.UtilityKnife, 0, true, ActiveSlot.SLOT_PRIMARY, 0, wrapper)

    assertEquals(player.brokenHearts, 1, "Utility Knife should resolve ToPlayer callback arguments before granting broken hearts")
end

local function test_utility_knife_post_update_fallback_grants_broken_heart_for_new_copies()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = {} })

    env.runPostUpdate()
    player.collectibles[env.items.UtilityKnife] = 1
    env.runPostUpdate()
    assertEquals(player.brokenHearts, 1, "Utility Knife fallback should grant a broken heart when the item count increases")

    player.collectibles[env.items.UtilityKnife] = 3
    env.runPostUpdate()
    assertEquals(player.brokenHearts, 3, "Utility Knife fallback should grant one broken heart per new copy")
end

local function test_crazy_coconut_rewards_collectibles_that_do_not_actually_increase_damage()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    env.runPostUpdate()
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 6.5, "Crazy Coconut should count its own pickup as one +3 damage layer")

    local nonBabyPickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(nonBabyPickup, player)
    nonBabyPickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 9.5, "a pickup that leaves actual damage unchanged should add another +3 layer")

    -- Simulate a genuine +1 damage pickup after the two existing +3 layers.
    player.Damage = 9.5
    local damagePickup = env.newPickup(env.items.DamageItem)
    env.runCollectiblePickup(damagePickup, player)
    damagePickup:Remove()
    player.collectibles[env.items.DamageItem] = 1
    player.Damage = 10.5
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 4.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 10.5, "a pickup that actually raises damage must not add a Crazy Coconut layer")

    -- CACHE_DAMAGE alone is not proof that a pickup raised Damage.
    player.Damage = 10.5
    local declaredPickup = env.newPickup(env.items.DamageDeclaredNonDamage)
    env.runCollectiblePickup(declaredPickup, player)
    declaredPickup:Remove()
    player.collectibles[env.items.DamageDeclaredNonDamage] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 4.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 13.5, "a damage-cache pickup with no actual damage gain should still add a Crazy Coconut layer")
end
local function test_crazy_coconut_uses_pickup_snapshots_not_global_item_enumeration()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    local forbiddenGlobalScanHelpers = {
        "GetCrazyCoconutKnownItemIds",
        "CaptureCrazyCoconutItemCounts",
        "DetectCrazyCoconutInventoryChanges",
        "EnsureCrazyCoconutItemCounts",
        "RecordCrazyCoconutUnresolvedAdd",
    }
    local source = readFile("main.lua")
    for _, helperName in ipairs(forbiddenGlobalScanHelpers) do
        assertEquals(env.mod[helperName], nil, "Crazy Coconut must not expose global inventory scan helper " .. helperName)
        assertTruthy(not source:find("function Neverbirth:" .. helperName, 1, true),
            "Crazy Coconut source must not define global inventory scan helper " .. helperName)
    end

    env.runPostUpdate()
    local pickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(pickup, player)
    pickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)

    assertEquals(player.Damage, 9.5,
        "a normal pedestal pickup with unchanged damage should settle from its pre-pickup snapshot")
end

local function test_crazy_coconut_records_ground_collectible_pickups_before_they_are_added()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    env.runPostUpdate()
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    local pickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(pickup, player)
    pickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()

    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 9.5, "a normal ground collectible with no damage gain should add one Crazy Coconut layer")

    local sawCollision = false
    local sawSettlement = false
    for _, message in ipairs(env.debugMessages) do
        sawCollision = sawCollision or message:find('%[pre%-pickup%-collision%]') ~= nil
        sawSettlement = sawSettlement or (message:find('%[cache%-settlement%]') ~= nil and message:find('reward=true') ~= nil)
    end
    assertTruthy(sawCollision, "ground pickup trace should prove the pre-collision callback fired")
    assertTruthy(sawSettlement, "ground pickup trace should prove the cache settlement rewarded the item")
end

local function test_crazy_coconut_post_update_recovers_missed_initial_pickup()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    local coconutPostAddCallbacks = 0
    for _, registration in ipairs(env.callbackRegistrations[ModCallbacks.MC_POST_ADD_COLLECTIBLE] or {}) do
        if registration.param == env.items.CrazyCoconut then
            coconutPostAddCallbacks = coconutPostAddCallbacks + 1
        end
    end
    assertEquals(coconutPostAddCallbacks, 0,
        "Crazy Coconut must not depend on MC_POST_ADD_COLLECTIBLE for its own damage layer")

    env.runPostUpdate()
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 6.5, "post-update tracking should grant Crazy Coconut's own +3 layer in a normal callback environment")

    -- Keep the already evaluated panel value through the next update; the test stub
    -- resets to base only immediately before the next cache evaluation.
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 6.5, "post-update fallback must not grant the same Crazy Coconut copy twice")
end

local function test_crazy_coconut_layers_scale_with_copies()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 2 } })

    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 9.5, "two Crazy Coconut copies should grant two self layers")

    local nonBabyPickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(nonBabyPickup, player)
    nonBabyPickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 15.5, "two Crazy Coconut copies should add two more layers from one qualifying pickup")
end

local function test_crazy_coconut_does_not_reward_the_same_pedestal_twice()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    env.runPostUpdate()
    local pickup = env.newPickup(env.items.NonBaby)
    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "Crazy Coconut pre-pickup collision must not cancel a normal pedestal pickup")
    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "Repeated collision with the same pedestal must still not cancel pickup")
    pickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 9.5,
        "The same pedestal collision must settle as exactly one Crazy Coconut reward")
end

local function test_crazy_coconut_waits_for_a_delayed_pedestal_pickup()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    env.runPostUpdate()
    local pickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(pickup, player)
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    pickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)

    assertEquals(player.Damage, 9.5,
        "Crazy Coconut must settle a pedestal pickup that joins the player after the initial two-frame wait")
end

local function test_crazy_coconut_confirms_a_pedestal_through_the_player_item_queue()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    env.runPostUpdate()
    local pickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(pickup, player)

    player.QueuedItem.Item = { ID = env.items.NonBaby }
    env.runPostUpdate()
    player.QueuedItem.Item = nil
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)

    assertEquals(player.Damage, 9.5,
        "Crazy Coconut must settle a normal pedestal when its matching player item queue flushes")
end

local function test_crazy_coconut_discards_a_removed_pedestal_without_a_pickup()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, collectibles = { [env.items.CrazyCoconut] = 1 } })

    env.runPostUpdate()
    local pickup = env.newPickup(env.items.NonBaby)
    env.runCollectiblePickup(pickup, player)
    pickup:Remove()
    env.runPostUpdate()

    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()
    player.Damage = 3.5
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)

    assertEquals(player.Damage, 6.5,
        "A removed pedestal that never added its item must not reward a later unrelated item gain")
end

local function test_condom_bans_up_to_two_unowned_baby_items_without_repeats()
    local env = loadNeverbirth()
    local player = env.newPlayer({ collectibles = { [env.items.BabyB] = 1 }, rngSequence = { 0, 0, 0 } })

    local result = env.runUseCondom(player)

    assertEquals(result, true, "Condom use should succeed when targets exist")
    assertEquals(env.mod:IsCondomBanned(env.items.BabyA), true, "first unowned baby item should be banned")
    assertEquals(env.mod:IsCondomBanned(env.items.BabyC), true, "second unowned baby item should be banned")
    assertEquals(env.mod:IsCondomBanned(env.items.BabyB), false, "owned baby item should not be banned")
end

local function test_condom_repeated_uses_can_exhaust_targets_and_show_feedback()
    local env = loadNeverbirth()
    local player = env.newPlayer({ rngSequence = { 0, 0, 0, 0, 0 } })

    env.runUseCondom(player)
    env.runUseCondom(player)
    env.runUseCondom(player)

    assertEquals(env.mod:IsCondomBanned(env.items.BabyA), true, "BabyA should stay banned")
    assertEquals(env.mod:IsCondomBanned(env.items.BabyB), true, "BabyB should stay banned")
    assertEquals(env.mod:IsCondomBanned(env.items.BabyC), true, "BabyC should stay banned")
    assertTruthy(#env.hudMessages >= 1, "empty target use should give HUD feedback when available")
end

local function test_condom_replaces_future_banned_collectible_pedestals()
    local env = loadNeverbirth({ poolSequence = { env and env.items and env.items.BabyA or 101, 201 } })
    local player = env.newPlayer({ rngSequence = { 0, 1 } })
    env.runUseCondom(player)
    local pickup = env.newPickup(env.items.BabyA)

    env.runPickupInit(pickup)

    assertEquals(pickup.SubType, env.items.NonBaby, "future banned baby pedestal should be rerolled to an allowed item")
    assertEquals(#pickup.morphs, 1, "replacement should morph the pickup once")
end

local function test_pickup_banner_immediately_uses_chinese_when_count_confirms_pickup()
    local env = loadNeverbirth({ language = "zh" })
    local player = env.newPlayer({ collectibles = {} })
    local pickup = env.newPickup(env.items.CrazyCoconut)

    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "pickup banner collision observer must not cancel the original pedestal pickup")
    pickup:Remove()
    player.collectibles[env.items.CrazyCoconut] = 1
    env.runPostUpdate()

    assertEquals(#env.hudMessages, 1, "count confirmation should replace the native banner in the first post-update")
    assertEquals(env.hudMessages[1].title, "疯狂的椰子", "Chinese game language should use the Chinese pickup name")
    assertEquals(env.hudMessages[1].subtitle, "空心地球之王", "Chinese game language should use the Chinese pickup subtitle")
end

local function test_pickup_banner_immediately_uses_chinese_when_queue_confirms_pickup()
    local env = loadNeverbirth({ language = "zh" })
    local player = env.newPlayer({ collectibles = {} })
    local pickup = env.newPickup(env.items.CrazyCoconut)

    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "pickup queue observer must not cancel the original pedestal pickup")
    player.QueuedItem.Item = { ID = env.items.CrazyCoconut }
    env.runPostUpdate()

    assertEquals(#env.hudMessages, 1, "matching item queue should replace the native banner in the first post-update")
    assertEquals(env.hudMessages[1].title, "疯狂的椰子", "queued pickup should immediately use the Chinese pickup name")
    assertEquals(env.hudMessages[1].subtitle, "空心地球之王", "queued pickup should immediately use the Chinese pickup subtitle")

    player.QueuedItem.Item = nil
    pickup:Remove()
    player.collectibles[env.items.CrazyCoconut] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    assertEquals(#env.hudMessages, 1, "queue and count confirmation must still settle the pedestal only once")
end

local function test_pickup_banner_leaves_native_english_untouched_and_deduplicates_collision()
    local env = loadNeverbirth({ language = "de" })
    local player = env.newPlayer({ collectibles = {} })
    local pickup = env.newPickup(env.items.CrazyCoconut)

    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "first pickup banner collision observer must return nil")
    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "repeated collision with the same pedestal must return nil")
    pickup:Remove()
    player.collectibles[env.items.CrazyCoconut] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()

    assertEquals(#env.hudMessages, 0, "non-Chinese languages should keep the native English banner without a custom redraw")
end
local function test_pickup_banner_ignores_non_neverbirth_collectibles()
    local env = loadNeverbirth({ language = "zh" })
    local player = env.newPlayer({ collectibles = {} })
    local pickup = env.newPickup(env.items.NonBaby)

    assertEquals(env.runCollectiblePickup(pickup, player), nil,
        "unregistered collectible collision must remain uncancelled")
    pickup:Remove()
    player.collectibles[env.items.NonBaby] = 1
    env.runPostUpdate()
    env.runPostUpdate()
    env.runPostUpdate()

    assertEquals(#env.hudMessages, 0, "non-Neverbirth collectibles must not receive a replacement banner")
end
local function test_fortune_rivalling_heaven_gu_uses_complete_audit_registry()
    local env = loadNeverbirth()
    local audit = env.mod.FortuneRivallingHeavenGu.auditRows
    assertEquals(#audit, 68, "the audit must retain the screenshot baseline plus Needletick")

    local blocked = 0
    local registeredPositive = 0
    local nextCollectibleId = 1000
    local nextTrinketId = 2000
    TrinketType = TrinketType or {}
    for _, auditRow in ipairs(audit) do
        if auditRow.kind == "trinket" then
            if not TrinketType[auditRow.enum] then
                TrinketType[auditRow.enum] = nextTrinketId
                nextTrinketId = nextTrinketId + 1
            end
        else
            if not CollectibleType[auditRow.enum] then
                CollectibleType[auditRow.enum] = nextCollectibleId
                nextCollectibleId = nextCollectibleId + 1
            end
        end
        if auditRow.condition and auditRow.condition:match("^COLLECTIBLE_") and not CollectibleType[auditRow.condition] then
            CollectibleType[auditRow.condition] = nextCollectibleId
            nextCollectibleId = nextCollectibleId + 1
        end
        if auditRow.verification == "BLOCKED" then
            blocked = blocked + 1
        end
        if auditRow.includeFortune then
            registeredPositive = registeredPositive + 1
        end
    end
    assertEquals(blocked, 0, "all screenshot rows must be resolved; no BLOCKED audit row is allowed")
    assertEquals(registeredPositive, 60, "all active positive rows, including Needletick, must be registered from the audit table")

    local needletickRow
    for _, auditRow in ipairs(audit) do
        if auditRow.en == "Needletick" then
            needletickRow = auditRow
            break
        end
    end
    assertTruthy(needletickRow ~= nil, "Needletick must have an audit row in the runtime source of truth")
    assertEquals(needletickRow.cap, 10, "Needletick must request its verified 10-luck cap")
    assertEquals(needletickRow.runtimeItemId, env.items.Needletick,
        "custom Neverbirth audit rows must carry their resolved runtime collectible ID")

    env.mod:RegisterVerifiedFortuneLuckCaps()
    local appleId = CollectibleType.COLLECTIBLE_APPLE
    local holyLightId = CollectibleType.COLLECTIBLE_HOLY_LIGHT
    local ludoId = CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE
    local momsEyeId = CollectibleType.COLLECTIBLE_MOMS_EYE
    local blackToothId = TrinketType.TRINKET_BLACK_TOOTH

    local low = env.newPlayer({ luck = 1, collectibles = {
        [env.items.FortuneRivallingHeavenGu] = 1,
        [appleId] = 1,
    } })
    env.runEvaluate(low, CacheFlag.CACHE_LUCK)
    assertEquals(low.Luck, 14, "one held low-threshold audited item must raise luck to its own cap")

    local multiple = env.newPlayer({ luck = 0, collectibles = {
        [env.items.FortuneRivallingHeavenGu] = 1,
        [appleId] = 1,
        [holyLightId] = 1,
    }, trinkets = { [blackToothId] = 2 } })
    env.runEvaluate(multiple, CacheFlag.CACHE_LUCK)
    assertEquals(multiple.Luck, 32, "collectibles and a golden/smelted trinket must share one maximum-threshold calculation")

    local synergy = env.newPlayer({ luck = 0, collectibles = {
        [env.items.FortuneRivallingHeavenGu] = 1,
        [momsEyeId] = 1,
        [ludoId] = 1,
    } })
    env.runEvaluate(synergy, CacheFlag.CACHE_LUCK)
    assertEquals(synergy.Luck, 10, "the Mom's Eye + Ludovico audit row must be evaluated through a resolver")

    local alreadyHigh = env.newPlayer({ luck = 99, collectibles = {
        [env.items.FortuneRivallingHeavenGu] = 1,
        [appleId] = 1,
    } })
    env.runEvaluate(alreadyHigh, CacheFlag.CACHE_LUCK)
    assertEquals(alreadyHigh.Luck, 99, "Fortune Rivalling Heaven Gu must never lower the original luck result")

    local noLuckyEffect = env.newPlayer({ luck = 2, collectibles = {
        [env.items.FortuneRivallingHeavenGu] = 1,
    } })
    env.runEvaluate(noLuckyEffect, CacheFlag.CACHE_LUCK)
    assertEquals(noLuckyEffect.Luck, 2, "holding no active audited lucky effect must not create luck from nothing")

    local needletick = env.newPlayer({ luck = 0, collectibles = {
        [env.items.FortuneRivallingHeavenGu] = 1,
        [env.items.Needletick] = 1,
    } })
    env.runEvaluate(needletick, CacheFlag.CACHE_LUCK)
    assertEquals(needletick.Luck, 10, "Needletick must raise Fortune Rivalling Heaven Gu's required luck to 10")
end
test_xml_registers_requested_items_and_pools()
test_pickup_banner_immediately_uses_chinese_when_count_confirms_pickup()
test_pickup_banner_immediately_uses_chinese_when_queue_confirms_pickup()
test_pickup_banner_leaves_native_english_untouched_and_deduplicates_collision()
test_pickup_banner_ignores_non_neverbirth_collectibles()
test_fortune_rivalling_heaven_gu_uses_complete_audit_registry()
test_utility_knife_adds_damage_and_grants_one_broken_heart_per_pickup()
test_utility_knife_pickup_accepts_wrapped_player_argument()
test_utility_knife_post_update_fallback_grants_broken_heart_for_new_copies()
test_crazy_coconut_rewards_collectibles_that_do_not_actually_increase_damage()
test_crazy_coconut_uses_pickup_snapshots_not_global_item_enumeration()
test_crazy_coconut_records_ground_collectible_pickups_before_they_are_added()
test_crazy_coconut_post_update_recovers_missed_initial_pickup()
test_crazy_coconut_layers_scale_with_copies()
test_crazy_coconut_does_not_reward_the_same_pedestal_twice()
test_crazy_coconut_waits_for_a_delayed_pedestal_pickup()
test_crazy_coconut_confirms_a_pedestal_through_the_player_item_queue()
test_crazy_coconut_discards_a_removed_pedestal_without_a_pickup()
test_condom_bans_up_to_two_unowned_baby_items_without_repeats()
test_condom_repeated_uses_can_exhaust_targets_and_show_feedback()
test_condom_replaces_future_banned_collectible_pedestals()

print("condom and utility knife behavior tests passed")
