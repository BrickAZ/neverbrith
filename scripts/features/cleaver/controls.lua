-- Private controls ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local GetPlayers = deps.GetPlayers
    local lifetime = deps.Lifetime

    local function GetShootDirection(action)
        if not ButtonAction then return nil end
        if action == ButtonAction.ACTION_SHOOTLEFT then return Vector(-1, 0) end
        if action == ButtonAction.ACTION_SHOOTRIGHT then return Vector(1, 0) end
        if action == ButtonAction.ACTION_SHOOTUP then return Vector(0, -1) end
        if action == ButtonAction.ACTION_SHOOTDOWN then return Vector(0, 1) end
        return nil
    end

    function Neverbirth.Cleaver.GetTriggeredShootDirection(player)
        if not (Input and Input.IsActionTriggered and ButtonAction) then return nil end
        local controller = player and player.ControllerIndex
        if controller == nil then return nil end
        local actions = {
            ButtonAction.ACTION_SHOOTLEFT,
            ButtonAction.ACTION_SHOOTRIGHT,
            ButtonAction.ACTION_SHOOTUP,
            ButtonAction.ACTION_SHOOTDOWN,
        }
        for _, action in ipairs(actions) do
            local ok, triggered = pcall(function() return Input.IsActionTriggered(action, controller) end)
            if ok and triggered then return GetShootDirection(action) end
        end
        return nil
    end

    local function GetSwingInputDirection(player)
        if player and player.GetShootingInput then
            local ok, input = pcall(function() return player:GetShootingInput() end)
            if ok and input and input.Length and input:Length() > 0.2 then
                return input:Normalized()
            end
        end
        -- Some controller configurations report a one-frame action before the
        -- player aim vector updates; retain that native fallback without relying on it.
        return Neverbirth.Cleaver.GetTriggeredShootDirection(player)
    end

    local function GetTearDirection(tear, player)
        if tear and tear.Velocity and tear.Velocity.Length and tear.Velocity:Length() > 0 then
            return tear.Velocity:Normalized()
        end
        if tear and tear.Position and player and player.Position then
            local delta = tear.Position - player.Position
            if delta.Length and delta:Length() > 0 then
                return delta:Normalized()
            end
        end
        return nil
    end

    local function ResolveTearOwner(tear)
        local candidate = tear and (tear.SpawnerEntity or tear.Spawner or tear.Parent)
        for _ = 1, 4 do
            if not candidate then
                break
            end
            if candidate.ToPlayer then
                local ok, player = pcall(function()
                    return candidate:ToPlayer()
                end)
                if ok and Neverbirth.Cleaver.IsEnabled(player) then
                    return player
                end
            end
            if Neverbirth.Cleaver.IsEnabled(candidate) then
                return candidate
            end
            local nextCandidate = candidate.SpawnerEntity or candidate.Spawner or candidate.Parent
            if nextCandidate == candidate then
                break
            end
            candidate = nextCandidate
        end

        -- A native tear can omit the direct Player reference. In one-player runs,
        -- the sole enabled Stranger is still an unambiguous owner.
        local enabledPlayer = nil
        for _, player in ipairs(GetPlayers()) do
            if Neverbirth.Cleaver.IsEnabled(player) then
                if enabledPlayer then
                    return nil
                end
                enabledPlayer = player
            end
        end
        return enabledPlayer
    end

    function Neverbirth:ReplaceCleaverTear(tear)
        if not lifetime.runtimeActive then return end
        local player = ResolveTearOwner(tear)
        if not player then
            return
        end
        -- Raw input drives the swing state machine. This only removes the original tear that
        -- the base character would otherwise create on the same shoot input.
        if tear.Remove then
            pcall(function() tear:Remove() end)
        elseif tear.Die then
            pcall(function() tear:Die() end)
        end
    end
    function Installers.FireTear()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, Neverbirth.ReplaceCleaverTear)
    end

    return {
        GetShootDirection = GetShootDirection,
        GetTriggeredShootDirection = Neverbirth.Cleaver.GetTriggeredShootDirection,
        GetSwingInputDirection = GetSwingInputDirection,
        GetTearDirection = GetTearDirection,
        ResolveTearOwner = ResolveTearOwner,
        ReplaceCleaverTear = Neverbirth.ReplaceCleaverTear,
        Installers = Installers,
    }
end
