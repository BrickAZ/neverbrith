-- Create each private instance once; retain the original callback installation order.
return function(Neverbirth, dependencies)
    Neverbirth.BurnAwayResentment = Neverbirth.BurnAwayResentment or {}
    local Config = {
        MaxLayers = 6,
        InitialLayers = 2,
        SpeedPenaltyPerLayer = 0.04,
        MinimumSpeed = 0.5,
        DamagePerClarity = 0.35,
        TearsPerClarity = 0.12,
        ActivePurgeMultiplier = 3.0,
        HurtPurgeMultiplierPerLayer = 0.5,
        BurnDuration = 90,
        StatusPath = "gfx/Effects/BurnAwayResentment/ResentmentStatus.anm2",
        BurstPath = "gfx/Effects/BurnAwayResentment/PurgeWave.anm2",
        BurstTimeout = 36,
    }
    Neverbirth.BurnAwayResentment.states = Neverbirth.BurnAwayResentment.states or {}
    Neverbirth.BurnAwayResentment.GetPlayerHeadWorldPosition = dependencies.GetPlayerHeadWorldPosition
    local lifetime = { active = true, disposed = false }
    local Queries = include("scripts.features.burn_away_resentment.queries")(Neverbirth, {
        World = dependencies.World, ItemId = dependencies.BurnAwayResentmentId,
    })
    local Attributes = include("scripts.features.burn_away_resentment.attributes")(Neverbirth, {
        World = dependencies.World, Config = Config, Queries = Queries,
    })
    local Ledger = include("scripts.features.burn_away_resentment.ledger")(Neverbirth, {
        World = dependencies.World, Config = Config, Queries = Queries, Attributes = Attributes,
    })
    local Presentation = include("scripts.features.burn_away_resentment.presentation")(Neverbirth, {
        World = dependencies.World, Config = Config, Queries = Queries,
    })
    local Combat = include("scripts.features.burn_away_resentment.combat")(Neverbirth, {
        World = dependencies.World, Config = Config, Lifetime = lifetime,
        Queries = Queries, Attributes = Attributes, Presentation = Presentation,
    })
    local Runtime = include("scripts.features.burn_away_resentment.runtime")(Neverbirth, {
        World = dependencies.World, Config = Config, Lifetime = lifetime, GetPlayers = dependencies.GetPlayers,
        Queries = Queries, Attributes = Attributes, Ledger = Ledger, Presentation = Presentation, Combat = Combat,
    })
    Runtime.Installers.Update()
    Attributes.Installers.Cache()
    Combat.Installers.Damage()
    if ModCallbacks.MC_POST_RENDER then Presentation.Installers.Render() end
    if ModCallbacks.MC_POST_NEW_ROOM then Runtime.Installers.NewRoom() end
    if ModCallbacks.MC_POST_NEW_LEVEL then Runtime.Installers.NewLevel() end
    if ModCallbacks.MC_POST_GAME_STARTED then Runtime.Installers.GameStarted() end
    if ModCallbacks.MC_PRE_GAME_EXIT then Runtime.Installers.GameExit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then Runtime.Installers.Unload() end
end
