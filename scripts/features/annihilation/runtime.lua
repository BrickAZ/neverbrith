-- Private runtime ownership for Annihilation.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local runtime = deps.State
    local ITEM_ID = deps.Config.ITEM_ID
    local FRIENDLY_FLAG = deps.Config.FRIENDLY_FLAG
    local CHARM_FLAG = deps.Config.CHARM_FLAG
    local FIREDELAY_CACHE = deps.Config.FIREDELAY_CACHE
    local RANGE_CACHE = deps.Config.RANGE_CACHE
    local AURA_VARIANT = deps.Config.AURA_VARIANT
    local ACTIVATE_VARIANT = deps.Config.ACTIVATE_VARIANT
    local AURA_ANM2 = deps.Config.AURA_ANM2
    local AURA_ANIMATION = deps.Config.AURA_ANIMATION
    local ACTIVATE_ANM2 = deps.Config.ACTIVATE_ANM2
    local ACTIVATE_ANIMATION = deps.Config.ACTIVATE_ANIMATION
    local DURATION_FRAMES = deps.Config.DURATION_FRAMES
    local KILL_EXTENSION_FRAMES = deps.Config.KILL_EXTENSION_FRAMES
    local AURA_INTERVAL_FRAMES = deps.Config.AURA_INTERVAL_FRAMES
    local ACTIVATE_FRAMES = deps.Config.ACTIVATE_FRAMES
    local RANGE_MULTIPLIER = deps.Config.RANGE_MULTIPLIER
    local FIRE_FREQUENCY_MULTIPLIER = deps.Config.FIRE_FREQUENCY_MULTIPLIER
    local GROUND_DEPTH_OFFSET = deps.Config.GROUND_DEPTH_OFFSET
    local DEATH_DATA_KEY = deps.Config.DEATH_DATA_KEY
    local NO_DISCHARGE_RESULT = deps.Config.NO_DISCHARGE_RESULT
    local trace = deps.Queries.trace
    local failOnce = deps.Queries.failOnce
    local entityKey = deps.Queries.entityKey
    local zeroVector = deps.Queries.zeroVector
    local getData = deps.Queries.getData
    local entityExists = deps.Queries.entityExists
    local playerIsDead = deps.Queries.playerIsDead
    local toPlayer = deps.Queries.toPlayer
    local toNpc = deps.Queries.toNpc
    local hasEntityFlag = deps.Queries.hasEntityFlag
    local getPlayers = deps.Queries.getPlayers
    local getFrameCount = deps.Queries.getFrameCount
    local getState = deps.Ledger.getState
    local anyStateActive = deps.Ledger.anyStateActive
    local trackNpc = deps.Ledger.trackNpc
    local seedRoomNpcs = deps.Ledger.seedRoomNpcs
    local refreshTemporaryCaches = deps.Ledger.refreshTemporaryCaches
    local removeEffect = deps.Presentation.removeEffect
    local spawnEffect = deps.Presentation.spawnEffect
    local removeStateVisuals = deps.Presentation.removeStateVisuals
    local createShockwave = deps.Presentation.createShockwave
    local applyAuraDamage = deps.Combat.applyAuraDamage
    local updateShockwave = deps.Combat.updateShockwave
    local AttackOwnership = include("scripts.systems.attack_ownership")

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
    function callbackInstallers.useItem()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, useItem, ITEM_ID)
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
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
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
    function callbackInstallers.evaluateCache()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, evaluateCache)
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
        if player and AttackOwnership.AvadaOwnsAttack(Neverbirth, player) then return nil end
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
    function callbackInstallers.postFireTear()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, postFireTear)
    end

    local function npcInit(_, npc)
        if anyStateActive() then trackNpc(npc) end
        return nil
    end
    function callbackInstallers.npcInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
    end

    local function npcUpdate(_, npc)
        if anyStateActive() then trackNpc(npc) end
        return nil
    end
    function callbackInstallers.npcUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate)
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
    function callbackInstallers.npcDeath()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, npcDeath)
    end

    local function entityKill(_, entity)
        resolveEnemyDeath(entity)
        return nil
    end
    function callbackInstallers.entityKill()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_KILL, entityKill)
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
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function gameStarted()
        clearAll(false, "game-start")
        runtime.logicalFrame = 0
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        clearAll(false, "exit")
        return nil
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    return {
        endStateByKey = endStateByKey,
        endState = endState,
        startState = startState,
        useItem = useItem,
        updateState = updateState,
        postUpdate = postUpdate,
        evaluateCache = evaluateCache,
        tearOwner = tearOwner,
        removeTear = removeTear,
        postFireTear = postFireTear,
        npcInit = npcInit,
        npcUpdate = npcUpdate,
        deathAlreadyResolved = deathAlreadyResolved,
        markDeathResolved = markDeathResolved,
        resolveEnemyDeath = resolveEnemyDeath,
        npcDeath = npcDeath,
        entityKill = entityKill,
        clearAll = clearAll,
        newRoom = newRoom,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        Installers = callbackInstallers,
    }
end
