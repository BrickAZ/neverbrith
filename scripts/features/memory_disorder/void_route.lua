-- Run entitlement, terminal detection and native Void trapdoor creation.
return function(Neverbirth, context, deps)
    local installers = {}
    local ensureSavedState = deps.ensureSavedState
    local runtime = deps.runtime

    local VALID_TERMINALS = {
        hush = true,
        bossrush = true,
        mega_satan = true,
        ultra_greedier = true,
    }

    local function hasExistingVoidPortal()
        if context.HasExistingVoidPortal then return context.HasExistingVoidPortal() == true end
        if not (Game and GridEntityType and GridEntityType.GRID_TRAPDOOR) then return false end
        local ok, found = pcall(function()
            local room = Game():GetRoom()
            for index = 0, room:GetGridSize() - 1 do
                local grid = room:GetGridEntity(index)
                if grid and grid:GetType() == GridEntityType.GRID_TRAPDOOR and grid.VarData == 1 then
                    return true
                end
            end
            return false
        end)
        if ok then return found == true end
        return false
    end

    local function findVoidPortalPosition(room)
        local centerIndex = room:GetGridIndex(room:GetCenterPos())
        local width = room:GetGridWidth()
        local offsets = { 0, -1, 1, -width, width, -width - 1, -width + 1, width - 1, width + 1 }
        for _, offset in ipairs(offsets) do
            local index = centerIndex + offset
            if index >= 0 and index < room:GetGridSize() and not room:GetGridEntity(index) then
                local position = room:GetGridPosition(index)
                if not room.GetGridCollisionAtPos or room:GetGridCollisionAtPos(position) == 0 then
                    return position
                end
            end
        end
        return nil
    end

    local function spawnVoidPortal(roomContext)
        if context.SpawnVoidPortal then return context.SpawnVoidPortal(roomContext) end
        if not (Isaac and Isaac.GridSpawn and Game and GridEntityType and GridEntityType.GRID_TRAPDOOR) then return nil end
        local game = Game()
        local room = game:GetRoom()
        local position = findVoidPortalPosition(room)
        if not position then return nil end
        local portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, position, true)
        if not portal then return nil end
        portal.VarData = 1
        local sprite = portal.GetSprite and portal:GetSprite() or nil
        if sprite then sprite:Load("gfx/grid/voidtrapdoor.anm2", true) end
        return portal
    end

    local function trySpawnVoidPortal(roomContext)
        local saved = ensureSavedState()
        if not saved.memoryDisorderVoidUnlockedThisRun then return false end
        if type(roomContext) ~= "table" or not VALID_TERMINALS[roomContext.kind] or roomContext.clear ~= true then return false end
        if runtime.portalSpawnedThisRoom or hasExistingVoidPortal() then return false end
        local portal = spawnVoidPortal(roomContext)
        if not portal then return false end
        runtime.portalSpawnedThisRoom = true
        return true
    end

    local function liveRoomContext()
        if context.GetRoomContext then return context.GetRoomContext(runtime.terminalKind) end
        if not Game then return nil end
        local ok, result = pcall(function()
            local game = Game()
            local room = game:GetRoom()
            local level = game:GetLevel()
            local kind = runtime.terminalKind
            if RoomType and room:GetType() == RoomType.ROOM_BOSSRUSH then kind = "bossrush" end
            if not kind and game.IsGreedMode and game:IsGreedMode() and LevelStage
                and level:GetStage() == LevelStage.STAGE7_GREED and RoomType and room:GetType() == RoomType.ROOM_BOSS then
                kind = "ultra_greedier"
            end
            if not kind and LevelStage and level:GetStage() == LevelStage.STAGE4_3
                and RoomType and room:GetType() == RoomType.ROOM_BOSS then
                kind = "hush"
            end
            return { kind = kind, clear = room:IsClear() }
        end)
        return ok and result or nil
    end

    local function onNpcDeath(npc)
        if not npc or not EntityType then return end
        if EntityType.ENTITY_HUSH and npc.Type == EntityType.ENTITY_HUSH then
            runtime.terminalKind = "hush"
        elseif (EntityType.ENTITY_MEGA_SATAN and npc.Type == EntityType.ENTITY_MEGA_SATAN)
            or (EntityType.ENTITY_MEGA_SATAN_2 and npc.Type == EntityType.ENTITY_MEGA_SATAN_2) then
            runtime.terminalKind = "mega_satan"
        elseif EntityType.ENTITY_ULTRA_GREED and npc.Type == EntityType.ENTITY_ULTRA_GREED then
            local greedier = Game and Game().Difficulty == (Difficulty and Difficulty.DIFFICULTY_GREEDIER or 3)
            if greedier then runtime.terminalKind = "ultra_greedier" end
        end
    end
    function installers.onNpcDeath()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc) onNpcDeath(npc) end)
    end

    return {
        trySpawnVoidPortal = trySpawnVoidPortal,
        liveRoomContext = liveRoomContext,
        onNpcDeath = onNpcDeath,
        Installers = installers,
    }
end
