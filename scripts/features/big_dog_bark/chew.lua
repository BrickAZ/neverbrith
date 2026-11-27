-- Private chew responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local NO_GRID_COLLISION = deps.NO_GRID_COLLISION
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local newVector = deps.Queries.newVector
    local vectorAdd = deps.Queries.vectorAdd
    local vectorSubtract = deps.Queries.vectorSubtract
    local vectorScale = deps.Queries.vectorScale
    local vectorLength = deps.Queries.vectorLength
    local normalized = deps.Queries.normalized
    local distanceSquared = deps.Queries.distanceSquared
    local copyVector = deps.Queries.copyVector
    local entityKey = deps.Queries.entityKey
    local getCurrentRoom = deps.Queries.getCurrentRoom
    local computeChewDamage = deps.Rules.computeChewDamage
    local getPlayerRecord = deps.State.getPlayerRecord
    local playDirectionalAnimation = deps.Effects.playDirectionalAnimation
    local spriteEventTriggered = deps.Effects.spriteEventTriggered
    local updateFollowPosition = deps.Effects.updateFollowPosition
    local isEligibleEnemy = deps.Targets.isEligibleEnemy
    local makeEntityReference = deps.Targets.makeEntityReference
    local resolveEntityReference = deps.Targets.resolveEntityReference
    local selectChewTarget = deps.Targets.selectChewTarget
    local damageEnemy = deps.Targets.damageEnemy
    local pointSegmentDistanceSquared = deps.Targets.pointSegmentDistanceSquared

    local function beginChewPause(state, frame)
        if type(state) ~= "table" then
            return nil
        end
        state.mode = "chew_pause"
        state.chewPauseUntil = math.floor(tonumber(frame) or runtime.frame) + Constants.CHEW_PAUSE_FRAMES
        return state.chewPauseUntil
    end

    local function isChewPauseComplete(state, frame)
        return type(state) == "table"
            and state.chewPauseUntil ~= nil
            and math.floor(tonumber(frame) or runtime.frame) >= math.floor(tonumber(state.chewPauseUntil) or 0)
    end

    local function roomHasDirectChewPath(room, startPosition, targetPosition)
        if not room or type(room.CheckLine) ~= "function" then
            return true
        end
        local checkMode = (LineCheckMode and LineCheckMode.PROJECTILE) or 0
        local ok, clear = pcall(room.CheckLine, room, startPosition, targetPosition, checkMode, 0, false, false)
        return ok and clear == true
    end

    local function buildChewGridPath(room, startPosition, targetPosition)
        if not room
            or type(room.GetGridWidth) ~= "function"
            or type(room.GetGridSize) ~= "function"
            or type(room.GetGridIndex) ~= "function"
            or type(room.GetGridPosition) ~= "function"
            or type(room.GetGridCollision) ~= "function"
        then
            return nil
        end
        local okWidth, width = pcall(room.GetGridWidth, room)
        local okSize, size = pcall(room.GetGridSize, room)
        local okStart, startIndex = pcall(room.GetGridIndex, room, startPosition)
        local okTarget, targetIndex = pcall(room.GetGridIndex, room, targetPosition)
        width = math.floor(tonumber(width) or 0)
        size = math.floor(tonumber(size) or 0)
        startIndex = math.floor(tonumber(startIndex) or -1)
        targetIndex = math.floor(tonumber(targetIndex) or -1)
        if not okWidth or not okSize or not okStart or not okTarget
            or width <= 0 or size <= 0
            or startIndex < 0 or startIndex >= size
            or targetIndex < 0 or targetIndex >= size
        then
            return nil
        end
        if startIndex == targetIndex then
            return { copyVector(targetPosition) }
        end

        local queue = { startIndex }
        local head = 1
        local cameFrom = { [startIndex] = startIndex }
        local function passable(index)
            if index == startIndex or index == targetIndex then
                return true
            end
            local okCollision, collision = pcall(room.GetGridCollision, room, index)
            return okCollision and tonumber(collision) == NO_GRID_COLLISION
        end
        while head <= #queue and cameFrom[targetIndex] == nil do
            local current = queue[head]
            head = head + 1
            local column = current % width
            local neighbors = {}
            if column > 0 then neighbors[#neighbors + 1] = current - 1 end
            if column < width - 1 then neighbors[#neighbors + 1] = current + 1 end
            if current - width >= 0 then neighbors[#neighbors + 1] = current - width end
            if current + width < size then neighbors[#neighbors + 1] = current + width end
            for _, nextIndex in ipairs(neighbors) do
                if cameFrom[nextIndex] == nil and passable(nextIndex) then
                    cameFrom[nextIndex] = current
                    queue[#queue + 1] = nextIndex
                end
            end
        end
        if cameFrom[targetIndex] == nil then
            return nil
        end

        local reversed = {}
        local current = targetIndex
        while current ~= startIndex do
            local okPosition, position = pcall(room.GetGridPosition, room, current)
            if not okPosition or not position then
                return nil
            end
            reversed[#reversed + 1] = copyVector(position)
            current = cameFrom[current]
        end
        local path = {}
        for index = #reversed, 1, -1 do
            path[#path + 1] = reversed[index]
        end
        path[#path] = copyVector(targetPosition)
        return path
    end

    local function shouldRefreshChewPath(state, targetKey, frame, blocked)
        if type(state) ~= "table" or blocked == true then
            return true
        end
        if type(state.chewPath) ~= "table" or tostring(state.chewPathTargetKey or "") ~= tostring(targetKey or "") then
            return true
        end
        return math.floor(tonumber(frame) or runtime.frame) >= math.floor(tonumber(state.nextChewPathFrame) or 0)
    end

    local function clearChewNavigation(state, preserveVelocity)
        if type(state) ~= "table" then return end
        state.chewPath = nil
        state.chewPathNode = 1
        state.chewPathTargetKey = nil
        state.nextChewPathFrame = 0
        state.chewPathFailureCount = 0
        if preserveVelocity ~= true then
            state.chewMoveVelocity = nil
        end
    end

    local function updateChewSafePosition(state, effect, room)
        if type(state) ~= "table" or not effect or not effect.Position then return end
        if runtime.frame < math.floor(tonumber(state.nextChewSafeFrame) or 0) then return end
        state.nextChewSafeFrame = runtime.frame + Constants.CHEW_SAFE_POSITION_INTERVAL
        local safe = true
        if room and type(room.GetGridIndex) == "function" and type(room.GetGridCollision) == "function" then
            local okIndex, index = pcall(room.GetGridIndex, room, effect.Position)
            local okCollision, collision = false, nil
            if okIndex then
                okCollision, collision = pcall(room.GetGridCollision, room, index)
            end
            safe = okIndex and okCollision and tonumber(collision) == NO_GRID_COLLISION
        end
        if safe then
            state.chewSafePosition = copyVector(effect.Position)
        end
    end

    local function rescueChewDog(state, effect, owner)
        local position = state.chewSafePosition or (owner and owner.Position)
        if position then effect.Position = copyVector(position) end
        effect.Velocity = newVector(0, 0)
        clearChewNavigation(state)
        state.chewSearchPending = true
    end

    local function clearChewAttack(state)
        if type(state) ~= "table" then return end
        state.chewWindupDirection = nil
        state.chewLungeDirection = nil
        state.chewLungeStart = nil
        state.chewLungeTravel = nil
        state.chewHitConsumed = false
        state.chewAnimation = nil
    end

    local function releaseChewTarget(state)
        if type(state) ~= "table" then return end
        state.chewTarget = nil
        state.chewTargetKey = nil
        clearChewNavigation(state)
        clearChewAttack(state)
    end

    local function finishChewRecovery(state)
        clearChewAttack(state)
        beginChewPause(state, runtime.frame)
    end

    local function updateChew(state, effect, owner)
        local record = getPlayerRecord(owner)
        local room = getCurrentRoom()
        updateChewSafePosition(state, effect, room)
        if not record or not record.chewUnlocked then
            state.mode = "follow"
            releaseChewTarget(state)
            state.chewSearchPending = true
            updateFollowPosition(effect, owner, state.lastMoveDirection)
            playDirectionalAnimation(effect, "Follow", state.lastMoveDirection or newVector(1, 0))
            return
        end

        if state.mode == "chew_pause" then
            effect.Velocity = newVector(0, 0)
            if isChewPauseComplete(state, runtime.frame) then
                state.mode = "follow"
                state.chewPauseUntil = nil
                releaseChewTarget(state)
                state.chewSearchPending = true
            else
                return
            end
        end

        local target = resolveEntityReference(state.chewTarget)
        local attackCommitted = state.mode == "bite_lunge" or state.mode == "bite_recover"
        if not attackCommitted then
            local targetKey = state.chewTargetKey or (target and entityKey(target))
            local lostReference = target == nil and state.chewTarget ~= nil
            local invalidTarget = target ~= nil and (not isEligibleEnemy(target) or state.roomChewed[targetKey])
            if lostReference or invalidTarget then
                target = nil
                releaseChewTarget(state)
                state.chewSearchPending = true
            end
        end

        if state.mode == "bite_windup" then
            if not target or not isEligibleEnemy(target) then
                state.mode = "follow"
                releaseChewTarget(state)
                state.chewSearchPending = true
                return
            end
            local direction = normalized(
                state.chewWindupDirection or vectorSubtract(target.Position, effect.Position),
                state.lastMoveDirection or newVector(1, 0)
            )
            state.chewWindupDirection = copyVector(direction)
            state.lastMoveDirection = direction
            state.chewAnimation = playDirectionalAnimation(effect, "Bite", direction)
            effect.Velocity = newVector(0, 0)
            if spriteEventTriggered(effect, "BiteLungeStart") then
                state.mode = "bite_lunge"
                state.chewLungeDirection = copyVector(direction)
                state.chewLungeStart = copyVector(effect.Position)
                state.chewLungeTravel = 0
                state.chewHitConsumed = false
                state.chewMoveVelocity = nil
            end
            return
        end

        if state.mode == "bite_lunge" then
            local direction = state.chewLungeDirection or state.lastMoveDirection or newVector(1, 0)
            local startPosition = state.chewLungeStart or copyVector(effect.Position)
            local traveled = math.max(0, tonumber(state.chewLungeTravel) or 0)
            local remaining = math.max(0, Constants.CHEW_LUNGE_DISTANCE - traveled)
            local step = math.min(Constants.CHEW_LUNGE_SPEED, remaining)
            traveled = traveled + step
            state.chewLungeTravel = traveled
            effect.Position = vectorAdd(startPosition, vectorScale(direction, traveled))
            effect.Velocity = newVector(0, 0)

            if spriteEventTriggered(effect, "BiteHit") and state.chewHitConsumed ~= true then
                state.chewHitConsumed = true
                local liveTarget = resolveEntityReference(state.chewTarget)
                local targetKey = state.chewTargetKey or (liveTarget and entityKey(liveTarget))
                if liveTarget and isEligibleEnemy(liveTarget) and liveTarget.Position then
                    local contactRadius = Constants.CHEW_HIT_RADIUS + math.max(0, tonumber(liveTarget.Size) or 0)
                    local inside = pointSegmentDistanceSquared(
                        liveTarget.Position,
                        startPosition,
                        effect.Position
                    ) <= contactRadius * contactRadius
                    local damage = computeChewDamage(liveTarget.MaxHitPoints)
                    if inside and damage > 0 and damageEnemy(liveTarget, damage, owner) then
                        state.roomChewed[targetKey] = true
                    end
                end
                state.mode = "bite_recover"
            end
            if spriteEventTriggered(effect, "BiteEnd") then
                finishChewRecovery(state)
            end
            return
        end

        if state.mode == "bite_recover" then
            effect.Velocity = newVector(0, 0)
            if spriteEventTriggered(effect, "BiteEnd") then
                finishChewRecovery(state)
            end
            return
        end

        local targetVersion = runtime.roomTargetVersion
        local retryDue = runtime.frame >= (tonumber(state.nextChewSearchFrame) or 0)
        if target == nil and (
            state.chewSearchPending or state.lastChewSearchVersion ~= targetVersion or retryDue
        ) then
            target = selectChewTarget(owner, runtime.roomTargets)
            state.chewTarget = target and makeEntityReference(target) or nil
            state.chewTargetKey = target and entityKey(target) or nil
            state.lastChewSearchVersion = targetVersion
            state.chewSearchPending = false
            state.nextChewSearchFrame = runtime.frame + Constants.CHEW_SEARCH_RETRY_FRAMES
            clearChewNavigation(state)
        end
        if not target then
            state.mode = "follow"
            updateFollowPosition(effect, owner, state.lastMoveDirection)
            playDirectionalAnimation(effect, "Follow", state.lastMoveDirection or newVector(1, 0))
            return
        end

        local delta = vectorSubtract(target.Position, effect.Position)
        local distance = vectorLength(delta)
        local direction = normalized(delta, state.lastMoveDirection or newVector(1, 0))
        state.lastMoveDirection = direction
        if distance <= Constants.CHEW_APPROACH_RADIUS then
            state.mode = "bite_windup"
            state.chewWindupDirection = direction
            state.chewHitConsumed = false
            state.chewAnimation = playDirectionalAnimation(effect, "Bite", direction)
            state.chewMoveVelocity = nil
            effect.Velocity = newVector(0, 0)
            return
        end

        state.mode = "chew_seek"
        local destination = target.Position
        if not roomHasDirectChewPath(room, effect.Position, target.Position) then
            local key = state.chewTargetKey or entityKey(target)
            if shouldRefreshChewPath(state, key, runtime.frame, false) then
                local path = buildChewGridPath(room, effect.Position, target.Position)
                state.chewPath = path or {}
                state.chewPathNode = 1
                state.chewPathTargetKey = key
                state.nextChewPathFrame = runtime.frame + Constants.CHEW_PATH_REFRESH_FRAMES
                if path then
                    state.chewPathFailureCount = 0
                else
                    state.chewPathFailureCount = (tonumber(state.chewPathFailureCount) or 0) + 1
                end
            end
            local path = state.chewPath
            local nodeIndex = math.max(1, math.floor(tonumber(state.chewPathNode) or 1))
            local node = type(path) == "table" and path[nodeIndex] or nil
            while node and distanceSquared(effect.Position, node) <= 16 * 16 do
                nodeIndex = nodeIndex + 1
                state.chewPathNode = nodeIndex
                node = path[nodeIndex]
            end
            if node then
                destination = node
            elseif (tonumber(state.chewPathFailureCount) or 0) >= Constants.CHEW_PATH_FAILURE_LIMIT then
                rescueChewDog(state, effect, owner)
                return
            else
                effect.Velocity = newVector(0, 0)
                return
            end
        else
            clearChewNavigation(state, true)
        end

        local moveDelta = vectorSubtract(destination, effect.Position)
        local moveDistance = vectorLength(moveDelta)
        local moveDirection = normalized(moveDelta, direction)
        local desiredVelocity = vectorScale(moveDirection, math.min(Constants.CHEW_SPEED, moveDistance))
        local previousVelocity = state.chewMoveVelocity or newVector(0, 0)
        local blendedVelocity = vectorAdd(
            vectorScale(previousVelocity, 1 - Constants.CHEW_MOVE_LERP),
            vectorScale(desiredVelocity, Constants.CHEW_MOVE_LERP)
        )
        if vectorLength(blendedVelocity) > moveDistance and moveDistance > 0 then
            blendedVelocity = vectorScale(normalized(blendedVelocity), moveDistance)
        end
        state.chewMoveVelocity = blendedVelocity
        effect.Position = vectorAdd(effect.Position, blendedVelocity)
        effect.Velocity = newVector(0, 0)
        playDirectionalAnimation(effect, "Run", moveDirection)
    end

    return {
        beginChewPause = beginChewPause,
        isChewPauseComplete = isChewPauseComplete,
        roomHasDirectChewPath = roomHasDirectChewPath,
        buildChewGridPath = buildChewGridPath,
        shouldRefreshChewPath = shouldRefreshChewPath,
        clearChewNavigation = clearChewNavigation,
        updateChewSafePosition = updateChewSafePosition,
        rescueChewDog = rescueChewDog,
        clearChewAttack = clearChewAttack,
        releaseChewTarget = releaseChewTarget,
        finishChewRecovery = finishChewRecovery,
        updateChew = updateChew,
    }
end
