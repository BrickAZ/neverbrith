-- Private kamikaze_squad responsibility: runtime. No registration until an installer is called.
return function(Neverbirth, deps)
    local runtime = deps.Runtime
    local SPAWN_INTERVAL = deps.Config.SPAWN_INTERVAL
    local MAX_LIVE_PER_OWNER = deps.Config.MAX_LIVE_PER_OWNER
    local OWNED_KEY = deps.Config.OWNED_KEY
    local diagnostic = deps.diagnostic
    local entityKey = deps.entityKey
    local getPlayers = deps.getPlayers
    local hasItem = deps.hasItem
    local isPlayerUsable = deps.isPlayerUsable
    local trackEnemy = deps.trackEnemy
    local removeTrackedEnemy = deps.removeTrackedEnemy
    local pruneHostiles = deps.pruneHostiles
    local seedRoomHostiles = deps.seedRoomHostiles
    local getHolderState = deps.getHolderState
    local pruneUnits = deps.pruneUnits
    local removeUnitReference = deps.removeUnitReference
    local clearHolder = deps.clearHolder
    local clearRuntime = deps.clearRuntime
    local detonateAllOwned = deps.detonateAllOwned
    local spawnForHolder = deps.spawnForHolder
    local updateOwnedUnit = deps.updateOwnedUnit
    local callbackInstallers = {}

    local function postUpdate()
        local players = getPlayers()
        local seenPlayers = {}
        local hasHolder = false
        for _, player in ipairs(players) do
            local key = entityKey(player)
            if key then seenPlayers[key] = true end
            if key and isPlayerUsable(player) and hasItem(player) then
                hasHolder = true
                getHolderState(player, true)
            else
                clearHolder(key)
            end
        end

        local stalePlayers = {}
        for player in pairs(runtime.holders) do
            if not seenPlayers[player] then stalePlayers[#stalePlayers + 1] = player end
        end
        for _, player in ipairs(stalePlayers) do clearHolder(player) end
        if not hasHolder then
            runtime.hostiles = {}
            runtime.hostileSet = {}
            runtime.roomSeeded = false
            return
        end

        seedRoomHostiles()
        pruneHostiles()
        if #runtime.hostiles == 0 then
            detonateAllOwned()
            return
        end

        for _, state in pairs(runtime.holders) do
            pruneUnits(state)
            if #state.units < MAX_LIVE_PER_OWNER then
                state.timer = state.timer + 1
                if state.timer == 1 or state.timer == 89 or state.timer == 90 then
                    diagnostic("timer " .. state.timer .. " owner " .. state.key)
                end
                if state.timer >= SPAWN_INTERVAL then
                    state.timer = 0
                    spawnForHolder(state)
                end
            end
        end
    end
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    end

    local function npcUpdate(_, npc)
        local data = npc.GetData and npc:GetData() or nil
        if data and data[OWNED_KEY] then
            updateOwnedUnit(npc)
        elseif next(runtime.holders) ~= nil and not runtime.hostileSet[entityKey(npc)] then
            trackEnemy(npc)
        end
    end
    function callbackInstallers.npcUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate)
    end

    local function npcInit(_, npc)
        if next(runtime.holders) ~= nil then trackEnemy(npc) end
    end
    function callbackInstallers.npcInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
    end

    local function npcDeath(_, npc)
        removeTrackedEnemy(npc)
        local data = npc.GetData and npc:GetData() or nil
        if data and data[OWNED_KEY] then removeUnitReference(npc) end
    end
    function callbackInstallers.npcDeath()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, npcDeath)
    end

    local function entityRemove(_, entity)
        removeTrackedEnemy(entity)
        local data = entity.GetData and entity:GetData() or nil
        if data and data[OWNED_KEY] then removeUnitReference(entity) end
    end
    function callbackInstallers.entityRemove()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, entityRemove)
    end

    local function roomCleared()
        runtime.hostiles = {}
        runtime.hostileSet = {}
        detonateAllOwned()
    end
    function callbackInstallers.roomCleared()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, roomCleared)
    end

    local function newRoom() clearRuntime() end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function newLevel() clearRuntime() end
    function callbackInstallers.newLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
    end

    local function gameStarted() clearRuntime() end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit() clearRuntime() end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    return {
        postUpdate = postUpdate,
        npcUpdate = npcUpdate,
        npcInit = npcInit,
        npcDeath = npcDeath,
        entityRemove = entityRemove,
        roomCleared = roomCleared,
        newRoom = newRoom,
        newLevel = newLevel,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        Installers = callbackInstallers,
    }
end
