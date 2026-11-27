-- Extracted engine double; original behavior assertions remain in the test.
return function()
local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > (epsilon or 0.0001) then
        error((message or "assertion failed") .. ": expected near " .. tostring(expected) .. ", got " .. tostring(actual), 2)
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

local function readPngInfo(path)
    local file = assert(io.open(path, "rb"), path .. " should exist")
    local header = file:read(26)
    local fileSize = file:seek("end")
    file:close()
    assertTruthy(header and #header >= 26, path .. " should have a PNG header")

    local function readU32(offset)
        local a, b, c, d = string.byte(header, offset, offset + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end

    return {
        width = readU32(17),
        height = readU32(21),
        colorType = string.byte(header, 26),
        fileSize = fileSize,
    }
end

local function loadNeverbirth(options)
    options = options or {}
    local callbacks = {}
    local players = {}
    local roomEntities = {}
    local spawns = {}
    local spriteEvents = {}
    local itemIds = {
        TheMoonIsBeautiful = 757,
        BurnAwayResentment = 759,
        Cleaver = 760,
    }
    local rngValues = options.rngValues or {}
    local rngIndex = 0
    local cardPoolSequence = options.cardPoolSequence or {}
    local cardPoolIndex = 0
    local cardConfigs = options.cardConfigs
    local eidDescriptions = options.eidDescriptions
    local roomClear = options.roomClear == true
    local roomType = options.roomType or 1
    local roomIndex = options.roomIndex or 1
    local triggeredShootActions = {}

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
        MC_POST_NPC_DEATH = 16,
        MC_POST_ENTITY_KILL = 17,
        MC_POST_FIRE_TEAR = 18,
        MC_PRE_PROJECTILE_COLLISION = 19,
        MC_INPUT_ACTION = 20,
        MC_POST_KNIFE_UPDATE = 21,
        MC_PRE_KNIFE_COLLISION = 22,
    }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_BOMB = 4, ENTITY_PICKUP = 5, ENTITY_LASER = 7, ENTITY_KNIFE = 8, ENTITY_PROJECTILE = 9, ENTITY_EFFECT = 1000 }
    KnifeVariant = { BONE_CLUB = 1, BAG_OF_CRAFTING = 4 }
    InputHook = { GET_ACTION_VALUE = 1, IS_ACTION_PRESSED = 2, IS_ACTION_TRIGGERED = 3 }
    ButtonAction = { ACTION_SHOOTLEFT = 10, ACTION_SHOOTUP = 11, ACTION_SHOOTRIGHT = 12, ACTION_SHOOTDOWN = 13 }
    Input = {
        IsActionTriggered = function(action, controller)
            return triggeredShootActions[controller or 0] == action
        end,
    }
    EntityCollisionClass = { ENTCOLL_NONE = 0, ENTCOLL_ALL = 4 }
    EntityGridCollisionClass = { GRIDCOLL_NONE = 0 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COIN = 20, PICKUP_KEY = 30, PICKUP_BOMB = 40, PICKUP_PILL = 70, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_FULL = 2 }
    CoinSubType = { COIN_PENNY = 1 }
    KeySubType = { KEY_NORMAL = 1 }
    BombSubType = { BOMB_NORMAL = 1 }
    Card = { CARD_RANDOM = 0, CARD_FOOL = 1 }
    for key, value in pairs(options.extraCards or {}) do
        Card[key] = value
    end
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SPEED = 8, CACHE_FIREDELAY = 64, CACHE_RANGE = 128, CACHE_SHOTSPEED = 2, CACHE_LUCK = 1024 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_BOSS = 5, ROOM_SACRIFICE = 13 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_ANGEL = 4, POOL_PLANETARIUM = 24 }
    ActiveSlot = { SLOT_PRIMARY = 0 }
    CollectibleType = { COLLECTIBLE_NULL = 0 }
    DamageFlag = { DAMAGE_FAKE = 8, DAMAGE_EXPLOSION = 16, DAMAGE_IV_BAG = 32, DAMAGE_DEVIL = 64, DAMAGE_CURSED_DOOR = 128, DAMAGE_SPIKES = 256, DAMAGE_NOKILL = 512 }
    EffectVariant = { POOF01 = 1 }

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
        return math.max(0, math.min(max - 1, math.floor(rngValues[rngIndex] or 0)))
    end

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
    Color = setmetatable({}, { __call = function(_, r, g, b, a, ro, go, bo) return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo } end })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)

    function Sprite()
        local sprite = { path = nil, animation = nil, updates = 0, renders = {}, Scale = Vector(1, 1) }
        function sprite:Load(path) self.path = path; spriteEvents[#spriteEvents + 1] = { type = "load", path = path } end
        function sprite:Play(animation) self.animation = animation; spriteEvents[#spriteEvents + 1] = { type = "play", animation = animation, path = self.path } end
        function sprite:Update() self.updates = self.updates + 1 end
        function sprite:GetFilename() return self.path or "gfx/mock_shadow.anm2" end
        function sprite:GetAnimation() return self.animation or "Idle" end
        function sprite:GetFrame() return self.updates end
        function sprite:SetFrame(animation, frame) self.animation = animation; self.frame = frame end
        function sprite:Render(position) self.renders[#self.renders + 1] = position; spriteEvents[#spriteEvents + 1] = { type = "render", path = self.path, animation = self.animation, position = position } end
        function sprite:IsFinished() return false end
        return sprite
    end

    local room = {}
    function room:GetSpawnSeed() return 5000 end
    function room:GetCenterPos() return Vector(320, 280) end
    function room:GetType() return roomType end
    function room:IsClear() return roomClear end
    function room:FindFreePickupSpawnPosition(pos) return pos end
    function room:IsPositionInRoom() return true end

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
            GetItemPool = function()
                return {
                    GetCollectible = function() return CollectibleType.COLLECTIBLE_NULL end,
                    GetCard = function()
                        cardPoolIndex = cardPoolIndex + 1
                        return cardPoolSequence[cardPoolIndex] or Card.CARD_FOOL
                    end,
                }
            end,
            GetStateFlag = function() return false end,
            SetStateFlag = function() end,
        }
    end

    function MusicManager()
        return { GetCurrentMusicID = function() return 1 end, Play = function() end, Fadeout = function() end }
    end

    Isaac = {
        GetItemIdByName = function(name)
            if name == "The Moon Is Beautiful" or name == "月色真美" then return itemIds.TheMoonIsBeautiful end
            if name == "Burn Away the Resentment" or name == "焚尽郁结" then return itemIds.BurnAwayResentment end
            if name == "Cleaver" or name == "柴刀" then return itemIds.Cleaver end
            return -1
        end,
        GetMusicIdByName = function() return -1 end,
        GetEntityVariantByName = function(name)
            if name == "Cleaver Attack" then return 3016 end
            return -1
        end,
        GetPlayerTypeByName = function(name, tainted)
            if name == "Stranger" and tainted == false then return options.strangerPlayerType or 777 end
            return -1
        end,
        GetPlayer = function(index) return players[(index or 0) + 1] end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then return players end
            return {}
        end,
        GetRoomEntities = function() return roomEntities end,
        DebugString = function() end,
        GetCostumeIdByPath = function() return -1 end,
        WorldToScreen = function(position) return Vector(position.X + 1000, position.Y + 2000) end,
        GetItemConfig = function()
            return {
                GetCollectible = function() return { Tags = 0, Type = 3, MaxCharges = 0, Name = "Mock" } end,
                GetCollectibles = function() return {} end,
                GetCard = function(_, subtype)
                    subtype = math.floor(tonumber(subtype) or 0)
                    if cardConfigs then
                        return cardConfigs[subtype]
                    end
                    if subtype >= 1 and subtype <= 31 then
                        return { ID = subtype, Name = "Defined Card", Description = "A real card" }
                    end
                    return nil
                end,
            }
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
                data = {},
            }
            entity.Size = 20
            entity.Rotation = 0
            entity.SpriteOffset = Vector(0, 0)
            entity.TargetPosition = Vector(0, 0)
            entity.sprite = Sprite()
            function entity:GetData() return self.data end
            function entity:GetSprite() return self.sprite end
            function entity:ToKnife() return self end
            function entity:Exists() return not self.removed end
            function entity:Remove() self.removed = true end
            spawns[#spawns + 1] = entity
            return entity
        end,
    }

    EID = nil
    if eidDescriptions then
        EID = {
            getDescriptionObjByID = function(_, _, _, subtype)
                return eidDescriptions[subtype]
            end,
            getDescriptionObj = function(_, _, _, subtype)
                return eidDescriptions[subtype]
            end,
        }
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

    function include()
        return function() end
    end

    dofile("tests/repentogon_test_fixture.lua")()
    dofile("main.lua")

    local function newPlayer(opts)
        opts = opts or {}
        local player = {
            Type = EntityType.ENTITY_PLAYER,
            InitSeed = opts.initSeed or (#players + 100),
            ControllerIndex = opts.controllerIndex or #players,
            Position = opts.position or Vector(120, 100),
            PositionOffset = opts.positionOffset or Vector(0, 0),
            Velocity = opts.velocity or Vector(0, 0),
            sprite = Sprite(),
            Damage = opts.damage or 10,
            Luck = opts.luck or 0,
            collectibles = opts.collectibles or { [itemIds.BurnAwayResentment] = 1, [itemIds.Cleaver] = 1 },
            MoveSpeed = opts.moveSpeed or 1,
            MaxFireDelay = opts.maxFireDelay or 10,
            hearts = opts.hearts or 8,
            soulHearts = opts.soulHearts or 0,
            boneHearts = opts.boneHearts or 0,
            Size = opts.size or 20,
            PlayerType = opts.playerType or 0,
            TearRange = opts.tearRange or 260,
            ShotSpeed = opts.shotSpeed or 1,
            damageCalls = {},
            sprite = Sprite(),
            firing = opts.firing == true,
            shootingInput = opts.shootingInput,
            firedKnives = {},
            cacheFlags = {},
            evaluated = 0,
        }
        function player:ToPlayer() return self end
        function player:GetPlayerType() return self.PlayerType end
        function player:GetSprite() return self.sprite end
        function player:TakeDamage(amount, flags, source, countdown) self.damageCalls[#self.damageCalls + 1] = { amount = amount, flags = flags, source = source, countdown = countdown } end
        function player:Exists() return not self.removed end
        function player:IsDead() return self.dead == true end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:GetHearts() return self.hearts end
        function player:GetSoulHearts() return self.soulHearts end
        function player:GetBoneHearts() return self.boneHearts end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:AddCollectible(itemId)
            self.collectibles[itemId] = (self.collectibles[itemId] or 0) + 1
        end
        function player:GetShootingInput() return self.shootingInput or (self.firing and Vector(1, 0) or Vector(0, 0)) end
        function player:SetShootingCooldown(frames) self.shootingCooldown = frames end
        function player:FireKnife(_, _, _, _, variant)
            local input = self:GetShootingInput()
            local direction = input:Length() > 0 and input:Normalized() or Vector(1, 0)
            local knife = {
                Type = EntityType.ENTITY_KNIFE, Variant = variant, Position = self.Position + direction * 70,
                Velocity = direction * 8, Size = self.Size, data = {}, CollisionDamage = 3, Visible = true,
            }
            function knife:GetData() return self.data end
            function knife:Exists() return not self.removed end
            function knife:GetKnifeVelocity() return 8 end
            function knife:Remove() self.removed = true end
            self.firedKnives[#self.firedKnives + 1] = knife
            return knife
        end
        function player:GetFlyingOffset() return opts.flyingOffset or Vector(0, 0) end
        function player:GetCollectibleRNG()
            return { RandomInt = function(_, max) return nextRngValue(max) end }
        end
        function player:AddCacheFlags(flag) self.cacheFlags[#self.cacheFlags + 1] = flag end
        function player:EvaluateItems() self.evaluated = self.evaluated + 1 end
        players[#players + 1] = player
        roomEntities[#roomEntities + 1] = player
        return player
    end

    local function newEnemy(opts)
        opts = opts or {}
        local enemy = {
            Type = opts.type or 10,
            Position = opts.position or Vector(160, 100),
            InitSeed = opts.initSeed or (#roomEntities + 300),
            data = {},
            damageTaken = 0,
            boss = opts.boss == true,
            Size = opts.size or 20,
            PlayerType = opts.playerType or 0,
            TearRange = opts.tearRange or 260,
            ShotSpeed = opts.shotSpeed or 1,
            damageCalls = {},
            sprite = Sprite(),
            PositionOffset = opts.positionOffset or Vector(0, 0),
            Velocity = opts.velocity or Vector(0, 0),
            sprite = Sprite(),
            dead = false,
        }
        function enemy:IsVulnerableEnemy() return opts.vulnerable ~= false end
        if opts.activeEnemy ~= nil then
            function enemy:IsActiveEnemy() return opts.activeEnemy end
        end
        function enemy:IsBoss() return self.boss end
        function enemy:Exists() return not self.removed end
        function enemy:IsDead() return self.dead == true end
        function enemy:ToNPC() return self end
        function enemy:GetSprite() return self.sprite end
        function enemy:AddVelocity(vector) self.Velocity = self.Velocity + vector end
        function enemy:GetData() return self.data end
        function enemy:TakeDamage(amount)
            self.damageTaken = self.damageTaken + (tonumber(amount) or 0)
            return true
        end
        function enemy:AddBurn(_, duration, damage)
            self.burnDuration = duration
            self.burnDamage = damage
        end
        function enemy:Remove() self.removed = true end
        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    local function newTear(player)
        return { Type = EntityType.ENTITY_TEAR, Position = Vector(140, 100), Velocity = Vector(1, 0), SpawnerEntity = player, Remove = function(self) self.removed = true end }
    end

    local function newTearRef(player)
        return { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player }
    end

    local function runPostUpdate(times)
        for _ = 1, times or 1 do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback(mod) end
        end
    end

    local function runPostFireTear(tear)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_FIRE_TEAR)) do callback(mod, tear) end
    end
    local function runInput(player, hook, action)
        local result = nil
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_INPUT_ACTION)) do
            local value = callback(mod, player, hook, action)
            if value ~= nil then result = value end
        end
        return result
    end

    local function triggerShoot(player, action)
        triggeredShootActions[player.ControllerIndex or 0] = action
        runPostUpdate()
        triggeredShootActions[player.ControllerIndex or 0] = nil
    end

    local function runKnifeUpdate(knife)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_KNIFE_UPDATE)) do callback(mod, knife) end
    end

    local function runKnifeCollision(knife, collider)
        local result = nil
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_KNIFE_COLLISION)) do
            local value = callback(mod, knife, collider, false)
            if value ~= nil then result = value end
        end
        if result == nil and knife and knife.CollisionDamage and collider and collider.TakeDamage then
            collider:TakeDamage(knife.CollisionDamage, 0, EntityRef(knife), 0)
        end
        return result
    end

    local function runRender()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_RENDER)) do callback(mod) end
    end

    local function runEvaluate(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do callback(mod, player, cacheFlag) end
    end

    local function runDamage(entity, amount, sourceEntity)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG)) do
            callback(mod, entity, amount or 1, 0, EntityRef(sourceEntity), 0)
        end
    end

    local function runDamageRef(entity, amount, sourceRef, flags)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG)) do
            callback(mod, entity, amount or 1, flags or 0, sourceRef, 0)
        end
    end

    local function runDeath(entity)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NPC_DEATH)) do callback(mod, entity) end
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ENTITY_KILL)) do callback(mod, entity) end
    end

    local function runNewRoom()
        roomIndex = roomIndex + 1
        roomEntities = {}
        for _, player in ipairs(players) do
            roomEntities[#roomEntities + 1] = player
        end
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback(mod) end
    end

    local function runNewLevel()
        roomIndex = roomIndex + 100
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_LEVEL)) do callback(mod) end
    end

    local function runGameStarted(isContinued)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do callback(mod, isContinued == true) end
    end

    return {
        items = itemIds,
        spawns = spawns,
        spriteEvents = spriteEvents,
        roomEntities = roomEntities,
        newPlayer = newPlayer,
        newEnemy = newEnemy,
        newTear = newTear,
        newTearRef = newTearRef,
        runPostUpdate = runPostUpdate,
        runPostFireTear = runPostFireTear,
        runInput = runInput,
        triggerShoot = triggerShoot,
        runKnifeUpdate = runKnifeUpdate,
        runKnifeCollision = runKnifeCollision,
        getLatestKnife = function()
            for index = #spawns, 1, -1 do
                if spawns[index].Type == EntityType.ENTITY_KNIFE then return spawns[index] end
            end
            return nil
        end,        getKnifeCount = function()
            local count = 0
            for _, spawn in ipairs(spawns) do
                if spawn.Type == EntityType.ENTITY_KNIFE then count = count + 1 end
            end
            return count
        end,
        runPickupCollision = function(pickup, collider)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_PICKUP_COLLISION)) do
                local result = callback(mod, pickup, collider, false)
                if result ~= nil then return result end
            end
        end,
        runProjectileCollision = function(projectile, collider)
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_PROJECTILE_COLLISION)) do
                local result = callback(mod, projectile, collider, false)
                if result ~= nil then return result end
            end
        end,
        runRender = runRender,
        runEvaluate = runEvaluate,
        runDamage = runDamage,
        runDamageRef = runDamageRef,
        runDeath = runDeath,
        runNewRoom = runNewRoom,
        runNewLevel = runNewLevel,
        runGameStarted = runGameStarted,
        clearMoonVisuals = function() Neverbirth.Moon.ClearVisuals() end,
        setRoomIndex = function(value) roomIndex = value end,
        setRoomClear = function(value) roomClear = value end,
        setRoomType = function(value) roomType = value end,
    }
end

local function burnState(player)
    return Neverbirth.BurnAwayResentment.GetState(player)
end

local function configureCleaver()
    local config = Neverbirth.Cleaver.Config
    config.Registered = true
    config.PlayerType = 42
    config.PlayerShadowDamageSource = "shadowOwner"
    config.GetSwingDirection = nil
end

local function shadowFor(target, kind)
    return Neverbirth.Cleaver.shadows[Neverbirth.Cleaver.GetEntityKey(target, kind)]
end

    return {
        assertEquals = assertEquals,
        assertNear = assertNear,
        assertTruthy = assertTruthy,
        readFile = readFile,
        readPngInfo = readPngInfo,
        loadNeverbirth = loadNeverbirth,
        burnState = burnState,
        configureCleaver = configureCleaver,
        shadowFor = shadowFor,
    }
end
