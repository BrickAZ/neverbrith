-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local Store = assert(dependencies.Store)
local GetPlayers = assert(dependencies.GetPlayers)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
local IsValidItemId = assert(dependencies.IsValidItemId)
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

    if type(Store.Get()) ~= "table" or Store.Get().runSeed ~= GetCurrentRunSeed() then
        Store.Replace({
            runSeed = GetCurrentRunSeed(),
            players = {},
        })
    end

    if type(Store.Get().players) ~= "table" then
        Store.Get().players = {}
    end

    return Store.Get()
end

local function ResetDiceSetDataForRun()

    Store.Replace({
        runSeed = GetCurrentRunSeed(),
        players = {},
    })
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

    Store.Save()
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
function callbackInstallers.Neverbirth_TrackDiceSetPickup()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.TrackDiceSetPickup)
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
function callbackInstallers.Neverbirth_TrackHeldDiceItems()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackHeldDiceItems)
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
function callbackInstallers.Neverbirth_RecordDiceSetPreUse()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_USE_ITEM, Neverbirth.RecordDiceSetPreUse)
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
function callbackInstallers.Neverbirth_HandleDiceSetUse()
    return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.HandleDiceSetUse)
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
function callbackInstallers.Neverbirth_EvaluateDiceSetStatProtection()
    return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateDiceSetStatProtection)
end

function Neverbirth:UpdateDiceSetPendingState()
    for playerKey, pending in pairs(diceSetStatProtectionPending) do
        pending.timer = (tonumber(pending.timer) or 0) - 1
        if pending.timer <= 0 then
            diceSetStatProtectionPending[playerKey] = nil
        end
    end
end
function callbackInstallers.Neverbirth_UpdateDiceSetPendingState()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateDiceSetPendingState)
end

function Neverbirth:ResetDiceSetState(isContinued)
    if isContinued then
        GetDiceSetData()
        return
    end

    ResetDiceSetDataForRun()
    Store.Save()
end
function callbackInstallers.Neverbirth_ResetDiceSetState()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetDiceSetState)
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

    return "Dice Set", "Fate can no longer set you back"
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
function callbackInstallers.Neverbirth_TryRegisterDiceSetEIDModifier()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TryRegisterDiceSetEIDModifier)
end


return { InstallCallbacks = function()
if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    callbackInstallers.Neverbirth_TrackDiceSetPickup()
end

if ModCallbacks.MC_PRE_USE_ITEM then
    callbackInstallers.Neverbirth_RecordDiceSetPreUse()
end

callbackInstallers.Neverbirth_HandleDiceSetUse()
callbackInstallers.Neverbirth_EvaluateDiceSetStatProtection()
callbackInstallers.Neverbirth_TrackHeldDiceItems()
callbackInstallers.Neverbirth_UpdateDiceSetPendingState()
callbackInstallers.Neverbirth_TryRegisterDiceSetEIDModifier()

if ModCallbacks.MC_POST_GAME_STARTED then
    callbackInstallers.Neverbirth_ResetDiceSetState()
end

end }
end
