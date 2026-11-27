include = function(name) return dofile((name:gsub("%.", "/")) .. ".lua") end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected a truthy value", 2) end
end

local VectorMt = {}
VectorMt.__index = VectorMt
function VectorMt:LengthSquared() return self.X * self.X + self.Y * self.Y end
function VectorMt.__sub(left, right)
    return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y }, VectorMt)
end
function VectorMt.__eq(left, right) return left.X == right.X and left.Y == right.Y end
Vector = setmetatable({}, {
    __call = function(_, x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, VectorMt)
    end,
})
Vector.Zero = Vector(0, 0)

ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_NPC_UPDATE = 2,
    MC_POST_EFFECT_UPDATE = 3,
    MC_INPUT_ACTION = 4,
    MC_POST_NEW_ROOM = 5,
    MC_POST_GAME_STARTED = 6,
    MC_PRE_GAME_EXIT = 7,
    MC_EVALUATE_CACHE = 8,
    MC_POST_PLAYER_RENDER = 9,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_EFFECT = 1000, ENTITY_HOST = 27 }
EffectVariant = { EFFECT_NULL = 0, HALO = 123 }
CollectibleType = { COLLECTIBLE_TRANSCENDENCE = 20 }
CacheFlag = { CACHE_FLYING = 1 }
EntityPartition = { ENEMY = 1 }
EntityCollisionClass = { ENTCOLL_NONE = 0 }
GridCollisionClass = { COLLISION_NONE = 0 }
InputHook = { IS_ACTION_PRESSED = 0, IS_ACTION_TRIGGERED = 1, GET_ACTION_VALUE = 2 }
ButtonAction = {
    ACTION_SHOOTLEFT = 4,
    ACTION_SHOOTRIGHT = 5,
    ACTION_SHOOTUP = 6,
    ACTION_SHOOTDOWN = 7,
    ACTION_LEFT = 8,
}
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2, FLAG_FEAR = 4, FLAG_RENDER_FLOOR = 8 }

local function makeSprite()
    local sprite = {
        loadCount = 0,
        playCount = 0,
        updateCount = 0,
        renderCount = 0,
        Rotation = 99,
        Scale = Vector(4, 4),
    }
    function sprite:Load(path)
        self.loadCount = self.loadCount + 1
        self.path = path
    end
    function sprite:Play(animation)
        self.playCount = self.playCount + 1
        self.animation = animation
    end
    function sprite:Update() self.updateCount = self.updateCount + 1 end
    function sprite:Render(position)
        self.renderCount = self.renderCount + 1
        self.renderPosition = position
    end
    return sprite
end

local function makeNpc(options)
    options = options or {}
    local npc = {
        Type = options.type or 10,
        Variant = options.variant or 0,
        SubType = options.subtype or 0,
        InitSeed = options.seed or 101,
        Position = options.position or Vector(100, 100),
        dead = false,
        boss = options.boss == true,
        vulnerable = options.vulnerable ~= false,
        active = options.active ~= false,
        flags = options.flags or 0,
        data = {},
        morphCalls = 0,
        champion = options.champion or -1,
    }
    function npc:ToNPC() return self end
    function npc:GetData() return self.data end
    function npc:Exists() return not self.removed end
    function npc:IsDead() return self.dead end
    function npc:IsBoss() return self.boss end
    function npc:IsVulnerableEnemy() return self.vulnerable end
    function npc:IsActiveEnemy() return self.active end
    function npc:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function npc:GetChampionColorIdx() return self.champion end
    function npc:Morph(entityType, variant, subtype, champion)
        self.morphCalls = self.morphCalls + 1
        self.Type, self.Variant, self.SubType, self.morphChampion = entityType, variant, subtype, champion
    end
    return npc
end

local function makePlayer(seed, count, position)
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = seed,
        collectibleCount = count or 0,
        Position = position or Vector(100, 100),
        data = {},
        fearCalls = 0,
        flags = 0,
        CanFly = false,
        collectibleCounts = {},
        addCollectibleCalls = {},
    }
    function player:ToPlayer() return self end
    function player:GetCollectibleNum(itemId)
        if itemId == 9001 then return self.collectibleCount end
        return self.collectibleCounts[itemId] or 0
    end
    function player:AddCollectible(itemId, charge, firstTimePickingUp)
        self.collectibleCounts[itemId] = (self.collectibleCounts[itemId] or 0) + 1
        self.addCollectibleCalls[#self.addCollectibleCalls + 1] = {
            itemId = itemId,
            charge = charge,
            firstTimePickingUp = firstTimePickingUp,
        }
    end
    function player:GetData() return self.data end
    function player:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function player:AddFear(source, duration)
        self.fearCalls = self.fearCalls + 1
        self.fearSource = source
        self.fearDuration = duration
        self.flags = self.flags | EntityFlag.FLAG_FEAR
    end
    return player
end

local function makeEnvironment(options)
    options = options or {}
    local callbacks = {}
    local players = { makePlayer(1, 1, Vector(100, 100)), makePlayer(2, 0, Vector(300, 300)) }
    local effects = {}
    local nearby = {}
    local luaSprites = {}
    local saveRoot = {}
    local saveCalls = 0

    local mod = {}
    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    Isaac = {
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            local effect = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                Velocity = velocity,
                SpawnerEntity = spawner,
                sprite = makeSprite(),
                data = {},
                removed = false,
            }
            function effect:GetSprite() return self.sprite end
            function effect:GetData() return self.data end
            function effect:Exists() return not self.removed end
            function effect:Remove() self.removed = true end
            function effect:AddEntityFlags(flag) self.addedFlags = (self.addedFlags or 0) | flag end
            effect.DepthOffset = 0
            setmetatable(effect, {
                __newindex = function(target, key, value)
                    if key == "Timeout" then
                        error("no member named 'Timeout'", 2)
                    end
                    rawset(target, key, value)
                end,
            })
            effects[#effects + 1] = effect
            return effect
        end,
        FindInRadius = function() return nearby end,
        WorldToScreen = function(position) return Vector(position.X, position.Y) end,
    }
    Sprite = setmetatable({}, {
        __call = function()
            local sprite = makeSprite()
            luaSprites[#luaSprites + 1] = sprite
            return sprite
        end,
    })
    function EntityRef(entity) return { Entity = entity } end

    local initialize = assert(dofile("night_of_the_cowards.lua"))
    local api = initialize(mod, {
        ItemId = 9001,
        AuraVariant = EffectVariant.HALO,
        AuraSubtype = 3,
        FlightItemId = CollectibleType.COLLECTIBLE_TRANSCENDENCE,
        GetPlayers = function() return players end,
        GetSaveRoot = function() return saveRoot end,
        GetCurrentRunSeed = options.GetCurrentRunSeed or function() return 12345 end,
        Save = function() saveCalls = saveCalls + 1 end,
    })

    local function getCallbacks(id)
        local found = {}
        for _, callback in ipairs(callbacks) do
            if callback.id == id then found[#found + 1] = callback end
        end
        return found
    end

    local function invoke(id, entity)
        for _, callback in ipairs(getCallbacks(id)) do
            if callback.param == nil or callback.param == entity.Variant then
                callback.fn(mod, entity)
            end
        end
    end

    return {
        api = api,
        mod = mod, callbacks = callbacks,
        setSaveRoot = function(root) saveRoot = root end,
        players = players,
        effects = effects,
        luaSprites = luaSprites,
        getSaveCalls = function() return saveCalls end,
        setNearby = function(value) nearby = value end,
        update = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback.fn(mod) end
        end,
        updateNpc = function(npc) invoke(ModCallbacks.MC_NPC_UPDATE, npc) end,
        updateEffect = function(effect) invoke(ModCallbacks.MC_POST_EFFECT_UPDATE, effect) end,
        newRoom = function()
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback.fn(mod) end
        end,
        input = function(player, hook, action)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_INPUT_ACTION)) do
                if callback.param == nil or callback.param == hook then
                    local result = callback.fn(mod, player, hook, action)
                    if result ~= nil then return result end
                end
            end
            return nil
        end,
        renderPlayer = function(player, renderOffset)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_PLAYER_RENDER)) do
                callback.fn(mod, player, renderOffset or Vector.Zero)
            end
        end,
        evaluateCache = function(player, cacheFlag)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
                if callback.param == nil or callback.param == cacheFlag then
                    callback.fn(mod, player, cacheFlag)
                end
            end
        end,
    }
end

return {
    assertEquals = assertEquals,
    assertTruthy = assertTruthy,
    makeEnvironment = makeEnvironment,
    makePlayer = makePlayer,
    makeNpc = makeNpc,
}
