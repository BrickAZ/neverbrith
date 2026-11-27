local function GetRenderOffset(player)
    local offset = Vector(0, 0)
    if player and player.PositionOffset then
        offset = offset + player.PositionOffset
    end
    if player and player.GetFlyingOffset then
        local ok, flyingOffset = pcall(function()
            return player:GetFlyingOffset()
        end)
        if ok and flyingOffset then
            offset = offset + flyingOffset
        end
    end
    return offset
end

local function GetPlayerHeadWorldPosition(player)
    if not player or not player.Position then return Vector(320, 280) end
    local offset = GetRenderOffset(player)
    local size = tonumber(player.Size) or 20
    return player.Position + offset + Vector(0, -math.max(18, size + 4))
end

return { GetPlayerHeadWorldPosition = GetPlayerHeadWorldPosition, GetRenderOffset = GetRenderOffset }
