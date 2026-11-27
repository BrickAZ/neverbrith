-- Private runtime ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local BLACK_CANDLE_ID = deps.State.BLACK_CANDLE_ID
    local runtime = deps.State.runtime
    local currentRunSeed = deps.State.currentRunSeed
    local save = deps.State.save
    local resetSavedState = deps.State.resetSavedState
    local getSavedState = deps.State.getSavedState
    local hasCollectible = deps.Queries.hasCollectible
    local collectibleCount = deps.Queries.collectibleCount
    local getPlayers = deps.Queries.getPlayers
    local processCurrentRoom = deps.Pedestals.processCurrentRoom
    local recordFirstAcquisition = deps.Acquisition.recordFirstAcquisition
    local settleAcquisitions = deps.Acquisition.settleAcquisitions
    local initializePlayerCounts = deps.Acquisition.initializePlayerCounts

    local function postUpdate()
        runtime.frame = runtime.frame + 1
        settleAcquisitions()
        return nil
    end
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    end

    local function newRoom()
        runtime.pending = {}
        runtime.failedBonusCandidates = {}
        processCurrentRoom()
        return nil
    end
    function callbackInstallers.newRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end

    local function gameStarted(_, isContinued)
        runtime.frame = 0
        runtime.serial = 0
        runtime.pending = {}
        runtime.failedBonusCandidates = {}
        runtime.resolvingQ4 = false
        runtime.testRunSeed = nil
        if not isContinued then
            resetSavedState(currentRunSeed())
            save()
        else
            getSavedState()
        end
        initializePlayerCounts()
        local state = getSavedState()
        if state and not state.yinCurseActive then
            for _, player in ipairs(getPlayers()) do
                if collectibleCount(player) > 0 then
                    recordFirstAcquisition(player, nil)
                    break
                end
            end
        end
        processCurrentRoom()
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function preGameExit()
        local state = getSavedState()
        if state and state.yinCurseActive then
            save()
        end
        runtime.pending = {}
        return nil
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    local function preExplosionImmunity(_, player, hit, immunity)
        if type(immunity) ~= "table" or immunity.reason ~= "EXPLOSION_IMMUNITY" then
            return nil
        end
        local state = getSavedState()
        if state and state.yinCurseActive and player and not hasCollectible(player, BLACK_CANDLE_ID) then
            return false -- Veto this native immunity source, not the damage call.
        end
        return nil
    end
    function callbackInstallers.preExplosionImmunity()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY, preExplosionImmunity)
    end

    return {
        postUpdate = postUpdate,
        newRoom = newRoom,
        gameStarted = gameStarted,
        preGameExit = preGameExit,
        preExplosionImmunity = preExplosionImmunity,
        Installers = callbackInstallers,
    }
end
