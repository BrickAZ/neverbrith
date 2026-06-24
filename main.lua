-- 注册模组
local Neverbirth = RegisterMod("neverbirth", 1)

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
            eidDescription = "{{Luck}} +3 Luck while held#First use converts red heart containers into full soul hearts#Overflow soul hearts recharge it#At full charge, forces an angel room this floor and adds 1 quality 4 angel item on first entry#Heart drops have a 10% chance to add a soul heart#Favors angel rooms while held",
        },
        zh_cn = {
            name = "天使盒",
            eidDescription = "持有时 {{Luck}} +3 幸运#每名玩家首次使用：每个红心容器生成1个完整魂心#之后只吸收装不下的魂心充能，满6格可再次使用#非首次使用：本层尽力必定开启天使房#若使用前本层未进入过天使房，该玩家使首次进入本层天使房时额外生成1个4级天使房道具#地上心掉落有10%额外生成1个完整魂心#持有时一半恶魔房概率转为天使房概率",
        },
    },
    [Items.Devilbox] = {
        en_us = {
            name = "Devil Box",
            eidDescription = "First use converts red heart containers into full black hearts#Overflow black hearts recharge it#At full charge, forces a devil room this floor and adds 1 quality 3 devil item on first entry#Heart drops have a 20% chance to add a black heart#Favors devil rooms while held",
        },
        zh_cn = {
            name = "恶魔盒",
            eidDescription = "每名玩家首次使用：每个红心容器生成1个完整黑心#之后只吸收装不下的黑心充能，满6格可再次使用#非首次使用：本层尽力必定开启恶魔房#若使用前本层未进入过恶魔房，该玩家使首次进入本层恶魔房时额外生成1个3级恶魔房道具#地上心掉落有20%额外生成1个黑心#持有时一半交易房方向转为恶魔房概率",
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

local ANGELBOX_MAX_CHARGE = 6
local ANGELBOX_ANGEL_CHANCE = 0.5
local ANGELBOX_LUCK_BONUS = 3
local ANGELBOX_EXTRA_SOUL_HEART_CHANCE = 10
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

local DEVILBOX_MAX_CHARGE = 6
local DEVILBOX_DEVIL_CHANCE = -0.5
local DEVILBOX_EXTRA_BLACK_HEART_CHANCE = 20
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
