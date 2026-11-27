-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
    local running, disposed = true, false
    local gameStartObserved, pendingNpcScan = false, false
    local CombatSource = include("scripts.systems.combat_source")
local WorldQueries = include("scripts.runtime.world_queries")
local Store = assert(dependencies.Store)
local Items = assert(dependencies.Items)
local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
local IsValidItemId = assert(dependencies.IsValidItemId)
local DebugLog = assert(dependencies.Log)
local function ResetDeathTrialDataForRun()
    local data = Store.Get()
    if type(data) ~= "table" then data = {} end
    data.active, data.runSeed = false, GetCurrentRunSeed()
    data.activatedFloorKey, data.activatedRoomKey = nil, nil
    data.spawnedByFloor, data.preActivationBossClearedFloors = {}, {}
    Store.Replace(data)
    return Store.Get()
end

local function GetDeathTrialData()


    local data = Store.Get()
    if type(data) ~= "table" or data.runSeed ~= GetCurrentRunSeed() then
        data = ResetDeathTrialDataForRun()
    end

    if type(data.spawnedByFloor) ~= "table" then
        data.spawnedByFloor = {}
    end

    if type(data.preActivationBossClearedFloors) ~= "table" then
        data.preActivationBossClearedFloors = {}
    end

    return data
end

local BETWEEN_DEATH_LIFE_MAX_CHARGE = 12
local BETWEEN_DEATH_LIFE_ACTIVE_SLOTS = {
    ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0,
    ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1,
    ActiveSlot and ActiveSlot.SLOT_POCKET or 2,
    ActiveSlot and ActiveSlot.SLOT_POCKET2 or 3,
}
local BETWEEN_DEATH_LIFE_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local BETWEEN_DEATH_LIFE_COLLECTIBLE_VARIANT = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
local BETWEEN_DEATH_LIFE_ROOM_BOSS = (RoomType and RoomType.ROOM_BOSS) or 5
local BETWEEN_DEATH_LIFE_DEATH_CERTIFICATE = (CollectibleType and CollectibleType.COLLECTIBLE_DEATH_CERTIFICATE) or nil
local BETWEEN_DEATH_LIFE_CHAMPION_COLOR = -1
local BETWEEN_DEATH_LIFE_NORMAL_HP_MULTIPLIER = 1.35
local BETWEEN_DEATH_LIFE_BOSS_HP_MULTIPLIER = 1.5
local BETWEEN_DEATH_LIFE_NORMAL_SPEED_MULTIPLIER = 1.05
local BETWEEN_DEATH_LIFE_BOSS_SPEED_MULTIPLIER = 1.08
local betweenDeathLifeDeathCertificateId = nil

local function GetBetweenDeathLifeGame()
    return WorldQueries.TryGame()
end

local function AwaitingGameStart()
    if gameStartObserved then return false end
    local game = GetBetweenDeathLifeGame()
    return game and game.GetFrameCount and game:GetFrameCount() == 0
end

local function GetBetweenDeathLifeLevel()
    local game = GetBetweenDeathLifeGame()
    return game and game.GetLevel and game:GetLevel() or nil
end

local function GetBetweenDeathLifeRoom()
    local game = GetBetweenDeathLifeGame()
    return game and game.GetRoom and game:GetRoom() or nil
end

local function GetBetweenDeathLifeFloorKey()
    return WorldQueries.RunFloorKey(GetBetweenDeathLifeLevel(), GetCurrentRunSeed)
end

local function GetBetweenDeathLifeRoomKey()
    local level = GetBetweenDeathLifeLevel()
    local room = GetBetweenDeathLifeRoom()
    local roomIndex = nil

    if level and level.GetCurrentRoomIndex then
        local ok, index = pcall(function()
            return level:GetCurrentRoomIndex()
        end)
        if ok then
            roomIndex = index
        end
    end

    if roomIndex == nil and room and room.GetSpawnSeed then
        local ok, seed = pcall(function()
            return room:GetSpawnSeed()
        end)
        if ok then
            roomIndex = "seed:" .. tostring(seed)
        end
    end

    return GetBetweenDeathLifeFloorKey() .. ":" .. tostring(roomIndex or "unknown")
end

local function FindBetweenDeathLifeSlot(player, preferredSlot)
    if not player or not player.GetActiveItem then
        return nil
    end

    if preferredSlot ~= nil and player:GetActiveItem(preferredSlot) == Items.BetweenDeathAndLife then
        return preferredSlot
    end

    for _, slot in ipairs(BETWEEN_DEATH_LIFE_ACTIVE_SLOTS) do
        if player:GetActiveItem(slot) == Items.BetweenDeathAndLife then
            return slot
        end
    end

    return nil
end

local function GetBetweenDeathLifeCharge(player, slot)
    if player and player.GetActiveCharge then
        local ok, charge = pcall(function()
            return player:GetActiveCharge(slot)
        end)
        if ok then
            return tonumber(charge) or 0
        end
    end

    return BETWEEN_DEATH_LIFE_MAX_CHARGE
end

local function RemoveBetweenDeathLifeItem(player, slot)
    if player and player.RemoveCollectible then
        local ok, err = pcall(function()
            player:RemoveCollectible(Items.BetweenDeathAndLife, false, slot or FindBetweenDeathLifeSlot(player) or 0, true)
        end)
        if not ok then
            DebugLog("[neverbirth] Between Death and Life removal failed: " .. tostring(err))
        end
    elseif player and player.SetActiveCharge then
        player:SetActiveCharge(0, slot or 0)
    end
end

local function IsBetweenDeathLifeBossRoomClear()
    local room = GetBetweenDeathLifeRoom()
    if not room or not room.GetType or not room.IsClear then
        return false
    end

    local okType, roomType = pcall(function()
        return room:GetType()
    end)
    local okClear, isClear = pcall(function()
        return room:IsClear()
    end)

    return okType and okClear and roomType == BETWEEN_DEATH_LIFE_ROOM_BOSS and isClear == true
end

local function GetBetweenDeathLifeDeathCertificateId()
    if IsValidItemId(betweenDeathLifeDeathCertificateId) then
        return betweenDeathLifeDeathCertificateId
    end

    if IsValidItemId(BETWEEN_DEATH_LIFE_DEATH_CERTIFICATE) then
        betweenDeathLifeDeathCertificateId = BETWEEN_DEATH_LIFE_DEATH_CERTIFICATE
        return betweenDeathLifeDeathCertificateId
    end

    if Isaac.GetItemIdByName then
        local ok, itemId = pcall(function()
            return Isaac.GetItemIdByName("Death Certificate")
        end)
        if ok and IsValidItemId(itemId) then
            betweenDeathLifeDeathCertificateId = itemId
            return betweenDeathLifeDeathCertificateId
        end
    end

    return nil
end

local function SpawnBetweenDeathLifeDeathCertificate()
    local deathCertificateId = GetBetweenDeathLifeDeathCertificateId()
    if not IsValidItemId(deathCertificateId) then
        DebugLog("[neverbirth] Death Certificate id not found for Between Death and Life")
        return false
    end

    local room = GetBetweenDeathLifeRoom()
    local position = room and room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
    if room and room.FindFreePickupSpawnPosition then
        position = room:FindFreePickupSpawnPosition(position, 40, true, false)
    end

    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    local seed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0
    local game = GetBetweenDeathLifeGame()

    if game and game.Spawn then
        game:Spawn(BETWEEN_DEATH_LIFE_ENTITY_PICKUP, BETWEEN_DEATH_LIFE_COLLECTIBLE_VARIANT, position, velocity, nil, deathCertificateId, seed + 628)
        return true
    elseif Isaac.Spawn then
        Isaac.Spawn(BETWEEN_DEATH_LIFE_ENTITY_PICKUP, BETWEEN_DEATH_LIFE_COLLECTIBLE_VARIANT, deathCertificateId, position, velocity, nil, seed + 628)
        return true
    end

    return false
end

local function IsBetweenDeathLifeEntityRemoved(entity)
    if not entity then
        return true
    end

    if entity.Exists then
        local ok, exists = pcall(function()
            return entity:Exists()
        end)
        if ok and exists == false then
            return true
        end
    end

    if entity.IsDead then
        local ok, dead = pcall(function()
            return entity:IsDead()
        end)
        if ok and dead then
            return true
        end
    end

    return entity.removed == true
end

local function GetBetweenDeathLifeNpcData(npc)
    if npc and npc.GetData then
        local ok, data = pcall(function()
            return npc:GetData()
        end)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

local function IsBetweenDeathLifeBoss(npc)
    if not npc or not npc.IsBoss then
        return false
    end

    local ok, isBoss = pcall(function()
        return npc:IsBoss()
    end)
    return ok and isBoss == true
end

local function IsBetweenDeathLifeChampion(npc)
    if not npc or not npc.IsChampion then
        return false
    end

    local ok, isChampion = pcall(function()
        return npc:IsChampion()
    end)
    return ok and isChampion == true
end

local function IsBetweenDeathLifeEligibleNpc(entity)
    if not entity or IsBetweenDeathLifeEntityRemoved(entity) then
        return false
    end

    local npc = entity
    if entity.ToNPC then
        local ok, converted = pcall(function()
            return entity:ToNPC()
        end)
        if ok and converted then
            npc = converted
        end
    end

    if not npc then
        return false
    end

    if CombatSource.TryPlayer(npc) then return false end

    if npc.HasEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
        local ok, friendly = pcall(function()
            return npc:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
        end)
        if ok and friendly then
            return false
        end
    end

    if npc.IsVulnerableEnemy then
        local ok, vulnerable = pcall(function()
            return npc:IsVulnerableEnemy()
        end)
        if ok and vulnerable == false then
            return false
        end
    end

    return true
end

local function TryBetweenDeathLifeMakeChampion(npc)
    if not npc or not npc.MakeChampion or IsBetweenDeathLifeChampion(npc) then
        return false
    end

    local room = GetBetweenDeathLifeRoom()
    local seed = npc.InitSeed or (room and room.GetSpawnSeed and room:GetSpawnSeed()) or 0
    local ok = pcall(function()
        npc:MakeChampion(seed, BETWEEN_DEATH_LIFE_CHAMPION_COLOR, true)
    end)

    return ok and IsBetweenDeathLifeChampion(npc)
end

local function EmpowerBetweenDeathLifeNpc(npc)
    local isBoss = IsBetweenDeathLifeBoss(npc)
    local hpMultiplier = isBoss and BETWEEN_DEATH_LIFE_BOSS_HP_MULTIPLIER or BETWEEN_DEATH_LIFE_NORMAL_HP_MULTIPLIER
    local speedMultiplier = isBoss and BETWEEN_DEATH_LIFE_BOSS_SPEED_MULTIPLIER or BETWEEN_DEATH_LIFE_NORMAL_SPEED_MULTIPLIER
    local oldMaxHp = tonumber(npc.MaxHitPoints) or 0
    local oldHp = tonumber(npc.HitPoints) or oldMaxHp

    if oldMaxHp > 0 then
        local newMaxHp = math.max(oldMaxHp + 1, math.floor(oldMaxHp * hpMultiplier + 0.5))
        npc.MaxHitPoints = newMaxHp
        npc.HitPoints = math.max(oldHp + (newMaxHp - oldMaxHp), oldHp)
    end

    if npc.MoveSpeed ~= nil then
        npc.MoveSpeed = npc.MoveSpeed * speedMultiplier
    end

    if npc.SetColor then
        local color = isBoss and Color(1, 0.35, 0.35, 1, 0.2, 0, 0) or Color(0.75, 0.75, 0.75, 1, 0.1, 0.1, 0.1)
        pcall(function()
            npc:SetColor(color, 90, 1, false, false)
        end)
    end
end

local function ShouldBetweenDeathLifeAffectCurrentRoom(data)
    return type(data) == "table"
        and data.active == true
        and data.activatedRoomKey ~= GetBetweenDeathLifeRoomKey()
end

local function ActivateBetweenDeathLifeTrial(player, activeSlot, requireCharge)
    if not player then
        return false
    end

    local slot = FindBetweenDeathLifeSlot(player, activeSlot) or activeSlot or (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    if requireCharge ~= false and GetBetweenDeathLifeCharge(player, slot) < BETWEEN_DEATH_LIFE_MAX_CHARGE then
        return false
    end

    local data = GetDeathTrialData()
    if data.active ~= true then
        data.active = true
        data.runSeed = GetCurrentRunSeed()
        data.activatedFloorKey = GetBetweenDeathLifeFloorKey()
        data.activatedRoomKey = GetBetweenDeathLifeRoomKey()
        if IsBetweenDeathLifeBossRoomClear() then
            data.preActivationBossClearedFloors[GetBetweenDeathLifeFloorKey()] = true
        end
        Store.Save()
    end

    RemoveBetweenDeathLifeItem(player, slot)
    return true
end

function Neverbirth:UseBetweenDeathAndLife(_, _, player, _, activeSlot)
    if not running or disposed then return false end
    return ActivateBetweenDeathLifeTrial(player, activeSlot, true)
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseBetweenDeathAndLife, Items.BetweenDeathAndLife)

-- REPENTOGON passes EntityPlayer userdata as the final POST_ADD_COLLECTIBLE argument.
function Neverbirth:ActivateBetweenDeathAndLifeOnPickup(_, _, _, slot, _, player)
    if not running or disposed then return nil end
    if not player then
        return
    end

    ActivateBetweenDeathLifeTrial(player, slot, false)
end

if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, Neverbirth.ActivateBetweenDeathAndLifeOnPickup, Items.BetweenDeathAndLife)
end

function Neverbirth:InitBetweenDeathLifeNpc(npc)
    if disposed then return nil end
    if not running or AwaitingGameStart() then
        pendingNpcScan = true
        return
    end
    local data = GetDeathTrialData()
    if not ShouldBetweenDeathLifeAffectCurrentRoom(data) or not IsBetweenDeathLifeEligibleNpc(npc) then
        return
    end

    local npcData = GetBetweenDeathLifeNpcData(npc)
    if npcData and npcData.neverbirthDeathTrialElite then
        return
    end

    if not TryBetweenDeathLifeMakeChampion(npc) then
        EmpowerBetweenDeathLifeNpc(npc)
    end

    if npcData then
        npcData.neverbirthDeathTrialElite = true
    end
end

if ModCallbacks.MC_POST_NPC_INIT then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, Neverbirth.InitBetweenDeathLifeNpc)
end

function Neverbirth:UpdateBetweenDeathLifeBossReward()
    if not running or disposed then return nil end
    if AwaitingGameStart() then return end
    local floorKey = GetBetweenDeathLifeFloorKey()
    local data = GetDeathTrialData()

    if not IsBetweenDeathLifeBossRoomClear() then
        return
    end

    if data.active ~= true then
        data.preActivationBossClearedFloors[floorKey] = true
        return
    end

    if data.preActivationBossClearedFloors[floorKey] or data.spawnedByFloor[floorKey] then
        return
    end

    if SpawnBetweenDeathLifeDeathCertificate() then
        data.spawnedByFloor[floorKey] = true
        Store.Save()
    end
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateBetweenDeathLifeBossReward)

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    ResetDeathTrialDataForRun()
    Store.Save()
end } })
function Neverbirth:ResetBetweenDeathLifeState(isContinued)
    if disposed then return end
    running = true
    gameStartObserved = true
    resetRun(self, isContinued)
    local reconcileNpcs = pendingNpcScan and isContinued
    pendingNpcScan = false
    if reconcileNpcs and Isaac.GetRoomEntities then
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            local npc = entity.ToNPC and entity:ToNPC()
            if npc then Neverbirth:InitBetweenDeathLifeNpc(npc) end
        end
    end
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetBetweenDeathLifeState)
end
function Neverbirth:ExitBetweenDeathLife()
    running = false
    gameStartObserved, pendingNpcScan = false, false
end
if ModCallbacks.MC_PRE_GAME_EXIT then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitBetweenDeathLife)
end

function Neverbirth:UnloadBetweenDeathLife(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    gameStartObserved, pendingNpcScan = false, false
end
if ModCallbacks.MC_PRE_MOD_UNLOAD then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadBetweenDeathLife)
end

end
