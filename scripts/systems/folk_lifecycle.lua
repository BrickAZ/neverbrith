return function(Neverbirth, dependencies)
    local GetPlayers = dependencies.GetPlayers
    local CoinFacedMask = dependencies.CoinFacedMask
    local BlackTaisui = dependencies.BlackTaisui
    local GoodGirl = dependencies.GoodGirl
    local running, disposed = true, false

    local resetRun = include("scripts.runtime.new_run_reset")({
        GetPlayers = GetPlayers,
        Players = {
            function(player) CoinFacedMask.ClearPlayerCostume(player) end,
            function(player) GoodGirl.ClearPlayerCostume(player) end,
        },
        Reset = {
            function() CoinFacedMask.ResetRuntime() end,
            function() BlackTaisui.ResetRun() end,
            function() GoodGirl.ResetRuntime() end,
        },
    })
    function Neverbirth:ResetFolkHorrorItemState(isContinued)
        if disposed then return end
        local resuming = not running
        running = true
        CoinFacedMask.Resume(false)
        BlackTaisui.Resume(false)
        GoodGirl.Resume(false)
        resetRun(self, isContinued)
        if isContinued and resuming then
            CoinFacedMask.Resume()
            BlackTaisui.Resume()
            GoodGirl.Resume()
        end
    end

    if ModCallbacks.MC_POST_GAME_STARTED then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.ResetFolkHorrorItemState)
    end

    function Neverbirth:ExitFolkHorrorItemState()
        if not running or disposed then return end
        running = false
        for _, player in ipairs(GetPlayers()) do
            CoinFacedMask.ClearPlayerCostume(player)
            GoodGirl.ClearPlayerCostume(player)
        end
        CoinFacedMask.Pause()
        BlackTaisui.Pause()
        GoodGirl.Pause()
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, Neverbirth.ExitFolkHorrorItemState)
    end

    function Neverbirth:UnloadFolkHorrorItemState(unloaded)
        if unloaded ~= Neverbirth or disposed then return end
        running, disposed = false, true
        -- Unload may run after the game world is already unavailable.
        CoinFacedMask.Dispose()
        BlackTaisui.Dispose()
        GoodGirl.Dispose()
    end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, Neverbirth.UnloadFolkHorrorItemState)
    end
end
