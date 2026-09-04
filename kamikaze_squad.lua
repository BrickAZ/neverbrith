local function initializeKamikazeSquad(Neverbirth, context)
    context = context or {}

    local ITEM_ID = context.ItemId or -1
    local SPAWN_INTERVAL = 90
    local MAX_LIVE_PER_OWNER = 2
    -- Verified against the installed vanilla entities2.xml: Mulliboom is Mulligan type 16, variant 2.
    local MULLIBOOM_TYPE = (EntityType and EntityType.ENTITY_MULLIGAN) or 16
    local MULLIBOOM_VARIANT = 2
    -- Vanilla Mullibooms use the standard 40-damage enemy-bomb explosion.
    local MULLIBOOM_EXPLOSION_DAMAGE = 40
    local EXPLOSION_RADIUS_MULTIPLIER = 2

    local OWNED_KEY = "NeverbirthKamikazeSquadOwned"
    local OWNER_KEY = "NeverbirthKamikazeSquadOwner"
    local TARGET_KEY = "NeverbirthKamikazeSquadTarget"
    local DETONATED_KEY = "NeverbirthKamikazeSquadDetonated"

    local runtime = {
        holders = {},
        hostiles = {},
        hostileSet = {},
        roomSeeded = false,
    }

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

    local function trackEnemy(entity)
        if not isValidHostile(entity) or runtime.hostileSet[entity] then return false end
        runtime.hostileSet[entity] = true
        runtime.hostiles[#runtime.hostiles + 1] = entity
        return true
    end

    local function removeTrackedEnemy(entity)
        if not runtime.hostileSet[entity] then return end
        runtime.hostileSet[entity] = nil
        for index = #runtime.hostiles, 1, -1 do
            if runtime.hostiles[index] == entity then
                table.remove(runtime.hostiles, index)
                break
            end
        end
    end

    local function pruneHostiles()
        for index = #runtime.hostiles, 1, -1 do
            local entity = runtime.hostiles[index]
            if not isValidHostile(entity) then
                runtime.hostileSet[entity] = nil
                table.remove(runtime.hostiles, index)
            end
        end
    end

    local function getRoomEntities()
        if context.GetRoomEntities then return context.GetRoomEntities() or {} end
        if Isaac and Isaac.GetRoomEntities then return Isaac.GetRoomEntities() end
        return {}
    end

    local function seedRoomHostiles()
        if runtime.roomSeeded then return end
        runtime.roomSeeded = true
        for _, entity in ipairs(getRoomEntities()) do trackEnemy(entity) end
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

    local function getHolderState(player, create)
        local state = runtime.holders[player]
        if not state and create then
            state = { player = player, timer = 0, units = {} }
            runtime.holders[player] = state
        end
        return state
    end

    local function isOwnedUnit(unit, owner)
        if not entityExists(unit) or isDead(unit) then return false end
        local data = unit.GetData and unit:GetData() or nil
        if not data or not data[OWNED_KEY] or data[DETONATED_KEY] then return false end
        if owner and data[OWNER_KEY] ~= owner then return false end
        return true
    end

    local function pruneUnits(state)
        for index = #state.units, 1, -1 do
            if not isOwnedUnit(state.units[index], state.player) then
                table.remove(state.units, index)
            end
        end
    end

    local function removeUnitReference(unit)
        for _, state in pairs(runtime.holders) do
            for index = #state.units, 1, -1 do
                if state.units[index] == unit then table.remove(state.units, index) end
            end
        end
    end

    local function triggerExplosion(position, owner)
        if context.TriggerExplosion then
            context.TriggerExplosion(position, MULLIBOOM_EXPLOSION_DAMAGE, EXPLOSION_RADIUS_MULTIPLIER, owner)
            return
        end

        local game = Game and Game() or nil
        if not game or not game.BombExplosionEffects then return end
        game:BombExplosionEffects(
            position,
            MULLIBOOM_EXPLOSION_DAMAGE,
            (TearFlags and TearFlags.TEAR_NORMAL) or 0,
            (Color and Color.Default) or nil,
            owner,
            EXPLOSION_RADIUS_MULTIPLIER,
            true,
            true,
            (DamageFlag and DamageFlag.DAMAGE_EXPLOSION) or 0
        )
    end

    local function detonate(unit)
        if not isOwnedUnit(unit) then return false end
        local data = unit:GetData()
        data[DETONATED_KEY] = true
        local owner = data[OWNER_KEY]
        local position = unit.Position
        removeUnitReference(unit)
        -- Remove instead of Kill/TakeDamage so the hard-coded Mulliboom death explosion cannot fire as a second hit.
        if unit.Remove then unit:Remove() end
        triggerExplosion(position, owner)
        return true
    end

    local function silentlyRemoveUnit(unit)
        if not entityExists(unit) then return end
        local data = unit.GetData and unit:GetData() or nil
        if data and data[OWNED_KEY] then data[DETONATED_KEY] = true end
        if unit.Remove then unit:Remove() end
    end

    local function clearHolder(player)
        local state = runtime.holders[player]
        if not state then return end
        for index = #state.units, 1, -1 do silentlyRemoveUnit(state.units[index]) end
        runtime.holders[player] = nil
    end

    local function clearRuntime()
        local players = {}
        for player in pairs(runtime.holders) do players[#players + 1] = player end
        for _, player in ipairs(players) do clearHolder(player) end
        runtime.holders = {}
        runtime.hostiles = {}
        runtime.hostileSet = {}
        runtime.roomSeeded = false
    end

    local function detonateAllOwned()
        local units = {}
        for _, state in pairs(runtime.holders) do
            pruneUnits(state)
            for _, unit in ipairs(state.units) do units[#units + 1] = unit end
        end
        for _, unit in ipairs(units) do detonate(unit) end
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

    local function spawnForHolder(state)
        pruneUnits(state)
        if #state.units >= MAX_LIVE_PER_OWNER then return nil end
        local owner = state.player
        local unit = spawnMulliboom(getFreeNearPosition(owner.Position), owner)
        if not unit then return nil end

        local data = unit:GetData()
        data[OWNED_KEY] = true
        data[OWNER_KEY] = owner
        data[TARGET_KEY] = nil
        data[DETONATED_KEY] = false
        if unit.AddCharmed then unit:AddCharmed(EntityRef(owner), -1) end
        if unit.AddEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
            unit:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
        end
        state.units[#state.units + 1] = unit
        return unit
    end

    local function nearestHostile(position)
        pruneHostiles()
        local nearest = nil
        local nearestDistance = math.huge
        for _, enemy in ipairs(runtime.hostiles) do
            local delta = enemy.Position - position
            local distance = delta.LengthSquared and delta:LengthSquared() or math.huge
            if distance < nearestDistance then
                nearest = enemy
                nearestDistance = distance
            end
        end
        return nearest
    end

    local function updateOwnedUnit(unit)
        if not isOwnedUnit(unit) then return end
        local target = nearestHostile(unit.Position)
        if not target then
            detonate(unit)
            return
        end

        local data = unit:GetData()
        data[TARGET_KEY] = target
        unit.Target = target
        if unit.Pathfinder and unit.Pathfinder.FindGridPath then
            unit.Pathfinder:FindGridPath(target.Position, 1, 0, true)
        end

        local unitSize = unit.Size or 0
        local targetSize = target.Size or 0
        local contactDistance = unitSize + targetSize
        local delta = target.Position - unit.Position
        if delta.LengthSquared and delta:LengthSquared() <= contactDistance * contactDistance then
            detonate(unit)
        end
    end

    local function postUpdate()
        local players = getPlayers()
        local seenPlayers = {}
        local hasHolder = false
        for _, player in ipairs(players) do
            seenPlayers[player] = true
            if isPlayerUsable(player) and hasItem(player) then
                hasHolder = true
                getHolderState(player, true)
            else
                clearHolder(player)
            end
        end

        local stalePlayers = {}
        for player in pairs(runtime.holders) do
            if not seenPlayers[player] then stalePlayers[#stalePlayers + 1] = player end
        end
        for _, player in ipairs(stalePlayers) do clearHolder(player) end
        if not hasHolder then
            runtime.hostiles = {}
            runtime.hostileSet = {}
            runtime.roomSeeded = false
            return
        end

        seedRoomHostiles()
        pruneHostiles()
        if #runtime.hostiles == 0 then
            detonateAllOwned()
            return
        end

        for _, state in pairs(runtime.holders) do
            pruneUnits(state)
            if #state.units < MAX_LIVE_PER_OWNER then
                state.timer = state.timer + 1
                if state.timer >= SPAWN_INTERVAL then
                    state.timer = 0
                    spawnForHolder(state)
                end
            end
        end
    end

    local function npcUpdate(_, npc)
        local data = npc.GetData and npc:GetData() or nil
        if data and data[OWNED_KEY] then
            updateOwnedUnit(npc)
        elseif next(runtime.holders) ~= nil and not runtime.hostileSet[npc] then
            trackEnemy(npc)
        end
    end

    local function npcInit(_, npc)
        if next(runtime.holders) ~= nil then trackEnemy(npc) end
    end

    local function npcDeath(_, npc)
        removeTrackedEnemy(npc)
        local data = npc.GetData and npc:GetData() or nil
        if data and data[OWNED_KEY] then removeUnitReference(npc) end
    end

    local function entityRemove(_, entity)
        removeTrackedEnemy(entity)
        local data = entity.GetData and entity:GetData() or nil
        if data and data[OWNED_KEY] then removeUnitReference(entity) end
    end

    local function roomCleared()
        runtime.hostiles = {}
        runtime.hostileSet = {}
        detonateAllOwned()
    end

    local function newRoom() clearRuntime() end
    local function newLevel() clearRuntime() end
    local function gameStarted() clearRuntime() end
    local function preGameExit() clearRuntime() end

    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    if ModCallbacks.MC_NPC_UPDATE then Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate) end
    if ModCallbacks.MC_POST_NPC_INIT then Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit) end
    if ModCallbacks.MC_POST_NPC_DEATH then Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, npcDeath) end
    if ModCallbacks.MC_POST_ENTITY_REMOVE then Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, entityRemove) end
    if ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then Neverbirth:AddCallback(ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD, roomCleared) end
    if ModCallbacks.MC_POST_NEW_ROOM then Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom) end
    if ModCallbacks.MC_POST_NEW_LEVEL then Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel) end
    if ModCallbacks.MC_POST_GAME_STARTED then Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted) end
    if ModCallbacks.MC_PRE_GAME_EXIT then Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit) end

    return {
        GetState = function(player) return runtime.holders[player] end,
        GetLiveCount = function(player)
            local state = runtime.holders[player]
            if not state then return 0 end
            pruneUnits(state)
            return #state.units
        end,
        TrackEnemy = trackEnemy,
        IsValidHostile = isValidHostile,
        Detonate = detonate,
        Constants = {
            SpawnInterval = SPAWN_INTERVAL,
            MaxLivePerOwner = MAX_LIVE_PER_OWNER,
            MulliboomType = MULLIBOOM_TYPE,
            MulliboomVariant = MULLIBOOM_VARIANT,
            ExplosionDamage = MULLIBOOM_EXPLOSION_DAMAGE,
            ExplosionRadiusMultiplier = EXPLOSION_RADIUS_MULTIPLIER,
        },
    }
end

return initializeKamikazeSquad
