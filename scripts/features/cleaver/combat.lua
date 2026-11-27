-- Private combat ownership for Cleaver.
return function(Neverbirth, deps)
    local Installers = {}
    local GetFolkRoomKey = deps.World.GetFolkRoomKey
    local GetFolkPlayerKey = deps.World.GetFolkPlayerKey
    local lifetime = deps.Lifetime
    local AttackOwnership = include("scripts.systems.attack_ownership")
    local Queries = deps.Queries
    local Geometry = deps.Geometry
    local Presentation = deps.Presentation
    local Shadows = deps.Shadows

    local function CanSwing(state)
        return state and state.swing == nil and (tonumber(state.cooldown) or 0) <= 0
    end

    local function RemoveSwing(state)
        if not state or not state.swing then return end
        local knife = state.swing.nativeKnife
        if knife and knife.Exists and knife.Remove then
            local ok, exists = pcall(function() return knife:Exists() end)
            if ok and exists then pcall(function() knife:Remove() end) end
        end
        state.swing = nil
    end

    local function PushEnemy(enemy, direction, speed)
        if not enemy or not direction or (tonumber(speed) or 0) <= 0 then return end
        local push = direction * speed
        if enemy.AddVelocity then pcall(function() enemy:AddVelocity(push) end)
        elseif enemy.Velocity then enemy.Velocity = enemy.Velocity + push end
    end

    local function HitEnemyBody(attacker, enemy, direction)
        if enemy.TakeDamage then pcall(function() enemy:TakeDamage(Neverbirth.Cleaver.Config.FixedBodyDamage, 0, EntityRef(attacker), 0) end) end
        PushEnemy(enemy, direction, Neverbirth.Cleaver.Config.SwingKnockback)
    end

    local function GetNativeKnifeState(knife)
        if not knife or not knife.GetData then return nil end
        local ok, data = pcall(function() return knife:GetData() end)
        local ownerKey = ok and data and data.NeverbirthCleaverOwnerKey
        local state = ownerKey and Neverbirth.Cleaver.states[ownerKey]
        if state and state.swing and state.swing.nativeKnife == knife then
            return state
        end
        return nil
    end

    local function ResolveKnifeShadowHits(state, previousProgress, currentProgress)
        local swing, player = state and state.swing, state and state.player
        if not swing or not player then return end
        local hits = {}
        for key, shadow in pairs(Neverbirth.Cleaver.shadows) do
            if not swing.hitShadows[key] and shadow.roomKey == GetFolkRoomKey() and shadow.position then
                if Geometry.IsInsideSwingSweep(swing, shadow.position, shadow.size, previousProgress, currentProgress) then
                    swing.hitShadows[key] = true
                    hits[#hits + 1] = shadow
                end
            end
        end
        for _, shadow in ipairs(hits) do Shadows.HitShadow(player, shadow) end
    end

    local function ResolveSwingBodyHits(state, previousProgress, currentProgress)
        local swing, player = state and state.swing, state and state.player
        if not swing or not player or not (Isaac and Isaac.GetRoomEntities) then return end
        local hits = {}
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            if Queries.IsHostileEnemy(entity) and entity.Position then
                local key = Neverbirth.Cleaver.GetEntityKey(entity, "enemy")
                if not swing.hitBodies[key]
                    and Geometry.IsInsideSwingSweep(swing, entity.Position, entity.Size, previousProgress, currentProgress) then
                    swing.hitBodies[key] = true
                    hits[#hits + 1] = entity
                end
            end
        end
        for _, enemy in ipairs(hits) do HitEnemyBody(player, enemy, swing.direction) end
    end

    local function SpawnSwingHitbox(state)
        local swing, player = state and state.swing, state and state.player
        if not swing or not player or swing.hitboxSpawned then return nil end
        if not (Isaac and Isaac.Spawn and EntityType and EntityType.ENTITY_KNIFE) then return nil end
        -- The native knife is an invisible lifecycle carrier only; sweep damage is resolved in UpdateSwing.
        local ok, entity = pcall(function()
            return Isaac.Spawn(EntityType.ENTITY_KNIFE, Neverbirth.Cleaver.Config.KnifeVariant, Neverbirth.Cleaver.Config.KnifeSubType, player.Position, Vector(0, 0), player)
        end)
        if not ok or not entity then return nil end
        local knife = entity.ToKnife and entity:ToKnife() or entity
        if not knife then return nil end
        local data = knife.GetData and knife:GetData() or nil
        if data then
            data.NeverbirthCleaverOwnerKey = GetFolkPlayerKey(player)
            data.targetPosition = Vector(0, 0)
            data.direction = swing.direction
            data.age = 0
            data.hitStarted = true
            data.shadowResolved = true
        end
        knife.SpawnerEntity = player
        knife.Parent = player
        knife.Target = knife
        knife.Size = 1
        knife.Rotation = swing.direction.GetAngleDegrees and swing.direction:GetAngleDegrees() or 0
        knife.TargetPosition = Vector(0, 0)
        knife.SpriteOffset = Vector(0, 0)
        knife.Velocity = player.Velocity or Vector(0, 0)
        if EntityGridCollisionClass and EntityGridCollisionClass.GRIDCOLL_NONE ~= nil then knife.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_NONE end
        if EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE ~= nil then knife.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE end
        knife.CollisionDamage = 0
        if knife.Visible ~= nil then knife.Visible = false end
        if knife.ClearEntityFlags and EntityFlag and EntityFlag.FLAG_APPEAR then pcall(function() knife:ClearEntityFlags(EntityFlag.FLAG_APPEAR) end) end
        swing.nativeKnife = knife
        swing.hitboxSpawned = true
        return knife
    end

    local function UpdateSwing(state)
        if state and AttackOwnership.AvadaOwnsAttack(Neverbirth, state.player) then
            RemoveSwing(state)
            return
        end
        local swing = state and state.swing
        if not swing then return end
        local duration = tonumber(Neverbirth.Cleaver.Config.SwingDurationTicks)
            or tonumber(Neverbirth.Cleaver.Config.CleaverVisualTimeout) or 22
        local previousProgress = tonumber(swing.sweepProgress) or 0
        swing.tick = (tonumber(swing.tick) or 0) + 1
        swing.frame = swing.tick -- retained for debugging; the full authored swing is 22 game ticks.
        local currentProgress = math.min(1, swing.tick / duration)
        swing.origin = Geometry.GetPlayerBodyWorldPosition(state.player)
        swing.range = Neverbirth.Cleaver.GetSwingRange(state.player)
        swing.sweepProgress = currentProgress
        -- Evaluate only the newly swept fan segment, not a repeated full-radius circle.
        ResolveSwingBodyHits(state, previousProgress, currentProgress)
        ResolveKnifeShadowHits(state, previousProgress, currentProgress)
        local visual = swing.visual
        local hitNow = false
        if visual and visual.sprite then
            -- The actor is authored at 30 FPS while game ticks are 60 FPS. Advance it
            -- every two ticks, keeping the complete 11-frame A/B swing on-screen for 22 ticks.
            local animationStep = tonumber(Neverbirth.Cleaver.Config.AnimationTicksPerFrame) or 2
            if swing.tick < duration and swing.tick % animationStep == 0 and visual.sprite.Update then
                pcall(function() visual.sprite:Update() end)
                visual.animationUpdates = (tonumber(visual.animationUpdates) or 0) + 1
            end
            if visual.sprite.IsEventTriggered then
                local ok, triggered = pcall(function() return visual.sprite:IsEventTriggered("Hit") end)
                hitNow = ok and triggered == true
            end
        end
        local fallbackTick = tonumber(Neverbirth.Cleaver.Config.SwingCarrierFallbackTick)
            or tonumber(Neverbirth.Cleaver.Config.SwingHitFrame) or 10
        if not hitNow and swing.tick >= fallbackTick then hitNow = true end
        if hitNow then SpawnSwingHitbox(state) end
        if swing.tick >= duration then RemoveSwing(state) end
    end

    function Neverbirth.Cleaver.TrySwing(player, direction)
        if AttackOwnership.AvadaOwnsAttack(Neverbirth, player) then return false end
        if not Neverbirth.Cleaver.IsEnabled(player) then return false end
        local state = Neverbirth.Cleaver.GetState(player)
        if not CanSwing(state) or not direction or not direction.Length or direction:Length() <= 0 then return false end
        direction = direction:Normalized()
        local variant = state.nextSwingVariant == "B" and "B" or "A"
        state.nextSwingVariant = variant == "A" and "B" or "A"
        state.holdDirection = direction
        state.lastSwingDirection = direction
        state.lastSwingVariant = variant
        state.cooldown = tonumber(Neverbirth.Cleaver.Config.SwingCooldownFrames) or 10
        state.swing = {
            direction = direction,
            variant = variant,
            tick = 0,
            frame = 0,
            sweepProgress = 0,
            hitBodies = {},
            hitShadows = {},
            visual = Presentation.CreateSwingVisual(player, direction, variant),
        }
        return true
    end

    function Neverbirth:UpdateCleaverKnife(knife)
        if not lifetime.runtimeActive then return end
        local state = GetNativeKnifeState(knife)
        if not state then return end
        local swing, player = state.swing, state.player
        local data = knife.GetData and knife:GetData() or nil
        if not swing or not player or not data then
            if knife.Remove then pcall(function() knife:Remove() end) end
            return
        end
        if player.Exists then
            local ok, exists = pcall(function() return player:Exists() end)
            if ok and not exists then
                if knife.Remove then pcall(function() knife:Remove() end) end
                return
            end
        end
        -- Reset the private native carrier after initialization; Lua owns all strike settlement.
        knife.Variant = 0
        if data.targetPosition then knife.Position = player.Position + data.targetPosition end
        knife.Velocity = player.Velocity or Vector(0, 0)
        data.age = (tonumber(data.age) or 0) + 1
        local sprite = knife.GetSprite and knife:GetSprite() or nil
        -- Collision is intentionally disabled: the Lua sweep owns all body and shadow settlement.
        local done = false
        if sprite and sprite.IsFinished and sprite.GetAnimation then
            local animation = sprite:GetAnimation()
            local ok, finished = pcall(function() return sprite:IsFinished(animation) end)
            done = ok and finished == true
        end
        if done or data.age >= (tonumber(Neverbirth.Cleaver.Config.CleaverVisualTimeout) or 14) then
            if knife.Remove then pcall(function() knife:Remove() end) end
        end
    end
    function Installers.KnifeUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_KNIFE_UPDATE, Neverbirth.UpdateCleaverKnife)
    end

    function Neverbirth:HandleCleaverKnifeCollision(knife, collider)
        if not lifetime.runtimeActive then return end
        local state = GetNativeKnifeState(knife)
        local data = knife and knife.GetData and knife:GetData() or nil
        if not state or not data or not data.hitStarted or not Queries.IsHostileEnemy(collider) then return nil end
        -- Hidden carrier never settles damage; this prevents native collision from duplicating Lua sweep hits.
        return true
    end
    function Installers.KnifeCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_KNIFE_COLLISION, Neverbirth.HandleCleaverKnifeCollision)
    end

    return {
        CanSwing = CanSwing,
        RemoveSwing = RemoveSwing,
        PushEnemy = PushEnemy,
        HitEnemyBody = HitEnemyBody,
        GetNativeKnifeState = GetNativeKnifeState,
        ResolveKnifeShadowHits = ResolveKnifeShadowHits,
        ResolveSwingBodyHits = ResolveSwingBodyHits,
        SpawnSwingHitbox = SpawnSwingHitbox,
        UpdateSwing = UpdateSwing,
        TrySwing = Neverbirth.Cleaver.TrySwing,
        UpdateCleaverKnife = Neverbirth.UpdateCleaverKnife,
        HandleCleaverKnifeCollision = Neverbirth.HandleCleaverKnifeCollision,
        Installers = Installers,
    }
end
