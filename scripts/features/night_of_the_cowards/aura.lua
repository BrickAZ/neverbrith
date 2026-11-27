-- Private night_of_the_cowards responsibility: aura. No registration until an installer is called.
return function(Neverbirth, deps)
    local runtime = deps.Runtime
    local EFFECT_ENTITY = deps.Config.EFFECT_ENTITY
    local HOST_ENTITY = deps.Config.HOST_ENTITY
    local AURA_VARIANT = deps.Config.AURA_VARIANT
    local AURA_SUBTYPE = deps.Config.AURA_SUBTYPE
    local NO_ENTITY_COLLISION = deps.Config.NO_ENTITY_COLLISION
    local NO_GRID_COLLISION = deps.Config.NO_GRID_COLLISION
    local AURA_VISUAL_SCALE = deps.Config.AURA_VISUAL_SCALE
    local AURA_VISUAL_OFFSET_Y = deps.Config.AURA_VISUAL_OFFSET_Y
    local AURA_DEPTH_OFFSET = deps.Config.AURA_DEPTH_OFFSET
    local AURA_PLAYBACK_SPEED = deps.Config.AURA_PLAYBACK_SPEED
    local AURA_DATA_KEY = deps.Config.AURA_DATA_KEY
    local AURA_OWNER_KEY = deps.Config.AURA_OWNER_KEY
    local TRANSFORMED_DATA_KEY = deps.Config.TRANSFORMED_DATA_KEY
    local zeroVector = deps.zeroVector
    local debugLog = deps.debugLog
    local makeVector = deps.makeVector
    local entityExists = deps.entityExists
    local isAuraEnemy = deps.isAuraEnemy
    local isNativeCursedDeathHead = deps.isNativeCursedDeathHead
    local isTransformableEnemy = deps.isTransformableEnemy
    local getData = deps.getData
    local stableHostVariant = deps.stableHostVariant
    local callbackInstallers = {}

    local function transformEnemy(npc)
        local data = getData(npc)
        if not data or data[TRANSFORMED_DATA_KEY] then return false end
        data[TRANSFORMED_DATA_KEY] = true
        if not isTransformableEnemy(npc) then return false end

        local champion = -1
        if type(npc.GetChampionColorIdx) == "function" then
            local ok, value = pcall(npc.GetChampionColorIdx, npc)
            if ok then champion = tonumber(value) or -1 end
        end
        local variant = stableHostVariant(npc)
        local ok, err = pcall(npc.Morph, npc, HOST_ENTITY, variant, 0, champion)
        if not ok then
            data[TRANSFORMED_DATA_KEY] = nil
            debugLog("enemy morph failed: " .. tostring(err))
            return false
        end
        return true
    end

    local function removeAura(effect)
        if not effect then return end
        local effectData = getData(effect)
        local owner = effectData and effectData[AURA_OWNER_KEY] or nil
        local ownerData = getData(owner)
        if ownerData and ownerData[AURA_DATA_KEY] == effect then
            ownerData[AURA_DATA_KEY] = nil
        end
        if effectData then effectData[AURA_OWNER_KEY] = nil end
        if entityExists(effect) and type(effect.Remove) == "function" then
            pcall(effect.Remove, effect)
        end
    end

    local function clearAuras()
        for _, effect in ipairs(runtime.auras) do removeAura(effect) end
        runtime.auras = {}
    end

    local function ensureAura(npc)
        if isNativeCursedDeathHead(npc) then return nil end
        if not isAuraEnemy(npc) then return nil end
        local npcData = getData(npc)
        if not npcData then return nil end
        local current = npcData[AURA_DATA_KEY]
        if entityExists(current) then return current end
        npcData[AURA_DATA_KEY] = nil

        if AURA_VARIANT <= 0 or not Isaac or type(Isaac.Spawn) ~= "function" or not npc.Position then
            return nil
        end
        local velocity = zeroVector()
        local ok, effect = pcall(Isaac.Spawn, EFFECT_ENTITY, AURA_VARIANT, AURA_SUBTYPE, npc.Position, velocity, npc)
        if not ok or not effect then return nil end

        effect.Parent = npc
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        effect.Velocity = velocity
        effect.SpriteScale = makeVector(AURA_VISUAL_SCALE, AURA_VISUAL_SCALE)
        effect.SpriteOffset = makeVector(0, AURA_VISUAL_OFFSET_Y)
        effect.DepthOffset = AURA_DEPTH_OFFSET

        -- Keep one ordinary (non-floor) Halo instance alive at the vanilla playback rate.
        -- Base Repentance has no Effect parent-follow method, so MC_POST_EFFECT_UPDATE
        -- moves this same instance without restarting its animation.
        if type(effect.GetSprite) == "function" then
            local spriteOk, sprite = pcall(effect.GetSprite, effect)
            if spriteOk and sprite then sprite.PlaybackSpeed = AURA_PLAYBACK_SPEED end
        end

        local effectData = getData(effect)
        if effectData then effectData[AURA_OWNER_KEY] = npc end
        npcData[AURA_DATA_KEY] = effect
        runtime.auras[#runtime.auras + 1] = effect
        return effect
    end

    local function npcUpdate(_, npc)
        if not runtime.active or not isAuraEnemy(npc) then return nil end
        transformEnemy(npc)
        ensureAura(npc)
        return nil
    end
    function callbackInstallers.npcUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate)
    end

    local function effectUpdate(_, effect)
        local data = getData(effect)
        local owner = data and data[AURA_OWNER_KEY] or nil
        if not owner then return nil end
        if not runtime.active or not isAuraEnemy(owner) then
            removeAura(effect)
            return nil
        end
        effect.Position = owner.Position
        effect.Velocity = zeroVector() or effect.Velocity
        return nil
    end
    function callbackInstallers.effectUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, effectUpdate, AURA_VARIANT)
    end

    return {
        transformEnemy = transformEnemy,
        removeAura = removeAura,
        clearAuras = clearAuras,
        ensureAura = ensureAura,
        npcUpdate = npcUpdate,
        effectUpdate = effectUpdate,
        Installers = callbackInstallers,
    }
end
