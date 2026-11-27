-- Coordinates item owners and preserves the original installation phases.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    -- Native bindings are declared here; the entry chooses their installation phase.
    local callbackInstallers = {}
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local GetFolkRoomKey = dependencies.World.GetFolkRoomKey
    local GetFolkPlayerKey = dependencies.World.GetFolkPlayerKey
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local TheMoonIsBeautifulId = dependencies.TheMoonIsBeautifulId
    local GetPlayers = dependencies.GetPlayers
    local runtimeActive = true
    local disposed = false
    local restoringCache = false
    local bonusOwners = {}
    private.IsRuntimeActive = function() return runtimeActive and not disposed end

    function private.PlayerHas(player)
        return PlayerHasCollectible(player, TheMoonIsBeautifulId)
    end

    function Neverbirth.Moon.GetRoomState()
        local key = GetFolkRoomKey()
        local state = private.roomState
        if type(state) ~= "table" or state.roomKey ~= key then
            Neverbirth.Moon.ClearVisuals()
            state = {
                roomKey = key,
                frame = 0,
                triggered = false,
                failed = false,
                playerStates = {},
                bonusPlayers = {},
            }
            private.roomState = state
        end
        return state
    end

    function private.IsRoomEligible()
        local room = GetFolkRoom()
        if room and room.IsClear then
            local ok, clear = pcall(function()
                return room:IsClear()
            end)
            if ok and clear == true then
                return false
            end
        end
        return true
    end

    function private.IsFiring(player)
        if player and player.GetShootingInput then
            local ok, input = pcall(function()
                return player:GetShootingInput()
            end)
            if ok and type(input) == "table" then
                local x = tonumber(input.X) or 0
                local y = tonumber(input.Y) or 0
                if (x * x + y * y) > 0.01 then
                    return true
                end
            end
        end

        if player and player.GetFireDirection then
            local ok, direction = pcall(function()
                return player:GetFireDirection()
            end)
            if ok and type(direction) == "number" then
                if Direction then
                    return direction == Direction.LEFT or direction == Direction.UP or direction == Direction.RIGHT or direction == Direction.DOWN
                end
                return direction >= 0 and direction <= 3
            end
        end

        return false
    end

    function private.RefreshCache(player)
        if not player or not player.AddCacheFlags or not CacheFlag then
            return
        end

        local flags = 0
        if CacheFlag.CACHE_DAMAGE then flags = flags | CacheFlag.CACHE_DAMAGE end
        if CacheFlag.CACHE_LUCK then flags = flags | CacheFlag.CACHE_LUCK end
        if flags ~= 0 then
            player:AddCacheFlags(flags)
            if player.EvaluateItems then
                player:EvaluateItems()
            end
        end
    end

    function private.RefreshAllCaches()
        for _, player in ipairs(GetPlayers()) do
            private.RefreshCache(player)
        end
    end

    function private.SpawnFailureVisuals(state)
        if type(state) ~= "table" or state.failureVisualSpawned then
            return
        end

        state.failureVisualSpawned = true
        for _, player in ipairs(GetPlayers()) do
            if private.PlayerHas(player) then
                private.SpawnVisual("Fail", player, player.Position)
            end
        end
    end

    function private.Trigger(player, state)
        if type(state) ~= "table" or state.triggered or state.failed then
            return
        end

        state.triggered = true
        state.triggerPlayerSeed = player and player.InitSeed or nil
        state.bonusPlayers[GetFolkPlayerKey(player)] = true
        bonusOwners[GetFolkPlayerKey(player)] = player
        for _, playerState in pairs(state.playerStates) do
            private.RemoveVisual(playerState.promptVisual)
            playerState.promptVisual = nil
        end
        private.SpawnVisual("Success", player, player and player.Position or Vector(320, 280))
        private.MarkRoomEnemies(player)
        private.RefreshCache(player)
    end

    function private.GetTriggeringPlayer(state)
        local seed = state and state.triggerPlayerSeed
        if seed == nil then
            return nil
        end
        for _, player in ipairs(GetPlayers()) do
            if player and player.InitSeed == seed then
                return player
            end
        end
        return nil
    end

    function private.ResetRoom()
        if not runtimeActive then return end
        bonusOwners = {}
        Neverbirth.Moon.ClearVisuals()
        private.roomState = {
            roomKey = GetFolkRoomKey(),
            frame = 0,
            triggered = false,
            failed = false,
            playerStates = {},
            bonusPlayers = {},
        }
        private.RefreshAllCaches()
    end

    function private.ResetRuntime()
        local previous = bonusOwners
        bonusOwners = {}
        Neverbirth.Moon.ClearVisuals()
        private.roomState = nil
        Neverbirth.Moon.waveDamageDepth = 0
        Neverbirth.Moon.bossBonusDepth = 0
        -- Restore known owners without asking Game for a player list during unload.
        restoringCache = true
        for _, player in pairs(previous) do
            pcall(function()
                if not player.Exists or player:Exists() then private.RefreshCache(player) end
            end)
        end
        restoringCache = false
    end

    function Neverbirth:UpdateMoonIsBeautiful()
        if not runtimeActive then return end
        private.UpdateVisuals()

        local state = Neverbirth.Moon.GetRoomState()
        if state.triggered or state.failed then
            return
        end

        if not private.IsRoomEligible() then
            state.failed = true
            return
        end

        local hasMoonPlayer = false
        for _, player in ipairs(GetPlayers()) do
            if private.PlayerHas(player) then
                hasMoonPlayer = true
                local key = GetFolkPlayerKey(player)
                local playerState = state.playerStates[key] or { silenceFrames = 0 }
                state.playerStates[key] = playerState
                if playerState.promptVisual and not private.HasVisual(playerState.promptVisual) then
                    playerState.promptVisual = nil
                end
                if not playerState.promptVisual then
                    playerState.promptVisual = private.SpawnVisual("Prompt", player, player.Position)
                end

                if private.IsFiring(player) then
                    playerState.silenceFrames = 0
                else
                    playerState.silenceFrames = (tonumber(playerState.silenceFrames) or 0) + 1
                    if state.frame < private.Config.WindowFrames and playerState.silenceFrames >= private.Config.SilenceFrames then
                        private.Trigger(player, state)
                        return
                    end
                end
            end
        end

        if not hasMoonPlayer then
            state.failed = true
            return
        end

        state.frame = (tonumber(state.frame) or 0) + 1
        if state.frame >= private.Config.WindowFrames then
            private.SpawnFailureVisuals(state)
            state.failed = true
            for _, playerState in pairs(state.playerStates) do
                private.RemoveVisual(playerState.promptVisual)
                playerState.promptVisual = nil
            end
        end
    end
    function callbackInstallers.InstallUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateMoonIsBeautiful)
    end

    function Neverbirth:EvaluateMoonIsBeautiful(player, cacheFlag)
        if not runtimeActive or restoringCache then return end
        if not private.PlayerHas(player) or not CacheFlag then
            return
        end

        local state = Neverbirth.Moon.GetRoomState()
        if type(state) ~= "table" or state.bonusPlayers[GetFolkPlayerKey(player)] ~= true then
            return
        end

        if cacheFlag == CacheFlag.CACHE_DAMAGE then
            player.Damage = player.Damage + private.Config.DamageBonus
        elseif cacheFlag == CacheFlag.CACHE_LUCK then
            player.Luck = player.Luck + private.Config.LuckBonus
        end
    end
    function callbackInstallers.InstallEvaluate()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, Neverbirth.EvaluateMoonIsBeautiful)
    end

    local function InstallGameStarted()
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
            if disposed then return end
            -- Baseline: the silence window, marks and room bonuses are runtime-only
            -- and restart on Continue as well as a same-seed fresh run.
            runtimeActive = true
            private.ResetRuntime()
        end)
    end
    local function ClearRuntimeForExit()
        if not runtimeActive then return end
        runtimeActive = false
        private.ResetRuntime()
    end
    local function InstallTeardown()
        if ModCallbacks.MC_PRE_GAME_EXIT then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
                ClearRuntimeForExit()
            end)
        end
        if ModCallbacks.MC_PRE_MOD_UNLOAD then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, mod)
                if mod ~= Neverbirth then return end
                disposed = true
                ClearRuntimeForExit()
            end)
        end
    end
    return { InstallUpdate = callbackInstallers.InstallUpdate, InstallEvaluate = callbackInstallers.InstallEvaluate,
        InstallGameStarted = InstallGameStarted, InstallTeardown = InstallTeardown }
end
