-- Private combat ownership for Burn Away the Resentment.
return function(Neverbirth, deps)
    local Installers = {}
    local Config = deps.Config
    local lifetime = deps.Lifetime
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local Queries = deps.Queries
    local Attributes = deps.Attributes
    local Presentation = deps.Presentation
    local damageDepth = 0

    local function Purge(player, state, spentLayers, multiplier)
        spentLayers = math.max(0, math.min(Config.MaxLayers, tonumber(spentLayers) or 0))
        if not player or type(state) ~= "table" or spentLayers <= 0 or state.floorSettled then
            return false
        end
        state.floorSettled = true
        state.currentLayers = 0
        state.pendingClarity = spentLayers
        state.readyRoomKey = nil
        state.pendingHurtBurst = nil
        Attributes.RefreshCache(player)
        Presentation.SpawnBurst(player, spentLayers)

        local damage = (tonumber(player.Damage) or 0) * (tonumber(multiplier) or 0)
        local burnDamage = tonumber(player.Damage) or 0
        local source = EntityRef and EntityRef(player) or nil
        damageDepth = (tonumber(damageDepth) or 0) + 1
        if Isaac and Isaac.GetRoomEntities then
            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                if Queries.IsHostileEnemy(entity) then
                    if entity.TakeDamage then
                        pcall(function()
                            entity:TakeDamage(damage, 0, source, 0)
                        end)
                    end
                    if entity.AddBurn then
                        pcall(function()
                            entity:AddBurn(source, Config.BurnDuration, burnDamage)
                        end)
                    end
                end
            end
        end
        damageDepth = math.max(0, (tonumber(damageDepth) or 0) - 1)
        return true
    end

    local function QueueHurtBurst(player, state, amount, flags, source)
        if not player or type(state) ~= "table" or state.floorSettled or state.pendingHurtBurst then
            return
        end
        local layers = tonumber(state.currentLayers) or 0
        local health = Queries.GetHealth(player)
        if layers < 3 or layers > Config.MaxLayers or health <= 0 then
            return
        end
        if Queries.IsSacrificeRoom() or Queries.IsExcludedDamage(flags) or not Queries.IsEnemyDamageSource(source) then
            return
        end
        if (tonumber(amount) or 0) >= health then
            return
        end
        state.pendingHurtBurst = {
            preHealth = health,
            layers = layers,
            frames = 3,
        }
    end

    local function ConfirmHurtBurst(player, state)
        local pending = state and state.pendingHurtBurst
        if type(pending) ~= "table" then
            return
        end
        local health = Queries.GetHealth(player)
        local dead = player and player.IsDead and player:IsDead() or false
        if not dead and health > 0 and health < (tonumber(pending.preHealth) or health) then
            Purge(player, state, pending.layers, pending.layers * Config.HurtPurgeMultiplierPerLayer)
            return
        end
        pending.frames = (tonumber(pending.frames) or 0) - 1
        if pending.frames <= 0 then
            state.pendingHurtBurst = nil
        end
    end

    function Neverbirth:HandleBurnAwayResentmentDamage(entity, amount, flags, source, countdown)
        if not lifetime.active then return end
        if (tonumber(damageDepth) or 0) > 0 then
            return nil
        end
        local player = entity and entity.ToPlayer and entity:ToPlayer() or nil
        if player then
            if Queries.PlayerHas(player) then
                local state = Neverbirth.BurnAwayResentment.GetState(player)
                QueueHurtBurst(player, state, amount, flags, source)
            end
            return nil
        end
        if not Queries.IsHostileEnemy(entity) then
            return nil
        end
        local attacker = Queries.GetDirectPlayerAttackOwner(source)
        if not attacker or not Queries.PlayerHas(attacker) then
            return nil
        end
        local state = Neverbirth.BurnAwayResentment.GetState(attacker)
        if state.floorSettled or (tonumber(state.currentLayers) or 0) ~= Config.MaxLayers then
            return nil
        end
        if state.readyRoomKey ~= GetFolkRoomKey() or not state.roomHadEnemies then
            return nil
        end
        Purge(attacker, state, Config.MaxLayers, Config.ActivePurgeMultiplier)
        return nil
    end

    function Installers.Damage()
        return Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, Neverbirth.HandleBurnAwayResentmentDamage)
    end

    local function ResetDepth()
        damageDepth = 0
    end

    return {
        Purge = Purge,
        QueueHurtBurst = QueueHurtBurst,
        ConfirmHurtBurst = ConfirmHurtBurst,
        HandleBurnAwayResentmentDamage = Neverbirth.HandleBurnAwayResentmentDamage,
        ResetDepth = ResetDepth,
        Installers = Installers,
    }
end
