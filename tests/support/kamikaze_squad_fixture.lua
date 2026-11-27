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
function VectorMt.__add(left, right)
    return setmetatable({ X = left.X + right.X, Y = left.Y + right.Y }, VectorMt)
end
function VectorMt.__sub(left, right)
    return setmetatable({ X = left.X - right.X, Y = left.Y - right.Y }, VectorMt)
end
function VectorMt.__mul(left, right)
    if type(left) == "number" then left, right = right, left end
    return setmetatable({ X = left.X * right, Y = left.Y * right }, VectorMt)
end
function VectorMt:LengthSquared() return self.X * self.X + self.Y * self.Y end
function VectorMt:Length() return math.sqrt(self:LengthSquared()) end
function VectorMt:Normalized()
    local length = self:Length()
    if length <= 0 then return Vector(0, 0) end
    return Vector(self.X / length, self.Y / length)
end

Vector = setmetatable({}, {
    __call = function(_, x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, VectorMt)
    end,
})
Vector.Zero = Vector(0, 0)

ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_NPC_UPDATE = 2,
    MC_POST_NPC_INIT = 3,
    MC_POST_NPC_DEATH = 4,
    MC_POST_ENTITY_REMOVE = 5,
    MC_PRE_SPAWN_CLEAN_AWARD = 6,
    MC_POST_NEW_ROOM = 7,
    MC_POST_NEW_LEVEL = 8,
    MC_POST_GAME_STARTED = 9,
    MC_PRE_GAME_EXIT = 10,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_NPC = 10, ENTITY_MULLIGAN = 16 }
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2 }
TearFlags = { TEAR_NORMAL = 0 }
DamageFlag = { DAMAGE_EXPLOSION = 1 }
local ColorMt = {}
Color = setmetatable({}, { __call = function() return setmetatable({}, ColorMt) end })
Color.Default = Color()

function EntityRef(entity) return { Entity = entity } end
local nextIdentity = 0
function GetPtrHash(entity)
    if not entity.identity then nextIdentity = nextIdentity + 1; entity.identity = nextIdentity end
    return entity.identity
end
local function fresh(entity)
    GetPtrHash(entity)
    return setmetatable({}, { __index = entity, __newindex = entity })
end
local currentGame = nil
function Game() return currentGame end

local function makePlayer(seed, position)
    local player = {
        Type = EntityType.ENTITY_PLAYER,
        InitSeed = seed,
        Position = position,
        Size = 10,
        collectibles = { [9054] = 1 },
        dead = false,
        removed = false,
    }
    function player:ToPlayer() return self end
    function player:Exists() return not self.removed end
    function player:IsDead() return self.dead end
    function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
    function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
    return player
end

local function makeNpc(options)
    options = options or {}
    local npc = {
        Type = options.type or EntityType.ENTITY_NPC,
        Variant = options.variant or 0,
        SubType = options.subtype or 0,
        InitSeed = options.seed or 1000,
        Position = options.position or Vector(200, 100),
        Velocity = Vector.Zero,
        Size = options.size or 10,
        active = options.active ~= false,
        vulnerable = options.vulnerable ~= false,
        dead = false,
        removed = false,
        flags = options.flags or 0,
        data = {},
        pathCalls = {},
    }
    npc.Pathfinder = {
        FindGridPath = function(_, targetPosition, speed, pathMarker, direct)
            npc.pathCalls[#npc.pathCalls + 1] = {
                targetPosition = targetPosition,
                speed = speed,
                pathMarker = pathMarker,
                direct = direct,
            }
        end,
    }
    function npc:ToNPC() return self end
    function npc:GetData() return self.data end
    function npc:Exists() return not self.removed end
    function npc:IsDead() return self.dead end
    function npc:IsActiveEnemy() return self.active end
    function npc:IsVulnerableEnemy() return self.vulnerable end
    function npc:HasEntityFlags(flag) return (self.flags & flag) ~= 0 end
    function npc:AddEntityFlags(flag) self.flags = self.flags | flag end
    function npc:AddCharmed(source, duration)
        self.charmSource = source
        self.charmDuration = duration
        self.flags = self.flags | EntityFlag.FLAG_CHARM
    end
    function npc:Remove() self.removed = true end
    return npc
end

local function makeEnvironment(options)
    options = options or {}
    local callbacks = {}
    local players = {
        makePlayer(1, Vector(100, 100)),
        makePlayer(2, Vector(300, 100)),
    }
    local roomEntities = {}
    local spawned = {}
    local explosions = {}
    local nativeExplosions = {}
    local explosionAttempts = 0
    local frame = 0
    local logs = {}
    local mod = {}

    currentGame = {
        BombExplosionEffects = function(_, position, damage, tearFlags, color, source,
                radiusMultiplier, lineCheck, damageSource, damageFlags)
            explosionAttempts = explosionAttempts + 1
            assertEquals(getmetatable(position), VectorMt, "dispatch requires constructor Vector")
            assertEquals(getmetatable(color), ColorMt, "dispatch requires constructor Color")
            assertTruthy(source and source.ToPlayer and source:ToPlayer(), "dispatch requires player source")
            if options.throwExplosion then error("injected explosion failure") end
            nativeExplosions[#nativeExplosions + 1] = {
                position = position,
                damage = damage,
                tearFlags = tearFlags,
                color = color,
                source = source,
                radiusMultiplier = radiusMultiplier,
                lineCheck = lineCheck,
                damageSource = damageSource,
                damageFlags = damageFlags,
            }
        end,
    }

    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    local initialize = assert(dofile("kamikaze_squad.lua"))
    local moduleContext = {
        ItemId = 9054,
        DiagnosticsEnabled = options.diagnostics,
        DebugLog = function(message) logs[#logs + 1] = message end,
        GetPlayers = function()
            if not options.freshWrappers then return players end
            local result = {}
            for i, player in ipairs(players) do result[i] = fresh(player) end
            return result
        end,
        GetRoomEntities = function() return roomEntities end,
        GetFrameCount = function() return frame end,
        GetFreeNearPosition = function(position) return position + Vector(16, 0) end,
        SpawnMulliboom = function(position, owner)
            local unit = makeNpc({
                type = EntityType.ENTITY_MULLIGAN,
                variant = 2,
                seed = 5000 + #spawned,
                position = position,
            })
            unit.SpawnerEntity = owner
            spawned[#spawned + 1] = unit
            return unit
        end,
    }
    if options.missingExplosion then currentGame.BombExplosionEffects = nil end
    if options.nativeSpawn then
        local spawn = moduleContext.SpawnMulliboom
        Isaac = { Spawn = function(kind, variant, subtype, position, velocity, owner)
            assertEquals(kind, 16, "native spawn type")
            assertEquals(variant, 2, "native spawn variant")
            assertEquals(subtype, 0, "native spawn subtype")
            assertEquals(getmetatable(position), VectorMt, "native spawn position")
            assertEquals(velocity, Vector.Zero, "native spawn velocity")
            local npc = spawn(position, owner)
            return { ToNPC = function() return fresh(npc) end }
        end }
        moduleContext.SpawnMulliboom = nil
    end
    if not options.useNativeExplosion then
        moduleContext.TriggerExplosion = function(position, damage, radiusMultiplier, owner)
            explosions[#explosions + 1] = {
                position = position,
                damage = damage,
                radiusMultiplier = radiusMultiplier,
                owner = owner,
            }
        end
    end
    local api = initialize(mod, moduleContext)

    local function invoke(id, entity, ...)
        local result
        for _, callback in ipairs(callbacks) do
            if callback.id == id
                and (callback.param == nil
                    or callback.param == entity
                    or (type(entity) == "table" and callback.param == entity.Type))
            then
                local value = callback.fn(mod, entity, ...)
                if value ~= nil then result = value end
            end
        end
        return result
    end

    local function update(count)
        for _ = 1, count or 1 do
            frame = frame + 1
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_UPDATE then callback.fn(mod) end
            end
            for _, unit in ipairs(spawned) do
                if not unit.removed then invoke(ModCallbacks.MC_NPC_UPDATE, unit) end
            end
        end
    end

    return {
        api = api,
        mod = mod, callbacks = callbacks, context = moduleContext, invoke = invoke,
        players = players,
        roomEntities = roomEntities,
        spawned = spawned,
        explosions = explosions,
        nativeExplosions = nativeExplosions,
        getExplosionAttempts = function() return explosionAttempts end,
        logs = logs,
        update = update,
        npcInit = function(npc) return invoke(ModCallbacks.MC_POST_NPC_INIT, npc) end,
        npcDeath = function(npc)
            npc.dead = true
            return invoke(ModCallbacks.MC_POST_NPC_DEATH, npc)
        end,
        npcRemove = function(npc)
            npc.removed = true
            return invoke(ModCallbacks.MC_POST_ENTITY_REMOVE, npc)
        end,
        npcUpdate = function(npc) return invoke(ModCallbacks.MC_NPC_UPDATE, npc) end,
        cleanAward = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then callback.fn(mod) end
            end
        end,
        newRoom = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_NEW_ROOM then callback.fn(mod) end
            end
        end,
        newLevel = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_NEW_LEVEL then callback.fn(mod) end
            end
        end,
        gameStarted = function(isContinued)
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_GAME_STARTED then callback.fn(mod, isContinued) end
            end
        end,
    }
end

local function addEnemy(env, seed, position)
    local enemy = makeNpc({ seed = seed, position = position })
    env.roomEntities[#env.roomEntities + 1] = enemy
    env.npcInit(enemy)
    return enemy
end

return {
    ColorMt = ColorMt,
    assertEquals = assertEquals,
    assertTruthy = assertTruthy,
    makeEnvironment = makeEnvironment,
    makePlayer = makePlayer,
    makeNpc = makeNpc,
    addEnemy = addEnemy,
    fresh = fresh,
}
