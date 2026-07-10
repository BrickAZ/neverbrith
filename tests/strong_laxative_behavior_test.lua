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

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > epsilon then
        error((message or "expected near value") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
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
    local players = {}
    local roomEntities = {}
    local spawns = {}
    local gridSpawns = {}
    local itemIds = {
        StrongLaxative = 755,
    }
    local costumeIds = {
        ["gfx/characters/costume_strong_laxative.anm2"] = 9201,
    }
    local rngValues = options.rngValues or {}
    local rngIndex = 0

    package.loaded.json = nil
    package.preload.json = function()
        return { encode = function() return "{}" end, decode = function() return {} end }
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
        MC_POST_EFFECT_UPDATE = 14,
    }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_EFFECT = 1000 }
    EffectVariant = { POOF01 = 1, PLAYER_CREEP_BLACK = 3, CREEP_RED = 4, CREEP_GREEN = 5, PLAYER_CREEP_GREEN = 6 }
    GridEntityType = { GRID_POOP = 14 }
    PickupVariant = { PICKUP_COLLECTIBLE = 100 }
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_LUCK = 1024 }
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_FAKE = 8 }
    EntityFlag = { FLAG_FRIENDLY = 2 }
    RoomType = { ROOM_DEFAULT = 1 }
    ItemPoolType = { POOL_TREASURE = 0 }
    ActiveSlot = { SLOT_PRIMARY = 0 }
    CollectibleType = { COLLECTIBLE_NULL = 0 }

    local roomIndex = options.roomIndex or 1
    local spawnSeed = options.spawnSeed or 5000

    local room = {}
    function room:GetSpawnSeed() return spawnSeed end
    function room:GetCenterPos() return Vector(320, 280) end
    function room:GetType() return RoomType.ROOM_DEFAULT end
    function room:IsClear() return false end
    function room:IsPositionInRoom(pos) return pos and pos.X >= 0 and pos.X <= 640 and pos.Y >= 0 and pos.Y <= 560 end
    function room:FindFreePickupSpawnPosition(pos) return pos end
    function room:GetGridIndex(pos) return math.floor((pos.X or 0) / 40) + math.floor((pos.Y or 0) / 40) * 20 end
    function room:SpawnGridEntity(index, gridType, variant, seed, varData)
        gridSpawns[#gridSpawns + 1] = { index = index, gridType = gridType, variant = variant, seed = seed, varData = varData }
        return gridSpawns[#gridSpawns]
    end

    function MusicManager()
        return { GetCurrentMusicID = function() return 1 end, Play = function() end, Fadeout = function() end }
    end

    function Game()
        return {
            GetSeeds = function() return { GetStartSeedString = function() return "TEST RUN" end } end,
            GetNumPlayers = function() return #players end,
            GetPlayer = function(_, index) return players[(index or 0) + 1] end,
            GetRoom = function() return room end,
            GetLevel = function()
                return {
                    GetStage = function() return 1 end,
                    GetStageType = function() return 0 end,
                    GetCurrentRoomIndex = function() return roomIndex end,
                }
            end,
            GetItemPool = function() return { GetCollectible = function() return CollectibleType.COLLECTIBLE_NULL end } end,
            GetStateFlag = function() return false end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Strong Laxative" or name == "强力泻药" then return itemIds.StrongLaxative end
            return -1
        end,
        GetMusicIdByName = function() return -1 end,
        GetPlayer = function(index) return players[(index or 0) + 1] end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then return players end
            return {}
        end,
        GetRoomEntities = function() return roomEntities end,
        DebugString = function() end,
        GetCostumeIdByPath = function(path)
            if options.missingCostume then return -1 end
            return costumeIds[path] or -1
        end,
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            local entity = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                Velocity = velocity,
                SpawnerEntity = spawner,
                InitSeed = #spawns + 900,
                FrameCount = 0,
                data = {},
                removed = false,
            }
            function entity:GetData() return self.data end
            function entity:ToEffect() return self end
            function entity:Remove() self.removed = true end
            function entity:SetColor(color) self.color = color end
            spawns[#spawns + 1] = entity
            if entityType == EntityType.ENTITY_EFFECT then
                roomEntities[#roomEntities + 1] = entity
            end
            return entity
        end,
        GetItemConfig = function()
            return { GetCollectible = function() return { Tags = 0, Type = 3, MaxCharges = 0, Name = "Mock" } end, GetCollectibles = function() return {} end }
        end,
    }

    Color = setmetatable({}, { __call = function(_, r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo } end })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)
    local vectorMeta = {
        __add = function(left, right) return Vector(left.X + right.X, left.Y + right.Y) end,
        __sub = function(left, right) return Vector(left.X - right.X, left.Y - right.Y) end,
        __mul = function(left, scalar) return Vector(left.X * scalar, left.Y * scalar) end,
    }
    function Vector(x, y)
        return setmetatable({
            X = x or 0,
            Y = y or 0,
            Length = function(self) return math.sqrt(self.X * self.X + self.Y * self.Y) end,
            Normalized = function(self)
                local length = self:Length()
                if length <= 0 then return Vector(1, 0) end
                return Vector(self.X / length, self.Y / length)
            end,
        }, vectorMeta)
    end
    function EntityRef(entity) return { Entity = entity } end

    local function nextRngValue(max)
        rngIndex = rngIndex + 1
        local value = rngValues[rngIndex] or 0
        return math.max(0, math.min(max - 1, math.floor(value)))
    end

    local mod
    function RegisterMod(name, version)
        mod = { Name = name, Version = version }
        function mod:AddCallback(callbackId, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
        end
        function mod:HasData() return false end
        function mod:LoadData() return "{}" end
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

    local function newPlayer(opts)
        opts = opts or {}
        local player = {
            Type = EntityType.ENTITY_PLAYER,
            InitSeed = opts.initSeed or (#players + 100),
            Position = opts.position or Vector(120, 100),
            Velocity = opts.velocity or Vector(0, 0),
            Damage = opts.damage or 10,
            collectibles = opts.collectibles or {},
            nullCostumes = {},
            addedNullCostumes = {},
            removedNullCostumes = {},
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetCollectibleRNG()
            return { RandomInt = function(_, max) return nextRngValue(max) end }
        end
        function player:AddNullCostume(costumeId)
            self.addedNullCostumes[#self.addedNullCostumes + 1] = costumeId
            self.nullCostumes[costumeId] = true
        end
        function player:TryRemoveNullCostume(costumeId)
            self.removedNullCostumes[#self.removedNullCostumes + 1] = costumeId
            self.nullCostumes[costumeId] = nil
        end
        players[#players + 1] = player
        roomEntities[#roomEntities + 1] = player
        return player
    end

    local function newEnemy(pos)
        local enemy = { Type = 10, InitSeed = #roomEntities + 300, Position = pos or Vector(120, 100), damageTaken = 0, slowed = 0, data = {} }
        function enemy:IsVulnerableEnemy() return true end
        function enemy:ToNPC() return self end
        function enemy:GetData() return self.data end
        function enemy:TakeDamage(amount) self.damageTaken = self.damageTaken + amount end
        function enemy:AddSlowing(_, duration) self.slowed = self.slowed + (duration or 0) end
        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    local function runPostUpdate(times)
        for _ = 1, times or 1 do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback(mod) end
        end
    end

    local function runEffectUpdate(effect, times)
        for _ = 1, times or 1 do
            effect.FrameCount = (effect.FrameCount or 0) + 1
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_EFFECT_UPDATE, effect.Variant)) do
                callback(mod, effect)
            end
        end
    end

    local function runNewRoom(newIndex)
        if newIndex then roomIndex = newIndex end
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback(mod) end
    end

    local function runDamage(player, source)
        local result
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER)) do
            local value = callback(mod, player, 1, 0, EntityRef(source), 0)
            if value == false then result = false end
        end
        return result
    end

    local function runAddCollectible(itemId, player)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemId)) do
            callback(mod, itemId, 0, true, 0, 0, player)
        end
    end

    return {
        items = itemIds,
        costumes = costumeIds,
        players = players,
        spawns = spawns,
        gridSpawns = gridSpawns,
        roomEntities = roomEntities,
        newPlayer = newPlayer,
        newEnemy = newEnemy,
        runPostUpdate = runPostUpdate,
        runEffectUpdate = runEffectUpdate,
        runNewRoom = runNewRoom,
        runDamage = runDamage,
        runAddCollectible = runAddCollectible,
    }
end

local function countStrongLaxativeCreeps(env)
    local count = 0
    for _, spawn in ipairs(env.spawns) do
        if spawn.GetData and spawn:GetData().NeverbirthStrongLaxativeCreep then
            count = count + 1
        end
    end
    return count
end

local function lastStrongLaxativeCreep(env)
    for index = #env.spawns, 1, -1 do
        local spawn = env.spawns[index]
        if spawn.GetData and spawn:GetData().NeverbirthStrongLaxativeCreep then
            return spawn
        end
    end
    return nil
end

local function test_xml_registers_strong_laxative_item_and_pools()
    local items = readFile("content/items.xml")
    local zhItems = readFile("content/items.zh_cn.xml")
    local enItems = readFile("content/items.en_us.xml")
    local pools = readFile("content/itempools.xml")

    assertTruthy(items:find('<passive%s+name="Strong Laxative".-quality="0"', 1), "Strong Laxative should be a quality 0 passive")
    assertTruthy(zhItems:find('name="强力泻药"', 1), "zh item xml should register Strong Laxative")
    assertTruthy(enItems:find('name="Strong Laxative"', 1), "en item xml should register Strong Laxative")
    assertTruthy(pools:find('<Pool Name="treasure".-<Item Name="Strong Laxative" Weight="1"', 1), "Strong Laxative should be in treasure")
    assertTruthy(pools:find('<Pool Name="curse".-<Item Name="Strong Laxative" Weight="1"', 1), "Strong Laxative should be in curse")
    assertTruthy(pools:find('<Pool Name="rottenBeggar".-<Item Name="Strong Laxative" Weight="1"', 1), "Strong Laxative should be in rotten beggar")
end

local function test_costume_anm2_uses_static_head_animations()
    local anm2 = readFile("resources/gfx/characters/costume_strong_laxative.anm2")

    assertTruthy(anm2:find('<Animations DefaultAnimation="HeadDown"', 1, true), "Strong Laxative costume should default to HeadDown")
    assertTruthy(anm2:find('<Layer Name="head2" Id="0" SpritesheetId="0" />', 1, true), "Strong Laxative costume should use the head2 layer")
    assertTruthy(anm2:find('<Spritesheet Id="0" Path="costumes\\costume_strong_laxative.png" />', 1, true), "Strong Laxative costume should reference its costume spritesheet")

    for _, name in ipairs({ "HeadDown", "HeadRight", "HeadUp", "HeadLeft" }) do
        assertTruthy(anm2:find('<Animation Name="' .. name .. '" FrameNum="4" Loop="false">', 1, true), name .. " should be a non-looping head costume animation")
    end
end

local function test_moving_player_leaves_creep_but_standing_still_does_not_stack()
    local env = loadNeverbirth()
    local player = env.newPlayer({ velocity = Vector(2, 0), collectibles = { [env.items.StrongLaxative] = 1 } })

    env.runPostUpdate(1)
    assertEquals(countStrongLaxativeCreeps(env), 1, "moving player should leave one creep")

    player.Velocity = Vector(0, 0)
    env.runPostUpdate(20)
    assertEquals(countStrongLaxativeCreeps(env), 1, "standing still should not keep spawning creep")
end

local function test_creep_expires_after_two_to_three_seconds()
    local env = loadNeverbirth()
    local player = env.newPlayer({ velocity = Vector(2, 0), collectibles = { [env.items.StrongLaxative] = 1 } })
    env.runPostUpdate(1)
    local creep = lastStrongLaxativeCreep(env)

    env.runEffectUpdate(creep, 119)
    assertEquals(creep.removed, false, "creep should last at least about two seconds")
    env.runEffectUpdate(creep, 31)
    assertEquals(creep.removed, true, "creep should expire before three seconds")
end

local function test_creep_slows_and_damages_enemy_every_ten_frames()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 20, velocity = Vector(2, 0), collectibles = { [env.items.StrongLaxative] = 1 } })
    local enemy = env.newEnemy(player.Position)
    env.runPostUpdate(1)
    local creep = lastStrongLaxativeCreep(env)

    env.runEffectUpdate(creep, 9)
    assertEquals(enemy.damageTaken, 0, "creep should not damage every frame")
    assertTruthy(enemy.slowed > 0, "creep should apply the native slow effect")

    env.runEffectUpdate(creep, 1)
    assertNear(enemy.damageTaken, 2, 0.0001, "creep should deal 10 percent player damage every 10 frames")
    env.runEffectUpdate(creep, 10)
    assertNear(enemy.damageTaken, 4, 0.0001, "creep damage should repeat on the 10-frame cadence")
end

local function test_player_damage_from_own_laxative_creep_is_cancelled()
    local env = loadNeverbirth()
    local player = env.newPlayer({ velocity = Vector(2, 0), collectibles = { [env.items.StrongLaxative] = 1 } })
    env.runPostUpdate(1)
    local creep = lastStrongLaxativeCreep(env)

    assertEquals(env.runDamage(player, creep), false, "player should not be damaged by Strong Laxative creep")
end

local function test_poop_roll_checks_once_per_second_and_probability_stacks()
    local env = loadNeverbirth({ rngValues = { 4, 0, 9, 0 } })
    env.newPlayer({ velocity = Vector(0, 0), collectibles = { [env.items.StrongLaxative] = 1 } })

    env.runPostUpdate(59)
    assertEquals(#env.gridSpawns, 0, "poop roll should not happen before one second")
    env.runPostUpdate(1)
    assertEquals(#env.gridSpawns, 1, "one copy should spawn at 5 percent roll")

    local env2 = loadNeverbirth({ rngValues = { 9, 0 } })
    env2.newPlayer({ velocity = Vector(0, 0), collectibles = { [env2.items.StrongLaxative] = 2 } })
    env2.runPostUpdate(60)
    assertEquals(#env2.gridSpawns, 1, "two copies should spawn at 10 percent roll")
end

local function test_poop_room_cap_and_room_reset()
    local values = {}
    for _ = 1, 40 do
        values[#values + 1] = 0
    end
    local env = loadNeverbirth({ rngValues = values })
    env.newPlayer({ velocity = Vector(0, 0), collectibles = { [env.items.StrongLaxative] = 1 } })

    env.runPostUpdate(60 * 20)
    assertEquals(#env.gridSpawns, 15, "Strong Laxative should cap poop at 15 per room")

    env.runNewRoom(2)
    env.runPostUpdate(60)
    assertEquals(#env.gridSpawns, 16, "new room should reset the Strong Laxative poop cap")
end

local function test_random_poop_uses_multiple_vanilla_variants()
    local values = {}
    for index = 0, 11 do
        values[#values + 1] = 0
        values[#values + 1] = 0
        values[#values + 1] = index
    end
    local env = loadNeverbirth({ rngValues = values })
    env.newPlayer({ velocity = Vector(0, 0), collectibles = { [env.items.StrongLaxative] = 1 } })

    env.runPostUpdate(60 * 12)

    local variants = {}
    for _, spawn in ipairs(env.gridSpawns) do
        variants[spawn.variant] = true
    end
    local count = 0
    for _ in pairs(variants) do count = count + 1 end
    assertTruthy(count > 3, "random poop should draw from multiple vanilla poop variants")
end

local function test_costume_is_applied_and_removed_when_item_state_changes()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    env.runAddCollectible(env.items.StrongLaxative, player)
    assertTruthy(player.nullCostumes[env.costumes["gfx/characters/costume_strong_laxative.anm2"]], "pickup should apply the Strong Laxative face costume")

    player.collectibles[env.items.StrongLaxative] = 0
    env.runPostUpdate(1)
    assertEquals(player.nullCostumes[env.costumes["gfx/characters/costume_strong_laxative.anm2"]], nil, "costume should not remain after losing the item")

    player.collectibles[env.items.StrongLaxative] = 1
    env.runPostUpdate(1)
    assertTruthy(player.nullCostumes[env.costumes["gfx/characters/costume_strong_laxative.anm2"]], "costume should refresh after appearance reload/update")
end

test_xml_registers_strong_laxative_item_and_pools()
test_costume_anm2_uses_static_head_animations()
test_moving_player_leaves_creep_but_standing_still_does_not_stack()
test_creep_expires_after_two_to_three_seconds()
test_creep_slows_and_damages_enemy_every_ten_frames()
test_player_damage_from_own_laxative_creep_is_cancelled()
test_poop_roll_checks_once_per_second_and_probability_stacks()
test_poop_room_cap_and_room_reset()
test_random_poop_uses_multiple_vanilla_variants()
test_costume_is_applied_and_removed_when_item_state_changes()

print("strong laxative behavior tests passed")
