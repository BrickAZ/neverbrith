return function(Neverbirth, context)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    context = context or {}

    local ITEM_ID = tonumber(context.ItemId) or -1
    local EFFECT_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local PLAYER_ENTITY = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local FRIENDLY_FLAG = EntityFlag and EntityFlag.FLAG_FRIENDLY or nil
    local CHARM_FLAG = EntityFlag and EntityFlag.FLAG_CHARM or nil
    local NO_ENTITY_COLLISION = (EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE) or 0
    local NO_GRID_COLLISION = (GridCollisionClass and GridCollisionClass.COLLISION_NONE) or 0
    local FIREDELAY_CACHE = CacheFlag and CacheFlag.CACHE_FIREDELAY or nil
    local RANGE_CACHE = CacheFlag and CacheFlag.CACHE_RANGE or nil
    local CAR_BATTERY_ID = CollectibleType and CollectibleType.COLLECTIBLE_CAR_BATTERY or 356
    local PRIMARY_ACTIVE_SLOT = ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0
    local SECONDARY_ACTIVE_SLOT = ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1
    local CAR_BATTERY_CHARGE_PER_HIT = 1
    local CAR_BATTERY_ACTIVE_SLOTS = { PRIMARY_ACTIVE_SLOT, SECONDARY_ACTIVE_SLOT }

    local variants = context.Variants or {}
    local AURA_VARIANT = tonumber(variants.Aura) or -1
    local SHOCKWAVE_VARIANT = tonumber(variants.Shockwave) or -1
    local ACTIVATE_VARIANT = tonumber(variants.Activate) or -1

    local AURA_ANM2 = "gfx/Effects/Annihilation/AnnihilationAura.anm2"
    local AURA_ANIMATION = "AuraLoop"
    local SHOCKWAVE_ANM2 = "gfx/Effects/Annihilation/AnnihilationShockwave.anm2"
    local SHOCKWAVE_ANIMATION = "Shockwave"
    local ACTIVATE_ANM2 = "gfx/Effects/Annihilation/AnnihilationActivate.anm2"
    local ACTIVATE_ANIMATION = "Activate"

    local DURATION_FRAMES = 150
    local KILL_EXTENSION_FRAMES = 9
    local AURA_INTERVAL_FRAMES = 4
    local AURA_RADIUS = 75
    local AURA_DAMAGE_MULTIPLIER = 0.40
    local SHOCKWAVE_RADIUS = 115
    local SHOCKWAVE_DAMAGE_MULTIPLIER = 1.00
    local SHOCKWAVE_FRAMES = 8
    local ACTIVATE_FRAMES = 6
    local RANGE_MULTIPLIER = 0.45
    local FIRE_FREQUENCY_MULTIPLIER = 0.60
    local GROUND_DEPTH_OFFSET = -10000
    local DEATH_DATA_KEY = "NeverbirthAnnihilationDeathResolved"
    local NO_DISCHARGE_RESULT = { Discharge = false, Remove = false, ShowAnim = false }

    local runtime = {
        states = {},
        roomNpcs = {},
        logicalFrame = 0,
    }

    local Config = {
        ITEM_ID = ITEM_ID,
        EFFECT_ENTITY = EFFECT_ENTITY,
        PLAYER_ENTITY = PLAYER_ENTITY,
        FRIENDLY_FLAG = FRIENDLY_FLAG,
        CHARM_FLAG = CHARM_FLAG,
        NO_ENTITY_COLLISION = NO_ENTITY_COLLISION,
        NO_GRID_COLLISION = NO_GRID_COLLISION,
        FIREDELAY_CACHE = FIREDELAY_CACHE,
        RANGE_CACHE = RANGE_CACHE,
        CAR_BATTERY_ID = CAR_BATTERY_ID,
        PRIMARY_ACTIVE_SLOT = PRIMARY_ACTIVE_SLOT,
        SECONDARY_ACTIVE_SLOT = SECONDARY_ACTIVE_SLOT,
        CAR_BATTERY_CHARGE_PER_HIT = CAR_BATTERY_CHARGE_PER_HIT,
        CAR_BATTERY_ACTIVE_SLOTS = CAR_BATTERY_ACTIVE_SLOTS,
        AURA_VARIANT = AURA_VARIANT,
        SHOCKWAVE_VARIANT = SHOCKWAVE_VARIANT,
        ACTIVATE_VARIANT = ACTIVATE_VARIANT,
        AURA_ANM2 = AURA_ANM2,
        AURA_ANIMATION = AURA_ANIMATION,
        SHOCKWAVE_ANM2 = SHOCKWAVE_ANM2,
        SHOCKWAVE_ANIMATION = SHOCKWAVE_ANIMATION,
        ACTIVATE_ANM2 = ACTIVATE_ANM2,
        ACTIVATE_ANIMATION = ACTIVATE_ANIMATION,
        DURATION_FRAMES = DURATION_FRAMES,
        KILL_EXTENSION_FRAMES = KILL_EXTENSION_FRAMES,
        AURA_INTERVAL_FRAMES = AURA_INTERVAL_FRAMES,
        AURA_RADIUS = AURA_RADIUS,
        AURA_DAMAGE_MULTIPLIER = AURA_DAMAGE_MULTIPLIER,
        SHOCKWAVE_RADIUS = SHOCKWAVE_RADIUS,
        SHOCKWAVE_DAMAGE_MULTIPLIER = SHOCKWAVE_DAMAGE_MULTIPLIER,
        SHOCKWAVE_FRAMES = SHOCKWAVE_FRAMES,
        ACTIVATE_FRAMES = ACTIVATE_FRAMES,
        RANGE_MULTIPLIER = RANGE_MULTIPLIER,
        FIRE_FREQUENCY_MULTIPLIER = FIRE_FREQUENCY_MULTIPLIER,
        GROUND_DEPTH_OFFSET = GROUND_DEPTH_OFFSET,
        DEATH_DATA_KEY = DEATH_DATA_KEY,
        NO_DISCHARGE_RESULT = NO_DISCHARGE_RESULT,
    }
    local Queries = include("scripts.features.annihilation.queries")(Neverbirth, {
        Context = context,
        State = runtime,
        Config = Config,
    })
    local Ledger = include("scripts.features.annihilation.ledger")(Neverbirth, {
        State = runtime,
        Config = Config,
        Queries = Queries,
    })
    local Presentation = include("scripts.features.annihilation.presentation")(Neverbirth, {
        Context = context,
        Config = Config,
        Queries = Queries,
    })
    local Combat = include("scripts.features.annihilation.combat")(Neverbirth, {
        State = runtime,
        Config = Config,
        Queries = Queries,
        Ledger = Ledger,
        Presentation = Presentation,
    })
    local Runtime = include("scripts.features.annihilation.runtime")(Neverbirth, {
        State = runtime,
        Config = Config,
        Queries = Queries,
        Ledger = Ledger,
        Presentation = Presentation,
        Combat = Combat,
    })
    Runtime.Installers.useItem()
    Runtime.Installers.postUpdate()
    if ModCallbacks.MC_EVALUATE_CACHE then
        Runtime.Installers.evaluateCache()
    end
    if ModCallbacks.MC_POST_FIRE_TEAR then
        Runtime.Installers.postFireTear()
    end
    if ModCallbacks.MC_POST_NPC_INIT then
        Runtime.Installers.npcInit()
    end
    if ModCallbacks.MC_NPC_UPDATE then
        Runtime.Installers.npcUpdate()
    end
    if ModCallbacks.MC_POST_NPC_DEATH then
        Runtime.Installers.npcDeath()
    end
    if ModCallbacks.MC_POST_ENTITY_KILL then
        Runtime.Installers.entityKill()
    end
    if ModCallbacks.MC_POST_NEW_ROOM then
        Runtime.Installers.newRoom()
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        Runtime.Installers.gameStarted()
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Runtime.Installers.preGameExit()
    end

    Queries.trace("init")
    local api = {
        SetDiagnostics = Queries.SetDiagnostics,
        Failures = Queries.Failures,
        ItemId = ITEM_ID,
        Variants = { Aura = AURA_VARIANT, Shockwave = SHOCKWAVE_VARIANT, Activate = ACTIVATE_VARIANT },
        Paths = { Aura = AURA_ANM2, Shockwave = SHOCKWAVE_ANM2, Activate = ACTIVATE_ANM2 },
        Animations = { Aura = AURA_ANIMATION, Shockwave = SHOCKWAVE_ANIMATION, Activate = ACTIVATE_ANIMATION },
        DurationFrames = DURATION_FRAMES,
        KillExtensionFrames = KILL_EXTENSION_FRAMES,
        AuraIntervalFrames = AURA_INTERVAL_FRAMES,
        AuraRadius = AURA_RADIUS,
        ShockwaveRadius = SHOCKWAVE_RADIUS,
        RangeMultiplier = RANGE_MULTIPLIER,
        FireFrequencyMultiplier = FIRE_FREQUENCY_MULTIPLIER,
        CarBatteryId = CAR_BATTERY_ID,
        CarBatteryChargePerHit = CAR_BATTERY_CHARGE_PER_HIT,
        Runtime = runtime,
        GetState = Ledger.getState,
        IsHostileNpc = Queries.isHostileNpc,
        StartState = Runtime.startState,
        EndState = Runtime.endState,
        CreateShockwave = Presentation.createShockwave,
        ChargeCarBatterySynergy = Combat.chargeCarBatterySynergy,
        ResolveEnemyDeath = Runtime.resolveEnemyDeath,
        Callbacks = {
            UseItem = Runtime.useItem,
            Update = Runtime.postUpdate,
            EvaluateCache = Runtime.evaluateCache,
            PostFireTear = Runtime.postFireTear,
            NpcInit = Runtime.npcInit,
            NpcUpdate = Runtime.npcUpdate,
            NpcDeath = Runtime.npcDeath,
            EntityKill = Runtime.entityKill,
            NewRoom = Runtime.newRoom,
            GameStarted = Runtime.gameStarted,
            PreGameExit = Runtime.preGameExit,
        },
    }
    Neverbirth.AnnihilationTestAPI = api
    return api
end
