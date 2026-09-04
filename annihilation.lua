return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = tonumber(context.ItemId) or -1
    local EFFECT_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local PLAYER_ENTITY = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local FRIENDLY_FLAG = EntityFlag and EntityFlag.FLAG_FRIENDLY or nil
    local CHARM_FLAG = EntityFlag and EntityFlag.FLAG_CHARM or nil
    local NO_ENTITY_COLLISION = (EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE) or 0
    local NO_GRID_COLLISION = (GridCollisionClass and GridCollisionClass.COLLISION_NONE) or 0
    local FIREDELAY_CACHE = CacheFlag and CacheFlag.CACHE_FIREDELAY or nil
    local RANGE_CACHE = CacheFlag and CacheFlag.CACHE_RANGE or nil
    local CAR_BATTERY_ID = CollectibleType and CollectibleType.COLLECTIBLE_CAR_BATTERY or 356
    local PRIMARY_ACTIVE_SLOT = ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0
    local SECONDARY_ACTIVE_SLOT = ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1
    local CAR_BATTERY_CHARGE_PER_HIT = 1
    local CAR_BATTERY_ACTIVE_SLOTS = { PRIMARY_ACTIVE_SLOT, SECONDARY_ACTIVE_SLOT }

    local variants = context.Variants or {}
    local AURA_VARIANT = tonumber(variants.Aura) or -1
    local SHOCKWAVE_VARIANT = tonumber(variants.Shockwave) or -1
    local ACTIVATE_VARIANT = tonumber(variants.Activate) or -1

    local AURA_ANM2 = "gfx/Effects/Annihilation/AnnihilationAura.anm2"
    local AURA_ANIMATION = "AuraLoop"
    local SHOCKWAVE_ANM2 = "gfx/Effects/Annihilation/AnnihilationShockwave.anm2"
    local SHOCKWAVE_ANIMATION = "Shockwave"
    local ACTIVATE_ANM2 = "gfx/Effects/Annihilation/AnnihilationActivate.anm2"
    local ACTIVATE_ANIMATION = "Activate"

    local DURATION_FRAMES = 150
    local KILL_EXTENSION_FRAMES = 9
    local AURA_INTERVAL_FRAMES = 4
    local AURA_RADIUS = 75
    local AURA_DAMAGE_MULTIPLIER = 0.40
    local SHOCKWAVE_RADIUS = 115
    local SHOCKWAVE_DAMAGE_MULTIPLIER = 1.00
    local SHOCKWAVE_FRAMES = 8
    local ACTIVATE_FRAMES = 6
    local RANGE_MULTIPLIER = 0.45
    local FIRE_FREQUENCY_MULTIPLIER = 0.60
    local GROUND_DEPTH_OFFSET = -10000
    local DEATH_DATA_KEY = "NeverbirthAnnihilationDeathResolved"
    local NO_DISCHARGE_RESULT = { Discharge = false, Remove = false, ShowAnim = false }

    local runtime = {
        states = {},
        roomNpcs = {},
        logicalFrame = 0,
    }

    local function debugLog(message)
        if type(context.DebugLog) == "function" then
            context.DebugLog("[Annihilation] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[Annihilation] " .. tostring(message))
        end
    end

    local function zeroVector()
        if Vector then
            local ok, value = pcall(function() return Vector.Zero end)
            if ok and value then return value end
        end
        if type(Vector) == "function" then return Vector(0, 0) end
        return nil
    end

    local function copyPosition(position)
        if type(Vector) == "function" and position then
            return Vector(tonumber(position.X) or 0, tonumber(position.Y) or 0)
        end
        return position
    end

    local function getData(entity)
        if not entity or type(entity.GetData) ~= "function" then return nil end
        local ok, data = pcall(entity.GetData, entity)
        return ok and type(data) == "table" and data or nil
    end

    local function entityExists(entity)
        if not entity then return false end
        if type(entity.Exists) == "function" then
            local ok, exists = pcall(entity.Exists, entity)
            return ok and exists == true
        end
        return true
    end

    local function entityIsDead(entity)
        if not entity or type(entity.IsDead) ~= "function" then return false end
        local ok, dead = pcall(entity.IsDead, entity)
        return ok and dead == true
    end

    local function playerIsDead(player)
        return player and type(player.IsDead) == "function" and entityIsDead(player) or false
    end

    local function toPlayer(entity)
        if not entity then return nil end
        if type(entity.ToPlayer) == "function" then
            local ok, player = pcall(entity.ToPlayer, entity)
            if ok and player then return player end
        end
        if tonumber(entity.Type) == PLAYER_ENTITY then return entity end
        return nil
    end

    local function toNpc(entity)
        if not entity then return nil end
        if type(entity.ToNPC) == "function" then
            local ok, npc = pcall(entity.ToNPC, entity)
            if ok and npc then return npc end
        end
        if type(entity.IsActiveEnemy) == "function" then return entity end
        return nil
    end

    local function hasEntityFlag(entity, flag)
        if not flag or not entity or type(entity.HasEntityFlags) ~= "function" then return false end
        local ok, value = pcall(entity.HasEntityFlags, entity, flag)
        return ok and value == true
    end

    local function isHostileNpc(entity, requireVulnerable)
        local npc = toNpc(entity)
        if not npc or not entityExists(npc) or entityIsDead(npc) then return false end
        if hasEntityFlag(npc, FRIENDLY_FLAG) or hasEntityFlag(npc, CHARM_FLAG) then return false end
        if type(npc.IsActiveEnemy) == "function" then
            local ok, active = pcall(npc.IsActiveEnemy, npc, false)
            if not ok or active ~= true then return false end
        end
        if requireVulnerable and type(npc.IsVulnerableEnemy) == "function" then
            local ok, vulnerable = pcall(npc.IsVulnerableEnemy, npc)
            if not ok or vulnerable ~= true then return false end
        end
        return true
    end

    local function getPlayers()
        if type(context.GetPlayers) ~= "function" then return {} end
        local ok, players = pcall(context.GetPlayers)
        return ok and type(players) == "table" and players or {}
    end

    local function getRoomEntities()
        if type(context.GetRoomEntities) == "function" then
            local ok, entities = pcall(context.GetRoomEntities)
            if ok and type(entities) == "table" then return entities end
        end
        if Isaac and type(Isaac.GetRoomEntities) == "function" then
            local ok, entities = pcall(Isaac.GetRoomEntities)
            if ok and type(entities) == "table" then return entities end
        end
        return {}
    end

    local function getFrameCount()
        if type(context.GetFrameCount) == "function" then
            local ok, frame = pcall(context.GetFrameCount)
            if ok then return math.floor(tonumber(frame) or runtime.logicalFrame) end
        end
        if Game then
            local ok, game = pcall(Game)
            if ok and game and type(game.GetFrameCount) == "function" then
                local frameOk, frame = pcall(game.GetFrameCount, game)
                if frameOk then return math.floor(tonumber(frame) or runtime.logicalFrame) end
            end
        end
        return runtime.logicalFrame
    end

    local function getCollectibleConfig(itemId)
        if type(context.GetCollectibleConfig) == "function" then
            local ok, config = pcall(context.GetCollectibleConfig, itemId)
            if ok and config then return config end
        end
        if not Isaac or type(Isaac.GetItemConfig) ~= "function" then return nil end
        local ok, itemConfig = pcall(Isaac.GetItemConfig)
        if not ok or not itemConfig or type(itemConfig.GetCollectible) ~= "function" then return nil end
        local configOk, config = pcall(itemConfig.GetCollectible, itemConfig, itemId)
        return configOk and config or nil
    end

    local function getCollectibleMaxCharge(itemId)
        local config = getCollectibleConfig(itemId)
        if not config then return 0 end
        return math.max(0, tonumber(
            config.MaxCharges or config.MaxCharge or config.Charge or config.MaxChargeCount
        ) or 0)
    end

    local function playerHasCarBattery(player)
        if not player or not CAR_BATTERY_ID or CAR_BATTERY_ID <= 0
            or type(player.HasCollectible) ~= "function"
        then
            return false
        end
        local ok, hasBattery = pcall(player.HasCollectible, player, CAR_BATTERY_ID)
        return ok and hasBattery == true
    end

    local function chargeActiveSlot(player, slot)
        if not player or type(player.GetActiveItem) ~= "function"
            or type(player.GetActiveCharge) ~= "function"
            or type(player.SetActiveCharge) ~= "function"
        then
            return false
        end
        local itemOk, itemId = pcall(player.GetActiveItem, player, slot)
        itemId = itemOk and tonumber(itemId) or 0
        if not itemId or itemId <= 0 then return false end

        local maxCharge = getCollectibleMaxCharge(itemId)
        if maxCharge <= 0 then return false end
        local chargeOk, currentCharge = pcall(player.GetActiveCharge, player, slot)
        currentCharge = chargeOk and tonumber(currentCharge) or nil
        if not currentCharge or currentCharge >= maxCharge then return false end

        local nextCharge = math.min(maxCharge, currentCharge + CAR_BATTERY_CHARGE_PER_HIT)
        local setOk = pcall(player.SetActiveCharge, player, nextCharge, slot)
        return setOk
    end

    local function chargeCarBatterySynergy(player)
        if not runtime.states[player] or not playerHasCarBattery(player) then return 0 end
        local chargedSlots = 0
        for _, slot in ipairs(CAR_BATTERY_ACTIVE_SLOTS) do
            if chargeActiveSlot(player, slot) then chargedSlots = chargedSlots + 1 end
        end
        return chargedSlots
    end

    local function removeEffect(effect)
        if entityExists(effect) and type(effect.Remove) == "function" then
            pcall(effect.Remove, effect)
        end
    end

    local function spawnEffect(variant, path, animation, position, spawner, depthOffset)
        if variant <= 0 or not position then return nil end
        local effect = nil
        if type(context.SpawnEffect) == "function" then
            local ok, value = pcall(context.SpawnEffect, variant, position, spawner)
            if ok then effect = value end
        elseif Isaac and type(Isaac.Spawn) == "function" then
            local ok, value = pcall(
                Isaac.Spawn,
                EFFECT_ENTITY,
                variant,
                0,
                position,
                zeroVector(),
                spawner
            )
            if ok then effect = value end
        end
        if not effect then return nil end

        effect.Position = position
        effect.Velocity = zeroVector() or effect.Velocity
        effect.DepthOffset = depthOffset or 0
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        effect.Parent = spawner

        local sprite = type(effect.GetSprite) == "function" and effect:GetSprite() or nil
        if not sprite then
            removeEffect(effect)
            return nil
        end
        local loaded, loadError = pcall(function()
            sprite:Load(path, true)
            sprite:Play(animation, true)
            sprite.Rotation = 0
            sprite.Scale = Vector(1, 1)
        end)
        if not loaded then
            debugLog("visual load failed for " .. tostring(path) .. ": " .. tostring(loadError))
            removeEffect(effect)
            return nil
        end
        return effect
    end

    local function refreshTemporaryCaches(player)
        if not player or type(player.AddCacheFlags) ~= "function" or type(player.EvaluateItems) ~= "function" then
            return
        end
        local flags = 0
        if FIREDELAY_CACHE then flags = flags | FIREDELAY_CACHE end
        if RANGE_CACHE then flags = flags | RANGE_CACHE end
        if flags == 0 then return end
        pcall(player.AddCacheFlags, player, flags)
        pcall(player.EvaluateItems, player)
    end

    local function anyStateActive()
        return next(runtime.states) ~= nil
    end

    local function trackNpc(entity)
        local npc = toNpc(entity)
        if npc and isHostileNpc(npc, false) then
            runtime.roomNpcs[npc] = true
            return npc
        end
        return nil
    end

    local function seedRoomNpcs()
        for _, entity in ipairs(getRoomEntities()) do trackNpc(entity) end
    end

    local function circlesIntersect(origin, radius, npc)
        if not origin or not npc or not npc.Position then return false end
        local dx = (tonumber(origin.X) or 0) - (tonumber(npc.Position.X) or 0)
        local dy = (tonumber(origin.Y) or 0) - (tonumber(npc.Position.Y) or 0)
        local combined = radius + math.max(0, tonumber(npc.Size) or 0)
        return dx * dx + dy * dy <= combined * combined
    end

    local function distanceBetween(left, right)
        local dx = (tonumber(left and left.X) or 0) - (tonumber(right and right.X) or 0)
        local dy = (tonumber(left and left.Y) or 0) - (tonumber(right and right.Y) or 0)
        return math.sqrt(dx * dx + dy * dy)
    end

    local function damageNpc(npc, amount, player)
        if amount <= 0 or not isHostileNpc(npc, true) or type(npc.TakeDamage) ~= "function" then return false end
        local source = type(EntityRef) == "function" and EntityRef(player) or nil
        local ok, result = pcall(npc.TakeDamage, npc, amount, 0, source, 0)
        local hitSucceeded = ok and result ~= false
        if hitSucceeded then chargeCarBatterySynergy(player) end
        return hitSucceeded
    end

    local function applyAuraDamage(state)
        local player = state and state.player
        if not player or not player.Position then return end
        local amount = math.max(0, tonumber(player.Damage) or 0) * AURA_DAMAGE_MULTIPLIER
        for npc in pairs(runtime.roomNpcs) do
            if not entityExists(npc) or entityIsDead(npc) then
                runtime.roomNpcs[npc] = nil
            elseif circlesIntersect(player.Position, AURA_RADIUS, npc) then
                damageNpc(npc, amount, player)
            end
        end
    end

    local function updateShockwave(state, wave)
        local previousRadius = SHOCKWAVE_RADIUS * math.min(wave.age, SHOCKWAVE_FRAMES) / SHOCKWAVE_FRAMES
        wave.age = wave.age + 1
        local currentRadius = SHOCKWAVE_RADIUS * math.min(wave.age, SHOCKWAVE_FRAMES) / SHOCKWAVE_FRAMES
        local player = state.player
        local amount = math.max(0, tonumber(player and player.Damage) or 0) * SHOCKWAVE_DAMAGE_MULTIPLIER

        for npc in pairs(runtime.roomNpcs) do
            if not entityExists(npc) or entityIsDead(npc) then
                runtime.roomNpcs[npc] = nil
            elseif not wave.hit[npc] and isHostileNpc(npc, true) and npc.Position then
                local distance = distanceBetween(wave.origin, npc.Position)
                local size = math.max(0, tonumber(npc.Size) or 0)
                if distance - size <= currentRadius and distance + size >= previousRadius then
                    wave.hit[npc] = true
                    damageNpc(npc, amount, player)
                end
            end
        end

        if wave.age >= SHOCKWAVE_FRAMES then
            removeEffect(wave.effect)
            return false
        end
        return true
    end

    local function removeStateVisuals(state)
        if not state then return end
        removeEffect(state.aura)
        removeEffect(state.activation and state.activation.effect)
        for _, wave in ipairs(state.shockwaves or {}) do removeEffect(wave.effect) end
        state.aura = nil
        state.activation = nil
        state.shockwaves = {}
    end

    local function endState(player, refreshCache)
        local state = runtime.states[player]
        if not state then return false end
        runtime.states[player] = nil
        removeStateVisuals(state)
        if refreshCache ~= false then refreshTemporaryCaches(player) end
        if not anyStateActive() then runtime.roomNpcs = {} end
        return true
    end

    local function createShockwave(state)
        if not state or not state.player or not state.player.Position then return nil end
        local origin = copyPosition(state.player.Position)
        local effect = spawnEffect(
            SHOCKWAVE_VARIANT,
            SHOCKWAVE_ANM2,
            SHOCKWAVE_ANIMATION,
            origin,
            state.player,
            GROUND_DEPTH_OFFSET + 1
        )
        local wave = { origin = origin, effect = effect, age = 0, hit = {} }
        state.shockwaves[#state.shockwaves + 1] = wave
        return wave
    end

    local function startState(player)
        if not player or runtime.states[player] then return false end
        local state = {
            player = player,
            remaining = DURATION_FRAMES,
            elapsed = 0,
            shockwaves = {},
            lastWaveFrame = nil,
        }
        runtime.states[player] = state
        seedRoomNpcs()
        state.aura = spawnEffect(
            AURA_VARIANT,
            AURA_ANM2,
            AURA_ANIMATION,
            player.Position,
            player,
            GROUND_DEPTH_OFFSET
        )
        state.activation = {
            age = 0,
            effect = spawnEffect(
                ACTIVATE_VARIANT,
                ACTIVATE_ANM2,
                ACTIVATE_ANIMATION,
                player.Position,
                player,
                GROUND_DEPTH_OFFSET + 2
            ),
        }
        refreshTemporaryCaches(player)
        return true
    end

    local function useItem(_, _, _, player)
        if not player or runtime.states[player] then return NO_DISCHARGE_RESULT end
        if startState(player) then return true end
        return NO_DISCHARGE_RESULT
    end

    local function updateState(player, state)
        if not player or not entityExists(player) or playerIsDead(player) then
            endState(player, false)
            return
        end

        state.elapsed = state.elapsed + 1
        state.remaining = state.remaining - 1

        if entityExists(state.aura) then
            state.aura.Position = player.Position
            state.aura.Velocity = zeroVector() or state.aura.Velocity
            state.aura.DepthOffset = GROUND_DEPTH_OFFSET
        end

        if state.activation then
            state.activation.age = state.activation.age + 1
            if entityExists(state.activation.effect) then
                state.activation.effect.Position = player.Position
                state.activation.effect.Velocity = zeroVector() or state.activation.effect.Velocity
            end
            if state.activation.age >= ACTIVATE_FRAMES then
                removeEffect(state.activation.effect)
                state.activation = nil
            end
        end

        for index = #state.shockwaves, 1, -1 do
            if not updateShockwave(state, state.shockwaves[index]) then
                table.remove(state.shockwaves, index)
            end
        end

        if state.elapsed % AURA_INTERVAL_FRAMES == 0 then applyAuraDamage(state) end
        if state.remaining <= 0 then endState(player, true) end
    end

    local function postUpdate()
        runtime.logicalFrame = runtime.logicalFrame + 1
        for player, state in pairs(runtime.states) do updateState(player, state) end
        return nil
    end

    local function evaluateCache(_, player, cacheFlag)
        if not runtime.states[player] then return nil end
        if RANGE_CACHE and cacheFlag == RANGE_CACHE then
            player.TearRange = (tonumber(player.TearRange) or 0) * RANGE_MULTIPLIER
        elseif FIREDELAY_CACHE and cacheFlag == FIREDELAY_CACHE then
            local currentDelay = tonumber(player.MaxFireDelay) or 0
            player.MaxFireDelay = (currentDelay + 1) / FIRE_FREQUENCY_MULTIPLIER - 1
        end
        return nil
    end

    local function tearOwner(tear)
        if not tear then return nil end
        return toPlayer(tear.SpawnerEntity) or toPlayer(tear.Parent)
    end

    local function removeTear(tear)
        if not tear then return end
        if type(tear.Remove) == "function" then
            pcall(tear.Remove, tear)
        elseif type(tear.Die) == "function" then
            pcall(tear.Die, tear)
        end
    end

    local function postFireTear(_, tear)
        local player = tearOwner(tear)
        local state = player and runtime.states[player] or nil
        if not state then return nil end
        removeTear(tear)
        local frame = getFrameCount()
        if state.lastWaveFrame ~= frame then
            state.lastWaveFrame = frame
            createShockwave(state)
        end
        return nil
    end

    local function npcInit(_, npc)
        if anyStateActive() then trackNpc(npc) end
        return nil
    end

    local function npcUpdate(_, npc)
        if anyStateActive() and not runtime.roomNpcs[npc] then trackNpc(npc) end
        return nil
    end

    local function deathAlreadyResolved(npc)
        local data = getData(npc)
        return data and data[DEATH_DATA_KEY] == true or false
    end

    local function markDeathResolved(npc)
        local data = getData(npc)
        if data then data[DEATH_DATA_KEY] = true end
    end

    local function resolveEnemyDeath(npc)
        npc = toNpc(npc)
        if not npc or not anyStateActive() or deathAlreadyResolved(npc) then return false end
        if not runtime.roomNpcs[npc] then return false end
        if hasEntityFlag(npc, FRIENDLY_FLAG) or hasEntityFlag(npc, CHARM_FLAG) then
            runtime.roomNpcs[npc] = nil
            markDeathResolved(npc)
            return false
        end
        markDeathResolved(npc)
        runtime.roomNpcs[npc] = nil
        for _, state in pairs(runtime.states) do
            state.remaining = state.remaining + KILL_EXTENSION_FRAMES
        end
        return true
    end

    local function npcDeath(_, npc)
        resolveEnemyDeath(npc)
        return nil
    end

    local function entityKill(_, entity)
        resolveEnemyDeath(entity)
        return nil
    end

    local function clearAll(refreshCache)
        local players = {}
        for player in pairs(runtime.states) do players[#players + 1] = player end
        for _, player in ipairs(players) do endState(player, refreshCache) end
        runtime.states = {}
        runtime.roomNpcs = {}
    end

    local function newRoom()
        clearAll(true)
        return nil
    end

    local function gameStarted()
        clearAll(false)
        runtime.logicalFrame = 0
        return nil
    end

    local function preGameExit()
        clearAll(false)
        return nil
    end

    Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, useItem, ITEM_ID)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    if ModCallbacks.MC_EVALUATE_CACHE then
        Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, evaluateCache)
    end
    if ModCallbacks.MC_POST_FIRE_TEAR then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, postFireTear)
    end
    if ModCallbacks.MC_POST_NPC_INIT then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
    end
    if ModCallbacks.MC_NPC_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate)
    end
    if ModCallbacks.MC_POST_NPC_DEATH then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, npcDeath)
    end
    if ModCallbacks.MC_POST_ENTITY_KILL then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, entityKill)
    end
    if ModCallbacks.MC_POST_NEW_ROOM then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    local api = {
        ItemId = ITEM_ID,
        Variants = { Aura = AURA_VARIANT, Shockwave = SHOCKWAVE_VARIANT, Activate = ACTIVATE_VARIANT },
        Paths = { Aura = AURA_ANM2, Shockwave = SHOCKWAVE_ANM2, Activate = ACTIVATE_ANM2 },
        Animations = { Aura = AURA_ANIMATION, Shockwave = SHOCKWAVE_ANIMATION, Activate = ACTIVATE_ANIMATION },
        DurationFrames = DURATION_FRAMES,
        KillExtensionFrames = KILL_EXTENSION_FRAMES,
        AuraIntervalFrames = AURA_INTERVAL_FRAMES,
        AuraRadius = AURA_RADIUS,
        ShockwaveRadius = SHOCKWAVE_RADIUS,
        RangeMultiplier = RANGE_MULTIPLIER,
        FireFrequencyMultiplier = FIRE_FREQUENCY_MULTIPLIER,
        CarBatteryId = CAR_BATTERY_ID,
        CarBatteryChargePerHit = CAR_BATTERY_CHARGE_PER_HIT,
        Runtime = runtime,
        GetState = function(player) return runtime.states[player] end,
        IsHostileNpc = isHostileNpc,
        StartState = startState,
        EndState = endState,
        CreateShockwave = createShockwave,
        ChargeCarBatterySynergy = chargeCarBatterySynergy,
        ResolveEnemyDeath = resolveEnemyDeath,
        Callbacks = {
            UseItem = useItem,
            Update = postUpdate,
            EvaluateCache = evaluateCache,
            PostFireTear = postFireTear,
            NpcInit = npcInit,
            NpcUpdate = npcUpdate,
            NpcDeath = npcDeath,
            EntityKill = entityKill,
            NewRoom = newRoom,
            GameStarted = gameStarted,
            PreGameExit = preGameExit,
        },
    }
    Neverbirth.AnnihilationTestAPI = api
    return api
end
