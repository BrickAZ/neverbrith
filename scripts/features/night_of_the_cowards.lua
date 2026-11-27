-- One instance per installation; gameplay and native bindings live in private modules.
return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = tonumber(context.ItemId) or -1
    local PLAYER_ENTITY = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local EFFECT_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local HOST_ENTITY = (EntityType and EntityType.ENTITY_HOST) or 27
    local AURA_VARIANT = tonumber(context.AuraVariant)
        or (EffectVariant and EffectVariant.HALO)
        or 123
    local AURA_SUBTYPE = tonumber(context.AuraSubtype) or 3
    local FLIGHT_ITEM_ID = tonumber(context.FlightItemId)
        or (CollectibleType and CollectibleType.COLLECTIBLE_TRANSCENDENCE)
        or 20
    local ENEMY_PARTITION = (EntityPartition and EntityPartition.ENEMY) or 1
    local NO_ENTITY_COLLISION = (EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE) or 0
    local NO_GRID_COLLISION = (GridCollisionClass and GridCollisionClass.COLLISION_NONE) or 0
    local CURSED_DEATH_HEAD_TYPE = tonumber(context.CursedDeathHeadType) or 212
    local CURSED_DEATH_HEAD_VARIANT = tonumber(context.CursedDeathHeadVariant) or 2
    local AURA_VISUAL_SCALE = tonumber(context.AuraVisualScale) or 0.75
    local AURA_VISUAL_OFFSET_Y = tonumber(context.AuraVisualOffsetY) or -16
    local AURA_DEPTH_OFFSET = tonumber(context.AuraDepthOffset) or -10
    local AURA_PLAYBACK_SPEED = tonumber(context.AuraPlaybackSpeed) or 1.0
    local FRIENDLY_FLAG = EntityFlag and EntityFlag.FLAG_FRIENDLY or nil
    local CHARM_FLAG = EntityFlag and EntityFlag.FLAG_CHARM or nil
    local AURA_ANM2 = "gfx/1000.123_Halo (Curse).anm2"
    local AURA_ANIMATION = "Idle"
    local PLAYER_FEAR_ANM2 = "gfx/statuseffects.anm2"
    local PLAYER_FEAR_ANIMATION = "Fear"
    local AURA_RADIUS = 48
    local AURA_RADIUS_SQUARED = AURA_RADIUS * AURA_RADIUS
    local HOST_VARIANTS = { 0, 1, 3 }
    local AURA_DATA_KEY = "NeverbirthCowardsNightAura"
    local AURA_OWNER_KEY = "NeverbirthCowardsNightAuraOwner"
    local TRANSFORMED_DATA_KEY = "NeverbirthCowardsNightTransformed"
    local PLAYER_BLOCK_DATA_KEY = "NeverbirthCowardsNightShootBlocked"

    local runtime = {
        active = false,
        auras = {},
        blockedPlayers = {},
        fearSprites = {},
        localC20Grants = {},
    }


    local Config = {
        ITEM_ID = ITEM_ID,
        PLAYER_ENTITY = PLAYER_ENTITY,
        EFFECT_ENTITY = EFFECT_ENTITY,
        HOST_ENTITY = HOST_ENTITY,
        AURA_VARIANT = AURA_VARIANT,
        AURA_SUBTYPE = AURA_SUBTYPE,
        FLIGHT_ITEM_ID = FLIGHT_ITEM_ID,
        ENEMY_PARTITION = ENEMY_PARTITION,
        NO_ENTITY_COLLISION = NO_ENTITY_COLLISION,
        NO_GRID_COLLISION = NO_GRID_COLLISION,
        CURSED_DEATH_HEAD_TYPE = CURSED_DEATH_HEAD_TYPE,
        CURSED_DEATH_HEAD_VARIANT = CURSED_DEATH_HEAD_VARIANT,
        AURA_VISUAL_SCALE = AURA_VISUAL_SCALE,
        AURA_VISUAL_OFFSET_Y = AURA_VISUAL_OFFSET_Y,
        AURA_DEPTH_OFFSET = AURA_DEPTH_OFFSET,
        AURA_PLAYBACK_SPEED = AURA_PLAYBACK_SPEED,
        FRIENDLY_FLAG = FRIENDLY_FLAG,
        CHARM_FLAG = CHARM_FLAG,
        AURA_ANM2 = AURA_ANM2,
        AURA_ANIMATION = AURA_ANIMATION,
        PLAYER_FEAR_ANM2 = PLAYER_FEAR_ANM2,
        PLAYER_FEAR_ANIMATION = PLAYER_FEAR_ANIMATION,
        AURA_RADIUS = AURA_RADIUS,
        AURA_RADIUS_SQUARED = AURA_RADIUS_SQUARED,
        HOST_VARIANTS = HOST_VARIANTS,
        AURA_DATA_KEY = AURA_DATA_KEY,
        AURA_OWNER_KEY = AURA_OWNER_KEY,
        TRANSFORMED_DATA_KEY = TRANSFORMED_DATA_KEY,
        PLAYER_BLOCK_DATA_KEY = PLAYER_BLOCK_DATA_KEY,
    }

    local queries = include("scripts.features.night_of_the_cowards.queries")(Neverbirth, {
        Context = context,
        Config = Config,
    })

    local grants = include("scripts.features.night_of_the_cowards.grants")(Neverbirth, {
        Context = context,
        Runtime = runtime,
        Config = Config,
        debugLog = queries.debugLog,
        playerKey = queries.playerKey,
        collectibleCount = queries.collectibleCount,
    })

    local aura = include("scripts.features.night_of_the_cowards.aura")(Neverbirth, {
        Runtime = runtime,
        Config = Config,
        zeroVector = queries.zeroVector,
        debugLog = queries.debugLog,
        makeVector = queries.makeVector,
        entityExists = queries.entityExists,
        isAuraEnemy = queries.isAuraEnemy,
        isNativeCursedDeathHead = queries.isNativeCursedDeathHead,
        isTransformableEnemy = queries.isTransformableEnemy,
        getData = queries.getData,
        stableHostVariant = queries.stableHostVariant,
    })

    local fear = include("scripts.features.night_of_the_cowards.fear")(Neverbirth, {
        Runtime = runtime,
        Config = Config,
        zeroVector = queries.zeroVector,
        debugLog = queries.debugLog,
        makeVector = queries.makeVector,
        playerKey = queries.playerKey,
        toPlayer = queries.toPlayer,
        isAuraEnemy = queries.isAuraEnemy,
        getData = queries.getData,
        distanceSquared = queries.distanceSquared,
    })

    local lifecycle = include("scripts.features.night_of_the_cowards.runtime")(Neverbirth, {
        Runtime = runtime,
        getPlayers = queries.getPlayers,
        anyPlayerHasItem = queries.anyPlayerHasItem,
        getPersistentData = grants.getPersistentData,
        grantTranscendenceOnce = grants.grantTranscendenceOnce,
        clearAuras = aura.clearAuras,
        clearPlayerBlocks = fear.clearPlayerBlocks,
        applyPlayerAuraState = fear.applyPlayerAuraState,
    })

    lifecycle.Installers.postUpdate()
    if ModCallbacks.MC_NPC_UPDATE then
        aura.Installers.npcUpdate()
    end
    if ModCallbacks.MC_POST_EFFECT_UPDATE then
        aura.Installers.effectUpdate()
    end
    if ModCallbacks.MC_POST_PLAYER_RENDER then
        fear.Installers.postPlayerRender()
    end
    if ModCallbacks.MC_INPUT_ACTION then
        if InputHook then
            fear.Installers.inputAction()
            fear.Installers.inputAction2()
            fear.Installers.inputAction3()
        else
            fear.Installers.inputAction4()
        end
    end
    if ModCallbacks.MC_POST_NEW_ROOM then
        lifecycle.Installers.newRoom()
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        lifecycle.Installers.gameStarted()
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        lifecycle.Installers.preGameExit()
    end

    local api = {
        ItemId = ITEM_ID,
        FlightItemId = FLIGHT_ITEM_ID,
        AuraVariant = AURA_VARIANT,
        AuraSubtype = AURA_SUBTYPE,
        AuraRadius = AURA_RADIUS,
        AuraPath = AURA_ANM2,
        AuraAnimation = AURA_ANIMATION,
        HostVariants = HOST_VARIANTS,
        Runtime = runtime,
        IsAuraEnemy = queries.isAuraEnemy,
        IsNativeCursedDeathHead = queries.isNativeCursedDeathHead,
        AuraVisualScale = AURA_VISUAL_SCALE,
        AuraVisualOffsetY = AURA_VISUAL_OFFSET_Y,
        AuraDepthOffset = AURA_DEPTH_OFFSET,
        AuraPlaybackSpeed = AURA_PLAYBACK_SPEED,
        GetPlayerFearWorldPosition = fear.getPlayerFearWorldPosition,
        IsTransformableEnemy = queries.isTransformableEnemy,
        StableHostVariant = queries.stableHostVariant,
        TransformEnemy = aura.transformEnemy,
        EnsureAura = aura.ensureAura,
        ClearAuras = aura.clearAuras,
        ApplyPlayerAuraState = fear.applyPlayerAuraState,
        GrantTranscendenceOnce = grants.grantTranscendenceOnce,
        GetPersistentData = grants.getPersistentData,
        Callbacks = {
            Update = lifecycle.postUpdate,
            NpcUpdate = aura.npcUpdate,
            EffectUpdate = aura.effectUpdate,
            PlayerRender = fear.postPlayerRender,
            InputAction = fear.inputAction,
            NewRoom = lifecycle.newRoom,
            GameStarted = lifecycle.gameStarted,
            PreGameExit = lifecycle.preGameExit,
        },
    }
    Neverbirth.NightOfTheCowardsTestAPI = api
    return api
end
