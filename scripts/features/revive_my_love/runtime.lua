-- Own the death sequence, callback handlers and lifecycle.
return function(Neverbirth, State, Presentation, config, debugLog, isFailureDeath)
    local callbackInstallers = {}
    local runtime = State.runtime
    local save = State.save
    local getSaveRoot = State.getSaveRoot
    local resetState = State.resetState
    local getState = State.getState
    local playerKey = State.playerKey
    local hasItem = State.hasItem
    local syncExtraLife = State.syncExtraLife
    local giveSurvivalHealth = Presentation.giveSurvivalHealth
    local giveInvincibility = Presentation.giveInvincibility
    local playSound = Presentation.playSound
    local removeEffect = Presentation.removeEffect
    local spawnEffect = Presentation.spawnEffect
    local ITEM_ID = config.ITEM_ID
    local REVIVE_EFFECT_VARIANT = config.REVIVE_EFFECT_VARIANT
    local REVIVE_ANIMATION = config.REVIVE_ANIMATION
    local EFFECT_WATCHDOG_FRAMES = config.EFFECT_WATCHDOG_FRAMES
    local function holdPresentation(player, sequence)
        player.Position = sequence.position
        player.Velocity = Vector.Zero
        player.ControlsEnabled = false
        player.Visible = false
        player.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    end

    local function finishRevival(player, key, reason)
        local sequence = runtime.sequencesByPlayer[key]
        if not sequence then return end
        runtime.sequencesByPlayer[key] = nil
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
        local sequence = runtime.sequencesByPlayer[key]
        -- Use engine identity, not equality of separate Lua userdata wrappers.
        if not player or not sequence or sequence.effectSeed ~= effect.InitSeed then
            removeEffect(effect)
            return
        end
        if effect:GetSprite():IsFinished(REVIVE_ANIMATION) then
            finishRevival(player, key, "Revive animation complete")
        end
    end
    function callbackInstallers.effectUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, effectUpdate, REVIVE_EFFECT_VARIANT)
    end

    local function prePlayerUpdate(_, player)
        local key = playerKey(player)
        local sequence = runtime.sequencesByPlayer[key]
        if not sequence then return end
        if not sequence.effect or not sequence.effect:Exists() then
            finishRevival(player, key, "visual removed early")
            return
        end
        holdPresentation(player, sequence)
        -- REPENTOGON 1160: true skips this player's native update. The room and
        -- effects keep updating; this player's shooting/use input cannot run.
        return true
    end
    function callbackInstallers.prePlayerUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, prePlayerUpdate)
    end

    local function postUpdate()
        -- Player updates run twice as often as the effect's animation updates.
        -- Only the 30 Hz game callback owns this timeout, including in co-op.
        for key, sequence in pairs(runtime.sequencesByPlayer) do
            if not sequence.player or not sequence.player:Exists() then
                removeEffect(sequence.effect)
                runtime.sequencesByPlayer[key] = nil
                runtime.livingStateByPlayer[key] = nil
            else
                -- The death-resolution path can skip POST_PLAYER_UPDATE and
                -- reset Revive()'s immediate flags. Reapply here, after native
                -- updates and before the first render of the revived player.
                holdPresentation(sequence.player, sequence)
                sequence.logicFrames = sequence.logicFrames + 1
                if sequence.logicFrames > EFFECT_WATCHDOG_FRAMES then
                    finishRevival(sequence.player, key, "animation watchdog recovery")
                end
            end
        end
    end
    function callbackInstallers.postUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    end

    local function triggerDeath(_, player)
        if isFailureDeath(player) then return end
        local state = getState()
        local key = playerKey(player)
        if not state or state.triggeredByPlayer[key] or runtime.sequencesByPlayer[key]
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
        local living = runtime.livingStateByPlayer[key] or {
            controlsEnabled = true, visible = true,
            collisionClass = EntityCollisionClass.ENTCOLL_ALL,
        }
        local sequence = {
            phase = "revive_effect", player = player, position = player.Position,
            controlsEnabled = living.controlsEnabled, visible = living.visible,
            collisionClass = living.collisionClass, logicFrames = 0,
        }
        runtime.sequencesByPlayer[key] = sequence
        state.triggeredByPlayer[key] = true
        player:RemoveCollectible(ITEM_ID)
        syncExtraLife(player)
        giveSurvivalHealth(player)
        save()
        holdPresentation(player, sequence)
        sequence.effect = spawnEffect(player)
        sequence.effectSeed = sequence.effect and sequence.effect.InitSeed
        playSound(player)
        debugLog("native death completed; playing Revive for player " .. key)
        if not sequence.effect then finishRevival(player, key, "effect spawn failed") end
        -- Already revived: REPENTOGON stops later death callbacks automatically.
    end
    function callbackInstallers.triggerDeath()
        return Neverbirth:AddCallback(ModCallbacks.MC_TRIGGER_PLAYER_DEATH_POST_CHECK_REVIVES, triggerDeath)
    end

    local function playerDamage(_, player)
        -- Protect only an already-revived owner during the presentation, before
        -- Holy Mantle and other damage-negation effects can be consumed.
        if runtime.sequencesByPlayer[playerKey(player)] then return false end
    end
    function callbackInstallers.playerDamage()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, playerDamage)
    end
    local function playerUpdate(_, player) syncExtraLife(player) end
    function callbackInstallers.playerUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, playerUpdate)
    end
    local function collectibleAdded(_, collectible, charge, firstTime, slot, varData, player)
        if collectible == ITEM_ID then syncExtraLife(player) end
    end
    function callbackInstallers.collectibleAdded()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, collectibleAdded, ITEM_ID)
    end
    local function collectibleRemoved(_, player, collectible)
        if collectible == ITEM_ID then syncExtraLife(player) end
    end
    function callbackInstallers.collectibleRemoved()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, collectibleRemoved)
    end

    local function cleanupSequences()
        for key, sequence in pairs(runtime.sequencesByPlayer) do
            if sequence.player and sequence.player:Exists() then
                finishRevival(sequence.player, key, "room/exit cleanup")
            else
                removeEffect(sequence.effect)
                runtime.sequencesByPlayer[key] = nil
            end
        end
        runtime.livingStateByPlayer = {}
    end
    function callbackInstallers.cleanupSequences()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, cleanupSequences)
    end
    local function syncAllPlayers()
        local game = Game()
        for i = 0, game:GetNumPlayers() - 1 do syncExtraLife(Isaac.GetPlayer(i)) end
    end
    local function gameStarted(_, isContinued)
        runtime.sequencesByPlayer = {}
        runtime.livingStateByPlayer = {}
        local root = getSaveRoot()
        if not root then return end
        if not isContinued then resetState(root); save() else getState() end
        syncAllPlayers()
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end
    local function preGameExit()
        cleanupSequences()
        save()
    end
    function callbackInstallers.preGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
    end

    return { Installers = callbackInstallers, triggerDeath = triggerDeath, prePlayerUpdate = prePlayerUpdate,
        playerDamage = playerDamage, playerUpdate = playerUpdate, effectUpdate = effectUpdate, gameStarted = gameStarted }
end
