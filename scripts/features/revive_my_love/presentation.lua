-- Native health and visual operations; no save or callback registration.
return function(context, config, debugLog)
    local REVIVE_EFFECT_VARIANT = config.REVIVE_EFFECT_VARIANT
    local REVIVE_ANIMATION = config.REVIVE_ANIMATION
    local INVINCIBILITY_FRAMES = config.INVINCIBILITY_FRAMES
    local SOUND_NAME = config.SOUND_NAME
    local function giveSurvivalHealth(player)
        local maxHearts = player:GetMaxHearts()
        local soulHearts = player:GetSoulHearts()
        if maxHearts > 0 then
            if soulHearts > 0 then player:AddSoulHearts(-soulHearts) end
            player:AddHearts(2 - player:GetHearts())
        else
            -- Soul-heart characters get one full soul heart. Lost-style
            -- characters ignore AddSoulHearts and retain their native life model.
            player:AddSoulHearts(2 - soulHearts)
        end
    end
    local function giveInvincibility(player)
        player:SetMinDamageCooldown(INVINCIBILITY_FRAMES)
        player:SetColor(Color(1.0, 0.55, 0.78, 1.0, 0.35, 0.08, 0.22),
            INVINCIBILITY_FRAMES, 1, true, false)
    end
    local function playSound(player)
        if context.PlaySound then
            context.PlaySound(player)
            return
        end
        local soundId = Isaac.GetSoundIdByName(SOUND_NAME)
        if soundId and soundId > 0 then SFXManager():Play(soundId, 1.0, 0, false, 1.0) end
    end
    local function removeEffect(effect)
        if effect and effect:Exists() then effect:Remove() end
    end
    local function spawnEffect(player)
        if REVIVE_EFFECT_VARIANT <= 0 then return nil end
        local ok, effect = pcall(Isaac.Spawn, EntityType.ENTITY_EFFECT,
            REVIVE_EFFECT_VARIANT, 0, player.Position, Vector.Zero, player)
        if not ok or not effect then
            debugLog("revive effect spawn failed: " .. tostring(effect))
            return nil
        end
        effect:GetSprite():Play(REVIVE_ANIMATION, true)
        effect:SetColor(Color(1.0, 0.32, 0.68, 1.0, 0.45, 0.05, 0.22), 48, 1, true, false)
        return effect
    end

    return { giveSurvivalHealth = giveSurvivalHealth, giveInvincibility = giveInvincibility, playSound = playSound, removeEffect = removeEffect, spawnEffect = spawnEffect }
end
