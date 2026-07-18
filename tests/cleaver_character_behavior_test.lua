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
    config.PlayerType = 42
    config.PlayerShadowDamageSource = "shadowOwner"
    config.GetSwingDirection = nil
end

local function shadowFor(target, kind)
    return Neverbirth.Cleaver.shadows[Neverbirth.Cleaver.GetEntityKey(target, kind)]
end

local function test_stranger_registration_and_cleaver_assets()
    local players = readFile("content/players.xml")
    assertTruthy(players:match('<player name="Stranger"'), "Stranger should be registered in players.xml")
    assertTruthy(players:match('skin="Character_001_Isaac%.png"'), "Stranger should reference the vanilla Isaac skin")
    assertTruthy(players:match('hp="6"'), "Stranger should start with 3 red hearts")
    local strangerRegistration = players:match('<player name="Stranger"[^>]*/>')
    assertTruthy(strangerRegistration and not strangerRegistration:match('%f[%a]hidden%s*='),
        "Stranger should remain visible instead of being hidden from the character list")
    assertTruthy(strangerRegistration and not strangerRegistration:match('%f[%a]achievement%s*='),
        "Stranger should not use an achievement lock as a fake unavailable state")

    local characterMenu = readFile("content/gfx/CharacterMenu.anm2")
    assertTruthy(characterMenu:match('<Spritesheet Id="1" Path="stranger_not_yet_name%.png"'),
        "Stranger character menu should load the dedicated NOT YET name sheet")
    assertTruthy(characterMenu:match('<Spritesheet Id="2" Path="stranger_not_yet_item%.png"'),
        "Stranger character menu should load the dedicated NOT YET item-name sheet")
    assertTruthy(characterMenu:match('<Layer Id="3" Name="Name" SpritesheetId="1"'),
        "Stranger Name layer should use the dedicated 80x32 NOT YET sheet")
    assertTruthy(characterMenu:match('<Layer Id="8" Name="Item Name" SpritesheetId="2"'),
        "Stranger Item Name layer should use the dedicated 112x32 NOT YET sheet")
    local itemIconLayer = characterMenu:match('<LayerAnimation LayerId="7".-</LayerAnimation>')
    assertTruthy(itemIconLayer and itemIconLayer:match('Visible="false"'),
        "Stranger Item Icon layer should be hidden instead of showing D6 or another icon")
    local nameLayer = characterMenu:match('<LayerAnimation LayerId="3".-</LayerAnimation>')
    assertTruthy(nameLayer and nameLayer:match('XCrop="0" YCrop="0" Width="80" Height="32"'),
        "Stranger Name frame should crop the complete 80x32 NOT YET sheet")
    local itemNameLayer = characterMenu:match('<LayerAnimation LayerId="8".-</LayerAnimation>')
    assertTruthy(itemNameLayer and itemNameLayer:match('XCrop="0" YCrop="0" Width="112" Height="32"'),
        "Stranger Item Name frame should crop the complete 112x32 NOT YET sheet")
    assertEquals(characterMenu:find("stranger_not_yet_preview.png", 1, true), nil,
        "the 480x270 preview is reference-only and must not be loaded by CharacterMenu.anm2")

    local notYetName = readPngInfo("content/gfx/stranger_not_yet_name.png")
    assertEquals(notYetName.width, 80, "Stranger NOT YET name sheet width")
    assertEquals(notYetName.height, 32, "Stranger NOT YET name sheet height")
    assertEquals(notYetName.colorType, 6, "Stranger NOT YET name sheet must preserve RGBA transparency")
    local notYetItem = readPngInfo("content/gfx/stranger_not_yet_item.png")
    assertEquals(notYetItem.width, 112, "Stranger NOT YET item-name sheet width")
    assertEquals(notYetItem.height, 32, "Stranger NOT YET item-name sheet height")
    assertEquals(notYetItem.colorType, 6, "Stranger NOT YET item-name sheet must preserve RGBA transparency")

    loadNeverbirth({ strangerPlayerType = 777 })
    assertEquals(Neverbirth.Cleaver.Config.PlayerType, 777, "Stranger PlayerType should resolve through Isaac.GetPlayerTypeByName")
    assertEquals(Neverbirth.Cleaver.Config.CleaverVisualTimeout, 22, "11 authored frames at 30 FPS must last 22 game ticks")
    assertEquals(Neverbirth.Cleaver.Config.SwingDurationTicks, 22, "sweep duration must match the complete 11-frame animation")
    assertEquals(Neverbirth.Cleaver.Config.HoldVisualPath, "gfx/Effects/CleaverAttack/stranger_machete.anm2", "idle must use the Stranger machete actor")
    assertEquals(Neverbirth.Cleaver.Config.CleaverVisualPath, "gfx/Effects/CleaverAttack/stranger_machete.anm2", "swing must use the Stranger machete actor")
    local macheteAnm2 = readFile("resources/gfx/Effects/CleaverAttack/stranger_machete.anm2")
    local function containsAnimation(xml, name)
        return xml:match('<Animation[^>]-Name="' .. name .. '"') ~= nil
    end
    assertTruthy(macheteAnm2:match('Spritesheet Id="0" Path="stranger_machete_swing_11f%.png"'), "machete actor must use the shared 11-frame spritesheet")
    for _, direction in ipairs({ "Up", "Down", "Left", "Right" }) do
        for _, variant in ipairs({ "A", "B" }) do
            assertTruthy(containsAnimation(macheteAnm2, "Idle" .. direction .. "_" .. variant), "machete actor should provide A/B idle animations")
            assertTruthy(containsAnimation(macheteAnm2, "Swing" .. direction .. "_" .. variant), "machete actor should provide A/B swing animations")
        end
    end
    assertTruthy(macheteAnm2:match('Event Name="Hit"') and macheteAnm2:match('Trigger EventId="0" AtFrame="3"'), "machete actor should retain its authored Hit event")
    for _, animation in ipairs({ "SwingUp_A", "SwingUp_B", "SwingDown_A", "SwingDown_B", "SwingLeft_A", "SwingLeft_B", "SwingRight_A", "SwingRight_B" }) do
        local block = macheteAnm2:match('<Animation[^>]-Name="' .. animation .. '"[^>]*>(.-)</Animation>')
        assertTruthy(block, animation .. " should exist")
        local frames = 0
        for _ in block:gmatch('XPivot="(%d+)" YPivot="(%d+)"') do frames = frames + 1 end
        assertEquals(frames, 11, animation .. " should retain all eleven hand-anchored frames")
    end
    local sheet = readPngInfo("resources/gfx/Effects/CleaverAttack/stranger_machete_swing_11f.png")
    assertEquals(sheet.width, 1056, "machete 11-frame spritesheet width")
    assertEquals(sheet.height, 896, "machete 11-frame spritesheet height")
    assertEquals(sheet.colorType, 6, "machete spritesheet must preserve RGBA transparency")
end
local function test_stranger_starts_with_cleaver_but_does_not_depend_on_the_item()
    local env = loadNeverbirth()
    configureCleaver()
    local stranger = env.newPlayer({ playerType = 42, collectibles = {} })
    assertTruthy(Neverbirth.Cleaver.IsEnabled(stranger), "Stranger must enable the system even before the visible starting item is granted")
    env.runGameStarted(false)
    assertEquals(stranger:GetCollectibleNum(env.items.Cleaver), 1, "a new Stranger run must grant one Cleaver")
    assertTruthy(Neverbirth.Cleaver.IsEnabled(stranger), "the starting item must not be the gameplay gate")
    stranger.collectibles[env.items.Cleaver] = 0
    assertTruthy(Neverbirth.Cleaver.IsEnabled(stranger), "losing the visible Cleaver item must not disable Stranger's character mechanic")
    env.runGameStarted(true)
    assertEquals(stranger:GetCollectibleNum(env.items.Cleaver), 0, "continued runs must not duplicate the visible starting item")
end
local function test_cleaver_has_a_persistent_handheld_visual_outside_swings()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(40, 50) })
    env.runPostUpdate()
    local state = Neverbirth.Cleaver.GetState(player)
    assertTruthy(state.holdVisual and state.holdVisual.sprite, "an enabled Stranger must create one persistent held-cleaver Sprite")
    assertEquals(state.holdVisual.animation, "IdleDown_A", "a stationary Stranger should use the A downward idle pose before the first swing")
    assertEquals(state.holdVisual.sprite.Scale.X, 0.5, "the held-cleaver Sprite must use the shared half-scale actor")
    assertEquals(state.holdVisual.sprite.Scale.Y, 0.5, "the held-cleaver Sprite must use the shared half-scale actor")
    env.runRender()
    local rendered = false
    for _, event in ipairs(env.spriteEvents) do rendered = rendered or (event.type == "render" and event.animation == "IdleDown_A") end
    assertTruthy(rendered, "the held-cleaver Sprite should render while not swinging")
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "first swing should start")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    env.runPostUpdate()
    assertEquals(state.holdVisual.animation, "IdleRight_A", "after a completed A swing, the held cleaver should preserve its direction and A pose")
end
local function test_non_cleaver_players_are_fully_isolated()
    local env = loadNeverbirth()
    local normal = env.newPlayer({ playerType = 0 })
    local enemy = env.newEnemy()
    env.runPostUpdate()
    assertEquals(next(Neverbirth.Cleaver.shadows), nil, "normal players must not create shadows")
    assertEquals(Neverbirth.Cleaver.TrySwing(normal, Vector(1, 0)), false, "normal players must not swing")
    local tear = { SpawnerEntity = normal }
    env.runPostFireTear(tear)
    assertEquals(tear.removed, nil, "normal player tears must remain untouched")
end

local function test_player_shooting_input_starts_a_swing_without_raw_trigger_state()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), shootingInput = Vector(1, 0) })
    env.runPostUpdate()
    assertTruthy(Neverbirth.Cleaver.GetState(player).swing, "player:GetShootingInput must start a swing even when Input.IsActionTriggered is unavailable")
end
local function test_raw_shoot_trigger_starts_a_swing_and_spawns_the_native_hitbox_at_the_authored_frame()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertEquals(env.runInput(player, InputHook.IS_ACTION_TRIGGERED, ButtonAction.ACTION_SHOOTRIGHT), nil, "Cleaver must not depend on MC_INPUT_ACTION interception")
    env.triggerShoot(player, ButtonAction.ACTION_SHOOTRIGHT)
    local state = Neverbirth.Cleaver.GetState(player)
    assertTruthy(state.swing, "raw shooting input should start the Lua swing state")
    assertEquals(env.getLatestKnife(), nil, "the invisible carrier must not exist before its configured fallback tick")
    local beforeCarrier = Neverbirth.Cleaver.Config.SwingCarrierFallbackTick - (state.swing.tick or 0) - 1
    if beforeCarrier > 0 then env.runPostUpdate(beforeCarrier) end
    assertEquals(env.getLatestKnife(), nil, "early authored frames must remain visual-only")
    env.runPostUpdate()
    local knife = env.getLatestKnife()
    assertTruthy(knife, "the configured carrier tick must create one native EntityKnife")
    assertEquals(knife.Variant, 10, "Cleaver must use the native Spirit Sword knife carrier")
    assertEquals(knife.SubType, Neverbirth.Cleaver.Config.KnifeSubType, "Cleaver must identify its native knife with a private subtype")
    assertEquals(knife.CollisionDamage, 0, "the hidden native carrier must not contribute a circular collision damage source")
    assertEquals(knife.Parent, player, "native knife must retain its owner for the swing lifetime")
    assertNear(knife.Size, 1, 0.0001, "the hidden native carrier must not expose a large circular collision radius")
    assertEquals(knife.EntityCollisionClass, EntityCollisionClass.ENTCOLL_NONE, "the hidden carrier must leave collision to the Lua sweep")
    env.runKnifeUpdate(knife)
    assertEquals(knife.Variant, 0, "after spawning as Spirit Sword, the native carrier must reset to the default knife variant")
    assertEquals(player.shootingCooldown, Neverbirth.Cleaver.Config.SwingCooldownFrames, "raw swing should set the configured shooting cooldown")
    local tear = env.newTear(player)
    env.runPostFireTear(tear)
    assertTruthy(tear.removed, "post-fire fallback must remove any vanilla tear that bypasses the swing input")
end
local function test_post_fire_tear_resolves_player_owner_before_replacing_shot()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    local ownerProxy = {
        ToPlayer = function()
            return player
        end,
    }
    local tear = {
        SpawnerEntity = ownerProxy,
        Position = Vector(8, 0),
        Velocity = Vector(8, 0),
        Remove = function(self)
            self.removed = true
        end,
    }
    env.runPostFireTear(tear)
    assertTruthy(tear.removed, "a tear whose owner resolves through ToPlayer must be removed")
    assertEquals(Neverbirth.Cleaver.GetState(player).swing, nil, "post-fire cleanup must not become the primary melee trigger")
end

local function test_raw_shoot_trigger_uses_the_manual_cleaver_visual()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    env.triggerShoot(player, ButtonAction.ACTION_SHOOTRIGHT)
    local state = Neverbirth.Cleaver.GetState(player)
    assertTruthy(state.swing and state.swing.visual, "raw input must own a manual CleaverAttack visual")
    assertEquals(state.swing.visual.animation, "SwingRight_A", "the first right input must select the A machete swing")
    local remaining = Neverbirth.Cleaver.Config.SwingCarrierFallbackTick - (state.swing.tick or 0)
    if remaining > 0 then env.runPostUpdate(remaining) end
    local knife = env.getLatestKnife()
    assertTruthy(knife, "the visual must create one native EntityKnife at its carrier tick")
    assertEquals(state.swing.nativeKnife, knife, "the active swing must own the carrier spawned by its visual")
end
local function test_swing_uses_shared_scale_and_advances_at_thirty_fps()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "swing should begin")
    local swing = Neverbirth.Cleaver.GetState(player).swing
    assertEquals(swing.visual.sprite.Scale.X, 0.5, "swing must use the same half scale as the held actor")
    assertEquals(swing.visual.sprite.Scale.Y, 0.5, "swing must use the same half scale as the held actor")
    env.runPostUpdate()
    assertEquals(swing.visual.sprite.updates, 0, "30 FPS animation must not advance on the first 60 FPS game tick")
    env.runPostUpdate()
    assertEquals(swing.visual.sprite.updates, 1, "30 FPS animation must advance once after two game ticks")
    local playCount = 0
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "play" and event.animation == "SwingRight_A" then playCount = playCount + 1 end
    end
    assertEquals(playCount, 1, "one swing must Play its A/B animation exactly once instead of restarting every update")
end

local function test_swing_alternates_a_and_b_and_resolves_the_hit_once()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "first swing should begin")
    local first = Neverbirth.Cleaver.GetState(player).swing
    assertEquals(first.variant, "A", "first swing must use the A animation")
    assertEquals(first.visual.animation, "SwingRight_A", "first swing must play SwingRight_A")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    assertEquals(env.getKnifeCount(), 1, "one complete swing must create only one hidden carrier")
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "second swing should begin after the full 22-tick animation")
    local second = Neverbirth.Cleaver.GetState(player).swing
    assertEquals(second.variant, "B", "second swing must alternate to the B animation")
    assertEquals(second.visual.animation, "SwingRight_B", "second swing must play SwingRight_B")
end
local function test_combat_targets_create_one_shadow_and_later_spawns_are_tracked()
    local env = loadNeverbirth()
    configureCleaver()
    local cleaver = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    local ally = env.newPlayer({ playerType = 0, position = Vector(20, 0) })
    local boss = env.newEnemy({ boss = true, position = Vector(60, 0), size = 30 })
    env.runPostUpdate()
    local bossShadow = shadowFor(boss, "enemy")
    assertTruthy(bossShadow, "boss should receive a shadow")
    assertTruthy(shadowFor(cleaver, "player"), "cleaver player should receive a shadow")
    assertTruthy(shadowFor(ally, "player"), "co-op player should receive a shadow")
    assertNear(bossShadow.position.X, 60, 0.001, "shadow should retain entry position")
    boss.Position = Vector(90, 0)
    assertNear(bossShadow.position.X, 60, 0.001, "shadow should not follow the target")
    local spawned = env.newEnemy({ position = Vector(40, 30) })
    local invulnerableSpawn = env.newEnemy({ position = Vector(45, 30), vulnerable = false, activeEnemy = true })
    env.runPostUpdate()
    assertTruthy(shadowFor(spawned, "enemy"), "wave, summon, and split spawns should receive shadows")
    assertTruthy(shadowFor(invulnerableSpawn, "enemy"), "an active spawning enemy should receive its shadow before it becomes vulnerable")
end

local function test_swing_hits_enemy_body_and_past_shadow_then_refreshes_shadow()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    local enemy = env.newEnemy({ position = Vector(50, 0), size = 10 })
    env.runPostUpdate()
    assertNear(Neverbirth.Cleaver.GetSwingRange(player), 160, 0.0001, "normal-size Stranger should reach the requested long cleaver range")
    enemy.Position = Vector(150, 0)
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "Stranger should start a melee swing")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingCarrierFallbackTick)
    local knife = env.getLatestKnife()
    assertTruthy(knife, "swing should own an EntityKnife carrier at its configured lifecycle tick")
    assertEquals(knife.EntityCollisionClass, EntityCollisionClass.ENTCOLL_NONE, "manual sweep must not expose a native circular hitbox")
    assertEquals(env.runKnifeCollision(knife, enemy), true, "the native carrier must suppress a duplicate body collision while the swing is active")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks - Neverbirth.Cleaver.Config.SwingCarrierFallbackTick)
    assertNear(enemy.damageTaken, 8.5, 0.0001, "one full sweep must deal 0.5 body damage plus one 2x Damage shadow hit")
    assertNear(enemy.Velocity.X, 8, 0.0001, "body hit must apply the configured strong knockback")
    local refreshed = shadowFor(enemy, "enemy")
    assertTruthy(refreshed, "living enemy should receive a refreshed shadow")
    assertNear(refreshed.position.X, 150, 0.001, "refreshed enemy shadow should use the target's current position")
    assertTruthy(refreshed.sprite and refreshed.sprite ~= enemy:GetSprite(), "past shadow must render a snapshot sprite rather than recoloring the live enemy sprite")
end

local function test_swing_sweeps_the_full_front_semicircle_without_repeating_hits()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    local upper = env.newEnemy({ position = Vector(90, -70), size = 8 })
    local center = env.newEnemy({ position = Vector(130, 0), size = 8 })
    local lower = env.newEnemy({ position = Vector(90, 70), size = 8 })
    env.runPostUpdate()
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "rightward A sweep should start")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    for _, enemy in ipairs({ upper, center, lower }) do
        assertNear(enemy.damageTaken, 8.5, 0.0001, "every side and center target in the front semicircle should receive body plus shadow settlement once")
    end
end

local function test_a_and_b_paths_are_opposite_for_all_input_directions()
    local cases = {
        { input = Vector(0, -1), aStart = Vector(-1, 0), aEnd = Vector(1, 0) },
        { input = Vector(0, 1), aStart = Vector(1, 0), aEnd = Vector(-1, 0) },
        { input = Vector(-1, 0), aStart = Vector(0, 1), aEnd = Vector(0, -1) },
        { input = Vector(1, 0), aStart = Vector(0, -1), aEnd = Vector(0, 1) },
    }
    for _, case in ipairs(cases) do
        local a = { direction = case.input, variant = "A" }
        local b = { direction = case.input, variant = "B" }
        local aStart, aEnd = Neverbirth.Cleaver.GetSweepDirection(a, 0), Neverbirth.Cleaver.GetSweepDirection(a, 1)
        local bStart, bEnd = Neverbirth.Cleaver.GetSweepDirection(b, 0), Neverbirth.Cleaver.GetSweepDirection(b, 1)
        assertNear(aStart.X, case.aStart.X, 0.0001, "A sweep must start on the authored first side")
        assertNear(aStart.Y, case.aStart.Y, 0.0001, "A sweep must start on the authored first side")
        assertNear(aEnd.X, case.aEnd.X, 0.0001, "A sweep must end on the authored opposite side")
        assertNear(aEnd.Y, case.aEnd.Y, 0.0001, "A sweep must end on the authored opposite side")
        assertNear(bStart.X, case.aEnd.X, 0.0001, "B sweep must reverse the A start/end path")
        assertNear(bStart.Y, case.aEnd.Y, 0.0001, "B sweep must reverse the A start/end path")
        assertNear(bEnd.X, case.aStart.X, 0.0001, "B sweep must reverse the A start/end path")
        assertNear(bEnd.Y, case.aStart.Y, 0.0001, "B sweep must reverse the A start/end path")
    end
end

local function test_swing_lasts_all_twenty_two_ticks()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "swing should start")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks - 1)
    assertTruthy(Neverbirth.Cleaver.GetState(player).swing, "swing must remain active through tick 21")
    env.runPostUpdate()
    assertEquals(Neverbirth.Cleaver.GetState(player).swing, nil, "swing must finish only after the 22nd tick")
end
local function test_swing_reach_and_width_ignore_range_and_body_size()
    local env = loadNeverbirth()
    configureCleaver()
    local normal = env.newPlayer({ playerType = 42, size = 20, tearRange = 260 })
    local large = env.newPlayer({ playerType = 42, size = 80, tearRange = 800 })
    assertNear(Neverbirth.Cleaver.GetSwingRange(normal), Neverbirth.Cleaver.Config.BaseSwingRange, 0.0001, "normal Stranger reach must use the fixed config")
    assertNear(Neverbirth.Cleaver.GetSwingRange(large), Neverbirth.Cleaver.Config.BaseSwingRange, 0.0001, "body size and range must not change Stranger reach")
    assertNear(Neverbirth.Cleaver.GetSwingHalfWidth(normal), Neverbirth.Cleaver.Config.BaseSwingHalfWidth, 0.0001, "normal Stranger blade width must use the fixed config")
    assertNear(Neverbirth.Cleaver.GetSwingHalfWidth(large), Neverbirth.Cleaver.Config.BaseSwingHalfWidth, 0.0001, "body size and range must not change Stranger blade width")
end
local function test_one_swing_hits_multiple_shadows()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    local first = env.newEnemy({ position = Vector(50, 0), size = 8 })
    local second = env.newEnemy({ position = Vector(60, 20), size = 8 })
    env.runPostUpdate()
    Neverbirth.Cleaver.TrySwing(player, Vector(1, 0))
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    assertNear(first.damageTaken, 8.5, 0.0001, "first enemy should receive body and shadow damage once")
    assertNear(second.damageTaken, 8.5, 0.0001, "second enemy should receive body and shadow damage once")
end
local function test_player_shadow_recoil_uses_shadow_owner_damage_in_isaac_half_heart_units()
    for _, case in ipairs({
        { damage = 2.0, units = 0 }, { damage = 3.5, units = 0 }, { damage = 4.0, units = 1 },
        { damage = 4.5, units = 2 }, { damage = 5.5, units = 4 },
    }) do
        local env = loadNeverbirth()
        configureCleaver()
        local attacker = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 2 })
        local target = env.newPlayer({ playerType = 0, position = Vector(50, 0), damage = case.damage })
        env.newEnemy({ position = Vector(90, 0) })
        env.runPostUpdate()
        Neverbirth.Cleaver.TrySwing(attacker, Vector(1, 0))
        env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
        if case.units == 0 then
            assertEquals(#target.damageCalls, 0, "Shadow-owner Damage " .. tostring(case.damage) .. " should not recoil")
        else
            assertEquals(target.damageCalls[1].amount, case.units, "Shadow-owner Damage " .. tostring(case.damage) .. " should use correct Isaac half-heart units")
            assertEquals(target.damageCalls[1].source.Entity, attacker, "co-op recoil should damage the shadow owner using the attacker as source")
        end
        assertEquals(shadowFor(target, "player"), nil, "a hit player shadow should stay consumed for this room")
    end
end
local function test_self_shadow_uses_the_normal_player_damage_pipeline()
    local env = loadNeverbirth()
    configureCleaver()
    local stranger = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    env.newEnemy({ position = Vector(120, 0) })
    env.runPostUpdate()
    assertTruthy(shadowFor(stranger, "player"), "Stranger should have a self shadow in combat")
    assertTruthy(Neverbirth.Cleaver.TrySwing(stranger, Vector(1, 0)), "Stranger should swing at the self shadow")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    assertEquals(#stranger.damageCalls, 1, "self-shadow recoil must call Player:TakeDamage once")
    assertEquals(stranger.damageCalls[1].amount, 1, "Damage 4.0 should recoil for one Isaac half-heart unit")
    assertEquals(stranger.damageCalls[1].source.Entity, stranger, "self recoil should retain the attacking Stranger as normal damage source")
end
local function test_stat_caps_and_conversion_are_recalculated_from_raw_stats()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, damage = 3.5, maxFireDelay = 6.5, tearRange = 320, shotSpeed = 1.5 })
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.MaxFireDelay, 30 / 2.73 - 1, 0.0001, "tears display should cap at 2.73")
    assertNear(player.TearRange, 260, 0.0001, "range display should cap at 6.50")
    assertNear(player.ShotSpeed, 1.0, 0.0001, "shot speed display should cap at 1.00")
    assertNear(player.Damage, 2 + (0.40 * (4 - 2.73)) + 0.10 * (8 - 6.5) + 0.50 * (1.5 - 1), 0.0001, "positive raw overflow should convert to damage")

    player.Damage = 3.5
    player.MaxFireDelay = 14
    player.TearRange = 200
    player.ShotSpeed = 0.5
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.Damage, 2 + 0.40 * (2 - 2.73) + 0.10 * (5 - 6.5) + 0.50 * (0.5 - 1), 0.0001, "negative raw stats should reduce damage through the same conversion")
end

local function test_stat_conversion_respects_per_stat_and_total_caps()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, damage = 3.5, maxFireDelay = 2, tearRange = 1000, shotSpeed = 5 })
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.Damage, 3.5, 0.0001, "positive conversions must cap at +1.50 total Damage")

    player.Damage = 3.5
    player.MaxFireDelay = 59
    player.TearRange = 0
    player.ShotSpeed = 0
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.Damage, 0.5, 0.0001, "each negative conversion must clamp at -0.50 Damage")
end
local function test_item_loss_style_type_change_and_new_room_clear_runtime_state()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42 })
    env.newEnemy()
    env.runPostUpdate()
    assertTruthy(next(Neverbirth.Cleaver.shadows) ~= nil, "enabled player should create combat shadows")
    player.PlayerType = 0
    env.runPostUpdate()
    assertEquals(Neverbirth.Cleaver.states[tostring(player.InitSeed)], nil, "changing away from the bound type should clear player state")
    assertEquals(next(Neverbirth.Cleaver.shadows), nil, "no enabled player should clear all shadows")
    player.PlayerType = 42
    env.runPostUpdate()
    env.runNewRoom()
    assertEquals(next(Neverbirth.Cleaver.shadows), nil, "new room should clear old room shadows")
    env.runGameStarted()
    assertEquals(next(Neverbirth.Cleaver.states), nil, "new game should not retain cleaver state")
end

test_stranger_registration_and_cleaver_assets()
test_stranger_starts_with_cleaver_but_does_not_depend_on_the_item()
test_cleaver_has_a_persistent_handheld_visual_outside_swings()
test_non_cleaver_players_are_fully_isolated()
test_player_shooting_input_starts_a_swing_without_raw_trigger_state()
test_raw_shoot_trigger_starts_a_swing_and_spawns_the_native_hitbox_at_the_authored_frame()
test_post_fire_tear_resolves_player_owner_before_replacing_shot()
test_raw_shoot_trigger_uses_the_manual_cleaver_visual()
test_swing_uses_shared_scale_and_advances_at_thirty_fps()
test_swing_alternates_a_and_b_and_resolves_the_hit_once()
test_combat_targets_create_one_shadow_and_later_spawns_are_tracked()
test_swing_hits_enemy_body_and_past_shadow_then_refreshes_shadow()
test_swing_sweeps_the_full_front_semicircle_without_repeating_hits()
test_a_and_b_paths_are_opposite_for_all_input_directions()
test_swing_lasts_all_twenty_two_ticks()
test_swing_reach_and_width_ignore_range_and_body_size()
test_one_swing_hits_multiple_shadows()
test_player_shadow_recoil_uses_shadow_owner_damage_in_isaac_half_heart_units()
test_self_shadow_uses_the_normal_player_damage_pipeline()
test_stat_caps_and_conversion_are_recalculated_from_raw_stats()
test_stat_conversion_respects_per_stat_and_total_caps()
test_item_loss_style_type_change_and_new_room_clear_runtime_state()
print("cleaver character behavior tests passed")
