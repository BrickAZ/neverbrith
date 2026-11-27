-- Coordinates item owners and preserves the original installation phases.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    -- Native bindings are declared here; the entry chooses their installation phase.
    local callbackInstallers = {}
    local CombatSource = include("scripts.systems.combat_source")
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local IsVulnerableEnemy = dependencies.World.IsVulnerableEnemy

    function private.IsBossRoom()
        local room = GetFolkRoom()
        if not room or not room.GetType then
            return false
        end

        local ok, roomType = pcall(function()
            return room:GetType()
        end)
        return ok and RoomType and RoomType.ROOM_BOSS and roomType == RoomType.ROOM_BOSS
    end

    function private.IsBoss(entity)
        if not entity then
            return false
        end
        if entity.IsBoss then
            local ok, result = pcall(function()
                return entity:IsBoss()
            end)
            if ok and result == true then
                return true
            end
        end
        return false
    end

    function private.MarkEnemy(entity, player)
        if not IsVulnerableEnemy(entity) then
            return
        end

        local data = entity.GetData and entity:GetData() or nil
        if type(data) ~= "table" then
            return
        end

        data.NeverbirthMoonMarked = true
        data.NeverbirthMoonWaveTriggered = false
        data.NeverbirthMoonRewardEligible = true
        data.NeverbirthMoonOwnerSeed = player and player.InitSeed or nil
        private.RemoveVisual(data.NeverbirthMoonMarkVisual)
        data.NeverbirthMoonMarkVisual = private.SpawnVisual(private.IsBoss(entity) and "BossMark" or "Mark", entity, entity.Position)
    end

    function private.MarkRoomEnemies(player)
        if not Isaac.GetRoomEntities then
            return
        end

        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if IsVulnerableEnemy(entity) then
                private.MarkEnemy(entity, player)
            end
        end
    end

    function private.RemoveMark(entity)
        local data = entity and entity.GetData and entity:GetData() or nil
        if type(data) ~= "table" then
            return
        end

        data.NeverbirthMoonMarked = false
        private.RemoveVisual(data.NeverbirthMoonMarkVisual)
        data.NeverbirthMoonMarkVisual = nil
    end

    function private.GetPlayerFromSource(source)
        local entity = CombatSource.Entity(source)
        if not entity then
            return nil, nil
        end

        local directPlayer = CombatSource.TryPlayer(entity)
        if directPlayer then return directPlayer, entity end

        if EntityType and entity.Type == EntityType.ENTITY_PLAYER then
            return entity, entity
        end

        local spawner = entity.SpawnerEntity or entity.Spawner or entity.Parent
        if (not spawner) and source and source ~= entity then
            spawner = source.SpawnerEntity or source.Spawner or source.Parent
        end
        local ownerPlayer = CombatSource.TryPlayer(spawner)
        if ownerPlayer then return ownerPlayer, entity end
        if spawner and EntityType and spawner.Type == EntityType.ENTITY_PLAYER then
            return spawner, entity
        end

        return nil, entity
    end

    function private.IsPlayerTearSource(source)
        local player, sourceEntity = private.GetPlayerFromSource(source)
        local sourceType = sourceEntity and sourceEntity.Type
        if sourceType == nil and source then
            sourceType = source.Type
        end
        return player ~= nil and sourceEntity ~= nil and EntityType and sourceType == EntityType.ENTITY_TEAR, player
    end

    function private.ReleaseWave(originEntity, player)
        if not originEntity or not originEntity.Position or not player then
            return
        end

        private.SpawnVisual("Wave", nil, private.GetOwnerFootPosition(originEntity))
        local damage = (tonumber(player.Damage) or 0) * private.Config.WaveDamageMultiplier
        if damage <= 0 or not Isaac.GetRoomEntities then
            return
        end

        Neverbirth.Moon.waveDamageDepth = (tonumber(Neverbirth.Moon.waveDamageDepth) or 0) + 1
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if entity ~= originEntity and IsVulnerableEnemy(entity) and entity.Position and (entity.Position - originEntity.Position):Length() <= private.Config.WaveRadius and entity.TakeDamage then
                pcall(function()
                    entity:TakeDamage(damage, 0, EntityRef(player), 0)
                end)
            end
        end
        Neverbirth.Moon.waveDamageDepth = math.max(0, (tonumber(Neverbirth.Moon.waveDamageDepth) or 0) - 1)
    end

    function Neverbirth:HandleMoonIsBeautifulDamage(entity, amount, flags, source, countdown)
        if (tonumber(Neverbirth.Moon.waveDamageDepth) or 0) > 0 or (tonumber(Neverbirth.Moon.bossBonusDepth) or 0) > 0 then
            return nil
        end

        local state = private.roomState
        if type(state) ~= "table" or state.triggered ~= true then
            return nil
        end

        local isPlayerTear, tearPlayer = private.IsPlayerTearSource(source)
        if isPlayerTear and private.IsBossRoom() and private.IsBoss(entity) and entity.TakeDamage then
            Neverbirth.Moon.bossBonusDepth = (tonumber(Neverbirth.Moon.bossBonusDepth) or 0) + 1
            pcall(function()
                entity:TakeDamage((tonumber(amount) or 0) * 0.5, flags or 0, source, countdown or 0)
            end)
            Neverbirth.Moon.bossBonusDepth = math.max(0, (tonumber(Neverbirth.Moon.bossBonusDepth) or 0) - 1)
        end

        local hitPlayer = tearPlayer or private.GetPlayerFromSource(source)
        local data = entity and entity.GetData and entity:GetData() or nil
        if hitPlayer and type(data) == "table" and data.NeverbirthMoonMarked == true then
            if data.NeverbirthMoonWaveTriggered ~= true then
                data.NeverbirthMoonWaveTriggered = true
                if not private.IsBoss(entity) then
                    private.RemoveMark(entity)
                end
                private.ReleaseWave(entity, hitPlayer)
            end
        end

        return nil
    end
    function callbackInstallers.InstallDamage()
        return Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleMoonIsBeautifulDamage)
    end

    return { InstallDamage = callbackInstallers.InstallDamage }
end
