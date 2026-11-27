-- One instance per installation; gameplay and native bindings live in private modules.
return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = context.ItemId or -1
    local SPAWN_INTERVAL = 90
    local MAX_LIVE_PER_OWNER = 2
    -- Verified against the installed vanilla entities2.xml: Mulliboom is Mulligan type 16, variant 2.
    local MULLIBOOM_TYPE = (EntityType and EntityType.ENTITY_MULLIGAN) or 16
    local MULLIBOOM_VARIANT = 2
    -- Preserved existing dispatch value; native Mulliboom equivalence is not yet measured.
    local MULLIBOOM_EXPLOSION_DAMAGE = 40
    local EXPLOSION_RADIUS_MULTIPLIER = 2

    local OWNED_KEY = "NeverbirthKamikazeSquadOwned"
    local OWNER_KEY = "NeverbirthKamikazeSquadOwner"
    local OWNER_ID_KEY = "NeverbirthKamikazeSquadOwnerId"
    local TARGET_KEY = "NeverbirthKamikazeSquadTarget"
    local DETONATED_KEY = "NeverbirthKamikazeSquadDetonated"
    local FAILED_KEY = "NeverbirthKamikazeSquadExplosionFailed"

    local runtime = {
        holders = {},
        hostiles = {},
        hostileSet = {},
        roomSeeded = false,
    }


    local Config = {
        ITEM_ID = ITEM_ID,
        SPAWN_INTERVAL = SPAWN_INTERVAL,
        MAX_LIVE_PER_OWNER = MAX_LIVE_PER_OWNER,
        MULLIBOOM_TYPE = MULLIBOOM_TYPE,
        MULLIBOOM_VARIANT = MULLIBOOM_VARIANT,
        MULLIBOOM_EXPLOSION_DAMAGE = MULLIBOOM_EXPLOSION_DAMAGE,
        EXPLOSION_RADIUS_MULTIPLIER = EXPLOSION_RADIUS_MULTIPLIER,
        OWNED_KEY = OWNED_KEY,
        OWNER_KEY = OWNER_KEY,
        OWNER_ID_KEY = OWNER_ID_KEY,
        TARGET_KEY = TARGET_KEY,
        DETONATED_KEY = DETONATED_KEY,
        FAILED_KEY = FAILED_KEY,
    }

    local queries = include("scripts.features.kamikaze_squad.queries")(Neverbirth, {
        Context = context,
        Config = Config,
    })

    local targets = include("scripts.features.kamikaze_squad.targets")(Neverbirth, {
        Runtime = runtime,
        entityKey = queries.entityKey,
        isValidHostile = queries.isValidHostile,
        getRoomEntities = queries.getRoomEntities,
    })

    local units = include("scripts.features.kamikaze_squad.units")(Neverbirth, {
        Context = context,
        Runtime = runtime,
        Config = Config,
        diagnostic = queries.diagnostic,
        entityKey = queries.entityKey,
        entityExists = queries.entityExists,
        isDead = queries.isDead,
        isValidHostile = queries.isValidHostile,
        getFreeNearPosition = queries.getFreeNearPosition,
        spawnMulliboom = queries.spawnMulliboom,
        nearestHostile = targets.nearestHostile,
    })

    local lifecycle = include("scripts.features.kamikaze_squad.runtime")(Neverbirth, {
        Runtime = runtime,
        Config = Config,
        diagnostic = queries.diagnostic,
        entityKey = queries.entityKey,
        getPlayers = queries.getPlayers,
        hasItem = queries.hasItem,
        isPlayerUsable = queries.isPlayerUsable,
        trackEnemy = targets.trackEnemy,
        removeTrackedEnemy = targets.removeTrackedEnemy,
        pruneHostiles = targets.pruneHostiles,
        seedRoomHostiles = targets.seedRoomHostiles,
        getHolderState = units.getHolderState,
        pruneUnits = units.pruneUnits,
        removeUnitReference = units.removeUnitReference,
        clearHolder = units.clearHolder,
        clearRuntime = units.clearRuntime,
        detonateAllOwned = units.detonateAllOwned,
        spawnForHolder = units.spawnForHolder,
        updateOwnedUnit = units.updateOwnedUnit,
    })

    lifecycle.Installers.postUpdate()
    if ModCallbacks.MC_NPC_UPDATE then lifecycle.Installers.npcUpdate() end
    if ModCallbacks.MC_POST_NPC_INIT then lifecycle.Installers.npcInit() end
    if ModCallbacks.MC_POST_NPC_DEATH then lifecycle.Installers.npcDeath() end
    if ModCallbacks.MC_POST_ENTITY_REMOVE then lifecycle.Installers.entityRemove() end
    if ModCallbacks.MC_PRE_SPAWN_CLEAN_AWARD then lifecycle.Installers.roomCleared() end
    if ModCallbacks.MC_POST_NEW_ROOM then lifecycle.Installers.newRoom() end
    if ModCallbacks.MC_POST_NEW_LEVEL then lifecycle.Installers.newLevel() end
    if ModCallbacks.MC_POST_GAME_STARTED then lifecycle.Installers.gameStarted() end
    if ModCallbacks.MC_PRE_GAME_EXIT then lifecycle.Installers.preGameExit() end

    return {
        GetState = function(player) return units.getHolderState(player, false) end,
        GetLiveCount = function(player)
            local state = units.getHolderState(player, false)
            if not state then return 0 end
            units.pruneUnits(state)
            return #state.units
        end,
        TrackEnemy = targets.trackEnemy,
        IsValidHostile = queries.isValidHostile,
        Detonate = units.detonate,
        Constants = {
            SpawnInterval = SPAWN_INTERVAL,
            MaxLivePerOwner = MAX_LIVE_PER_OWNER,
            MulliboomType = MULLIBOOM_TYPE,
            MulliboomVariant = MULLIBOOM_VARIANT,
            ExplosionDamage = MULLIBOOM_EXPLOSION_DAMAGE,
            ExplosionRadiusMultiplier = EXPLOSION_RADIUS_MULTIPLIER,
        },
    }
end

