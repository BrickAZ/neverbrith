-- Owns this feature's rules, state and callbacks. Dependencies are provided by main.lua.
return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local Cards = include("scripts.systems.card_rewards")
    local Rolls = include("scripts.systems.collectible_rng")
local WorldQueries = include("scripts.runtime.world_queries")
local Items = assert(dependencies.Items)
local IsValidItemId = assert(dependencies.IsValidItemId)
local BOSS_ORDER_ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
local BOSS_ORDER_CARD_VARIANT = (PickupVariant and PickupVariant.PICKUP_TAROTCARD) or 300
local BOSS_ORDER_MIN_CARD_SUBTYPE = 1
local BOSS_ORDER_MAX_CARD_SUBTYPE = (Card and type(Card.RUNE_HAGALAZ) == "number" and Card.RUNE_HAGALAZ > 1) and (Card.RUNE_HAGALAZ - 1) or 31
local BOSS_ORDER_MAX_REASONABLE_CARD_SUBTYPE = 10000
local BOSS_ORDER_CARD_PICK_RETRIES = 16
local BOSS_ORDER_MIN_SPAWN_DISTANCE = 80
local BOSS_ORDER_SPAWN_OFFSET = 120
local BOSS_ORDER_CHAMPION_CHANCE = 15
local BOSS_ORDER_CHAMPION_COLOR = -1

local bossOrderPendingEncounters = {}
local bossOrderRunToken = {}
local running, disposed = true, false
local ownedEncounters = setmetatable({}, { __mode = "k" })

local function BossOrderTarget(entityType, variant, subtype, rewardCategory, segments)
    return {
        entityType = entityType,
        variant = variant or 0,
        subtype = subtype or 0,
        rewardCategory = rewardCategory or "normal",
        segments = segments or 1,
    }
end

local BOSS_ORDER_TARGET_ROLLS = {
    "normal",
    "normal",
    "boss",
    "boss",
    "boss",
}

local BOSS_ORDER_NORMAL_TARGETS_BY_STAGE_GROUP = {
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_GAPER or 10),
        BossOrderTarget(EntityType and EntityType.ENTITY_HORF or 12),
        BossOrderTarget(EntityType and EntityType.ENTITY_POOTER or 14),
        BossOrderTarget(EntityType and EntityType.ENTITY_ATTACKFLY or 13),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_CLOTTY or 21),
        BossOrderTarget(EntityType and EntityType.ENTITY_MULLIGAN or 22),
        BossOrderTarget(EntityType and EntityType.ENTITY_CHARGER or 23),
        BossOrderTarget(EntityType and EntityType.ENTITY_SPITTY or 31),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_VIS or 39),
        BossOrderTarget(EntityType and EntityType.ENTITY_LEECH or 55),
        BossOrderTarget(EntityType and EntityType.ENTITY_KNIGHT or 32),
        BossOrderTarget(EntityType and EntityType.ENTITY_HOST or 44),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_VIS or 39),
        BossOrderTarget(EntityType and EntityType.ENTITY_LEECH or 55),
        BossOrderTarget(EntityType and EntityType.ENTITY_BONY or 227),
        BossOrderTarget(EntityType and EntityType.ENTITY_NULLS or 282),
    },
    {
        BossOrderTarget(EntityType and EntityType.ENTITY_GAPER or 10),
        BossOrderTarget(EntityType and EntityType.ENTITY_HORF or 12),
        BossOrderTarget(EntityType and EntityType.ENTITY_LEECH or 55),
        BossOrderTarget(EntityType and EntityType.ENTITY_VIS or 39),
    },
}

local BOSS_ORDER_BOSS_RUSH_TARGETS = {
    BossOrderTarget(EntityType and EntityType.ENTITY_MONSTRO or 20, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_LARRYJR or 19, 0, 0, "boss", 5),
    BossOrderTarget(EntityType and EntityType.ENTITY_DUKE or 67, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_GURDY or 36, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_CHUB or 28, 0, 0, "boss", 3),
    BossOrderTarget(EntityType and EntityType.ENTITY_PIN or 62, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_FAMINE or 63, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_PESTILENCE or 64, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_WAR or 65, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_DEATH or 66, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_LOKI or 69, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_MONSTRO2 or 43, 0, 0, "boss"),
    BossOrderTarget(EntityType and EntityType.ENTITY_GURDY_JR or 99, 0, 0, "boss"),
}

local function GetBossOrderGame()
    return WorldQueries.TryGame() or nil
end

local function GetBossOrderRoom()
    return WorldQueries.TryMethod(GetBossOrderGame(), "GetRoom") or nil
end

local function GetBossOrderItemPool()
    return WorldQueries.TryMethod(GetBossOrderGame(), "GetItemPool") or nil
end

local function GetBossOrderItemConfig()
    return WorldQueries.TryItemConfig() or nil
end

local function GetBossOrderLevel()
    return WorldQueries.TryMethod(GetBossOrderGame(), "GetLevel") or nil
end

local function GetBossOrderRandomInt(player, max)
    if max <= 0 then return 0 end
    local rng
    if player and player.GetCollectibleRNG and IsValidItemId(Items.BossOrder) then
        rng = Rolls.Get(player, Items.BossOrder, "RandomInt")
    end
    return Rolls.IntOrRoomSeed(rng, max, GetBossOrderRoom)
end

local function GetBossOrderStageGroup()
    local level = GetBossOrderLevel()
    local stage = 1
    if level and level.GetStage then
        local ok, value = pcall(function()
            return level:GetStage()
        end)
        if ok and type(value) == "number" then
            stage = math.max(1, math.floor(value))
        end
    end

    if stage <= 2 then
        return 1
    end
    if stage <= 4 then
        return 2
    end
    if stage <= 6 then
        return 3
    end
    if stage <= 8 then
        return 4
    end
    return 5
end

local function CollectBossOrderTargetsFromPool(pool)
    local targets = {}
    for _, target in ipairs(pool or {}) do
        if type(target.entityType) == "number" and target.entityType > 0 then
            targets[#targets + 1] = target
        end
    end
    return targets
end

local function CollectBossOrderNormalTargets()
    local stageGroup = GetBossOrderStageGroup()
    local targets = CollectBossOrderTargetsFromPool(BOSS_ORDER_NORMAL_TARGETS_BY_STAGE_GROUP[stageGroup])
    if #targets <= 0 then
        targets = CollectBossOrderTargetsFromPool(BOSS_ORDER_NORMAL_TARGETS_BY_STAGE_GROUP[1])
    end
    return targets
end

local function CollectBossOrderBossRushTargets()
    return CollectBossOrderTargetsFromPool(BOSS_ORDER_BOSS_RUSH_TARGETS)
end

local function GetBossOrderOffsetPosition(position, x, y)
    if not position then
        return nil
    end

    local newX = (position.X or 0) + x
    local newY = (position.Y or 0) + y
    return (Vector and Vector(newX, newY)) or { X = newX, Y = newY }
end

local function IsBossOrderSpawnFarEnough(position, player)
    if not position or not player or not player.Position then
        return true
    end

    local dx = (position.X or 0) - (player.Position.X or 0)
    local dy = (position.Y or 0) - (player.Position.Y or 0)
    return dx * dx + dy * dy >= BOSS_ORDER_MIN_SPAWN_DISTANCE * BOSS_ORDER_MIN_SPAWN_DISTANCE
end

local function IsBossOrderSpawnAvailable(position, player, nearby, room)
    if not IsBossOrderSpawnFarEnough(position, player) then return false end
    if nearby and room then
        if room.IsPositionInRoom and not room:IsPositionInRoom(position, 20) then return false end
        if room.GetGridCollisionAtPos and room:GetGridCollisionAtPos(position) ~= 0 then return false end
    end
    for _, npc in ipairs(nearby or {}) do
        if npc:Exists() and not npc:IsDead() and not IsBossOrderSpawnFarEnough(position, npc) then
            return false
        end
    end
    return true
end

local function TryBossOrderSpawnPosition(room, candidate, player, nearby)
    if not candidate then
        return nil
    end

    if room and room.FindFreeTilePosition then
        local ok, freePosition = pcall(function()
            return room:FindFreeTilePosition(candidate, BOSS_ORDER_MIN_SPAWN_DISTANCE)
        end)
        if ok and freePosition and IsBossOrderSpawnAvailable(freePosition, player, nearby, room) then
            return freePosition
        end
    end

    if room and room.FindFreePickupSpawnPosition then
        local ok, freePosition = pcall(function()
            return room:FindFreePickupSpawnPosition(candidate, BOSS_ORDER_MIN_SPAWN_DISTANCE, true, false)
        end)
        if ok and freePosition and IsBossOrderSpawnAvailable(freePosition, player, nearby, room) then
            return freePosition
        end
    end

    if IsBossOrderSpawnAvailable(candidate, player, nearby, room) then
        return candidate
    end

    return nil
end

local function GetBossOrderSpawnPosition(player, target)
    local room = GetBossOrderRoom()
    local nearby
    if target and target.segments > 1 then
        -- Separate bodies, including back-to-back uses in the same update.
        -- Snapshot once per use; never scan every frame or adopt unrelated NPCs.
        if not Isaac.FindByType then return nil end
        nearby = Isaac.FindByType(target.entityType, target.variant, target.subtype, false, false)
    end
    local fallbackPosition = player and player.Position or (Vector and Vector(320, 280)) or { X = 320, Y = 280 }
    local candidates = {}

    if room and room.GetCenterPos then
        local ok, center = pcall(function()
            return room:GetCenterPos()
        end)
        if ok and center then
            candidates[#candidates + 1] = center
        end
    end

    if player and player.Position then
        local offsets = {
            { x = BOSS_ORDER_SPAWN_OFFSET, y = 0 },
            { x = -BOSS_ORDER_SPAWN_OFFSET, y = 0 },
            { x = 0, y = BOSS_ORDER_SPAWN_OFFSET },
            { x = 0, y = -BOSS_ORDER_SPAWN_OFFSET },
        }
        for _, offset in ipairs(offsets) do
            candidates[#candidates + 1] = GetBossOrderOffsetPosition(player.Position, offset.x, offset.y)
        end
    end

    candidates[#candidates + 1] = fallbackPosition

    for _, candidate in ipairs(candidates) do
        local position = TryBossOrderSpawnPosition(room, candidate, player, nearby)
        if position then
            return position
        end
    end

    if nearby then return nil end
    return fallbackPosition
end

local function SelectBossOrderTarget(player)
    local targetType = BOSS_ORDER_TARGET_ROLLS[GetBossOrderRandomInt(player, #BOSS_ORDER_TARGET_ROLLS) + 1] or "normal"
    local targets = targetType == "boss" and CollectBossOrderBossRushTargets() or CollectBossOrderNormalTargets()

    if #targets <= 0 and targetType == "boss" then
        targets = CollectBossOrderNormalTargets()
    elseif #targets <= 0 then
        targets = CollectBossOrderBossRushTargets()
    end

    if #targets <= 0 then
        return nil
    end

    return targets[GetBossOrderRandomInt(player, #targets) + 1]
end

local function GetBossOrderEntityData(entity)
    if entity and entity.GetData then
        local ok, data = pcall(function()
            return entity:GetData()
        end)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

local function GetBossOrderNpc(entity)
    if entity and entity.ToNPC then
        local ok, npc = pcall(function()
            return entity:ToNPC()
        end)
        if ok and npc then
            return npc
        end
    end

    return entity
end

local function IsBossOrderChampion(npc)
    if npc and npc.IsChampion then
        local ok, isChampion = pcall(function()
            return npc:IsChampion()
        end)
        return ok and isChampion == true
    end

    return false
end

local function MarkBossOrderTarget(entity, target, encounter)
    local data = GetBossOrderEntityData(entity)
    if not data then
        return false
    end

    data.neverbirthBossOrderTarget = true
    data.neverbirthBossOrderRewarded = false
    data.neverbirthBossOrderRewardCategory = target and target.rewardCategory or "normal"
    if encounter then
        local member = { entity = entity, dead = false }
        encounter.members[#encounter.members + 1] = member
        data.neverbirthBossOrderEncounter = encounter
        data.neverbirthBossOrderMember = member
    end
    return true
end

local function TryBossOrderMakeChampion(entity, player, target)
    if not target or target.rewardCategory ~= "normal" then
        return false
    end

    local npc = GetBossOrderNpc(entity)
    if not npc or not npc.MakeChampion or IsBossOrderChampion(npc) then
        return false
    end

    if GetBossOrderRandomInt(player, 100) >= BOSS_ORDER_CHAMPION_CHANCE then
        return false
    end

    local room = GetBossOrderRoom()
    local seed = npc.InitSeed or (room and room.GetSpawnSeed and room:GetSpawnSeed()) or 0
    local ok = pcall(function()
        npc:MakeChampion(seed, BOSS_ORDER_CHAMPION_COLOR, true)
    end)

    return ok and IsBossOrderChampion(npc)
end

local function SpawnBossOrderTarget(player, target)
    if not Isaac or not Isaac.Spawn or not target then
        return nil
    end

    local position = GetBossOrderSpawnPosition(player, target)
    if not position then return nil end
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
    local entities = {}
    local room = GetBossOrderRoom()
    local encounter = target.segments > 1 and {
        members = {},
        status = "spawning",
        runToken = bossOrderRunToken,
        entityType = target.entityType,
        variant = target.variant,
        subtype = target.subtype,
        roomSeed = room and room:GetSpawnSeed(),
    } or nil
    local function rollback()
        if encounter then encounter.status = "cancelled" end
        for _, spawned in ipairs(entities) do
            if spawned.Exists and spawned:Exists() then
                local data = GetBossOrderEntityData(spawned)
                if data then data.neverbirthBossOrderRewarded = true end
                spawned:Remove()
            end
        end
    end

    -- Vanilla Larry/Chub assemble adjacent same-position spawns into a body.
    -- Match the native chunks contract; Pin creates its own segments and is 1.
    -- Do not force AI state, HP, or link fields before native initialization.
    for _ = 1, target.segments do
        local ok, entity = pcall(function()
            return Isaac.Spawn(target.entityType, target.variant, target.subtype, position, velocity, player)
        end)
        if not ok or not entity then rollback(); return nil end
        entities[#entities + 1] = entity
        local npc = entity.ToNPC and entity:ToNPC()
        if not npc or not npc:Exists() or npc:IsDead()
            or npc.Type ~= target.entityType or npc.Variant ~= target.variant or npc.SubType ~= target.subtype
            or not MarkBossOrderTarget(npc, target, encounter)
        then
            rollback()
            return nil
        end
    end

    if encounter then
        encounter.status = "active"
        encounter.seed = entities[1].InitSeed
        ownedEncounters[encounter] = true
    end
    TryBossOrderMakeChampion(entities[1], player, target)
    return entities[1]
end

function Neverbirth:UseBossOrder(_, _, player)
    if not running then return { Discharge = false, Remove = false, ShowAnim = false } end
    local target = SelectBossOrderTarget(player)
    if SpawnBossOrderTarget(player, target) then return true end
    -- A boolean only controls the animation; explicitly cancel charge/wisp use.
    return { Discharge = false, Remove = false, ShowAnim = false }
end
function callbackInstallers.Neverbirth_UseBossOrder()
    return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseBossOrder, Items.BossOrder)
end

local function IsBossOrderBoss(npc, data)
    if data and data.neverbirthBossOrderRewardCategory == "boss" then
        return true
    end

    if npc and npc.IsBoss then
        local ok, isBoss = pcall(function()
            return npc:IsBoss()
        end)
        return ok and isBoss == true
    end

    return false
end

local function GetBossOrderRewardCount(npc, data)
    if IsBossOrderBoss(npc, data) then
        return 3
    end

    if IsBossOrderChampion(npc) then
        return 2
    end

    return 1
end

local function GetBossOrderRewardSeed(npc, index, attempt)
    local seed = npc and type(npc.InitSeed) == "number" and npc.InitSeed or 0
    if seed == 0 then
        local room = GetBossOrderRoom()
        if room and room.GetSpawnSeed then
            local ok, roomSeed = pcall(function()
                return room:GetSpawnSeed()
            end)
            if ok and type(roomSeed) == "number" then
                seed = roomSeed
            end
        end
    end

    return math.abs(math.floor(seed + (index or 1) * 37 + (attempt or 0) * 101))
end

local function IsBossOrderKnownCardSubtype(subtype)
    subtype = math.floor(tonumber(subtype) or 0)
    if subtype < BOSS_ORDER_MIN_CARD_SUBTYPE or subtype > BOSS_ORDER_MAX_REASONABLE_CARD_SUBTYPE then return false end
    if not Cards.HasDisplayData(GetBossOrderItemConfig(), subtype) then return false end
    return Cards.HasEIDDescription(BOSS_ORDER_ENTITY_PICKUP, function() return BOSS_ORDER_CARD_VARIANT end, subtype, true)
end

local function AddBossOrderCardCandidate(candidates, seen, subtype)
    return Cards.AddCandidate(candidates, seen, subtype, IsBossOrderKnownCardSubtype)
end

local function CollectBossOrderRewardCardCandidates()
    return Cards.CollectCandidates(AddBossOrderCardCandidate, BOSS_ORDER_MIN_CARD_SUBTYPE, BOSS_ORDER_MAX_CARD_SUBTYPE)
end

local function GetBossOrderPoolCardSubtype(npc, index, attempt)
    local itemPool = GetBossOrderItemPool()
    if not itemPool or not itemPool.GetCard then return nil end
    local seed = GetBossOrderRewardSeed(npc, index, attempt)
    return Cards.RollPool(itemPool, seed, IsBossOrderKnownCardSubtype)
end

local function GetBossOrderRewardCardSubtype(npc, index)
    for attempt = 0, BOSS_ORDER_CARD_PICK_RETRIES - 1 do
        local subtype = GetBossOrderPoolCardSubtype(npc, index, attempt)
        if subtype then
            return subtype
        end
    end

    local candidates = CollectBossOrderRewardCardCandidates()
    if #candidates <= 0 then
        return BOSS_ORDER_MIN_CARD_SUBTYPE
    end

    local seed = GetBossOrderRewardSeed(npc, index, 0)
    return candidates[(seed % #candidates) + 1]
end

local function SpawnBossOrderCards(npc, count, savedPosition, savedSeed)
    if not Isaac or not Isaac.Spawn then
        return
    end

    local origin = savedPosition or (npc and npc.Position) or (Vector and Vector(320, 280)) or { X = 320, Y = 280 }
    local rewardSource = savedSeed and { InitSeed = savedSeed } or npc
    local room = GetBossOrderRoom()
    local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }

    for index = 1, count do
        local position = origin
        if room and room.FindFreePickupSpawnPosition then
            local ok, freePosition = pcall(function()
                return room:FindFreePickupSpawnPosition(origin, 20 + index * 5, true, false)
            end)
            if ok and freePosition then
                position = freePosition
            end
        end

        local cardSubtype = GetBossOrderRewardCardSubtype(rewardSource, index)
        pcall(function()
            Isaac.Spawn(BOSS_ORDER_ENTITY_PICKUP, BOSS_ORDER_CARD_VARIANT, cardSubtype, position, velocity, npc)
        end)
    end
end

function Neverbirth:RewardBossOrderTarget(npc)
    if not running then return end
    local data = GetBossOrderEntityData(npc)
    if not data or data.neverbirthBossOrderTarget ~= true or data.neverbirthBossOrderRewarded == true then
        return
    end

    local encounter = data.neverbirthBossOrderEncounter
    if encounter then
        local member = data.neverbirthBossOrderMember
        if encounter.status ~= "active" or encounter.runToken ~= bossOrderRunToken or not member or member.dead then return end
        if npc.Type ~= encounter.entityType or npc.Variant ~= encounter.variant or npc.SubType ~= encounter.subtype then
            encounter.status = "cancelled"
            return
        end
        member.dead = true
        member.entity = nil -- no userdata access after the death animation removes it
        data.neverbirthBossOrderRewarded = true
        encounter.position = Vector(npc.Position.X, npc.Position.Y)
        ownedEncounters[encounter] = true
        bossOrderPendingEncounters[encounter] = true
        return
    end

    data.neverbirthBossOrderRewarded = true
    SpawnBossOrderCards(npc, GetBossOrderRewardCount(npc, data))
end
function callbackInstallers.Neverbirth_RewardBossOrderTarget()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, Neverbirth.RewardBossOrderTarget)
end
function callbackInstallers.Neverbirth_RewardBossOrderTarget2()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, Neverbirth.RewardBossOrderTarget)
end

function Neverbirth:UpdateBossOrderEncounters()
    if not running then return end
    if next(bossOrderPendingEncounters) == nil then return end
    local room = GetBossOrderRoom()
    local roomSeed = room and room:GetSpawnSeed()
    for encounter in pairs(bossOrderPendingEncounters) do
        local complete = true
        if encounter.status == "active" and encounter.runToken == bossOrderRunToken and encounter.roomSeed == roomSeed then
            for _, member in ipairs(encounter.members) do
                if not member.dead then
                    local npc = member.entity
                    if not npc or not npc:Exists() then
                        encounter.status = "cancelled" -- Remove is not a kill.
                        break
                    elseif npc.Type ~= encounter.entityType or npc.Variant ~= encounter.variant or npc.SubType ~= encounter.subtype then
                        encounter.status = "cancelled" -- Morph is not a kill.
                        break
                    elseif npc:IsDead() then
                        -- Native linked deaths may become visible before all death callbacks.
                        member.dead = true
                        member.entity = nil
                    else
                        complete = false
                    end
                end
            end
            if complete and encounter.status == "active" then
                encounter.status = "rewarded"
                -- Only plain position/seed snapshots survive; a removed NPC cannot
                -- be passed as the native spawner argument to Isaac.Spawn.
                SpawnBossOrderCards(nil, 3, encounter.position, encounter.seed)
            end
        else
            bossOrderPendingEncounters[encounter] = nil
        end
        if encounter.status ~= "active" then
            bossOrderPendingEncounters[encounter] = nil
            for _, member in ipairs(encounter.members) do member.entity = nil end
        end
    end
end
function callbackInstallers.Neverbirth_UpdateBossOrderEncounters()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateBossOrderEncounters)
end

function Neverbirth:ResetBossOrderPendingEncounters()
    if not running then return end
    -- Queues are visit-local. Existing entity GetData owns the encounter; if
    -- those entities survive a revisit, a subsequent death queues it again.
    -- No SaveData/persistence policy is added to this previously entity-owned item.
    bossOrderPendingEncounters = {}
end
function callbackInstallers.Neverbirth_ResetBossOrderPendingEncounters()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.ResetBossOrderPendingEncounters)
end

local function clearRun()
    for encounter in pairs(ownedEncounters) do
        if encounter.status == "active" then encounter.status = "cancelled" end
        for _, member in ipairs(encounter.members or {}) do member.entity = nil end
        ownedEncounters[encounter] = nil
    end
    bossOrderRunToken = {}
    bossOrderPendingEncounters = {}
end

function Neverbirth:ResetBossOrderRun()
    if disposed then return end
    running = true
    clearRun()
end
function callbackInstallers.Neverbirth_ResetBossOrderRun()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetBossOrderRun)
end

function Neverbirth:ExitBossOrder()
    running = false
    clearRun()
end
function callbackInstallers.Neverbirth_ResetBossOrderRun2()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitBossOrder)
end

function Neverbirth:UnloadBossOrder(unloaded)
    if unloaded ~= Neverbirth or disposed then return end
    disposed = true
    self:ExitBossOrder()
end
function callbackInstallers.Neverbirth_UnloadBossOrder()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadBossOrder)
end

callbackInstallers.Neverbirth_UseBossOrder()
callbackInstallers.Neverbirth_UpdateBossOrderEncounters()
callbackInstallers.Neverbirth_ResetBossOrderPendingEncounters()
callbackInstallers.Neverbirth_ResetBossOrderRun()
if ModCallbacks.MC_PRE_GAME_EXIT then
    callbackInstallers.Neverbirth_ResetBossOrderRun2()
end

if ModCallbacks.MC_POST_NPC_DEATH then
    callbackInstallers.Neverbirth_RewardBossOrderTarget()
end

if ModCallbacks.MC_POST_ENTITY_KILL then
    callbackInstallers.Neverbirth_RewardBossOrderTarget2()
end
if ModCallbacks.MC_PRE_MOD_UNLOAD then callbackInstallers.Neverbirth_UnloadBossOrder() end

end
