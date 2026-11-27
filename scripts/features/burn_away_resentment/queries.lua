-- Private queries ownership for Burn Away the Resentment.
return function(Neverbirth, deps)
    local Installers = {}
    local GetFolkRoom = deps.World.GetFolkRoom
    local PlayerHasCollectible = deps.World.PlayerHasCollectible
    local IsVulnerableEnemy = deps.World.IsVulnerableEnemy
    local BurnAwayResentmentId = deps.ItemId
    local Source = include("scripts.systems.combat_source")

    local function PlayerHas(player)
        return PlayerHasCollectible(player, BurnAwayResentmentId)
    end

    local function GetHealth(player)
        local total = 0
        if player and player.GetHearts then
            local ok, hearts = pcall(function()
                return player:GetHearts()
            end)
            total = total + (ok and (tonumber(hearts) or 0) or 0)
        end
        if player and player.GetSoulHearts then
            local ok, soulHearts = pcall(function()
                return player:GetSoulHearts()
            end)
            total = total + (ok and (tonumber(soulHearts) or 0) or 0)
        end
        if player and player.GetBoneHearts then
            local ok, boneHearts = pcall(function()
                return player:GetBoneHearts()
            end)
            total = total + (ok and (tonumber(boneHearts) or 0) * 2 or 0)
        end
        return total
    end

    local function IsAlive(entity)
        if not entity then
            return false
        end
        if entity.Exists then
            local ok, exists = pcall(function()
                return entity:Exists()
            end)
            if ok and exists == false then
                return false
            end
        end
        if entity.IsDead then
            local ok, dead = pcall(function()
                return entity:IsDead()
            end)
            if ok and dead == true then
                return false
            end
        end
        return true
    end

    local function IsHostileEnemy(entity)
        if not IsAlive(entity) or not IsVulnerableEnemy(entity) then
            return false
        end
        if entity.HasEntityFlags and EntityFlag and EntityFlag.FLAG_FRIENDLY then
            local ok, friendly = pcall(function()
                return (entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) == true)
            end)
            if ok and friendly then
                return false
            end
        end
        return true
    end

    local function RoomHasEnemies()
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

    local function IsRoomClear()
        if RoomHasEnemies() then
            return false
        end
        local room = GetFolkRoom()
        if room and room.IsClear then
            local ok, clear = pcall(function()
                return room:IsClear()
            end)
            return ok and clear == true
        end
        return false
    end

    local function IsSacrificeRoom()
        local room = GetFolkRoom()
        if not room or not room.GetType or not RoomType or not RoomType.ROOM_SACRIFICE then
            return false
        end
        local ok, roomType = pcall(function()
            return room:GetType()
        end)
        return ok and roomType == RoomType.ROOM_SACRIFICE
    end

    local function IsBossRoom()
        local room = GetFolkRoom()
        if not room or not room.GetType or not RoomType or not RoomType.ROOM_BOSS then
            return false
        end
        local ok, roomType = pcall(function()
            return room:GetType()
        end)
        return ok and roomType == RoomType.ROOM_BOSS
    end

    local function GetDirectPlayerAttackOwner(source)
        local entity = source and source.Entity or source
        if not entity or not EntityType then
            return nil
        end
        local sourceType = entity.Type
        local directTypes = {
            EntityType.ENTITY_TEAR,
            EntityType.ENTITY_LASER,
            EntityType.ENTITY_KNIFE,
            EntityType.ENTITY_BOMB,
        }
        local allowed = false
        for _, typeId in ipairs(directTypes) do
            if typeId ~= nil and sourceType == typeId then
                allowed = true
                break
            end
        end
        if not allowed then
            return nil
        end
        local owner = entity.SpawnerEntity or entity.Spawner or entity.Parent
        local player = Source.TryPlayer(owner)
        if player then return player end
        if owner and owner.Type == EntityType.ENTITY_PLAYER then
            return owner
        end
        return nil
    end

    local function IsExcludedDamage(flags)
        flags = tonumber(flags) or 0
        local excluded = {
            DamageFlag and DamageFlag.DAMAGE_FAKE,
            DamageFlag and DamageFlag.DAMAGE_IV_BAG,
            DamageFlag and DamageFlag.DAMAGE_DEVIL,
            DamageFlag and DamageFlag.DAMAGE_CURSED_DOOR,
            DamageFlag and DamageFlag.DAMAGE_SPIKES,
            DamageFlag and DamageFlag.DAMAGE_NOKILL,
        }
        for _, flag in ipairs(excluded) do
            if flag and (flags & flag) ~= 0 then
                return true
            end
        end
        return false
    end

    local function IsEnemyDamageSource(source)
        local entity = source and source.Entity or source
        if IsHostileEnemy(entity) then
            return true
        end
        local owner = entity and (entity.SpawnerEntity or entity.Spawner or entity.Parent) or nil
        return IsHostileEnemy(owner)
    end

    return {
        PlayerHas = PlayerHas,
        GetHealth = GetHealth,
        IsAlive = IsAlive,
        IsHostileEnemy = IsHostileEnemy,
        RoomHasEnemies = RoomHasEnemies,
        IsRoomClear = IsRoomClear,
        IsSacrificeRoom = IsSacrificeRoom,
        IsBossRoom = IsBossRoom,
        GetDirectPlayerAttackOwner = GetDirectPlayerAttackOwner,
        IsExcludedDamage = IsExcludedDamage,
        IsEnemyDamageSource = IsEnemyDamageSource,
        Installers = Installers,
    }
end
