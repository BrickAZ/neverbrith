-- Caller-owned snapshots. No global lock, callbacks, timers or lifecycle policy.
local Shooting = {}

-- Block(scopes, key, player): capture CanShoot once, then suppress this update.
function Shooting.Block(scopes, key, player)
    if not scopes[key] then scopes[key] = {player=player, value=player:CanShoot()} end
    player:SetCanShoot(false)
end

-- Restore(scopes, key, exists): detach before any engine call; restore exact bool.
-- The caller supplies its existing entity-validity contract. Errors propagate.
function Shooting.Restore(scopes, key, exists)
    local scope = scopes[key]
    scopes[key] = nil
    if scope and exists(scope.player) then scope.player:SetCanShoot(scope.value) end
end

-- Bind one real consumer to the installation's shared CanShoot service.
-- Omitted service keeps the historical standalone-factory contract above.
function Shooting.ForOwner(service, name)
    if not service then return Shooting end
    local owner = service.Owner(name)
    local scoped = {}
    function scoped.Block(scopes, key, player)
        if not scopes[key] then scopes[key] = {handle=owner.Capture(player)} end
        owner.Block(scopes[key].handle)
    end
    function scoped.Restore(scopes, key, exists)
        local scope = scopes[key]
        scopes[key] = nil
        if scope then owner.Release(scope.handle, exists) end
    end
    return scoped
end

return Shooting
