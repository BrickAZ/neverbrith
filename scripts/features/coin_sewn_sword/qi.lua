-- Owns projectile creation, movement, collision and one-hit/one-block bookkeeping.
return function(Neverbirth, dependencies)
    local Runtime = assert(dependencies.Runtime)
    local ownedEffects = setmetatable({}, { __mode = "k" })
    local CoinSwordEntityProjectile = (EntityType and EntityType.ENTITY_PROJECTILE) or 9
    local CoinSwordSpoonBender = (CollectibleType and CollectibleType.COLLECTIBLE_SPOON_BENDER) or 3
    local CoinSwordLostContact = (CollectibleType and CollectibleType.COLLECTIBLE_LOST_CONTACT) or 213
    local CoinSwordHomingTurnRate = 0.18
    local GetFolkRoom = dependencies.World.GetFolkRoom
    local PlayerHasCollectible = dependencies.World.PlayerHasCollectible
    local IsVulnerableEnemy = dependencies.World.IsVulnerableEnemy
    local DebugLog = dependencies.Log
    local GetCoinSwordBaseDirection = dependencies.Aiming.GetBaseDirection
    local PlayCoinSwordAnimation = dependencies.Presentation.Play
    local GetCoinSwordAnimationName = dependencies.Presentation.AnimationName
    local coinSwordQiVariant = nil
    local COIN_SWORD_MODE_CONFIGS = dependencies.Rules.COIN_SWORD_MODE_CONFIGS
    local COIN_SWORD_SPEED = dependencies.Rules.COIN_SWORD_SPEED
    local COIN_SWORD_LIFE = dependencies.Rules.COIN_SWORD_LIFE
    local COIN_SWORD_ENTITY_EFFECT = dependencies.Rules.COIN_SWORD_ENTITY_EFFECT
    local COIN_SWORD_FALLBACK_EFFECT = dependencies.Rules.COIN_SWORD_FALLBACK_EFFECT
    local COIN_SWORD_DISAPPEAR_LIFE = dependencies.Rules.COIN_SWORD_DISAPPEAR_LIFE
    local COIN_SWORD_DAMAGE_FLAGS = dependencies.Rules.COIN_SWORD_DAMAGE_FLAGS
    local function GetCoinSwordQiVariant()
        if coinSwordQiVariant ~= nil then
            return coinSwordQiVariant
        end

        coinSwordQiVariant = -1
        if Isaac.GetEntityVariantByName then
            local ok, variant = pcall(function()
                return Isaac.GetEntityVariantByName("Coin Sword Qi")
            end)
            if ok and type(variant) == "number" and variant > 0 then
                coinSwordQiVariant = variant
            end
        end

        if coinSwordQiVariant <= 0 then
            DebugLog("[neverbirth] Coin Sword Qi variant not found; falling back to default effect")
        end

        return coinSwordQiVariant
    end

    local function GetCoinSwordHitboxConfig(mode)
        local config = COIN_SWORD_MODE_CONFIGS[mode or "normal"] or COIN_SWORD_MODE_CONFIGS.normal
        return config.length, config.width, config.back
    end

    local function SpawnCoinSwordQi(player, damageMultiplier, mode, direction, forwardOffset)
        if not Runtime.running or Runtime.disposed then return nil end
        direction = (direction and direction:Length() > 0) and direction:Normalized() or GetCoinSwordBaseDirection(player)
        local velocity = direction * COIN_SWORD_SPEED
        local config = COIN_SWORD_MODE_CONFIGS[mode or "normal"] or COIN_SWORD_MODE_CONFIGS.normal
        local spawnOffset = config.spawnOffset or 28
        spawnOffset = spawnOffset + (tonumber(forwardOffset) or 0)
        local position = (player and player.Position or Vector(320, 280)) + direction * spawnOffset
        local variant = GetCoinSwordQiVariant()
        local spawnVariant = variant > 0 and variant or COIN_SWORD_FALLBACK_EFFECT
        local effect = Isaac.Spawn and Isaac.Spawn(COIN_SWORD_ENTITY_EFFECT, spawnVariant, 0, position, velocity, player) or nil

        if not effect then
            return nil
        end
        ownedEffects[effect] = true

        local data = effect.GetData and effect:GetData() or {}
        data.NeverbirthCoinSwordQi = true
        data.Owner = player
        data.OwnerSeed = player and player.InitSeed
        data.Direction = direction
        data.Velocity = velocity
        data.Damage = (tonumber(player and player.Damage) or 3.5) * damageMultiplier
        data.Mode = mode or "normal"
        data.Life = COIN_SWORD_LIFE + (mode == "empowered" and 8 or 0)
        data.HitEnemies = {}
        data.BlockedProjectiles = {}
        data.Piercing = mode == "empowered"
        data.Homing = PlayerHasCollectible(player, CoinSwordSpoonBender)
        data.Shielded = PlayerHasCollectible(player, CoinSwordLostContact)
        data.Length, data.Width, data.BackLength = GetCoinSwordHitboxConfig(data.Mode)

        PlayCoinSwordAnimation(effect, data.Mode, direction)
        dependencies.Presentation.SetField(effect, "DepthOffset", data.Piercing and 160 or 80)
        dependencies.Presentation.SetField(effect, "RenderZOffset", data.Piercing and 14000 or 10000)
        DebugLog("[neverbirth] Coin Sword Qi spawn variant=" .. tostring(variant) ..
            " spawnVariant=" .. tostring(spawnVariant) ..
            " mode=" .. tostring(data.Mode) ..
            " animation=" .. tostring(GetCoinSwordAnimationName(data.Mode)))

        return effect
    end

    local function EnemyHitKey(entity)
        return tostring((entity and entity.InitSeed) or entity)
    end

    local function IsCoinSwordEnemyProjectile(entity, data)
        if not entity or entity.Type ~= CoinSwordEntityProjectile or not entity.Position then
            return false
        end

        if data and data.Owner and entity.SpawnerEntity and entity.SpawnerEntity.InitSeed == data.Owner.InitSeed then
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

    local function RemoveCoinSwordBlockedProjectile(projectile)
        if not projectile then
            return
        end

        if projectile.Die then
            local ok = pcall(function()
                projectile:Die()
            end)
            if ok then
                return
            end
        end

        if projectile.Remove then
            pcall(function()
                projectile:Remove()
            end)
        end
    end

    local function IsEnemyInsideCoinSwordHitbox(effect, enemy, data)
        if not effect or not enemy or not enemy.Position or not data or not data.Direction then
            return false
        end

        local relative = enemy.Position - effect.Position
        local direction = data.Direction
        local forward = relative.X * direction.X + relative.Y * direction.Y
        local backLength = tonumber(data.BackLength) or 36
        local length = tonumber(data.Length) or COIN_SWORD_MODE_CONFIGS.normal.length
        local width = tonumber(data.Width) or COIN_SWORD_MODE_CONFIGS.normal.width
        local radius = width / 2
        if forward < -backLength - radius or forward > length + radius then
            return false
        end

        local perpendicular = math.abs(relative.X * -direction.Y + relative.Y * direction.X)
        if forward >= -backLength and forward <= length then
            return perpendicular <= radius
        end

        local capCenter = forward < -backLength and -backLength or length
        local capForward = forward - capCenter
        return (capForward * capForward + perpendicular * perpendicular) <= (radius * radius)
    end

    local function RemoveCoinSwordEffect(effect)
        ownedEffects[effect] = nil
        local data = effect and effect.GetData and effect:GetData()
        if data then
            data.Owner, data.HitEnemies, data.BlockedProjectiles = nil, nil, nil
        end
        if effect and effect.Remove then
            effect:Remove()
        end
    end

    local function ReleaseAll()
        for effect in pairs(ownedEffects) do RemoveCoinSwordEffect(effect) end
    end

    local function StartCoinSwordDisappear(effect, data)
        if not effect then
            return
        end

        data = data or (effect.GetData and effect:GetData()) or {}
        if data.Disappearing then
            return
        end

        data.Disappearing = true
        data.Life = COIN_SWORD_DISAPPEAR_LIFE
        data.Velocity = Vector(0, 0)
        effect.Velocity = Vector(0, 0)

        dependencies.Presentation.PlayDisappear(effect)
    end

    function Neverbirth:UpdateCoinSwordQi(effect)
        if not Runtime.running or Runtime.disposed then return end
        if not effect then
            return
        end

        local data = effect.GetData and effect:GetData() or nil
        if type(data) ~= "table" or not data.NeverbirthCoinSwordQi then
            return
        end

        if data.Disappearing then
            data.Life = (tonumber(data.Life) or 0) - 1
            if data.Life <= 0 then
                RemoveCoinSwordEffect(effect)
            end
            return
        end

        data.Life = (tonumber(data.Life) or 0) - 1
        if data.Life <= 0 then
            RemoveCoinSwordEffect(effect)
            return
        end

        if data.Homing then
            local targetDirection = dependencies.Aiming.GetNearestEnemyDirectionFromPosition(effect.Position)
            if targetDirection and targetDirection:Length() > 0 then
                local currentDirection = data.Direction
                if not currentDirection or currentDirection:Length() <= 0 then
                    currentDirection = Vector(1, 0)
                else
                    currentDirection = currentDirection:Normalized()
                end

                local blended = (currentDirection * (1 - CoinSwordHomingTurnRate)) + (targetDirection * CoinSwordHomingTurnRate)
                if blended:Length() > 0 then
                    data.Direction = blended:Normalized()
                    data.Velocity = data.Direction * COIN_SWORD_SPEED
                    effect.Velocity = data.Velocity
                    dependencies.Presentation.UpdateDirection(effect, data.Direction)
                end
            end
        end

        if data.Velocity then
            effect.Position = effect.Position + data.Velocity
        end

        local room = GetFolkRoom()
        if room and room.IsPositionInRoom then
            local ok, inRoom = pcall(function()
                return room:IsPositionInRoom(effect.Position, 16)
            end)
            if ok and not inRoom then
                RemoveCoinSwordEffect(effect)
                return
            end
        end

        if not Isaac.GetRoomEntities then
            return
        end

        local owner = data.Owner
        local source = EntityRef(owner or effect)
        if data.Shielded then
            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                if entity ~= effect and IsCoinSwordEnemyProjectile(entity, data) and IsEnemyInsideCoinSwordHitbox(effect, entity, data) then
                    local key = EnemyHitKey(entity)
                    data.BlockedProjectiles = data.BlockedProjectiles or {}
                    if not data.BlockedProjectiles[key] then
                        data.BlockedProjectiles[key] = true
                        RemoveCoinSwordBlockedProjectile(entity)
                        if not data.Piercing then
                            StartCoinSwordDisappear(effect, data)
                            return
                        end
                    end
                end
            end
        end

        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if entity ~= effect and IsVulnerableEnemy(entity) and IsEnemyInsideCoinSwordHitbox(effect, entity, data) then
                local key = EnemyHitKey(entity)
                data.HitEnemies = data.HitEnemies or {}
                if not data.HitEnemies[key] then
                    data.HitEnemies[key] = true
                    if entity.TakeDamage then
                        entity:TakeDamage(tonumber(data.Damage) or 0, COIN_SWORD_DAMAGE_FLAGS, source, 0)
                    end
                    if not data.Piercing then
                        StartCoinSwordDisappear(effect, data)
                        return
                    end
                end
            end
        end
    end

    if ModCallbacks.MC_POST_EFFECT_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.UpdateCoinSwordQi)
    end

    return { Spawn = SpawnCoinSwordQi, ReleaseAll = ReleaseAll }
end
