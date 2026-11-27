-- Owns the complete EmptyCradle feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    local running, disposed = true, false
    local Rolls = include("scripts.systems.collectible_rng")
    local CombatSource = include("scripts.systems.combat_source")
local WorldQueries = include("scripts.runtime.world_queries")
    local Items = { EmptyCradle = assert(dependencies.ItemId) }
    local GetPlayers = assert(dependencies.GetPlayers)
    local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
    local IsBloodSkullBacklashActive = assert(dependencies.IsBloodSkullBacklashActive)

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
    return WorldQueries.TryGame()
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
    return WorldQueries.RoomIndexOrSeed(GetEmptyCradleLevel, GetEmptyCradleRoom)
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
    return CombatSource.Entity(source)
end

local function IsEmptyCradleCostDamage(flags, source)
    if IsBloodSkullBacklashActive() then
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
    if max <= 1 then return 0 end
    return Rolls.IntOrMath(Rolls.Get(player, Items.EmptyCradle, "RandomInt"), max)
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
        local game = WorldQueries.TryGame()
        if game and game.Spawn then
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
    if not running or disposed then return nil end
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
    if not running or disposed then return nil end
    for _, player in ipairs(GetPlayers()) do
        TrySettleEmptyCradleReward(player)
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateEmptyCradleRewards)

function Neverbirth:EvaluateEmptyCradle(player, cacheFlag)
    if not running or disposed then return nil end
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
    if not running or disposed then return nil end
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

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    local previous = emptyCradleStates
    emptyCradleStates = {}
    for _, player in ipairs(GetPlayers()) do
        local oldState = previous[GetEmptyCradlePlayerKey(player)]
        if oldState and (tonumber(oldState.damageBonus) or 0) ~= 0 then
            RefreshEmptyCradleDamageCache(player)
        end
    end
end } })
function Neverbirth:ResetEmptyCradleState(isContinued)
    if disposed then return end
    local resuming = not running
    running = true
    resetRun(self, isContinued)
    if isContinued and resuming then
        for _, player in ipairs(GetPlayers()) do
            local state = emptyCradleStates[GetEmptyCradlePlayerKey(player)]
            if state and (tonumber(state.damageBonus) or 0) ~= 0 then RefreshEmptyCradleDamageCache(player) end
        end
    end
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetEmptyCradleState)
end
function Neverbirth:ExitEmptyCradle()
    running = false
end
if ModCallbacks.MC_PRE_GAME_EXIT then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitEmptyCradle)
end

function Neverbirth:UnloadEmptyCradle(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    emptyCradleStates = {}
end
if ModCallbacks.MC_PRE_MOD_UNLOAD then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadEmptyCradle)
end
end

end
