-- Owns the complete Needletick feature; installed at its original callback position.
return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local Rolls = include("scripts.systems.collectible_rng")
    local CombatSource = include("scripts.systems.combat_source")
    local Collectibles = include("scripts.systems.collectible_stats")(dependencies.IsValidItemId)
    local Items = { Needletick = assert(dependencies.ItemId) }
    local IsValidItemId = assert(dependencies.IsValidItemId)

-- Private implementation; callback methods and the chance test bridge stay public.
local NeedletickPcallBoolean, GetNeedletickTearData, GetNeedletickPlayerFromTear, NeedletickPlayerHasItem
local GetNeedletickRandomFloat, NeedletickDistance, GetNeedletickTearVariant, IsNeedletickTear
local CanNeedletickKillEntity, KillNeedletickTarget, ApplyNeedletickTearVariant, ApplyNeedletickTearVisuals
local PlayNeedletickTearAnimation, SpawnNeedletickImpactEffect, ResolveNeedletickImpact

local NeedletickRadius = 80
local NeedletickDataKey = "NeverbirthNeedletickTear"
local NeedletickResolvedKey = "NeverbirthNeedletickResolved"
local NeedletickBaseChance = 0.05
local NeedletickMaxChance = 0.15
Neverbirth.NeedletickLuckCap = 10
local NeedletickKillDamage = 999999
local NeedletickTearEntityName = "Needletick Tear"
local NeedletickTearVariant = nil
local NeedletickImpactEffectVariant = (EffectVariant and EffectVariant.POOF01) or 1
local NeedletickTearAnimation = "RegularTear6"
local NeedletickVisualSpriteScale = 1.6

function NeedletickPcallBoolean(entity, methodName)
    if not entity or not entity[methodName] then
        return false
    end

    local ok, result = pcall(function()
        return entity[methodName](entity)
    end)
    return ok and result == true
end

function GetNeedletickTearData(tear)
    if tear and tear.GetData then
        local ok, data = pcall(function()
            return tear:GetData()
        end)
        if ok and type(data) == "table" then
            return data
        end
    end

    return nil
end

function GetNeedletickPlayerFromTear(tear)
    local spawner = tear and (tear.SpawnerEntity or tear.Spawner or tear.Parent)
    local player = spawner
    player = CombatSource.TryPlayer(player) or player

    if player and player.GetCollectibleNum then
        return player
    end

    return nil
end

function NeedletickPlayerHasItem(player)
    return Collectibles.Has(player, Items.Needletick)
end

function GetNeedletickRandomFloat(player)
    if player and player.GetCollectibleRNG and IsValidItemId(Items.Needletick) then
        local rng = Rolls.Get(player, Items.Needletick)
        if rng then
            if rng.RandomFloat then
                local rollOk, value = pcall(function()
                    return rng:RandomFloat()
                end)
                if rollOk and value ~= nil then
                    return math.max(0, math.min(1, tonumber(value) or 0))
                end
            elseif rng.RandomInt then
                local rollOk, value = pcall(function()
                    return rng:RandomInt(1000000)
                end)
                if rollOk and value ~= nil then
                    return math.max(0, math.min(999999, tonumber(value) or 0)) / 1000000
                end
            end
        end
    end

    return math.random()
end

function NeedletickDistance(a, b)
    if not a or not b then
        return nil
    end

    if a.X and b.X and a.Y and b.Y then
        local dx = a.X - b.X
        local dy = a.Y - b.Y
        return math.sqrt(dx * dx + dy * dy)
    end

    local ok, delta = pcall(function()
        return a - b
    end)
    if ok and delta and delta.Length then
        local lengthOk, length = pcall(function()
            return delta:Length()
        end)
        if lengthOk then
            return tonumber(length) or nil
        end
    end

    return nil
end

function Neverbirth.GetNeedletickChance(luck)
    local value = tonumber(luck) or 0
    local scaled = NeedletickBaseChance + ((math.max(0, value) / Neverbirth.NeedletickLuckCap) * (NeedletickMaxChance - NeedletickBaseChance))
    return math.max(NeedletickBaseChance, math.min(NeedletickMaxChance, scaled))
end

function GetNeedletickTearVariant()
    if NeedletickTearVariant ~= nil then
        return NeedletickTearVariant
    end

    NeedletickTearVariant = -1
    if Isaac and Isaac.GetEntityVariantByName then
        local ok, variant = pcall(function()
            return Isaac.GetEntityVariantByName(NeedletickTearEntityName)
        end)
        if ok and type(variant) == "number" and variant > 0 then
            NeedletickTearVariant = variant
        end
    end

    return NeedletickTearVariant
end

function IsNeedletickTear(tear)
    local data = GetNeedletickTearData(tear)
    return data and data[NeedletickDataKey] == true
end

function CanNeedletickKillEntity(entity)
    if not entity or entity.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) then
        return false
    end
    if CombatSource.TryPlayer(entity) then return false end
    if entity.IsVulnerableEnemy then
        local ok, vulnerable = pcall(function()
            return entity:IsVulnerableEnemy()
        end)
        if ok and vulnerable ~= true then
            return false
        end
    end
    if NeedletickPcallBoolean(entity, "IsInvincible") or NeedletickPcallBoolean(entity, "IsInvulnerable") then
        return false
    end
    if entity.HasEntityFlags and EntityFlag then
        local friendlyFlag = EntityFlag.FLAG_FRIENDLY or 0
        local charmFlag = EntityFlag.FLAG_CHARM or 0
        local ok, hasFriendly = pcall(function()
            return entity:HasEntityFlags(friendlyFlag)
        end)
        if ok and hasFriendly then
            return false
        end
        ok, hasFriendly = pcall(function()
            return entity:HasEntityFlags(charmFlag)
        end)
        if ok and hasFriendly then
            return false
        end
    end

    local npc = entity
    if entity.ToNPC then
        local ok, converted = pcall(function()
            return entity:ToNPC()
        end)
        if ok and converted then
            npc = converted
        end
    end
    if NeedletickPcallBoolean(npc, "IsBoss") or NeedletickPcallBoolean(npc, "IsChampion") then
        return false
    end

    return true
end

function KillNeedletickTarget(entity, source)
    if entity.TakeDamage then
        local flags = (DamageFlag and (DamageFlag.DAMAGE_IGNORE_ARMOR or DamageFlag.DAMAGE_INVINCIBLE)) or 0
        local ref = source and EntityRef and EntityRef(source) or nil
        local damage = (tonumber(entity.HitPoints) or tonumber(entity.MaxHitPoints) or NeedletickKillDamage) + 999
        local ok = pcall(function()
            entity:TakeDamage(damage, flags, ref, 0)
        end)
        if ok then
            return true
        end
    end

    if entity.Die then
        local ok = pcall(function()
            entity:Die()
        end)
        if ok then
            return true
        end
    end

    return false
end

function ApplyNeedletickTearVariant(tear)
    if not tear or not tear.ChangeVariant then
        return false
    end

    local variant = GetNeedletickTearVariant()
    if not variant or variant <= 0 then
        return false
    end

    local ok = pcall(function()
        tear:ChangeVariant(variant)
    end)
    if ok then
        PlayNeedletickTearAnimation(tear, true)
        ApplyNeedletickTearVisuals(tear)
    end
    return ok
end

function ApplyNeedletickTearVisuals(tear)
    if not tear then
        return
    end

    local velocity = tear.Velocity
    if velocity then
        if velocity.GetAngleDegrees then
            pcall(function()
                tear.SpriteRotation = velocity:GetAngleDegrees()
            end)
        elseif velocity.X and velocity.Y then
            pcall(function()
                tear.SpriteRotation = math.deg(math.atan(velocity.Y, velocity.X))
            end)
        end
    end

    if Vector then
        pcall(function()
            tear.SpriteScale = Vector(NeedletickVisualSpriteScale, NeedletickVisualSpriteScale)
        end)
    end
end

function PlayNeedletickTearAnimation(tear, force)
    if not tear or not tear.GetSprite then
        return false
    end

    local spriteOk, sprite = pcall(function()
        return tear:GetSprite()
    end)
    if not spriteOk or not sprite or not sprite.Play then
        return false
    end

    local ok = pcall(function()
        sprite:Play(NeedletickTearAnimation, force == true)
    end)
    return ok
end

function SpawnNeedletickImpactEffect(position, source)
    if not (Isaac and Isaac.Spawn and position) then
        return nil
    end

    local effect = Isaac.Spawn((EntityType and EntityType.ENTITY_EFFECT) or 1000, NeedletickImpactEffectVariant, 0, position, Vector(0, 0), source)
    if effect and effect.SetColor and Color then
        pcall(function()
            effect:SetColor(Color(0.55, 0.05, 0.9, 1, 0.08, 0, 0.18), 18, 1, false, false)
        end)
    end
    return effect
end

function Neverbirth:MarkNeedletickTearOnFire(tear)
    local player = GetNeedletickPlayerFromTear(tear)
    if not NeedletickPlayerHasItem(player) then
        return
    end

    local chance = Neverbirth.GetNeedletickChance(player.Luck)
    if GetNeedletickRandomFloat(player) >= chance then
        return
    end

    local data = GetNeedletickTearData(tear)
    if data then
        data[NeedletickDataKey] = true
    end
    ApplyNeedletickTearVariant(tear)
end
function callbackInstallers.Neverbirth_MarkNeedletickTearOnFire()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, Neverbirth.MarkNeedletickTearOnFire)
end

function ResolveNeedletickImpact(tear, position)
    local data = GetNeedletickTearData(tear)
    if not data or data[NeedletickDataKey] ~= true or data[NeedletickResolvedKey] == true then
        return 0
    end

    local origin = position or tear.Position
    if not origin or not Isaac.GetRoomEntities then
        return 0
    end

    data[NeedletickResolvedKey] = true
    local killed = 0
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        if entity and entity.Position and CanNeedletickKillEntity(entity) then
            local distance = NeedletickDistance(entity.Position, origin)
            if distance and distance <= NeedletickRadius and KillNeedletickTarget(entity, tear) then
                killed = killed + 1
            end
        end
    end
    if killed > 0 then
        SpawnNeedletickImpactEffect(origin, tear)
    end

    return killed
end

function Neverbirth:HandleNeedletickTearCollision(tear, collider)
    if not IsNeedletickTear(tear) or not collider or collider.Type == ((EntityType and EntityType.ENTITY_PLAYER) or 1) then
        return nil
    end

    if collider.IsVulnerableEnemy or collider.ToNPC then
        ResolveNeedletickImpact(tear, collider.Position or tear.Position)
    end

    return nil
end
function callbackInstallers.Neverbirth_HandleNeedletickTearCollision()
    return Neverbirth:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, Neverbirth.HandleNeedletickTearCollision)
end

function Neverbirth:UpdateNeedletickTear(tear)
    if not IsNeedletickTear(tear) then
        return
    end
    PlayNeedletickTearAnimation(tear, false)
    ApplyNeedletickTearVisuals(tear)

    if tear.IsDead then
        local ok, dead = pcall(function()
            return tear:IsDead()
        end)
        if ok and dead then
            ResolveNeedletickImpact(tear, tear.Position)
        end
    end
end
function callbackInstallers.Neverbirth_UpdateNeedletickTear()
    return Neverbirth:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, Neverbirth.UpdateNeedletickTear)
end

if ModCallbacks.MC_POST_FIRE_TEAR then
    callbackInstallers.Neverbirth_MarkNeedletickTearOnFire()
end

if ModCallbacks.MC_PRE_TEAR_COLLISION then
    callbackInstallers.Neverbirth_HandleNeedletickTearCollision()
end

if ModCallbacks.MC_POST_TEAR_UPDATE then
    callbackInstallers.Neverbirth_UpdateNeedletickTear()
end

-- Instance-owned, side-effect-free query. Preserve the existing mutable public
-- cap used by GetNeedletickChance; consumers receive this function from main.
return { GetLuckCap = function() return Neverbirth.NeedletickLuckCap end }

end
