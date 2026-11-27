return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local SpawnFolkEffect = dependencies.World.SpawnFolkEffect
    local GetPlayers = dependencies.GetPlayers
    local effects = {}

    Neverbirth.FolkVisualEffects = Neverbirth.FolkVisualEffects or {
        GoodGirlHalo = { name = "Good Girl Halo", fallback = 3002, animation = "Idle", timeout = 45, followOwner = true, followOffset = Vector(0, 0), spriteOffset = Vector(0, -24), depthOffset = 300000 },
        GoodGirlCharm = { name = "Good Girl Charm", fallback = 3003, animation = "Charm", timeout = 45 },
        GoodGirlReward = { name = "Good Girl Reward", fallback = 3004, animation = "Reward", timeout = 60 },
        GoodGirlBreak = { name = "Good Girl Break", fallback = 3005, animation = "Break", timeout = 75 },
        GoodGirlEcho = { name = "Good Girl Echo", fallback = 3006, animation = "Echo", timeout = 45, followOwner = true },
        BlackTaisuiSpore = { name = "Black Taisui Spore", fallback = 3007, animation = "Spore", timeout = 45 },
        BlackTaisuiPulse = { name = "Black Taisui Pulse", fallback = 3008, animation = "Pulse", timeout = 45 },
        BlackTaisuiCurseDevour = { name = "Black Taisui Curse Devour", fallback = 3009, animation = "Devour", timeout = 60 },
        BlackTaisuiReveal = { name = "Black Taisui Reveal", fallback = 3010, animation = "Reveal", timeout = 60 },
        BlackTaisuiFearPulse = { name = "Black Taisui Fear Pulse", fallback = 3011, animation = "FearPulse", timeout = 60 },
        BlackTaisuiDeathDeny = { name = "Black Taisui Death Deny", fallback = 3012, animation = "DeathDeny", timeout = 90 },
        BlackTaisuiMatureCore = { name = "Black Taisui Mature Core", fallback = 3013, animation = "MatureCore", timeout = 45 },
        BlackTaisuiHallucinationEat = { name = "Black Taisui Hallucination Eat", fallback = 3014, animation = "HallucinationEat", timeout = 75 },
    }

    function Neverbirth:GetFolkVisualEffectVariant(key)
        local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
        if not spec then
            return -1
        end
        if spec.variant ~= nil then
            return spec.variant
        end

        spec.variant = spec.fallback or -1
        if Isaac and Isaac.GetEntityVariantByName and spec.name then
            local ok, variant = pcall(function()
                return Isaac.GetEntityVariantByName(spec.name)
            end)
            if ok and type(variant) == "number" and variant > 0 then
                spec.variant = variant
            end
        end

        return spec.variant
    end

    function Neverbirth:GetFolkVisualEffectOwnerSeed(owner)
        return owner and owner.InitSeed or nil
    end

    function Neverbirth:GetFolkVisualEffectFollowOffset(spec)
        if spec and spec.followOffset then
            return spec.followOffset
        end
        return Vector(0, 0)
    end

    function Neverbirth:GetFolkVisualEffectPositionOffset(spec, owner)
        local offset = (spec and spec.positionOffset) or Vector(0, 0)
        if owner and owner.PositionOffset then
            offset = owner.PositionOffset + offset
        end
        if owner and owner.GetFlyingOffset then
            local ok, flyingOffset = pcall(function()
                return owner:GetFlyingOffset()
            end)
            if ok and flyingOffset then
                offset = offset + flyingOffset
            end
        end
        return offset
    end

    function Neverbirth:ApplyFolkVisualEffectFollowPosition(effect, owner, spec)
        if not effect or not owner or not owner.Position then
            return false
        end

        local followOffset = Neverbirth:GetFolkVisualEffectFollowOffset(spec)
        pcall(function()
            effect.Position = owner.Position + followOffset
        end)
        if spec and spec.positionOffset then
            pcall(function()
                effect.PositionOffset = Neverbirth:GetFolkVisualEffectPositionOffset(spec, owner)
            end)
        end
        if spec and spec.spriteOffset then
            pcall(function()
                effect.SpriteOffset = spec.spriteOffset
            end)
        end
        if spec and spec.depthOffset then
            pcall(function()
                effect.DepthOffset = spec.depthOffset
            end)
        end
        if effect.FollowParent then
            pcall(function()
                effect.Parent = owner
                effect:FollowParent(owner)
            end)
        else
            pcall(function()
                effect.Parent = owner
            end)
        end
        return true
    end

    function effects:BindOwner(effect, key, owner)
        if not effect or not owner then
            return false
        end

        local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
        if not spec or not spec.followOwner then
            return false
        end

        local data = effect.GetData and effect:GetData() or nil
        if type(data) ~= "table" then
            return false
        end

        local offset = Neverbirth:GetFolkVisualEffectFollowOffset(spec)
        data.NeverbirthFolkVisualEffectOwner = owner
        data.NeverbirthFolkVisualEffectOwnerSeed = Neverbirth:GetFolkVisualEffectOwnerSeed(owner)
        data.NeverbirthFolkVisualEffectFollowOffset = offset
        Neverbirth:ApplyFolkVisualEffectFollowPosition(effect, owner, spec)
        return true
    end

    function Neverbirth:GetFolkVisualEffectOwner(data)
        if type(data) ~= "table" then
            return nil
        end

        local owner = data.NeverbirthFolkVisualEffectOwner
        if owner and owner.Position then
            return owner
        end

        local ownerSeed = data.NeverbirthFolkVisualEffectOwnerSeed
        if ownerSeed == nil then
            return nil
        end

        for _, player in ipairs(GetPlayers()) do
            if tostring(Neverbirth:GetFolkVisualEffectOwnerSeed(player)) == tostring(ownerSeed) then
                data.NeverbirthFolkVisualEffectOwner = player
                return player
            end
        end

        return nil
    end

    function effects:RefreshTimeout(effect, key, timeout)
        local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
        local data = effect and effect.GetData and effect:GetData() or nil
        if type(data) ~= "table" then
            return
        end
        data.NeverbirthFolkVisualEffectTimeout = math.max(1, math.floor(tonumber(timeout or (spec and spec.timeout)) or 45))
    end

    function effects:IsActive(effect)
        if not effect then
            return false
        end
        if effect.Exists then
            local ok, exists = pcall(function()
                return effect:Exists()
            end)
            if ok then
                return exists == true
            end
        end
        return effect.removed ~= true and effect.Removed ~= true
    end

    function effects:Spawn(key, position, spawner, timeout)
        if not Isaac or not Isaac.Spawn then
            return nil
        end

        local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[key]
        local variant = Neverbirth:GetFolkVisualEffectVariant(key)
        if not spec or not variant or variant <= 0 then
            return nil
        end

        local effect = SpawnFolkEffect(variant, position, spawner)
        local data = effect and effect.GetData and effect:GetData() or nil
        if type(data) == "table" then
            data.NeverbirthFolkVisualEffect = true
            data.NeverbirthFolkVisualEffectKey = key
            data.NeverbirthFolkVisualEffectTimeout = math.max(1, math.floor(tonumber(timeout or spec.timeout) or 45))
        end
        if spec.followOwner and spawner then
            Neverbirth:BindFolkVisualEffectOwner(effect, key, spawner)
        end

        local sprite = effect and effect.GetSprite and effect:GetSprite() or nil
        if sprite and sprite.Play and spec.animation then
            pcall(function()
                sprite:Play(spec.animation, true)
            end)
        end

        return effect
    end

    function Neverbirth:UpdateFolkVisualEffect(effect)
        local data = effect and effect.GetData and effect:GetData() or nil
        if type(data) ~= "table" or data.NeverbirthFolkVisualEffect ~= true then
            return
        end

        if data.NeverbirthFolkVisualEffectOwnerSeed ~= nil then
            local owner = Neverbirth:GetFolkVisualEffectOwner(data)
            local spec = Neverbirth.FolkVisualEffects and Neverbirth.FolkVisualEffects[data.NeverbirthFolkVisualEffectKey]
            if not Neverbirth:ApplyFolkVisualEffectFollowPosition(effect, owner, spec) then
                if effect.Remove then
                    effect:Remove()
                end
                return
            end
        end

        local sprite = effect.GetSprite and effect:GetSprite() or nil
        if sprite and sprite.IsFinished then
            local ok, finished = pcall(function()
                return sprite:IsFinished()
            end)
            if ok and finished then
                if effect.Remove then
                    effect:Remove()
                end
                return
            end
        end

        data.NeverbirthFolkVisualEffectTimeout = (tonumber(data.NeverbirthFolkVisualEffectTimeout) or 1) - 1
        if data.NeverbirthFolkVisualEffectTimeout <= 0 and effect.Remove then
            effect:Remove()
        end
    end
    function callbackInstallers.Neverbirth_UpdateFolkVisualEffect()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, Neverbirth.UpdateFolkVisualEffect)
    end

    Neverbirth.SpawnFolkVisualEffect = effects.Spawn
    Neverbirth.IsFolkVisualEffectActive = effects.IsActive
    Neverbirth.BindFolkVisualEffectOwner = effects.BindOwner
    Neverbirth.RefreshFolkVisualEffectTimeout = effects.RefreshTimeout

    if ModCallbacks.MC_POST_EFFECT_UPDATE then
        callbackInstallers.Neverbirth_UpdateFolkVisualEffect()
    end

    return effects
end
