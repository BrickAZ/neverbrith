-- Private dash responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local ECHO_SHARD_ID = deps.ECHO_SHARD_ID
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local newVector = deps.Queries.newVector
    local vectorAdd = deps.Queries.vectorAdd
    local vectorScale = deps.Queries.vectorScale
    local normalized = deps.Queries.normalized
    local copyVector = deps.Queries.copyVector
    local playerKey = deps.Queries.playerKey
    local hasCollectible = deps.Queries.hasCollectible
    local isBusy = deps.Rules.isBusy
    local computeDashDamage = deps.Rules.computeDashDamage
    local applyVelocityImpulse = deps.Rules.applyVelocityImpulse
    local save = deps.State.save
    local getPlayerRuntime = deps.State.getPlayerRuntime
    local getPlayerRecord = deps.State.getPlayerRecord
    local playSoundCue = deps.Audio.playSoundCue
    local clearChargeSoundSchedule = deps.Audio.clearChargeSoundSchedule
    local playDirectionalAnimation = deps.Effects.playDirectionalAnimation
    local isEligibleEnemy = deps.Targets.isEligibleEnemy
    local damageOnce = deps.Targets.damageOnce
    local getEnemiesAlongSegment = deps.Targets.getEnemiesAlongSegment
    local spawnOrRefreshTrail = deps.Trails.spawnOrRefreshTrail
    local createEchoFromDash = deps.EchoShard.createEchoFromDash
    local spawnEchoEffect = deps.EchoShard.spawnEchoEffect

    local function launch(player, direction, options)
        if Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.OwnsAttack(player) then return nil end
        options = options or {}
        local state = getPlayerRuntime(player, true)
        local record = getPlayerRecord(player)
        if not state or not record or options.busy == true then
            return nil
        end
        if options.ignoreBusy ~= true and (isBusy(state.mode) or state.echoActive == true) then
            return nil
        end
        if options.ignoreSameFrame ~= true and state.lastLaunchFrame == runtime.frame then
            return nil
        end

        local resolvedDirection = normalized(direction, newVector(1, 0))
        local explicitMultiplier = options.potionMultiplier ~= nil
        local enhanced = explicitMultiplier
            and (tonumber(options.potionMultiplier) or 1) > 1
            or (not explicitMultiplier and record.potionArmed == true)
        local damageMultiplier = explicitMultiplier
            and math.max(0, tonumber(options.potionMultiplier) or 1)
            or (enhanced and 1.5 or 1)
        local distance = enhanced and Constants.DASH_DISTANCE * 1.5 or Constants.DASH_DISTANCE
        local trailRadius = enhanced and Constants.ENHANCED_TRAIL_RADIUS or Constants.TRAIL_RADIUS
        local startPosition = copyVector(options.startPosition or (state.dog and state.dog.Position) or player.Position)
        local finalChargePitch = math.max(Constants.CHARGE_SOUND_START_PITCH, math.min(
            Constants.CHARGE_SOUND_MAX_PITCH,
            tonumber(options.chargeSoundPitch)
                or tonumber(state.chargeSoundPitch)
                or Constants.CHARGE_SOUND_START_PITCH
        ))
        local endPosition = vectorAdd(startPosition, vectorScale(resolvedDirection, distance))
        local hasEcho = options.hasEchoShard
        if hasEcho == nil then
            hasEcho = hasCollectible(player, ECHO_SHARD_ID)
        end

        local dash = {
            owner = player,
            ownerKey = playerKey(player),
            createdFrame = runtime.frame,
            startPosition = startPosition,
            endPosition = endPosition,
            direction = resolvedDirection,
            distance = distance,
            traveled = 0,
            stepFrames = 0,
            damageMultiplier = damageMultiplier,
            trailRadius = trailRadius,
            trailEnabled = hasEcho == true,
            windImpulse = enhanced and Constants.WIND_IMPULSE or 0,
            hasEchoShard = hasEcho == true,
            hitMap = {},
        }

        state.mode = "dash"
        state.dash = dash
        state.chargeStartFrame = nil
        state.chargeFrames = nil
        state.chargeSlot = nil
        state.chargeSawHeld = false
        clearChargeSoundSchedule(state)
        state.lastLaunchFrame = runtime.frame
        if not explicitMultiplier and record.potionArmed then
            record.potionArmed = false
            save()
        end
        playSoundCue("Release", 1 / finalChargePitch)
        return dash
    end

    local function finishDash(state, effect)
        local dash = state.dash
        if not dash then
            state.mode = "follow"
            return
        end
        dash.endPosition = copyVector(effect.Position or dash.endPosition)
        dash.finishedFrame = runtime.frame
        if dash.trailEnabled == true then
            spawnOrRefreshTrail(dash.owner, dash.endPosition, dash.trailRadius, runtime.frame)
        end
        local echo = createEchoFromDash(dash)
        state.dash = nil
        state.mode = "follow"
        state.chewSearchPending = true
        if echo then
            spawnEchoEffect(state, echo)
        end
    end

    local function updateDash(state, effect)
        local dash = state.dash
        if not dash then
            state.mode = "follow"
            return
        end
        if dash.traveled <= 0 then
            if dash.trailEnabled == true then
                spawnOrRefreshTrail(dash.owner, dash.startPosition, dash.trailRadius, runtime.frame)
            end
        end
        local previousPosition = vectorAdd(dash.startPosition, vectorScale(dash.direction, dash.traveled))
        local remaining = math.max(0, dash.distance - dash.traveled)
        local step = math.min(Constants.DASH_SPEED, remaining)
        dash.traveled = dash.traveled + step
        dash.stepFrames = dash.stepFrames + 1
        effect.Position = vectorAdd(dash.startPosition, vectorScale(dash.direction, dash.traveled))
        effect.Velocity = newVector(0, 0)
        playDirectionalAnimation(effect, "Dash", dash.direction)

        for _, enemy in ipairs(getEnemiesAlongSegment(previousPosition, effect.Position, Constants.HIT_RADIUS)) do
            if isEligibleEnemy(enemy) then
                local damage = computeDashDamage(enemy.MaxHitPoints, dash.owner.Damage, dash.damageMultiplier)
                if damageOnce(dash.hitMap, enemy, damage, dash.owner)
                    and dash.windImpulse > 0
                    and enemy.Velocity ~= nil
                then
                    enemy.Velocity = applyVelocityImpulse(
                        enemy.Velocity,
                        dash.direction,
                        dash.windImpulse,
                        Constants.WIND_SPEED_CAP
                    )
                end
            end
        end

        if dash.trailEnabled == true
            and dash.stepFrames % Constants.TRAIL_INTERVAL_FRAMES == 0 then
            spawnOrRefreshTrail(dash.owner, effect.Position, dash.trailRadius, runtime.frame)
        end
        if dash.traveled >= dash.distance - 0.0001 then
            finishDash(state, effect)
        end
    end

    return {
        launch = launch,
        finishDash = finishDash,
        updateDash = updateDash,
    }
end
