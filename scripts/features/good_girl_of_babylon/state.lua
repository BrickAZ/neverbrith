-- Item-owned state; the entry coordinates installation of the callback owners.
return function(Neverbirth, dependencies)
    local GetFolkRoomKey = dependencies.World.GetFolkRoomKey
    local GetFolkPlayerKey = dependencies.World.GetFolkPlayerKey
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local GoodGirlOfBabylonId = dependencies.GoodGirlOfBabylonId

    local function Find(player)
        return Neverbirth.GoodGirl.states[GetFolkPlayerKey(player)]
    end

    local function GetGoodGirlState(player)
        local key = GetFolkPlayerKey(player)
        local roomKey = GetFolkRoomKey()
        local state = Neverbirth.GoodGirl.states[key]
        if type(state) ~= "table" or state.roomKey ~= roomKey then
            dependencies.Runtime.RemoveFollowEffect(state, "haloEffect")
            dependencies.Runtime.RemoveFollowEffect(state, "echoEffect")
            state = {
                roomKey = roomKey,
                broken = false,
                redDamaged = false,
                rewarded = false,
                echoFrames = 0,
            }
            Neverbirth.GoodGirl.states[key] = state
        end
        return state
    end

    local function PlayerHasGoodGirl(player)
        return PlayerHasCollectible(player, GoodGirlOfBabylonId)
    end

    local function GoodGirlHasFullRedHearts(player)
        if not player or not player.GetMaxHearts or not player.GetHearts then
            return false
        end

        local maxRed = tonumber(player:GetMaxHearts()) or 0
        local currentRed = tonumber(player:GetHearts()) or 0
        return maxRed > 0 and currentRed >= maxRed
    end

    local function IsGoodGirlPresentable(player, state)
        return PlayerHasGoodGirl(player) and GoodGirlHasFullRedHearts(player) and not (state and state.broken)
    end

    local function ReplaceRoomState(key)
        local state = { roomKey = GetFolkRoomKey(), broken = false, redDamaged = false, rewarded = false, echoFrames = 0 }
        Neverbirth.GoodGirl.states[key] = state
        return state
    end

    local function Break(state)
        state.broken = true
        state.redDamaged = true
        state.echoFrames = 5 * 30
    end

    local function TickEcho(state)
        local previous = tonumber(state.echoFrames) or 0
        if previous > 0 then state.echoFrames = math.max(0, previous - 1) end
        return previous
    end

    local function ObservePresentable(state, presentable)
        presentable = presentable == true
        local changed = (state.presentable == true) ~= presentable
        state.presentable, state.detached = presentable, false
        return changed
    end

    local function Release(state)
        if state.detached then return false end
        local hadStats = state.presentable == true or state.broken == true
            or (tonumber(state.echoFrames) or 0) > 0
        -- End possession effects without erasing this room's damage/reward history.
        state.echoFrames, state.presentable, state.detached = 0, false, true
        return hadStats
    end

    local function ClaimReward(state)
        if state.rewarded then return false end
        state.rewarded = true
        return true
    end

    local function ResetRuntime()
        Neverbirth.GoodGirl.states = {}
    end

    return {
        Find = Find,
        GetGoodGirlState = GetGoodGirlState,
        PlayerHasGoodGirl = PlayerHasGoodGirl,
        GoodGirlHasFullRedHearts = GoodGirlHasFullRedHearts,
        IsGoodGirlPresentable = IsGoodGirlPresentable,
        ReplaceRoomState = ReplaceRoomState,
        Break = Break,
        TickEcho = TickEcho,
        ObservePresentable = ObservePresentable,
        Release = Release,
        ClaimReward = ClaimReward,
        ResetRuntime = ResetRuntime,
    }
end
