-- Continue validation, room/floor changes, exit and unload.
return function(mod, context, State, Runtime, TOTAL)
    local callbackInstallers = {}
    local runtime = State.runtime
    local save = State.save
    local playerKey = State.playerKey
    local floorKey = State.floorKey
    local data = State.data
    local currentFloor = State.currentFloor
    local bedRecord = State.bedRecord
    local sleepState = State.sleepState
    local hasOwner = State.hasOwner
    local inOrigin = State.inOrigin
    local isOwned = State.isOwned
    local clearRuntime = Runtime.clearRuntime
    local cancel = Runtime.cancel
    local syncFloor = Runtime.syncFloor
    local function gameStarted(_, continued)
        clearRuntime()
        runtime.completedUntil = nil
        runtime.ready = true
        if not continued then context.GetSaveRoot().healthySleep={version=1,run=context.GetCurrentRunSeed()} end
        syncFloor()
        local bed, sleep = bedRecord(), sleepState()
        if sleep then
            local value = tonumber(sleep.elapsed)
            if not value or value ~= value or value < 0 or value > TOTAL
                or type(sleep.recipients) ~= 'table' then cancel();return end
            for _, recipient in pairs(sleep.recipients) do
                if type(recipient) ~= 'table' or type(recipient.position) ~= 'table'
                    or type(recipient.position.x) ~= 'number' or type(recipient.position.y) ~= 'number'
                    or type(recipient.animation) ~= 'string' or type(recipient.frame) ~= 'number' then
                    cancel();return
                end
            end
            if sleep.nativeSamples ~= nil then
                if type(sleep.nativeSamples) ~= 'table' then cancel();return end
                for _, sample in ipairs(sleep.nativeSamples) do
                    if type(sample) ~= 'table' or type(sample.seconds) ~= 'number'
                        or sample.seconds < 0 or type(sample.mature) ~= 'table' then cancel();return end
                    for _, values in pairs(sample.mature) do
                        if type(values) ~= 'table' then cancel();return end
                    end
                end
            end
        end
        if sleep and not sleep.settled then
            if not next(sleep.recipients) then cancel();return end
            bed.phase = 'sleeping'
            sleep.nativeSamples, sleep.captureClosed, sleep.overlayPlayer = nil, nil, nil
            -- The movie is not replayed on continue; the earned sleep remains.
            for _, pickup in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BED, 0, false, false)) do
                if isOwned(pickup) then pickup.Target=nil end
            end
        end
    end
    function callbackInstallers.gameStarted()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end
    local function newRoom()
        clearRuntime()
        if not runtime.ready then return end
        syncFloor()
        local bed = bedRecord()
        if bed and not inOrigin() and bed.sleep and not bed.sleep.settled then cancel() end
    end
    function callbackInstallers.newRoom()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end
    local function newLevel() if runtime.ready then syncFloor() end end
    function callbackInstallers.newLevel()
        return mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
    end
    local function exitGame()
        if runtime.ready then save() end
        runtime.ready = false
        clearRuntime()
    end
    function callbackInstallers.exitGame()
        return mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, exitGame)
    end
    local function gameEnded()
        if runtime.ready then context.GetSaveRoot().healthySleep=nil;save() end
        runtime.ready=false;clearRuntime()
    end
    function callbackInstallers.gameEnded()
        return mod:AddCallback(ModCallbacks.MC_POST_GAME_END, gameEnded)
    end
    local function unload(_, unloadingMod) if unloadingMod == mod then exitGame() end end
    function callbackInstallers.unload()
        return mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, unload)
    end
    return callbackInstallers
end
