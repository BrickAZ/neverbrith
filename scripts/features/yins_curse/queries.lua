-- Private queries ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local context = deps.context
    local ITEM_ID = deps.State.ITEM_ID

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function toPlayer(entity)
        if not entity then
            return nil
        end
        if type(entity.ToPlayer) == "function" then
            local ok, player = pcall(entity.ToPlayer, entity)
            if ok and player then
                return player
            end
        end
        if type(entity.HasCollectible) == "function" then
            return entity
        end
        return nil
    end

    local function hasCollectible(player, itemId)
        if not player or type(player.HasCollectible) ~= "function" then
            return false
        end
        local ok, held = pcall(player.HasCollectible, player, itemId)
        return ok and held == true
    end

    local function collectibleCount(player)
        if not player or type(player.GetCollectibleNum) ~= "function" or ITEM_ID <= 0 then
            return 0
        end
        local ok, count = pcall(player.GetCollectibleNum, player, ITEM_ID, true)
        return ok and math.max(0, math.floor(tonumber(count) or 0)) or 0
    end

    local function getPlayers()
        if type(context.GetPlayers) ~= "function" then
            return {}
        end
        local ok, players = pcall(context.GetPlayers)
        return ok and type(players) == "table" and players or {}
    end

    return {
        playerKey = playerKey,
        toPlayer = toPlayer,
        hasCollectible = hasCollectible,
        collectibleCount = collectibleCount,
        getPlayers = getPlayers,
    }
end
