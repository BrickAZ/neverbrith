-- Shared complete-entry engine double. No localization assertions run here.
local function loadNeverbirthWithEID(options)
    options = options or {}
    local callbacks = {}
    local logicalItemIds = {
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
        Condom = 746,
        UtilityKnife = 747,
        CoinSewnSword = 748,
        CoinFacedMask = 749,
        BlackTaisui = 750,
        MeatLump = 751,
        GoodGirlOfBabylon = 752,
        DebugController = 753,
        BossOrder = 754,
        StrongLaxative = 755,
        TowerOfBabel = 756,
        TheMoonIsBeautiful = 757,
        Needletick = 758,
        CrazyCoconut = 759,
        BurnAwayResentment = 760,
        Cleaver = 761,
        LittleLeatherShoes = 762,
        TrafficUnboxing = 763,
        TrafficExposure = 764,
        TrafficHeat = 765,
        CertificateOfNeverbirth = 766,
        HouseVsElephant = 769,
        Everchanging = 770,
        ProteinStrip = 771,
        EnergyKibble = 772,
        LeanCan = 773,
        DHAFishOil = 774,
        DentalChew = 775,
        LuckyLiverBites = 776,
        GoatMilkPudding = 777,
        ACEAntiCheatSystem = 778,
        YinsCurse = 779,
        BigDogBark = 780,
        WindChargeRod = 781,
        EchoShard = 782,
        ReviveMyLove = 783,
        NightOfTheCowards = 784,
        Annihilation = 785,
        KamikazeSquad = 786,
        MemoryDisorder = 787,
        RingOfSevenCurses = 788,
        AvadaKedavra = 789,
        HealthySleep = 990,
        IAmAGod = 991,
        GodComplex = 992,
        DivineLeftHand = 993,
        EchoBaby = 994,
        Blinky = 996,
        BombSuit = 995,
        DriveGlove = 997,
        Piledriver360 = 1101,
        Ultimate720 = 1102,
        MotionWave = 1103,
        DragonPunch = 1104,
        CleansedWavyCap = 767,
        FortuneRivallingHeavenGu = 768,
    }
    local defaultItemIdsByLoadedName = {}
    defaultItemIdsByLoadedName["Music Box"] = logicalItemIds.Musicbox
    defaultItemIdsByLoadedName["八音盒"] = logicalItemIds.Musicbox
    defaultItemIdsByLoadedName["Divine Left Hand, Demonic Right Hand"] = logicalItemIds.DivineLeftHand
    defaultItemIdsByLoadedName["神的左手，恶魔之右手"] = logicalItemIds.DivineLeftHand
    defaultItemIdsByLoadedName["Echo Baby"] = logicalItemIds.EchoBaby
    defaultItemIdsByLoadedName["Blinky"] = logicalItemIds.Blinky
    defaultItemIdsByLoadedName["凸眼鱼"] = logicalItemIds.Blinky
    defaultItemIdsByLoadedName["回声宝宝"] = logicalItemIds.EchoBaby
    defaultItemIdsByLoadedName["Bomb Suit"] = logicalItemIds.BombSuit
    defaultItemIdsByLoadedName["炸弹套装"] = logicalItemIds.BombSuit
    defaultItemIdsByLoadedName["Drive Glove"] = logicalItemIds.DriveGlove
    defaultItemIdsByLoadedName["斗气拳套"] = logicalItemIds.DriveGlove
    defaultItemIdsByLoadedName["360"] = logicalItemIds.Piledriver360
    defaultItemIdsByLoadedName["720"] = logicalItemIds.Ultimate720
    defaultItemIdsByLoadedName["Wave"] = logicalItemIds.MotionWave
    defaultItemIdsByLoadedName["波动"] = logicalItemIds.MotionWave
    defaultItemIdsByLoadedName["Dragon Punch"] = logicalItemIds.DragonPunch
    defaultItemIdsByLoadedName["升龙"] = logicalItemIds.DragonPunch
    defaultItemIdsByLoadedName["I Am a God"] = logicalItemIds.IAmAGod
    defaultItemIdsByLoadedName["我即神明"] = logicalItemIds.IAmAGod
    defaultItemIdsByLoadedName["God Complex"] = logicalItemIds.GodComplex
    defaultItemIdsByLoadedName["神性过载"] = logicalItemIds.GodComplex
    defaultItemIdsByLoadedName['健康睡眠'] = logicalItemIds.HealthySleep
    for name, itemId in pairs(logicalItemIds) do
        defaultItemIdsByLoadedName[name] = itemId
    end
    defaultItemIdsByLoadedName["Uncut Cord"] = logicalItemIds.UncutCord
    defaultItemIdsByLoadedName["未剪断的脐带"] = logicalItemIds.UncutCord
    defaultItemIdsByLoadedName["Shredded Tarot"] = logicalItemIds.ShreddedTarot
    defaultItemIdsByLoadedName["剪碎的塔罗"] = logicalItemIds.ShreddedTarot
    defaultItemIdsByLoadedName["Sterilization Certificate"] = logicalItemIds.SterilizationCertificate
    defaultItemIdsByLoadedName["绝育证明"] = logicalItemIds.SterilizationCertificate
    defaultItemIdsByLoadedName["Empty Cradle"] = logicalItemIds.EmptyCradle
    defaultItemIdsByLoadedName["空摇篮"] = logicalItemIds.EmptyCradle
    defaultItemIdsByLoadedName["Blood Skull Gu"] = logicalItemIds.BloodSkullGu
    defaultItemIdsByLoadedName["血颅蛊"] = logicalItemIds.BloodSkullGu
    defaultItemIdsByLoadedName["Between Death and Life"] = logicalItemIds.BetweenDeathAndLife
    defaultItemIdsByLoadedName["生死一念间"] = logicalItemIds.BetweenDeathAndLife
    defaultItemIdsByLoadedName["Condom"] = logicalItemIds.Condom
    defaultItemIdsByLoadedName["避孕套"] = logicalItemIds.Condom
    defaultItemIdsByLoadedName["Utility Knife"] = logicalItemIds.UtilityKnife
    defaultItemIdsByLoadedName["美工刀"] = logicalItemIds.UtilityKnife
    defaultItemIdsByLoadedName["Cleaver"] = logicalItemIds.Cleaver
    defaultItemIdsByLoadedName["柴刀"] = logicalItemIds.Cleaver
    defaultItemIdsByLoadedName["Coin-Sewn Sword"] = logicalItemIds.CoinSewnSword
    defaultItemIdsByLoadedName["铜钱剑"] = logicalItemIds.CoinSewnSword
    defaultItemIdsByLoadedName["Coin-Faced Mask"] = logicalItemIds.CoinFacedMask
    defaultItemIdsByLoadedName["铜钱面具"] = logicalItemIds.CoinFacedMask
    defaultItemIdsByLoadedName["Black Taisui"] = logicalItemIds.BlackTaisui
    defaultItemIdsByLoadedName["黑太岁"] = logicalItemIds.BlackTaisui
    defaultItemIdsByLoadedName["Meat Lump"] = logicalItemIds.MeatLump
    defaultItemIdsByLoadedName["肉块"] = logicalItemIds.MeatLump
    defaultItemIdsByLoadedName["Good Girl of Babylon"] = logicalItemIds.GoodGirlOfBabylon
    defaultItemIdsByLoadedName["巴比伦好女孩"] = logicalItemIds.GoodGirlOfBabylon
    defaultItemIdsByLoadedName["Debug Controller"] = logicalItemIds.DebugController
    defaultItemIdsByLoadedName["调试控制器"] = logicalItemIds.DebugController
    defaultItemIdsByLoadedName["Boss's Order"] = logicalItemIds.BossOrder
    defaultItemIdsByLoadedName["老大的指令"] = logicalItemIds.BossOrder
    defaultItemIdsByLoadedName["Strong Laxative"] = logicalItemIds.StrongLaxative
    defaultItemIdsByLoadedName["强力泻药"] = logicalItemIds.StrongLaxative
    defaultItemIdsByLoadedName["Tower of Babel"] = logicalItemIds.TowerOfBabel
    defaultItemIdsByLoadedName["通天塔"] = logicalItemIds.TowerOfBabel
    defaultItemIdsByLoadedName["The Moon Is Beautiful"] = logicalItemIds.TheMoonIsBeautiful
    defaultItemIdsByLoadedName["月色真美"] = logicalItemIds.TheMoonIsBeautiful
    defaultItemIdsByLoadedName["Burn Away the Resentment"] = logicalItemIds.BurnAwayResentment
    defaultItemIdsByLoadedName["焚尽郁结"] = logicalItemIds.BurnAwayResentment
    defaultItemIdsByLoadedName["Crazy Coconut"] = logicalItemIds.CrazyCoconut
    defaultItemIdsByLoadedName["疯狂的椰子"] = logicalItemIds.CrazyCoconut
    defaultItemIdsByLoadedName["Little Leather Shoes"] = logicalItemIds.LittleLeatherShoes
    defaultItemIdsByLoadedName["小皮鞋"] = logicalItemIds.LittleLeatherShoes
    defaultItemIdsByLoadedName["Traffic: Unboxing"] = logicalItemIds.TrafficUnboxing
    defaultItemIdsByLoadedName["流量：开箱"] = logicalItemIds.TrafficUnboxing
    defaultItemIdsByLoadedName["Traffic: Exposure"] = logicalItemIds.TrafficExposure
    defaultItemIdsByLoadedName["流量：曝光"] = logicalItemIds.TrafficExposure
    defaultItemIdsByLoadedName["Traffic: Heat"] = logicalItemIds.TrafficHeat
    defaultItemIdsByLoadedName["流量：热度"] = logicalItemIds.TrafficHeat
    defaultItemIdsByLoadedName["Certificate of Neverbirth"] = logicalItemIds.CertificateOfNeverbirth
    defaultItemIdsByLoadedName["未生证明"] = logicalItemIds.CertificateOfNeverbirth
    defaultItemIdsByLoadedName["House VS Elephant"] = logicalItemIds.HouseVsElephant
    defaultItemIdsByLoadedName["再契象"] = logicalItemIds.HouseVsElephant
    defaultItemIdsByLoadedName["Everchanging"] = logicalItemIds.Everchanging
    defaultItemIdsByLoadedName["千变万化"] = logicalItemIds.Everchanging
    defaultItemIdsByLoadedName["Protein Strip"] = logicalItemIds.ProteinStrip
    defaultItemIdsByLoadedName["高蛋白肉条"] = logicalItemIds.ProteinStrip
    defaultItemIdsByLoadedName["Energy Kibble"] = logicalItemIds.EnergyKibble
    defaultItemIdsByLoadedName["活力狗饼干"] = logicalItemIds.EnergyKibble
    defaultItemIdsByLoadedName["Lean Can"] = logicalItemIds.LeanCan
    defaultItemIdsByLoadedName["轻盈低脂罐头"] = logicalItemIds.LeanCan
    defaultItemIdsByLoadedName["DHA Fish Oil"] = logicalItemIds.DHAFishOil
    defaultItemIdsByLoadedName["DHA 鱼油"] = logicalItemIds.DHAFishOil
    defaultItemIdsByLoadedName["Dental Chew"] = logicalItemIds.DentalChew
    defaultItemIdsByLoadedName["护齿磨牙骨"] = logicalItemIds.DentalChew
    defaultItemIdsByLoadedName["Lucky Liver Bites"] = logicalItemIds.LuckyLiverBites
    defaultItemIdsByLoadedName["幸运肝粒"] = logicalItemIds.LuckyLiverBites
    defaultItemIdsByLoadedName["Goat Milk Pudding"] = logicalItemIds.GoatMilkPudding
    defaultItemIdsByLoadedName["羊奶布丁"] = logicalItemIds.GoatMilkPudding
    defaultItemIdsByLoadedName["ACE Anti-Cheat System"] = logicalItemIds.ACEAntiCheatSystem
    defaultItemIdsByLoadedName["ACE 反作弊系统"] = logicalItemIds.ACEAntiCheatSystem
    defaultItemIdsByLoadedName["Yin's Curse"] = logicalItemIds.YinsCurse
    defaultItemIdsByLoadedName["阴的诅咒"] = logicalItemIds.YinsCurse
    defaultItemIdsByLoadedName["Big Dog Bark"] = logicalItemIds.BigDogBark
    defaultItemIdsByLoadedName["大狗叫"] = logicalItemIds.BigDogBark
    defaultItemIdsByLoadedName["Wind Charge Rod"] = logicalItemIds.WindChargeRod
    defaultItemIdsByLoadedName["蓄风棒"] = logicalItemIds.WindChargeRod
    defaultItemIdsByLoadedName["Echo Shard"] = logicalItemIds.EchoShard
    defaultItemIdsByLoadedName["回响碎片"] = logicalItemIds.EchoShard
    defaultItemIdsByLoadedName["Revive My Love"] = logicalItemIds.ReviveMyLove
    defaultItemIdsByLoadedName["复活吧，我的爱人！"] = logicalItemIds.ReviveMyLove
    defaultItemIdsByLoadedName["Night of the Cowards"] = logicalItemIds.NightOfTheCowards
    defaultItemIdsByLoadedName["胆小鬼之夜"] = logicalItemIds.NightOfTheCowards
    defaultItemIdsByLoadedName["Annihilation"] = logicalItemIds.Annihilation
    defaultItemIdsByLoadedName["诛"] = logicalItemIds.Annihilation
    defaultItemIdsByLoadedName["Kamikaze Squad"] = logicalItemIds.KamikazeSquad
    defaultItemIdsByLoadedName["神风特攻队"] = logicalItemIds.KamikazeSquad
    defaultItemIdsByLoadedName["Memory Disorder"] = logicalItemIds.MemoryDisorder
    defaultItemIdsByLoadedName["记忆紊乱"] = logicalItemIds.MemoryDisorder
    defaultItemIdsByLoadedName["Ring of the Seven Curses"] = logicalItemIds.RingOfSevenCurses
    defaultItemIdsByLoadedName["七咒之戒"] = logicalItemIds.RingOfSevenCurses
    defaultItemIdsByLoadedName["Avada Kedavra"] = logicalItemIds.AvadaKedavra
    defaultItemIdsByLoadedName["阿瓦达啃大瓜"] = logicalItemIds.AvadaKedavra
    defaultItemIdsByLoadedName["Cleansed Wavy Cap"] = logicalItemIds.CleansedWavyCap
    defaultItemIdsByLoadedName["净化迷幻菇"] = logicalItemIds.CleansedWavyCap
    defaultItemIdsByLoadedName["Fortune Rivalling Heaven Gu"] = logicalItemIds.FortuneRivallingHeavenGu
    defaultItemIdsByLoadedName["鸿运齐天蛊"] = logicalItemIds.FortuneRivallingHeavenGu

    local itemIdsByLoadedName = options.itemIdsByLoadedName or defaultItemIdsByLoadedName
    local eidCalls = {}

    package.loaded.json = nil
    package.preload.json = function()
        return {
            encode = function()
                return "{}"
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
        MC_USE_PILL = 10,
        MC_POST_PEFFECT_UPDATE = 11,
        MC_POST_GAME_STARTED = 12,
        MC_PRE_GAME_EXIT = 13,
        MC_POST_PLAYER_INIT = 14,
        MC_POST_PLAYER_UPDATE = 15,
        MC_POST_EFFECT_UPDATE = 16,
        MC_POST_NPC_INIT = 17,
        MC_POST_ENTITY_REMOVE = 18,
        MC_POST_PLAYER_RENDER = 19,
        MC_POST_PICKUP_UPDATE = 35,
    }

    for index,name in ipairs({"MC_PRE_PLAYER_RENDER", "MC_POST_PLAYERHUD_RENDER_HEARTS",
        "MC_POST_TRIGGER_WEAPON_FIRED", "MC_PRE_USE_CARD", "MC_PRE_USE_PILL", "MC_PRE_TEAR_UPDATE",
        "MC_PRE_FAMILIAR_UPDATE", "MC_PRE_PICKUP_UPDATE", "MC_PRE_KNIFE_UPDATE", "MC_PRE_PROJECTILE_UPDATE",
        "MC_PRE_LASER_UPDATE", "MC_PRE_NPC_UPDATE", "MC_PRE_SLOT_UPDATE", "MC_POST_ADD_COLLECTIBLE", "MC_PRE_MOD_UNLOAD"}) do
        ModCallbacks[name]=2200+index
    end
    UseFlag = { USE_MIMIC = 1 }

    CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_PLAN_C = 475 }
    CacheFlag = {
        CACHE_DAMAGE = 1,
        CACHE_SHOTSPEED = 2,
        CACHE_TEARCOLOR = 4,
        CACHE_SPEED = 8,
        CACHE_FIREDELAY = 16,
        CACHE_TEARFLAG = 32,
        CACHE_LUCK = 1024,
    }
    DamageFlag = {
        DAMAGE_RED_HEARTS = 1,
        DAMAGE_NOKILL = 2,
        DAMAGE_INVINCIBLE = 4,
        DAMAGE_EXPLOSION = 4,
    }
    EntityFlag = { FLAG_CHARM = 1, FLAG_FRIENDLY = 2 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_NPC = 10, ENTITY_EFFECT = 1000 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_PILL = 70, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
    EntityPartition = { ENEMY = 1 }
    ItemConfig = { TAG_FOOD = 1 }
    ButtonAction = { ACTION_ITEM = 5, ACTION_PILLCARD = 6,
        ACTION_SHOOTLEFT = 14, ACTION_SHOOTRIGHT = 15, ACTION_SHOOTUP = 16, ACTION_SHOOTDOWN = 17 }
    EffectVariant = { BRIMSTONE_SWIRL = 71 }
    -- Unique fixture IDs: this suite tests localization, not native dispatch.
    for index, name in ipairs({
        "MC_PRE_PLAYER_UPDATE", "MC_INPUT_ACTION", "MC_POST_EFFECT_INIT", "MC_PRE_EFFECT_UPDATE",
        "MC_POST_LASER_INIT", "MC_POST_FIRE_BRIMSTONE", "MC_PRE_LASER_COLLISION", "MC_POST_LASER_COLLISION",
        "MC_POST_ENTITY_TAKE_DMG", "MC_PRE_PLAYER_REVIVE", "MC_EXECUTE_CMD", "MC_POST_FIRE_TEAR",
        "MC_POST_FIRE_KNIFE", "MC_POST_FIRE_BONE_CLUB", "MC_POST_FIRE_SWORD", "MC_POST_FIRE_BOMB",
        "MC_PRE_TEAR_COLLISION",
        "MC_POST_TEAR_UPDATE",
    }) do ModCallbacks[name] = 2100 + index end
    Input = { IsActionPressed = function() return false end }
    HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
    ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
    RoomType = { ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
    GameStateFlag = {
        STATE_DEVILROOM_SPAWNED = 5,
        STATE_DEVILROOM_VISITED = 6,
    }
    GridRooms = { ROOM_DEVIL_IDX = -1 }
    ActiveSlot = {
        SLOT_PRIMARY = 0,
        SLOT_SECONDARY = 1,
        SLOT_POCKET = 2,
        SLOT_POCKET2 = 3,
    }
    Card = {
        RUNE_HAGALAZ = 32,
        RUNE_BLACK = 41,
        RUNE_SHARD = 55,
        CARD_SOUL_ISAAC = 81,
        CARD_SOUL_JACOB = 97,
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
        }
    end

    Isaac = {
        GetItemIdByName = function(name)
            return itemIdsByLoadedName[name] or -1
        end,
        GetMusicIdByName = function(name)
            if name == "MusicboxTheme" then
                return 736
            end
            return -1
        end,
        DebugString = function() end,
        GetPillEffectByName = function(name)
            if name == "Wind Charge Potion" or name == "蓄风药剂" then return 920 end
            return -1
        end,
        GetEntityVariantByName = function(name)
            local variants = {
                ["Big Dog Bark Dog"] = 3017,
                ["Big Dog Bark Echo"] = 3018,
                ["Big Dog Bark Pollution"] = 3019,
            }
            return variants[name] or -1
        end,
        GetItemConfig = function()
            return { GetCollectible = function() return nil end }
        end,
        FindInRadius = function() return {} end,
        Spawn = function() return nil end,
        GetRoomEntities = function()
            return {}
        end,
        FindByType = function()
            return {}
        end,
        WorldToScreen = function(position)
            return position
        end,
        RenderText = function() end,
    }

    Color = setmetatable({}, {
        __call = function(_, r, g, b, a, ro, go, bo)
            return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo }
        end,
    })
    Color.Default = Color(1, 1, 1, 1, 0, 0, 0)

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

    function include(path)
        if options.OnInclude then options.OnInclude(path) end
        if options.OmitModule == path then return function() end end
        return dofile((options.Root or "") .. (path:gsub("%.", "/")) .. ".lua")
    end

    local mod
    function RegisterMod(name, version)
        mod = {
            Name = name,
            Version = version,
        }

        function mod:AddCallback(callbackId, fn, param)
            self:AddPriorityCallback(callbackId, 0, fn, param)
        end

        function mod:AddPriorityCallback(callbackId, priority, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = {
                fn = fn, param = param, Priority = priority,
                AddOrder = #callbacks[callbackId] + 1, Mod = self, Function = fn,
            }
            if options.AfterRegister then options.AfterRegister(self, callbackId, fn, param) end
        end

        function mod:RemoveCallback(callbackId, fn)
            local entries = callbacks[callbackId] or {}
            for index = #entries, 1, -1 do
                if entries[index].fn == fn then table.remove(entries, index) end
            end
        end

        function mod:HasData()
            return false
        end

        function mod:LoadData()
            return "{}"
        end

        function mod:SaveData() end

        if options.OnModCreated then options.OnModCreated(mod, callbacks) end
        return mod
    end

    EID = {
        _currentMod = "previous-mod",
        ModIndicator = {},
        addCollectible = function(_, id, description, itemName, language)
            eidCalls[#eidCalls + 1] = {
                id = id,
                description = description,
                itemName = itemName,
                language = language,
            }
        end,
    }

    dofile("tests/repentogon_test_fixture.lua")({ ExistingIncludeComplete = true })
    dofile((options.Root or "") .. "main.lua")
    _G.NeverbirthLocalizationTestCallbacks = callbacks

    return {
        eidCalls = eidCalls,
        itemIds = logicalItemIds,
        callbacks = callbacks,
    }
end

return loadNeverbirthWithEID
