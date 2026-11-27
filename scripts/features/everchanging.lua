-- Create private instances once, then install callbacks in their original order.
return function(Neverbirth, dependencies)
    local Store = assert(dependencies.Store)
    local Items = assert(dependencies.Items)
    local GetPlayers = assert(dependencies.GetPlayers)
    local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
    local IsValidItemId = assert(dependencies.IsValidItemId)
    local DebugLog = assert(dependencies.Log)
    local EVERCHANGING = Items.Everchanging
    local PLAYER_RUNTIME_KEY = "neverbirth_everchanging_runtime"
    local lifetime = { running = true, disposed = false, runtimePlayers = setmetatable({}, { __mode = "k" }) }
    local Registry = include("scripts.features.everchanging.registry")(Neverbirth, {
        DebugLog = DebugLog,
    })
    local State = include("scripts.features.everchanging.state")(Neverbirth, {
        Store = Store,
        GetCurrentRunSeed = GetCurrentRunSeed,
        IsValidItemId = IsValidItemId,
        ItemId = EVERCHANGING,
        RuntimeKey = PLAYER_RUNTIME_KEY,
        Registry = Registry,
        Lifetime = lifetime,
    })
    local Selection = include("scripts.features.everchanging.selection")(Neverbirth, {
        Store = Store,
        IsValidItemId = IsValidItemId,
        DebugLog = DebugLog,
        ItemId = EVERCHANGING,
        Registry = Registry,
        State = State,
    })
    local Resources = include("scripts.features.everchanging.resources")(Neverbirth, {
        DebugLog = DebugLog,
    })
    local PlayerAnm2 = include("scripts.features.everchanging.player_anm2")(Neverbirth, {
        DebugLog = DebugLog,
        Registry = Registry,
    })
    local Presentation = include("scripts.features.everchanging.presentation")(Neverbirth, {
        DebugLog = DebugLog,
        Registry = Registry,
        State = State,
        Selection = Selection,
        Resources = Resources,
        PlayerAnm2 = PlayerAnm2,
    })
    local Runtime = include("scripts.features.everchanging.runtime")(Neverbirth, {
        Store = Store,
        GetPlayers = GetPlayers,
        DebugLog = DebugLog,
        RuntimeKey = PLAYER_RUNTIME_KEY,
        Registry = Registry,
        Lifetime = lifetime,
        Resources = Resources,
        State = State,
        Selection = Selection,
        Presentation = Presentation,
    })
    Neverbirth.EverchangingTestAPI = {
        StyleSpecs = Registry.StyleSpecs,
        StyleRegistry = Registry.StyleRegistry,
        BuildStyleRegistry = Registry.BuildStyleRegistry,
        ResolveStyleCostumes = Resources.ResolveStyleCostumes,
        ResolveStyleResources = Resources.ResolveStyleResources,
        SelectStyle = Selection.SelectStyle,
        GetNormalTwinRole = Selection.GetNormalTwinRole,
        GetNormalTwinPair = Selection.GetNormalTwinPair,
        IsStyleEligible = Selection.IsStyleEligibleForPlayer,
        IsCompatiblePlayer = PlayerAnm2.IsCompatiblePlayer,
        GetPlayerState = State.GetEverchangingPlayerState,
        ForceStyle = Runtime.ForceEverchangingStyle,
        SyncPlayer = Runtime.SyncEverchangingPlayer,
        ResetRunState = State.ResetEverchangingRunState,
        ClearRuntime = Runtime.ClearEverchangingRuntime,
        GetRuntime = State.GetEverchangingRuntime,
        ApplyPair = Presentation.ApplyEverchangingPair,
        GetItemId = function() return EVERCHANGING end,
        Callbacks = {
            PlayerUpdate = Runtime.OnEverchangingPlayerUpdate,
            PlayerInit = Runtime.OnEverchangingPlayerInit,
            NewRoom = Runtime.OnEverchangingNewRoom,
            NewLevel = Runtime.OnEverchangingNewLevel,
            GameStarted = Runtime.OnEverchangingGameStarted,
            ExecuteCommand = Runtime.OnEverchangingExecuteCommand,
        },
    }

    if ModCallbacks.MC_POST_PLAYER_UPDATE then
        Runtime.Installers.OnEverchangingPlayerUpdate()
    end
    if ModCallbacks.MC_POST_PLAYER_INIT then
        Runtime.Installers.OnEverchangingPlayerInit()
    end
    if ModCallbacks.MC_POST_NEW_ROOM then
        Runtime.Installers.OnEverchangingNewRoom()
    end
    if ModCallbacks.MC_POST_NEW_LEVEL then
        Runtime.Installers.OnEverchangingNewLevel()
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        Runtime.Installers.OnEverchangingGameStarted()
    end
    if ModCallbacks.MC_EXECUTE_CMD then
        Runtime.Installers.OnEverchangingExecuteCommand()
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then Runtime.Installers.OnEverchangingExit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then Runtime.Installers.OnEverchangingUnload() end
end
