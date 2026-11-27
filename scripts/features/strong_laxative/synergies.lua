-- Aquarius-style tear sampling; direct damage remains owned by Strong Laxative.
-- REPENTOGON 1.0.12a Lua_SpawnAquariusCreep supplies the sampling formula.
return function(config, isVulnerableEnemy)
    local api = {}
    local function has(flags, name)
        local flag = TearFlags[name]
        return flag ~= nil and (flags & flag) ~= TearFlags.TEAR_NORMAL
    end
    local function owns(player, name)
        local id = CollectibleType[name]
        return id ~= nil and player:HasCollectible(id)
    end

    function api.Snapshot(player)
        local damage = math.max(0, player.Damage or 0)
        local poisonDamage = math.max(0, player:GetTearPoisonDamage())
        -- Native Aquarius supplies the status/color roll. Direct damage keeps
        -- the author's 10% base; do not inherit unrelated on-hit damage buffs.
        -- Never remove/re-add inventory to recalc stats.
        local scale = damage > 0 and poisonDamage * 0.666 / damage or 0
        local params = player:GetTearHitParams(WeaponType.WEAPON_TEARS, scale, 1, nil)
        local flags = params.TearFlags
        local cookie = owns(player, "COLLECTIBLE_PLAYDOUGH_COOKIE")
        local sampledBase = poisonDamage * 0.666
        -- Cookie's red double-damage roll has no separate public flag. Keep its
        -- native damage result; Cookie + Proptosis still needs engine calibration.
        local hitMultiplier = cookie and sampledBase > 0
            and math.max(0, params.TearDamage) / sampledBase or 1
        local baseDamage = owns(player, "COLLECTIBLE_IPECAC") and poisonDamage or damage
        local tickDamage = damage > 0 and baseDamage * 0.1 * hitMultiplier or 0
        -- Aquarius does not use the tear's distance/age attenuation.
        if has(flags, "TEAR_SHRINK") then tickDamage = tickDamage * 3 end
        local color = params.TearColor
        if not cookie then
            if has(flags, "TEAR_BURN") or has(flags, "TEAR_ACID") then
                color = Color(1, 0.85, 0.1, 0.9, 0, 0, 0)
            elseif has(flags, "TEAR_GROW") then
                color = Color(0.12, 0.12, 0.12, 0.9, 0, 0, 0)
            elseif flags == TearFlags.TEAR_NORMAL then
                color = Color(0.45, 0.6, 0.22, 0.9, 0.1, 0.04, 0)
            end
        end
        return {
            Damage = tickDamage,
            StatusDamage = poisonDamage,
            Flags = flags,
            Color = color,
            Homing = has(flags, "TEAR_HOMING"),
        }
    end

    function api.IsGroundEnemy(entity)
        if not isVulnerableEnemy(entity) then return false end
        if entity.Exists and not entity:Exists() then return false end
        if entity.IsDead and entity:IsDead() then return false end
        if entity.IsFlying and entity:IsFlying() then return false end
        if entity.HasEntityFlags then
            if entity:HasEntityFlags(EntityFlag.FLAG_FRIENDLY) then return false end
            if EntityFlag.FLAG_CHARM and entity:HasEntityFlags(EntityFlag.FLAG_CHARM) then return false end
        end
        return entity.Position ~= nil
    end

    function api.Move(effect, snapshot, entities)
        if not snapshot.Homing then return end
        effect.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE
        local target, closest
        for _, entity in ipairs(entities) do
            if api.IsGroundEnemy(entity) then
                local dx = entity.Position.X - effect.Position.X
                local dy = entity.Position.Y - effect.Position.Y
                local distance = dx * dx + dy * dy
                if closest == nil or distance < closest then target, closest = entity, distance end
            end
        end
        if not target or closest < 1 then
            effect.Velocity = Vector(0, 0)
            return
        end
        local speed = math.min(2, math.sqrt(closest))
        local factor = speed / math.sqrt(closest)
        effect.Velocity = Vector((target.Position.X - effect.Position.X) * factor,
            (target.Position.Y - effect.Position.Y) * factor)
    end

    function api.ApplyStatuses(snapshot, enemy, source)
        -- Refresh on the existing ten-update contact tick. Engine APIs own DOT,
        -- immunity, boss resistance and expiry; no parallel Lua poison/burn tick.
        local flags, duration = snapshot.Flags, config.SlowDuration
        if has(flags, "TEAR_POISON") then enemy:AddPoison(source, duration, snapshot.StatusDamage) end
        if has(flags, "TEAR_BURN") then enemy:AddBurn(source, duration, snapshot.StatusDamage) end
        if has(flags, "TEAR_FREEZE") then enemy:AddFreeze(source, duration) end
        if has(flags, "TEAR_CHARM") then enemy:AddCharmed(source, duration) end
        if has(flags, "TEAR_FEAR") then enemy:AddFear(source, duration) end
        -- These bits are above 63: keep the native BitSet128 throughout.
        if has(flags, "TEAR_ICE") then enemy:AddIce(source, duration) end
        if has(flags, "TEAR_BAIT") then enemy:AddBaited(source, duration) end
        -- SLOW is already supplied by the item's base mechanic. GROW, ACID,
        -- GLOW, EXPLOSIVE and TURN_HORIZONTAL intentionally have no extra action.
    end

    return api
end
