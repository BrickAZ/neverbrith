-- Create each private instance once; preserve the disabled character policy and callback order.
return function(Neverbirth, dependencies)
    local lifetime = { runtimeActive = true, disposed = false, restoringCache = false }
    local shadowState = { roomKey = nil, consumedPlayerShadows = {}, shadowDamageDepth = 0 }
    Neverbirth.Cleaver = Neverbirth.Cleaver or {}
    Neverbirth.Cleaver.Config = Neverbirth.Cleaver.Config or {
        PlayerName = "Stranger",
        Registered = false,
        PlayerType = nil,
        CleaverVisualPath = "gfx/Effects/CleaverAttack/stranger_machete.anm2",
        -- The authored swing has 11 animation frames at 30 FPS: approximately 22 game ticks.
        CleaverVisualTimeout = 22,
        SwingDurationTicks = 22,
        SwingCarrierFallbackTick = 10,
        -- The authored Stranger machete actor owns both directional idle and A/B swing animation.
        -- The weapon pivots around its authored hand anchor; no render-time flip or center offset is applied.
        HoldVisualPath = "gfx/Effects/CleaverAttack/stranger_machete.anm2",
        -- The authored 96x112 actor is drawn at half scale for both idle and swing states.
        HoldScale = 0.5,
        AnimationTicksPerFrame = 2,
        HoldOffsets = {
            IdleUp = { x = 0, y = 0 },
            IdleDown = { x = 0, y = 0 },
            IdleLeft = { x = 0, y = 0 },
            IdleRight = { x = 0, y = 0 },
        },
        -- Native Spirit Sword knife plus a private subtype; CleaverAttack.anm2 stays visual-only.
        -- This carrier has no collision and has no external mod dependency.
        KnifeVariant = 10,
        KnifeSubType = 3016,
        BaseSwingRange = 160,
        BaseSwingHalfWidth = 22,
        ReferencePlayerSize = 20,
        SwingArcDegrees = 180,
        SwingCooldownFrames = 10,
        -- Native Knife is visual/lifecycle-only; this is only the fallback carrier spawn tick.
        SwingHitFrame = 10,
        SweepAngularPaddingDegrees = 3,
        SwingKnockback = 8,
        PlayerShadowDamageSource = "shadowOwner",
        BaseDamage = 2.0,
        IsaacBaseDamage = 3.5,
        BaseTears = 2.73,
        BaseRange = 6.50,
        BaseShotSpeed = 1.00,
        ConversionCaps = { minimum = -0.50, maximum = 1.00, positiveTotal = 1.50 },
        ShadowAlpha = 0.45,
        FixedBodyDamage = 0.5,
    }
    Neverbirth.Cleaver.Config.Registered = false
    local Queries = include("scripts.features.cleaver.queries")(Neverbirth, {
        World = dependencies.World,
        GetPlayers = dependencies.GetPlayers,
    })
    Neverbirth.Cleaver.Config.PlayerType = Queries.ResolvePlayerType()
    Neverbirth.Cleaver.states = Neverbirth.Cleaver.states or {}
    Neverbirth.Cleaver.shadows = Neverbirth.Cleaver.shadows or {}
    local Attributes = include("scripts.features.cleaver.attributes")(Neverbirth, {
        Lifetime = lifetime,
    })
    local Geometry = include("scripts.features.cleaver.geometry")(Neverbirth, {

    })
    local Presentation = include("scripts.features.cleaver.presentation")(Neverbirth, {
        Lifetime = lifetime,
        Queries = Queries,
        Geometry = Geometry,
    })
    local Shadows = include("scripts.features.cleaver.shadows")(Neverbirth, {
        World = dependencies.World,
        GetPlayers = dependencies.GetPlayers,
        ShadowState = shadowState,
        Queries = Queries,
        Presentation = Presentation,
    })
    local Controls = include("scripts.features.cleaver.controls")(Neverbirth, {
        GetPlayers = dependencies.GetPlayers,
        Lifetime = lifetime,
    })
    local Combat = include("scripts.features.cleaver.combat")(Neverbirth, {
        World = dependencies.World,
        Lifetime = lifetime,
        Queries = Queries,
        Geometry = Geometry,
        Presentation = Presentation,
        Shadows = Shadows,
    })
    local Runtime = include("scripts.features.cleaver.runtime")(Neverbirth, {
        World = dependencies.World,
        GetPlayers = dependencies.GetPlayers,
        CleaverId = dependencies.CleaverId,
        IsValidItemId = dependencies.IsValidItemId,
        Lifetime = lifetime,
        ShadowState = shadowState,
        Queries = Queries,
        Attributes = Attributes,
        Presentation = Presentation,
        Shadows = Shadows,
        Controls = Controls,
        Combat = Combat,
    })
    Attributes.Installers.Cache()
    if ModCallbacks.MC_POST_FIRE_TEAR then Controls.Installers.FireTear() end
    if ModCallbacks.MC_POST_KNIFE_UPDATE then Combat.Installers.KnifeUpdate() end
    if ModCallbacks.MC_PRE_KNIFE_COLLISION then Combat.Installers.KnifeCollision() end
    Runtime.Installers.Update()
    if ModCallbacks.MC_POST_RENDER then Presentation.Installers.Render() end
    if ModCallbacks.MC_POST_NEW_ROOM then Runtime.Installers.NewRoom() end
    if ModCallbacks.MC_POST_GAME_STARTED then Runtime.Installers.GameStarted() end
    if ModCallbacks.MC_PRE_GAME_EXIT then Runtime.Installers.Exit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then Runtime.Installers.Unload() end
end
