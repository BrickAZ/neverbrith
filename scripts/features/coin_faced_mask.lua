return function(Neverbirth, dependencies)
    local Runtime = { running = true, disposed = false }
    local GetFolkRoomKey = dependencies.World.GetFolkRoomKey
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local GetPlayerCoins = dependencies.World.GetPlayerCoins
    local CoinFacedMaskId = dependencies.CoinFacedMaskId
    local GetPlayers = dependencies.GetPlayers
    local MASK_REQUIRED_COINS = 5
    local COIN_MASK_VISUAL_NONE = "none"
    local state = include("scripts.features.coin_faced_mask.state")({
        GetPlayerKey = dependencies.World.GetFolkPlayerKey, GetRoomKey = GetFolkRoomKey,
    })
    local presentation = include("scripts.features.coin_faced_mask.presentation")(Neverbirth, {
        GetPlayerKey = dependencies.World.GetFolkPlayerKey,
    })
    local settlement = include("scripts.features.coin_faced_mask.settlement")(Neverbirth, {
        World = dependencies.World, CoinFacedMaskId = CoinFacedMaskId,
        RequiredCoins = MASK_REQUIRED_COINS, State = state, Presentation = presentation,
        Runtime = Runtime,
    })
    local ApplyCoinFacedMaskCostume = presentation.Apply
    local RefreshMaskLuck = settlement.RefreshLuck
    local DisturbMaskEnemies = settlement.DisturbEnemies

    local function RefreshCoinFacedMaskForPlayer(player)
        local previous = state.Find(player)
        local hadPenalty = previous and (tonumber(previous.luckPenalty) or 0) ~= 0
        local roomState = state.Replace(player,
            PlayerHasCollectible(player, CoinFacedMaskId) and GetPlayerCoins(player) >= MASK_REQUIRED_COINS)
        if roomState.active then
            DisturbMaskEnemies(player)
        end
        ApplyCoinFacedMaskCostume(player, presentation.GetVisualState(roomState))
        if hadPenalty then
            RefreshMaskLuck(player)
        end
    end

    function Neverbirth:RefreshCoinFacedMaskRoom()
        if not Runtime.running or Runtime.disposed then return end
        for _, player in ipairs(GetPlayers()) do
            RefreshCoinFacedMaskForPlayer(player)
        end
    end

    if ModCallbacks.MC_POST_NEW_ROOM then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.RefreshCoinFacedMaskRoom)
    end

    function Neverbirth:ClearCoinFacedMaskCostumes()
        if not Runtime.running or Runtime.disposed then return end
        for _, player in ipairs(GetPlayers()) do
            local previous = state.Find(player)
            local hadPenalty = previous and (tonumber(previous.luckPenalty) or 0) ~= 0
            state.Remove(player)
            ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
            if hadPenalty then RefreshMaskLuck(player) end
        end
        state.Reset()
    end

    if ModCallbacks.MC_POST_NEW_LEVEL then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, Neverbirth.ClearCoinFacedMaskCostumes)
    end

    function Neverbirth:UpdateCoinFacedMaskCostumes()
        if not Runtime.running or Runtime.disposed then return end
        for _, player in ipairs(GetPlayers()) do
            if not PlayerHasCollectible(player, CoinFacedMaskId) then
                local previous = state.Find(player)
                local hadPenalty = previous and (tonumber(previous.luckPenalty) or 0) ~= 0
                state.Remove(player)
                ApplyCoinFacedMaskCostume(player, COIN_MASK_VISUAL_NONE)
                if hadPenalty then RefreshMaskLuck(player) end
            else
                local roomState = state.Find(player)
                if type(roomState) ~= "table" or roomState.roomKey ~= GetFolkRoomKey() then
                    RefreshCoinFacedMaskForPlayer(player)
                elseif not roomState.consumed and not roomState.active and (tonumber(roomState.luckPenalty) or 0) == 0 and GetPlayerCoins(player) >= MASK_REQUIRED_COINS then
                    RefreshCoinFacedMaskForPlayer(player)
                else
                    ApplyCoinFacedMaskCostume(player, presentation.GetVisualState(roomState))
                end
            end
        end
    end

    if ModCallbacks.MC_POST_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, Neverbirth.UpdateCoinFacedMaskCostumes)
    end

    -- Room, level and update callbacks precede damage and cache callbacks as before.
    settlement.InstallCallbacks()
    local function ResetRuntime()
        Neverbirth:ClearCoinFacedMaskCostumes()
        state.Reset()
        presentation.ResetRuntime()
    end
    local function Pause()
        Runtime.running = false
        presentation.ResetRuntime()
    end
    local function Resume(refresh)
        if Runtime.disposed then return end
        Runtime.running = true
        if refresh == false then return end
        for _, player in ipairs(GetPlayers()) do
            if state.Find(player) then RefreshMaskLuck(player) end
        end
    end
    local function Dispose()
        if Runtime.disposed then return end
        Pause()
        Runtime.disposed = true
        state.Reset()
    end
    return { ClearPlayerCostume = presentation.ClearPlayerCostume, ResetRuntime = ResetRuntime,
        Pause = Pause, Resume = Resume, Dispose = Dispose }
end
