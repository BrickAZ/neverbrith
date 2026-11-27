-- Owns the complete ShreddedTarot feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    local running, disposed = true, false
local WorldQueries = include("scripts.runtime.world_queries")
    local Items = { ShreddedTarot = assert(dependencies.ItemId) }
    local GetPlayers = assert(dependencies.GetPlayers)

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

local BuildActiveSlots = include("scripts.systems.active_slots")
local function BuildShreddedTarotActiveSlots()
    return BuildActiveSlots()
end

local SHREDDED_TAROT_ACTIVE_SLOTS = BuildShreddedTarotActiveSlots()

local function GetShreddedTarotGame()
    return WorldQueries.TryGame()
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
    if not running or disposed then return false end
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
    if not running or disposed then return nil end
    if CacheFlag and CacheFlag.CACHE_LUCK and cacheFlag == CacheFlag.CACHE_LUCK and PlayerHasShreddedTarot(player) then
        player.Luck = player.Luck + SHREDDED_TAROT_LUCK_BONUS
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateShreddedTarot)

function Neverbirth:TrackShreddedTarotHolders()
    if not running or disposed then return nil end
    for _, player in ipairs(GetPlayers()) do
        local playerKey = GetShreddedTarotPlayerKey(player)
        if PlayerHasShreddedTarot(player) then
            local newlyHeld = shreddedTarotStates[playerKey] == nil
            EnsureShreddedTarotState(player)
            if newlyHeld then RefreshShreddedTarotLuck(player) end
        elseif playerKey ~= "" then
            local wasHeld = shreddedTarotStates[playerKey] ~= nil
            shreddedTarotStates[playerKey] = nil
            if wasHeld then RefreshShreddedTarotLuck(player) end
        end
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.TrackShreddedTarotHolders)

function Neverbirth:RemoveUnusedShreddedTarotOnNewLevel()
    if not running or disposed then return nil end
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

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    local previous = shreddedTarotStates
    shreddedTarotStates = {}
    for _, player in ipairs(GetPlayers()) do
        if previous[GetShreddedTarotPlayerKey(player)] then RefreshShreddedTarotLuck(player) end
    end
end } })
function Neverbirth:ResetShreddedTarotState(isContinued)
    if disposed then return end
    local resuming = not running
    running = true
    resetRun(self, isContinued)
    if isContinued and resuming then
        for _, player in ipairs(GetPlayers()) do
            if shreddedTarotStates[GetShreddedTarotPlayerKey(player)] then RefreshShreddedTarotLuck(player) end
        end
    end
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetShreddedTarotState)
end
function Neverbirth:ExitShreddedTarot()
    running = false
end
if ModCallbacks.MC_PRE_GAME_EXIT then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitShreddedTarot)
end

function Neverbirth:UnloadShreddedTarot(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    shreddedTarotStates = {}
end
if ModCallbacks.MC_PRE_MOD_UNLOAD then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadShreddedTarot)
end
end

end
