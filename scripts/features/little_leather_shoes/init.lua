-- Owns enemy chains, floor settlement and callback order; assembles traffic rewards and presentation.
return function(Neverbirth, dependencies)
-- Keep native bindings beside handlers; invoke at their original installation phase.
local callbackInstallers = {}
local Items = assert(dependencies.Items)
local GetPlayers = assert(dependencies.GetPlayers)
local IsValidItemId = assert(dependencies.IsValidItemId)
local DebugLog = assert(dependencies.Log)
local running, disposed = true, false

    local SHOES = Items.LittleLeatherShoes
    local UNBOXING = Items.TrafficUnboxing
    local EXPOSURE = Items.TrafficExposure
    local HEAT = Items.TrafficHeat
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local BOSS_ROOM = (RoomType and RoomType.ROOM_BOSS) or 5
    local FRIENDLY = (EntityFlag and EntityFlag.FLAG_FRIENDLY) or 0
    local unboxing = include("scripts.features.traffic_unboxing")()
    local trafficAnm2 = {
        [UNBOXING] = "gfx/Items/Collectibles/traffic_unboxing.anm2",
        [EXPOSURE] = "gfx/Items/Collectibles/traffic_exposure.anm2",
        [HEAT] = "gfx/Items/Collectibles/traffic_heat.anm2",
    }

    local state = {}
    -- Existing behavior tests and the traffic fixture inspect this runtime view.
    Neverbirth.LittleLeatherShoesState = state
    local views = include("scripts.features.little_leather_shoes.runtime_views")(state)
    local rewards, presentation -- Used only after assembly by the lifecycle callbacks.
    local function log(message)
        DebugLog("[neverbirth][Shoes] " .. message)
    end

    local function call(object, methodName, ...)
        local method = object and object[methodName]
        if type(method) ~= "function" then return nil, false end
        local ok, value = pcall(method, object, ...)
        if not ok then return nil, false end
        return value, true
    end

    local function copyPosition(position)
        return Vector(position and tonumber(position.X) or 0, position and tonumber(position.Y) or 0)
    end

    local function dataOf(entity)
        local data, ok = call(entity, "GetData")
        return ok and type(data) == "table" and data or nil
    end

    local function entityKey(entity)
        if not entity then return "nil" end
        if entity.InitSeed ~= nil then return "seed:" .. tostring(entity.InitSeed) end
        return tostring(entity)
    end

    local function playerKey(player)
        return tostring((player and player.InitSeed) or "")
    end

    local function sameEntity(a, b)
        return a ~= nil and b ~= nil and (a == b or (a.InitSeed ~= nil and b.InitSeed ~= nil and a.InitSeed == b.InitSeed))
    end

    local rules = include("scripts.features.little_leather_shoes.rules")({ Items = Items })
    local returnChance, shouldReturn = rules.GetReturnChance, rules.ShouldReturn
    local trafficTier, nextTrafficTarget, roomTraffic = rules.GetTier, rules.GetNextTrafficTarget, rules.GetRoomTraffic
    local rewardItems = rules.GetRewardItems
    local heat = include("scripts.features.traffic_heat")(Neverbirth, {
        Store = dependencies.Store, RefreshRuntime = views.Heat, GetFrame = function() return state.frame end,
        GetPlayers = GetPlayers, PlayerKey = playerKey, Call = call, Log = log,
    })
    local addTears = heat.AddTears
    local processHeatRefreshes, queueOwnedHeatRefreshes, addHeat = heat.ProcessRefreshes, heat.QueueOwnedRefreshes, heat.Add

    local function resetFloor(enabled)
        state.floorSerial = (tonumber(state.floorSerial) or 0) + 1
        state.floorEnabled = enabled == true
        state.returnsEnabled = enabled == true
        state.floorTraffic = 0
        state.floorBossSettled = false
        state.rooms = {}
        state.splitWatch = {}
        state.pendingReturns = {}
        state.pendingBossRewards = {}
        state.nextChainId = 1
        state.frame = 0
        state.releasingAward = false
        state.spawningReturn = nil
        heat.ResetTransient(); rewards.ResetFloor(); presentation.ResetFloor()
        log("floor reset enabled=" .. tostring(state.floorEnabled))
    end

    local function anyShoes()
        if not IsValidItemId(SHOES) then return false end
        for _, player in ipairs(GetPlayers()) do
            local held, ok = call(player, "HasCollectible", SHOES)
            if ok and held == true then return true end
        end
        return false
    end

    local persistent = heat.GetData
    local function roomKey()
        local game = Game()
        local level = game and game:GetLevel() or nil
        local stage = level and level.GetStage and level:GetStage() or 0
        local stageType = level and level.GetStageType and level:GetStageType() or 0
        local dimension = level and level.GetDimension and level:GetDimension() or 0
        local index = level and level.GetCurrentRoomIndex and level:GetCurrentRoomIndex() or 0
        return table.concat({ state.floorSerial or 0, stage, stageType, dimension, index }, ":")
    end

    local function getRoom(key, create)
        key = key or roomKey()
        local value = state.rooms[key]
        if not value and create ~= false then
            value = { key = key, chains = {}, settled = false, pendingAward = false, awardReleased = false }
            state.rooms[key] = value
        end
        return value
    end

    local function present(entity)
        if not entity then return false end
        local exists, ok = call(entity, "Exists")
        return not ok or exists == true
    end

    local function bossOrMiniBoss(npc)
        local boss, ok = call(npc, "IsBoss")
        if ok and boss == true then return true end
        local bossId, idOk = call(npc, "GetBossID")
        return idOk and type(bossId) == "number" and bossId > 0
    end

    local function segmented(npc)
        if not npc then return false end
        if present(npc.Parent) or present(npc.Child) or present(npc.ParentNPC) or present(npc.ChildNPC) then return true end
        return tonumber(npc.GroupIdx) ~= nil and tonumber(npc.GroupIdx) > 0
    end

    local function eligible(npc)
        if not npc or not state.floorEnabled or bossOrMiniBoss(npc) or segmented(npc) then return false end
        local data = dataOf(npc)
        if data and data.NeverbirthLittleLeatherShoesExcluded then return false end
        local dead, deadOk = call(npc, "IsDead"); if deadOk and dead == true then return false end
        local enemy, enemyOk = call(npc, "IsEnemy"); if enemyOk and enemy ~= true then return false end
        local vulnerable, vulnerableOk = call(npc, "IsVulnerableEnemy"); if vulnerableOk and vulnerable ~= true then return false end
        local active, activeOk = call(npc, "IsActiveEnemy", false); if activeOk and active ~= true then return false end
        if FRIENDLY ~= 0 then local friendly, friendlyOk = call(npc, "HasEntityFlags", FRIENDLY); if friendlyOk and friendly == true then return false end end
        return true
    end

    local function markSplitChild(npc, key)
        local spawner = npc and npc.SpawnerEntity
        if not spawner then return false end
        for _, watch in ipairs(state.splitWatch) do
            if watch.roomKey == key and sameEntity(spawner, watch.source) then
                watch.split = true
                local room = getRoom(key, false)
                local chain = room and room.chains[watch.chainId]
                if chain then chain.excluded = true end
                local data = dataOf(npc); if data then data.NeverbirthLittleLeatherShoesExcluded = true end
                return true
            end
        end
        return false
    end

    local function registerNpc(npc)
        if not state.floorEnabled then return nil end
        local key = roomKey()
        if markSplitChild(npc, key) or not eligible(npc) then return nil end
        local data = dataOf(npc)
        if not data then return nil end
        local existing = getRoom(key, false)
        if data.NeverbirthLittleLeatherShoesRoomKey == key and existing
            and existing.chains[data.NeverbirthLittleLeatherShoesChainId] then
            return data.NeverbirthLittleLeatherShoesChainId
        end
        local id = state.nextChainId; state.nextChainId = id + 1
        getRoom(key, true).chains[id] = { id = id, deaths = 0, excluded = false }
        data.NeverbirthLittleLeatherShoesChainId = id
        data.NeverbirthLittleLeatherShoesRoomKey = key
        data.NeverbirthLittleLeatherShoesDeathHandled = false
        log("registered room=" .. key .. " chain=" .. id .. " npc=" .. entityKey(npc))
        return id
    end

    local function scanRoom()
        if not state.floorEnabled then return end
        local room = getRoom(roomKey(), true)
        if room.scanned then return end
        room.scanned = true
        for _, entity in ipairs(Isaac.GetRoomEntities and Isaac.GetRoomEntities() or {}) do
            local npc = entity and entity.ToNPC and entity:ToNPC()
            if npc then registerNpc(npc) end
        end
    end

    local function deterministicRoll(snapshot, deathCount)
        local seed = ((snapshot.roomSeed or 0) * 1103515245 + (snapshot.initSeed or 0) * 12345) % 2147483647
        return (seed + (snapshot.chainId or 0) * 97 + deathCount * 53) % 100
    end

    local function snapshot(npc, chainId, key)
        local champion, championOk = call(npc, "IsChampion")
        local color, colorOk = call(npc, "GetChampionColorIdx")
        local room = Game():GetRoom()
        return {
            type = npc.Type, variant = npc.Variant, subtype = npc.SubType,
            position = copyPosition(npc.Position), initSeed = tonumber(npc.InitSeed) or 0,
            roomSeed = room and room.GetSpawnSeed and room:GetSpawnSeed() or 0,
            maxHp = math.max(1, tonumber(npc.MaxHitPoints) or tonumber(npc.HitPoints) or 1),
            champion = championOk and champion == true, championColor = colorOk and color or -1,
            chainId = chainId, roomKey = key,
        }
    end

    local function pendingFor(key)
        for _, value in ipairs(state.splitWatch) do if value.roomKey == key then return true end end
        for _, value in ipairs(state.pendingReturns) do if value.roomKey == key then return true end end
        return false
    end

    local function spawnReturn(value)
        if not state.returnsEnabled or value.roomKey ~= roomKey() then return nil end
        local snap = value.snapshot
        state.spawningReturn = value
        local spawnOk, spawned = pcall(Isaac.Spawn, snap.type, snap.variant, snap.subtype, snap.position, Vector(0, 0), nil)
        state.spawningReturn = nil
        if not spawnOk then log("return spawn failed chain=" .. snap.chainId); return nil end
        local npc = spawned and spawned.ToNPC and spawned:ToNPC() or spawned
        if not npc then log("return spawn missing chain=" .. snap.chainId); return nil end
        if snap.champion and npc.MakeChampion then pcall(function() npc:MakeChampion(snap.initSeed + value.deathCount, snap.championColor, true) end) end
        npc.MaxHitPoints = snap.maxHp; npc.HitPoints = snap.maxHp
        local data = dataOf(npc)
        if data then
            data.NeverbirthLittleLeatherShoesChainId = snap.chainId
            data.NeverbirthLittleLeatherShoesRoomKey = snap.roomKey
            data.NeverbirthLittleLeatherShoesDeathHandled = false
            data.NeverbirthLittleLeatherShoesReturnBody = true
        end
        log("return spawned chain=" .. snap.chainId .. " afterDeath=" .. value.deathCount)
        return npc
    end

    local function queueBossReward(tier, key)
        state.pendingBossRewards[#state.pendingBossRewards + 1] = { tier = tier, roomKey = key, due = state.frame + 1 }
    end

    local function settleRoom()
        if not state.floorEnabled then return 0 end
        local key = roomKey(); local value = getRoom(key, true)
        if value.settled then return value.traffic or 0 end
        value.settled = true; value.traffic = roomTraffic(value.chains)
        state.floorTraffic = state.floorTraffic + value.traffic
        log("settled room=" .. key .. " gained=" .. value.traffic .. " total=" .. state.floorTraffic)
        local room = Game():GetRoom()
        if room and room.GetType and room:GetType() == BOSS_ROOM and not state.floorBossSettled then
            state.floorBossSettled = true
            local tier = trafficTier(state.floorTraffic)
            log("boss settled traffic=" .. state.floorTraffic .. " tier=" .. tier)
            if tier > 0 then queueBossReward(tier, key) end
            state.floorTraffic = 0
        end
        return value.traffic
    end

    presentation = include("scripts.features.little_leather_shoes.presentation")({
        Runtime = views.Presentation, Rules = rules, Animations = trafficAnm2, CopyPosition = copyPosition,
        GetHudState = function() return state.floorEnabled, state.floorTraffic end,
    })
    rewards = include("scripts.features.little_leather_shoes.rewards")({
        Runtime = views.Rewards, Presentation = presentation, Rules = rules, Items = Items, Unboxing = unboxing, AddHeat = addHeat,
        GetPlayers = GetPlayers, IsValidItemId = IsValidItemId, Animations = trafficAnm2,
        CopyPosition = copyPosition, DataOf = dataOf, EntityKey = entityKey, PlayerKey = playerKey, RoomKey = roomKey, Log = log,
        IsRunning = function() return running end,
    })
    local spawnBossReward, resolveChoice = rewards.SpawnBossReward, rewards.ResolveChoice
    local trackTrafficPickup = rewards.TrackPickup
    local processTrafficInventory, processTrafficPlayer = rewards.ProcessInventory, rewards.ProcessPlayer
    local visual, processVisuals, exposure = rewards.QueuePickupVisual, rewards.ProcessPickupVisuals, rewards.ResolveExposure

    local function processSplitWatch()
        for index = #state.splitWatch, 1, -1 do
            local value = state.splitWatch[index]
            if state.frame >= value.expires then
                local roll = deterministicRoll(value.snapshot, value.deaths)
                local queued = not value.split and state.returnsEnabled and shouldReturn(roll, value.deaths)
                log(string.format("return roll chain=%d deaths=%d roll=%d threshold=%d split=%s enabled=%s queued=%s", value.chainId, value.deaths, roll, returnChance(value.deaths), tostring(value.split), tostring(state.returnsEnabled), tostring(queued)))
                if queued then
                    state.pendingReturns[#state.pendingReturns + 1] = { snapshot = value.snapshot, roomKey = value.roomKey, deathCount = value.deaths, due = state.frame + 1 }
                end
                table.remove(state.splitWatch, index)
            end
        end
    end

    local function roomReady()
        local room = Game():GetRoom(); if not room or pendingFor(roomKey()) then return false end
        local clear, clearOk = call(room, "IsClear"); if clearOk and clear ~= true then return false end
        local alive, aliveOk = call(room, "GetAliveEnemiesCount")
        if aliveOk and tonumber(alive) and alive > 0 then return false end
        local roomType = room:GetType()
        local active = call(room, "IsAmbushActive")
        local waveRoom = roomType == ((RoomType and RoomType.ROOM_CHALLENGE) or 11)
            or roomType == ((RoomType and RoomType.ROOM_BOSSRUSH) or 17)
        if waveRoom or active == true then
            local done, doneOk = call(room, "IsAmbushDone")
            if not doneOk or done ~= true then return false end
        end
        return true
    end

    local function processSettlement()
        if not state.floorEnabled or not roomReady() then return end
        local value = getRoom(roomKey(), true); settleRoom()
        if value.pendingAward and not value.awardReleased then
            value.awardReleased = true; local room = Game():GetRoom()
            if room and room.SpawnClearAward then state.releasingAward = true; pcall(function() room:SpawnClearAward() end); state.releasingAward = false end
        end
    end

    local function handleFloorOwnership(hasShoes)
        if state.floorEnabled and state.returnsEnabled and not hasShoes then
            state.returnsEnabled = false
            state.pendingReturns = {}
            log("returns disabled: item lost")
        end
    end

    local function update()
        if not running then return nil end
        state.frame = (state.frame or 0) + 1
        handleFloorOwnership(anyShoes())
        processHeatRefreshes()
        processSplitWatch()
        for index = #state.pendingReturns, 1, -1 do local value = state.pendingReturns[index]; if not state.returnsEnabled or value.roomKey ~= roomKey() then table.remove(state.pendingReturns, index) elseif state.frame >= value.due then spawnReturn(value); table.remove(state.pendingReturns, index) end end
        processTrafficInventory(); processVisuals()
        for index = #state.pendingBossRewards, 1, -1 do local value = state.pendingBossRewards[index]; if value.roomKey ~= roomKey() then table.remove(state.pendingBossRewards, index) elseif state.frame >= value.due then spawnBossReward(value.tier); table.remove(state.pendingBossRewards, index) end end
        processSettlement()
    end
    function callbackInstallers.update()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    end

    local function npcInit(_, npc)
        if not running then return nil end
        local pending = state.spawningReturn
        if pending and pending.snapshot then
            local snap = pending.snapshot
            local data = dataOf(npc)
            if data then
                data.NeverbirthLittleLeatherShoesChainId = snap.chainId
                data.NeverbirthLittleLeatherShoesRoomKey = snap.roomKey
                data.NeverbirthLittleLeatherShoesDeathHandled = false
                data.NeverbirthLittleLeatherShoesReturnBody = true
            end
            return nil
        end
        registerNpc(npc)
        return nil
    end
    function callbackInstallers.npcInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
    end

    local function entityKill(_, entity)
        if not state.floorEnabled or not entity then return nil end
        local npc = entity.ToNPC and entity:ToNPC(); local data = dataOf(npc)
        if not npc or not data or data.NeverbirthLittleLeatherShoesDeathHandled then return nil end
        local id, key = data.NeverbirthLittleLeatherShoesChainId, data.NeverbirthLittleLeatherShoesRoomKey
        local room = id and key and getRoom(key, false); local chain = room and room.chains[id]
        if not chain or chain.excluded then return nil end
        data.NeverbirthLittleLeatherShoesDeathHandled = true; chain.deaths = chain.deaths + 1
        state.splitWatch[#state.splitWatch + 1] = { source = npc, chainId = id, roomKey = key, deaths = chain.deaths, snapshot = snapshot(npc, id, key), expires = state.frame + 2, split = false }
        return nil
    end
    function callbackInstallers.entityKill()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, entityKill)
    end

    local function npcUpdate(_, npc)
        if not state.floorEnabled then return nil end
        local data = dataOf(npc)
        if not data or data.NeverbirthLittleLeatherShoesExcluded then return nil end
        local key = roomKey()
        local room = getRoom(key, false)
        if data.NeverbirthLittleLeatherShoesRoomKey == key and room
            and room.chains[data.NeverbirthLittleLeatherShoesChainId] then return nil end
        registerNpc(npc)
        return nil
    end
    function callbackInstallers.npcUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate)
    end

    local function preClearAward()
        if not state.floorEnabled or state.releasingAward then return nil end
        local room = getRoom(roomKey(), true)
        if pendingFor(room.key) or not roomReady() then room.pendingAward = true; return true end
        settleRoom(); return nil
    end
    function callbackInstallers.preClearAward()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, preClearAward)
    end

    local function newRoom() if running and state.floorEnabled then getRoom(roomKey(), true); scanRoom() end end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end
    local function newLevel()
        if not running then return end
        resetFloor(anyShoes()); queueOwnedHeatRefreshes()
    end
    function callbackInstallers.newLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
    end
    local function gameStarted(_, isContinued)
        if disposed then return end
        running = true
        rewards.ResetRun()
        resetFloor(anyShoes())
        if isContinued == true then queueOwnedHeatRefreshes() else heat.ResetRun() end
        scanRoom()
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        if not running then return end
        running = false
        resetFloor(false)
        rewards.ResetRun()
        presentation.ResetRun()
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    local function preModUnload(_, unloaded)
        if unloaded ~= Neverbirth or disposed then return end
        preGameExit()
        disposed = true
    end
    function callbackInstallers.preModUnload()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, preModUnload)
    end

    local evaluateHeat = heat.Evaluate
    local render = presentation.Render

    resetFloor(false)

    Neverbirth.LittleLeatherShoesTestAPI = {
        GetReturnChance = returnChance, ShouldReturn = shouldReturn, GetTier = trafficTier,
        GetNextTrafficTarget = nextTrafficTarget, GetRoomTraffic = roomTraffic,
        ApplyTearsBonus = addTears, GetRewardItemsForTraffic = rewardItems,
        ResetTransientState = resetFloor, IsBossOrMiniBoss = bossOrMiniBoss,
        IsSegmentedNpc = segmented, IsEligibleNpc = eligible, RegisterNpc = registerNpc,
        MarkSplitChild = markSplitChild, SettleCurrentRoom = settleRoom,
        SpawnTrafficBossReward = spawnBossReward, ResolveChoiceAtCollision = resolveChoice,
        AddHeat = addHeat, ProcessHeatRefreshes = processHeatRefreshes, GetPersistentData = persistent, HandleFloorOwnership = handleFloorOwnership, ResolveExposure = exposure,
        ProcessTrafficInventory = processTrafficInventory, ProcessTrafficPlayer = processTrafficPlayer, TrackTrafficPickup = trackTrafficPickup, QueuePickupVisual = visual, ProcessPickupVisuals = processVisuals, SpawnReturn = spawnReturn, Update = update, Render = render,
        Callbacks = { NpcInit = npcInit, NpcUpdate = npcUpdate, EntityKill = entityKill, PreClearAward = preClearAward, TrackTrafficPickup = trackTrafficPickup, EvaluateHeat = evaluateHeat },
    }

    if ModCallbacks.MC_POST_NPC_INIT then callbackInstallers.npcInit() end
    if ModCallbacks.MC_NPC_UPDATE then callbackInstallers.npcUpdate() end
    if ModCallbacks.MC_POST_ENTITY_KILL then callbackInstallers.entityKill() end
    callbackInstallers.update()
    if ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then callbackInstallers.preClearAward() end
    if ModCallbacks.MC_POST_NEW_ROOM then callbackInstallers.newRoom() end
    if ModCallbacks.MC_POST_NEW_LEVEL then callbackInstallers.newLevel() end
    if ModCallbacks.MC_POST_GAME_STARTED then callbackInstallers.gameStarted() end
    if ModCallbacks.MC_POST_PICKUP_UPDATE then rewards.InstallTrackPickup(Neverbirth, COLLECTIBLE_PICKUP) end
    heat.InstallCallback()
    if ModCallbacks.MC_POST_RENDER then presentation.InstallRender(Neverbirth) end
    if ModCallbacks.MC_PRE_GAME_EXIT then callbackInstallers.preGameExit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then callbackInstallers.preModUnload() end
    return { BindAcquisitions = rewards.BindAcquisitions }
end
