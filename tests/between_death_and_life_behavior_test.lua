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
        BetweenDeathAndLife = 745,
        DeathCertificate = 628,
    }
    local players = {}
    local spawned = {}
    local nextSeed = 1000

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function(value)
                savedData = value
                return "<json>"
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
        MC_POST_ADD_COLLECTIBLE = 13,
        MC_POST_NPC_INIT = 27,
    }

    CollectibleType = {
        COLLECTIBLE_NULL = 0,
        COLLECTIBLE_DEATH_CERTIFICATE = itemIds.DeathCertificate,
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
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_NOKILL = 2, DAMAGE_INVINCIBLE = 4 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = {
        ENTITY_PLAYER = 1,
        ENTITY_FAMILIAR = 3,
        ENTITY_PICKUP = 5,
        ENTITY_EFFECT = 1000,
        ENTITY_FLY = 13,
        ENTITY_DUKE = 67,
    }
    EffectVariant = { POOF01 = 15 }
    PickupVariant = {
        PICKUP_HEART = 10,
        PICKUP_COLLECTIBLE = 100,
        PICKUP_TAROTCARD = 300,
    }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = {
        ROOM_DEFAULT = 1,
        ROOM_BOSS = 5,
        ROOM_DEVIL = 14,
        ROOM_ANGEL = 15,
    }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }
    GameStateFlag = {
        STATE_DEVILROOM_SPAWNED = 5,
        STATE_DEVILROOM_VISITED = 6,
    }
    GridRooms = { ROOM_DEVIL_IDX = -1 }

    local room = {
        roomType = RoomType.ROOM_DEFAULT,
        clear = false,
        spawnSeed = 5000,
        center = nil,
    }
    function room:GetType()
        return self.roomType
    end
    function room:IsClear()
        return self.clear
    end
    function room:GetSpawnSeed()
        return self.spawnSeed
    end
    function room:GetCenterPos()
        return self.center or Vector(320, 280)
    end
    function room:FindFreePickupSpawnPosition(position)
        return position
    end

    local level = { stage = 1, stageType = 0, currentRoomIndex = 0 }
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
                return { GetCollectible = function() return CollectibleType.COLLECTIBLE_NULL end }
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
            if name == "Between Death and Life" or name == "生死一念间" then
                return itemIds.BetweenDeathAndLife
            end
            if name == "Death Certificate" then
                return itemIds.DeathCertificate
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
            return {}
        end,
        DebugString = function() end,
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
            return { GetCollectible = function() return { Quality = 4 } end }
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

    local function runUse(player, slot)
        local callbacksForItem = getCallbacks(ModCallbacks.MC_USE_ITEM, itemIds.BetweenDeathAndLife)
        assertTruthy(callbacksForItem[1], "Between Death and Life use callback should be registered")
        return callbacksForItem[1](mod, itemIds.BetweenDeathAndLife, nil, player, 0, slot or ActiveSlot.SLOT_PRIMARY, 0)
    end

    local function runPostAddCollectible(player, slot)
        local callbacksForItem = getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemIds.BetweenDeathAndLife)
        assertTruthy(callbacksForItem[1], "Between Death and Life pickup callback should be registered")
        callbacksForItem[1](
            mod,
            itemIds.BetweenDeathAndLife,
            player:GetActiveCharge(slot or ActiveSlot.SLOT_PRIMARY),
            true,
            slot or ActiveSlot.SLOT_PRIMARY,
            0,
            player
        )
    end

    local function runPostNpcInit(npc)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NPC_INIT)) do
            callback(mod, npc)
        end
    end

    local function runPostUpdate()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do
            callback(mod)
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
            activeItems = optionsForPlayer.activeItems or { [ActiveSlot.SLOT_PRIMARY] = itemIds.BetweenDeathAndLife },
            activeCharges = optionsForPlayer.activeCharges or { [ActiveSlot.SLOT_PRIMARY] = 12 },
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
        function player:RemoveCollectible(itemId, ignoreModifiers, slot, removeFromPlayerForm)
            self.removeCalls[#self.removeCalls + 1] = {
                itemId = itemId,
                ignoreModifiers = ignoreModifiers,
                slot = slot,
                removeFromPlayerForm = removeFromPlayerForm,
            }
            self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] = 0
        end
        function player:GetCollectibleNum()
            return 0
        end
        function player:AddCacheFlags() end
        function player:EvaluateItems() end
        players[#players + 1] = player
        return player
    end

    local function newNpc(optionsForNpc)
        optionsForNpc = optionsForNpc or {}
        local data = {}
        local npc = {
            Type = optionsForNpc.type or EntityType.ENTITY_FLY,
            Variant = optionsForNpc.variant or 0,
            SubType = optionsForNpc.subtype or 0,
            InitSeed = optionsForNpc.initSeed or (nextSeed + 1),
            Position = optionsForNpc.position or Vector(180, 180),
            MaxHitPoints = optionsForNpc.maxHp or 100,
            HitPoints = optionsForNpc.hp or optionsForNpc.maxHp or 100,
            MoveSpeed = optionsForNpc.moveSpeed or 1,
            flags = optionsForNpc.flags or 0,
            isBoss = optionsForNpc.isBoss == true,
            champion = optionsForNpc.champion == true,
            makeChampionCalls = {},
            colors = {},
        }
        nextSeed = npc.InitSeed
        function npc:ToNPC()
            return self
        end
        function npc:ToPlayer()
            return nil
        end
        function npc:GetData()
            return data
        end
        function npc:IsVulnerableEnemy()
            return optionsForNpc.vulnerable ~= false
        end
        function npc:HasEntityFlags(flag)
            return (self.flags & flag) ~= 0
        end
        function npc:IsBoss()
            return self.isBoss
        end
        function npc:IsChampion()
            return self.champion
        end
        if optionsForNpc.noMakeChampion ~= true then
            function npc:MakeChampion(seed, championType, init)
                self.champion = true
                self.makeChampionCalls[#self.makeChampionCalls + 1] = {
                    seed = seed,
                    championType = championType,
                    init = init,
                }
            end
        end
        function npc:SetColor(color, duration, priority, fadeout, share)
            self.colors[#self.colors + 1] = {
                color = color,
                duration = duration,
                priority = priority,
                fadeout = fadeout,
                share = share,
            }
        end
        return npc
    end

    return {
        mod = mod,
        items = itemIds,
        room = room,
        level = level,
        spawned = spawned,
        runUse = runUse,
        runPostAddCollectible = runPostAddCollectible,
        runPostNpcInit = runPostNpcInit,
        runPostUpdate = runPostUpdate,
        runPostGameStarted = runPostGameStarted,
        newPlayer = newPlayer,
        newNpc = newNpc,
        savedData = function()
            return savedData
        end,
    }
end

local function getItemXmlAttribute(itemName, attribute)
    local text = readFile("content/items.xml")
    local block = text:match('<active%s+name="' .. itemName .. '"(.-)/>')
    assertTruthy(block, "items.xml should contain active item " .. itemName)
    return block:match(attribute .. '="([^"]+)"')
end

local function countDeathCertificateSpawns(env)
    local count = 0
    for _, spawn in ipairs(env.spawned) do
        if spawn.Type == EntityType.ENTITY_PICKUP
            and spawn.Variant == PickupVariant.PICKUP_COLLECTIBLE
            and spawn.SubType == env.items.DeathCertificate then
            count = count + 1
        end
    end
    return count
end

local function test_xml_registers_active_twelve_charge_item_and_pools()
    assertEquals(getItemXmlAttribute("Between Death and Life", "maxcharges"), "12", "Between Death and Life should have 12 charges")
    assertEquals(getItemXmlAttribute("Between Death and Life", "gfx"), "BetweenDeathAndLife.png", "Between Death and Life should use the provided icon name")

    local pools = readFile("content/itempools.xml")
    assertTruthy(pools:find('<Pool Name="secret".-<Item Name="Between Death and Life" Weight="1"', 1), "Between Death and Life should be in secret pool")
    assertTruthy(pools:find('<Pool Name="devil".-<Item Name="Between Death and Life" Weight="1"', 1), "Between Death and Life should be in devil pool")
    assertTruthy(pools:find('<Pool Name="curse".-<Item Name="Between Death and Life" Weight="1"', 1), "Between Death and Life should be in curse pool")
end

local function test_use_activates_trial_and_consumes_item()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    local result = env.runUse(player)

    assertEquals(result, true, "successful use should return true")
    assertEquals(#player.removeCalls, 1, "single-use active should remove itself")
    assertEquals(player.removeCalls[1].itemId, env.items.BetweenDeathAndLife, "Between Death and Life should be consumed")
end

local function test_pickup_immediately_activates_trial_and_consumes_item()
    local env = loadNeverbirth()
    local player = env.newPlayer({ activeCharges = { [ActiveSlot.SLOT_PRIMARY] = 0 } })

    env.runPostAddCollectible(player)
    env.level.currentRoomIndex = 1
    local enemy = env.newNpc({ type = EntityType.ENTITY_FLY })
    env.runPostNpcInit(enemy)

    assertEquals(#player.removeCalls, 1, "pickup should immediately consume Between Death and Life")
    assertEquals(player.removeCalls[1].itemId, env.items.BetweenDeathAndLife, "pickup consumption should remove Between Death and Life")
    assertEquals(enemy.champion, true, "pickup should activate Death Trial without requiring manual use or charge")
end

local function test_use_does_not_stack_trial()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runUse(player)
    player.activeItems[ActiveSlot.SLOT_PRIMARY] = env.items.BetweenDeathAndLife
    env.runUse(player)

    assertEquals(#player.removeCalls, 2, "second use should only consume the extra item copy")
end

local function test_normal_enemy_spawn_after_activation_becomes_champion()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runUse(player)
    env.level.currentRoomIndex = 1
    local enemy = env.newNpc({ type = EntityType.ENTITY_FLY })

    env.runPostNpcInit(enemy)

    assertEquals(enemy.champion, true, "normal enemy should be made champion after activation")
    assertTruthy(enemy:GetData().neverbirthDeathTrialElite == true, "enemy should be marked to avoid double processing")
end

local function test_activation_room_spawn_is_not_elite_until_later_rooms()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.level.currentRoomIndex = 0
    env.runUse(player)
    local sameRoomEnemy = env.newNpc({ type = EntityType.ENTITY_FLY })
    env.runPostNpcInit(sameRoomEnemy)
    env.level.currentRoomIndex = 1
    local laterEnemy = env.newNpc({ type = EntityType.ENTITY_FLY })
    env.runPostNpcInit(laterEnemy)

    assertEquals(sameRoomEnemy.champion, false, "enemies in the activation room should not be retroactively empowered")
    assertEquals(laterEnemy.champion, true, "later room enemies should be empowered")
end

local function test_boss_without_champion_api_is_empowered()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runUse(player)
    env.level.currentRoomIndex = 1
    local boss = env.newNpc({
        type = EntityType.ENTITY_DUKE,
        isBoss = true,
        maxHp = 200,
        hp = 200,
        noMakeChampion = true,
    })

    env.runPostNpcInit(boss)

    assertEquals(boss.MaxHitPoints, 300, "boss fallback empowerment should increase max HP by 50%")
    assertEquals(boss.HitPoints, 300, "boss fallback empowerment should sync current HP")
    assertTruthy(#boss.colors > 0, "boss fallback empowerment should add a visual marker")
end

local function test_true_floor_boss_clear_spawns_death_certificate_once()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runUse(player)
    env.room.roomType = RoomType.ROOM_BOSS
    env.room.clear = true

    env.runPostUpdate()
    env.runPostUpdate()

    assertEquals(countDeathCertificateSpawns(env), 1, "cleared boss room should spawn one Death Certificate")
end

local function test_boss_defeated_before_activation_does_not_backfill_reward()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.room.roomType = RoomType.ROOM_BOSS
    env.room.clear = true
    env.runPostUpdate()

    env.runUse(player)
    env.runPostUpdate()

    assertEquals(countDeathCertificateSpawns(env), 0, "boss clear before activation should not be backfilled")
end

local function test_new_run_resets_trial_state()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runUse(player)
    env.runPostGameStarted(false)
    env.level.currentRoomIndex = 1
    local enemy = env.newNpc({ type = EntityType.ENTITY_FLY })

    env.runPostNpcInit(enemy)

    assertEquals(enemy.champion, false, "new run should reset Death Trial state")
end

test_xml_registers_active_twelve_charge_item_and_pools()
test_use_activates_trial_and_consumes_item()
test_pickup_immediately_activates_trial_and_consumes_item()
test_use_does_not_stack_trial()
test_normal_enemy_spawn_after_activation_becomes_champion()
test_activation_room_spawn_is_not_elite_until_later_rooms()
test_boss_without_champion_api_is_empowered()
test_true_floor_boss_clear_spawns_death_certificate_once()
test_boss_defeated_before_activation_does_not_backfill_reward()
test_new_run_resets_trial_state()

print("between death and life behavior tests passed")
