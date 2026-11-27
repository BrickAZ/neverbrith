-- I Am a God: a timed, team-wide risk and a floor-owned no-healing room.
-- Requires the project's REPENTOGON gate; no weapon replacement.
return function(mod, context)
    local ITEM_ID = context.ItemId
    if not ITEM_ID or ITEM_ID <= 0 then return end
    local required = { "MC_PRE_PLAYER_TAKE_DMG", "MC_POST_ENTITY_TAKE_DMG",
        "MC_PRE_PLAYER_ADD_HEARTS", "MC_POST_PLAYER_ADD_HEARTS", "MC_PRE_PLAYER_UPDATE",
        "MC_POST_GRID_ENTITY_DOOR_UPDATE", "MC_PRE_TRIGGER_PLAYER_DEATH" }
    for _, name in ipairs(required) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog("[我即神明] 当前运行环境缺少必要接口，已停止此道具初始化。") end
            return
        end
    end

    -- Build private owners once; the entry only connects dependencies and installs.
    local Config = include("scripts.features.i_am_a_god.config")
    local State = include("scripts.features.i_am_a_god.state")(mod, context, {
        Config = Config,
    })
    local Health = include("scripts.features.i_am_a_god.health")(mod, context, {
        State = State,
        Config = Config,
    })
    local Presentation = include("scripts.features.i_am_a_god.presentation")(mod, context, {
        State = State,
    })
    local Combat = include("scripts.features.i_am_a_god.combat")(mod, context, {
        State = State,
        Config = Config,
        Health = Health,
        Presentation = Presentation,
    })
    local Lifecycle = include("scripts.features.i_am_a_god.lifecycle")(mod, context, {
        State = State,
        Config = Config,
        Health = Health,
        Combat = Combat,
    })

    Combat.Installers.use()
    Combat.Installers.evaluate()
    Combat.Installers.damage()
    Combat.Installers.preDamage()
    Combat.Installers.postDamage()
    Health.Installers.beforeHealth()
    Health.Installers.afterHealth()
    Health.Installers.beforePlayer()
    Health.Installers.afterPlayer()
    Lifecycle.Installers.death()
    Lifecycle.Installers.removed()
    Health.Installers.removeHeart()
    Health.Installers.removeHeart2()
    Health.Installers.heartCollision()
    State.Installers.holdDoor()
    Combat.Installers.trackTear()
    Lifecycle.Installers.update()
    Presentation.Installers.render()
    Lifecycle.Installers.enterRoom()
    Lifecycle.Installers.newLevel()
    Lifecycle.Installers.started()
    Lifecycle.Installers.exitGame()
    Lifecycle.Installers.exitGame2()
    Lifecycle.Installers.unload()
end
