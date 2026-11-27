-- Stateless mechanics; entity markers, caches, phase and timing remain item-owned.
-- See docs/api/archive-rooms.md. No callback registration or import-time world access.
local Controls = {}

-- Returns played, attempted. "attempted" distinguishes Play failure from a
-- missing sprite/animation; Certificate only clears its played marker after Play.
function Controls.PlayAnimation(effect, requested, onMissing)
    if not requested then return false end
    local sprite = effect and effect.GetSprite and effect:GetSprite() or nil
    if not sprite or not sprite.Play then return false end
    if sprite.HasAnimation then
        local ok, exists = pcall(function() return sprite:HasAnimation(requested) end)
        if not ok or exists ~= true then
            if onMissing then onMissing(requested) end
            return false
        end
    end
    local ok = pcall(function() sprite:Play(requested, true) end)
    return ok, true
end

function Controls.MakeHarmless(effect)
    pcall(function() effect.Timeout = -1 end)
    pcall(function() effect.CollisionDamage = 0 end)
    if EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE ~= nil then
        pcall(function() effect.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE end)
    end
    if GridCollisionClass and GridCollisionClass.COLLISION_NONE ~= nil then
        pcall(function() effect.GridCollisionClass = GridCollisionClass.COLLISION_NONE end)
    end
end

-- Queries live players once per control, preserving the old observation order.
function Controls.AnyPlayerWithin(control, radius, getPlayers, vectorXY)
    if not control then return false end
    local controlX, controlY = vectorXY(control.Position)
    local radiusSquared = radius * radius
    for _, player in ipairs(getPlayers()) do
        local playerX, playerY = vectorXY(player and player.Position)
        local dx, dy = playerX - controlX, playerY - controlY
        if dx * dx + dy * dy <= radiusSquared then return true end
    end
    return false
end

-- Mutates only the caller-owned session.controlTouchLatch; returns new touch facts.
function Controls.UpdateTouchLatches(session, roles, entered)
    session.controlTouchLatch = type(session.controlTouchLatch) == "table" and session.controlTouchLatch or {}
    local touching = {}
    for _, role in ipairs(roles) do
        touching[role] = entered(session, role)
        if not touching[role] then session.controlTouchLatch[role] = nil end
    end
    return touching
end

return Controls
