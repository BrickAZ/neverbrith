-- Version-1 save schema and plain-data snapshots. Runtime wrappers never enter persisted records.
return function(Neverbirth, context, deps)
    local copyTable = deps.copyTable
    local currentRunSeed = deps.currentRunSeed
    local playerKey = deps.playerKey
    local getPlayerType = deps.getPlayerType
    local readHealth = deps.readHealth
    local captureSlots = deps.captureSlots
    local capturePockets = deps.capturePockets
    local profilesById = deps.profilesById
    local FALLBACK_ICON_ID = deps.FALLBACK_ICON_ID
    local SAVE_VERSION = deps.SAVE_VERSION

    local function ensureSavedState()
        local root = context.GetSaveRoot and context.GetSaveRoot() or {}
        if type(root.memoryDisorder) ~= "table" then root.memoryDisorder = {} end
        local saved = root.memoryDisorder
        if saved.version ~= SAVE_VERSION or saved.runSeed ~= currentRunSeed() then
            saved.version = SAVE_VERSION
            saved.runSeed = currentRunSeed()
            saved.memoryDisorderVoidUnlockedThisRun = false
            saved.players = {}
            saved.pickedIconItems = {}
            saved.pedestalIconIds = {}
        end
        if type(saved.players) ~= "table" then saved.players = {} end
        if type(saved.pickedIconItems) ~= "table" then saved.pickedIconItems = {} end
        if type(saved.pedestalIconIds) ~= "table" then saved.pedestalIconIds = {} end
        if saved.memoryDisorderVoidUnlockedThisRun ~= true then
            saved.memoryDisorderVoidUnlockedThisRun = false
        end
        return saved
    end

    local function save()
        if context.Save then context.Save() end
    end

    local function makeState(player, savedPlayer)
        local state = {
            player = player,
            key = playerKey(player),
            originalType = savedPlayer and savedPlayer.originalType or getPlayerType(player),
            currentProfile = nil,
            currentProfileId = savedPlayer and savedPlayer.currentProfileId or nil,
            transition = nil,
            armedForNextRoom = savedPlayer and savedPlayer.armedForNextRoom ~= false or true,
            temporaryCopies = copyTable(savedPlayer and savedPlayer.temporaryCopies or {}),
            permanentCounts = copyTable(savedPlayer and savedPlayer.permanentCounts or {}),
            temporaryActiveSlots = copyTable(savedPlayer and savedPlayer.temporaryActiveSlots or {}),
            temporaryPocketCards = copyTable(savedPlayer and savedPlayer.temporaryPocketCards or {}),
            permanentSlots = copyTable(savedPlayer and savedPlayer.permanentSlots or captureSlots(player)),
            permanentPockets = copyTable(savedPlayer and savedPlayer.permanentPockets or capturePockets(player)),
            healthLedger = copyTable(savedPlayer and savedPlayer.healthLedger or readHealth(player)),
            appliedHealth = savedPlayer and savedPlayer.appliedHealth and copyTable(savedPlayer.appliedHealth) or nil,
            healthProjection = savedPlayer and savedPlayer.healthProjection or nil,
            projectedSoulTail = savedPlayer and savedPlayer.projectedSoulTail or 0,
            pairSnapshots = copyTable(savedPlayer and savedPlayer.pairSnapshots or {}),
            pairProxies = copyTable(savedPlayer and savedPlayer.pairProxies or {}),
            currentIconId = savedPlayer and savedPlayer.currentIconId or FALLBACK_ICON_ID,
            switchSerial = savedPlayer and savedPlayer.switchSerial or 0,
        }
        if state.currentProfileId then state.currentProfile = profilesById[state.currentProfileId] end
        return state
    end

    local function persistState(state)
        local saved = ensureSavedState()
        saved.players[state.key] = {
            active = true,
            originalType = state.originalType,
            currentProfileId = state.currentProfile and state.currentProfile.id or state.currentProfileId,
            armedForNextRoom = state.armedForNextRoom,
            temporaryCopies = copyTable(state.temporaryCopies),
            permanentCounts = copyTable(state.permanentCounts),
            temporaryActiveSlots = copyTable(state.temporaryActiveSlots),
            temporaryPocketCards = copyTable(state.temporaryPocketCards),
            permanentSlots = copyTable(state.permanentSlots),
            permanentPockets = copyTable(state.permanentPockets),
            healthLedger = copyTable(state.healthLedger),
            appliedHealth = copyTable(state.appliedHealth),
            healthProjection = state.healthProjection,
            projectedSoulTail = state.projectedSoulTail,
            pairSnapshots = copyTable(state.pairSnapshots),
            pairProxies = copyTable(state.pairProxies),
            currentIconId = state.currentIconId,
            switchSerial = state.switchSerial,
        }
    end

    return {
        ensureSavedState = ensureSavedState,
        save = save,
        makeState = makeState,
        persistState = persistState,
    }
end
