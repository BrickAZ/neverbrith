-- Private effects responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local DOG_VARIANT = deps.DOG_VARIANT
    local EFFECT_ENTITY = deps.EFFECT_ENTITY
    local NO_ENTITY_COLLISION = deps.NO_ENTITY_COLLISION
    local NO_GRID_COLLISION = deps.NO_GRID_COLLISION
    local Constants = deps.Constants
    local newVector = deps.Queries.newVector
    local vectorX = deps.Queries.vectorX
    local vectorY = deps.Queries.vectorY
    local vectorAdd = deps.Queries.vectorAdd
    local vectorSubtract = deps.Queries.vectorSubtract
    local vectorScale = deps.Queries.vectorScale
    local vectorLengthSquared = deps.Queries.vectorLengthSquared
    local entityExists = deps.Queries.entityExists
    local playerKey = deps.Queries.playerKey
    local getPlayerRuntime = deps.State.getPlayerRuntime

    local function removeEntity(entity)
        if entityExists(entity) and type(entity.Remove) == "function" then
            pcall(entity.Remove, entity)
        end
    end

    local function getSprite(entity)
        if entity and type(entity.GetSprite) == "function" then
            local ok, sprite = pcall(entity.GetSprite, entity)
            if ok then
                return sprite
            end
        end
        return nil
    end

    local function setEntityVisualScale(entity, scale)
        local sprite = getSprite(entity)
        if not sprite then
            return false
        end
        return pcall(function()
            sprite.Scale = newVector(scale, scale)
        end)
    end

    local function makeEntityRef(entity)
        if EntityRef ~= nil then
            local ok, source = pcall(function()
                return EntityRef(entity)
            end)
            if ok and source then
                return source
            end
        end
        return entity
    end

    local function dealEnemyDamage(enemy, amount, owner)
        if not enemy or type(enemy.TakeDamage) ~= "function" then
            return false, nil
        end
        local source = makeEntityRef(owner)
        local ok, accepted = pcall(enemy.TakeDamage, enemy, amount, 0, source, 0)
        return ok and accepted ~= false, source
    end

    local function directionalAnimationName(prefix, direction)
        local x = vectorX(direction)
        local y = vectorY(direction)
        if math.abs(x) > math.abs(y) then
            return tostring(prefix) .. "Horizontal", x < 0
        elseif y < 0 then
            return tostring(prefix) .. "Up", false
        end
        return tostring(prefix) .. "Down", false
    end

    local function playDirectionalAnimation(entity, prefix, direction)
        local sprite = getSprite(entity)
        if not sprite then
            return nil
        end
        local animation, flip = directionalAnimationName(prefix, direction)
        sprite.FlipX = flip
        local playing = false
        if type(sprite.IsPlaying) == "function" then
            local ok, value = pcall(sprite.IsPlaying, sprite, animation)
            playing = ok and value == true
        end
        if not playing and type(sprite.Play) == "function" then
            pcall(sprite.Play, sprite, animation, false)
        end
        return animation
    end

    local function spriteEventTriggered(entity, eventName)
        local sprite = getSprite(entity)
        if not sprite or type(sprite.IsEventTriggered) ~= "function" then
            return false
        end
        local ok, triggered = pcall(sprite.IsEventTriggered, sprite, eventName)
        return ok and triggered == true
    end

    local function markEffectCollisionFree(effect)
        if not effect then
            return
        end
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        if effect.CollisionDamage ~= nil then
            effect.CollisionDamage = 0
        end
        if effect.Velocity ~= nil then
            effect.Velocity = newVector(0, 0)
        end
    end

    local function spawnOwnedEffect(variant, position, owner, marker)
        if not Isaac or type(Isaac.Spawn) ~= "function" or not position then
            return nil
        end
        local ok, entity = pcall(
            Isaac.Spawn,
            EFFECT_ENTITY,
            variant,
            0,
            position,
            newVector(0, 0),
            owner
        )
        if not ok or not entity then
            return nil
        end
        local effect = entity
        if type(entity.ToEffect) == "function" then
            local okEffect, converted = pcall(entity.ToEffect, entity)
            if okEffect and converted then
                effect = converted
            end
        end
        markEffectCollisionFree(effect)
        if type(effect.GetData) == "function" then
            local okData, data = pcall(effect.GetData, effect)
            if okData and type(data) == "table" then
                data[marker] = true
                data.NeverbirthBigDogOwnerKey = playerKey(owner)
            end
        end

        return effect
    end

    local function ensureDog(player, state)
        state = state or getPlayerRuntime(player, true)
        if not state then
            return nil
        end
        if entityExists(state.dog) then
            return state.dog
        end
        state.dog = nil
        local position = player and player.Position or newVector(0, 0)
        local dog = spawnOwnedEffect(DOG_VARIANT, position, player, "NeverbirthBigDogDog")
        if dog then
            state.dog = dog
            setEntityVisualScale(dog, Constants.DOG_VISUAL_SCALE)
            playDirectionalAnimation(dog, "Follow", state.lastMoveDirection or newVector(1, 0))
        end
        return dog
    end

    local function followPosition(player, direction)
        return vectorSubtract(player.Position or newVector(0, 0), vectorScale(direction or newVector(1, 0), 32))
    end

    local function updateFollowPosition(effect, player, direction)
        local target = followPosition(player, direction)
        local current = effect.Position or target
        local delta = vectorSubtract(target, current)
        local teleportDistance = Constants.FOLLOW_TELEPORT_DISTANCE
        if vectorLengthSquared(delta) >= teleportDistance * teleportDistance then
            effect.Position = target
        else
            effect.Position = vectorAdd(current, vectorScale(delta, Constants.FOLLOW_LERP))
        end
        effect.Velocity = newVector(0, 0)
        return target
    end

    return {
        removeEntity = removeEntity,
        getSprite = getSprite,
        setEntityVisualScale = setEntityVisualScale,
        makeEntityRef = makeEntityRef,
        dealEnemyDamage = dealEnemyDamage,
        directionalAnimationName = directionalAnimationName,
        playDirectionalAnimation = playDirectionalAnimation,
        spriteEventTriggered = spriteEventTriggered,
        markEffectCollisionFree = markEffectCollisionFree,
        spawnOwnedEffect = spawnOwnedEffect,
        ensureDog = ensureDog,
        followPosition = followPosition,
        updateFollowPosition = updateFollowPosition,
    }
end
