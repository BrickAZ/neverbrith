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
    local players = {}
    local roomEntities = {}
    local spawns = {}
    local gridSpawns = {}
    local itemIds = {
        StrongLaxative = 755,
        TowerOfBabel = 756,
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
        MC_POST_EFFECT_INIT = 15,
    }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_EFFECT = 1000 }
    EffectVariant = {
        POOF01 = 1,
        CREEP_RED = 4,
        CREEP_GREEN = 5,
        CREEP_BLACK = 6,
        CREEP_WHITE = 7,
        CREEP_YELLOW = 8,
        PLAYER_CREEP_GREEN = 9,
        PLAYER_CREEP_BLACK = 10,
        PLAYER_CREEP_WHITE = 11,
    }
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

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end
        return found
    end

    local function nextRngValue(max)
        rngIndex = rngIndex + 1
        local value = rngValues[rngIndex] or 0
        return math.max(0, math.min(max - 1, math.floor(value)))
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "Strong Laxative" or name == "强力泻药" then return itemIds.StrongLaxative end
            if name == "Tower of Babel" or name == "通天塔" then return itemIds.TowerOfBabel end
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
        GetCostumeIdByPath = function() return -1 end,
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
                for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_EFFECT_INIT, variant)) do
                    callback(mod, entity)
                end
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

    local function newPlayer(opts)
        opts = opts or {}
        local player = {
            Type = EntityType.ENTITY_PLAYER,
            InitSeed = opts.initSeed or (#players + 100),
            Position = opts.position or Vector(120, 100),
            Velocity = opts.velocity or Vector(0, 0),
            Damage = opts.damage or 10,
            collectibles = opts.collectibles or {},
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetCollectibleRNG()
            return { RandomInt = function(_, max) return nextRngValue(max) end }
        end
        players[#players + 1] = player
        roomEntities[#roomEntities + 1] = player
        return player
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

    local function spawnEffect(variant)
        return Isaac.Spawn(EntityType.ENTITY_EFFECT, variant, 0, Vector(120, 100), Vector(0, 0), nil)
    end

    return {
        items = itemIds,
        effect = EffectVariant,
        spawns = spawns,
        gridSpawns = gridSpawns,
        newPlayer = newPlayer,
        spawnEffect = spawnEffect,
        runPostUpdate = runPostUpdate,
        runEffectUpdate = runEffectUpdate,
    }
end

local function test_xml_registers_tower_of_babel_item_and_pools()
    local items = readFile("content/items.xml")
    local zhItems = readFile("content/items.zh_cn.xml")
    local enItems = readFile("content/items.en_us.xml")
    local pools = readFile("content/itempools.xml")

    assertTruthy(items:find('<passive%s+name="Tower of Babel".-quality="1"', 1), "Tower of Babel should be a quality 1 passive")
    assertTruthy(items:find('<passive%s+name="Tower of Babel".-tags="defensive anti%-terrain"', 1), "Tower of Babel should use defensive anti-terrain tags")
    assertTruthy(zhItems:find('name="通天塔"', 1), "zh item xml should register Tower of Babel")
    assertTruthy(enItems:find('name="Tower of Babel"', 1), "en item xml should register Tower of Babel")
    assertTruthy(pools:find('<Pool Name="treasure".-<Item Name="Tower of Babel" Weight="1"', 1), "Tower of Babel should be in treasure")
    assertTruthy(pools:find('<Pool Name="boss".-<Item Name="Tower of Babel" Weight="1"', 1), "Tower of Babel should be in boss")
end

local function test_tower_of_babel_removes_new_enemy_player_and_neutral_creep()
    local env = loadNeverbirth()
    env.newPlayer({ collectibles = { [env.items.TowerOfBabel] = 1 } })

    assertEquals(env.spawnEffect(env.effect.CREEP_RED).removed, true, "enemy red creep should be removed immediately")
    assertEquals(env.spawnEffect(env.effect.PLAYER_CREEP_GREEN).removed, true, "player creep should be removed immediately")
    assertEquals(env.spawnEffect(env.effect.CREEP_WHITE).removed, true, "neutral white creep should be removed immediately")
end

local function test_tower_of_babel_does_not_remove_existing_creep_or_non_creep_effects()
    local env = loadNeverbirth()
    local preexistingCreep = env.spawnEffect(env.effect.CREEP_GREEN)
    preexistingCreep.FrameCount = 30
    assertEquals(preexistingCreep.removed, false, "creep spawned before Tower of Babel should remain")

    env.newPlayer({ collectibles = { [env.items.TowerOfBabel] = 1 } })
    env.runEffectUpdate(preexistingCreep, 1)
    assertEquals(preexistingCreep.removed, false, "Tower of Babel should not actively clear old creep")

    local poof = env.spawnEffect(env.effect.POOF01)
    assertEquals(poof.removed, false, "non-creep effects should not be removed")
end

local function test_no_tower_of_babel_keeps_creep()
    local env = loadNeverbirth()
    env.newPlayer()

    local creep = env.spawnEffect(env.effect.CREEP_BLACK)
    assertEquals(creep.removed, false, "creep should stay when no player owns Tower of Babel")
end

local function test_strong_laxative_poop_stays_but_creep_is_removed_with_tower_of_babel()
    local env = loadNeverbirth({ rngValues = { 0, 0, 0 } })
    env.newPlayer({ velocity = Vector(2, 0), collectibles = { [env.items.StrongLaxative] = 1, [env.items.TowerOfBabel] = 1 } })

    env.runPostUpdate(60)

    local removedStrongCreep = false
    for _, spawn in ipairs(env.spawns) do
        local data = spawn.GetData and spawn:GetData() or nil
        if data and data.NeverbirthStrongLaxativeCreep then
            removedStrongCreep = removedStrongCreep or spawn.removed == true
        end
    end

    assertTruthy(removedStrongCreep, "Tower of Babel should remove Strong Laxative creep")
    assertEquals(#env.gridSpawns, 1, "Tower of Babel should not block Strong Laxative poop")
end

test_xml_registers_tower_of_babel_item_and_pools()
test_tower_of_babel_removes_new_enemy_player_and_neutral_creep()
test_tower_of_babel_does_not_remove_existing_creep_or_non_creep_effects()
test_no_tower_of_babel_keeps_creep()
test_strong_laxative_poop_stays_but_creep_is_removed_with_tower_of_babel()

print("tower of babel behavior tests passed")
