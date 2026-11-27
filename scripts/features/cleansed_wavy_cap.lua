return function(Neverbirth, dependencies)
    local running, disposed = true, false
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local GetFolkRoomKey = dependencies.World.GetFolkRoomKey
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local CleansedWavyCapId = dependencies.CleansedWavyCapId
    local GetPlayers = dependencies.GetPlayers
    local GetRuntimeState = dependencies.GetRuntimeState

    local CleansedWavyCapSpeedPenalty = 0.03
    local CleansedWavyCapTearsBonus = 0.75
    local CleansedWavyCapSettledSpeedPenalty = 0.06
    local CleansedWavyCapSettledTearsBonus = 0.30
    local CleansedWavyCapMaxCharge = 900
    local CleansedWavyCapChargeStep = 100

    function Neverbirth:GetCleansedWavyCapState(player)
        local state = GetRuntimeState(player)
        state.cleansedWavyRoomKey = state.cleansedWavyRoomKey or GetFolkRoomKey()
        state.cleansedWavyCurrentSpeed = tonumber(state.cleansedWavyCurrentSpeed) or 0
        state.cleansedWavyCurrentTears = tonumber(state.cleansedWavyCurrentTears) or 0
        state.cleansedWavyLingeringSpeed = tonumber(state.cleansedWavyLingeringSpeed) or 0
        state.cleansedWavyLingeringTears = tonumber(state.cleansedWavyLingeringTears) or 0
        return state
    end

    local function RefreshCleansedWavyCapCache(player)
        if not player or not player.AddCacheFlags or not CacheFlag then
            return
        end
        local flags = 0
        if CacheFlag.CACHE_SPEED then flags = flags | CacheFlag.CACHE_SPEED end
        if CacheFlag.CACHE_FIREDELAY then flags = flags | CacheFlag.CACHE_FIREDELAY end
        if flags ~= 0 then
            player:AddCacheFlags(flags)
            if player.EvaluateItems then
                player:EvaluateItems()
            end
        end
    end

    local function QueueCleansedWavyCapChargeUpdate(player, slot)
        if not player then
            return
        end
        local state = Neverbirth:GetCleansedWavyCapState(player)
        state.cleansedWavyChargeSlot = slot or 0
        state.cleansedWavyChargeDelay = 1
        state.cleansedWavyChargeRepeats = 3
    end

    local function ApplyCleansedWavyCapChargeUpdate(player)
        if not player or not player.SetActiveCharge then
            return
        end
        local state = Neverbirth:GetCleansedWavyCapState(player)
        local delay = tonumber(state.cleansedWavyChargeDelay) or 0
        if delay <= 0 then
            return
        end
        local slot = state.cleansedWavyChargeSlot or 0
        if player.GetActiveItem and player:GetActiveItem(slot) ~= CleansedWavyCapId then
            state.cleansedWavyChargeSlot, state.cleansedWavyChargeDelay, state.cleansedWavyChargeRepeats = nil, nil, nil
            return
        end
        if delay > 1 then
            state.cleansedWavyChargeDelay = delay - 1
            return
        end
        local uses = tonumber(state.cleansedWavyUses) or 1
        local spent = math.min(CleansedWavyCapMaxCharge, uses * CleansedWavyCapChargeStep)
        local charge = math.max(0, CleansedWavyCapMaxCharge - spent)
        pcall(function()
            player:SetActiveCharge(charge, state.cleansedWavyChargeSlot or 0)
        end)

        local repeats = tonumber(state.cleansedWavyChargeRepeats) or 1
        if repeats > 1 then
            state.cleansedWavyChargeRepeats = repeats - 1
            state.cleansedWavyChargeDelay = 1
        else
            state.cleansedWavyChargeDelay = nil
            state.cleansedWavyChargeRepeats = nil
        end
    end

    function Neverbirth:UseCleansedWavyCap(itemId, rng, player, flags, slot)
        if not running or disposed then return nil end
        if not player then
            return nil
        end
        local state = Neverbirth:GetCleansedWavyCapState(player)
        state.cleansedWavyRoomKey = GetFolkRoomKey()
        state.cleansedWavyCurrentSpeed = (tonumber(state.cleansedWavyCurrentSpeed) or 0) + CleansedWavyCapSpeedPenalty
        state.cleansedWavyCurrentTears = (tonumber(state.cleansedWavyCurrentTears) or 0) + CleansedWavyCapTearsBonus
        state.cleansedWavyUses = (tonumber(state.cleansedWavyUses) or 0) + 1
        QueueCleansedWavyCapChargeUpdate(player, slot)
        RefreshCleansedWavyCapCache(player)
        return true
    end
    function callbackInstallers.Neverbirth_UseCleansedWavyCap()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, Neverbirth.UseCleansedWavyCap, CleansedWavyCapId)
    end

    local function AdvanceCleansedWavyCapRoom(player)
        if not player then
            return
        end
        local state = Neverbirth:GetCleansedWavyCapState(player)
        local roomKey = GetFolkRoomKey()
        if state.cleansedWavyRoomKey == roomKey then
            return
        end

        local speed = tonumber(state.cleansedWavyCurrentSpeed) or 0
        local tears = tonumber(state.cleansedWavyCurrentTears) or 0
        if speed > 0 or tears > 0 then
            state.cleansedWavyLingeringSpeed = (tonumber(state.cleansedWavyLingeringSpeed) or 0) + speed * 2
            state.cleansedWavyLingeringTears = (tonumber(state.cleansedWavyLingeringTears) or 0) + tears * 0.4
            state.cleansedWavyCurrentSpeed = 0
            state.cleansedWavyCurrentTears = 0
            RefreshCleansedWavyCapCache(player)
        end
        state.cleansedWavyRoomKey = roomKey
        state.cleansedWavyClearRoomKey = nil
    end

    local function DecayCleansedWavyCapOnClear(player)
        local room = GetFolkRoom()
        if not room or not room.IsClear or not room:IsClear() then
            return
        end
        local state = Neverbirth:GetCleansedWavyCapState(player)
        local roomKey = GetFolkRoomKey()
        if state.cleansedWavyClearRoomKey == roomKey then
            return
        end
        state.cleansedWavyClearRoomKey = roomKey

        local speed = tonumber(state.cleansedWavyLingeringSpeed) or 0
        local tears = tonumber(state.cleansedWavyLingeringTears) or 0
        if speed > 0 or tears > 0 then
            state.cleansedWavyLingeringSpeed = math.max(0, speed - CleansedWavyCapSettledSpeedPenalty)
            state.cleansedWavyLingeringTears = math.max(0, tears - CleansedWavyCapSettledTearsBonus)
            RefreshCleansedWavyCapCache(player)
        end
    end

    function Neverbirth:AdvanceCleansedWavyCapRooms()
        if not running or disposed then return end
        for _, player in ipairs(GetPlayers()) do
            if PlayerHasCollectible(player, CleansedWavyCapId) then
                AdvanceCleansedWavyCapRoom(player)
            end
        end
    end
    function callbackInstallers.Neverbirth_AdvanceCleansedWavyCapRooms()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, Neverbirth.AdvanceCleansedWavyCapRooms)
    end

    local function InstallCallbacks()
        if ModCallbacks.MC_POST_NEW_ROOM then
            callbackInstallers.Neverbirth_AdvanceCleansedWavyCapRooms()
        end

        callbackInstallers.Neverbirth_UseCleansedWavyCap()
    end

    local function ApplySpeed(player, state)
        state = state or GetRuntimeState(player)
        local currentSpeed = tonumber(state.cleansedWavyCurrentSpeed) or 0
        local lingeringSpeed = tonumber(state.cleansedWavyLingeringSpeed) or 0
        if (currentSpeed > 0 or lingeringSpeed > 0) and player.MoveSpeed then
            player.MoveSpeed = player.MoveSpeed - currentSpeed - lingeringSpeed
        end
    end

    local function ApplyTears(player, state)
        state = state or GetRuntimeState(player)
        local currentTears = tonumber(state.cleansedWavyCurrentTears) or 0
        local lingeringTears = tonumber(state.cleansedWavyLingeringTears) or 0
        if (currentTears > 0 or lingeringTears > 0) and player.MaxFireDelay then
            player.MaxFireDelay = player.MaxFireDelay - currentTears - lingeringTears
        end
    end

    local function UpdatePlayer(player)
        if PlayerHasCollectible(player, CleansedWavyCapId) then
            ApplyCleansedWavyCapChargeUpdate(player)
            AdvanceCleansedWavyCapRoom(player)
            DecayCleansedWavyCapOnClear(player)
        else
            local state = GetRuntimeState(player)
            state.cleansedWavyChargeSlot, state.cleansedWavyChargeDelay, state.cleansedWavyChargeRepeats = nil, nil, nil
        end
    end

    local function ResetFloor(state)
        state.cleansedWavyRoomKey = GetFolkRoomKey()
        state.cleansedWavyCurrentSpeed = 0
        state.cleansedWavyCurrentTears = 0
        state.cleansedWavyLingeringSpeed = 0
        state.cleansedWavyLingeringTears = 0
        state.cleansedWavyClearRoomKey = nil
    end

    local function HasCachedStats(player)
        local state = GetRuntimeState(player)
        return (tonumber(state.cleansedWavyCurrentSpeed) or 0) ~= 0
            or (tonumber(state.cleansedWavyCurrentTears) or 0) ~= 0
            or (tonumber(state.cleansedWavyLingeringSpeed) or 0) ~= 0
            or (tonumber(state.cleansedWavyLingeringTears) or 0) ~= 0
    end

    return {
        InstallCallbacks = InstallCallbacks,
        ApplySpeed = ApplySpeed,
        ApplyTears = ApplyTears,
        UpdatePlayer = UpdatePlayer,
        HasCachedStats = HasCachedStats,
        ResetFloor = ResetFloor, -- Legacy state-taking adapter.
        ResetPlayerFloor = function(player) ResetFloor(GetRuntimeState(player)) end,
        Pause = function() running = false end,
        Resume = function() if not disposed then running = true end end,
        Dispose = function() running, disposed = false, true end,
    }
end
