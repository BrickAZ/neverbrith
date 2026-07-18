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
    }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_BOMB = 4, ENTITY_PICKUP = 5, ENTITY_LASER = 7, ENTITY_KNIFE = 8, ENTITY_PROJECTILE = 9, ENTITY_EFFECT = 1000 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COIN = 20, PICKUP_KEY = 30, PICKUP_BOMB = 40, PICKUP_PILL = 70, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_FULL = 2 }
    CoinSubType = { COIN_PENNY = 1 }
    KeySubType = { KEY_NORMAL = 1 }
    BombSubType = { BOMB_NORMAL = 1 }
    Card = { CARD_RANDOM = 0, CARD_FOOL = 1 }
    for key, value in pairs(options.extraCards or {}) do
        Card[key] = value
    end
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SPEED = 8, CACHE_FIREDELAY = 64, CACHE_LUCK = 1024 }
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
        local sprite = { path = nil, animation = nil, updates = 0, renders = {} }
        function sprite:Load(path) self.path = path; spriteEvents[#spriteEvents + 1] = { type = "load", path = path } end
        function sprite:Play(animation) self.animation = animation; spriteEvents[#spriteEvents + 1] = { type = "play", animation = animation, path = self.path } end
        function sprite:Update() self.updates = self.updates + 1 end
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
            function entity:GetData() return self.data end
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
            Position = opts.position or Vector(120, 100),
            PositionOffset = opts.positionOffset or Vector(0, 0),
            Damage = opts.damage or 10,
            Luck = opts.luck or 0,
            collectibles = opts.collectibles or { [itemIds.BurnAwayResentment] = 1 },
            MoveSpeed = opts.moveSpeed or 1,
            MaxFireDelay = opts.maxFireDelay or 10,
            hearts = opts.hearts or 8,
            soulHearts = opts.soulHearts or 0,
            boneHearts = opts.boneHearts or 0,
            Size = opts.size or 20,
            firing = opts.firing == true,
            cacheFlags = {},
            evaluated = 0,
        }
        function player:ToPlayer() return self end
        function player:Exists() return not self.removed end
        function player:IsDead() return self.dead == true end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:GetHearts() return self.hearts end
        function player:GetSoulHearts() return self.soulHearts end
        function player:GetBoneHearts() return self.boneHearts end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetShootingInput() return self.firing and Vector(1, 0) or Vector(0, 0) end
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
            PositionOffset = opts.positionOffset or Vector(0, 0),
            dead = false,
        }
        function enemy:IsVulnerableEnemy() return true end
        function enemy:IsBoss() return self.boss end
        function enemy:Exists() return not self.removed end
        function enemy:IsDead() return self.dead == true end
        function enemy:ToNPC() return self end
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
        return { Type = EntityType.ENTITY_TEAR, Position = Vector(140, 100), SpawnerEntity = player }
    end

    local function newTearRef(player)
        return { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player }
    end

    local function runPostUpdate(times)
        for _ = 1, times or 1 do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback(mod) end
        end
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

    local function runGameStarted()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do callback(mod, false) end
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

local function test_burn_away_resentment_visual_resources_match_runtime_contract()
    local status = readFile("resources/gfx/Effects/BurnAwayResentment/ResentmentStatus.anm2")
    local burst = readFile("resources/gfx/Effects/BurnAwayResentment/PurgeWave.anm2")
    local statusPng = readPngInfo("resources/gfx/Effects/BurnAwayResentment/ResentmentStatus.png")
    local burstPng = readPngInfo("resources/gfx/Effects/BurnAwayResentment/PurgeWave.png")
    assertTruthy(status:find('DefaultAnimation="Resentment"', 1, true), "status ANM2 should default to Resentment")
    assertTruthy(status:find('Animation Name="Resentment" FrameNum="5" Loop="false"', 1, true), "status ANM2 should expose five resentment frames")
    assertTruthy(status:find('Animation Name="Ready" FrameNum="4" Loop="true"', 1, true), "status ANM2 should expose looping Ready")
    assertTruthy(status:find('Animation Name="Clarity" FrameNum="6" Loop="false"', 1, true), "status ANM2 should expose six clarity frames")
    assertTruthy(burst:find('DefaultAnimation="Burst"', 1, true), "purge ANM2 should default to Burst")
    assertTruthy(burst:find('Animation Name="Burst" FrameNum="12" Loop="false"', 1, true), "purge ANM2 should expose the 12-frame burst")
    assertEquals(statusPng.width, 288, "status PNG width")
    assertEquals(statusPng.height, 144, "status PNG height")
    assertEquals(burstPng.width, 384, "burst PNG width")
    assertEquals(burstPng.height, 288, "burst PNG height")
end

local function test_xml_registers_burn_away_resentment()
    local items = readFile("content/items.xml")
    local zh = readFile("content/items.zh_cn.xml")
    local en = readFile("content/items.en_us.xml")
    local pools = readFile("content/itempools.xml")
    assertTruthy(items:find('name="Burn Away the Resentment"', 1, true), "default XML should register Burn Away the Resentment")
    assertTruthy(zh:find('name="焚尽郁结"', 1, true), "Chinese XML should register 焚尽郁结")
    assertTruthy(en:find('name="Burn Away the Resentment"', 1, true), "English XML should register Burn Away the Resentment")
    assertTruthy(pools:find('<Pool Name="curse">', 1, true) and pools:find('Name="Burn Away the Resentment"', 1, true), "curse pool should contain Burn Away the Resentment")
    assertTruthy(pools:find('<Pool Name="devil">', 1, true), "devil pool should exist")
end

local function clearCurrentRoom(env, enemy)
    enemy.removed = true
    env.setRoomClear(true)
    env.runPostUpdate()
end

local function test_initial_layers_and_room_clear_stacks()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 10 })
    local enemy = env.newEnemy()
    env.runPostUpdate()
    assertEquals(burnState(player).currentLayers, 2, "first pickup should grant exactly 2 layers")
    env.runPostUpdate(3)
    assertEquals(burnState(player).currentLayers, 2, "holding extra update frames should not repeat initial layers")
    clearCurrentRoom(env, enemy)
    assertEquals(burnState(player).currentLayers, 3, "first normal hostile clear should add 1 layer")
    env.runPostUpdate(2)
    assertEquals(burnState(player).currentLayers, 3, "same room clear should count once")

    env.runNewRoom()
    env.setRoomClear(false)
    local nextEnemy = env.newEnemy()
    env.runPostUpdate()
    clearCurrentRoom(env, nextEnemy)
    assertEquals(burnState(player).currentLayers, 4, "second hostile room should add one more layer")
end

local function test_boss_clear_adds_two_layers()
    local env = loadNeverbirth({ roomType = 5 })
    local player = env.newPlayer()
    local boss = env.newEnemy({ boss = true })
    env.runPostUpdate()
    clearCurrentRoom(env, boss)
    assertEquals(burnState(player).currentLayers, 4, "boss clear should add normal 1 plus bonus 1")
end

local function test_ready_direct_hit_purges_once()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 10 })
    local enemy = env.newEnemy()
    env.runPostUpdate()
    local state = burnState(player)
    state.currentLayers = 6
    state.readyRoomKey = state.roomKey
    env.runDamage(enemy, 1, { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player })
    assertEquals(enemy.damageTaken, 30, "ready direct player hit should deal 300% damage")
    assertEquals(enemy.burnDuration, 90, "ready purge should burn enemies for 3 seconds")
    assertEquals(state.currentLayers, 0, "ready purge should consume all layers")
    assertEquals(state.pendingClarity, 6, "ready purge should bank 6 clarity")
    assertTruthy(state.floorSettled, "ready purge should settle the floor")
    env.runDamage(enemy, 1, { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player })
    assertEquals(enemy.damageTaken, 30, "settled floor must not recurse or purge twice")
end

local function test_hurt_purges_after_real_health_loss()
    for layers = 3, 6 do
        local env = loadNeverbirth()
        local player = env.newPlayer({ damage = 10, hearts = 8 })
        local enemy = env.newEnemy()
        env.runPostUpdate()
        local state = burnState(player)
        state.currentLayers = layers
        env.runDamage(player, 1, enemy)
        assertEquals(enemy.damageTaken, 0, "damage callback must not burst before health loss is confirmed")
        player.hearts = player.hearts - 2
        env.runPostUpdate()
        assertEquals(enemy.damageTaken, layers * 5, "hurt purge multiplier should match spent layers")
        assertEquals(enemy.burnDuration, 90, "hurt purge should burn for 3 seconds")
        assertEquals(state.pendingClarity, layers, "hurt purge should bank exactly spent layers")
        assertTruthy(state.floorSettled, "hurt purge should settle the floor")
    end
end

local function test_invalid_or_blocked_hurt_does_not_purge()
    local invalidFlags = { DamageFlag.DAMAGE_FAKE, DamageFlag.DAMAGE_IV_BAG, DamageFlag.DAMAGE_DEVIL, DamageFlag.DAMAGE_CURSED_DOOR, DamageFlag.DAMAGE_SPIKES }
    for _, flags in ipairs(invalidFlags) do
        local env = loadNeverbirth()
        local player = env.newPlayer({ hearts = 8 })
        local enemy = env.newEnemy()
        env.runPostUpdate()
        local state = burnState(player)
        state.currentLayers = 4
        env.runDamageRef(player, 1, EntityRef(enemy), flags)
        player.hearts = player.hearts - 2
        env.runPostUpdate(3)
        assertEquals(enemy.damageTaken, 0, "excluded damage flags must not purge")
        assertEquals(state.currentLayers, 4, "excluded damage must keep layers")
    end

    local shielded = loadNeverbirth()
    local player = shielded.newPlayer({ hearts = 8 })
    local enemy = shielded.newEnemy()
    shielded.runPostUpdate()
    local state = burnState(player)
    state.currentLayers = 4
    shielded.runDamage(player, 1, enemy)
    shielded.runPostUpdate(3)
    assertEquals(enemy.damageTaken, 0, "blocked damage with no health loss must not purge")
    assertEquals(state.currentLayers, 4, "blocked damage must keep layers")

    local sacrifice = loadNeverbirth({ roomType = 13 })
    local sacrificePlayer = sacrifice.newPlayer({ hearts = 8 })
    local sacrificeEnemy = sacrifice.newEnemy()
    sacrifice.runPostUpdate()
    local sacrificeState = burnState(sacrificePlayer)
    sacrificeState.currentLayers = 4
    sacrifice.runDamage(sacrificePlayer, 1, sacrificeEnemy)
    sacrificePlayer.hearts = sacrificePlayer.hearts - 2
    sacrifice.runPostUpdate(3)
    assertEquals(sacrificeEnemy.damageTaken, 0, "sacrifice room damage must not purge")
    assertEquals(sacrificeState.currentLayers, 4, "sacrifice room damage must keep layers")
end

local function test_floor_transition_cache_and_independent_players()
    local env = loadNeverbirth()
    local first = env.newPlayer({ damage = 10, maxFireDelay = 10, moveSpeed = 1 })
    local second = env.newPlayer({ damage = 10, maxFireDelay = 10, moveSpeed = 1 })
    env.runPostUpdate()
    local firstState = burnState(first)
    local secondState = burnState(second)
    firstState.currentLayers = 3
    secondState.currentLayers = 5
    env.runNewLevel()
    assertEquals(firstState.currentLayers, 0, "new level should clear old resentment")
    assertEquals(firstState.currentFloorClarity, 3, "new level should convert unsettled layers to clarity")
    assertEquals(secondState.currentFloorClarity, 5, "players should settle clarity independently")
    env.runEvaluate(first, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(first, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(first, CacheFlag.CACHE_SPEED)
    assertNear(first.Damage, 11.05, 0.0001, "3 clarity should add 1.05 damage")
    assertNear(first.MaxFireDelay, 9.64, 0.0001, "3 clarity should lower MaxFireDelay by 0.36")
    assertNear(first.MoveSpeed, 1, 0.0001, "new level should remove resentment speed penalty")
end

local function test_item_loss_and_runtime_reset_clear_state_and_visuals()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runPostUpdate()
    env.runRender()
    assertTruthy(#env.spriteEvents > 0, "status visual should attempt Sprite rendering while the item is held")
    player.collectibles[env.items.BurnAwayResentment] = 0
    env.runPostUpdate()
    assertEquals(Neverbirth.BurnAwayResentment.states[tostring(player.InitSeed)], nil, "item loss should clear runtime state")
    player.collectibles[env.items.BurnAwayResentment] = 1
    env.runPostUpdate()
    assertEquals(burnState(player).currentLayers, 2, "reacquiring should start a fresh holding with 2 layers")
    env.runGameStarted()
    assertEquals(next(Neverbirth.BurnAwayResentment.states), nil, "new run should not retain state")
end

test_burn_away_resentment_visual_resources_match_runtime_contract()
test_xml_registers_burn_away_resentment()
test_initial_layers_and_room_clear_stacks()
test_boss_clear_adds_two_layers()
test_ready_direct_hit_purges_once()
test_hurt_purges_after_real_health_loss()
test_invalid_or_blocked_hurt_does_not_purge()
test_floor_transition_cache_and_independent_players()
test_item_loss_and_runtime_reset_clear_state_and_visuals()

print("burn away resentment behavior tests passed")