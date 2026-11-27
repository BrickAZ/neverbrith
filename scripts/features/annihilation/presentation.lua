-- Private presentation ownership for Annihilation.
return function(Neverbirth, deps)
    local context = deps.Context
    local EFFECT_ENTITY = deps.Config.EFFECT_ENTITY
    local NO_ENTITY_COLLISION = deps.Config.NO_ENTITY_COLLISION
    local NO_GRID_COLLISION = deps.Config.NO_GRID_COLLISION
    local SHOCKWAVE_VARIANT = deps.Config.SHOCKWAVE_VARIANT
    local SHOCKWAVE_ANM2 = deps.Config.SHOCKWAVE_ANM2
    local SHOCKWAVE_ANIMATION = deps.Config.SHOCKWAVE_ANIMATION
    local GROUND_DEPTH_OFFSET = deps.Config.GROUND_DEPTH_OFFSET
    local failOnce = deps.Queries.failOnce
    local zeroVector = deps.Queries.zeroVector
    local copyPosition = deps.Queries.copyPosition
    local entityExists = deps.Queries.entityExists

    local function removeEffect(effect)
        if entityExists(effect) and type(effect.Remove) == "function" then
            pcall(effect.Remove, effect)
        end
    end

    local function spawnEffect(variant, path, animation, position, spawner, depthOffset)
        if variant <= 0 or not position then return nil end
        local effect = nil
        if type(context.SpawnEffect) == "function" then
            local ok, value = pcall(context.SpawnEffect, variant, position, spawner)
            if ok then effect = value else failOnce("spawn", value) end
        elseif Isaac and type(Isaac.Spawn) == "function" then
            local ok, value = pcall(
                Isaac.Spawn,
                EFFECT_ENTITY,
                variant,
                0,
                position,
                zeroVector(),
                spawner
            )
            if ok and value then
                local converted, result = pcall(function() return value:ToEffect() end)
                if converted then effect = result else failOnce("ToEffect", result) end
                if converted and not result then failOnce("ToEffect", "returned nil") end
                if not effect then removeEffect(value) end
            elseif not ok then failOnce("spawn", value) end
        end
        if not effect then return nil end

        local configured, configureError = pcall(function()
        effect.Position = position
        effect.Velocity = zeroVector() or effect.Velocity
        effect.DepthOffset = depthOffset or 0
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        effect.Parent = spawner

        local sprite = effect:GetSprite()
        assert(sprite, "GetSprite returned nil")
            assert(sprite:Load(path, true) ~= false, "Load returned false")
            assert(sprite:Play(animation, true) ~= false, "Play returned false")
            if type(sprite.IsPlaying) == "function" then
                assert(sprite:IsPlaying(animation), "animation not playing: " .. animation)
            end
            sprite.Rotation = 0
            sprite.Scale = Vector(1, 1)
        end)
        if not configured then
            failOnce("visual:" .. tostring(path), configureError)
            removeEffect(effect)
            return nil
        end
        return effect
    end

    local function removeStateVisuals(state)
        if not state then return end
        removeEffect(state.aura)
        removeEffect(state.activation and state.activation.effect)
        for _, wave in ipairs(state.shockwaves or {}) do removeEffect(wave.effect) end
        state.aura = nil
        state.activation = nil
        state.shockwaves = {}
    end

    local function createShockwave(state)
        if not state or not state.player or not state.player.Position then return nil end
        local origin = copyPosition(state.player.Position)
        local effect = spawnEffect(
            SHOCKWAVE_VARIANT,
            SHOCKWAVE_ANM2,
            SHOCKWAVE_ANIMATION,
            origin,
            state.player,
            GROUND_DEPTH_OFFSET + 1
        )
        local wave = { origin = origin, effect = effect, age = 0, hit = {} }
        state.shockwaves[#state.shockwaves + 1] = wave
        return wave
    end

    return {
        removeEffect = removeEffect,
        spawnEffect = spawnEffect,
        removeStateVisuals = removeStateVisuals,
        createShockwave = createShockwave,
    }
end
