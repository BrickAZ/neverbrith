-- Private night_of_the_cowards responsibility: grants. No registration until an installer is called.
return function(Neverbirth, deps)
    local context = deps.Context
    local runtime = deps.Runtime
    local FLIGHT_ITEM_ID = deps.Config.FLIGHT_ITEM_ID
    local debugLog = deps.debugLog
    local playerKey = deps.playerKey
    local collectibleCount = deps.collectibleCount

    local function currentRunSeed()
        if type(context.GetCurrentRunSeed) ~= "function" then return 0 end
        local ok, seed = pcall(context.GetCurrentRunSeed)
        return ok and math.floor(tonumber(seed) or 0) or 0
    end

    local function getPersistentData()
        if type(context.GetSaveRoot) ~= "function" then
            return { c20Granted = runtime.localC20Grants }
        end
        local ok, root = pcall(context.GetSaveRoot)
        if not ok or type(root) ~= "table" then
            return { c20Granted = runtime.localC20Grants }
        end

        local seed = currentRunSeed()
        local data = root.nightOfTheCowards
        if type(data) ~= "table" or tonumber(data.runSeed) ~= seed then
            data = { runSeed = seed, c20Granted = {} }
            root.nightOfTheCowards = data
        end
        if type(data.c20Granted) ~= "table" then data.c20Granted = {} end
        return data
    end

    local function savePersistentData()
        if type(context.Save) == "function" then pcall(context.Save) end
    end

    local function grantTranscendenceOnce(player)
        if not player or collectibleCount(player) <= 0 or FLIGHT_ITEM_ID <= 0 then return false end
        local data = getPersistentData()
        local key = playerKey(player)
        if data.c20Granted[key] == true then return false end
        if type(player.AddCollectible) ~= "function" then
            debugLog("cannot grant c20: Player:AddCollectible is unavailable")
            return false
        end

        local ok, err = pcall(player.AddCollectible, player, FLIGHT_ITEM_ID, 0, false)
        if not ok then
            debugLog("c20 grant failed: " .. tostring(err))
            return false
        end
        data.c20Granted[key] = true
        savePersistentData()
        return true
    end

    return {
        currentRunSeed = currentRunSeed,
        getPersistentData = getPersistentData,
        savePersistentData = savePersistentData,
        grantTranscendenceOnce = grantTranscendenceOnce,
    }
end
