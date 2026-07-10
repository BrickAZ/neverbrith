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
    }
    local defaultItemIdsByLoadedName = {}
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
    }

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
    }
    EntityFlag = { FLAG_CHARM = 1 }
    TearFlags = { TEAR_HOMING = 1 }
    EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5 }
    PickupVariant = { PICKUP_HEART = 10, PICKUP_PILL = 70, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
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

    local mod
    function RegisterMod(name, version)
        mod = {
            Name = name,
            Version = version,
        }

        function mod:AddCallback(callbackId, fn, param)
            callbacks[callbackId] = callbacks[callbackId] or {}
            callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
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

    dofile("main.lua")

    return {
        eidCalls = eidCalls,
        itemIds = logicalItemIds,
    }
end

local expectedXmlItems = {
    EssentialBalm = {
        enName = "EssentialBalm",
        zhName = "风油精",
        description = "Handle with care",
        zhDescription = "3岁以下儿童慎用",
    },
    Wuhu = {
        enName = "Wuhu",
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
        enName = "Musicbox",
        zhName = "八音盒",
        description = "Your life, on a timer",
        zhDescription = "为你的生命倒计时",
    },
    Angelbox = {
        enName = "Angelbox",
        zhName = "天使盒",
        description = "Full hearts, heavenbound",
        zhDescription = "盈魂引向天国",
    },
    Devilbox = {
        enName = "Devilbox",
        zhName = "恶魔盒",
        description = "Black hearts, below",
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
        description = "Remembered harm",
        zhDescription = "伤痕会回应",
    },
    BloodSkullGu = {
        enName = "Blood Skull Gu",
        zhName = "血颅蛊",
        description = "Slaughter your kin to purify your aptitude.",
        zhDescription = "杀亲证道，提纯资质。",
    },
    BossOrder = {
        enName = "Boss's Order",
        zhName = "老大的指令",
        description = "I wanna catch u!",
        zhDescription = "兄弟，想抓杀你",
    },
    BetweenDeathAndLife = {
        enName = "Between Death and Life",
        zhName = "生死一念间",
        description = "Every life becomes testimony.",
        zhDescription = "众生皆证。",
    },
    Condom = {
        enName = "Condom",
        zhName = "避孕套",
        description = "It does not count",
        zhDescription = "她说戴了不算给",
    },
    UtilityKnife = {
        enName = "Utility Knife",
        zhName = "美工刀",
        description = "Painful scars",
        zhDescription = "苦痛伤痕",
    },
    CoinSewnSword = {
        enName = "Coin-Sewn Sword",
        zhName = "铜钱剑",
        description = "Coin and blade share the same edge.",
        zhDescription = "钱是香火，也是剑刃。",
    },
    CoinFacedMask = {
        enName = "Coin-Faced Mask",
        zhName = "铜钱面具",
        description = "Buy yourself another face.",
        zhDescription = "买一张脸。",
    },
    BlackTaisui = {
        enName = "Black Taisui",
        zhName = "黑太岁",
        description = "Feeds on blood and lets you see clearly.",
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
        description = "Don't stain the dress.",
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
}

local expectedEID = {
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
            description = "{{Speed}} +1 speed#{{Tears}} Max fire rate#{{Damage}} +40 damage#{{Shotspeed}} -1 shot speed",
        },
        zh_cn = {
            name = "芜湖！~",
            description = "↑ +1移速#↑ 攻速上限达到30#↑ +40攻击力#↓ -1弹速",
        },
    },
    Aphrodisiac = {
        en_us = {
            name = "Aphrodisiac",
            description = "Spend 1 full heart without dying#{{Damage}} +0.5 damage#{{Tears}} +0.5 fire rate#Charm effect and homing tears for 3 seconds",
        },
        zh_cn = {
            name = "春药",
            description = "使用后扣除1滴完整的血#{{Warning}} 优先扣红心 #{{Warning}} 不致死#↑ +0.5攻击力#↑ +0.5攻速#角色进入魅惑状态#眼泪获得追踪效果#持续3秒",
        },
    },
    Musicbox = {
        en_us = {
            name = "Music Box",
            description = "20 seconds of invincibility and red tears#{{Warning}} Death when the timer ends#Reuse does not extend time#When uncharged, blocks one lethal hit and triggers itself#Extra lives can save you",
        },
        zh_cn = {
            name = "八音盒",
            description = "使用后进入20秒无敌状态，眼泪变红并播放八音盒音乐#{{Warning}} 倒计时结束时强制死亡#第二次使用不会延长倒计时#未充能且受到致死伤害时，失去八音盒并自动触发一次#八音盒期间压制计划C的自杀死亡，但保留杀敌伤害#只有额外生命可以继续游戏",
        },
    },
    Angelbox = {
        en_us = {
            name = "Angel Box",
            description = "{{Luck}} +3 Luck while held#First use converts red heart containers into full soul hearts#Overflow soul hearts recharge it#At full charge, forces an angel room this floor and adds 1 quality 4 angel item on first entry#Heart drops have a 60% chance to add a soul heart#Favors angel rooms while held",
        },
        zh_cn = {
            name = "天使盒",
            description = "持有时 {{Luck}} +3 幸运#每名玩家首次使用：每个红心容器生成1个完整魂心#之后只吸收装不下的魂心充能，满4格可再次使用#非首次使用：本层尽力必定开启天使房#若使用前本层未进入过天使房，该玩家使首次进入本层天使房时额外生成1个4级天使房道具#地上心掉落有60%额外生成1个完整魂心#持有时一半恶魔房概率转为天使房概率",
        },
    },
    Devilbox = {
        en_us = {
            name = "Devil Box",
            description = "First use converts red heart containers into full black hearts#Overflow black hearts recharge it#At full charge, forces a devil room this floor and adds 1 quality 3 devil item on first entry#Heart drops have an 80% chance to add a black heart#Favors devil rooms while held",
        },
        zh_cn = {
            name = "恶魔盒",
            description = "每名玩家首次使用：每个红心容器生成1个完整黑心#之后只吸收装不下的黑心充能，满4格可再次使用#非首次使用：本层尽力必定开启恶魔房#若使用前本层未进入过恶魔房，该玩家使首次进入本层恶魔房时额外生成1个3级恶魔房道具#地上心掉落有80%额外生成1个黑心#持有时一半交易房方向转为恶魔房概率",
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
            description = "50% chance to delay incoming damage instead of taking it immediately#Clear 2 rooms without getting hit to take only half of the delayed damage#Getting hit again triggers the full delayed damage immediately",
        },
        zh_cn = {
            name = "未剪断的脐带",
            description = "受到伤害时，50%概率将本次伤害变为延迟伤害#连续通过2个房间且未再次受伤后，只承受一半延迟伤害#若期间再次受伤，立即承受全部延迟伤害",
        },
    },
    ShreddedTarot = {
        en_us = {
            name = "Shredded Tarot",
            description = "{{Luck}} +3 Luck while held#Single-use active item#Removes card pickups in the current room#For every 3 cards removed, spawns 1 Treasure Room item#Not consumed if fewer than 3 cards are present#Empty use does not count; disappears after this floor if unused",
        },
        zh_cn = {
            name = "剪碎的塔罗",
            description = "持有时 {{Luck}} +3 幸运#一次性使用#移除当前房间内的地上卡牌#每移除3张卡牌，生成1个宝箱房道具#卡牌不足3张时不会消耗#空拍不算使用，本层结束仍会消失",
        },
    },
    BloodSkullGu = {
        en_us = {
            name = "Blood Skull Gu",
            description = "3-charge active item#Sacrifice one familiar item you own#{{Damage}} Permanently gain +1.5 damage#{{Range}} Permanently gain +1 range#Drops 1-2 black hearts#If no familiar item can be sacrificed, take half a red heart of backlash damage instead",
        },
        zh_cn = {
            name = "血颅蛊",
            description = "3充能主动道具#献祭1个属于你的跟班类道具#{{Damage}} 永久 +1.5 攻击#{{Range}} 永久 +1 射程#掉落1-2个黑心#没有可献祭跟班类道具时，反噬并受到半颗红心伤害",
        },
    },
    BossOrder = {
        en_us = {
            name = "Boss's Order",
            description = "Spawns a hostile target#Small enemies come from the current floor#Bosses come from the Boss Rush pool#Small enemies may become champions after spawning#Killing it drops cards: 1 normal, 2 champion, 3 boss",
        },
        zh_cn = {
            name = "老大的指令",
            description = "生成一个敌对目标#小怪来源于当前层小怪池#头目来源于Boss Rush池#小怪生成后有概率变为精英#击杀后掉落卡牌：普通1张，精英2张，头目3张",
        },
    },
    BetweenDeathAndLife = {
        en_us = {
            name = "Between Death and Life",
            description = "On pickup, activates Death Trial for the rest of the run:#Enemies become champions whenever possible#Bosses are championed or empowered#Defeating each floor boss spawns Death Certificate#Once per floor",
        },
        zh_cn = {
            name = "生死一念间",
            description = "拾取后，本局进入死证试炼：#所有敌人尽可能变为精英怪#Boss也会被精英化或强化#每层击败楼层Boss后，生成一个死亡证明#每层最多触发一次",
        },
    },
    SterilizationCertificate = {
        en_us = {
            name = "Sterilization Certificate",
            description = "Prevents spawning enemies from creating more enemies#Blocked spawns deal backlash damage to the source enemy#Boss summons are only partially weakened",
        },
        zh_cn = {
            name = "绝育证明",
            description = "阻止会生成敌人的敌人继续生成敌人#每次阻止生成时，对该敌人造成反噬伤害#Boss 召唤效果只会被部分削弱",
        },
    },
    Condom = {
        en_us = {
            name = "Condom",
            description = "On use, randomly bans up to 2 future baby-tag items#Does not remove items you already own",
        },
        zh_cn = {
            name = "避孕套",
            description = "使用后，随机禁用最多2个未来可生成的宝宝标签道具#不会移除已经拥有的道具",
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
    CoinSewnSword = {
        en_us = {
            name = "Coin-Sewn Sword",
            description = "Spend up to 6 coins and fire that many coin sword qi in a 150-degree fan#Each qi deals your damage x2.0#Spending 6 coins also fires a piercing empowered qi that deals x6.0#With no coins, take half a red heart of damage and fire 1 blood qi that deals x4.0",
        },
        zh_cn = {
            name = "铜钱剑",
            description = "消耗至多6枚硬币，向前方150度释放等量铜钱剑气#每道剑气造成攻击力 x2.0 伤害#消耗满6枚时，额外释放造成 x6.0 伤害的贯穿剑气#没有硬币时，受到半红心伤害并释放1道造成 x4.0 伤害的血色剑气",
        },
    },
    CoinFacedMask = {
        en_us = {
            name = "Coin-Faced Mask",
            description = "Enter a room with at least 5 coins to gain a mask#The mask disturbs enemies#When hit by a monster, spend 5 coins to block that hit#Without enough coins, the mask breaks and lowers luck for the room",
        },
        zh_cn = {
            name = "铜钱面具",
            description = "拥有至少5枚硬币时，进房获得假面#假面会扰乱敌人#被怪物伤害时消耗5枚硬币，免疫本次伤害#硬币不足时，假面破裂，本房间幸运下降",
        },
    },
    BlackTaisui = {
        en_us = {
            name = "Black Taisui",
            description = "Feeds on blood to gain parasite value#0-7: heavy damage, speed, and luck penalties#8-15: reveals hidden items and suppresses Blind, Lost, Unknown, and Wavy Cap side effects#16+: inherits stage 2, grants fixed damage per copy, and creates Meat Lump once#Multiple copies share parasite value; Meat Lump still appears only once",
        },
        zh_cn = {
            name = "黑太岁",
            description = "以红心治疗、红心容器和红心伤害积累寄生值#0-7：大幅降低伤害、移速和幸运#8-15：揭示问号道具，免疫致盲/迷途/未知诅咒表现，并压制波浪帽副作用#16+：继承二阶段效果，每个黑太岁提供修正伤害，并生成一次肉块#多个黑太岁共享寄生值；阶段效果按规则叠加，但肉块只生成一次",
        },
    },
    MeatLump = {
        en_us = {
            name = "Meat Lump",
            description = "Conditionally blocks one lethal hit from enemies#This item does not exist in any item pool",
        },
        zh_cn = {
            name = "肉块",
            description = "有条件抵挡一次来自敌人的致死伤害#这个道具不存在于任何道具池里",
        },
    },
    GoodGirlOfBabylon = {
        en_us = {
            name = "Good Girl of Babylon",
            description = "At full red hearts, enter a presentable state:#{{Tears}} +0.6 tears#{{Luck}} +2 luck#Enemies may be charmed#Clearing a room without red heart damage may grant an extra reward#Taking red heart damage breaks the state:#{{Luck}} -2 luck for the room#Fears nearby enemies#Briefly gain an echo of Babylon",
        },
        zh_cn = {
            name = "巴比伦好女孩",
            description = "满红心时进入端正状态：#{{Tears}} +0.6射速#{{Luck}} +2幸运#敌人有概率被魅惑#无红心伤害清房时，可能获得额外奖励#受到红心伤害时端正破裂：#{{Luck}} 本房间幸运下降#恐惧附近敌人#短暂获得巴比伦回声",
        },
    },
    DebugController = {
        en_us = {
            name = "Debug Controller",
            description = "Opens a directional debug command menu#Use again to close#Directional input selects entries instead of firing while open#Runs debug 1 through debug 10",
        },
        zh_cn = {
            name = "调试控制器",
            description = "打开四向调试命令菜单#再次使用关闭菜单#菜单打开时方向输入用于选择，不会发射眼泪#可执行 debug 1 至 debug 10",
        },
    },
    StrongLaxative = {
        en_us = {
            name = "Strong Laxative",
            description = "All creep is treated as friendly#Leave slippery creep while moving#Slippery creep slows enemies and deals 10% of your damage every 10 frames#5% chance per second to spawn random poop#Up to 15 poops per room#Extra copies increase poop chance",
        },
        zh_cn = {
            name = "强力泻药",
            description = "所有水迹视为己方水迹#移动时留下打滑水迹#打滑水迹使敌人减速，并每10帧造成10%角色伤害#每秒5%概率生成随机大便#每个房间最多生成15个大便#多拿提高生成概率",
        },
    },
    EmptyCradle = {
        en_us = {
            name = "Empty Cradle",
            description = "The first effective damage each floor remembers the lost heart type#Clear that room for a reward: red hearts give hearts, soul hearts give pickups, black hearts give floor damage#Taking another hit before the room is clear downgrades the reward#Black-heart damage bonuses last for this floor only",
        },
        zh_cn = {
            name = "空摇篮",
            description = "每层第一次有效受伤会记录损失的心形类型#清理当前房间后获得对应奖励：红心给心，魂心给资源，黑心给本层攻击力#清房前再次受伤会降为基础奖励#黑心奖励的攻击力加成换层清除",
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
    assertEquals(#env.eidCalls, expectedCallCount, "EID should register exactly two languages for each item")
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
    local baselineEnv = loadNeverbirthWithEID()
    for itemName, expected in pairs(expectedXmlItems) do
        chineseLookupNames[expected.zhName] = baselineEnv.itemIds[itemName]
    end

    local englishEnv = loadNeverbirthWithEID()
    local chineseEnv = loadNeverbirthWithEID({ itemIdsByLoadedName = chineseLookupNames })

    for itemName, itemId in pairs(englishEnv.itemIds) do
        assertTruthy(findEIDCall(englishEnv.eidCalls, itemId, "en_us"), "English-name lookup should register EID for " .. itemName)
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

local function getItemXmlBlock(itemName)
    local file = assert(io.open("content/items.xml", "r"))
    local text = file:read("*a")
    file:close()

    return getItemXmlBlockFromText(text, expectedXmlItems[itemName].enName)
end

local function test_items_xml_uses_english_pickup_names_and_descriptions_by_default()
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
    for name in text:gmatch('<%w+%s+name="(.-)"') do
        names[name] = true
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
        if itemName ~= "ds4" then
            assertTruthy(containsHan(chineseDescription), itemName .. " Chinese template should contain Chinese")
        end
    end

    assertItemPoolsReferenceExistingItems(englishPools, collectItemNamesFromItemsXml(englishTemplate), "English")
    assertItemPoolsReferenceExistingItems(chinesePools, collectItemNamesFromItemsXml(chineseTemplate), "Chinese")
end

local function test_default_xml_files_match_english_templates()
    assertEquals(
        normalizeNewlines(readFile("content/items.xml")),
        normalizeNewlines(readFile("content/items.en_us.xml")),
        "default items.xml should match the English language template"
    )
    assertEquals(
        normalizeNewlines(readFile("content/itempools.xml")),
        normalizeNewlines(readFile("content/itempools.en_us.xml")),
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

test_eid_registers_explicit_english_and_chinese_descriptions()
test_item_ids_are_resolved_from_english_or_chinese_loaded_names()
test_items_xml_uses_english_pickup_names_and_descriptions_by_default()
test_language_templates_are_parseable_and_localize_pickup_names()
test_default_xml_files_match_english_templates()
test_playable_files_do_not_depend_on_neverbirth_stringtable_tokens()
test_failed_stringtable_experiment_is_documented()

print("localization tests passed")
