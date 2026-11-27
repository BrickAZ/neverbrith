-- Memory Disorder: create each private instance once, publish the legacy API, then bind in legacy order.
return function(Neverbirth, context)
    context = context or {}
    local include = include or require -- Standalone Lua callers retain the old factory entry.
    local ITEM_ID = context.ItemId or 0
    local FALLBACK_ICON_ID = 0 -- Neutral question mark when no unseen passive remains.
    local QUESTION_MARK_GFX = "gfx/items/collectibles/questionmark.png"
    local SAVE_VERSION = 1
    local TRANSITION_SWITCH_FRAME = 15
    local TRANSITION_END_FRAME = 30
    local MAX_DARKNESS = 0.55

    local SLOT_PRIMARY = ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0
    local SLOT_SECONDARY = ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1
    local SLOT_POCKET = ActiveSlot and ActiveSlot.SLOT_POCKET or 2
    local POCKET_PRIMARY = PocketItemSlot and PocketItemSlot.SLOT_PRIMARY or 0
    local POCKET_SECONDARY = PocketItemSlot and PocketItemSlot.SLOT_SECONDARY or 1

    local runtime = {
        states = {},
        roomSerial = 0,
        iconCandidates = nil,
        iconConfigs = {},
        collectibleGfx = {},
        iconHistoryPlayers = {},
        iconHistoryDirty = false,
        portalSpawnedThisRoom = false,
        terminalKind = nil,
        diagnostics = {},
    }

    Neverbirth.MemoryDisorderCharacterProfiles = Neverbirth.MemoryDisorderCharacterProfiles or {}

    local player_access = include("scripts.features.memory_disorder.player_access")(Neverbirth, context, {
        ITEM_ID = ITEM_ID,
        runtime = runtime,
    })

    local profiles = include("scripts.features.memory_disorder.profiles")(Neverbirth, context, {
        playerType = player_access.playerType,
        SLOT_PRIMARY = SLOT_PRIMARY,
        SLOT_POCKET = SLOT_POCKET,
        POCKET_PRIMARY = POCKET_PRIMARY,
    })

    local health = include("scripts.features.memory_disorder.health")(Neverbirth, context, {
        safeCall = player_access.safeCall,
        numberCall = player_access.numberCall,
        copyTable = player_access.copyTable,
        playerType = player_access.playerType,
        getPlayerType = player_access.getPlayerType,
        pairPartner = player_access.pairPartner,
        profileForType = profiles.profileForType,
    })

    local inventory = include("scripts.features.memory_disorder.inventory")(Neverbirth, context, {
        diagnosticOnce = player_access.diagnosticOnce,
        safeCall = player_access.safeCall,
        numberCall = player_access.numberCall,
        playerKey = player_access.playerKey,
        getCollectibleCount = player_access.getCollectibleCount,
        seedHash = player_access.seedHash,
        SLOT_PRIMARY = SLOT_PRIMARY,
        SLOT_SECONDARY = SLOT_SECONDARY,
        SLOT_POCKET = SLOT_POCKET,
        POCKET_PRIMARY = POCKET_PRIMARY,
        POCKET_SECONDARY = POCKET_SECONDARY,
    })

    local state = include("scripts.features.memory_disorder.state")(Neverbirth, context, {
        copyTable = player_access.copyTable,
        currentRunSeed = player_access.currentRunSeed,
        playerKey = player_access.playerKey,
        getPlayerType = player_access.getPlayerType,
        readHealth = health.readHealth,
        captureSlots = inventory.captureSlots,
        capturePockets = inventory.capturePockets,
        profilesById = profiles.profilesById,
        FALLBACK_ICON_ID = FALLBACK_ICON_ID,
        SAVE_VERSION = SAVE_VERSION,
    })

    local icons = include("scripts.features.memory_disorder.icons")(Neverbirth, context, {
        safeCall = player_access.safeCall,
        numberCall = player_access.numberCall,
        runtimePlayerKey = player_access.runtimePlayerKey,
        getPlayers = player_access.getPlayers,
        pairMain = player_access.pairMain,
        randomIndex = player_access.randomIndex,
        ensureSavedState = state.ensureSavedState,
        ITEM_ID = ITEM_ID,
        FALLBACK_ICON_ID = FALLBACK_ICON_ID,
        QUESTION_MARK_GFX = QUESTION_MARK_GFX,
        runtime = runtime,
    })

    local pairs = include("scripts.features.memory_disorder.pairs")(Neverbirth, context, {
        diagnosticOnce = player_access.diagnosticOnce,
        safeCall = player_access.safeCall,
        numberCall = player_access.numberCall,
        copyTable = player_access.copyTable,
        runtimePlayerKey = player_access.runtimePlayerKey,
        getPlayers = player_access.getPlayers,
        playerExists = player_access.playerExists,
        getPlayerType = player_access.getPlayerType,
        getCollectibleCount = player_access.getCollectibleCount,
        pairPartner = player_access.pairPartner,
        profileForType = profiles.profileForType,
        readHealth = health.readHealth,
        applyHealth = health.applyHealth,
        captureSlots = inventory.captureSlots,
        capturePockets = inventory.capturePockets,
        restoreSlot = inventory.restoreSlot,
        ITEM_ID = ITEM_ID,
        SLOT_PRIMARY = SLOT_PRIMARY,
        SLOT_SECONDARY = SLOT_SECONDARY,
        SLOT_POCKET = SLOT_POCKET,
        POCKET_PRIMARY = POCKET_PRIMARY,
        POCKET_SECONDARY = POCKET_SECONDARY,
    })

    local identity = include("scripts.features.memory_disorder.identity")(Neverbirth, context, {
        diagnosticOnce = player_access.diagnosticOnce,
        safeCall = player_access.safeCall,
        numberCall = player_access.numberCall,
        playerKey = player_access.playerKey,
        runtimePlayerKey = player_access.runtimePlayerKey,
        playerIsDead = player_access.playerIsDead,
        getPlayerType = player_access.getPlayerType,
        getCollectibleCount = player_access.getCollectibleCount,
        pairMain = player_access.pairMain,
        pairPartner = player_access.pairPartner,
        hasItem = player_access.hasItem,
        randomIndex = player_access.randomIndex,
        profileForType = profiles.profileForType,
        buildAllCandidates = profiles.buildAllCandidates,
        readHealth = health.readHealth,
        healthMode = health.healthMode,
        healthAmount = health.healthAmount,
        applyHealth = health.applyHealth,
        captureHealthLedger = health.captureHealthLedger,
        updatePermanentSlots = inventory.updatePermanentSlots,
        reconcileTemporaryCopies = inventory.reconcileTemporaryCopies,
        removeTemporaryComponents = inventory.removeTemporaryComponents,
        recordTemporaryCopy = inventory.recordTemporaryCopy,
        addProfileComponents = inventory.addProfileComponents,
        ensureSavedState = state.ensureSavedState,
        save = state.save,
        makeState = state.makeState,
        persistState = state.persistState,
        iconIsEligible = icons.iconIsEligible,
        chooseIcon = icons.chooseIcon,
        snapshotPartner = pairs.snapshotPartner,
        canSwitchPair = pairs.canSwitchPair,
        parkPartner = pairs.parkPartner,
        removeFormerPartner = pairs.removeFormerPartner,
        ensureNativePair = pairs.ensureNativePair,
        restorePartner = pairs.restorePartner,
        VANILLA_PROFILES = profiles.VANILLA_PROFILES,
        profilesById = profiles.profilesById,
        ITEM_ID = ITEM_ID,
        TRANSITION_SWITCH_FRAME = TRANSITION_SWITCH_FRAME,
        TRANSITION_END_FRAME = TRANSITION_END_FRAME,
        MAX_DARKNESS = MAX_DARKNESS,
        runtime = runtime,
    })

    local void_route = include("scripts.features.memory_disorder.void_route")(Neverbirth, context, {
        ensureSavedState = state.ensureSavedState,
        runtime = runtime,
    })

    local lifecycle = include("scripts.features.memory_disorder.lifecycle")(Neverbirth, context, {
        currentRunSeed = player_access.currentRunSeed,
        runtimePlayerKey = player_access.runtimePlayerKey,
        getPlayers = player_access.getPlayers,
        playerExists = player_access.playerExists,
        playerIsDead = player_access.playerIsDead,
        pairMain = player_access.pairMain,
        captureHealthLedger = health.captureHealthLedger,
        updatePermanentSlots = inventory.updatePermanentSlots,
        reconcileTemporaryCopies = inventory.reconcileTemporaryCopies,
        ensureSavedState = state.ensureSavedState,
        save = state.save,
        persistState = state.persistState,
        importIconHistory = icons.importIconHistory,
        syncIconHistory = icons.syncIconHistory,
        iconIsEligible = icons.iconIsEligible,
        chooseIcon = icons.chooseIcon,
        registerIconDescription = icons.registerIconDescription,
        onOwnershipUpdate = identity.onOwnershipUpdate,
        beginRoomTransitions = identity.beginRoomTransitions,
        advanceFrame = identity.advanceFrame,
        trySpawnVoidPortal = void_route.trySpawnVoidPortal,
        liveRoomContext = void_route.liveRoomContext,
        SAVE_VERSION = SAVE_VERSION,
        runtime = runtime,
    })

    local runtimePlayerKey = player_access.runtimePlayerKey
    local pairMain = player_access.pairMain
    local buildVanillaCandidates = profiles.buildVanillaCandidates
    local buildAllCandidates = profiles.buildAllCandidates
    local findProfile = profiles.findProfile
    local ensureSavedState = state.ensureSavedState
    local rememberPickedIcon = icons.rememberPickedIcon
    local chooseIcon = icons.chooseIcon
    local resolveIdentitySwitch = identity.resolveIdentitySwitch
    local onOwnershipUpdate = identity.onOwnershipUpdate
    local transitionDarkness = identity.transitionDarkness
    local beginRoomTransitions = identity.beginRoomTransitions
    local advanceFrame = identity.advanceFrame
    local trySpawnVoidPortal = void_route.trySpawnVoidPortal
    local onNpcDeath = void_route.onNpcDeath
    local onGameStarted = lifecycle.onGameStarted
    local onPreGameExit = lifecycle.onPreGameExit
    local VANILLA_PROFILES = profiles.VANILLA_PROFILES

    local api = {
        Constants = {
            ITEM_ID = ITEM_ID,
            FALLBACK_ICON_ID = FALLBACK_ICON_ID,
            TRANSITION_SWITCH_FRAME = TRANSITION_SWITCH_FRAME,
            TRANSITION_END_FRAME = TRANSITION_END_FRAME,
        },
        MemoryDisorderCharacterProfiles = Neverbirth.MemoryDisorderCharacterProfiles,
        VanillaProfiles = VANILLA_PROFILES,
        BuildVanillaCandidates = buildVanillaCandidates,
        BuildAllCandidates = buildAllCandidates,
        FindProfile = findProfile,
        OnOwnershipUpdate = onOwnershipUpdate,
        ResolveIdentitySwitch = resolveIdentitySwitch,
        BeginRoomTransitions = beginRoomTransitions,
        AdvanceFrame = advanceFrame,
        TransitionDarkness = transitionDarkness,
        ChooseIcon = chooseIcon,
        InvalidateIconCache = function() runtime.iconCandidates = nil; runtime.iconConfigs = {} end,
        RememberPickedIcon = rememberPickedIcon,
        TrySpawnVoidPortal = trySpawnVoidPortal,
        GetRuntimeState = function(player) return runtime.states[runtimePlayerKey(pairMain(player))] end,
        GetSavedState = ensureSavedState,
        OnGameStarted = onGameStarted,
        OnPreGameExit = onPreGameExit,
        OnNpcDeath = onNpcDeath,
        Runtime = runtime,
    }

    Neverbirth.MemoryDisorder = api

    if ModCallbacks then
        lifecycle.Installers.onPostUpdate()
        lifecycle.Installers.onNewRoom()
        lifecycle.Installers.onGameStarted()
        lifecycle.Installers.onPreGameExit()
        if ModCallbacks.MC_POST_PLAYER_INIT then identity.Installers.onOwnershipUpdate() end
        if ModCallbacks.MC_POST_NPC_DEATH then void_route.Installers.onNpcDeath() end
        if ModCallbacks.MC_POST_ADD_COLLECTIBLE then icons.Installers.rememberPickedIcon() end
        if ModCallbacks.MC_POST_PICKUP_UPDATE then icons.Installers.updatePickupIcon() end
        if ModCallbacks.MC_PRE_PICKUP_RENDER then icons.Installers.renderPickupIcon() end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then icons.Installers.capturePickupIcon() end
        if ModCallbacks.MC_PRE_PLAYER_RENDER then icons.Installers.renderHeldIcon() end
    end

    return api
end
