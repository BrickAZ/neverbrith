return function(Neverbirth, dependencies)
    local GetFolkFloorKey = dependencies.World.GetFolkFloorKey
    local GetFolkPlayerKey = dependencies.World.GetFolkPlayerKey
    local GetCurrentRunSeed = dependencies.GetCurrentRunSeed
    local Store = dependencies.Store

    local blackTaisuiStates = {}

local getRunData = include("scripts.runtime.run_section")(Store, GetCurrentRunSeed,
    function() return { runSeed = GetCurrentRunSeed(), players = {}, meatLumpCounts = {}, meatLumpLives = {} } end, { "players", "meatLumpCounts", "meatLumpLives" })
    local function GetSaveData()
        return getRunData()
    end

    local function GetRuntimeState(player)
        local key = GetFolkPlayerKey(player)
        local state = blackTaisuiStates[key]
        if type(state) ~= "table" then
            state = { floorKey = GetFolkFloorKey(), sporeKeys = {} }
            blackTaisuiStates[key] = state
        end
        if state.floorKey ~= GetFolkFloorKey() then
            state.floorKey = GetFolkFloorKey()
            state.deathSavedFloorKey = nil
            state.sporeKeys = {}
            state.wavySuppressedStacks = 0
        end
        if type(state.sporeKeys) ~= "table" then
            state.sporeKeys = {}
        end
        return state
    end

    local function ResetRuntime()
        blackTaisuiStates = {}
    end

    local function ResetRun()
        -- A seed identifies generation, not a unique run. Preserve extensions
        -- while explicitly invalidating only this owner's saved run fields.
        local data = Store.Get()
        data.runSeed = GetCurrentRunSeed()
        data.players, data.meatLumpCounts, data.meatLumpLives = {}, {}, {}
        ResetRuntime()
        Store.Save()
    end

    return {
        GetSaveData = GetSaveData,
        GetRuntimeState = GetRuntimeState,
        ResetRuntime = ResetRuntime,
        ResetRun = ResetRun,
    }
end
