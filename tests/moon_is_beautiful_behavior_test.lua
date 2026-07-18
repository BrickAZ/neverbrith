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
    EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_PICKUP = 5, ENTITY_EFFECT = 1000 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COIN = 20, PICKUP_KEY = 30, PICKUP_BOMB = 40, PICKUP_PILL = 70, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_FULL = 2 }
    CoinSubType = { COIN_PENNY = 1 }
    KeySubType = { KEY_NORMAL = 1 }
    BombSubType = { BOMB_NORMAL = 1 }
    Card = { CARD_RANDOM = 0, CARD_FOOL = 1 }
    for key, value in pairs(options.extraCards or {}) do
        Card[key] = value
    end
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_LUCK = 1024 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_BOSS = 5 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_ANGEL = 4, POOL_PLANETARIUM = 24 }
    ActiveSlot = { SLOT_PRIMARY = 0 }
    CollectibleType = { COLLECTIBLE_NULL = 0 }
    DamageFlag = { DAMAGE_FAKE = 8, DAMAGE_EXPLOSION = 16 }
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
            collectibles = opts.collectibles or { [itemIds.TheMoonIsBeautiful] = 1 },
            firing = opts.firing == true,
            cacheFlags = {},
            evaluated = 0,
        }
        function player:ToPlayer() return self end
        function player:Exists() return not self.removed end
        function player:IsDead() return self.dead == true end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
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

    local function runDamageRef(entity, amount, sourceRef)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG)) do
            callback(mod, entity, amount or 1, 0, sourceRef, 0)
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

local function countMoonRendersAfter(env, startIndex, path)
    local count = 0
    for index = (startIndex or 0) + 1, #env.spriteEvents do
        local event = env.spriteEvents[index]
        if event.type == "render" and event.path and event.path:find("gfx/Effects/TheMoonIsBeautiful/", 1, true) then
            if not path or event.path == path then
                count = count + 1
            end
        end
    end
    return count
end

local function test_xml_registers_moon_item_pools_and_resources()
    local items = readFile("content/items.xml")
    local zhItems = readFile("content/items.zh_cn.xml")
    local enItems = readFile("content/items.en_us.xml")
    local pools = readFile("content/itempools.xml")

    assertTruthy(items:find('<passive%s+name="The Moon Is Beautiful".-quality="3"', 1), "The Moon Is Beautiful should be a quality 3 passive")
    assertTruthy(zhItems:find('name="月色真美"', 1), "zh item xml should register 月色真美")
    assertTruthy(enItems:find('name="The Moon Is Beautiful"', 1), "en item xml should register The Moon Is Beautiful")
    assertTruthy(pools:find('<Pool Name="planetarium".-<Item Name="The Moon Is Beautiful" Weight="1"', 1), "Moon should be in planetarium")
    assertTruthy(pools:find('<Pool Name="angel".-<Item Name="The Moon Is Beautiful" Weight="1"', 1), "Moon should be in angel")
    assertTruthy(pools:find('<Pool Name="treasure".-<Item Name="The Moon Is Beautiful" Weight="0%.1"', 1), "Moon should be low weight in treasure")

    local function assertMoonResource(spec)
        local pngFile = spec.pngFile or spec.file
        local layerName = spec.layerName or "body"
        local png = readPngInfo("resources/gfx/Effects/TheMoonIsBeautiful/" .. pngFile .. ".png")
        local anm2 = readFile("resources/gfx/Effects/TheMoonIsBeautiful/" .. spec.file .. ".anm2")
        assertEquals(png.width, spec.width, spec.file .. " PNG width should match the spritesheet")
        assertEquals(png.height, spec.height, spec.file .. " PNG height should match the spritesheet")
        assertEquals(png.colorType, 6, spec.file .. " PNG should be RGBA")
        assertTruthy(png.fileSize > 100, spec.file .. " PNG should not be empty")
        assertTruthy(anm2:find('<Spritesheet Id="0" Path="' .. pngFile .. '.png"', 1, true), spec.file .. " anm2 should reference the canonical PNG")
        assertTruthy(anm2:find('<Layer Name="' .. layerName .. '" Id="0" SpritesheetId="0"', 1, true), spec.file .. " anm2 should have the expected layer")
        assertTruthy(anm2:find('<Animations DefaultAnimation="' .. spec.default .. '"', 1, true), spec.file .. " should default to the expected animation")
        assertTruthy(anm2:find('<LayerAnimation LayerId="0" Visible="true"', 1, true), spec.file .. " should have a visible LayerAnimation")
        assertTruthy(anm2:find('AlphaTint="255"', 1, true), spec.file .. " should render at full alpha")
        assertTruthy(not anm2:find('AlphaTint="0"', 1, true), spec.file .. " should not contain invisible alpha-zero frames")

        for _, animation in ipairs(spec.animations) do
            local firstCrop = animation.first * spec.frameWidth
            local lastCrop = animation.last * spec.frameWidth
            local pivotX = spec.pivotX or spec.pivot
            local pivotY = spec.pivotY or spec.pivot
            assertTruthy(anm2:find('<Animation Name="' .. animation.name .. '" FrameNum="' .. animation.frames .. '" Loop="' .. animation.loop .. '"', 1, true), spec.file .. " should define " .. animation.name)
            assertTruthy(anm2:find('XPivot="' .. pivotX .. '" YPivot="' .. pivotY .. '" XCrop="' .. firstCrop .. '" YCrop="0" Width="' .. spec.frameWidth .. '" Height="' .. spec.frameHeight .. '"', 1, true), spec.file .. " " .. animation.name .. " first frame crop should match")
            assertTruthy(anm2:find('XPivot="' .. pivotX .. '" YPivot="' .. pivotY .. '" XCrop="' .. lastCrop .. '" YCrop="0" Width="' .. spec.frameWidth .. '" Height="' .. spec.frameHeight .. '"', 1, true), spec.file .. " " .. animation.name .. " last frame crop should match")
            assertTruthy(anm2:find('XCrop="' .. lastCrop .. '" YCrop="0" Width="' .. spec.frameWidth .. '" Height="' .. spec.frameHeight .. '" XScale="100" YScale="100" Delay="1"', 1, true), spec.file .. " " .. animation.name .. " should play the last frame instead of holding it with a long delay")
        end
    end

    assertMoonResource({
        file = "moon_silence_prompt",
        pngFile = "moon_silence_prompt_v2",
        layerName = "moon_silence_prompt",
        width = 1280,
        height = 96,
        frameWidth = 64,
        frameHeight = 96,
        pivotX = 32,
        pivotY = 90,
        default = "Appear",
        animations = {
            { name = "Appear", first = 0, last = 4, frames = 5, loop = "false" },
            { name = "Idle", first = 5, last = 10, frames = 6, loop = "true" },
            { name = "Success", first = 11, last = 13, frames = 3, loop = "false" },
            { name = "Fail", first = 14, last = 17, frames = 4, loop = "false" },
            { name = "Disappear", first = 18, last = 19, frames = 2, loop = "false" },
        },
    })
    assertMoonResource({
        file = "moon_silence_success",
        width = 1152,
        height = 96,
        frameWidth = 96,
        frameHeight = 96,
        pivotX = 48,
        pivotY = 64,
        default = "Burst",
        animations = {
            { name = "Burst", first = 0, last = 11, frames = 12, loop = "false" },
        },
    })
    assertMoonResource({
        file = "moon_mark",
        width = 512,
        height = 32,
        frameWidth = 32,
        frameHeight = 32,
        pivotX = 16,
        pivotY = 26,
        default = "Idle",
        animations = {
            { name = "Appear", first = 0, last = 3, frames = 4, loop = "false" },
            { name = "Idle", first = 4, last = 8, frames = 5, loop = "true" },
            { name = "Trigger", first = 9, last = 11, frames = 3, loop = "false" },
            { name = "Disappear", first = 12, last = 15, frames = 4, loop = "false" },
        },
    })
    assertMoonResource({
        file = "moon_mark_boss",
        width = 1024,
        height = 64,
        frameWidth = 64,
        frameHeight = 64,
        pivotX = 32,
        pivotY = 52,
        default = "Idle",
        animations = {
            { name = "Appear", first = 0, last = 3, frames = 4, loop = "false" },
            { name = "Idle", first = 4, last = 8, frames = 5, loop = "true" },
            { name = "Trigger", first = 9, last = 11, frames = 3, loop = "false" },
            { name = "Disappear", first = 12, last = 15, frames = 4, loop = "false" },
        },
    })
    assertMoonResource({
        file = "moon_mark_wave",
        width = 960,
        height = 96,
        frameWidth = 96,
        frameHeight = 96,
        pivotX = 48,
        pivotY = 84,
        default = "Wave",
        animations = {
            { name = "Wave", first = 0, last = 9, frames = 10, loop = "false" },
        },
    })
    assertMoonResource({
        file = "moon_reward_drop",
        width = 768,
        height = 64,
        frameWidth = 64,
        frameHeight = 64,
        pivotX = 32,
        pivotY = 48,
        default = "Reward",
        animations = {
            { name = "Reward", first = 0, last = 11, frames = 12, loop = "false" },
        },
    })
end

local function test_prompt_plays_appear_then_idle()
    local env = loadNeverbirth()
    env.newPlayer()

    env.runPostUpdate(1)
    env.runPostUpdate(5)

    local promptPlays = {}
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "play" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2" then
            promptPlays[#promptPlays + 1] = event.animation
        end
    end

    assertEquals(promptPlays[1], "Appear", "opening Moon prompt should begin with Appear")
    assertEquals(promptPlays[2], "Idle", "opening Moon prompt should transition into Idle after Appear")
end

local function test_prompt_respawns_if_visual_table_was_cleared()
    local env = loadNeverbirth()
    env.newPlayer()

    env.runPostUpdate(1)
    env.clearMoonVisuals()

    local afterClear = #env.spriteEvents
    env.runPostUpdate(1)
    env.runRender()

    assertTruthy(countMoonRendersAfter(env, afterClear, "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2") > 0, "Moon prompt should respawn when its stored visual id was pruned")
end

local function test_silence_window_triggers_room_bonus_and_marks_enemies()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 12, luck = 1 })
    local enemy = env.newEnemy()
    local boss = env.newEnemy({ boss = true, position = Vector(190, 100) })

    env.runPostUpdate(60)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Damage, 13, "Moon silence should grant room damage")
    assertEquals(player.Luck, 2, "Moon silence should grant room luck")
    assertEquals(enemy:GetData().NeverbirthMoonMarked, true, "normal enemy should be marked")
    assertEquals(boss:GetData().NeverbirthMoonMarked, true, "boss should be marked")
    assertTruthy(player.evaluated > 0, "triggering should refresh cache")

    local loadedPrompt = false
    local loadedSuccess = false
    for _, event in ipairs(env.spriteEvents) do
        loadedPrompt = loadedPrompt or event.path == "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2"
        loadedSuccess = loadedSuccess or event.path == "gfx/Effects/TheMoonIsBeautiful/moon_silence_success.anm2"
    end
    assertTruthy(loadedPrompt, "prompt visual should load during the window")
    assertTruthy(loadedSuccess, "success visual should load on trigger")
end

local function test_moon_visuals_render_in_screen_space_and_follow_heads()
    local env = loadNeverbirth()
    local player = env.newPlayer({
        position = Vector(120, 100),
        positionOffset = Vector(0, -3),
        flyingOffset = Vector(0, -2),
    })
    local enemy = env.newEnemy({ position = Vector(160, 100), size = 20 })
    local boss = env.newEnemy({ position = Vector(220, 120), size = 60, boss = true })

    env.runPostUpdate(1)
    env.runRender()

    local promptRender = nil
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2" then
            promptRender = event.position
        end
    end

    assertTruthy(promptRender, "prompt should render while the Moon window is open")
    assertEquals(promptRender.X, 1120, "prompt should render in screen-space X coordinates")
    assertEquals(promptRender.Y, 2071, "prompt should use the player-head anchor before WorldToScreen")

    env.runPostUpdate(59)
    env.runRender()

    local normalMark = nil
    local bossMark = nil
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark.anm2" then
            normalMark = event.position
        elseif event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark_boss.anm2" then
            bossMark = event.position
        end
    end

    assertTruthy(normalMark, "normal enemy mark should render")
    assertTruthy(bossMark, "boss mark should render")
    assertEquals(normalMark.X, 1160, "normal mark should render in screen-space X coordinates")
    assertEquals(normalMark.Y, 2066, "normal mark should sit above the enemy head using enemy size")
    assertEquals(bossMark.X, 1220, "boss mark should render in screen-space X coordinates")
    assertEquals(bossMark.Y, 2038, "boss mark should scale its head offset with boss size")

    enemy.Position = Vector(180, 130)
    env.runPostUpdate(1)
    env.runRender()

    local movedMark = nil
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark.anm2" then
            movedMark = event.position
        end
    end

    assertEquals(movedMark.X, 1180, "normal mark should follow moved enemy X position")
    assertEquals(movedMark.Y, 2096, "normal mark should follow moved enemy Y position")
end

local function test_moon_visuals_clear_when_room_changes_or_rewinds()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 20 })
    local marked = env.newEnemy({ position = Vector(160, 100), size = 24 })
    env.newEnemy({ position = Vector(200, 100) })

    env.runPostUpdate(60)
    env.runDamage(marked, 5, env.newTear(player))
    env.runRender()

    local afterInitialRender = #env.spriteEvents
    env.runNewRoom()
    env.runRender()

    assertEquals(countMoonRendersAfter(env, afterInitialRender), 0, "new room reset should clear stale Moon visuals before the next update")

    local newMarked = env.newEnemy({ position = Vector(180, 120), size = 24 })
    env.runPostUpdate(60)
    env.runDamage(newMarked, 5, env.newTear(player))
    env.runRender()

    local afterRewindRender = #env.spriteEvents
    env.setRoomIndex(999)
    env.runPostUpdate(1)
    env.runRender()

    assertEquals(countMoonRendersAfter(env, afterRewindRender, "gfx/Effects/TheMoonIsBeautiful/moon_mark.anm2"), 0, "room-key rewind should clear stale Moon marks")
    assertEquals(countMoonRendersAfter(env, afterRewindRender, "gfx/Effects/TheMoonIsBeautiful/moon_mark_wave.anm2"), 0, "room-key rewind should clear stale Moon waves")
end

local function test_moon_visuals_clear_when_owner_is_removed()
    local env = loadNeverbirth()
    env.newPlayer()
    local enemy = env.newEnemy({ position = Vector(160, 100), size = 24 })

    env.runPostUpdate(60)
    env.runRender()

    local afterMarkedRender = #env.spriteEvents
    enemy:Remove()
    env.runPostUpdate(1)
    env.runRender()

    assertEquals(countMoonRendersAfter(env, afterMarkedRender, "gfx/Effects/TheMoonIsBeautiful/moon_mark.anm2"), 0, "removed enemies should not keep rendering stale Moon marks")
end

local function test_firing_prevents_late_trigger_after_window_expires()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 8, luck = 0, firing = true })
    local enemy = env.newEnemy()

    env.runPostUpdate(121)
    player.firing = false
    env.runPostUpdate(80)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Damage, 8, "Moon silence should not trigger after the first two seconds")
    assertEquals(player.Luck, 0, "Moon silence should not grant luck after a failed window")
    assertEquals(enemy:GetData().NeverbirthMoonMarked, nil, "enemy should not be marked after a failed window")
end

local function test_expired_silence_window_plays_fail()
    local env = loadNeverbirth()
    local player = env.newPlayer({ firing = true })

    env.runPostUpdate(121)
    env.runRender()

    local failPlayed = false
    local failRendered = false
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "play" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2" and event.animation == "Fail" then
            failPlayed = true
        elseif event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_silence_prompt.anm2" and event.animation == "Fail" then
            failRendered = true
        end
    end
    assertTruthy(failPlayed, "expired Moon silence window should play Fail once")
    assertTruthy(failRendered, "expired Moon silence window should render Fail once")
end

local function test_mark_first_player_hit_releases_wave_once()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 20 })
    local marked = env.newEnemy({ position = Vector(160, 100), positionOffset = Vector(0, -6), size = 24 })
    local nearby = env.newEnemy({ position = Vector(200, 100) })
    local far = env.newEnemy({ position = Vector(400, 100) })

    env.runPostUpdate(60)
    env.runDamage(marked, 5, env.newTear(player))
    env.runDamage(marked, 5, env.newTear(player))
    env.runRender()

    assertEquals(marked:GetData().NeverbirthMoonMarked, false, "first hit should consume the mark")
    assertNear(nearby.damageTaken, 6, 0.0001, "wave should deal 30% player damage nearby")
    assertEquals(far.damageTaken, 0, "wave should not hit far enemies")

    local wavePlays = 0
    local waveRender = nil
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "play" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark_wave.anm2" then
            wavePlays = wavePlays + 1
            assertEquals(event.animation, "Wave", "mark wave should play the Wave animation")
        elseif event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark_wave.anm2" then
            waveRender = event.position
        end
    end
    assertEquals(wavePlays, 1, "mark wave should play once")
    assertTruthy(waveRender, "mark wave should render")
    assertEquals(waveRender.X, 1160, "mark wave should render from the enemy foot X")
    assertEquals(waveRender.Y, 2094, "mark wave should use the foot anchor expected by the 48/84 pivot")
end

local function test_boss_mark_persists_after_first_player_hit_while_wave_stays_once()
    local env = loadNeverbirth({ roomType = RoomType.ROOM_BOSS })
    local player = env.newPlayer({ damage = 20 })
    local boss = env.newEnemy({ boss = true, position = Vector(160, 100) })
    local nearby = env.newEnemy({ position = Vector(200, 100) })

    env.runPostUpdate(60)
    env.runDamage(boss, 5, env.newTear(player))
    env.runDamage(boss, 5, env.newTear(player))
    env.runRender()

    assertEquals(boss:GetData().NeverbirthMoonMarked, true, "boss Moon mark should remain until the boss dies")
    assertNear(nearby.damageTaken, 6, 0.0001, "boss Moon wave should still deal damage only once")

    local wavePlays = 0
    local bossMarkRendered = false
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "play" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark_wave.anm2" then
            wavePlays = wavePlays + 1
        elseif event.type == "render" and event.path == "gfx/Effects/TheMoonIsBeautiful/moon_mark_boss.anm2" then
            bossMarkRendered = true
        end
    end
    assertEquals(wavePlays, 1, "boss Moon wave should only release on its first player hit")
    assertTruthy(bossMarkRendered, "boss Moon mark visual should remain after its first player hit")
end

local function getLastCardSpawn(env)
    local card = nil
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_PICKUP and spawn.Variant == PickupVariant.PICKUP_TAROTCARD then
            card = spawn
        end
    end
    return card
end

local function test_marked_enemy_death_can_drop_common_reward()
    local env = loadNeverbirth({ rngValues = { 0, 0 } })
    local player = env.newPlayer()
    local enemy = env.newEnemy()

    env.runPostUpdate(60)
    env.runDeath(enemy)

    assertEquals(#env.spawns, 1, "marked enemy death should drop a reward when the 10% roll succeeds")
    assertEquals(env.spawns[1].Type, EntityType.ENTITY_PICKUP, "reward should be a pickup")
end

local function test_marked_enemy_death_reward_skips_unknown_cards_without_blocking_mod_cards()
    local env = loadNeverbirth({
        rngValues = { 0, 5 },
        extraCards = { MOD_MOON_CARD = 42 },
        cardPoolSequence = { 230967295, 42 },
        cardConfigs = {
            [230967295] = { ID = 230967295, Name = "5.300.0230967295", Description = "(no description available)", GfxFileName = "placeholder.png" },
            [42] = { ID = 42, Name = "Mod Moon Card", Description = "A real custom card" },
        },
        eidDescriptions = {
            [230967295] = false,
            [42] = { Name = "Mod Moon Card", Description = "A real custom card" },
        },
    })
    local player = env.newPlayer()
    local enemy = env.newEnemy()

    env.runPostUpdate(60)
    env.runDeath(enemy)

    local card = getLastCardSpawn(env)
    assertTruthy(card, "marked enemy death should still be able to drop a card reward")
    assertEquals(card.SubType, 42, "Moon card reward should skip unknown card subtypes and allow valid modded cards")
end

local function test_boss_room_bonus_only_applies_to_player_tears()
    local env = loadNeverbirth({ roomType = RoomType.ROOM_BOSS })
    local player = env.newPlayer({ damage = 10 })
    local boss = env.newEnemy({ boss = true })
    local normalSource = player

    env.runPostUpdate(60)
    env.runDamage(boss, 10, env.newTear(player))
    assertNear(boss.damageTaken, 5, 0.0001, "boss should take 50% extra damage from player tears")

    env.runDamage(boss, 10, normalSource)
    assertNear(boss.damageTaken, 5, 0.0001, "non-tear player damage should not get the boss bonus")
end

local function test_boss_room_bonus_accepts_entityref_tear_source()
    local env = loadNeverbirth({ roomType = RoomType.ROOM_BOSS })
    local player = env.newPlayer({ damage = 10 })
    local boss = env.newEnemy({ boss = true })

    env.runPostUpdate(60)
    env.runDamageRef(boss, 10, env.newTearRef(player))

    assertNear(boss.damageTaken, 5, 0.0001, "boss bonus should accept EntityRef-style tear sources without an Entity field")
end

local function test_cleared_room_and_missing_item_do_not_trigger()
    local cleared = loadNeverbirth({ roomClear = true })
    local clearedPlayer = cleared.newPlayer({ damage = 10 })
    cleared.runPostUpdate(80)
    cleared.runEvaluate(clearedPlayer, CacheFlag.CACHE_DAMAGE)
    assertEquals(clearedPlayer.Damage, 10, "cleared rooms should not open the Moon silence window")

    local noItem = loadNeverbirth()
    local player = noItem.newPlayer({ damage = 10, collectibles = {} })
    noItem.newEnemy()
    noItem.runPostUpdate(80)
    noItem.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertEquals(player.Damage, 10, "players without Moon should not trigger")
end

test_xml_registers_moon_item_pools_and_resources()
test_prompt_plays_appear_then_idle()
test_prompt_respawns_if_visual_table_was_cleared()
test_silence_window_triggers_room_bonus_and_marks_enemies()
test_moon_visuals_render_in_screen_space_and_follow_heads()
test_moon_visuals_clear_when_room_changes_or_rewinds()
test_moon_visuals_clear_when_owner_is_removed()
test_firing_prevents_late_trigger_after_window_expires()
test_expired_silence_window_plays_fail()
test_mark_first_player_hit_releases_wave_once()
test_boss_mark_persists_after_first_player_hit_while_wave_stays_once()
test_marked_enemy_death_can_drop_common_reward()
test_marked_enemy_death_reward_skips_unknown_cards_without_blocking_mod_cards()
test_boss_room_bonus_only_applies_to_player_tears()
test_boss_room_bonus_accepts_entityref_tear_source()
test_cleared_room_and_missing_item_do_not_trigger()

print("moon is beautiful behavior tests passed")
