-- Extracted engine double; original behavior assertions remain in the test.
return function()
function include(name) return dofile(name:gsub("%.", "/") .. ".lua") end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

local function assertNear(actual, expected, epsilon, message)
    epsilon = epsilon or 0.000001
    if math.abs(actual - expected) > epsilon then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local VectorMt = {}
VectorMt.__index = VectorMt
function VectorMt.__sub(left, right)
    return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y }, VectorMt)
end
function VectorMt:LengthSquared() return self.X * self.X + self.Y * self.Y end
function VectorMt.__eq(left, right) return left.X == right.X and left.Y == right.Y end
Vector = setmetatable({}, {
    __call = function(_, x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, VectorMt)
    end,
})
Vector.Zero = Vector(0, 0)

ModCallbacks = {
    MC_USE_ITEM = 1,
    MC_POST_UPDATE = 2,
    MC_EVALUATE_CACHE = 3,
    MC_POST_FIRE_TEAR = 4,
    MC_POST_NPC_INIT = 5,
    MC_POST_NPC_DEATH = 6,
    MC_POST_ENTITY_KILL = 7,
    MC_POST_NEW_ROOM = 8,
    MC_POST_GAME_STARTED = 9,
    MC_PRE_GAME_EXIT = 10,
    MC_NPC_UPDATE = 11,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_NPC = 10, ENTITY_EFFECT = 1000 }
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2 }
EntityCollisionClass = { ENTCOLL_NONE = 0 }
GridCollisionClass = { COLLISION_NONE = 0 }
CacheFlag = { CACHE_FIREDELAY = 1, CACHE_RANGE = 2 }
CollectibleType = { COLLECTIBLE_CAR_BATTERY = 356 }
ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2, SLOT_POCKET2 = 3 }

local function makeSprite()
    local sprite = { loadCount = 0, playCount = 0, Rotation = 99, Scale = Vector(3, 3) }
    function sprite:Load(path)
        self.loadCount = self.loadCount + 1
        self.path = path
    end
    function sprite:Play(animation)
        self.playCount = self.playCount + 1
        self.animation = animation
    end
    return sprite
end

local function makeEffect(variant, position, spawner)
    local effect = {
        Type = EntityType.ENTITY_EFFECT,
        Variant = variant,
        Position = position,
        Velocity = Vector.Zero,
        SpawnerEntity = spawner,
        sprite = makeSprite(),
        data = {},
        removed = false,
    }
    function effect:GetSprite() return self.sprite end
    function effect:GetData() return self.data end
    function effect:Exists() return not self.removed end
    function effect:Remove() self.removed = true end
    return effect
end

local function makePlayer(seed, position)
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = seed,
        Position = position or Vector(100, 100),
        Damage = 10,
        TearRange = 100,
        MaxFireDelay = 9,
        cacheFlags = 0,
        evaluateCalls = 0,
        dead = false,
        collectibles = {},
        activeItems = {
            [ActiveSlot.SLOT_PRIMARY] = 6001,
            [ActiveSlot.SLOT_SECONDARY] = 6002,
            [ActiveSlot.SLOT_POCKET] = 6003,
        },
        activeCharges = {
            [ActiveSlot.SLOT_PRIMARY] = 0,
            [ActiveSlot.SLOT_SECONDARY] = 0,
            [ActiveSlot.SLOT_POCKET] = 0,
        },
    }
    function player:ToPlayer() return self end
    function player:Exists() return true end
    function player:IsDead() return self.dead end
    function player:AddCacheFlags(flags) self.cacheFlags = self.cacheFlags | flags end
    function player:EvaluateItems() self.evaluateCalls = self.evaluateCalls + 1 end
    function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
    function player:GetActiveItem(slot) return self.activeItems[slot] or 0 end
    function player:GetActiveCharge(slot) return self.activeCharges[slot] or 0 end
    function player:SetActiveCharge() error("manual charging is forbidden") end
    function player:AddActiveCharge(charge, slot, flashHud, overcharge, force)
        self.nativeChargeCalls = self.nativeChargeCalls or {}
        self.nativeChargeCalls[#self.nativeChargeCalls + 1] = { charge, slot, flashHud, overcharge, force }
        if self.nativeChargeError then error("native charge failure") end
        if self.nativeChargeResult ~= nil then return self.nativeChargeResult end
        local config = self.nativeConfigs[self.activeItems[slot] or 0]
        local maximum = config and config.MaxCharges or 0
        -- Match the current engine's charge-type gate before its capacity clamp.
        local chargeType = config and config.ChargeType or 0
        if charge > 0 and not force then
            if chargeType == 2 then return 0 end
            if chargeType == 1 then charge = maximum end
        end
        local added = math.max(0, math.min(charge, maximum - (self.activeCharges[slot] or 0)))
        self.activeCharges[slot] = (self.activeCharges[slot] or 0) + added
        return added
    end
    return player
end

local function makeNpc(options)
    options = options or {}
    local npc = {
        Type = EntityType.ENTITY_NPC,
        InitSeed = options.seed or 1001,
        Position = options.position or Vector(140, 100),
        Size = options.size or 10,
        flags = options.flags or 0,
        active = options.active ~= false,
        vulnerable = options.vulnerable ~= false,
        dead = false,
        removed = false,
        data = {},
        damageEvents = {},
    }
    function npc:ToNPC() return self end
    function npc:GetData() return self.data end
    function npc:Exists() return not self.removed end
    function npc:IsDead() return self.dead end
    function npc:IsActiveEnemy() return self.active end
    function npc:IsVulnerableEnemy() return self.vulnerable end
    function npc:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function npc:TakeDamage(amount, flags, source, countdown)
        self.damageEvents[#self.damageEvents + 1] = {
            amount = amount,
            flags = flags,
            source = source,
            countdown = countdown,
        }
        return true
    end
    return npc
end

local function makeTear(player)
    local tear = { SpawnerEntity = player, removed = false }
    function tear:Remove() self.removed = true end
    return tear
end

function EntityRef(entity) return { Entity = entity } end
function GetPtrHash(entity) return entity.ptr or entity.InitSeed end

local function makeEnvironment(options)
    options = options or {}
    local callbacks = {}
    local players = { makePlayer(1, Vector(100, 100)), makePlayer(2, Vector(300, 100)) }
    local effects = {}
    local roomEntities = {}
    local frame = 0
    local mod = {}
    local collectibleConfigs = {
        [6001] = { MaxCharges = 3 },
        [6002] = { MaxCharges = 5 },
        [6003] = { MaxCharges = 5 },
    }
    for _, player in ipairs(players) do player.nativeConfigs = collectibleConfigs end

    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    local initialize = assert(dofile("annihilation.lua"))
    local settings = {
        ItemId = 9053,
        Variants = { Aura = 3022, Shockwave = 3023, Activate = 3024 },
        GetPlayers = function() return players end,
        GetRoomEntities = function() return roomEntities end,
        GetFrameCount = function() return frame end,
        GetCollectibleConfig = function(itemId) return collectibleConfigs[itemId] end,
        SpawnEffect = function(variant, position, spawner)
            local effect = makeEffect(variant, position, spawner)
            effects[#effects + 1] = effect
            return effect
        end,
    }
    for key, value in pairs(options) do settings[key] = value end
    if options.NativeSpawn then settings.SpawnEffect = nil end
    local api = initialize(mod, settings)

    local function getCallbacks(id)
        local result = {}
        for _, callback in ipairs(callbacks) do
            if callback.id == id then result[#result + 1] = callback end
        end
        return result
    end

    local function invoke(id, entity, ...)
        local result = nil
        for _, callback in ipairs(getCallbacks(id)) do
            if callback.param == nil
                or callback.param == entity
                or (type(entity) == "table" and callback.param == entity.Type)
            then
                local value = callback.fn(mod, entity, ...)
                if value ~= nil then result = value end
            end
        end
        return result
    end

    return {
        mod = mod,
        api = api,
        players = players,
        effects = effects,
        roomEntities = roomEntities,
        collectibleConfigs = collectibleConfigs,
        use = function(player)
            local result
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_USE_ITEM)) do
                if callback.param == 9053 then
                    result = callback.fn(mod, 9053, nil, player, 0, 0, 0)
                end
            end
            return result
        end,
        update = function(count)
            for _ = 1, count or 1 do
                frame = frame + 1
                for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback.fn(mod) end
            end
        end,
        getFrame = function() return frame end,
        fireTear = function(tear) return invoke(ModCallbacks.MC_POST_FIRE_TEAR, tear) end,
        npcInit = function(npc) return invoke(ModCallbacks.MC_POST_NPC_INIT, npc) end,
        npcUpdate = function(npc) return invoke(ModCallbacks.MC_NPC_UPDATE, npc) end,
        npcDeath = function(npc)
            npc.dead = true
            return invoke(ModCallbacks.MC_POST_NPC_DEATH, npc)
        end,
        entityKill = function(npc) return invoke(ModCallbacks.MC_POST_ENTITY_KILL, npc) end,
        newRoom = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback.fn(mod) end
        end,
        gameStarted = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do callback.fn(mod, false) end
        end,
        preExit = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_GAME_EXIT)) do callback.fn(mod, true) end
        end,
        evaluate = function(player, cacheFlag)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
                callback.fn(mod, player, cacheFlag)
            end
        end,
    }
end

    return {
        VectorMt = VectorMt,
        assertEquals = assertEquals,
        assertTruthy = assertTruthy,
        assertNear = assertNear,
        makeSprite = makeSprite,
        makeEffect = makeEffect,
        makePlayer = makePlayer,
        makeNpc = makeNpc,
        makeTear = makeTear,
        makeEnvironment = makeEnvironment,
    }
end
