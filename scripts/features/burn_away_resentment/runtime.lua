-- Private runtime ownership for Burn Away the Resentment.
return function(Neverbirth, deps)
    local Installers = {}
    local Config = deps.Config
    local GetPlayers = deps.GetPlayers
    local lifetime = deps.Lifetime
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local GetFolkFloorKey = deps.World.GetFolkFloorKey
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local Queries = deps.Queries
    local Attributes = deps.Attributes
    local Ledger = deps.Ledger
    local Presentation = deps.Presentation
    local Combat = deps.Combat

    local function ClearPlayer(player)
        if not player then
            return
        end
        local key = GetFolkPlayerKey(player)
        local state = Neverbirth.BurnAwayResentment.states[key]
        if state then
            state.player, state.statusSprite, state.pendingHurtBurst = nil, nil, nil
        end
        Neverbirth.BurnAwayResentment.states[key] = nil
        Presentation.ClearOwnerBursts(key)
        Attributes.RefreshCache(player)
    end

    local function ClearRuntime()
        local previous = Neverbirth.BurnAwayResentment.states
        Neverbirth.BurnAwayResentment.states = {}
        Presentation.ClearBursts()
        Combat.ResetDepth()
        for _, state in pairs(previous) do
            local player = state.player
            state.player, state.statusSprite, state.pendingHurtBurst = nil, nil, nil
            if player then
                pcall(function()
                    if not player.Exists or player:Exists() then Attributes.RefreshCache(player) end
                end)
            end
        end
    end

    function Neverbirth:UpdateBurnAwayResentment()
        if not lifetime.active then return end
        for _, player in ipairs(GetPlayers()) do
            if Queries.PlayerHas(player) then
                local state = Neverbirth.BurnAwayResentment.GetState(player)
                if state.floorKey ~= GetFolkFloorKey() then
                    Ledger.SettleForNewFloor(player, state)
                end
                if not state.initialLayersGranted then
                    state.initialLayersGranted = true
                    Ledger.AddLayers(player, state, Config.InitialLayers)
                end
                if state.roomKey ~= GetFolkRoomKey() then
                    Ledger.AttachRoom(state)
                elseif not state.roomHadEnemies and not state.roomCounted and Queries.RoomHasEnemies() then
                    -- Enemy spawns can occur after MC_POST_NEW_ROOM; remember this room once they exist.
                    state.roomHadEnemies = true
                    if state.currentLayers == Config.MaxLayers and not state.floorSettled then
                        state.readyRoomKey = state.roomKey
                    end
                end
                Combat.ConfirmHurtBurst(player, state)
                if not state.floorSettled and state.roomHadEnemies and not state.roomCounted and Queries.IsRoomClear() then
                    state.roomCounted = true
                    state.countedRooms[state.roomKey] = true
                    local amount = Queries.IsBossRoom() and 2 or 1
                    Ledger.AddLayers(player, state, amount)
                end
            else
                local key = GetFolkPlayerKey(player)
                if Neverbirth.BurnAwayResentment.states[key] then
                    ClearPlayer(player)
                end
            end
        end
        Presentation.UpdateVisuals()
    end

    function Installers.Update()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateBurnAwayResentment)
    end

    function Installers.NewRoom()
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
            Presentation.ClearBursts()
            for _, state in pairs(Neverbirth.BurnAwayResentment.states) do
                Ledger.AttachRoom(state)
            end
        end)
    end

    function Installers.NewLevel()
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
            if not lifetime.active then return end
            for _, player in ipairs(GetPlayers()) do
                local state = Neverbirth.BurnAwayResentment.states[GetFolkPlayerKey(player)]
                if state and Queries.PlayerHas(player) then
                    Ledger.SettleForNewFloor(player, state)
                elseif state then
                    ClearPlayer(player)
                end
            end
            Presentation.ClearBursts()
        end)
    end

    function Installers.GameStarted()
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, isContinued)
            if lifetime.disposed then return end
            -- Baseline contract: these unsaved floor counters and visuals reset on
            -- both fresh starts and Continue; do not infer persistence from the seed.
            ClearRuntime()
            lifetime.active = true
        end)
    end

    function Installers.GameExit()
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
            lifetime.active = false
            ClearRuntime()
        end)
    end

    function Installers.Unload()
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, mod)
            if mod ~= Neverbirth then return end
            lifetime.disposed = true
            lifetime.active = false
            ClearRuntime()
        end)
    end

    return {
        ClearPlayer = ClearPlayer,
        ClearRuntime = ClearRuntime,
        UpdateBurnAwayResentment = Neverbirth.UpdateBurnAwayResentment,
        Installers = Installers,
    }
end
