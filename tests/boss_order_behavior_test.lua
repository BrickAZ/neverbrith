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

local function assertVectorNotEquals(actual, expected, message)
    if actual and expected and actual.X == expected.X and actual.Y == expected.Y then
        error(message or "expected different vector", 2)
    end
end

local function assertVectorDistanceAtLeast(actual, expected, distance, message)
    if not actual or not expected or not actual.Length then
        error(message or "expected vector distance check", 2)
    end

    if (actual - expected):Length() < distance then
        error(message or "expected vectors to be farther apart", 2)
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
    local itemIds = {
        BossOrder = 754,
    }
    local spawned = {}
    local players = {}

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
        MC_POST_PICKUP_INIT = 11,
        MC_POST_NPC_DEATH = 12,
        MC_POST_ENTITY_KILL = 13,
    }

    CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_PLAN_C = 475 }
    CacheFlag = {
        CACHE_DAMAGE = 1,
        CACHE_SHOTSPEED = 2,
        CACHE_TEARCOLOR = 4,
        CACHE_SPEED = 8,
        CACHE_FIREDELAY = 16,
        CACHE_RANGE = 64,
        CACHE_LUCK = 1024,
    }
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_NOKILL = 2, DAMAGE_INVINCIBLE = 4 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = {
        ENTITY_PLAYER = 1,
        ENTITY_PICKUP = 5,
        ENTITY_ATTACKFLY = 13,
        ENTITY_GAPER = 10,
        ENTITY_HORF = 12,
        ENTITY_POOTER = 14,
        ENTITY_CLOTTY = 21,
        ENTITY_MULLIGAN = 22,
        ENTITY_CHARGER = 23,
        ENTITY_SPITTY = 31,
        ENTITY_LEECH = 55,
        ENTITY_VIS = 39,
        ENTITY_CHUB = 28,
        ENTITY_GURDY = 36,
        ENTITY_MONSTRO = 20,
        ENTITY_LARRYJR = 19,
        ENTITY_DUKE = 30,
        ENTITY_FAMINE = 63,
        ENTITY_PESTILENCE = 64,
        ENTITY_WAR = 65,
        ENTITY_DEATH = 66,
        ENTITY_PIN = 62,
        ENTITY_LOKI = 81,
        ENTITY_MONSTRO2 = 43,
        ENTITY_GURDYJR = 97,
        ENTITY_MOM = 45,
        ENTITY_MOMS_HEART = 78,
        ENTITY_SATAN = 84,
        ENTITY_ISAAC = 102,
        ENTITY_BLUE_BABY = 273,
        ENTITY_MEGA_SATAN = 274,
        ENTITY_HUSH = 407,
        ENTITY_DELIRIUM = 412,
        ENTITY_MOTHER = 912,
        ENTITY_DOGMA = 950,
        ENTITY_BEAST = 951,
    }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
    GameStateFlag = { STATE_DEVILROOM_SPAWNED = 5, STATE_DEVILROOM_VISITED = 6 }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2, SLOT_POCKET2 = 3 }
    Card = { CARD_RANDOM = options.cardRandomSubtype or 0, CARD_FOOL = 1, RUNE_HAGALAZ = 32, RUNE_BLACK = 41, RUNE_SHARD = 55, CARD_SOUL_ISAAC = 81, CARD_SOUL_JACOB = 97 }
    if options.extraCards then
        for key, value in pairs(options.extraCards) do
            Card[key] = value
        end
    end

    function MusicManager()
        return {
            GetCurrentMusicID = function() return 1 end,
            Play = function() end,
            Fadeout = function() end,
        }
    end

    local room = { spawnSeed = 7000 }
    function room:GetCenterPos()
        return Vector(320, 280)
    end
    function room:FindFreePickupSpawnPosition(position)
        return position
    end
    function room:FindFreeTilePosition(position)
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

    local level = { stage = 1, stageType = 0 }
    function level:GetStage()
        return self.stage
    end
    function level:GetStageType()
        return self.stageType
    end
    function level:AddAngelRoomChance() end
    function level:InitializeDevilAngelRoom() end

    local rngValues = options.rngValues or {}
    local rngIndex = 0
    local cardPoolSequence = options.cardPoolSequence or {}
    local cardPoolIndex = 0
    local function nextRngValue(max)
        rngIndex = rngIndex + 1
        local value = rngValues[rngIndex] or 0
        return math.max(0, math.min(max - 1, math.floor(value)))
    end

    local function makeSpawnedEntity(entityType, variant, subtype, position, velocity, spawner, seed)
        local entity = {
            Type = entityType,
            Variant = variant,
            SubType = subtype,
            Position = position,
            Velocity = velocity,
            Spawner = spawner,
            InitSeed = seed or (#spawned + 900),
            data = {},
            boss = options.forceSpawnedBoss == true or entityType == EntityType.ENTITY_MONSTRO,
            champion = options.forceSpawnedChampion == true,
            makeChampionCalls = {},
        }

        function entity:GetData()
            return self.data
        end
        function entity:ToNPC()
            return self
        end
        function entity:ToPlayer()
            return nil
        end
        function entity:IsBoss()
            return self.boss == true
        end
        function entity:IsChampion()
            return self.champion == true
        end
        function entity:MakeChampion(seed, championType, init)
            self.champion = true
            self.makeChampionCalls[#self.makeChampionCalls + 1] = {
                seed = seed,
                championType = championType,
                init = init,
            }
        end
        function entity:IsVulnerableEnemy()
            return self.Type ~= EntityType.ENTITY_PICKUP
        end
        function entity:HasEntityFlags(flag)
            return options.friendlySpawn == true and flag == EntityFlag.FLAG_FRIENDLY
        end

        spawned[#spawned + 1] = entity
        return entity
    end

    function Game()
        return {
            GetSeeds = function()
                return { GetStartSeedString = function() return "TEST RUN" end }
            end,
            GetNumPlayers = function()
                return #players
            end,
            GetLevel = function()
                return level
            end,
            GetRoom = function()
                return room
            end,
            GetItemPool = function()
                local pool = { GetCollectible = function() return CollectibleType.COLLECTIBLE_NULL end }
                if options.cardPoolSequence then
                    pool.GetCard = function()
                        cardPoolIndex = cardPoolIndex + 1
                        return cardPoolSequence[cardPoolIndex] or Card.CARD_FOOL
                    end
                end
                return pool
            end,
            Spawn = function(_, entityType, variant, position, velocity, spawner, subtype, seed)
                return makeSpawnedEntity(entityType, variant, subtype, position, velocity, spawner, seed)
            end,
            GetStateFlag = function()
                return false
            end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Boss's Order" or name == "老大的指令" then
                return itemIds.BossOrder
            end
            return -1
        end,
        GetMusicIdByName = function()
            return -1
        end,
        DebugString = function() end,
        GetRoomEntities = function()
            return {}
        end,
        FindByType = function(entityType)
            if entityType ~= EntityType.ENTITY_PLAYER then
                return {}
            end
            local found = {}
            for _, player in ipairs(players) do
                found[#found + 1] = player
            end
            return found
        end,
        GetPlayer = function(index)
            return players[(index or 0) + 1]
        end,
        WorldToScreen = function(position)
            return position
        end,
        RenderText = function() end,
        GetItemConfig = function()
            return {
                GetCollectible = function() return { Tags = 0, Type = 3, MaxCharges = 0, Name = "Mock" } end,
                GetCollectibles = function() return {} end,
                GetCard = function(_, subtype)
                    if options.cardConfigs and options.cardConfigs[subtype] ~= nil then
                        return options.cardConfigs[subtype]
                    end
                    local unknown = options.unknownCards or {}
                    if unknown[subtype] then
                        return nil
                    end
                    local known = options.knownCards
                    if known then
                        return known[subtype] and { ID = subtype, Name = "Card " .. tostring(subtype) } or nil
                    end
                    return { ID = subtype, Name = "Card " .. tostring(subtype) }
                end,
            }
        end,
    }

    if not options.disableIsaacSpawn then
        Isaac.Spawn = function(entityType, variant, subtype, position, velocity, spawner, seed)
            return makeSpawnedEntity(entityType, variant, subtype, position, velocity, spawner, seed)
        end
    end

    EID = nil
    if options.eidDescriptions then
        EID = {
            getDescriptionObjByID = function(_, entityType, variant, subtype)
                local desc = options.eidDescriptions[subtype]
                if desc == false then
                    return { Name = tostring(entityType) .. "." .. tostring(variant) .. "." .. tostring(subtype), Description = "(no description available)" }
                end
                return desc
            end,
        }
    end

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
    }
    function Vector(x, y)
        local value = { X = x or 0, Y = y or 0 }
        function value:Length()
            return math.sqrt(self.X * self.X + self.Y * self.Y)
        end
        return setmetatable(value, vectorMeta)
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
            if param == nil or registration.param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end
        return found
    end

    local function newPlayer()
        local player = {
            InitSeed = #players + 100,
            Position = Vector(120, 100),
            activeItems = { [ActiveSlot.SLOT_PRIMARY] = itemIds.BossOrder },
            activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 3 },
        }
        function player:ToPlayer()
            return self
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
        function player:GetCollectibleNum(itemId)
            return itemId == itemIds.BossOrder and 1 or 0
        end
        function player:GetCollectibleRNG()
            return { RandomInt = function(_, max) return nextRngValue(max) end }
        end
        players[#players + 1] = player
        return player
    end

    local function runUseBossOrder(player, slot)
        local use = getCallback(ModCallbacks.MC_USE_ITEM, itemIds.BossOrder)
        return use(mod, itemIds.BossOrder, nil, player, 0, slot or ActiveSlot.SLOT_PRIMARY, 0)
    end

    local function runNpcDeath(npc)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NPC_DEATH)) do
            callback(mod, npc)
        end
    end

    local function runEntityKill(entity)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ENTITY_KILL)) do
            callback(mod, entity)
        end
    end

    return {
        mod = mod,
        items = itemIds,
        room = room,
        level = level,
        spawned = spawned,
        newPlayer = newPlayer,
        runUseBossOrder = runUseBossOrder,
        runNpcDeath = runNpcDeath,
        runEntityKill = runEntityKill,
    }
end

local function getItemXmlAttribute(itemName, attribute)
    local block = readFile("content/items.xml"):match('<active%s+name="' .. itemName .. '"(.-)/>')
    assertTruthy(block, "items.xml should contain active item " .. itemName)
    return block:match(attribute .. '="([^"]+)"')
end

local function countCardSpawns(env)
    local count = 0
    for _, spawn in ipairs(env.spawned) do
        if spawn.Type == EntityType.ENTITY_PICKUP and spawn.Variant == PickupVariant.PICKUP_TAROTCARD then
            count = count + 1
        end
    end
    return count
end

local function getLastCardSpawn(env)
    for index = #env.spawned, 1, -1 do
        local spawn = env.spawned[index]
        if spawn.Type == EntityType.ENTITY_PICKUP and spawn.Variant == PickupVariant.PICKUP_TAROTCARD then
            return spawn
        end
    end
    return nil
end

local function test_xml_registers_active_item_and_treasure_pool()
    assertEquals(getItemXmlAttribute("Boss's Order", "maxcharges"), "3", "Boss's Order should have 3 charges")
    assertEquals(getItemXmlAttribute("Boss's Order", "initcharge"), "3", "Boss's Order should start charged")
    assertEquals(getItemXmlAttribute("Boss's Order", "quality"), "2", "Boss's Order should be quality 2")
    local tags = getItemXmlAttribute("Boss's Order", "tags") or ""
    assertTruthy(tags:find("nochallenge", 1, true), "Boss's Order should have nochallenge tag")
    assertTruthy(tags:find("nolostbr", 1, true), "Boss's Order should have nolostbr tag")

    local pools = readFile("content/itempools.xml")
    assertTruthy(pools:find('<Pool Name="treasure".-<Item Name="Boss\'s Order" Weight="1"', 1), "Boss's Order should be in treasure pool")
end

local function test_use_spawns_one_marked_hostile_non_final_target()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer()

    local result = env.runUseBossOrder(player)

    assertEquals(result, true, "successful target spawn should make the use succeed")
    assertEquals(#env.spawned, 1, "use should spawn exactly one target")
    local target = env.spawned[1]
    assertTruthy(target.Type ~= EntityType.ENTITY_MOM and target.Type ~= EntityType.ENTITY_MOMS_HEART, "target should not be a final/story boss")
    assertTruthy(target:IsVulnerableEnemy(), "target should be hostile/vulnerable")
    assertEquals(target:GetData().neverbirthBossOrderTarget, true, "spawned target should be marked")
    assertEquals(target:GetData().neverbirthBossOrderRewarded, false, "spawned target should not start rewarded")
end

local function test_normal_target_comes_from_current_floor_pool()
    local env = loadNeverbirth({ rngValues = { 0, 0, 99 } })
    env.level.stage = 3
    local player = env.newPlayer()

    env.runUseBossOrder(player)

    assertEquals(env.spawned[1].Type, EntityType.ENTITY_CLOTTY, "normal target should come from the current floor small enemy pool")
    assertEquals(env.spawned[1]:IsBoss(), false, "current-floor small enemy target should not be marked as boss reward")
end

local function test_boss_target_comes_from_boss_rush_pool()
    local env = loadNeverbirth({ rngValues = { 2, 3 } })
    local player = env.newPlayer()

    env.runUseBossOrder(player)

    assertEquals(env.spawned[1].Type, EntityType.ENTITY_GURDY, "boss target should come from the Boss Rush boss pool")
    assertEquals(env.spawned[1]:GetData().neverbirthBossOrderRewardCategory, "boss", "Boss Rush target should be marked as boss reward")
end

local function test_normal_target_rolls_champion_after_spawn()
    local env = loadNeverbirth({ rngValues = { 0, 0, 0 } })
    local player = env.newPlayer()

    env.runUseBossOrder(player)

    local target = env.spawned[1]
    assertEquals(target:GetData().neverbirthBossOrderRewardCategory, "normal", "champion roll should happen after normal target spawn")
    assertEquals(target:IsChampion(), true, "normal target should become champion when the post-spawn champion roll succeeds")
    assertEquals(#target.makeChampionCalls, 1, "normal target should use the native champion conversion path")
end

local function test_use_spawns_target_away_from_player_to_avoid_contact_damage()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer()

    env.runUseBossOrder(player)

    assertVectorNotEquals(env.spawned[1].Position, player.Position, "target should not spawn on the player")
end

local function test_use_spawns_target_away_when_player_is_room_center()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer()
    player.Position = env.room:GetCenterPos()

    env.runUseBossOrder(player)

    assertVectorDistanceAtLeast(env.spawned[1].Position, player.Position, 60, "target should keep distance from centered player")
end

local function test_use_fails_gracefully_when_spawn_api_is_missing()
    local env = loadNeverbirth({ disableIsaacSpawn = true })
    local player = env.newPlayer()

    local result = env.runUseBossOrder(player)

    assertEquals(result, false, "missing spawn API should fail the use without crashing")
    assertEquals(#env.spawned, 0, "failed use should not spawn anything")
end

local function test_marked_normal_target_drops_one_card_once()
    local env = loadNeverbirth({ rngValues = { 0 } })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]
    target.boss = false
    target.champion = false

    env.runNpcDeath(target)
    env.runNpcDeath(target)

    assertEquals(countCardSpawns(env), 1, "normal marked target should drop one card once")
    assertEquals(target:GetData().neverbirthBossOrderRewarded, true, "target should be marked rewarded")
end

local function test_card_rewards_use_vanilla_card_subtypes_when_random_card_is_negative()
    local env = loadNeverbirth({ rngValues = { 0 }, cardRandomSubtype = -1 })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]
    target.boss = false
    target.champion = false

    env.runNpcDeath(target)

    local card = getLastCardSpawn(env)
    assertTruthy(card, "marked target should spawn a card reward")
    assertTruthy(card.SubType >= Card.CARD_FOOL and card.SubType < Card.RUNE_HAGALAZ, "card reward should use a vanilla card subtype")
end

local function test_card_rewards_skip_unknown_card_subtypes_without_blocking_mod_cards()
    local env = loadNeverbirth({
        rngValues = { 0 },
        extraCards = { MOD_CARD_A = 42 },
        unknownCards = { [41] = true },
        knownCards = { [1] = true, [42] = true },
    })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]
    target.InitSeed = 4
    target.boss = false
    target.champion = false

    env.runNpcDeath(target)

    local card = getLastCardSpawn(env)
    assertTruthy(card, "marked target should spawn a card reward")
    assertEquals(card.SubType, 42, "card reward should skip unknown card subtypes and allow valid modded cards")
end

local function test_card_rewards_skip_empty_card_configs_from_item_pool()
    local env = loadNeverbirth({
        rngValues = { 0 },
        extraCards = { MOD_CARD_A = 42 },
        cardPoolSequence = { 41, 42 },
        cardConfigs = {
            [41] = { ID = 41 },
            [42] = { ID = 42, Name = "Mod Card", Description = "A real custom card" },
        },
    })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]
    target.InitSeed = 4
    target.boss = false
    target.champion = false

    env.runNpcDeath(target)

    local card = getLastCardSpawn(env)
    assertTruthy(card, "marked target should spawn a card reward")
    assertEquals(card.SubType, 42, "card reward should reject item pool card configs without display data")
end

local function test_card_rewards_reject_absurd_item_pool_subtypes_even_with_config_shells()
    local env = loadNeverbirth({
        rngValues = { 0 },
        extraCards = { MOD_CARD_A = 42 },
        cardPoolSequence = { 230967295, 42 },
        cardConfigs = {
            [230967295] = { ID = 230967295, Name = "5.300.0230967295", Description = "(no description available)", GfxFileName = "placeholder.png" },
            [42] = { ID = 42, Name = "Mod Card", Description = "A real custom card" },
        },
        eidDescriptions = {
            [230967295] = false,
            [42] = { Name = "Mod Card", Description = "A real custom card" },
        },
    })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]
    target.InitSeed = 4
    target.boss = false
    target.champion = false

    env.runNpcDeath(target)

    local card = getLastCardSpawn(env)
    assertTruthy(card, "marked target should spawn a card reward")
    assertEquals(card.SubType, 42, "card reward should reject absurd unknown card subtypes and continue to valid mod cards")
end

local function test_marked_champion_target_drops_two_cards()
    local env = loadNeverbirth({ rngValues = { 0 }, forceSpawnedChampion = true })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]
    target.boss = false

    env.runNpcDeath(target)

    assertEquals(countCardSpawns(env), 2, "champion marked target should drop two cards")
end

local function test_marked_boss_target_drops_three_cards()
    local env = loadNeverbirth({ rngValues = { 2 }, forceSpawnedBoss = true })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]

    env.runNpcDeath(target)

    assertEquals(countCardSpawns(env), 3, "boss marked target should drop three cards")
end

local function test_marked_boss_target_rewards_on_entity_kill_callback()
    local env = loadNeverbirth({ rngValues = { 2 }, forceSpawnedBoss = true })
    local player = env.newPlayer()
    env.runUseBossOrder(player)
    local target = env.spawned[1]

    env.runEntityKill(target)

    assertEquals(countCardSpawns(env), 3, "boss marked target should drop three cards on entity kill")
end

test_xml_registers_active_item_and_treasure_pool()
test_use_spawns_one_marked_hostile_non_final_target()
test_normal_target_comes_from_current_floor_pool()
test_boss_target_comes_from_boss_rush_pool()
test_normal_target_rolls_champion_after_spawn()
test_use_spawns_target_away_from_player_to_avoid_contact_damage()
test_use_spawns_target_away_when_player_is_room_center()
test_use_fails_gracefully_when_spawn_api_is_missing()
test_marked_normal_target_drops_one_card_once()
test_card_rewards_use_vanilla_card_subtypes_when_random_card_is_negative()
test_card_rewards_skip_unknown_card_subtypes_without_blocking_mod_cards()
test_card_rewards_skip_empty_card_configs_from_item_pool()
test_card_rewards_reject_absurd_item_pool_subtypes_even_with_config_shells()
test_marked_champion_target_drops_two_cards()
test_marked_boss_target_drops_three_cards()
test_marked_boss_target_rewards_on_entity_kill_callback()

print("boss order behavior tests passed")
