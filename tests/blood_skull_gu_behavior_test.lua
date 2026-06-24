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
        EmptyCradle = 743,
        BloodSkullGu = 744,
    }
    local players = {}
    local roomEntities = {}
    local spawned = {}

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
    }

    CollectibleType = {
        COLLECTIBLE_NULL = 0,
        COLLECTIBLE_BROTHER_BOBBY = 8,
        COLLECTIBLE_SISTER_MAGGY = 67,
        COLLECTIBLE_INCUBUS = 360,
        COLLECTIBLE_TWISTED_PAIR = 698,
        COLLECTIBLE_PLAN_C = 475,
    }
    CacheFlag = {
        CACHE_DAMAGE = 1,
        CACHE_SHOTSPEED = 2,
        CACHE_TEARCOLOR = 4,
        CACHE_SPEED = 8,
        CACHE_FIREDELAY = 16,
        CACHE_TEARFLAG = 32,
        CACHE_RANGE = 64,
        CACHE_LUCK = 1024,
    }
    DamageFlag = {
        DAMAGE_RED_HEARTS = 1,
        DAMAGE_NOKILL = 2,
        DAMAGE_INVINCIBLE = 4,
    }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = {
        ENTITY_PLAYER = 1,
        ENTITY_FAMILIAR = 3,
        ENTITY_PICKUP = 5,
        ENTITY_EFFECT = 1000,
    }
    EffectVariant = {
        POOF01 = 15,
        BLOOD_EXPLOSION = 34,
        CREEP_RED = 22,
    }
    FamiliarVariant = {
        BROTHER_BOBBY = 1,
        SISTER_MAGGY = 7,
        INCUBUS = 80,
        TWISTED_BABY = 235,
        BLUE_FLY = 43,
        BLUE_SPIDER = 73,
        WISP = 206,
        ABYSS_LOCUST = 231,
    }
    PickupVariant = {
        PICKUP_HEART = 10,
        PICKUP_COIN = 20,
        PICKUP_KEY = 30,
        PICKUP_BOMB = 40,
        PICKUP_COLLECTIBLE = 100,
    }
    HeartSubType = {
        HEART_SOUL = 3,
        HEART_BLACK = 6,
    }
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

    local level = { stage = 1, stageType = 0 }
    function level:GetStage()
        return self.stage
    end
    function level:GetStageType()
        return self.stageType
    end
    function level:AddAngelRoomChance() end
    function level:InitializeDevilAngelRoom() end

    local room = { spawnSeed = 9000 }
    function room:GetSpawnSeed()
        return self.spawnSeed
    end
    function room:GetType()
        return RoomType.ROOM_DEFAULT
    end
    function room:GetCenterPos()
        return Vector(320, 280)
    end
    function room:FindFreePickupSpawnPosition(position)
        return position
    end
    function room:IsClear()
        return true
    end

    local seeds = {
        GetStartSeedString = function()
            return "TEST RUN"
        end,
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

    function Game()
        return {
            GetSeeds = function()
                return seeds
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
            GetStateFlag = function()
                return false
            end,
            SetStateFlag = function() end,
        }
    end

    local rngValues = options.rngValues or {}
    local rngIndex = 0
    local function nextRngValue(max)
        rngIndex = rngIndex + 1
        local value = rngValues[rngIndex]
        if value == nil then
            value = 0
        end
        return math.max(0, math.min(max - 1, math.floor(value)))
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Blood Skull Gu" or name == "血颅蛊" then
                return itemIds.BloodSkullGu
            end
            if name == "Uncut Cord" or name == "未剪断的脐带" then
                return itemIds.UncutCord
            end
            if name == "Shredded Tarot" or name == "剪碎的塔罗" then
                return itemIds.ShreddedTarot
            end
            if name == "Sterilization Certificate" or name == "绝育证明" then
                return itemIds.SterilizationCertificate
            end
            if name == "Empty Cradle" or name == "空摇篮" then
                return itemIds.EmptyCradle
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
                GetCollectible = function(_, itemId)
                    if options.disableItemConfigFamiliarVariant then
                        return { Quality = 1 }
                    end
                    if itemId == CollectibleType.COLLECTIBLE_BROTHER_BOBBY then
                        return { Quality = 1, FamiliarVariant = FamiliarVariant.BROTHER_BOBBY }
                    end
                    if itemId == CollectibleType.COLLECTIBLE_SISTER_MAGGY then
                        return { Quality = 1, FamiliarVariant = FamiliarVariant.SISTER_MAGGY }
                    end
                    return { Quality = 1 }
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

    local function getCallback(callbackId, param)
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == param then
                return registration.fn
            end
        end
        error("callback not found: " .. tostring(callbackId) .. " param=" .. tostring(param), 2)
    end

    local function runEvaluateCache(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE, cacheFlag)) do
            callback(mod, player, cacheFlag)
        end
    end

    local function runPostGameStarted(isContinued)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do
            callback(mod, isContinued == true)
        end
    end

    local function newPlayer(optionsForPlayer)
        optionsForPlayer = optionsForPlayer or {}
        local player = {
            InitSeed = optionsForPlayer.initSeed or (#players + 100),
            Position = optionsForPlayer.position or Vector(100, 100),
            activeItems = optionsForPlayer.activeItems or { [ActiveSlot.SLOT_PRIMARY] = itemIds.BloodSkullGu },
            activeCharges = optionsForPlayer.activeCharges or { [ActiveSlot.SLOT_PRIMARY] = 3 },
            collectibles = optionsForPlayer.collectibles or {},
            Damage = optionsForPlayer.damage or 3.5,
            TearRange = optionsForPlayer.range or 260,
            cacheFlags = {},
            evaluated = 0,
            damageCalls = {},
            removeCalls = {},
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
            if itemId == itemIds.BloodSkullGu then
                for _, activeItemId in pairs(self.activeItems) do
                    if activeItemId == itemId then
                        return 1
                    end
                end
            end
            return self.collectibles[itemId] or 0
        end
        function player:RemoveCollectible(itemId, ignoreModifiers, slot, removeFromPlayerForm)
            self.removeCalls[#self.removeCalls + 1] = {
                itemId = itemId,
                ignoreModifiers = ignoreModifiers,
                slot = slot,
                removeFromPlayerForm = removeFromPlayerForm,
            }
            self.collectibles[itemId] = math.max((self.collectibles[itemId] or 0) - 1, 0)
        end
        function player:GetCollectibleRNG()
            return {
                RandomInt = function(_, max)
                    return nextRngValue(max)
                end,
            }
        end
        function player:AddCacheFlags(flags)
            self.cacheFlags[#self.cacheFlags + 1] = flags
        end
        function player:EvaluateItems()
            self.evaluated = self.evaluated + 1
            local flags = self.cacheFlags
            self.cacheFlags = {}
            for _, flag in ipairs(flags) do
                runEvaluateCache(self, flag)
            end
        end
        function player:TakeDamage(amount, flags, source, countdown)
            self.damageCalls[#self.damageCalls + 1] = {
                amount = amount,
                flags = flags,
                source = source,
                countdown = countdown,
            }
        end

        players[#players + 1] = player
        return player
    end

    local function newFamiliar(player, optionsForFamiliar)
        optionsForFamiliar = optionsForFamiliar or {}
        local familiar = {
            Type = EntityType.ENTITY_FAMILIAR,
            Variant = optionsForFamiliar.variant or 100,
            SubType = optionsForFamiliar.subtype or 0,
            InitSeed = optionsForFamiliar.initSeed or (#roomEntities + 500),
            Position = optionsForFamiliar.position or Vector(140, 100),
            Player = optionsForFamiliar.playerField ~= false and player or nil,
            SpawnerEntity = optionsForFamiliar.spawnerEntity,
            removed = false,
            dead = false,
        }

        function familiar:ToFamiliar()
            return self
        end
        function familiar:ToPlayer()
            return nil
        end
        function familiar:IsDead()
            return self.dead
        end
        function familiar:Remove()
            self.removed = true
        end
        function familiar:HasEntityFlags(flag)
            return optionsForFamiliar.friendlyFlag == true and flag == EntityFlag.FLAG_FRIENDLY
        end

        roomEntities[#roomEntities + 1] = familiar
        return familiar
    end

    return {
        mod = mod,
        items = itemIds,
        spawned = spawned,
        roomEntities = roomEntities,
        getCallback = getCallback,
        getCallbacks = getCallbacks,
        runEvaluateCache = runEvaluateCache,
        runPostGameStarted = runPostGameStarted,
        newPlayer = newPlayer,
        newFamiliar = newFamiliar,
    }
end

local function runUseBloodSkullGu(env, player, slot)
    local use = env.getCallback(ModCallbacks.MC_USE_ITEM, env.items.BloodSkullGu)
    return use(env.mod, env.items.BloodSkullGu, nil, player, 0, slot or ActiveSlot.SLOT_PRIMARY, 0)
end

local function getItemXmlAttribute(itemName, attribute)
    local text = readFile("content/items.xml")
    local block = text:match('<active%s+name="' .. itemName .. '"(.-)/>')
    assertTruthy(block, "items.xml should contain active item " .. itemName)
    return block:match(attribute .. '="([^"]+)"')
end

local function countBlackHeartSpawns(env)
    local count = 0
    for _, spawn in ipairs(env.spawned) do
        if spawn.Type == EntityType.ENTITY_PICKUP
            and spawn.Variant == PickupVariant.PICKUP_HEART
            and spawn.SubType == HeartSubType.HEART_BLACK then
            count = count + 1
        end
    end
    return count
end

local function test_xml_registers_active_three_charge_item_and_pools()
    assertEquals(getItemXmlAttribute("Blood Skull Gu", "maxcharges"), "3", "Blood Skull Gu should have 3 charges")
    assertEquals(getItemXmlAttribute("Blood Skull Gu", "quality"), "3", "Blood Skull Gu should be quality 3")

    local pools = readFile("content/itempools.xml")
    assertTruthy(pools:find('<Pool Name="devil".-<Item Name="Blood Skull Gu" Weight="1"', 1), "Blood Skull Gu should be in devil pool")
    assertTruthy(pools:find('<Pool Name="curse".-<Item Name="Blood Skull Gu" Weight="1"', 1), "Blood Skull Gu should be in curse pool")
end

local function test_successful_use_removes_random_eligible_familiar()
    local env = loadNeverbirth({ rngValues = { 1, 0 } })
    local player = env.newPlayer({
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
            [CollectibleType.COLLECTIBLE_SISTER_MAGGY] = 1,
        },
    })
    local first = env.newFamiliar(player, {
        variant = FamiliarVariant.BROTHER_BOBBY,
        initSeed = 501,
        position = Vector(110, 100),
    })
    local second = env.newFamiliar(player, {
        variant = FamiliarVariant.SISTER_MAGGY,
        initSeed = 502,
        position = Vector(160, 100),
    })

    local result = runUseBloodSkullGu(env, player)

    assertEquals(result, true, "use with eligible familiar should succeed")
    assertEquals(first.removed, false, "rng should leave the first familiar alive")
    assertEquals(second.removed, true, "rng should remove the selected familiar")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_SISTER_MAGGY, "selected familiar should remove its source item")
    assertTruthy(#env.spawned >= 2, "successful sacrifice should spawn blood effect and black heart")
    assertEquals(countBlackHeartSpawns(env), 1, "first heart roll should drop one black heart")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "successful use should consume charge")
end

local function test_sacrifice_removes_source_collectible_so_cache_cannot_restore_familiar()
    local env = loadNeverbirth({ rngValues = { 0, 0 } })
    local player = env.newPlayer({
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
        },
    })
    local familiar = env.newFamiliar(player, {
        variant = FamiliarVariant.BROTHER_BOBBY,
        initSeed = 501,
    })

    runUseBloodSkullGu(env, player)

    assertEquals(#player.removeCalls, 1, "sacrificing an item-created familiar should remove its source collectible")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_BROTHER_BOBBY, "source collectible should be removed")
    assertEquals(player:GetCollectibleNum(CollectibleType.COLLECTIBLE_BROTHER_BOBBY), 0, "source collectible count should be gone")
    assertEquals(familiar.removed, true, "selected familiar should still be removed immediately for visible feedback")
end

local function test_static_baby_mapping_removes_source_collectible_without_item_config_variant()
    local env = loadNeverbirth({
        rngValues = { 0, 0 },
        disableItemConfigFamiliarVariant = true,
    })
    local player = env.newPlayer({
        collectibles = {
            [CollectibleType.COLLECTIBLE_SISTER_MAGGY] = 1,
        },
    })
    local familiar = env.newFamiliar(player, {
        variant = FamiliarVariant.SISTER_MAGGY,
        initSeed = 501,
    })

    runUseBloodSkullGu(env, player)

    assertEquals(#player.removeCalls, 1, "static baby mapping should remove the source collectible even when ItemConfig lacks FamiliarVariant")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_SISTER_MAGGY, "Sister Maggy familiar should remove Sister Maggy item")
    assertEquals(player:GetCollectibleNum(CollectibleType.COLLECTIBLE_SISTER_MAGGY), 0, "Sister Maggy item should be gone")
    assertEquals(familiar.removed, true, "selected familiar should still be removed immediately")
end

local function test_static_mapping_covers_repentance_baby_items()
    local env = loadNeverbirth({
        rngValues = { 1, 0 },
        disableItemConfigFamiliarVariant = true,
    })
    local player = env.newPlayer({
        collectibles = {
            [CollectibleType.COLLECTIBLE_INCUBUS] = 1,
            [CollectibleType.COLLECTIBLE_TWISTED_PAIR] = 1,
        },
    })
    local incubus = env.newFamiliar(player, {
        variant = FamiliarVariant.INCUBUS,
        initSeed = 501,
    })
    local twisted = env.newFamiliar(player, {
        variant = FamiliarVariant.TWISTED_BABY,
        initSeed = 502,
    })

    runUseBloodSkullGu(env, player)

    assertEquals(incubus.removed, false, "rng should leave Incubus alive")
    assertEquals(twisted.removed, true, "rng should sacrifice Twisted Pair baby")
    assertEquals(#player.removeCalls, 1, "one source item should be removed")
    assertEquals(player.removeCalls[1].itemId, CollectibleType.COLLECTIBLE_TWISTED_PAIR, "Twisted Pair familiar should remove Twisted Pair item")
end

local function test_unmapped_familiar_without_source_collectible_is_not_sacrificed()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local familiar = env.newFamiliar(player, {
        variant = 999,
        initSeed = 501,
    })

    runUseBloodSkullGu(env, player)

    assertEquals(familiar.removed, false, "familiar without a removable source collectible should not be sacrificed")
    assertEquals(#player.removeCalls, 0, "no collectible should be removed for an unmapped familiar")
    assertEquals(#player.damageCalls, 1, "without a removable familiar item, Blood Skull Gu should backlash")
    assertEquals(countBlackHeartSpawns(env), 0, "backlash should not drop black hearts")
end

local function test_successful_use_grants_damage_and_range()
    local env = loadNeverbirth({ rngValues = { 0, 0 } })
    local player = env.newPlayer({
        damage = 3.5,
        range = 260,
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
        },
    })
    env.newFamiliar(player, { variant = FamiliarVariant.BROTHER_BOBBY })

    runUseBloodSkullGu(env, player)
    player.Damage = 3.5
    player.TearRange = 260
    env.runEvaluateCache(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluateCache(player, CacheFlag.CACHE_RANGE)

    assertEquals(player.Damage, 5.0, "one sacrifice should grant +1.5 damage")
    assertEquals(player.TearRange, 300, "one sacrifice should grant +1 range as 40 TearRange")
end

local function test_successful_use_drops_one_or_two_black_hearts()
    local oneHeartEnv = loadNeverbirth({ rngValues = { 0, 0 } })
    local oneHeartPlayer = oneHeartEnv.newPlayer({
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
        },
    })
    oneHeartEnv.newFamiliar(oneHeartPlayer, { variant = FamiliarVariant.BROTHER_BOBBY })
    runUseBloodSkullGu(oneHeartEnv, oneHeartPlayer)
    assertEquals(countBlackHeartSpawns(oneHeartEnv), 1, "heart roll 0 should drop one black heart")

    local twoHeartEnv = loadNeverbirth({ rngValues = { 1 } })
    local twoHeartPlayer = twoHeartEnv.newPlayer({
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
        },
    })
    twoHeartEnv.newFamiliar(twoHeartPlayer, { variant = FamiliarVariant.BROTHER_BOBBY })
    runUseBloodSkullGu(twoHeartEnv, twoHeartPlayer)
    assertEquals(countBlackHeartSpawns(twoHeartEnv), 2, "heart roll 1 should drop two black hearts")
end

local function test_no_familiar_backlashes_without_growth_or_black_hearts()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 3.5, range = 260 })

    local result = runUseBloodSkullGu(env, player)
    player.Damage = 3.5
    player.TearRange = 260
    env.runEvaluateCache(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluateCache(player, CacheFlag.CACHE_RANGE)

    assertEquals(result, true, "backlash use should still consume the active item charge")
    assertEquals(#player.damageCalls, 1, "backlash should damage the player")
    assertEquals(player.damageCalls[1].amount, 1, "backlash should deal half a heart")
    assertEquals(player.Damage, 3.5, "backlash should not grant damage")
    assertEquals(player.TearRange, 260, "backlash should not grant range")
    assertEquals(countBlackHeartSpawns(env), 0, "backlash should not drop black hearts")
    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "backlash should consume charge")
end

local function test_multiple_successes_stack_and_new_run_resets()
    local env = loadNeverbirth({ rngValues = { 0, 0, 0, 0 } })
    local player = env.newPlayer({
        damage = 3.5,
        range = 260,
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
            [CollectibleType.COLLECTIBLE_SISTER_MAGGY] = 1,
        },
    })
    env.newFamiliar(player, { variant = FamiliarVariant.BROTHER_BOBBY, initSeed = 501 })
    runUseBloodSkullGu(env, player)
    player:SetActiveCharge(3, ActiveSlot.SLOT_PRIMARY)
    env.newFamiliar(player, { variant = FamiliarVariant.SISTER_MAGGY, initSeed = 502 })
    runUseBloodSkullGu(env, player)

    player.Damage = 3.5
    player.TearRange = 260
    env.runEvaluateCache(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluateCache(player, CacheFlag.CACHE_RANGE)
    assertEquals(player.Damage, 6.5, "two sacrifices should stack damage")
    assertEquals(player.TearRange, 340, "two sacrifices should stack range")

    env.runPostGameStarted(false)
    player.Damage = 3.5
    player.TearRange = 260
    env.runEvaluateCache(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluateCache(player, CacheFlag.CACHE_RANGE)
    assertEquals(player.Damage, 3.5, "new run should reset damage growth")
    assertEquals(player.TearRange, 260, "new run should reset range growth")
end

local function test_multiplayer_state_and_targets_are_independent()
    local env = loadNeverbirth({ rngValues = { 0, 0 } })
    local playerA = env.newPlayer({
        initSeed = 111,
        damage = 3.5,
        range = 260,
        collectibles = {
            [CollectibleType.COLLECTIBLE_BROTHER_BOBBY] = 1,
        },
    })
    local playerB = env.newPlayer({
        initSeed = 222,
        damage = 4.0,
        range = 280,
        collectibles = {
            [CollectibleType.COLLECTIBLE_SISTER_MAGGY] = 1,
        },
    })
    local familiarA = env.newFamiliar(playerA, { variant = FamiliarVariant.BROTHER_BOBBY, initSeed = 501 })
    local familiarB = env.newFamiliar(playerB, { variant = FamiliarVariant.SISTER_MAGGY, initSeed = 502 })

    runUseBloodSkullGu(env, playerA)
    playerA.Damage = 3.5
    playerB.Damage = 4.0
    env.runEvaluateCache(playerA, CacheFlag.CACHE_DAMAGE)
    env.runEvaluateCache(playerB, CacheFlag.CACHE_DAMAGE)

    assertEquals(familiarA.removed, true, "player A should sacrifice only their own familiar")
    assertEquals(familiarB.removed, false, "player B familiar should not be touched")
    assertEquals(playerA.Damage, 5.0, "player A should receive growth")
    assertEquals(playerB.Damage, 4.0, "player B should not receive player A growth")
end

local function test_temporary_consumables_are_not_eligible()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local fly = env.newFamiliar(player, { variant = FamiliarVariant.BLUE_FLY })

    runUseBloodSkullGu(env, player)

    assertEquals(fly.removed, false, "blue fly style temporary familiar should not be sacrificed")
    assertEquals(#player.damageCalls, 1, "only temporary familiars should cause backlash")
end

test_xml_registers_active_three_charge_item_and_pools()
test_successful_use_removes_random_eligible_familiar()
test_sacrifice_removes_source_collectible_so_cache_cannot_restore_familiar()
test_static_baby_mapping_removes_source_collectible_without_item_config_variant()
test_static_mapping_covers_repentance_baby_items()
test_unmapped_familiar_without_source_collectible_is_not_sacrificed()
test_successful_use_grants_damage_and_range()
test_successful_use_drops_one_or_two_black_hearts()
test_no_familiar_backlashes_without_growth_or_black_hearts()
test_multiple_successes_stack_and_new_run_resets()
test_multiplayer_state_and_targets_are_independent()
test_temporary_consumables_are_not_eligible()

print("blood skull gu behavior tests passed")
