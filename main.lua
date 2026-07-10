-- 注册模组
local Neverbirth = RegisterMod("neverbirth", 1)
if _G then
    _G.Neverbirth = Neverbirth
end

local ITEM_NAME_CANDIDATES = {
    EssentialBalm = { "EssentialBalm", "风油精" },
    Wuhu = { "Wuhu", "芜湖！~" },
    Chunyao = { "Aphrodisiac", "春药" },
    Musicbox = { "Musicbox", "八音盒" },
    Angelbox = { "Angelbox", "天使盒" },
    Devilbox = { "Devilbox", "恶魔盒" },
    UncutCord = { "Uncut Cord", "未剪断的脐带" },
    ShreddedTarot = { "Shredded Tarot", "剪碎的塔罗" },
    SterilizationCertificate = { "Sterilization Certificate", "绝育证明" },
    EmptyCradle = { "Empty Cradle", "空摇篮" },
    BloodSkullGu = { "Blood Skull Gu", "血颅蛊" },
    BossOrder = { "Boss's Order", "老大的指令" },
    BetweenDeathAndLife = { "Between Death and Life", "生死一念间" },
    CoinSewnSword = { "Coin-Sewn Sword", "铜钱剑" },
    CoinFacedMask = { "Coin-Faced Mask", "铜钱面具" },
    BlackTaisui = { "Black Taisui", "黑太岁" },
    MeatLump = { "Meat Lump", "肉块" },
    CleansedWavyCap = { "Cleansed Wavy Cap", "净化迷幻菇" },
    GoodGirlOfBabylon = { "Good Girl of Babylon", "巴比伦好女孩" },
    DebugController = { "Debug Controller", "调试控制器" },
    StrongLaxative = { "Strong Laxative", "强力泻药" },
    Needletick = { "Needletick", "虚空针尖" },
    Condom = { "Condom", "避孕套" },
    UtilityKnife = { "Utility Knife", "美工刀" },
    DS4 = { "ds4" },
}

local function FindItemIdByNames(names)
    for _, name in ipairs(names) do
        local itemId = Isaac.GetItemIdByName(name)
        if type(itemId) == "number" and itemId > 0 then
            return itemId
        end
    end

    return -1
end

local Items = {
    EssentialBalm = FindItemIdByNames(ITEM_NAME_CANDIDATES.EssentialBalm),
    Wuhu = FindItemIdByNames(ITEM_NAME_CANDIDATES.Wuhu),
    Chunyao = FindItemIdByNames(ITEM_NAME_CANDIDATES.Chunyao),
    Musicbox = FindItemIdByNames(ITEM_NAME_CANDIDATES.Musicbox),
    Angelbox = FindItemIdByNames(ITEM_NAME_CANDIDATES.Angelbox),
    Devilbox = FindItemIdByNames(ITEM_NAME_CANDIDATES.Devilbox),
    UncutCord = FindItemIdByNames(ITEM_NAME_CANDIDATES.UncutCord),
    ShreddedTarot = FindItemIdByNames(ITEM_NAME_CANDIDATES.ShreddedTarot),
    SterilizationCertificate = FindItemIdByNames(ITEM_NAME_CANDIDATES.SterilizationCertificate),
    EmptyCradle = FindItemIdByNames(ITEM_NAME_CANDIDATES.EmptyCradle),
    BloodSkullGu = FindItemIdByNames(ITEM_NAME_CANDIDATES.BloodSkullGu),
    BossOrder = FindItemIdByNames(ITEM_NAME_CANDIDATES.BossOrder),
    BetweenDeathAndLife = FindItemIdByNames(ITEM_NAME_CANDIDATES.BetweenDeathAndLife),
    CoinSewnSword = FindItemIdByNames(ITEM_NAME_CANDIDATES.CoinSewnSword),
    CoinFacedMask = FindItemIdByNames(ITEM_NAME_CANDIDATES.CoinFacedMask),
    BlackTaisui = FindItemIdByNames(ITEM_NAME_CANDIDATES.BlackTaisui),
    MeatLump = FindItemIdByNames(ITEM_NAME_CANDIDATES.MeatLump),
    CleansedWavyCap = FindItemIdByNames(ITEM_NAME_CANDIDATES.CleansedWavyCap),
    GoodGirlOfBabylon = FindItemIdByNames(ITEM_NAME_CANDIDATES.GoodGirlOfBabylon),
    DebugController = FindItemIdByNames(ITEM_NAME_CANDIDATES.DebugController),
    StrongLaxative = FindItemIdByNames(ITEM_NAME_CANDIDATES.StrongLaxative),
    Needletick = FindItemIdByNames(ITEM_NAME_CANDIDATES.Needletick),
    Condom = FindItemIdByNames(ITEM_NAME_CANDIDATES.Condom),
    UtilityKnife = FindItemIdByNames(ITEM_NAME_CANDIDATES.UtilityKnife),
    DS4 = FindItemIdByNames(ITEM_NAME_CANDIDATES.DS4),
}

local DEBUG_PRINT_ITEM_IDS = true
local bloodSkullGuBacklashDepth = 0

local EID_DESCRIPTIONS = {
    [Items.EssentialBalm] = {
        en_us = {
            name = "Essential Balm",
            eidDescription = "{{Damage}} +1 damage#{{Shotspeed}} -0.2 shot speed",
        },
        zh_cn = {
            name = "风油精",
            eidDescription = "↑ +1攻击力#↓ -0.2弹速",
        },
    },
    [Items.Wuhu] = {
        en_us = {
            name = "Wuhu!",
            eidDescription = "{{Speed}} +1 speed#{{Tears}} Max fire rate#{{Damage}} +40 damage#{{Shotspeed}} -1 shot speed",
        },
        zh_cn = {
            name = "芜湖！~",
            eidDescription = "↑ +1移速#↑ 攻速上限达到30#↑ +40攻击力#↓ -1弹速",
        },
    },
    [Items.Chunyao] = {
        en_us = {
            name = "Aphrodisiac",
            eidDescription = "Spend 1 full heart without dying#{{Damage}} +0.5 damage#{{Tears}} +0.5 fire rate#Charm effect and homing tears for 3 seconds",
        },
        zh_cn = {
            name = "春药",
            eidDescription = "使用后扣除1滴完整的血#{{Warning}} 优先扣红心 #{{Warning}} 不致死#↑ +0.5攻击力#↑ +0.5攻速#角色进入魅惑状态#眼泪获得追踪效果#持续3秒",
        },
    },
    [Items.Musicbox] = {
        en_us = {
            name = "Music Box",
            eidDescription = "20 seconds of invincibility and red tears#{{Warning}} Death when the timer ends#Reuse does not extend time#When uncharged, blocks one lethal hit and triggers itself#Extra lives can save you",
        },
        zh_cn = {
            name = "八音盒",
            eidDescription = "使用后进入20秒无敌状态，眼泪变红并播放八音盒音乐#{{Warning}} 倒计时结束时强制死亡#第二次使用不会延长倒计时#未充能且受到致死伤害时，失去八音盒并自动触发一次#八音盒期间压制计划C的自杀死亡，但保留杀敌伤害#只有额外生命可以继续游戏",
        },
    },
    [Items.Angelbox] = {
        en_us = {
            name = "Angel Box",
            eidDescription = "{{Luck}} +3 Luck while held#First use converts red heart containers into full soul hearts#Overflow soul hearts recharge it#At full charge, forces an angel room this floor and adds 1 quality 4 angel item on first entry#Heart drops have a 60% chance to add a soul heart#Favors angel rooms while held",
        },
        zh_cn = {
            name = "天使盒",
            eidDescription = "持有时 {{Luck}} +3 幸运#每名玩家首次使用：每个红心容器生成1个完整魂心#之后只吸收装不下的魂心充能，满4格可再次使用#非首次使用：本层尽力必定开启天使房#若使用前本层未进入过天使房，该玩家使首次进入本层天使房时额外生成1个4级天使房道具#地上心掉落有60%额外生成1个完整魂心#持有时一半恶魔房概率转为天使房概率",
        },
    },
    [Items.Devilbox] = {
        en_us = {
            name = "Devil Box",
            eidDescription = "First use converts red heart containers into full black hearts#Overflow black hearts recharge it#At full charge, forces a devil room this floor and adds 1 quality 3 devil item on first entry#Heart drops have an 80% chance to add a black heart#Favors devil rooms while held",
        },
        zh_cn = {
            name = "恶魔盒",
            eidDescription = "每名玩家首次使用：每个红心容器生成1个完整黑心#之后只吸收装不下的黑心充能，满4格可再次使用#非首次使用：本层尽力必定开启恶魔房#若使用前本层未进入过恶魔房，该玩家使首次进入本层恶魔房时额外生成1个3级恶魔房道具#地上心掉落有80%额外生成1个黑心#持有时一半交易房方向转为恶魔房概率",
        },
    },
    [Items.UncutCord] = {
        en_us = {
            name = "Uncut Cord",
            eidDescription = "50% chance to delay incoming damage instead of taking it immediately#Clear 2 rooms without getting hit to take only half of the delayed damage#Getting hit again triggers the full delayed damage immediately",
        },
        zh_cn = {
            name = "未剪断的脐带",
            eidDescription = "受到伤害时，50%概率将本次伤害变为延迟伤害#连续通过2个房间且未再次受伤后，只承受一半延迟伤害#若期间再次受伤，立即承受全部延迟伤害",
        },
    },
    [Items.ShreddedTarot] = {
        en_us = {
            name = "Shredded Tarot",
            eidDescription = "{{Luck}} +3 Luck while held#Single-use active item#Removes card pickups in the current room#For every 3 cards removed, spawns 1 Treasure Room item#Not consumed if fewer than 3 cards are present#Empty use does not count; disappears after this floor if unused",
        },
        zh_cn = {
            name = "剪碎的塔罗",
            eidDescription = "持有时 {{Luck}} +3 幸运#一次性使用#移除当前房间内的地上卡牌#每移除3张卡牌，生成1个宝箱房道具#卡牌不足3张时不会消耗#空拍不算使用，本层结束仍会消失",
        },
    },
    [Items.BloodSkullGu] = {
        en_us = {
            name = "Blood Skull Gu",
            eidDescription = "3-charge active item#Sacrifice one familiar item you own#{{Damage}} Permanently gain +1.5 damage#{{Range}} Permanently gain +1 range#Drops 1-2 black hearts#If no familiar item can be sacrificed, take half a red heart of backlash damage instead",
        },
        zh_cn = {
            name = "血颅蛊",
            eidDescription = "3充能主动道具#献祭1个属于你的跟班类道具#{{Damage}} 永久 +1.5 攻击#{{Range}} 永久 +1 射程#掉落1-2个黑心#没有可献祭跟班类道具时，反噬并受到半颗红心伤害",
        },
    },
    [Items.BossOrder] = {
        en_us = {
            name = "Boss's Order",
            eidDescription = "Spawns a hostile target#Small enemies come from the current floor#Bosses come from the Boss Rush pool#Small enemies may become champions after spawning#Killing it drops cards: 1 normal, 2 champion, 3 boss",
        },
        zh_cn = {
            name = "老大的指令",
            eidDescription = "生成一个敌对目标#小怪来源于当前层小怪池#头目来源于Boss Rush池#小怪生成后有概率变为精英#击杀后掉落卡牌：普通1张，精英2张，头目3张",
        },
    },
    [Items.BetweenDeathAndLife] = {
        en_us = {
            name = "Between Death and Life",
            eidDescription = "On pickup, activates Death Trial for the rest of the run:#Enemies become champions whenever possible#Bosses are championed or empowered#Defeating each floor boss spawns Death Certificate#Once per floor",
        },
        zh_cn = {
            name = "生死一念间",
            eidDescription = "拾取后，本局进入死证试炼：#所有敌人尽可能变为精英怪#Boss也会被精英化或强化#每层击败楼层Boss后，生成一个死亡证明#每层最多触发一次",
        },
    },
    [Items.CoinSewnSword] = {
        en_us = {
            name = "Coin-Sewn Sword",
            eidDescription = "Spend up to 6 coins and fire that many coin sword qi in a 150-degree fan#Each qi deals your damage x2.0#Spending 6 coins also fires a piercing empowered qi that deals x6.0#With no coins, take half a red heart of damage and fire 1 blood qi that deals x4.0",
        },
        zh_cn = {
            name = "铜钱剑",
            eidDescription = "消耗至多6枚硬币，向前方150度释放等量铜钱剑气#每道剑气造成攻击力 x2.0 伤害#消耗满6枚时，额外释放造成 x6.0 伤害的贯穿剑气#没有硬币时，受到半红心伤害并释放1道造成 x4.0 伤害的血色剑气",
        },
    },
    [Items.CoinFacedMask] = {
        en_us = {
            name = "Coin-Faced Mask",
            eidDescription = "Enter a room with at least 5 coins to gain a mask#The mask disturbs enemies#When hit by a monster, spend 5 coins to block that hit#Without enough coins, the mask breaks and lowers luck for the room",
        },
        zh_cn = {
            name = "铜钱面具",
            eidDescription = "拥有至少5枚硬币时，进房获得假面#假面会扰乱敌人#被怪物伤害时消耗5枚硬币，免疫本次伤害#硬币不足时，假面破裂，本房间幸运下降",
        },
    },
    [Items.BlackTaisui] = {
        en_us = {
            name = "Black Taisui",
            eidDescription = "Feeds on blood to gain parasite value#0-7: heavy damage, speed, and luck penalties#8-15: reveals hidden items and suppresses Blind, Lost, Unknown, and Wavy Cap side effects#16+: inherits stage 2, grants fixed damage per copy, and creates Meat Lump once#Multiple copies share parasite value; Meat Lump still appears only once",
        },
        zh_cn = {
            name = "黑太岁",
            eidDescription = "以红心治疗、红心容器和红心伤害积累寄生值#0-7：大幅降低伤害、移速和幸运#8-15：揭示问号道具，免疫致盲/迷途/未知诅咒表现，并压制波浪帽副作用#16+：继承二阶段效果，每个黑太岁提供修正伤害，并生成一次肉块#多个黑太岁共享寄生值；阶段效果按规则叠加，但肉块只生成一次",
        },
    },
    [Items.MeatLump] = {
        en_us = {
            name = "Meat Lump",
            eidDescription = "Conditionally blocks one lethal hit from enemies#This item does not exist in any item pool",
        },
        zh_cn = {
            name = "肉块",
            eidDescription = "有条件抵挡一次来自敌人的致死伤害#这个道具不存在于任何道具池里",
        },
    },
    [Items.CleansedWavyCap] = {
        en_us = {
            name = "Cleansed Wavy Cap",
            eidDescription = "A Black Taisui-safe Wavy Cap#On use: {{Speed}} -0.03 speed, {{Tears}} +0.75 fire rate#Leaving the room converts this room's speed loss to x2 and fire-rate gain to x0.4#Clearing a room removes one use worth of lingering changes",
        },
        zh_cn = {
            name = "净化迷幻菇",
            eidDescription = "被黑太岁净化的迷幻蘑菇#使用后：{{Speed}} -0.03移速，{{Tears}} +0.75射速修正#离开房间时，本房间增减益转化：移速减益x2，射速增益x0.4#清理房间后，移除相当于1次使用的残留增减益",
        },
    },
    [Items.GoodGirlOfBabylon] = {
        en_us = {
            name = "Good Girl of Babylon",
            eidDescription = "At full red hearts, enter a presentable state:#{{Tears}} +0.6 tears#{{Luck}} +2 luck#Enemies may be charmed#Clearing a room without red heart damage may grant an extra reward#Taking red heart damage breaks the state:#{{Luck}} -2 luck for the room#Fears nearby enemies#Briefly gain an echo of Babylon",
        },
        zh_cn = {
            name = "巴比伦好女孩",
            eidDescription = "满红心时进入端正状态：#{{Tears}} +0.6射速#{{Luck}} +2幸运#敌人有概率被魅惑#无红心伤害清房时，可能获得额外奖励#受到红心伤害时端正破裂：#{{Luck}} 本房间幸运下降#恐惧附近敌人#短暂获得巴比伦回声",
        },
    },
    [Items.DebugController] = {
        en_us = {
            name = "Debug Controller",
            eidDescription = "Opens a directional debug command menu#Use again to close#Directional input selects entries instead of firing while open#Runs debug 1 through debug 10",
        },
        zh_cn = {
            name = "调试控制器",
            eidDescription = "打开四向调试命令菜单#再次使用关闭菜单#菜单打开时方向输入用于选择，不会发射眼泪#可执行 debug 1 至 debug 10",
        },
    },
    [Items.StrongLaxative] = {
        en_us = {
            name = "Strong Laxative",
            eidDescription = "All creep is treated as friendly#Leave slippery creep while moving#Slippery creep slows enemies and deals 10% of your damage every 10 frames#5% chance per second to spawn random poop#Up to 15 poops per room#Extra copies increase poop chance",
        },
        zh_cn = {
            name = "强力泻药",
            eidDescription = "所有水迹视为己方水迹#移动时留下打滑水迹#打滑水迹使敌人减速，并每10帧造成10%角色伤害#每秒5%概率生成随机大便#每个房间最多生成15个大便#多拿提高生成概率",
        },
    },
    [Items.Needletick] = {
        en_us = {
            name = "Needletick",
            eidDescription = "5% chance to fire a void needle tear#At 10 Luck: 15%#Void needle tears instantly kill nearby normal enemies",
        },
        zh_cn = {
            name = "虚空针尖",
            eidDescription = "5%概率发射虚空针尖泪弹#10幸运时：15%#虚空泪弹秒杀附近普通敌人",
        },
    },
    [Items.SterilizationCertificate] = {
        en_us = {
            name = "Sterilization Certificate",
            eidDescription = "Prevents spawning enemies from creating more enemies#Blocked spawns deal backlash damage to the source enemy#Boss summons are only partially weakened",
        },
        zh_cn = {
            name = "绝育证明",
            eidDescription = "阻止会生成敌人的敌人继续生成敌人#每次阻止生成时，对该敌人造成反噬伤害#Boss 召唤效果只会被部分削弱",
        },
    },
    [Items.Condom] = {
        en_us = {
            name = "Condom",
            eidDescription = "On use, randomly bans up to 2 future baby-tag items#Does not remove items you already own",
        },
        zh_cn = {
            name = "避孕套",
            eidDescription = "使用后，随机禁用最多2个未来可生成的宝宝标签道具#不会移除已经拥有的道具",
        },
    },
    [Items.UtilityKnife] = {
        en_us = {
            name = "Utility Knife",
            eidDescription = "{{Damage}} +1 damage#Gain 1 broken heart on pickup",
        },
        zh_cn = {
            name = "美工刀",
            eidDescription = "↑ +1攻击力#获得一颗碎心",
        },
    },
    [Items.EmptyCradle] = {
        en_us = {
            name = "Empty Cradle",
            eidDescription = "The first effective damage each floor remembers the lost heart type#Clear that room for a reward: red hearts give hearts, soul hearts give pickups, black hearts give floor damage#Taking another hit before the room is clear downgrades the reward#Black-heart damage bonuses last for this floor only",
        },
        zh_cn = {
            name = "空摇篮",
            eidDescription = "每层第一次有效受伤会记录损失的心形类型#清理当前房间后获得对应奖励：红心给心，魂心给资源，黑心给本层攻击力#清房前再次受伤会降为基础奖励#黑心奖励的攻击力加成换层清除",
        },
    },
    [Items.DS4] = {
        en_us = {
            name = "ds4",
            eidDescription = "{{Warning}} Effect not implemented yet",
        },
        zh_cn = {
            name = "ds4",
            eidDescription = "{{Warning}} 效果尚未实现",
        },
    },
}

local EID_LANGUAGE_ORDER = { "en_us", "zh_cn" }

local function IsValidItemId(id)
    if id == nil then
        return false
    end

    if type(id) == "number" then
        return id > 0
    end

    return true
end

local eidDescriptionsRegistered = false

local function RegisterEIDDescriptions()
    if eidDescriptionsRegistered or not EID or type(EID.addCollectible) ~= "function" then
        return false
    end

    local previousMod = EID._currentMod
    if EID._currentMod ~= nil then
        EID._currentMod = "neverbirth"
    end
    if EID.ModIndicator and not EID.ModIndicator.neverbirth then
        EID.ModIndicator.neverbirth = { Name = "neverbirth", Icon = nil }
    end

    for id, item in pairs(EID_DESCRIPTIONS) do
        if IsValidItemId(id) then
            for _, language in ipairs(EID_LANGUAGE_ORDER) do
                local localizedText = item[language] or item.en_us
                if localizedText then
                    EID:addCollectible(id, localizedText.eidDescription, localizedText.name, language)
                end
            end
        end
    end

    if previousMod ~= nil then
        EID._currentMod = previousMod
    end

    eidDescriptionsRegistered = true
    return true
end

local function DebugLog(message)
    if Isaac.DebugString then
        Isaac.DebugString(message)
    elseif print then
        print(message)
    end
end

RegisterEIDDescriptions()

function Neverbirth:TryRegisterEIDDescriptions()
    if RegisterEIDDescriptions() then
        DebugLog("[neverbirth] EID descriptions registered")
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TryRegisterEIDDescriptions)

local function PrintItemDebugCommands()
    if not DEBUG_PRINT_ITEM_IDS then
        return
    end

    DebugLog("[neverbirth] Mod item console commands:")
    for itemKey, itemId in pairs(Items) do
        if IsValidItemId(itemId) then
            DebugLog("[neverbirth] " .. itemKey .. " id=" .. tostring(itemId) .. " | giveitem c" .. tostring(itemId) .. " | spawn 5.100." .. tostring(itemId))
        else
            DebugLog("[neverbirth] " .. itemKey .. " id not found")
        end
    end
end

PrintItemDebugCommands()

local function GetPlayers()
    local players = {}

    if Game and Isaac.GetPlayer then
        local gameOk, game = pcall(Game)
        if gameOk and game and game.GetNumPlayers then
            local countOk, playerCount = pcall(function()
                return game:GetNumPlayers()
            end)
            playerCount = countOk and tonumber(playerCount) or 0

            for index = 0, playerCount - 1 do
                local playerOk, player = pcall(function()
                    return Isaac.GetPlayer(index)
                end)
                if playerOk and player then
                    if player.ToPlayer then
                        local toPlayerOk, convertedPlayer = pcall(function()
                            return player:ToPlayer()
                        end)
                        player = toPlayerOk and convertedPlayer or player
                    end

                    if player then
                        players[#players + 1] = player
                    end
                end
            end

            if #players > 0 then
                return players
            end
        end
    end

    if Isaac.FindByType then
        for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PLAYER, -1, -1, false, false)) do
            local player = entity and entity.ToPlayer and entity:ToPlayer()
            if player then
                players[#players + 1] = player
            end
        end
    end

    return players
end

--------------------------------------------------
-- Debug Controller

Neverbirth.DebugController = {
    anm2 = "gfx/UI/DebugController/DebugControllerKeys.anm2",
    states = {},
    sprites = {},
    directions = { "left", "up", "right", "down" },
    offsets = {
        left = Vector(-24, 0),
        up = Vector(0, -24),
        right = Vector(24, 0),
        down = Vector(0, 24),
    },
    actions = {
        left = { "ACTION_SHOOTLEFT", "ACTION_LEFT" },
        up = { "ACTION_SHOOTUP", "ACTION_UP" },
        right = { "ACTION_SHOOTRIGHT", "ACTION_RIGHT" },
        down = { "ACTION_SHOOTDOWN", "ACTION_DOWN" },
    },
    layouts = {
        root = {
            left = { page = "left", animation = "Left", label = "<" },
            up = { page = "up", animation = "Up", label = "^" },
            right = { page = "right", animation = "Right", label = ">" },
            down = { page = "down", animation = "Down", label = "v" },
        },
        left = {
            down = { command = 1, animation = "Num1", label = "1" },
            left = { command = 2, animation = "Num2", label = "2" },
            up = { command = 3, animation = "Num3", label = "3" },
            right = { page = "root", animation = "Back", label = "B" },
        },
        up = {
            down = { page = "root", animation = "Back", label = "B" },
            left = { command = 4, animation = "Num4", label = "4" },
            up = { command = 5, animation = "Num5", label = "5" },
            right = { command = 6, animation = "Num6", label = "6" },
        },
        right = {
            left = { page = "root", animation = "Back", label = "B" },
            up = { command = 7, animation = "Num7", label = "7" },
            right = { command = 8, animation = "Num8", label = "8" },
            down = { command = 9, animation = "Num9", label = "9" },
        },
        down = {
            up = { page = "root", animation = "Back", label = "B" },
            down = { command = 10, animation = "Num10", label = "10" },
        },
    },
}

function Neverbirth.DebugController.GetPlayerKey(player)
    return tostring((player and player.InitSeed) or "0")
end

function Neverbirth.DebugController.IsPlayerDead(player)
    if not player then
        return true
    end

    if player.IsDead then
        local ok, result = pcall(function()
            return player:IsDead()
        end)
        if ok then
            return result == true
        end
    end

    return player.dead == true or player.Dead == true
end

function Neverbirth.DebugController.PlayerHasItem(player)
    if not player or not IsValidItemId(Items.DebugController) then
        return false
    end

    if player.HasCollectible then
        local ok, hasItem = pcall(function()
            return player:HasCollectible(Items.DebugController)
        end)
        if ok and hasItem then
            return true
        end
    end

    if player.GetActiveItem then
        for slot = 0, 3 do
            local ok, activeItem = pcall(function()
                return player:GetActiveItem(slot)
            end)
            if ok and activeItem == Items.DebugController then
                return true
            end
        end
    end

    return false
end

function Neverbirth.DebugController.Close(player)
    Neverbirth.DebugController.states[Neverbirth.DebugController.GetPlayerKey(player)] = nil
end

function Neverbirth.DebugController.IsOpen(player)
    return Neverbirth.DebugController.states[Neverbirth.DebugController.GetPlayerKey(player)] ~= nil
end

function Neverbirth.DebugController.Open(player)
    Neverbirth.DebugController.states[Neverbirth.DebugController.GetPlayerKey(player)] = {
        player = player,
        page = "root",
        previous = {},
    }
end

function Neverbirth.DebugController.GetCommand(number)
    return "debug " .. tostring(number)
end

function Neverbirth.DebugController.ExecuteCommand(number)
    if Isaac and Isaac.ExecuteCommand then
        local command = Neverbirth.DebugController.GetCommand(number)
        pcall(function()
            Isaac.ExecuteCommand(command)
        end)
    end
end

function Neverbirth.DebugController.GetControllerIndex(player)
    if not player then
        return 0
    end
    return player.ControllerIndex or player.ControllerId or player.Controller or 0
end

function Neverbirth.DebugController.IsDirectionPressed(player, direction)
    if not (Input and Input.IsActionPressed and ButtonAction) then
        return false
    end

    local controllerIndex = Neverbirth.DebugController.GetControllerIndex(player)
    for _, actionName in ipairs(Neverbirth.DebugController.actions[direction] or {}) do
        local action = ButtonAction[actionName]
        if action ~= nil then
            local ok, pressed = pcall(function()
                return Input.IsActionPressed(action, controllerIndex)
            end)
            if ok and pressed then
                return true
            end
        end
    end

    return false
end

function Neverbirth.DebugController.HandleDirection(player, state, direction)
    local page = state.page or "root"
    local entry = Neverbirth.DebugController.layouts[page] and Neverbirth.DebugController.layouts[page][direction]
    if not entry then
        return
    end

    if entry.page then
        state.page = entry.page
        return
    end

    if entry.command then
        Neverbirth.DebugController.ExecuteCommand(entry.command)
        Neverbirth.DebugController.Close(player)
    end
end

function Neverbirth.DebugController.GetSprite(animation)
    if not Sprite then
        return nil
    end

    local sprite = Neverbirth.DebugController.sprites[animation]
    if sprite then
        return sprite
    end

    local ok, newSprite = pcall(function()
        return Sprite()
    end)
    if not ok or not newSprite then
        return nil
    end

    if newSprite.Load then
        pcall(function()
            newSprite:Load(Neverbirth.DebugController.anm2, true)
        end)
    end
    if newSprite.Play then
        pcall(function()
            newSprite:Play(animation, true)
        end)
    end

    Neverbirth.DebugController.sprites[animation] = newSprite
    return newSprite
end

function Neverbirth.DebugController.RenderIcon(entry, position)
    local animation = entry.animation
    local sprite = animation and Neverbirth.DebugController.GetSprite(animation)
    if sprite and sprite.Render then
        pcall(function()
            if sprite.Play then
                sprite:Play(animation, true)
            end
            sprite:Render(position)
        end)
        return
    end

    if Isaac and Isaac.RenderText then
        Isaac.RenderText(entry.label or "?", position.X - 4, position.Y - 4, 1, 1, 1, 1)
    end
end

function Neverbirth:UseDebugController(_, _, player)
    if not player then
        return { Discharge = false, Remove = false, ShowAnim = true }
    end

    if Neverbirth.DebugController.IsOpen(player) then
        Neverbirth.DebugController.Close(player)
    else
        Neverbirth.DebugController.Open(player)
    end

    return { Discharge = false, Remove = false, ShowAnim = true }
end

function Neverbirth:UpdateDebugControllerMenus()
    for key, state in pairs(Neverbirth.DebugController.states) do
        local player = state.player
        if not player or Neverbirth.DebugController.IsPlayerDead(player) or not Neverbirth.DebugController.PlayerHasItem(player) then
            Neverbirth.DebugController.states[key] = nil
        else
            state.previous = state.previous or {}
            for _, direction in ipairs(Neverbirth.DebugController.directions) do
                local pressed = Neverbirth.DebugController.IsDirectionPressed(player, direction)
                if pressed and not state.previous[direction] then
                    Neverbirth.DebugController.HandleDirection(player, state, direction)
                    if not Neverbirth.DebugController.states[key] then
                        break
                    end
                end
                state.previous[direction] = pressed
            end
        end
    end
end

function Neverbirth:RenderDebugControllerMenus()
    if not (Isaac and Isaac.WorldToScreen) then
        return
    end

    for _, state in pairs(Neverbirth.DebugController.states) do
        local player = state.player
        if player and player.Position then
            local base = Isaac.WorldToScreen(player.Position + Vector(0, -54))
            local layout = Neverbirth.DebugController.layouts[state.page or "root"] or Neverbirth.DebugController.layouts.root
            for direction, entry in pairs(layout) do
                local offset = Neverbirth.DebugController.offsets[direction] or Vector(0, 0)
                Neverbirth.DebugController.RenderIcon(entry, base + offset)
            end
        end
    end
end

function Neverbirth:SuppressDebugControllerTear(tear)
    if not tear then
        return
    end

    local spawner = tear.SpawnerEntity or tear.Spawner or tear.Parent
    local player = spawner
    if player and player.ToPlayer then
        local ok, converted = pcall(function()
            return player:ToPlayer()
        end)
        player = ok and converted or player
    end

    if player and Neverbirth.DebugController.IsOpen(player) then
        if tear.Remove then
            pcall(function()
                tear:Remove()
            end)
        end
    end
end

function Neverbirth:CloseDebugControllerMenus()
    Neverbirth.DebugController.states = {}
end

--------------------------------------------------
-- 虚空针尖

Neverbirth.NeedletickRadius = 80
Neverbirth.NeedletickDataKey = "NeverbirthNeedletickTear"
Neverbirth.NeedletickResolvedKey = "NeverbirthNeedletickResolved"
Neverbirth.NeedletickBaseChance = 0.05
Neverbirth.NeedletickMaxChance = 0.15
Neverbirth.NeedletickLuckCap = 10
Neverbirth.NeedletickKillDamage = 999999
Neverbirth.NeedletickTearEntityName = "Needletick Tear"
Neverbirth.NeedletickTearVariant = nil
Neverbirth.NeedletickImpactEffectVariant = (EffectVariant and EffectVariant.POOF01) or 1
Neverbirth.NeedletickTearAnimation = "RegularTear6"
Neverbirth.NeedletickVisualSpriteScale = 1.6

function Neverbirth.NeedletickPcallBoolean(entity, methodName)
    if not entity or not entity[methodName] then
        return false
    end

    local ok, result = pcall(function()
        return entity[methodName](entity)
    end)
    return ok and result == true
end

function Neverbirth.GetNeedletickTearData(tear)
    if tear and tear.GetData then
        local ok, data = pcall(function()
            return tear:GetData()
        end)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

function Neverbirth.GetNeedletickPlayerFromTear(tear)
    local spawner = tear and (tear.SpawnerEntity or tear.Spawner or tear.Parent)
    local player = spawner
    if player and player.ToPlayer then
        local ok, converted = pcall(function()
            return player:ToPlayer()
        end)
        if ok and converted then
            player = converted
        end
    end

    if player and player.GetCollectibleNum then
        return player
    end

    return nil
end

function Neverbirth.NeedletickPlayerHasItem(player)
    if not player or not IsValidItemId(Items.Needletick) then
        return false
    end

    if player.HasCollectible then
        local ok, result = pcall(function()
            return player:HasCollectible(Items.Needletick)
        end)
        if ok then
            return result == true
        end
    end

    if player.GetCollectibleNum then
        local ok, count = pcall(function()
            return player:GetCollectibleNum(Items.Needletick)
        end)
        return ok and (tonumber(count) or 0) > 0
    end

    return false
end

function Neverbirth.GetNeedletickRandomFloat(player)
    if player and player.GetCollectibleRNG and IsValidItemId(Items.Needletick) then
        local ok, rng = pcall(function()
            return player:GetCollectibleRNG(Items.Needletick)
        end)
        if ok and rng then
            if rng.RandomFloat then
                local rollOk, value = pcall(function()
                    return rng:RandomFloat()
                end)
                if rollOk and value ~= nil then
                    return math.max(0, math.min(1, tonumber(value) or 0))
                end
            elseif rng.RandomInt then
                local rollOk, value = pcall(function()
                    return rng:RandomInt(1000000)
                end)
                if rollOk and value ~= nil then
                    return math.max(0, math.min(999999, tonumber(value) or 0)) / 1000000
                end
            end
        end
    end

    return math.random()
end

function Neverbirth.NeedletickDistance(a, b)
    if not a or not b then
        return nil
    end

    if a.X and b.X and a.Y and b.Y then
        local dx = a.X - b.X
        local dy = a.Y - b.Y
        return math.sqrt(dx * dx + dy * dy)
    end

    local ok, delta = pcall(function()
        return a - b
    end)
    if ok and delta and delta.Length then
        local lengthOk, length = pcall(function()
            return delta:Length()
        end)
        if lengthOk then
            return tonumber(length) or nil
        end
    end

    return nil
end

function Neverbirth.GetNeedletickChance(luck)
    local value = tonumber(luck) or 0
    local scaled = Neverbirth.NeedletickBaseChance + ((math.max(0, value) / Neverbirth.NeedletickLuckCap) * (Neverbirth.NeedletickMaxChance - Neverbirth.NeedletickBaseChance))
    return math.max(Neverbirth.NeedletickBaseChance, math.min(Neverbirth.NeedletickMaxChance, scaled))
end

function Neverbirth:GetNeedletickTearVariant()
    if Neverbirth.NeedletickTearVariant ~= nil then
        return Neverbirth.NeedletickTearVariant
    end

    Neverbirth.NeedletickTearVariant = -1
    if Isaac and Isaac.GetEntityVariantByName then
        local ok, variant = pcall(function()
            return Isaac.GetEntityVariantByName(Neverbirth.NeedletickTearEntityName)
        end)
        if ok and type(variant) == "number" and variant > 0 then
            Neverbirth.NeedletickTearVariant = variant
        end
    end

    return Neverbirth.NeedletickTearVariant
end

function Neverbirth:IsNeedletickTear(tear)
    local data = Neverbirth.GetNeedletickTearData(tear)
    return data and data[Neverbirth.NeedletickDataKey] == true
end

function Neverbirth:CanNeedletickKillEntity(entity)
    if not entity or entity.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) then
        return false
    end
    if entity.ToPlayer then
        local ok, player = pcall(function()
            return entity:ToPlayer()
        end)
        if ok and player then
            return false
        end
    end
    if entity.IsVulnerableEnemy then
        local ok, vulnerable = pcall(function()
            return entity:IsVulnerableEnemy()
        end)
        if ok and vulnerable ~= true then
            return false
        end
    end
    if Neverbirth.NeedletickPcallBoolean(entity, "IsInvincible") or Neverbirth.NeedletickPcallBoolean(entity, "IsInvulnerable") then
        return false
    end
    if entity.HasEntityFlags and EntityFlag then
        local friendlyFlag = EntityFlag.FLAG_FRIENDLY or 0
        local charmFlag = EntityFlag.FLAG_CHARM or 0
        local ok, hasFriendly = pcall(function()
            return entity:HasEntityFlags(friendlyFlag)
        end)
        if ok and hasFriendly then
            return false
        end
        ok, hasFriendly = pcall(function()
            return entity:HasEntityFlags(charmFlag)
        end)
        if ok and hasFriendly then
            return false
        end
    end

    local npc = entity
    if entity.ToNPC then
        local ok, converted = pcall(function()
            return entity:ToNPC()
        end)
        if ok and converted then
            npc = converted
        end
    end
    if Neverbirth.NeedletickPcallBoolean(npc, "IsBoss") or Neverbirth.NeedletickPcallBoolean(npc, "IsChampion") then
        return false
    end

    return true
end

function Neverbirth:KillNeedletickTarget(entity, source)
    if entity.TakeDamage then
        local flags = (DamageFlag and (DamageFlag.DAMAGE_IGNORE_ARMOR or DamageFlag.DAMAGE_INVINCIBLE)) or 0
        local ref = source and EntityRef and EntityRef(source) or nil
        local damage = (tonumber(entity.HitPoints) or tonumber(entity.MaxHitPoints) or Neverbirth.NeedletickKillDamage) + 999
        local ok = pcall(function()
            entity:TakeDamage(damage, flags, ref, 0)
        end)
        if ok then
            return true
        end
    end

    if entity.Die then
        local ok = pcall(function()
            entity:Die()
        end)
        if ok then
            return true
        end
    end

    return false
end

function Neverbirth:ApplyNeedletickTearVariant(tear)
    if not tear or not tear.ChangeVariant then
        return false
    end

    local variant = Neverbirth:GetNeedletickTearVariant()
    if not variant or variant <= 0 then
        return false
    end

    local ok = pcall(function()
        tear:ChangeVariant(variant)
    end)
    if ok then
        Neverbirth:PlayNeedletickTearAnimation(tear, true)
        Neverbirth:ApplyNeedletickTearVisuals(tear)
    end
    return ok
end

function Neverbirth:ApplyNeedletickTearVisuals(tear)
    if not tear then
        return
    end

    local velocity = tear.Velocity
    if velocity then
        if velocity.GetAngleDegrees then
            pcall(function()
                tear.SpriteRotation = velocity:GetAngleDegrees()
            end)
        elseif velocity.X and velocity.Y then
            pcall(function()
                tear.SpriteRotation = math.deg(math.atan(velocity.Y, velocity.X))
            end)
        end
    end

    if Vector then
        pcall(function()
            tear.SpriteScale = Vector(Neverbirth.NeedletickVisualSpriteScale, Neverbirth.NeedletickVisualSpriteScale)
        end)
    end
end

function Neverbirth:PlayNeedletickTearAnimation(tear, force)
    if not tear or not tear.GetSprite then
        return false
    end

    local spriteOk, sprite = pcall(function()
        return tear:GetSprite()
    end)
    if not spriteOk or not sprite or not sprite.Play then
        return false
    end

    local ok = pcall(function()
        sprite:Play(Neverbirth.NeedletickTearAnimation, force == true)
    end)
    return ok
end

function Neverbirth:SpawnNeedletickImpactEffect(position, source)
    if not (Isaac and Isaac.Spawn and position) then
        return nil
    end

    local effect = Isaac.Spawn((EntityType and EntityType.ENTITY_EFFECT) or 1000, Neverbirth.NeedletickImpactEffectVariant, 0, position, Vector(0, 0), source)
    if effect and effect.SetColor and Color then
        pcall(function()
            effect:SetColor(Color(0.55, 0.05, 0.9, 1, 0.08, 0, 0.18), 18, 1, false, false)
        end)
    end
    return effect
end

function Neverbirth:MarkNeedletickTearOnFire(tear)
    local player = Neverbirth.GetNeedletickPlayerFromTear(tear)
    if not Neverbirth.NeedletickPlayerHasItem(player) then
        return
    end

    local chance = Neverbirth.GetNeedletickChance(player.Luck)
    if Neverbirth.GetNeedletickRandomFloat(player) >= chance then
        return
    end

    local data = Neverbirth.GetNeedletickTearData(tear)
    if data then
        data[Neverbirth.NeedletickDataKey] = true
    end
    Neverbirth:ApplyNeedletickTearVariant(tear)
end

function Neverbirth:ResolveNeedletickImpact(tear, position)
    local data = Neverbirth.GetNeedletickTearData(tear)
    if not data or data[Neverbirth.NeedletickDataKey] ~= true or data[Neverbirth.NeedletickResolvedKey] == true then
        return 0
    end

    local origin = position or tear.Position
    if not origin or not Isaac.GetRoomEntities then
        return 0
    end

    data[Neverbirth.NeedletickResolvedKey] = true
    local killed = 0
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity and entity.Position and Neverbirth:CanNeedletickKillEntity(entity) then
            local distance = Neverbirth.NeedletickDistance(entity.Position, origin)
            if distance and distance <= Neverbirth.NeedletickRadius and Neverbirth:KillNeedletickTarget(entity, tear) then
                killed = killed + 1
            end
        end
    end
    if killed > 0 then
        Neverbirth:SpawnNeedletickImpactEffect(origin, tear)
    end

    return killed
end

function Neverbirth:HandleNeedletickTearCollision(tear, collider)
    if not Neverbirth:IsNeedletickTear(tear) or not collider or collider.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) then
        return nil
    end

    if collider.IsVulnerableEnemy or collider.ToNPC then
        Neverbirth:ResolveNeedletickImpact(tear, collider.Position or tear.Position)
    end

    return nil
end

function Neverbirth:UpdateNeedletickTear(tear)
    if not Neverbirth:IsNeedletickTear(tear) then
        return
    end
    Neverbirth:PlayNeedletickTearAnimation(tear, false)
    Neverbirth:ApplyNeedletickTearVisuals(tear)

    if tear.IsDead then
        local ok, dead = pcall(function()
            return tear:IsDead()
        end)
        if ok and dead then
            Neverbirth:ResolveNeedletickImpact(tear, tear.Position)
        end
    end
end

if ModCallbacks.MC_POST_FIRE_TEAR then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, Neverbirth.MarkNeedletickTearOnFire)
end

if ModCallbacks.MC_PRE_TEAR_COLLISION then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, Neverbirth.HandleNeedletickTearCollision)
end

if ModCallbacks.MC_POST_TEAR_UPDATE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, Neverbirth.UpdateNeedletickTear)
end

--------------------------------------------------
-- 风油精

function Neverbirth:EvaluateEssentialBalm(player, cacheFlag)
    local itemCount = player:GetCollectibleNum(Items.EssentialBalm)
    if itemCount <= 0 then
        return
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 1 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed - 0.2 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color(0.2, 1.0, 0.2, 1.0)
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateEssentialBalm)

--------------------------------------------------
-- 芜湖

function Neverbirth:EvaluateWuhu(player, cacheFlag)
    local itemCount = player:GetCollectibleNum(Items.Wuhu)
    if itemCount <= 0 then
        return
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + 40 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed - 1 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed + 1 * itemCount
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color()
    end

    player.MaxFireDelay = 0
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateWuhu)

--------------------------------------------------
-- 春药

local chunyaoEffects = {}

function Neverbirth:UseChunyao(_, _, player)
    if player:GetActiveCharge() < 1 then
        return false
    end

    player:DischargeActiveItem(1)
    player:TakeDamage(
        1,
        DamageFlag.DAMAGE_RED_HEARTS | DamageFlag.DAMAGE_NOKILL | DamageFlag.DAMAGE_INVINCIBLE,
        EntityRef(player),
        0
    )

    local effects = chunyaoEffects[player.InitSeed] or {}
    effects[#effects + 1] = {
        damageBonus = 0.5,
        fireRateBonus = 0.5,
        timer = 90,
    }
    chunyaoEffects[player.InitSeed] = effects

    player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG)
    player:EvaluateItems()

    player:AddEntityFlags(EntityFlag.FLAG_CHARM)
    player.TearColor = Color(1, 0, 1, 1, 0, 0, 0)
    player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING

    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseChunyao, Items.Chunyao)

function Neverbirth:UpdateChunyaoEffects()
    for _, player in ipairs(GetPlayers()) do
        if player then
            local effects = chunyaoEffects[player.InitSeed]

            if effects then
                for i = #effects, 1, -1 do
                    effects[i].timer = effects[i].timer - 1

                    if effects[i].timer <= 0 then
                        table.remove(effects, i)
                    end
                end

                if #effects == 0 then
                    chunyaoEffects[player.InitSeed] = nil
                    player:ClearEntityFlags(EntityFlag.FLAG_CHARM)
                    player.TearColor = Color.Default
                    player.TearFlags = player.TearFlags & ~TearFlags.TEAR_HOMING
                end

                player:AddCacheFlags(CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARCOLOR | CacheFlag.CACHE_TEARFLAG)
                player:EvaluateItems()
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateChunyaoEffects)

function Neverbirth:EvaluateChunyao(player, cacheFlag)
    local effects = chunyaoEffects[player.InitSeed]
    if not effects then
        return
    end

    local totalDamageBonus = 0
    local totalFireRateBonus = 0

    for _, effect in ipairs(effects) do
        totalDamageBonus = totalDamageBonus + effect.damageBonus
        totalFireRateBonus = totalFireRateBonus + effect.fireRateBonus
    end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + totalDamageBonus
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay - totalFireRateBonus
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = Color(1, 0, 1, 1, 0, 0, 0)
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_HOMING
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateChunyao)

--------------------------------------------------
-- 八音盒

local json = require("json")

local MUSICBOX_THEME_NAME = "MusicboxTheme"
local MUSICBOX_DURATION = 20 * 30
local MUSICBOX_MAX_CHARGE = 12
local PLAN_C_ID = (CollectibleType and CollectibleType.COLLECTIBLE_PLAN_C) or 475
local MUSICBOX_PLAN_C_DAMAGE = 9999999
local MUSICBOX_PLAN_C_DELAY = 3 * 30
local MUSICBOX_TEAR_COLOR = Color(1, 0, 0, 1, 0, 0, 0)
local MUSICBOX_COUNTDOWN_OFFSET = Vector(0, -45)
local MUSICBOX_ACTIVE_SLOTS = {
    ActiveSlot.SLOT_PRIMARY,
    ActiveSlot.SLOT_SECONDARY,
}

local musicboxEffects = {}
local musicboxPlanCDeaths = {}
local musicboxSaveData = nil
local musicboxDataLoaded = false
local musicboxThemeId = nil
local musicboxPreviousMusicId = nil
local musicboxMusicStarted = false
local musicboxMissingThemeLogged = false

local function IsValidMusicId(musicId)
    return type(musicId) == "number" and musicId > 0
end

local function GetMusicboxThemeId()
    if musicboxThemeId == nil then
        musicboxThemeId = Isaac.GetMusicIdByName(MUSICBOX_THEME_NAME)
    end

    if IsValidMusicId(musicboxThemeId) then
        return musicboxThemeId
    end

    if not musicboxMissingThemeLogged then
        DebugLog("[neverbirth] MusicboxTheme music id not found")
        musicboxMissingThemeLogged = true
    end

    return nil
end

local function HasActiveMusicboxEffect()
    for _, effect in pairs(musicboxEffects) do
        if effect.timer > 0 then
            return true
        end
    end

    return false
end

local function GetCurrentRunSeed()
    if not Game then
        return "unknown"
    end

    local ok, game = pcall(Game)
    if not ok or not game or not game.GetSeeds then
        return "unknown"
    end

    local seeds = game:GetSeeds()
    if not seeds then
        return "unknown"
    end

    if seeds.GetStartSeedString then
        return seeds:GetStartSeedString()
    end

    if seeds.GetStartSeed then
        return tostring(seeds:GetStartSeed())
    end

    return "unknown"
end

local function EnsureMusicboxDataLoaded()
    if musicboxDataLoaded then
        return
    end

    musicboxDataLoaded = true
    musicboxSaveData = {}

    if Neverbirth.HasData and Neverbirth:HasData() then
        local ok, decoded = pcall(json.decode, Neverbirth:LoadData())
        if ok and type(decoded) == "table" then
            musicboxSaveData = decoded
        end
    end

    if type(musicboxSaveData.musicboxDeathDebt) ~= "table" then
        musicboxSaveData.musicboxDeathDebt = {}
    end

    if type(musicboxSaveData.musicboxDeathDebt.debts) ~= "table" then
        musicboxSaveData.musicboxDeathDebt.debts = {}
    end

    if type(musicboxSaveData.angelbox) ~= "table" then
        musicboxSaveData.angelbox = {}
    end

    if type(musicboxSaveData.angelbox.players) ~= "table" then
        musicboxSaveData.angelbox.players = {}
    end

    if type(musicboxSaveData.angelbox.pendingRewards) ~= "table" then
        musicboxSaveData.angelbox.pendingRewards = {}
    end

    if type(musicboxSaveData.angelbox.enteredAngelFloors) ~= "table" then
        musicboxSaveData.angelbox.enteredAngelFloors = {}
    end

    if type(musicboxSaveData.angelbox.appliedChanceFloors) ~= "table" then
        musicboxSaveData.angelbox.appliedChanceFloors = {}
    end

    if type(musicboxSaveData.angelbox.forcedAngelFloors) ~= "table" then
        musicboxSaveData.angelbox.forcedAngelFloors = {}
    end

    if type(musicboxSaveData.devilbox) ~= "table" then
        musicboxSaveData.devilbox = {}
    end

    if type(musicboxSaveData.devilbox.players) ~= "table" then
        musicboxSaveData.devilbox.players = {}
    end

    if type(musicboxSaveData.devilbox.pendingRewards) ~= "table" then
        musicboxSaveData.devilbox.pendingRewards = {}
    end

    if type(musicboxSaveData.devilbox.enteredDevilFloors) ~= "table" then
        musicboxSaveData.devilbox.enteredDevilFloors = {}
    end

    if type(musicboxSaveData.devilbox.appliedChanceFloors) ~= "table" then
        musicboxSaveData.devilbox.appliedChanceFloors = {}
    end

    if type(musicboxSaveData.devilbox.forcedDevilFloors) ~= "table" then
        musicboxSaveData.devilbox.forcedDevilFloors = {}
    end

    if type(musicboxSaveData.deathTrial) ~= "table" then
        musicboxSaveData.deathTrial = {}
    end

    if type(musicboxSaveData.deathTrial.spawnedByFloor) ~= "table" then
        musicboxSaveData.deathTrial.spawnedByFloor = {}
    end

    if type(musicboxSaveData.deathTrial.preActivationBossClearedFloors) ~= "table" then
        musicboxSaveData.deathTrial.preActivationBossClearedFloors = {}
    end

    if type(musicboxSaveData.diceSet) ~= "table" then
        musicboxSaveData.diceSet = {}
    end

    if type(musicboxSaveData.diceSet.players) ~= "table" then
        musicboxSaveData.diceSet.players = {}
    end

    if type(musicboxSaveData.condom) ~= "table" then
        musicboxSaveData.condom = {}
    end

    if type(musicboxSaveData.condom.banned) ~= "table" then
        musicboxSaveData.condom.banned = {}
    end

    if type(musicboxSaveData.utilityKnife) ~= "table" then
        musicboxSaveData.utilityKnife = {}
    end

    if type(musicboxSaveData.utilityKnife.players) ~= "table" then
        musicboxSaveData.utilityKnife.players = {}
    end

    if type(musicboxSaveData.blackTaisui) ~= "table" then
        musicboxSaveData.blackTaisui = {}
    end

    if type(musicboxSaveData.blackTaisui.players) ~= "table" then
        musicboxSaveData.blackTaisui.players = {}
    end
end

local function SaveMusicboxData()
    EnsureMusicboxDataLoaded()

    if not Neverbirth.SaveData then
        return
    end

    local ok, encoded = pcall(json.encode, musicboxSaveData)
    if ok then
        Neverbirth:SaveData(encoded)
    else
        DebugLog("[neverbirth] Failed to save Musicbox data: " .. tostring(encoded))
    end
end

local function GetMusicboxDebtTable()
    EnsureMusicboxDataLoaded()
    return musicboxSaveData.musicboxDeathDebt.debts
end

local function GetAngelboxData()
    EnsureMusicboxDataLoaded()
    return musicboxSaveData.angelbox
end

local function GetDevilboxData()
    EnsureMusicboxDataLoaded()
    return musicboxSaveData.devilbox
end

local function ResetDeathTrialDataForRun()
    EnsureMusicboxDataLoaded()
    musicboxSaveData.deathTrial = {
        active = false,
        runSeed = GetCurrentRunSeed(),
        activatedFloorKey = nil,
        activatedRoomKey = nil,
        spawnedByFloor = {},
        preActivationBossClearedFloors = {},
    }
    return musicboxSaveData.deathTrial
end

local function GetDeathTrialData()
    EnsureMusicboxDataLoaded()

    local data = musicboxSaveData.deathTrial
    if type(data) ~= "table" or data.runSeed ~= GetCurrentRunSeed() then
        data = ResetDeathTrialDataForRun()
    end

    if type(data.spawnedByFloor) ~= "table" then
        data.spawnedByFloor = {}
    end

    if type(data.preActivationBossClearedFloors) ~= "table" then
        data.preActivationBossClearedFloors = {}
    end

    return data
end

--------------------------------------------------
-- 骰子套装

do
local DICE_SET_REQUIRED_UNIQUE_ITEMS = 3
local DICE_SET_ACTIVE_ITEM_TYPE = (ItemType and ItemType.ITEM_ACTIVE) or 3
local DICE_SET_D7_FALLBACK_ID = 437
local DICE_SET_D1_FALLBACK_ID = 476
local DICE_SET_ACTIVE_SLOTS = {
    ActiveSlot.SLOT_PRIMARY,
    ActiveSlot.SLOT_SECONDARY,
    ActiveSlot.SLOT_POCKET,
    ActiveSlot.SLOT_POCKET2,
}
local DICE_SET_NAME_KEYWORDS = {
    "Dice",
    "Die",
    "D1",
    "D6",
    "D7",
    "D8",
    "D10",
    "D12",
    "D20",
    "D100",
    "骰",
    "骰子",
}
local diceSetRegisteredItems = {}
local diceSetPreUse = {}
local diceSetStatProtectionPending = {}
local diceSetStatBaselines = {}
local diceSetEidModifierRegistered = false
local diceSetEidTransformationSupportRegistered = false
local DICE_SET_EID_TRANSFORMATION = "neverbirthDiceSet"
local DICE_SET_EID_ICON_MARKUP = "{{neverbirthDiceSet}}"
local DICE_SET_EID_FALLBACK_ICON_MARKUP = "{{Collectible105}}"
local DICE_SET_EID_ICON_ANM2 = "gfx/eid/DiceSetIcon.anm2"
local DICE_SET_EID_ICON_ANIMATION = "Transformation"
local diceSetEidIconSprite = nil

local function AddOriginalDiceItem(itemId)
    if IsValidItemId(itemId) then
        diceSetRegisteredItems[itemId] = {
            name = "vanilla dice",
            protectStats = true,
            original = true,
        }
    end
end

if CollectibleType then
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D6)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D4)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D8)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D7 or DICE_SET_D7_FALLBACK_ID)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D1 or DICE_SET_D1_FALLBACK_ID)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D10)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D12)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D20)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D100)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_D_INFINITY)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_ETERNAL_D6)
    AddOriginalDiceItem(CollectibleType.COLLECTIBLE_SPINDOWN_DICE)
end

local function GetDiceSetData()
    EnsureMusicboxDataLoaded()
    if type(musicboxSaveData.diceSet) ~= "table" or musicboxSaveData.diceSet.runSeed ~= GetCurrentRunSeed() then
        musicboxSaveData.diceSet = {
            runSeed = GetCurrentRunSeed(),
            players = {},
        }
    end

    if type(musicboxSaveData.diceSet.players) ~= "table" then
        musicboxSaveData.diceSet.players = {}
    end

    return musicboxSaveData.diceSet
end

local function ResetDiceSetDataForRun()
    EnsureMusicboxDataLoaded()
    musicboxSaveData.diceSet = {
        runSeed = GetCurrentRunSeed(),
        players = {},
    }
    diceSetPreUse = {}
    diceSetStatProtectionPending = {}
    diceSetStatBaselines = {}
end

local function GetDiceSetPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function GetDiceSetPlayerState(player)
    local data = GetDiceSetData()
    local playerKey = GetDiceSetPlayerKey(player)
    data.players[playerKey] = data.players[playerKey] or {
        seen = {},
        unlocked = false,
    }

    if type(data.players[playerKey].seen) ~= "table" then
        data.players[playerKey].seen = {}
    end

    return data.players[playerKey]
end

local function CaptureDiceSetStatBaseline(player)
    if not player then
        return nil
    end

    return {
        beforeDamage = player.Damage,
        beforeMaxFireDelay = player.MaxFireDelay,
        beforeTearRange = player.TearRange,
    }
end

local function StoreDiceSetStatBaseline(player, force)
    if not player then
        return nil
    end

    local playerKey = GetDiceSetPlayerKey(player)
    if not force and diceSetStatProtectionPending[playerKey] then
        return diceSetStatBaselines[playerKey]
    end

    local baseline = CaptureDiceSetStatBaseline(player)
    diceSetStatBaselines[playerKey] = baseline
    return baseline
end

local function GetDiceSetStatBaseline(player)
    return diceSetStatBaselines[GetDiceSetPlayerKey(player)]
end

local function GetCollectibleConfig(itemId)
    if not Isaac.GetItemConfig then
        return nil
    end

    local ok, itemConfig = pcall(function()
        return Isaac.GetItemConfig()
    end)
    if not ok or not itemConfig or not itemConfig.GetCollectible then
        return nil
    end

    local configOk, config = pcall(function()
        return itemConfig:GetCollectible(itemId)
    end)
    if configOk then
        return config
    end

    return nil
end

local function IsActiveCollectibleConfig(config)
    if not config then
        return false
    end

    return config.Type == DICE_SET_ACTIVE_ITEM_TYPE
        or config.Type == "active"
        or config.Type == "Active"
end

local function GetCollectibleMaxChargeFromConfig(config)
    if not config then
        return 0
    end

    return tonumber(config.MaxCharges or config.MaxCharge or config.Charge or config.MaxChargeCount) or 0
end

local function GetDiceSetItemOptions(itemId)
    return diceSetRegisteredItems[itemId]
end

function Neverbirth:RegisterDiceItem(itemId, options)
    if not IsValidItemId(itemId) then
        return false
    end

    options = options or {}
    diceSetRegisteredItems[itemId] = {
        name = options.name,
        protectStats = options.protectStats ~= false,
        registered = true,
    }
    return true
end

function Neverbirth:IsDiceActiveItem(itemId)
    if not IsValidItemId(itemId) then
        return false
    end

    if CollectibleType then
        if itemId == CollectibleType.COLLECTIBLE_CROOKED_PENNY
            or itemId == CollectibleType.COLLECTIBLE_GLITCHED_CROWN then
            return false
        end
    end

    if diceSetRegisteredItems[itemId] then
        return true
    end

    local config = GetCollectibleConfig(itemId)
    if not IsActiveCollectibleConfig(config) or GetCollectibleMaxChargeFromConfig(config) <= 0 then
        return false
    end

    local name = tostring(config.Name or config.NameLocalization or "")
    for _, keyword in ipairs(DICE_SET_NAME_KEYWORDS) do
        if name:find(keyword, 1, true) then
            return true
        end
    end

    return false
end

function Neverbirth:PlayerHasDiceSet(player)
    if not player then
        return false
    end

    return GetDiceSetPlayerState(player).unlocked == true
end

local function CountDiceSetSeenItems(state)
    local count = 0
    for _, seen in pairs(state.seen or {}) do
        if seen then
            count = count + 1
        end
    end
    return count
end

function Neverbirth:GetDiceSetProgress(player)
    if not player then
        return 0, DICE_SET_REQUIRED_UNIQUE_ITEMS, false
    end

    local state = GetDiceSetPlayerState(player)
    local count = math.min(CountDiceSetSeenItems(state), DICE_SET_REQUIRED_UNIQUE_ITEMS)
    return count, DICE_SET_REQUIRED_UNIQUE_ITEMS, state.unlocked == true
end

local ShowDiceSetUnlockBanner
local PlayDiceSetUnlockSound

local function PlayDiceSetUnlockFeedback(player)
    if ShowDiceSetUnlockBanner then
        ShowDiceSetUnlockBanner()
    end
    if PlayDiceSetUnlockSound then
        PlayDiceSetUnlockSound()
    end
    if player and player.SetColor then
        pcall(function()
            player:SetColor(Color(0.7, 0.9, 1, 1, 0.2, 0.2, 0.4), 30, 1, true, false)
        end)
    end
    if Isaac.Spawn and EntityType and EntityType.ENTITY_EFFECT and EffectVariant and EffectVariant.POOF01 and player and player.Position then
        pcall(function()
            Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.POOF01, 0, player.Position, Vector(0, 0), player)
        end)
    end
end

local function MarkDiceItemSeen(player, itemId)
    if not player or not Neverbirth:IsDiceActiveItem(itemId) then
        return false
    end

    local state = GetDiceSetPlayerState(player)
    local key = tostring(itemId)
    if state.seen[key] then
        return false
    end

    state.seen[key] = true
    if not state.unlocked and CountDiceSetSeenItems(state) >= DICE_SET_REQUIRED_UNIQUE_ITEMS then
        state.unlocked = true
        StoreDiceSetStatBaseline(player, true)
        PlayDiceSetUnlockFeedback(player)
    end

    SaveMusicboxData()
    return true
end

local function GetDiceSetUseKey(player, slot)
    return GetDiceSetPlayerKey(player) .. ":" .. tostring(slot or ActiveSlot.SLOT_PRIMARY)
end

local function StartDiceSetStatProtection(player, preUseState, itemId)
    if not Neverbirth:PlayerHasDiceSet(player) then
        return
    end

    local protectedItemId = (preUseState and preUseState.itemId) or itemId
    local options = GetDiceSetItemOptions(protectedItemId)
    if options and options.protectStats == false then
        return
    end

    local baseline = preUseState or GetDiceSetStatBaseline(player)
    if not baseline then
        baseline = StoreDiceSetStatBaseline(player, true)
    end
    if not baseline then
        return
    end

    local playerKey = GetDiceSetPlayerKey(player)
    diceSetStatProtectionPending[playerKey] = {
        beforeDamage = baseline.beforeDamage,
        beforeMaxFireDelay = baseline.beforeMaxFireDelay,
        beforeTearRange = baseline.beforeTearRange,
        remaining = {
            damage = true,
            fireDelay = true,
            range = true,
        },
        timer = 5,
    }

    if player.AddCacheFlags then
        local flags = 0
        if CacheFlag and CacheFlag.CACHE_DAMAGE then
            flags = flags | CacheFlag.CACHE_DAMAGE
        end
        if CacheFlag and CacheFlag.CACHE_FIREDELAY then
            flags = flags | CacheFlag.CACHE_FIREDELAY
        end
        if CacheFlag and CacheFlag.CACHE_RANGE then
            flags = flags | CacheFlag.CACHE_RANGE
        end
        if flags ~= 0 then
            player:AddCacheFlags(flags)
        end
    end

    if player.EvaluateItems then
        player:EvaluateItems()
    end
end

local function ParseDiceSetPickupPlayer(...)
    local args = { ... }
    local maybePlayer = args[6]
    if type(maybePlayer) == "table" and maybePlayer.ToPlayer then
        local player = maybePlayer:ToPlayer()
        if player then
            return player
        end
    elseif type(maybePlayer) == "table" then
        return maybePlayer
    end

    for _, argument in ipairs(args) do
        if type(argument) == "table" and argument.ToPlayer then
            local player = argument:ToPlayer()
            if player then
                return player
            end
        elseif type(argument) == "table" and argument.InitSeed then
            return argument
        end
    end

    return nil
end

function Neverbirth:TrackDiceSetPickup(itemId, ...)
    local player = ParseDiceSetPickupPlayer(...)
    MarkDiceItemSeen(player, itemId)
end

function Neverbirth:TrackHeldDiceItems()
    for _, player in ipairs(GetPlayers()) do
        for _, slot in ipairs(DICE_SET_ACTIVE_SLOTS) do
            if player.GetActiveItem then
                local ok, itemId = pcall(function()
                    return player:GetActiveItem(slot)
                end)
                if ok and Neverbirth:IsDiceActiveItem(itemId) then
                    MarkDiceItemSeen(player, itemId)
                end
            end
        end
        if Neverbirth:PlayerHasDiceSet(player) then
            StoreDiceSetStatBaseline(player)
        end
    end
end

function Neverbirth:RecordDiceSetPreUse(itemId, _, player, _, activeSlot)
    if not player or not Neverbirth:IsDiceActiveItem(itemId) then
        return nil
    end

    MarkDiceItemSeen(player, itemId)
    local slot = activeSlot or ActiveSlot.SLOT_PRIMARY
    diceSetPreUse[GetDiceSetUseKey(player, slot)] = {
        itemId = itemId,
        slot = slot,
        beforeDamage = player.Damage,
        beforeMaxFireDelay = player.MaxFireDelay,
        beforeTearRange = player.TearRange,
    }

    return nil
end

function Neverbirth:HandleDiceSetUse(itemId, _, player, _, activeSlot)
    if not player or not Neverbirth:IsDiceActiveItem(itemId) then
        return nil
    end

    MarkDiceItemSeen(player, itemId)
    local slot = activeSlot or ActiveSlot.SLOT_PRIMARY
    local useKey = GetDiceSetUseKey(player, slot)
    local preUseState = diceSetPreUse[useKey]
    diceSetPreUse[useKey] = nil

    StartDiceSetStatProtection(player, preUseState, itemId)

    return nil
end

function Neverbirth:EvaluateDiceSetStatProtection(player, cacheFlag)
    local pending = diceSetStatProtectionPending[GetDiceSetPlayerKey(player)]
    if not pending then
        return
    end

    if CacheFlag and cacheFlag == CacheFlag.CACHE_DAMAGE and pending.beforeDamage and player.Damage < pending.beforeDamage then
        player.Damage = pending.beforeDamage
        pending.remaining.damage = nil
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_FIREDELAY and pending.beforeMaxFireDelay and player.MaxFireDelay > pending.beforeMaxFireDelay then
        player.MaxFireDelay = pending.beforeMaxFireDelay
        pending.remaining.fireDelay = nil
    elseif CacheFlag and cacheFlag == CacheFlag.CACHE_RANGE and pending.beforeTearRange and player.TearRange < pending.beforeTearRange then
        player.TearRange = pending.beforeTearRange
        pending.remaining.range = nil
    end

    if not pending.remaining.damage and not pending.remaining.fireDelay and not pending.remaining.range then
        diceSetStatProtectionPending[GetDiceSetPlayerKey(player)] = nil
    end
end

function Neverbirth:UpdateDiceSetPendingState()
    for playerKey, pending in pairs(diceSetStatProtectionPending) do
        pending.timer = (tonumber(pending.timer) or 0) - 1
        if pending.timer <= 0 then
            diceSetStatProtectionPending[playerKey] = nil
        end
    end
end

function Neverbirth:ResetDiceSetState(isContinued)
    if isContinued then
        GetDiceSetData()
        return
    end

    ResetDiceSetDataForRun()
    SaveMusicboxData()
end

local function GetDiceSetEIDLanguage()
    local language = "en_us"
    if EID and EID.getLanguage then
        local ok, currentLanguage = pcall(function()
            return EID:getLanguage()
        end)
        if ok and type(currentLanguage) == "string" then
            language = currentLanguage
        end
    end

    return language
end

local function GetDiceSetUnlockText()
    local language = GetDiceSetEIDLanguage()
    if language == "zh_cn" or language == "zh" then
        return "骰子套装", "命运不再低于起点"
    end

    return "Dice Set", "Fate no longer falls below its origin"
end

ShowDiceSetUnlockBanner = function()
    if not Game then
        return
    end

    local gameOk, game = pcall(Game)
    if not gameOk or not game or type(game.GetHUD) ~= "function" then
        return
    end

    local hudOk, hud = pcall(function()
        return game:GetHUD()
    end)
    if not hudOk or not hud or type(hud.ShowItemText) ~= "function" then
        return
    end

    local title, subtitle = GetDiceSetUnlockText()
    pcall(function()
        hud:ShowItemText(title, subtitle)
    end)
end

PlayDiceSetUnlockSound = function()
    if not SoundEffect or not SFXManager then
        return
    end

    local soundId = SoundEffect.SOUND_CHOIR_UNLOCK or SoundEffect.SOUND_POWERUP2 or SoundEffect.SOUND_HOLY
    if not soundId then
        return
    end

    local managerOk, manager = pcall(SFXManager)
    if not managerOk or not manager or type(manager.Play) ~= "function" then
        return
    end

    pcall(function()
        manager:Play(soundId, 1, 0, false, 1)
    end)
end

local function GetDiceSetEIDPlayer(descObj)
    if descObj then
        if descObj.Player then
            return descObj.Player
        end
        if descObj.PlayerEntity then
            return descObj.PlayerEntity
        end
    end

    if EID and EID.player then
        return EID.player
    end

    if Isaac.GetPlayer then
        local ok, player = pcall(function()
            return Isaac.GetPlayer(0)
        end)
        if ok and player then
            return player
        end
    end

    local players = GetPlayers()
    return players[1]
end

local function GetDiceSetEIDTitle(player)
    local count, required = Neverbirth:GetDiceSetProgress(player)
    local language = GetDiceSetEIDLanguage()

    if language == "zh_cn" or language == "zh" then
        return "骰子套装 (" .. tostring(count) .. "/" .. tostring(required) .. ")"
    end

    return "Dice Set (" .. tostring(count) .. "/" .. tostring(required) .. ")"
end

local function GetDiceSetEIDTransformationName()
    local language = GetDiceSetEIDLanguage()

    if language == "zh_cn" or language == "zh" then
        return "骰子套装"
    end

    return "Dice Set"
end

local function GetDiceSetEIDBody(player)
    local _, _, unlocked = Neverbirth:GetDiceSetProgress(player)
    local language = GetDiceSetEIDLanguage()

    if language == "zh_cn" or language == "zh" then
        if unlocked then
            return "{{Damage}} {{Tears}} {{Range}} 当骰子更改伤害、射速、射程时，倍率不小于1.0"
        end
        return DICE_SET_EID_ICON_MARKUP .. " 收集或使用过3个不同骰子类主动道具后激活"
    end

    if unlocked then
        return "{{Damage}} {{Tears}} {{Range}} When dice change damage, fire rate, or range, their multipliers cannot be lower than 1.0"
    end
    return DICE_SET_EID_ICON_MARKUP .. " Collect or use 3 different dice active items to activate"
end

function Neverbirth:FormatDiceSetEID(player)
    return DICE_SET_EID_ICON_MARKUP .. " {{ColorPurple}}" .. GetDiceSetEIDTitle(player) .. "{{CR}}#" .. GetDiceSetEIDBody(player)
end

local function AppendDiceSetTransformation(descObj)
    if not descObj then
        return
    end

    local current = tostring(descObj.Transformation or "")
    if current == "" or current == "0" then
        descObj.Transformation = DICE_SET_EID_TRANSFORMATION
        return
    end

    for transform in string.gmatch(current, "([^,]+)") do
        if transform == DICE_SET_EID_TRANSFORMATION then
            return
        end
    end

    descObj.Transformation = current .. "," .. DICE_SET_EID_TRANSFORMATION
end

local function RegisterDiceSetEIDTransformationSupport()
    if diceSetEidTransformationSupportRegistered or not EID then
        return
    end

    if type(EID.createTransformation) == "function" then
        pcall(function()
            EID:createTransformation(DICE_SET_EID_TRANSFORMATION, "Dice Set", "en_us")
            EID:createTransformation(DICE_SET_EID_TRANSFORMATION, "骰子套装", "zh_cn")
        end)
    elseif type(EID.CustomTransformations) == "table" then
        EID.CustomTransformations[DICE_SET_EID_TRANSFORMATION] = EID.CustomTransformations[DICE_SET_EID_TRANSFORMATION] or {}
        EID.CustomTransformations[DICE_SET_EID_TRANSFORMATION].en_us = "Dice Set"
        EID.CustomTransformations[DICE_SET_EID_TRANSFORMATION].zh_cn = "骰子套装"
    end

    if type(EID.TransformationData) == "table" then
        EID.TransformationData[DICE_SET_EID_TRANSFORMATION] = EID.TransformationData[DICE_SET_EID_TRANSFORMATION] or {}
        EID.TransformationData[DICE_SET_EID_TRANSFORMATION].NumNeeded = DICE_SET_REQUIRED_UNIQUE_ITEMS
    end

    if type(EID.InlineIcons) == "table" then
        local iconRegistered = false
        if Sprite then
            local ok, sprite = pcall(function()
                local loadedSprite = Sprite()
                loadedSprite:Load(DICE_SET_EID_ICON_ANM2, true)
                loadedSprite:Play(DICE_SET_EID_ICON_ANIMATION, true)
                return loadedSprite
            end)
            if ok and sprite then
                diceSetEidIconSprite = sprite
                if type(EID.addIcon) == "function" then
                    pcall(function()
                        EID:addIcon(DICE_SET_EID_TRANSFORMATION, DICE_SET_EID_ICON_ANIMATION, 0, 16, 16, 0, 0, diceSetEidIconSprite)
                    end)
                    iconRegistered = EID.InlineIcons[DICE_SET_EID_TRANSFORMATION] ~= nil
                end
                if not iconRegistered then
                    EID.InlineIcons[DICE_SET_EID_TRANSFORMATION] = { DICE_SET_EID_ICON_ANIMATION, 0, 16, 16, 0, 0, diceSetEidIconSprite }
                    iconRegistered = true
                end
            end
        end

        if not iconRegistered and type(EID.createItemIconObject) == "function" then
            pcall(function()
                local icon = EID:createItemIconObject(DICE_SET_EID_FALLBACK_ICON_MARKUP)
                if icon then
                    EID.InlineIcons[DICE_SET_EID_TRANSFORMATION] = icon
                end
            end)
        end
    end

    if type(EID.evaluateTransformationProgress) == "function" and not EID.__neverbirthDiceSetEvaluateProgress then
        local originalEvaluateTransformationProgress = EID.evaluateTransformationProgress
        EID.__neverbirthDiceSetEvaluateProgress = originalEvaluateTransformationProgress
        EID.evaluateTransformationProgress = function(self, transformation)
            if transformation ~= DICE_SET_EID_TRANSFORMATION then
                return originalEvaluateTransformationProgress(self, transformation)
            end

            self.TransformationProgress = self.TransformationProgress or {}
            local players = self.coopAllPlayers
            if type(players) ~= "table" or #players == 0 then
                players = GetPlayers()
            end

            for _, player in ipairs(players) do
                local playerId
                if type(self.getPlayerID) == "function" then
                    local ok, id = pcall(function()
                        return self:getPlayerID(player, true)
                    end)
                    if ok then
                        playerId = id
                    end
                end
                playerId = playerId or GetDiceSetPlayerKey(player)
                self.TransformationProgress[playerId] = self.TransformationProgress[playerId] or {}
                local count = Neverbirth:GetDiceSetProgress(player)
                self.TransformationProgress[playerId][DICE_SET_EID_TRANSFORMATION] = count
            end
        end
    end

    if type(EID.getTransformationName) == "function" and not EID.__neverbirthDiceSetGetTransformationName then
        local originalGetTransformationName = EID.getTransformationName
        EID.__neverbirthDiceSetGetTransformationName = originalGetTransformationName
        EID.getTransformationName = function(self, transformId)
            if transformId == DICE_SET_EID_TRANSFORMATION then
                return GetDiceSetEIDTransformationName(GetDiceSetEIDPlayer())
            end
            return originalGetTransformationName(self, transformId)
        end
    end

    diceSetEidTransformationSupportRegistered = true
end

local function RegisterDiceSetEIDModifier()
    if diceSetEidModifierRegistered or not EID or type(EID.addDescriptionModifier) ~= "function" then
        return false
    end

    RegisterDiceSetEIDTransformationSupport()

    EID:addDescriptionModifier(
        "neverbirth Dice Set",
        function(descObj)
            local itemId = descObj and (descObj.ObjSubType or descObj.SubType or descObj.ItemID or descObj.ItemId)
            return Neverbirth:IsDiceActiveItem(itemId)
        end,
        function(descObj)
            if not descObj then
                return descObj
            end

            local player = GetDiceSetEIDPlayer(descObj)
            local originalDescription = tostring(descObj.Description or "")
            if EID.Config and (EID.Config["TransformationIcons"] or EID.Config["TransformationText"] or EID.Config["TransformationProgress"]) then
                AppendDiceSetTransformation(descObj)
                descObj.Description = GetDiceSetEIDBody(player)
                if originalDescription ~= "" then
                    descObj.Description = descObj.Description .. "#" .. originalDescription
                end
            else
                descObj.Description = Neverbirth:FormatDiceSetEID(player)
                if originalDescription ~= "" then
                    descObj.Description = descObj.Description .. "#" .. originalDescription
                end
            end
            return descObj
        end
    )

    diceSetEidModifierRegistered = true
    return true
end

function Neverbirth:TryRegisterDiceSetEIDModifier()
    RegisterDiceSetEIDModifier()
end
end

local function GetPlayerMusicboxKey(player)
    return tostring(player and player.InitSeed or "")
end

local function FindPlayerByMusicboxDebt(debt)
    if not debt then
        return nil
    end

    local debtSeed = tostring(debt.playerInitSeed or "")
    for _, player in ipairs(GetPlayers()) do
        if tostring(player.InitSeed or "") == debtSeed then
            return player
        end
    end

    return nil
end

local function GetCurrentMusicboxDebt(player)
    local debt = GetMusicboxDebtTable()[GetPlayerMusicboxKey(player)]
    if not debt or debt.runSeed ~= GetCurrentRunSeed() then
        return nil
    end

    return debt
end

local function IsMusicboxActiveForPlayer(player)
    if not player then
        return false
    end

    local effect = musicboxEffects[player.InitSeed]
    if effect and (tonumber(effect.timer) or 0) > 0 then
        return true
    end

    local debt = GetCurrentMusicboxDebt(player)
    return debt and (tonumber(debt.timer) or 0) > 0
end

local function PlayerHasMusicbox(player)
    if not player then
        return false
    end

    if IsMusicboxActiveForPlayer(player) then
        return true
    end

    if player.GetActiveItem then
        for _, slot in ipairs(MUSICBOX_ACTIVE_SLOTS) do
            if player:GetActiveItem(slot) == Items.Musicbox then
                return true
            end
        end
    end

    return player.GetCollectibleNum and player:GetCollectibleNum(Items.Musicbox) > 0
end

local function StartMusicboxMusic()
    local themeId = GetMusicboxThemeId()
    if not themeId then
        return
    end

    local music = MusicManager()
    if musicboxPreviousMusicId == nil and music.GetCurrentMusicID then
        local currentMusicId = music:GetCurrentMusicID()
        if currentMusicId ~= themeId then
            musicboxPreviousMusicId = currentMusicId
        end
    end

    music:Play(themeId, 1)
    musicboxMusicStarted = true
end

local function KeepMusicboxMusic()
    local themeId = GetMusicboxThemeId()
    if not themeId then
        return
    end

    local music = MusicManager()
    if not music.GetCurrentMusicID or music:GetCurrentMusicID() ~= themeId then
        music:Play(themeId, 1)
        musicboxMusicStarted = true
    end
end

local function StopMusicboxMusic()
    if not musicboxMusicStarted then
        return
    end

    local music = MusicManager()
    local themeId = GetMusicboxThemeId()

    if IsValidMusicId(musicboxPreviousMusicId) and musicboxPreviousMusicId ~= themeId then
        music:Play(musicboxPreviousMusicId, 1)
    elseif music.Fadeout then
        music:Fadeout(0.08)
    end

    musicboxPreviousMusicId = nil
    musicboxMusicStarted = false
end

local function RefreshMusicboxPlayerCache(player)
    player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR)
    player:EvaluateItems()
end

local function SyncMusicboxEffectFromDebt(player, debt)
    if not player or not debt then
        return
    end

    musicboxEffects[player.InitSeed] = {
        timer = math.max(tonumber(debt.timer) or 0, 0),
        player = player,
    }
end

local function ClearMusicboxDebt(key)
    GetMusicboxDebtTable()[key] = nil
end

local function ForceMusicboxDeath(key, debt, player)
    if not player then
        return
    end

    local willRevive = player.WillPlayerRevive and player:WillPlayerRevive()
    musicboxEffects[player.InitSeed] = nil
    RefreshMusicboxPlayerCache(player)

    if willRevive then
        ClearMusicboxDebt(key)
    else
        debt.timer = 0
        debt.expired = true
    end
    SaveMusicboxData()

    if player.Kill then
        player:Kill()
    elseif player.Die then
        player:Die()
    elseif player.TakeDamage then
        player:TakeDamage(999, DamageFlag.DAMAGE_INVINCIBLE, EntityRef(player), 0)
    end
end

local function ForcePlanCDeath(player)
    if not player then
        return
    end

    if player.Kill then
        player:Kill()
    elseif player.Die then
        player:Die()
    elseif player.TakeDamage then
        player:TakeDamage(999, DamageFlag.DAMAGE_INVINCIBLE, EntityRef(player), 0)
    end
end

local function StartMusicboxEffect(player, source)
    local wasActive = HasActiveMusicboxEffect()
    local key = GetPlayerMusicboxKey(player)
    local debts = GetMusicboxDebtTable()
    local debt = debts[key]
    local runSeed = GetCurrentRunSeed()
    musicboxPlanCDeaths[player.InitSeed] = nil

    if debt and debt.runSeed == runSeed then
        SyncMusicboxEffectFromDebt(player, debt)
        RefreshMusicboxPlayerCache(player)

        if wasActive then
            KeepMusicboxMusic()
        else
            StartMusicboxMusic()
        end

        if (tonumber(debt.timer) or 0) <= 0 then
            ForceMusicboxDeath(key, debt, player)
        end

        return true
    end

    debt = {
        runSeed = runSeed,
        playerInitSeed = player.InitSeed,
        timer = MUSICBOX_DURATION,
        source = source or "use",
        expired = false,
    }
    debts[key] = debt
    SyncMusicboxEffectFromDebt(player, debt)
    SaveMusicboxData()

    RefreshMusicboxPlayerCache(player)

    if not wasActive then
        StartMusicboxMusic()
    else
        KeepMusicboxMusic()
    end

    return true
end

function Neverbirth:UseMusicbox(_, _, player)
    if not player then
        return false
    end

    return StartMusicboxEffect(player, "use")
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseMusicbox, Items.Musicbox)

local function DamageEnemiesWithPlanC(player)
    local source = EntityRef(player)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity and entity.IsVulnerableEnemy and entity:IsVulnerableEnemy() and entity.TakeDamage then
            entity:TakeDamage(MUSICBOX_PLAN_C_DAMAGE, 0, source, 0)
        end
    end
end

local function RemoveInterceptedPlanC(player, activeSlot)
    if player and player.RemoveCollectible then
        player:RemoveCollectible(PLAN_C_ID, false, activeSlot or ActiveSlot.SLOT_PRIMARY, true)
    end
end

function Neverbirth:InterceptPlanC(collectibleId, _, player, _, activeSlot)
    if collectibleId ~= PLAN_C_ID or not PlayerHasMusicbox(player) then
        return nil
    end

    DamageEnemiesWithPlanC(player)
    RemoveInterceptedPlanC(player, activeSlot)

    if not IsMusicboxActiveForPlayer(player) then
        musicboxPlanCDeaths[player.InitSeed] = {
            timer = MUSICBOX_PLAN_C_DELAY,
            player = player,
        }
    end

    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, Neverbirth.InterceptPlanC, PLAN_C_ID)

local function UpdateMusicboxPlanCDeaths()
    for seed, effect in pairs(musicboxPlanCDeaths) do
        local player = effect.player
        if player and IsMusicboxActiveForPlayer(player) then
            musicboxPlanCDeaths[seed] = nil
        elseif player then
            effect.timer = effect.timer - 1
            if effect.timer <= 0 then
                musicboxPlanCDeaths[seed] = nil
                ForcePlanCDeath(player)
            end
        end
    end
end

function Neverbirth:UpdateMusicbox()
    UpdateMusicboxPlanCDeaths()

    local hasActiveAfterUpdate = false
    local changed = false
    local debts = GetMusicboxDebtTable()
    local runSeed = GetCurrentRunSeed()

    for key, debt in pairs(debts) do
        if type(debt) ~= "table" or debt.runSeed ~= runSeed then
            debts[key] = nil
            changed = true
        else
            local player = FindPlayerByMusicboxDebt(debt)
            local timer = tonumber(debt.timer) or 0

            if player then
                if timer > 0 then
                    timer = timer - 1
                    debt.timer = timer
                    changed = true
                end

                if timer <= 0 then
                    ForceMusicboxDeath(key, debt, player)
                    changed = true
                else
                    SyncMusicboxEffectFromDebt(player, debt)
                    hasActiveAfterUpdate = true
                end
            elseif timer <= 0 and debt.expired then
                changed = true
            end
        end
    end

    if changed then
        SaveMusicboxData()
    end

    if hasActiveAfterUpdate then
        KeepMusicboxMusic()
    else
        StopMusicboxMusic()
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateMusicbox)

function Neverbirth:RenderMusicboxCountdown()
    for _, player in ipairs(GetPlayers()) do
        local effect = musicboxEffects[player.InitSeed]
        if effect and effect.timer > 0 then
            local secondsLeft = math.ceil(effect.timer / 30)
            local screenPosition = Isaac.WorldToScreen(player.Position + MUSICBOX_COUNTDOWN_OFFSET)
            Isaac.RenderText(tostring(secondsLeft), screenPosition.X - 4, screenPosition.Y, 1, 0.1, 0.1, 1)
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderMusicboxCountdown)

function Neverbirth:EvaluateMusicbox(player, cacheFlag)
    local debt = GetCurrentMusicboxDebt(player)
    local effect = musicboxEffects[player.InitSeed]

    if not effect and not (debt and (tonumber(debt.timer) or 0) > 0) then
        return
    end

    if cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = MUSICBOX_TEAR_COLOR
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateMusicbox)

local function IsIncomingDamageLethal(player, amount)
    if player.HasMortalDamage and player:HasMortalDamage() then
        return true
    end

    local totalHealth = 0
    if player.GetHearts then
        totalHealth = totalHealth + player:GetHearts()
    end
    if player.GetSoulHearts then
        totalHealth = totalHealth + player:GetSoulHearts()
    end
    if player.GetBoneHearts then
        totalHealth = totalHealth + player:GetBoneHearts() * 2
    end

    return totalHealth > 0 and amount ~= nil and amount >= totalHealth
end

local function IsMusicboxSlotUncharged(player, slot)
    if player.GetActiveCharge then
        local ok, charge = pcall(function()
            return player:GetActiveCharge(slot)
        end)
        if ok and charge ~= nil then
            return charge < MUSICBOX_MAX_CHARGE
        end
    end

    if player.NeedsCharge then
        local ok, needsCharge = pcall(function()
            return player:NeedsCharge(slot)
        end)
        if ok and needsCharge ~= nil then
            return needsCharge
        end
    end

    return false
end

local function FindUnchargedMusicboxSlot(player)
    if not player.GetActiveItem then
        return nil
    end

    for _, slot in ipairs(MUSICBOX_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.Musicbox and IsMusicboxSlotUncharged(player, slot) then
            return slot
        end
    end

    return nil
end

local function TryTriggerPanicMusicbox(player, amount)
    if GetCurrentMusicboxDebt(player) then
        return false
    end

    if not IsIncomingDamageLethal(player, amount) then
        return false
    end

    local slot = FindUnchargedMusicboxSlot(player)
    if slot == nil then
        return false
    end

    if player.RemoveCollectible then
        pcall(function()
            player:RemoveCollectible(Items.Musicbox, false, slot, true)
        end)
    end

    StartMusicboxEffect(player, "panic")
    return true
end

function Neverbirth:PreventMusicboxDamage(entity, amount)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player then
        return nil
    end

    local debt = GetCurrentMusicboxDebt(player)
    if debt and (tonumber(debt.timer) or 0) > 0 then
        SyncMusicboxEffectFromDebt(player, debt)
        return false
    end

    if musicboxEffects[player.InitSeed] then
        return false
    end

    if TryTriggerPanicMusicbox(player, amount) then
        return false
    end

    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.PreventMusicboxDamage)

--------------------------------------------------
-- 未剪断的脐带

local UNCUT_CORD_TRIGGER_CHANCE = 0.5
local UNCUT_CORD_ROOMS_REQUIRED = 2
local UNCUT_CORD_MIN_SETTLED_DAMAGE = 1
local UNCUT_CORD_SETTLE_FLAGS = DamageFlag.DAMAGE_INVINCIBLE
local UNCUT_CORD_POPUP_DURATION = 45
local UNCUT_CORD_DEBT_OFFSET = Vector(0, -44)
local UNCUT_CORD_POPUP_OFFSET = Vector(0, -58)

local uncutCordDebts = {}
local uncutCordSettling = {}
local uncutCordFeedbacks = {}

local function GetUncutCordPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function PlayerHasUncutCord(player)
    return player and player.GetCollectibleNum and player:GetCollectibleNum(Items.UncutCord) > 0
end

local function GetUncutCordRandomFloat(player)
    if player and player.GetCollectibleRNG then
        local ok, rng = pcall(function()
            return player:GetCollectibleRNG(Items.UncutCord)
        end)
        if ok and rng and rng.RandomFloat then
            local rngOk, value = pcall(function()
                return rng:RandomFloat()
            end)
            if rngOk and type(value) == "number" then
                return value
            end
        end
    end

    return math.random()
end

local function IsUncutCordCombatEnemy(entity)
    if not entity or not entity.IsVulnerableEnemy then
        return false
    end

    local ok, isEnemy = pcall(function()
        return entity:IsVulnerableEnemy()
    end)
    return ok and isEnemy == true
end

local function UncutCordRoomHasEnemies()
    if not Isaac.GetRoomEntities then
        return false
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsUncutCordCombatEnemy(entity) then
            return true
        end
    end

    return false
end

local function GetUncutCordGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    if ok then
        return game
    end

    return nil
end

local function GetUncutCordRoom()
    local game = GetUncutCordGame()
    if game and game.GetRoom then
        return game:GetRoom()
    end

    return nil
end

local function GetUncutCordRoomKey()
    local game = GetUncutCordGame()
    if game and game.GetLevel then
        local level = game:GetLevel()
        if level and level.GetCurrentRoomIndex then
            local ok, roomIndex = pcall(function()
                return level:GetCurrentRoomIndex()
            end)
            if ok and roomIndex ~= nil then
                return "idx:" .. tostring(roomIndex)
            end
        end
    end

    local room = GetUncutCordRoom()
    if room and room.GetSpawnSeed then
        local ok, spawnSeed = pcall(function()
            return room:GetSpawnSeed()
        end)
        if ok and spawnSeed ~= nil then
            return "seed:" .. tostring(spawnSeed)
        end
    end

    return "unknown"
end

local function IsUncutCordRoomClear()
    if UncutCordRoomHasEnemies() then
        return false
    end

    local room = GetUncutCordRoom()
    if room and room.IsClear then
        local ok, isClear = pcall(function()
            return room:IsClear()
        end)
        if ok then
            return isClear == true
        end
    end

    return true
end

local function AttachUncutCordRoomState(record)
    record.currentRoomKey = GetUncutCordRoomKey()
    record.currentRoomHadEnemies = UncutCordRoomHasEnemies()
    record.currentRoomCounted = false
end

local function FindUncutCordPlayerByKey(playerKey)
    for _, player in ipairs(GetPlayers()) do
        if GetUncutCordPlayerKey(player) == playerKey then
            return player
        end
    end

    return nil
end

local function FormatUncutCordHeartAmount(amount)
    return string.format("%.1f", (tonumber(amount) or 0) / 2)
end

local function SetUncutCordFeedback(playerKey, text, r, g, b, player)
    if playerKey == nil or playerKey == "" then
        return
    end

    uncutCordFeedbacks[playerKey] = {
        text = text,
        timer = UNCUT_CORD_POPUP_DURATION,
        r = r or 1,
        g = g or 1,
        b = b or 1,
        player = player,
    }
end

local function SetUncutCordPlayerFeedback(player, text, r, g, b)
    SetUncutCordFeedback(GetUncutCordPlayerKey(player), text, r, g, b, player)
end

local function ApplyUncutCordDamage(player, amount)
    local playerKey = GetUncutCordPlayerKey(player)
    uncutCordSettling[playerKey] = true

    if player and player.TakeDamage then
        player:TakeDamage(amount, UNCUT_CORD_SETTLE_FLAGS, EntityRef(player), 0)
    end

    uncutCordSettling[playerKey] = nil
end

local function SettleUncutCordDebt(player, playerKey, record, amount, feedbackLabel)
    local settledAmount = math.max(UNCUT_CORD_MIN_SETTLED_DAMAGE, tonumber(amount) or 0)
    uncutCordDebts[playerKey] = nil
    if feedbackLabel then
        SetUncutCordFeedback(
            playerKey,
            feedbackLabel .. " " .. FormatUncutCordHeartAmount(settledAmount),
            1,
            feedbackLabel == "HALF PAID" and 0.85 or 0.35,
            feedbackLabel == "HALF PAID" and 0.25 or 0.2,
            player
        )
    end
    ApplyUncutCordDamage(player, settledAmount)
end

local function SettleUncutCordDebtHalf(player, playerKey, record)
    SettleUncutCordDebt(player, playerKey, record, (tonumber(record.amount) or 0) / 2, "HALF PAID")
end

local function SettleUncutCordDebtFull(player, playerKey, record)
    SettleUncutCordDebt(player, playerKey, record, tonumber(record.amount) or 0, "FULL PAID")
end

local function StoreUncutCordDebt(player, amount)
    local playerKey = GetUncutCordPlayerKey(player)
    local record = {
        amount = tonumber(amount) or 0,
        roomsCleared = 0,
        player = player,
    }
    AttachUncutCordRoomState(record)
    uncutCordDebts[playerKey] = record
    SetUncutCordPlayerFeedback(player, "DELAY " .. FormatUncutCordHeartAmount(record.amount), 0.55, 0.9, 1)
end

function Neverbirth:HandleUncutCordDamage(entity, amount)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player then
        return nil
    end

    local playerKey = GetUncutCordPlayerKey(player)
    if uncutCordSettling[playerKey] then
        return nil
    end

    if bloodSkullGuBacklashDepth > 0 then
        return nil
    end

    local record = uncutCordDebts[playerKey]
    if record then
        SettleUncutCordDebtFull(player, playerKey, record)
        return nil
    end

    local damageAmount = tonumber(amount) or 0
    if damageAmount <= 0 or not PlayerHasUncutCord(player) then
        return nil
    end

    if GetUncutCordRandomFloat(player) >= UNCUT_CORD_TRIGGER_CHANCE then
        return nil
    end

    StoreUncutCordDebt(player, damageAmount)
    return false
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleUncutCordDamage)

function Neverbirth:TrackUncutCordNewRoom()
    for _, record in pairs(uncutCordDebts) do
        AttachUncutCordRoomState(record)
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.TrackUncutCordNewRoom)
end

function Neverbirth:UpdateUncutCordRooms()
    if next(uncutCordDebts) == nil or not IsUncutCordRoomClear() then
        return
    end

    local currentRoomKey = GetUncutCordRoomKey()
    for playerKey, record in pairs(uncutCordDebts) do
        if record.currentRoomKey ~= currentRoomKey then
            AttachUncutCordRoomState(record)
        end

        if record.currentRoomHadEnemies and not record.currentRoomCounted then
            record.currentRoomCounted = true
            record.roomsCleared = (tonumber(record.roomsCleared) or 0) + 1

            if record.roomsCleared >= UNCUT_CORD_ROOMS_REQUIRED then
                local player = FindUncutCordPlayerByKey(playerKey) or record.player
                if player then
                    SettleUncutCordDebtHalf(player, playerKey, record)
                else
                    uncutCordDebts[playerKey] = nil
                end
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateUncutCordRooms)

function Neverbirth:UpdateUncutCordFeedbacks()
    for playerKey, feedback in pairs(uncutCordFeedbacks) do
        feedback.timer = (tonumber(feedback.timer) or 0) - 1
        if feedback.timer <= 0 then
            uncutCordFeedbacks[playerKey] = nil
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateUncutCordFeedbacks)

local function AddUncutCordRenderPlayer(playersByKey, player)
    if not player or not player.Position then
        return
    end

    local playerKey = GetUncutCordPlayerKey(player)
    if playerKey ~= "" then
        playersByKey[playerKey] = player
    end
end

local function GetUncutCordRenderPlayers()
    local playersByKey = {}
    for _, player in ipairs(GetPlayers()) do
        AddUncutCordRenderPlayer(playersByKey, player)
    end

    for _, record in pairs(uncutCordDebts) do
        if record and record.player then
            AddUncutCordRenderPlayer(playersByKey, record.player)
        end
    end

    for _, feedback in pairs(uncutCordFeedbacks) do
        if feedback and feedback.player then
            AddUncutCordRenderPlayer(playersByKey, feedback.player)
        end
    end

    return playersByKey
end

local function RenderUncutCordText(text, screenPosition, r, g, b)
    local x = screenPosition.X - 32
    local y = screenPosition.Y
    Isaac.RenderText(text, x + 1, y + 1, 0, 0, 0, 0.75)
    Isaac.RenderText(text, x, y, r, g, b, 1)
end

function Neverbirth:RenderUncutCordFeedbacks()
    for playerKey, player in pairs(GetUncutCordRenderPlayers()) do
        local record = uncutCordDebts[playerKey]
        if record then
            local roomsCleared = math.min(tonumber(record.roomsCleared) or 0, UNCUT_CORD_ROOMS_REQUIRED)
            local debtText = "DEBT " ..
                FormatUncutCordHeartAmount(record.amount) ..
                " " ..
                tostring(roomsCleared) ..
                "/" ..
                tostring(UNCUT_CORD_ROOMS_REQUIRED)
            local debtPosition = Isaac.WorldToScreen(player.Position + UNCUT_CORD_DEBT_OFFSET)
            RenderUncutCordText(debtText, debtPosition, 1, 0.75, 0.2)
        end

        local feedback = uncutCordFeedbacks[playerKey]
        if feedback and (tonumber(feedback.timer) or 0) > 0 then
            local popupPosition = Isaac.WorldToScreen(player.Position + UNCUT_CORD_POPUP_OFFSET)
            RenderUncutCordText(feedback.text, popupPosition, feedback.r or 1, feedback.g or 1, feedback.b or 1)
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderUncutCordFeedbacks)

local function ClearUncutCordState()
    uncutCordDebts = {}
    uncutCordSettling = {}
    uncutCordFeedbacks = {}
end

function Neverbirth:ResetUncutCordState(isContinued)
    if isContinued then
        return
    end

    ClearUncutCordState()
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetUncutCordState)
end

--------------------------------------------------
-- 剪碎的塔罗

do
local SHREDDED_TAROT_LUCK_BONUS = 3
local SHREDDED_TAROT_CARDS_PER_REWARD = 3
local SHREDDED_TAROT_MAX_REWARDS = 3
local SHREDDED_TAROT_TREASURE_POOL = (ItemPoolType and ItemPoolType.POOL_TREASURE) or 0
local SHREDDED_TAROT_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local SHREDDED_TAROT_COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local SHREDDED_TAROT_CARD_VARIANT = (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300
local SHREDDED_TAROT_NULL_ITEM = (CollectibleType and CollectibleType.COLLECTIBLE_NULL) or 0
local SHREDDED_TAROT_RUNE_MIN = (Card and Card.RUNE_HAGALAZ) or 32
local SHREDDED_TAROT_RUNE_MAX = (Card and Card.RUNE_BLACK) or 41
local SHREDDED_TAROT_RUNE_SHARD = (Card and Card.RUNE_SHARD) or 55
local SHREDDED_TAROT_SOUL_MIN = (Card and Card.CARD_SOUL_ISAAC) or 81
local SHREDDED_TAROT_SOUL_MAX = (Card and Card.CARD_SOUL_JACOB) or 97

local shreddedTarotStates = {}

local function BuildShreddedTarotActiveSlots()
    if not ActiveSlot then
        return { 0, 1, 2, 3 }
    end

    local slots = {}
    if ActiveSlot.SLOT_PRIMARY ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_PRIMARY
    end
    if ActiveSlot.SLOT_SECONDARY ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_SECONDARY
    end
    if ActiveSlot.SLOT_POCKET ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_POCKET
    end
    if ActiveSlot.SLOT_POCKET2 ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_POCKET2
    end

    return slots
end

local SHREDDED_TAROT_ACTIVE_SLOTS = BuildShreddedTarotActiveSlots()

local function GetShreddedTarotGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    if ok then
        return game
    end

    return nil
end

local function GetShreddedTarotLevel()
    local game = GetShreddedTarotGame()
    if game and game.GetLevel then
        return game:GetLevel()
    end

    return nil
end

local function GetShreddedTarotRoom()
    local game = GetShreddedTarotGame()
    if game and game.GetRoom then
        return game:GetRoom()
    end

    return nil
end

local function GetShreddedTarotFloorKey()
    local level = GetShreddedTarotLevel()
    if not level then
        return "unknown"
    end

    local stage = "?"
    if level.GetStage then
        local ok, value = pcall(function()
            return level:GetStage()
        end)
        if ok and value ~= nil then
            stage = tostring(value)
        end
    end

    local stageType = "?"
    if level.GetStageType then
        local ok, value = pcall(function()
            return level:GetStageType()
        end)
        if ok and value ~= nil then
            stageType = tostring(value)
        end
    end

    return stage .. ":" .. stageType
end

local function GetShreddedTarotPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function FindShreddedTarotSlot(player, preferredSlot)
    if not player or not player.GetActiveItem then
        return nil
    end

    if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == Items.ShreddedTarot then
        return preferredSlot
    end

    for _, slot in ipairs(SHREDDED_TAROT_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.ShreddedTarot then
            return slot
        end
    end

    return nil
end

local function PlayerHasShreddedTarot(player)
    if not player then
        return false
    end

    if FindShreddedTarotSlot(player) ~= nil then
        return true
    end

    return player.GetCollectibleNum and player:GetCollectibleNum(Items.ShreddedTarot) > 0
end

local function EnsureShreddedTarotState(player)
    local playerKey = GetShreddedTarotPlayerKey(player)
    if playerKey == "" then
        return nil
    end

    local state = shreddedTarotStates[playerKey]
    if type(state) ~= "table" then
        state = {
            floorKey = GetShreddedTarotFloorKey(),
            successfulUse = false,
        }
        shreddedTarotStates[playerKey] = state
    end

    return state
end

local function RefreshShreddedTarotLuck(player)
    if not player then
        return
    end

    if player.AddCacheFlags and CacheFlag and CacheFlag.CACHE_LUCK then
        player:AddCacheFlags(CacheFlag.CACHE_LUCK)
    end
    if player.EvaluateItems then
        player:EvaluateItems()
    end
end

local function RemoveShreddedTarot(player, slot)
    if not player or not player.RemoveCollectible then
        return
    end

    local targetSlot = slot or FindShreddedTarotSlot(player) or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    player:RemoveCollectible(Items.ShreddedTarot, false, targetSlot, true)
    RefreshShreddedTarotLuck(player)
end

local function IsShreddedTarotRuneOrSoulStone(subType)
    local cardId = tonumber(subType) or 0
    if cardId >= SHREDDED_TAROT_RUNE_MIN and cardId <= SHREDDED_TAROT_RUNE_MAX then
        return true
    end

    if cardId == SHREDDED_TAROT_RUNE_SHARD then
        return true
    end

    return cardId >= SHREDDED_TAROT_SOUL_MIN and cardId <= SHREDDED_TAROT_SOUL_MAX
end

local function IsShreddedTarotCardPickup(entity)
    if not entity or entity.Type ~= SHREDDED_TAROT_ENTITY_PICKUP or entity.Variant ~= SHREDDED_TAROT_CARD_VARIANT then
        return false
    end

    if IsShreddedTarotRuneOrSoulStone(entity.SubType) then
        return false
    end

    if entity.IsDead then
        local ok, isDead = pcall(function()
            return entity:IsDead()
        end)
        if ok and isDead then
            return false
        end
    end

    return true
end

local function CollectShreddedTarotCards()
    local cards = {}
    if not Isaac.GetRoomEntities then
        return cards
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsShreddedTarotCardPickup(entity) then
            cards[#cards + 1] = entity
        end
    end

    return cards
end

local function RemoveShreddedTarotCards(cards)
    for _, card in ipairs(cards) do
        if card and card.Remove then
            card:Remove()
        end
    end
end

local function GetShreddedTarotRewardSeed(baseSeed, rewardIndex)
    return (tonumber(baseSeed) or 0) + (tonumber(rewardIndex) or 1) * 1000003 + 1297
end

local function SelectShreddedTarotReward(rewardIndex)
    local game = GetShreddedTarotGame()
    local itemPool = game and game.GetItemPool and game:GetItemPool()
    local room = GetShreddedTarotRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0

    if itemPool and itemPool.GetCollectible then
        return itemPool:GetCollectible(
            SHREDDED_TAROT_TREASURE_POOL,
            false,
            GetShreddedTarotRewardSeed(seed, rewardIndex),
            SHREDDED_TAROT_NULL_ITEM
        )
    end

    return SHREDDED_TAROT_NULL_ITEM
end

local function SpawnShreddedTarotRewards(player, rewardCount)
    local game = GetShreddedTarotGame()
    local room = GetShreddedTarotRoom()
    if not game or not game.Spawn then
        return
    end

    local center = nil
    if room and room.GetCenterPos then
        center = room:GetCenterPos()
    elseif player and player.Position then
        center = player.Position
    else
        center = Vector(320, 280)
    end

    local spawnSeed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }

    for index = 1, rewardCount do
        local position = center
        if Vector then
            position = center + Vector((index - (rewardCount + 1) / 2) * 40, 0)
        end

        if room and room.FindFreePickupSpawnPosition then
            position = room:FindFreePickupSpawnPosition(position, 40, true, false)
        end

        game:Spawn(
            SHREDDED_TAROT_ENTITY_PICKUP,
            SHREDDED_TAROT_COLLECTIBLE_VARIANT,
            position,
            velocity,
            player,
            SelectShreddedTarotReward(index),
            spawnSeed + index
        )
    end
end

function Neverbirth:UseShreddedTarot(_, _, player, _, activeSlot)
    if not player then
        return false
    end

    local slot = FindShreddedTarotSlot(player, activeSlot) or activeSlot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    local state = EnsureShreddedTarotState(player)
    local cards = CollectShreddedTarotCards()
    local rewardCount = math.min(math.floor(#cards / SHREDDED_TAROT_CARDS_PER_REWARD), SHREDDED_TAROT_MAX_REWARDS)

    if rewardCount <= 0 then
        return false
    end

    RemoveShreddedTarotCards(cards)
    SpawnShreddedTarotRewards(player, rewardCount)

    if state then
        state.successfulUse = true
    end
    RemoveShreddedTarot(player, slot)
    if not PlayerHasShreddedTarot(player) then
        shreddedTarotStates[GetShreddedTarotPlayerKey(player)] = nil
    end
    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseShreddedTarot, Items.ShreddedTarot)

function Neverbirth:EvaluateShreddedTarot(player, cacheFlag)
    if CacheFlag and CacheFlag.CACHE_LUCK and cacheFlag == CacheFlag.CACHE_LUCK and PlayerHasShreddedTarot(player) then
        player.Luck = player.Luck + SHREDDED_TAROT_LUCK_BONUS
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateShreddedTarot)

function Neverbirth:TrackShreddedTarotHolders()
    for _, player in ipairs(GetPlayers()) do
        local playerKey = GetShreddedTarotPlayerKey(player)
        if PlayerHasShreddedTarot(player) then
            EnsureShreddedTarotState(player)
        elseif playerKey ~= "" then
            shreddedTarotStates[playerKey] = nil
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackShreddedTarotHolders)

function Neverbirth:RemoveUnusedShreddedTarotOnNewLevel()
    local currentFloorKey = GetShreddedTarotFloorKey()
    for _, player in ipairs(GetPlayers()) do
        local playerKey = GetShreddedTarotPlayerKey(player)
        if PlayerHasShreddedTarot(player) then
            local state = shreddedTarotStates[playerKey]
            if type(state) == "table" and state.floorKey ~= currentFloorKey and not state.successfulUse then
                RemoveShreddedTarot(player, FindShreddedTarotSlot(player))
                shreddedTarotStates[playerKey] = nil
            elseif type(state) ~= "table" then
                EnsureShreddedTarotState(player)
            end
        elseif playerKey ~= "" then
            shreddedTarotStates[playerKey] = nil
        end
    end
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.RemoveUnusedShreddedTarotOnNewLevel)
end

function Neverbirth:ResetShreddedTarotState(isContinued)
    if isContinued then
        return
    end

    shreddedTarotStates = {}
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetShreddedTarotState)
end
end

--------------------------------------------------
-- 血颅蛊

do
local BLOOD_SKULL_GU_MAX_CHARGE = 3
local BLOOD_SKULL_GU_DAMAGE_BONUS = 1.5
local BLOOD_SKULL_GU_RANGE_BONUS = 40
local BLOOD_SKULL_GU_ENTITY_FAMILIAR = (EntityType and EntityType.ENTITY_FAMILIAR) or 3
local BLOOD_SKULL_GU_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local BLOOD_SKULL_GU_ENTITY_EFFECT = (EntityType and EntityType.ENTITY_EFFECT) or 1000
local BLOOD_SKULL_GU_HEART_VARIANT = (PickupVariant and PickupVariant.PICKUP_HEART) or 10
local BLOOD_SKULL_GU_BLACK_HEART = (HeartSubType and HeartSubType.HEART_BLACK) or 6
local BLOOD_SKULL_GU_POOF_EFFECT = (EffectVariant and (EffectVariant.BLOOD_EXPLOSION or EffectVariant.POOF01)) or 15
local BLOOD_SKULL_GU_CREEP_EFFECT = (EffectVariant and EffectVariant.CREEP_RED) or 22
local BLOOD_SKULL_GU_RANGE_CACHE = (CacheFlag and CacheFlag.CACHE_RANGE) or 64
local BLOOD_SKULL_GU_RED_HEART_DAMAGE = (DamageFlag and DamageFlag.DAMAGE_RED_HEARTS) or 0
local BLOOD_SKULL_GU_FAMILIAR_ITEM_SCAN_MAX = 1000
local BLOOD_SKULL_GU_TEMPORARY_FAMILIARS = {
    [FamiliarVariant and FamiliarVariant.BLUE_FLY or 43] = true,
    [FamiliarVariant and FamiliarVariant.BLUE_SPIDER or 73] = true,
    [FamiliarVariant and FamiliarVariant.WISP or 206] = true,
    [FamiliarVariant and FamiliarVariant.ABYSS_LOCUST or 231] = true,
}

local function BloodSkullGuFamiliarVariant(name, fallback)
    return FamiliarVariant and FamiliarVariant[name] or fallback
end

local function BloodSkullGuCollectibleType(name, fallback)
    return CollectibleType and CollectibleType[name] or fallback
end

local function BuildBloodSkullGuFamiliarSourceItems()
    local mappings = {}

    local function add(variantName, variantFallback, collectibleName, collectibleFallback)
        local variant = BloodSkullGuFamiliarVariant(variantName, variantFallback)
        local collectible = BloodSkullGuCollectibleType(collectibleName, collectibleFallback)
        if variant ~= nil and IsValidItemId(collectible) then
            mappings[variant] = mappings[variant] or {}
            mappings[variant][#mappings[variant] + 1] = collectible
        end
    end

    add("BROTHER_BOBBY", 1, "COLLECTIBLE_BROTHER_BOBBY", 8)
    add("SISTER_MAGGY", 7, "COLLECTIBLE_SISTER_MAGGY", 67)
    add("LITTLE_STEVEN", 5, "COLLECTIBLE_LITTLE_STEVEN", 100)
    add("ROBO_BABY", 6, "COLLECTIBLE_ROBO_BABY", 95)
    add("GUARDIAN_ANGEL", 32, "COLLECTIBLE_GUARDIAN_ANGEL", 112)
    add("DEMON_BABY", 2, "COLLECTIBLE_DEMON_BABY", 113)
    add("GHOST_BABY", 9, "COLLECTIBLE_GHOST_BABY", 163)
    add("HARLEQUIN_BABY", 10, "COLLECTIBLE_HARLEQUIN_BABY", 167)
    add("RAINBOW_BABY", 11, "COLLECTIBLE_RAINBOW_BABY", 174)
    add("ABEL", 8, "COLLECTIBLE_ABEL", 188)
    add("DRY_BABY", 51, "COLLECTIBLE_DRY_BABY", 265)
    add("ROBO_BABY_2", 53, "COLLECTIBLE_ROBO_BABY_2", 267)
    add("ROTTEN_BABY", 54, "COLLECTIBLE_ROTTEN_BABY", 268)
    add("HEADLESS_BABY", 55, "COLLECTIBLE_HEADLESS_BABY", 269)
    add("LIL_BRIMSTONE", 61, "COLLECTIBLE_LIL_BRIMSTONE", 275)
    add("LIL_HAUNT", 63, "COLLECTIBLE_LIL_HAUNT", 277)
    add("DARK_BUM", 64, "COLLECTIBLE_DARK_BUM", 278)
    add("MONGO_BABY", 74, "COLLECTIBLE_MONGO_BABY", 322)
    add("INCUBUS", 80, "COLLECTIBLE_INCUBUS", 360)
    add("SWORN_PROTECTOR", 83, "COLLECTIBLE_SWORN_PROTECTOR", 363)
    add("CHARGED_BABY", 86, "COLLECTIBLE_CHARGED_BABY", 372)
    add("LIL_GURDY", 87, "COLLECTIBLE_LIL_GURDY", 384)
    add("BUMBO", 88, "COLLECTIBLE_BUMBO", 385)
    add("CENSER", 89, "COLLECTIBLE_CENSER", 387)
    add("SERAPHIM", 92, "COLLECTIBLE_SERAPHIM", 390)
    add("FARTING_BABY", 95, "COLLECTIBLE_FARTING_BABY", 404)
    add("SUCCUBUS", 96, "COLLECTIBLE_SUCCUBUS", 417)
    add("LIL_LOKI", 97, "COLLECTIBLE_LIL_LOKI", 435)
    add("PAPA_FLY", 99, "COLLECTIBLE_PAPA_FLY", 430)
    add("MULTIDIMENSIONAL_BABY", 101, "COLLECTIBLE_MULTIDIMENSIONAL_BABY", 431)
    add("SHADE", 106, "COLLECTIBLE_SHADE", 468)
    add("LIL_MONSTRO", 108, "COLLECTIBLE_LIL_MONSTRO", 471)
    add("KING_BABY", 109, "COLLECTIBLE_KING_BABY", 472)
    add("BIG_CHUBBY", 104, "COLLECTIBLE_BIG_CHUBBY", 473)
    add("ACID_BABY", 112, "COLLECTIBLE_ACID_BABY", 491)
    add("BUDDY_IN_A_BOX", 119, "COLLECTIBLE_BUDDY_IN_A_BOX", 518)
    add("BLOOD_PUPPY", 241, "COLLECTIBLE_BLOOD_PUPPY", 565)
    add("BOILED_BABY", 208, "COLLECTIBLE_BOILED_BABY", 607)
    add("FREEZER_BABY", 209, "COLLECTIBLE_FREEZER_BABY", 608)
    add("LIL_DUMPY", 212, "COLLECTIBLE_LIL_DUMPY", 615)
    add("BOT_FLY", 218, "COLLECTIBLE_BOT_FLY", 629)
    add("CUBE_BABY", 239, "COLLECTIBLE_CUBE_BABY", 652)
    add("MINISAAC", 228, "COLLECTIBLE_QUINTS", 661)
    add("LIL_ABADDON", 230, "COLLECTIBLE_LIL_ABADDON", 679)
    add("TWISTED_BABY", 235, "COLLECTIBLE_TWISTED_PAIR", 698)

    return mappings
end

local BLOOD_SKULL_GU_FAMILIAR_SOURCE_ITEMS = BuildBloodSkullGuFamiliarSourceItems()

local bloodSkullGuGrowth = {}
local bloodSkullGuFamiliarItemCache = {}

local function BuildBloodSkullGuActiveSlots()
    if not ActiveSlot then
        return { 0, 1, 2, 3 }
    end

    local slots = {}
    if ActiveSlot.SLOT_PRIMARY ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_PRIMARY
    end
    if ActiveSlot.SLOT_SECONDARY ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_SECONDARY
    end
    if ActiveSlot.SLOT_POCKET ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_POCKET
    end
    if ActiveSlot.SLOT_POCKET2 ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_POCKET2
    end

    return slots
end

local BLOOD_SKULL_GU_ACTIVE_SLOTS = BuildBloodSkullGuActiveSlots()

local function GetBloodSkullGuPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function GetBloodSkullGuState(player)
    local playerKey = GetBloodSkullGuPlayerKey(player)
    if playerKey == "" then
        return nil
    end

    local state = bloodSkullGuGrowth[playerKey]
    if type(state) ~= "table" then
        state = {
            damageBonus = 0,
            rangeBonus = 0,
        }
        bloodSkullGuGrowth[playerKey] = state
    end

    return state
end

local function FindBloodSkullGuSlot(player, preferredSlot)
    if not player or not player.GetActiveItem then
        return nil
    end

    if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == Items.BloodSkullGu then
        return preferredSlot
    end

    for _, slot in ipairs(BLOOD_SKULL_GU_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.BloodSkullGu then
            return slot
        end
    end

    return nil
end

local function GetBloodSkullGuCharge(player, slot)
    if player and player.GetActiveCharge then
        return tonumber(player:GetActiveCharge(slot)) or 0
    end

    return BLOOD_SKULL_GU_MAX_CHARGE
end

local function DischargeBloodSkullGu(player, slot)
    if not player then
        return
    end

    if player.SetActiveCharge then
        player:SetActiveCharge(0, slot)
    elseif player.DischargeActiveItem then
        player:DischargeActiveItem(slot)
    end
end

local function GetBloodSkullGuRNG(player)
    if player and player.GetCollectibleRNG then
        local ok, rng = pcall(function()
            return player:GetCollectibleRNG(Items.BloodSkullGu)
        end)
        if ok and rng and rng.RandomInt then
            return rng
        end
    end

    return nil
end

local function BloodSkullGuRandomInt(player, max)
    max = tonumber(max) or 1
    if max <= 1 then
        return 0
    end

    local rng = GetBloodSkullGuRNG(player)
    if rng then
        local ok, value = pcall(function()
            return rng:RandomInt(max)
        end)
        if ok and value ~= nil then
            return math.max(0, math.min(max - 1, tonumber(value) or 0))
        end
    end

    return math.random(max) - 1
end

local function ExtractBloodSkullGuPlayer(entity)
    if not entity then
        return nil
    end

    if entity.ToPlayer then
        local ok, player = pcall(function()
            return entity:ToPlayer()
        end)
        if ok and player then
            return player
        end
    end

    return nil
end

local function IsBloodSkullGuSamePlayer(candidate, player)
    if not candidate or not player then
        return false
    end

    if candidate == player then
        return true
    end

    local candidatePlayer = ExtractBloodSkullGuPlayer(candidate) or candidate
    return tostring(candidatePlayer and candidatePlayer.InitSeed or "") == tostring(player.InitSeed or "")
end

local function IsBloodSkullGuEntityRemoved(entity)
    if not entity then
        return true
    end

    if entity.IsDead then
        local ok, dead = pcall(function()
            return entity:IsDead()
        end)
        if ok and dead then
            return true
        end
    end

    if entity.Exists then
        local ok, exists = pcall(function()
            return entity:Exists()
        end)
        if ok and exists == false then
            return true
        end
    end

    return entity.removed == true
end

local function IsEligibleBloodSkullFamiliar(entity, player)
    if not entity or entity.Type ~= BLOOD_SKULL_GU_ENTITY_FAMILIAR or IsBloodSkullGuEntityRemoved(entity) then
        return false
    end

    local familiar = entity
    if entity.ToFamiliar then
        local ok, converted = pcall(function()
            return entity:ToFamiliar()
        end)
        if ok and converted then
            familiar = converted
        end
    end

    if not familiar then
        return false
    end

    if BLOOD_SKULL_GU_TEMPORARY_FAMILIARS[familiar.Variant] then
        return false
    end

    if familiar.Player ~= nil then
        return IsBloodSkullGuSamePlayer(familiar.Player, player)
    end

    if familiar.SpawnerEntity ~= nil then
        return IsBloodSkullGuSamePlayer(familiar.SpawnerEntity, player)
    end

    return false
end

local function CollectBloodSkullGuFamiliars(player)
    local familiars = {}
    if not Isaac.GetRoomEntities then
        return familiars
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsEligibleBloodSkullFamiliar(entity, player) then
            familiars[#familiars + 1] = entity
        end
    end

    return familiars
end

local function GetBloodSkullGuGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    if ok then
        return game
    end

    return nil
end

local function GetBloodSkullGuRoom()
    local game = GetBloodSkullGuGame()
    return game and game.GetRoom and game:GetRoom() or nil
end

local function GetBloodSkullGuSpawnPosition(position, index)
    local spawnPosition = position or Vector(320, 280)
    if Vector then
        spawnPosition = spawnPosition + Vector(((tonumber(index) or 1) - 1) * 24, 0)
    end

    local room = GetBloodSkullGuRoom()
    if room and room.FindFreePickupSpawnPosition then
        spawnPosition = room:FindFreePickupSpawnPosition(spawnPosition, 40, true, false)
    end

    return spawnPosition
end

local function SpawnBloodSkullGuEffects(position, player)
    if not Isaac.Spawn then
        return
    end

    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    pcall(function()
        Isaac.Spawn(BLOOD_SKULL_GU_ENTITY_EFFECT, BLOOD_SKULL_GU_POOF_EFFECT, 0, position, velocity, player)
    end)
    if BLOOD_SKULL_GU_CREEP_EFFECT then
        pcall(function()
            Isaac.Spawn(BLOOD_SKULL_GU_ENTITY_EFFECT, BLOOD_SKULL_GU_CREEP_EFFECT, 0, position, velocity, player)
        end)
    end
end

local function SpawnBloodSkullGuBlackHearts(player, position, count)
    local game = GetBloodSkullGuGame()
    if not game or not game.Spawn then
        return
    end

    local room = GetBloodSkullGuRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }

    for index = 1, count do
        game:Spawn(
            BLOOD_SKULL_GU_ENTITY_PICKUP,
            BLOOD_SKULL_GU_HEART_VARIANT,
            GetBloodSkullGuSpawnPosition(position, index),
            velocity,
            player,
            BLOOD_SKULL_GU_BLACK_HEART,
            seed + 900 + index
        )
    end
end

local function RefreshBloodSkullGuCache(player)
    if not player then
        return
    end

    if player.AddCacheFlags and CacheFlag and CacheFlag.CACHE_DAMAGE then
        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
    end
    if player.AddCacheFlags then
        player:AddCacheFlags(BLOOD_SKULL_GU_RANGE_CACHE)
    end
    if player.EvaluateItems then
        player:EvaluateItems()
    end
end

local function RefreshBloodSkullGuFamiliarCache(player)
    if not player then
        return
    end

    if player.AddCacheFlags and CacheFlag and CacheFlag.CACHE_FAMILIARS then
        player:AddCacheFlags(CacheFlag.CACHE_FAMILIARS)
    end
    if player.EvaluateItems then
        player:EvaluateItems()
    end
end

local function GrantBloodSkullGuGrowth(player)
    local state = GetBloodSkullGuState(player)
    if not state then
        return
    end

    state.damageBonus = (tonumber(state.damageBonus) or 0) + BLOOD_SKULL_GU_DAMAGE_BONUS
    state.rangeBonus = (tonumber(state.rangeBonus) or 0) + BLOOD_SKULL_GU_RANGE_BONUS
    RefreshBloodSkullGuCache(player)
end

local function PlayerHasBloodSkullGuCollectible(player, itemId)
    return player and player.GetCollectibleNum and IsValidItemId(itemId) and player:GetCollectibleNum(itemId) > 0
end

local function GetBloodSkullGuCollectibleConfig(itemConfig, itemId)
    if not itemConfig or not itemConfig.GetCollectible or not IsValidItemId(itemId) then
        return nil
    end

    local ok, collectible = pcall(function()
        return itemConfig:GetCollectible(itemId)
    end)
    if ok then
        return collectible
    end

    return nil
end

local function GetBloodSkullGuDirectSourceItem(familiar, player)
    local candidates = {
        familiar and familiar.CollectibleType,
        familiar and familiar.Collectible,
        familiar and familiar.ItemId,
        familiar and familiar.SourceCollectible,
        familiar and familiar.SourceItem,
    }

    for _, itemId in ipairs(candidates) do
        if PlayerHasBloodSkullGuCollectible(player, itemId) then
            return itemId
        end
    end

    return nil
end

local function FindBloodSkullGuSourceCollectible(familiar, player)
    if not familiar or not player then
        return nil
    end

    local directItem = GetBloodSkullGuDirectSourceItem(familiar, player)
    if directItem then
        return directItem
    end

    local variant = familiar.Variant
    if variant == nil or not Isaac.GetItemConfig then
        return nil
    end

    local cached = bloodSkullGuFamiliarItemCache[variant]
    if type(cached) == "table" then
        for _, itemId in ipairs(cached) do
            if PlayerHasBloodSkullGuCollectible(player, itemId) then
                return itemId
            end
        end
    end

    local staticCandidates = BLOOD_SKULL_GU_FAMILIAR_SOURCE_ITEMS[variant]
    if type(staticCandidates) == "table" then
        for _, itemId in ipairs(staticCandidates) do
            if PlayerHasBloodSkullGuCollectible(player, itemId) then
                bloodSkullGuFamiliarItemCache[variant] = staticCandidates
                return itemId
            end
        end
    end

    local itemConfig = Isaac.GetItemConfig()
    local candidates = {}
    for itemId = 1, BLOOD_SKULL_GU_FAMILIAR_ITEM_SCAN_MAX do
        local collectible = GetBloodSkullGuCollectibleConfig(itemConfig, itemId)
        if collectible and collectible.FamiliarVariant == variant then
            candidates[#candidates + 1] = itemId
            if PlayerHasBloodSkullGuCollectible(player, itemId) then
                bloodSkullGuFamiliarItemCache[variant] = candidates
                return itemId
            end
        end
    end

    bloodSkullGuFamiliarItemCache[variant] = candidates
    return nil
end

local function CollectBloodSkullGuSourceFamiliars(player)
    local candidates = {}
    for _, familiar in ipairs(CollectBloodSkullGuFamiliars(player)) do
        if FindBloodSkullGuSourceCollectible(familiar, player) then
            candidates[#candidates + 1] = familiar
        end
    end

    return candidates
end

local function RemoveBloodSkullGuFamiliar(player, familiar)
    local sourceItem = FindBloodSkullGuSourceCollectible(familiar, player)
    if sourceItem and player and player.RemoveCollectible then
        local ok, err = pcall(function()
            player:RemoveCollectible(sourceItem)
        end)
        if ok then
            RefreshBloodSkullGuFamiliarCache(player)
        else
            DebugLog("[neverbirth] Blood Skull Gu source item removal failed: " .. tostring(err))
        end
    end

    if familiar and familiar.Remove then
        pcall(function()
            familiar:Remove()
        end)
    end
end

local function ApplyBloodSkullGuBacklash(player)
    if not player or not player.TakeDamage then
        return
    end

    bloodSkullGuBacklashDepth = bloodSkullGuBacklashDepth + 1
    local ok, err = pcall(function()
        player:TakeDamage(1, BLOOD_SKULL_GU_RED_HEART_DAMAGE, EntityRef(player), 0)
    end)
    bloodSkullGuBacklashDepth = math.max(0, bloodSkullGuBacklashDepth - 1)
    if not ok then
        DebugLog("[neverbirth] Blood Skull Gu backlash failed: " .. tostring(err))
    end
end

function Neverbirth:UseBloodSkullGu(_, _, player, _, activeSlot)
    if not player then
        return false
    end

    local slot = FindBloodSkullGuSlot(player, activeSlot) or activeSlot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    if GetBloodSkullGuCharge(player, slot) < BLOOD_SKULL_GU_MAX_CHARGE then
        return false
    end

    local familiars = CollectBloodSkullGuSourceFamiliars(player)
    DischargeBloodSkullGu(player, slot)

    if #familiars <= 0 then
        ApplyBloodSkullGuBacklash(player)
        return true
    end

    local selected = familiars[BloodSkullGuRandomInt(player, #familiars) + 1]
    local position = selected and selected.Position or (player.Position or Vector(320, 280))
    SpawnBloodSkullGuEffects(position, player)
    RemoveBloodSkullGuFamiliar(player, selected)
    GrantBloodSkullGuGrowth(player)
    SpawnBloodSkullGuBlackHearts(player, position, 1 + BloodSkullGuRandomInt(player, 2))
    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseBloodSkullGu, Items.BloodSkullGu)

function Neverbirth:EvaluateBloodSkullGu(player, cacheFlag)
    local state = bloodSkullGuGrowth[GetBloodSkullGuPlayerKey(player)]
    if type(state) ~= "table" then
        return
    end

    if CacheFlag and cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage + (tonumber(state.damageBonus) or 0)
    elseif cacheFlag == BLOOD_SKULL_GU_RANGE_CACHE then
        player.TearRange = player.TearRange + (tonumber(state.rangeBonus) or 0)
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateBloodSkullGu)

function Neverbirth:ResetBloodSkullGuState(isContinued)
    if isContinued then
        return
    end

    bloodSkullGuGrowth = {}
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetBloodSkullGuState)
end
end

--------------------------------------------------
-- 老大的指令

do
local BOSS_ORDER_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local BOSS_ORDER_CARD_VARIANT = (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300
local BOSS_ORDER_MIN_CARD_SUBTYPE = 1
local BOSS_ORDER_MAX_CARD_SUBTYPE = (Card and type(Card.RUNE_HAGALAZ) == "number" and Card.RUNE_HAGALAZ > 1) and (Card.RUNE_HAGALAZ - 1) or 31
local BOSS_ORDER_MAX_REASONABLE_CARD_SUBTYPE = 10000
local BOSS_ORDER_CARD_PICK_RETRIES = 16
local BOSS_ORDER_MIN_SPAWN_DISTANCE = 80
local BOSS_ORDER_SPAWN_OFFSET = 120
local BOSS_ORDER_CHAMPION_CHANCE = 15
local BOSS_ORDER_CHAMPION_COLOR = -1

local function BossOrderTarget(entityType, variant, subtype, rewardCategory)
    return {
        entityType = entityType,
        variant = variant or 0,
        subtype = subtype or 0,
        rewardCategory = rewardCategory or "normal",
    }
end

local BOSS_ORDER_TARGET_ROLLS = {
    "normal",
    "normal",
    "boss",
    "boss",
    "boss",
}

local BOSS_ORDER_NORMAL_TARGETS_BY_STAGE_GROUP = {
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_GAPER or 10),
        BossOrderTarget(EntityType and EntityType.ENTITY_HORF or 12),
        BossOrderTarget(EntityType and EntityType.ENTITY_POOTER or 14),
        BossOrderTarget(EntityType and EntityType.ENTITY_ATTACKFLY or 13),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_CLOTTY or 21),
        BossOrderTarget(EntityType and EntityType.ENTITY_MULLIGAN or 22),
        BossOrderTarget(EntityType and EntityType.ENTITY_CHARGER or 23),
        BossOrderTarget(EntityType and EntityType.ENTITY_SPITTY or 31),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_VIS or 39),
        BossOrderTarget(EntityType and EntityType.ENTITY_LEECH or 55),
        BossOrderTarget(EntityType and EntityType.ENTITY_KNIGHT or 32),
        BossOrderTarget(EntityType and EntityType.ENTITY_HOST or 44),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_VIS or 39),
        BossOrderTarget(EntityType and EntityType.ENTITY_LEECH or 55),
        BossOrderTarget(EntityType and EntityType.ENTITY_BONY or 227),
        BossOrderTarget(EntityType and EntityType.ENTITY_NULLS or 282),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_GAPER or 10),
        BossOrderTarget(EntityType and EntityType.ENTITY_HORF or 12),
        BossOrderTarget(EntityType and EntityType.ENTITY_LEECH or 55),
        BossOrderTarget(EntityType and EntityType.ENTITY_VIS or 39),
    },
}

local BOSS_ORDER_BOSS_RUSH_TARGETS = {
    BossOrderTarget(EntityType and EntityType.ENTITY_MONSTRO or 20, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_LARRYJR or 19, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_DUKE or 30, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_GURDY or 36, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_CHUB or 28, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_PIN or 62, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_FAMINE or 63, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_PESTILENCE or 64, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_WAR or 65, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_DEATH or 66, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_LOKI or 81, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_MONSTRO2 or 43, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_GURDYJR or 97, 0, 0, "boss"),
}

local function GetBossOrderGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    return ok and game or nil
end

local function GetBossOrderRoom()
    local game = GetBossOrderGame()
    if not game or not game.GetRoom then
        return nil
    end

    local ok, room = pcall(function()
        return game:GetRoom()
    end)
    return ok and room or nil
end

local function GetBossOrderItemPool()
    local game = GetBossOrderGame()
    if not game or not game.GetItemPool then
        return nil
    end

    local ok, itemPool = pcall(function()
        return game:GetItemPool()
    end)
    return ok and itemPool or nil
end

local function GetBossOrderItemConfig()
    if not Isaac or not Isaac.GetItemConfig then
        return nil
    end

    local ok, itemConfig = pcall(function()
        return Isaac.GetItemConfig()
    end)
    return ok and itemConfig or nil
end

local function GetBossOrderLevel()
    local game = GetBossOrderGame()
    if not game or not game.GetLevel then
        return nil
    end

    local ok, level = pcall(function()
        return game:GetLevel()
    end)
    return ok and level or nil
end

local function GetBossOrderRandomInt(player, max)
    if max <= 0 then
        return 0
    end

    if player and player.GetCollectibleRNG and IsValidItemId(Items.BossOrder) then
        local okRng, rng = pcall(function()
            return player:GetCollectibleRNG(Items.BossOrder)
        end)
        if okRng and rng and rng.RandomInt then
            local okRoll, value = pcall(function()
                return rng:RandomInt(max)
            end)
            if okRoll and type(value) == "number" then
                return math.max(0, math.min(max - 1, math.floor(value)))
            end
        end
    end

    local room = GetBossOrderRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    return math.max(0, math.floor(seed) % max)
end

local function GetBossOrderStageGroup()
    local level = GetBossOrderLevel()
    local stage = 1
    if level and level.GetStage then
        local ok, value = pcall(function()
            return level:GetStage()
        end)
        if ok and type(value) == "number" then
            stage = math.max(1, math.floor(value))
        end
    end

    if stage <= 2 then
        return 1
    end
    if stage <= 4 then
        return 2
    end
    if stage <= 6 then
        return 3
    end
    if stage <= 8 then
        return 4
    end
    return 5
end

local function CollectBossOrderTargetsFromPool(pool)
    local targets = {}
    for _, target in ipairs(pool or {}) do
        if type(target.entityType) == "number" and target.entityType > 0 then
            targets[#targets + 1] = target
        end
    end
    return targets
end

local function CollectBossOrderNormalTargets()
    local stageGroup = GetBossOrderStageGroup()
    local targets = CollectBossOrderTargetsFromPool(BOSS_ORDER_NORMAL_TARGETS_BY_STAGE_GROUP[stageGroup])
    if #targets <= 0 then
        targets = CollectBossOrderTargetsFromPool(BOSS_ORDER_NORMAL_TARGETS_BY_STAGE_GROUP[1])
    end
    return targets
end

local function CollectBossOrderBossRushTargets()
    return CollectBossOrderTargetsFromPool(BOSS_ORDER_BOSS_RUSH_TARGETS)
end

local function GetBossOrderOffsetPosition(position, x, y)
    if not position then
        return nil
    end

    local newX = (position.X or 0) + x
    local newY = (position.Y or 0) + y
    return (Vector and Vector(newX, newY)) or { X = newX, Y = newY }
end

local function IsBossOrderSpawnFarEnough(position, player)
    if not position or not player or not player.Position then
        return true
    end

    local dx = (position.X or 0) - (player.Position.X or 0)
    local dy = (position.Y or 0) - (player.Position.Y or 0)
    return dx * dx + dy * dy >= BOSS_ORDER_MIN_SPAWN_DISTANCE * BOSS_ORDER_MIN_SPAWN_DISTANCE
end

local function TryBossOrderSpawnPosition(room, candidate, player)
    if not candidate then
        return nil
    end

    if room and room.FindFreeTilePosition then
        local ok, freePosition = pcall(function()
            return room:FindFreeTilePosition(candidate, BOSS_ORDER_MIN_SPAWN_DISTANCE)
        end)
        if ok and freePosition and IsBossOrderSpawnFarEnough(freePosition, player) then
            return freePosition
        end
    end

    if room and room.FindFreePickupSpawnPosition then
        local ok, freePosition = pcall(function()
            return room:FindFreePickupSpawnPosition(candidate, BOSS_ORDER_MIN_SPAWN_DISTANCE, true, false)
        end)
        if ok and freePosition and IsBossOrderSpawnFarEnough(freePosition, player) then
            return freePosition
        end
    end

    if IsBossOrderSpawnFarEnough(candidate, player) then
        return candidate
    end

    return nil
end

local function GetBossOrderSpawnPosition(player)
    local room = GetBossOrderRoom()
    local fallbackPosition = player and player.Position or (Vector and Vector(320, 280)) or { X = 320, Y = 280 }
    local candidates = {}

    if room and room.GetCenterPos then
        local ok, center = pcall(function()
            return room:GetCenterPos()
        end)
        if ok and center then
            candidates[#candidates + 1] = center
        end
    end

    if player and player.Position then
        local offsets = {
            { x = BOSS_ORDER_SPAWN_OFFSET, y = 0 },
            { x = -BOSS_ORDER_SPAWN_OFFSET, y = 0 },
            { x = 0, y = BOSS_ORDER_SPAWN_OFFSET },
            { x = 0, y = -BOSS_ORDER_SPAWN_OFFSET },
        }
        for _, offset in ipairs(offsets) do
            candidates[#candidates + 1] = GetBossOrderOffsetPosition(player.Position, offset.x, offset.y)
        end
    end

    candidates[#candidates + 1] = fallbackPosition

    for _, candidate in ipairs(candidates) do
        local position = TryBossOrderSpawnPosition(room, candidate, player)
        if position then
            return position
        end
    end

    return fallbackPosition
end

local function SelectBossOrderTarget(player)
    local targetType = BOSS_ORDER_TARGET_ROLLS[GetBossOrderRandomInt(player, #BOSS_ORDER_TARGET_ROLLS) + 1] or "normal"
    local targets = targetType == "boss" and CollectBossOrderBossRushTargets() or CollectBossOrderNormalTargets()

    if #targets <= 0 and targetType == "boss" then
        targets = CollectBossOrderNormalTargets()
    elseif #targets <= 0 then
        targets = CollectBossOrderBossRushTargets()
    end

    if #targets <= 0 then
        return nil
    end

    return targets[GetBossOrderRandomInt(player, #targets) + 1]
end

local function GetBossOrderEntityData(entity)
    if entity and entity.GetData then
        local ok, data = pcall(function()
            return entity:GetData()
        end)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

local function GetBossOrderNpc(entity)
    if entity and entity.ToNPC then
        local ok, npc = pcall(function()
            return entity:ToNPC()
        end)
        if ok and npc then
            return npc
        end
    end

    return entity
end

local function IsBossOrderChampion(npc)
    if npc and npc.IsChampion then
        local ok, isChampion = pcall(function()
            return npc:IsChampion()
        end)
        return ok and isChampion == true
    end

    return false
end

local function MarkBossOrderTarget(entity, target)
    local data = GetBossOrderEntityData(entity)
    if not data then
        return false
    end

    data.neverbirthBossOrderTarget = true
    data.neverbirthBossOrderRewarded = false
    data.neverbirthBossOrderRewardCategory = target and target.rewardCategory or "normal"
    return true
end

local function TryBossOrderMakeChampion(entity, player, target)
    if not target or target.rewardCategory ~= "normal" then
        return false
    end

    local npc = GetBossOrderNpc(entity)
    if not npc or not npc.MakeChampion or IsBossOrderChampion(npc) then
        return false
    end

    if GetBossOrderRandomInt(player, 100) >= BOSS_ORDER_CHAMPION_CHANCE then
        return false
    end

    local room = GetBossOrderRoom()
    local seed = npc.InitSeed or (room and room.GetSpawnSeed and room:GetSpawnSeed()) or 0
    local ok = pcall(function()
        npc:MakeChampion(seed, BOSS_ORDER_CHAMPION_COLOR, true)
    end)

    return ok and IsBossOrderChampion(npc)
end

local function SpawnBossOrderTarget(player, target)
    if not Isaac or not Isaac.Spawn or not target then
        return nil
    end

    local position = GetBossOrderSpawnPosition(player)
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    local ok, entity = pcall(function()
        return Isaac.Spawn(target.entityType, target.variant or 0, target.subtype or 0, position, velocity, player)
    end)
    if not ok or not entity then
        return nil
    end

    if not MarkBossOrderTarget(entity, target) then
        return nil
    end

    TryBossOrderMakeChampion(entity, player, target)
    return entity
end

function Neverbirth:UseBossOrder(_, _, player)
    local target = SelectBossOrderTarget(player)
    return SpawnBossOrderTarget(player, target) ~= nil
end

local function IsBossOrderBoss(npc, data)
    if data and data.neverbirthBossOrderRewardCategory == "boss" then
        return true
    end

    if npc and npc.IsBoss then
        local ok, isBoss = pcall(function()
            return npc:IsBoss()
        end)
        return ok and isBoss == true
    end

    return false
end

local function GetBossOrderRewardCount(npc, data)
    if IsBossOrderBoss(npc, data) then
        return 3
    end

    if IsBossOrderChampion(npc) then
        return 2
    end

    return 1
end

local function GetBossOrderRewardSeed(npc, index, attempt)
    local seed = npc and type(npc.InitSeed) == "number" and npc.InitSeed or 0
    if seed == 0 then
        local room = GetBossOrderRoom()
        if room and room.GetSpawnSeed then
            local ok, roomSeed = pcall(function()
                return room:GetSpawnSeed()
            end)
            if ok and type(roomSeed) == "number" then
                seed = roomSeed
            end
        end
    end

    return math.abs(math.floor(seed + (index or 1) * 37 + (attempt or 0) * 101))
end

local function IsBossOrderKnownCardSubtype(subtype)
    subtype = math.floor(tonumber(subtype) or 0)
    if subtype < BOSS_ORDER_MIN_CARD_SUBTYPE then
        return false
    end
    if subtype > BOSS_ORDER_MAX_REASONABLE_CARD_SUBTYPE then
        return false
    end

    local itemConfig = GetBossOrderItemConfig()
    if itemConfig and itemConfig.GetCard then
        local ok, cardConfig = pcall(function()
            return itemConfig:GetCard(subtype)
        end)
        if not ok or cardConfig == nil then
            return false
        end

        local displayFields = { "Name", "Description", "GfxFileName", "HudAnim" }
        local hasDisplayData = false
        for _, field in ipairs(displayFields) do
            local fieldOk, value = pcall(function()
                return cardConfig[field]
            end)
            if fieldOk and value ~= nil and tostring(value) ~= "" then
                hasDisplayData = true
                break
            end
        end

        if not hasDisplayData then
            return false
        end
    end

    if EID then
        local eidChecked = false
        local descObj = nil
        local eidCalls = {
            function() return EID.getDescriptionObjByID and EID:getDescriptionObjByID(BOSS_ORDER_ENTITY_PICKUP, BOSS_ORDER_CARD_VARIANT, subtype) end,
            function() return EID.getDescriptionObj and EID:getDescriptionObj(BOSS_ORDER_ENTITY_PICKUP, BOSS_ORDER_CARD_VARIANT, subtype) end,
        }
        for _, call in ipairs(eidCalls) do
            local ok, result = pcall(call)
            if ok and result ~= nil then
                descObj = result
                eidChecked = true
                break
            elseif ok then
                eidChecked = true
            end
        end
        if descObj == nil and EID.getObjectName then
            local ok, name = pcall(function()
                return EID:getObjectName(BOSS_ORDER_ENTITY_PICKUP, BOSS_ORDER_CARD_VARIANT, subtype)
            end)
            if ok then
                eidChecked = true
                if name ~= nil then
                    descObj = { Name = name }
                end
            end
        end

        if eidChecked then
            if type(descObj) ~= "table" then
                return false
            end
            local name = tostring(descObj.Name or descObj.ObjName or "")
            local description = tostring(descObj.Description or "")
            local combined = string.lower(name .. " " .. description)
            if combined == " " then
                return false
            end
            if combined:find("no description available", 1, true) then
                return false
            end
            if combined:find(tostring(BOSS_ORDER_ENTITY_PICKUP) .. "." .. tostring(BOSS_ORDER_CARD_VARIANT) .. ".", 1, true) then
                return false
            end
        end
    end

    return true
end

local function AddBossOrderCardCandidate(candidates, seen, subtype)
    subtype = math.floor(tonumber(subtype) or 0)
    if subtype >= BOSS_ORDER_MIN_CARD_SUBTYPE and not seen[subtype] and IsBossOrderKnownCardSubtype(subtype) then
        seen[subtype] = true
        candidates[#candidates + 1] = subtype
    end
end

local function CollectBossOrderRewardCardCandidates()
    local candidates = {}
    local seen = {}

    for subtype = BOSS_ORDER_MIN_CARD_SUBTYPE, BOSS_ORDER_MAX_CARD_SUBTYPE do
        AddBossOrderCardCandidate(candidates, seen, subtype)
    end

    if type(Card) == "table" then
        for _, subtype in pairs(Card) do
            AddBossOrderCardCandidate(candidates, seen, subtype)
        end
    end

    table.sort(candidates)
    return candidates
end

local function GetBossOrderPoolCardSubtype(npc, index, attempt)
    local itemPool = GetBossOrderItemPool()
    if not itemPool or not itemPool.GetCard then
        return nil
    end

    local seed = GetBossOrderRewardSeed(npc, index, attempt)
    local attempts = {
        function() return itemPool:GetCard(seed, true, true, false) end,
        function() return itemPool:GetCard(seed, true, false, false) end,
    }
    for _, roll in ipairs(attempts) do
        local ok, subtype = pcall(roll)
        if ok and IsBossOrderKnownCardSubtype(subtype) then
            return math.floor(subtype)
        end
    end
    return nil
end

local function GetBossOrderRewardCardSubtype(npc, index)
    for attempt = 0, BOSS_ORDER_CARD_PICK_RETRIES - 1 do
        local subtype = GetBossOrderPoolCardSubtype(npc, index, attempt)
        if subtype then
            return subtype
        end
    end

    local candidates = CollectBossOrderRewardCardCandidates()
    if #candidates <= 0 then
        return BOSS_ORDER_MIN_CARD_SUBTYPE
    end

    local seed = GetBossOrderRewardSeed(npc, index, 0)
    return candidates[(seed % #candidates) + 1]
end

local function SpawnBossOrderCards(npc, count)
    if not Isaac or not Isaac.Spawn then
        return
    end

    local origin = npc and npc.Position or (Vector and Vector(320, 280)) or { X = 320, Y = 280 }
    local room = GetBossOrderRoom()
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }

    for index = 1, count do
        local position = origin
        if room and room.FindFreePickupSpawnPosition then
            local ok, freePosition = pcall(function()
                return room:FindFreePickupSpawnPosition(origin, 20 + index * 5, true, false)
            end)
            if ok and freePosition then
                position = freePosition
            end
        end

        local cardSubtype = GetBossOrderRewardCardSubtype(npc, index)
        pcall(function()
            Isaac.Spawn(BOSS_ORDER_ENTITY_PICKUP, BOSS_ORDER_CARD_VARIANT, cardSubtype, position, velocity, npc)
        end)
    end
end

function Neverbirth:RewardBossOrderTarget(npc)
    local data = GetBossOrderEntityData(npc)
    if not data or data.neverbirthBossOrderTarget ~= true or data.neverbirthBossOrderRewarded == true then
        return
    end

    data.neverbirthBossOrderRewarded = true
    SpawnBossOrderCards(npc, GetBossOrderRewardCount(npc, data))
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseBossOrder, Items.BossOrder)

if ModCallbacks.MC_POST_NPC_DEATH then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, Neverbirth.RewardBossOrderTarget)
end

if ModCallbacks.MC_POST_ENTITY_KILL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, Neverbirth.RewardBossOrderTarget)
end
end

--------------------------------------------------
-- 生死一念间

do
local BETWEEN_DEATH_LIFE_MAX_CHARGE = 12
local BETWEEN_DEATH_LIFE_ACTIVE_SLOTS = {
    ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0,
    ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1,
    ActiveSlot and ActiveSlot.SLOT_POCKET or 2,
    ActiveSlot and ActiveSlot.SLOT_POCKET2 or 3,
}
local BETWEEN_DEATH_LIFE_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local BETWEEN_DEATH_LIFE_COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local BETWEEN_DEATH_LIFE_ROOM_BOSS = (RoomType and RoomType.ROOM_BOSS) or 5
local BETWEEN_DEATH_LIFE_DEATH_CERTIFICATE = (CollectibleType and CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE) or nil
local BETWEEN_DEATH_LIFE_CHAMPION_COLOR = -1
local BETWEEN_DEATH_LIFE_NORMAL_HP_MULTIPLIER = 1.35
local BETWEEN_DEATH_LIFE_BOSS_HP_MULTIPLIER = 1.5
local BETWEEN_DEATH_LIFE_NORMAL_SPEED_MULTIPLIER = 1.05
local BETWEEN_DEATH_LIFE_BOSS_SPEED_MULTIPLIER = 1.08
local betweenDeathLifeDeathCertificateId = nil

local function GetBetweenDeathLifeGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    if ok then
        return game
    end

    return nil
end

local function GetBetweenDeathLifeLevel()
    local game = GetBetweenDeathLifeGame()
    return game and game.GetLevel and game:GetLevel() or nil
end

local function GetBetweenDeathLifeRoom()
    local game = GetBetweenDeathLifeGame()
    return game and game.GetRoom and game:GetRoom() or nil
end

local function GetBetweenDeathLifeFloorKey()
    local level = GetBetweenDeathLifeLevel()
    if not level then
        return GetCurrentRunSeed() .. ":unknown"
    end

    local stage = level.GetStage and level:GetStage() or "unknown"
    local stageType = level.GetStageType and level:GetStageType() or "unknown"
    return GetCurrentRunSeed() .. ":" .. tostring(stage) .. ":" .. tostring(stageType)
end

local function GetBetweenDeathLifeRoomKey()
    local level = GetBetweenDeathLifeLevel()
    local room = GetBetweenDeathLifeRoom()
    local roomIndex = nil

    if level and level.GetCurrentRoomIndex then
        local ok, index = pcall(function()
            return level:GetCurrentRoomIndex()
        end)
        if ok then
            roomIndex = index
        end
    end

    if roomIndex == nil and room and room.GetSpawnSeed then
        local ok, seed = pcall(function()
            return room:GetSpawnSeed()
        end)
        if ok then
            roomIndex = "seed:" .. tostring(seed)
        end
    end

    return GetBetweenDeathLifeFloorKey() .. ":" .. tostring(roomIndex or "unknown")
end

local function FindBetweenDeathLifeSlot(player, preferredSlot)
    if not player or not player.GetActiveItem then
        return nil
    end

    if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == Items.BetweenDeathAndLife then
        return preferredSlot
    end

    for _, slot in ipairs(BETWEEN_DEATH_LIFE_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.BetweenDeathAndLife then
            return slot
        end
    end

    return nil
end

local function GetBetweenDeathLifeCharge(player, slot)
    if player and player.GetActiveCharge then
        local ok, charge = pcall(function()
            return player:GetActiveCharge(slot)
        end)
        if ok then
            return tonumber(charge) or 0
        end
    end

    return BETWEEN_DEATH_LIFE_MAX_CHARGE
end

local function RemoveBetweenDeathLifeItem(player, slot)
    if player and player.RemoveCollectible then
        local ok, err = pcall(function()
            player:RemoveCollectible(Items.BetweenDeathAndLife, false, slot or FindBetweenDeathLifeSlot(player) or 0, true)
        end)
        if not ok then
            DebugLog("[neverbirth] Between Death and Life removal failed: " .. tostring(err))
        end
    elseif player and player.SetActiveCharge then
        player:SetActiveCharge(0, slot or 0)
    end
end

local function IsBetweenDeathLifeBossRoomClear()
    local room = GetBetweenDeathLifeRoom()
    if not room or not room.GetType or not room.IsClear then
        return false
    end

    local okType, roomType = pcall(function()
        return room:GetType()
    end)
    local okClear, isClear = pcall(function()
        return room:IsClear()
    end)

    return okType and okClear and roomType == BETWEEN_DEATH_LIFE_ROOM_BOSS and isClear == true
end

local function GetBetweenDeathLifeDeathCertificateId()
    if IsValidItemId(betweenDeathLifeDeathCertificateId) then
        return betweenDeathLifeDeathCertificateId
    end

    if IsValidItemId(BETWEEN_DEATH_LIFE_DEATH_CERTIFICATE) then
        betweenDeathLifeDeathCertificateId = BETWEEN_DEATH_LIFE_DEATH_CERTIFICATE
        return betweenDeathLifeDeathCertificateId
    end

    if Isaac.GetItemIdByName then
        local ok, itemId = pcall(function()
            return Isaac.GetItemIdByName("Death Certificate")
        end)
        if ok and IsValidItemId(itemId) then
            betweenDeathLifeDeathCertificateId = itemId
            return betweenDeathLifeDeathCertificateId
        end
    end

    return nil
end

local function SpawnBetweenDeathLifeDeathCertificate()
    local deathCertificateId = GetBetweenDeathLifeDeathCertificateId()
    if not IsValidItemId(deathCertificateId) then
        DebugLog("[neverbirth] Death Certificate id not found for Between Death and Life")
        return false
    end

    local room = GetBetweenDeathLifeRoom()
    local position = room and room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
    if room and room.FindFreePickupSpawnPosition then
        position = room:FindFreePickupSpawnPosition(position, 40, true, false)
    end

    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    local game = GetBetweenDeathLifeGame()

    if game and game.Spawn then
        game:Spawn(BETWEEN_DEATH_LIFE_ENTITY_PICKUP, BETWEEN_DEATH_LIFE_COLLECTIBLE_VARIANT, position, velocity, nil, deathCertificateId, seed + 628)
        return true
    elseif Isaac.Spawn then
        Isaac.Spawn(BETWEEN_DEATH_LIFE_ENTITY_PICKUP, BETWEEN_DEATH_LIFE_COLLECTIBLE_VARIANT, deathCertificateId, position, velocity, nil, seed + 628)
        return true
    end

    return false
end

local function IsBetweenDeathLifeEntityRemoved(entity)
    if not entity then
        return true
    end

    if entity.Exists then
        local ok, exists = pcall(function()
            return entity:Exists()
        end)
        if ok and exists == false then
            return true
        end
    end

    if entity.IsDead then
        local ok, dead = pcall(function()
            return entity:IsDead()
        end)
        if ok and dead then
            return true
        end
    end

    return entity.removed == true
end

local function GetBetweenDeathLifeNpcData(npc)
    if npc and npc.GetData then
        local ok, data = pcall(function()
            return npc:GetData()
        end)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

local function IsBetweenDeathLifeBoss(npc)
    if not npc or not npc.IsBoss then
        return false
    end

    local ok, isBoss = pcall(function()
        return npc:IsBoss()
    end)
    return ok and isBoss == true
end

local function IsBetweenDeathLifeChampion(npc)
    if not npc or not npc.IsChampion then
        return false
    end

    local ok, isChampion = pcall(function()
        return npc:IsChampion()
    end)
    return ok and isChampion == true
end

local function IsBetweenDeathLifeEligibleNpc(entity)
    if not entity or IsBetweenDeathLifeEntityRemoved(entity) then
        return false
    end

    local npc = entity
    if entity.ToNPC then
        local ok, converted = pcall(function()
            return entity:ToNPC()
        end)
        if ok and converted then
            npc = converted
        end
    end

    if not npc then
        return false
    end

    if npc.ToPlayer then
        local ok, player = pcall(function()
            return npc:ToPlayer()
        end)
        if ok and player then
            return false
        end
    end

    if npc.HasEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
        local ok, friendly = pcall(function()
            return npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
        end)
        if ok and friendly then
            return false
        end
    end

    if npc.IsVulnerableEnemy then
        local ok, vulnerable = pcall(function()
            return npc:IsVulnerableEnemy()
        end)
        if ok and vulnerable == false then
            return false
        end
    end

    return true
end

local function TryBetweenDeathLifeMakeChampion(npc)
    if not npc or not npc.MakeChampion or IsBetweenDeathLifeChampion(npc) then
        return false
    end

    local room = GetBetweenDeathLifeRoom()
    local seed = npc.InitSeed or (room and room.GetSpawnSeed and room:GetSpawnSeed()) or 0
    local ok = pcall(function()
        npc:MakeChampion(seed, BETWEEN_DEATH_LIFE_CHAMPION_COLOR, true)
    end)

    return ok and IsBetweenDeathLifeChampion(npc)
end

local function EmpowerBetweenDeathLifeNpc(npc)
    local isBoss = IsBetweenDeathLifeBoss(npc)
    local hpMultiplier = isBoss and BETWEEN_DEATH_LIFE_BOSS_HP_MULTIPLIER or BETWEEN_DEATH_LIFE_NORMAL_HP_MULTIPLIER
    local speedMultiplier = isBoss and BETWEEN_DEATH_LIFE_BOSS_SPEED_MULTIPLIER or BETWEEN_DEATH_LIFE_NORMAL_SPEED_MULTIPLIER
    local oldMaxHp = tonumber(npc.MaxHitPoints) or 0
    local oldHp = tonumber(npc.HitPoints) or oldMaxHp

    if oldMaxHp > 0 then
        local newMaxHp = math.max(oldMaxHp + 1, math.floor(oldMaxHp * hpMultiplier + 0.5))
        npc.MaxHitPoints = newMaxHp
        npc.HitPoints = math.max(oldHp + (newMaxHp - oldMaxHp), oldHp)
    end

    if npc.MoveSpeed ~= nil then
        npc.MoveSpeed = npc.MoveSpeed * speedMultiplier
    end

    if npc.SetColor then
        local color = isBoss and Color(1, 0.35, 0.35, 1, 0.2, 0, 0) or Color(0.75, 0.75, 0.75, 1, 0.1, 0.1, 0.1)
        pcall(function()
            npc:SetColor(color, 90, 1, false, false)
        end)
    end
end

local function ShouldBetweenDeathLifeAffectCurrentRoom(data)
    return type(data) == "table"
        and data.active == true
        and data.activatedRoomKey ~= GetBetweenDeathLifeRoomKey()
end

local function ActivateBetweenDeathLifeTrial(player, activeSlot, requireCharge)
    if not player then
        return false
    end

    local slot = FindBetweenDeathLifeSlot(player, activeSlot) or activeSlot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    if requireCharge ~= false and GetBetweenDeathLifeCharge(player, slot) < BETWEEN_DEATH_LIFE_MAX_CHARGE then
        return false
    end

    local data = GetDeathTrialData()
    if data.active ~= true then
        data.active = true
        data.runSeed = GetCurrentRunSeed()
        data.activatedFloorKey = GetBetweenDeathLifeFloorKey()
        data.activatedRoomKey = GetBetweenDeathLifeRoomKey()
        if IsBetweenDeathLifeBossRoomClear() then
            data.preActivationBossClearedFloors[GetBetweenDeathLifeFloorKey()] = true
        end
        SaveMusicboxData()
    end

    RemoveBetweenDeathLifeItem(player, slot)
    return true
end

function Neverbirth:UseBetweenDeathAndLife(_, _, player, _, activeSlot)
    return ActivateBetweenDeathLifeTrial(player, activeSlot, true)
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseBetweenDeathAndLife, Items.BetweenDeathAndLife)

local function FindBetweenDeathLifePickupPlayer(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "table" then
            if value.ToPlayer then
                local ok, player = pcall(function()
                    return value:ToPlayer()
                end)
                if ok and player then
                    return player
                end
            end

            if value.RemoveCollectible or value.GetActiveItem then
                return value
            end
        end
    end

    return nil
end

function Neverbirth:ActivateBetweenDeathAndLifeOnPickup(...)
    local slot = nil
    if select("#", ...) >= 4 then
        slot = select(4, ...)
    end

    local player = FindBetweenDeathLifePickupPlayer(...)
    if not player then
        return
    end

    ActivateBetweenDeathLifeTrial(player, slot, false)
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.ActivateBetweenDeathAndLifeOnPickup, Items.BetweenDeathAndLife)
end

function Neverbirth:InitBetweenDeathLifeNpc(npc)
    local data = GetDeathTrialData()
    if not ShouldBetweenDeathLifeAffectCurrentRoom(data) or not IsBetweenDeathLifeEligibleNpc(npc) then
        return
    end

    local npcData = GetBetweenDeathLifeNpcData(npc)
    if npcData and npcData.neverbirthDeathTrialElite then
        return
    end

    if not TryBetweenDeathLifeMakeChampion(npc) then
        EmpowerBetweenDeathLifeNpc(npc)
    end

    if npcData then
        npcData.neverbirthDeathTrialElite = true
    end
end

if ModCallbacks.MC_POST_NPC_INIT then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, Neverbirth.InitBetweenDeathLifeNpc)
end

function Neverbirth:UpdateBetweenDeathLifeBossReward()
    local floorKey = GetBetweenDeathLifeFloorKey()
    local data = GetDeathTrialData()

    if not IsBetweenDeathLifeBossRoomClear() then
        return
    end

    if data.active ~= true then
        data.preActivationBossClearedFloors[floorKey] = true
        return
    end

    if data.preActivationBossClearedFloors[floorKey] or data.spawnedByFloor[floorKey] then
        return
    end

    if SpawnBetweenDeathLifeDeathCertificate() then
        data.spawnedByFloor[floorKey] = true
        SaveMusicboxData()
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateBetweenDeathLifeBossReward)

function Neverbirth:ResetBetweenDeathLifeState(isContinued)
    if isContinued then
        return
    end

    ResetDeathTrialDataForRun()
    SaveMusicboxData()
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetBetweenDeathLifeState)
end
end

--------------------------------------------------
-- 铜钱剑 / 铜钱面具 / 黑太岁

do
local COIN_SWORD_MAX_SPEND = 6
local COIN_SWORD_NORMAL_DAMAGE_MULT = 2.0
local COIN_SWORD_EMPOWERED_DAMAGE_MULT = 6.0
local COIN_SWORD_BLOOD_DAMAGE_MULT = 4.0
local COIN_SWORD_SPEED = 12
local COIN_SWORD_LIFE = 18
local COIN_SWORD_MODE_CONFIGS = {
    normal = { length = 76, width = 64, back = 48, scatter = 75, scale = 1, spawnOffset = 28 },
    blood = { length = 84, width = 72, back = 52, scatter = 0, scale = 1, spawnOffset = 28 },
    empowered = { length = 144, width = 64, back = 56, scale = 1.45, spawnOffset = 54 },
}
local COIN_SWORD_DISAPPEAR_LIFE = 4
local COIN_SWORD_BACKLASH_FLAGS = (DamageFlag and DamageFlag.DAMAGE_RED_HEARTS) or 0
local COIN_SWORD_DAMAGE_FLAGS = (DamageFlag and DamageFlag.DAMAGE_NO_MODIFIERS) or 0
local COIN_SWORD_ENTITY_EFFECT = (EntityType and EntityType.ENTITY_EFFECT) or 1000
local COIN_SWORD_FALLBACK_EFFECT = (EffectVariant and EffectVariant.POOF01) or 1
local COIN_SWORD_NO_DISCHARGE_RESULT = { Discharge = false, Remove = false, ShowAnim = true }
Neverbirth.CoinSwordEntityProjectile = (EntityType and EntityType.ENTITY_PROJECTILE) or 9
Neverbirth.CoinSwordSpoonBender = (CollectibleType and CollectibleType.COLLECTIBLE_SPOON_BENDER) or 3
Neverbirth.CoinSwordLostContact = (CollectibleType and CollectibleType.COLLECTIBLE_LOST_CONTACT) or 213
Neverbirth.CoinSwordHomingTurnRate = 0.18
local coinSwordQiVariant = nil
local coinSwordHoldStates = {}
Neverbirth.__coinSwordReleaseTearSuppressions = Neverbirth.__coinSwordReleaseTearSuppressions or {}

local MASK_REQUIRED_COINS = 5
local MASK_CONFUSION_DURATION = 90
local MASK_LUCK_PENALTY = -2
local COIN_MASK_COSTUME_PATHS = {
    "gfx/characters/costume_coin_faced_mask.anm2",
}
local COIN_MASK_BROKEN_COSTUME_PATHS = {
    "gfx/characters/costume_coin_faced_mask_broken.anm2",
}
local COIN_MASK_VISUAL_NONE = "none"
local COIN_MASK_VISUAL_ACTIVE = "active"
local COIN_MASK_VISUAL_BROKEN = "broken"
local coinFacedMaskStates = {}
local coinFacedMaskCostumeStates = {}
local coinFacedMaskCostumeIds = {}
local coinFacedMaskSettling = 0

local StrongLaxativeConfig = {
    CreepLifetime = 150,
    CreepInterval = 6,
    CreepRadius = 44,
    CreepDamageInterval = 10,
    SlowDuration = 30,
    PoopRollInterval = 60,
    PoopChancePerCopy = 5,
    RoomPoopCap = 15,
    PoopDistance = 56,
    CostumePath = "gfx/characters/costume_strong_laxative.anm2",
    EntityEffect = (EntityType and EntityType.ENTITY_EFFECT) or 1000,
    GridPoop = (GridEntityType and GridEntityType.GRID_POOP) or 14,
    CreepVariant = (EffectVariant and (EffectVariant.PLAYER_CREEP_GREEN or EffectVariant.CREEP_GREEN or EffectVariant.PLAYER_CREEP_BLACK or EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1,
    CreepVariants = {
        (EffectVariant and (EffectVariant.PLAYER_CREEP_GREEN or EffectVariant.CREEP_GREEN or EffectVariant.PLAYER_CREEP_BLACK or EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1,
        EffectVariant and EffectVariant.PLAYER_CREEP_GREEN,
        EffectVariant and EffectVariant.CREEP_GREEN,
        EffectVariant and EffectVariant.PLAYER_CREEP_BLACK,
        EffectVariant and EffectVariant.CREEP_RED,
    },
}
Neverbirth.StrongLaxativePoopVariants = Neverbirth.StrongLaxativePoopVariants or { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
Neverbirth.StrongLaxative = Neverbirth.StrongLaxative or {}
local strongLaxativeStates = {}
local strongLaxativeCostumeStates = {}
local strongLaxativeCostumeId = nil
local strongLaxativeRoomPoopCounts = {}

local blackTaisuiStates = {}

local FOLK_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local FOLK_PICKUP_HEART = (PickupVariant and PickupVariant.PICKUP_HEART) or 10
local FOLK_HALF_BLACK_HEART = (HeartSubType and (HeartSubType.HEART_HALF_BLACK or HeartSubType.HEART_BLACK)) or 6
local FOLK_BLACK_HEART = (HeartSubType and HeartSubType.HEART_BLACK) or 6
local FOLK_BLACK_CREEP = (EffectVariant and (EffectVariant.PLAYER_CREEP_BLACK or EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1
local FOLK_RED_CREEP = (EffectVariant and (EffectVariant.CREEP_RED or EffectVariant.POOF01)) or 1

local function GetCoinSwordQiVariant()
    if coinSwordQiVariant ~= nil then
        return coinSwordQiVariant
    end

    coinSwordQiVariant = -1
    if Isaac.GetEntityVariantByName then
        local ok, variant = pcall(function()
            return Isaac.GetEntityVariantByName("Coin Sword Qi")
        end)
        if ok and type(variant) == "number" and variant > 0 then
            coinSwordQiVariant = variant
        end
    end

    if coinSwordQiVariant <= 0 then
        DebugLog("[neverbirth] Coin Sword Qi variant not found; falling back to default effect")
    end

    return coinSwordQiVariant
end

local function GetFolkGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    return ok and game or nil
end

local function GetFolkRoom()
    local game = GetFolkGame()
    if game and game.GetRoom then
        local ok, room = pcall(function()
            return game:GetRoom()
        end)
        if ok then
            return room
        end
    end

    return nil
end

local function GetFolkRoomKey()
    local game = GetFolkGame()
    if not game or not game.GetLevel then
        return "0:0:0"
    end

    local ok, level = pcall(function()
        return game:GetLevel()
    end)
    if not ok or not level then
        return "0:0:0"
    end

    local stage = level.GetStage and level:GetStage() or 0
    local stageType = level.GetStageType and level:GetStageType() or 0
    local roomIndex = level.GetCurrentRoomIndex and level:GetCurrentRoomIndex() or 0
    return tostring(stage) .. ":" .. tostring(stageType) .. ":" .. tostring(roomIndex)
end

local function GetFolkFloorKey()
    local game = GetFolkGame()
    if not game or not game.GetLevel then
        return "0:0"
    end

    local ok, level = pcall(function()
        return game:GetLevel()
    end)
    if not ok or not level then
        return "0:0"
    end

    local stage = level.GetStage and level:GetStage() or 0
    local stageType = level.GetStageType and level:GetStageType() or 0
    return tostring(stage) .. ":" .. tostring(stageType)
end

local function GetFolkPlayerKey(player)
    return tostring((player and player.InitSeed) or "0")
end

local function PlayerHasCollectible(player, itemId)
    if not player or not IsValidItemId(itemId) then
        return false
    end

    if player.HasCollectible then
        local ok, result = pcall(function()
            return player:HasCollectible(itemId)
        end)
        if ok then
            return result == true
        end
    end

    if player.GetCollectibleNum then
        local ok, count = pcall(function()
            return player:GetCollectibleNum(itemId)
        end)
        return ok and (tonumber(count) or 0) > 0
    end

    return false
end

local function GetPlayerCoins(player)
    if player and player.GetNumCoins then
        local ok, coins = pcall(function()
            return player:GetNumCoins()
        end)
        if ok then
            return tonumber(coins) or 0
        end
    end

    return tonumber(player and player.coins) or 0
end

local function AddPlayerCoins(player, amount)
    if player and player.AddCoins then
        pcall(function()
            player:AddCoins(amount)
        end)
    end
end

local function GetFolkRandomInt(player, itemId, max)
    max = tonumber(max) or 1
    if max <= 1 then
        return 0
    end

    if player and player.GetCollectibleRNG then
        local ok, rng = pcall(function()
            return player:GetCollectibleRNG(itemId)
        end)
        if ok and rng and rng.RandomInt then
            local rollOk, value = pcall(function()
                return rng:RandomInt(max)
            end)
            if rollOk and value ~= nil then
                return math.max(0, math.min(max - 1, tonumber(value) or 0))
            end
        end
    end

    return math.random(max) - 1
end

local function IsVulnerableEnemy(entity)
    if not entity or entity.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) then
        return false
    end

    if entity.IsVulnerableEnemy then
        local ok, result = pcall(function()
            return entity:IsVulnerableEnemy()
        end)
        if ok then
            return result == true
        end
    end

    return false
end

local function GetNearestEnemyDirection(player)
    local origin = player and player.Position or Vector(0, 0)
    local nearest
    local nearestDistance

    if Isaac.GetRoomEntities then
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) and entity.Position then
                local distance = (entity.Position - origin):Length()
                if not nearestDistance or distance < nearestDistance then
                    nearest = entity
                    nearestDistance = distance
                end
            end
        end
    end

    if nearest and nearest.Position then
        return (nearest.Position - origin):Normalized()
    end

    return nil
end

function Neverbirth.GetNearestEnemyDirectionFromPosition(origin)
    origin = origin or Vector(0, 0)
    local nearest
    local nearestDistance

    if Isaac.GetRoomEntities then
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) and entity.Position then
                local distance = (entity.Position - origin):Length()
                if not nearestDistance or distance < nearestDistance then
                    nearest = entity
                    nearestDistance = distance
                end
            end
        end
    end

    if nearest and nearest.Position then
        return (nearest.Position - origin):Normalized()
    end

    return nil
end

local function VectorFromInput(value)
    if type(value) == "table" and value.X and value.Y then
        local vector = Vector(tonumber(value.X) or 0, tonumber(value.Y) or 0)
        if vector:Length() > 0 then
            return vector:Normalized()
        end
    end

    return nil
end

local function DirectionToVector(value)
    local vector = VectorFromInput(value)
    if vector then
        return vector
    end

    if type(value) ~= "number" then
        return nil
    end

    if Direction then
        if value == Direction.LEFT then
            return Vector(-1, 0)
        elseif value == Direction.UP then
            return Vector(0, -1)
        elseif value == Direction.RIGHT then
            return Vector(1, 0)
        elseif value == Direction.DOWN then
            return Vector(0, 1)
        end
    end

    if value == 0 then
        return Vector(-1, 0)
    elseif value == 1 then
        return Vector(0, -1)
    elseif value == 2 then
        return Vector(1, 0)
    elseif value == 3 then
        return Vector(0, 1)
    end

    return nil
end

local function GetCoinSwordBaseDirection(player)
    if player and player.GetShootingInput then
        local ok, input = pcall(function()
            return player:GetShootingInput()
        end)
        local vector = ok and VectorFromInput(input) or nil
        if vector then
            return vector
        end
    end

    if player and player.GetFireDirection then
        local ok, input = pcall(function()
            return player:GetFireDirection()
        end)
        local vector = ok and DirectionToVector(input) or nil
        if vector then
            return vector
        end
    end

    if player and player.GetMovementInput then
        local ok, input = pcall(function()
            return player:GetMovementInput()
        end)
        local vector = ok and VectorFromInput(input) or nil
        if vector then
            return vector
        end
    end

    if player and player.GetMovementDirection then
        local ok, input = pcall(function()
            return player:GetMovementDirection()
        end)
        local vector = ok and DirectionToVector(input) or nil
        if vector then
            return vector
        end
    end

    local targetDirection = GetNearestEnemyDirection(player)
    if targetDirection and targetDirection:Length() > 0 then
        return targetDirection:Normalized()
    end

    return Vector(1, 0)
end

local function GetCoinSwordReleaseDirection(player)
    if player and player.GetShootingInput then
        local ok, input = pcall(function()
            return player:GetShootingInput()
        end)
        local vector = ok and VectorFromInput(input) or nil
        if vector then
            return vector
        end
    end

    if player and player.GetFireDirection then
        local ok, input = pcall(function()
            return player:GetFireDirection()
        end)
        local vector = ok and DirectionToVector(input) or nil
        if vector then
            return vector
        end
    end

    return nil
end

local function RotateVector(vector, degrees)
    local radians = (degrees or 0) * math.pi / 180
    local cosValue = math.cos(radians)
    local sinValue = math.sin(radians)
    return Vector(vector.X * cosValue - vector.Y * sinValue, vector.X * sinValue + vector.Y * cosValue)
end

local function AngleFromVector(vector)
    return math.atan(vector.Y, vector.X) * 180 / math.pi
end

local function GetCoinSwordAnimationName(mode)
    if mode == "blood" then
        return "BloodSlash"
    elseif mode == "empowered" then
        return "EmpoweredSlash"
    end

    return "Slash"
end

local function GetCoinSwordHitboxConfig(mode)
    local config = COIN_SWORD_MODE_CONFIGS[mode or "normal"] or COIN_SWORD_MODE_CONFIGS.normal
    return config.length, config.width, config.back
end

function Neverbirth.SafeSetCoinSwordField(target, field, value)
    if not target then
        return false
    end

    local ok = pcall(function()
        target[field] = value
    end)
    return ok == true
end

local function PlayCoinSwordAnimation(effect, mode, direction)
    if not effect or not effect.GetSprite then
        return
    end

    local sprite = effect:GetSprite()
    if not sprite then
        return
    end

    local animation = GetCoinSwordAnimationName(mode)

    if sprite.Play then
        pcall(function()
            sprite:Play(animation, true)
        end)
    end
    local angle = AngleFromVector(direction or Vector(1, 0))
    local config = COIN_SWORD_MODE_CONFIGS[mode or "normal"] or COIN_SWORD_MODE_CONFIGS.normal
    local scaleValue = config.scale or 1
    local scale = Vector(scaleValue, scaleValue)
    Neverbirth.SafeSetCoinSwordField(sprite, "Rotation", angle)
    Neverbirth.SafeSetCoinSwordField(effect, "SpriteRotation", angle)
    Neverbirth.SafeSetCoinSwordField(sprite, "Scale", scale)
    Neverbirth.SafeSetCoinSwordField(effect, "SpriteScale", scale)
end

function Neverbirth.UpdateCoinSwordVisualDirection(effect, direction)
    if not effect or not direction then
        return
    end

    local angle = AngleFromVector(direction)
    if effect.GetSprite then
        local sprite = effect:GetSprite()
        Neverbirth.SafeSetCoinSwordField(sprite, "Rotation", angle)
    end
    Neverbirth.SafeSetCoinSwordField(effect, "SpriteRotation", angle)
end

local function SpawnCoinSwordQi(player, damageMultiplier, mode, direction, forwardOffset)
    direction = (direction and direction:Length() > 0) and direction:Normalized() or GetCoinSwordBaseDirection(player)
    local velocity = direction * COIN_SWORD_SPEED
    local config = COIN_SWORD_MODE_CONFIGS[mode or "normal"] or COIN_SWORD_MODE_CONFIGS.normal
    local spawnOffset = config.spawnOffset or 28
    spawnOffset = spawnOffset + (tonumber(forwardOffset) or 0)
    local position = (player and player.Position or Vector(320, 280)) + direction * spawnOffset
    local variant = GetCoinSwordQiVariant()
    local spawnVariant = variant > 0 and variant or COIN_SWORD_FALLBACK_EFFECT
    local effect = Isaac.Spawn and Isaac.Spawn(COIN_SWORD_ENTITY_EFFECT, spawnVariant, 0, position, velocity, player) or nil

    if not effect then
        return nil
    end

    local data = effect.GetData and effect:GetData() or {}
    data.NeverbirthCoinSwordQi = true
    data.Owner = player
    data.OwnerSeed = player and player.InitSeed
    data.Direction = direction
    data.Velocity = velocity
    data.Damage = (tonumber(player and player.Damage) or 3.5) * damageMultiplier
    data.Mode = mode or "normal"
    data.Life = COIN_SWORD_LIFE + (mode == "empowered" and 8 or 0)
    data.HitEnemies = {}
    data.BlockedProjectiles = {}
    data.Piercing = mode == "empowered"
    data.Homing = PlayerHasCollectible(player, Neverbirth.CoinSwordSpoonBender)
    data.Shielded = PlayerHasCollectible(player, Neverbirth.CoinSwordLostContact)
    data.Length, data.Width, data.BackLength = GetCoinSwordHitboxConfig(data.Mode)

    PlayCoinSwordAnimation(effect, data.Mode, direction)
    Neverbirth.SafeSetCoinSwordField(effect, "DepthOffset", data.Piercing and 160 or 80)
    Neverbirth.SafeSetCoinSwordField(effect, "RenderZOffset", data.Piercing and 14000 or 10000)
    DebugLog("[neverbirth] Coin Sword Qi spawn variant=" .. tostring(variant) ..
        " spawnVariant=" .. tostring(spawnVariant) ..
        " mode=" .. tostring(data.Mode) ..
        " animation=" .. tostring(GetCoinSwordAnimationName(data.Mode)))

    return effect
end

local function EnemyHitKey(entity)
    return tostring((entity and entity.InitSeed) or entity)
end

function Neverbirth.IsCoinSwordEnemyProjectile(entity, data)
    if not entity or entity.Type ~= Neverbirth.CoinSwordEntityProjectile or not entity.Position then
        return false
    end

    if data and data.Owner and entity.SpawnerEntity and entity.SpawnerEntity.InitSeed == data.Owner.InitSeed then
        return false
    end

    if entity.HasEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
        local ok, friendly = pcall(function()
            return entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
        end)
        if ok and friendly then
            return false
        end
    end

    return true
end

function Neverbirth.RemoveCoinSwordBlockedProjectile(projectile)
    if not projectile then
        return
    end

    if projectile.Die then
        local ok = pcall(function()
            projectile:Die()
        end)
        if ok then
            return
        end
    end

    if projectile.Remove then
        pcall(function()
            projectile:Remove()
        end)
    end
end

local function IsEnemyInsideCoinSwordHitbox(effect, enemy, data)
    if not effect or not enemy or not enemy.Position or not data or not data.Direction then
        return false
    end

    local relative = enemy.Position - effect.Position
    local direction = data.Direction
    local forward = relative.X * direction.X + relative.Y * direction.Y
    local backLength = tonumber(data.BackLength) or 36
    local length = tonumber(data.Length) or COIN_SWORD_MODE_CONFIGS.normal.length
    local width = tonumber(data.Width) or COIN_SWORD_MODE_CONFIGS.normal.width
    local radius = width / 2
    if forward < -backLength - radius or forward > length + radius then
        return false
    end

    local perpendicular = math.abs(relative.X * -direction.Y + relative.Y * direction.X)
    if forward >= -backLength and forward <= length then
        return perpendicular <= radius
    end

    local capCenter = forward < -backLength and -backLength or length
    local capForward = forward - capCenter
    return (capForward * capForward + perpendicular * perpendicular) <= (radius * radius)
end

local function RemoveCoinSwordEffect(effect)
    if effect and effect.Remove then
        effect:Remove()
    end
end

local function StartCoinSwordDisappear(effect, data)
    if not effect then
        return
    end

    data = data or (effect.GetData and effect:GetData()) or {}
    if data.Disappearing then
        return
    end

    data.Disappearing = true
    data.Life = COIN_SWORD_DISAPPEAR_LIFE
    data.Velocity = Vector(0, 0)
    effect.Velocity = Vector(0, 0)

    if effect.GetSprite then
        local sprite = effect:GetSprite()
        if sprite and sprite.Play then
            pcall(function()
                sprite:Play("Disappear", true)
            end)
        end
    end
end

function Neverbirth:UpdateCoinSwordQi(effect)
    if not effect then
        return
    end

    local data = effect.GetData and effect:GetData() or nil
    if type(data) ~= "table" or not data.NeverbirthCoinSwordQi then
        return
    end

    if data.Disappearing then
        data.Life = (tonumber(data.Life) or 0) - 1
        if data.Life <= 0 then
            RemoveCoinSwordEffect(effect)
        end
        return
    end

    data.Life = (tonumber(data.Life) or 0) - 1
    if data.Life <= 0 then
        RemoveCoinSwordEffect(effect)
        return
    end

    if data.Homing then
        local targetDirection = Neverbirth.GetNearestEnemyDirectionFromPosition(effect.Position)
        if targetDirection and targetDirection:Length() > 0 then
            local currentDirection = data.Direction
            if not currentDirection or currentDirection:Length() <= 0 then
                currentDirection = Vector(1, 0)
            else
                currentDirection = currentDirection:Normalized()
            end

            local blended = (currentDirection * (1 - Neverbirth.CoinSwordHomingTurnRate)) + (targetDirection * Neverbirth.CoinSwordHomingTurnRate)
            if blended:Length() > 0 then
                data.Direction = blended:Normalized()
                data.Velocity = data.Direction * COIN_SWORD_SPEED
                effect.Velocity = data.Velocity
                Neverbirth.UpdateCoinSwordVisualDirection(effect, data.Direction)
            end
        end
    end

    if data.Velocity then
        effect.Position = effect.Position + data.Velocity
    end

    local room = GetFolkRoom()
    if room and room.IsPositionInRoom then
        local ok, inRoom = pcall(function()
            return room:IsPositionInRoom(effect.Position, 16)
        end)
        if ok and not inRoom then
            RemoveCoinSwordEffect(effect)
            return
        end
    end

    if not Isaac.GetRoomEntities then
        return
    end

    local owner = data.Owner
    local source = EntityRef(owner or effect)
    if data.Shielded then
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if entity ~= effect and Neverbirth.IsCoinSwordEnemyProjectile(entity, data) and IsEnemyInsideCoinSwordHitbox(effect, entity, data) then
                local key = EnemyHitKey(entity)
                data.BlockedProjectiles = data.BlockedProjectiles or {}
                if not data.BlockedProjectiles[key] then
                    data.BlockedProjectiles[key] = true
                    Neverbirth.RemoveCoinSwordBlockedProjectile(entity)
                    if not data.Piercing then
                        StartCoinSwordDisappear(effect, data)
                        return
                    end
                end
            end
        end
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity ~= effect and IsVulnerableEnemy(entity) and IsEnemyInsideCoinSwordHitbox(effect, entity, data) then
            local key = EnemyHitKey(entity)
            data.HitEnemies = data.HitEnemies or {}
            if not data.HitEnemies[key] then
                data.HitEnemies[key] = true
                if entity.TakeDamage then
                    entity:TakeDamage(tonumber(data.Damage) or 0, COIN_SWORD_DAMAGE_FLAGS, source, 0)
                end
                if not data.Piercing then
                    StartCoinSwordDisappear(effect, data)
                    return
                end
            end
        end
    end
end

if ModCallbacks.MC_POST_EFFECT_UPDATE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.UpdateCoinSwordQi)
end

local function RenderCoinSwordQiDebugText(text, position, red, green, blue, alpha)
    if not position or not Isaac.WorldToScreen or not Isaac.RenderText then
        return
    end

    local ok, screen = pcall(function()
        return Isaac.WorldToScreen(position)
    end)
    if not ok or not screen then
        return
    end

    pcall(function()
        Isaac.RenderText(text, screen.X, screen.Y, red, green, blue, alpha)
    end)
end

function Neverbirth:RenderCoinSwordQiDebug()
    if not self.DebugCoinSwordHitbox then
        return
    end
    if not Isaac.GetRoomEntities then
        return
    end

    for _, effect in ipairs(Isaac.GetRoomEntities()) do
        local data = effect and effect.GetData and effect:GetData() or nil
        if type(data) == "table" and data.NeverbirthCoinSwordQi and effect.Position and data.Direction then
            local direction = data.Direction
            if not direction.Length or direction:Length() <= 0 then
                direction = Vector(1, 0)
            else
                direction = direction:Normalized()
            end

            local length = tonumber(data.Length) or COIN_SWORD_MODE_CONFIGS.normal.length
            local width = tonumber(data.Width) or COIN_SWORD_MODE_CONFIGS.normal.width
            local backLength = tonumber(data.BackLength) or COIN_SWORD_MODE_CONFIGS.normal.back
            local radius = width / 2
            local side = Vector(-direction.Y, direction.X)
            local red, green, blue = 0.2, 1, 0.2
            if data.Mode == "blood" then
                red, green, blue = 1, 0.15, 0.15
            elseif data.Mode == "empowered" then
                red, green, blue = 1, 0.85, 0.15
            end

            RenderCoinSwordQiDebugText("CSQ " .. tostring(data.Mode or "normal"), effect.Position, red, green, blue, 1)
            for index = 0, 4 do
                local forward = -backLength + ((length + backLength) * index / 4)
                local center = effect.Position + direction * forward
                RenderCoinSwordQiDebugText(".", center, red, green, blue, 0.9)
                RenderCoinSwordQiDebugText(".", center + side * radius, red, green, blue, 0.9)
                RenderCoinSwordQiDebugText(".", center - side * radius, red, green, blue, 0.9)
            end
            RenderCoinSwordQiDebugText("o", effect.Position + direction * length, red, green, blue, 0.9)
            RenderCoinSwordQiDebugText("o", effect.Position - direction * backLength, red, green, blue, 0.9)
        end
    end
end

if ModCallbacks.MC_POST_RENDER then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderCoinSwordQiDebug)
end

local function SpawnFolkEffect(variant, position, spawner)
    if Isaac.Spawn then
        return Isaac.Spawn((EntityType and EntityType.ENTITY_EFFECT) or 1000, variant, 0, position or Vector(320, 280), Vector(0, 0), spawner)
    end

    return nil
end

Neverbirth.FolkVisualEffects = Neverbirth.FolkVisualEffects or {
    GoodGirlHalo = { name = "Good Girl Halo", fallback = 3002, animation = "Idle", timeout = 45, followOwner = true, followOffset = Vector(0, 0), spriteOffset = Vector(0, -24), depthOffset = 300000 },
    GoodGirlCharm = { name = "Good Girl Charm", fallback = 3003, animation = "Charm", timeout = 45 },
    GoodGirlReward = { name = "Good Girl Reward", fallback = 3004, animation = "Reward", timeout = 60 },
    GoodGirlBreak = { name = "Good Girl Break", fallback = 3005, animation = "Break", timeout = 75 },
    GoodGirlEcho = { name = "Good Girl Echo", fallback = 3006, animation = "Echo", timeout = 45, followOwner = true },
    BlackTaisuiSpore = { name = "Black Taisui Spore", fallback = 3007, animation = "Spore", timeout = 45 },
    BlackTaisuiPulse = { name = "Black Taisui Pulse", fallback = 3008, animation = "Pulse", timeout = 45 },
    BlackTaisuiCurseDevour = { name = "Black Taisui Curse Devour", fallback = 3009, animation = "Devour", timeout = 60 },
    BlackTaisuiReveal = { name = "Black Taisui Reveal", fallback = 3010, animation = "Reveal", timeout = 60 },
    BlackTaisuiFearPulse = { name = "Black Taisui Fear Pulse", fallback = 3011, animation = "FearPulse", timeout = 60 },
    BlackTaisuiDeathDeny = { name = "Black Taisui Death Deny", fallback = 3012, animation = "DeathDeny", timeout = 90 },
    BlackTaisuiMatureCore = { name = "Black Taisui Mature Core", fallback = 3013, animation = "MatureCore", timeout = 45 },
    BlackTaisuiHallucinationEat = { name = "Black Taisui Hallucination Eat", fallback = 3014, animation = "HallucinationEat", timeout = 75 },
}

function Neverbirth:GetFolkVisualEffectVariant(key)
    local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
    if not spec then
        return -1
    end
    if spec.variant ~= nil then
        return spec.variant
    end

    spec.variant = spec.fallback or -1
    if Isaac and Isaac.GetEntityVariantByName and spec.name then
        local ok, variant = pcall(function()
            return Isaac.GetEntityVariantByName(spec.name)
        end)
        if ok and type(variant) == "number" and variant > 0 then
            spec.variant = variant
        end
    end

    return spec.variant
end

function Neverbirth:GetFolkVisualEffectOwnerSeed(owner)
    return owner and owner.InitSeed or nil
end

function Neverbirth:GetFolkVisualEffectFollowOffset(spec)
    if spec and spec.followOffset then
        return spec.followOffset
    end
    return Vector(0, 0)
end

function Neverbirth:GetFolkVisualEffectPositionOffset(spec, owner)
    local offset = (spec and spec.positionOffset) or Vector(0, 0)
    if owner and owner.PositionOffset then
        offset = owner.PositionOffset + offset
    end
    if owner and owner.GetFlyingOffset then
        local ok, flyingOffset = pcall(function()
            return owner:GetFlyingOffset()
        end)
        if ok and flyingOffset then
            offset = offset + flyingOffset
        end
    end
    return offset
end

function Neverbirth:ApplyFolkVisualEffectFollowPosition(effect, owner, spec)
    if not effect or not owner or not owner.Position then
        return false
    end

    local followOffset = Neverbirth:GetFolkVisualEffectFollowOffset(spec)
    pcall(function()
        effect.Position = owner.Position + followOffset
    end)
    if spec and spec.positionOffset then
        pcall(function()
            effect.PositionOffset = Neverbirth:GetFolkVisualEffectPositionOffset(spec, owner)
        end)
    end
    if spec and spec.spriteOffset then
        pcall(function()
            effect.SpriteOffset = spec.spriteOffset
        end)
    end
    if spec and spec.depthOffset then
        pcall(function()
            effect.DepthOffset = spec.depthOffset
        end)
    end
    if effect.FollowParent then
        pcall(function()
            effect.Parent = owner
            effect:FollowParent(owner)
        end)
    else
        pcall(function()
            effect.Parent = owner
        end)
    end
    return true
end

function Neverbirth:BindFolkVisualEffectOwner(effect, key, owner)
    if not effect or not owner then
        return false
    end

    local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
    if not spec or not spec.followOwner then
        return false
    end

    local data = effect.GetData and effect:GetData() or nil
    if type(data) ~= "table" then
        return false
    end

    local offset = Neverbirth:GetFolkVisualEffectFollowOffset(spec)
    data.NeverbirthFolkVisualEffectOwner = owner
    data.NeverbirthFolkVisualEffectOwnerSeed = Neverbirth:GetFolkVisualEffectOwnerSeed(owner)
    data.NeverbirthFolkVisualEffectFollowOffset = offset
    Neverbirth:ApplyFolkVisualEffectFollowPosition(effect, owner, spec)
    return true
end

function Neverbirth:GetFolkVisualEffectOwner(data)
    if type(data) ~= "table" then
        return nil
    end

    local owner = data.NeverbirthFolkVisualEffectOwner
    if owner and owner.Position then
        return owner
    end

    local ownerSeed = data.NeverbirthFolkVisualEffectOwnerSeed
    if ownerSeed == nil then
        return nil
    end

    for _, player in ipairs(GetPlayers()) do
        if tostring(Neverbirth:GetFolkVisualEffectOwnerSeed(player)) == tostring(ownerSeed) then
            data.NeverbirthFolkVisualEffectOwner = player
            return player
        end
    end

    return nil
end

function Neverbirth:RefreshFolkVisualEffectTimeout(effect, key, timeout)
    local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
    local data = effect and effect.GetData and effect:GetData() or nil
    if type(data) ~= "table" then
        return
    end
    data.NeverbirthFolkVisualEffectTimeout = math.max(1, math.floor(tonumber(timeout or (spec and spec.timeout)) or 45))
end

function Neverbirth:IsFolkVisualEffectActive(effect)
    if not effect then
        return false
    end
    if effect.Exists then
        local ok, exists = pcall(function()
            return effect:Exists()
        end)
        if ok then
            return exists == true
        end
    end
    return effect.removed ~= true and effect.Removed ~= true
end

function Neverbirth:SpawnFolkVisualEffect(key, position, spawner, timeout)
    if not Isaac or not Isaac.Spawn then
        return nil
    end

    local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
    local variant = Neverbirth:GetFolkVisualEffectVariant(key)
    if not spec or not variant or variant <= 0 then
        return nil
    end

    local effect = SpawnFolkEffect(variant, position, spawner)
    local data = effect and effect.GetData and effect:GetData() or nil
    if type(data) == "table" then
        data.NeverbirthFolkVisualEffect = true
        data.NeverbirthFolkVisualEffectKey = key
        data.NeverbirthFolkVisualEffectTimeout = math.max(1, math.floor(tonumber(timeout or spec.timeout) or 45))
    end
    if spec.followOwner and spawner then
        Neverbirth:BindFolkVisualEffectOwner(effect, key, spawner)
    end

    local sprite = effect and effect.GetSprite and effect:GetSprite() or nil
    if sprite and sprite.Play and spec.animation then
        pcall(function()
            sprite:Play(spec.animation, true)
        end)
    end

    return effect
end

function Neverbirth:UpdateFolkVisualEffect(effect)
    local data = effect and effect.GetData and effect:GetData() or nil
    if type(data) ~= "table" or data.NeverbirthFolkVisualEffect ~= true then
        return
    end

    if data.NeverbirthFolkVisualEffectOwnerSeed ~= nil then
        local owner = Neverbirth:GetFolkVisualEffectOwner(data)
        local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[data.NeverbirthFolkVisualEffectKey]
        if not Neverbirth:ApplyFolkVisualEffectFollowPosition(effect, owner, spec) then
            if effect.Remove then
                effect:Remove()
            end
            return
        end
    end

    local sprite = effect.GetSprite and effect:GetSprite() or nil
    if sprite and sprite.IsFinished then
        local ok, finished = pcall(function()
            return sprite:IsFinished()
        end)
        if ok and finished then
            if effect.Remove then
                effect:Remove()
            end
            return
        end
    end

    data.NeverbirthFolkVisualEffectTimeout = (tonumber(data.NeverbirthFolkVisualEffectTimeout) or 1) - 1
    if data.NeverbirthFolkVisualEffectTimeout <= 0 and effect.Remove then
        effect:Remove()
    end
end

if ModCallbacks.MC_POST_EFFECT_UPDATE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.UpdateFolkVisualEffect)
end

function Neverbirth.StrongLaxative.PlayerHas(player)
    return PlayerHasCollectible(player, Items.StrongLaxative)
end

function Neverbirth.StrongLaxative.GetCopyCount(player)
    if not player or not IsValidItemId(Items.StrongLaxative) then
        return 0
    end

    if player.GetCollectibleNum then
        local ok, count = pcall(function()
            return player:GetCollectibleNum(Items.StrongLaxative)
        end)
        if ok then
            return math.max(0, tonumber(count) or 0)
        end
    end

    return Neverbirth.StrongLaxative.PlayerHas(player) and 1 or 0
end

function Neverbirth.StrongLaxative.GetCostumeId()
    if strongLaxativeCostumeId ~= nil then
        return strongLaxativeCostumeId or nil
    end

    strongLaxativeCostumeId = false
    if Isaac and Isaac.GetCostumeIdByPath then
        local ok, costumeId = pcall(function()
            return Isaac.GetCostumeIdByPath(StrongLaxativeConfig.CostumePath)
        end)
        if ok and type(costumeId) == "number" and costumeId > 0 then
            strongLaxativeCostumeId = costumeId
        end
    end

    return strongLaxativeCostumeId or nil
end

function Neverbirth.StrongLaxative.RemoveCostume(player, costumeId)
    if player and costumeId and player.TryRemoveNullCostume then
        pcall(function()
            player:TryRemoveNullCostume(costumeId)
        end)
    end
end

function Neverbirth.StrongLaxative.AddCostume(player, costumeId)
    if player and costumeId and player.AddNullCostume then
        pcall(function()
            player:AddNullCostume(costumeId)
        end)
    end
end

function Neverbirth.StrongLaxative.ApplyCostume(player, active)
    if not player then
        return
    end

    local key = GetFolkPlayerKey(player)
    local visualState = active and "active" or "none"
    if strongLaxativeCostumeStates[key] == visualState then
        return
    end

    local costumeId = Neverbirth.StrongLaxative.GetCostumeId()
    if costumeId then
        Neverbirth.StrongLaxative.RemoveCostume(player, costumeId)
        if active then
            Neverbirth.StrongLaxative.AddCostume(player, costumeId)
        end
    end
    strongLaxativeCostumeStates[key] = visualState
end

function Neverbirth.StrongLaxative.GetState(player)
    local key = GetFolkPlayerKey(player)
    local state = strongLaxativeStates[key]
    if type(state) ~= "table" then
        state = {
            creepCooldown = 0,
            poopTimer = 0,
        }
        strongLaxativeStates[key] = state
    end
    return state
end

function Neverbirth.StrongLaxative.IsMoving(player)
    if not player then
        return false
    end

    local velocity = player.Velocity
    if velocity and velocity.Length then
        local ok, length = pcall(function()
            return velocity:Length()
        end)
        if ok and (tonumber(length) or 0) > 0.35 then
            return true
        end
    end

    if player.GetMovementInput then
        local ok, input = pcall(function()
            return player:GetMovementInput()
        end)
        if ok and input and input.Length then
            local okLength, length = pcall(function()
                return input:Length()
            end)
            if okLength and (tonumber(length) or 0) > 0.1 then
                return true
            end
        end
    end

    return false
end

function Neverbirth.StrongLaxative.GetRng(player)
    if player and player.GetCollectibleRNG and IsValidItemId(Items.StrongLaxative) then
        local ok, rng = pcall(function()
            return player:GetCollectibleRNG(Items.StrongLaxative)
        end)
        if ok and rng and rng.RandomInt then
            return rng
        end
    end
    return nil
end

function Neverbirth.StrongLaxative.RandomInt(player, max)
    if max <= 0 then
        return 0
    end

    local rng = Neverbirth.StrongLaxative.GetRng(player)
    if rng and rng.RandomInt then
        local ok, value = pcall(function()
            return rng:RandomInt(max)
        end)
        if ok and type(value) == "number" then
            return math.max(0, math.min(max - 1, math.floor(value)))
        end
    end

    local room = GetFolkRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    return math.max(0, math.floor(seed) % max)
end

function Neverbirth.StrongLaxative.SpawnCreep(player)
    if not player or not player.Position or not Isaac or not Isaac.Spawn then
        return nil
    end

    local creep = Isaac.Spawn(StrongLaxativeConfig.EntityEffect, StrongLaxativeConfig.CreepVariant, 0, player.Position, Vector(0, 0), player)
    if not creep then
        return nil
    end

    local data = creep.GetData and creep:GetData() or nil
    if type(data) == "table" then
        data.NeverbirthStrongLaxativeCreep = true
        data.Owner = player
        data.OwnerSeed = player.InitSeed
        data.Life = StrongLaxativeConfig.CreepLifetime
        data.Age = 0
        data.Radius = StrongLaxativeConfig.CreepRadius
        data.Damage = (tonumber(player.Damage) or 3.5) * 0.1
    end

    if creep.SetColor and Color then
        pcall(function()
            creep:SetColor(Color(0.45, 0.6, 0.22, 0.9, 0.1, 0.04, 0), StrongLaxativeConfig.CreepLifetime, 1, true, false)
        end)
    end

    return creep
end

function Neverbirth.StrongLaxative.IsCreepVariant(variant)
    for _, creepVariant in ipairs(StrongLaxativeConfig.CreepVariants) do
        if type(creepVariant) == "number" and variant == creepVariant then
            return true
        end
    end
    return false
end

function Neverbirth.StrongLaxative.GetPoopRoomCount(roomKey)
    return math.max(0, tonumber(strongLaxativeRoomPoopCounts[roomKey]) or 0)
end

function Neverbirth.StrongLaxative.GetPoopSpawnPosition(player)
    if not player or not player.Position then
        return nil
    end

    local room = GetFolkRoom()
    local angleIndex = Neverbirth.StrongLaxative.RandomInt(player, 8)
    local angle = (angleIndex / 8) * math.pi * 2
    local offset = Vector(math.cos(angle), math.sin(angle)) * StrongLaxativeConfig.PoopDistance
    local position = player.Position + offset

    if room and room.FindFreePickupSpawnPosition then
        local ok, freePosition = pcall(function()
            return room:FindFreePickupSpawnPosition(position, 24, true, false)
        end)
        if ok and freePosition then
            position = freePosition
        end
    end

    if room and room.IsPositionInRoom then
        local ok, inRoom = pcall(function()
            return room:IsPositionInRoom(position, 16)
        end)
        if ok and not inRoom then
            return nil
        end
    end

    return position
end

function Neverbirth.StrongLaxative.SpawnPoop(player)
    local room = GetFolkRoom()
    if not room then
        return false
    end

    local position = Neverbirth.StrongLaxative.GetPoopSpawnPosition(player)
    if not position then
        return false
    end

    local variants = Neverbirth.StrongLaxativePoopVariants or {}
    if #variants <= 0 then
        return false
    end

    local variant = variants[Neverbirth.StrongLaxative.RandomInt(player, #variants) + 1] or 0
    local seed = room.GetSpawnSeed and room:GetSpawnSeed() or 0

    if room.SpawnGridEntity and room.GetGridIndex then
        local ok, result = pcall(function()
            return room:SpawnGridEntity(room:GetGridIndex(position), StrongLaxativeConfig.GridPoop, variant, seed, 0)
        end)
        return ok and result ~= false
    end

    return false
end

function Neverbirth.StrongLaxative.TryPoopRoll(player, copies)
    local roomKey = GetFolkRoomKey()
    if Neverbirth.StrongLaxative.GetPoopRoomCount(roomKey) >= StrongLaxativeConfig.RoomPoopCap then
        return
    end

    local chance = math.min(100, math.max(0, (tonumber(copies) or 0) * StrongLaxativeConfig.PoopChancePerCopy))
    if chance <= 0 then
        return
    end

    if Neverbirth.StrongLaxative.RandomInt(player, 100) < chance and Neverbirth.StrongLaxative.SpawnPoop(player) then
        strongLaxativeRoomPoopCounts[roomKey] = Neverbirth.StrongLaxative.GetPoopRoomCount(roomKey) + 1
    end
end

function Neverbirth:UpdateStrongLaxativePlayers()
    for _, player in ipairs(GetPlayers()) do
        local copies = Neverbirth.StrongLaxative.GetCopyCount(player)
        if copies <= 0 then
            strongLaxativeStates[GetFolkPlayerKey(player)] = nil
            Neverbirth.StrongLaxative.ApplyCostume(player, false)
        else
            local state = Neverbirth.StrongLaxative.GetState(player)
            Neverbirth.StrongLaxative.ApplyCostume(player, true)

            state.creepCooldown = math.max(0, (tonumber(state.creepCooldown) or 0) - 1)
            if state.creepCooldown <= 0 and Neverbirth.StrongLaxative.IsMoving(player) then
                if Neverbirth.StrongLaxative.SpawnCreep(player) then
                    state.creepCooldown = StrongLaxativeConfig.CreepInterval
                end
            end

            state.poopTimer = (tonumber(state.poopTimer) or 0) + 1
            if state.poopTimer >= StrongLaxativeConfig.PoopRollInterval then
                state.poopTimer = 0
                Neverbirth.StrongLaxative.TryPoopRoll(player, copies)
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateStrongLaxativePlayers)

function Neverbirth:UpdateStrongLaxativeCreep(effect)
    if not effect then
        return
    end

    local data = effect.GetData and effect:GetData() or nil
    if type(data) ~= "table" or data.NeverbirthStrongLaxativeCreep ~= true then
        return
    end

    data.Age = (tonumber(data.Age) or 0) + 1
    data.Life = (tonumber(data.Life) or 0) - 1
    if data.Life <= 0 then
        if effect.Remove then
            effect:Remove()
        end
        return
    end

    if not Isaac.GetRoomEntities then
        return
    end

    local radius = tonumber(data.Radius) or StrongLaxativeConfig.CreepRadius
    local radiusSquared = radius * radius
    local source = EntityRef(data.Owner or effect)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity ~= effect and IsVulnerableEnemy(entity) and entity.Position and effect.Position then
            local dx = (entity.Position.X or 0) - (effect.Position.X or 0)
            local dy = (entity.Position.Y or 0) - (effect.Position.Y or 0)
            if dx * dx + dy * dy <= radiusSquared then
                if entity.AddSlowing then
                    pcall(function()
                        entity:AddSlowing(source, StrongLaxativeConfig.SlowDuration, 0.5, Color and Color(0.45, 0.65, 0.2, 1, 0, 0, 0) or nil)
                    end)
                end
                if ((tonumber(data.Age) or 0) % StrongLaxativeConfig.CreepDamageInterval) == 0 and entity.TakeDamage then
                    pcall(function()
                        entity:TakeDamage(tonumber(data.Damage) or 0, 0, source, 0)
                    end)
                end
            end
        end
    end
end

if ModCallbacks.MC_POST_EFFECT_UPDATE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.UpdateStrongLaxativeCreep, StrongLaxativeConfig.CreepVariant)
end

function Neverbirth.StrongLaxative.GetDamageSource(source)
    if source and source.Entity then
        return source.Entity
    end
    return source
end

function Neverbirth:BlockStrongLaxativeCreepDamage(entity, amount, flags, source)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player or Neverbirth.StrongLaxative.GetCopyCount(player) <= 0 then
        return nil
    end

    local sourceEntity = Neverbirth.StrongLaxative.GetDamageSource(source)
    local sourceData = sourceEntity and sourceEntity.GetData and sourceEntity:GetData() or nil
    if type(sourceData) == "table" and sourceData.NeverbirthStrongLaxativeCreep == true then
        return false
    end

    if sourceEntity and sourceEntity.Type == StrongLaxativeConfig.EntityEffect and Neverbirth.StrongLaxative.IsCreepVariant(sourceEntity.Variant) then
        return false
    end

    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.BlockStrongLaxativeCreepDamage, EntityType and EntityType.ENTITY_PLAYER or 1)

function Neverbirth:RefreshStrongLaxativeOnPickup(...)
    local player = nil
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "table" and value.ToPlayer then
            local ok, maybePlayer = pcall(function()
                return value:ToPlayer()
            end)
            if ok and maybePlayer then
                player = maybePlayer
                break
            end
        end
    end

    if player then
        Neverbirth.StrongLaxative.ApplyCostume(player, true)
    end
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.RefreshStrongLaxativeOnPickup, Items.StrongLaxative)
end

function Neverbirth:ResetStrongLaxativeRoomState()
    strongLaxativeRoomPoopCounts[GetFolkRoomKey()] = 0
    for _, state in pairs(strongLaxativeStates) do
        if type(state) == "table" then
            state.creepCooldown = 0
            state.poopTimer = 0
        end
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.ResetStrongLaxativeRoomState)
end

local function DischargeCoinSewnSword(player, slot)
    if player and player.DischargeActiveItem then
        pcall(function()
            player:DischargeActiveItem(slot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0)
        end)
    end
end

local function GetCoinSwordActiveItem(player, slot)
    if not player or not player.GetActiveItem then
        return Items.CoinSewnSword
    end

    local ok, itemId = pcall(function()
        return player:GetActiveItem(slot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0)
    end)
    if ok then
        return itemId
    end

    return Items.CoinSewnSword
end

local function FireCoinSewnSword(player, direction, slot)
    if not player then
        return false
    end

    local baseDirection = (direction and direction:Length() > 0) and direction:Normalized() or GetCoinSwordBaseDirection(player)
    Neverbirth.SuppressNextCoinSwordReleaseTear(player)
    local coins = GetPlayerCoins(player)
    if coins <= 0 then
        if player.TakeDamage then
            player:TakeDamage(1, COIN_SWORD_BACKLASH_FLAGS, EntityRef(player), 0)
        end
        SpawnFolkEffect(FOLK_RED_CREEP, player.Position, player)
        SpawnCoinSwordQi(player, COIN_SWORD_BLOOD_DAMAGE_MULT, "blood", baseDirection)
        DischargeCoinSewnSword(player, slot)
        return true
    end

    local spent = math.min(coins, COIN_SWORD_MAX_SPEND)
    AddPlayerCoins(player, -spent)
    for index = 1, spent do
        local angle = 0
        if spent > 1 then
            angle = -COIN_SWORD_MODE_CONFIGS.normal.scatter + ((index - 1) * COIN_SWORD_MODE_CONFIGS.normal.scatter * 2 / (spent - 1))
        end
        local forwardOffset = (index - 1) * 3
        SpawnCoinSwordQi(player, COIN_SWORD_NORMAL_DAMAGE_MULT, "normal", RotateVector(baseDirection, angle), forwardOffset)
    end
    if spent >= COIN_SWORD_MAX_SPEND then
        SpawnCoinSwordQi(player, COIN_SWORD_EMPOWERED_DAMAGE_MULT, "empowered", baseDirection)
    end

    DischargeCoinSewnSword(player, slot)
    return true
end

local function GetCoinSwordHoldKey(player)
    return tostring((player and player.InitSeed) or "")
end

function Neverbirth.GetCoinSwordTearOwnerKey(tear)
    if not tear then
        return nil
    end

    local candidates = { tear.SpawnerEntity, tear.Parent }
    for _, entity in ipairs(candidates) do
        if entity then
            local player = nil
            if entity.ToPlayer then
                local ok, value = pcall(function()
                    return entity:ToPlayer()
                end)
                if ok then
                    player = value
                end
            end
            player = player or (entity.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) and entity or nil)
            if player and player.InitSeed then
                return GetCoinSwordHoldKey(player)
            end
        end
    end

    return nil
end

function Neverbirth.SuppressNextCoinSwordReleaseTear(player)
    local key = GetCoinSwordHoldKey(player)
    if key == "" then
        return
    end

    Neverbirth.__coinSwordReleaseTearSuppressions[key] = {
        shots = 1,
        frames = 3,
    }
end

function Neverbirth.RemoveCoinSwordTear(tear)
    if tear and tear.Remove then
        pcall(function()
            tear:Remove()
        end)
    end
end

function Neverbirth.ShouldSuppressCoinSwordTear(tear)
    if not tear or tear.Type ~= ((EntityType and EntityType.ENTITY_TEAR) or 2) then
        return false
    end

    local key = Neverbirth.GetCoinSwordTearOwnerKey(tear)
    if not key then
        return false
    end

    if coinSwordHoldStates[key] then
        return true
    end

    local suppression = Neverbirth.__coinSwordReleaseTearSuppressions[key]
    if suppression and (suppression.shots or 0) > 0 then
        suppression.shots = suppression.shots - 1
        if suppression.shots <= 0 then
            Neverbirth.__coinSwordReleaseTearSuppressions[key] = nil
        end
        return true
    end

    return false
end

function Neverbirth:SuppressCoinSewnSwordTear(tear)
    if Neverbirth.ShouldSuppressCoinSwordTear(tear) then
        Neverbirth.RemoveCoinSwordTear(tear)
    end
end

function Neverbirth.UpdateCoinSwordReleaseTearSuppressions()
    for key, suppression in pairs(Neverbirth.__coinSwordReleaseTearSuppressions) do
        suppression.frames = (tonumber(suppression.frames) or 0) - 1
        if suppression.frames <= 0 or (suppression.shots or 0) <= 0 then
            Neverbirth.__coinSwordReleaseTearSuppressions[key] = nil
        end
    end
end

function Neverbirth.SuppressCoinSwordTearsInRoomFallback()
    if not Isaac.GetRoomEntities then
        return
    end
    if not next(coinSwordHoldStates) and not next(Neverbirth.__coinSwordReleaseTearSuppressions) then
        return
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if Neverbirth.ShouldSuppressCoinSwordTear(entity) then
            Neverbirth.RemoveCoinSwordTear(entity)
        end
    end
end

local function CancelCoinSewnSwordHold(player)
    coinSwordHoldStates[GetCoinSwordHoldKey(player)] = nil
end

local function StartCoinSewnSwordHold(player, slot)
    coinSwordHoldStates[GetCoinSwordHoldKey(player)] = {
        player = player,
        slot = slot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0,
    }
end

function Neverbirth:UseCoinSewnSword(_, _, player, _, activeSlot)
    if not player then
        return false
    end

    local key = GetCoinSwordHoldKey(player)
    if coinSwordHoldStates[key] then
        local direction = GetCoinSwordReleaseDirection(player)
        if direction then
            local state = coinSwordHoldStates[key]
            coinSwordHoldStates[key] = nil
            FireCoinSewnSword(player, direction, state.slot or activeSlot)
        else
            coinSwordHoldStates[key] = nil
        end
        return COIN_SWORD_NO_DISCHARGE_RESULT
    end

    StartCoinSewnSwordHold(player, activeSlot)
    return COIN_SWORD_NO_DISCHARGE_RESULT
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseCoinSewnSword, Items.CoinSewnSword)

function Neverbirth:UpdateCoinSewnSwordHold()
    for key, state in pairs(coinSwordHoldStates) do
        local player = state and state.player
        if not player or GetCoinSwordActiveItem(player, state.slot) ~= Items.CoinSewnSword then
            coinSwordHoldStates[key] = nil
        else
            local direction = GetCoinSwordReleaseDirection(player)
            if direction then
                coinSwordHoldStates[key] = nil
                FireCoinSewnSword(player, direction, state.slot)
            end
        end
    end
    Neverbirth.SuppressCoinSwordTearsInRoomFallback()
    Neverbirth.UpdateCoinSwordReleaseTearSuppressions()
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateCoinSewnSwordHold)

if ModCallbacks.MC_POST_FIRE_TEAR then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, Neverbirth.SuppressCoinSewnSwordTear)
end

function Neverbirth:CancelCoinSewnSwordHolds()
    coinSwordHoldStates = {}
    Neverbirth.__coinSwordReleaseTearSuppressions = {}
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.CancelCoinSewnSwordHolds)
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.CancelCoinSewnSwordHolds)
end

local function GetMaskState(player)
    local key = GetFolkPlayerKey(player)
    local state = coinFacedMaskStates[key]
    if type(state) ~= "table" or state.roomKey ~= GetFolkRoomKey() then
        state = {
            roomKey = GetFolkRoomKey(),
            active = false,
            consumed = false,
            luckPenalty = 0,
        }
        coinFacedMaskStates[key] = state
    end
    return state
end

local function GetCoinMaskCostumeId(path)
    if not Isaac or not Isaac.GetCostumeIdByPath then
        return nil
    end

    if coinFacedMaskCostumeIds[path] ~= nil then
        return coinFacedMaskCostumeIds[path]
    end

    local ok, costumeId = pcall(function()
        return Isaac.GetCostumeIdByPath(path)
    end)
    if ok and type(costumeId) == "number" and costumeId > 0 then
        coinFacedMaskCostumeIds[path] = costumeId
    else
        coinFacedMaskCostumeIds[path] = false
    end

    return coinFacedMaskCostumeIds[path] or nil
end

local function GetFirstCoinMaskCostumeId(paths)
    for _, path in ipairs(paths or {}) do
        local costumeId = GetCoinMaskCostumeId(path)
        if costumeId then
            return costumeId
        end
    end
    return nil
end

local function TryRemoveCoinMaskCostume(player, costumeId)
    if player and costumeId and player.TryRemoveNullCostume then
        pcall(function()
            player:TryRemoveNullCostume(costumeId)
        end)
    end
end

local function TryAddCoinMaskCostume(player, costumeId)
    if player and costumeId and player.AddNullCostume then
        pcall(function()
            player:AddNullCostume(costumeId)
        end)
    end
end

local function ApplyCoinFacedMaskCostume(player, visualState)
    if not player then
        return
    end

    local key = GetFolkPlayerKey(player)
    visualState = visualState or COIN_MASK_VISUAL_NONE
    if coinFacedMaskCostumeStates[key] == visualState then
        return
    end

    local activeCostume = GetFirstCoinMaskCostumeId(COIN_MASK_COSTUME_PATHS)
    local brokenCostume = GetFirstCoinMaskCostumeId(COIN_MASK_BROKEN_COSTUME_PATHS)
    if activeCostume then
        TryRemoveCoinMaskCostume(player, activeCostume)
    end
    if brokenCostume then
        TryRemoveCoinMaskCostume(player, brokenCostume)
    end

    if visualState == COIN_MASK_VISUAL_ACTIVE then
        TryAddCoinMaskCostume(player, activeCostume)
    elseif visualState == COIN_MASK_VISUAL_BROKEN then
        TryAddCoinMaskCostume(player, brokenCostume)
    end

    coinFacedMaskCostumeStates[key] = visualState
end

function Neverbirth.GetCoinFacedMaskVisualState(state)
    if state and state.active then
        return COIN_MASK_VISUAL_ACTIVE
    end
    if state and (tonumber(state.luckPenalty) or 0) ~= 0 then
        return COIN_MASK_VISUAL_BROKEN
    end
    return COIN_MASK_VISUAL_NONE
end

local function RefreshMaskLuck(player)
    if player and player.AddCacheFlags and CacheFlag then
        player:AddCacheFlags(CacheFlag.CACHE_LUCK)
        if player.EvaluateItems then
            player:EvaluateItems()
        end
    end
end

local function DisturbMaskEnemies(player)
    if not Isaac.GetRoomEntities then
        return
    end

    local ref = EntityRef(player)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsVulnerableEnemy(entity) and entity.AddConfusion then
            pcall(function()
                entity:AddConfusion(ref, MASK_CONFUSION_DURATION, false)
            end)
        end
    end
end

local function RefreshCoinFacedMaskForPlayer(player)
    local previous = coinFacedMaskStates[GetFolkPlayerKey(player)]
    local hadPenalty = previous and (tonumber(previous.luckPenalty) or 0) ~= 0
    local state = {
        roomKey = GetFolkRoomKey(),
        active = PlayerHasCollectible(player, Items.CoinFacedMask) and GetPlayerCoins(player) >= MASK_REQUIRED_COINS,
        consumed = false,
        luckPenalty = 0,
    }
    coinFacedMaskStates[GetFolkPlayerKey(player)] = state
    if state.active then
        DisturbMaskEnemies(player)
    end
    ApplyCoinFacedMaskCostume(player, Neverbirth.GetCoinFacedMaskVisualState(state))
    if hadPenalty then
        RefreshMaskLuck(player)
    end
end

function Neverbirth:RefreshCoinFacedMaskRoom()
    for _, player in ipairs(GetPlayers()) do
        RefreshCoinFacedMaskForPlayer(player)
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.RefreshCoinFacedMaskRoom)
end

function Neverbirth:ClearCoinFacedMaskCostumes()
    for _, player in ipairs(GetPlayers()) do
        ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
    end
    coinFacedMaskStates = {}
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.ClearCoinFacedMaskCostumes)
end

function Neverbirth:UpdateCoinFacedMaskCostumes()
    for _, player in ipairs(GetPlayers()) do
        local key = GetFolkPlayerKey(player)
        if not PlayerHasCollectible(player, Items.CoinFacedMask) then
            coinFacedMaskStates[key] = nil
            ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
        else
            local state = coinFacedMaskStates[key]
            if type(state) ~= "table" or state.roomKey ~= GetFolkRoomKey() then
                RefreshCoinFacedMaskForPlayer(player)
            elseif not state.consumed and not state.active and (tonumber(state.luckPenalty) or 0) == 0 and GetPlayerCoins(player) >= MASK_REQUIRED_COINS then
                RefreshCoinFacedMaskForPlayer(player)
            else
                ApplyCoinFacedMaskCostume(player, Neverbirth.GetCoinFacedMaskVisualState(state))
            end
        end
    end
end

if ModCallbacks.MC_POST_UPDATE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateCoinFacedMaskCostumes)
end

local function HasCoinFacedMaskDamageFlag(flags, flag)
    return type(flags) == "number" and type(flag) == "number" and (flags & flag) ~= 0
end

local function IsIgnoredCoinFacedMaskDamage(flags)
    local ignoredFlags = {
        DamageFlag and DamageFlag.DAMAGE_FAKE,
        DamageFlag and DamageFlag.DAMAGE_IV_BAG,
        DamageFlag and DamageFlag.DAMAGE_DEVIL,
        DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
        DamageFlag and DamageFlag.DAMAGE_NOKILL,
    }

    for _, flag in ipairs(ignoredFlags) do
        if HasCoinFacedMaskDamageFlag(flags, flag) then
            return true
        end
    end

    return false
end

local function GetCoinFacedMaskDamageSourceEntity(source)
    if source and source.Entity then
        return source.Entity
    end
    return source
end

local function IsCoinFacedMaskMonsterDamage(source)
    local sourceEntity = GetCoinFacedMaskDamageSourceEntity(source)
    if not sourceEntity then
        return true
    end

    if sourceEntity.ToPlayer then
        local ok, sourcePlayer = pcall(function()
            return sourceEntity:ToPlayer()
        end)
        if ok and sourcePlayer then
            return false
        end
    end

    if IsVulnerableEnemy(sourceEntity) then
        return true
    end

    return sourceEntity.Type ~= (EntityType and EntityType.ENTITY_PLAYER or 1)
end

function Neverbirth:HandleCoinFacedMaskDamage(entity, amount, flags, source)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if coinFacedMaskSettling > 0 or not player or (tonumber(amount) or 0) <= 0 or not PlayerHasCollectible(player, Items.CoinFacedMask) or IsIgnoredCoinFacedMaskDamage(flags) or not IsCoinFacedMaskMonsterDamage(source) then
        return nil
    end

    local state = GetMaskState(player)
    if not state.active or state.consumed then
        return nil
    end

    state.consumed = true
    state.active = false
    if GetPlayerCoins(player) >= MASK_REQUIRED_COINS then
        AddPlayerCoins(player, -MASK_REQUIRED_COINS)
        ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
        return false
    end

    state.luckPenalty = MASK_LUCK_PENALTY
    ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_BROKEN)
    RefreshMaskLuck(player)
    DisturbMaskEnemies(player)
    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleCoinFacedMaskDamage, EntityType.ENTITY_PLAYER)

function Neverbirth:EvaluateCoinFacedMask(player, cacheFlag)
    if not CacheFlag or cacheFlag ~= CacheFlag.CACHE_LUCK then
        return
    end

    local state = coinFacedMaskStates[GetFolkPlayerKey(player)]
    local penalty = tonumber(state and state.roomKey == GetFolkRoomKey() and state.luckPenalty) or 0
    if penalty ~= 0 then
        player.Luck = player.Luck + penalty
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateCoinFacedMask)

Neverbirth.BlackTaisuiStageTwoThreshold = 8
Neverbirth.BlackTaisuiStageThreeThreshold = 16
Neverbirth.BlackTaisuiStageOneDamagePenalty = 0.5
Neverbirth.BlackTaisuiStageOneSpeedPenalty = 0.2
Neverbirth.BlackTaisuiStageOneLuckPenalty = 3
Neverbirth.BlackTaisuiStageTwoDamagePenalty = 0.5
Neverbirth.BlackTaisuiStageThreeDamageBonus = 1.5
Neverbirth.BlackTaisuiDamageFloor = 1
Neverbirth.BlackTaisuiSpeedFloor = 0.5
Neverbirth.BlackTaisuiFearDuration = 90
Neverbirth.BlackTaisuiFearRadius = 180
Neverbirth.BlackTaisuiWavyCap = (CollectibleType and CollectibleType.COLLECTIBLE_WAVY_CAP) or 582
Neverbirth.BlackTaisuiWavyCapTearsBonus = 0.75
Neverbirth.BlackTaisuiWavyCapRangeBonus = 20
Neverbirth.BlackTaisuiOfficialLifeItem = (CollectibleType and CollectibleType.COLLECTIBLE_1UP) or 11
Neverbirth.BlackTaisuiLifeHudText = "WARD"
Neverbirth.BlackTaisuiLifeHudX = 132
Neverbirth.BlackTaisuiLifeHudY = 28
Neverbirth.CleansedWavyCapSpeedPenalty = 0.03
Neverbirth.CleansedWavyCapTearsBonus = 0.75
Neverbirth.CleansedWavyCapSettledSpeedPenalty = 0.06
Neverbirth.CleansedWavyCapSettledTearsBonus = 0.30
Neverbirth.CleansedWavyCapMaxCharge = 900
Neverbirth.CleansedWavyCapChargeStep = 100

function Neverbirth.GetBlackTaisuiData()
    EnsureMusicboxDataLoaded()
    local data = musicboxSaveData.blackTaisui
    if type(data) ~= "table" or data.runSeed ~= GetCurrentRunSeed() then
        data = { runSeed = GetCurrentRunSeed(), players = {}, meatLumpCounts = {}, meatLumpLives = {} }
        musicboxSaveData.blackTaisui = data
    end
    if type(data.players) ~= "table" then
        data.players = {}
    end
    if type(data.meatLumpCounts) ~= "table" then
        data.meatLumpCounts = {}
    end
    if type(data.meatLumpLives) ~= "table" then
        data.meatLumpLives = {}
    end
    return data
end

function Neverbirth:GetBlackTaisuiSavedPlayer(player)
    local key = GetFolkPlayerKey(player)
    local data = Neverbirth.GetBlackTaisuiData()
    local saved = data.players[key]
    if type(saved) ~= "table" then
        saved = { parasite = 0 }
        data.players[key] = saved
    end
    saved.parasite = math.max(0, tonumber(saved.parasite) or 0)
    return saved
end

function Neverbirth:GetBlackTaisuiRuntimeState(player)
    local key = GetFolkPlayerKey(player)
    local state = blackTaisuiStates[key]
    if type(state) ~= "table" then
        state = { floorKey = GetFolkFloorKey(), sporeKeys = {} }
        blackTaisuiStates[key] = state
    end
    if state.floorKey ~= GetFolkFloorKey() then
        state.floorKey = GetFolkFloorKey()
        state.deathSavedFloorKey = nil
        state.sporeKeys = {}
        state.wavySuppressedStacks = 0
    end
    if type(state.sporeKeys) ~= "table" then
        state.sporeKeys = {}
    end
    return state
end

function Neverbirth:GetBlackTaisuiParasiteValue(player)
    return tonumber(Neverbirth:GetBlackTaisuiSavedPlayer(player).parasite) or 0
end

function Neverbirth:SetBlackTaisuiParasiteValue(player, value)
    local oldStage = Neverbirth:GetBlackTaisuiStage(player)
    Neverbirth:GetBlackTaisuiSavedPlayer(player).parasite = math.max(0, tonumber(value) or 0)
    Neverbirth:SpawnFolkVisualEffect("BlackTaisuiPulse", player and player.Position or Vector(320, 280), player)
    SaveMusicboxData()
    Neverbirth:RefreshBlackTaisuiCache(player)
    if Neverbirth:GetBlackTaisuiStage(player) > oldStage then
        Neverbirth:TriggerBlackTaisuiSpores(player, "stage-set:" .. tostring(value), true)
    end
    if Neverbirth:GetBlackTaisuiStage(player) >= 2 then
        Neverbirth:SuppressBlackTaisuiLevelCurses(player)
        Neverbirth:RevealBlackTaisuiRoomCollectibles(player, "stage-set")
    end
    Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
end

function Neverbirth:GetBlackTaisuiStage(player)
    local parasite = Neverbirth:GetBlackTaisuiParasiteValue(player)
    if parasite >= Neverbirth.BlackTaisuiStageThreeThreshold then
        return 3
    elseif parasite >= Neverbirth.BlackTaisuiStageTwoThreshold then
        return 2
    end
    return 1
end

function Neverbirth:SpawnBlackTaisuiMeatLump(player)
    if not player or not PlayerHasCollectible(player, Items.BlackTaisui) or Neverbirth:GetBlackTaisuiStage(player) < 3 then
        return false
    end
    local saved = Neverbirth:GetBlackTaisuiSavedPlayer(player)
    if saved.meatLumpSpawned then
        return false
    end
    if not IsValidItemId(Items.MeatLump) or not Isaac or not Isaac.Spawn or not EntityType or not PickupVariant then
        return false
    end

    local position = player.Position or Vector(320, 280)
    local game = GetFolkGame()
    local room = game and game.GetRoom and game:GetRoom() or nil
    if room and room.FindFreePickupSpawnPosition then
        pcall(function()
            position = room:FindFreePickupSpawnPosition(position, 40, true, false)
        end)
    end

    local ok, spawned = pcall(function()
        return Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, Items.MeatLump, position, Vector(0, 0), player)
    end)
    if ok and spawned then
        saved.meatLumpSpawned = true
        SaveMusicboxData()
        Neverbirth:TriggerBlackTaisuiSpores(player, "meat-lump:" .. tostring(GetFolkPlayerKey(player)), true)
        return true
    end
    return false
end

function Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
    Neverbirth:SpawnBlackTaisuiMeatLump(player)
end

function Neverbirth:RefreshBlackTaisuiCache(player)
    if not player or not player.AddCacheFlags or not CacheFlag then
        return
    end
    local flags = 0
    if CacheFlag.CACHE_DAMAGE then flags = flags | CacheFlag.CACHE_DAMAGE end
    if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
    if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
    if CacheFlag.CACHE_RANGE then flags = flags | CacheFlag.CACHE_RANGE end
    if CacheFlag.CACHE_LUCK then flags = flags | CacheFlag.CACHE_LUCK end
    player:AddCacheFlags(flags)
    if player.EvaluateItems then
        player:EvaluateItems()
    end
end

function Neverbirth:AddBlackTaisuiParasite(player, amount, reason)
    if not player or not PlayerHasCollectible(player, Items.BlackTaisui) then
        return
    end
    amount = tonumber(amount) or 0
    if amount <= 0 then
        return
    end
    local saved = Neverbirth:GetBlackTaisuiSavedPlayer(player)
    local oldStage = Neverbirth:GetBlackTaisuiStage(player)
    saved.parasite = math.max(0, (tonumber(saved.parasite) or 0) + amount)
    Neverbirth:SpawnFolkVisualEffect("BlackTaisuiPulse", player.Position or Vector(320, 280), player)
    SaveMusicboxData()
    Neverbirth:RefreshBlackTaisuiCache(player)
    if Neverbirth:GetBlackTaisuiStage(player) > oldStage then
        Neverbirth:TriggerBlackTaisuiSpores(player, "stage:" .. tostring(reason or saved.parasite), true)
    end
    Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
end

function Neverbirth:GetBlackTaisuiHealthSnapshot(player)
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    state.maxHearts = player and player.GetMaxHearts and player:GetMaxHearts() or tonumber(player and player.maxHearts) or 0
    state.hearts = player and player.GetHearts and player:GetHearts() or tonumber(player and player.hearts) or 0
    state.soulHearts = player and player.GetSoulHearts and player:GetSoulHearts() or tonumber(player and player.soulHearts) or 0
    state.blackHearts = player and player.GetBlackHearts and player:GetBlackHearts() or tonumber(player and player.blackHearts) or 0
    state.snapshotReady = true
    return state
end

function Neverbirth:UpdateBlackTaisuiParasiteFromHealth(player)
    if not player or not PlayerHasCollectible(player, Items.BlackTaisui) then
        return
    end
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or tonumber(player.maxHearts) or 0
    local hearts = player.GetHearts and player:GetHearts() or tonumber(player.hearts) or 0
    local soulHearts = player.GetSoulHearts and player:GetSoulHearts() or tonumber(player.soulHearts) or 0
    if not state.snapshotReady then
        Neverbirth:GetBlackTaisuiHealthSnapshot(player)
        return
    end

    local gainedContainers = math.max(0, maxHearts - (tonumber(state.maxHearts) or 0))
    if gainedContainers > 0 then
        Neverbirth:AddBlackTaisuiParasite(player, (gainedContainers / 2) * 4, "container")
    end

    if maxHearts > 0 then
        local redHealing = math.max(0, hearts - (tonumber(state.hearts) or 0))
        if redHealing > 0 then
            Neverbirth:AddBlackTaisuiParasite(player, redHealing, "red-heal")
        end
    else
        -- In Repentance, GetBlackHearts is a bitmask, while GetSoulHearts is
        -- the real soul/black layer amount. Use the layer amount to avoid
        -- treating black-heart masks as extra health.
        local soulHealing = math.max(0, soulHearts - (tonumber(state.soulHearts) or 0))
        if soulHealing > 0 then
            Neverbirth:AddBlackTaisuiParasite(player, soulHealing * 0.5, "soul-heal")
        end
    end

    Neverbirth:GetBlackTaisuiHealthSnapshot(player)
end

function Neverbirth:IsBlackTaisuiIgnoredDamage(flags)
    flags = tonumber(flags) or 0
    local ignoredFlags = {
        DamageFlag and DamageFlag.DAMAGE_FAKE,
        DamageFlag and DamageFlag.DAMAGE_IV_BAG,
        DamageFlag and DamageFlag.DAMAGE_DEVIL,
        DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
        DamageFlag and DamageFlag.DAMAGE_NOKILL,
    }
    for _, flag in ipairs(ignoredFlags) do
        if flag and (flags & flag) ~= 0 then
            return true
        end
    end
    return false
end

function Neverbirth:BlackTaisuiDamageIsLethal(player, amount)
    return IsIncomingDamageLethal(player, tonumber(amount) or 0)
end

function Neverbirth:TriggerBlackTaisuiSpores(player, reason, strong)
    if not player then
        return
    end
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    local key = tostring(reason or "spore") .. ":" .. tostring(GetFolkRoomKey())
    if state.sporeKeys[key] then
        return
    end
    state.sporeKeys[key] = true
    SpawnFolkEffect(FOLK_BLACK_CREEP, player.Position or Vector(320, 280), player)
    Neverbirth:SpawnFolkVisualEffect(strong and "BlackTaisuiFearPulse" or "BlackTaisuiSpore", player.Position or Vector(320, 280), player)
    if player.SetColor then
        pcall(function()
            player:SetColor(Color(0.22, 0.22, 0.22, 1, 0, 0, 0.08), strong and 45 or 20, 1, true, false)
        end)
    end
    if not Isaac.GetRoomEntities then
        return
    end
    local ref = EntityRef(player)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsVulnerableEnemy(entity) and entity.AddFear then
            pcall(function()
                entity:AddFear(ref, Neverbirth.BlackTaisuiFearDuration, false)
            end)
        end
    end
end

function Neverbirth:BlackTaisuiDeathSaveAvailable(player)
    if not player or not PlayerHasCollectible(player, Items.BlackTaisui) or Neverbirth:GetBlackTaisuiStage(player) < 3 then
        return false
    end
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    return state.deathSavedFloorKey ~= GetFolkFloorKey()
end

function Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    if not player or not player.GetEffects then
        return nil
    end
    local ok, effects = pcall(function()
        return player:GetEffects()
    end)
    if ok then
        return effects
    end
    return nil
end

function Neverbirth:GetBlackTaisuiOfficialLifeCount(player)
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    if not effects then
        return nil
    end
    local itemId = Neverbirth.BlackTaisuiOfficialLifeItem
    if effects.GetCollectibleEffectNum then
        local ok, count = pcall(function()
            return effects:GetCollectibleEffectNum(itemId)
        end)
        if ok then
            return tonumber(count) or 0
        end
    end
    if effects.HasCollectibleEffect then
        local ok, has = pcall(function()
            return effects:HasCollectibleEffect(itemId)
        end)
        if ok then
            return has and 1 or 0
        end
    end
    return nil
end

function Neverbirth:GetBlackTaisuiWavyCapEffectCount(player)
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    if not effects then
        return 0
    end
    local itemId = Neverbirth.BlackTaisuiWavyCap
    if effects.GetCollectibleEffectNum then
        local ok, count = pcall(function()
            return effects:GetCollectibleEffectNum(itemId)
        end)
        if ok then
            return tonumber(count) or 0
        end
    end
    if effects.HasCollectibleEffect then
        local ok, has = pcall(function()
            return effects:HasCollectibleEffect(itemId)
        end)
        if ok then
            return has and 1 or 0
        end
    end
    return 0
end

function Neverbirth:RemoveBlackTaisuiWavyCapEffects(player, count)
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    count = math.max(0, math.floor(tonumber(count) or 0))
    if not effects or count <= 0 or not effects.RemoveCollectibleEffect then
        return 0
    end

    local removed = 0
    local ok = pcall(function()
        effects:RemoveCollectibleEffect(Neverbirth.BlackTaisuiWavyCap, count)
    end)
    if ok then
        removed = count
    else
        for _ = 1, count do
            local oneOk = pcall(function()
                effects:RemoveCollectibleEffect(Neverbirth.BlackTaisuiWavyCap, 1)
            end)
            if oneOk then
                removed = removed + 1
            else
                break
            end
        end
    end
    return removed
end

function Neverbirth:AddBlackTaisuiOfficialLifeEffect(player)
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    if state.officialLifeEffectActive then
        return true
    end
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    if not effects or not effects.AddCollectibleEffect then
        return false
    end
    local ok = pcall(function()
        effects:AddCollectibleEffect(Neverbirth.BlackTaisuiOfficialLifeItem, false, 1)
    end)
    if ok then
        state.officialLifeEffectActive = true
        local count = Neverbirth:GetBlackTaisuiOfficialLifeCount(player)
        state.officialLifeEffectConfirmed = count ~= nil and count > 0
        return true
    end
    return false
end

function Neverbirth:RemoveBlackTaisuiOfficialLifeEffect(player)
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    local hasEffect = state.officialLifeEffectActive == true
    if not hasEffect and effects and effects.GetCollectibleEffectNum then
        local ok, count = pcall(function()
            return effects:GetCollectibleEffectNum(Neverbirth.BlackTaisuiOfficialLifeItem)
        end)
        hasEffect = ok and (tonumber(count) or 0) > 0
    end
    if not hasEffect then
        state.officialLifeEffectActive = nil
        state.officialLifeEffectConfirmed = nil
        return
    end
    if effects and effects.RemoveCollectibleEffect then
        pcall(function()
            effects:RemoveCollectibleEffect(Neverbirth.BlackTaisuiOfficialLifeItem, 1)
        end)
    end
    state.officialLifeEffectActive = nil
    state.officialLifeEffectConfirmed = nil
end

function Neverbirth:SyncBlackTaisuiOfficialLifeEffect(player)
    -- Do not fake the official 1UP HUD/costume for Black Taisui. The protection
    -- is a damage ward, not an extra-life item, so always clean old temp effects.
    Neverbirth:RemoveBlackTaisuiOfficialLifeEffect(player)
end

function Neverbirth:RestoreBlackTaisuiDeathSaveHealth(player)
    if player.GetMaxHearts and player:GetMaxHearts() > 0 then
        if player.GetHearts and player.AddHearts then
            local current = tonumber(player:GetHearts()) or 0
            player:AddHearts(1 - current)
        end
    elseif player.AddBlackHearts then
        player:AddBlackHearts(2)
    end
end

function Neverbirth:ApplyBlackTaisuiDeathSave(player, reviveDeadPlayer)
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    Neverbirth:RemoveBlackTaisuiOfficialLifeEffect(player)
    state.deathSavedFloorKey = GetFolkFloorKey()
    state.deathSaveFeedbackFrames = 90
    state.deathSaveFeedbackText = "TAISUI BLOCK"
    if reviveDeadPlayer and player.Revive then
        pcall(function()
            player:Revive()
        end)
    end
    Neverbirth:RestoreBlackTaisuiDeathSaveHealth(player)
    if player and player.SetColor and Color then
        pcall(function()
            player:SetColor(Color(0.35, 0.08, 0.45, 1, 0.12, 0, 0.2), 45, 1, true, false)
        end)
    end
    Neverbirth:SpawnFolkVisualEffect("BlackTaisuiDeathDeny", player.Position or Vector(320, 280), player)
    local game = GetFolkGame()
    local hud = game and game.GetHUD and game:GetHUD()
    if hud and hud.ShowItemText then
        pcall(function()
            hud:ShowItemText("黑太岁", "挡下致命伤害")
        end)
    end
    Neverbirth:TriggerBlackTaisuiSpores(player, "death-save:" .. tostring(GetFolkFloorKey()), true)
end

function Neverbirth:HandleBlackTaisuiDamage(entity, amount, flags)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player or (tonumber(amount) or 0) <= 0 or not PlayerHasCollectible(player, Items.BlackTaisui) then
        return nil
    end
    if Neverbirth:IsBlackTaisuiIgnoredDamage(flags) then
        return nil
    end

    if Neverbirth:BlackTaisuiDeathSaveAvailable(player) and Neverbirth:BlackTaisuiDamageIsLethal(player, amount) then
        Neverbirth:ApplyBlackTaisuiDeathSave(player, false)
        return false
    end

    local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or tonumber(player.maxHearts) or 0
    if maxHearts > 0 and DamageFlag and DamageFlag.DAMAGE_RED_HEARTS and ((tonumber(flags) or 0) & DamageFlag.DAMAGE_RED_HEARTS) ~= 0 then
        Neverbirth:AddBlackTaisuiParasite(player, (tonumber(amount) or 0) * 2, "red-damage")
    elseif maxHearts <= 0 then
        Neverbirth:AddBlackTaisuiParasite(player, (tonumber(amount) or 0), "soul-damage")
    end

    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleBlackTaisuiDamage, EntityType.ENTITY_PLAYER)

function Neverbirth:EvaluateBlackTaisui(player, cacheFlag)
    if not player or not CacheFlag or not PlayerHasCollectible(player, Items.BlackTaisui) then
        return
    end
    local copies = player.GetCollectibleNum and (tonumber(player:GetCollectibleNum(Items.BlackTaisui)) or 0) or 1
    if copies <= 0 then
        return
    end

    local stage = Neverbirth:GetBlackTaisuiStage(player)
    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        if stage >= 3 then
            player.Damage = player.Damage + (Neverbirth.BlackTaisuiStageThreeDamageBonus * copies)
        else
            local penalty = stage >= 2 and Neverbirth.BlackTaisuiStageTwoDamagePenalty or (Neverbirth.BlackTaisuiStageOneDamagePenalty * copies)
            if player.Damage > Neverbirth.BlackTaisuiDamageFloor then
                player.Damage = math.max(Neverbirth.BlackTaisuiDamageFloor, player.Damage - penalty)
            end
        end
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        if stage == 1 and player.MoveSpeed and player.MoveSpeed > Neverbirth.BlackTaisuiSpeedFloor then
            player.MoveSpeed = math.max(Neverbirth.BlackTaisuiSpeedFloor, player.MoveSpeed - Neverbirth.BlackTaisuiStageOneSpeedPenalty * copies)
        end
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        local currentSpeed = tonumber(state.cleansedWavyCurrentSpeed) or 0
        local lingeringSpeed = tonumber(state.cleansedWavyLingeringSpeed) or 0
        if (currentSpeed > 0 or lingeringSpeed > 0) and player.MoveSpeed then
            player.MoveSpeed = player.MoveSpeed - currentSpeed - lingeringSpeed
        end
    elseif cacheFlag == CacheFlag.CACHE_LUCK then
        if stage == 1 then
            player.Luck = player.Luck - Neverbirth.BlackTaisuiStageOneLuckPenalty * copies
        end
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        local stacks = tonumber(state.wavySuppressedStacks) or 0
        if stage >= 2 and stacks > 0 and player.MaxFireDelay then
            player.MaxFireDelay = player.MaxFireDelay - (Neverbirth.BlackTaisuiWavyCapTearsBonus * stacks)
        end
        local currentTears = tonumber(state.cleansedWavyCurrentTears) or 0
        local lingeringTears = tonumber(state.cleansedWavyLingeringTears) or 0
        if (currentTears > 0 or lingeringTears > 0) and player.MaxFireDelay then
            player.MaxFireDelay = player.MaxFireDelay - currentTears - lingeringTears
        end
    elseif cacheFlag == CacheFlag.CACHE_RANGE then
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        local stacks = tonumber(state.wavySuppressedStacks) or 0
        if stage >= 2 and stacks > 0 and player.TearRange then
            player.TearRange = player.TearRange + (Neverbirth.BlackTaisuiWavyCapRangeBonus * stacks)
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateBlackTaisui)

function Neverbirth:GetBlackTaisuiCurseMask()
    local mask = 0
    if LevelCurse then
        mask = ((LevelCurse.CURSE_OF_BLIND or LevelCurse.CURSE_OF_THE_BLIND or 0)
            | (LevelCurse.CURSE_OF_LOST or LevelCurse.CURSE_OF_THE_LOST or 0)
            | (LevelCurse.CURSE_OF_UNKNOWN or LevelCurse.CURSE_OF_THE_UNKNOWN or 0))
    end
    return mask
end

function Neverbirth:FilterBlackTaisuiCurses(curses)
    local result = tonumber(curses) or 0
    local mask = Neverbirth:GetBlackTaisuiCurseMask()
    if mask == 0 or (result & mask) == 0 then
        return result
    end
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasCollectible(player, Items.BlackTaisui) and Neverbirth:GetBlackTaisuiStage(player) >= 2 then
            Neverbirth:TriggerBlackTaisuiSpores(player, "curse:" .. tostring(result), false)
            Neverbirth:SpawnFolkVisualEffect("BlackTaisuiCurseDevour", player.Position or Vector(320, 280), player)
            return result & (~mask)
        end
    end
    return result
end

function Neverbirth:SuppressBlackTaisuiLevelCurses(player)
    local mask = Neverbirth:GetBlackTaisuiCurseMask()
    if mask == 0 then
        return false
    end
    local game = GetFolkGame()
    local level = game and game.GetLevel and game:GetLevel() or nil
    if not level then
        return false
    end

    local current = nil
    if level.GetCurses then
        local ok, value = pcall(function()
            return level:GetCurses()
        end)
        if ok then
            current = tonumber(value) or 0
            if (current & mask) == 0 then
                return false
            end
        end
    end

    local changed = false
    if level.RemoveCurses then
        local ok = pcall(function()
            level:RemoveCurses(mask)
        end)
        changed = changed or ok
    end
    if level.RemoveCurse and LevelCurse then
        local curseList = {
            LevelCurse.CURSE_OF_BLIND or LevelCurse.CURSE_OF_THE_BLIND,
            LevelCurse.CURSE_OF_LOST or LevelCurse.CURSE_OF_THE_LOST,
            LevelCurse.CURSE_OF_UNKNOWN or LevelCurse.CURSE_OF_THE_UNKNOWN,
        }
        for _, curse in ipairs(curseList) do
            if curse and curse ~= 0 then
                local ok = pcall(function()
                    level:RemoveCurse(curse)
                end)
                changed = changed or ok
            end
        end
    end
    if current ~= nil and level.SetCurses then
        local ok = pcall(function()
            level:SetCurses(current & (~mask))
        end)
        changed = changed or ok
    end

    if changed and player then
        Neverbirth:TriggerBlackTaisuiSpores(player, "curse-active:" .. tostring(GetFolkFloorKey()), false)
        Neverbirth:SpawnFolkVisualEffect("BlackTaisuiCurseDevour", player.Position or Vector(320, 280), player)
    end
    return changed
end

if ModCallbacks.MC_POST_CURSE_EVAL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, Neverbirth.FilterBlackTaisuiCurses)
end

function Neverbirth:AnyBlackTaisuiStageAtLeast(stage)
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasCollectible(player, Items.BlackTaisui) and Neverbirth:GetBlackTaisuiStage(player) >= stage then
            return true, player
        end
    end
    return false, nil
end

function Neverbirth:GetBlackTaisuiCollectibleGfx(subtype)
    if not Isaac or not Isaac.GetItemConfig then
        return nil
    end
    local ok, config = pcall(function()
        return Isaac.GetItemConfig()
    end)
    if not ok or not config or not config.GetCollectible then
        return nil
    end
    local itemOk, collectible = pcall(function()
        return config:GetCollectible(subtype)
    end)
    if itemOk and collectible and collectible.GfxFileName and collectible.GfxFileName ~= "" then
        return collectible.GfxFileName
    end
    return nil
end

function Neverbirth:ApplyBlackTaisuiCollectibleSprite(pickup, subtype)
    if not pickup or not pickup.GetSprite then
        return false
    end
    local gfx = Neverbirth:GetBlackTaisuiCollectibleGfx(subtype)
    if not gfx then
        return false
    end
    local ok, sprite = pcall(function()
        return pickup:GetSprite()
    end)
    if not ok or not sprite then
        return false
    end
    local animation = "Idle"
    if sprite.GetAnimation then
        local animOk, currentAnimation = pcall(function()
            return sprite:GetAnimation()
        end)
        if animOk and currentAnimation == "ShopIdle" then
            animation = "ShopIdle"
        end
    end
    local replaced = false
    if sprite.ReplaceSpritesheet then
        local replaceOk = pcall(function()
            sprite:ReplaceSpritesheet(1, gfx)
        end)
        replaced = replaced or replaceOk
    end
    if sprite.LoadGraphics then
        pcall(function()
            sprite:LoadGraphics()
        end)
    end
    if replaced then
        if pickup.hidden ~= nil then
            pickup.hidden = false
        end
        if pickup.Hidden ~= nil then
            pickup.Hidden = false
        end
        local data = pickup.GetData and pickup:GetData() or nil
        if type(data) == "table" then
            data.NeverbirthBlackTaisuiSpriteApplied = true
            data.NeverbirthBlackTaisuiSpriteSubtype = subtype
        end
    end
    return replaced
end

function Neverbirth:RevealBlackTaisuiCollectiblePickup(pickup, player, reason)
    if not pickup or not PickupVariant or pickup.Variant ~= PickupVariant.PICKUP_COLLECTIBLE then
        return false
    end

    local subtype = tonumber(pickup.SubType) or 0
    if subtype <= 0 then
        local data = pickup.GetData and pickup:GetData() or nil
        if type(data) == "table" and not data.NeverbirthBlackTaisuiUnknownLogged then
            data.NeverbirthBlackTaisuiUnknownLogged = true
            DebugLog("[neverbirth] Black Taisui skipped unknown collectible pedestal without subtype")
        end
        return false
    end

    local data = pickup.GetData and pickup:GetData() or nil
    local firstReveal = true
    if type(data) == "table" then
        local key = tostring(GetFolkFloorKey()) .. ":" .. tostring(GetFolkRoomKey()) .. ":" .. tostring(subtype)
        if data.NeverbirthBlackTaisuiRevealedKey == key then
            firstReveal = false
        else
            data.NeverbirthBlackTaisuiRevealedKey = key
        end
    end

    local refreshed = false

    refreshed = Neverbirth:ApplyBlackTaisuiCollectibleSprite(pickup, subtype) or refreshed

    if refreshed and firstReveal and player then
        Neverbirth:TriggerBlackTaisuiSpores(player, "reveal:" .. tostring(reason or GetFolkRoomKey()), false)
        Neverbirth:SpawnFolkVisualEffect("BlackTaisuiReveal", pickup.Position or (player and player.Position) or Vector(320, 280), player)
    end
    if refreshed and firstReveal then
        DebugLog("[neverbirth] Black Taisui refreshed collectible pedestal subtype=" .. tostring(subtype))
    end
    return refreshed
end

function Neverbirth:RevealBlackTaisuiRoomCollectibles(player, reason)
    if not Isaac.GetRoomEntities then
        return 0
    end
    local count = 0
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local pickup = entity
        if entity and entity.ToPickup then
            local ok, converted = pcall(function()
                return entity:ToPickup()
            end)
            if ok and converted then
                pickup = converted
            end
        end
        if Neverbirth:RevealBlackTaisuiCollectiblePickup(pickup, player, reason) then
            count = count + 1
        end
    end
    return count
end

function Neverbirth:RevealBlackTaisuiPickupOnInit(pickup)
    local active, player = Neverbirth:AnyBlackTaisuiStageAtLeast(2)
    if active then
        Neverbirth:RevealBlackTaisuiCollectiblePickup(pickup, player, "pickup-init")
    end
end

if ModCallbacks.MC_POST_PICKUP_INIT and PickupVariant then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, Neverbirth.RevealBlackTaisuiPickupOnInit, PickupVariant.PICKUP_COLLECTIBLE)
end

function Neverbirth:SuppressBlackTaisuiWavyCapSideEffects(player)
    local removed = 0
    local effectCount = Neverbirth:GetBlackTaisuiWavyCapEffectCount(player)
    if effectCount > 0 then
        removed = Neverbirth:RemoveBlackTaisuiWavyCapEffects(player, effectCount)
        if removed > 0 then
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            state.wavySuppressedStacks = (tonumber(state.wavySuppressedStacks) or 0) + removed
            Neverbirth:RefreshBlackTaisuiCache(player)
        end
    end

    if MusicManager then
        local ok, music = pcall(MusicManager)
        if ok and music then
            if music.PitchSlide then
                pcall(function()
                    music:PitchSlide(1)
                end)
            elseif music.SetPitch then
                pcall(function()
                    music:SetPitch(1)
                end)
            end
        end
    end

    local game = GetFolkGame()
    if game and game.ShakeScreen then
        pcall(function()
            game:ShakeScreen(0)
        end)
    end

    if removed > 0 then
        Neverbirth:TriggerBlackTaisuiSpores(player, "wavy:" .. tostring(GetFolkRoomKey()) .. ":" .. tostring(removed), false)
    end
end

function Neverbirth:ReplaceBlackTaisuiWavyCap(player)
    if not player or not PlayerHasCollectible(player, Items.BlackTaisui) or Neverbirth:GetBlackTaisuiStage(player) < 2 then
        return false
    end
    if not IsValidItemId(Items.CleansedWavyCap) or not PlayerHasCollectible(player, Neverbirth.BlackTaisuiWavyCap) then
        return false
    end

    local count = player.GetCollectibleNum and (tonumber(player:GetCollectibleNum(Neverbirth.BlackTaisuiWavyCap)) or 0) or 1
    count = math.max(1, math.floor(count))
    local replaced = 0
    for _ = 1, count do
        local removed = false
        if player.RemoveCollectible then
            removed = pcall(function()
                player:RemoveCollectible(Neverbirth.BlackTaisuiWavyCap)
            end)
        end
        if removed then
            replaced = replaced + 1
            if player.AddCollectible then
                pcall(function()
                    player:AddCollectible(Items.CleansedWavyCap, 0, true)
                end)
            end
        end
    end

    if replaced > 0 then
        Neverbirth:SuppressBlackTaisuiWavyCapSideEffects(player)
        Neverbirth:SpawnFolkVisualEffect("BlackTaisuiHallucinationEat", player.Position or Vector(320, 280), player)
        Neverbirth:TriggerBlackTaisuiSpores(player, "wavy-replace:" .. tostring(GetFolkPlayerKey(player)), false)
        return true
    end
    return false
end

function Neverbirth:GetCleansedWavyCapState(player)
    local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
    state.cleansedWavyRoomKey = state.cleansedWavyRoomKey or GetFolkRoomKey()
    state.cleansedWavyCurrentSpeed = tonumber(state.cleansedWavyCurrentSpeed) or 0
    state.cleansedWavyCurrentTears = tonumber(state.cleansedWavyCurrentTears) or 0
    state.cleansedWavyLingeringSpeed = tonumber(state.cleansedWavyLingeringSpeed) or 0
    state.cleansedWavyLingeringTears = tonumber(state.cleansedWavyLingeringTears) or 0
    return state
end

function Neverbirth:RefreshCleansedWavyCapCache(player)
    if not player or not player.AddCacheFlags or not CacheFlag then
        return
    end
    local flags = 0
    if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
    if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
    if flags ~= 0 then
        player:AddCacheFlags(flags)
        if player.EvaluateItems then
            player:EvaluateItems()
        end
    end
end

function Neverbirth:QueueCleansedWavyCapChargeUpdate(player, slot)
    if not player then
        return
    end
    local state = Neverbirth:GetCleansedWavyCapState(player)
    state.cleansedWavyChargeSlot = slot or 0
    state.cleansedWavyChargeDelay = 1
    state.cleansedWavyChargeRepeats = 3
end

function Neverbirth:ApplyCleansedWavyCapChargeUpdate(player)
    if not player or not player.SetActiveCharge then
        return
    end
    local state = Neverbirth:GetCleansedWavyCapState(player)
    local delay = tonumber(state.cleansedWavyChargeDelay) or 0
    if delay <= 0 then
        return
    end
    if delay > 1 then
        state.cleansedWavyChargeDelay = delay - 1
        return
    end
    local uses = tonumber(state.cleansedWavyUses) or 1
    local spent = math.min(Neverbirth.CleansedWavyCapMaxCharge, uses * Neverbirth.CleansedWavyCapChargeStep)
    local charge = math.max(0, Neverbirth.CleansedWavyCapMaxCharge - spent)
    pcall(function()
        player:SetActiveCharge(charge, state.cleansedWavyChargeSlot or 0)
    end)

    local repeats = tonumber(state.cleansedWavyChargeRepeats) or 1
    if repeats > 1 then
        state.cleansedWavyChargeRepeats = repeats - 1
        state.cleansedWavyChargeDelay = 1
    else
        state.cleansedWavyChargeDelay = nil
        state.cleansedWavyChargeRepeats = nil
    end
end

function Neverbirth:UseCleansedWavyCap(itemId, rng, player, flags, slot)
    if not player then
        return nil
    end
    local state = Neverbirth:GetCleansedWavyCapState(player)
    state.cleansedWavyRoomKey = GetFolkRoomKey()
    state.cleansedWavyCurrentSpeed = (tonumber(state.cleansedWavyCurrentSpeed) or 0) + Neverbirth.CleansedWavyCapSpeedPenalty
    state.cleansedWavyCurrentTears = (tonumber(state.cleansedWavyCurrentTears) or 0) + Neverbirth.CleansedWavyCapTearsBonus
    state.cleansedWavyUses = (tonumber(state.cleansedWavyUses) or 0) + 1
    Neverbirth:QueueCleansedWavyCapChargeUpdate(player, slot)
    Neverbirth:RefreshCleansedWavyCapCache(player)
    return true
end

function Neverbirth:AdvanceCleansedWavyCapRoom(player)
    if not player then
        return
    end
    local state = Neverbirth:GetCleansedWavyCapState(player)
    local roomKey = GetFolkRoomKey()
    if state.cleansedWavyRoomKey == roomKey then
        return
    end

    local speed = tonumber(state.cleansedWavyCurrentSpeed) or 0
    local tears = tonumber(state.cleansedWavyCurrentTears) or 0
    if speed > 0 or tears > 0 then
        state.cleansedWavyLingeringSpeed = (tonumber(state.cleansedWavyLingeringSpeed) or 0) + speed * 2
        state.cleansedWavyLingeringTears = (tonumber(state.cleansedWavyLingeringTears) or 0) + tears * 0.4
        state.cleansedWavyCurrentSpeed = 0
        state.cleansedWavyCurrentTears = 0
        Neverbirth:RefreshCleansedWavyCapCache(player)
    end
    state.cleansedWavyRoomKey = roomKey
    state.cleansedWavyClearRoomKey = nil
end

function Neverbirth:DecayCleansedWavyCapOnClear(player)
    local room = GetFolkRoom()
    if not room or not room.IsClear or not room:IsClear() then
        return
    end
    local state = Neverbirth:GetCleansedWavyCapState(player)
    local roomKey = GetFolkRoomKey()
    if state.cleansedWavyClearRoomKey == roomKey then
        return
    end
    state.cleansedWavyClearRoomKey = roomKey

    local speed = tonumber(state.cleansedWavyLingeringSpeed) or 0
    local tears = tonumber(state.cleansedWavyLingeringTears) or 0
    if speed > 0 or tears > 0 then
        state.cleansedWavyLingeringSpeed = math.max(0, speed - Neverbirth.CleansedWavyCapSettledSpeedPenalty)
        state.cleansedWavyLingeringTears = math.max(0, tears - Neverbirth.CleansedWavyCapSettledTearsBonus)
        Neverbirth:RefreshCleansedWavyCapCache(player)
    end
end

function Neverbirth:AdvanceCleansedWavyCapRooms()
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasCollectible(player, Items.CleansedWavyCap) then
            Neverbirth:AdvanceCleansedWavyCapRoom(player)
        end
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.AdvanceCleansedWavyCapRooms)
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseCleansedWavyCap, Items.CleansedWavyCap)

function Neverbirth:UpdateBlackTaisui()
    for _, player in ipairs(GetPlayers()) do
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        if (tonumber(state.deathSaveFeedbackFrames) or 0) > 0 then
            state.deathSaveFeedbackFrames = math.max(0, (tonumber(state.deathSaveFeedbackFrames) or 0) - 1)
        end
        Neverbirth:UpdateBlackTaisuiParasiteFromHealth(player)
        if PlayerHasCollectible(player, Items.BlackTaisui) and Neverbirth:GetBlackTaisuiStage(player) >= 2 and PlayerHasCollectible(player, Neverbirth.BlackTaisuiWavyCap) then
            Neverbirth:ReplaceBlackTaisuiWavyCap(player)
        end
        if PlayerHasCollectible(player, Items.BlackTaisui) and Neverbirth:GetBlackTaisuiStage(player) >= 2 and PlayerHasCollectible(player, Neverbirth.BlackTaisuiWavyCap) then
            Neverbirth:SuppressBlackTaisuiWavyCapSideEffects(player)
        end
        if PlayerHasCollectible(player, Items.CleansedWavyCap) then
            Neverbirth:ApplyCleansedWavyCapChargeUpdate(player)
            Neverbirth:AdvanceCleansedWavyCapRoom(player)
            Neverbirth:DecayCleansedWavyCapOnClear(player)
        end
        if PlayerHasCollectible(player, Items.BlackTaisui) and Neverbirth:GetBlackTaisuiStage(player) >= 2 then
            Neverbirth:SuppressBlackTaisuiLevelCurses(player)
            local revealKey = tostring(GetFolkFloorKey()) .. ":" .. tostring(GetFolkRoomKey())
            if state.revealRoomKey ~= revealKey then
                state.revealRoomKey = revealKey
                state.revealRefreshTick = 0
                Neverbirth:RevealBlackTaisuiRoomCollectibles(player, "room")
            else
                state.revealRefreshTick = (tonumber(state.revealRefreshTick) or 0) + 1
                if state.revealRefreshTick >= 10 then
                    state.revealRefreshTick = 0
                    Neverbirth:RevealBlackTaisuiRoomCollectibles(player, "room-refresh")
                end
            end
        end
        Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
        if PlayerHasCollectible(player, Items.BlackTaisui) and Neverbirth:GetBlackTaisuiStage(player) >= 3 then
            state.matureCoreTick = (tonumber(state.matureCoreTick) or 999) + 1
            if state.matureCoreTick >= 60 then
                state.matureCoreTick = 0
                Neverbirth:SpawnFolkVisualEffect("BlackTaisuiMatureCore", player.Position or Vector(320, 280), player)
            end
        end
        Neverbirth:SyncBlackTaisuiOfficialLifeEffect(player)
        if Neverbirth:BlackTaisuiDeathSaveAvailable(player) and player.IsDead then
            local deadOk, isDead = pcall(function()
                return player:IsDead()
            end)
            if deadOk and isDead then
                Neverbirth:ApplyBlackTaisuiDeathSave(player, true)
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateBlackTaisui)

function Neverbirth:RenderBlackTaisuiLifeHud()
    if not Isaac or not Isaac.RenderText then
        return
    end
    local slot = 0
    for _, player in ipairs(GetPlayers()) do
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        if Neverbirth:BlackTaisuiDeathSaveAvailable(player) then
            local x = Neverbirth.BlackTaisuiLifeHudX + slot * 24
            local y = Neverbirth.BlackTaisuiLifeHudY
            Isaac.RenderText(Neverbirth.BlackTaisuiLifeHudText, x + 1, y + 1, 0, 0, 0, 0.75)
            Isaac.RenderText(Neverbirth.BlackTaisuiLifeHudText, x, y, 0.58, 0.28, 0.76, 1)
            slot = slot + 1
        end
        if (tonumber(state.deathSaveFeedbackFrames) or 0) > 0 and player and player.Position and Isaac.WorldToScreen then
            local screen = Isaac.WorldToScreen(player.Position + Vector(0, -52))
            local text = state.deathSaveFeedbackText or "TAISUI BLOCK"
            Isaac.RenderText(text, screen.X - 34 + 1, screen.Y + 1, 0, 0, 0, 0.85)
            Isaac.RenderText(text, screen.X - 34, screen.Y, 0.65, 0.22, 0.88, 1)
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderBlackTaisuiLifeHud)

function Neverbirth:ResetBlackTaisuiOnNewLevel()
    for _, player in ipairs(GetPlayers()) do
        local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
        state.floorKey = GetFolkFloorKey()
        state.deathSavedFloorKey = nil
        state.sporeKeys = {}
        state.revealRoomKey = nil
        state.snapshotReady = false
        state.officialLifeEffectActive = nil
        state.wavySuppressedStacks = 0
        state.cleansedWavyRoomKey = GetFolkRoomKey()
        state.cleansedWavyCurrentSpeed = 0
        state.cleansedWavyCurrentTears = 0
        state.cleansedWavyLingeringSpeed = 0
        state.cleansedWavyLingeringTears = 0
        state.cleansedWavyClearRoomKey = nil
        Neverbirth:RefreshBlackTaisuiCache(player)
        Neverbirth:SyncBlackTaisuiOfficialLifeEffect(player)
    end
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.ResetBlackTaisuiOnNewLevel)
end

local GOOD_GIRL_TEARS_BONUS = 0.6
local GOOD_GIRL_LUCK_BONUS = 2
local GOOD_GIRL_BROKEN_LUCK_PENALTY = -2
local GOOD_GIRL_ECHO_DAMAGE_BONUS = 1.2
local GOOD_GIRL_ECHO_SPEED_BONUS = 0.15
local GOOD_GIRL_ECHO_FRAMES = 5 * 30
local GOOD_GIRL_FEAR_RADIUS = 120
local GOOD_GIRL_FEAR_DURATION = 2 * 30
local GOOD_GIRL_CHARM_CHANCE = 15
local GOOD_GIRL_CHARM_DURATION = 90
local GOOD_GIRL_REWARD_CHANCE = 33
local GOOD_GIRL_HALF_SOUL = (HeartSubType and HeartSubType.HEART_HALF_SOUL) or 8
local GOOD_GIRL_COIN = (CoinSubType and CoinSubType.COIN_PENNY) or 1
Neverbirth.GoodGirl = Neverbirth.GoodGirl or {
    CostumePath = "gfx/characters/costume_good_girl_of_babylon.anm2",
    CardPickRetries = 16,
    MaxReasonableCardSubtype = 10000,
    states = {},
    costumeStates = {},
    costumeId = nil,
}

function GetGoodGirlState(player)
    local key = GetFolkPlayerKey(player)
    local roomKey = GetFolkRoomKey()
    local state = Neverbirth.GoodGirl.states[key]
    if type(state) ~= "table" or state.roomKey ~= roomKey then
        state = {
            roomKey = roomKey,
            broken = false,
            redDamaged = false,
            rewarded = false,
            echoFrames = 0,
        }
        Neverbirth.GoodGirl.states[key] = state
    end
    return state
end

function PlayerHasGoodGirl(player)
    return PlayerHasCollectible(player, Items.GoodGirlOfBabylon)
end

function GoodGirlHasFullRedHearts(player)
    if not player or not player.GetMaxHearts or not player.GetHearts then
        return false
    end

    local maxRed = tonumber(player:GetMaxHearts()) or 0
    local currentRed = tonumber(player:GetHearts()) or 0
    return maxRed > 0 and currentRed >= maxRed
end

function IsGoodGirlPresentable(player, state)
    return PlayerHasGoodGirl(player) and GoodGirlHasFullRedHearts(player) and not (state and state.broken)
end

function GetGoodGirlCostumeId()
    if Neverbirth.GoodGirl.costumeId ~= nil then
        return Neverbirth.GoodGirl.costumeId or nil
    end

    Neverbirth.GoodGirl.costumeId = false
    if Isaac and Isaac.GetCostumeIdByPath then
        local ok, costumeId = pcall(function()
            return Isaac.GetCostumeIdByPath(Neverbirth.GoodGirl.CostumePath)
        end)
        if ok and type(costumeId) == "number" and costumeId > 0 then
            Neverbirth.GoodGirl.costumeId = costumeId
        end
    end

    return Neverbirth.GoodGirl.costumeId or nil
end

function RemoveGoodGirlCostume(player, costumeId)
    if player and costumeId and player.TryRemoveNullCostume then
        pcall(function()
            player:TryRemoveNullCostume(costumeId)
        end)
    end
end

function AddGoodGirlCostume(player, costumeId)
    if player and costumeId and player.AddNullCostume then
        pcall(function()
            player:AddNullCostume(costumeId)
        end)
    end
end

function ApplyGoodGirlCostume(player, active)
    if not player then
        return
    end

    local key = GetFolkPlayerKey(player)
    local visualState = active and "presentable" or "none"
    if Neverbirth.GoodGirl.costumeStates[key] == visualState then
        return
    end

    local costumeId = GetGoodGirlCostumeId()
    if costumeId then
        RemoveGoodGirlCostume(player, costumeId)
        if active then
            AddGoodGirlCostume(player, costumeId)
        end
    end
    Neverbirth.GoodGirl.costumeStates[key] = visualState
end

function GetGoodGirlItemPool()
    local game = Game and Game() or nil
    if game and game.GetItemPool then
        local ok, itemPool = pcall(function()
            return game:GetItemPool()
        end)
        if ok then
            return itemPool
        end
    end
    return nil
end

function GetGoodGirlItemConfig()
    if Isaac and Isaac.GetItemConfig then
        local ok, itemConfig = pcall(function()
            return Isaac.GetItemConfig()
        end)
        if ok then
            return itemConfig
        end
    end
    return nil
end

function GetGoodGirlRewardSeed(player, attempt)
    local seed = tonumber(player and player.InitSeed) or 0
    local room = GetFolkRoom()
    if room and room.GetSpawnSeed then
        local ok, roomSeed = pcall(function()
            return room:GetSpawnSeed()
        end)
        if ok and type(roomSeed) == "number" then
            seed = seed + roomSeed
        end
    end
    return math.abs(math.floor(seed + (attempt or 0) * 101 + 37))
end

function IsGoodGirlKnownCardSubtype(subtype)
    subtype = math.floor(tonumber(subtype) or 0)
    if subtype < 1 or subtype > Neverbirth.GoodGirl.MaxReasonableCardSubtype then
        return false
    end

    local itemConfig = GetGoodGirlItemConfig()
    if itemConfig and itemConfig.GetCard then
        local ok, cardConfig = pcall(function()
            return itemConfig:GetCard(subtype)
        end)
        if not ok or cardConfig == nil then
            return false
        end

        local hasDisplayData = false
        for _, field in ipairs({ "Name", "Description", "GfxFileName", "HudAnim" }) do
            local fieldOk, value = pcall(function()
                return cardConfig[field]
            end)
            if fieldOk and value ~= nil and tostring(value) ~= "" then
                hasDisplayData = true
                break
            end
        end
        if not hasDisplayData then
            return false
        end
    end

    if EID then
        local eidChecked = false
        local descObj = nil
        local eidCalls = {
            function() return EID.getDescriptionObjByID and EID:getDescriptionObjByID(FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300, subtype) end,
            function() return EID.getDescriptionObj and EID:getDescriptionObj(FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300, subtype) end,
        }
        for _, call in ipairs(eidCalls) do
            local ok, result = pcall(call)
            if ok and result ~= nil then
                eidChecked = true
                descObj = result
                break
            elseif ok then
                eidChecked = true
            end
        end
        if eidChecked then
            if type(descObj) ~= "table" then
                return false
            end
            local name = tostring(descObj.Name or descObj.ObjName or "")
            local description = tostring(descObj.Description or "")
            local combined = string.lower(name .. " " .. description)
            if combined == " " then
                return false
            end
            if combined:find("no description available", 1, true) then
                return false
            end
            if combined:find(tostring(FOLK_ENTITY_PICKUP) .. "." .. tostring((PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300) .. ".", 1, true) then
                return false
            end
        end
    end

    return true
end

function AddGoodGirlCardCandidate(candidates, seen, subtype)
    subtype = math.floor(tonumber(subtype) or 0)
    if subtype >= 1 and not seen[subtype] and IsGoodGirlKnownCardSubtype(subtype) then
        seen[subtype] = true
        candidates[#candidates + 1] = subtype
    end
end

function CollectGoodGirlCardCandidates()
    local candidates = {}
    local seen = {}
    local maxVanilla = (Card and type(Card.RUNE_HAGALAZ) == "number" and Card.RUNE_HAGALAZ > 1) and (Card.RUNE_HAGALAZ - 1) or 31
    for subtype = 1, maxVanilla do
        AddGoodGirlCardCandidate(candidates, seen, subtype)
    end
    if type(Card) == "table" then
        for _, subtype in pairs(Card) do
            AddGoodGirlCardCandidate(candidates, seen, subtype)
        end
    end
    table.sort(candidates)
    return candidates
end

function GetGoodGirlRewardCardSubtype(player)
    local itemPool = GetGoodGirlItemPool()
    if itemPool and itemPool.GetCard then
        for attempt = 0, Neverbirth.GoodGirl.CardPickRetries - 1 do
            local seed = GetGoodGirlRewardSeed(player, attempt)
            local rolls = {
                function() return itemPool:GetCard(seed, true, true, false) end,
                function() return itemPool:GetCard(seed, true, false, false) end,
            }
            for _, roll in ipairs(rolls) do
                local ok, subtype = pcall(roll)
                if ok and IsGoodGirlKnownCardSubtype(subtype) then
                    return math.floor(subtype)
                end
            end
        end
    end

    local candidates = CollectGoodGirlCardCandidates()
    if #candidates <= 0 then
        return (Card and Card.CARD_FOOL) or 1
    end

    local seed = GetGoodGirlRewardSeed(player, 0)
    return candidates[(seed % #candidates) + 1]
end

function RefreshGoodGirlCache(player)
    if not player or not player.AddCacheFlags or not CacheFlag then
        return
    end

    local flags = 0
    if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
    if CacheFlag.CACHE_LUCK then flags = flags | CacheFlag.CACHE_LUCK end
    if CacheFlag.CACHE_DAMAGE then flags = flags | CacheFlag.CACHE_DAMAGE end
    if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
    if flags ~= 0 then
        player:AddCacheFlags(flags)
        if player.EvaluateItems then
            player:EvaluateItems()
        end
    end
end

function IsGoodGirlRedHeartDamage(player, amount, flags)
    if (tonumber(amount) or 0) <= 0 then
        return false
    end
    if flags and DamageFlag and DamageFlag.DAMAGE_FAKE and (flags & DamageFlag.DAMAGE_FAKE) ~= 0 then
        return false
    end
    if flags and DamageFlag and DamageFlag.DAMAGE_IV_BAG and (flags & DamageFlag.DAMAGE_IV_BAG) ~= 0 then
        return false
    end
    if flags and DamageFlag and DamageFlag.DAMAGE_RED_HEARTS and (flags & DamageFlag.DAMAGE_RED_HEARTS) ~= 0 then
        return true
    end

    local soulHearts = 0
    if player and player.GetSoulHearts then
        soulHearts = tonumber(player:GetSoulHearts()) or 0
    end
    local redHearts = 0
    if player and player.GetHearts then
        redHearts = tonumber(player:GetHearts()) or 0
    end

    -- MC_ENTITY_TAKE_DMG fires before health changes. Without an explicit red
    -- heart flag, we only treat the hit as red damage when no soul/black layer
    -- is available to absorb it.
    return soulHearts <= 0 and redHearts > 0
end

function FearGoodGirlEnemies(player)
    if not Isaac.GetRoomEntities then
        return
    end

    local origin = player and player.Position or Vector(320, 280)
    local ref = EntityRef(player)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsVulnerableEnemy(entity) and entity.Position and (entity.Position - origin):Length() <= GOOD_GIRL_FEAR_RADIUS and entity.AddFear then
            pcall(function()
                entity:AddFear(ref, GOOD_GIRL_FEAR_DURATION)
            end)
        end
    end
end

function CharmGoodGirlRoomEnemies(player)
    if not Isaac.GetRoomEntities or not IsGoodGirlPresentable(player, GetGoodGirlState(player)) then
        return
    end

    local ref = EntityRef(player)
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if IsVulnerableEnemy(entity) then
            local data = entity.GetData and entity:GetData() or nil
            local key = "NeverbirthGoodGirlCharmChecked" .. tostring(GetFolkPlayerKey(player))
            if not data or data[key] ~= true then
                if data then
                    data[key] = true
                end
                if GetFolkRandomInt(player, Items.GoodGirlOfBabylon, 100) < GOOD_GIRL_CHARM_CHANCE then
                    local charmed = false
                    if entity.AddCharmed then
                        charmed = pcall(function()
                            entity:AddCharmed(ref, GOOD_GIRL_CHARM_DURATION)
                        end)
                    elseif entity.AddConfusion then
                        charmed = pcall(function()
                            entity:AddConfusion(ref, GOOD_GIRL_CHARM_DURATION, false)
                        end)
                    elseif entity.AddEntityFlags and EntityFlag and EntityFlag.FLAG_CHARM then
                        entity:AddEntityFlags(EntityFlag.FLAG_CHARM)
                        charmed = true
                    end
                    if charmed then
                        Neverbirth:SpawnFolkVisualEffect("GoodGirlCharm", entity.Position or player.Position or Vector(320, 280), player)
                    end
                end
            end
        end
    end
end

function SpawnGoodGirlReward(player)
    local position = player and player.Position or Vector(320, 280)
    local room = GetFolkRoom()
    if room and room.FindFreePickupSpawnPosition then
        position = room:FindFreePickupSpawnPosition(position, 40, true, false)
    end

    local reward = GetFolkRandomInt(player, Items.GoodGirlOfBabylon, 3)
    if reward == 0 then
        Isaac.Spawn(FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300, GetGoodGirlRewardCardSubtype(player), position, Vector(0, 0), player)
    elseif reward == 1 then
        Isaac.Spawn(FOLK_ENTITY_PICKUP, FOLK_PICKUP_HEART, GOOD_GIRL_HALF_SOUL, position, Vector(0, 0), player)
    else
        Isaac.Spawn(FOLK_ENTITY_PICKUP, (PickupVariant and PickupVariant.PICKUP_COIN) or 20, GOOD_GIRL_COIN, position, Vector(0, 0), player)
    end
    Neverbirth:SpawnFolkVisualEffect("GoodGirlReward", position, player)
end

function Neverbirth:EvaluateGoodGirlOfBabylon(player, cacheFlag)
    if not PlayerHasGoodGirl(player) then
        return
    end

    local state = GetGoodGirlState(player)
    local presentable = IsGoodGirlPresentable(player, state)

    if cacheFlag == CacheFlag.CACHE_FIREDELAY and presentable then
        player.MaxFireDelay = player.MaxFireDelay - GOOD_GIRL_TEARS_BONUS
    elseif cacheFlag == CacheFlag.CACHE_LUCK then
        if presentable then
            player.Luck = player.Luck + GOOD_GIRL_LUCK_BONUS
        end
        if state.broken then
            player.Luck = player.Luck + GOOD_GIRL_BROKEN_LUCK_PENALTY
        end
    elseif cacheFlag == CacheFlag.CACHE_DAMAGE and (tonumber(state.echoFrames) or 0) > 0 then
        player.Damage = player.Damage + GOOD_GIRL_ECHO_DAMAGE_BONUS
    elseif cacheFlag == CacheFlag.CACHE_SPEED and (tonumber(state.echoFrames) or 0) > 0 then
        player.MoveSpeed = player.MoveSpeed + GOOD_GIRL_ECHO_SPEED_BONUS
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateGoodGirlOfBabylon)

function Neverbirth:EnsureGoodGirlFollowEffect(state, field, key, player)
    if type(state) ~= "table" or not player then
        return nil
    end

    local effect = state[field]
    if not Neverbirth:IsFolkVisualEffectActive(effect) then
        effect = Neverbirth:SpawnFolkVisualEffect(key, player.Position or Vector(320, 280), player)
        state[field] = effect
    else
        Neverbirth:BindFolkVisualEffectOwner(effect, key, player)
        Neverbirth:RefreshFolkVisualEffectTimeout(effect, key)
    end

    return effect
end

function Neverbirth:RemoveGoodGirlFollowEffect(state, field)
    if type(state) ~= "table" then
        return
    end

    local effect = state[field]
    if Neverbirth:IsFolkVisualEffectActive(effect) and effect.Remove then
        effect:Remove()
    end
    state[field] = nil
end

function Neverbirth:HandleGoodGirlOfBabylonDamage(entity, amount, flags)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player or not PlayerHasGoodGirl(player) then
        return nil
    end

    local state = GetGoodGirlState(player)
    if not IsGoodGirlPresentable(player, state) or not IsGoodGirlRedHeartDamage(player, amount, flags) then
        return nil
    end

    state.broken = true
    state.redDamaged = true
    state.echoFrames = GOOD_GIRL_ECHO_FRAMES
    FearGoodGirlEnemies(player)
    ApplyGoodGirlCostume(player, false)
    Neverbirth:RemoveGoodGirlFollowEffect(state, "haloEffect")
    Neverbirth:SpawnFolkVisualEffect("GoodGirlBreak", player.Position or Vector(320, 280), player)
    if player.SetColor then
        player:SetColor(Color(0.65, 0.05, 0.05, 1, 0.15, 0, 0), 45, 1, true, false)
    end
    RefreshGoodGirlCache(player)
    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleGoodGirlOfBabylonDamage, EntityType.ENTITY_PLAYER)

function Neverbirth:RefreshGoodGirlOfBabylonRoom()
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasGoodGirl(player) then
            local key = GetFolkPlayerKey(player)
            local previousState = Neverbirth.GoodGirl.states[key]
            Neverbirth:RemoveGoodGirlFollowEffect(previousState, "haloEffect")
            Neverbirth:RemoveGoodGirlFollowEffect(previousState, "echoEffect")
            Neverbirth.GoodGirl.states[key] = {
                roomKey = GetFolkRoomKey(),
                broken = false,
                redDamaged = false,
                rewarded = false,
                echoFrames = 0,
            }
            ApplyGoodGirlCostume(player, IsGoodGirlPresentable(player, Neverbirth.GoodGirl.states[key]))
            CharmGoodGirlRoomEnemies(player)
            RefreshGoodGirlCache(player)
        end
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.RefreshGoodGirlOfBabylonRoom)
end

function Neverbirth:UpdateGoodGirlOfBabylon()
    local room = GetFolkRoom()
    local isClear = room and room.IsClear and room:IsClear()

    for _, player in ipairs(GetPlayers()) do
        if PlayerHasGoodGirl(player) then
            local state = GetGoodGirlState(player)
            local echoFrames = tonumber(state.echoFrames) or 0
            if echoFrames > 0 then
                state.echoFrames = echoFrames - 1
                if state.echoFrames > 0 then
                    Neverbirth:EnsureGoodGirlFollowEffect(state, "echoEffect", "GoodGirlEcho", player)
                else
                    state.echoFrames = 0
                    Neverbirth:RemoveGoodGirlFollowEffect(state, "echoEffect")
                    RefreshGoodGirlCache(player)
                end
            else
                Neverbirth:RemoveGoodGirlFollowEffect(state, "echoEffect")
            end

            if IsGoodGirlPresentable(player, state) then
                ApplyGoodGirlCostume(player, true)
                Neverbirth:EnsureGoodGirlFollowEffect(state, "haloEffect", "GoodGirlHalo", player)
            else
                ApplyGoodGirlCostume(player, false)
                Neverbirth:RemoveGoodGirlFollowEffect(state, "haloEffect")
            end

            if isClear and not state.rewarded then
                state.rewarded = true
                if IsGoodGirlPresentable(player, state) and not state.redDamaged and GetFolkRandomInt(player, Items.GoodGirlOfBabylon, 100) < GOOD_GIRL_REWARD_CHANCE then
                    SpawnGoodGirlReward(player)
                end
            end
        else
            ApplyGoodGirlCostume(player, false)
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateGoodGirlOfBabylon)

function Neverbirth:ResetFolkHorrorItemState(isContinued)
    if isContinued then
        return
    end
    for _, player in ipairs(GetPlayers()) do
        ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
        ApplyGoodGirlCostume(player, false)
    end
    coinFacedMaskStates = {}
    coinFacedMaskCostumeStates = {}
    blackTaisuiStates = {}
    for _, state in pairs(Neverbirth.GoodGirl.states) do
        Neverbirth:RemoveGoodGirlFollowEffect(state, "haloEffect")
        Neverbirth:RemoveGoodGirlFollowEffect(state, "echoEffect")
    end
    Neverbirth.GoodGirl.states = {}
    Neverbirth.GoodGirl.costumeStates = {}
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetFolkHorrorItemState)
end
end

--------------------------------------------------
-- 绝育证明

do
local STERILIZATION_NORMAL_BASE_DAMAGE = 10
local STERILIZATION_NORMAL_MAX_HP_RATIO = 0.05
local STERILIZATION_BOSS_BASE_DAMAGE = 3
local STERILIZATION_BOSS_MAX_HP_RATIO = 0.01
local STERILIZATION_ENTITY_EFFECT = (EntityType and EntityType.ENTITY_EFFECT) or 1000
local STERILIZATION_POOF_VARIANT = (EffectVariant and EffectVariant.POOF01) or 15
local STERILIZATION_DAMAGE_FLAGS = 0

local function SterilizationEntityType(name, fallback)
    if EntityType and EntityType[name] then
        return EntityType[name]
    end

    return fallback
end

local STERILIZATION_SPAWNER_TYPES = {
    [SterilizationEntityType("ENTITY_MULLIGAN", 16)] = true,
    [SterilizationEntityType("ENTITY_HIVE", 22)] = true,
    [SterilizationEntityType("ENTITY_BIGSPIDER", 94)] = true,
    [SterilizationEntityType("ENTITY_NEST", 205)] = true,
    [SterilizationEntityType("ENTITY_FAT_SACK", 209)] = true,
    [SterilizationEntityType("ENTITY_HALF_SACK", 211)] = true,
    [SterilizationEntityType("ENTITY_PORTAL", 306)] = true,
    [SterilizationEntityType("ENTITY_DUKE", 67)] = true,
    [SterilizationEntityType("ENTITY_GURDY", 36)] = true,
    [SterilizationEntityType("ENTITY_WIDOW", 100)] = true,
    [SterilizationEntityType("ENTITY_MAMA_GURDY", 266)] = true,
    [SterilizationEntityType("ENTITY_MATRIARCH", 413)] = true,
}

local STERILIZATION_ORDINARY_SPAWN_TYPES = {
    [SterilizationEntityType("ENTITY_FLY", 13)] = true,
    [SterilizationEntityType("ENTITY_ATTACKFLY", 18)] = true,
    [SterilizationEntityType("ENTITY_MAGGOT", 21)] = true,
    [SterilizationEntityType("ENTITY_SPIDER", 85)] = true,
    [SterilizationEntityType("ENTITY_FLY_L2", 214)] = true,
    [SterilizationEntityType("ENTITY_SPIDER_L2", 215)] = true,
    [SterilizationEntityType("ENTITY_DIP", 217)] = true,
    [SterilizationEntityType("ENTITY_SWARM", 281)] = true,
    [SterilizationEntityType("ENTITY_SWARM_SPIDER", 884)] = true,
}

local sterilizationKnownEntities = {}
local sterilizationBlockedEntities = {}
local sterilizationTrackedSpawners = {}
local sterilizationRoomInitialized = false

local function GetSterilizationEntityKey(entity)
    if not entity then
        return nil
    end

    if entity.InitSeed ~= nil then
        return tostring(entity.InitSeed)
    end

    return tostring(entity)
end

local function PlayerHasSterilizationCertificate(player)
    return player and player.GetCollectibleNum and player:GetCollectibleNum(Items.SterilizationCertificate) > 0
end

local function AnyPlayerHasSterilizationCertificate()
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasSterilizationCertificate(player) then
            return true
        end
    end

    return false
end

local function IsSterilizationEnemy(entity)
    if not entity or entity.Type == ((EntityType and EntityType.ENTITY_PICKUP) or 5) then
        return false
    end

    if entity.IsVulnerableEnemy then
        local ok, isEnemy = pcall(function()
            return entity:IsVulnerableEnemy()
        end)
        if ok then
            return isEnemy == true
        end
    end

    return entity.ToNPC and entity:ToNPC() ~= nil
end

local function IsSterilizationBoss(entity)
    if not entity or not entity.IsBoss then
        return false
    end

    local ok, isBoss = pcall(function()
        return entity:IsBoss()
    end)
    return ok and isBoss == true
end

local function HasSterilizationFriendlyFlag(entity)
    if not entity or not entity.HasEntityFlags or not EntityFlag or not EntityFlag.FLAG_FRIENDLY then
        return false
    end

    local ok, hasFlag = pcall(function()
        return entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
    end)
    return ok and hasFlag == true
end

local function IsSterilizationSpawner(entity)
    return IsSterilizationEnemy(entity) and STERILIZATION_SPAWNER_TYPES[entity.Type] == true
end

local function IsSterilizationOrdinarySpawn(entity)
    if not IsSterilizationEnemy(entity) then
        return false
    end

    if HasSterilizationFriendlyFlag(entity) then
        return false
    end

    if IsSterilizationBoss(entity) then
        return false
    end

    return STERILIZATION_ORDINARY_SPAWN_TYPES[entity.Type] == true
end

local function ExtractSterilizationEntity(candidate)
    if candidate and candidate.Entity then
        return candidate.Entity
    end

    return candidate
end

local function IsSameSterilizationEntity(left, right)
    left = ExtractSterilizationEntity(left)
    right = ExtractSterilizationEntity(right)

    if left == nil or right == nil then
        return false
    end

    if left == right then
        return true
    end

    local leftKey = GetSterilizationEntityKey(left)
    local rightKey = GetSterilizationEntityKey(right)
    return leftKey ~= nil and rightKey ~= nil and leftKey == rightKey
end

local function IsSterilizationSpawnFromSource(spawn, source)
    if IsSameSterilizationEntity(spawn.SpawnerEntity, source) then
        return true
    end

    if IsSameSterilizationEntity(spawn.Parent, source) then
        return true
    end

    return false
end

local function FindSterilizationSpawnSource(spawn)
    for _, source in pairs(sterilizationTrackedSpawners) do
        if IsSterilizationSpawnFromSource(spawn, source) then
            return source
        end
    end

    return nil
end

local function GetSterilizationMaxHitPoints(entity)
    return tonumber(entity and (entity.MaxHitPoints or entity.HitPoints)) or 0
end

local function GetSterilizationBacklashDamage(source)
    local maxHitPoints = GetSterilizationMaxHitPoints(source)
    if IsSterilizationBoss(source) then
        return STERILIZATION_BOSS_BASE_DAMAGE + maxHitPoints * STERILIZATION_BOSS_MAX_HP_RATIO
    end

    return STERILIZATION_NORMAL_BASE_DAMAGE + maxHitPoints * STERILIZATION_NORMAL_MAX_HP_RATIO
end

local function FlashSterilizationSource(source)
    if not source or not source.SetColor or not Color then
        return
    end

    pcall(function()
        source:SetColor(Color(1, 0.25, 0.25, 1, 0.25, 0, 0), 8, 1, true, false)
    end)
end

local function SpawnSterilizationPoof(spawn, source)
    local position = spawn and spawn.Position or (source and source.Position) or (Vector and Vector(0, 0))
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }

    if Isaac.Spawn then
        Isaac.Spawn(STERILIZATION_ENTITY_EFFECT, STERILIZATION_POOF_VARIANT, 0, position, velocity, source)
        return
    end

    if Game then
        local ok, game = pcall(Game)
        if ok and game and game.Spawn then
            game:Spawn(STERILIZATION_ENTITY_EFFECT, STERILIZATION_POOF_VARIANT, position, velocity, source, 0, 0)
        end
    end
end

local function BlockSterilizationSpawn(spawn, source)
    local spawnKey = GetSterilizationEntityKey(spawn)
    if not spawnKey or sterilizationBlockedEntities[spawnKey] then
        return false
    end

    sterilizationBlockedEntities[spawnKey] = true
    SpawnSterilizationPoof(spawn, source)

    if spawn and spawn.Remove then
        pcall(function()
            spawn:Remove()
        end)
    end

    if source and source.TakeDamage then
        local damageSource = EntityRef and EntityRef(spawn) or nil
        pcall(function()
            source:TakeDamage(GetSterilizationBacklashDamage(source), STERILIZATION_DAMAGE_FLAGS, damageSource, 0)
        end)
    end

    FlashSterilizationSource(source)
    return true
end

local function GetSterilizationRoomEntities()
    if not Isaac.GetRoomEntities then
        return {}
    end

    return Isaac.GetRoomEntities()
end

local function RefreshSterilizationTrackedSpawners(entities)
    sterilizationTrackedSpawners = {}
    for _, entity in ipairs(entities) do
        if IsSterilizationSpawner(entity) then
            local entityKey = GetSterilizationEntityKey(entity)
            if entityKey then
                sterilizationTrackedSpawners[entityKey] = entity
            end
        end
    end
end

local function RememberSterilizationEntity(entity)
    local entityKey = GetSterilizationEntityKey(entity)
    if entityKey then
        sterilizationKnownEntities[entityKey] = true
    end
end

local function RememberSterilizationRoomEntities(entities)
    for _, entity in ipairs(entities or GetSterilizationRoomEntities()) do
        RememberSterilizationEntity(entity)
    end
end

function Neverbirth:TrackSterilizationNewRoom()
    sterilizationKnownEntities = {}
    sterilizationBlockedEntities = {}
    sterilizationTrackedSpawners = {}
    sterilizationRoomInitialized = false

    if not AnyPlayerHasSterilizationCertificate() then
        return
    end

    local entities = GetSterilizationRoomEntities()
    RefreshSterilizationTrackedSpawners(entities)
    RememberSterilizationRoomEntities(entities)
    sterilizationRoomInitialized = true
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.TrackSterilizationNewRoom)
end

function Neverbirth:UpdateSterilizationCertificate()
    local hasSterilization = AnyPlayerHasSterilizationCertificate()
    if not hasSterilization then
        if sterilizationRoomInitialized then
            sterilizationKnownEntities = {}
            sterilizationBlockedEntities = {}
            sterilizationTrackedSpawners = {}
            sterilizationRoomInitialized = false
        end
        return
    end

    local entities = GetSterilizationRoomEntities()
    RefreshSterilizationTrackedSpawners(entities)

    if not sterilizationRoomInitialized then
        sterilizationRoomInitialized = true
        RememberSterilizationRoomEntities(entities)
        return
    end

    for _, entity in ipairs(entities) do
        local entityKey = GetSterilizationEntityKey(entity)
        if entityKey and not sterilizationKnownEntities[entityKey] then
            if IsSterilizationOrdinarySpawn(entity) then
                local source = FindSterilizationSpawnSource(entity)
                if source then
                    BlockSterilizationSpawn(entity, source)
                end
            end
        end
    end

    RememberSterilizationRoomEntities(entities)
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateSterilizationCertificate)

function Neverbirth:ResetSterilizationCertificateState(isContinued)
    if isContinued then
        return
    end

    sterilizationKnownEntities = {}
    sterilizationBlockedEntities = {}
    sterilizationTrackedSpawners = {}
    sterilizationRoomInitialized = false
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetSterilizationCertificateState)
end
end

--------------------------------------------------
-- 空摇篮

do
local EMPTY_CRADLE_DAMAGE_RED = "red"
local EMPTY_CRADLE_DAMAGE_SOUL = "soul"
local EMPTY_CRADLE_DAMAGE_BLACK = "black"
local EMPTY_CRADLE_HEART_VARIANT = (PickupVariant and PickupVariant.PICKUP_HEART) or 10
local EMPTY_CRADLE_COIN_VARIANT = (PickupVariant and PickupVariant.PICKUP_COIN) or 20
local EMPTY_CRADLE_KEY_VARIANT = (PickupVariant and PickupVariant.PICKUP_KEY) or 30
local EMPTY_CRADLE_BOMB_VARIANT = (PickupVariant and PickupVariant.PICKUP_BOMB) or 40
local EMPTY_CRADLE_HALF_HEART = (HeartSubType and HeartSubType.HEART_HALF) or 2
local EMPTY_CRADLE_FULL_HEART = (HeartSubType and HeartSubType.HEART_FULL) or 1
local EMPTY_CRADLE_HALF_SOUL_HEART = (HeartSubType and HeartSubType.HEART_HALF_SOUL) or 8
local EMPTY_CRADLE_SOUL_HEART = (HeartSubType and HeartSubType.HEART_SOUL) or 3
local EMPTY_CRADLE_BLACK_HEART = (HeartSubType and HeartSubType.HEART_BLACK) or 6
local EMPTY_CRADLE_PENNY = (CoinSubType and CoinSubType.COIN_PENNY) or 1
local EMPTY_CRADLE_KEY = (KeySubType and KeySubType.KEY_NORMAL) or 1
local EMPTY_CRADLE_BOMB = (BombSubType and BombSubType.BOMB_NORMAL) or 1
local EMPTY_CRADLE_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local EMPTY_CRADLE_ENTITY_SLOT = (EntityType and EntityType.ENTITY_SLOT) or 6
local EMPTY_CRADLE_ROOM_SACRIFICE = (RoomType and RoomType.ROOM_SACRIFICE) or 13
local EMPTY_CRADLE_DAMAGE_FLAGS = {
    DamageFlag and DamageFlag.DAMAGE_IV_BAG,
    DamageFlag and DamageFlag.DAMAGE_FAKE,
    DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
    DamageFlag and DamageFlag.DAMAGE_DEVIL,
}

local emptyCradleStates = {}

local function GetEmptyCradlePlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function PlayerHasEmptyCradle(player)
    return player and player.GetCollectibleNum and player:GetCollectibleNum(Items.EmptyCradle) > 0
end

local function GetEmptyCradleGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    if ok then
        return game
    end

    return nil
end

local function GetEmptyCradleLevel()
    local game = GetEmptyCradleGame()
    return game and game.GetLevel and game:GetLevel() or nil
end

local function GetEmptyCradleRoom()
    local game = GetEmptyCradleGame()
    return game and game.GetRoom and game:GetRoom() or nil
end

local function GetEmptyCradleFloorKey()
    local level = GetEmptyCradleLevel()
    local runSeed = GetCurrentRunSeed and GetCurrentRunSeed() or "unknown"
    if not level then
        return runSeed .. ":unknown"
    end

    local stage = "?"
    if level.GetStage then
        local ok, value = pcall(function()
            return level:GetStage()
        end)
        if ok and value ~= nil then
            stage = tostring(value)
        end
    end

    local stageType = "?"
    if level.GetStageType then
        local ok, value = pcall(function()
            return level:GetStageType()
        end)
        if ok and value ~= nil then
            stageType = tostring(value)
        end
    end

    return runSeed .. ":" .. stage .. ":" .. stageType
end

local function GetEmptyCradleRoomKey()
    local level = GetEmptyCradleLevel()
    if level and level.GetCurrentRoomIndex then
        local ok, roomIndex = pcall(function()
            return level:GetCurrentRoomIndex()
        end)
        if ok and roomIndex ~= nil then
            return "idx:" .. tostring(roomIndex)
        end
    end

    local room = GetEmptyCradleRoom()
    if room and room.GetSpawnSeed then
        local ok, spawnSeed = pcall(function()
            return room:GetSpawnSeed()
        end)
        if ok and spawnSeed ~= nil then
            return "seed:" .. tostring(spawnSeed)
        end
    end

    return "unknown"
end

local function IsEmptyCradleRoomClear()
    local room = GetEmptyCradleRoom()
    if room and room.IsClear then
        local ok, isClear = pcall(function()
            return room:IsClear()
        end)
        if ok then
            return isClear == true
        end
    end

    return true
end

local function GetEmptyCradleState(player)
    local playerKey = GetEmptyCradlePlayerKey(player)
    if playerKey == "" then
        return nil
    end

    local floorKey = GetEmptyCradleFloorKey()
    local state = emptyCradleStates[playerKey]
    if type(state) ~= "table" or state.floorKey ~= floorKey then
        state = {
            floorKey = floorKey,
            usedThisFloor = false,
            pending = false,
            pendingRoomKey = nil,
            damageType = nil,
            upgraded = true,
            damageBonus = 0,
        }
        emptyCradleStates[playerKey] = state
    end

    return state
end

local function RefreshEmptyCradleDamageCache(player)
    if not player then
        return
    end

    if player.AddCacheFlags and CacheFlag and CacheFlag.CACHE_DAMAGE then
        pcall(function()
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
        end)
    end

    if player.EvaluateItems then
        pcall(function()
            player:EvaluateItems()
        end)
    end
end

local function HasEmptyCradleDamageFlag(flags, flag)
    return flag ~= nil and flag ~= 0 and ((tonumber(flags) or 0) & flag) ~= 0
end

local function GetEmptyCradleSourceEntity(source)
    if source and source.Entity then
        return source.Entity
    end

    return source
end

local function IsEmptyCradleCostDamage(flags, source)
    if bloodSkullGuBacklashDepth > 0 then
        return true
    end

    for _, flag in pairs(EMPTY_CRADLE_DAMAGE_FLAGS) do
        if HasEmptyCradleDamageFlag(flags, flag) then
            return true
        end
    end

    local sourceEntity = GetEmptyCradleSourceEntity(source)
    if sourceEntity and sourceEntity.Type == EMPTY_CRADLE_ENTITY_SLOT then
        return true
    end

    local room = GetEmptyCradleRoom()
    if room and room.GetType then
        local ok, roomType = pcall(function()
            return room:GetType()
        end)
        if ok and roomType == EMPTY_CRADLE_ROOM_SACRIFICE then
            return true
        end
    end

    -- Isaac does not expose every paid-damage source uniformly; flags, slot
    -- entities, and sacrifice rooms cover the stable cases without blocking
    -- normal combat damage in curse/devil themed rooms.
    return false
end

local function InferEmptyCradleDamageType(player, flags)
    if HasEmptyCradleDamageFlag(flags, DamageFlag and DamageFlag.DAMAGE_RED_HEARTS) then
        return EMPTY_CRADLE_DAMAGE_RED
    end

    local soulHearts = 0
    if player and player.GetSoulHearts then
        local ok, value = pcall(function()
            return player:GetSoulHearts()
        end)
        soulHearts = ok and (tonumber(value) or 0) or 0
    end

    if soulHearts <= 0 then
        return EMPTY_CRADLE_DAMAGE_RED
    end

    if player and player.GetBlackHearts then
        local ok, result = pcall(function()
            return player:GetBlackHearts()
        end)
        if ok and (tonumber(result) or 0) > 0 then
            return EMPTY_CRADLE_DAMAGE_BLACK
        end
    end

    return EMPTY_CRADLE_DAMAGE_SOUL
end

local function GetEmptyCradleRandomInt(player, max)
    max = tonumber(max) or 1
    if max <= 1 then
        return 0
    end

    if player and player.GetCollectibleRNG then
        local ok, rng = pcall(function()
            return player:GetCollectibleRNG(Items.EmptyCradle)
        end)
        if ok and rng and rng.RandomInt then
            local rollOk, value = pcall(function()
                return rng:RandomInt(max)
            end)
            if rollOk and value ~= nil then
                return math.max(0, math.min(max - 1, tonumber(value) or 0))
            end
        end
    end

    return math.random(max) - 1
end

local function SpawnEmptyCradlePickup(player, variant, subtype, offsetIndex)
    local position = player and player.Position or (GetEmptyCradleRoom() and GetEmptyCradleRoom():GetCenterPos()) or Vector(320, 280)
    local offset = ((tonumber(offsetIndex) or 1) - 1) * 24
    position = position + Vector(offset, 0)

    local room = GetEmptyCradleRoom()
    if room and room.FindFreePickupSpawnPosition then
        position = room:FindFreePickupSpawnPosition(position, 40, true, false)
    end

    if Isaac.Spawn then
        Isaac.Spawn(EMPTY_CRADLE_ENTITY_PICKUP, variant, subtype, position, Vector(0, 0), player)
    elseif Game then
        local ok, game = pcall(Game)
        if ok and game and game.Spawn then
            game:Spawn(EMPTY_CRADLE_ENTITY_PICKUP, variant, position, Vector(0, 0), player, subtype, 0)
        end
    end
end

local function GrantEmptyCradleRedReward(player, upgraded)
    local subtype
    if upgraded then
        local reward = GetEmptyCradleRandomInt(player, 3)
        subtype = ({ EMPTY_CRADLE_FULL_HEART, EMPTY_CRADLE_SOUL_HEART, EMPTY_CRADLE_BLACK_HEART })[reward + 1]
    else
        local reward = GetEmptyCradleRandomInt(player, 2)
        subtype = ({ EMPTY_CRADLE_HALF_HEART, EMPTY_CRADLE_HALF_SOUL_HEART })[reward + 1]
    end

    SpawnEmptyCradlePickup(player, EMPTY_CRADLE_HEART_VARIANT, subtype, 1)
end

local function GrantEmptyCradleResourceReward(player, offsetIndex)
    local reward = GetEmptyCradleRandomInt(player, 3)
    if reward == 0 then
        for index = 1, 3 do
            SpawnEmptyCradlePickup(player, EMPTY_CRADLE_COIN_VARIANT, EMPTY_CRADLE_PENNY, (offsetIndex or 1) + index - 1)
        end
    elseif reward == 1 then
        SpawnEmptyCradlePickup(player, EMPTY_CRADLE_KEY_VARIANT, EMPTY_CRADLE_KEY, offsetIndex or 1)
    else
        SpawnEmptyCradlePickup(player, EMPTY_CRADLE_BOMB_VARIANT, EMPTY_CRADLE_BOMB, offsetIndex or 1)
    end
end

local function GrantEmptyCradleSoulReward(player, upgraded)
    GrantEmptyCradleResourceReward(player, 1)
    if upgraded then
        GrantEmptyCradleResourceReward(player, 4)
    end
end

local function GrantEmptyCradleReward(player, state)
    if not player or type(state) ~= "table" then
        return
    end

    if state.damageType == EMPTY_CRADLE_DAMAGE_RED then
        GrantEmptyCradleRedReward(player, state.upgraded)
    elseif state.damageType == EMPTY_CRADLE_DAMAGE_SOUL then
        GrantEmptyCradleSoulReward(player, state.upgraded)
    elseif state.damageType == EMPTY_CRADLE_DAMAGE_BLACK then
        state.damageBonus = state.upgraded and 1.0 or 0.5
        RefreshEmptyCradleDamageCache(player)
    end
end

local function TrySettleEmptyCradleReward(player)
    local state = GetEmptyCradleState(player)
    if not state or not state.pending or state.pendingRoomKey ~= GetEmptyCradleRoomKey() then
        return
    end

    if not IsEmptyCradleRoomClear() then
        return
    end

    state.pending = false
    GrantEmptyCradleReward(player, state)
    state.pendingRoomKey = nil
    state.damageType = nil
end

function Neverbirth:HandleEmptyCradleDamage(entity, amount, flags, source)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    local damageAmount = tonumber(amount) or 0
    if not player or damageAmount <= 0 or not PlayerHasEmptyCradle(player) or IsEmptyCradleCostDamage(flags, source) then
        return nil
    end

    local state = GetEmptyCradleState(player)
    if not state then
        return nil
    end

    if state.pending then
        if state.pendingRoomKey == GetEmptyCradleRoomKey() then
            state.upgraded = false
        end
        return nil
    end

    if state.usedThisFloor then
        return nil
    end

    state.usedThisFloor = true
    state.pending = true
    state.pendingRoomKey = GetEmptyCradleRoomKey()
    state.damageType = InferEmptyCradleDamageType(player, flags)
    state.upgraded = true
    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleEmptyCradleDamage, EntityType.ENTITY_PLAYER)

function Neverbirth:UpdateEmptyCradleRewards()
    for _, player in ipairs(GetPlayers()) do
        TrySettleEmptyCradleReward(player)
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateEmptyCradleRewards)

function Neverbirth:EvaluateEmptyCradle(player, cacheFlag)
    if not CacheFlag or cacheFlag ~= CacheFlag.CACHE_DAMAGE then
        return
    end

    local state = GetEmptyCradleState(player)
    local bonus = tonumber(state and state.damageBonus) or 0
    if bonus > 0 then
        player.Damage = player.Damage + bonus
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateEmptyCradle)

function Neverbirth:ResetEmptyCradleOnNewLevel()
    for _, player in ipairs(GetPlayers()) do
        local playerKey = GetEmptyCradlePlayerKey(player)
        local oldState = emptyCradleStates[playerKey]
        local hadDamageBonus = oldState and (tonumber(oldState.damageBonus) or 0) > 0
        emptyCradleStates[playerKey] = {
            floorKey = GetEmptyCradleFloorKey(),
            usedThisFloor = false,
            pending = false,
            pendingRoomKey = nil,
            damageType = nil,
            upgraded = true,
            damageBonus = 0,
        }
        if hadDamageBonus then
            RefreshEmptyCradleDamageCache(player)
        end
    end
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.ResetEmptyCradleOnNewLevel)
end

function Neverbirth:ResetEmptyCradleState(isContinued)
    if isContinued then
        return
    end

    emptyCradleStates = {}
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetEmptyCradleState)
end
end

--------------------------------------------------
-- 天使盒

local ANGELBOX_MAX_CHARGE = 4
local ANGELBOX_ANGEL_CHANCE = 0.5
local ANGELBOX_LUCK_BONUS = 3
local ANGELBOX_EXTRA_SOUL_HEART_CHANCE = 60
local ANGELBOX_REWARD_QUALITY = 4
local ANGELBOX_ANGEL_POOL = (ItemPoolType and ItemPoolType.POOL_ANGEL) or 4
local ANGELBOX_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local ANGELBOX_HEART_VARIANT = (PickupVariant and PickupVariant.PICKUP_HEART) or 10
local ANGELBOX_COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local ANGELBOX_SOUL_HEART_SUBTYPE = (HeartSubType and HeartSubType.HEART_SOUL) or 3
local ANGELBOX_ROOM_ANGEL = (RoomType and RoomType.ROOM_ANGEL) or 15
local ANGELBOX_NULL_ITEM = (CollectibleType and CollectibleType.COLLECTIBLE_NULL) or 0
local ANGELBOX_REWARD_ATTEMPTS = 120
local ANGELBOX_REWARD_SEED_STEP = 7919
local ANGELBOX_FALLBACK_REWARDS = {
    331, -- Godhead
    643, -- Revelation
    415, -- Crown of Light
    691, -- Sacred Orb
    313, -- Holy Mantle
    180, -- The Wafer
    182, -- Sacred Heart
}

local function BuildAngelboxActiveSlots()
    if not ActiveSlot then
        return { 0, 1, 2, 3 }
    end

    local slots = {}
    if ActiveSlot.SLOT_PRIMARY ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_PRIMARY
    end
    if ActiveSlot.SLOT_SECONDARY ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_SECONDARY
    end
    if ActiveSlot.SLOT_POCKET ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_POCKET
    end
    if ActiveSlot.SLOT_POCKET2 ~= nil then
        slots[#slots + 1] = ActiveSlot.SLOT_POCKET2
    end

    return slots
end

local ANGELBOX_ACTIVE_SLOTS = BuildAngelboxActiveSlots()

local function GetAngelboxGame()
    if not Game then
        return nil
    end

    local ok, game = pcall(Game)
    if ok then
        return game
    end

    return nil
end

local function GetAngelboxLevel()
    local game = GetAngelboxGame()
    if game and game.GetLevel then
        return game:GetLevel()
    end

    return nil
end

local function GetAngelboxRoom()
    local game = GetAngelboxGame()
    if game and game.GetRoom then
        return game:GetRoom()
    end

    return nil
end

local function GetAngelboxFloorKey()
    local level = GetAngelboxLevel()
    if not level then
        return GetCurrentRunSeed() .. ":unknown"
    end

    local stage = level.GetStage and level:GetStage() or "unknown"
    local stageType = level.GetStageType and level:GetStageType() or "unknown"
    return GetCurrentRunSeed() .. ":" .. tostring(stage) .. ":" .. tostring(stageType)
end

local function GetAngelboxPlayerRecord(player)
    local data = GetAngelboxData()
    local key = tostring(player and player.InitSeed or "")
    local runSeed = GetCurrentRunSeed()
    local record = data.players[key]

    if type(record) ~= "table" or record.runSeed ~= runSeed then
        record = {
            runSeed = runSeed,
            firstUseDone = false,
        }
        data.players[key] = record
    end

    return record, key
end

local function IsAngelboxFirstUseDone(player)
    local record = GetAngelboxPlayerRecord(player)
    return record.firstUseDone == true
end

local function FindAngelboxSlot(player, preferredSlot)
    if not player or not player.GetActiveItem then
        return nil
    end

    if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == Items.Angelbox then
        return preferredSlot
    end

    for _, slot in ipairs(ANGELBOX_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.Angelbox then
            return slot
        end
    end

    return nil
end

local function PlayerHasAngelbox(player)
    if not player then
        return false
    end

    if FindAngelboxSlot(player) ~= nil then
        return true
    end

    return player.GetCollectibleNum and player:GetCollectibleNum(Items.Angelbox) > 0
end

local function AnyPlayerHasAngelbox()
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasAngelbox(player) then
            return true
        end
    end

    return false
end

function Neverbirth:EvaluateAngelboxLuck(player, cacheFlag)
    if not CacheFlag or cacheFlag ~= CacheFlag.CACHE_LUCK then
        return
    end

    if PlayerHasAngelbox(player) then
        player.Luck = player.Luck + ANGELBOX_LUCK_BONUS
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateAngelboxLuck)

local function GetAngelboxCharge(player, slot)
    if player and player.GetActiveCharge then
        return player:GetActiveCharge(slot) or 0
    end

    return 0
end

local function SetAngelboxCharge(player, slot, charge)
    if not player then
        return
    end

    local clampedCharge = math.max(0, math.min(charge or 0, ANGELBOX_MAX_CHARGE))
    if player.SetActiveCharge then
        player:SetActiveCharge(clampedCharge, slot)
    elseif clampedCharge <= 0 and player.DischargeActiveItem then
        player:DischargeActiveItem(slot)
    elseif clampedCharge >= ANGELBOX_MAX_CHARGE and player.FullCharge then
        player:FullCharge(slot)
    end
end

local function AddAngelboxCharge(player, slot, amount)
    local currentCharge = GetAngelboxCharge(player, slot)
    SetAngelboxCharge(player, slot, currentCharge + (amount or 0))
end

local function GetAngelboxSoulHeartRoom(player)
    if not player then
        return 0
    end

    local heartLimit = 24
    if player.GetHeartLimit then
        heartLimit = player:GetHeartLimit()
    end

    local effectiveMaxHearts = 0
    if player.GetEffectiveMaxHearts then
        effectiveMaxHearts = player:GetEffectiveMaxHearts()
    elseif player.GetMaxHearts then
        effectiveMaxHearts = player:GetMaxHearts()
        if player.GetBoneHearts then
            effectiveMaxHearts = effectiveMaxHearts + player:GetBoneHearts() * 2
        end
    end

    local soulHearts = player.GetSoulHearts and player:GetSoulHearts() or 0
    return math.max(heartLimit - effectiveMaxHearts - soulHearts, 0)
end

local function GetAngelboxSoulHeartValue(pickup)
    if not pickup then
        return nil
    end

    local subtype = pickup.SubType
    local soulHeartSubtype = HeartSubType and HeartSubType.HEART_SOUL or 3
    local halfSoulHeartSubtype = HeartSubType and HeartSubType.HEART_HALF_SOUL or 8

    if subtype == soulHeartSubtype then
        return 2
    elseif subtype == halfSoulHeartSubtype then
        return 1
    end

    return nil
end

local function GetAngelboxPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function GetAngelboxPendingRewardTable()
    local data = GetAngelboxData()
    local floorKey = GetAngelboxFloorKey()
    local pending = data.pendingRewards[floorKey]

    if type(pending) == "table" then
        return pending
    end

    local legacyCount = tonumber(pending) or 0
    pending = {}
    for index = 1, legacyCount do
        pending["legacy" .. tostring(index)] = true
    end
    data.pendingRewards[floorKey] = pending
    return pending
end

local function CountAngelboxPendingRewards()
    local count = 0
    for _, pending in pairs(GetAngelboxPendingRewardTable()) do
        if pending then
            count = count + 1
        end
    end

    return count
end

local function HasAngelboxPendingReward()
    return CountAngelboxPendingRewards() > 0
end

local function IsAngelboxCurrentRoomAngel()
    local room = GetAngelboxRoom()
    return room and room.GetType and room:GetType() == ANGELBOX_ROOM_ANGEL
end

local function IsAngelboxRoomEnteredThisFloor()
    return GetAngelboxData().enteredAngelFloors[GetAngelboxFloorKey()] == true or IsAngelboxCurrentRoomAngel()
end

local function MarkAngelboxRoomEnteredThisFloor()
    local data = GetAngelboxData()
    local floorKey = GetAngelboxFloorKey()
    if data.enteredAngelFloors[floorKey] then
        return false
    end

    data.enteredAngelFloors[floorKey] = true
    return true
end

local function MarkAngelboxRewardPending(player)
    if IsAngelboxRoomEnteredThisFloor() then
        return false
    end

    local pending = GetAngelboxPendingRewardTable()
    pending[GetAngelboxPlayerKey(player)] = true
    return true
end

local function ClearAngelboxPendingRewards()
    GetAngelboxData().pendingRewards[GetAngelboxFloorKey()] = nil
end

local function GetAngelboxAppliedChance(data, floorKey)
    local applied = data.appliedChanceFloors[floorKey]
    if applied == true then
        return ANGELBOX_ANGEL_CHANCE
    elseif type(applied) == "number" then
        return applied
    end

    return 0
end

local function SetAngelboxChanceTarget(target)
    local level = GetAngelboxLevel()
    if not level or not level.AddAngelRoomChance then
        return false
    end

    local data = GetAngelboxData()
    local floorKey = GetAngelboxFloorKey()
    local applied = GetAngelboxAppliedChance(data, floorKey)
    local delta = target - applied

    if math.abs(delta) <= 0.0001 then
        return false
    end

    level:AddAngelRoomChance(delta)

    if target <= 0 then
        data.appliedChanceFloors[floorKey] = nil
    else
        data.appliedChanceFloors[floorKey] = target
    end

    return true
end

local function GetAngelboxChanceTarget()
    local data = GetAngelboxData()
    local floorKey = GetAngelboxFloorKey()

    if data.forcedAngelFloors[floorKey] then
        return 1
    end

    if AnyPlayerHasAngelbox() then
        return ANGELBOX_ANGEL_CHANCE
    end

    return 0
end

local function IsCollectibleQuality(itemId, quality)
    if not itemId or itemId <= 0 or not Isaac.GetItemConfig then
        return false
    end

    local itemConfig = Isaac.GetItemConfig()
    if not itemConfig or not itemConfig.GetCollectible then
        return false
    end

    local ok, collectible = pcall(function()
        return itemConfig:GetCollectible(itemId)
    end)

    return ok and collectible and collectible.Quality == quality
end

local function IsQualityFourCollectible(itemId)
    return IsCollectibleQuality(itemId, ANGELBOX_REWARD_QUALITY)
end

local function IsAngelboxRewardAlreadySelected(selectedItems, itemId)
    return selectedItems and selectedItems[itemId] == true
end

local function GetAngelboxRewardSeed(baseSeed, rewardIndex, attempt)
    return (tonumber(baseSeed) or 0) + (tonumber(rewardIndex) or 1) * 1000003 + attempt * ANGELBOX_REWARD_SEED_STEP
end

local function SelectAngelboxFallbackReward(baseSeed, rewardIndex, selectedItems)
    local listSize = #ANGELBOX_FALLBACK_REWARDS
    if listSize <= 0 then
        return 182
    end

    local startIndex = ((tonumber(baseSeed) or 0) + (tonumber(rewardIndex) or 1) - 1) % listSize + 1
    local duplicateCandidate = nil

    for offset = 0, listSize - 1 do
        local itemId = ANGELBOX_FALLBACK_REWARDS[((startIndex + offset - 1) % listSize) + 1]
        if IsQualityFourCollectible(itemId) then
            if not IsAngelboxRewardAlreadySelected(selectedItems, itemId) then
                return itemId
            end

            duplicateCandidate = duplicateCandidate or itemId
        end
    end

    return duplicateCandidate or ANGELBOX_FALLBACK_REWARDS[startIndex] or 182
end

local function SelectAngelboxReward(rewardIndex, selectedItems)
    local game = GetAngelboxGame()
    local itemPool = game and game.GetItemPool and game:GetItemPool()
    local room = GetAngelboxRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0

    if not itemPool or not itemPool.GetCollectible then
        return SelectAngelboxFallbackReward(seed, rewardIndex, selectedItems)
    end

    local duplicateCandidate = nil

    for attempt = 1, ANGELBOX_REWARD_ATTEMPTS do
        local itemId = itemPool:GetCollectible(ANGELBOX_ANGEL_POOL, false, GetAngelboxRewardSeed(seed, rewardIndex, attempt), ANGELBOX_NULL_ITEM)
        if IsQualityFourCollectible(itemId) then
            if not IsAngelboxRewardAlreadySelected(selectedItems, itemId) then
                return itemId
            end

            duplicateCandidate = duplicateCandidate or itemId
        end
    end

    return duplicateCandidate or SelectAngelboxFallbackReward(seed, rewardIndex, selectedItems)
end

local function TrySpawnAngelboxReward()
    if not HasAngelboxPendingReward() then
        return false
    end

    local game = GetAngelboxGame()
    local room = GetAngelboxRoom()
    if not game or not game.Spawn or not room or not room.GetType or room:GetType() ~= ANGELBOX_ROOM_ANGEL then
        return false
    end

    local rewardCount = CountAngelboxPendingRewards()
    local center = room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
    local seed = room.GetSpawnSeed and room:GetSpawnSeed() or 0
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    local selectedItems = {}

    for index = 1, rewardCount do
        local position = center
        if Vector then
            position = center + Vector((index - (rewardCount + 1) / 2) * 40, 0)
        end

        if room.FindFreePickupSpawnPosition then
            position = room:FindFreePickupSpawnPosition(position, 40, true, false)
        end

        local itemId = SelectAngelboxReward(index, selectedItems)
        selectedItems[itemId] = true
        game:Spawn(ANGELBOX_ENTITY_PICKUP, ANGELBOX_COLLECTIBLE_VARIANT, position, velocity, nil, itemId, seed + index)
    end

    ClearAngelboxPendingRewards()
    SaveMusicboxData()
    return true
end

local function ForceAngelboxAngelRoom()
    local level = GetAngelboxLevel()
    if not level then
        return
    end

    local data = GetAngelboxData()
    local floorKey = GetAngelboxFloorKey()
    if not data.forcedAngelFloors[floorKey] then
        data.forcedAngelFloors[floorKey] = true
    end
    SetAngelboxChanceTarget(1)

    if level.InitializeDevilAngelRoom then
        level:InitializeDevilAngelRoom(true, false)
    end
end

function Neverbirth:UseAngelbox(_, _, player, _, activeSlot)
    if not player then
        return false
    end

    local slot = FindAngelboxSlot(player, activeSlot) or activeSlot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    if GetAngelboxCharge(player, slot) < ANGELBOX_MAX_CHARGE then
        return false
    end

    local record = GetAngelboxPlayerRecord(player)
    if not record.firstUseDone then
        local redContainers = 0
        if player.GetMaxHearts then
            redContainers = math.floor((player:GetMaxHearts() or 0) / 2)
        end

        if redContainers > 0 and player.AddSoulHearts then
            player:AddSoulHearts(redContainers * 2)
        end

        record.firstUseDone = true
        SetAngelboxCharge(player, slot, 0)
        SaveMusicboxData()
        return true
    end

    MarkAngelboxRewardPending(player)
    ForceAngelboxAngelRoom()
    SetAngelboxCharge(player, slot, 0)
    SaveMusicboxData()
    TrySpawnAngelboxReward()
    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseAngelbox, Items.Angelbox)

function Neverbirth:HandleAngelboxSoulHeartPickup(pickup, collider)
    if not pickup or pickup.Type ~= ANGELBOX_ENTITY_PICKUP or pickup.Variant ~= ANGELBOX_HEART_VARIANT then
        return nil
    end

    local soulHeartValue = GetAngelboxSoulHeartValue(pickup)
    if not soulHeartValue then
        return nil
    end

    local player = collider and collider.ToPlayer and collider:ToPlayer()
    if not player or not IsAngelboxFirstUseDone(player) then
        return nil
    end

    local slot = FindAngelboxSlot(player)
    if slot == nil then
        return nil
    end

    local currentCharge = GetAngelboxCharge(player, slot)
    if currentCharge >= ANGELBOX_MAX_CHARGE then
        return nil
    end

    local soulHeartRoom = GetAngelboxSoulHeartRoom(player)
    local healthAmount = math.min(soulHeartValue, soulHeartRoom)
    local overflowAmount = soulHeartValue - healthAmount
    if overflowAmount <= 0 then
        return nil
    end

    local chargeAmount = math.min(overflowAmount, ANGELBOX_MAX_CHARGE - currentCharge)
    if chargeAmount <= 0 then
        return nil
    end

    if healthAmount > 0 and player.AddSoulHearts then
        player:AddSoulHearts(healthAmount)
    end

    AddAngelboxCharge(player, slot, chargeAmount)

    if pickup.PlayPickupSound then
        pickup:PlayPickupSound()
    end
    if pickup.Remove then
        pickup:Remove()
    end

    return true
end

if ModCallbacks.MC_PRE_PICKUP_COLLISION then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, Neverbirth.HandleAngelboxSoulHeartPickup, ANGELBOX_HEART_VARIANT)
end

function Neverbirth:SpawnAngelboxRewardOnNewRoom()
    if not IsAngelboxCurrentRoomAngel() then
        return
    end

    TrySpawnAngelboxReward()
    if MarkAngelboxRoomEnteredThisFloor() then
        SaveMusicboxData()
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.SpawnAngelboxRewardOnNewRoom)
end

function Neverbirth:UpdateAngelboxDealChance()
    local data = GetAngelboxData()
    local floorKey = GetAngelboxFloorKey()
    local target = GetAngelboxChanceTarget()
    local applied = GetAngelboxAppliedChance(data, floorKey)

    if target <= 0 and applied <= 0 then
        return
    end

    if SetAngelboxChanceTarget(target) then
        SaveMusicboxData()
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateAngelboxDealChance)

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.UpdateAngelboxDealChance)
end

--------------------------------------------------
-- 恶魔盒

local DEVILBOX_MAX_CHARGE = 4
local DEVILBOX_DEVIL_CHANCE = -0.5
local DEVILBOX_EXTRA_BLACK_HEART_CHANCE = 80
local DEVILBOX_REWARD_QUALITY = 3
local DEVILBOX_DEVIL_POOL = (ItemPoolType and ItemPoolType.POOL_DEVIL) or 3
local DEVILBOX_ROOM_DEVIL = (RoomType and RoomType.ROOM_DEVIL) or 14
local DEVILBOX_BLACK_HEART_SUBTYPE = (HeartSubType and HeartSubType.HEART_BLACK) or 6
local DEVILBOX_GRID_ROOM_INDEX = (GridRooms and GridRooms.ROOM_DEVIL_IDX) or -1
local DEVILBOX_STATE_DEVILROOM_SPAWNED = (GameStateFlag and GameStateFlag.STATE_DEVILROOM_SPAWNED) or 5
local DEVILBOX_STATE_DEVILROOM_VISITED = (GameStateFlag and GameStateFlag.STATE_DEVILROOM_VISITED) or 6
local DEVILBOX_FALLBACK_REWARDS = {
    278, -- Dark Bum
    292, -- Satanic Bible
    399, -- Maw of the Void
    417, -- Succubus
    462, -- Eye of Belial
    654, -- False PHD
    679, -- Lil Abaddon
}

local function GetDevilboxPlayerRecord(player)
    local data = GetDevilboxData()
    local key = tostring(player and player.InitSeed or "")
    local runSeed = GetCurrentRunSeed()
    local record = data.players[key]

    if type(record) ~= "table" or record.runSeed ~= runSeed then
        record = {
            runSeed = runSeed,
            firstUseDone = false,
        }
        data.players[key] = record
    end

    return record, key
end

local function IsDevilboxFirstUseDone(player)
    local record = GetDevilboxPlayerRecord(player)
    return record.firstUseDone == true
end

local function FindDevilboxSlot(player, preferredSlot)
    if not player or not player.GetActiveItem then
        return nil
    end

    if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == Items.Devilbox then
        return preferredSlot
    end

    for _, slot in ipairs(ANGELBOX_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.Devilbox then
            return slot
        end
    end

    return nil
end

local function PlayerHasDevilbox(player)
    if not player then
        return false
    end

    if FindDevilboxSlot(player) ~= nil then
        return true
    end

    return player.GetCollectibleNum and player:GetCollectibleNum(Items.Devilbox) > 0
end

local function AnyPlayerHasDevilbox()
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasDevilbox(player) then
            return true
        end
    end

    return false
end

local boxBonusHeartKeys = {}
local boxProcessedHeartKeys = {}
local boxBonusHeartSpawnDepth = 0

local function GetBoxHeartPickupKey(pickup)
    if not pickup then
        return nil
    end

    if pickup.InitSeed ~= nil then
        return "init:" .. tostring(pickup.InitSeed)
    end

    if pickup.Seed ~= nil then
        return "seed:" .. tostring(pickup.Seed)
    end

    return tostring(pickup)
end

local function RollBoxHeartBonus(pickup, chancePercent, salt)
    local seed = tonumber(pickup and (pickup.InitSeed or pickup.Seed)) or 0
    return ((seed + (salt or 0)) % 100) < chancePercent
end

local function SpawnBoxBonusHeart(sourcePickup, subtype)
    local game = GetAngelboxGame()
    if not game or not game.Spawn then
        return nil
    end

    local position = sourcePickup and sourcePickup.Position or nil
    if not position then
        local room = GetAngelboxRoom()
        position = room and room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
    end

    local room = GetAngelboxRoom()
    if room and room.FindFreePickupSpawnPosition then
        position = room:FindFreePickupSpawnPosition(position, 40, true, false)
    end

    local seed = (tonumber(sourcePickup and (sourcePickup.InitSeed or sourcePickup.Seed)) or 0) + subtype * 1000
    boxBonusHeartSpawnDepth = boxBonusHeartSpawnDepth + 1
    local pickup = game:Spawn(ANGELBOX_ENTITY_PICKUP, ANGELBOX_HEART_VARIANT, position, Vector(0, 0), sourcePickup, subtype, seed)
    boxBonusHeartSpawnDepth = boxBonusHeartSpawnDepth - 1

    local key = GetBoxHeartPickupKey(pickup)
    if key then
        boxBonusHeartKeys[key] = true
    end

    return pickup
end

function Neverbirth:HandleBoxHeartPickupInit(pickup)
    if not pickup or pickup.Type ~= ANGELBOX_ENTITY_PICKUP or pickup.Variant ~= ANGELBOX_HEART_VARIANT then
        return
    end

    local key = GetBoxHeartPickupKey(pickup)
    if key and boxBonusHeartKeys[key] then
        boxProcessedHeartKeys[key] = true
        return
    end

    if boxBonusHeartSpawnDepth > 0 then
        if key then
            boxBonusHeartKeys[key] = true
            boxProcessedHeartKeys[key] = true
        end
        return
    end

    if key and boxProcessedHeartKeys[key] then
        return
    end

    if key then
        boxProcessedHeartKeys[key] = true
    end

    if AnyPlayerHasAngelbox() and RollBoxHeartBonus(pickup, ANGELBOX_EXTRA_SOUL_HEART_CHANCE, 0) then
        SpawnBoxBonusHeart(pickup, ANGELBOX_SOUL_HEART_SUBTYPE)
    end

    if AnyPlayerHasDevilbox() and RollBoxHeartBonus(pickup, DEVILBOX_EXTRA_BLACK_HEART_CHANCE, 7) then
        SpawnBoxBonusHeart(pickup, DEVILBOX_BLACK_HEART_SUBTYPE)
    end
end

if ModCallbacks.MC_POST_PICKUP_INIT then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, Neverbirth.HandleBoxHeartPickupInit, ANGELBOX_HEART_VARIANT)
end

local function GetDevilboxCharge(player, slot)
    if player and player.GetActiveCharge then
        return player:GetActiveCharge(slot) or 0
    end

    return 0
end

local function SetDevilboxCharge(player, slot, charge)
    if not player then
        return
    end

    local clampedCharge = math.max(0, math.min(charge or 0, DEVILBOX_MAX_CHARGE))
    if player.SetActiveCharge then
        player:SetActiveCharge(clampedCharge, slot)
    elseif clampedCharge <= 0 and player.DischargeActiveItem then
        player:DischargeActiveItem(slot)
    elseif clampedCharge >= DEVILBOX_MAX_CHARGE and player.FullCharge then
        player:FullCharge(slot)
    end
end

local function AddDevilboxCharge(player, slot, amount)
    local currentCharge = GetDevilboxCharge(player, slot)
    SetDevilboxCharge(player, slot, currentCharge + (amount or 0))
end

local function GetDevilboxPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function GetDevilboxPendingRewardTable()
    local data = GetDevilboxData()
    local floorKey = GetAngelboxFloorKey()
    local pending = data.pendingRewards[floorKey]

    if type(pending) == "table" then
        return pending
    end

    local legacyCount = tonumber(pending) or 0
    pending = {}
    for index = 1, legacyCount do
        pending["legacy" .. tostring(index)] = true
    end
    data.pendingRewards[floorKey] = pending
    return pending
end

local function CountDevilboxPendingRewards()
    local count = 0
    for _, pending in pairs(GetDevilboxPendingRewardTable()) do
        if pending then
            count = count + 1
        end
    end

    return count
end

local function HasDevilboxPendingReward()
    return CountDevilboxPendingRewards() > 0
end

local function IsDevilboxCurrentRoomDevil()
    local room = GetAngelboxRoom()
    return room and room.GetType and room:GetType() == DEVILBOX_ROOM_DEVIL
end

local function IsDevilboxRoomEnteredThisFloor()
    return GetDevilboxData().enteredDevilFloors[GetAngelboxFloorKey()] == true or IsDevilboxCurrentRoomDevil()
end

local function MarkDevilboxRoomEnteredThisFloor()
    local data = GetDevilboxData()
    local floorKey = GetAngelboxFloorKey()
    if data.enteredDevilFloors[floorKey] then
        return false
    end

    data.enteredDevilFloors[floorKey] = true
    return true
end

local function MarkDevilboxRewardPending(player)
    if IsDevilboxRoomEnteredThisFloor() then
        return false
    end

    local pending = GetDevilboxPendingRewardTable()
    pending[GetDevilboxPlayerKey(player)] = true
    return true
end

local function ClearDevilboxPendingRewards()
    GetDevilboxData().pendingRewards[GetAngelboxFloorKey()] = nil
end

local function GetDevilboxAppliedChance(data, floorKey)
    local applied = data.appliedChanceFloors[floorKey]
    if applied == true then
        return DEVILBOX_DEVIL_CHANCE
    elseif type(applied) == "number" then
        return applied
    end

    return 0
end

local function SetDevilboxChanceTarget(target)
    local level = GetAngelboxLevel()
    if not level or not level.AddAngelRoomChance then
        return false
    end

    local data = GetDevilboxData()
    local floorKey = GetAngelboxFloorKey()
    local applied = GetDevilboxAppliedChance(data, floorKey)
    local delta = target - applied

    if math.abs(delta) <= 0.0001 then
        return false
    end

    level:AddAngelRoomChance(delta)

    if target >= 0 then
        data.appliedChanceFloors[floorKey] = nil
    else
        data.appliedChanceFloors[floorKey] = target
    end

    return true
end

local function GetDevilboxChanceTarget()
    local data = GetDevilboxData()
    local floorKey = GetAngelboxFloorKey()

    if data.forcedDevilFloors[floorKey] then
        return -1
    end

    if AnyPlayerHasDevilbox() then
        return DEVILBOX_DEVIL_CHANCE
    end

    return 0
end

local function GetDevilboxBlackHeartValue(pickup)
    if pickup and pickup.SubType == DEVILBOX_BLACK_HEART_SUBTYPE then
        return 2
    end

    return nil
end

local function SelectDevilboxFallbackReward(baseSeed, rewardIndex, selectedItems)
    local listSize = #DEVILBOX_FALLBACK_REWARDS
    if listSize <= 0 then
        return 118
    end

    local startIndex = ((tonumber(baseSeed) or 0) + (tonumber(rewardIndex) or 1) - 1) % listSize + 1
    local duplicateCandidate = nil

    for offset = 0, listSize - 1 do
        local itemId = DEVILBOX_FALLBACK_REWARDS[((startIndex + offset - 1) % listSize) + 1]
        if IsCollectibleQuality(itemId, DEVILBOX_REWARD_QUALITY) then
            if not IsAngelboxRewardAlreadySelected(selectedItems, itemId) then
                return itemId
            end

            duplicateCandidate = duplicateCandidate or itemId
        end
    end

    return duplicateCandidate or DEVILBOX_FALLBACK_REWARDS[startIndex] or 278
end

local function SelectDevilboxReward(rewardIndex, selectedItems)
    local game = GetAngelboxGame()
    local itemPool = game and game.GetItemPool and game:GetItemPool()
    local room = GetAngelboxRoom()
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0

    if not itemPool or not itemPool.GetCollectible then
        return SelectDevilboxFallbackReward(seed, rewardIndex, selectedItems)
    end

    local duplicateCandidate = nil

    for attempt = 1, ANGELBOX_REWARD_ATTEMPTS do
        local itemId = itemPool:GetCollectible(DEVILBOX_DEVIL_POOL, false, GetAngelboxRewardSeed(seed, rewardIndex, attempt), ANGELBOX_NULL_ITEM)
        if IsCollectibleQuality(itemId, DEVILBOX_REWARD_QUALITY) then
            if not IsAngelboxRewardAlreadySelected(selectedItems, itemId) then
                return itemId
            end

            duplicateCandidate = duplicateCandidate or itemId
        end
    end

    return duplicateCandidate or SelectDevilboxFallbackReward(seed, rewardIndex, selectedItems)
end

local function TrySpawnDevilboxReward()
    if not HasDevilboxPendingReward() then
        return false
    end

    local game = GetAngelboxGame()
    local room = GetAngelboxRoom()
    if not game or not game.Spawn or not room or not room.GetType or room:GetType() ~= DEVILBOX_ROOM_DEVIL then
        return false
    end

    local rewardCount = CountDevilboxPendingRewards()
    local center = room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
    local seed = room.GetSpawnSeed and room:GetSpawnSeed() or 0
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    local selectedItems = {}

    for index = 1, rewardCount do
        local position = center
        if Vector then
            position = center + Vector((index - (rewardCount + 1) / 2) * 40, 0)
        end

        if room.FindFreePickupSpawnPosition then
            position = room:FindFreePickupSpawnPosition(position, 40, true, false)
        end

        local itemId = SelectDevilboxReward(index, selectedItems)
        selectedItems[itemId] = true
        game:Spawn(ANGELBOX_ENTITY_PICKUP, ANGELBOX_COLLECTIBLE_VARIANT, position, velocity, nil, itemId, seed + index)
    end

    ClearDevilboxPendingRewards()
    SaveMusicboxData()
    return true
end

local function ClearDevilboxInitializedDealRoom(level)
    if not level or not level.GetRoomByIdx then
        return false
    end

    local ok, cleared = pcall(function()
        local roomDesc = level:GetRoomByIdx(DEVILBOX_GRID_ROOM_INDEX)
        if not roomDesc then
            return false
        end

        roomDesc.Data = nil
        return true
    end)

    return ok and cleared == true
end

local function ResetDevilboxDealStateForDevilRoom()
    local game = GetAngelboxGame()
    if not game or not game.SetStateFlag then
        return false
    end

    game:SetStateFlag(DEVILBOX_STATE_DEVILROOM_SPAWNED, false)
    game:SetStateFlag(DEVILBOX_STATE_DEVILROOM_VISITED, false)
    return true
end

local function ForceDevilboxDevilRoom()
    local level = GetAngelboxLevel()
    if not level then
        return
    end

    local data = GetDevilboxData()
    local floorKey = GetAngelboxFloorKey()
    if not data.forcedDevilFloors[floorKey] then
        data.forcedDevilFloors[floorKey] = true
    end
    SetDevilboxChanceTarget(-1)
    ResetDevilboxDealStateForDevilRoom()
    ClearDevilboxInitializedDealRoom(level)

    if level.InitializeDevilAngelRoom then
        level:InitializeDevilAngelRoom(false, true)
    end
end

function Neverbirth:UseDevilbox(_, _, player, _, activeSlot)
    if not player then
        return false
    end

    local slot = FindDevilboxSlot(player, activeSlot) or activeSlot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    if GetDevilboxCharge(player, slot) < DEVILBOX_MAX_CHARGE then
        return false
    end

    local record = GetDevilboxPlayerRecord(player)
    if not record.firstUseDone then
        local redContainers = 0
        if player.GetMaxHearts then
            redContainers = math.floor((player:GetMaxHearts() or 0) / 2)
        end

        if redContainers > 0 and player.AddBlackHearts then
            player:AddBlackHearts(redContainers * 2)
        end

        record.firstUseDone = true
        SetDevilboxCharge(player, slot, 0)
        SaveMusicboxData()
        return true
    end

    MarkDevilboxRewardPending(player)
    ForceDevilboxDevilRoom()
    SetDevilboxCharge(player, slot, 0)
    SaveMusicboxData()
    TrySpawnDevilboxReward()
    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseDevilbox, Items.Devilbox)

function Neverbirth:HandleDevilboxBlackHeartPickup(pickup, collider)
    if not pickup or pickup.Type ~= ANGELBOX_ENTITY_PICKUP or pickup.Variant ~= ANGELBOX_HEART_VARIANT then
        return nil
    end

    local blackHeartValue = GetDevilboxBlackHeartValue(pickup)
    if not blackHeartValue then
        return nil
    end

    local player = collider and collider.ToPlayer and collider:ToPlayer()
    if not player or not IsDevilboxFirstUseDone(player) then
        return nil
    end

    local slot = FindDevilboxSlot(player)
    if slot == nil then
        return nil
    end

    local currentCharge = GetDevilboxCharge(player, slot)
    if currentCharge >= DEVILBOX_MAX_CHARGE then
        return nil
    end

    local blackHeartRoom = GetAngelboxSoulHeartRoom(player)
    local healthAmount = math.min(blackHeartValue, blackHeartRoom)
    local overflowAmount = blackHeartValue - healthAmount
    if overflowAmount <= 0 then
        return nil
    end

    local chargeAmount = math.min(overflowAmount, DEVILBOX_MAX_CHARGE - currentCharge)
    if chargeAmount <= 0 then
        return nil
    end

    if healthAmount > 0 and player.AddBlackHearts then
        player:AddBlackHearts(healthAmount)
    end

    AddDevilboxCharge(player, slot, chargeAmount)

    if pickup.PlayPickupSound then
        pickup:PlayPickupSound()
    end
    if pickup.Remove then
        pickup:Remove()
    end

    return true
end

if ModCallbacks.MC_PRE_PICKUP_COLLISION then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, Neverbirth.HandleDevilboxBlackHeartPickup, ANGELBOX_HEART_VARIANT)
end

function Neverbirth:SpawnDevilboxRewardOnNewRoom()
    if not IsDevilboxCurrentRoomDevil() then
        return
    end

    TrySpawnDevilboxReward()
    if MarkDevilboxRoomEnteredThisFloor() then
        SaveMusicboxData()
    end
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.SpawnDevilboxRewardOnNewRoom)
end

function Neverbirth:UpdateDevilboxDealChance()
    local data = GetDevilboxData()
    local floorKey = GetAngelboxFloorKey()
    local target = GetDevilboxChanceTarget()
    local applied = GetDevilboxAppliedChance(data, floorKey)

    if target >= 0 and applied >= 0 then
        return
    end

    if SetDevilboxChanceTarget(target) then
        SaveMusicboxData()
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateDevilboxDealChance)

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.UpdateDevilboxDealChance)
end

--------------------------------------------------
-- 避孕套 / 美工刀

do
Neverbirth.CondomBanCount = 2
Neverbirth.CondomReplacementAttempts = 20
Neverbirth.CondomEntityPickup = (EntityType and EntityType.ENTITY_PICKUP) or 5
Neverbirth.CondomCollectibleVariant = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
Neverbirth.UtilityKnifeDamageUp = 1

function Neverbirth:GetCondomData()
    EnsureMusicboxDataLoaded()

    local data = musicboxSaveData.condom
    if type(data) ~= "table" or data.runSeed ~= GetCurrentRunSeed() then
        data = {
            runSeed = GetCurrentRunSeed(),
            banned = {},
        }
        musicboxSaveData.condom = data
    end

    if type(data.banned) ~= "table" then
        data.banned = {}
    end

    return data
end

function Neverbirth:GetUtilityKnifeData()
    EnsureMusicboxDataLoaded()

    local data = musicboxSaveData.utilityKnife
    if type(data) ~= "table" or data.runSeed ~= GetCurrentRunSeed() then
        data = {
            runSeed = GetCurrentRunSeed(),
            playerCounts = {},
        }
        musicboxSaveData.utilityKnife = data
    end

    if type(data.playerCounts) ~= "table" then
        data.playerCounts = {}
    end

    return data
end

function Neverbirth:GetItemConfigObject()
    if Isaac.GetItemConfig then
        return Isaac.GetItemConfig()
    end

    return nil
end

function Neverbirth:GetCollectibleConfig(itemId)
    local config = self:GetItemConfigObject()
    if config and config.GetCollectible then
        return config:GetCollectible(itemId)
    end

    return nil
end

function Neverbirth:IsBabyTaggedCollectible(itemId)
    local config = self:GetCollectibleConfig(itemId)
    local babyTag = ItemConfig and ItemConfig.TAG_BABY
    if config and babyTag and type(config.Tags) == "number" then
        return (config.Tags & babyTag) ~= 0
    end

    return false
end

function Neverbirth:AddFallbackBabyItem(targets, collectibleName)
    if CollectibleType and CollectibleType[collectibleName] then
        targets[CollectibleType[collectibleName]] = true
    end
end

function Neverbirth:CollectBabyTaggedItems()
    local ids = {}
    local seen = {}
    local config = self:GetItemConfigObject()

    if config and config.GetCollectibles then
        local ok, collectibles = pcall(function()
            return config:GetCollectibles()
        end)
        if ok and type(collectibles) == "table" then
            for _, collectible in pairs(collectibles) do
                local itemId = collectible and (collectible.ID or collectible.Id)
                if type(itemId) == "number" and itemId > 0 and self:IsBabyTaggedCollectible(itemId) and not seen[itemId] then
                    ids[#ids + 1] = itemId
                    seen[itemId] = true
                end
            end
        end
    end

    if #ids == 0 then
        local fallback = {}
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_BROTHER_BOBBY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_SISTER_MAGGY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_LITTLE_CHUBBY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_ROBO_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_LITTLE_GISH")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_LITTLE_STEVEN")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_DEMON_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_GHOST_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_HARLEQUIN_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_RAINBOW_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_ROBO_BABY_2")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_ROTTEN_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_HEADLESS_BABY")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_LEECH")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_LIL_BRIMSTONE")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_INCUBUS")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_LIL_LOKI")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_BBF")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_SERAPHIM")
        self:AddFallbackBabyItem(fallback, "COLLECTIBLE_SWORN_PROTECTOR")

        for itemId in pairs(fallback) do
            if not seen[itemId] then
                ids[#ids + 1] = itemId
                seen[itemId] = true
            end
        end
    end

    table.sort(ids)
    return ids
end

function Neverbirth:AnyPlayerOwnsCollectible(itemId)
    for _, player in ipairs(GetPlayers()) do
        if player.GetCollectibleNum and player:GetCollectibleNum(itemId) > 0 then
            return true
        end
    end

    return false
end

function Neverbirth:GetCondomEligibleItems()
    local data = self:GetCondomData()
    local eligible = {}

    for _, itemId in ipairs(self:CollectBabyTaggedItems()) do
        if not data.banned[tostring(itemId)] and not self:AnyPlayerOwnsCollectible(itemId) then
            eligible[#eligible + 1] = itemId
        end
    end

    return eligible
end

function Neverbirth:ShowCondomFeedback(bannedCount)
    local game = Game()
    local hud = game and game.GetHUD and game:GetHUD()
    if not hud or not hud.ShowItemText then
        return
    end

    if bannedCount > 0 then
        hud:ShowItemText("Condom", tostring(bannedCount) .. " baby items banned")
    else
        hud:ShowItemText("Condom", "No baby items left")
    end
end

function Neverbirth:PickCondomTarget(eligible, rng)
    if #eligible <= 0 then
        return nil
    end

    local index = 1
    if rng and rng.RandomInt then
        index = rng:RandomInt(#eligible) + 1
    end

    local itemId = eligible[index]
    table.remove(eligible, index)
    return itemId
end

function Neverbirth:UseCondom(itemId, rng, player)
    local data = self:GetCondomData()
    local eligible = self:GetCondomEligibleItems()
    local playerRng = rng
    if (not playerRng or not playerRng.RandomInt) and player and player.GetCollectibleRNG then
        playerRng = player:GetCollectibleRNG(Items.Condom)
    end

    local bannedCount = 0
    for _ = 1, self.CondomBanCount do
        local target = self:PickCondomTarget(eligible, playerRng)
        if not target then
            break
        end

        data.banned[tostring(target)] = true
        bannedCount = bannedCount + 1
    end

    self:ShowCondomFeedback(bannedCount)
    if bannedCount > 0 then
        SaveMusicboxData()
    end

    return true
end

function Neverbirth:IsCondomBanned(itemId)
    local data = self:GetCondomData()
    return data.banned[tostring(itemId)] == true
end

function Neverbirth:IsCondomBannedCollectible(itemId)
    return itemId and self:IsCondomBanned(itemId)
end

function Neverbirth:RollCondomReplacement(originalItemId)
    local game = Game()
    local itemPool = game and game.GetItemPool and game:GetItemPool()
    if not itemPool or not itemPool.GetCollectible then
        return nil
    end

    for _ = 1, self.CondomReplacementAttempts do
        local candidate = itemPool:GetCollectible(ItemPoolType and ItemPoolType.POOL_TREASURE or 0, true, 0, 0)
        if type(candidate) == "number"
            and candidate > 0
            and candidate ~= originalItemId
            and not self:IsCondomBannedCollectible(candidate) then
            return candidate
        end
    end

    return nil
end

function Neverbirth:ReplaceCondomBannedPickup(pickup)
    if not pickup or pickup.Variant ~= self.CondomCollectibleVariant then
        return
    end

    local currentSubtype = pickup.SubType
    if not self:IsCondomBannedCollectible(currentSubtype) then
        return
    end

    local pickupData = pickup.GetData and pickup:GetData() or nil
    if pickupData and pickupData.neverbirthCondomReplacing then
        return
    end
    if pickupData then
        pickupData.neverbirthCondomReplacing = true
    end

    local replacement = self:RollCondomReplacement(currentSubtype)
    if replacement then
        if pickup.Morph then
            pickup:Morph(self.CondomEntityPickup, self.CondomCollectibleVariant, replacement, true, true, false)
        else
            pickup.SubType = replacement
        end
    elseif pickup.Remove then
        pickup:Remove()
    end

    if pickupData then
        pickupData.neverbirthCondomReplacing = nil
    end
end

function Neverbirth:EvaluateUtilityKnife(player, cacheFlag)
    if cacheFlag ~= CacheFlag.CACHE_DAMAGE then
        return
    end

    if not player or not player.GetCollectibleNum then
        return
    end

    local count = player:GetCollectibleNum(Items.UtilityKnife)
    if count <= 0 then
        return
    end

    player.Damage = player.Damage + self.UtilityKnifeDamageUp * count
end

function Neverbirth:FindUtilityKnifePickupPlayer(...)
    for index = 1, select("#", ...) do
        local value = select(index, ...)
        if type(value) == "table" then
            if value.ToPlayer then
                local ok, player = pcall(function()
                    return value:ToPlayer()
                end)
                if ok and player then
                    return player
                end
            end

            if value.AddBrokenHearts or value.GetCollectibleNum then
                return value
            end
        end
    end

    return nil
end

function Neverbirth:GrantUtilityKnifeBrokenHeart(...)
    local player = self:FindUtilityKnifePickupPlayer(...)
    if not player or not player.AddBrokenHearts then
        return
    end

    local data = self:GetUtilityKnifeData()
    local key = tostring(player.InitSeed or "")
    local count = 0
    if player.GetCollectibleNum then
        count = tonumber(player:GetCollectibleNum(Items.UtilityKnife)) or 0
    end

    if count > 0 then
        data.playerCounts[key] = math.max(tonumber(data.playerCounts[key]) or 0, count)
    end
    player:AddBrokenHearts(1)
    SaveMusicboxData()
end

function Neverbirth:GrantMeatLumpOneUp(...)
    local player = self:FindUtilityKnifePickupPlayer(...)
    if not player then
        return
    end

    local granted = self:GrantOfficialOneUpFromMeatLump(player)
    if granted and player.GetCollectibleNum and IsValidItemId(Items.MeatLump) then
        local data = Neverbirth.GetBlackTaisuiData()
        local key = tostring((player and player.InitSeed) or "0")
        data.meatLumpCounts[key] = math.max(tonumber(data.meatLumpCounts[key]) or 0, tonumber(player:GetCollectibleNum(Items.MeatLump)) or 0)
        SaveMusicboxData()
    end
end

function Neverbirth:GrantOfficialOneUpFromMeatLump(player)
    if not player then
        return false
    end
    Neverbirth:AddHiddenMeatLumpOneUpEffect(player, Neverbirth.BlackTaisuiOfficialLifeItem)
    Neverbirth:AddMeatLumpLife(player, 1)
    return true
end

function Neverbirth:GetMeatLumpLifeCount(player)
    local data = Neverbirth.GetBlackTaisuiData()
    local key = tostring((player and player.InitSeed) or "0")
    return math.max(0, tonumber(data.meatLumpLives[key]) or 0)
end

function Neverbirth:AddMeatLumpLife(player, amount)
    local data = Neverbirth.GetBlackTaisuiData()
    local key = tostring((player and player.InitSeed) or "0")
    data.meatLumpLives[key] = math.max(0, (tonumber(data.meatLumpLives[key]) or 0) + (tonumber(amount) or 0))
    SaveMusicboxData()
end

function Neverbirth:ConsumeMeatLumpLife(player)
    local data = Neverbirth.GetBlackTaisuiData()
    local key = tostring((player and player.InitSeed) or "0")
    local count = math.max(0, tonumber(data.meatLumpLives[key]) or 0)
    if count <= 0 then
        return false
    end
    data.meatLumpLives[key] = count - 1
    SaveMusicboxData()
    return true
end

function Neverbirth:RestoreMeatLumpLifeHealth(player)
    if not player then
        return
    end
    local maxHearts = player.GetMaxHearts and (tonumber(player:GetMaxHearts()) or 0) or tonumber(player.maxHearts) or 0
    if maxHearts > 0 and player.GetHearts and player.AddHearts then
        local current = tonumber(player:GetHearts()) or 0
        player:AddHearts(math.max(0, 1 - current))
    elseif player.AddBlackHearts then
        player:AddBlackHearts(2)
    elseif player.AddSoulHearts then
        player:AddSoulHearts(2)
    end
end

function Neverbirth:ApplyMeatLumpLife(player, reviveDeadPlayer)
    if not Neverbirth:ConsumeMeatLumpLife(player) then
        return false
    end
    Neverbirth:ConsumeHiddenMeatLumpOneUpEffect(player, Neverbirth.BlackTaisuiOfficialLifeItem)
    if reviveDeadPlayer and player and player.Revive then
        pcall(function()
            player:Revive()
        end)
    end
    Neverbirth:RestoreMeatLumpLifeHealth(player)
    if player and player.SetColor and Color then
        pcall(function()
            player:SetColor(Color(0.25, 0.15, 0.18, 1, 0.08, 0, 0.08), 45, 1, true, false)
        end)
    end
    return true
end

function Neverbirth:HandleMeatLumpDamage(entity, amount)
    local player = entity and entity.ToPlayer and entity:ToPlayer()
    if not player or (tonumber(amount) or 0) <= 0 or Neverbirth:GetMeatLumpLifeCount(player) <= 0 then
        return nil
    end
    if IsIncomingDamageLethal(player, tonumber(amount) or 0) and Neverbirth:ApplyMeatLumpLife(player, false) then
        return false
    end
    return nil
end

function Neverbirth:RecoverMeatLumpDeadPlayers()
    for _, player in ipairs(GetPlayers()) do
        if Neverbirth:GetMeatLumpLifeCount(player) > 0 and player and player.IsDead then
            local ok, dead = pcall(function()
                return player:IsDead()
            end)
            if ok and dead then
                Neverbirth:ApplyMeatLumpLife(player, true)
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleMeatLumpDamage, EntityType.ENTITY_PLAYER)
if ModCallbacks.MC_POST_UPDATE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.RecoverMeatLumpDeadPlayers)
end

function Neverbirth:TryRemoveCollectibleCostume(player, itemId)
    if not player or not itemId or not Isaac or not Isaac.GetItemConfig then
        return
    end
    local ok, config = pcall(function()
        local itemConfig = Isaac.GetItemConfig()
        return itemConfig and itemConfig.GetCollectible and itemConfig:GetCollectible(itemId) or nil
    end)
    if not ok or not config then
        return
    end
    if player.TryRemoveCollectibleCostume then
        pcall(function() player:TryRemoveCollectibleCostume(config, true) end)
        pcall(function() player:TryRemoveCollectibleCostume(config, false) end)
    end
    if player.RemoveCostume then
        pcall(function() player:RemoveCostume(config) end)
    end
end

function Neverbirth:AddHiddenMeatLumpOneUpEffect(player, itemId)
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    if not effects or not effects.AddCollectibleEffect then
        return false
    end
    local attempts = {
        function() effects:AddCollectibleEffect(itemId, false, 1) end,
        function() effects:AddCollectibleEffect(itemId, false) end,
        function() effects:AddCollectibleEffect(itemId) end,
    }
    for _, attempt in ipairs(attempts) do
        if pcall(attempt) then
            return true
        end
    end
    return false
end

function Neverbirth:ConsumeHiddenMeatLumpOneUpEffect(player, itemId)
    local effects = Neverbirth:GetBlackTaisuiTemporaryEffects(player)
    if not effects or not effects.RemoveCollectibleEffect then
        return false
    end
    return pcall(function()
        effects:RemoveCollectibleEffect(itemId, 1)
    end)
end

function Neverbirth:HideMeatLumpOneUpCollectible(player, itemId)
    Neverbirth:TryRemoveCollectibleCostume(player, itemId)

    if player and player.RemoveCollectible then
        local attempts = {
            function() player:RemoveCollectible(itemId, false, 0, true) end,
            function() player:RemoveCollectible(itemId, false, 0) end,
            function() player:RemoveCollectible(itemId, false) end,
            function() player:RemoveCollectible(itemId) end,
        }
        for _, attempt in ipairs(attempts) do
            if pcall(attempt) then
                break
            end
        end
    end

    -- The official 1UP is engine-side. After hiding its collectible/costume,
    -- keep a no-costume collectible effect as the closest hidden official-life
    -- backup available from Lua. If the engine ignores this for revives, the
    -- visible collectible route is the only fully official path.
    Neverbirth:AddHiddenMeatLumpOneUpEffect(player, itemId)
end

function Neverbirth:TrackMeatLumpOneUpCopies()
    if not IsValidItemId(Items.MeatLump) then
        return
    end
    local data = Neverbirth.GetBlackTaisuiData()
    for _, player in ipairs(GetPlayers()) do
        if player and player.GetCollectibleNum then
            local key = tostring((player and player.InitSeed) or "0")
            local currentCount = tonumber(player:GetCollectibleNum(Items.MeatLump)) or 0
            local previousCount = tonumber(data.meatLumpCounts[key]) or 0
            if currentCount > previousCount then
                local granted = 0
                for _ = 1, currentCount - previousCount do
                    if Neverbirth:GrantOfficialOneUpFromMeatLump(player) then
                        granted = granted + 1
                    end
                end
                if granted > 0 then
                    data.meatLumpCounts[key] = currentCount
                    SaveMusicboxData()
                end
            elseif currentCount < previousCount then
                data.meatLumpCounts[key] = currentCount
                SaveMusicboxData()
            end
        end
    end
end

function Neverbirth:TrackUtilityKnifeCopies()
    local data = self:GetUtilityKnifeData()

    for _, player in ipairs(GetPlayers()) do
        if player and player.GetCollectibleNum then
            local key = tostring(player.InitSeed or "")
            local currentCount = tonumber(player:GetCollectibleNum(Items.UtilityKnife)) or 0
            local previousCount = tonumber(data.playerCounts[key]) or 0

            if currentCount > previousCount then
                local gained = currentCount - previousCount
                if player.AddBrokenHearts then
                    player:AddBrokenHearts(gained)
                end
                data.playerCounts[key] = currentCount
                SaveMusicboxData()
            elseif currentCount < previousCount then
                data.playerCounts[key] = currentCount
                SaveMusicboxData()
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseCondom, Items.Condom)
Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseDebugController, Items.DebugController)
Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateUtilityKnife)
Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackUtilityKnifeCopies)
Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackMeatLumpOneUpCopies)
Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateDebugControllerMenus)

if ModCallbacks.MC_POST_RENDER then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderDebugControllerMenus)
end

if ModCallbacks.MC_POST_FIRE_TEAR then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, Neverbirth.SuppressDebugControllerTear)
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.CloseDebugControllerMenus)
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.CloseDebugControllerMenus)
end

if ModCallbacks.MC_POST_PICKUP_INIT then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, Neverbirth.ReplaceCondomBannedPickup, Neverbirth.CondomCollectibleVariant)
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.GrantUtilityKnifeBrokenHeart, Items.UtilityKnife)
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE and IsValidItemId(Items.MeatLump) then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.GrantMeatLumpOneUp, Items.MeatLump)
end
end

--------------------------------------------------
-- 骰子套装回调登记放在文件末尾，避免影响现有主动道具测试按顺序取回调。

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.TrackDiceSetPickup)
end

if ModCallbacks.MC_PRE_USE_ITEM then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, Neverbirth.RecordDiceSetPreUse)
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.HandleDiceSetUse)
Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateDiceSetStatProtection)
Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackHeldDiceItems)
Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateDiceSetPendingState)
Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TryRegisterDiceSetEIDModifier)

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetDiceSetState)
end
