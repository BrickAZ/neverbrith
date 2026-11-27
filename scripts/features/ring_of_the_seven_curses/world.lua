-- Private world ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local SLOT_SECONDARY = deps.State.SLOT_SECONDARY
    local REQUIRED_CURSES = deps.State.REQUIRED_CURSES
    local PROTECTED_COLLECTIBLES = deps.State.PROTECTED_COLLECTIBLES
    local DebugLog = deps.State.DebugLog
    local Save = deps.State.Save
    local GetPlayerKey = deps.State.GetPlayerKey
    local GetPlayerState = deps.State.GetPlayerState
    local AnyPlayerActive = deps.State.AnyPlayerActive
    local GetRoomKey = deps.State.GetRoomKey
    local GetCollectibleCount = deps.Inventory.GetCollectibleCount
    local RequestCaches = deps.Inventory.RequestCaches
    local DropHeldTrinkets = deps.Inventory.DropHeldTrinkets
    local EnsureSlotTrinket = deps.Inventory.EnsureSlotTrinket
    local RemoveBannedSources = deps.Inventory.RemoveBannedSources
    local ClampHealth = deps.Inventory.ClampHealth
    local ClampResources = deps.Inventory.ClampResources

    local function IsValidEnemy(npc)
        if not npc then return false end
        if npc.Exists and not npc:Exists() then return false end
        if npc.IsDead and npc:IsDead() then return false end
        if npc.IsActiveEnemy and not npc:IsActiveEnemy(false) then return false end
        if npc.IsVulnerableEnemy and not npc:IsVulnerableEnemy() then return false end
        if npc.HasEntityFlags then
            local friendly = (EntityFlag and EntityFlag.FLAG_FRIENDLY) or 1
            local charm = (EntityFlag and EntityFlag.FLAG_CHARM) or 2
            if npc:HasEntityFlags(friendly) or npc:HasEntityFlags(charm) then return false end
        end
        return (npc.MaxHitPoints or 0) > 0
    end

    local function DoubleNpcHealth(npc)
        if not AnyPlayerActive() or not IsValidEnemy(npc) then return false end
        local data = npc.GetData and npc:GetData() or nil
        if data and data.NeverbirthSevenCursesHealthDoubled then return false end
        if data then data.NeverbirthSevenCursesHealthDoubled = true end
        npc.MaxHitPoints = math.max(0, npc.MaxHitPoints or 0) * 2
        npc.HitPoints = math.min(npc.MaxHitPoints, math.max(0, npc.HitPoints or 0) * 2)
        return true
    end

    local function ScanCurrentRoomEnemies()
        if not AnyPlayerActive() or not Isaac or not Isaac.GetRoomEntities then return end
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            local npc = entity.ToNPC and entity:ToNPC() or nil
            if npc then DoubleNpcHealth(npc) end
        end
    end

    local function ForceCurses(curses)
        return (tonumber(curses) or 0) | REQUIRED_CURSES
    end

    local function EnforceCurrentFloorCurses()
        if not AnyPlayerActive() then return false end
        local game = Game and Game()
        local level = game and game.GetLevel and game:GetLevel()
        if not level or not level.AddCurse then return false end
        local current = level.GetCurses and level:GetCurses() or 0
        local missing = REQUIRED_CURSES & (~current)
        if missing ~= 0 then level:AddCurse(missing, false); return true end
        return false
    end

    local function ActivatePlayer(player)
        if not player then return false end
        local state = GetPlayerState(player, true)
        if state.active then return false end

        state.active = true
        state.roomProgress = 0
        state.lastRoomKey = GetRoomKey()
        RemoveBannedSources(player)
        state.nativeSecondary = player.GetActiveItem and (player:GetActiveItem(SLOT_SECONDARY) or 0) or 0
        state.protectedCounts = {}
        for _, itemId in ipairs(PROTECTED_COLLECTIBLES) do
            state.protectedCounts[tostring(itemId)] = GetCollectibleCount(player, itemId)
        end
        DropHeldTrinkets(player)
        EnsureSlotTrinket(player)
        RequestCaches(player)
        ClampResources(player)
        ClampHealth(player)
        EnforceCurrentFloorCurses()
        ScanCurrentRoomEnemies()
        Save()
        DebugLog("run contract activated for player " .. GetPlayerKey(player))
        return true
    end

    return {
        IsValidEnemy = IsValidEnemy,
        DoubleNpcHealth = DoubleNpcHealth,
        ScanCurrentRoomEnemies = ScanCurrentRoomEnemies,
        ForceCurses = ForceCurses,
        EnforceCurrentFloorCurses = EnforceCurrentFloorCurses,
        ActivatePlayer = ActivatePlayer,
    }
end
