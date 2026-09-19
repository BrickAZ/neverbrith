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

    local failures = {}
    local diagnostics = context.Diagnostics == true
    local function trace(phase)
        if diagnostics then debugLog(phase) end
    end
    local function failOnce(kind, err)
        if failures[kind] then return end
        failures[kind] = tostring(err)
        debugLog(kind .. ": " .. tostring(err))
    end

    local function entityKey(entity)
        if not entity then return nil end
        local ok, hash = pcall(function() return GetPtrHash(entity) end)
        if not ok or hash == nil or entity.InitSeed == nil then
            failOnce("identity", ok and "missing GetPtrHash/InitSeed" or hash)
            return nil
        end
        return tostring(hash) .. ":" .. tostring(entity.InitSeed)
    end

    local function getState(player)
        local key = entityKey(player)
        local state = key and runtime.states[key]
        if state then state.player = player end
        return state
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
        if position then
            local ok, value = pcall(function() return Vector(position.X, position.Y) end)
            if ok then return value end
            failOnce("Vector", value)
        end
        return nil
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
        if not player or type(player.AddActiveCharge) ~= "function" then
            failOnce("nativeCharge", "AddActiveCharge unavailable; active charging skipped")
            return false
        end
        -- Fixed per-hit gain must not become a timed full recharge or reject special actives.
        local ok, added = pcall(player.AddActiveCharge, player, CAR_BATTERY_CHARGE_PER_HIT, slot, true, false, true)
        if not ok then
            failOnce("nativeCharge", "AddActiveCharge failed; active charging skipped")
            return false
        end
        return (tonumber(added) or 0) > 0
    end

    local function chargeCarBatterySynergy(player)
        if not getState(player) or not playerHasCarBattery(player) then return 0 end
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
            if ok then effect = value else failOnce("spawn", value) end
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
            if ok and value then
                local converted, result = pcall(function() return value:ToEffect() end)
                if converted then effect = result else failOnce("ToEffect", result) end
                if converted and not result then failOnce("ToEffect", "returned nil") end
                if not effect then removeEffect(value) end
            elseif not ok then failOnce("spawn", value) end
        end
        if not effect then return nil end

        local configured, configureError = pcall(function()
        effect.Position = position
        effect.Velocity = zeroVector() or effect.Velocity
        effect.DepthOffset = depthOffset or 0
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        effect.Parent = spawner

        local sprite = effect:GetSprite()
        assert(sprite, "GetSprite returned nil")
            assert(sprite:Load(path, true) ~= false, "Load returned false")
            assert(sprite:Play(animation, true) ~= false, "Play returned false")
            if type(sprite.IsPlaying) == "function" then
                assert(sprite:IsPlaying(animation), "animation not playing: " .. animation)
            end
            sprite.Rotation = 0
            sprite.Scale = Vector(1, 1)
        end)
        if not configured then
            failOnce("visual:" .. tostring(path), configureError)
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
            local key = entityKey(npc)
            if not key then return nil end
            runtime.roomNpcs[key] = npc
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
        local sourceOk, source = pcall(function() return EntityRef(player) end)
        if not sourceOk or not source then
            failOnce("EntityRef", sourceOk and "constructor returned nil" or source)
            return false
        end
        local ok, result = pcall(npc.TakeDamage, npc, amount, 0, source, 0)
        if not ok then failOnce("TakeDamage", result) end
        local hitSucceeded = ok and result ~= false
        local state = getState(player)
        if state and not state.damageObserved then
            state.damageObserved = true
            trace("first-damage:" .. tostring(hitSucceeded))
        end
        if hitSucceeded then chargeCarBatterySynergy(player) end
        return hitSucceeded
    end

    local function applyAuraDamage(state)
        local player = state and state.player
        if not player or not player.Position then return end
        local amount = math.max(0, tonumber(player.Damage) or 0) * AURA_DAMAGE_MULTIPLIER
        for key, npc in pairs(runtime.roomNpcs) do
            if not entityExists(npc) or entityIsDead(npc) then
                runtime.roomNpcs[key] = nil
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

        for key, npc in pairs(runtime.roomNpcs) do
            if not entityExists(npc) or entityIsDead(npc) then
                runtime.roomNpcs[key] = nil
            elseif not wave.hit[key] and isHostileNpc(npc, true) and npc.Position then
                local distance = distanceBetween(wave.origin, npc.Position)
                local size = math.max(0, tonumber(npc.Size) or 0)
                if distance - size <= currentRadius and distance + size >= previousRadius then
                    wave.hit[key] = true
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

    -- Internal cleanup must work after the owner's native handle has expired.
    local function endStateByKey(key, state, refreshCache, reason)
        if not state or runtime.states[key] ~= state then return false end
        runtime.states[key] = nil
        trace("end:" .. (reason or "manual"))
        removeStateVisuals(state)
        if refreshCache ~= false then refreshTemporaryCaches(state.player) end
        if not anyStateActive() then runtime.roomNpcs = {} end
        return true
    end

    local function endState(player, refreshCache, reason)
        local key = entityKey(player)
        return key and endStateByKey(key, runtime.states[key], refreshCache, reason) or false
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
        local key = entityKey(player)
        if not key or getState(player) then return false end
        local state = {
            player = player,
            remaining = DURATION_FRAMES,
            elapsed = 0,
            shockwaves = {},
            lastWaveFrame = nil,
        }
        runtime.states[key] = state
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
        trace("use")
        if not player or getState(player) then return NO_DISCHARGE_RESULT end
        if startState(player) then return true end
        return NO_DISCHARGE_RESULT
    end

    local function updateState(key, player, state)
        if not player or not entityExists(player) or playerIsDead(player) then
            endStateByKey(key, state, false, "invalid-owner")
            return
        end

        state.elapsed = state.elapsed + 1
        if state.elapsed == 1 then trace("first-update") end
        state.remaining = state.remaining - 1

        if entityExists(state.aura) then
            local ok, err = pcall(function()
            state.aura.Position = player.Position
            state.aura.Velocity = zeroVector() or state.aura.Velocity
            state.aura.DepthOffset = GROUND_DEPTH_OFFSET
            end)
            if not ok then failOnce("visual-update:aura", err); removeEffect(state.aura); state.aura = nil end
        end

        if state.activation then
            state.activation.age = state.activation.age + 1
            if entityExists(state.activation.effect) then
                local ok, err = pcall(function()
                state.activation.effect.Position = player.Position
                state.activation.effect.Velocity = zeroVector() or state.activation.effect.Velocity
                end)
                if not ok then
                    failOnce("visual-update:activation", err)
                    removeEffect(state.activation.effect)
                    state.activation.effect = nil
                end
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
        if state.remaining <= 0 then endStateByKey(key, state, true, "expired") end
    end

    local function postUpdate()
        runtime.logicalFrame = runtime.logicalFrame + 1
        for _, player in ipairs(getPlayers()) do getState(player) end
        for key, state in pairs(runtime.states) do updateState(key, state.player, state) end
        return nil
    end

    local function evaluateCache(_, player, cacheFlag)
        if not getState(player) then return nil end
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
        if tear.SpawnerEntity then return toPlayer(tear.SpawnerEntity) end
        return toPlayer(tear.Parent)
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
        if player and Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.OwnsAttack(player) then return nil end
        local state = player and getState(player) or nil
        if not state then return nil end
        if not state.shotObserved then state.shotObserved = true; trace("first-shot") end
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
        if anyStateActive() then trackNpc(npc) end
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
        local key = entityKey(npc)
        if not key or not runtime.roomNpcs[key] then return false end
        if hasEntityFlag(npc, FRIENDLY_FLAG) or hasEntityFlag(npc, CHARM_FLAG) then
            runtime.roomNpcs[key] = nil
            markDeathResolved(npc)
            return false
        end
        markDeathResolved(npc)
        runtime.roomNpcs[key] = nil
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

    local function clearAll(refreshCache, reason)
        local states = {}
        for key, state in pairs(runtime.states) do states[#states + 1] = { key = key, state = state } end
        for _, entry in ipairs(states) do
            endStateByKey(entry.key, entry.state, refreshCache, reason)
        end
        runtime.states = {}
        runtime.roomNpcs = {}
    end

    local function newRoom()
        clearAll(true, "room")
        return nil
    end

    local function gameStarted()
        clearAll(false, "game-start")
        runtime.logicalFrame = 0
        return nil
    end

    local function preGameExit()
        clearAll(false, "exit")
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

    trace("init")
    local api = {
        SetDiagnostics = function(enabled) diagnostics = enabled == true end,
        Failures = failures,
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
        GetState = getState,
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
