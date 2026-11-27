-- Private queries ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local GetFolkRoom = deps.World.GetFolkRoom
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local IsVulnerableEnemy = deps.World.IsVulnerableEnemy
    local GetPlayers = deps.GetPlayers

    local function ResolvePlayerType()
        if Neverbirth.Cleaver.Config and Neverbirth.Cleaver.Config.Registered ~= true then return nil end
        if Isaac and Isaac.GetPlayerTypeByName then
            local ok, playerType = pcall(function()
                return Isaac.GetPlayerTypeByName("Stranger", false)
            end)
            if ok and type(playerType) == "number" and playerType >= 0 then
                return playerType
            end
        end
        return nil
    end

    local function IsStranger(player)
        if Neverbirth.Cleaver.Config.Registered ~= true then return false end
        local playerType = Neverbirth.Cleaver.Config.PlayerType or ResolvePlayerType()
        Neverbirth.Cleaver.Config.PlayerType = playerType
        if playerType == nil or not player then
            return false
        end
        local actualType = nil
        if player.GetPlayerType then
            local ok, value = pcall(function()
                return player:GetPlayerType()
            end)
            if ok then
                actualType = value
            end
        end
        actualType = actualType or player.PlayerType
        return actualType == playerType
    end

    function Neverbirth.Cleaver.IsEnabled(player)
        -- Cleaver is Stranger's character mechanic. The starting collectible remains visible,
        -- but losing it must not turn off the character's attack, shadows, or tear replacement.
        return IsStranger(player)
    end

    function Neverbirth.Cleaver.GetState(player)
        if not player then
            return nil
        end
        local key = GetFolkPlayerKey(player)
        local state = Neverbirth.Cleaver.states[key]
        if type(state) ~= "table" then
            state = {
                player = player,
                cooldown = 0,
                rawDamage = Neverbirth.Cleaver.Config.IsaacBaseDamage,
                rawTears = Neverbirth.Cleaver.Config.BaseTears,
                rawRange = Neverbirth.Cleaver.Config.BaseRange,
                rawShotSpeed = Neverbirth.Cleaver.Config.BaseShotSpeed,
                nextSwingVariant = "A",
                needsDamageRefresh = false,
            }
            Neverbirth.Cleaver.states[key] = state
        end
        state.player = player
        return state
    end

    function Neverbirth.Cleaver.GetEntityKey(entity, kind)
        return tostring(kind or "entity") .. ":" .. tostring((entity and entity.InitSeed) or entity)
    end

    local function IsTargetAlive(target)
        if not target or not target.Position then
            return false
        end
        if target.Exists then
            local ok, exists = pcall(function()
                return target:Exists()
            end)
            if ok and exists == false then
                return false
            end
        end
        if target.IsDead then
            local ok, dead = pcall(function()
                return target:IsDead()
            end)
            if ok and dead then
                return false
            end
        end
        return true
    end

    local function IsHostileEnemy(entity)
        if not IsTargetAlive(entity) then
            return false
        end
        local active = nil
        if entity.IsActiveEnemy then
            local ok, result = pcall(function()
                return entity:IsActiveEnemy(false)
            end)
            if ok then
                active = result == true
            end
        end
        if active == false or (active == nil and not IsVulnerableEnemy(entity)) then
            return false
        end
        if entity.HasEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
            local ok, friendly = pcall(function()
                return entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY)
            end)
            if ok and friendly then
                return false
            end
        end
        return true
    end

    local function IsCombatRoom()
        local room = GetFolkRoom()
        if not room or not room.IsClear then
            return false
        end
        local ok, clear = pcall(function()
            return room:IsClear()
        end)
        if not ok or clear then
            return false
        end
        if not Isaac or not Isaac.GetRoomEntities then
            return false
        end
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsHostileEnemy(entity) then
                return true
            end
        end
        return false
    end

    local function AnyEnabledPlayer()
        for _, player in ipairs(GetPlayers()) do
            if Neverbirth.Cleaver.IsEnabled(player) then
                return true
            end
        end
        return false
    end

    return {
        ResolvePlayerType = ResolvePlayerType,
        IsStranger = IsStranger,
        IsEnabled = Neverbirth.Cleaver.IsEnabled,
        GetState = Neverbirth.Cleaver.GetState,
        GetEntityKey = Neverbirth.Cleaver.GetEntityKey,
        IsTargetAlive = IsTargetAlive,
        IsHostileEnemy = IsHostileEnemy,
        IsCombatRoom = IsCombatRoom,
        AnyEnabledPlayer = AnyEnabledPlayer,
        Installers = Installers,
    }
end
