return function(Neverbirth, context)
    context = context or {}
    local ITEM_ID = tonumber(context.ItemId) or -1
    local REVIVE_EFFECT_VARIANT = tonumber(context.EffectVariant) or -1
    local REVIVE_ANIMATION = "Revive"
    local INVINCIBILITY_FRAMES = 60
    local SOUND_NAME = "Revive My Love"
    local EFFECT_WATCHDOG_FRAMES = 90 -- 30 Hz game updates, not 60 Hz player updates.
    local sequencesByPlayer = {} -- Runtime userdata only; never serialized.
    local livingStateByPlayer = {} -- Never snapshot transient native death/Revive flags.

    local function debugLog(message)
        if context.DebugLog then context.DebugLog("[Revive My Love] " .. tostring(message)) end
    end

    -- The XML reviveeffect tag, callbacks and semantics were checked against the
    -- installed REPENTOGON 1.0.12a scripts/changelog. No vanilla fallback.
    if not REPENTOGON or not REPENTOGON.MeetsVersion
        or not REPENTOGON.MeetsVersion("1.0.12a")
        or not ModCallbacks.MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES
        or not ModCallbacks.MC_PRE_PLAYER_UPDATE
        or not ModCallbacks.MC_PRE_PLAYER_TAKE_DMG then
        debugLog("requires REPENTOGON 1.0.12a or newer; revive module not registered")
        return nil
    end

    local function currentRunSeed()
        return tostring(context.GetCurrentRunSeed and context.GetCurrentRunSeed() or "")
    end
    local function save()
        if context.Save then context.Save() end
    end
    local function getSaveRoot()
        return context.GetSaveRoot and context.GetSaveRoot() or nil
    end
    local function resetState(root)
        root.reviveMyLove = {runSeed = currentRunSeed(), triggeredByPlayer = {}}
        return root.reviveMyLove
    end
    local function getState()
        local root = getSaveRoot()
        if not root then return nil end
        local state = root.reviveMyLove
        if type(state) ~= "table" or tostring(state.runSeed or "") ~= currentRunSeed() then
            state = resetState(root)
        end
        if type(state.triggeredByPlayer) ~= "table" then state.triggeredByPlayer = {} end
        return state
    end
    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end
    local function hasItem(player)
        return ITEM_ID > 0 and player and player:GetCollectibleNum(ITEM_ID, true) > 0
    end

    local function syncExtraLife(player)
        if not player then return end
        local state = getState()
        if not state then return end
        local key = playerKey(player)
        local wanted = hasItem(player) and not state.triggeredByPlayer[key]
            and not sequencesByPlayer[key] and 1 or 0
        if wanted == 1 and not player:IsDead() then
            livingStateByPlayer[key] = {
                controlsEnabled = player.ControlsEnabled, visible = player.Visible,
                collisionClass = player.EntityCollisionClass,
            }
        elseif wanted == 0 then
            livingStateByPlayer[key] = nil
        end
        local effects = player:GetEffects()
        local count = effects:GetCollectibleEffectNum(ITEM_ID)
        -- Own only this collectible's effect. One effect advertises x1 even
        -- with duplicate copies; it adds no costume or stats.
        if count < wanted then
            effects:AddCollectibleEffect(ITEM_ID, false, wanted - count)
        elseif count > wanted then
            effects:RemoveCollectibleEffect(ITEM_ID, count - wanted)
        end
        if count ~= wanted then
            debugLog("extra life entitlement for player " .. key .. ": " .. count .. " -> " .. wanted)
        end
    end

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

    local function finishRevival(player, key, reason)
        local sequence = sequencesByPlayer[key]
        if not sequence then return end
        sequencesByPlayer[key] = nil
        player.ControlsEnabled = sequence.controlsEnabled
        player.Visible = sequence.visible
        player.EntityCollisionClass = sequence.collisionClass
        player.Velocity = Vector.Zero
        giveSurvivalHealth(player)
        giveInvincibility(player)
        removeEffect(sequence.effect)
        syncExtraLife(player)
        debugLog("revival presentation finished for player " .. key .. ": " .. tostring(reason)
            .. "; visible=" .. tostring(player.Visible)
            .. "; controls=" .. tostring(player.ControlsEnabled))
    end

    local function effectUpdate(_, effect)
        if not effect or effect.Variant ~= REVIVE_EFFECT_VARIANT then return end
        local player = effect.SpawnerEntity and effect.SpawnerEntity:ToPlayer()
        local key = playerKey(player)
        local sequence = sequencesByPlayer[key]
        -- Use engine identity, not equality of separate Lua userdata wrappers.
        if not player or not sequence or sequence.effectSeed ~= effect.InitSeed then
            removeEffect(effect)
            return
        end
        if effect:GetSprite():IsFinished(REVIVE_ANIMATION) then
            finishRevival(player, key, "Revive animation complete")
        end
    end

    local function prePlayerUpdate(_, player)
        local key = playerKey(player)
        local sequence = sequencesByPlayer[key]
        if not sequence then return end
        if not sequence.effect or not sequence.effect:Exists() then
            finishRevival(player, key, "visual removed early")
            return
        end
        player.Position = sequence.position
        player.Velocity = Vector.Zero
        player.ControlsEnabled = false
        player.Visible = false
        -- REPENTOGON 1160: true skips this player's native update. The room and
        -- effects keep updating; this player's shooting/use input cannot run.
        return true
    end

    local function postUpdate()
        -- Player updates run twice as often as the effect's animation updates.
        -- Only the 30 Hz game callback owns this timeout, including in co-op.
        for key, sequence in pairs(sequencesByPlayer) do
            if not sequence.player or not sequence.player:Exists() then
                removeEffect(sequence.effect)
                sequencesByPlayer[key] = nil
                livingStateByPlayer[key] = nil
            else
                sequence.logicFrames = sequence.logicFrames + 1
                if sequence.logicFrames > EFFECT_WATCHDOG_FRAMES then
                    finishRevival(sequence.player, key, "animation watchdog recovery")
                end
            end
        end
    end

    local function triggerDeath(_, player)
        if Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.IsFailureDeath(player) then return end
        local state = getState()
        local key = playerKey(player)
        if not state or state.triggeredByPlayer[key] or sequencesByPlayer[key]
            or not hasItem(player) or not player:IsDead() then return end

        -- 1051 runs after the actual death animation and after vanilla revives.
        -- Never test WillPlayerRevive here: our own reviveeffect makes it true.
        -- Revive at this boundary prevents Game Over; visual awakening remains
        -- locked until the custom animation ends. No lethal damage is cancelled.
        local ok, err = pcall(function() player:Revive() end)
        if not ok or player:IsDead() then
            debugLog("engine revival failed or was vetoed for player " .. key .. ": " .. tostring(err))
            return
        end
        -- Revive() is inside native death resolution: its immediate Visible,
        -- controls and collision can still be the death-animation values.
        -- Restore the last living snapshot instead. If loading while already
        -- dead, no snapshot exists; release to normal live player defaults.
        local living = livingStateByPlayer[key] or {
            controlsEnabled = true, visible = true,
            collisionClass = EntityCollisionClass.ENTCOLL_ALL,
        }
        local sequence = {
            phase = "revive_effect", player = player, position = player.Position,
            controlsEnabled = living.controlsEnabled, visible = living.visible,
            collisionClass = living.collisionClass, logicFrames = 0,
        }
        sequencesByPlayer[key] = sequence
        state.triggeredByPlayer[key] = true
        player:RemoveCollectible(ITEM_ID)
        syncExtraLife(player)
        giveSurvivalHealth(player)
        save()
        player.ControlsEnabled = false
        player.Visible = false
        player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
        player.Velocity = Vector.Zero
        sequence.effect = spawnEffect(player)
        sequence.effectSeed = sequence.effect and sequence.effect.InitSeed
        playSound(player)
        debugLog("native death completed; playing Revive for player " .. key)
        if not sequence.effect then finishRevival(player, key, "effect spawn failed") end
        -- Already revived: REPENTOGON stops later death callbacks automatically.
    end

    local function playerDamage(_, player)
        -- Protect only an already-revived owner during the presentation, before
        -- Holy Mantle and other damage-negation effects can be consumed.
        if sequencesByPlayer[playerKey(player)] then return false end
    end
    local function playerUpdate(_, player) syncExtraLife(player) end
    local function collectibleAdded(_, collectible, charge, firstTime, slot, varData, player)
        if collectible == ITEM_ID then syncExtraLife(player) end
    end
    local function collectibleRemoved(_, player, collectible)
        if collectible == ITEM_ID then syncExtraLife(player) end
    end

    local function cleanupSequences()
        for key, sequence in pairs(sequencesByPlayer) do
            if sequence.player and sequence.player:Exists() then
                finishRevival(sequence.player, key, "room/exit cleanup")
            else
                removeEffect(sequence.effect)
                sequencesByPlayer[key] = nil
            end
        end
        livingStateByPlayer = {}
    end
    local function syncAllPlayers()
        local game = Game()
        for i = 0, game:GetNumPlayers() - 1 do syncExtraLife(Isaac.GetPlayer(i)) end
    end
    local function gameStarted(_, isContinued)
        sequencesByPlayer = {}
        livingStateByPlayer = {}
        local root = getSaveRoot()
        if not root then return end
        if not isContinued then resetState(root); save() else getState() end
        syncAllPlayers()
    end
    local function preGameExit()
        cleanupSequences()
        save()
    end

    Neverbirth:AddCallback(ModCallbacks.MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES, triggerDeath)
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, playerDamage)
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, prePlayerUpdate)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, collectibleAdded, ITEM_ID)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, collectibleRemoved)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, cleanupSequences)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, playerUpdate)
    Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, effectUpdate, REVIVE_EFFECT_VARIANT)

    local api = {
        ItemId = ITEM_ID, EffectVariant = REVIVE_EFFECT_VARIANT,
        EffectAnimation = REVIVE_ANIMATION, InvincibilityFrames = INVINCIBILITY_FRAMES,
        SoundName = SOUND_NAME, GetState = getState, TriggerDeath = triggerDeath,
        SyncExtraLife = syncExtraLife, PrePlayerUpdate = prePlayerUpdate,
        PlayerDamage = playerDamage, PlayerUpdate = playerUpdate,
        EffectUpdate = effectUpdate, GameStarted = gameStarted,
    }
    Neverbirth.ReviveMyLoveTestAPI = api
    debugLog("registered REPENTOGON revive route; version=" .. tostring(REPENTOGON.Version)
        .. "; item=" .. ITEM_ID .. "; effect=" .. REVIVE_EFFECT_VARIANT)
    return api
end
