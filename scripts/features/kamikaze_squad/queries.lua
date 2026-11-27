-- Private kamikaze_squad responsibility: queries. No registration until an installer is called.
return function(Neverbirth, deps)
    local context = deps.Context
    local ITEM_ID = deps.Config.ITEM_ID
    local MULLIBOOM_TYPE = deps.Config.MULLIBOOM_TYPE
    local MULLIBOOM_VARIANT = deps.Config.MULLIBOOM_VARIANT
    local OWNED_KEY = deps.Config.OWNED_KEY
    local diagnosticsSeen = {}

    local function diagnostic(message, once)
        if (context.DiagnosticsEnabled ~= true and Neverbirth.KamikazeSquadDiagnosticsEnabled ~= true)
            or type(context.DebugLog) ~= "function" then return end
        if once and diagnosticsSeen[message] then return end
        if once then diagnosticsSeen[message] = true end
        context.DebugLog("Kamikaze Squad: " .. message)
    end

    local function entityKey(entity)
        if not entity or type(GetPtrHash) ~= "function" then return nil end
        local ok, hash = pcall(GetPtrHash, entity)
        if not ok or type(hash) ~= "number" then return nil end
        return tostring(hash) .. ":" .. tostring(entity.InitSeed)
    end

    local function entityExists(entity)
        if entity == nil then return false end
        if entity.Exists and not entity:Exists() then return false end
        return true
    end

    local function isDead(entity)
        return entity.IsDead and entity:IsDead()
    end

    local function hasFlag(entity, flag)
        return flag ~= nil and entity.HasEntityFlags and entity:HasEntityFlags(flag)
    end

    local function isValidHostile(entity)
        if not entityExists(entity) or isDead(entity) then return false end
        local npc = entity.ToNPC and entity:ToNPC() or nil
        if not npc then return false end
        local data = npc.GetData and npc:GetData() or nil
        if data and data[OWNED_KEY] then return false end
        if hasFlag(npc, EntityFlag and EntityFlag.FLAG_FRIENDLY) then return false end
        if hasFlag(npc, EntityFlag and EntityFlag.FLAG_CHARM) then return false end
        if npc.IsActiveEnemy and not npc:IsActiveEnemy(false) then return false end
        if npc.IsVulnerableEnemy and not npc:IsVulnerableEnemy() then return false end
        return true
    end

    local function getRoomEntities()
        if context.GetRoomEntities then return context.GetRoomEntities() or {} end
        if Isaac and Isaac.GetRoomEntities then return Isaac.GetRoomEntities() end
        return {}
    end

    local function getPlayers()
        if context.GetPlayers then return context.GetPlayers() or {} end
        local result = {}
        local game = Game and Game() or nil
        local count = game and game.GetNumPlayers and game:GetNumPlayers() or 0
        for index = 0, count - 1 do result[#result + 1] = Isaac.GetPlayer(index) end
        return result
    end

    local function hasItem(player)
        if ITEM_ID == nil or ITEM_ID < 0 or not player then return false end
        if player.GetCollectibleNum then return player:GetCollectibleNum(ITEM_ID) > 0 end
        return player.HasCollectible and player:HasCollectible(ITEM_ID) or false
    end

    local function isPlayerUsable(player)
        return entityExists(player) and not isDead(player)
    end

    local function getFreeNearPosition(position)
        if context.GetFreeNearPosition then return context.GetFreeNearPosition(position) end
        if Isaac and Isaac.GetFreeNearPosition then return Isaac.GetFreeNearPosition(position, 24) end
        return position
    end

    local function spawnMulliboom(position, owner)
        if context.SpawnMulliboom then return context.SpawnMulliboom(position, owner) end
        if not Isaac or not Isaac.Spawn then return nil end
        local entity = Isaac.Spawn(MULLIBOOM_TYPE, MULLIBOOM_VARIANT, 0, position, Vector.Zero, owner)
        return entity and entity.ToNPC and entity:ToNPC() or nil
    end

    diagnostic("initialized", true)

    return {
        diagnostic = diagnostic,
        entityKey = entityKey,
        entityExists = entityExists,
        isDead = isDead,
        hasFlag = hasFlag,
        isValidHostile = isValidHostile,
        getRoomEntities = getRoomEntities,
        getPlayers = getPlayers,
        hasItem = hasItem,
        isPlayerUsable = isPlayerUsable,
        getFreeNearPosition = getFreeNearPosition,
        spawnMulliboom = spawnMulliboom,
    }
end
