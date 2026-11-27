return function(Neverbirth, dependencies)
    -- Private implementation state stays inside this installed feature instance.
    local private = {}
    local provided = dependencies
    dependencies = {}
    for key, value in pairs(provided) do dependencies[key] = value end
    dependencies.Private = private
    local CreepVariants = dependencies.CreepVariants
    local StrongLaxativeConfig = {
        CreepLifetime = 150,
        CreepInterval = 6,
        CreepRadius = 44,
        CreepDamageInterval = 10,
        SlowDuration = 30,
        PoopRollInterval = 60,
        PoopChancePerCopy = 5,
        RoomPoopCap = 15,
        PoopDistance = 56,
        CostumePath = "gfx/characters/costume_strong_laxative.anm2",
        EntityEffect = (EntityType and EntityType.ENTITY_EFFECT) or 1000,
        GridPoop = (GridEntityType and GridEntityType.GRID_POOP) or 14,
        CreepVariant = EffectVariant.PLAYER_CREEP_HOLYWATER_TRAIL,

        CreepVariants = CreepVariants,
    }

    private.PoopVariants = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 }
    Neverbirth.StrongLaxative = Neverbirth.StrongLaxative or {}

    local presentation = include("scripts.features.strong_laxative.presentation")(Neverbirth, {
        Private = private, Config = StrongLaxativeConfig, ItemId = dependencies.StrongLaxativeId,
    })
    private.Synergies = include("scripts.features.strong_laxative.synergies")(
        StrongLaxativeConfig, dependencies.World.IsVulnerableEnemy)
    local creep = include("scripts.features.strong_laxative.creep")(Neverbirth, {
        Private = private, Config = StrongLaxativeConfig, RemoveCreepIfActive = dependencies.RemoveCreepIfActive,
    })
    local poop = include("scripts.features.strong_laxative.poop")(Neverbirth, {
        Private = private, Config = StrongLaxativeConfig, ItemId = dependencies.StrongLaxativeId,
        IsValidItemId = dependencies.IsValidItemId,
        GetRoom = dependencies.World.GetFolkRoom, GetRoomKey = dependencies.World.GetFolkRoomKey,
    })
    local players = include("scripts.features.strong_laxative.players")(Neverbirth, {
        Private = private, Config = StrongLaxativeConfig, ItemId = dependencies.StrongLaxativeId,
        IsValidItemId = dependencies.IsValidItemId, GetPlayers = dependencies.GetPlayers,
        PlayerHasCollectible = dependencies.World.PlayerHasCollectible,
        GetPlayerKey = dependencies.World.GetFolkPlayerKey, ResetPoopRoom = poop.ResetRoom,
        ResetPoopRuntime = poop.ResetRuntime, ResetPresentation = presentation.ResetRuntime,
        ResetCreep = creep.ResetRuntime,
    })
    -- Explicit original order: player update, effect update, damage, pickup, room reset.
    players.InstallUpdateCallback()
    creep.InstallEffectCallback()
    creep.InstallDamageCallback()
    presentation.InstallPickupCallback()
    players.InstallRoomCallback()
    players.InstallLifecycle()
end
