-- Private engine access, identity keys and deterministic selection. Preserve legacy fallback/error semantics.
return function(Neverbirth, context, deps)
    local ITEM_ID = deps.ITEM_ID
    local runtime = deps.runtime

    local function debugLog(message)
        if context.DebugLog then context.DebugLog(message) end
    end

    local function diagnosticOnce(key, message)
        if runtime.diagnostics[key] then return end
        runtime.diagnostics[key] = true
        debugLog("[neverbirth][memory-disorder] " .. message)
    end

    local function safeCall(object, methodName, ...)
        local method = object and object[methodName]
        if type(method) ~= "function" then return nil, false end
        local ok, result = pcall(method, object, ...)
        if not ok then return nil, false end
        return result, true
    end

    local function numberCall(object, methodName, ...)
        local value = safeCall(object, methodName, ...)
        return tonumber(value) or 0
    end

    local function copyTable(source)
        local result = {}
        for key, value in pairs(source or {}) do
            if type(value) == "table" then
                result[key] = copyTable(value)
            else
                result[key] = value
            end
        end
        return result
    end

    local function playerType(name, fallback)
        if PlayerType and PlayerType[name] ~= nil then return PlayerType[name] end
        return fallback
    end

    local function currentRunSeed()
        if context.GetCurrentRunSeed then return tostring(context.GetCurrentRunSeed()) end
        if Game then
            local ok, game = pcall(Game)
            if ok and game and game.GetSeeds then
                local seeds = game:GetSeeds()
                if seeds and seeds.GetStartSeed then return tostring(seeds:GetStartSeed()) end
            end
        end
        return "0"
    end

    local function playerKey(player)
        local initSeed = player and player.InitSeed or 0
        local controller = player and player.ControllerIndex or 0
        return tostring(initSeed) .. ":" .. tostring(controller)
    end

    local function runtimePlayerKey(player)
        if not player then return nil end
        -- Engine calls can wrap the same native player in different Lua userdata.
        -- Keep pointer identity only in runtime state, never in the save data.
        if type(GetPtrHash) == "function" then
            return tostring(GetPtrHash(player)) .. ":" .. tostring(player.InitSeed or 0)
        end
        return playerKey(player)
    end

    local function getPlayers()
        if context.GetPlayers then return context.GetPlayers() or {} end
        local result = {}
        if Game then
            local ok, game = pcall(Game)
            if ok and game and game.GetNumPlayers then
                for index = 0, game:GetNumPlayers() - 1 do
                    result[#result + 1] = Isaac.GetPlayer(index)
                end
            end
        end
        return result
    end

    local function playerExists(player)
        local value, ok = safeCall(player, "Exists")
        return not ok or value ~= false
    end

    local function playerIsDead(player)
        local value, ok = safeCall(player, "IsDead")
        return ok and value == true
    end

    local function getPlayerType(player)
        local value = safeCall(player, "GetPlayerType")
        return value or playerType("PLAYER_ISAAC", 0)
    end

    local function getCollectibleCount(player, itemId)
        local value = safeCall(player, "GetCollectibleNum", itemId, true)
        if value == nil then value = safeCall(player, "GetCollectibleNum", itemId) end
        return tonumber(value) or 0
    end

    local function pairMain(player)
        local kind = getPlayerType(player)
        local expected = ({ [20] = 19, [40] = 35, [17] = 16 })[kind]
        if not expected then return player end
        for _, method in ipairs({ "GetMainTwin", "GetOtherTwin", "GetSubPlayer" }) do
            local candidate = safeCall(player, method)
            if candidate and playerExists(candidate) and getPlayerType(candidate) == expected
                and candidate.ControllerIndex == player.ControllerIndex then return candidate end
        end
        return player
    end

    local function pairPartner(player)
        local expected = ({ [19] = 20, [35] = 40, [16] = 17 })[getPlayerType(player)]
        if not expected then return nil end
        for _, method in ipairs({ "GetOtherTwin", "GetSubPlayer" }) do
            local other = safeCall(player, method)
            if other and playerExists(other) and getPlayerType(other) == expected
                and other.ControllerIndex == player.ControllerIndex then return other end
        end
        return nil
    end

    local function hasItem(player)
        if not player or ITEM_ID <= 0 then return false end
        local value, ok = safeCall(player, "HasCollectible", ITEM_ID)
        if ok and value == true then return true end
        if getCollectibleCount(player, ITEM_ID) > 0 then return true end
        local other = pairPartner(player)
        return other ~= nil and getCollectibleCount(other, ITEM_ID) > 0
    end

    local function seedHash(text)
        local value = 2166136261
        text = tostring(text or "")
        for index = 1, #text do
            value = (value * 16777619 + string.byte(text, index)) % 2147483647
        end
        return math.max(1, value)
    end

    local function randomIndex(count, player, salt)
        if count <= 1 then return 1 end
        local seed = seedHash(currentRunSeed() .. ":" .. playerKey(player) .. ":" .. tostring(salt or 0))
        local ok, value = pcall(function()
            local rng = RNG()
            rng:SetSeed(seed, 35)
            return rng:RandomInt(count) + 1
        end)
        if ok and type(value) == "number" and value >= 1 and value <= count then return value end
        -- Only used by the isolated Lua test harness or if the engine RNG
        -- constructor is unavailable. The fallback remains seed-deterministic.
        return (seed % count) + 1
    end

    return {
        diagnosticOnce = diagnosticOnce,
        safeCall = safeCall,
        numberCall = numberCall,
        copyTable = copyTable,
        playerType = playerType,
        currentRunSeed = currentRunSeed,
        playerKey = playerKey,
        runtimePlayerKey = runtimePlayerKey,
        getPlayers = getPlayers,
        playerExists = playerExists,
        playerIsDead = playerIsDead,
        getPlayerType = getPlayerType,
        getCollectibleCount = getCollectibleCount,
        pairMain = pairMain,
        pairPartner = pairPartner,
        hasItem = hasItem,
        seedHash = seedHash,
        randomIndex = randomIndex,
    }
end
