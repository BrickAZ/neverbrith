-- Private ledger ownership for Burn Away the Resentment.
return function(Neverbirth, deps)
    local Installers = {}
    local Config = deps.Config
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local GetFolkFloorKey = deps.World.GetFolkFloorKey
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local Queries = deps.Queries
    local Attributes = deps.Attributes

    function Neverbirth.BurnAwayResentment.GetState(player)
        if not player then
            return nil
        end

        local key = GetFolkPlayerKey(player)
        local state = Neverbirth.BurnAwayResentment.states[key]
        if type(state) ~= "table" then
            state = {
                player = player,
                currentLayers = 0,
                floorSettled = false,
                pendingClarity = 0,
                currentFloorClarity = 0,
                initialLayersGranted = false,
                floorKey = GetFolkFloorKey(),
                roomKey = nil,
                roomHadEnemies = false,
                roomCounted = false,
                countedRooms = {},
                readyRoomKey = nil,
                pendingHurtBurst = nil,
                statusSprite = nil,
                statusAnimation = nil,
                statusFrame = nil,
            }
            Neverbirth.BurnAwayResentment.states[key] = state
        end
        state.player = player
        return state
    end

    local function AttachRoom(state)
        if type(state) ~= "table" then
            return
        end
        local roomKey = GetFolkRoomKey()
        state.roomKey = roomKey
        state.roomHadEnemies = Queries.RoomHasEnemies()
        state.roomCounted = state.countedRooms and state.countedRooms[roomKey] == true or false
        if state.currentLayers == Config.MaxLayers and not state.floorSettled and state.roomHadEnemies then
            state.readyRoomKey = roomKey
        else
            state.readyRoomKey = nil
        end
    end

    local function AddLayers(player, state, amount)
        if type(state) ~= "table" or state.floorSettled then
            return false
        end
        local before = tonumber(state.currentLayers) or 0
        state.currentLayers = math.min(Config.MaxLayers, before + math.max(0, tonumber(amount) or 0))
        if state.currentLayers ~= before then
            Attributes.RefreshCache(player)
            return true
        end
        return false
    end

    local function SettleForNewFloor(player, state)
        if type(state) ~= "table" then
            return
        end
        local pending = tonumber(state.pendingClarity) or 0
        if pending <= 0 then
            pending = tonumber(state.currentLayers) or 0
        end
        state.currentFloorClarity = math.max(0, math.min(Config.MaxLayers, pending))
        state.pendingClarity = 0
        state.currentLayers = 0
        state.floorSettled = false
        state.floorKey = GetFolkFloorKey()
        state.roomKey = nil
        state.roomHadEnemies = false
        state.roomCounted = false
        state.countedRooms = {}
        state.readyRoomKey = nil
        state.pendingHurtBurst = nil
        Attributes.RefreshCache(player)
    end

    return {
        GetState = Neverbirth.BurnAwayResentment.GetState,
        AttachRoom = AttachRoom,
        AddLayers = AddLayers,
        SettleForNewFloor = SettleForNewFloor,
        Installers = Installers,
    }
end
