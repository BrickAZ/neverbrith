return function(mod, deps)
    deps = deps or {}

    local PLAYER_NAME = "Dante"
    local COSTUME_PATH = "gfx/characters/costume_dante_hair.anm2"
    local RUNTIME_KEY = "NeverbirthDanteVisualRuntime"
    local playerTypeResolved = false
    local dantePlayerType = nil
    local costumeIdResolved = false
    local danteHairCostumeId = nil

    local function debugLog(message)
        if deps.DebugLog then deps.DebugLog("[neverbirth] Dante visual: " .. tostring(message)) end
    end

    local function resolveDantePlayerType()
        if playerTypeResolved then return dantePlayerType end
        playerTypeResolved = true
        if Isaac and Isaac.GetPlayerTypeByName then
            local ok, value = pcall(function()
                return Isaac.GetPlayerTypeByName(PLAYER_NAME, false)
            end)
            if ok and type(value) == "number" and value >= 0 then dantePlayerType = value end
        end
        if dantePlayerType == nil then debugLog("could not resolve registered player type") end
        return dantePlayerType
    end

    local function resolveHairCostumeId()
        if costumeIdResolved then return danteHairCostumeId end
        costumeIdResolved = true
        if Isaac and Isaac.GetCostumeIdByPath then
            local ok, value = pcall(function()
                return Isaac.GetCostumeIdByPath(COSTUME_PATH)
            end)
            if ok and type(value) == "number" and value > 0 then danteHairCostumeId = value end
        end
        if danteHairCostumeId == nil then debugLog("could not resolve hair costume " .. COSTUME_PATH) end
        return danteHairCostumeId
    end

    local function getRuntime(player)
        if not player or not player.GetData then return nil end
        local ok, data = pcall(function() return player:GetData() end)
        if not ok or type(data) ~= "table" then return nil end
        if type(data[RUNTIME_KEY]) ~= "table" then data[RUNTIME_KEY] = {} end
        return data[RUNTIME_KEY]
    end

    local function isDante(player)
        local playerType = resolveDantePlayerType()
        if playerType == nil or not player or not player.GetPlayerType then return false end
        local ok, actualType = pcall(function() return player:GetPlayerType() end)
        return ok and actualType == playerType
    end

    local function removeOwnedHair(player, runtime)
        local appliedId = runtime and runtime.appliedCostumeId or nil
        if not appliedId then return false end
        local removed = false
        if player and player.TryRemoveNullCostume then
            removed = pcall(function() player:TryRemoveNullCostume(appliedId) end)
        end
        runtime.appliedCostumeId = nil
        return removed
    end

    local function syncPlayer(player)
        local runtime = getRuntime(player)
        if not runtime then return false end
        if not isDante(player) then
            removeOwnedHair(player, runtime)
            return false
        end

        local costumeId = resolveHairCostumeId()
        if costumeId == nil then return false end
        if runtime.appliedCostumeId == costumeId then return true end
        if runtime.appliedCostumeId ~= nil then removeOwnedHair(player, runtime) end
        if not player.AddNullCostume then return false end
        local ok = pcall(function() player:AddNullCostume(costumeId) end)
        if not ok then
            debugLog("failed to apply hair costume")
            return false
        end
        runtime.appliedCostumeId = costumeId
        return true
    end

    local function getPlayers()
        if deps.GetPlayers then return deps.GetPlayers() or {} end
        local players = {}
        if Game and Isaac and Isaac.GetPlayer then
            local game = Game()
            local count = game and game.GetNumPlayers and game:GetNumPlayers() or 0
            for index = 0, count - 1 do players[#players + 1] = Isaac.GetPlayer(index) end
        end
        return players
    end

    local function playerInit(_, player)
        syncPlayer(player)
        return nil
    end

    local function gameStarted(_, isContinued)
        for _, player in ipairs(getPlayers()) do syncPlayer(player) end
        return nil
    end

    mod.DanteVisualTestAPI = {
        PlayerName = PLAYER_NAME,
        CostumePath = COSTUME_PATH,
        IsDante = isDante,
        SyncPlayer = syncPlayer,
        Callbacks = {
            PlayerInit = playerInit,
            GameStarted = gameStarted,
        },
    }

    if ModCallbacks.MC_POST_PLAYER_INIT then
        mod:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, playerInit)
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end
end

