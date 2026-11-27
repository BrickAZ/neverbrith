-- The only writer of per-player room state. Find/Replace return borrowed read-only views.
return function(dependencies)
    local states = {}
    local function Find(player)
        return states[dependencies.GetPlayerKey(player)]
    end
    local function Replace(player, active)
        local state = {
            roomKey = dependencies.GetRoomKey(), active = active,
            consumed = false, luckPenalty = 0,
        }
        states[dependencies.GetPlayerKey(player)] = state
        return state
    end
    local function Consume(player)
        local state = Find(player)
        if type(state) ~= 'table' or state.roomKey ~= dependencies.GetRoomKey() then
            state = Replace(player, false)
        end
        if not state.active or state.consumed then return false end
        state.consumed = true
        state.active = false
        return true
    end
    local function Break(player, penalty)
        states[dependencies.GetPlayerKey(player)].luckPenalty = penalty
    end
    local function Remove(player)
        states[dependencies.GetPlayerKey(player)] = nil
    end
    local function Reset()
        states = {}
    end
    return { Find = Find, Replace = Replace, Consume = Consume, Break = Break, Remove = Remove, Reset = Reset }
end
