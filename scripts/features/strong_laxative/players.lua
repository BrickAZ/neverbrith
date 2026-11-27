-- Owns player clocks; GetState retains the existing deliberately mutable public view.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local StrongLaxativeConfig = dependencies.Config
    local StrongLaxativeId = dependencies.ItemId
    local IsValidItemId = dependencies.IsValidItemId
    local PlayerHasCollectible = dependencies.PlayerHasCollectible
    local GetFolkPlayerKey = dependencies.GetPlayerKey
    local GetPlayers = dependencies.GetPlayers
    local strongLaxativeStates = {}
    local runtimeActive = true
    local disposed = false
    private.IsRuntimeActive = function() return runtimeActive and not disposed end

    function private.PlayerHas(player)
        return PlayerHasCollectible(player, StrongLaxativeId)
    end

    function Neverbirth.StrongLaxative.GetCopyCount(player)
        if not player or not IsValidItemId(StrongLaxativeId) then
            return 0
        end

        if player.GetCollectibleNum then
            local ok, count = pcall(function()
                return player:GetCollectibleNum(StrongLaxativeId)
            end)
            if ok then
                return math.max(0, tonumber(count) or 0)
            end
        end

        return private.PlayerHas(player) and 1 or 0
    end

    function Neverbirth.StrongLaxative.GetState(player)
        local key = GetFolkPlayerKey(player)
        local state = strongLaxativeStates[key]
        if type(state) ~= "table" then
            state = {
                creepCooldown = 0,
                poopTimer = 0,
            }
            strongLaxativeStates[key] = state
        end
        return state
    end

    function private.IsMoving(player)
        if not player then
            return false
        end

        local velocity = player.Velocity
        if velocity and velocity.Length then
            local ok, length = pcall(function()
                return velocity:Length()
            end)
            if ok and (tonumber(length) or 0) > 0.35 then
                return true
            end
        end

        if player.GetMovementInput then
            local ok, input = pcall(function()
                return player:GetMovementInput()
            end)
            if ok and input and input.Length then
                local okLength, length = pcall(function()
                    return input:Length()
                end)
                if okLength and (tonumber(length) or 0) > 0.1 then
                    return true
                end
            end
        end

        return false
    end

    function Neverbirth:UpdateStrongLaxativePlayers()
        if not runtimeActive then return end
        for _, player in ipairs(GetPlayers()) do
            local copies = Neverbirth.StrongLaxative.GetCopyCount(player)
            if copies <= 0 then
                strongLaxativeStates[GetFolkPlayerKey(player)] = nil
                Neverbirth.StrongLaxative.ApplyCostume(player, false)
            else
                local state = Neverbirth.StrongLaxative.GetState(player)
                Neverbirth.StrongLaxative.ApplyCostume(player, true)

                state.creepCooldown = math.max(0, (tonumber(state.creepCooldown) or 0) - 1)
                if state.creepCooldown <= 0 and private.IsMoving(player) then
                    if Neverbirth.StrongLaxative.SpawnCreep(player) then
                        state.creepCooldown = StrongLaxativeConfig.CreepInterval
                    end
                end

                state.poopTimer = (tonumber(state.poopTimer) or 0) + 1
                if state.poopTimer >= StrongLaxativeConfig.PoopRollInterval then
                    state.poopTimer = 0
                    Neverbirth.StrongLaxative.TryPoopRoll(player, copies)
                end
            end
        end
    end
    function callbackInstallers.Neverbirth_UpdateStrongLaxativePlayers()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateStrongLaxativePlayers)
    end

    local function InstallUpdateCallback()
        callbackInstallers.Neverbirth_UpdateStrongLaxativePlayers()
    end

    function Neverbirth:ResetStrongLaxativeRoomState()
        if not runtimeActive then return end
        dependencies.ResetPoopRoom()
        for _, state in pairs(strongLaxativeStates) do
            if type(state) == "table" then
                state.creepCooldown = 0
                state.poopTimer = 0
            end
        end
    end
    function callbackInstallers.Neverbirth_ResetStrongLaxativeRoomState()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.ResetStrongLaxativeRoomState)
    end

    local function InstallRoomCallback()
        if ModCallbacks.MC_POST_NEW_ROOM then
            callbackInstallers.Neverbirth_ResetStrongLaxativeRoomState()
        end
    end
    local function ResetRuntime()
        strongLaxativeStates = {}
        dependencies.ResetPoopRuntime()
        dependencies.ResetPresentation()
        dependencies.ResetCreep()
    end
    local function InstallLifecycle()
        if ModCallbacks.MC_POST_GAME_STARTED then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
                if disposed then return end
                -- Clocks are room-transient (the existing new-room path already
                -- zeroes them on Continue); appearance must bind the current body.
                runtimeActive = true
                ResetRuntime()
            end)
        end
        if ModCallbacks.MC_PRE_GAME_EXIT then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
                if not runtimeActive then return end
                runtimeActive = false
                ResetRuntime()
            end)
        end
        if ModCallbacks.MC_PRE_MOD_UNLOAD then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, mod)
                if mod ~= Neverbirth then return end
                disposed = true
                if not runtimeActive then return end
                runtimeActive = false
                ResetRuntime()
            end)
        end
    end
    return { InstallUpdateCallback = InstallUpdateCallback, InstallRoomCallback = InstallRoomCallback,
        InstallLifecycle = InstallLifecycle }
end
