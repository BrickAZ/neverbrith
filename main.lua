-- 注册模组
local Neverbirth = RegisterMod("neverbirth", 1)

local Items = {
    EssentialBalm = Isaac.GetItemIdByName("EssentialBalm"),
    Wuhu = Isaac.GetItemIdByName("Wuhu"),
    Chunyao = Isaac.GetItemIdByName("Aphrodisiac"),
    Musicbox = Isaac.GetItemIdByName("Musicbox"),
    Angelbox = Isaac.GetItemIdByName("Angelbox"),
    Devilbox = Isaac.GetItemIdByName("Devilbox"),
    DS4 = Isaac.GetItemIdByName("ds4"),
}

local DEBUG_PRINT_ITEM_IDS = true

local EID_DESCRIPTIONS = {
    [Items.EssentialBalm] = {
        Name = "风油精",
        Description = "↑ +1攻击力#↓ -0.2弹速",
        EnglishName = "Essential Balm",
        EnglishDescription = "{{Damage}} +1 damage#{{Shotspeed}} -0.2 shot speed",
    },
    [Items.Wuhu] = {
        Name = "芜湖！~",
        Description = "↑ +1移速#↑ 攻速上限达到30#↑ +40攻击力#↓ -1弹速",
        EnglishName = "Wuhu!",
        EnglishDescription = "{{Speed}} +1 speed#{{Tears}} Sets fire delay to 0#{{Damage}} +40 damage#{{Shotspeed}} -1 shot speed",
    },
    [Items.Chunyao] = {
        Name = "Chunyao",
        Description = "使用后扣除1滴完整的血#{{Warning}} 优先扣红心 #{{Warning}} 不致死#↑ +0.5攻击力#↑ +0.5攻速#角色进入魅惑状态#眼泪获得追踪效果#持续3秒",
        EnglishName = "Aphrodisiac",
        EnglishDescription = "On use, removes 1 full heart#{{Warning}} Prioritizes red hearts #{{Warning}} Cannot kill you#{{Damage}} +0.5 damage#{{Tears}} +0.5 fire rate#Charms the player#Tears become homing#Lasts 3 seconds",
    },
    [Items.Musicbox] = {
        Name = "八音盒",
        Description = "使用后角色进入20秒无敌状态，期间不会死亡且眼泪变为红色，头顶显示倒计时",
        EnglishName = "Music Box",
        EnglishDescription = "On use, grants 20 seconds of invincibility#Prevents death while active#Tears turn red#Shows a countdown above the player",
    },
    [Items.Angelbox] = {
        Name = "天使盒",
        Description = "{{Warning}} 效果尚未实现",
        EnglishName = "Angel Box",
        EnglishDescription = "{{Warning}} Effect not implemented yet",
    },
    [Items.Devilbox] = {
        Name = "恶魔盒",
        Description = "{{Warning}} 效果尚未实现",
        EnglishName = "Devil Box",
        EnglishDescription = "{{Warning}} Effect not implemented yet",
    },
    [Items.DS4] = {
        Name = "ds4",
        Description = "{{Warning}} 效果尚未实现",
        EnglishName = "ds4",
        EnglishDescription = "{{Warning}} Effect not implemented yet",
    },
}

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
            EID:addCollectible(id, item.EnglishDescription or item.Description, item.EnglishName or item.Name)
            EID:addCollectible(id, item.Description, item.Name, "zh_cn")
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
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local player = entity:ToPlayer()
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

local invincibleActive = false
local invincibleTimer = 0
local INVINCIBLE_DURATION = 20 * 30
local countdownTextEntity = nil

function Neverbirth:UseMusicbox(_, _, player)
    invincibleActive = true
    invincibleTimer = INVINCIBLE_DURATION

    countdownTextEntity = Isaac.Spawn(EntityType.ENTITY_TEXT, 0, 0, player.Position, Vector(0, 0), nil)
    countdownTextEntity:GetData().timer = INVINCIBLE_DURATION

    player.TearColor = Color(1, 0, 0, 1, 0, 0, 0)

    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseMusicbox, Items.Musicbox)

function Neverbirth:UpdateMusicbox()
    local players = Isaac.FindByType(EntityType.ENTITY_PLAYER, -1, -1, false, false)

    for _, entity in ipairs(players) do
        local player = entity:ToPlayer()

        if invincibleActive then
            if invincibleTimer > 0 then
                invincibleTimer = invincibleTimer - 1

                if countdownTextEntity and countdownTextEntity:Exists() then
                    local data = countdownTextEntity:GetData()
                    if data.timer and data.timer > 0 then
                        data.timer = data.timer - 1
                        local timeLeft = math.floor(data.timer / 30)
                        countdownTextEntity:GetSprite():SetAnimation(string.format("%d", timeLeft), false)
                        countdownTextEntity.Position = player.Position + Vector(0, -30)
                    end
                end

                player.TearColor = Color(1, 0, 0, 1, 0, 0, 0)
            else
                invincibleActive = false

                if countdownTextEntity and countdownTextEntity:Exists() then
                    countdownTextEntity:Remove()
                    countdownTextEntity = nil
                end

                player.TearColor = Color(1, 1, 1, 1, 0, 0, 0)
            end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateMusicbox)

function Neverbirth:PreventMusicboxDamage(entity)
    if entity:IsPlayer() and invincibleActive then
        local player = entity:ToPlayer()
        if player:GetHearts() <= 0 then
            player:AddHearts(1)
        end

        return false
    end

    return true
end

Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.PreventMusicboxDamage)
