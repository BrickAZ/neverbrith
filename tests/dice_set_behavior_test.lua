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

local function loadNeverbirth(options)
    options = options or {}
    local callbacks = {}
    local players = {}
    local itemConfigs = {}
    local savedData = options.savedData or "{}"
    local eidModifiers = {}
    local eidTransformations = {}
    local loadedSprites = {}
    local hudMessages = {}
    local sfxPlays = {}

    local itemIds = {
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        ds4 = 739,
        UncutCord = 740,
        ShreddedTarot = 741,
        SterilizationCertificate = 742,
        EmptyCradle = 743,
        BloodSkullGu = 744,
        BetweenDeathAndLife = 745,
    }

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function(value)
                savedData = value
                return "<json>"
            end,
            decode = function()
                return {}
            end,
        }
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
        MC_POST_NPC_INIT = 27,
    }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }
    CollectibleType = {
        COLLECTIBLE_NULL = 0,
        COLLECTIBLE_D6 = 105,
        COLLECTIBLE_D20 = 166,
        COLLECTIBLE_D100 = 283,
        COLLECTIBLE_D4 = 284,
        COLLECTIBLE_D10 = 285,
        COLLECTIBLE_D12 = 386,
        COLLECTIBLE_D8 = 406,
        COLLECTIBLE_D7 = 437,
        COLLECTIBLE_D1 = 476,
        COLLECTIBLE_D_INFINITY = 489,
        COLLECTIBLE_ETERNAL_D6 = 609,
        COLLECTIBLE_SPINDOWN_DICE = 723,
        COLLECTIBLE_CROOKED_PENNY = 485,
        COLLECTIBLE_GLITCHED_CROWN = 689,
        COLLECTIBLE_PLAN_C = 475,
    }
    ItemType = {
        ITEM_PASSIVE = 1,
        ITEM_TRINKET = 2,
        ITEM_ACTIVE = 3,
    }
    CacheFlag = {
        CACHE_DAMAGE = 1,
        CACHE_SHOTSPEED = 2,
        CACHE_TEARCOLOR = 4,
        CACHE_SPEED = 8,
        CACHE_FIREDELAY = 16,
        CACHE_TEARFLAG = 32,
        CACHE_RANGE = 64,
        CACHE_LUCK = 1024,
    }
    DamageFlag = { DAMAGE_RED_HEARTS = 1, DAMAGE_NOKILL = 2, DAMAGE_INVINCIBLE = 4 }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_EFFECT = 1000 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEFAULT = 1, ROOM_BOSS = 5, ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
    GameStateFlag = { STATE_DEVILROOM_SPAWNED = 5, STATE_DEVILROOM_VISITED = 6 }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    EffectVariant = { POOF01 = 15 }
    SoundEffect = { SOUND_CHOIR_UNLOCK = 23, SOUND_HOLY = 54, SOUND_POWERUP2 = 129 }
    Card = { RUNE_HAGALAZ = 32, RUNE_BLACK = 41, RUNE_SHARD = 55, CARD_SOUL_ISAAC = 81, CARD_SOUL_JACOB = 97 }

    local function addConfig(itemId, name, itemType, maxCharges)
        itemConfigs[itemId] = {
            ID = itemId,
            Name = name,
            Type = itemType,
            MaxCharges = maxCharges or 0,
        }
    end

    addConfig(CollectibleType.COLLECTIBLE_D6, "D6", ItemType.ITEM_ACTIVE, 6)
    addConfig(CollectibleType.COLLECTIBLE_D8, "D8", ItemType.ITEM_ACTIVE, 4)
    addConfig(CollectibleType.COLLECTIBLE_D7, "D7", ItemType.ITEM_ACTIVE, 3)
    addConfig(CollectibleType.COLLECTIBLE_D1, "D1", ItemType.ITEM_ACTIVE, 4)
    addConfig(CollectibleType.COLLECTIBLE_D20, "D20", ItemType.ITEM_ACTIVE, 6)
    addConfig(CollectibleType.COLLECTIBLE_D100, "D100", ItemType.ITEM_ACTIVE, 6)
    addConfig(CollectibleType.COLLECTIBLE_CROOKED_PENNY, "Crooked Penny", ItemType.ITEM_ACTIVE, 1)
    addConfig(CollectibleType.COLLECTIBLE_GLITCHED_CROWN, "Glitched Crown", ItemType.ITEM_PASSIVE, 0)
    addConfig(901, "Lucky Dice", ItemType.ITEM_ACTIVE, 4)
    addConfig(902, "Dice Charm", ItemType.ITEM_PASSIVE, 0)
    addConfig(903, "Dice Zero", ItemType.ITEM_ACTIVE, 0)
    addConfig(904, "Plain Active", ItemType.ITEM_ACTIVE, 3)
    addConfig(905, "Giant Dice", ItemType.ITEM_ACTIVE, 20)

    local room = {
        GetType = function()
            return RoomType.ROOM_DEFAULT
        end,
        IsClear = function()
            return false
        end,
        GetSpawnSeed = function()
            return 5000
        end,
        GetCenterPos = function()
            return Vector(320, 280)
        end,
        FindFreePickupSpawnPosition = function(_, position)
            return position
        end,
    }
    local level = {
        GetStage = function()
            return 1
        end,
        GetStageType = function()
            return 0
        end,
        GetCurrentRoomIndex = function()
            return 0
        end,
        AddAngelRoomChance = function() end,
        InitializeDevilAngelRoom = function() end,
    }

    function MusicManager()
        return {
            GetCurrentMusicID = function()
                return 1
            end,
            Play = function() end,
            Fadeout = function() end,
        }
    end

    function Game()
        return {
            GetSeeds = function()
                return { GetStartSeedString = function() return "TEST RUN" end }
            end,
            GetNumPlayers = function()
                return #players
            end,
            GetRoom = function()
                return room
            end,
            GetLevel = function()
                return level
            end,
            GetItemPool = function()
                return { GetCollectible = function() return CollectibleType.COLLECTIBLE_NULL end }
            end,
            GetHUD = function()
                if options.noHud then
                    return nil
                end
                return {
                    ShowItemText = function(_, title, subtitle)
                        hudMessages[#hudMessages + 1] = { title = title, subtitle = subtitle }
                    end,
                }
            end,
            Spawn = function() end,
            GetStateFlag = function()
                return false
            end,
            SetStateFlag = function() end,
        }
    end

    if not options.noSfxManager then
        function SFXManager()
            return {
                Play = function(_, soundId, volume, frameDelay, loop, pitch)
                    sfxPlays[#sfxPlays + 1] = {
                        soundId = soundId,
                        volume = volume,
                        frameDelay = frameDelay,
                        loop = loop,
                        pitch = pitch,
                    }
                end,
            }
        end
    else
        SFXManager = nil
    end

    Isaac = {
        GetItemIdByName = function(name)
            return itemIds[name] or -1
        end,
        GetMusicIdByName = function(name)
            if name == "MusicboxTheme" then
                return 736
            end
            return -1
        end,
        GetPlayer = function(index)
            return players[(index or 0) + 1]
        end,
        FindByType = function(entityType)
            if entityType == EntityType.ENTITY_PLAYER then
                return players
            end
            return {}
        end,
        GetRoomEntities = function()
            return {}
        end,
        DebugString = function() end,
        Spawn = function() end,
        GetItemConfig = function()
            return {
                GetCollectible = function(_, itemId)
                    return itemConfigs[itemId]
                end,
            }
        end,
    }

    EID = {
        player = nil,
        coopAllPlayers = players,
        Config = options.eidConfig,
        CustomTransformations = {},
        TransformationData = {},
        TransformationProgress = {},
        InlineIcons = {},
        addCollectible = function() end,
        addIcon = function(_, shortcut, animationName, animationFrame, width, height, leftOffset, topOffset, spriteObject)
            EID.InlineIcons[shortcut] = { animationName, animationFrame, width, height, leftOffset, topOffset, spriteObject }
        end,
        addDescriptionModifier = function(_, name, condition, modifier)
            eidModifiers[#eidModifiers + 1] = {
                name = name,
                condition = condition,
                modifier = modifier,
            }
        end,
        createTransformation = function(_, uniqueName, displayName, language)
            eidTransformations[uniqueName] = eidTransformations[uniqueName] or {}
            eidTransformations[uniqueName][language or "en_us"] = displayName
        end,
        createItemIconObject = function(_, markup)
            return { markup, 0, 16, 16, 0, 0 }
        end,
        getIcon = function(_, str)
            local key = tostring(str or ""):gsub("{{(.-)}}", "%1")
            return EID.InlineIcons[key] or EID.InlineIcons.ERROR or { "ERROR", 0, 10, 10 }
        end,
        getTransformationIcon = function(_, transform)
            return EID:getIcon(tostring(transform or ""):gsub(" ", ""))
        end,
        evaluateTransformationProgress = function() end,
        getTransformationName = function(_, transformId)
            local names = eidTransformations[transformId]
            return names and (names[options.eidLanguage or "en_us"] or names.en_us) or transformId
        end,
        getPlayerID = function(_, player)
            return tostring(player.InitSeed)
        end,
        getLanguage = function()
            return options.eidLanguage or "en_us"
        end,
    }

    Color = setmetatable({}, {
        __call = function(_, r, g, b, a, ro, go, bo)
            return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo }
        end,
    })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)

    function Sprite()
        local sprite = {
            loadCalls = {},
            playCalls = {},
        }
        function sprite:Load(path, loadGraphics)
            self.loadCalls[#self.loadCalls + 1] = { path = path, loadGraphics = loadGraphics }
            loadedSprites[#loadedSprites + 1] = self
        end
        function sprite:Play(animationName, force)
            self.playCalls[#self.playCalls + 1] = { animationName = animationName, force = force }
        end
        return sprite
    end

    local vectorMeta = {
        __add = function(left, right)
            return Vector(left.X + right.X, left.Y + right.Y)
        end,
    }
    function Vector(x, y)
        return setmetatable({ X = x or 0, Y = y or 0 }, vectorMeta)
    end

    function EntityRef(entity)
        return { Entity = entity }
    end

    local mod
    function RegisterMod(name, version)
        mod = { Name = name, Version = version }
        function mod:AddCallback(callbackId, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
        end
        function mod:HasData()
            return options.hasData == true
        end
        function mod:LoadData()
            return "{}"
        end
        function mod:SaveData(data)
            savedData = data
        end
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

    local function runPostAddCollectible(player, itemId, slot)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_ADD_COLLECTIBLE, itemId)) do
            callback(mod, itemId, player:GetActiveCharge(slot or ActiveSlot.SLOT_PRIMARY), true, slot or ActiveSlot.SLOT_PRIMARY, 0, player)
        end
    end

    local function runPreUse(player, itemId, slot)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_PRE_USE_ITEM, itemId)) do
            callback(mod, itemId, nil, player, 0, slot or ActiveSlot.SLOT_PRIMARY, 0)
        end
    end

    local function runUse(player, itemId, slot)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_USE_ITEM, itemId)) do
            callback(mod, itemId, nil, player, 0, slot or ActiveSlot.SLOT_PRIMARY, 0)
        end
    end

    local function runPostUpdate()
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_UPDATE)) do
            callback(mod)
        end
    end

    local function runEvaluate(player, cacheFlag)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_EVALUATE_CACHE)) do
            callback(mod, player, cacheFlag)
        end
    end

    local function runPostGameStarted(isContinued)
        for _, callback in ipairs(getCallbacks(ModCallbacks.MC_POST_GAME_STARTED)) do
            callback(mod, isContinued == true)
        end
    end

    local function makeRng(sequence)
        sequence = sequence or {}
        local index = 0
        return {
            RandomInt = function(_, max)
                index = index + 1
                local value = sequence[index]
                if value == nil then
                    value = 1
                end
                return value % max
            end,
        }
    end

    local function newPlayer(optionsForPlayer)
        optionsForPlayer = optionsForPlayer or {}
        local player = {
            InitSeed = optionsForPlayer.initSeed or (#players + 100),
            Position = Vector(100, 100),
            Damage = optionsForPlayer.damage or 5,
            MaxFireDelay = optionsForPlayer.maxFireDelay or 10,
            TearRange = optionsForPlayer.range or 260,
            activeItems = optionsForPlayer.activeItems or {},
            activeCharges = optionsForPlayer.activeCharges or {},
            rng = makeRng(optionsForPlayer.rngSequence),
            cacheFlags = {},
            evaluateCalls = 0,
            colors = {},
        }
        function player:ToPlayer()
            return self
        end
        function player:GetActiveItem(slot)
            return self.activeItems[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end
        function player:GetActiveCharge(slot)
            return self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] or 0
        end
        function player:SetActiveCharge(charge, slot)
            self.activeCharges[slot or ActiveSlot.SLOT_PRIMARY] = charge
        end
        function player:GetCollectibleRNG()
            return self.rng
        end
        function player:GetCollectibleNum()
            return 0
        end
        function player:AddCacheFlags(flags)
            self.cacheFlags[#self.cacheFlags + 1] = flags
        end
        function player:EvaluateItems()
            self.evaluateCalls = self.evaluateCalls + 1
            runEvaluate(self, CacheFlag.CACHE_DAMAGE)
            runEvaluate(self, CacheFlag.CACHE_FIREDELAY)
            runEvaluate(self, CacheFlag.CACHE_RANGE)
        end
        function player:SetColor(color, duration, priority, fadeout, share)
            self.colors[#self.colors + 1] = { color = color, duration = duration, priority = priority, fadeout = fadeout, share = share }
        end
        players[#players + 1] = player
        if not EID.player then
            EID.player = player
        end
        return player
    end

    return {
        mod = mod,
        items = itemIds,
        itemConfigs = itemConfigs,
        newPlayer = newPlayer,
        runPostAddCollectible = runPostAddCollectible,
        runPreUse = runPreUse,
        runUse = runUse,
        runPostUpdate = runPostUpdate,
        runEvaluate = runEvaluate,
        runPostGameStarted = runPostGameStarted,
        eidModifiers = eidModifiers,
        eid = EID,
        eidTransformations = eidTransformations,
        loadedSprites = loadedSprites,
        hudMessages = hudMessages,
        sfxPlays = sfxPlays,
        savedData = function()
            return savedData
        end,
    }
end

local function useDice(env, player, itemId, beforeCharge, afterCharge, slot)
    slot = slot or ActiveSlot.SLOT_PRIMARY
    player.activeItems[slot] = itemId
    player.activeCharges[slot] = beforeCharge
    env.runPreUse(player, itemId, slot)
    env.runUse(player, itemId, slot)
    player.activeCharges[slot] = afterCharge
    env.runPostUpdate()
end

local function test_original_and_heuristic_dice_detection()
    local env = loadNeverbirth()

    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_D6), true, "D6 should be a dice item")
    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_D8), true, "D8 should be a dice item")
    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_D7), true, "D7 should be a dice item")
    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_D1), true, "D1 should be a dice item")
    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_D20), true, "D20 should be a dice item")
    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_D100), true, "D100 should be a dice item")
    assertEquals(env.mod:IsDiceActiveItem(CollectibleType.COLLECTIBLE_CROOKED_PENNY), false, "Crooked Penny should not count as dice")
    assertEquals(env.mod:IsDiceActiveItem(904), false, "plain active should not count as dice")
    assertEquals(env.mod:IsDiceActiveItem(901), true, "charged active item with Dice in its name should count")
    assertEquals(env.mod:IsDiceActiveItem(902), false, "passive item with Dice in its name should not count")
    assertEquals(env.mod:IsDiceActiveItem(903), false, "zero-charge active with Dice in its name should not count")
end

local function test_collecting_or_using_three_different_dice_unlocks_set()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    useDice(env, player, CollectibleType.COLLECTIBLE_D7, 3, 0)

    assertEquals(env.mod:PlayerHasDiceSet(player), true, "three different dice should unlock Dice Set")
end

local function test_repeating_same_dice_does_not_unlock_set()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    useDice(env, player, CollectibleType.COLLECTIBLE_D6, 6, 0)
    useDice(env, player, CollectibleType.COLLECTIBLE_D6, 6, 0)

    assertEquals(env.mod:PlayerHasDiceSet(player), false, "same dice item should count only once")
end

local function test_unlocked_set_does_not_modify_active_charge()
    local env = loadNeverbirth()
    local player = env.newPlayer({ rngSequence = { 0, 0, 0, 0, 0, 0 } })

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    useDice(env, player, CollectibleType.COLLECTIBLE_D6, 6, 0)

    assertEquals(player:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "Dice Set should no longer refund or modify active charge")
end

local function test_players_track_dice_set_independently()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111, rngSequence = { 0, 0, 0, 0, 0, 0 } })
    local playerB = env.newPlayer({ initSeed = 222, rngSequence = { 0, 0, 0, 0, 0, 0 } })

    env.runPostAddCollectible(playerA, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(playerA, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(playerA, CollectibleType.COLLECTIBLE_D20)
    env.runPostAddCollectible(playerB, CollectibleType.COLLECTIBLE_D6)

    useDice(env, playerA, CollectibleType.COLLECTIBLE_D6, 6, 0)
    useDice(env, playerB, CollectibleType.COLLECTIBLE_D6, 6, 0)

    assertEquals(playerA:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "unlocked player should not refund charge")
    assertEquals(playerB:GetActiveCharge(ActiveSlot.SLOT_PRIMARY), 0, "locked player should not refund charge")
end

local function test_dice_stat_drop_is_protected_to_pre_use_value()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 5, maxFireDelay = 10, range = 260 })

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    player.activeItems[ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_D8
    player.activeCharges[ActiveSlot.SLOT_PRIMARY] = 4
    env.runPreUse(player, CollectibleType.COLLECTIBLE_D8, ActiveSlot.SLOT_PRIMARY)

    player.Damage = 2
    player.MaxFireDelay = 20
    player.TearRange = 100
    env.runUse(player, CollectibleType.COLLECTIBLE_D8, ActiveSlot.SLOT_PRIMARY)

    assertEquals(player.Damage, 5, "dice-caused damage drop should be protected")
    assertEquals(player.MaxFireDelay, 10, "dice-caused fire-rate drop should be protected")
    assertEquals(player.TearRange, 260, "dice-caused range drop should be protected")
end

local function test_dice_stat_drop_is_protected_without_pre_use_callback()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 5, maxFireDelay = 10, range = 260 })

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    player.activeItems[ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_D8
    player.activeCharges[ActiveSlot.SLOT_PRIMARY] = 4
    env.runPostUpdate()

    player.Damage = 2
    player.MaxFireDelay = 20
    player.TearRange = 100
    env.runUse(player, CollectibleType.COLLECTIBLE_D8, ActiveSlot.SLOT_PRIMARY)

    assertEquals(player.Damage, 5, "dice-caused damage drop should be protected even if pre-use did not fire")
    assertEquals(player.MaxFireDelay, 10, "dice-caused fire-rate drop should be protected even if pre-use did not fire")
    assertEquals(player.TearRange, 260, "dice-caused range drop should be protected even if pre-use did not fire")
end

local function test_dice_stat_increase_is_preserved()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 5, maxFireDelay = 10, range = 260 })

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    player.activeItems[ActiveSlot.SLOT_PRIMARY] = CollectibleType.COLLECTIBLE_D8
    player.activeCharges[ActiveSlot.SLOT_PRIMARY] = 4
    env.runPreUse(player, CollectibleType.COLLECTIBLE_D8, ActiveSlot.SLOT_PRIMARY)

    player.Damage = 7
    player.MaxFireDelay = 6
    player.TearRange = 320
    env.runUse(player, CollectibleType.COLLECTIBLE_D8, ActiveSlot.SLOT_PRIMARY)

    assertEquals(player.Damage, 7, "dice-caused damage increase should be kept")
    assertEquals(player.MaxFireDelay, 6, "dice-caused fire-rate increase should be kept")
    assertEquals(player.TearRange, 320, "dice-caused range increase should be kept")
end

local function test_non_dice_stat_drop_is_not_protected()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 2, maxFireDelay = 20, range = 100 })

    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)

    assertEquals(player.Damage, 2, "non-dice damage drop should not be changed")
    assertEquals(player.MaxFireDelay, 20, "non-dice fire-rate drop should not be changed")
    assertEquals(player.TearRange, 100, "non-dice range drop should not be changed")
end

local function test_public_registration_marks_mod_dice()
    local env = loadNeverbirth()
    env.mod:RegisterDiceItem(904, { name = "Plain Active", refundCharges = true, protectStats = true })

    assertEquals(env.mod:IsDiceActiveItem(904), true, "registered mod item should count as dice")
end

local function test_dice_set_progress_reports_seen_count_and_unlock_state()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    local count, required, unlocked = env.mod:GetDiceSetProgress(player)
    assertEquals(count, 0, "fresh player should have no dice set progress")
    assertEquals(required, 3, "Dice Set should require three dice")
    assertEquals(unlocked, false, "fresh player should not be unlocked")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    count, required, unlocked = env.mod:GetDiceSetProgress(player)
    assertEquals(count, 1, "one unique dice should show 1/3")
    assertEquals(required, 3, "required count should stay three")
    assertEquals(unlocked, false, "one dice should not unlock")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    count = env.mod:GetDiceSetProgress(player)
    assertEquals(count, 1, "repeating the same dice should not increase EID progress")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    count, required, unlocked = env.mod:GetDiceSetProgress(player)
    assertEquals(count, 3, "three unique dice should show full progress")
    assertEquals(required, 3, "required count should stay three when unlocked")
    assertEquals(unlocked, true, "three unique dice should unlock")
end

local function test_eid_modifier_formats_independent_dice_set_module_for_dice_items()
    local env = loadNeverbirth()
    local player = env.newPlayer()

    env.runPostUpdate()

    assertTruthy(env.eidModifiers[1], "Dice Set EID modifier should be registered when EID supports modifiers")
    assertEquals(env.eidModifiers[1].condition({ ObjSubType = CollectibleType.COLLECTIBLE_D6 }), true, "EID modifier should apply to dice items")
    assertEquals(env.eidModifiers[1].condition({ ObjSubType = CollectibleType.COLLECTIBLE_D7 }), true, "EID modifier should apply to D7")
    assertEquals(env.eidModifiers[1].condition({ ObjSubType = CollectibleType.COLLECTIBLE_D1 }), true, "EID modifier should apply to D1")
    assertEquals(env.eidModifiers[1].condition({ ObjSubType = 904 }), false, "EID modifier should not apply to non-dice items")

    local descObj = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D6, Description = "Base text", Player = player })
    assertTruthy(descObj.Description:find("{{neverbirthDiceSet}}", 1, true), "Dice Set module should include the custom dice set icon markup")
    assertTruthy(descObj.Description:find("Dice Set (0/3)", 1, true), "fresh player should show inactive 0/3 module title")
    assertTruthy(descObj.Description:find("{{neverbirthDiceSet}} Collect or use 3 different dice active items", 1, true), "inactive body should use a dice set icon instead of a plain bullet")
    assertTruthy(descObj.Description:find("Collect or use 3 different dice active items", 1, true), "inactive module should explain unlock condition")
    assertTruthy(descObj.Description:find("Base text", 1, true), "item's original description should remain present")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    descObj = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D8, Description = "Base text", Player = player })
    assertTruthy(descObj.Description:find("Dice Set (1/3)", 1, true), "one unique dice should show 1/3 in the module")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    descObj = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D8, Description = "Base text", Player = player })
    assertTruthy(descObj.Description:find("Dice Set (2/3)", 1, true), "two unique dice should show 2/3 in the module")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D100)
    descObj = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D8, Description = "Base text", Player = player })
    assertTruthy(descObj.Description:find("Dice Set (3/3)", 1, true), "three unique dice should show full progress in the module")
    assertEquals(descObj.Description:find("Dice Set Active", 1, true), nil, "Dice Set title should match vanilla-style progress instead of adding Active")
    assertTruthy(descObj.Description:find("{{Damage}} {{Tears}} {{Range}}", 1, true), "active module should use stat icons for protection")
    assertEquals(descObj.Description:find("{{Battery}}", 1, true), nil, "active module should not use a battery icon after charge refund removal")
    assertEquals(descObj.Description:find("each spent charge has a 50% chance", 1, true), nil, "active module should not describe charge refund after removal")
    assertTruthy(descObj.Description:find("When dice change damage, fire rate, or range, their multipliers cannot be lower than 1.0", 1, true), "active module should describe stat protection")
end

local function test_eid_modifier_uses_current_player_progress_without_cross_pollution()
    local env = loadNeverbirth()
    local playerA = env.newPlayer({ initSeed = 111 })
    local playerB = env.newPlayer({ initSeed = 222 })

    env.runPostUpdate()
    env.runPostAddCollectible(playerA, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(playerA, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(playerB, CollectibleType.COLLECTIBLE_D20)

    local descA = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D6, Description = "Base text", Player = playerA })
    local descB = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D6, Description = "Base text", Player = playerB })

    assertTruthy(descA.Description:find("Dice Set (2/3)", 1, true), "player A should see their own 2/3 progress")
    assertTruthy(descB.Description:find("Dice Set (1/3)", 1, true), "player B should see their own 1/3 progress")
end

local function test_eid_modifier_uses_native_transformation_block_when_available()
    local env = loadNeverbirth({ eidConfig = { TransformationIcons = true, TransformationText = true, TransformationProgress = true } })
    local player = env.newPlayer()

    env.runPostUpdate()

    local descObj = env.eidModifiers[1].modifier({ ObjSubType = CollectibleType.COLLECTIBLE_D6, Description = "Base text", Player = player })
    assertTruthy(tostring(descObj.Transformation):find("neverbirthDiceSet", 1, true), "native EID path should add Dice Set as a transformation block")
    assertEquals(descObj.Description:find("Dice Set (0/3)", 1, true), nil, "native EID path should not duplicate the title inside the body")
    assertTruthy(descObj.Description:find("{{neverbirthDiceSet}} Collect or use 3 different dice active items", 1, true), "native inactive body should use icon-prefixed text")
    assertTruthy(descObj.Description:find("Collect or use 3 different dice active items", 1, true), "native EID path should keep the inactive explanation")
    assertTruthy(env.eid.InlineIcons.neverbirthDiceSet, "native EID path should register the custom Dice Set icon")
    assertEquals(env.loadedSprites[1].loadCalls[1].path, "gfx/eid/DiceSetIcon.anm2", "native EID path should load the Dice Set icon anm2 from EID's lowercase icon folder")
    assertEquals(env.eid:getTransformationIcon("neverbirthDiceSet")[1], "Transformation", "native EID transformation icon should use a transformation-style animation")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.eid:evaluateTransformationProgress("neverbirthDiceSet")
    assertEquals(env.eid.TransformationProgress[tostring(player.InitSeed)].neverbirthDiceSet, 1, "native EID progress should come from Dice Set state")
    assertEquals(env.eid:getTransformationName("neverbirthDiceSet"), "Dice Set", "inactive native title should let EID append progress once")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D20)
    assertEquals(env.eid:getTransformationName("neverbirthDiceSet"), "Dice Set", "active native title should keep the vanilla-style transformation name")
end

local function test_dice_set_unlock_feedback_uses_hud_and_sound_once()
    local env = loadNeverbirth({ eidLanguage = "zh_cn" })
    local player = env.newPlayer()

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    assertEquals(#env.hudMessages, 0, "locked progress should not show unlock banner")
    assertEquals(#env.sfxPlays, 0, "locked progress should not play unlock sound")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D1)
    assertEquals(#env.hudMessages, 1, "unlock should show one HUD banner")
    assertEquals(env.hudMessages[1].title, "骰子套装", "unlock banner should use localized title")
    assertEquals(env.hudMessages[1].subtitle, "命运不再低于起点", "unlock banner should use the custom fate subtitle")
    assertEquals(#env.sfxPlays, 1, "unlock should play one sound")
    assertEquals(env.sfxPlays[1].soundId, SoundEffect.SOUND_CHOIR_UNLOCK, "unlock should prefer the choir unlock sound")

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D1)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D7)
    assertEquals(#env.hudMessages, 1, "duplicate or post-unlock dice should not repeat the banner")
    assertEquals(#env.sfxPlays, 1, "duplicate or post-unlock dice should not repeat the sound")
end

local function test_dice_set_unlock_feedback_tolerates_missing_hud_or_sound_manager()
    local env = loadNeverbirth({ noHud = true, noSfxManager = true })
    local player = env.newPlayer()

    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D6)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D8)
    env.runPostAddCollectible(player, CollectibleType.COLLECTIBLE_D1)

    assertEquals(env.mod:PlayerHasDiceSet(player), true, "missing feedback APIs should not prevent unlock")
end

test_original_and_heuristic_dice_detection()
test_collecting_or_using_three_different_dice_unlocks_set()
test_repeating_same_dice_does_not_unlock_set()
test_unlocked_set_does_not_modify_active_charge()
test_players_track_dice_set_independently()
test_dice_stat_drop_is_protected_to_pre_use_value()
test_dice_stat_drop_is_protected_without_pre_use_callback()
test_dice_stat_increase_is_preserved()
test_non_dice_stat_drop_is_not_protected()
test_public_registration_marks_mod_dice()
test_dice_set_progress_reports_seen_count_and_unlock_state()
test_eid_modifier_formats_independent_dice_set_module_for_dice_items()
test_eid_modifier_uses_current_player_progress_without_cross_pollution()
test_eid_modifier_uses_native_transformation_block_when_available()
test_dice_set_unlock_feedback_uses_hud_and_sound_once()
test_dice_set_unlock_feedback_tolerates_missing_hud_or_sound_manager()

print("dice set behavior tests passed")
