-- Own the family configuration and instances; preserve legacy callback order.
return function(Neverbirth, context)
    context = context or {}
    local ITEM_IDS = context.ItemIds or {}
    local BIG_DOG_BARK_ID = tonumber(ITEM_IDS.BigDogBark) or -1
    local WIND_CHARGE_ROD_ID = tonumber(ITEM_IDS.WindChargeRod) or -1
    local ECHO_SHARD_ID = tonumber(ITEM_IDS.EchoShard) or -1
    local VARIANTS = context.Variants or {}
    local DOG_VARIANT = tonumber(VARIANTS.Dog) or 3017
    local ECHO_VARIANT = tonumber(VARIANTS.Echo) or 3018
    local TRAIL_VARIANT = tonumber(VARIANTS.Trail) or 3019
    local EFFECT_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local ENEMY_PARTITION = (EntityPartition and EntityPartition.ENEMY) or 1
    local NO_ENTITY_COLLISION = (EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE) or 0
    local NO_GRID_COLLISION = (GridCollisionClass and GridCollisionClass.COLLISION_NONE) or 0
    local FRIENDLY_FLAG = (EntityFlag and EntityFlag.FLAG_FRIENDLY) or 0
    local CHARM_FLAG = (EntityFlag and EntityFlag.FLAG_CHARM) or 0

    local Constants = {
        DASH_DISTANCE = 320,
        DASH_SPEED = 20,
        HIT_RADIUS = 30,
        ECHO_DELAY_FRAMES = 12,
        TRAIL_RADIUS = 40,
        ENHANCED_TRAIL_RADIUS = 60,
        TRAIL_INTERVAL_FRAMES = 4,
        TRAIL_LIFETIME_FRAMES = 150,
        WIND_IMPULSE = 8,
        WIND_SPEED_CAP = 12,
        CHEW_SPEED = 8,
        CHEW_APPROACH_RADIUS = 80,
        CHEW_LUNGE_DISTANCE = 72,
        CHEW_LUNGE_SPEED = 12,
        CHEW_HIT_RADIUS = 24,
        CHEW_PATH_REFRESH_FRAMES = 12,
        CHEW_PATH_FAILURE_LIMIT = 3,
        CHEW_MOVE_LERP = 0.35,
        CHEW_SAFE_POSITION_INTERVAL = 6,
        CHEW_PAUSE_FRAMES = 20,
        CHEW_SEARCH_RETRY_FRAMES = 15,
        FOOD_SETTLE_DELAY_FRAMES = 2,
        FOOD_SETTLE_TIMEOUT_FRAMES = 10,
        TRAIL_SLOW_DURATION = 30,
        TRAIL_SLOW_MULTIPLIER = 0.5,
        DOG_VISUAL_SCALE = 0.5,
        ECHO_VISUAL_SCALE = 0.5,
        TRAIL_VISUAL_SCALE = 0.5,
        FOLLOW_LERP = 0.35,
        FOLLOW_TELEPORT_DISTANCE = 160,
        CHARGE_BAR_PATH = "gfx/chargebar.anm2",
        CHARGE_BAR_HEAD_OFFSET_X = -8,
        CHARGE_BAR_HEAD_OFFSET_Y = -44,
        CHARGE_SOUND_DURATION_SECONDS = 0.441179,
        CHARGE_SOUND_FRAMES_PER_SECOND = 30,
        CHARGE_SOUND_START_PITCH = 1,
        CHARGE_SOUND_PITCH_STEP = 0.2,
        CHARGE_SOUND_MAX_PITCH = 2,
    }

    local SOUND_NAMES = {
        Charge = "Big Dog Bark Charge",
        Release = "Big Dog Bark Release",
    }
    local Queries = include("scripts.features.big_dog_bark.queries")(Neverbirth, {
        Context = context,
        BIG_DOG_BARK_ID = BIG_DOG_BARK_ID,
    })
    local Rules = include("scripts.features.big_dog_bark.rules")(Neverbirth, {
        Queries = Queries,
    })
    local State = include("scripts.features.big_dog_bark.state")(Neverbirth, {
        Context = context,
        Queries = Queries,
    })
    local Audio = include("scripts.features.big_dog_bark.audio")(Neverbirth, {
        Constants = Constants,
        SOUND_NAMES = SOUND_NAMES,
        State = State,
    })
    local Effects = include("scripts.features.big_dog_bark.effects")(Neverbirth, {
        DOG_VARIANT = DOG_VARIANT,
        EFFECT_ENTITY = EFFECT_ENTITY,
        NO_ENTITY_COLLISION = NO_ENTITY_COLLISION,
        NO_GRID_COLLISION = NO_GRID_COLLISION,
        Constants = Constants,
        Queries = Queries,
        State = State,
    })
    local Targets = include("scripts.features.big_dog_bark.targets")(Neverbirth, {
        EFFECT_ENTITY = EFFECT_ENTITY,
        PICKUP_ENTITY = PICKUP_ENTITY,
        ENEMY_PARTITION = ENEMY_PARTITION,
        FRIENDLY_FLAG = FRIENDLY_FLAG,
        CHARM_FLAG = CHARM_FLAG,
        State = State,
        Queries = Queries,
        Effects = Effects,
    })
    local Trails = include("scripts.features.big_dog_bark.trails")(Neverbirth, {
        TRAIL_VARIANT = TRAIL_VARIANT,
        Constants = Constants,
        State = State,
        Queries = Queries,
        Effects = Effects,
        Targets = Targets,
    })
    local Food = include("scripts.features.big_dog_bark.food")(Neverbirth, {
        PICKUP_ENTITY = PICKUP_ENTITY,
        COLLECTIBLE_PICKUP = COLLECTIBLE_PICKUP,
        Constants = Constants,
        State = State,
        Queries = Queries,
    })
    local Lifecycle = include("scripts.features.big_dog_bark.lifecycle")(Neverbirth, {
        State = State,
        Audio = Audio,
        Effects = Effects,
        Targets = Targets,
        Trails = Trails,
        Food = Food,
    })
    local EchoShard = include("scripts.features.echo_shard")(Neverbirth, {
        ECHO_VARIANT = ECHO_VARIANT,
        Constants = Constants,
        State = State,
        Queries = Queries,
        Effects = Effects,
        Targets = Targets,
        Trails = Trails,
        ECHO_SHARD_ID = ECHO_SHARD_ID,
    })
    local Dash = include("scripts.features.big_dog_bark.dash")(Neverbirth, {
        ECHO_SHARD_ID = ECHO_SHARD_ID,
        Constants = Constants,
        State = State,
        Queries = Queries,
        Rules = Rules,
        Audio = Audio,
        Effects = Effects,
        Targets = Targets,
        Trails = Trails,
        EchoShard = EchoShard,
    })
    local Chew = include("scripts.features.big_dog_bark.chew")(Neverbirth, {
        NO_GRID_COLLISION = NO_GRID_COLLISION,
        Constants = Constants,
        State = State,
        Queries = Queries,
        Rules = Rules,
        Effects = Effects,
        Targets = Targets,
    })
    local Hud = include("scripts.features.big_dog_bark.hud")(Neverbirth, {
        Constants = Constants,
        State = State,
        Queries = Queries,
    })
    local Rod = include("scripts.features.wind_charge_rod")(WIND_CHARGE_ROD_ID, Queries.hasCollectible)
    local Input = include("scripts.features.big_dog_bark.input")(Neverbirth, {
        Context = context,
        BIG_DOG_BARK_ID = BIG_DOG_BARK_ID,
        DOG_VARIANT = DOG_VARIANT,
        Constants = Constants,
        State = State,
        Rod = Rod,
        Queries = Queries,
        Rules = Rules,
        Audio = Audio,
        Effects = Effects,
        Lifecycle = Lifecycle,
        Dash = Dash,
        Chew = Chew,
        Hud = Hud,
    })
    local UpgradePool = include("scripts.features.big_dog_bark.upgrade_pool")(Neverbirth, {
        WIND_CHARGE_ROD_ID = WIND_CHARGE_ROD_ID,
        ECHO_SHARD_ID = ECHO_SHARD_ID,
        Queries = Queries,
    })
    local Callbacks = {
        PostGetCollectible = UpgradePool.postGetCollectible,
        UseItem = Input.useItem,
        PlayerUpdate = Input.postPlayerUpdate,
        PostPlayerUpdate = Input.postPlayerUpdate,
        PlayerRender = Hud.postPlayerRender,
        PrePickupCollision = Food.prePickupCollision,
        NPCInit = Targets.npcInit,
        EntityRemove = Targets.entityRemove,
        UsePill = Input.usePill,
        UpdateDog = Input.updateDog,
        UpdateEcho = EchoShard.updateEcho,
        UpdateTrail = Trails.updateTrail,
        PostUpdate = Lifecycle.postUpdate,
        NewRoom = Lifecycle.newRoom,
        NewLevel = Lifecycle.newLevel,
        GameStarted = Lifecycle.gameStarted,
        PreGameExit = Lifecycle.preGameExit,
    }

    Neverbirth.BigDogBarkTestAPI = {
        ItemId = BIG_DOG_BARK_ID,
        RodItemId = WIND_CHARGE_ROD_ID,
        EchoItemId = ECHO_SHARD_ID,
        PillEffectId = Input.PillEffectId,
        Constants = Constants,
        SoundNames = SOUND_NAMES,
        Runtime = State.Runtime,
        GetChargeSeconds = Rules.getChargeSeconds,
        GetChargeFrames = Rules.getChargeFrames,
        ResolveDirection = Rules.resolveDirection,
        HasBigDogActive = Queries.hasBigDogActive,
        GetChargeProgress = Hud.chargeProgress,
        IsBusy = Rules.isBusy,
        ComputeDashDamage = Rules.computeDashDamage,
        ComputeEchoDamage = EchoShard.computeEchoDamage,
        ComputeChewDamage = Rules.computeChewDamage,
        ApplyVelocityImpulse = Rules.applyVelocityImpulse,
        EntityKey = Queries.entityKey,
        ResolveEntityReference = Targets.resolveEntityReference,
        RegisterHit = Rules.registerHit,
        DamageOnce = Targets.damageOnce,
        PointSegmentDistanceSquared = Targets.pointSegmentDistanceSquared,
        CreateEchoFromDash = EchoShard.createEchoFromDash,
        BeginChewPause = Chew.beginChewPause,
        IsChewPauseComplete = Chew.isChewPauseComplete,
        GetPlayerRecord = State.getPlayerRecord,
        CaptureFoodPickup = Food.captureFoodPickup,
        SettleFoodPickups = Food.settleFoodPickups,
        SpawnOrRefreshTrail = Trails.spawnOrRefreshTrail,
        SubmitTrailCandidates = Trails.submitTrailCandidates,
        ApplyTrailCandidates = Trails.applyTrailCandidates,
        SelectChewTarget = Targets.selectChewTarget,
        RegisterRoomTarget = Targets.registerRoomTarget,
        UpdateChew = Chew.updateChew,
        BuildChewGridPath = Chew.buildChewGridPath,
        ShouldRefreshChewPath = Chew.shouldRefreshChewPath,
        SpriteEventTriggered = Effects.spriteEventTriggered,
        UseWindPill = State.useWindPill,
        PlaySoundCue = Audio.playSoundCue,
        Launch = Dash.launch,
        ResetForTest = Lifecycle.resetForTest,
        Callbacks = Callbacks,
    }

    if BIG_DOG_BARK_ID <= 0 then
        Queries.debugLog("Big Dog Bark item id was not resolved; runtime callbacks stay registered for tests and food history")
    end

    if ModCallbacks then
        if ModCallbacks.MC_POST_GET_COLLECTIBLE then
            UpgradePool.Installers.postGetCollectible()
        end
        if ModCallbacks.MC_USE_ITEM and BIG_DOG_BARK_ID > 0 then
            Input.Installers.useItem()
        end
        if ModCallbacks.MC_POST_PEFFECT_UPDATE then
            Input.Installers.postPlayerUpdate()
        end
        if ModCallbacks.MC_POST_PLAYER_RENDER then
            Hud.Installers.postPlayerRender()
        end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then
            Food.Installers.prePickupCollision()
        end
        if ModCallbacks.MC_POST_NPC_INIT then
            Targets.Installers.npcInit()
        end
        if ModCallbacks.MC_POST_ENTITY_REMOVE then
            Targets.Installers.entityRemove()
        end
        if ModCallbacks.MC_USE_PILL then
            if Input.PillEffectId >= 0 then
                Input.Installers.usePill()
            else
                Input.Installers.usePill2()
            end
        end
        if ModCallbacks.MC_POST_EFFECT_UPDATE then
            Input.Installers.updateDog()
            EchoShard.Installers.updateEcho()
            Trails.Installers.updateTrail()
        end
        if ModCallbacks.MC_POST_UPDATE then
            Lifecycle.Installers.postUpdate()
        end
        if ModCallbacks.MC_POST_NEW_ROOM then
            Lifecycle.Installers.newRoom()
        end
        if ModCallbacks.MC_POST_NEW_LEVEL then
            Lifecycle.Installers.newLevel()
        end
        if ModCallbacks.MC_POST_GAME_STARTED then
            Lifecycle.Installers.gameStarted()
        end
        if ModCallbacks.MC_PRE_GAME_EXIT then
            Lifecycle.Installers.preGameExit()
        end
    end

    return Neverbirth.BigDogBarkTestAPI
end
