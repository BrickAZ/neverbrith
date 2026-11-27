return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local Items = dependencies.Items
local GetPlayers, GetCurrentRunSeed = dependencies.GetPlayers, dependencies.GetCurrentRunSeed
local IsValidItemId, DebugLog = dependencies.IsValidItemId, dependencies.Log
local Store = assert(dependencies.Store)
local SaveMusicboxData = Store.Save
local GetDevilboxData = Store.Get

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    local data = GetDevilboxData()
    data.players, data.pendingRewards = {}, {}
    data.enteredDevilFloors, data.appliedChanceFloors, data.forcedDevilFloors = {}, {}, {}
    SaveMusicboxData()
end } })
local GetAngelboxGame = dependencies.Shared.GetGame
local GetAngelboxLevel = dependencies.Shared.GetLevel
local GetAngelboxRoom = dependencies.Shared.GetRoom
local GetAngelboxFloorKey = dependencies.Shared.GetFloorKey
local GetAngelboxSoulHeartRoom = dependencies.Shared.GetSoulHeartRoom
local ANGELBOX_ENTITY_PICKUP = dependencies.Shared.PickupEntity
local ANGELBOX_HEART_VARIANT = dependencies.Shared.HeartVariant
local ANGELBOX_COLLECTIBLE_VARIANT = dependencies.Shared.CollectibleVariant
-- 恶魔盒

local DEVILBOX_MAX_CHARGE = 4
local DEVILBOX_DEVIL_CHANCE = -0.5
local DEVILBOX_EXTRA_BLACK_HEART_CHANCE = 80
local DEVILBOX_REWARD_QUALITY = 3
local DEVILBOX_DEVIL_POOL = (ItemPoolType and ItemPoolType.POOL_DEVIL) or 3
local DEVILBOX_ROOM_DEVIL = (RoomType and RoomType.ROOM_DEVIL) or 14
local DEVILBOX_BLACK_HEART_SUBTYPE = (HeartSubType and HeartSubType.HEART_BLACK) or 6
local DEVILBOX_FALLBACK_REWARDS = {
    278, -- Dark Bum
    292, -- Satanic Bible
    399, -- Maw of the Void
    417, -- Succubus
    462, -- Eye of Belial
    654, -- False PHD
    679, -- Lil Abaddon
}

local rewardLedger = dependencies.Shared.CreateRewardLedger({
    GetData = GetDevilboxData, GetRunSeed = GetCurrentRunSeed,
    GetFloorKey = GetAngelboxFloorKey, GetRoom = GetAngelboxRoom, GetLevel = GetAngelboxLevel,
    RoomType = DEVILBOX_ROOM_DEVIL, EnteredField = "enteredDevilFloors", LegacyChance = DEVILBOX_DEVIL_CHANCE,
    ClearChance = function(target) return target >= 0 end,
})

local function GetDevilboxPlayerRecord(player)
    return rewardLedger.PlayerRecord(player)
end

local function IsDevilboxFirstUseDone(player)
    local record = GetDevilboxPlayerRecord(player)
    return record.firstUseDone == true
end

local charge = dependencies.Shared.CreateCharge(Items.Devilbox, DEVILBOX_MAX_CHARGE)
local FindDevilboxSlot = charge.FindSlot

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

local GetDevilboxCharge, SetDevilboxCharge, AddDevilboxCharge = charge.Get, charge.Set, charge.Add

local function GetDevilboxPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function GetDevilboxPendingRewardTable()
    return rewardLedger.Pending()
end

local function CountDevilboxPendingRewards()
    return rewardLedger.Count()
end

local function HasDevilboxPendingReward()
    return rewardLedger.HasPending()
end

local function IsDevilboxCurrentRoomDevil()
    return rewardLedger.IsCurrentRoom()
end

local function IsDevilboxRoomEnteredThisFloor()
    return rewardLedger.HasEntered()
end

local function MarkDevilboxRoomEnteredThisFloor()
    return rewardLedger.MarkEntered()
end

local function MarkDevilboxRewardPending(player)
    return rewardLedger.MarkPending(player)
end

local function ClearDevilboxPendingRewards()
    return rewardLedger.ClearPending()
end

local function GetDevilboxAppliedChance(data, floorKey)
    return rewardLedger.AppliedChance(data, floorKey)
end

local function SetDevilboxChanceTarget(target)
    return rewardLedger.SetChance(target)
end

local function GetDevilboxBlackHeartValue(pickup)
    if pickup and pickup.SubType == DEVILBOX_BLACK_HEART_SUBTYPE then
        return 2
    end

    return nil
end

local SelectDevilboxReward = dependencies.Shared.CreateRewardSelector({
    Pool = DEVILBOX_DEVIL_POOL,
    Quality = DEVILBOX_REWARD_QUALITY,
    FallbackItems = DEVILBOX_FALLBACK_REWARDS,
    EmptyFallback = 118,
    FinalFallback = 278,
})

local deliverReward = dependencies.Shared.CreateRewardDelivery({
    Shared = dependencies.Shared, Ledger = rewardLedger, RoomType = DEVILBOX_ROOM_DEVIL,
    Select = SelectDevilboxReward, Log = DebugLog, Name = "Devilbox", Save = SaveMusicboxData,
})
local function TrySpawnDevilboxReward()
    return deliverReward()
end

local function ForceDevilboxDevilRoom()
    return Neverbirth.BoxDealRooms.Open(DEVILBOX_ROOM_DEVIL)
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

    if not ForceDevilboxDevilRoom() then
        return { Discharge = false, Remove = false, ShowAnim = false }
    end
    MarkDevilboxRewardPending(player)
    SetDevilboxCharge(player, slot, 0)
    SaveMusicboxData()
    TrySpawnDevilboxReward()
    return true
end
function callbackInstallers.Neverbirth_UseDevilbox()
    return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseDevilbox, Items.Devilbox)
end


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

    local accepted = AddDevilboxCharge(player, slot, chargeAmount)
    if accepted <= 0 then
        return nil
    end
    DebugLog(string.format("[neverbirth][Boxes] charge box=Devilbox slot=%d requested=%d accepted=%d health=%d", slot, chargeAmount, accepted, healthAmount))

    if healthAmount > 0 and player.AddBlackHearts then
        player:AddBlackHearts(healthAmount)
    end

    if pickup.PlayPickupSound then
        pickup:PlayPickupSound()
    end
    if pickup.Remove then
        pickup:Remove()
    end

    return true
end
function callbackInstallers.Neverbirth_HandleDevilboxBlackHeartPickup()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, Neverbirth.HandleDevilboxBlackHeartPickup, ANGELBOX_HEART_VARIANT)
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
function callbackInstallers.Neverbirth_SpawnDevilboxRewardOnNewRoom()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.SpawnDevilboxRewardOnNewRoom)
end



function Neverbirth:UpdateDevilboxDealChance()
    if SetDevilboxChanceTarget(0) then SaveMusicboxData() end
end
function callbackInstallers.Neverbirth_UpdateDevilboxDealChance()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateDevilboxDealChance)
end
function callbackInstallers.Neverbirth_UpdateDevilboxDealChance2()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.UpdateDevilboxDealChance)
end




return { HasItem = PlayerHasDevilbox, AnyHolder = AnyPlayerHasDevilbox, WasEntered = IsDevilboxRoomEnteredThisFloor, BonusChance = DEVILBOX_EXTRA_BLACK_HEART_CHANCE, HeartSubtype = DEVILBOX_BLACK_HEART_SUBTYPE, InstallCallbacks = function()
callbackInstallers.Neverbirth_UseDevilbox()
function Neverbirth:ResetDevilboxRun(isContinued)
    resetRun(self, isContinued)
end
Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetDevilboxRun)

if ModCallbacks.MC_PRE_PICKUP_COLLISION then
    callbackInstallers.Neverbirth_HandleDevilboxBlackHeartPickup()
end
if ModCallbacks.MC_POST_NEW_ROOM then
    callbackInstallers.Neverbirth_SpawnDevilboxRewardOnNewRoom()
end
callbackInstallers.Neverbirth_UpdateDevilboxDealChance()

if ModCallbacks.MC_POST_NEW_LEVEL then
    callbackInstallers.Neverbirth_UpdateDevilboxDealChance2()
end
end }
end
