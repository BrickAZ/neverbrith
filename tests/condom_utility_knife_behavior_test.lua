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
    local itemIds = {
        Condom = 746,
        UtilityKnife = 747,
        BabyA = 101,
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

    local itemConfigs = {
        [itemIds.BabyA] = { ID = itemIds.BabyA, Tags = ItemConfig.TAG_BABY },
        [itemIds.BabyB] = { ID = itemIds.BabyB, Tags = ItemConfig.TAG_BABY },
        [itemIds.BabyC] = { ID = itemIds.BabyC, Tags = ItemConfig.TAG_BABY },
        [itemIds.NonBaby] = { ID = itemIds.NonBaby, Tags = 0 },
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
        DebugString = function() end,
        Spawn = function() end,
        GetItemConfig = function()
            return {
                GetCollectible = function(_, itemId)
                    return itemConfigs[itemId]
                end,
                GetCollectibles = function()
                    return { itemConfigs[itemIds.BabyA], itemConfigs[itemIds.BabyB], itemConfigs[itemIds.BabyC], itemConfigs[itemIds.NonBaby] }
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

    local function runPickupInit(pickup)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_PICKUP_INIT, PickupVariant.PICKUP_COLLECTIBLE)) do
            callback(mod, pickup)
        end
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
            collectibles = optionsForPlayer.collectibles or {},
            brokenHearts = 0,
            rngSequence = optionsForPlayer.rngSequence or { 0, 0, 0 },
            rngIndex = 0,
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
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
        function pickup:Morph(entityType, variant, subtype, seed, preservePrice, preserveSeed, ignoreModifiers)
            self.morphs[#self.morphs + 1] = { entityType = entityType, variant = variant, subtype = subtype, seed = seed, preservePrice = preservePrice, preserveSeed = preserveSeed, ignoreModifiers = ignoreModifiers }
            self.SubType = subtype
        end
        return pickup
    end

    return {
        items = itemIds,
        hudMessages = hudMessages,
        newPlayer = newPlayer,
        newPickup = newPickup,
        runUseCondom = runUseCondom,
        runEvaluate = runEvaluate,
        runPostAddUtilityKnife = runPostAddUtilityKnife,
        runPostUpdate = runPostUpdate,
        runPickupInit = runPickupInit,
        savedData = function() return savedData end,
        mod = mod,
    }
end

local function test_xml_registers_requested_items_and_pools()
    local items = readFile("content/items.xml")
    local pools = readFile("content/itempools.xml")

    assertTruthy(items:find('<active%s+name="Condom".-maxcharges="3".-description="It does not count".-gfx="Condom.png".-quality="0"', 1), "Condom XML should be a 3-charge quality 0 active")
    assertTruthy(items:find('<passive%s+name="Utility Knife".-cache="damage".-description="Painful scars".-gfx="UtilityKnife.png".-quality="2".-tags="offensive summonable"', 1), "Utility Knife XML should be a damage passive with requested tags")
    assertTruthy(pools:find('<Pool Name="oldChest".-<Item Name="Condom" Weight="1"', 1), "Condom should be in oldChest pool")
    assertTruthy(pools:find('<Pool Name="boss".-<Item Name="Utility Knife" Weight="1"', 1), "Utility Knife should be in boss pool")
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

test_xml_registers_requested_items_and_pools()
test_utility_knife_adds_damage_and_grants_one_broken_heart_per_pickup()
test_utility_knife_pickup_accepts_wrapped_player_argument()
test_utility_knife_post_update_fallback_grants_broken_heart_for_new_copies()
test_condom_bans_up_to_two_unowned_baby_items_without_repeats()
test_condom_repeated_uses_can_exhaust_targets_and_show_feedback()
test_condom_replaces_future_banned_collectible_pedestals()

print("condom and utility knife behavior tests passed")
