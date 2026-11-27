return function(Neverbirth, dependencies)
local Items = dependencies.Items
local GetPlayers, GetCurrentRunSeed = dependencies.GetPlayers, dependencies.GetCurrentRunSeed
local IsValidItemId, DebugLog = dependencies.IsValidItemId, dependencies.Log
local Store = assert(dependencies.Store)
local SaveMusicboxData = Store.Save
local GetAngelboxData = Store.Get

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    local data = GetAngelboxData()
    data.players, data.pendingRewards = {}, {}
    data.enteredAngelFloors, data.appliedChanceFloors, data.forcedAngelFloors = {}, {}, {}
    SaveMusicboxData()
end } })
function Neverbirth:ResetAngelboxRun(isContinued)
    resetRun(self, isContinued)
end
Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetAngelboxRun)

local GetAngelboxGame = dependencies.Shared.GetGame
local GetAngelboxLevel = dependencies.Shared.GetLevel
local GetAngelboxRoom = dependencies.Shared.GetRoom
local GetAngelboxFloorKey = dependencies.Shared.GetFloorKey
local GetAngelboxSoulHeartRoom = dependencies.Shared.GetSoulHeartRoom
local ANGELBOX_ENTITY_PICKUP = dependencies.Shared.PickupEntity
local ANGELBOX_HEART_VARIANT = dependencies.Shared.HeartVariant
local ANGELBOX_COLLECTIBLE_VARIANT = dependencies.Shared.CollectibleVariant
-- 天使盒

local ANGELBOX_MAX_CHARGE = 4
local ANGELBOX_ANGEL_CHANCE = 0.5
local ANGELBOX_LUCK_BONUS = 3
local ANGELBOX_EXTRA_SOUL_HEART_CHANCE = 60
local ANGELBOX_REWARD_QUALITY = 4
local ANGELBOX_ANGEL_POOL = (ItemPoolType and ItemPoolType.POOL_ANGEL) or 4
local ANGELBOX_SOUL_HEART_SUBTYPE = (HeartSubType and HeartSubType.HEART_SOUL) or 3
local ANGELBOX_ROOM_ANGEL = (RoomType and RoomType.ROOM_ANGEL) or 15
local ANGELBOX_FALLBACK_REWARDS = {
    331, -- Godhead
    643, -- Revelation
    415, -- Crown of Light
    691, -- Sacred Orb
    313, -- Holy Mantle
    180, -- The Wafer
    182, -- Sacred Heart
}

local rewardLedger = dependencies.Shared.CreateRewardLedger({
    GetData = GetAngelboxData, GetRunSeed = GetCurrentRunSeed,
    GetFloorKey = GetAngelboxFloorKey, GetRoom = GetAngelboxRoom, GetLevel = GetAngelboxLevel,
    RoomType = ANGELBOX_ROOM_ANGEL, EnteredField = "enteredAngelFloors", LegacyChance = ANGELBOX_ANGEL_CHANCE,
    ClearChance = function(target) return target <= 0 end,
})

local function GetAngelboxPlayerRecord(player)
    return rewardLedger.PlayerRecord(player)
end

local function IsAngelboxFirstUseDone(player)
    local record = GetAngelboxPlayerRecord(player)
    return record.firstUseDone == true
end

local charge = dependencies.Shared.CreateCharge(Items.Angelbox, ANGELBOX_MAX_CHARGE)
local FindAngelboxSlot = charge.FindSlot

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

local GetAngelboxCharge, SetAngelboxCharge, AddAngelboxCharge = charge.Get, charge.Set, charge.Add

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
    return rewardLedger.Pending()
end

local function CountAngelboxPendingRewards()
    return rewardLedger.Count()
end

local function HasAngelboxPendingReward()
    return rewardLedger.HasPending()
end

local function IsAngelboxCurrentRoomAngel()
    return rewardLedger.IsCurrentRoom()
end

local function IsAngelboxRoomEnteredThisFloor()
    return rewardLedger.HasEntered()
end

local function MarkAngelboxRoomEnteredThisFloor()
    return rewardLedger.MarkEntered()
end

local function MarkAngelboxRewardPending(player)
    return rewardLedger.MarkPending(player)
end

local function ClearAngelboxPendingRewards()
    return rewardLedger.ClearPending()
end

local function GetAngelboxAppliedChance(data, floorKey)
    return rewardLedger.AppliedChance(data, floorKey)
end

local function SetAngelboxChanceTarget(target)
    return rewardLedger.SetChance(target)
end

local SelectAngelboxReward = dependencies.Shared.CreateRewardSelector({
    Pool = ANGELBOX_ANGEL_POOL,
    Quality = ANGELBOX_REWARD_QUALITY,
    FallbackItems = ANGELBOX_FALLBACK_REWARDS,
    EmptyFallback = 182,
    FinalFallback = 182,
})

local deliverReward = dependencies.Shared.CreateRewardDelivery({
    Shared = dependencies.Shared, Ledger = rewardLedger, RoomType = ANGELBOX_ROOM_ANGEL,
    Select = SelectAngelboxReward, Log = DebugLog, Name = "Angelbox", Save = SaveMusicboxData,
})
local function TrySpawnAngelboxReward()
    return deliverReward()
end

local function ForceAngelboxAngelRoom()
    return Neverbirth.BoxDealRooms.Open(ANGELBOX_ROOM_ANGEL)
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

    if not ForceAngelboxAngelRoom() then
        return { Discharge = false, Remove = false, ShowAnim = false }
    end
    MarkAngelboxRewardPending(player)
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

    -- Do not heal or consume the pickup if the native charge transaction declined.
    local accepted = AddAngelboxCharge(player, slot, chargeAmount)
    if accepted <= 0 then
        return nil
    end
    DebugLog(string.format("[neverbirth][Boxes] charge box=Angelbox slot=%d requested=%d accepted=%d health=%d", slot, chargeAmount, accepted, healthAmount))

    if healthAmount > 0 and player.AddSoulHearts then
        player:AddSoulHearts(healthAmount)
    end

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
    -- Undo only the legacy contribution recorded by this mod.
    if SetAngelboxChanceTarget(0) then SaveMusicboxData() end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateAngelboxDealChance)

if ModCallbacks.MC_POST_NEW_LEVEL then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.UpdateAngelboxDealChance)
end

return { HasItem = PlayerHasAngelbox, AnyHolder = AnyPlayerHasAngelbox, WasEntered = IsAngelboxRoomEnteredThisFloor, BonusChance = ANGELBOX_EXTRA_SOUL_HEART_CHANCE, HeartSubtype = ANGELBOX_SOUL_HEART_SUBTYPE }
end
