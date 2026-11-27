-- Private geometry ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}

    local function GetPlayerBodyWorldPosition(player)
        local position = (player and player.Position) or Vector(320, 280)
        if player and player.PositionOffset then position = position + player.PositionOffset end
        if player and player.GetFlyingOffset then
            local ok, offset = pcall(function() return player:GetFlyingOffset() end)
            if ok and offset then position = position + offset end
        end
        return position
    end

    function Neverbirth.Cleaver.GetSwingRange(player)
        -- Stranger's reach is deliberately fixed: neither TearRange nor body size changes it.
        return tonumber(Neverbirth.Cleaver.Config.BaseSwingRange) or 70
    end

    function Neverbirth.Cleaver.GetSwingHalfWidth(player)
        return tonumber(Neverbirth.Cleaver.Config.BaseSwingHalfWidth) or 22
    end

    local function GetAngleDegrees(vector)
        if not vector then return 0 end
        local x, y = tonumber(vector.X) or 0, tonumber(vector.Y) or 0
        if x == 0 and y == 0 then return 0 end
        local radians
        if x > 0 then
            radians = math.atan(y / x)
        elseif x < 0 and y >= 0 then
            radians = math.atan(y / x) + math.pi
        elseif x < 0 then
            radians = math.atan(y / x) - math.pi
        elseif y > 0 then
            radians = math.pi * 0.5
        else
            radians = -math.pi * 0.5
        end
        return math.deg(radians)
    end

    local function NormalizeSignedDegrees(degrees)
        degrees = tonumber(degrees) or 0
        while degrees > 180 do degrees = degrees - 360 end
        while degrees <= -180 do degrees = degrees + 360 end
        return degrees
    end

    local function GetSweepRelativeAngle(variant, progress)
        progress = math.max(0, math.min(1, tonumber(progress) or 0))
        if variant == "B" then return 90 - 180 * progress end
        return -90 + 180 * progress
    end

    function Neverbirth.Cleaver.GetSweepDirection(swing, progress)
        if not swing or not swing.direction then return Vector(0, 1) end
        local degrees = GetAngleDegrees(swing.direction)
            + GetSweepRelativeAngle(swing.variant, progress)
        local radians = math.rad(degrees)
        return Vector(math.cos(radians), math.sin(radians))
    end

    local function IsInsideSwingSweep(swing, position, size, previousProgress, currentProgress)
        if not swing or not swing.origin or not swing.direction or not position then return false end
        local delta = position - swing.origin
        local targetRadius = math.max(0, tonumber(size) or 0)
        local distance = delta:Length()
        local range = tonumber(swing.range) or 0
        if distance - targetRadius > range then return false end
        if distance <= targetRadius then return true end
        local relative = NormalizeSignedDegrees(
            GetAngleDegrees(delta) - GetAngleDegrees(swing.direction)
        )
        local from = GetSweepRelativeAngle(swing.variant, previousProgress)
        local to = GetSweepRelativeAngle(swing.variant, currentProgress)
        local lower, upper = math.min(from, to), math.max(from, to)
        local radiusPadding = math.deg(math.asin(math.min(1, targetRadius / math.max(distance, 1))))
        local padding = (tonumber(Neverbirth.Cleaver.Config.SweepAngularPaddingDegrees) or 0) + radiusPadding
        return relative >= lower - padding and relative <= upper + padding
    end

    return {
        GetPlayerBodyWorldPosition = GetPlayerBodyWorldPosition,
        GetSwingRange = Neverbirth.Cleaver.GetSwingRange,
        GetSwingHalfWidth = Neverbirth.Cleaver.GetSwingHalfWidth,
        GetAngleDegrees = GetAngleDegrees,
        NormalizeSignedDegrees = NormalizeSignedDegrees,
        GetSweepRelativeAngle = GetSweepRelativeAngle,
        GetSweepDirection = Neverbirth.Cleaver.GetSweepDirection,
        IsInsideSwingSweep = IsInsideSwingSweep,
        Installers = Installers,
    }
end
