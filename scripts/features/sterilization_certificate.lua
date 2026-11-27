-- Owns the complete SterilizationCertificate feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    local WorldQueries = include("scripts.runtime.world_queries")
    local Items = { SterilizationCertificate = assert(dependencies.ItemId) }
    local GetPlayers = assert(dependencies.GetPlayers)

do
local STERILIZATION_NORMAL_BASE_DAMAGE = 10
local STERILIZATION_NORMAL_MAX_HP_RATIO = 0.05
local STERILIZATION_BOSS_BASE_DAMAGE = 3
local STERILIZATION_BOSS_MAX_HP_RATIO = 0.01
local STERILIZATION_ENTITY_EFFECT = (EntityType and EntityType.ENTITY_EFFECT) or 1000
local STERILIZATION_POOF_VARIANT = (EffectVariant and EffectVariant.POOF01) or 15
local STERILIZATION_DAMAGE_FLAGS = 0

local function SterilizationEntityType(name, fallback)
    if EntityType and EntityType[name] then
        return EntityType[name]
    end

    return fallback
end

local STERILIZATION_SPAWNER_TYPES = {
    [SterilizationEntityType("ENTITY_MULLIGAN", 16)] = true,
    [SterilizationEntityType("ENTITY_HIVE", 22)] = true,
    [SterilizationEntityType("ENTITY_BIGSPIDER", 94)] = true,
    [SterilizationEntityType("ENTITY_NEST", 205)] = true,
    [SterilizationEntityType("ENTITY_FAT_SACK", 209)] = true,
    [SterilizationEntityType("ENTITY_HALF_SACK", 211)] = true,
    [SterilizationEntityType("ENTITY_PORTAL", 306)] = true,
    [SterilizationEntityType("ENTITY_DUKE", 67)] = true,
    [SterilizationEntityType("ENTITY_GURDY", 36)] = true,
    [SterilizationEntityType("ENTITY_WIDOW", 100)] = true,
    [SterilizationEntityType("ENTITY_MAMA_GURDY", 266)] = true,
    [SterilizationEntityType("ENTITY_MATRIARCH", 413)] = true,
}

local STERILIZATION_ORDINARY_SPAWN_TYPES = {
    [SterilizationEntityType("ENTITY_FLY", 13)] = true,
    [SterilizationEntityType("ENTITY_ATTACKFLY", 18)] = true,
    [SterilizationEntityType("ENTITY_MAGGOT", 21)] = true,
    [SterilizationEntityType("ENTITY_SPIDER", 85)] = true,
    [SterilizationEntityType("ENTITY_FLY_L2", 214)] = true,
    [SterilizationEntityType("ENTITY_SPIDER_L2", 215)] = true,
    [SterilizationEntityType("ENTITY_DIP", 217)] = true,
    [SterilizationEntityType("ENTITY_SWARM", 281)] = true,
    [SterilizationEntityType("ENTITY_SWARM_SPIDER", 884)] = true,
}

local sterilizationKnownEntities = {}
local sterilizationBlockedEntities = {}
local sterilizationTrackedSpawners = {}
local sterilizationRoomInitialized = false
local running, disposed = true, false

local function ClearSterilizationRuntime()
    sterilizationKnownEntities = {}
    sterilizationBlockedEntities = {}
    sterilizationTrackedSpawners = {}
    sterilizationRoomInitialized = false
end

local function GetSterilizationEntityKey(entity)
    if not entity then
        return nil
    end

    if entity.InitSeed ~= nil then
        return tostring(entity.InitSeed)
    end

    return tostring(entity)
end

local function PlayerHasSterilizationCertificate(player)
    return player and player.GetCollectibleNum and player:GetCollectibleNum(Items.SterilizationCertificate) > 0
end

local function AnyPlayerHasSterilizationCertificate()
    for _, player in ipairs(GetPlayers()) do
        if PlayerHasSterilizationCertificate(player) then
            return true
        end
    end

    return false
end

local function IsSterilizationEnemy(entity)
    if not entity or entity.Type == ((EntityType and EntityType.ENTITY_PICKUP) or 5) then
        return false
    end

    if entity.IsVulnerableEnemy then
        local ok, isEnemy = pcall(function()
            return entity:IsVulnerableEnemy()
        end)
        if ok then
            return isEnemy == true
        end
    end

    return entity.ToNPC and entity:ToNPC() ~= nil
end

local function IsSterilizationBoss(entity)
    if not entity or not entity.IsBoss then
        return false
    end

    local ok, isBoss = pcall(function()
        return entity:IsBoss()
    end)
    return ok and isBoss == true
end

local function HasSterilizationFriendlyFlag(entity)
    if not entity or not entity.HasEntityFlags or not EntityFlag or not EntityFlag.FLAG_FRIENDLY then
        return false
    end

    local ok, hasFlag = pcall(function()
        return entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
    end)
    return ok and hasFlag == true
end

local function IsSterilizationSpawner(entity)
    return IsSterilizationEnemy(entity) and STERILIZATION_SPAWNER_TYPES[entity.Type] == true
end

local function IsSterilizationOrdinarySpawn(entity)
    if not IsSterilizationEnemy(entity) then
        return false
    end

    if HasSterilizationFriendlyFlag(entity) then
        return false
    end

    if IsSterilizationBoss(entity) then
        return false
    end

    return STERILIZATION_ORDINARY_SPAWN_TYPES[entity.Type] == true
end

local function ExtractSterilizationEntity(candidate)
    if candidate and candidate.Entity then
        return candidate.Entity
    end

    return candidate
end

local function IsSameSterilizationEntity(left, right)
    left = ExtractSterilizationEntity(left)
    right = ExtractSterilizationEntity(right)

    if left == nil or right == nil then
        return false
    end

    if left == right then
        return true
    end

    local leftKey = GetSterilizationEntityKey(left)
    local rightKey = GetSterilizationEntityKey(right)
    return leftKey ~= nil and rightKey ~= nil and leftKey == rightKey
end

local function IsSterilizationSpawnFromSource(spawn, source)
    if IsSameSterilizationEntity(spawn.SpawnerEntity, source) then
        return true
    end

    if IsSameSterilizationEntity(spawn.Parent, source) then
        return true
    end

    return false
end

local function FindSterilizationSpawnSource(spawn)
    for _, source in pairs(sterilizationTrackedSpawners) do
        if IsSterilizationSpawnFromSource(spawn, source) then
            return source
        end
    end

    return nil
end

local function GetSterilizationMaxHitPoints(entity)
    return tonumber(entity and (entity.MaxHitPoints or entity.HitPoints)) or 0
end

local function GetSterilizationBacklashDamage(source)
    local maxHitPoints = GetSterilizationMaxHitPoints(source)
    if IsSterilizationBoss(source) then
        return STERILIZATION_BOSS_BASE_DAMAGE + maxHitPoints * STERILIZATION_BOSS_MAX_HP_RATIO
    end

    return STERILIZATION_NORMAL_BASE_DAMAGE + maxHitPoints * STERILIZATION_NORMAL_MAX_HP_RATIO
end

local function FlashSterilizationSource(source)
    if not source or not source.SetColor or not Color then
        return
    end

    pcall(function()
        source:SetColor(Color(1, 0.25, 0.25, 1, 0.25, 0, 0), 8, 1, true, false)
    end)
end

local function SpawnSterilizationPoof(spawn, source)
    local position = spawn and spawn.Position or (source and source.Position) or (Vector and Vector(0, 0))
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }

    if Isaac.Spawn then
        Isaac.Spawn(STERILIZATION_ENTITY_EFFECT, STERILIZATION_POOF_VARIANT, 0, position, velocity, source)
        return
    end

    if Game then
        local game = WorldQueries.TryGame()
        if game and game.Spawn then
            game:Spawn(STERILIZATION_ENTITY_EFFECT, STERILIZATION_POOF_VARIANT, position, velocity, source, 0, 0)
        end
    end
end

local function BlockSterilizationSpawn(spawn, source)
    local spawnKey = GetSterilizationEntityKey(spawn)
    if not spawnKey or sterilizationBlockedEntities[spawnKey] then
        return false
    end

    sterilizationBlockedEntities[spawnKey] = true
    SpawnSterilizationPoof(spawn, source)

    if spawn and spawn.Remove then
        pcall(function()
            spawn:Remove()
        end)
    end

    if source and source.TakeDamage then
        local damageSource = EntityRef and EntityRef(spawn) or nil
        pcall(function()
            source:TakeDamage(GetSterilizationBacklashDamage(source), STERILIZATION_DAMAGE_FLAGS, damageSource, 0)
        end)
    end

    FlashSterilizationSource(source)
    return true
end

local function GetSterilizationRoomEntities()
    if not Isaac.GetRoomEntities then
        return {}
    end

    return Isaac.GetRoomEntities()
end

local function RefreshSterilizationTrackedSpawners(entities)
    sterilizationTrackedSpawners = {}
    for _, entity in ipairs(entities) do
        if IsSterilizationSpawner(entity) then
            local entityKey = GetSterilizationEntityKey(entity)
            if entityKey then
                sterilizationTrackedSpawners[entityKey] = entity
            end
        end
    end
end

local function RememberSterilizationEntity(entity)
    local entityKey = GetSterilizationEntityKey(entity)
    if entityKey then
        sterilizationKnownEntities[entityKey] = true
    end
end

local function RememberSterilizationRoomEntities(entities)
    for _, entity in ipairs(entities or GetSterilizationRoomEntities()) do
        RememberSterilizationEntity(entity)
    end
end

function Neverbirth:TrackSterilizationNewRoom()
    if not running or disposed then return end
    ClearSterilizationRuntime()

    if not AnyPlayerHasSterilizationCertificate() then
        return
    end

    local entities = GetSterilizationRoomEntities()
    RefreshSterilizationTrackedSpawners(entities)
    RememberSterilizationRoomEntities(entities)
    sterilizationRoomInitialized = true
end

if ModCallbacks.MC_POST_NEW_ROOM then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.TrackSterilizationNewRoom)
end

function Neverbirth:UpdateSterilizationCertificate()
    if not running or disposed then return end
    local hasSterilization = AnyPlayerHasSterilizationCertificate()
    if not hasSterilization then
        if sterilizationRoomInitialized then
            sterilizationKnownEntities = {}
            sterilizationBlockedEntities = {}
            sterilizationTrackedSpawners = {}
            sterilizationRoomInitialized = false
        end
        return
    end

    local entities = GetSterilizationRoomEntities()
    RefreshSterilizationTrackedSpawners(entities)

    if not sterilizationRoomInitialized then
        sterilizationRoomInitialized = true
        RememberSterilizationRoomEntities(entities)
        return
    end

    for _, entity in ipairs(entities) do
        local entityKey = GetSterilizationEntityKey(entity)
        if entityKey and not sterilizationKnownEntities[entityKey] then
            if IsSterilizationOrdinarySpawn(entity) then
                local source = FindSterilizationSpawnSource(entity)
                if source then
                    BlockSterilizationSpawn(entity, source)
                end
            end
        end
    end

    RememberSterilizationRoomEntities(entities)
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateSterilizationCertificate)

local resetRun = include("scripts.runtime.new_run_reset")({ Reset = { ClearSterilizationRuntime } })
function Neverbirth:ResetSterilizationCertificateState(isContinued)
    if disposed then return end
    running = true
    resetRun(self, isContinued)
end

if ModCallbacks.MC_POST_GAME_STARTED then
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetSterilizationCertificateState)
end

function Neverbirth:ExitSterilizationCertificate()
    running = false
    -- Scalar discovery and blocked keys survive same-instance Continue; NPCs do not.
    sterilizationTrackedSpawners = {}
end
if ModCallbacks.MC_PRE_GAME_EXIT then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitSterilizationCertificate)
end

function Neverbirth:UnloadSterilizationCertificate(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    running, disposed = false, true
    ClearSterilizationRuntime()
end
if ModCallbacks.MC_PRE_MOD_UNLOAD then
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadSterilizationCertificate)
end
end

end
