-- Private state responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local context = deps.Context
    local entityExists = deps.Queries.entityExists
    local playerKey = deps.Queries.playerKey
    local getPlayers = deps.Queries.getPlayers

    local runtime = {
        frame = 0,
        serial = 0,
        trailSerial = 0,
        players = {},
        pendingFood = {},
        roomTargets = {},
        roomTargetKeys = {},
        roomTargetVersion = 0,
        chewSearchCount = 0,
        trails = {},
        trailById = {},
        trailCandidates = {},
        lastTrailAppliedFrame = nil,
        fallbackSaveRoot = {},
        testRunSeed = nil,
        savedAtExit = false,

    }


    local function getSaveRoot()
        local root = nil
        if type(context.GetSaveRoot) == "function" then
            local ok, value = pcall(context.GetSaveRoot)
            if ok and type(value) == "table" then
                root = value
            end
        end
        if not root then
            root = runtime.fallbackSaveRoot
        end
        if type(root.bigDogBark) ~= "table" then
            root.bigDogBark = {}
        end
        return root
    end

    local function currentRunSeed()
        if runtime.testRunSeed ~= nil then
            return tostring(runtime.testRunSeed)
        end
        if type(context.GetCurrentRunSeed) == "function" then
            local ok, seed = pcall(context.GetCurrentRunSeed)
            if ok and seed ~= nil then
                return tostring(seed)
            end
        end
        return "unknown"
    end

    local function save()
        if type(context.Save) == "function" then
            pcall(context.Save)
        end
    end

    local function resetSavedState(seed)
        local root = getSaveRoot()
        root.bigDogBark = {
            runSeed = tostring(seed or currentRunSeed()),
            players = {},
        }
        return root.bigDogBark
    end

    local function getSavedState()
        local root = getSaveRoot()
        local state = root.bigDogBark
        local seed = currentRunSeed()
        if type(state) ~= "table" or tostring(state.runSeed or "") ~= seed then
            state = resetSavedState(seed)
        end
        if type(state.players) ~= "table" then
            state.players = {}
        end
        return state
    end

    local function getPlayerRuntime(player, create)
        local key = playerKey(player)
        if key == "" then
            return nil
        end
        local state = runtime.players[key]
        if type(state) ~= "table" and create ~= false then
            state = {
                key = key,
                player = player,
                mode = "follow",
                lastMoveDirection = nil,
                roomChewed = {},
                chewTarget = nil,
                chewTargetKey = nil,
                chewPauseUntil = nil,
                chewSearchPending = true,
                lastChewSearchVersion = -1,
                nextChewSearchFrame = 0,
                chewPath = nil,
                chewPathNode = 1,
                chewPathTargetKey = nil,
                nextChewPathFrame = 0,
                chewPathFailureCount = 0,
                chewMoveVelocity = nil,
                chewSafePosition = nil,
                nextChewSafeFrame = 0,
                chewWindupDirection = nil,
                chewLungeDirection = nil,
                chewLungeStart = nil,
                chewLungeTravel = nil,
                chewHitConsumed = false,
                chewAnimation = nil,
                dog = nil,
                dash = nil,
                echoEntity = nil,
                echoData = nil,
                echoActive = false,
                chargeStartFrame = nil,
                chargeFrames = nil,
                chargeSlot = nil,
                chargeSawHeld = false,
                chargeReady = false,
                chargeSoundPitch = nil,
                chargeSoundNextFrame = nil,
                chargeBarSprite = nil,
                chargeBarPhase = nil,
                chargeBarVisible = false,
                chargeBarLoadFailed = false,
                lastLaunchFrame = nil,
            }
            runtime.players[key] = state
        elseif state then
            state.player = player or state.player
            if type(state.roomChewed) ~= "table" then
                state.roomChewed = {}
            end
            if type(state.mode) ~= "string" then
                state.mode = "follow"
            end
            if state.chewSearchPending == nil then
                state.chewSearchPending = true
            end
            if type(state.lastChewSearchVersion) ~= "number" then
                state.lastChewSearchVersion = -1
            end
            if type(state.nextChewSearchFrame) ~= "number" then
                state.nextChewSearchFrame = 0
            end
            if type(state.chewPathNode) ~= "number" then
                state.chewPathNode = 1
            end
            if type(state.nextChewPathFrame) ~= "number" then
                state.nextChewPathFrame = 0
            end
            if type(state.chewPathFailureCount) ~= "number" then
                state.chewPathFailureCount = 0
            end
            if type(state.nextChewSafeFrame) ~= "number" then
                state.nextChewSafeFrame = 0
            end
            if state.chewHitConsumed == nil then
                state.chewHitConsumed = false
            end
            if state.chargeReady == nil then
                state.chargeReady = false
            end
            if state.chargeBarVisible == nil then
                state.chargeBarVisible = false
            end
        end
        return state
    end

    local function getPlayerRecord(player)
        local key = playerKey(player)
        if key == "" then
            return nil
        end
        getPlayerRuntime(player, true)
        local saved = getSavedState()
        local record = saved.players[key]
        if type(record) ~= "table" then
            record = {}
            saved.players[key] = record
        end
        record.foodPickups = math.max(0, math.floor(tonumber(record.foodPickups) or 0))
        record.chewUnlocked = record.chewUnlocked == true or record.foodPickups >= 4
        record.potionArmed = record.potionArmed == true
        return record
    end

    local function findPlayerByKey(key)
        key = tostring(key or "")
        local state = runtime.players[key]
        if state and entityExists(state.player) then
            return state.player
        end
        for _, player in ipairs(getPlayers()) do
            if playerKey(player) == key then
                if state then
                    state.player = player
                end
                return player
            end
        end
        return nil
    end

    local function useWindPill(player)
        local record = getPlayerRecord(player)
        if not record or record.potionArmed then
            return false
        end
        record.potionArmed = true
        save()
        return true
    end

    return {
        getSaveRoot = getSaveRoot,
        currentRunSeed = currentRunSeed,
        save = save,
        resetSavedState = resetSavedState,
        getSavedState = getSavedState,
        getPlayerRuntime = getPlayerRuntime,
        getPlayerRecord = getPlayerRecord,
        findPlayerByKey = findPlayerByKey,
        useWindPill = useWindPill,
        Runtime = runtime,
    }
end
