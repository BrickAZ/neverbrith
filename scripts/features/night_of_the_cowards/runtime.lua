-- Private night_of_the_cowards responsibility: runtime. No registration until an installer is called.
return function(Neverbirth, deps)
    local runtime = deps.Runtime
    local getPlayers = deps.getPlayers
    local anyPlayerHasItem = deps.anyPlayerHasItem
    local getPersistentData = deps.getPersistentData
    local grantTranscendenceOnce = deps.grantTranscendenceOnce
    local clearAuras = deps.clearAuras
    local clearPlayerBlocks = deps.clearPlayerBlocks
    local applyPlayerAuraState = deps.applyPlayerAuraState
    local callbackInstallers = {}

    local function setActive(active)
        active = active == true
        if runtime.active == active then return end
        runtime.active = active
        if not active then
            clearPlayerBlocks()
            clearAuras()
        end
    end

    local function postUpdate()
        for _, player in ipairs(getPlayers()) do grantTranscendenceOnce(player) end
        setActive(anyPlayerHasItem())
        if not runtime.active then return nil end
        for _, player in ipairs(getPlayers()) do applyPlayerAuraState(player) end
        return nil
    end
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    end

    local function newRoom()
        clearPlayerBlocks()
        clearAuras()
        setActive(anyPlayerHasItem())
        return nil
    end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function gameStarted()
        clearPlayerBlocks()
        clearAuras()
        runtime.fearSprites = {}
        runtime.active = false
        getPersistentData()
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        clearPlayerBlocks()
        clearAuras()
        runtime.fearSprites = {}
        runtime.active = false
        return nil
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    return {
        setActive = setActive,
        postUpdate = postUpdate,
        newRoom = newRoom,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        Installers = callbackInstallers,
    }
end
