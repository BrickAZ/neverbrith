return function(Neverbirth, context)
    context = context or {}
    local ITEM_ID = tonumber(context.ItemId) or -1
    local REVIVE_EFFECT_VARIANT = tonumber(context.EffectVariant) or -1
    local REVIVE_ANIMATION = "Revive"
    local INVINCIBILITY_FRAMES = 60
    local SOUND_NAME = "Revive My Love"
    local EFFECT_WATCHDOG_FRAMES = 90 -- 30 Hz game updates, not 60 Hz player updates.

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

    local config = { ITEM_ID=ITEM_ID, REVIVE_EFFECT_VARIANT=REVIVE_EFFECT_VARIANT, REVIVE_ANIMATION=REVIVE_ANIMATION,
        INVINCIBILITY_FRAMES=INVINCIBILITY_FRAMES, SOUND_NAME=SOUND_NAME, EFFECT_WATCHDOG_FRAMES=EFFECT_WATCHDOG_FRAMES }
    local State = include("scripts.features.revive_my_love.state")(context, ITEM_ID, debugLog)
    local Presentation = include("scripts.features.revive_my_love.presentation")(context, config, debugLog)
    local Runtime = include("scripts.features.revive_my_love.runtime")(Neverbirth, State, Presentation, config, debugLog, assert(context.IsFailureDeath))
    local callbackInstallers = Runtime.Installers
    callbackInstallers.triggerDeath()
    callbackInstallers.playerDamage()
    callbackInstallers.prePlayerUpdate()
    callbackInstallers.postUpdate()
    callbackInstallers.collectibleAdded()
    callbackInstallers.collectibleRemoved()
    callbackInstallers.cleanupSequences()
    callbackInstallers.gameStarted()
    callbackInstallers.preGameExit()
    callbackInstallers.playerUpdate()
    callbackInstallers.effectUpdate()

    local api = {
        ItemId = ITEM_ID, EffectVariant = REVIVE_EFFECT_VARIANT,
        EffectAnimation = REVIVE_ANIMATION, InvincibilityFrames = INVINCIBILITY_FRAMES,
        SoundName = SOUND_NAME, GetState = State.getState, TriggerDeath = Runtime.triggerDeath,
        SyncExtraLife = State.syncExtraLife, PrePlayerUpdate = Runtime.prePlayerUpdate,
        PlayerDamage = Runtime.playerDamage, PlayerUpdate = Runtime.playerUpdate,
        EffectUpdate = Runtime.effectUpdate, GameStarted = Runtime.gameStarted,
    }
    Neverbirth.ReviveMyLoveTestAPI = api
    debugLog("registered REPENTOGON revive route; version=" .. tostring(REPENTOGON.Version)
        .. "; item=" .. ITEM_ID .. "; effect=" .. REVIVE_EFFECT_VARIANT)
    return api
end
