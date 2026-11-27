-- Private shadows ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local GetPlayers = deps.GetPlayers
    local shadowState = deps.ShadowState
    local Queries = deps.Queries
    local Presentation = deps.Presentation

    local function CreateShadow(target, kind)
        if not Queries.IsTargetAlive(target) then
            return nil
        end
        local key = Neverbirth.Cleaver.GetEntityKey(target, kind)
        local shadow = {
            key = key,
            target = target,
            kind = kind,
            position = target.Position,
            size = tonumber(target.Size) or 20,
            roomKey = GetFolkRoomKey(),
            sprite = Presentation.CaptureShadowSprite(target),
            renderOffset = target.PositionOffset or Vector(0, 0),
        }
        Neverbirth.Cleaver.shadows[key] = shadow
        return shadow
    end

    local function RemoveShadow(shadow)
        if shadow and shadow.key then
            Neverbirth.Cleaver.shadows[shadow.key] = nil
        end
    end

    local function TrackShadows()
        local roomKey = GetFolkRoomKey()
        if not Queries.AnyEnabledPlayer() or not Queries.IsCombatRoom() then
            Neverbirth.Cleaver.shadows = {}
            shadowState.consumedPlayerShadows = {}
            shadowState.roomKey = roomKey
            return
        end
        if shadowState.roomKey ~= roomKey then
            Neverbirth.Cleaver.shadows = {}
            shadowState.consumedPlayerShadows = {}
            shadowState.roomKey = roomKey
        end
        for key, shadow in pairs(Neverbirth.Cleaver.shadows) do
            if shadow.roomKey ~= roomKey or not Queries.IsTargetAlive(shadow.target) then
                Neverbirth.Cleaver.shadows[key] = nil
            end
        end
        for _, player in ipairs(GetPlayers()) do
            local key = Neverbirth.Cleaver.GetEntityKey(player, "player")
            if not Neverbirth.Cleaver.shadows[key] and not shadowState.consumedPlayerShadows[key] then
                CreateShadow(player, "player")
            end
        end
        if Isaac and Isaac.GetRoomEntities then
            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                if Queries.IsHostileEnemy(entity) then
                    local key = Neverbirth.Cleaver.GetEntityKey(entity, "enemy")
                    if not Neverbirth.Cleaver.shadows[key] then
                        CreateShadow(entity, "enemy")
                    end
                end
            end
        end
    end

    local function GetPlayerShadowDamageUnits(attacker, shadowOwner)
        -- In co-op, the shadow owner is both the victim and the damage basis.
        local damage = tonumber(shadowOwner and shadowOwner.Damage) or 0
        return math.floor(math.max(0, damage - 3.5) / 0.5)
    end

    local function HitShadow(attacker, shadow)
        if not shadow or not Queries.IsTargetAlive(shadow.target) then RemoveShadow(shadow); return end
        local target = shadow.target
        RemoveShadow(shadow)
        if shadow.kind == "enemy" then
            if target.TakeDamage then pcall(function() target:TakeDamage((tonumber(attacker.Damage) or 0) * 2, 0, EntityRef(attacker), 0) end) end
            if Queries.IsTargetAlive(target) then CreateShadow(target, "enemy") end
        elseif shadow.kind == "player" then
            local units = GetPlayerShadowDamageUnits(attacker, target)
            if units and units > 0 and target.TakeDamage then pcall(function() target:TakeDamage(units, 0, EntityRef(attacker), 0) end) end
            shadowState.consumedPlayerShadows[shadow.key] = true
        end
    end

    return {
        CreateShadow = CreateShadow,
        RemoveShadow = RemoveShadow,
        TrackShadows = TrackShadows,
        GetPlayerShadowDamageUnits = GetPlayerShadowDamageUnits,
        HitShadow = HitShadow,
        Installers = Installers,
    }
end
