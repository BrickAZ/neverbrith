-- A single recursion/deduplication owner processes both box bonuses.
return function(Neverbirth, dependencies)
local DebugLog = dependencies.Log
local AnyPlayerHasAngelbox, AnyPlayerHasDevilbox = dependencies.Angel.AnyHolder, dependencies.Devil.AnyHolder
local ANGELBOX_EXTRA_SOUL_HEART_CHANCE, DEVILBOX_EXTRA_BLACK_HEART_CHANCE = dependencies.Angel.BonusChance, dependencies.Devil.BonusChance
local ANGELBOX_SOUL_HEART_SUBTYPE, DEVILBOX_BLACK_HEART_SUBTYPE = dependencies.Angel.HeartSubtype, dependencies.Devil.HeartSubtype
local GetAngelboxGame = dependencies.Shared.GetGame
local GetAngelboxRoom = dependencies.Shared.GetRoom
local ANGELBOX_ENTITY_PICKUP = dependencies.Shared.PickupEntity
local ANGELBOX_HEART_VARIANT = dependencies.Shared.HeartVariant
local boxBonusHeartKeys = {}
local boxProcessedHeartKeys = {}
local boxBonusHeartSpawnDepth = 0

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { function()
    boxBonusHeartKeys, boxProcessedHeartKeys = {}, {}
    boxBonusHeartSpawnDepth = 0
end } })
function Neverbirth:ResetBoxHeartBonuses(isContinued)
    resetRun(self, isContinued)
end
Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetBoxHeartBonuses)

local function GetBoxHeartPickupKey(pickup)
    if not pickup then
        return nil
    end

    if pickup.InitSeed ~= nil then
        return "init:" .. tostring(pickup.InitSeed)
    end

    if pickup.Seed ~= nil then
        return "seed:" .. tostring(pickup.Seed)
    end

    return tostring(pickup)
end

local function RollBoxHeartBonus(pickup, chancePercent, salt)
    local seed = tonumber(pickup and (pickup.InitSeed or pickup.Seed)) or 0
    local roll = (seed + (salt or 0)) % 100
    return roll < chancePercent, roll
end

local function SpawnBoxBonusHeart(sourcePickup, subtype)
    local game = GetAngelboxGame()
    if not game or not game.Spawn then
        return nil
    end

    local position = sourcePickup and sourcePickup.Position or nil
    if not position then
        local room = GetAngelboxRoom()
        position = room and room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
    end

    local room = GetAngelboxRoom()
    if room and room.FindFreePickupSpawnPosition then
        position = room:FindFreePickupSpawnPosition(position, 40, true, false)
    end

    local seed = (tonumber(sourcePickup and (sourcePickup.InitSeed or sourcePickup.Seed)) or 0) + subtype * 1000
    boxBonusHeartSpawnDepth = boxBonusHeartSpawnDepth + 1
    local ok, pickup = pcall(function()
        return game:Spawn(ANGELBOX_ENTITY_PICKUP, ANGELBOX_HEART_VARIANT, position, Vector(0, 0), sourcePickup, subtype, seed)
    end)
    boxBonusHeartSpawnDepth = boxBonusHeartSpawnDepth - 1
    if not ok then
        DebugLog("[neverbirth][Boxes] bonus heart spawn failed: " .. tostring(pickup))
        return nil
    end

    local key = GetBoxHeartPickupKey(pickup)
    if key then
        boxBonusHeartKeys[key] = true
    end

    return pickup
end

function Neverbirth:HandleBoxHeartPickupInit(pickup)
    if not pickup or pickup.Type ~= ANGELBOX_ENTITY_PICKUP or pickup.Variant ~= ANGELBOX_HEART_VARIANT then
        return
    end

    local key = GetBoxHeartPickupKey(pickup)
    if key and boxBonusHeartKeys[key] then
        boxProcessedHeartKeys[key] = true
        return
    end

    if boxBonusHeartSpawnDepth > 0 then
        if key then
            boxBonusHeartKeys[key] = true
            boxProcessedHeartKeys[key] = true
        end
        return
    end

    if key and boxProcessedHeartKeys[key] then
        return
    end

    if key then
        boxProcessedHeartKeys[key] = true
    end

    if AnyPlayerHasAngelbox() then
        local hit, roll = RollBoxHeartBonus(pickup, ANGELBOX_EXTRA_SOUL_HEART_CHANCE, 0)
        local spawned = hit and SpawnBoxBonusHeart(pickup, ANGELBOX_SOUL_HEART_SUBTYPE) or nil
        DebugLog(string.format("[neverbirth][Boxes] heart box=Angelbox source=%s roll=%d threshold=60 hit=%s spawned=%s", tostring(key), roll, tostring(hit), tostring(spawned ~= nil)))
    end

    if AnyPlayerHasDevilbox() then
        local hit, roll = RollBoxHeartBonus(pickup, DEVILBOX_EXTRA_BLACK_HEART_CHANCE, 7)
        local spawned = hit and SpawnBoxBonusHeart(pickup, DEVILBOX_BLACK_HEART_SUBTYPE) or nil
        DebugLog(string.format("[neverbirth][Boxes] heart box=Devilbox source=%s roll=%d threshold=80 hit=%s spawned=%s", tostring(key), roll, tostring(hit), tostring(spawned ~= nil)))
    end
end

if ModCallbacks.MC_POST_PICKUP_INIT then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, Neverbirth.HandleBoxHeartPickupInit, ANGELBOX_HEART_VARIANT)
end

end
