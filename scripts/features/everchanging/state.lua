-- Private state ownership for Everchanging.
return function(Neverbirth, deps)
    local Store = deps.Store
    local GetCurrentRunSeed = deps.GetCurrentRunSeed
    local IsValidItemId = deps.IsValidItemId
    local EVERCHANGING = deps.ItemId
    local PLAYER_RUNTIME_KEY = deps.RuntimeKey
    local STYLE_REGISTRY = deps.Registry.StyleRegistry
    local lifetime = deps.Lifetime

    local function GetEverchangingPlayerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function ResetEverchangingRunState()

        Store.Replace({
            runSeed = GetCurrentRunSeed(),
            players = {},
        })
        Store.Save()
        return Store.Get()
    end

    local function GetEverchangingRunState()

        local state = Store.Get()
        if type(state) ~= "table"
            or tostring(state.runSeed or "") ~= tostring(GetCurrentRunSeed() or "") then
            return ResetEverchangingRunState()
        end
        if type(state.players) ~= "table" then
            state.players = {}
        end
        return state
    end

    local function NormalizeSavedPlayerState(state)
        state.knownCopies = math.max(0, math.floor(tonumber(state.knownCopies) or 0))
        state.rollCount = math.max(0, math.floor(tonumber(state.rollCount) or 0))
        if type(state.styleId) ~= "string" or not STYLE_REGISTRY.byId[state.styleId] then
            state.styleId = nil
        end
        return state
    end

    local function GetEverchangingPlayerState(player)
        local playerKey = GetEverchangingPlayerKey(player)
        if playerKey == "" then
            return nil
        end
        local runState = GetEverchangingRunState()
        if type(runState.players[playerKey]) ~= "table" then
            runState.players[playerKey] = {}
        end
        return NormalizeSavedPlayerState(runState.players[playerKey])
    end

    local function GetEverchangingRuntime(player)
        if lifetime.disposed then return nil end
        if not player or not player.GetData then
            return nil
        end
        local ok, data = pcall(function()
            return player:GetData()
        end)
        if not ok or type(data) ~= "table" then
            return nil
        end
        lifetime.runtimePlayers[player] = true
        if type(data[PLAYER_RUNTIME_KEY]) ~= "table" then
            data[PLAYER_RUNTIME_KEY] = {
                appliedStyleId = nil,
                appliedRole = nil,
                appliedPlayerAnm2 = nil,

                originalSpriteFilename = nil,
                appliedCostumeIds = {},
                failedStyleId = nil,
                dirty = true,
            }
        end
        local runtime = data[PLAYER_RUNTIME_KEY]
        if type(runtime.appliedCostumeIds) ~= "table" then
            runtime.appliedCostumeIds = {}
        end

        return runtime
    end

    local function GetEverchangingCount(player)
        if not player or not player.GetCollectibleNum or not IsValidItemId(EVERCHANGING) then
            return 0
        end
        local ok, count = pcall(function()
            return player:GetCollectibleNum(EVERCHANGING)
        end)
        if not ok then
            return 0
        end
        return math.max(0, math.floor(tonumber(count) or 0))
    end

    return {
        GetEverchangingPlayerKey = GetEverchangingPlayerKey,
        ResetEverchangingRunState = ResetEverchangingRunState,
        GetEverchangingRunState = GetEverchangingRunState,
        NormalizeSavedPlayerState = NormalizeSavedPlayerState,
        GetEverchangingPlayerState = GetEverchangingPlayerState,
        GetEverchangingRuntime = GetEverchangingRuntime,
        GetEverchangingCount = GetEverchangingCount,
    }
end
