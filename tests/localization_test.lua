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

local function containsHan(text)
    return text ~= nil and text:match("[\228-\233][\128-\191][\128-\191]") ~= nil
end

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
        CleansedWavyCap = 767,
        FortuneRivallingHeavenGu = 768,
    }
    local defaultItemIdsByLoadedName = {}
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
        return dofile((path:gsub("%.", "/")) .. ".lua")
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
        end

        function mod:HasData()
            return false
        end

        function mod:LoadData()
            return "{}"
        end

        function mod:SaveData() end

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

    dofile("tests/repentogon_test_fixture.lua")()
    dofile("main.lua")
    _G.NeverbirthLocalizationTestCallbacks = callbacks

    return {
        eidCalls = eidCalls,
        itemIds = logicalItemIds,
        callbacks = callbacks,
    }
end

local expectedXmlItems = {
    HealthySleep = { enName = "Healthy Sleep", zhName = "健康睡眠", description = "Get your eight hours", zhDescription = "睡够八小时" },
    AvadaKedavra = { enName = "Avada Kedavra", zhName = "阿瓦达啃大瓜", description = "", zhDescription = "" },
    RingOfSevenCurses = {
        enName = "Ring of the Seven Curses",
        zhName = "七咒之戒",
        description = "This world isn't worth it.",
        zhDescription = "人间不值得",
    },
    MemoryDisorder = {
        enName = "Memory Disorder",
        zhName = "记忆紊乱",
        description = "Who am I?",
        zhDescription = "我是谁？",
    },
    KamikazeSquad = {
        enName = "Kamikaze Squad",
        zhName = "神风特攻队",
        description = "For victory! Give it all!",
        zhDescription = "为胜利！献身！",
    },
    Annihilation = {
        enName = "Annihilation",
        zhName = "诛",
        description = "Feel my pain!",
        zhDescription = "感受！我的痛苦！",
    },
    NightOfTheCowards = {
        enName = "Night of the Cowards",
        zhName = "胆小鬼之夜",
        description = "Everybody is a Scaredy-Shroom.",
        zhDescription = "人人都是胆小菇",
    },
    ReviveMyLove = {
        enName = "Arise, My Love!",
        zhName = "复活吧，我的爱人！",
        description = "Please open your eyes again",
        zhDescription = "请再次睁开眼睛。",
    },
    BigDogBark = {
        enName = "Big Dog Bark",
        zhName = "大狗叫",
        description = "Charge up. Let the dog loose.",
        zhDescription = "蓄力，放狗",
    },
    WindChargeRod = {
        enName = "Wind Charge Rod",
        zhName = "蓄风棒",
        description = "No windup. Strike backwards.",
        zhDescription = "即刻反向出击",
    },
    EchoShard = {
        enName = "Echo Shard",
        zhName = "回响碎片",
        description = "The dash comes back to haunt them",
        zhDescription = "冲刺后留下回响",
    },
    ProteinStrip = { enName = "Protein Strip", zhName = "高蛋白肉条", description = "A stronger bite", zhDescription = "更有力的一口" },
    EnergyKibble = { enName = "Energy Kibble", zhName = "活力狗饼干", description = "Stay lively", zhDescription = "活力满满" },
    LeanCan = { enName = "Low-Fat Chow", zhName = "轻盈低脂罐头", description = "Light on your feet", zhDescription = "身轻步快" },
    DHAFishOil = { enName = "DHA Fish Oil", zhName = "DHA 鱼油", description = "See farther", zhDescription = "看得更远" },
    DentalChew = { enName = "Dental Chew", zhName = "护齿磨牙骨", description = "Push back", zhDescription = "顶回去" },
    LuckyLiverBites = { enName = "Lucky Liver Bites", zhName = "幸运肝粒", description = "A lucky snack", zhDescription = "幸运零食" },
    GoatMilkPudding = { enName = "Goat Milk Pudding", zhName = "羊奶布丁", description = "A little comfort", zhDescription = "柔软滋养" },
    ACEAntiCheatSystem = {
        enName = "ACE Anti-Cheat System",
        zhName = "ACE 反作弊系统",
        description = "Built on 20+ years of experience",
        zhDescription = "基于20+年的经验沉淀",
    },
    YinsCurse = {
        enName = "Yin's Curse",
        zhName = "阴的诅咒",
        description = "Darkness suppresses the curse",
        zhDescription = "唯有黑暗能压制诅咒",
    },
    Everchanging = {
        enName = "Everchanging",
        zhName = "千变万化",
        description = "A different look for this run",
        zhDescription = "本局换个模样",
    },
    HouseVsElephant = {
        enName = "House VS Elephant",
        zhName = "再契象",
        description = "Who's up for a frantic round of House VS Elephant?",
        zhDescription = "谁不想急头白脸来一把房子VS大象呢？",
    },
    CertificateOfNeverbirth = {
        enName = "Certificate of Neverbirth",
        zhName = "未生证明",
        description = "Enter the Neverbirth gallery",
        zhDescription = "进入未生陈列室",
    },
    LittleLeatherShoes = {
        enName = "Little Leather Shoes",
        zhName = "小皮鞋",
        description = "Meowmermermer",
        zhDescription = "咪mermermer",
    },
    TrafficUnboxing = {
        enName = "Traffic: Unboxing",
        zhName = "流量：开箱",
        description = "A promising debut",
        zhDescription = "初露锋芒",
    },
    TrafficExposure = {
        enName = "Traffic: Exposure",
        zhName = "流量：曝光",
        description = "More eyes are on you",
        zhDescription = "更多人看见了你",
    },
    TrafficHeat = {
        enName = "Traffic: Heat",
        zhName = "流量：热度",
        description = "Are you sure this is what you want?",
        zhDescription = "你确定这是你想要的吗？",
    },
    CleansedWavyCap = {
        enName = "Cleansed Wavy Cap",
        zhName = "净化迷幻菇",
        description = "A trip without the side effects",
        zhDescription = "被净化的迷幻蘑菇。",
    },
    FortuneRivallingHeavenGu = {
        enName = "Fortune Rivalling Heaven Gu",
        zhName = "鸿运齐天蛊",
        description = "The world bends your way.",
        zhDescription = "天命所归。",
    },
    EssentialBalm = {
        enName = "Essential Balm",
        zhName = "风油精",
        description = "Use with caution under age three",
        zhDescription = "3岁以下儿童慎用",
    },
    Wuhu = {
        enName = "Wuhu!",
        zhName = "芜湖！~",
        description = "Dark wind, wild flight",
        zhDescription = "黑风吹过呜呼起飞",
    },
    Aphrodisiac = {
        enName = "Aphrodisiac",
        zhName = "春药",
        description = "Heat of the moment",
        zhDescription = "性奋",
    },
    Musicbox = {
        enName = "Music Box",
        zhName = "八音盒",
        description = "Your life, on a timer",
        zhDescription = "为你的生命倒计时",
    },
    Angelbox = {
        enName = "Angel Box",
        zhName = "天使盒",
        description = "Full hearts, heavenbound",
        zhDescription = "盈魂引向天国",
    },
    Devilbox = {
        enName = "Devil Box",
        zhName = "恶魔盒",
        description = "Black hearts, hellbound",
        zhDescription = "暗血引向深渊",
    },
    ds4 = {
        enName = "ds4",
        zhName = "ds4",
        description = "",
        zhDescription = "",
    },
    UncutCord = {
        enName = "Uncut Cord",
        zhName = "未剪断的脐带",
        description = "Half now, half later",
        zhDescription = "一半现在，一半以后",
    },
    ShreddedTarot = {
        enName = "Shredded Tarot",
        zhName = "剪碎的塔罗",
        description = "Cut the deck",
        zhDescription = "把命运剪碎",
    },
    SterilizationCertificate = {
        enName = "Sterilization Certificate",
        zhName = "绝育证明",
        description = "No more births",
        zhDescription = "不许再生",
    },
    EmptyCradle = {
        enName = "Empty Cradle",
        zhName = "空摇篮",
        description = "Scars remember",
        zhDescription = "伤痕会回应",
    },
    BloodSkullGu = {
        enName = "Blood Skull Gu",
        zhName = "血颅蛊",
        description = "Slaughter your kin. Refine your potential.",
        zhDescription = "杀亲证道，提纯资质。",
    },
    BossOrder = {
        enName = "Boss's Order",
        zhName = "老大的指令",
        description = "Buddy, I'm coming for you!",
        zhDescription = "兄弟，想抓杀你",
    },
    BetweenDeathAndLife = {
        enName = "Between Life and Death",
        zhName = "生死一念间",
        description = "Let every life bear witness",
        zhDescription = "众生皆证。",
    },
    Condom = {
        enName = "Condom",
        zhName = "避孕套",
        description = "She said it doesn't count with one on",
        zhDescription = "她说戴了不算给",
    },
    UtilityKnife = {
        enName = "Utility Knife",
        zhName = "美工刀",
        description = "Painful scars",
        zhDescription = "苦痛伤痕",
    },
    Cleaver = {
        enName = "Cleaver",
        zhName = "柴刀",
        description = "Tears become cleaver swings",
        zhDescription = "眼泪替换为柴刀挥砍",
    },
    CoinSewnSword = {
        enName = "Coin-Sewn Sword",
        zhName = "铜钱剑",
        description = "An offering and a blade",
        zhDescription = "钱是香火，也是剑刃。",
    },
    CoinFacedMask = {
        enName = "Coin-Faced Mask",
        zhName = "铜钱面具",
        description = "Buy yourself another face",
        zhDescription = "买一张脸。",
    },
    BlackTaisui = {
        enName = "Black Taisui",
        zhName = "黑太岁",
        description = "It feeds on blood. You see the truth.",
        zhDescription = "以血为食，替你看清世界。",
    },
    MeatLump = {
        enName = "Meat Lump",
        zhName = "肉块",
        description = "One more bite",
        zhDescription = "再活一口",
    },
    GoodGirlOfBabylon = {
        enName = "Good Girl of Babylon",
        zhName = "巴比伦好女孩",
        description = "Don't stain the dress",
        zhDescription = "别弄脏裙子。",
    },
    DebugController = {
        enName = "Debug Controller",
        zhName = "调试控制器",
        description = "Debug command menu",
        zhDescription = "调试命令菜单",
    },
    StrongLaxative = {
        enName = "Strong Laxative",
        zhName = "强力泻药",
        description = "A thousand-mile purge",
        zhDescription = "一泻千里",
    },
    TowerOfBabel = {
        enName = "Tower of Babel",
        zhName = "通天塔",
        description = "No more floods",
        zhDescription = "不再有洪水。",
    },
    TheMoonIsBeautiful = {
        enName = "The Moon Is Beautiful",
        zhName = "月色真美",
        description = "Say it to me",
        zhDescription = "请这样对我说。",
    },
    BurnAwayResentment = {
        enName = "Burn Away the Resentment",
        zhName = "焚尽郁结",
        description = "I've never felt so refreshed.",
        zhDescription = "我从未如此神清气爽过。",
    },
    Needletick = {
        enName = "Void Needle",
        zhName = "虚空针尖",
        description = "Next time, spit in the trash...",
        zhDescription = "下次请吐在垃圾桶里……",
    },
    CrazyCoconut = {
        enName = "Crazy Coconut",
        zhName = "疯狂的椰子",
        description = "King of the Hollow Earth",
        zhDescription = "空心地球之王",
    },
}

local expectedEID = {
    HealthySleep = {
        en_us = { name = "Healthy Sleep", description = "Spawns a bed in the starting room once per floor#A full night's sleep takes 8 hours of real time; progress stops while paused or out of the game#Hold a gameplay input for 15 frames to speed up sleep#Hold different inputs together for a greater speedup, with diminishing returns#While asleep, inputs only help you wake up sooner#Finishing sleep fully restores red hearts, then grants 3 soul hearts" },
        zh_cn = { name = "健康睡眠", description = "每层初始房间生成一张原版床，每层仅一次#睡眠进度需要现实时间8小时，暂停和退出时停止计时#持续按住游戏操作15帧后加速；不同操作可叠加，遵循平方根递减收益#睡眠中操作仅用于催醒#睡满后先补满红心，再获得3颗魂心" },
    },
    AvadaKedavra = {
        en_us = { name = "Avada Kedavra", description = "Replaces your weapon with Anti-Gravity Brimstone#While enemies remain, hold fire for 1 second, then release to cast#{{Damage}} Damage x5#Fire rate does not affect charge time#At full charge, keep holding to wait or adjust your aim; releasing early cancels the cast#{{Warning}} If a completed cast directly kills no enemies, you die and cannot revive from that death#In co-op, only the caster dies" },
        zh_cn = { name = "阿瓦达啃大瓜", description = "攻击替换为原版反重力硫磺火#有敌人时按住射击蓄力1秒，蓄满后松键施法#面板攻击力翻5倍；蓄力不受射速影响#蓄满可持续按住并调整方向；未蓄满松键取消#一次攻击完全结束后若未直接击杀敌人，施法者死亡且本次无法复活#合作模式只杀死施法者" },
    },
    RingOfSevenCurses = {
        en_us = {
            name = "Ring of the Seven Curses",
            description = "Permanently occupies your primary active slot for the rest of the run#Forces the Curses of Darkness, the Lost, the Unknown, and the Maze#Disables trinkets and flight; prevents sleeping in beds except Mom's Bed#{{Damage}} Damage x0.75#{{Tears}} Fire rate x0.75#{{Shotspeed}} Shot speed x1.25#{{Luck}} -5 luck#Doubles enemy health and the damage you take#Caps health at 6 hearts, keys at 2, bombs at 1, and coins at 20#Every 2 rooms, adds 1 charge to your character's built-in secondary active, if retained#Quality 4 and modded items cannot be picked up; an item you can pick up spawns beside each one#Rerolling a blocked item checks it again; active items dropped when equipping the ring do not grant replacements#Taking an item that costs hearts also adds 1 broken heart",
        },
        zh_cn = {
            name = "七咒之戒",
            description = "本局永久绑定主手主动栏#强制黑暗、迷失、未知、迷宫诅咒；禁用饰品栏与飞行#无法使用床，妈妈的床除外#{{Damage}}攻击力变为75%#{{Tears}}射击频率变为75%#{{Shotspeed}}弹速变为125%#{{Luck}}幸运-5#敌人生命与自身受到伤害翻倍#上限：6颗心、2钥匙、1炸弹、20硬币#每过2个房间，为保留的角色原生副手主动充能1格#品质4与模组道具保留但无法拾取，旁边生成1件可拾取道具#原底座重骰后重新判定；换下的原有主动不参与补偿#交易道具额外增加1颗碎心",
        },
    },
    MemoryDisorder = {
        en_us = {
            name = "Memory Disorder",
            description = "Starting with the next room, entering a room turns you into a random unlocked character#Temporarily grants that character's starting items and abilities while preserving your existing build#Losing this item restores your original character#Once picked up, guarantees a Void portal after eligible endgame encounters for the rest of the run: Boss Rush, Hush, Mega Satan, and the final Greed Mode boss room",
        },
        zh_cn = {
            name = "记忆紊乱",
            description = "从下次进房开始，每次进房都会随机变为一名已解锁角色#角色初始组件随身份临时替换；正常构筑永久保留#失去本道具会恢复原始身份#本局曾拾取后，原版有效终局节点必定提供虚空入口",
        },
    },
    KamikazeSquad = {
        en_us = {
            name = "Kamikaze Squad",
            description = "While enemies remain, spawns a friendly Mulliboom near you every 3 seconds#Up to 2 per player at a time#They chase the nearest enemy and explode on contact#Explosions deal normal Mulliboom damage with twice the radius#Clearing the room makes all remaining squad members explode",
        },
        zh_cn = {
            name = "神风特攻队",
            description = "房间内有敌人时，每3秒在身边召唤1只友好炸弹棉花怪#每名玩家最多同时存在2只#追逐最近敌人，接触后自爆#爆炸伤害与原版相同，范围翻倍#清房时剩余成员立即自爆",
        },
    },
    Annihilation = {
        en_us = {
            name = "Annihilation",
            description = "For 5 seconds, emit a damaging aura and replace your tears with radial shockwaves#The aura deals 40% of your current damage every 4 frames#Each shockwave deals 100% of your current damage#{{Range}} Range x0.45#{{Tears}} Fire rate x0.60#Each enemy death extends the effect by 0.3 seconds#{{Collectible356}} Car Battery: each hit during the effect adds 1 charge to both your primary and secondary active items",
        },
        zh_cn = {
            name = "诛",
            description = "持续5秒：每4帧以光环造成当前攻击力40%的伤害#泪弹替换为环形冲击波，造成当前攻击力100%的伤害#{{Range}}射程变为45%#{{Tears}}射击频率变为60%#敌人死亡会延长0.3秒#{{Collectible356}}车载电池：诛状态期间每次命中为主手和副手主动道具各充能1格",
        },
    },
    NightOfTheCowards = {
        en_us = {
            name = "Night of the Cowards",
            description = "Grants {{Collectible20}} Transcendence#Turns normal enemies into Hosts, Red Hosts, or Hard Hosts#All enemies emit a small fear aura#You cannot shoot while inside an aura; {{Fear}} Fear appears above you",
        },
        zh_cn = {
            name = "胆小鬼之夜",
            description = "获得{{Collectible20}}超凡升天#普通敌人会变为Host、红Host或硬Host#所有敌人脚下产生小型恐惧光环#进入光环会显示{{Fear}}恐惧且无法射击",
        },
    },
    ReviveMyLove = {
        en_us = {
            name = "Arise, My Love!",
            description = "If no other revival is waiting to trigger, your first death this run plays its full animation#After the death and revival animations, revives you in the same room with {{Heart}} 1 full red heart and brief invincibility#Consumes 1 copy without removing your other revival items",
        },
        zh_cn = {
            name = "复活吧，我的爱人！",
            description = "没有其他复活待结算时，本局首次真正死亡会完整播放死亡过程#死亡动画与复活动画结束后，在当前房间以{{Heart}}1颗完整红心复活，并获得短暂无敌#消耗1份本道具；不会移除其他复活来源",
        },
    },
    BigDogBark = {
        en_us = {
            name = "Big Dog Bark",
            description = "Hold the active item button until fully charged, then release to send the dog dashing in your movement direction#While standing still, uses your last movement direction#Releasing before full charge cancels the attack#Higher fire rate shortens the charge time#Dash damage: 5 + 5% of the enemy's max HP + 20% of your damage#After you pick up 4 food items this run, the dog also chews enemies automatically for 10% of their max HP",
        },
        zh_cn = {
            name = "大狗叫",
            description = "长按主动键蓄满后松开，沿移动方向放狗#未蓄满时松开会取消攻击#蓄力时间随射速缩短#冲刺伤害：5+目标最大生命值5%+攻击力20%#本局实际拾取4个食物标签道具后，自动咀嚼敌人并造成其最大生命值10%伤害",
        },
    },
    WindChargeRod = {
        en_us = { name = "Wind Charge Rod", description = "Big Dog Bark no longer needs to charge#Press the active item button to send the dog dashing opposite your movement direction#While standing still, uses the opposite of your last movement direction" },
        zh_cn = { name = "蓄风棒", description = "大狗叫无需蓄力，按下即沿移动方向反向发射" },
    },
    EchoShard = {
        en_us = { name = "Echo Shard", description = "Big Dog Bark's dash and echo leave creep that slows enemies and deals 1% of your damage every frame#After the dash, an echo retraces its path and deals 50% of the original dash's damage" },
        zh_cn = { name = "回响碎片", description = "大狗本体冲刺与回响都会留下减速水迹，每帧造成攻击力1%伤害#冲刺结束后回响重走原路径，并造成冲刺伤害的50%" },
    },
    ProteinStrip = {
        en_us = { name = "Protein Strip", description = "{{Heart}} +1 heart container#Fully restores red hearts#{{Damage}} +0.15 damage" },
        zh_cn = { name = "高蛋白肉条", description = "{{Heart}} +1红心上限并补满所有红心#{{Damage}} +0.15攻击" },
    },
    EnergyKibble = {
        en_us = { name = "Energy Kibble", description = "{{Heart}} +1 heart container#Fully restores red hearts#{{Tears}} +0.15 fire rate" },
        zh_cn = { name = "活力狗饼干", description = "{{Heart}} +1红心上限并补满所有红心#{{Tears}} +0.15射速" },
    },
    LeanCan = {
        en_us = { name = "Low-Fat Chow", description = "{{Heart}} +1 heart container#Fully restores red hearts#{{Speed}} +0.10 speed" },
        zh_cn = { name = "轻盈低脂罐头", description = "{{Heart}} +1红心上限并补满所有红心#{{Speed}} +0.10移速" },
    },
    DHAFishOil = {
        en_us = { name = "DHA Fish Oil", description = "{{Heart}} +1 heart container#Fully restores red hearts#{{Range}} +0.40 range" },
        zh_cn = { name = "DHA 鱼油", description = "{{Heart}} +1红心上限并补满所有红心#{{Range}} +0.40射程" },
    },
    DentalChew = {
        en_us = { name = "Dental Chew", description = "{{Heart}} +1 heart container#Fully restores red hearts#Your tears push normal, movable enemies in the tear's direction#Each copy adds 1.25 push strength, up to an enemy speed of 4.5#Each player can push the same enemy once every 8 frames" },
        zh_cn = { name = "护齿磨牙骨", description = "{{Heart}} +1红心上限并补满所有红心#自身泪弹会沿飞行方向轻推普通可移动敌人#每份推力1.25；速度上限4.5；同一敌人与玩家冷却8帧" },
    },
    LuckyLiverBites = {
        en_us = { name = "Lucky Liver Bites", description = "{{Heart}} +1 heart container#Fully restores red hearts#{{Luck}} +0.25 luck" },
        zh_cn = { name = "幸运肝粒", description = "{{Heart}} +1红心上限并补满所有红心#{{Luck}} +0.25幸运" },
    },
    GoatMilkPudding = {
        en_us = { name = "Goat Milk Pudding", description = "{{Heart}} +1 heart container#Fully restores red hearts#{{SoulHeart}} +0.5 soul heart" },
        zh_cn = { name = "羊奶布丁", description = "{{Heart}} +1红心上限并补满所有红心#{{SoulHeart}} +0.5魂心" },
    },
    ACEAntiCheatSystem = {
        en_us = {
            name = "ACE Anti-Cheat System",
            description = "Doubles the damage you take#Killing a normal enemy in one hit causes severe room slowdown and 3 FPS-style stuttering for 5 seconds#{{Warning}} Killing 3 normal enemies in one hit each in the same room kills the entire team",
        },
        zh_cn = {
            name = "ACE 反作弊系统",
            description = "受到的伤害翻倍#一击击杀普通敌人：全房间严重减速并呈现低帧卡顿，持续5秒#同一房间内一击击杀3个普通敌人：全队立即死亡",
        },
    },
    YinsCurse = {
        en_us = {
            name = "Yin's Curse",
            description = "The first quality 4 item is replaced by {{Collectible149}} Ipecac#If you held {{Collectible260}} Black Candle when you picked up Yin's Curse, Ipecac spawns beside that item instead#Existing explosion immunity still works; Black Candle does not grant explosion immunity",
        },
        zh_cn = {
            name = "阴的诅咒",
            description = "首个品质4道具会被{{Collectible149}}吐根酊取代#若拾取时持有黑蜡烛，则改为在其旁额外生成吐根酊#已有防爆效果目前仍会生效；{{Collectible260}}黑蜡烛本身不提供防爆",
        },
    },
    Everchanging = {
        en_us = {
            name = "Everchanging",
            description = "Gives you a random appearance for the run that takes priority over ordinary costumes#Additional copies choose a different appearance when possible#Unsupported characters keep their normal appearance",
        },
        zh_cn = {
            name = "千变万化",
            description = "本局获得一套确定性的高优先级外观样式#重复获得时，在可行情况下重抽不同样式#不兼容的角色骨架保留道具但不改变外观",
        },
    },
    HouseVsElephant = {
        en_us = {
            name = "House VS Elephant",
            description = "Single-use active item; no charge required#Enter a gallery of passive and familiar items seen on pedestals this run that nobody on the team currently holds#Separate pedestals of the same item appear as separate choices#The team may take 3 items in total; taking the third returns everyone automatically#Use the previous page, next page, and return controls to browse or leave early#If fewer than 3 choices are available, fills the remaining slots with {{Collectible25}} Breakfast",
        },
        zh_cn = {
            name = "再契象",
            description = "一次性主动道具，无需充能#进入分页特殊房，陈列本局见过且当前全队无人持有的被动或跟班道具底座#同一道具的不同底座实例会重复出现#全队合计拿取3件，第三件会自动送全队返回#使用上一页、返回、下一页机关浏览或提前离开#候选不足3件时用{{Collectible25}}牛奶补足",
        },
    },
    CleansedWavyCap = {
        en_us = {
            name = "Cleansed Wavy Cap",
            description = "Wavy Cap purified by Black Taisui#Each use: {{Speed}} -0.03 speed and {{Tears}} -0.75 tear delay (faster firing)#Leaving the room doubles the speed penalty accumulated there and keeps 40% of its tear-delay reduction#Clearing a room removes one use's worth of these lingering effects",
        },
        zh_cn = {
            name = "净化迷幻菇",
            description = "被黑太岁净化的迷幻蘑菇#使用后：{{Speed}} -0.03移速，{{Tears}} 射击间隔-0.75#离开房间时，本房间增减益转化：移速减益x2，射击间隔减免x0.4#清理房间后，移除相当于1次使用的残留增减益",
        },
    },
    FortuneRivallingHeavenGu = {
        en_us = {
            name = "Fortune Rivalling Heaven Gu",
            description = "{{Luck}} Raises luck to the highest activation threshold among your supported items and trinkets#Only effects with a registered luck threshold are supported#Eligible room-clear, boss, chest, beggar, and machine rewards have a 10% chance to pay out a second time#Item pedestals have a 1% chance to spawn an extra item from the same pool#Coins have a 5% chance to spawn an extra Lucky Penny",
        },
        zh_cn = {
            name = "鸿运齐天蛊",
            description = "{{Luck}} 将幸运补足至所持已登记道具中的最高阈值#合法奖励事件有10%概率额外结算一次#每个道具底座有1%概率从同一池额外生成一个道具底座#每枚硬币有5%概率额外生成一枚幸运硬币",
        },
    },
    CertificateOfNeverbirth = {
        en_us = {
            name = "Certificate of Neverbirth",
            description = "Reusable debug active item; no charge required#Enter a gallery of all collectibles registered by neverbrith#Take as many items as you like; switching pages resets the items on that page#Use the return control to leave",
        },
        zh_cn = {
            name = "未生证明",
            description = "无需充能且不会消失的调试主动道具#进入分页陈列全部neverbrith注册收藏品的未生陈列室#可拿取任意数量道具；每次切页都会完整重建该页#只有使用返回机关才会离开陈列室",
        },
    },
    LittleLeatherShoes = {
        en_us = {
            name = "Little Leather Shoes",
            description = "Normal enemies can return after death: a 33% chance the first time, then 22%, then 11%#Earn Traffic, representing audience attention, when you clear a room#Traffic gained equals the highest death count in a chain of returning enemies in that room#Reach 6, 8, or 12 Traffic to unlock rewards when you clear the floor's boss room#At 12 Traffic, choose between Exposure and Heat#Traffic is settled and reset each floor",
        },
        zh_cn = {
            name = "小皮鞋",
            description = "普通敌人死亡后可依次以33%、22%、11%概率返回#清房时，按本房有效敌人链中最高死亡次数获得流量#6、8、12点流量解锁Boss结算奖励#12点奖励中的曝光与热度二选一#流量每层检查并重置",
        },
    },
    TrafficUnboxing = {
        en_us = {
            name = "Traffic: Unboxing",
            description = "Spawns 1 normal chest after the pickup animation#Does not appear in item pools",
        },
        zh_cn = {
            name = "流量：开箱",
            description = "拾取动画结束后生成1个普通宝箱#不会出现在道具池中",
        },
    },
    TrafficExposure = {
        en_us = {
            name = "Traffic: Exposure",
            description = "Spawns 1 collectible from the current room's item pool",
        },
        zh_cn = {
            name = "流量：曝光",
            description = "拾取时从当前房间对应道具池生成1个道具",
        },
    },
    TrafficHeat = {
        en_us = {
            name = "Traffic: Heat",
            description = "{{Tears}} +0.5 tears per second",
        },
        zh_cn = {
            name = "流量：热度",
            description = "{{Tears}} 永久+0.5射速",
        },
    },
    EssentialBalm = {
        en_us = {
            name = "Essential Balm",
            description = "{{Damage}} +1 damage#{{Shotspeed}} -0.2 shot speed",
        },
        zh_cn = {
            name = "风油精",
            description = "↑ +1攻击力#↓ -0.2弹速",
        },
    },
    Wuhu = {
        en_us = {
            name = "Wuhu!",
            description = "{{Speed}} +1 speed#{{Tears}} Sets fire rate to 30 tears per second#{{Damage}} +40 damage#{{Shotspeed}} -1 shot speed",
        },
        zh_cn = {
            name = "芜湖！~",
            description = "↑ +1移速#↑ 攻速上限达到30#↑ +40攻击力#↓ -1弹速",
        },
    },
    Aphrodisiac = {
        en_us = {
            name = "Aphrodisiac",
            description = "1-charge active item#Take damage with a base cost of half a heart; red hearts are used first#{{Warning}} This damage cannot kill you#For 3 seconds:#{{Damage}} +0.5 damage#{{Tears}} -0.5 tear delay (faster firing)#Charm effect and homing tears",
        },
        zh_cn = {
            name = "春药",
            description = "1充能主动道具#使用后受到基础半颗心伤害#{{Warning}} 优先扣红心#{{Warning}} 不致死#{{Damage}} +0.5攻击力#{{Tears}} 射击间隔-0.5#角色进入魅惑状态#眼泪获得追踪效果#持续3秒",
        },
    },
    Musicbox = {
        en_us = {
            name = "Music Box",
            description = "12-charge active item#Grants 20 seconds of invincibility, turns your tears red, and plays music#{{Warning}} You die when the timer ends#Using it again does not extend the timer#At 0 charge, a lethal enemy hit consumes Music Box and activates it once#While active, Plan C still damages enemies but does not kill you#You need an extra life to survive the final death",
        },
        zh_cn = {
            name = "八音盒",
            description = "12充能主动道具#使用后进入20秒无敌状态，眼泪变红并播放八音盒音乐#{{Warning}} 倒计时结束时强制死亡#第二次使用不会延长倒计时#未充能且受到致死敌人伤害时，失去八音盒并自动触发一次#八音盒期间压制计划C的自杀死亡，但保留杀敌伤害#只有额外生命可以继续游戏",
        },
    },
    Angelbox = {
        en_us = {
            name = "Angel Box",
            description = "{{Luck}} +3 luck while held#4-charge active item#Each player's first use spawns 1 full soul heart per red heart container#After that, absorbs only soul hearts you cannot hold; 4 charges are needed per use#Later uses at full charge attempt to open an Angel Room on the current floor#If you have not entered an Angel Room this floor, the first one also contains 1 quality-4 Angel Room item#Heart pickups have a 60% chance to spawn 1 extra full soul heart#While held, converts half of your Devil Deal chance into Angel Room chance",
        },
        zh_cn = {
            name = "天使盒",
            description = "持有时 {{Luck}} +3 幸运#4充能主动道具#每名玩家首次使用：每个红心容器生成1个完整魂心#之后只吸收装不下的魂心充能，满4格可再次使用#非首次满充能使用：本层尽力开启天使房#若本层尚未进入过天使房，首次进入时额外生成1个4级天使房道具#地上心掉落有60%概率额外生成1个完整魂心#持有时50%恶魔房概率转为天使房概率",
        },
    },
    Devilbox = {
        en_us = {
            name = "Devil Box",
            description = "4-charge active item#Each player's first use spawns 1 full black heart per red heart container#After that, absorbs only black hearts you cannot hold; 4 charges are needed per use#Later uses at full charge attempt to open a Devil Room on the current floor#If you have not entered a Devil Room this floor, the first one also contains 1 quality-3 Devil Room item#Heart pickups have an 80% chance to spawn 1 extra black heart#While held, converts half of your Angel Room chance into Devil Deal chance",
        },
        zh_cn = {
            name = "恶魔盒",
            description = "4充能主动道具#每名玩家首次使用：每个红心容器生成1个完整黑心#之后只吸收装不下的黑心充能，满4格可再次使用#非首次满充能使用：本层尽力开启恶魔房#若本层尚未进入过恶魔房，首次进入时额外生成1个3级恶魔房道具#地上心掉落有80%概率额外生成1个黑心#持有时50%天使房概率转为恶魔房概率",
        },
    },
    ds4 = {
        en_us = {
            name = "ds4",
            description = "{{Warning}} Effect not implemented yet",
        },
        zh_cn = {
            name = "ds4",
            description = "{{Warning}} 效果尚未实现",
        },
    },
    UncutCord = {
        en_us = {
            name = "Uncut Cord",
            description = "50% chance to delay incoming damage#Clear 2 enemy rooms without taking another hit to pay only half of the delayed damage, with a minimum of half a heart#Taking another hit makes you pay the full delayed damage immediately",
        },
        zh_cn = {
            name = "未剪断的脐带",
            description = "受到伤害时，50%概率将本次伤害变为延迟伤害#连续通过2个房间且未再次受伤后，只承受一半延迟伤害#若期间再次受伤，立即承受全部延迟伤害",
        },
    },
    ShreddedTarot = {
        en_us = {
            name = "Shredded Tarot",
            description = "{{Luck}} +3 luck while held#Single-use active item#Removes card pickups from the current room#Every 3 cards removed spawn 1 Treasure Room item#Fewer than 3 cards: no effect and no item consumed#Disappears at the end of the floor if unused",
        },
        zh_cn = {
            name = "剪碎的塔罗",
            description = "持有时 {{Luck}} +3 幸运#一次性使用#移除当前房间内的地上卡牌#每移除3张卡牌，生成1个宝箱房道具#卡牌不足3张时不会消耗#空拍不算使用，本层结束仍会消失",
        },
    },
    BloodSkullGu = {
        en_us = {
            name = "Blood Skull Gu",
            description = "3-charge active item#Sacrifices 1 familiar collectible you own#{{Damage}} +1.5 permanent damage#{{Range}} +1 permanent range#Drops 1-2 black hearts#If you have no familiar collectible to sacrifice, takes half a red heart of damage instead",
        },
        zh_cn = {
            name = "血颅蛊",
            description = "3充能主动道具#献祭1个属于你的跟班类道具#{{Damage}} 永久 +1.5 攻击#{{Range}} 永久 +1 射程#掉落1-2个黑心#没有可献祭跟班类道具时，反噬并受到半颗红心伤害",
        },
    },
    BossOrder = {
        en_us = {
            name = "Boss's Order",
            description = "3-charge active item#Spawns 1 hostile enemy#Normal enemies are drawn from the current floor; bosses are drawn from the Boss Rush pool#Normal enemies have a 15% chance to become champions after spawning#Killing the target drops cards: 1 for a normal enemy, 2 for a champion, or 3 for a boss",
        },
        zh_cn = {
            name = "老大的指令",
            description = "3充能主动道具#生成1个敌对目标#小怪来源于当前层小怪池#头目来源于Boss Rush池#小怪生成后有15%概率变为精英#击杀后掉落卡牌：普通1张，精英2张，头目3张",
        },
    },
    BetweenDeathAndLife = {
        en_us = {
            name = "Between Life and Death",
            description = "Picking this up starts a Death Certificate trial for the rest of the run#Enemies become champions whenever possible#Bosses become champions when possible; otherwise, they are strengthened#Defeating a floor boss spawns Death Certificate#This reward can trigger once per floor",
        },
        zh_cn = {
            name = "生死一念间",
            description = "拾取后，本局进入死证试炼：#所有敌人尽可能变为精英怪#Boss也会被精英化或强化#每层击败楼层Boss后，生成一个死亡证明#每层最多触发一次",
        },
    },
    SterilizationCertificate = {
        en_us = {
            name = "Sterilization Certificate",
            description = "Prevents enemies from summoning more enemies#Each blocked summon damages its summoner: normal enemies take 10 + 5% of their max HP; bosses take 3 + 1% of their max HP#Boss summons are only partially suppressed",
        },
        zh_cn = {
            name = "绝育证明",
            description = "阻止会生成敌人的敌人继续生成敌人#每次阻止生成时，对源敌人造成反噬：普通敌人10+最大生命5%，Boss 3+最大生命1%#Boss 召唤效果只会被部分削弱",
        },
    },
    Condom = {
        en_us = {
            name = "Condom",
            description = "3-charge active item#Randomly removes up to 2 baby-tagged collectibles from future item spawns#Does not remove items you already own",
        },
        zh_cn = {
            name = "避孕套",
            description = "3充能主动道具#使用后，随机禁用最多2个未来可生成的宝宝标签道具#不会移除已经拥有的道具",
        },
    },
    UtilityKnife = {
        en_us = {
            name = "Utility Knife",
            description = "{{Damage}} +1 damage#Gain 1 broken heart on pickup",
        },
        zh_cn = {
            name = "美工刀",
            description = "↑ +1攻击力#获得一颗碎心",
        },
    },
    Cleaver = {
        en_us = {
            name = "Cleaver",
            description = "Only works for Stranger#Replaces tears with cleaver swings#Hitting an enemy's body deals 0.5 damage and strong knockback#Hitting its past shadow deals 200% of your damage",
        },
        zh_cn = {
            name = "柴刀",
            description = "仅 Stranger 可用#眼泪替换为柴刀挥砍#砍中敌人本体：0.5伤害并强力击退#砍中过去影子：造成2倍角色伤害",
        },
    },
    CoinSewnSword = {
        en_us = {
            name = "Coin-Sewn Sword",
            description = "3-charge active item#Spend up to 6 coins to fire the same number of coin blades in a 150-degree fan#Each blade deals 200% of your damage#Spending 6 coins also fires a piercing empowered blade that deals 600% of your damage#With no coins, take half a red heart of damage and fire 1 blood blade that deals 400% of your damage",
        },
        zh_cn = {
            name = "铜钱剑",
            description = "3充能主动道具#消耗至多6枚硬币，向前方150度释放等量铜钱剑气#每道剑气造成攻击力 x2.0 伤害#消耗满6枚时，额外释放造成 x6.0 伤害的贯穿剑气#没有硬币时，受到半红心伤害并释放1道造成 x4.0 伤害的血色剑气",
        },
    },
    CoinFacedMask = {
        en_us = {
            name = "Coin-Faced Mask",
            description = "Enter a room with at least 5 coins to gain a mask#The mask confuses room enemies for 3 seconds#When hit by a monster, spend 5 coins to block that hit#Without enough coins, the mask breaks and your {{Luck}} luck is reduced by 2 for the room",
        },
        zh_cn = {
            name = "铜钱面具",
            description = "拥有至少5枚硬币时，进房获得假面#假面令本房敌人混乱3秒#被怪物伤害时消耗5枚硬币，免疫本次伤害#硬币不足时，假面破裂，{{Luck}} 本房间-2幸运",
        },
    },
    BlackTaisui = {
        en_us = {
            name = "Black Taisui",
            description = "Builds up parasite points from healing, heart containers, and damage taken#Each red heart container adds 4 points; each half red heart healed adds 1; each half red heart lost to damage adds 2#With no red heart containers: each full soul or black heart healed adds 1 point; each half heart lost adds 1#0-7 points: {{Damage}} -0.5 damage, {{Speed}} -0.2 speed, and {{Luck}} -3 luck per copy; damage cannot fall below 1 and speed cannot fall below 0.5#8-15 points: {{Damage}} -0.5 damage; reveals hidden pedestal items and suppresses the Curses of the Blind, the Lost, and the Unknown, plus Wavy Cap's side effects#16+ points: keeps the reveal and protection effects, replaces the damage penalty with {{Damage}} +1.5 damage per copy, and spawns Meat Lump once#At 16+ points, also blocks 1 lethal hit per floor, except damage from IV Bag, Devil Deals, and curse room doors#All copies share parasite points; Meat Lump is still granted only once",
        },
        zh_cn = {
            name = "黑太岁",
            description = "红心治疗、红心容器和红心伤害会积累寄生值#每个红心容器+4；红心治疗每半心+1；红心伤害每半心+2#无红心容器时：魂心/黑心治疗每整心+1；魂心/黑心伤害每半心+1#0-7：每个黑太岁 {{Damage}} -0.5、{{Speed}} -0.2、{{Luck}} -3（攻击最低1，移速最低0.5）#8-15：{{Damage}} -0.5；揭示问号道具，并压制致盲/迷途/未知和波浪帽副作用#16+：保留揭示与压制效果，取消攻击减益；每个黑太岁 {{Damage}} +1.5；生成1次肉块#三阶段本体每层可挡1次致命伤；不挡献血袋、恶魔交易和诅咒门代价#多个黑太岁共享寄生值；肉块仍只生成一次",
        },
    },
    MeatLump = {
        en_us = {
            name = "Meat Lump",
            description = "Each copy blocks 1 lethal hit#Leaves you with a little health and grants brief invincibility#The HUD's +N counter shows how many hits Meat Lump can still block#Does not appear in item pools",
        },
        zh_cn = {
            name = "肉块",
            description = "每个肉块可抵挡1次致命伤害#触发后保留少量生命，并获得短暂无敌#HUD +N 显示肉块剩余挡死次数#这个道具不存在于任何道具池里",
        },
    },
    GoodGirlOfBabylon = {
        en_us = {
            name = "Good Girl of Babylon",
            description = "At full red health, become prim and proper:#{{Tears}} -0.6 tear delay (faster firing)#{{Luck}} +2 luck#Each enemy has a 15% chance to be charmed for 3 seconds#Clearing a room without taking red-heart damage has a 33% chance to drop a Tarot card, half a soul heart, or a penny#Taking red-heart damage breaks your composure:#{{Luck}} -2 luck for the room#Frightens enemies within a radius of 120 for 2 seconds#For 5 seconds: {{Damage}} +1.2 damage and {{Speed}} +0.15 speed",
        },
        zh_cn = {
            name = "巴比伦好女孩",
            description = "满红心时进入端正状态：#{{Tears}} 射击间隔-0.6#{{Luck}} +2幸运#每个敌人有15%概率被魅惑3秒#无红心伤害清房时，有33%概率掉落1张塔罗牌、半魂心或1枚硬币#受到红心伤害时端正破裂：#{{Luck}} 本房间-2幸运#恐惧120范围内敌人2秒#获得5秒巴比伦回声：{{Damage}} +1.2攻击力，{{Speed}} +0.15移速",
        },
    },
    DebugController = {
        en_us = {
            name = "Debug Controller",
            description = "Opens a directional debug command menu#Use again to close it#While open, shooting directions select commands instead of firing tears#Supports debug commands 1 through 13",
        },
        zh_cn = {
            name = "调试控制器",
            description = "打开四向调试命令菜单#再次使用关闭菜单#菜单打开时仅射击方向用于选择，不会发射眼泪#可执行 debug 1 至 debug 13",
        },
    },
    StrongLaxative = {
        en_us = {
            name = "Strong Laxative",
            description = "Treats all creep as friendly#Leaves slippery creep as you move#The creep slows grounded enemies and deals a base 10% of your damage every 10 frames#Supports Aquarius-style poison, burning, homing, and Playdough Cookie effects#Proptosis triples creep damage; Ipecac uses Aquarius's damage calculation#Lump of Coal and Sulfuric Acid add neither obstacle destruction nor distance-based damage; no explosions or Godhead aura#Each copy adds a 5% chance per second to spawn random poop, up to 100%#Spawns up to 15 poops per room",
        },
        zh_cn = {
            name = "强力泻药",
            description = "所有水迹视为己方水迹#移动时留下打滑水迹#打滑水迹使地面敌人减速，每10帧造成基础10%角色伤害#继承宝瓶座式协同：中毒、燃烧、追踪及黏土饼干随机效果#眼球突出：水迹伤害×3；吐根酊：使用宝瓶座的伤害计算基数#煤块与硫酸不破坏障碍物、不增加距离伤害；无爆炸和神性光环#每个副本每秒+5%概率生成随机大便（最高100%）#每个房间最多生成15个大便",
        },
    },
    TowerOfBabel = {
        en_us = {
            name = "Tower of Babel",
            description = "All newly spawned creep disappears immediately#Affects enemy, neutral, and player-created creep",
        },
        zh_cn = {
            name = "通天塔",
            description = "本局游戏中，新生成的水渍会立刻消失#包括敌方、中立和玩家自己的水渍",
        },
    },
    TheMoonIsBeautiful = {
        en_us = {
            name = "The Moon Is Beautiful",
            description = "Within 2 seconds of entering an uncleared room, go 1 full second without firing tears to activate:#{{Damage}} +1 damage and {{Luck}} +1 luck for the room#Marks all enemies in the room#The first player hit on each marked enemy releases a moonlight wave for 30% of your damage#Marked enemies have a 10% chance to drop an extra reward when killed#In boss rooms, bosses take 50% more damage from player tears for the room#Activates once per room",
        },
        zh_cn = {
            name = "月色真美",
            description = "进入未清理房间后，若前2秒内连续1秒不发射眼泪：#本房间+1伤害、+1幸运#并标记本房间所有敌人#被标记敌人第一次被玩家命中时释放月光波#月光波造成30%角色伤害#被标记敌人死亡时有10%概率掉落额外奖励#Boss房中，Boss本房间受到的玩家泪弹伤害+50%#每个房间最多触发一次",
        },
    },
    BurnAwayResentment = {
        en_us = {
            name = "Burn Away the Resentment",
            description = "First pickup: gain 2 resentment stacks#Clearing an enemy room adds 1 stack; boss rooms add 2#{{Speed}} -0.04 speed per stack, down to a minimum of 0.5; up to 6 stacks#At 6 stacks, your first direct hit in the next enemy room deals 300% of your damage to all enemies and burns them for 3 seconds#Taking damage from an enemy at 3-6 stacks instead deals 50% of your damage per stack to all enemies and burns them for 3 seconds#On the next floor, each spent or unspent stack grants {{Damage}} +0.35 damage and {{Tears}} -0.12 tear delay (faster firing)",
        },
        zh_cn = {
            name = "焚尽郁结",
            description = "首次拾取获得2层郁结#清理敌对房间+1层，头目房总共+2层#{{Speed}} 每层-0.04移速（最低0.5），最多6层#满6层后，下一间敌对房的首次直接命中：全房造成300%角色伤害并燃烧3秒#3-6层受到真实敌方伤害时：每层造成50%角色伤害并燃烧3秒#下一层中，每层已消耗或未消耗的郁结提供 {{Damage}} +0.35攻击力和 {{Tears}} 射击间隔-0.12",
        },
    },
    Needletick = {
        en_us = {
            name = "Void Needle",
            description = "Chance to fire a void needle: 5% at 0 luck, rising linearly to 15% at 10 luck; capped at 15%#On impact or when the needle breaks, instantly kills normal enemies within a radius of 80 around that point",
        },
        zh_cn = {
            name = "虚空针尖",
            description = "0幸运时5%概率发射；随幸运线性提升，10幸运时15%（最高15%）#虚空针尖泪弹秒杀80范围内附近普通敌人",
        },
    },
    CrazyCoconut = {
        en_us = {
            name = "Crazy Coconut",
            description = "{{Damage}} Each copy grants +3 permanent damage#After that, picking up an item from a pedestal grants another +3 permanent damage per copy if that item does not increase your actual damage",
        },
        zh_cn = {
            name = "疯狂的椰子",
            description = "{{Damage}} 每个副本永久+3攻击力#之后，从道具底座拿到的每个实际不增加攻击力的道具：每个副本永久+3攻击力",
        },
    },
    EmptyCradle = {
        en_us = {
            name = "Empty Cradle",
            description = "The first time you lose health each floor, the type of heart lost is recorded#Clear that room for a reward:#Red heart: 1 full red, soul, or black heart#Soul heart: 3 pennies, 1 key, or 1 bomb#Black heart: {{Damage}} +1.0 for this floor#Taking another hit before the room is clear downgrades the reward:#Red heart: half red or half soul heart#Soul heart: no extra reward#Black heart: {{Damage}} +0.5 for this floor",
        },
        zh_cn = {
            name = "空摇篮",
            description = "每层第一次有效受伤会记录损失的心形类型#清理当前房间后获得对应奖励：#红心：1个完整红心、魂心或黑心#魂心：获得1轮奖励，3硬币、1钥匙或1炸弹#黑心：本层 {{Damage}} +1.0攻击力#清房前再次受伤会降为基础奖励：#红心：半红心或半魂心#魂心：不再获得额外奖励轮次#黑心：本层 {{Damage}} +0.5攻击力",
        },
    },
}

local function findEIDCall(calls, id, language)
    local found = nil
    for _, call in ipairs(calls) do
        if call.id == id and call.language == language then
            assertEquals(found, nil, "EID should register only one " .. language .. " description for item " .. tostring(id))
            found = call
        end
    end
    return found
end

local function test_eid_registers_explicit_english_and_chinese_descriptions()
    local env = loadNeverbirthWithEID()

    for itemName, languageExpectations in pairs(expectedEID) do
        local itemId = env.itemIds[itemName]
        for language, expectation in pairs(languageExpectations) do
            local call = findEIDCall(env.eidCalls, itemId, language)
            assertTruthy(call, "missing EID " .. language .. " registration for " .. itemName)
            assertEquals(call.itemName, expectation.name, itemName .. " " .. language .. " EID name")
            assertEquals(call.description, expectation.description, itemName .. " " .. language .. " EID description")
        end
    end

    local expectedCallCount = 0
    for _, languageExpectations in pairs(expectedEID) do
        for _ in pairs(languageExpectations) do
            expectedCallCount = expectedCallCount + 1
        end
    end
    assertEquals(#env.eidCalls, expectedCallCount,
        "EID should register both languages for every collectible")
    for _, call in ipairs(env.eidCalls) do
        assertTruthy(call.language == "en_us" or call.language == "zh_cn", "EID language should be explicit for every registration")
        if call.language == "en_us" then
            assertEquals(containsHan(call.itemName), false, "English EID name should not contain Chinese")
            assertEquals(containsHan(call.description), false, "English EID description should not contain Chinese")
        elseif call.language == "zh_cn" and call.itemName ~= "ds4" then
            assertTruthy(containsHan(call.itemName), "Chinese EID name should contain Chinese for " .. tostring(call.id))
            assertTruthy(containsHan(call.description), "Chinese EID description should contain Chinese for " .. tostring(call.id))
        end
    end
end

local function test_item_ids_are_resolved_from_english_or_chinese_loaded_names()
    local chineseLookupNames = {}
    local englishDisplayLookupNames = {}
    local baselineEnv = loadNeverbirthWithEID()
    for itemName, expected in pairs(expectedXmlItems) do
        chineseLookupNames[expected.zhName] = baselineEnv.itemIds[itemName]
        englishDisplayLookupNames[expected.enName] = baselineEnv.itemIds[itemName]
    end

    local englishEnv = loadNeverbirthWithEID()
    local englishDisplayEnv = loadNeverbirthWithEID({ itemIdsByLoadedName = englishDisplayLookupNames })
    local chineseEnv = loadNeverbirthWithEID({ itemIdsByLoadedName = chineseLookupNames })

    for itemName, itemId in pairs(englishEnv.itemIds) do
        assertTruthy(findEIDCall(englishEnv.eidCalls, itemId, "en_us"), "Legacy registration-name lookup should register EID for " .. itemName)
        assertEquals(englishDisplayEnv.itemIds[itemName], itemId, "English display-name lookup should preserve the registered item ID for " .. itemName)
        assertTruthy(findEIDCall(englishDisplayEnv.eidCalls, itemId, "en_us"), "English display-name lookup should register EID for " .. itemName)
        assertTruthy(findEIDCall(chineseEnv.eidCalls, itemId, "en_us"), "Chinese-name lookup should register EID for " .. itemName)
        assertTruthy(findEIDCall(chineseEnv.eidCalls, itemId, "zh_cn"), "Chinese-name lookup should register Chinese EID for " .. itemName)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"))
    local text = file:read("*a")
    file:close()
    return text
end

local function getItemXmlBlockFromText(text, xmlName)
    local patternName = xmlName:gsub("([^%w])", "%%%1")
    local block = text:match('<active%s+name="' .. patternName .. '"(.-)/>')
        or text:match('<passive%s+name="' .. patternName .. '"(.-)/>')
    assertTruthy(block, "items.xml should contain item " .. xmlName)
    return block
end

local STABLE_REGISTRATION_NAMES = {
    BetweenDeathAndLife = "Between Death and Life",
    LeanCan = "Lean Can",
    ReviveMyLove = "Revive My Love",
    Needletick = "Needletick",
    EssentialBalm = "EssentialBalm",
    Wuhu = "Wuhu",
    Musicbox = "Music Box",
    Angelbox = "Angelbox",
    Devilbox = "Devilbox",
}

local function getItemXmlBlock(itemName)
    local file = assert(io.open("content/items.xml", "r"))
    local text = file:read("*a")
    file:close()

    return getItemXmlBlockFromText(text, STABLE_REGISTRATION_NAMES[itemName] or expectedXmlItems[itemName].enName)
end

local function test_items_xml_uses_stable_registration_names_and_english_descriptions()
    for itemName, expected in pairs(expectedXmlItems) do
        local block = getItemXmlBlock(itemName)
        local description = block:match('description="(.-)"')
        assertEquals(description, expected.description, itemName .. " XML description")
        assertEquals(containsHan(description), false, itemName .. " XML description should not contain Chinese")
    end
end

local function fileExists(path)
    local file = io.open(path, "r")
    if file then
        file:close()
        return true
    end
    return false
end

local function normalizeNewlines(text)
    return (text:gsub("\r\n", "\n"))
end

local function collectItemNamesFromItemsXml(text)
    local names = {}
    for kind, name in text:gmatch('<(%w+)%s+name="(.-)"') do
        if kind == "active" or kind == "passive" or kind == "familiar" then
            names[name] = true
        end
    end
    return names
end

local function assertItemPoolsReferenceExistingItems(itempoolsText, itemNames, label)
    for referencedName in itempoolsText:gmatch('<Item%s+Name="(.-)"') do
        assertTruthy(itemNames[referencedName], label .. " itempools.xml references missing item name " .. referencedName)
    end
end

local function test_language_templates_are_parseable_and_localize_pickup_names()
    local englishTemplate = readFile("content/items.en_us.xml")
    local chineseTemplate = readFile("content/items.zh_cn.xml")
    local englishPools = readFile("content/itempools.en_us.xml")
    local chinesePools = readFile("content/itempools.zh_cn.xml")

    for itemName, expected in pairs(expectedXmlItems) do
        local englishBlock = getItemXmlBlockFromText(englishTemplate, expected.enName)
        local chineseBlock = getItemXmlBlockFromText(chineseTemplate, expected.zhName)
        local englishDescription = englishBlock:match('description="(.-)"')
        local chineseDescription = chineseBlock:match('description="(.-)"')

        assertEquals(englishDescription, expected.description, itemName .. " English template description")
        assertEquals(chineseDescription, expected.zhDescription, itemName .. " Chinese template description")
        assertEquals(containsHan(expected.enName), false, itemName .. " English pickup name should not contain Chinese")
        if itemName ~= "ds4" then
            assertTruthy(containsHan(expected.zhName), itemName .. " Chinese pickup name should contain Chinese")
        end
        assertEquals(containsHan(englishDescription), false, itemName .. " English template should not contain Chinese")
        if itemName ~= "ds4" and expected.zhDescription ~= "" then
            assertTruthy(containsHan(chineseDescription), itemName .. " Chinese template should contain Chinese")
        end
    end

    assertItemPoolsReferenceExistingItems(englishPools, collectItemNamesFromItemsXml(englishTemplate), "English")
    assertItemPoolsReferenceExistingItems(chinesePools, collectItemNamesFromItemsXml(chineseTemplate), "Chinese")
end

local function test_runtime_pickup_banner_table_matches_all_language_templates()
    local source = readFile("main.lua")
    local registrationCount = 0
    for _ in source:gmatch("[\r\n]Neverbirth:RegisterPickupBannerText%(") do
        registrationCount = registrationCount + 1
    end

    local expectedCount = 0
    for itemName, expected in pairs(expectedXmlItems) do
        expectedCount = expectedCount + 1
        local needle = ', "' .. expected.enName .. '", "' .. expected.description
            .. '", "' .. expected.zhName .. '", "' .. expected.zhDescription .. '")'
        assertTruthy(source:find(needle, 1, true),
            itemName .. " runtime pickup banner text should match the English and Chinese XML templates")
    end

    local registeredNames = collectItemNamesFromItemsXml(readFile("content/items.xml"))
    local registeredCount = 0
    for _ in pairs(registeredNames) do registeredCount = registeredCount + 1 end
    assertEquals(expectedCount, registeredCount,
        "localization baseline should contain every collectible currently registered in content/items.xml")
    assertEquals(registrationCount, expectedCount,
        "runtime pickup banner table should register exactly one entry per Neverbirth collectible")
end
local ENGLISH_DISPLAY_TO_REGISTRATION_NAME = {
    ["Between Life and Death"] = "Between Death and Life",
    ["Low-Fat Chow"] = "Lean Can",
    ["Arise, My Love!"] = "Revive My Love",
    ["Void Needle"] = "Needletick",
    ["Essential Balm"] = "EssentialBalm",
    ["Wuhu!"] = "Wuhu",
    ["Angel Box"] = "Angelbox",
    ["Devil Box"] = "Devilbox",
}

local function normalizeEnglishLocalizedRegistrationNames(text)
    for displayName, registrationName in pairs(ENGLISH_DISPLAY_TO_REGISTRATION_NAME) do
        local pattern = displayName:gsub("([^%w])", "%%%1")
        text = text:gsub('name="' .. pattern .. '"', 'name="' .. registrationName .. '"')
        text = text:gsub('Name="' .. pattern .. '"', 'Name="' .. registrationName .. '"')
    end

    return text
end

local function test_default_xml_files_match_english_templates()
    assertEquals(
        normalizeNewlines(readFile("content/items.xml")),
        normalizeEnglishLocalizedRegistrationNames(normalizeNewlines(readFile("content/items.en_us.xml"))),
        "default items.xml should match the English language template"
    )
    assertEquals(
        normalizeNewlines(readFile("content/itempools.xml")),
        normalizeEnglishLocalizedRegistrationNames(normalizeNewlines(readFile("content/itempools.en_us.xml"))),
        "default itempools.xml should match the English language template"
    )
end

local function test_playable_files_do_not_depend_on_neverbirth_stringtable_tokens()
    for _, path in ipairs({
        "content/items.xml",
        "content/items.en_us.xml",
        "content/items.zh_cn.xml",
        "content/itempools.xml",
        "content/itempools.en_us.xml",
        "content/itempools.zh_cn.xml",
        "main.lua",
    }) do
        local text = readFile(path)
        assertEquals(text:find("#NEVERBIRTH_", 1, true), nil, path .. " should not contain inactive localization tokens")
    end
    assertEquals(fileExists("resources/stringtable.sta"), false, "inactive mod stringtable should not ship in playable v2.1")
end

local function test_failed_stringtable_experiment_is_documented()
    local text = readFile("docs/localization-token-research.md")
    assertTruthy(text:find("resources/stringtable.sta", 1, true), "token research should mention the tested stringtable path")
    assertTruthy(text:find("#NEVERBIRTH_", 1, true), "token research should mention the failed token symptom")
    assertTruthy(text:find("not loaded", 1, true), "token research should record that the mod stringtable was not loaded")
end

local function test_little_leather_shoes_registration_contract()
    local files = {
        { path = "content/items.xml", shoes = "Little Leather Shoes", unboxing = "Traffic: Unboxing", exposure = "Traffic: Exposure", heat = "Traffic: Heat" },
        { path = "content/items.en_us.xml", shoes = "Little Leather Shoes", unboxing = "Traffic: Unboxing", exposure = "Traffic: Exposure", heat = "Traffic: Heat" },
        { path = "content/items.zh_cn.xml", shoes = "小皮鞋", unboxing = "流量：开箱", exposure = "流量：曝光", heat = "流量：热度" },
    }
    for _, entry in ipairs(files) do
        local text = readFile(entry.path)
        local shoes = getItemXmlBlockFromText(text, entry.shoes)
        assertEquals(shoes:match('id="(.-)"'), "32", entry.path .. " Little Leather Shoes local id")
        assertEquals(shoes:match('quality="(.-)"'), "2", entry.path .. " Little Leather Shoes quality")
        assertEquals(shoes:match('tags="(.-)"'), "offensive summonable", entry.path .. " Little Leather Shoes tags")
        for _, hidden in ipairs({ { entry.unboxing, "33" }, { entry.exposure, "34" }, { entry.heat, "35" } }) do
            local block = getItemXmlBlockFromText(text, hidden[1])
            assertEquals(block:match('id="(.-)"'), hidden[2], entry.path .. " hidden Traffic local id")
            assertEquals(block:match('quality="(.-)"'), "0", entry.path .. " hidden Traffic quality")
            assertEquals(block:match('hidden="(.-)"'), "true", entry.path .. " hidden Traffic flag")
            assertEquals(block:match('tags="(.-)"'), "noeden nochallenge nodaily nogreed", entry.path .. " hidden Traffic tags")
        end
    end

    for _, entry in ipairs({
        { path = "content/itempools.xml", name = "Little Leather Shoes" },
        { path = "content/itempools.en_us.xml", name = "Little Leather Shoes" },
        { path = "content/itempools.zh_cn.xml", name = "小皮鞋" },
    }) do
        local pools = readFile(entry.path)
        local escaped = entry.name:gsub("([^%w])", "%%%1")
        local entries = {}
        for weight, decrease, removeOn in pools:gmatch('<Item%s+Name="' .. escaped .. '"%s+Weight="(.-)"%s+DecreaseBy="(.-)"%s+RemoveOn="(.-)"/>') do entries[#entries + 1] = { weight, decrease, removeOn } end
        assertEquals(#entries, 3, entry.path .. " should contain exactly three Little Leather Shoes pool entries")
        local weights = {}
        for _, values in ipairs(entries) do
            assertEquals(values[2], "1", entry.path .. " DecreaseBy")
            assertEquals(values[3], "1", entry.path .. " RemoveOn")
            weights[values[1]] = (weights[values[1]] or 0) + 1
        end
        assertEquals(weights["1"], 2, entry.path .. " treasure and shop weights")
        assertEquals(weights["0.1"], 1, entry.path .. " devil weight")
        assertEquals(pools:find("Traffic:", 1, true), nil, entry.path .. " hidden Traffic rewards must not enter pools")
        assertEquals(pools:find("流量：", 1, true), nil, entry.path .. " hidden Traffic rewards must not enter localized pools")
    end
end

local function test_player_facing_english_copy_is_natural_and_synchronized()
    local revisions = {
        { paths = { "main.lua" }, old = "Dash damage: 5 + 5% enemy max HP + 20% damage", new = "Dash damage: 5 + 5% of the enemy's max HP + 20% of your damage" },
        { paths = { "main.lua" }, old = "Big Dog Bark's body dash and echo leave slowing pollution", new = "Big Dog Bark's dash and echo leave creep that slows enemies" },
        { paths = { "main.lua" }, old = "One-hit killing a normal enemy", new = "Killing a normal enemy in one hit" },
        { paths = { "main.lua" }, old = "3 one-hit kills in the same room: kill the whole team", new = "Killing 3 normal enemies in one hit each in the same room kills the entire team" },
        { paths = { "main.lua" }, old = "Enter a paged room containing each passive or familiar pedestal", new = "Enter a gallery of passive and familiar items seen on pedestals this run" },
        { paths = { "main.lua" }, old = "During Music Box, Plan C self-kill is prevented but its enemy damage remains", new = "While active, Plan C still damages enemies but does not kill you" },
        { paths = { "main.lua" }, old = "Later full-charge uses try to force an Angel Room this floor", new = "Later uses at full charge attempt to open an Angel Room on the current floor" },
        { paths = { "main.lua" }, old = "the first Angel Room gains 1 quality-4 Angel item", new = "the first one also contains 1 quality-4 Angel Room item" },
        { paths = { "main.lua" }, old = "Later full-charge uses try to force a Devil Room this floor", new = "Later uses at full charge attempt to open a Devil Room on the current floor" },
        { paths = { "main.lua" }, old = "the first Devil Room gains 1 quality-3 Devil item", new = "the first one also contains 1 quality-3 Devil Room item" },
        { paths = { "main.lua" }, old = "For every 3 cards removed, spawns 1 Treasure Room item", new = "Every 3 cards removed spawn 1 Treasure Room item" },
        { paths = { "main.lua" }, old = "{{Damage}} Permanently gain +1.5 damage", new = "{{Damage}} +1.5 permanent damage" },
        { paths = { "main.lua" }, old = "{{Range}} Permanently gain +1 range", new = "{{Range}} +1 permanent range" },
        { paths = { "main.lua" }, old = "Killing it drops cards: 1 normal, 2 champion, 3 boss", new = "Killing the target drops cards: 1 for a normal enemy, 2 for a champion, or 3 for a boss" },
        { paths = { "main.lua" }, old = "Bosses are championed or empowered", new = "Bosses become champions when possible; otherwise, they are strengthened" },
        { paths = { "main.lua" }, old = "Without enough coins, the mask breaks and {{Luck}} -2 luck for the room", new = "Without enough coins, the mask breaks and your {{Luck}} luck is reduced by 2 for the room" },
        { paths = { "main.lua" }, old = "16+: keeps all 8-15 effects; {{Damage}} +1.5 per copy; create Meat Lump once", new = "16+ points: keeps the reveal and protection effects, replaces the damage penalty" },
        { paths = { "main.lua" }, old = "Leaving the room converts this room's speed loss to x2 and fire-rate gain to x0.4", new = "Leaving the room doubles the speed penalty accumulated there and keeps 40% of its tear-delay reduction" },
        { paths = { "main.lua" }, old = "Clearing a room removes one use worth of lingering changes", new = "Clearing a room removes one use's worth of these lingering effects" },
        { paths = { "main.lua" }, old = "Fear enemies within 120 for 2 seconds", new = "Frightens enemies within a radius of 120 for 2 seconds" },
        { paths = { "main.lua" }, old = "The first player hit on a marked enemy releases a moonlight wave", new = "The first player hit on each marked enemy releases a moonlight wave" },
        { paths = { "main.lua" }, old = "bosses take +50% player tear damage for the room", new = "bosses take 50% more damage from player tears for the room" },
        { paths = { "main.lua" }, old = "your first direct hit in the next hostile room purges the room for 300% damage and burns enemies for 3 seconds", new = "your first direct hit in the next enemy room deals 300% of your damage to all enemies and burns them for 3 seconds" },
        { paths = { "main.lua" }, old = "Taking real enemy damage at 3-6 layers instead purges for 50% damage per layer", new = "Taking damage from an enemy at 3-6 stacks instead deals 50% of your damage per stack to all enemies and burns them for 3 seconds" },
        { paths = { "main.lua" }, old = "Hit enemy bodies: 0.5 damage and heavy knockback#Hit past shadows: 2x your Damage", new = "Hitting an enemy's body deals 0.5 damage and strong knockback#Hitting its past shadow deals 200% of your damage" },
        { paths = { "main.lua" }, old = "The first time you lose health each floor remembers the lost heart type", new = "The first time you lose health each floor, the type of heart lost is recorded" },
        { paths = { "main.lua", "content/items.xml", "content/items.en_us.xml" }, old = "vomit in buckets", new = "Next time, spit in the trash..." },
        { paths = { "main.lua", "content/items.xml", "content/items.en_us.xml" }, old = "King of hollow earth", new = "King of the Hollow Earth" },
        { paths = { "main.lua" }, old = "Fate no longer falls below its origin", new = "Fate can no longer set you back" },
        { paths = { "metadata.xml" }, old = "is a The Binding of Isaac: Repentance item mod", new = "is an item mod for The Binding of Isaac: Repentance" },
        { paths = { "metadata.xml" }, old = "charge-driven deal-room direction items", new = "charge-based items that steer deal-room chances" },
        { paths = { "metadata.xml" }, old = "remembers the first hurt of each floor", new = "records the first type of heart lost each floor" },
        { paths = { "main.lua" }, old = "{{Tears}} Permanently +0.5 fire rate", new = "{{Tears}} +0.5 tears per second" },
        { paths = { "main.lua" }, old = "coin sword qi", new = "coin blades" },
        { paths = { "main.lua" }, old = "deals your damage x2.0", new = "deals 200% of your damage" },
        { paths = { "main.lua" }, old = "enter a presentable state", new = "become prim and proper" },
        { paths = { "main.lua" }, old = "soul-heart overflow", new = "absorbs only soul hearts you cannot hold" },
        { paths = { "main.lua" }, old = "black-heart overflow", new = "absorbs only black hearts you cannot hold" },
        { paths = { "main.lua" }, old = "+1 red heart container and refill all red hearts", new = "+1 heart container#Fully restores red hearts" },
        { paths = { "main.lua", "content/items.xml", "content/items.en_us.xml" }, old = "The first quality 4 item is replaced by Ipecac; if Black Candle was held when this item was picked up, Ipecac instead appears beside it. Lose all explosion immunity; Black Candle temporarily makes you immune to explosions.", new = "Darkness suppresses the curse" },
        { paths = { "README.md" }, old = "A The Binding of Isaac: Repentance mod by brick.", new = "A mod for The Binding of Isaac: Repentance by brick." },
        { paths = { "metadata.xml" }, old = "[*] Musicbox -", new = "[*] Music Box -" },
        { paths = { "content/items.xml" }, old = "name=\"Musicbox\"", new = "name=\"Music Box\"" },
        { paths = { "content/itempools.xml" }, old = "Name=\"Musicbox\"", new = "Name=\"Music Box\"" },
    }

    assertEquals(#revisions, 44, "player-facing English copy revision count")
    for index, revision in ipairs(revisions) do
        for _, path in ipairs(revision.paths) do
            local text = readFile(path)
            assertEquals(text:find(revision.old, 1, true), nil,
                path .. " should not contain outdated English copy for revision " .. index)
            assertTruthy(text:find(revision.new, 1, true),
                path .. " should contain revised English copy for revision " .. index)
        end
    end
end
local function test_healthy_sleep_has_complete_bilingual_copy()
    local previousGlobals = {}
    for key, value in pairs(_G) do previousGlobals[key] = value end
    for _, loadedName in ipairs({ "Healthy Sleep", "健康睡眠" }) do
        local env = loadNeverbirthWithEID({ itemIdsByLoadedName = { [loadedName] = 990 } })
        local en = findEIDCall(env.eidCalls, 990, "en_us")
        local zh = findEIDCall(env.eidCalls, 990, "zh_cn")
        assertTruthy(en, loadedName .. " should resolve English EID")
        assertTruthy(zh, loadedName .. " should resolve Chinese EID")
        assertEquals(en.itemName, "Healthy Sleep")
        assertEquals(zh.itemName, "健康睡眠")
        assertTruthy(en.description:find("8 hours of real time", 1, true))
        assertTruthy(en.description:find("15 frames", 1, true))
        assertTruthy(en.description:find("3 soul hearts", 1, true))
        assertTruthy(zh.description:find("15帧", 1, true))
        assertEquals(Neverbirth.PickupBannerTexts[990].en_us.subtitle, "Get your eight hours")
        assertEquals(Neverbirth.PickupBannerTexts[990].zh_cn.subtitle, "睡够八小时")
    end
    for _, spec in ipairs({
        { "content/items.xml", "Healthy Sleep", "Get your eight hours" },
        { "content/items.en_us.xml", "Healthy Sleep", "Get your eight hours" },
        { "content/items.zh_cn.xml", "健康睡眠", "睡够八小时" },
    }) do
        local entry = getItemXmlBlockFromText(readFile(spec[1]), spec[2])
        assertTruthy(entry, spec[1] .. " healthy sleep registration")
        assertEquals(entry:match('id="(.-)"'), "58", "Healthy Sleep keeps its local ID")
        assertEquals(entry:match('quality="(.-)"'), "0", "Healthy Sleep keeps its quality")
        assertEquals(entry:match('description="(.-)"'), spec[3])
        assertEquals(entry:match('gfx="(.-)"'), "healthy_sleep.png")
        assertEquals(entry:find("tags=", 1, true), nil, "translation must not invent tags")
    end
    -- Restore the fixture environment used by suites that import this test.
    for key, value in pairs(previousGlobals) do _G[key] = value end
end

test_eid_registers_explicit_english_and_chinese_descriptions()
test_item_ids_are_resolved_from_english_or_chinese_loaded_names()
test_items_xml_uses_stable_registration_names_and_english_descriptions()
test_language_templates_are_parseable_and_localize_pickup_names()
test_runtime_pickup_banner_table_matches_all_language_templates()
test_default_xml_files_match_english_templates()
test_playable_files_do_not_depend_on_neverbirth_stringtable_tokens()
test_failed_stringtable_experiment_is_documented()
test_little_leather_shoes_registration_contract()
test_player_facing_english_copy_is_natural_and_synchronized()
test_healthy_sleep_has_complete_bilingual_copy()

print("localization tests passed")
