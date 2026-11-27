-- Private bombs responsibilities for bomb_suit; created once by its entry.
return function(mod, context, deps)
    local callbackInstallers = {}
    local data = deps.State.Data
    local OWNER_MARKER = deps.Config.OWNER_MARKER
    local stop = deps.State.stop
    local key = deps.State.key

    local function sourceOwner(entity, seen, depth)
        if not entity or (depth or 0) > 8 then return nil end
        seen = seen or {}; local k = key(entity)
        if seen[k] then return nil end; seen[k] = true
        local data = entity.GetData and entity:GetData()
        if data and data[OWNER_MARKER] then return data[OWNER_MARKER] end
        return sourceOwner(entity.Parent, seen, (depth or 0)+1)
            or sourceOwner(entity.SpawnerEntity, seen, (depth or 0)+1)
    end

    local function initOwned(_, entity)
        local owner = sourceOwner(entity)
        if owner and entity.GetData then entity:GetData()[OWNER_MARKER] = owner end
    end
    function callbackInstallers.initOwned(name)
        return mod:AddCallback(ModCallbacks[name], initOwned)
    end

    local function sweepBombScopes()
        local frame = Game():GetFrameCount()
        if data.scopeFrame ~= frame then
            -- A cancelled/removed bomb may not have a matching POST update.
            -- Never carry an open native-AI scope into another frame.
            data.bombScopes, data.scopeFrame = {}, frame
            for seed, candidate in pairs(data.pendingScatter) do
                if frame > candidate.frame + 2 then data.pendingScatter[seed] = nil end
            end
        end
    end

    local function preBomb(_, bomb)
        if not data.ready then return end
        sweepBombScopes()
        local candidate = data.pendingScatter[bomb.InitSeed]
        if candidate then
            data.pendingScatter[bomb.InitSeed] = nil
            -- Native Scatter children deliberately have no Parent and point
            -- straight to the player. Spawn identity alone is insufficient:
            -- confirm the native mini-bomb size and half-parent damage before
            -- adopting it. Hot Bombs flags are retained; Mega children do 92.5.
            if bomb.FrameCount <= 1 and bomb.Variant == BombVariant.BOMB_NORMAL
                and bomb.SubType == 0 and not bomb.IsFetus and bomb:GetScale() == 0.5
                and math.abs(bomb.ExplosionDamage - candidate.damage) < 0.001
                and key(bomb.SpawnerEntity) == candidate.owner
                and not bomb:HasTearFlags(TearFlags.TEAR_SCATTER_BOMB) then
                bomb:GetData()[OWNER_MARKER] = candidate.owner
            end
        end
        local owner = sourceOwner(bomb)
        -- Every bomb contributes a stack entry: unrelated nested Bomb:Update()
        -- calls are barriers and cannot borrow the enclosing owned root.
        data.bombScopes[#data.bombScopes+1] = {bomb=bomb, key=key(bomb),
            owner=owner and bomb:HasTearFlags(TearFlags.TEAR_SCATTER_BOMB) and owner or nil,
            damage=bomb.ExplosionDamage}
    end
    function callbackInstallers.preBomb()
        return mod:AddPriorityCallback(ModCallbacks.MC_PRE_BOMB_UPDATE, 20000, preBomb)
    end

    local function postBomb(_, bomb)
        for i=#data.bombScopes,1,-1 do
            if data.bombScopes[i].key == key(bomb) then
                for j=#data.bombScopes,i,-1 do data.bombScopes[j] = nil end
                return
            end
        end
    end
    function callbackInstallers.postBomb()
        return mod:AddPriorityCallback(ModCallbacks.MC_POST_BOMB_UPDATE, -20000, postBomb)
    end

    local function preSpawn(_, kind, variant, subtype, position, velocity, spawner, seed)
        if not data.ready or kind ~= EntityType.ENTITY_BOMBDROP then return end
        sweepBombScopes()
        local scope = data.bombScopes[#data.bombScopes]
        if scope and scope.owner and scope.bomb:GetExplosionCountdown() <= 0
            and variant == BombVariant.BOMB_NORMAL and subtype == 0
            and key(spawner) == scope.owner then
            data.pendingScatter[seed] = {owner=scope.owner, damage=scope.damage/2, frame=data.scopeFrame}
        end
    end
    function callbackInstallers.preSpawn()
        return mod:AddCallback(ModCallbacks.MC_PRE_ENTITY_SPAWN, preSpawn)
    end

    local function detonate(k, state)
        -- Keep the armed damage guard until native Update returns. Descendants
        -- get narrow ownership marks, so late cluster/tear/effect damage remains
        -- self-safe without adding general invulnerability after the three seconds.
        local ok, err = pcall(function()
            local player = state.player
            local entity = Isaac.Spawn(EntityType.ENTITY_BOMBDROP, BombVariant.BOMB_NORMAL,
                0, player.Position, Vector(0, 0), player)
            local bomb = entity and entity:ToBomb()
            if not bomb then error("normal bomb spawn returned no bomb") end
            bomb:GetData()[OWNER_MARKER] = k
            -- GetBombFlags(false) supplies guaranteed ordinary bomb upgrades,
            -- rather than the random fetus subset. Do not convert BitSet128
            -- to a Lua integer. The engine executes the bomb's special effects.
            bomb:AddTearFlags(player:GetBombFlags(false))
            local mega = player:HasCollectible(CollectibleType.COLLECTIBLE_MR_MEGA)
                or player:GetEffects():HasCollectibleEffect(CollectibleType.COLLECTIBLE_MR_MEGA)
            bomb.ExplosionDamage = mega and 185 or 100
            -- Native bombs decrement a positive countdown to trigger explosion;
            -- setting zero alone leaves the normal carrier unexploded.
            bomb:SetExplosionCountdown(1)
            bomb:Update()
        end)
        stop(k)
        if not ok and context.DebugLog then context.DebugLog("[Bomb Suit] " .. tostring(err)) end
    end

    function callbackInstallers.resetBombScopes()
        mod:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE, -20000, function() data.bombScopes = {} end)
    end

    return {
        Installers = callbackInstallers,
        sourceOwner = sourceOwner,
        initOwned = initOwned,
        sweepBombScopes = sweepBombScopes,
        preBomb = preBomb,
        postBomb = postBomb,
        preSpawn = preSpawn,
        detonate = detonate,
    }
end
