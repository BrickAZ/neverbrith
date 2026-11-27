-- Owns creep snapshots and the sole direct-damage path. Tower removal wins before ticking.
return function(Neverbirth, dependencies)
    local private = dependencies.Private or {}
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local CombatSource = include("scripts.systems.combat_source")
    local StrongLaxativeConfig = dependencies.Config
    local RemoveCreepIfActive = dependencies.RemoveCreepIfActive
    local ownedCreeps = setmetatable({}, { __mode = "k" })

    local function ReleaseCreep(effect, remove)
        local data = effect.GetData and effect:GetData() or nil
        if data and data.NeverbirthStrongLaxativeCreep then
            data.Owner, data.Synergy = nil, nil
        end
        ownedCreeps[effect] = nil
        if remove and effect.Remove and (not effect.Exists or effect:Exists()) then effect:Remove() end
    end

    function Neverbirth.StrongLaxative.SpawnCreep(player)
        if not player or not player.Position or not Isaac or not Isaac.Spawn then
            return nil
        end

        local snapshot = private.Synergies.Snapshot(player)
        local spawned = Isaac.Spawn(StrongLaxativeConfig.EntityEffect, StrongLaxativeConfig.CreepVariant, 0, player.Position, Vector(0, 0), player)
        local creep = spawned and spawned:ToEffect()
        if not creep then
            return nil
        end
        ownedCreeps[creep] = true

        -- Reuse the native Aquarius visual only. Its contact damage/tear flags must
        -- not run alongside our original radius and ten-update damage cadence.
        creep.CollisionDamage = 0
        creep.Timeout = StrongLaxativeConfig.CreepLifetime

        local data = creep.GetData and creep:GetData() or nil
        if type(data) == "table" then
            data.NeverbirthStrongLaxativeCreep = true
            data.Owner = player
            data.OwnerSeed = player.InitSeed
            data.Life = StrongLaxativeConfig.CreepLifetime
            data.Age = 0
            data.Radius = StrongLaxativeConfig.CreepRadius
            data.Damage = snapshot.Damage
            data.Synergy = snapshot
        end

        if creep.SetColor and Color then
            pcall(function()
                creep:SetColor(snapshot.Color, StrongLaxativeConfig.CreepLifetime, 1, false, false)
            end)
        end

        RemoveCreepIfActive(creep)

        return creep
    end

    function private.IsCreepVariant(variant)
        for _, creepVariant in ipairs(StrongLaxativeConfig.CreepVariants) do
            if type(creepVariant) == "number" and variant == creepVariant then
                return true
            end
        end
        return false
    end

    function Neverbirth:UpdateStrongLaxativeCreep(effect)
        if private.IsRuntimeActive and not private.IsRuntimeActive() then return end
        if not effect then
            return
        end

        local data = effect.GetData and effect:GetData() or nil
        if type(data) ~= "table" or data.NeverbirthStrongLaxativeCreep ~= true then
            return
        end
        ownedCreeps[effect] = true
        if data.NeverbirthTowerOfBabelRemoved or (effect.Exists and not effect:Exists()) then
            ReleaseCreep(effect, false)
            return
        end
        if not data.Owner or (data.Owner.Exists and not data.Owner:Exists())
            or (data.Owner.IsDead and data.Owner:IsDead()) then
            ReleaseCreep(effect, true)
            return
        end
        effect.CollisionDamage = 0

        data.Age = (tonumber(data.Age) or 0) + 1
        data.Life = (tonumber(data.Life) or 0) - 1
        if data.Life <= 0 then
            ReleaseCreep(effect, true)
            return
        end

        if not Isaac.GetRoomEntities then
            return
        end

        local entities = Isaac.GetRoomEntities()
        local synergies = private.Synergies
        if data.Synergy then synergies.Move(effect, data.Synergy, entities) end
        local radius = tonumber(data.Radius) or StrongLaxativeConfig.CreepRadius
        local radiusSquared = radius * radius
        local source = EntityRef(data.Owner or effect)
        for _, entity in ipairs(entities) do
            if entity ~= effect and synergies.IsGroundEnemy(entity) and effect.Position then
                local dx = (entity.Position.X or 0) - (effect.Position.X or 0)
                local dy = (entity.Position.Y or 0) - (effect.Position.Y or 0)
                if dx * dx + dy * dy <= radiusSquared then
                    if entity.AddSlowing then
                        pcall(function()
                            entity:AddSlowing(source, StrongLaxativeConfig.SlowDuration, 0.5, Color and Color(0.45, 0.65, 0.2, 1, 0, 0, 0) or nil)
                        end)
                    end
                    if ((tonumber(data.Age) or 0) % StrongLaxativeConfig.CreepDamageInterval) == 0 and entity.TakeDamage then
                        if data.Synergy then synergies.ApplyStatuses(data.Synergy, entity, source) end
                        pcall(function()
                            entity:TakeDamage(tonumber(data.Damage) or 0, 0, source, 0)
                        end)
                    end
                end
            end
        end
    end
    function callbackInstallers.Neverbirth_UpdateStrongLaxativeCreep()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.UpdateStrongLaxativeCreep, StrongLaxativeConfig.CreepVariant)
    end

    local function InstallEffectCallback()
        if ModCallbacks.MC_POST_EFFECT_UPDATE then
            callbackInstallers.Neverbirth_UpdateStrongLaxativeCreep()
        end
    end

    function private.GetDamageSource(source)
        return CombatSource.Entity(source)
    end

    function Neverbirth:BlockStrongLaxativeCreepDamage(entity, amount, flags, source)
        if private.IsRuntimeActive and not private.IsRuntimeActive() then return end
        local player = entity and entity.ToPlayer and entity:ToPlayer()
        if not player or Neverbirth.StrongLaxative.GetCopyCount(player) <= 0 then
            return nil
        end

        local sourceEntity = private.GetDamageSource(source)
        local sourceData = sourceEntity and sourceEntity.GetData and sourceEntity:GetData() or nil
        if type(sourceData) == "table" and sourceData.NeverbirthStrongLaxativeCreep == true then
            return false
        end

        if sourceEntity and sourceEntity.Type == StrongLaxativeConfig.EntityEffect and private.IsCreepVariant(sourceEntity.Variant) then
            return false
        end

        return nil
    end
    function callbackInstallers.Neverbirth_BlockStrongLaxativeCreepDamage()
        return Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.BlockStrongLaxativeCreepDamage, EntityType and EntityType.ENTITY_PLAYER or 1)
    end

    local function InstallDamageCallback()
        callbackInstallers.Neverbirth_BlockStrongLaxativeCreepDamage()
    end

    local function ResetRuntime()
        -- Only tracked owned effects may be removed. No Game/room access during unload.
        for effect in pairs(ownedCreeps) do ReleaseCreep(effect, true) end
        ownedCreeps = setmetatable({}, { __mode = "k" })
    end
    return { InstallEffectCallback = InstallEffectCallback, InstallDamageCallback = InstallDamageCallback,
        ResetRuntime = ResetRuntime }
end
