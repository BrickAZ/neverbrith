-- Private queries ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local GetPlayers = deps.GetPlayers
    local IsValidItemId = deps.IsValidItemId
    local ITEM_ID = deps.State.ITEM_ID
    local World = include("scripts.runtime.world_queries")

    local function safeCall(target, methodName, ...)
        if not target or type(target[methodName]) ~= "function" then return nil, false end
        local ok, result = pcall(target[methodName], target, ...)
        if not ok then return nil, false end
        return result, true
    end

    local function dataOf(entity)
        local data, ok = safeCall(entity, "GetData")
        return ok and data or nil
    end

    local function itemCount(player)
        if not player or not IsValidItemId(ITEM_ID) then return 0 end
        local count, ok = safeCall(player, "GetCollectibleNum", ITEM_ID)
        if ok and type(count) == "number" then return math.max(0, count) end
        local held, heldOk = safeCall(player, "HasCollectible", ITEM_ID)
        return heldOk and held == true and 1 or 0
    end

    local function anyHolder()
        for _, player in ipairs(GetPlayers()) do
            if itemCount(player) > 0 then return true end
        end
        return false
    end

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function currentGame()
        if type(Game) ~= "function" then return nil end
        return World.TryGame() or nil
    end

    local function currentRoom()
        local game = currentGame()
        local room, ok = safeCall(game, "GetRoom")
        return ok and room or nil
    end

    local function toNpc(entity)
        if not entity or type(entity.ToNPC) ~= "function" then return nil end
        local ok, npc = pcall(entity.ToNPC, entity)
        return ok and npc or nil
    end

    local function present(entity)
        if not entity then return false end
        local exists, ok = safeCall(entity, "Exists")
        return not ok or exists == true
    end

    local function hasFlag(entity, flag)
        if not entity or not flag or flag == 0 then return false end
        local result, ok = safeCall(entity, "HasEntityFlags", flag)
        return ok and result == true
    end

    return {
        safeCall = safeCall,
        dataOf = dataOf,
        itemCount = itemCount,
        anyHolder = anyHolder,
        playerKey = playerKey,
        currentGame = currentGame,
        currentRoom = currentRoom,
        toNpc = toNpc,
        present = present,
        hasFlag = hasFlag,
    }
end
