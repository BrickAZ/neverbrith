-- God Complex / 神性过载. Timed owner-only active; no rewards or room mutations.
-- REPENTOGON 1.0.12a: laser/knife damage can expose Player as its source.
-- Collision scopes supply narrow provenance; optional ExtraSource also supports
-- newer runtimes. Unknown player/effect damage is deliberately left alone.
return function(mod, context)
    local ID=context.ItemId
    if not ID or ID<=0 then return end
    local REQUIRED={'MC_POST_ENTITY_TAKE_DMG','MC_PRE_PLAYER_UPDATE','MC_PRE_LASER_COLLISION',
        'MC_POST_LASER_COLLISION','MC_POST_KNIFE_COLLISION','MC_PRE_PLAYER_RENDER'}
    for _,name in ipairs(REQUIRED) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog('[God Complex] Missing callback: '..name) end
            return
        end
    end
    -- Build private owners once; the entry only connects dependencies and installs.
    local Config = include("scripts.features.god_complex.config")
    local Shooting = include("scripts.systems.shooting_scope").ForOwner(context.ShootingControls, "god_complex")
    local State = include("scripts.features.god_complex.state")(mod, context, {
        Shooting = Shooting,
        Config = Config,
    })
    local Targeting = include("scripts.features.god_complex.targeting")(mod, context, {
        State = State,
    })
    local Presentation = include("scripts.features.god_complex.presentation")(mod, context, {
        State = State,
        Config = Config,
        Targeting = Targeting,
    })
    local Combat = include("scripts.features.god_complex.combat")(mod, context, {
        State = State,
        Config = Config,
        Targeting = Targeting,
    })
    local Lifecycle = include("scripts.features.god_complex.lifecycle")(mod, context, {
        State = State,
        Shooting = Shooting,
        Config = Config,
        Targeting = Targeting,
        Presentation = Presentation,
        Combat = Combat,
    })

    Lifecycle.Installers.use()
    Lifecycle.Installers.evaluate()
    Combat.Installers.preDamage()
    Combat.Installers.postDamage()
    Combat.Installers.entityKilled()
    Combat.Installers.npcDeath()
    Combat.Installers.npcUpdate()
    Combat.Installers.removed()
    Combat.Installers.preCollision()
    Combat.Installers.postCollision()
    Combat.Installers.preCollision2()
    Combat.Installers.postCollision2()
    Combat.Installers.fireTear()
    Lifecycle.Installers.prePlayer()
    Lifecycle.Installers.postPlayer()
    Lifecycle.Installers.update()
    Presentation.Installers.renderUnderPlayer()
    Presentation.Installers.render()
    State.Installers.clear()
    State.Installers.clear2()
    Lifecycle.Installers.started()
    Lifecycle.Installers.died()
    Lifecycle.Installers.lost()
    Lifecycle.Installers.exitGame()
    Lifecycle.Installers.exitGame2()
    Lifecycle.Installers.unload()
end
