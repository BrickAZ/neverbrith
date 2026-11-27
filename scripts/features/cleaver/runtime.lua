-- Private runtime ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local PlayerHasCollectible = deps.World.PlayerHasCollectible
    local GetPlayers = deps.GetPlayers
    local CleaverId = deps.CleaverId
    local IsValidItemId = deps.IsValidItemId
    local lifetime = deps.Lifetime
    local shadowState = deps.ShadowState
    local Queries = deps.Queries
    local Attributes = deps.Attributes
    local Presentation = deps.Presentation
    local Shadows = deps.Shadows
    local Controls = deps.Controls
    local Combat = deps.Combat

    local function ClearPlayer(player)
        if not player then
            return
        end
        local key = GetFolkPlayerKey(player)
        local state = Neverbirth.Cleaver.states[key]
        if state then
            Combat.RemoveSwing(state)
            state.player, state.holdVisual = nil, nil
        end
        Neverbirth.Cleaver.states[key] = nil
        if state then Attributes.RefreshCleaverCache(player) end
    end

    local function ClearRuntime(restoreCache)
        local previous = Neverbirth.Cleaver.states
        Neverbirth.Cleaver.states = {}
        for _, state in pairs(previous) do
            Combat.RemoveSwing(state)
            local player = state.player
            state.player, state.holdVisual = nil, nil
            if restoreCache ~= false then
                lifetime.restoringCache = true
                -- Released native owners may reject Exists/cache operations during teardown.
                pcall(Attributes.RefreshCleaverCache, player)
                lifetime.restoringCache = false
            end
        end
        Neverbirth.Cleaver.shadows = {}
        shadowState.consumedPlayerShadows = {}
        shadowState.roomKey = nil
        shadowState.shadowDamageDepth = 0
    end

    function Neverbirth:UpdateCleaverCharacter()
        if not lifetime.runtimeActive then return end
        for _, player in ipairs(GetPlayers()) do
            local key = GetFolkPlayerKey(player)
            if Neverbirth.Cleaver.IsEnabled(player) then
                local state = Neverbirth.Cleaver.GetState(player)
                if state.needsDamageRefresh then
                    state.needsDamageRefresh = false
                    if player.AddCacheFlags and CacheFlag and CacheFlag.CACHE_DAMAGE then
                        player:AddCacheFlags(CacheFlag.CACHE_DAMAGE)
                        if player.EvaluateItems then
                            player:EvaluateItems()
                        end
                    end
                end
                if (tonumber(state.cooldown) or 0) > 0 then
                    state.cooldown = math.max(0, (tonumber(state.cooldown) or 0) - 1)
                end
                local direction = Controls.GetSwingInputDirection(player)
                Presentation.UpdateHoldVisual(state, direction)
                if direction and Neverbirth.Cleaver.TrySwing(player, direction) and player.SetShootingCooldown then
                    pcall(function() player:SetShootingCooldown(Neverbirth.Cleaver.Config.SwingCooldownFrames) end)
                end
                Combat.UpdateSwing(state)
            elseif Neverbirth.Cleaver.states[key] then
                ClearPlayer(player)
            end
        end
        Shadows.TrackShadows()
    end
    function Installers.Update()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateCleaverCharacter)
    end

    function Neverbirth:StartCleaverCharacterRun(isContinued)
        if lifetime.disposed then return end
        -- Swings, shadows and raw-cache snapshots are transient on Continue too.
        -- Start preserves the engine's already evaluated character attributes;
        -- only exit/unload removes this instance's cache contribution.
        ClearRuntime(false)
        lifetime.runtimeActive = true
        if isContinued or not IsValidItemId(CleaverId) then
            return
        end
        for _, player in ipairs(GetPlayers()) do
            if Queries.IsStranger(player) and not PlayerHasCollectible(player, CleaverId) and player.AddCollectible then
                pcall(function()
                    player:AddCollectible(CleaverId, 0, true)
                end)
            end
        end
    end
    function Installers.GameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, Neverbirth.StartCleaverCharacterRun)
    end

    function Installers.NewRoom()
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
            if not lifetime.runtimeActive then return end
            for _, state in pairs(Neverbirth.Cleaver.states) do
                Combat.RemoveSwing(state)
            end
            Neverbirth.Cleaver.shadows = {}
            shadowState.consumedPlayerShadows = {}
            shadowState.roomKey = GetFolkRoomKey()
        end)
    end

    function Installers.Exit()
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
            lifetime.runtimeActive = false
            ClearRuntime()
        end)
    end

    function Installers.Unload()
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, function(_, mod)
            if mod ~= Neverbirth then return end
            lifetime.disposed = true
            lifetime.runtimeActive = false
            ClearRuntime()
        end)
    end

    return {
        ClearPlayer = ClearPlayer,
        ClearRuntime = ClearRuntime,
        UpdateCleaverCharacter = Neverbirth.UpdateCleaverCharacter,
        StartCleaverCharacterRun = Neverbirth.StartCleaverCharacterRun,
        Installers = Installers,
    }
end
