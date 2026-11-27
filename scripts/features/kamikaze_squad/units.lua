-- Private kamikaze_squad responsibility: units. No registration until an installer is called.
return function(Neverbirth, deps)
    local context = deps.Context
    local runtime = deps.Runtime
    local MAX_LIVE_PER_OWNER = deps.Config.MAX_LIVE_PER_OWNER
    local MULLIBOOM_EXPLOSION_DAMAGE = deps.Config.MULLIBOOM_EXPLOSION_DAMAGE
    local EXPLOSION_RADIUS_MULTIPLIER = deps.Config.EXPLOSION_RADIUS_MULTIPLIER
    local OWNED_KEY = deps.Config.OWNED_KEY
    local OWNER_KEY = deps.Config.OWNER_KEY
    local OWNER_ID_KEY = deps.Config.OWNER_ID_KEY
    local TARGET_KEY = deps.Config.TARGET_KEY
    local DETONATED_KEY = deps.Config.DETONATED_KEY
    local FAILED_KEY = deps.Config.FAILED_KEY
    local diagnostic = deps.diagnostic
    local entityKey = deps.entityKey
    local entityExists = deps.entityExists
    local isDead = deps.isDead
    local isValidHostile = deps.isValidHostile
    local getFreeNearPosition = deps.getFreeNearPosition
    local spawnMulliboom = deps.spawnMulliboom
    local nearestHostile = deps.nearestHostile

    local function getHolderState(player, create)
        local key = entityKey(player)
        if not key then return nil end
        local state = runtime.holders[key]
        if not state and create then
            state = { player = player, key = key, timer = 0, units = {} }
            runtime.holders[key] = state
            diagnostic("owner recognized " .. key)
        end
        if state then state.player = player end
        return state
    end

    local function isOwnedUnit(unit, owner)
        if not entityExists(unit) or isDead(unit) then return false end
        local data = unit.GetData and unit:GetData() or nil
        if not data or not data[OWNED_KEY] or data[DETONATED_KEY] then return false end
        if owner and data[OWNER_ID_KEY] ~= entityKey(owner) then return false end
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
                if entityKey(state.units[index]) == entityKey(unit) then table.remove(state.units, index) end
            end
        end
    end

    local function prepareExplosion(position, owner)
        if context.TriggerExplosion then
            return function()
                context.TriggerExplosion(position, MULLIBOOM_EXPLOSION_DAMAGE, EXPLOSION_RADIUS_MULTIPLIER, owner)
            end
        end

        local game = Game and Game() or nil
        if not game or type(game.BombExplosionEffects) ~= "function" then error("explosion API unavailable") end
        if not entityExists(owner) or not entityKey(owner) or not owner.ToPlayer or not owner:ToPlayer() then
            error("explosion source unavailable")
        end
        -- Construct through the engine API before Remove; do not fabricate Lua Vector/Color tables.
        local nativePosition = Vector(position.X, position.Y)
        local nativeColor = Color(1, 1, 1, 1)
        if nativePosition == nil or nativeColor == nil then error("explosion native values unavailable") end
        return function() game:BombExplosionEffects(
            nativePosition,
            MULLIBOOM_EXPLOSION_DAMAGE,
            (TearFlags and TearFlags.TEAR_NORMAL) or 0,
            nativeColor,
            owner,
            EXPLOSION_RADIUS_MULTIPLIER,
            true,
            true,
            (DamageFlag and DamageFlag.DAMAGE_EXPLOSION) or 0
        ) end
    end

    local function detonate(unit)
        if not isOwnedUnit(unit) then return false end
        local data = unit:GetData()
        if data[FAILED_KEY] then return false end
        local ownerState = runtime.holders[data[OWNER_ID_KEY]]
        local owner = ownerState and ownerState.player or data[OWNER_KEY]
        local ready, explode = pcall(prepareExplosion, unit.Position, owner)
        if not ready or type(explode) ~= "function" or type(unit.Remove) ~= "function" then
            data[FAILED_KEY] = true
            diagnostic("explosion preflight failed; unit retained, no retry", true)
            return false
        end
        data[DETONATED_KEY] = true
        removeUnitReference(unit)
        -- Remove instead of Kill/TakeDamage so the hard-coded Mulliboom death explosion cannot fire as a second hit.
        if unit.Remove then unit:Remove() end
        local ok = pcall(explode)
        if not ok then diagnostic("explosion call failed after removal; no retry", true) end
        return ok
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
        diagnostic("owner cleanup " .. tostring(player))
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

    local function spawnForHolder(state)
        diagnostic("spawn attempt " .. state.key)
        pruneUnits(state)
        if #state.units >= MAX_LIVE_PER_OWNER then return nil end
        local owner = state.player
        local unit = spawnMulliboom(getFreeNearPosition(owner.Position), owner)
        if not unit then return nil end

        local data = unit:GetData()
        data[OWNED_KEY] = true
        data[OWNER_KEY] = owner
        data[OWNER_ID_KEY] = state.key
        data[TARGET_KEY] = nil
        data[DETONATED_KEY] = false
        if unit.AddCharmed then unit:AddCharmed(EntityRef(owner), -1) end
        if unit.AddEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
            unit:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
        end
        state.units[#state.units + 1] = unit
        return unit
    end

    local function updateOwnedUnit(unit)
        if not isOwnedUnit(unit) then return end
        local data = unit:GetData()
        if data[FAILED_KEY] then return end
        local target = data[TARGET_KEY]
        if not isValidHostile(target) then target = nearestHostile(unit.Position) end
        if not target then
            detonate(unit)
            return
        end

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

    return {
        getHolderState = getHolderState,
        isOwnedUnit = isOwnedUnit,
        pruneUnits = pruneUnits,
        removeUnitReference = removeUnitReference,
        prepareExplosion = prepareExplosion,
        detonate = detonate,
        silentlyRemoveUnit = silentlyRemoveUnit,
        clearHolder = clearHolder,
        clearRuntime = clearRuntime,
        detonateAllOwned = detonateAllOwned,
        spawnForHolder = spawnForHolder,
        updateOwnedUnit = updateOwnedUnit,
    }
end
