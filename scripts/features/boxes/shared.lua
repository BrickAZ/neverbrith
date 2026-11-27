-- Shared world, charge-slot and reward selection queries for the two boxes.
return function(dependencies)
local WorldQueries = include("scripts.runtime.world_queries")
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
local ANGELBOX_REWARD_SEED_STEP = 7919
local ANGELBOX_REWARD_ATTEMPTS = 120
local ANGELBOX_NULL_ITEM = (CollectibleType and CollectibleType.COLLECTIBLE_NULL) or 0
local ANGELBOX_COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local ANGELBOX_HEART_VARIANT = (PickupVariant and PickupVariant.PICKUP_HEART) or 10
local ANGELBOX_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local BuildActiveSlots = include("scripts.systems.active_slots")
local function BuildAngelboxActiveSlots()
    return BuildActiveSlots()
end

local ANGELBOX_ACTIVE_SLOTS = BuildAngelboxActiveSlots()

local function GetAngelboxGame()
    return WorldQueries.TryGame()
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
    return WorldQueries.RunFloorKey(GetAngelboxLevel(), GetCurrentRunSeed)
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

local function IsAngelboxRewardAlreadySelected(selectedItems, itemId)
    return selectedItems and selectedItems[itemId] == true
end

local function GetAngelboxRewardSeed(baseSeed, rewardIndex, attempt)
    return (tonumber(baseSeed) or 0) + (tonumber(rewardIndex) or 1) * 1000003 + attempt * ANGELBOX_REWARD_SEED_STEP
end

local createCharge = include("scripts.features.boxes.active_charge")
local createRewardSelector = include("scripts.features.boxes.reward_selection")({
    GetGame = GetAngelboxGame,
    GetRoom = GetAngelboxRoom,
    IsCollectibleQuality = IsCollectibleQuality,
    IsRewardAlreadySelected = IsAngelboxRewardAlreadySelected,
    GetRewardSeed = GetAngelboxRewardSeed,
    RewardAttempts = ANGELBOX_REWARD_ATTEMPTS,
    NullItem = ANGELBOX_NULL_ITEM,
})

return {
CreateRewardLedger = include("scripts.features.boxes.reward_ledger"),
CreateRewardDelivery = include("scripts.features.boxes.reward_delivery"),
CreateCharge = function(itemId, maxCharge) return createCharge(itemId, maxCharge, ANGELBOX_ACTIVE_SLOTS) end,
CreateRewardSelector = createRewardSelector,
ActiveSlots = ANGELBOX_ACTIVE_SLOTS,
GetGame = GetAngelboxGame,
GetLevel = GetAngelboxLevel,
GetRoom = GetAngelboxRoom,
GetFloorKey = GetAngelboxFloorKey,
GetSoulHeartRoom = GetAngelboxSoulHeartRoom,
IsCollectibleQuality = IsCollectibleQuality,
IsRewardAlreadySelected = IsAngelboxRewardAlreadySelected,
GetRewardSeed = GetAngelboxRewardSeed,
PickupEntity = ANGELBOX_ENTITY_PICKUP,
HeartVariant = ANGELBOX_HEART_VARIANT,
CollectibleVariant = ANGELBOX_COLLECTIBLE_VARIANT,
NullItem = ANGELBOX_NULL_ITEM,
RewardAttempts = ANGELBOX_REWARD_ATTEMPTS,
RewardSeedStep = ANGELBOX_REWARD_SEED_STEP,
}
end
