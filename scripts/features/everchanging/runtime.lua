-- Private runtime ownership for Everchanging.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local TWIN_STYLE_ID = "tantan_daodao_twins"
    local DEBUG_COMMAND = "nb_everchanging"
    local Store = deps.Store
    local GetPlayers = deps.GetPlayers
    local DebugLog = deps.DebugLog
    local PLAYER_RUNTIME_KEY = deps.RuntimeKey
    local STYLE_REGISTRY = deps.Registry.StyleRegistry
    local lifetime = deps.Lifetime
    local Resources = deps.Resources
    local ResetEverchangingRunState = deps.State.ResetEverchangingRunState
    local GetEverchangingRunState = deps.State.GetEverchangingRunState
    local GetEverchangingPlayerState = deps.State.GetEverchangingPlayerState
    local GetEverchangingRuntime = deps.State.GetEverchangingRuntime
    local GetEverchangingCount = deps.State.GetEverchangingCount
    local GetNormalTwinPair = deps.Selection.GetNormalTwinPair
    local IsStyleEligibleForPlayer = deps.Selection.IsStyleEligibleForPlayer
    local UpdateEverchangingSelection = deps.Selection.UpdateEverchangingSelection
    local ClearEverchangingStyle = deps.Presentation.ClearEverchangingStyle
    local SyncEverchangingVisual = deps.Presentation.SyncEverchangingVisual
    local ApplyEverchangingPair = deps.Presentation.ApplyEverchangingPair

    local function SyncEverchangingPlayer(player)
        if not lifetime.running then return false end
        local pair = GetNormalTwinPair(player)
        if pair then
            local jacobState, jacobRuntime, jacobCount, jacobChanged = UpdateEverchangingSelection(pair.jacob)
            local esauState, esauRuntime, esauCount, esauChanged = UpdateEverchangingSelection(pair.esau)
            local pairActive =
                (jacobCount > 0 and jacobState and jacobState.styleId == TWIN_STYLE_ID)
                or (esauCount > 0 and esauState and esauState.styleId == TWIN_STYLE_ID)
            if pairActive then
                ApplyEverchangingPair(pair, STYLE_REGISTRY.byId[TWIN_STYLE_ID])
            else
                SyncEverchangingVisual(pair.jacob, jacobState, jacobRuntime, jacobCount)
                SyncEverchangingVisual(pair.esau, esauState, esauRuntime, esauCount)
            end
            return jacobChanged or esauChanged
        end

        local state, runtime, count, changed = UpdateEverchangingSelection(player)
        if state and state.styleId == TWIN_STYLE_ID then
            ClearEverchangingStyle(player)
            runtime.dirty = false
            return changed
        end
        SyncEverchangingVisual(player, state, runtime, count)
        return changed
    end

    local function ForceEverchangingStyle(player, styleId)
        if not lifetime.running then return false, "runtime is not active" end
        if not player or GetEverchangingCount(player) <= 0 then
            return false, "the current player must hold Everchanging"
        end
        if type(styleId) ~= "string" or not STYLE_REGISTRY.byId[styleId] then
            return false, "unknown style " .. tostring(styleId)
        end
        if not IsStyleEligibleForPlayer(player, STYLE_REGISTRY.byId[styleId]) then
            return false, "style is not eligible for the current player"
        end

        local state = GetEverchangingPlayerState(player)
        local runtime = GetEverchangingRuntime(player)
        if not state or not runtime then
            return false, "player state is unavailable"
        end

        state.styleId = styleId
        state.knownCopies = GetEverchangingCount(player)
        Store.Save()
        runtime.failedStyleId = nil
        runtime.dirty = true
        SyncEverchangingPlayer(player)
        if GetEverchangingRuntime(player).appliedStyleId ~= styleId then
            return false, "style application failed"
        end
        return true, "forced style " .. styleId
    end

    local function WriteEverchangingCommandResult(message)
        local line = "[neverbirth] Everchanging: " .. tostring(message)
        DebugLog(line)
        return line
    end

    local function OnEverchangingExecuteCommand(_, command, parameters)
        if tostring(command or ""):lower() ~= DEBUG_COMMAND then
            return nil
        end

        local alias = tostring(parameters or ""):match("^%s*(%S+)")
        alias = tostring(alias or ""):lower()
        local styleAliases = {
            ringo = "ringotsuga_apple_storyteller",
            ringotsuga = "ringotsuga_apple_storyteller",
            banana = "blue_banana_peel",
            blue_banana = "blue_banana_peel",
            tokarev = "tokarev_cloak",
            twins = "tantan_daodao_twins",
            tantan = "tantan_daodao_twins",
            daodao = "tantan_daodao_twins",
            yoon = "yoontoons_storyteller",
            yoontoons = "yoontoons_storyteller",
        }
        local styleId = styleAliases[alias]
        if not styleId then
            return WriteEverchangingCommandResult(
                "usage: nb_everchanging ringo|banana|tokarev|twins|yoontoons"
            )
        end

        local player = GetPlayers()[1]
        if not player then
            return WriteEverchangingCommandResult("no player is available")
        end

        local _, reason = ForceEverchangingStyle(player, styleId)
        return WriteEverchangingCommandResult(reason)
    end
    function callbackInstallers.OnEverchangingExecuteCommand()
        return Neverbirth:AddCallback(ModCallbacks.MC_EXECUTE_CMD, OnEverchangingExecuteCommand)
    end

    local function MarkAllEverchangingPlayersDirty()
        for _, player in ipairs(GetPlayers()) do
            local runtime = GetEverchangingRuntime(player)
            if runtime then
                runtime.dirty = true
            end
        end
    end

    local function ClearEverchangingRuntime(player, removeCostume)
        local runtime = GetEverchangingRuntime(player)
        if not runtime then
            return
        end
        if removeCostume then
            ClearEverchangingStyle(player)
        end
        local data = player:GetData()
        data[PLAYER_RUNTIME_KEY] = {
            appliedStyleId = nil,
            appliedRole = nil,
            appliedPlayerAnm2 = nil,

            originalSpriteFilename = nil,
            appliedCostumeIds = {},
            dirty = true,
        }
    end

    local function OnEverchangingPlayerUpdate(_, player)
        SyncEverchangingPlayer(player)
        return nil
    end
    function callbackInstallers.OnEverchangingPlayerUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, OnEverchangingPlayerUpdate)
    end

    local function OnEverchangingPlayerInit(_, player)
        if not lifetime.running then return nil end
        local runtime = GetEverchangingRuntime(player)
        if runtime then
            runtime.dirty = true
        end
        SyncEverchangingPlayer(player)
        return nil
    end
    function callbackInstallers.OnEverchangingPlayerInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, OnEverchangingPlayerInit)
    end

    local function OnEverchangingNewRoom(_)
        if not lifetime.running then return nil end
        MarkAllEverchangingPlayersDirty()
        return nil
    end
    function callbackInstallers.OnEverchangingNewRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, OnEverchangingNewRoom)
    end

    local function OnEverchangingNewLevel(_)
        if not lifetime.running then return nil end
        MarkAllEverchangingPlayersDirty()
        return nil
    end
    function callbackInstallers.OnEverchangingNewLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, OnEverchangingNewLevel)
    end

    local function OnEverchangingGameStarted(_, isContinued)
        if lifetime.disposed then return nil end
        lifetime.running = true
        local players = GetPlayers()
        if isContinued then
            GetEverchangingRunState()
        else
            for _, player in ipairs(players) do
                ClearEverchangingStyle(player)
                ClearEverchangingRuntime(player, false)
            end
            ResetEverchangingRunState()
        end
        for _, player in ipairs(players) do
            local runtime = GetEverchangingRuntime(player)
            if runtime then
                runtime.dirty = true
            end
            SyncEverchangingPlayer(player)
        end
        return nil
    end
    function callbackInstallers.OnEverchangingGameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, OnEverchangingGameStarted)
    end

    local function clearRuntimePlayers()
        -- Weak keys let removed players disappear without a new module-owned root.
        -- Use only players this instance touched; no Game() query is needed at unload.
        for player in pairs(lifetime.runtimePlayers) do
            pcall(function()
                ClearEverchangingStyle(player)
                player:GetData()[PLAYER_RUNTIME_KEY] = nil
            end)
            lifetime.runtimePlayers[player] = nil
        end
    end

    local function OnEverchangingExit(_)
        if not lifetime.running then return end
        lifetime.running = false
        clearRuntimePlayers()
    end
    function callbackInstallers.OnEverchangingExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, OnEverchangingExit)
    end

    local function OnEverchangingUnload(_, unloaded)
        if unloaded ~= Neverbirth or lifetime.disposed then return end
        clearRuntimePlayers()
        lifetime.running, lifetime.disposed = false, true
        Resources.ClearCaches()
    end
    function callbackInstallers.OnEverchangingUnload()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, OnEverchangingUnload)
    end

    return {
        SyncEverchangingPlayer = SyncEverchangingPlayer,
        ForceEverchangingStyle = ForceEverchangingStyle,
        WriteEverchangingCommandResult = WriteEverchangingCommandResult,
        OnEverchangingExecuteCommand = OnEverchangingExecuteCommand,
        MarkAllEverchangingPlayersDirty = MarkAllEverchangingPlayersDirty,
        ClearEverchangingRuntime = ClearEverchangingRuntime,
        OnEverchangingPlayerUpdate = OnEverchangingPlayerUpdate,
        OnEverchangingPlayerInit = OnEverchangingPlayerInit,
        OnEverchangingNewRoom = OnEverchangingNewRoom,
        OnEverchangingNewLevel = OnEverchangingNewLevel,
        OnEverchangingGameStarted = OnEverchangingGameStarted,
        clearRuntimePlayers = clearRuntimePlayers,
        OnEverchangingExit = OnEverchangingExit,
        OnEverchangingUnload = OnEverchangingUnload,
        Installers = callbackInstallers,
    }
end
