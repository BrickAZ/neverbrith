-- Private echo_shard responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local ECHO_VARIANT = deps.ECHO_VARIANT
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local newVector = deps.Queries.newVector
    local vectorAdd = deps.Queries.vectorAdd
    local vectorScale = deps.Queries.vectorScale
    local copyVector = deps.Queries.copyVector
    local playerIsDead = deps.Queries.playerIsDead
    local findPlayerByKey = deps.State.findPlayerByKey
    local removeEntity = deps.Effects.removeEntity
    local setEntityVisualScale = deps.Effects.setEntityVisualScale
    local playDirectionalAnimation = deps.Effects.playDirectionalAnimation
    local markEffectCollisionFree = deps.Effects.markEffectCollisionFree
    local spawnOwnedEffect = deps.Effects.spawnOwnedEffect
    local isEligibleEnemy = deps.Targets.isEligibleEnemy
    local damageOnce = deps.Targets.damageOnce
    local getEnemiesAlongSegment = deps.Targets.getEnemiesAlongSegment
    local spawnOrRefreshTrail = deps.Trails.spawnOrRefreshTrail
    local ECHO_SHARD_ID = deps.ECHO_SHARD_ID

    local function computeEchoDamage(targetMaxHitPoints, ownerDamage, multiplier)
        local base = 2.5
            + math.max(0, tonumber(targetMaxHitPoints) or 0) * 0.025
            + math.max(0, tonumber(ownerDamage) or 0) * 0.10
        return base * math.max(0, tonumber(multiplier) or 1)
    end

    local function createEchoFromDash(dash)
        if type(dash) ~= "table" or dash.hasEchoShard ~= true then
            return nil
        end
        local createdFrame = math.floor(tonumber(dash.finishedFrame) or runtime.frame)
        return {
            owner = dash.owner,
            ownerKey = dash.ownerKey,
            createdFrame = createdFrame,
            readyFrame = createdFrame + Constants.ECHO_DELAY_FRAMES,
            startPosition = copyVector(dash.startPosition),
            endPosition = copyVector(dash.endPosition),
            direction = copyVector(dash.direction),
            distance = tonumber(dash.distance) or Constants.DASH_DISTANCE,
            traveled = 0,
            stepFrames = 0,
            damageMultiplier = tonumber(dash.damageMultiplier) or 1,
            trailRadius = tonumber(dash.trailRadius) or Constants.TRAIL_RADIUS,
            hitMap = {},
        }
    end

    local function spawnEchoEffect(state, echo)
        local entity = spawnOwnedEffect(ECHO_VARIANT, echo.startPosition, echo.owner, "NeverbirthBigDogEcho")
        if not entity then
            return nil
        end
        state.echoEntity = entity
        state.echoData = echo
        state.echoActive = true
        setEntityVisualScale(entity, Constants.ECHO_VISUAL_SCALE)
        playDirectionalAnimation(entity, "Echo", echo.direction)
        return entity
    end

    local function updateEcho(_, effect)
        if not effect or type(effect.GetData) ~= "function" then
            return nil
        end
        local okData, data = pcall(effect.GetData, effect)
        if not okData or type(data) ~= "table" or data.NeverbirthBigDogEcho ~= true then
            return nil
        end
        local key = tostring(data.NeverbirthBigDogOwnerKey or "")
        local state = runtime.players[key]
        local echo = state and state.echoData or nil
        local owner = echo and echo.owner or findPlayerByKey(key)
        if not state or not echo or not owner or playerIsDead(owner) then
            removeEntity(effect)
            if state then
                state.echoEntity = nil
                state.echoData = nil
                state.echoActive = false
            end
            return nil
        end
        state.echoEntity = effect
        markEffectCollisionFree(effect)
        setEntityVisualScale(effect, Constants.ECHO_VISUAL_SCALE)
        playDirectionalAnimation(effect, "Echo", echo.direction)
        if runtime.frame < echo.readyFrame then
            effect.Position = copyVector(echo.startPosition)
            return nil
        end
        if echo.traveled <= 0 then
            spawnOrRefreshTrail(owner, echo.startPosition, echo.trailRadius, runtime.frame)
        end
        local previousPosition = vectorAdd(echo.startPosition, vectorScale(echo.direction, echo.traveled))
        local remaining = math.max(0, echo.distance - echo.traveled)
        local step = math.min(Constants.DASH_SPEED, remaining)
        echo.traveled = echo.traveled + step
        echo.stepFrames = echo.stepFrames + 1
        effect.Position = vectorAdd(echo.startPosition, vectorScale(echo.direction, echo.traveled))
        effect.Velocity = newVector(0, 0)

        for _, enemy in ipairs(getEnemiesAlongSegment(previousPosition, effect.Position, Constants.HIT_RADIUS)) do
            if isEligibleEnemy(enemy) then
                damageOnce(
                    echo.hitMap,
                    enemy,
                    computeEchoDamage(enemy.MaxHitPoints, owner.Damage, echo.damageMultiplier),
                    owner
                )
            end
        end
        if echo.stepFrames % Constants.TRAIL_INTERVAL_FRAMES == 0 then
            spawnOrRefreshTrail(owner, effect.Position, echo.trailRadius, runtime.frame)
        end
        if echo.traveled >= echo.distance - 0.0001 then
            spawnOrRefreshTrail(owner, effect.Position, echo.trailRadius, runtime.frame)
            removeEntity(effect)
            state.echoEntity = nil
            state.echoData = nil
            state.echoActive = false
        end
        return nil
    end
    function callbackInstallers.updateEcho()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, updateEcho, ECHO_VARIANT)
    end

    return {
        computeEchoDamage = computeEchoDamage,
        createEchoFromDash = createEchoFromDash,
        spawnEchoEffect = spawnEchoEffect,
        updateEcho = updateEcho,
        Installers = callbackInstallers,
        ItemId = ECHO_SHARD_ID,
    }
end
