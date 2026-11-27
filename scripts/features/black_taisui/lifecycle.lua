-- Coordinates the three item owners in the original per-player and callback order.
return function(Neverbirth, dependencies)
    local Runtime = assert(dependencies.Runtime)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local GetPlayers = dependencies.GetPlayers
    local GetFolkFloorKey = dependencies.GetFolkFloorKey
    local GetFolkRoomKey = dependencies.GetFolkRoomKey
    local GetFolkPlayerKey = dependencies.GetFolkPlayerKey
    local PlayerHasCollectible = dependencies.PlayerHasCollectible
    local BlackTaisuiId = dependencies.BlackTaisuiId
    local CleansedWavyCap = dependencies.CleansedWavyCap
    local VisualEffects = dependencies.VisualEffects
    local ParasiteState = dependencies.ParasiteState
    function Neverbirth:UpdateBlackTaisui()
        if not Runtime.running or Runtime.disposed then return end
        for _, player in ipairs(GetPlayers()) do
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            local copies = PlayerHasCollectible(player, BlackTaisuiId)
                and (player.GetCollectibleNum and player:GetCollectibleNum(BlackTaisuiId) or 1) or 0
            local previousCopies = state.blackTaisuiCopies
            state.blackTaisuiCopies = copies
            if previousCopies ~= nil and previousCopies ~= copies then Runtime:RefreshBlackTaisuiCache(player) end
            if (tonumber(state.deathSaveFeedbackFrames) or 0) > 0 then
                state.deathSaveFeedbackFrames = math.max(0, (tonumber(state.deathSaveFeedbackFrames) or 0) - 1)
            end
            Runtime:UpdateBlackTaisuiParasiteFromHealth(player)
            if PlayerHasCollectible(player, BlackTaisuiId) and Neverbirth:GetBlackTaisuiStage(player) >= 2 and PlayerHasCollectible(player, Runtime.BlackTaisuiWavyCap) then
                Runtime:ReplaceBlackTaisuiWavyCap(player)
            end
            if PlayerHasCollectible(player, BlackTaisuiId) and Neverbirth:GetBlackTaisuiStage(player) >= 2 and PlayerHasCollectible(player, Runtime.BlackTaisuiWavyCap) then
                Runtime:SuppressBlackTaisuiWavyCapSideEffects(player)
            end
            CleansedWavyCap.UpdatePlayer(player)
            if PlayerHasCollectible(player, BlackTaisuiId) and Neverbirth:GetBlackTaisuiStage(player) >= 2 then
                Runtime:SuppressBlackTaisuiLevelCurses(player)
                local revealKey = tostring(GetFolkFloorKey()) .. ":" .. tostring(GetFolkRoomKey())
                if state.revealRoomKey ~= revealKey then
                    state.revealRoomKey = revealKey
                    state.revealRefreshTick = 0
                    Runtime:RevealBlackTaisuiRoomCollectibles(player, "room")
                else
                    state.revealRefreshTick = (tonumber(state.revealRefreshTick) or 0) + 1
                    if state.revealRefreshTick >= 10 then
                        state.revealRefreshTick = 0
                        Runtime:RevealBlackTaisuiRoomCollectibles(player, "room-refresh")
                    end
                end
            end
            Neverbirth:EnsureBlackTaisuiStageThreeReward(player)
            if PlayerHasCollectible(player, BlackTaisuiId) and Neverbirth:GetBlackTaisuiStage(player) >= 3 then
                state.matureCoreTick = (tonumber(state.matureCoreTick) or 999) + 1
                if state.matureCoreTick >= 60 then
                    state.matureCoreTick = 0
                    VisualEffects:Spawn("BlackTaisuiMatureCore", player.Position or Vector(320, 280), player)
                end
            end
            if Neverbirth:BlackTaisuiDeathSaveAvailable(player) and player.IsDead then
                local deadOk, isDead = pcall(function()
                    return player:IsDead()
                end)
                if deadOk and isDead then
                    Neverbirth:ApplyBlackTaisuiDeathSave(player, true)
                end
            end
        end
    end
    function callbackInstallers.Neverbirth_UpdateBlackTaisui()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateBlackTaisui)
    end



    function Neverbirth:ResetBlackTaisuiOnNewLevel()
        if not Runtime.running or Runtime.disposed then return end
        for _, player in ipairs(GetPlayers()) do
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            state.floorKey = GetFolkFloorKey()
            state.deathSavedFloorKey = nil
            state.sporeKeys = {}
            state.revealRoomKey = nil
            state.snapshotReady = false
            state.wavySuppressedStacks = 0
            CleansedWavyCap.ResetPlayerFloor(player)
            Runtime:RefreshBlackTaisuiCache(player)
        end
    end
    function callbackInstallers.Neverbirth_ResetBlackTaisuiOnNewLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.ResetBlackTaisuiOnNewLevel)
    end

    local function InstallLateCallbacks()
        callbackInstallers.Neverbirth_UpdateBlackTaisui()

        dependencies.Presentation.InstallRender()

        if ModCallbacks.MC_POST_NEW_LEVEL then
            callbackInstallers.Neverbirth_ResetBlackTaisuiOnNewLevel()
        end
    end

    local function ResetRun()
        local refreshPlayers = {}
        for _, player in ipairs(GetPlayers()) do
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            refreshPlayers[GetFolkPlayerKey(player)] = PlayerHasCollectible(player, BlackTaisuiId)
                or (tonumber(state.blackTaisuiCopies) or 0) > 0 or CleansedWavyCap.HasCachedStats(player)
        end
        ParasiteState.ResetRun()
        -- Initial player caches can have observed the previous same-seed save.
        for _, player in ipairs(GetPlayers()) do
            if refreshPlayers[GetFolkPlayerKey(player)] then
                Runtime:RefreshBlackTaisuiCache(player)
            end
        end
    end

    local function Pause()
        Runtime.running = false
        CleansedWavyCap.Pause()
        dependencies.MeatLump.Pause()
    end
    local function Resume(refresh)
        if Runtime.disposed then return end
        Runtime.running = true
        CleansedWavyCap.Resume()
        dependencies.MeatLump.Resume()
        if refresh == false then return end
        for _, player in ipairs(GetPlayers()) do
            local state = Neverbirth:GetBlackTaisuiRuntimeState(player)
            state.snapshotReady = false -- The resumed entity owns a new health observation.
            if PlayerHasCollectible(player, BlackTaisuiId) or (tonumber(state.blackTaisuiCopies) or 0) > 0
                or CleansedWavyCap.HasCachedStats(player) then Runtime:RefreshBlackTaisuiCache(player) end
        end
    end
    local function Dispose()
        if Runtime.disposed then return end
        Runtime.running, Runtime.disposed = false, true
        CleansedWavyCap.Dispose()
        dependencies.MeatLump.Dispose()
        ParasiteState.ResetRuntime()
    end
    return { InstallLateCallbacks = InstallLateCallbacks, ResetRuntime = ParasiteState.ResetRuntime, ResetRun = ResetRun,
        Pause = Pause, Resume = Resume, Dispose = Dispose }
end
