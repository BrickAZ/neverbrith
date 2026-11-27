-- Owns the complete BloodSkullGu feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    local running, disposed = true, false
    local Rolls = include("scripts.systems.collectible_rng")
    local CombatSource = include("scripts.systems.combat_source")
local WorldQueries = include("scripts.runtime.world_queries")
    local Items = { BloodSkullGu = assert(dependencies.ItemId) }
    local IsValidItemId = assert(dependencies.IsValidItemId)
    local GetPlayers = assert(dependencies.GetPlayers)
    local DebugLog = assert(dependencies.Log)
    local bloodSkullGuBacklashDepth = 0

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
local BLOOD_SKULL_GU_TEMPORARY_FAMILIARS = {
    [FamiliarVariant and FamiliarVariant.BLUE_FLY or 43] = true,
    [FamiliarVariant and FamiliarVariant.BLUE_SPIDER or 73] = true,
    [FamiliarVariant and FamiliarVariant.WISP or 206] = true,
    [FamiliarVariant and FamiliarVariant.ABYSS_LOCUST or 231] = true,
}


local bloodSkullGuGrowth = {}

local BuildActiveSlots = include("scripts.systems.active_slots")
local function BuildBloodSkullGuActiveSlots()
    return BuildActiveSlots()
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
    return Rolls.Get(player, Items.BloodSkullGu, "RandomInt")
end

local function BloodSkullGuRandomInt(player, max)
    max = tonumber(max) or 1
    if max <= 1 then return 0 end
    return Rolls.IntOrMath(GetBloodSkullGuRNG(player), max)
end

local function ExtractBloodSkullGuPlayer(entity)
    return CombatSource.TryPlayer(entity)
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

local function GetEligibleBloodSkullFamiliar(entity, player)
    if not entity or entity.Type ~= BLOOD_SKULL_GU_ENTITY_FAMILIAR or IsBloodSkullGuEntityRemoved(entity) then
        return nil
    end

    local familiar
    if entity.ToFamiliar then
        local ok, converted = pcall(function()
            return entity:ToFamiliar()
        end)
        if ok and converted then
            familiar = converted
        end
    end

    if not familiar then
        return nil
    end

    if BLOOD_SKULL_GU_TEMPORARY_FAMILIARS[familiar.Variant] then
        return nil
    end

    if familiar.Player ~= nil then
        return IsBloodSkullGuSamePlayer(familiar.Player, player) and familiar or nil
    end

    if familiar.SpawnerEntity ~= nil then
        return IsBloodSkullGuSamePlayer(familiar.SpawnerEntity, player) and familiar or nil
    end

    return nil
end

local function CollectBloodSkullGuFamiliars(player)
    local familiars = {}
    if not Isaac.GetRoomEntities then
        return familiars
    end

    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        -- Keep the converted view: GetItemConfig belongs to EntityFamiliar,
        -- not the base Entity handles returned by GetRoomEntities.
        local familiar = GetEligibleBloodSkullFamiliar(entity, player)
        if familiar then
            familiars[#familiars + 1] = familiar
        end
    end

    return familiars
end

local function GetBloodSkullGuGame()
    return WorldQueries.TryGame()
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

local function FindBloodSkullGuSourceCollectible(familiar, player)
    if not familiar or not player then return nil end
    -- REPENTOGON 1.0.12a records the actual granting ItemConfig on the familiar.
    -- A nil source is meaningful (e.g. a non-item summon); never guess by variant.
    local ok, config = pcall(function() return familiar:GetItemConfig() end)
    local itemId = ok and config and config.ID or nil
    if PlayerHasBloodSkullGuCollectible(player, itemId) then return itemId end
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
    if not running or disposed then return false end
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
    if not running or disposed then return nil end
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

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    local previous = bloodSkullGuGrowth
    bloodSkullGuGrowth = {}
    for _, player in ipairs(GetPlayers()) do
        if previous[GetBloodSkullGuPlayerKey(player)] then
            RefreshBloodSkullGuCache(player)
        end
    end
end } })
function Neverbirth:ResetBloodSkullGuState(isContinued)
    if disposed then return end
    local resuming = not running
    running = true
    resetRun(self, isContinued)
    if isContinued and resuming then
        for _, player in ipairs(GetPlayers()) do
            if bloodSkullGuGrowth[GetBloodSkullGuPlayerKey(player)] then RefreshBloodSkullGuCache(player) end
        end
    end
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetBloodSkullGuState)
end
function Neverbirth:ExitBloodSkullGu()
    running = false
end
if ModCallbacks.MC_PRE_GAME_EXIT then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitBloodSkullGu)
end

function Neverbirth:UnloadBloodSkullGu(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    bloodSkullGuGrowth, bloodSkullGuBacklashDepth = {}, 0
end
if ModCallbacks.MC_PRE_MOD_UNLOAD then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadBloodSkullGu)
end
end

    return { IsBacklashActive = function() return bloodSkullGuBacklashDepth > 0 end }
end
