return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = tonumber(context.ItemId) or -1
    local PLAYER_ENTITY = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local EFFECT_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local REVIVE_EFFECT_VARIANT = tonumber(context.EffectVariant) or -1
    local REVIVE_ANIMATION = "Revive"
    local FAKE_DAMAGE = DamageFlag and DamageFlag.DAMAGE_FAKE or nil
    local NOKILL_DAMAGE = DamageFlag and DamageFlag.DAMAGE_NOKILL or nil
    local INVINCIBILITY_FRAMES = 60
    local SOUND_NAME = "Revive My Love"
    local DEATH_ANIMATION_SUFFIX = "Death"

    -- Live EntityPlayer/Effect userdata belongs only to this runtime table. The
    -- once-per-run settlement stays in SaveData, but an interrupted death
    -- animation is deliberately not serialized.
    local sequencesByPlayer = {}

    local function debugLog(message)
        if context.DebugLog then
            context.DebugLog("[Revive My Love] " .. tostring(message))
        end
    end

    local function currentRunSeed()
        if context.GetCurrentRunSeed then
            local ok, seed = pcall(context.GetCurrentRunSeed)
            if ok then return tostring(seed or "") end
        end
        return ""
    end

    local function save()
        if context.Save then
            local ok, err = pcall(context.Save)
            if not ok then debugLog("save failed: " .. tostring(err)) end
        end
    end

    local function getSaveRoot()
        if not context.GetSaveRoot then return nil end
        local ok, root = pcall(context.GetSaveRoot)
        if not ok or type(root) ~= "table" then return nil end
        return root
    end

    local function resetState(root, seed)
        root.reviveMyLove = {
            runSeed = tostring(seed or ""),
            triggeredByPlayer = {},
        }
        return root.reviveMyLove
    end

    local function getState()
        local root = getSaveRoot()
        if not root then return nil end
        local state = root.reviveMyLove
        if type(state) ~= "table" or tostring(state.runSeed or "") ~= currentRunSeed() then
            state = resetState(root, currentRunSeed())
        end
        if type(state.triggeredByPlayer) ~= "table" then state.triggeredByPlayer = {} end
        return state
    end

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function toPlayer(entity)
        if not entity then return nil end
        if entity.ToPlayer then
            local ok, player = pcall(function() return entity:ToPlayer() end)
            if ok and player then return player end
        end
        if entity.Type == PLAYER_ENTITY then return entity end
        return nil
    end

    local function hasItem(player)
        if ITEM_ID <= 0 or not player then return false end
        if player.GetCollectibleNum then
            local ok, count = pcall(function() return player:GetCollectibleNum(ITEM_ID) end)
            if ok then return (tonumber(count) or 0) > 0 end
        end
        if player.HasCollectible then
            local ok, result = pcall(function() return player:HasCollectible(ITEM_ID) end)
            return ok and result == true
        end
        return false
    end

    local function hasFlag(flags, flag)
        return type(flags) == "number" and type(flag) == "number" and (flags & flag) ~= 0
    end

    local function isIgnoredDamage(amount, flags)
        if (tonumber(amount) or 0) <= 0 then return true end
        return hasFlag(flags, FAKE_DAMAGE) or hasFlag(flags, NOKILL_DAMAGE)
    end

    local function hasPendingEngineRevive(player)
        if not player or not player.WillPlayerRevive then return false end
        local ok, result = pcall(function() return player:WillPlayerRevive() end)
        return ok and result == true
    end

    local function isPlayerDead(player)
        if not player or not player.IsDead then return false end
        local ok, result = pcall(function() return player:IsDead() end)
        return ok and result == true
    end

    local function getFinishedDeathAnimation(player)
        if not player or not player.GetSprite then return nil end
        local okSprite, sprite = pcall(function() return player:GetSprite() end)
        if not okSprite or not sprite or not sprite.GetAnimation or not sprite.IsFinished then
            return nil
        end

        local okAnimation, animation = pcall(function() return sprite:GetAnimation() end)
        if not okAnimation or type(animation) ~= "string" then return nil end
        if animation:sub(-#DEATH_ANIMATION_SUFFIX) ~= DEATH_ANIMATION_SUFFIX then
            return nil
        end

        local okFinished, finished = pcall(function()
            return sprite:IsFinished(animation)
        end)
        if okFinished and finished == true then return animation end
        return nil
    end

    local function conventionalHealth(player)
        local total = 0
        for method, multiplier in pairs({ GetHearts = 1, GetSoulHearts = 1, GetBoneHearts = 2 }) do
            if player and player[method] then
                local ok, value = pcall(function() return player[method](player) end)
                if ok then total = total + math.max(0, tonumber(value) or 0) * multiplier end
            end
        end
        return total
    end

    local function isLethal(player, amount)
        if context.IsIncomingDamageLethal then
            local ok, result = pcall(context.IsIncomingDamageLethal, player, tonumber(amount) or 0)
            if ok and result == true then return true end
        end

        if player and player.HasMortalDamage then
            local ok, result = pcall(function() return player:HasMortalDamage() end)
            if ok and result == true then return true end
        end

        -- Zero-heart characters do not expose a conventional heart layer for
        -- comparison. If positive damage reaches this callback after shields
        -- and other immunity checks, cancelling it is the safe survival path.
        return (tonumber(amount) or 0) > 0 and conventionalHealth(player) <= 0
    end

    local function removeOneCopy(player)
        if not player or not player.RemoveCollectible then return false end
        local ok, err = pcall(function() player:RemoveCollectible(ITEM_ID) end)
        if not ok then debugLog("failed to remove one copy: " .. tostring(err)) end
        return ok
    end

    local function makeColor(...)
        if not Color then return nil end
        local ok, value = pcall(Color, ...)
        if ok then return value end
        debugLog("failed to construct Color: " .. tostring(value))
        return nil
    end

    local function makeZeroVector()
        if Vector and Vector.Zero then return Vector.Zero end
        if not Vector then return nil end
        local ok, value = pcall(Vector, 0, 0)
        if ok then return value end
        debugLog("failed to construct Vector.Zero: " .. tostring(value))
        return nil
    end

    local function giveSurvivalHealth(player)
        local maxHearts = 0
        if player and player.GetMaxHearts then
            local ok, value = pcall(function() return player:GetMaxHearts() end)
            if ok then maxHearts = math.max(0, tonumber(value) or 0) end
        end

        local soulHearts = 0
        if player and player.GetSoulHearts then
            local ok, value = pcall(function() return player:GetSoulHearts() end)
            if ok then soulHearts = math.max(0, tonumber(value) or 0) end
        end

        if maxHearts > 0 and player.AddHearts then
            local hearts = 0
            if player.GetHearts then
                local ok, value = pcall(function() return player:GetHearts() end)
                if ok then hearts = math.max(0, tonumber(value) or 0) end
            end
            if soulHearts > 0 and player.AddSoulHearts then
                pcall(function() player:AddSoulHearts(-soulHearts) end)
            end
            pcall(function() player:AddHearts(2 - hearts) end)
            return
        end

        if player and player.AddSoulHearts then
            pcall(function() player:AddSoulHearts(2 - soulHearts) end)
        end
    end

    local function giveInvincibility(player)
        if player and player.SetMinDamageCooldown then
            pcall(function() player:SetMinDamageCooldown(INVINCIBILITY_FRAMES) end)
        end
        if player and player.SetColor then
            local color = makeColor(1.0, 0.55, 0.78, 1.0, 0.35, 0.08, 0.22)
            if not color then return end
            pcall(function()
                player:SetColor(color, INVINCIBILITY_FRAMES, 1, true, false)
            end)
        end
    end

    local function playSound(player)
        if context.PlaySound then
            local ok, err = pcall(context.PlaySound, player)
            if not ok then debugLog("audio hook failed: " .. tostring(err)) end
            return
        end
        if not Isaac or not Isaac.GetSoundIdByName or type(SFXManager) ~= "function" then return end
        local okId, soundId = pcall(Isaac.GetSoundIdByName, SOUND_NAME)
        if not okId or type(soundId) ~= "number" or soundId < 0 then return end
        local okManager, manager = pcall(SFXManager)
        if okManager and manager and manager.Play then
            pcall(function() manager:Play(soundId, 1.0, 0, false, 1.0) end)
        end
    end

    local function spawnEffect(player)
        if REVIVE_EFFECT_VARIANT <= 0 then
            debugLog("registered revive effect variant is unavailable")
            return nil
        end
        if not Isaac or not Isaac.Spawn or not player or not player.Position then return nil end

        local velocity = makeZeroVector()
        if not velocity then
            debugLog("revive effect spawn skipped because Vector.Zero is unavailable")
            return nil
        end

        local ok, effect = pcall(
            Isaac.Spawn,
            EFFECT_ENTITY,
            REVIVE_EFFECT_VARIANT,
            0,
            player.Position,
            velocity,
            player
        )
        if not ok then
            debugLog("revive effect spawn failed: " .. tostring(effect))
            return nil
        end
        if not effect then return nil end

        if effect.GetSprite then
            local okSprite, sprite = pcall(function() return effect:GetSprite() end)
            if okSprite and sprite and sprite.Play then
                pcall(function() sprite:Play(REVIVE_ANIMATION, true) end)
            end
        end

        local color = makeColor(1.0, 0.32, 0.68, 1.0, 0.45, 0.05, 0.22)
        if color and effect.SetColor then
            pcall(function()
                effect:SetColor(color, 48, 1, true, false)
            end)
        end
        return effect
    end

    local function removeEffect(effect)
        if effect and effect.Remove then
            pcall(function() effect:Remove() end)
        end
    end

    local function finishRevival(player, key, effect)
        local sequence = sequencesByPlayer[key]
        if not sequence or sequence.phase ~= "revive_effect" or sequence.effect ~= effect then
            removeEffect(effect)
            return false
        end

        if not player or not player.Revive then
            debugLog("engine Revive API unavailable for player " .. tostring(key))
            return false
        end

        local ok, err = pcall(function() player:Revive() end)
        if not ok then
            debugLog("engine revive failed for player " .. tostring(key) .. ": " .. tostring(err))
            return false
        end

        giveSurvivalHealth(player)
        giveInvincibility(player)
        sequencesByPlayer[key] = nil
        removeEffect(effect)
        debugLog("revived player " .. tostring(key) .. " after both animations")
        return true
    end

    local function effectUpdate(_, effect)
        if not effect or tonumber(effect.Variant) ~= REVIVE_EFFECT_VARIANT then return end
        local player = toPlayer(effect.SpawnerEntity)
        local key = playerKey(player)
        local sequence = sequencesByPlayer[key]
        if not player or not sequence or sequence.phase ~= "revive_effect" or sequence.effect ~= effect then
            removeEffect(effect)
            return
        end

        if not effect.GetSprite then
            finishRevival(player, key, effect)
            return
        end

        local okSprite, sprite = pcall(function() return effect:GetSprite() end)
        if not okSprite or not sprite then
            finishRevival(player, key, effect)
            return
        end

        if sprite.IsFinished then
            local okFinished, finished = pcall(function()
                return sprite:IsFinished(REVIVE_ANIMATION)
            end)
            if okFinished and finished then
                finishRevival(player, key, effect)
            end
        end
    end

    local function beginConfirmedDeath(player, state, key, sequence)
        state.triggeredByPlayer[key] = true
        removeOneCopy(player)
        save()
        sequence.phase = "death_animation"
        debugLog("confirmed real death for player " .. tostring(key))
    end

    local function playerUpdate(_, player)
        local key = playerKey(player)
        local sequence = sequencesByPlayer[key]
        if not sequence then return end
        sequence.player = player

        if sequence.phase == "pending_death" then
            if not isPlayerDead(player) then
                -- Another callback, shield, or immunity prevented the predicted
                -- lethal hit. Do not consume or lock the item.
                sequencesByPlayer[key] = nil
                debugLog("predicted lethal hit was cancelled for player " .. tostring(key))
                return
            end

            local state = getState()
            if not state or state.triggeredByPlayer[key] or not hasItem(player) or hasPendingEngineRevive(player) then
                sequencesByPlayer[key] = nil
                return
            end
            beginConfirmedDeath(player, state, key, sequence)
        end

        if sequence.phase == "death_animation" then
            if not isPlayerDead(player) then
                sequencesByPlayer[key] = nil
                debugLog("death sequence was superseded before the custom animation for player " .. tostring(key))
                return
            end

            local finishedAnimation = getFinishedDeathAnimation(player)
            if not finishedAnimation then return end

            local effect = spawnEffect(player)
            if not effect then
                -- The registered visual is expected to exist, but a resource
                -- failure must not strand a dead player forever.
                debugLog("custom revive effect unavailable; reviving without it for player " .. tostring(key))
                sequence.phase = "revive_effect"
                sequence.effect = false
                if player.Revive then
                    local ok = pcall(function() player:Revive() end)
                    if ok then
                        giveSurvivalHealth(player)
                        giveInvincibility(player)
                        sequencesByPlayer[key] = nil
                    end
                end
                return
            end

            sequence.phase = "revive_effect"
            sequence.effect = effect
            sequence.deathAnimation = finishedAnimation
            playSound(player)
            debugLog("playing custom revive animation after " .. finishedAnimation .. " for player " .. tostring(key))
            return
        end

        if sequence.phase == "revive_effect" and not isPlayerDead(player) then
            -- A foreign revival won the race after our death confirmation.
            -- Remove only our visual and do not rewrite the other revival.
            removeEffect(sequence.effect)
            sequencesByPlayer[key] = nil
            debugLog("custom revive sequence was superseded for player " .. tostring(key))
        end
    end

    local function playerDamage(_, entity, amount, flags, source, countdown)
        local player = toPlayer(entity)
        if not player or isIgnoredDamage(amount, flags) or not hasItem(player) then return nil end

        local state = getState()
        local key = playerKey(player)
        if not state or state.triggeredByPlayer[key] then return nil end
        if not isLethal(player, amount) then return nil end

        -- Let engine-registered revival sources resolve first. The custom item
        -- stays intact and may still trigger on a later true death.
        if hasPendingEngineRevive(player) then return nil end

        sequencesByPlayer[key] = {
            phase = "pending_death",
            player = player,
        }
        debugLog("armed real-death observation for player " .. tostring(key))
        -- Do not cancel or rewrite the lethal hit. The engine owns the real
        -- death state, death animation, and its movement/shooting lock.
        return nil
    end

    local function gameStarted(_, isContinued)
        sequencesByPlayer = {}
        local root = getSaveRoot()
        if not root then return end
        if not isContinued then
            resetState(root, currentRunSeed())
            save()
        else
            getState()
        end
    end

    local function preGameExit()
        sequencesByPlayer = {}
        save()
    end

    Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, playerDamage, PLAYER_ENTITY)
    if ModCallbacks.MC_POST_GAME_STARTED then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end
    if ModCallbacks.MC_POST_PLAYER_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, playerUpdate)
    end
    if ModCallbacks.MC_POST_EFFECT_UPDATE and REVIVE_EFFECT_VARIANT > 0 then
        Neverbirth:AddCallback(
            ModCallbacks.MC_POST_EFFECT_UPDATE,
            effectUpdate,
            REVIVE_EFFECT_VARIANT
        )
    end

    local api = {
        ItemId = ITEM_ID,
        EffectVariant = REVIVE_EFFECT_VARIANT,
        EffectAnimation = REVIVE_ANIMATION,
        InvincibilityFrames = INVINCIBILITY_FRAMES,
        SoundName = SOUND_NAME,
        GetState = getState,
        IsLethal = isLethal,
        PlayerDamage = playerDamage,
        PlayerUpdate = playerUpdate,
        EffectUpdate = effectUpdate,
        GameStarted = gameStarted,
    }
    Neverbirth.ReviveMyLoveTestAPI = api
    return api
end
