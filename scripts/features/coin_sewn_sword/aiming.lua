-- Direction selection is shared by input, release and projectile creation.
return function(Neverbirth, dependencies)
    local IsVulnerableEnemy = dependencies.IsVulnerableEnemy
    local function GetNearestEnemyDirection(player)
        local origin = player and player.Position or Vector(0, 0)
        local nearest
        local nearestDistance

        if Isaac.GetRoomEntities then
            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                if IsVulnerableEnemy(entity) and entity.Position then
                    local distance = (entity.Position - origin):Length()
                    if not nearestDistance or distance < nearestDistance then
                        nearest = entity
                        nearestDistance = distance
                    end
                end
            end
        end

        if nearest and nearest.Position then
            return (nearest.Position - origin):Normalized()
        end

        return nil
    end

    local function GetNearestEnemyDirectionFromPosition(origin)
        origin = origin or Vector(0, 0)
        local nearest
        local nearestDistance

        if Isaac.GetRoomEntities then
            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                if IsVulnerableEnemy(entity) and entity.Position then
                    local distance = (entity.Position - origin):Length()
                    if not nearestDistance or distance < nearestDistance then
                        nearest = entity
                        nearestDistance = distance
                    end
                end
            end
        end

        if nearest and nearest.Position then
            return (nearest.Position - origin):Normalized()
        end

        return nil
    end

    local function VectorFromInput(value)
        -- Engine Vectors are userdata; table-only checks reject real shooting input.
        local valueType = type(value)
        if (valueType == "userdata" or valueType == "table") and value.X and value.Y then
            local vector = Vector(tonumber(value.X) or 0, tonumber(value.Y) or 0)
            if vector:Length() > 0 then
                return vector:Normalized()
            end
        end

        return nil
    end

    local function DirectionToVector(value)
        local vector = VectorFromInput(value)
        if vector then
            return vector
        end

        if type(value) ~= "number" then
            return nil
        end

        if Direction then
            if value == Direction.LEFT then
                return Vector(-1, 0)
            elseif value == Direction.UP then
                return Vector(0, -1)
            elseif value == Direction.RIGHT then
                return Vector(1, 0)
            elseif value == Direction.DOWN then
                return Vector(0, 1)
            end
        end

        if value == 0 then
            return Vector(-1, 0)
        elseif value == 1 then
            return Vector(0, -1)
        elseif value == 2 then
            return Vector(1, 0)
        elseif value == 3 then
            return Vector(0, 1)
        end

        return nil
    end

    local function GetCoinSwordBaseDirection(player)
        if player and player.GetShootingInput then
            local ok, input = pcall(function()
                return player:GetShootingInput()
            end)
            local vector = ok and VectorFromInput(input) or nil
            if vector then
                return vector
            end
        end

        if player and player.GetFireDirection then
            local ok, input = pcall(function()
                return player:GetFireDirection()
            end)
            local vector = ok and DirectionToVector(input) or nil
            if vector then
                return vector
            end
        end

        if player and player.GetMovementInput then
            local ok, input = pcall(function()
                return player:GetMovementInput()
            end)
            local vector = ok and VectorFromInput(input) or nil
            if vector then
                return vector
            end
        end

        if player and player.GetMovementDirection then
            local ok, input = pcall(function()
                return player:GetMovementDirection()
            end)
            local vector = ok and DirectionToVector(input) or nil
            if vector then
                return vector
            end
        end

        local targetDirection = GetNearestEnemyDirection(player)
        if targetDirection and targetDirection:Length() > 0 then
            return targetDirection:Normalized()
        end

        return Vector(1, 0)
    end

    return { GetNearestEnemyDirectionFromPosition = GetNearestEnemyDirectionFromPosition, VectorFromInput = VectorFromInput, GetBaseDirection = GetCoinSwordBaseDirection }
end
