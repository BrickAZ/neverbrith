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
    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        DS4 = 739,
        UncutCord = 740,
        ShreddedTarot = 741,
        SterilizationCertificate = 742,
        EmptyCradle = 743,
        BloodSkullGu = 744,
        BetweenDeathAndLife = 745,
        Condom = 746,
        UtilityKnife = 747,
        CoinSewnSword = 748,
        CoinFacedMask = 749,
        BlackTaisui = 750,
        GoodGirlOfBabylon = 751,
    }

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
    CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_PLAN_C = 475, COLLECTIBLE_DEATH_CERTIFICATE = 628 }
    CacheFlag = { CACHE_DAMAGE = 1, CACHE_SHOTSPEED = 2, CACHE_TEARCOLOR = 4, CACHE_SPEED = 8, CACHE_FIREDELAY = 16, CACHE_TEARFLAG = 32, CACHE_RANGE = 64, CACHE_LUCK = 1024 }
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_NOKILL = 2, DAMAGE_INVINCIBLE = 4, DAMAGE_FAKE = 8, DAMAGE_IV_BAG = 16 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1, TEAR_PIERCING = 2, TEAR_SPECTRAL = 4 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_TEAR = 2, ENTITY_PICKUP = 5, ENTITY_EFFECT = 1000, ENTITY_SLOT = 6 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COIN = 20, PICKUP_KEY = 30, PICKUP_BOMB = 40, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_HALF = 1, HEART_FULL = 2, HEART_SOUL = 3, HEART_BLACK = 6, HEART_HALF_SOUL = 8, HEART_HALF_BLACK = 10 }
    CoinSubType = { COIN_PENNY = 1 }
    Card = { CARD_RANDOM = 0, CARD_FOOL = 1, RUNE_HAGALAZ = 32 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_BOSS = 5, ROOM_DEVIL = 14, ROOM_ANGEL = 15, ROOM_SACRIFICE = 17 }
    GameStateFlag = { STATE_DEVILROOM_SPAWNED = 5, STATE_DEVILROOM_VISITED = 6 }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2, SLOT_POCKET2 = 3 }
    ItemConfig = { TAG_BABY = 1 }
    EffectVariant = { POOF01 = 1, BLOOD_EXPLOSION = 2, PLAYER_CREEP_BLACK = 3, CREEP_RED = 4 }

    local roomClear = options.roomClear == true
    local roomIndex = options.roomIndex or 1
    local stage = options.stage or 1
    local cardPoolSequence = options.cardPoolSequence or {}
    local cardPoolIndex = 0

    function MusicManager()
        return { GetCurrentMusicID = function() return 1 end, Play = function() end, Fadeout = function() end }
    end

    function Game()
        return {
            GetSeeds = function()
                return { GetStartSeedString = function() return "TEST RUN" end }
            end,
            GetNumPlayers = function() return #players end,
            GetItemPool = function()
                local pool = { GetCollectible = function() return 1 end }
                if options.cardPoolSequence then
                    pool.GetCard = function()
                        cardPoolIndex = cardPoolIndex + 1
                        return cardPoolSequence[cardPoolIndex] or Card.CARD_FOOL
                    end
                end
                return pool
            end,
            GetHUD = function()
                return { ShowItemText = function() end }
            end,
            GetRoom = function()
                return {
                    GetSpawnSeed = function() return 5000 end,
                    GetCenterPos = function() return Vector(320, 280) end,
                    GetType = function() return RoomType.ROOM_DEFAULT end,
                    IsClear = function() return roomClear end,
                    FindFreePickupSpawnPosition = function(_, pos) return pos end,
                    IsPositionInRoom = function() return true end,
                }
            end,
            GetLevel = function()
                return {
                    GetStage = function() return stage end,
                    GetStageType = function() return 0 end,
                    GetCurrentRoomIndex = function() return roomIndex end,
                    AddAngelRoomChance = function() end,
                    InitializeDevilAngelRoom = function() end,
                }
            end,
            Spawn = function(_, entityType, variant, position, velocity, spawner, subtype, seed)
                local spawn = { Type = entityType, Variant = variant, SubType = subtype, Position = position, Velocity = velocity, SpawnerEntity = spawner, seed = seed, viaGame = true }
                spawns[#spawns + 1] = spawn
                return spawn
            end,
            GetStateFlag = function() return false end,
            SetStateFlag = function() end,
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            local byName = {
                EssentialBalm = itemIds.EssentialBalm,
                Wuhu = itemIds.Wuhu,
                Aphrodisiac = itemIds.Aphrodisiac,
                Musicbox = itemIds.Musicbox,
                Angelbox = itemIds.Angelbox,
                Devilbox = itemIds.Devilbox,
                ds4 = itemIds.DS4,
                ["Uncut Cord"] = itemIds.UncutCord,
                ["未剪断的脐带"] = itemIds.UncutCord,
                ["Shredded Tarot"] = itemIds.ShreddedTarot,
                ["剪碎的塔罗"] = itemIds.ShreddedTarot,
                ["Sterilization Certificate"] = itemIds.SterilizationCertificate,
                ["绝育证明"] = itemIds.SterilizationCertificate,
                ["Empty Cradle"] = itemIds.EmptyCradle,
                ["空摇篮"] = itemIds.EmptyCradle,
                ["Blood Skull Gu"] = itemIds.BloodSkullGu,
                ["血颅蛊"] = itemIds.BloodSkullGu,
                ["Between Death and Life"] = itemIds.BetweenDeathAndLife,
                ["生死一念间"] = itemIds.BetweenDeathAndLife,
                Condom = itemIds.Condom,
                ["避孕套"] = itemIds.Condom,
                ["Utility Knife"] = itemIds.UtilityKnife,
                ["美工刀"] = itemIds.UtilityKnife,
                ["Coin-Sewn Sword"] = itemIds.CoinSewnSword,
                ["铜钱剑"] = itemIds.CoinSewnSword,
                ["Coin-Faced Mask"] = itemIds.CoinFacedMask,
                ["铜钱面具"] = itemIds.CoinFacedMask,
                ["Black Taisui"] = itemIds.BlackTaisui,
                ["黑太岁"] = itemIds.BlackTaisui,
                ["Good Girl of Babylon"] = itemIds.GoodGirlOfBabylon,
                ["巴比伦好女孩"] = itemIds.GoodGirlOfBabylon,
            }
            return byName[name] or -1
        end,
        GetMusicIdByName = function() return -1 end,
        GetPlayer = function(index) return players[(index or 0) + 1] end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then return players end
            return {}
        end,
        GetRoomEntities = function() return roomEntities end,
        DebugString = function() end,
        GetEntityVariantByName = function(name)
            local variants = {
                ["Good Girl Halo"] = 3002,
                ["Good Girl Charm"] = 3003,
                ["Good Girl Reward"] = 3004,
                ["Good Girl Break"] = 3005,
                ["Good Girl Echo"] = 3006,
            }
            return variants[name] or -1
        end,
        GetCostumeIdByPath = function(path)
            if path == "gfx/characters/costume_good_girl_of_babylon.anm2" then
                return 17494
            end
            return -1
        end,
        Spawn = function(entityType, variant, subtype, position, velocity, spawner)
            local spawn = {
                Type = entityType,
                Variant = variant,
                SubType = subtype,
                Position = position,
                PositionOffset = Vector(0, 0),
                SpriteOffset = Vector(0, 0),
                DepthOffset = 0,
                Velocity = velocity,
                SpawnerEntity = spawner,
                data = {},
            }
            function spawn:GetData() return self.data end
            function spawn:GetSprite() return { Play = function() end, IsFinished = function() return false end } end
            function spawn:ToEffect() return self end
            function spawn:FollowParent(parent) self.followedParent = parent end
            function spawn:Remove() self.removed = true end
            spawns[#spawns + 1] = spawn
            return spawn
        end,
        GetItemConfig = function()
            return {
                GetCollectible = function() return { Tags = 0, Type = 3, MaxCharges = 3, Name = "Mock" } end,
                GetCollectibles = function() return {} end,
                GetCard = function(_, subtype)
                    if options.cardConfigs and options.cardConfigs[subtype] ~= nil then
                        return options.cardConfigs[subtype]
                    end
                    return { ID = subtype, Name = "Card " .. tostring(subtype), Description = "Defined card" }
                end,
            }
        end,
    }

    EID = nil
    if options.eidDescriptions then
        EID = {
            getDescriptionObjByID = function(_, entityType, variant, subtype)
                local desc = options.eidDescriptions[subtype]
                if desc == false then
                    return { Name = tostring(entityType) .. "." .. tostring(variant) .. "." .. tostring(subtype), Description = "(no description available)" }
                end
                return desc
            end,
        }
    end

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

    local function getCallbacks(callbackId, param)
        local found = {}
        for _, registration in ipairs(callbacks[callbackId] or {}) do
            if param == nil or registration.param == nil or registration.param == param then
                found[#found + 1] = registration.fn
            end
        end
        return found
    end

    local function runEvaluate(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do callback(mod, player, cacheFlag) end
    end

    local function runDamage(player, amount, flags)
        local result
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_ENTITY_TAKE_DMG, EntityType.ENTITY_PLAYER)) do
            local value = callback(mod, player, amount or 1, flags or 0, EntityRef(player), 0)
            if value == false then result = false end
        end
        return result
    end

    local function runPostUpdate(times)
        for _ = 1, times or 1 do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do callback(mod) end
        end
    end

    local function runEffectUpdate(effect, times)
        for _ = 1, times or 1 do
            for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_EFFECT_UPDATE)) do callback(mod, effect) end
        end
    end

    local function runNewRoom()
        roomIndex = roomIndex + 1
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_NEW_ROOM)) do callback(mod) end
    end

    local function newPlayer(opts)
        opts = opts or {}
        local player = {
            Type = EntityType.ENTITY_PLAYER,
            InitSeed = opts.initSeed or (#players + 100),
            Position = opts.position or Vector(100, 100),
            Damage = opts.damage or 3.5,
            MaxFireDelay = opts.maxFireDelay or 10,
            MoveSpeed = opts.speed or 1,
            Luck = opts.luck or 0,
            hearts = opts.hearts or 6,
            maxHearts = opts.maxHearts or 6,
            soulHearts = opts.soulHearts or 0,
            collectibles = opts.collectibles or { [itemIds.GoodGirlOfBabylon] = 1 },
            cacheFlags = {},
            rngSequence = opts.rngSequence or { 0, 0, 0, 0, 0 },
            rngIndex = 0,
            PositionOffset = opts.positionOffset or Vector(0, 0),
            addedNullCostumes = {},
            removedNullCostumes = {},
        }
        function player:ToPlayer() return self end
        function player:GetCollectibleNum(itemId) return self.collectibles[itemId] or 0 end
        function player:HasCollectible(itemId) return (self.collectibles[itemId] or 0) > 0 end
        function player:GetMaxHearts() return self.maxHearts end
        function player:GetHearts() return self.hearts end
        function player:GetSoulHearts() return self.soulHearts end
        function player:AddCacheFlags(flag) self.cacheFlags[#self.cacheFlags + 1] = flag end
        function player:EvaluateItems() end
        function player:SetColor(color) self.lastColor = color end
        function player:GetFlyingOffset() return opts.flyingOffset or Vector(0, 0) end
        function player:AddNullCostume(costumeId) self.addedNullCostumes[#self.addedNullCostumes + 1] = costumeId end
        function player:TryRemoveNullCostume(costumeId) self.removedNullCostumes[#self.removedNullCostumes + 1] = costumeId end
        function player:GetCollectibleRNG()
            return {
                RandomInt = function(_, max)
                    player.rngIndex = player.rngIndex + 1
                    return (player.rngSequence[player.rngIndex] or 0) % max
                end,
            }
        end
        players[#players + 1] = player
        return player
    end

    local function newEnemy(x, y)
        local enemy = { Type = 10, Position = Vector(x or 130, y or 100), data = {}, feared = 0, charmed = 0 }
        function enemy:IsVulnerableEnemy() return true end
        function enemy:ToNPC() return self end
        function enemy:GetData() return self.data end
        function enemy:AddCharmed(_, duration) self.charmed = self.charmed + (duration or 0) end
        function enemy:AddConfusion(_, duration) self.confused = (self.confused or 0) + (duration or 0) end
        function enemy:AddFear(_, duration) self.feared = self.feared + (duration or 0) end
        roomEntities[#roomEntities + 1] = enemy
        return enemy
    end

    return {
        items = itemIds,
        spawns = spawns,
        roomEntities = roomEntities,
        newPlayer = newPlayer,
        newEnemy = newEnemy,
        runEvaluate = runEvaluate,
        runDamage = runDamage,
        runPostUpdate = runPostUpdate,
        runEffectUpdate = runEffectUpdate,
        runNewRoom = runNewRoom,
        setRoomClear = function(value) roomClear = value end,
    }
end

local function countEffectSpawns(env, variant)
    local count = 0
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_EFFECT and spawn.Variant == variant then
            count = count + 1
        end
    end
    return count
end

local function countPickupSpawns(env)
    local count = 0
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_PICKUP then
            count = count + 1
        end
    end
    return count
end

local function findEffectSpawn(env, variant)
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_EFFECT and spawn.Variant == variant then
            return spawn
        end
    end
    return nil
end

local function test_xml_registers_good_girl_and_pools()
    local items = readFile("content/items.xml")
    local pools = readFile("content/itempools.xml")
    local costumes = readFile("content/costumes2.xml")

    assertTruthy(items:find('<passive%s+name="Good Girl of Babylon".-description="Don\'t stain the dress%."', 1), "Good Girl of Babylon should be registered as passive")
    assertTruthy(pools:find('<Pool Name="angel".-<Item Name="Good Girl of Babylon" Weight="1"', 1), "Good Girl should be in angel pool")
    assertTruthy(pools:find('<Pool Name="library".-<Item Name="Good Girl of Babylon" Weight="1"', 1), "Good Girl should be in library pool")
    assertTruthy(pools:find('<Pool Name="curse".-<Item Name="Good Girl of Babylon" Weight="1"', 1), "Good Girl should be in curse pool")
    assertTruthy(costumes:find('anm2path="costume_good_girl_of_babylon%.anm2"%s+type="none"', 1), "Good Girl body visual should be registered as a null costume")
end

local function test_good_girl_effect_resources_are_registered()
    local entities = readFile("content/entities2.xml")
    local expected = {
        { variant = "3002", file = "GoodGirlHalo", anim = "Idle", loop = "true", width = "64", height = "24", pivot = "32" },
        { variant = "3003", file = "GoodGirlCharm", anim = "Charm", loop = "true", width = "32", height = "32", pivot = "16" },
        { variant = "3004", file = "GoodGirlReward", anim = "Reward", loop = "false", width = "64", height = "64", pivot = "32" },
        { variant = "3005", file = "GoodGirlBreak", anim = "Break", loop = "false", width = "96", height = "96", pivot = "48" },
        { variant = "3006", file = "GoodGirlEcho", anim = "Echo", loop = "true", width = "96", height = "96", pivot = "48" },
    }

    assertTruthy(entities:find('<entities anm2root="gfx/" version="5"', 1, true), "Good Girl effects should use the Repentance entities2 registry version")

    for _, effect in ipairs(expected) do
        local relativePath = "Effects/GoodGirlOfBabylon/" .. effect.file .. ".anm2"
        local prefixedPath = "gfx/" .. relativePath
        assertTruthy(entities:find('variant="' .. effect.variant .. '"', 1, true), effect.file .. " should reserve its effect variant")
        assertTruthy(entities:find('anm2path="' .. relativePath .. '"', 1, true), effect.file .. " should use an anm2 path relative to gfx/")
        assertTruthy(not entities:find('anm2path="' .. prefixedPath .. '"', 1, true), effect.file .. " should not double-prefix gfx in entities2.xml")

        local anm2Path = "resources/gfx/Effects/GoodGirlOfBabylon/" .. effect.file .. ".anm2"
        local anm2 = readFile(anm2Path)
        assertTruthy(anm2:find('<Spritesheet Id="0" Path="' .. effect.file .. '.png" />', 1, true), effect.file .. " should reference its spritesheet relative to the anm2 file")
        assertTruthy(anm2:find('<Animations DefaultAnimation="' .. effect.anim .. '">', 1, true), effect.file .. " should define the expected default animation")
        assertTruthy(anm2:find('<Animation Name="' .. effect.anim .. '" FrameNum=', 1, true), effect.file .. " should define its main animation")
        assertTruthy(anm2:find('Loop="' .. effect.loop .. '"', 1, true), effect.file .. " should use the expected loop setting")
        assertTruthy(anm2:find('<LayerAnimation LayerId="0" Visible="true">', 1, true), effect.file .. " should have a visible layer animation")
        assertTruthy(anm2:find('XPivot="' .. effect.pivot .. '" YPivot="' .. effect.pivot .. '" XCrop="0" YCrop="0" Width="' .. effect.width .. '" Height="' .. effect.height .. '"', 1, true), effect.file .. " should crop its first frame correctly")
        assertTruthy(not anm2:find('AlphaTint="0"', 1, true), effect.file .. " should not hide frames with zero alpha tint")
    end
end

local function test_good_girl_body_costume_uses_body_layer()
    local anm2 = readFile("resources/gfx/characters/costume_good_girl_of_babylon.anm2")

    assertTruthy(anm2:find('<Spritesheet Id="0" Path="costumes\\costume_good_girl_of_babylon.png" />', 1, true), "Good Girl costume should use the body costume spritesheet")
    assertTruthy(anm2:find('<Layer Name="body0" Id="0" SpritesheetId="0" />', 1, true), "Good Girl dress should attach to the body layer")
    assertTruthy(not anm2:find('Layer Name="head2"', 1, true), "Good Girl dress should not be attached to the head layer")
    assertTruthy(anm2:find('<Animations DefaultAnimation="WalkDown">', 1, true), "Good Girl body costume should default to a body walk animation")
    assertTruthy(anm2:find('<Animation Name="WalkDown" FrameNum="4" Loop="true">', 1, true), "Good Girl costume should define WalkDown")
    assertTruthy(anm2:find('<Animation Name="WalkRight" FrameNum="4" Loop="true">', 1, true), "Good Girl costume should define WalkRight")
    assertTruthy(anm2:find('<Animation Name="WalkUp" FrameNum="4" Loop="true">', 1, true), "Good Girl costume should define WalkUp")
    assertTruthy(anm2:find('<Animation Name="WalkLeft" FrameNum="4" Loop="true">', 1, true), "Good Girl costume should define WalkLeft")
end

local function test_good_girl_effects_spawn_from_mechanics()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6, rngSequence = { 0, 0, 0, 1 } })
    local enemy = env.newEnemy(120, 100)

    env.runPostUpdate()
    assertEquals(countEffectSpawns(env, 3002), 1, "presentable Good Girl should show the halo effect")

    env.runNewRoom()
    assertTruthy(enemy.charmed > 0, "new room should charm when the charm roll succeeds")
    assertEquals(countEffectSpawns(env, 3003), 1, "successful Good Girl charm should spawn the charm effect")

    env.setRoomClear(true)
    env.runPostUpdate()
    assertEquals(countEffectSpawns(env, 3004), 1, "successful Good Girl clear reward should spawn the reward effect")

    env.runDamage(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    assertEquals(countEffectSpawns(env, 3005), 1, "breaking Good Girl should spawn the break effect")

    env.runPostUpdate()
    assertEquals(countEffectSpawns(env, 3006), 1, "Babylon echo should spawn the echo effect while active")
end

local function test_good_girl_halo_follows_owner_position()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6, position = Vector(100, 100) })

    env.runPostUpdate()
    local halo = findEffectSpawn(env, 3002)

    assertTruthy(halo, "presentable Good Girl should spawn a halo effect")
    assertEquals(halo:GetData().NeverbirthFolkVisualEffectOwnerSeed, player.InitSeed, "halo should bind to the player that spawned it")

    player.Position = Vector(180, 140)
    env.runEffectUpdate(halo)

    assertEquals(halo.Position.X, 180, "halo should follow owner X position")
    assertEquals(halo.Position.Y, 140, "halo should follow owner ground position")
    assertEquals(halo.PositionOffset.Y, 0, "halo should leave vertical alignment to FollowParent and the anm2 pivot")
    assertEquals(halo.SpriteOffset.Y, -24, "halo should float above Isaac's head instead of sitting on the face")
    assertEquals(halo.DepthOffset, 300000, "halo should render over the player like attached halo effects")
    assertEquals(halo.Parent, player, "halo should set the player as parent")
    assertEquals(halo.followedParent, player, "halo should use engine FollowParent behavior")
end

local function test_good_girl_presentable_state_applies_body_costume()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6 })

    env.runPostUpdate()

    assertEquals(player.addedNullCostumes[1], 17494, "presentable Good Girl should apply its body costume to Isaac")

    env.runDamage(player, 1, DamageFlag.DAMAGE_RED_HEARTS)

    assertEquals(player.removedNullCostumes[#player.removedNullCostumes], 17494, "breaking Good Girl should remove the body costume")
end

local function test_good_girl_instant_effects_do_not_follow_owner()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6, rngSequence = { 0 } })
    local enemy = env.newEnemy(120, 100)

    env.runNewRoom()
    local charm = findEffectSpawn(env, 3003)

    assertTruthy(enemy.charmed > 0, "new room should charm when the charm roll succeeds")
    assertTruthy(charm, "successful charm should spawn a charm effect")
    assertEquals(charm:GetData().NeverbirthFolkVisualEffectOwnerSeed, nil, "instant charm effect should not bind to the player")
end

local function test_full_red_hearts_grant_presentable_cache_bonuses()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6 })

    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.MaxFireDelay, 9.4, "presentable state should grant +0.6 fire rate")
    assertEquals(player.Luck, 2, "presentable state should grant +2 luck")
end

local function test_missing_red_hearts_or_red_containers_disable_presentable_state()
    local env = loadNeverbirth()
    local wounded = env.newPlayer({ hearts = 4, maxHearts = 6 })
    local noContainers = env.newPlayer({ hearts = 0, maxHearts = 0 })

    env.runEvaluate(wounded, CacheFlag.CACHE_LUCK)
    env.runEvaluate(noContainers, CacheFlag.CACHE_LUCK)

    assertEquals(wounded.Luck, 0, "not-full red hearts should not grant luck")
    assertEquals(noContainers.Luck, 0, "characters without red containers should not enter presentable state")
end

local function test_red_heart_damage_breaks_state_and_starts_babylon_echo()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6 })
    local enemy = env.newEnemy(120, 100)

    env.runDamage(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)

    assertEquals(player.Luck, -2, "broken state should apply room luck penalty")
    assertEquals(player.Damage, 4.7, "Babylon echo should add damage")
    assertEquals(player.MoveSpeed, 1.15, "Babylon echo should add speed")
    assertTruthy(enemy.feared > 0, "breaking should fear nearby enemies")

    env.runPostUpdate(150)
    player.Damage = 3.5
    player.MoveSpeed = 1
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_SPEED)
    assertEquals(player.Damage, 3.5, "echo damage should expire")
    assertEquals(player.MoveSpeed, 1, "echo speed should expire")
end

local function test_soul_heart_damage_does_not_break_presentable_state()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6, soulHearts = 2 })

    env.runDamage(player, 1, 0)
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Luck, 2, "soul heart damage should not break full-red presentable state")
end

local function test_new_room_rechecks_state_after_break()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6 })

    env.runDamage(player, 1, DamageFlag.DAMAGE_RED_HEARTS)
    env.runNewRoom()
    env.runEvaluate(player, CacheFlag.CACHE_LUCK)

    assertEquals(player.Luck, 2, "new room should clear broken state and re-enter presentable state if red hearts are full")
end

local function test_clear_room_without_red_damage_can_spawn_reward()
    local env = loadNeverbirth()
    local player = env.newPlayer({ hearts = 6, maxHearts = 6, rngSequence = { 0, 0 } })

    env.setRoomClear(true)
    env.runPostUpdate()

    assertEquals(countPickupSpawns(env), 1, "clear-room reward should spawn one pickup when reward roll succeeds")
end

local function test_clear_room_reward_skips_unknown_random_cards()
    local env = loadNeverbirth({
        cardPoolSequence = { 230967295, 1 },
        cardConfigs = {
            [230967295] = { ID = 230967295, Name = "5.300.0230967295", Description = "(no description available)" },
            [1] = { ID = 1, Name = "The Fool", Description = "Defined card" },
        },
        eidDescriptions = {
            [230967295] = false,
            [1] = { Name = "The Fool", Description = "Defined card" },
        },
    })
    local player = env.newPlayer({ hearts = 6, maxHearts = 6, rngSequence = { 0, 0 } })

    env.setRoomClear(true)
    env.runPostUpdate()

    local card = nil
    for _, spawn in ipairs(env.spawns) do
        if spawn.Type == EntityType.ENTITY_PICKUP and spawn.Variant == PickupVariant.PICKUP_TAROTCARD then
            card = spawn
        end
    end
    assertTruthy(card, "clear-room reward should spawn a card")
    assertEquals(card.SubType, 1, "Good Girl card reward should reject unknown random card subtypes")
end

local function test_multi_player_states_are_independent()
    local env = loadNeverbirth()
    local first = env.newPlayer({ initSeed = 101, hearts = 6, maxHearts = 6 })
    local second = env.newPlayer({ initSeed = 202, hearts = 6, maxHearts = 6 })

    env.runDamage(first, 1, DamageFlag.DAMAGE_RED_HEARTS)
    env.runEvaluate(first, CacheFlag.CACHE_LUCK)
    env.runEvaluate(second, CacheFlag.CACHE_LUCK)

    assertEquals(first.Luck, -2, "first player should break")
    assertEquals(second.Luck, 2, "second player should remain presentable")
end

local function test_does_not_reference_original_whore_of_babylon()
    local main = readFile("main.lua")
    assertTruthy(not main:find("COLLECTIBLE_WHORE", 1, true), "Good Girl should not call original Whore of Babylon logic")
end

test_xml_registers_good_girl_and_pools()
test_good_girl_effect_resources_are_registered()
test_good_girl_body_costume_uses_body_layer()
test_good_girl_effects_spawn_from_mechanics()
test_good_girl_halo_follows_owner_position()
test_good_girl_presentable_state_applies_body_costume()
test_good_girl_instant_effects_do_not_follow_owner()
test_full_red_hearts_grant_presentable_cache_bonuses()
test_missing_red_hearts_or_red_containers_disable_presentable_state()
test_red_heart_damage_breaks_state_and_starts_babylon_echo()
test_soul_heart_damage_does_not_break_presentable_state()
test_new_room_rechecks_state_after_break()
test_clear_room_without_red_damage_can_spawn_reward()
test_clear_room_reward_skips_unknown_random_cards()
test_multi_player_states_are_independent()
test_does_not_reference_original_whore_of_babylon()

print("good girl of babylon behavior tests passed")
