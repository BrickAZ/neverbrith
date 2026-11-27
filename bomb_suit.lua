-- Bomb Suit / 炸弹套装. Runtime-only owner state and a normal bomb carrier.
-- FireBomb creates a fetus (35 damage), not an ordinary placed bomb (100).
return function(mod, context)
    local ID = context.ItemId
    if not ID or ID <= 0 then return end
    local required = {"MC_PRE_PLAYER_TAKE_DMG", "MC_POST_ENTITY_TAKE_DMG",
        "MC_PRE_PLAYER_UPDATE", "MC_POST_PLAYER_UPDATE", "MC_PRE_TRIGGER_PLAYER_DEATH",
        "MC_POST_TRIGGER_COLLECTIBLE_REMOVED", "MC_PRE_BOMB_UPDATE",
        "MC_POST_BOMB_UPDATE", "MC_PRE_ENTITY_SPAWN"}
    for _, name in ipairs(required) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog("[Bomb Suit] Missing callback: " .. name) end
            return
        end
    end
    -- Build private owners once; the entry only connects dependencies and installs.
    local Config = include("scripts.features.bomb_suit.config")
    local Shooting = include("scripts.systems.shooting_scope").ForOwner(context.ShootingControls, "bomb_suit")
    local State = include("scripts.features.bomb_suit.state")(mod, context, {
        Shooting = Shooting,
    })
    local Bombs = include("scripts.features.bomb_suit.bombs")(mod, context, {
        State = State,
        Config = Config,
    })
    local Presentation = include("scripts.features.bomb_suit.presentation")(mod, context, {
        State = State,
        Config = Config,
    })
    local Damage = include("scripts.features.bomb_suit.damage")(mod, context, {
        State = State,
        Config = Config,
        Bombs = Bombs,
        Presentation = Presentation,
    })
    local Lifecycle = include("scripts.features.bomb_suit.lifecycle")(mod, context, {
        State = State,
        Shooting = Shooting,
        Config = Config,
        Bombs = Bombs,
        Presentation = Presentation,
    })

    mod.BombSuit = {IsActive=function(player) return State.stateFor(player) ~= nil end,
        GetAge=function(player) local s=State.stateFor(player); return s and s.age or nil end,
        IsBloodPayment=Damage.isBloodPayment, ItemId=ID}
    Damage.Installers.preDamage()
    Damage.Installers.postDamage()
    Damage.Installers.evaluate()
    -- Nested around existing modules' priority-0 shooting scopes.
    Lifecycle.Installers.prePlayer()
    Lifecycle.Installers.postPlayer()
    Lifecycle.Installers.input()
    Lifecycle.Installers.update()
    Lifecycle.Installers.start()
    Lifecycle.Installers.exit()
    Lifecycle.Installers.death()
    Lifecycle.Installers.removed()
    -- Open after ordinary PRE callbacks, close before ordinary POST callbacks.
    -- Only the native Bomb AI segment can propose Scatter ownership candidates.
    Bombs.Installers.preBomb()
    Bombs.Installers.postBomb()
    Bombs.Installers.preSpawn()
    Bombs.Installers.resetBombScopes()
    for _, name in ipairs({"MC_POST_BOMB_INIT", "MC_POST_EFFECT_INIT", "MC_POST_TEAR_INIT"}) do
        if ModCallbacks[name] then Bombs.Installers.initOwned(name) end
    end
    if ModCallbacks.MC_POST_PLAYER_RENDER then Presentation.Installers.render() end
    if ModCallbacks.MC_POST_GLOWING_HOURGLASS_LOAD then
        State.Installers.clear()
    end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then
        Lifecycle.Installers.unload()
    end
end
