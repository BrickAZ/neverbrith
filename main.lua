-- Required REPENTOGON bootstrap: no gameplay registration or module side effects before this gate.
do
    local function supportedRelease(runtime)
        if type(runtime) ~= "table" or runtime.Real ~= true
            or type(runtime.Version) ~= "string"
            or type(_RunEntityTakeDmgCallback) ~= "function"
        then return false end
        -- This fixed-source local candidate is explicitly approved for Yin's
        -- native API. Capability 0 still falls back within the Yin module.
        if runtime.Version == "1.0.12a-yin-api1-dev" then return true end
        local major, minor, patch, suffix = runtime.Version:match("^(%d+)%.(%d+)%.(%d+)([a-z]?)$")
        if not major then return false end
        for _, component in ipairs({ major, minor, patch }) do
            if #component > 1 and component:sub(1, 1) == "0" then return false end
        end
        major, minor, patch = tonumber(major), tonumber(minor), tonumber(patch)
        if major ~= 1 then return major > 1 end
        if minor ~= 0 then return minor > 0 end
        if patch ~= 12 then return patch > 12 end
        return suffix ~= "" -- 1.0.12 itself lacks the required letter patch.
    end
    if not supportedRelease(REPENTOGON) then
        if not _G.NeverbirthRepentogonDependencyMessageShown then
            _G.NeverbirthRepentogonDependencyMessageShown = true
            local message = "[neverbirth] 需要 REPENTOGON 1.0.12a 或更新的可识别稳定版本，或已认可的 Yin API 本地候选；当前前置缺失、过旧或构建未知，已停止初始化。Required: REPENTOGON 1.0.12a or newer recognized stable release, or the approved local Yin API candidate; initialization stopped (missing, old or unknown build)."
            if Isaac and type(Isaac.ConsoleOutput) == "function" then Isaac.ConsoleOutput(message .. "\n")
            elseif Isaac and type(Isaac.DebugString) == "function" then Isaac.DebugString(message)
            elseif type(print) == "function" then print(message) end
        end
        -- Only vanilla-safe diagnostics and drop blocking may run without the dependency.
        -- Do not export Neverbirth or load any gameplay / EID / menu modules here.
        local dependencyMod = RegisterMod("neverbirth", 1)
        include("repentogon_dependency_guard")(dependencyMod)
        return
    end
end

-- 注册模组
local Neverbirth = RegisterMod("neverbirth", 1)
local featureInstallation = include("scripts.runtime.feature_installation").Create(Neverbirth)
local eidIntegration
featureInstallation.Run("Neverbirth bootstrap", function()
featureInstallation.PublishGlobal("Neverbirth", Neverbirth)

local Items = include("scripts.catalog.collectibles")()

include("scripts.runtime.localization")(Neverbirth)

local DebugLog = include("scripts.runtime.log")
-- Only event-time closures query this instance, after full entry installation.
local bloodSkullGuModule

local yinExplosionApiReady = false
if type(Isaac.GetPlayerExplosionImmunityAPIVersion) == "function" then
    local ok, version = pcall(Isaac.GetPlayerExplosionImmunityAPIVersion)
    yinExplosionApiReady = ok and version == 1
end

local EID_DESCRIPTIONS, EID_LANGUAGE_ORDER = include("scripts.catalog.eid_descriptions")(Items, yinExplosionApiReady)

local IsValidItemId = include("scripts.catalog.item_id")

-- 原生拾取横幅默认读取英文；只有游戏简体中文代码 "zh" 映射到 zh_cn。
local pickupBanners = include("scripts.runtime.pickup_banners")(Neverbirth, { IsValidItemId = IsValidItemId })
include("scripts.catalog.pickup_texts")(Neverbirth, Items)

-- Register before the eager EID pass, including when EID is already loaded.
include("motion_item_text")(Neverbirth, { Items = Items, EIDDescriptions = EID_DESCRIPTIONS })

eidIntegration = include("scripts.integrations.eid")(Neverbirth, { Descriptions = EID_DESCRIPTIONS, LanguageOrder = EID_LANGUAGE_ORDER, IsValidItemId = IsValidItemId, Log = DebugLog })

include("scripts.runtime.item_diagnostics")(Items, IsValidItemId, DebugLog)

local GetPlayers = include("scripts.runtime.players")

--------------------------------------------------
local debugController = include("scripts.features.debug_controller")(Neverbirth, { Items = Items, IsValidItemId = IsValidItemId })
--------------------------------------------------
-- 虚空针尖

local needletick = featureInstallation.Run("Needletick", function()
return include("scripts.features.needletick")(Neverbirth, {
    ItemId = Items.Needletick,
    IsValidItemId = IsValidItemId
})
end)

--------------------------------------------------
-- 风油精

include("scripts.features.essential_balm")(Neverbirth, { ItemId = Items.EssentialBalm })

--------------------------------------------------
-- 芜湖

include("scripts.features.wuhu")(Neverbirth, { ItemId = Items.Wuhu })

--------------------------------------------------
-- 春药

featureInstallation.Run("Chunyao", function()
return include("scripts.features.chunyao")(Neverbirth, {
    ItemId = Items.Chunyao,
    GetPlayers = GetPlayers
})
end)

--------------------------------------------------
-- 八音盒

-- Shared persistence; owners declare their legacy fields in the original order.
local persistence = include("scripts.runtime.persistence").Create(Neverbirth, {
    Json = require("json"), Log = DebugLog,
    Initialize = include("scripts.runtime.legacy_save_schema")({
        include("scripts.features.musicbox.save_schema"),
        include("scripts.features.boxes.angelbox_save_schema"),
        include("scripts.features.boxes.devilbox_save_schema"),
        include("scripts.features.between_death_and_life.save_schema"),
        include("scripts.systems.dice_set.save_schema"),
        include("scripts.features.condom.save_schema"),
        include("scripts.features.utility_knife.save_schema"),
        include("scripts.features.crazy_coconut.save_schema"),
        include("scripts.features.black_taisui.save_schema"),
        include("scripts.features.certificate_of_neverbirth.save_schema"),
        include("scripts.features.house_vs_elephant.save_schema"),
        include("scripts.features.everchanging.save_schema"),
        include("scripts.features.dog_food_series.save_schema"),
        include("scripts.features.big_dog_bark.save_schema"),
        include("scripts.features.yins_curse.save_schema"),
        include("scripts.features.revive_my_love.save_schema"),
        include("scripts.features.memory_disorder.save_schema"),
        include("scripts.features.ring_of_the_seven_curses.save_schema"),
        include("scripts.features.night_of_the_cowards.save_schema"),
    }),
})
local GetCurrentRunSeed = include("scripts.runtime.run_seed")
local playerIdentity = include("scripts.runtime.player_identity")
local shootingControls = include("scripts.systems.control_ownership").Create(
    include("scripts.systems.entity_identity"), function(player) return player:Exists() end)

--------------------------------------------------
-- 骰子套装
local diceSet = include("scripts.systems.dice_set")(Neverbirth, { Store = persistence.Section("diceSet"), GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, IsValidItemId = IsValidItemId })
local IsIncomingDamageLethal = include("scripts.systems.incoming_damage")
include("scripts.features.musicbox.init")(Neverbirth, {
    IsIncomingDamageLethal = IsIncomingDamageLethal,
    ItemId = Items.Musicbox, GetPlayers = GetPlayers,
    GetCurrentRunSeed = GetCurrentRunSeed, Log = DebugLog,
    Store = persistence.Section("musicboxDeathDebt"),
})

--------------------------------------------------
-- 未剪断的脐带

featureInstallation.Run("UncutCord", function()
return include("scripts.features.uncut_cord")(Neverbirth, {
    ItemId = Items.UncutCord,
    GetPlayers = GetPlayers,
    IsBloodSkullBacklashActive = function() return bloodSkullGuModule.IsBacklashActive() end
})
end)

--------------------------------------------------
-- 剪碎的塔罗

featureInstallation.Run("ShreddedTarot", function()
return include("scripts.features.shredded_tarot")(Neverbirth, {
    ItemId = Items.ShreddedTarot,
    GetPlayers = GetPlayers
})
end)

--------------------------------------------------
-- 血颅蛊

bloodSkullGuModule = featureInstallation.Run("BloodSkullGu", function()
local instance = include("scripts.features.blood_skull_gu")(Neverbirth, {
    ItemId = Items.BloodSkullGu,
    IsValidItemId = IsValidItemId,
    GetPlayers = GetPlayers,
    Log = DebugLog
})
assert(type(instance) == "table" and type(instance.IsBacklashActive) == "function", "BloodSkullGu query missing")
return instance
end)

--------------------------------------------------
-- 老大的指令
include("scripts.features.boss_order")(Neverbirth, { Items = Items, IsValidItemId = IsValidItemId })
--------------------------------------------------
-- 生死一念间
include("scripts.features.between_death_and_life")(Neverbirth, { Store = persistence.Section("deathTrial"), Items = Items, GetCurrentRunSeed = GetCurrentRunSeed, IsValidItemId = IsValidItemId, Log = DebugLog })
local playerGeometry = include("scripts.systems.player_geometry")

local meatLump

do

    local folkWorld = featureInstallation.Run("FolkWorld", function()
        return include("scripts.systems.folk_world")(Neverbirth, {
            IsValidItemId = IsValidItemId,
        })
    end)

    local laxativeCreepVariants = include("scripts.features.strong_laxative.creep_variants")

    local towerOfBabel = featureInstallation.Run("TowerOfBabel", function()
        return include("scripts.features.tower_of_babel")(Neverbirth, {
            World = folkWorld,
            TowerOfBabelId = Items.TowerOfBabel,
            GetPlayers = GetPlayers,
            CreepVariants = laxativeCreepVariants,
        })
    end)

    featureInstallation.Run("Cleaver", function()
        return include("scripts.features.cleaver")(Neverbirth, {
            World = folkWorld,
            CleaverId = Items.Cleaver,
            IsValidItemId = IsValidItemId,
            GetPlayers = GetPlayers,
        })
    end)

    featureInstallation.Run("BurnAwayResentment", function()
        return include("scripts.features.burn_away_resentment")(Neverbirth, {
            World = folkWorld,
            BurnAwayResentmentId = Items.BurnAwayResentment,
            GetPlayers = GetPlayers,
            GetPlayerHeadWorldPosition = playerGeometry.GetPlayerHeadWorldPosition,
        })
    end)

    featureInstallation.Run("TheMoonIsBeautiful", function()
        return include("scripts.features.the_moon_is_beautiful")(Neverbirth, {
            World = folkWorld,
            TheMoonIsBeautifulId = Items.TheMoonIsBeautiful,
            GetPlayers = GetPlayers,
        })
    end)

    local coinSewnSword = featureInstallation.Run("CoinSewnSword", function()
        return include("scripts.features.coin_sewn_sword")(Neverbirth, {
            World = folkWorld,
            CoinSewnSwordId = Items.CoinSewnSword,
            Log = DebugLog,
        })
    end)

    local folkVisualEffects = featureInstallation.Run("FolkVisualEffects", function()
        return include("scripts.systems.folk_visual_effects")(Neverbirth, {
            World = folkWorld,
            GetPlayers = GetPlayers,
        })
    end)

    featureInstallation.Run("StrongLaxative", function()
        return include("scripts.features.strong_laxative")(Neverbirth, {
            World = folkWorld,
            StrongLaxativeId = Items.StrongLaxative,
            IsValidItemId = IsValidItemId,
            GetPlayers = GetPlayers,
            CreepVariants = laxativeCreepVariants,
            RemoveCreepIfActive = towerOfBabel.RemoveCreepIfActive,
        })
    end)

    featureInstallation.Run("CoinSewnSwordHold", coinSewnSword.InstallHoldCallbacks)

    local coinFacedMask = featureInstallation.Run("CoinFacedMask", function()
        return include("scripts.features.coin_faced_mask")(Neverbirth, {
            World = folkWorld,
            CoinFacedMaskId = Items.CoinFacedMask,
            GetPlayers = GetPlayers,
        })
    end)

    local parasiteStore = persistence.Section("blackTaisui")

    local parasiteState = featureInstallation.Run("FolkParasiteState", function()
        return include("scripts.systems.folk_parasite_state")(Neverbirth, {
            World = folkWorld,
            GetCurrentRunSeed = GetCurrentRunSeed,
            Store = parasiteStore,
        })
    end)

    local cleansedWavyCap = featureInstallation.Run("CleansedWavyCap", function()
        return include("scripts.features.cleansed_wavy_cap")(Neverbirth, {
            World = folkWorld,
            CleansedWavyCapId = Items.CleansedWavyCap,
            GetPlayers = GetPlayers,
            GetRuntimeState = parasiteState.GetRuntimeState,
        })
    end)

    local getSurvivalCooldown = featureInstallation.Run("FolkSurvivalCooldown", function()
        return include("scripts.systems.folk_survival_cooldown")(Neverbirth)
    end)

    meatLump = featureInstallation.Run("MeatLump", function()
        return include("scripts.features.meat_lump")(Neverbirth, {
            GetSurvivalCooldown = getSurvivalCooldown,
            MeatLumpId = Items.MeatLump,
            IsValidItemId = IsValidItemId,
            GetPlayers = GetPlayers,
            IsIncomingDamageLethal = IsIncomingDamageLethal,
            GetSaveData = parasiteState.GetSaveData,
            Store = parasiteStore,
        })
    end)

    local blackTaisui = featureInstallation.Run("BlackTaisui", function()
        return include("scripts.features.black_taisui")(Neverbirth, {
            GetSurvivalCooldown = getSurvivalCooldown,
            VisualEffects = folkVisualEffects,
            World = folkWorld,
            BlackTaisuiId = Items.BlackTaisui,
            CleansedWavyCapId = Items.CleansedWavyCap,
            MeatLumpId = Items.MeatLump,
            IsValidItemId = IsValidItemId,
            GetPlayers = GetPlayers,
            IsIncomingDamageLethal = IsIncomingDamageLethal,
            Log = DebugLog,
            ParasiteState = parasiteState,
            Store = parasiteStore,
            CleansedWavyCap = cleansedWavyCap,
            MeatLump = meatLump,
        })
    end)

    featureInstallation.Run("CleansedWavyCapCallbacks", cleansedWavyCap.InstallCallbacks)

    featureInstallation.Run("BlackTaisuiLateCallbacks", blackTaisui.InstallLateCallbacks)

    local goodGirl = featureInstallation.Run("GoodGirlOfBabylon", function()
        return include("scripts.features.good_girl_of_babylon")(Neverbirth, {
            VisualEffects = folkVisualEffects,
            World = folkWorld,
            GoodGirlOfBabylonId = Items.GoodGirlOfBabylon,
            GetPlayers = GetPlayers,
            PublishGlobal = featureInstallation.PublishGlobal,
        })
    end)

    featureInstallation.Run("FolkLifecycle", function()
        return include("scripts.systems.folk_lifecycle")(Neverbirth, {
            GetPlayers = GetPlayers,
            CoinFacedMask = coinFacedMask,
            BlackTaisui = blackTaisui,
            GoodGirl = goodGirl,
        })
    end)

end

--------------------------------------------------
-- 绝育证明

featureInstallation.Run("SterilizationCertificate", function()
return include("scripts.features.sterilization_certificate")(Neverbirth, {
    ItemId = Items.SterilizationCertificate,
    GetPlayers = GetPlayers
})
end)

--------------------------------------------------
-- 空摇篮

featureInstallation.Run("EmptyCradle", function()
return include("scripts.features.empty_cradle")(Neverbirth, {
    ItemId = Items.EmptyCradle,
    GetPlayers = GetPlayers,
    GetCurrentRunSeed = GetCurrentRunSeed,
    IsBloodSkullBacklashActive = function() return bloodSkullGuModule.IsBacklashActive() end
})
end)

--------------------------------------------------
-- 天使盒 / 恶魔盒：shared helpers are constructed once; callback phases retain baseline order.
local boxQueries = include("scripts.features.boxes.shared")({ GetCurrentRunSeed = GetCurrentRunSeed })
local angelbox = include("scripts.features.boxes.angelbox")(Neverbirth, { Items = Items, Shared = boxQueries, Store = persistence.Section("angelbox"), GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, IsValidItemId = IsValidItemId, Log = DebugLog })
--------------------------------------------------
local devilbox = include("scripts.features.boxes.devilbox")(Neverbirth, { Items = Items, Shared = boxQueries, Store = persistence.Section("devilbox"), GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, IsValidItemId = IsValidItemId, Log = DebugLog })
include("scripts.features.boxes.heart_bonuses")(Neverbirth, { Shared = boxQueries, Angel = angelbox, Devil = devilbox, Log = DebugLog })
devilbox.InstallCallbacks()
include("box_deal_rooms")(Neverbirth, {
    AngelItem = Items.Angelbox,
    DevilItem = Items.Devilbox,
    GetPlayers = GetPlayers,
    GetData = persistence.Section("angelbox").Get,
    GetFloorKey = boxQueries.GetFloorKey,
    Save = persistence.Save,
    HasItem = function(player, itemId)
        return itemId == Items.Angelbox and angelbox.HasItem(player)
            or itemId == Items.Devilbox and devilbox.HasItem(player)
    end,
    WasEntered = function()
        return angelbox.WasEntered() or devilbox.WasEntered()
    end,
})

--------------------------------------------------
-- 避孕套 / 美工刀

do
local condom = include("scripts.features.condom")(Neverbirth, { Store = persistence.Section("condom"), Items = Items, GetCurrentRunSeed = GetCurrentRunSeed })
local utilityKnife = featureInstallation.Run("UtilityKnife", function()
return include("scripts.features.utility_knife")(Neverbirth, {
    ItemId = Items.UtilityKnife, GetPlayers = GetPlayers,
    GetCurrentRunSeed = GetCurrentRunSeed, Store = persistence.Section("utilityKnife"),
})
end)
local crazyCoconut = include("scripts.features.crazy_coconut")(Neverbirth, { Store = persistence.Section("crazyCoconut"), Items = Items, GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, IsValidItemId = IsValidItemId, Log = DebugLog })
include("scripts.catalog.item_config")(Neverbirth, { GetPlayers = GetPlayers })
local fortuneGu = include("scripts.features.fortune_rivalling_heaven_gu")(Neverbirth, { Items = Items, GetPlayers = GetPlayers, IsValidItemId = IsValidItemId, Log = DebugLog, GetNeedletickLuckCap = needletick.GetLuckCap })
featureInstallation.Run("MeatLumpDamage", meatLump.InstallDamageCallbacks)

featureInstallation.Run("FolkCostumes", function()
    return include("scripts.systems.folk_costumes")(Neverbirth, {})
end)

condom.InstallGameStarted()
crazyCoconut.InstallGameStarted()
condom.InstallUseCondom()
debugController.InstallUse()
featureInstallation.Run("UtilityKnife/cache", function()
    utilityKnife.InstallCache()
end)
crazyCoconut.InstallEvaluateCrazyCoconut()
fortuneGu.InstallEvaluateFortuneRivallingHeavenGu()
featureInstallation.Run("UtilityKnife/update", function()
    utilityKnife.InstallUpdate()
end)
crazyCoconut.InstallTrackCrazyCoconutCopies()
fortuneGu.InstallTrackFortuneRivallingHeavenGuLuckSources()
fortuneGu.InstallEvaluateFortuneCustomCache()
fortuneGu.InstallResetFortuneLuckRuntime()
fortuneGu.InstallInvalidateFortuneLuck()
fortuneGu.InstallOnFortunePlayerInit()
fortuneGu.InstallOnFortuneCollectibleAdded()
fortuneGu.InstallOnFortuneCollectibleRemoved()
fortuneGu.InstallOnFortuneTrinketAdded()
fortuneGu.InstallOnFortuneTrinketRemoved()
featureInstallation.Run("MeatLumpTracking", meatLump.InstallTrackingCallback)
debugController.InstallUpdate()
pickupBanners.InstallUpdate()

if ModCallbacks.MC_POST_RENDER then
    debugController.InstallRender()
end

if ModCallbacks.MC_POST_FIRE_TEAR then
    debugController.InstallTear()
end

if ModCallbacks.MC_POST_NEW_LEVEL then
    debugController.InstallLevel()
end

if ModCallbacks.MC_POST_GAME_STARTED then
    debugController.InstallGameStarted()
    pickupBanners.InstallReset()
end

if ModCallbacks.MC_POST_PICKUP_INIT then
    condom.InstallPickupInit()
end

if ModCallbacks.MC_POST_PICKUP_MORPH then
    condom.InstallPickupMorph()
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    featureInstallation.Run("UtilityKnife/pickup", function()
    utilityKnife.InstallPickup()
    end)
end

if ModCallbacks.MC_PRE_PICKUP_COLLISION then
    crazyCoconut.InstallHandleCrazyCoconutCollectiblePickup()
    pickupBanners.InstallPickup()
end


featureInstallation.Run("MeatLumpCollectibles", meatLump.InstallCollectibleCallbacks)
end

--------------------------------------------------
-- 骰子套装回调登记放在文件末尾，避免影响现有主动道具测试按顺序取回调。

diceSet.InstallCallbacks();

-- LITTLE_LEATHER_SHOES_BEGIN
local trafficRewards = include("scripts.features.little_leather_shoes.init")(Neverbirth, { Items = Items, Store = persistence.Section("littleLeatherShoes"), GetPlayers = GetPlayers, IsValidItemId = IsValidItemId, Log = DebugLog })
-- LITTLE_LEATHER_SHOES_END

-- CERTIFICATE_OF_NEVERBIRTH_BEGIN
-- Resolve the peer at event time; each bootstrap owns exactly one carrier pair.
local certificateCarrier, houseCarrier
certificateCarrier = include("scripts.features.certificate_of_neverbirth")(Neverbirth, {
    Store = persistence.Section("certificateOfNeverbirth"), Items = Items, GetPlayers = GetPlayers,
    GetCurrentRunSeed = GetCurrentRunSeed, Log = DebugLog,
    GetHouseCarrier = function() return houseCarrier end,
})
-- CERTIFICATE_OF_NEVERBIRTH_END
-- HOUSE_VS_ELEPHANT_BEGIN
houseCarrier = include("scripts.features.house_vs_elephant")(Neverbirth, {
    Store = persistence.Section("houseVsElephant"), Items = Items, GetPlayers = GetPlayers,
    GetCurrentRunSeed = GetCurrentRunSeed, Log = DebugLog,
    GetCertificateCarrier = function() return certificateCarrier end,
})
-- HOUSE_VS_ELEPHANT_END

-- EVERCHANGING_BEGIN
include("scripts.features.everchanging")(Neverbirth, { Store = persistence.Section("everchanging"), Items = Items, GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed, IsValidItemId = IsValidItemId, Log = DebugLog })
-- EVERCHANGING_END

-- DOG_FOOD_SERIES_BEGIN
include("scripts.features.dog_food_series")(Neverbirth, {
    Items = Items, Store = persistence.Section("dogFoodSeries"),
    GetPlayers = GetPlayers, GetCurrentRunSeed = GetCurrentRunSeed,
    IsValidItemId = IsValidItemId, Log = DebugLog,
})
-- DOG_FOOD_SERIES_END

-- ACE_ANTI_CHEAT_SYSTEM_BEGIN
include("scripts.features.ace_anti_cheat_system")(Neverbirth, { Items = Items, GetPlayers = GetPlayers, IsValidItemId = IsValidItemId, Log = DebugLog })
-- ACE_ANTI_CHEAT_SYSTEM_END

-- YINS_CURSE_BEGIN
local initializeYinsCurse = include("yins_curse")
initializeYinsCurse(Neverbirth, {
    ItemId = Items.YinsCurse,
    GetSaveRoot = persistence.Scope("yinCurse").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- YINS_CURSE_END

-- BIG_DOG_BARK_BEGIN
local initializeBigDogBark = include("big_dog_bark")
initializeBigDogBark(Neverbirth, {
    ItemIds = {
        BigDogBark = Items.BigDogBark,
        WindChargeRod = Items.WindChargeRod,
        EchoShard = Items.EchoShard,
    },
    PillName = "Wind Charge Potion",
    Variants = {
        Dog = 3017,
        Echo = 3018,
        Trail = 3019,
    },
    GetSaveRoot = persistence.Scope("bigDogBark").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    GetCollectibleConfig = function(itemId)
        return Neverbirth:GetCollectibleConfig(itemId)
    end,
    DebugLog = DebugLog,
})
-- BIG_DOG_BARK_END

-- REVIVE_MY_LOVE_BEGIN
local initializeReviveMyLove = include("revive_my_love")
initializeReviveMyLove(Neverbirth, {
    ItemId = Items.ReviveMyLove,
    EffectVariant = 3020,
    IsFailureDeath = function(player)
        return Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.IsFailureDeath(player)
    end,
    GetSaveRoot = persistence.Scope("reviveMyLove").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    DebugLog = DebugLog,
})
-- REVIVE_MY_LOVE_END

-- NIGHT_OF_THE_COWARDS_BEGIN
local initializeNightOfTheCowards = include("night_of_the_cowards")
initializeNightOfTheCowards(Neverbirth, {
    ItemId = Items.NightOfTheCowards,
    AuraVariant = (EffectVariant and EffectVariant.HALO) or 123,
    AuraSubtype = 3,
    FlightItemId = (CollectibleType and CollectibleType.COLLECTIBLE_TRANSCENDENCE) or 20,
    GetPlayers = GetPlayers,
    GetSaveRoot = persistence.Scope("nightOfTheCowards").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    DebugLog = DebugLog,
})
-- NIGHT_OF_THE_COWARDS_END

-- ANNIHILATION_BEGIN
-- AVADA_KEDAVRA_BEGIN: shared per-owner guards are available to other modules.
include("avada_kedavra")(Neverbirth, {
    ItemId = Items.AvadaKedavra,
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- AVADA_KEDAVRA_END

-- Annihilation keeps its aura; only its shooting replacement yields to Avada.
local initializeAnnihilation = include("annihilation")
initializeAnnihilation(Neverbirth, {
    ItemId = Items.Annihilation,
    Variants = {
        Aura = 3022,
        Shockwave = 3023,
        Activate = 3024,
    },
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- ANNIHILATION_END

-- KAMIKAZE_SQUAD_BEGIN
if include then
    local initializeKamikazeSquad = include("kamikaze_squad")
    initializeKamikazeSquad(Neverbirth, {
        ItemId = Items.KamikazeSquad,
        GetPlayers = GetPlayers,
        DebugLog = DebugLog,
    })
end
-- KAMIKAZE_SQUAD_END

-- MEMORY_DISORDER_BEGIN
local initializeMemoryDisorder = include("memory_disorder")
initializeMemoryDisorder(Neverbirth, {
    ItemId = Items.MemoryDisorder,
    GetSaveRoot = persistence.Scope("memoryDisorder").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    GetCollectibleConfigs = function()
        local itemConfig = Isaac.GetItemConfig()
        return itemConfig and itemConfig:GetCollectibles() or {}
    end,
    Darken = include("scripts.runtime.world_feedback").Darken,
    DebugLog = DebugLog,
})
-- MEMORY_DISORDER_END

-- RING_OF_THE_SEVEN_CURSES_BEGIN
include("ring_of_the_seven_curses")(Neverbirth, {
    ItemId = Items.RingOfSevenCurses,
    TrinketId = (Isaac.GetTrinketIdByName and Isaac.GetTrinketIdByName("Seven Curses Slot Seal")) or -1,
    GetSaveRoot = persistence.Scope("ringOfSevenCurses").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- RING_OF_THE_SEVEN_CURSES_END

-- HEALTHY_SLEEP_BEGIN
include("healthy_sleep")(Neverbirth, {
    ItemId = Items.HealthySleep,
    GetSaveRoot = persistence.Scope("healthySleep").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- HEALTHY_SLEEP_END

-- I_AM_A_GOD_BEGIN
include("i_am_a_god")(Neverbirth, {
    ItemId = Items.IAmAGod,
    GetSaveRoot = persistence.Scope("iAmAGod").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    GetPlayerHeadWorldPosition = playerGeometry.GetPlayerHeadWorldPosition,
    DebugLog = DebugLog,
})
-- I_AM_A_GOD_END

-- GOD_COMPLEX_BEGIN
include("god_complex")(Neverbirth, {
    ShootingControls = shootingControls,
    ItemId = Items.GodComplex,
    GetSaveRoot = persistence.Scope("godComplex").GetRoot,
    Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- GOD_COMPLEX_END

-- PENDING_CONTENT_COMPLETION_BEGIN
local acquisitionState = include("scripts.systems.acquisition_state")(Neverbirth, {
    GetSaveRoot = persistence.Scope({"pendingContent", "pendingContentHourglass"}).GetRoot,
    Identity = playerIdentity, Save = persistence.Save,
    GetCurrentRunSeed = GetCurrentRunSeed, GetPlayers = GetPlayers, DebugLog = DebugLog,
})
local pendingContent = include("pending_content_integration")(Neverbirth, {
    Items = Items, EIDDescriptions = EID_DESCRIPTIONS,
    State = acquisitionState,
    SaveScopes = {
        DivineLeftHand = persistence.Scope("divineLeftHand"),
        EchoBaby = persistence.Scope("echoBaby"),
        LowGrade = persistence.Scope("lowGrade"),
    },
    Save = persistence.Save, GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers, DebugLog = DebugLog,
})
-- PENDING_CONTENT_COMPLETION_END
trafficRewards.BindAcquisitions(acquisitionState)

-- BLINKY_BEGIN
include("blinky")(Neverbirth, {
    ItemId=Items.Blinky, State=acquisitionState,
    GetSelector=function() return pendingContent.Selector end,
    GetSaveRoot = persistence.Scope("blinky").GetRoot,
    Save=persistence.Save, GetCurrentRunSeed=GetCurrentRunSeed,
    GetPlayers=GetPlayers, DebugLog=DebugLog,
})
-- BLINKY_END

-- BOMB_SUIT_BEGIN
include("bomb_suit")(Neverbirth, {
    ShootingControls = shootingControls,
    ItemId = Items.BombSuit,
    GetPlayers = GetPlayers,
    GetPlayerHeadWorldPosition = playerGeometry.GetPlayerHeadWorldPosition,
    DebugLog = DebugLog,
})
-- BOMB_SUIT_END

-- DRIVE_GLOVE_BEGIN
include("drive_glove")(Neverbirth, {
    ShootingControls = shootingControls,
    ItemId = Items.DriveGlove,
    IsInventoryBlocking = function(player) return pendingContent.Selector.IsBlocking(player) end,
    Key = playerIdentity.InventoryPlayerKey,
    GetSaveRoot = persistence.Scope("driveGlove").GetRoot,
    Save = persistence.Save, GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers, DebugLog = DebugLog,
    IncomingDamageMultiplier = function(player) return Neverbirth:GetRingOfSevenCursesIncomingDamageMultiplier(player) end,
})
-- DRIVE_GLOVE_END

-- MOTION_INPUT_BEGIN
local motionInput = include("motion_input")(Neverbirth, {
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- MOTION_INPUT_END

-- MOTION_PRESENTATION_BEGIN
local motionPresentation = include("motion_presentation")(Neverbirth, {
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- MOTION_PRESENTATION_END

-- MOTION_ITEMS_BEGIN
local motionCombat = include("motion_combat")(Neverbirth, {
    Input = motionInput, Presentation = motionPresentation,
    GetSaveRoot = persistence.Scope({"motionCombat", "motionCombatHourglass"}).GetRoot,
    Save = persistence.Save, GetCurrentRunSeed = GetCurrentRunSeed,
    GetPlayers = GetPlayers, Key = playerIdentity.InventoryPlayerKey,
    DebugLog = DebugLog,
})
include("motion_items")(Neverbirth, {
    Input = motionInput, Presentation = motionPresentation, Combat = motionCombat,
    Items = Items,
    GetPlayers = GetPlayers,
    DebugLog = DebugLog,
})
-- MOTION_ITEMS_END

-- DANTE_CHARACTER_BEGIN
-- Custom characters are temporarily disabled; do not load their gameplay or visual callbacks.
-- dante_character.lua and its assets are retained for possible future use.
-- DANTE_CHARACTER_END

end) -- Whole-entry transaction: no partially installed gameplay after a load failure.

-- Publish optional external descriptions only after gameplay installation commits.
eidIntegration.Publish()
