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
    local PILL_NAMES = {}
    local seenPillNames = {}
    local requestedPillNames = type(context.PillNames) == "table"
        and context.PillNames
        or { context.PillName }
    for _, name in ipairs(requestedPillNames) do
        name = tostring(name or "")
        if name ~= "" and not seenPillNames[name] then
            seenPillNames[name] = true
            PILL_NAMES[#PILL_NAMES + 1] = name
        end
    end
    for _, name in ipairs({ "Wind Charge Potion", "蓄风药剂" }) do
        if not seenPillNames[name] then
            seenPillNames[name] = true
            PILL_NAMES[#PILL_NAMES + 1] = name
        end
    end

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

    local runtime = {
        frame = 0,
        serial = 0,
        trailSerial = 0,
        players = {},
        pendingFood = {},
        roomTargets = {},
        roomTargetKeys = {},
        roomTargetVersion = 0,
        chewSearchCount = 0,
        trails = {},
        trailById = {},
        trailCandidates = {},
        lastTrailAppliedFrame = nil,
        fallbackSaveRoot = {},
        testRunSeed = nil,
        savedAtExit = false,

    }

    local soundIds = {}
    local soundManager = nil

    local function debugLog(message)
        local text = "[neverbirth][Big Dog Bark] " .. tostring(message)
        if type(context.DebugLog) == "function" then
            pcall(context.DebugLog, text)
        elseif Isaac and type(Isaac.DebugString) == "function" then
            pcall(Isaac.DebugString, text)
        end
    end

    local function resolveSoundId(cue)
        if soundIds[cue] then
            return soundIds[cue]
        end
        local name = SOUND_NAMES[cue]
        if not name or not Isaac or type(Isaac.GetSoundIdByName) ~= "function" then
            return nil
        end
        local ok, soundId = pcall(Isaac.GetSoundIdByName, name)
        soundId = ok and tonumber(soundId) or nil
        if not soundId or soundId <= 0 then
            return nil
        end
        soundIds[cue] = soundId
        return soundId
    end

    local function playSoundCue(cue, pitch)
        local soundId = resolveSoundId(cue)
        if not soundId or type(SFXManager) ~= "function" then
            return false
        end
        if not soundManager then
            local ok, manager = pcall(SFXManager)
            if ok then
                soundManager = manager
            end
        end
        if not soundManager or type(soundManager.Play) ~= "function" then
            return false
        end
        local ok = pcall(soundManager.Play, soundManager, soundId, 1, 0, false, tonumber(pitch) or 1)
        return ok
    end
    local function chargeSoundIntervalFrames(pitch)
        local safePitch = math.max(0.01, tonumber(pitch) or Constants.CHARGE_SOUND_START_PITCH)
        local frames = Constants.CHARGE_SOUND_DURATION_SECONDS
            * Constants.CHARGE_SOUND_FRAMES_PER_SECOND / safePitch
        return math.max(1, math.floor(frames + 0.5))
    end

    local function clearChargeSoundSchedule(state)
        if type(state) ~= "table" then
            return
        end
        state.chargeSoundPitch = nil
        state.chargeSoundNextFrame = nil
    end

    local function scheduleChargeSound(state, pitch)
        if type(state) ~= "table" then
            return false
        end
        local resolvedPitch = math.max(0.01, tonumber(pitch) or Constants.CHARGE_SOUND_START_PITCH)
        state.chargeSoundPitch = resolvedPitch
        state.chargeSoundNextFrame = nil
        if not playSoundCue("Charge", resolvedPitch) then
            return false
        end
        state.chargeSoundNextFrame = runtime.frame + chargeSoundIntervalFrames(resolvedPitch)
        return true
    end

    local function beginChargeSoundSchedule(state)
        clearChargeSoundSchedule(state)
        return scheduleChargeSound(state, Constants.CHARGE_SOUND_START_PITCH)
    end

    local function updateChargeSoundSchedule(state)
        if type(state) ~= "table" or state.chargeSoundNextFrame == nil then
            return false
        end
        if runtime.frame < state.chargeSoundNextFrame then
            return false
        end
        local nextPitch = math.min(
            Constants.CHARGE_SOUND_MAX_PITCH,
            (tonumber(state.chargeSoundPitch) or Constants.CHARGE_SOUND_START_PITCH)
                + Constants.CHARGE_SOUND_PITCH_STEP
        )
        return scheduleChargeSound(state, nextPitch)
    end

    local function newVector(x, y)
        local valueX = tonumber(x) or 0
        local valueY = tonumber(y) or 0
        if Vector ~= nil then
            local ok, value = pcall(function()
                return Vector(valueX, valueY)
            end)
            if ok and value then
                return value
            end
        end
        return { X = valueX, Y = valueY }
    end

    local function vectorX(value)
        return tonumber(value and value.X) or 0
    end

    local function vectorY(value)
        return tonumber(value and value.Y) or 0
    end

    local function vectorAdd(left, right)
        return newVector(vectorX(left) + vectorX(right), vectorY(left) + vectorY(right))
    end

    local function vectorSubtract(left, right)
        return newVector(vectorX(left) - vectorX(right), vectorY(left) - vectorY(right))
    end

    local function vectorScale(value, amount)
        local scalar = tonumber(amount) or 0
        return newVector(vectorX(value) * scalar, vectorY(value) * scalar)
    end

    local function vectorLengthSquared(value)
        local x = vectorX(value)
        local y = vectorY(value)
        return x * x + y * y
    end

    local function vectorLength(value)
        return math.sqrt(vectorLengthSquared(value))
    end

    local function normalized(value, fallback)
        local length = vectorLength(value)
        if length <= 0.000001 then
            if fallback ~= nil then
                return normalized(fallback, nil)
            end
            return newVector(1, 0)
        end
        return newVector(vectorX(value) / length, vectorY(value) / length)
    end

    local function distanceSquared(left, right)
        return vectorLengthSquared(vectorSubtract(left, right))
    end

    local function copyVector(value)
        return newVector(vectorX(value), vectorY(value))
    end

    local function entityExists(entity)
        if not entity then
            return false
        end
        if type(entity.Exists) == "function" then
            local ok, exists = pcall(entity.Exists, entity)
            return ok and exists == true
        end
        return entity.removed ~= true
    end

    local function entityIsDead(entity)
        if not entity then
            return true
        end
        if type(entity.IsDead) == "function" then
            local ok, dead = pcall(entity.IsDead, entity)
            if ok then
                return dead == true
            end
        end
        return entity.dead == true
    end

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function entityKey(entity)
        if not entity then
            return ""
        end
        if type(GetPtrHash) == "function" then
            local ok, value = pcall(GetPtrHash, entity)
            if ok and value ~= nil then
                return "ptr:" .. tostring(value)
            end
        end
        return table.concat({
            "seed",
            tostring(entity.InitSeed or ""),
            tostring(entity.Type or ""),
            tostring(entity.Variant or ""),
            tostring(entity.SubType or ""),
        }, ":")
    end

    local function getPlayers()
        if type(context.GetPlayers) == "function" then
            local ok, players = pcall(context.GetPlayers)
            if ok and type(players) == "table" then
                return players
            end
        end
        return {}
    end

    local function findPlayerByKey(key)
        key = tostring(key or "")
        local state = runtime.players[key]
        if state and entityExists(state.player) then
            return state.player
        end
        for _, player in ipairs(getPlayers()) do
            if playerKey(player) == key then
                if state then
                    state.player = player
                end
                return player
            end
        end
        return nil
    end

    local function hasCollectible(player, itemId)
        if not player or (tonumber(itemId) or -1) <= 0 or type(player.HasCollectible) ~= "function" then
            return false
        end
        local ok, held = pcall(player.HasCollectible, player, itemId)
        return ok and held == true
    end

    local function collectibleCount(player, itemId)
        if not player or (tonumber(itemId) or -1) <= 0 or type(player.GetCollectibleNum) ~= "function" then
            return 0
        end
        local ok, count = pcall(player.GetCollectibleNum, player, itemId)
        if not ok then
            return 0
        end
        return math.max(0, math.floor(tonumber(count) or 0))
    end

    local function playerIsDead(player)
        if not player then
            return true
        end
        if type(player.IsDead) == "function" then
            local ok, dead = pcall(player.IsDead, player)
            if ok then
                return dead == true
            end
        end
        return false
    end

    local function getSaveRoot()
        local root = nil
        if type(context.GetSaveRoot) == "function" then
            local ok, value = pcall(context.GetSaveRoot)
            if ok and type(value) == "table" then
                root = value
            end
        end
        if not root then
            root = runtime.fallbackSaveRoot
        end
        if type(root.bigDogBark) ~= "table" then
            root.bigDogBark = {}
        end
        return root
    end

    local function currentRunSeed()
        if runtime.testRunSeed ~= nil then
            return tostring(runtime.testRunSeed)
        end
        if type(context.GetCurrentRunSeed) == "function" then
            local ok, seed = pcall(context.GetCurrentRunSeed)
            if ok and seed ~= nil then
                return tostring(seed)
            end
        end
        return "unknown"
    end

    local function save()
        if type(context.Save) == "function" then
            pcall(context.Save)
        end
    end

    local function resetSavedState(seed)
        local root = getSaveRoot()
        root.bigDogBark = {
            runSeed = tostring(seed or currentRunSeed()),
            players = {},
        }
        return root.bigDogBark
    end

    local function getSavedState()
        local root = getSaveRoot()
        local state = root.bigDogBark
        local seed = currentRunSeed()
        if type(state) ~= "table" or tostring(state.runSeed or "") ~= seed then
            state = resetSavedState(seed)
        end
        if type(state.players) ~= "table" then
            state.players = {}
        end
        return state
    end

    local function getPlayerRuntime(player, create)
        local key = playerKey(player)
        if key == "" then
            return nil
        end
        local state = runtime.players[key]
        if type(state) ~= "table" and create ~= false then
            state = {
                key = key,
                player = player,
                mode = "follow",
                lastMoveDirection = nil,
                roomChewed = {},
                chewTarget = nil,
                chewTargetKey = nil,
                chewPauseUntil = nil,
                chewSearchPending = true,
                lastChewSearchVersion = -1,
                nextChewSearchFrame = 0,
                chewPath = nil,
                chewPathNode = 1,
                chewPathTargetKey = nil,
                nextChewPathFrame = 0,
                chewPathFailureCount = 0,
                chewMoveVelocity = nil,
                chewSafePosition = nil,
                nextChewSafeFrame = 0,
                chewWindupDirection = nil,
                chewLungeDirection = nil,
                chewLungeStart = nil,
                chewLungeTravel = nil,
                chewHitConsumed = false,
                chewAnimation = nil,
                dog = nil,
                dash = nil,
                echoEntity = nil,
                echoData = nil,
                echoActive = false,
                chargeStartFrame = nil,
                chargeFrames = nil,
                chargeSlot = nil,
                chargeSawHeld = false,
                chargeReady = false,
                chargeSoundPitch = nil,
                chargeSoundNextFrame = nil,
                chargeBarSprite = nil,
                chargeBarPhase = nil,
                chargeBarVisible = false,
                chargeBarLoadFailed = false,
                lastLaunchFrame = nil,
            }
            runtime.players[key] = state
        elseif state then
            state.player = player or state.player
            if type(state.roomChewed) ~= "table" then
                state.roomChewed = {}
            end
            if type(state.mode) ~= "string" then
                state.mode = "follow"
            end
            if state.chewSearchPending == nil then
                state.chewSearchPending = true
            end
            if type(state.lastChewSearchVersion) ~= "number" then
                state.lastChewSearchVersion = -1
            end
            if type(state.nextChewSearchFrame) ~= "number" then
                state.nextChewSearchFrame = 0
            end
            if type(state.chewPathNode) ~= "number" then
                state.chewPathNode = 1
            end
            if type(state.nextChewPathFrame) ~= "number" then
                state.nextChewPathFrame = 0
            end
            if type(state.chewPathFailureCount) ~= "number" then
                state.chewPathFailureCount = 0
            end
            if type(state.nextChewSafeFrame) ~= "number" then
                state.nextChewSafeFrame = 0
            end
            if state.chewHitConsumed == nil then
                state.chewHitConsumed = false
            end
            if state.chargeReady == nil then
                state.chargeReady = false
            end
            if state.chargeBarVisible == nil then
                state.chargeBarVisible = false
            end
        end
        return state
    end

    local function getPlayerRecord(player)
        local key = playerKey(player)
        if key == "" then
            return nil
        end
        getPlayerRuntime(player, true)
        local saved = getSavedState()
        local record = saved.players[key]
        if type(record) ~= "table" then
            record = {}
            saved.players[key] = record
        end
        record.foodPickups = math.max(0, math.floor(tonumber(record.foodPickups) or 0))
        record.chewUnlocked = record.chewUnlocked == true or record.foodPickups >= 4
        record.potionArmed = record.potionArmed == true
        return record
    end

    local function getCollectibleConfig(itemId)
        if type(context.GetCollectibleConfig) == "function" then
            local ok, config = pcall(context.GetCollectibleConfig, itemId)
            if ok and config then
                return config
            end
        end
        if not Isaac or type(Isaac.GetItemConfig) ~= "function" then
            return nil
        end
        local okConfig, itemConfig = pcall(Isaac.GetItemConfig)
        if not okConfig or not itemConfig or type(itemConfig.GetCollectible) ~= "function" then
            return nil
        end
        local okItem, config = pcall(itemConfig.GetCollectible, itemConfig, itemId)
        return okItem and config or nil
    end

    local function isFoodConfig(config)
        if not config then
            return false
        end
        local foodTag = ItemConfig and ItemConfig.TAG_FOOD
        if not foodTag then
            return false
        end
        if type(config.HasTags) == "function" then
            local ok, tagged = pcall(config.HasTags, config, foodTag)
            if ok then
                return tagged == true
            end
        end
        local tags = tonumber(config.Tags)
        local numericTag = tonumber(foodTag)
        if tags and numericTag then
            return (tags & numericTag) ~= 0
        end
        return false
    end

    local function getChargeSeconds(tears)
        local currentTears = math.max(0.0001, tonumber(tears) or 0.0001)
        return math.max(0.1, 0.5 * 2.73 / currentTears)
    end

    local function getChargeFrames(tears)
        return math.ceil(getChargeSeconds(tears) * 30 - 0.0000001)
    end

    local function resolveDirection(currentMovement, rememberedDirection, reverse)
        local current = currentMovement
        local remembered = rememberedDirection
        if vectorLengthSquared(current) > 0.000001 then
            remembered = normalized(current)
        end
        local direction = normalized(remembered, newVector(1, 0))
        if reverse == true then
            direction = vectorScale(direction, -1)
        end
        return direction, remembered
    end

    local busyModes = {
        charging = true,
        dash = true,
        echo_wait = true,
        echo = true,
        chew = true,
        chew_pause = true,
        bite_windup = true,
        bite_lunge = true,
        bite_recover = true,
    }

    local function isBusy(mode)
        return busyModes[tostring(mode or "")] == true
    end

    local function computeDashDamage(targetMaxHitPoints, ownerDamage, multiplier)
        local base = 5
            + math.max(0, tonumber(targetMaxHitPoints) or 0) * 0.05
            + math.max(0, tonumber(ownerDamage) or 0) * 0.20
        return base * math.max(0, tonumber(multiplier) or 1)
    end

    local function computeEchoDamage(targetMaxHitPoints, ownerDamage, multiplier)
        local base = 2.5
            + math.max(0, tonumber(targetMaxHitPoints) or 0) * 0.025
            + math.max(0, tonumber(ownerDamage) or 0) * 0.10
        return base * math.max(0, tonumber(multiplier) or 1)
    end

    local function computeChewDamage(targetMaxHitPoints)
        return math.max(0, tonumber(targetMaxHitPoints) or 0) * 0.10
    end

    local function applyVelocityImpulse(currentVelocity, direction, impulse, speedCap)
        local value = vectorAdd(currentVelocity, vectorScale(normalized(direction), tonumber(impulse) or 0))
        local cap = math.max(0, tonumber(speedCap) or 0)
        local length = vectorLength(value)
        if cap > 0 and length > cap then
            value = vectorScale(value, cap / length)
        end
        return value
    end

    local function registerHit(hitMap, entity)
        if type(hitMap) ~= "table" or not entity then
            return false
        end
        local key = entityKey(entity)
        if key == "" or hitMap[key] then
            return false
        end
        hitMap[key] = true
        return true
    end

    local function hasBigDogActive(player)
        if not player or BIG_DOG_BARK_ID <= 0 then
            return false
        end
        if type(player.GetActiveItem) ~= "function" then
            return false
        end
        local slots = {
            ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0,
            ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1,
            ActiveSlot and ActiveSlot.SLOT_POCKET or 2,
            ActiveSlot and ActiveSlot.SLOT_POCKET2 or 3,
        }
        for _, slot in ipairs(slots) do
            local ok, itemId = pcall(player.GetActiveItem, player, slot)
            if ok and tonumber(itemId) == BIG_DOG_BARK_ID then
                return true
            end
        end
        return false
    end

    local function removeEntity(entity)
        if entityExists(entity) and type(entity.Remove) == "function" then
            pcall(entity.Remove, entity)
        end
    end

    local function getSprite(entity)
        if entity and type(entity.GetSprite) == "function" then
            local ok, sprite = pcall(entity.GetSprite, entity)
            if ok then
                return sprite
            end
        end
        return nil
    end

    local function setEntityVisualScale(entity, scale)
        local sprite = getSprite(entity)
        if not sprite then
            return false
        end
        return pcall(function()
            sprite.Scale = newVector(scale, scale)
        end)
    end

    local function makeEntityRef(entity)
        if EntityRef ~= nil then
            local ok, source = pcall(function()
                return EntityRef(entity)
            end)
            if ok and source then
                return source
            end
        end
        return entity
    end

    local function dealEnemyDamage(enemy, amount, owner)
        if not enemy or type(enemy.TakeDamage) ~= "function" then
            return false, nil
        end
        local source = makeEntityRef(owner)
        local ok, accepted = pcall(enemy.TakeDamage, enemy, amount, 0, source, 0)
        return ok and accepted ~= false, source
    end

    local function directionalAnimationName(prefix, direction)
        local x = vectorX(direction)
        local y = vectorY(direction)
        if math.abs(x) > math.abs(y) then
            return tostring(prefix) .. "Horizontal", x < 0
        elseif y < 0 then
            return tostring(prefix) .. "Up", false
        end
        return tostring(prefix) .. "Down", false
    end

    local function playDirectionalAnimation(entity, prefix, direction)
        local sprite = getSprite(entity)
        if not sprite then
            return nil
        end
        local animation, flip = directionalAnimationName(prefix, direction)
        sprite.FlipX = flip
        local playing = false
        if type(sprite.IsPlaying) == "function" then
            local ok, value = pcall(sprite.IsPlaying, sprite, animation)
            playing = ok and value == true
        end
        if not playing and type(sprite.Play) == "function" then
            pcall(sprite.Play, sprite, animation, false)
        end
        return animation
    end

    local function spriteEventTriggered(entity, eventName)
        local sprite = getSprite(entity)
        if not sprite or type(sprite.IsEventTriggered) ~= "function" then
            return false
        end
        local ok, triggered = pcall(sprite.IsEventTriggered, sprite, eventName)
        return ok and triggered == true
    end

    local function markEffectCollisionFree(effect)
        if not effect then
            return
        end
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        if effect.CollisionDamage ~= nil then
            effect.CollisionDamage = 0
        end
        if effect.Velocity ~= nil then
            effect.Velocity = newVector(0, 0)
        end
    end

    local function spawnOwnedEffect(variant, position, owner, marker)
        if not Isaac or type(Isaac.Spawn) ~= "function" or not position then
            return nil
        end
        local ok, entity = pcall(
            Isaac.Spawn,
            EFFECT_ENTITY,
            variant,
            0,
            position,
            newVector(0, 0),
            owner
        )
        if not ok or not entity then
            return nil
        end
        local effect = entity
        if type(entity.ToEffect) == "function" then
            local okEffect, converted = pcall(entity.ToEffect, entity)
            if okEffect and converted then
                effect = converted
            end
        end
        markEffectCollisionFree(effect)
        if type(effect.GetData) == "function" then
            local okData, data = pcall(effect.GetData, effect)
            if okData and type(data) == "table" then
                data[marker] = true
                data.NeverbirthBigDogOwnerKey = playerKey(owner)
            end
        end

        return effect
    end

    local function ensureDog(player, state)
        state = state or getPlayerRuntime(player, true)
        if not state then
            return nil
        end
        if entityExists(state.dog) then
            return state.dog
        end
        state.dog = nil
        local position = player and player.Position or newVector(0, 0)
        local dog = spawnOwnedEffect(DOG_VARIANT, position, player, "NeverbirthBigDogDog")
        if dog then
            state.dog = dog
            setEntityVisualScale(dog, Constants.DOG_VISUAL_SCALE)
            playDirectionalAnimation(dog, "Follow", state.lastMoveDirection or newVector(1, 0))
        end
        return dog
    end

    local function useWindPill(player)
        local record = getPlayerRecord(player)
        if not record or record.potionArmed then
            return false
        end
        record.potionArmed = true
        save()
        return true
    end

    local function launch(player, direction, options)
        options = options or {}
        local state = getPlayerRuntime(player, true)
        local record = getPlayerRecord(player)
        if not state or not record or options.busy == true then
            return nil
        end
        if options.ignoreBusy ~= true and (isBusy(state.mode) or state.echoActive == true) then
            return nil
        end
        if options.ignoreSameFrame ~= true and state.lastLaunchFrame == runtime.frame then
            return nil
        end

        local resolvedDirection = normalized(direction, newVector(1, 0))
        local explicitMultiplier = options.potionMultiplier ~= nil
        local enhanced = explicitMultiplier
            and (tonumber(options.potionMultiplier) or 1) > 1
            or (not explicitMultiplier and record.potionArmed == true)
        local damageMultiplier = explicitMultiplier
            and math.max(0, tonumber(options.potionMultiplier) or 1)
            or (enhanced and 1.5 or 1)
        local distance = enhanced and Constants.DASH_DISTANCE * 1.5 or Constants.DASH_DISTANCE
        local trailRadius = enhanced and Constants.ENHANCED_TRAIL_RADIUS or Constants.TRAIL_RADIUS
        local startPosition = copyVector(options.startPosition or (state.dog and state.dog.Position) or player.Position)
        local finalChargePitch = math.max(Constants.CHARGE_SOUND_START_PITCH, math.min(
            Constants.CHARGE_SOUND_MAX_PITCH,
            tonumber(options.chargeSoundPitch)
                or tonumber(state.chargeSoundPitch)
                or Constants.CHARGE_SOUND_START_PITCH
        ))
        local endPosition = vectorAdd(startPosition, vectorScale(resolvedDirection, distance))
        local hasEcho = options.hasEchoShard
        if hasEcho == nil then
            hasEcho = hasCollectible(player, ECHO_SHARD_ID)
        end

        local dash = {
            owner = player,
            ownerKey = playerKey(player),
            createdFrame = runtime.frame,
            startPosition = startPosition,
            endPosition = endPosition,
            direction = resolvedDirection,
            distance = distance,
            traveled = 0,
            stepFrames = 0,
            damageMultiplier = damageMultiplier,
            trailRadius = trailRadius,
            trailEnabled = hasEcho == true,
            windImpulse = enhanced and Constants.WIND_IMPULSE or 0,
            hasEchoShard = hasEcho == true,
            hitMap = {},
        }

        state.mode = "dash"
        state.dash = dash
        state.chargeStartFrame = nil
        state.chargeFrames = nil
        state.chargeSlot = nil
        state.chargeSawHeld = false
        clearChargeSoundSchedule(state)
        state.lastLaunchFrame = runtime.frame
        if not explicitMultiplier and record.potionArmed then
            record.potionArmed = false
            save()
        end
        playSoundCue("Release", 1 / finalChargePitch)
        return dash
    end

    local function createEchoFromDash(dash)
        if type(dash) ~= "table" or dash.hasEchoShard ~= true then
            return nil
        end
        local createdFrame = math.floor(tonumber(dash.finishedFrame) or runtime.frame)
        return {
            owner = dash.owner,
            ownerKey = dash.ownerKey,
            createdFrame = createdFrame,
            readyFrame = createdFrame + Constants.ECHO_DELAY_FRAMES,
            startPosition = copyVector(dash.startPosition),
            endPosition = copyVector(dash.endPosition),
            direction = copyVector(dash.direction),
            distance = tonumber(dash.distance) or Constants.DASH_DISTANCE,
            traveled = 0,
            stepFrames = 0,
            damageMultiplier = tonumber(dash.damageMultiplier) or 1,
            trailRadius = tonumber(dash.trailRadius) or Constants.TRAIL_RADIUS,
            hitMap = {},
        }
    end

    local function beginChewPause(state, frame)
        if type(state) ~= "table" then
            return nil
        end
        state.mode = "chew_pause"
        state.chewPauseUntil = math.floor(tonumber(frame) or runtime.frame) + Constants.CHEW_PAUSE_FRAMES
        return state.chewPauseUntil
    end

    local function isChewPauseComplete(state, frame)
        return type(state) == "table"
            and state.chewPauseUntil ~= nil
            and math.floor(tonumber(frame) or runtime.frame) >= math.floor(tonumber(state.chewPauseUntil) or 0)
    end

    local function hasExcludedEnemyFlag(npc)
        if not npc or type(npc.HasEntityFlags) ~= "function" then
            return false
        end
        if FRIENDLY_FLAG ~= 0 then
            local ok, present = pcall(npc.HasEntityFlags, npc, FRIENDLY_FLAG)
            if ok and present == true then
                return true
            end
        end
        if CHARM_FLAG ~= 0 then
            local ok, present = pcall(npc.HasEntityFlags, npc, CHARM_FLAG)
            if ok and present == true then
                return true
            end
        end
        return false
    end

    local function isEligibleEnemy(entity)
        if not entityExists(entity) or entityIsDead(entity) then
            return false
        end
        local npc = entity
        if type(entity.ToNPC) == "function" then
            local ok, converted = pcall(entity.ToNPC, entity)
            if not ok or not converted then
                return false
            end
            npc = converted
        elseif tonumber(entity.Type) == EFFECT_ENTITY or tonumber(entity.Type) == PICKUP_ENTITY then
            return false
        end
        if type(npc.IsVulnerableEnemy) == "function" then
            local ok, vulnerable = pcall(npc.IsVulnerableEnemy, npc)
            if not ok or vulnerable ~= true then
                return false
            end
        end
        if type(npc.IsActiveEnemy) == "function" then
            local ok, active = pcall(npc.IsActiveEnemy, npc, false)
            if not ok or active ~= true then
                return false
            end
        end
        if hasExcludedEnemyFlag(npc) then
            return false
        end
        return true
    end

    local function isPotentialEnemy(entity)
        if not entityExists(entity) or entityIsDead(entity) then
            return false
        end
        local npc = entity
        if type(entity.ToNPC) == "function" then
            local ok, converted = pcall(entity.ToNPC, entity)
            if not ok or not converted then
                return false
            end
            npc = converted
        elseif tonumber(entity.Type) == EFFECT_ENTITY or tonumber(entity.Type) == PICKUP_ENTITY then
            return false
        end
        return true
    end

    local function makeEntityReference(entity, key)
        local reference = {
            NeverbirthBigDogEntityReference = true,
            key = key or entityKey(entity),
            entity = entity,
            pointer = nil,
        }
        if EntityPtr ~= nil then
            local ok, pointer = pcall(function()
                return EntityPtr(entity)
            end)
            if ok and pointer then
                reference.pointer = pointer
                reference.entity = nil
            end
        end
        return reference
    end

    local function resolveEntityReference(reference)
        if type(reference) ~= "table" or reference.NeverbirthBigDogEntityReference ~= true then
            return reference
        end
        if reference.pointer then
            local ok, entity = pcall(function()
                return reference.pointer.Ref
            end)
            return ok and entity or nil
        end
        return reference.entity
    end

    local function entityReferenceKey(reference, entity)
        if type(reference) == "table" and reference.NeverbirthBigDogEntityReference == true then
            return tostring(reference.key or "")
        end
        return entityKey(entity or reference)
    end

    local function registerRoomTarget(entity)
        if not isPotentialEnemy(entity) then
            return false
        end
        local key = entityKey(entity)
        if key == "" or runtime.roomTargetKeys[key] then
            return false
        end
        runtime.roomTargetKeys[key] = true
        runtime.roomTargets[#runtime.roomTargets + 1] = makeEntityReference(entity, key)
        runtime.roomTargetVersion = runtime.roomTargetVersion + 1
        return true
    end

    local function selectChewTarget(player, enemies)
        runtime.chewSearchCount = runtime.chewSearchCount + 1
        local state = getPlayerRuntime(player, true)
        if not state then
            return nil
        end
        local origin = (state.dog and state.dog.Position) or player.Position or newVector(0, 0)
        local best = nil
        local bestDistance = math.huge
        for _, reference in ipairs(enemies or runtime.roomTargets) do
            local entity = resolveEntityReference(reference)
            local key = entityReferenceKey(reference, entity)
            if key ~= "" and not state.roomChewed[key] and isEligibleEnemy(entity) and entity.Position then
                local value = distanceSquared(origin, entity.Position)
                if value < bestDistance then
                    best = entity
                    bestDistance = value
                end
            end
        end
        return best
    end


    local function getCurrentRoom()
        if type(Game) ~= "function" then
            return nil
        end
        local okGame, game = pcall(Game)
        if not okGame or not game or type(game.GetRoom) ~= "function" then
            return nil
        end
        local okRoom, room = pcall(game.GetRoom, game)
        return okRoom and room or nil
    end

    local function roomHasDirectChewPath(room, startPosition, targetPosition)
        if not room or type(room.CheckLine) ~= "function" then
            return true
        end
        local checkMode = (LineCheckMode and LineCheckMode.PROJECTILE) or 0
        local ok, clear = pcall(room.CheckLine, room, startPosition, targetPosition, checkMode, 0, false, false)
        return ok and clear == true
    end

    local function buildChewGridPath(room, startPosition, targetPosition)
        if not room
            or type(room.GetGridWidth) ~= "function"
            or type(room.GetGridSize) ~= "function"
            or type(room.GetGridIndex) ~= "function"
            or type(room.GetGridPosition) ~= "function"
            or type(room.GetGridCollision) ~= "function"
        then
            return nil
        end
        local okWidth, width = pcall(room.GetGridWidth, room)
        local okSize, size = pcall(room.GetGridSize, room)
        local okStart, startIndex = pcall(room.GetGridIndex, room, startPosition)
        local okTarget, targetIndex = pcall(room.GetGridIndex, room, targetPosition)
        width = math.floor(tonumber(width) or 0)
        size = math.floor(tonumber(size) or 0)
        startIndex = math.floor(tonumber(startIndex) or -1)
        targetIndex = math.floor(tonumber(targetIndex) or -1)
        if not okWidth or not okSize or not okStart or not okTarget
            or width <= 0 or size <= 0
            or startIndex < 0 or startIndex >= size
            or targetIndex < 0 or targetIndex >= size
        then
            return nil
        end
        if startIndex == targetIndex then
            return { copyVector(targetPosition) }
        end

        local queue = { startIndex }
        local head = 1
        local cameFrom = { [startIndex] = startIndex }
        local function passable(index)
            if index == startIndex or index == targetIndex then
                return true
            end
            local okCollision, collision = pcall(room.GetGridCollision, room, index)
            return okCollision and tonumber(collision) == NO_GRID_COLLISION
        end
        while head <= #queue and cameFrom[targetIndex] == nil do
            local current = queue[head]
            head = head + 1
            local column = current % width
            local neighbors = {}
            if column > 0 then neighbors[#neighbors + 1] = current - 1 end
            if column < width - 1 then neighbors[#neighbors + 1] = current + 1 end
            if current - width >= 0 then neighbors[#neighbors + 1] = current - width end
            if current + width < size then neighbors[#neighbors + 1] = current + width end
            for _, nextIndex in ipairs(neighbors) do
                if cameFrom[nextIndex] == nil and passable(nextIndex) then
                    cameFrom[nextIndex] = current
                    queue[#queue + 1] = nextIndex
                end
            end
        end
        if cameFrom[targetIndex] == nil then
            return nil
        end

        local reversed = {}
        local current = targetIndex
        while current ~= startIndex do
            local okPosition, position = pcall(room.GetGridPosition, room, current)
            if not okPosition or not position then
                return nil
            end
            reversed[#reversed + 1] = copyVector(position)
            current = cameFrom[current]
        end
        local path = {}
        for index = #reversed, 1, -1 do
            path[#path + 1] = reversed[index]
        end
        path[#path] = copyVector(targetPosition)
        return path
    end

    local function shouldRefreshChewPath(state, targetKey, frame, blocked)
        if type(state) ~= "table" or blocked == true then
            return true
        end
        if type(state.chewPath) ~= "table" or tostring(state.chewPathTargetKey or "") ~= tostring(targetKey or "") then
            return true
        end
        return math.floor(tonumber(frame) or runtime.frame) >= math.floor(tonumber(state.nextChewPathFrame) or 0)
    end

    local function clearChewNavigation(state, preserveVelocity)
        if type(state) ~= "table" then return end
        state.chewPath = nil
        state.chewPathNode = 1
        state.chewPathTargetKey = nil
        state.nextChewPathFrame = 0
        state.chewPathFailureCount = 0
        if preserveVelocity ~= true then
            state.chewMoveVelocity = nil
        end
    end

    local function updateChewSafePosition(state, effect, room)
        if type(state) ~= "table" or not effect or not effect.Position then return end
        if runtime.frame < math.floor(tonumber(state.nextChewSafeFrame) or 0) then return end
        state.nextChewSafeFrame = runtime.frame + Constants.CHEW_SAFE_POSITION_INTERVAL
        local safe = true
        if room and type(room.GetGridIndex) == "function" and type(room.GetGridCollision) == "function" then
            local okIndex, index = pcall(room.GetGridIndex, room, effect.Position)
            local okCollision, collision = false, nil
            if okIndex then
                okCollision, collision = pcall(room.GetGridCollision, room, index)
            end
            safe = okIndex and okCollision and tonumber(collision) == NO_GRID_COLLISION
        end
        if safe then
            state.chewSafePosition = copyVector(effect.Position)
        end
    end

    local function rescueChewDog(state, effect, owner)
        local position = state.chewSafePosition or (owner and owner.Position)
        if position then effect.Position = copyVector(position) end
        effect.Velocity = newVector(0, 0)
        clearChewNavigation(state)
        state.chewSearchPending = true
    end
    local function removeTrailVisuals(trail)
        for _, node in ipairs((type(trail) == "table" and trail.nodes) or {}) do
            removeEntity(node.entity)
        end
    end

    local function cleanupExpiredTrails(frame)
        local kept = {}
        for _, trail in ipairs(runtime.trails) do
            local expired = math.floor(tonumber(trail.expiresFrame) or 0) <= frame
            if expired then
                removeTrailVisuals(trail)
                runtime.trailById[trail.id] = nil
            else
                local nodes = {}
                for _, node in ipairs(trail.nodes or {}) do
                    if node.entity == nil or entityExists(node.entity) then
                        nodes[#nodes + 1] = node
                    end
                end
                trail.nodes = nodes
                local first = nodes[1]
                trail.entity = first and first.entity or nil
                trail.position = first and first.position or trail.position
                if #nodes == 0 then
                    runtime.trailById[trail.id] = nil
                else
                    kept[#kept + 1] = trail
                end
            end
        end
        runtime.trails = kept
    end

    local function syncTrailVisualScale(node)
        if type(node) ~= "table" or not entityExists(node.entity) then
            return false
        end
        local sprite = getSprite(node.entity)
        if not sprite then
            return false
        end
        local scale = math.max(
            0.01,
            Constants.TRAIL_VISUAL_SCALE
                * (tonumber(node.radius) or Constants.TRAIL_RADIUS)
                / Constants.TRAIL_RADIUS
        )
        local ok = pcall(function()
            sprite.Scale = newVector(scale, scale)
        end)
        return ok
    end

    local function addTrailVisualNode(trail, owner, position, radius)
        trail.nextNodeId = math.floor(tonumber(trail.nextNodeId) or 0) + 1
        local nodeId = trail.nextNodeId
        local entity = spawnOwnedEffect(TRAIL_VARIANT, position, owner, "NeverbirthBigDogTrail")
        local node = {
            id = nodeId,
            entity = entity,
            position = copyVector(position),
            radius = radius,
        }
        trail.nodes[#trail.nodes + 1] = node
        trail.entity = trail.entity or entity
        trail.position = trail.position or node.position
        if entity and type(entity.GetData) == "function" then
            local okData, data = pcall(entity.GetData, entity)
            if okData and type(data) == "table" then
                data.NeverbirthBigDogTrailId = trail.id
                data.NeverbirthBigDogTrailNodeId = nodeId
                data.NeverbirthBigDogTrailRadius = radius
                data.NeverbirthBigDogTrailExpires = trail.expiresFrame
            end
            local sprite = getSprite(entity)
            if sprite and type(sprite.Play) == "function" then
                pcall(sprite.Play, sprite, "Appear", false)
            end
        end
        syncTrailVisualScale(node)
        return node
    end

    local function spawnOrRefreshTrail(owner, position, radius, frame)
        frame = math.floor(tonumber(frame) or runtime.frame)
        radius = math.max(1, tonumber(radius) or Constants.TRAIL_RADIUS)
        cleanupExpiredTrails(frame)
        local merge = nil
        for _, trail in ipairs(runtime.trails) do
            for _, node in ipairs(trail.nodes or {}) do
                local threshold = (tonumber(node.radius) or 0) + radius
                if distanceSquared(node.position, position) <= threshold * threshold then
                    merge = trail
                    break
                end
            end
            if merge then
                break
            end
        end
        local ownerKey = playerKey(owner)
        if merge then
            merge.radius = math.max(tonumber(merge.radius) or 0, radius)
            merge.expiresFrame = frame + Constants.TRAIL_LIFETIME_FRAMES
            merge.contributors[ownerKey] = { player = owner }
            local contained = false
            for _, node in ipairs(merge.nodes or {}) do
                local nodeRadius = tonumber(node.radius) or 0
                local centerDistance = math.sqrt(distanceSquared(node.position, position))
                if centerDistance + radius <= nodeRadius then
                    contained = true
                end
                if entityExists(node.entity) and type(node.entity.GetData) == "function" then
                    local okData, data = pcall(node.entity.GetData, node.entity)
                    if okData and type(data) == "table" then
                        data.NeverbirthBigDogTrailExpires = merge.expiresFrame
                    end
                end
                if entityExists(node.entity) and node.entity.Color ~= nil and type(Color) ~= "nil" then
                    local okColor, tint = pcall(Color, 1, 1, 1, 1, 0, 0, 0)
                    if okColor then
                        node.entity.Color = tint
                    end
                end
            end
            if not contained then
                addTrailVisualNode(merge, owner, position, radius)
            end
            return merge
        end

        runtime.trailSerial = runtime.trailSerial + 1
        local id = runtime.trailSerial
        local trail = {
            id = id,
            radius = radius,
            expiresFrame = frame + Constants.TRAIL_LIFETIME_FRAMES,
            nodes = {},
            nextNodeId = 0,
            contributors = {
                [ownerKey] = { player = owner },
            },
        }
        runtime.trails[#runtime.trails + 1] = trail
        runtime.trailById[id] = trail
        addTrailVisualNode(trail, owner, position, radius)
        return trail
    end
    local function highestTrailOwner(trail)
        local bestPlayer = nil
        local bestDamage = -math.huge
        for key, contributor in pairs(trail.contributors or {}) do
            local player = contributor and contributor.player or findPlayerByKey(key)
            if entityExists(player) and not playerIsDead(player) then
                contributor.player = player
                local damage = math.max(0, tonumber(player.Damage) or 0) * 0.01
                if damage > bestDamage then
                    bestDamage = damage
                    bestPlayer = player
                end
            end
        end
        return bestPlayer, bestDamage
    end

    local function submitTrailCandidates(trail, frame, enemies)
        if type(trail) ~= "table" or math.floor(tonumber(trail.expiresFrame) or 0) <= frame then
            return 0
        end
        local owner, damage = highestTrailOwner(trail)
        if not owner or damage < 0 then
            return 0
        end
        local count = 0
        for _, enemy in ipairs(enemies or {}) do
            if isEligibleEnemy(enemy) then
                local key = entityKey(enemy)
                if key ~= "" then
                    local candidate = runtime.trailCandidates[key]
                    if not candidate or candidate.frame ~= frame or damage > candidate.damage then
                        runtime.trailCandidates[key] = {
                            frame = frame,
                            entity = enemy,
                            damage = damage,
                            owner = owner,
                        }
                    end
                    count = count + 1
                end
            end
        end
        return count
    end

    local function applyTrailCandidates(frame)
        frame = math.floor(tonumber(frame) or runtime.frame)
        if runtime.lastTrailAppliedFrame == frame then
            return 0
        end
        runtime.lastTrailAppliedFrame = frame
        local applied = 0
        local remaining = {}
        for key, candidate in pairs(runtime.trailCandidates) do
            if candidate.frame == frame then
                local enemy = candidate.entity
                if isEligibleEnemy(enemy) then
                    local damaged, source = dealEnemyDamage(enemy, candidate.damage, candidate.owner)
                    if damaged then
                        if type(enemy.AddSlowing) == "function" then
                            local tint = nil
                            if type(Color) == "function" or (type(Color) == "table" and getmetatable(Color)) then
                                local okColor, value = pcall(Color, 0.45, 0.65, 0.2, 1, 0, 0, 0)
                                if okColor then
                                    tint = value
                                end
                            end
                            pcall(
                                enemy.AddSlowing,
                                enemy,
                                source,
                                Constants.TRAIL_SLOW_DURATION,
                                Constants.TRAIL_SLOW_MULTIPLIER,
                                tint
                            )
                        end
                        applied = applied + 1
                    end
                end
            elseif candidate.frame > frame then
                remaining[key] = candidate
            end
        end
        runtime.trailCandidates = remaining
        return applied
    end

    local function getQueuedItemId(player)
        if not player then
            return nil
        end
        local queued = player.QueuedItem
        if type(player.GetQueuedItem) == "function" then
            local ok, value = pcall(player.GetQueuedItem, player)
            if ok and value ~= nil then
                queued = value
            end
        end
        local item = queued and queued.Item
        return tonumber(item and (item.ID or item.Id))
    end

    local function captureFoodPickup(pickup, player, frame)
        if not pickup or not player
            or tonumber(pickup.Type) ~= PICKUP_ENTITY
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
        then
            return false
        end
        local itemId = math.floor(tonumber(pickup.SubType) or 0)
        if itemId <= 0 or not isFoodConfig(getCollectibleConfig(itemId)) then
            return false
        end
        if not entityExists(pickup) then
            return false
        end
        local key = playerKey(player) .. ":" .. entityKey(pickup)
        if runtime.pendingFood[key] then
            return false
        end
        runtime.serial = runtime.serial + 1
        runtime.pendingFood[key] = {
            key = key,
            serial = runtime.serial,
            frame = math.floor(tonumber(frame) or runtime.frame),
            player = player,
            playerKey = playerKey(player),
            pickup = pickup,
            itemId = itemId,
            beforeCount = collectibleCount(player, itemId),
            queueSeen = getQueuedItemId(player) == itemId,
        }
        return true
    end

    local function settleFoodPickups(frame)
        frame = math.floor(tonumber(frame) or runtime.frame)
        local ordered = {}
        for _, entry in pairs(runtime.pendingFood) do
            ordered[#ordered + 1] = entry
        end
        table.sort(ordered, function(left, right)
            return (tonumber(left.serial) or 0) < (tonumber(right.serial) or 0)
        end)
        local settled = 0
        for _, entry in ipairs(ordered) do
            local age = frame - (tonumber(entry.frame) or frame)
            if age >= Constants.FOOD_SETTLE_DELAY_FRAMES then
                local current = collectibleCount(entry.player, entry.itemId)
                local queuedItemId = getQueuedItemId(entry.player)
                if queuedItemId == entry.itemId then
                    entry.queueSeen = true
                end
                local sourceGone = not entityExists(entry.pickup)
                local confirmed = current > (tonumber(entry.beforeCount) or 0)
                    or (entry.queueSeen == true and sourceGone and queuedItemId ~= entry.itemId)
                if confirmed then
                    local record = getPlayerRecord(entry.player)
                    if record then
                        record.foodPickups = record.foodPickups + 1
                        if record.foodPickups >= 4 then
                            record.chewUnlocked = true
                        end
                        save()
                        settled = settled + 1
                    end
                    runtime.pendingFood[entry.key] = nil
                elseif entry.queueSeen == true and queuedItemId ~= entry.itemId then
                    -- The pickup entered the real queued-item flow but did not
                    -- increase the inventory and its pedestal still exists.
                    -- Treat that as a cancelled/finished queue so a later real
                    -- collision can establish a fresh snapshot.
                    runtime.pendingFood[entry.key] = nil
                elseif entry.queueSeen ~= true
                    and entityExists(entry.pickup)
                    and age > Constants.FOOD_SETTLE_TIMEOUT_FRAMES
                then
                    -- Only an unqueued collision against a still-existing
                    -- pedestal is allowed to expire by age. Queued pickup
                    -- animations may legitimately last longer than ten frames.
                    runtime.pendingFood[entry.key] = nil
                elseif entry.queueSeen ~= true and sourceGone then
                    -- The source vanished without ever entering the player's
                    -- pickup queue and without a collectible-count increase.
                    -- It was not a confirmed player pickup.
                    runtime.pendingFood[entry.key] = nil
                end
            end
        end
        return settled
    end

    local function removeOwnerFromTrails(ownerKey)
        local kept = {}
        for _, trail in ipairs(runtime.trails) do
            trail.contributors[ownerKey] = nil
            if next(trail.contributors) == nil then
                removeTrailVisuals(trail)
                runtime.trailById[trail.id] = nil
            else
                kept[#kept + 1] = trail
            end
        end
        runtime.trails = kept
    end
    local function clearPlayerTransient(state, removeTrails)
        if type(state) ~= "table" then
            return
        end
        removeEntity(state.dog)
        removeEntity(state.echoEntity)
        state.dog = nil
        state.echoEntity = nil
        state.echoData = nil
        state.echoActive = false
        state.dash = nil
        state.mode = "follow"
        state.chargeStartFrame = nil
        state.chargeFrames = nil
        state.chargeSlot = nil
        state.chargeSawHeld = false
        state.chargeReady = false
        clearChargeSoundSchedule(state)
        state.chargeBarPhase = nil
        state.chargeBarVisible = false
        state.chewTarget = nil
        state.chewTargetKey = nil
        state.chewPauseUntil = nil
        state.chewSearchPending = true
        state.lastChewSearchVersion = -1
        state.nextChewSearchFrame = 0
        state.chewPath = nil
        state.chewPathNode = 1
        state.chewPathTargetKey = nil
        state.nextChewPathFrame = 0
        state.chewPathFailureCount = 0
        state.chewMoveVelocity = nil
        state.chewSafePosition = nil
        state.nextChewSafeFrame = 0
        state.chewWindupDirection = nil
        state.chewLungeDirection = nil
        state.chewLungeStart = nil
        state.chewLungeTravel = nil
        state.chewHitConsumed = false
        state.chewAnimation = nil
        if removeTrails then
            removeOwnerFromTrails(state.key)
        end
    end

    local function getNearbyEnemies(position, radius)
        if not Isaac or type(Isaac.FindInRadius) ~= "function" then
            return {}
        end
        local ok, entities = pcall(Isaac.FindInRadius, position, radius, ENEMY_PARTITION)
        return ok and type(entities) == "table" and entities or {}
    end

    local function damageEnemy(enemy, amount, owner)
        if not isEligibleEnemy(enemy) then
            return false
        end
        local damaged = dealEnemyDamage(enemy, amount, owner)
        return damaged == true
    end

    local function damageOnce(hitMap, enemy, amount, owner)
        if type(hitMap) ~= "table" or not enemy then
            return false
        end
        local key = entityKey(enemy)
        if key == "" or hitMap[key] then
            return false
        end
        if not damageEnemy(enemy, amount, owner) then
            return false
        end
        hitMap[key] = true
        return true
    end

    local function pointSegmentDistanceSquared(point, segmentStart, segmentEnd)
        local segment = vectorSubtract(segmentEnd, segmentStart)
        local lengthSquared = vectorLengthSquared(segment)
        if lengthSquared <= 0.000001 then
            return distanceSquared(point, segmentStart)
        end
        local offset = vectorSubtract(point, segmentStart)
        local projection = (
            vectorX(offset) * vectorX(segment)
            + vectorY(offset) * vectorY(segment)
        ) / lengthSquared
        projection = math.max(0, math.min(1, projection))
        local closest = vectorAdd(segmentStart, vectorScale(segment, projection))
        return distanceSquared(point, closest)
    end

    local function getEnemiesAlongSegment(segmentStart, segmentEnd, radius)
        radius = math.max(0, tonumber(radius) or 0)
        local midpoint = vectorScale(vectorAdd(segmentStart, segmentEnd), 0.5)
        local queryRadius = vectorLength(vectorSubtract(segmentEnd, segmentStart)) * 0.5 + radius
        local enemies = {}
        for _, enemy in ipairs(getNearbyEnemies(midpoint, queryRadius)) do
            local contactRadius = radius + math.max(0, tonumber(enemy and enemy.Size) or 0)
            if pointSegmentDistanceSquared(enemy.Position, segmentStart, segmentEnd) <= contactRadius * contactRadius then
                enemies[#enemies + 1] = enemy
            end
        end
        return enemies
    end

    local function spawnEchoEffect(state, echo)
        local entity = spawnOwnedEffect(ECHO_VARIANT, echo.startPosition, echo.owner, "NeverbirthBigDogEcho")
        if not entity then
            return nil
        end
        state.echoEntity = entity
        state.echoData = echo
        state.echoActive = true
        setEntityVisualScale(entity, Constants.ECHO_VISUAL_SCALE)
        playDirectionalAnimation(entity, "Echo", echo.direction)
        return entity
    end

    local function followPosition(player, direction)
        return vectorSubtract(player.Position or newVector(0, 0), vectorScale(direction or newVector(1, 0), 32))
    end

    local function updateFollowPosition(effect, player, direction)
        local target = followPosition(player, direction)
        local current = effect.Position or target
        local delta = vectorSubtract(target, current)
        local teleportDistance = Constants.FOLLOW_TELEPORT_DISTANCE
        if vectorLengthSquared(delta) >= teleportDistance * teleportDistance then
            effect.Position = target
        else
            effect.Position = vectorAdd(current, vectorScale(delta, Constants.FOLLOW_LERP))
        end
        effect.Velocity = newVector(0, 0)
        return target
    end

    local function finishDash(state, effect)
        local dash = state.dash
        if not dash then
            state.mode = "follow"
            return
        end
        dash.endPosition = copyVector(effect.Position or dash.endPosition)
        dash.finishedFrame = runtime.frame
        if dash.trailEnabled == true then
            spawnOrRefreshTrail(dash.owner, dash.endPosition, dash.trailRadius, runtime.frame)
        end
        local echo = createEchoFromDash(dash)
        state.dash = nil
        state.mode = "follow"
        state.chewSearchPending = true
        if echo then
            spawnEchoEffect(state, echo)
        end
    end

    local function updateDash(state, effect)
        local dash = state.dash
        if not dash then
            state.mode = "follow"
            return
        end
        if dash.traveled <= 0 then
            if dash.trailEnabled == true then
                spawnOrRefreshTrail(dash.owner, dash.startPosition, dash.trailRadius, runtime.frame)
            end
        end
        local previousPosition = vectorAdd(dash.startPosition, vectorScale(dash.direction, dash.traveled))
        local remaining = math.max(0, dash.distance - dash.traveled)
        local step = math.min(Constants.DASH_SPEED, remaining)
        dash.traveled = dash.traveled + step
        dash.stepFrames = dash.stepFrames + 1
        effect.Position = vectorAdd(dash.startPosition, vectorScale(dash.direction, dash.traveled))
        effect.Velocity = newVector(0, 0)
        playDirectionalAnimation(effect, "Dash", dash.direction)

        for _, enemy in ipairs(getEnemiesAlongSegment(previousPosition, effect.Position, Constants.HIT_RADIUS)) do
            if isEligibleEnemy(enemy) then
                local damage = computeDashDamage(enemy.MaxHitPoints, dash.owner.Damage, dash.damageMultiplier)
                if damageOnce(dash.hitMap, enemy, damage, dash.owner)
                    and dash.windImpulse > 0
                    and enemy.Velocity ~= nil
                then
                    enemy.Velocity = applyVelocityImpulse(
                        enemy.Velocity,
                        dash.direction,
                        dash.windImpulse,
                        Constants.WIND_SPEED_CAP
                    )
                end
            end
        end

        if dash.trailEnabled == true
            and dash.stepFrames % Constants.TRAIL_INTERVAL_FRAMES == 0 then
            spawnOrRefreshTrail(dash.owner, effect.Position, dash.trailRadius, runtime.frame)
        end
        if dash.traveled >= dash.distance - 0.0001 then
            finishDash(state, effect)
        end
    end

    local function clearChewAttack(state)
        if type(state) ~= "table" then return end
        state.chewWindupDirection = nil
        state.chewLungeDirection = nil
        state.chewLungeStart = nil
        state.chewLungeTravel = nil
        state.chewHitConsumed = false
        state.chewAnimation = nil
    end

    local function releaseChewTarget(state)
        if type(state) ~= "table" then return end
        state.chewTarget = nil
        state.chewTargetKey = nil
        clearChewNavigation(state)
        clearChewAttack(state)
    end

    local function finishChewRecovery(state)
        clearChewAttack(state)
        beginChewPause(state, runtime.frame)
    end

    local function updateChew(state, effect, owner)
        local record = getPlayerRecord(owner)
        local room = getCurrentRoom()
        updateChewSafePosition(state, effect, room)
        if not record or not record.chewUnlocked then
            state.mode = "follow"
            releaseChewTarget(state)
            state.chewSearchPending = true
            updateFollowPosition(effect, owner, state.lastMoveDirection)
            playDirectionalAnimation(effect, "Follow", state.lastMoveDirection or newVector(1, 0))
            return
        end

        if state.mode == "chew_pause" then
            effect.Velocity = newVector(0, 0)
            if isChewPauseComplete(state, runtime.frame) then
                state.mode = "follow"
                state.chewPauseUntil = nil
                releaseChewTarget(state)
                state.chewSearchPending = true
            else
                return
            end
        end

        local target = resolveEntityReference(state.chewTarget)
        local attackCommitted = state.mode == "bite_lunge" or state.mode == "bite_recover"
        if not attackCommitted then
            local targetKey = state.chewTargetKey or (target and entityKey(target))
            local lostReference = target == nil and state.chewTarget ~= nil
            local invalidTarget = target ~= nil and (not isEligibleEnemy(target) or state.roomChewed[targetKey])
            if lostReference or invalidTarget then
                target = nil
                releaseChewTarget(state)
                state.chewSearchPending = true
            end
        end

        if state.mode == "bite_windup" then
            if not target or not isEligibleEnemy(target) then
                state.mode = "follow"
                releaseChewTarget(state)
                state.chewSearchPending = true
                return
            end
            local direction = normalized(
                state.chewWindupDirection or vectorSubtract(target.Position, effect.Position),
                state.lastMoveDirection or newVector(1, 0)
            )
            state.chewWindupDirection = copyVector(direction)
            state.lastMoveDirection = direction
            state.chewAnimation = playDirectionalAnimation(effect, "Bite", direction)
            effect.Velocity = newVector(0, 0)
            if spriteEventTriggered(effect, "BiteLungeStart") then
                state.mode = "bite_lunge"
                state.chewLungeDirection = copyVector(direction)
                state.chewLungeStart = copyVector(effect.Position)
                state.chewLungeTravel = 0
                state.chewHitConsumed = false
                state.chewMoveVelocity = nil
            end
            return
        end

        if state.mode == "bite_lunge" then
            local direction = state.chewLungeDirection or state.lastMoveDirection or newVector(1, 0)
            local startPosition = state.chewLungeStart or copyVector(effect.Position)
            local traveled = math.max(0, tonumber(state.chewLungeTravel) or 0)
            local remaining = math.max(0, Constants.CHEW_LUNGE_DISTANCE - traveled)
            local step = math.min(Constants.CHEW_LUNGE_SPEED, remaining)
            traveled = traveled + step
            state.chewLungeTravel = traveled
            effect.Position = vectorAdd(startPosition, vectorScale(direction, traveled))
            effect.Velocity = newVector(0, 0)

            if spriteEventTriggered(effect, "BiteHit") and state.chewHitConsumed ~= true then
                state.chewHitConsumed = true
                local liveTarget = resolveEntityReference(state.chewTarget)
                local targetKey = state.chewTargetKey or (liveTarget and entityKey(liveTarget))
                if liveTarget and isEligibleEnemy(liveTarget) and liveTarget.Position then
                    local contactRadius = Constants.CHEW_HIT_RADIUS + math.max(0, tonumber(liveTarget.Size) or 0)
                    local inside = pointSegmentDistanceSquared(
                        liveTarget.Position,
                        startPosition,
                        effect.Position
                    ) <= contactRadius * contactRadius
                    local damage = computeChewDamage(liveTarget.MaxHitPoints)
                    if inside and damage > 0 and damageEnemy(liveTarget, damage, owner) then
                        state.roomChewed[targetKey] = true
                    end
                end
                state.mode = "bite_recover"
            end
            if spriteEventTriggered(effect, "BiteEnd") then
                finishChewRecovery(state)
            end
            return
        end

        if state.mode == "bite_recover" then
            effect.Velocity = newVector(0, 0)
            if spriteEventTriggered(effect, "BiteEnd") then
                finishChewRecovery(state)
            end
            return
        end

        local targetVersion = runtime.roomTargetVersion
        local retryDue = runtime.frame >= (tonumber(state.nextChewSearchFrame) or 0)
        if target == nil and (
            state.chewSearchPending or state.lastChewSearchVersion ~= targetVersion or retryDue
        ) then
            target = selectChewTarget(owner, runtime.roomTargets)
            state.chewTarget = target and makeEntityReference(target) or nil
            state.chewTargetKey = target and entityKey(target) or nil
            state.lastChewSearchVersion = targetVersion
            state.chewSearchPending = false
            state.nextChewSearchFrame = runtime.frame + Constants.CHEW_SEARCH_RETRY_FRAMES
            clearChewNavigation(state)
        end
        if not target then
            state.mode = "follow"
            updateFollowPosition(effect, owner, state.lastMoveDirection)
            playDirectionalAnimation(effect, "Follow", state.lastMoveDirection or newVector(1, 0))
            return
        end

        local delta = vectorSubtract(target.Position, effect.Position)
        local distance = vectorLength(delta)
        local direction = normalized(delta, state.lastMoveDirection or newVector(1, 0))
        state.lastMoveDirection = direction
        if distance <= Constants.CHEW_APPROACH_RADIUS then
            state.mode = "bite_windup"
            state.chewWindupDirection = direction
            state.chewHitConsumed = false
            state.chewAnimation = playDirectionalAnimation(effect, "Bite", direction)
            state.chewMoveVelocity = nil
            effect.Velocity = newVector(0, 0)
            return
        end

        state.mode = "chew_seek"
        local destination = target.Position
        if not roomHasDirectChewPath(room, effect.Position, target.Position) then
            local key = state.chewTargetKey or entityKey(target)
            if shouldRefreshChewPath(state, key, runtime.frame, false) then
                local path = buildChewGridPath(room, effect.Position, target.Position)
                state.chewPath = path or {}
                state.chewPathNode = 1
                state.chewPathTargetKey = key
                state.nextChewPathFrame = runtime.frame + Constants.CHEW_PATH_REFRESH_FRAMES
                if path then
                    state.chewPathFailureCount = 0
                else
                    state.chewPathFailureCount = (tonumber(state.chewPathFailureCount) or 0) + 1
                end
            end
            local path = state.chewPath
            local nodeIndex = math.max(1, math.floor(tonumber(state.chewPathNode) or 1))
            local node = type(path) == "table" and path[nodeIndex] or nil
            while node and distanceSquared(effect.Position, node) <= 16 * 16 do
                nodeIndex = nodeIndex + 1
                state.chewPathNode = nodeIndex
                node = path[nodeIndex]
            end
            if node then
                destination = node
            elseif (tonumber(state.chewPathFailureCount) or 0) >= Constants.CHEW_PATH_FAILURE_LIMIT then
                rescueChewDog(state, effect, owner)
                return
            else
                effect.Velocity = newVector(0, 0)
                return
            end
        else
            clearChewNavigation(state, true)
        end

        local moveDelta = vectorSubtract(destination, effect.Position)
        local moveDistance = vectorLength(moveDelta)
        local moveDirection = normalized(moveDelta, direction)
        local desiredVelocity = vectorScale(moveDirection, math.min(Constants.CHEW_SPEED, moveDistance))
        local previousVelocity = state.chewMoveVelocity or newVector(0, 0)
        local blendedVelocity = vectorAdd(
            vectorScale(previousVelocity, 1 - Constants.CHEW_MOVE_LERP),
            vectorScale(desiredVelocity, Constants.CHEW_MOVE_LERP)
        )
        if vectorLength(blendedVelocity) > moveDistance and moveDistance > 0 then
            blendedVelocity = vectorScale(normalized(blendedVelocity), moveDistance)
        end
        state.chewMoveVelocity = blendedVelocity
        effect.Position = vectorAdd(effect.Position, blendedVelocity)
        effect.Velocity = newVector(0, 0)
        playDirectionalAnimation(effect, "Run", moveDirection)
    end

    local function updateDog(_, effect)
        if not effect or type(effect.GetData) ~= "function" then
            return nil
        end
        local okData, data = pcall(effect.GetData, effect)
        if not okData or type(data) ~= "table" or data.NeverbirthBigDogDog ~= true then
            return nil
        end
        local key = tostring(data.NeverbirthBigDogOwnerKey or "")
        local state = runtime.players[key]
        local owner = findPlayerByKey(key)
        if not state or not owner or playerIsDead(owner) or not hasBigDogActive(owner) then
            removeEntity(effect)
            if state then
                clearPlayerTransient(state, true)
            end
            return nil
        end
        if state.dog and entityExists(state.dog) and entityKey(state.dog) ~= entityKey(effect) then
            removeEntity(effect)
            return nil
        end
        state.dog = effect
        markEffectCollisionFree(effect)
        setEntityVisualScale(effect, Constants.DOG_VISUAL_SCALE)

        if state.mode == "dash" then
            updateDash(state, effect)
        elseif state.mode == "charging" then
            local direction = state.lastMoveDirection or newVector(1, 0)
            updateFollowPosition(effect, owner, direction)
            playDirectionalAnimation(effect, "Charge", direction)
        else
            updateChew(state, effect, owner)
        end
        return nil
    end

    local function updateEcho(_, effect)
        if not effect or type(effect.GetData) ~= "function" then
            return nil
        end
        local okData, data = pcall(effect.GetData, effect)
        if not okData or type(data) ~= "table" or data.NeverbirthBigDogEcho ~= true then
            return nil
        end
        local key = tostring(data.NeverbirthBigDogOwnerKey or "")
        local state = runtime.players[key]
        local echo = state and state.echoData or nil
        local owner = echo and echo.owner or findPlayerByKey(key)
        if not state or not echo or not owner or playerIsDead(owner) then
            removeEntity(effect)
            if state then
                state.echoEntity = nil
                state.echoData = nil
                state.echoActive = false
            end
            return nil
        end
        state.echoEntity = effect
        markEffectCollisionFree(effect)
        setEntityVisualScale(effect, Constants.ECHO_VISUAL_SCALE)
        playDirectionalAnimation(effect, "Echo", echo.direction)
        if runtime.frame < echo.readyFrame then
            effect.Position = copyVector(echo.startPosition)
            return nil
        end
        if echo.traveled <= 0 then
            spawnOrRefreshTrail(owner, echo.startPosition, echo.trailRadius, runtime.frame)
        end
        local previousPosition = vectorAdd(echo.startPosition, vectorScale(echo.direction, echo.traveled))
        local remaining = math.max(0, echo.distance - echo.traveled)
        local step = math.min(Constants.DASH_SPEED, remaining)
        echo.traveled = echo.traveled + step
        echo.stepFrames = echo.stepFrames + 1
        effect.Position = vectorAdd(echo.startPosition, vectorScale(echo.direction, echo.traveled))
        effect.Velocity = newVector(0, 0)

        for _, enemy in ipairs(getEnemiesAlongSegment(previousPosition, effect.Position, Constants.HIT_RADIUS)) do
            if isEligibleEnemy(enemy) then
                damageOnce(
                    echo.hitMap,
                    enemy,
                    computeEchoDamage(enemy.MaxHitPoints, owner.Damage, echo.damageMultiplier),
                    owner
                )
            end
        end
        if echo.stepFrames % Constants.TRAIL_INTERVAL_FRAMES == 0 then
            spawnOrRefreshTrail(owner, effect.Position, echo.trailRadius, runtime.frame)
        end
        if echo.traveled >= echo.distance - 0.0001 then
            spawnOrRefreshTrail(owner, effect.Position, echo.trailRadius, runtime.frame)
            removeEntity(effect)
            state.echoEntity = nil
            state.echoData = nil
            state.echoActive = false
        end
        return nil
    end

    local function updateTrail(_, effect)
        if not effect or type(effect.GetData) ~= "function" then
            return nil
        end
        local okData, data = pcall(effect.GetData, effect)
        if not okData or type(data) ~= "table" or data.NeverbirthBigDogTrail ~= true then
            return nil
        end
        local trail = runtime.trailById[tonumber(data.NeverbirthBigDogTrailId)]
        if not trail or runtime.frame >= trail.expiresFrame then
            removeEntity(effect)
            return nil
        end
        local nodeId = tonumber(data.NeverbirthBigDogTrailNodeId)
        local node = nil
        for _, candidate in ipairs(trail.nodes or {}) do
            if candidate.id == nodeId then
                node = candidate
                break
            end
        end
        if not node then
            removeEntity(effect)
            return nil
        end
        node.entity = effect
        node.position = copyVector(effect.Position or node.position)
        markEffectCollisionFree(effect)
        local remaining = trail.expiresFrame - runtime.frame
        if effect.Color ~= nil and type(Color) ~= "nil" then
            local alpha = remaining <= 30 and math.max(0, remaining / 30) or 1
            local okColor, tint = pcall(Color, 1, 1, 1, alpha, 0, 0, 0)
            if okColor then
                effect.Color = tint
            end
        end
        submitTrailCandidates(
            trail,
            runtime.frame,
            getNearbyEnemies(effect.Position or node.position, node.radius)
        )
        return nil
    end
    local function movementInput(player)
        if player and type(player.GetMovementInput) == "function" then
            local ok, value = pcall(player.GetMovementInput, player)
            if ok and value then
                return value
            end
        end
        return newVector(0, 0)
    end

    local function activeAction(slot)
        if not ButtonAction then
            return nil
        end
        local pocket = ActiveSlot and (
            slot == ActiveSlot.SLOT_POCKET or slot == ActiveSlot.SLOT_POCKET2
        )
        return pocket and ButtonAction.ACTION_PILLCARD or ButtonAction.ACTION_ITEM
    end

    local function actionPressed(player, slot)
        local action = activeAction(slot)
        if action == nil or not Input or type(Input.IsActionPressed) ~= "function" then
            return false
        end
        local controller = tonumber(player and (
            player.ControllerIndex or player.ControllerId or player.Controller
        )) or 0
        local ok, held = pcall(Input.IsActionPressed, action, controller)
        return ok and held == true
    end

    local function chargeProgress(state)
        if type(state) ~= "table" then
            return 0
        end
        local required = math.max(1, tonumber(state.chargeFrames) or 1)
        local elapsed = math.max(0, runtime.frame - (tonumber(state.chargeStartFrame) or runtime.frame))
        return math.max(0, math.min(1, elapsed / required))
    end

    local function setChargeBarPhase(state, phase)
        if type(state) ~= "table" then
            return
        end
        state.chargeBarPhase = phase
        state.chargeBarVisible = phase ~= nil
    end

    local function clearChargeGameplay(state)
        state.chargeStartFrame = nil
        state.chargeFrames = nil
        state.chargeSlot = nil
        state.chargeSawHeld = false
        state.chargeReady = false
        clearChargeSoundSchedule(state)
    end

    local function chargeBarAnimation(sprite)
        if sprite and type(sprite.GetAnimation) == "function" then
            local ok, animation = pcall(sprite.GetAnimation, sprite)
            if ok then
                return animation
            end
        end
        return nil
    end

    local function playChargeBarAnimation(sprite, animation)
        if not sprite or type(sprite.Play) ~= "function" then
            return false
        end
        if chargeBarAnimation(sprite) ~= animation then
            local ok = pcall(sprite.Play, sprite, animation, true)
            return ok
        end
        return true
    end

    local function ensureChargeBarSprite(state)
        if state.chargeBarSprite then
            return state.chargeBarSprite
        end
        if state.chargeBarLoadFailed then
            return nil
        end
        local okSprite, sprite = pcall(function()
            return Sprite()
        end)
        if not okSprite or not sprite or type(sprite.Load) ~= "function" then
            state.chargeBarLoadFailed = true
            debugLog("chargebar Sprite constructor is unavailable")
            return nil
        end
        local okLoad = pcall(sprite.Load, sprite, Constants.CHARGE_BAR_PATH, true)
        if not okLoad then
            state.chargeBarLoadFailed = true
            debugLog("failed to load " .. Constants.CHARGE_BAR_PATH)
            return nil
        end
        state.chargeBarSprite = sprite
        return sprite
    end

    local function chargeBarScreenPosition(player)
        local scaleY = tonumber(player and player.SpriteScale and player.SpriteScale.Y) or 1
        local anchor = vectorAdd(
            player.Position or newVector(0, 0),
            newVector(Constants.CHARGE_BAR_HEAD_OFFSET_X, Constants.CHARGE_BAR_HEAD_OFFSET_Y * scaleY)
        )
        if not Isaac or type(Isaac.WorldToScreen) ~= "function" then
            return nil, "Isaac.WorldToScreen is unavailable"
        end
        local ok, converted = pcall(Isaac.WorldToScreen, anchor)
        if not ok then
            return nil, tostring(converted)
        end
        if not converted then
            return nil, "Isaac.WorldToScreen returned no position"
        end
        return converted
    end

    local function canRenderChargeBarInCurrentPass()
        if not RenderMode or type(Game) ~= "function" then
            return true
        end
        local ok, renderMode = pcall(function()
            local game = Game()
            local room = game and type(game.GetRoom) == "function" and game:GetRoom() or nil
            if room and type(room.GetRenderMode) == "function" then
                return room:GetRenderMode()
            end
            return nil
        end)
        if not ok then
            return true
        end
        return renderMode ~= RenderMode.RENDER_WATER_REFRACT
            and renderMode ~= RenderMode.RENDER_WATER_REFLECT
    end

    -- MC_POST_PLAYER_RENDER callback contract: (_, player, renderOffset).
    -- Gameplay readiness is updated only in MC_POST_PEFFECT_UPDATE; this callback
    -- owns cached Sprite animation and screen-space rendering only.
    local function postPlayerRender(_, player, _renderOffset)
        if not canRenderChargeBarInCurrentPass() then
            return nil
        end
        local state = getPlayerRuntime(player, false)
        if not state or state.chargeBarVisible ~= true then
            return nil
        end
        if playerIsDead(player) or not hasBigDogActive(player) then
            setChargeBarPhase(state, nil)
            return nil
        end
        local sprite = ensureChargeBarSprite(state)
        if not sprite then
            return nil
        end
        local phase = state.chargeBarPhase
        if phase == "charging" then
            local frame = math.floor(chargeProgress(state) * 100)
            if type(sprite.SetFrame) == "function" then
                pcall(sprite.SetFrame, sprite, "Charging", frame)
            end
        elseif phase == "start_charged" then
            if chargeBarAnimation(sprite) ~= "StartCharged" then
                playChargeBarAnimation(sprite, "StartCharged")
            elseif type(sprite.IsFinished) == "function" then
                local ok, finished = pcall(sprite.IsFinished, sprite, "StartCharged")
                if ok and finished == true then
                    setChargeBarPhase(state, "charged")
                    playChargeBarAnimation(sprite, "Charged")
                elseif type(sprite.Update) == "function" then
                    pcall(sprite.Update, sprite)
                end
            end
        elseif phase == "charged" then
            playChargeBarAnimation(sprite, "Charged")
            if type(sprite.Update) == "function" then
                pcall(sprite.Update, sprite)
            end
        elseif phase == "disappear" then
            if chargeBarAnimation(sprite) ~= "Disappear" then
                playChargeBarAnimation(sprite, "Disappear")
            elseif type(sprite.IsFinished) == "function" then
                local ok, finished = pcall(sprite.IsFinished, sprite, "Disappear")
                if ok and finished == true then
                    setChargeBarPhase(state, nil)
                    return nil
                elseif type(sprite.Update) == "function" then
                    pcall(sprite.Update, sprite)
                end
            end
        else
            return nil
        end
        local renderPosition, projectionError = chargeBarScreenPosition(player)
        if not renderPosition then
            local message = tostring(projectionError or "unknown projection failure")
            if state.chargeBarProjectionError ~= message then
                state.chargeBarProjectionError = message
                debugLog("chargebar WorldToScreen failed; skipping render: " .. message)
            end
            return nil
        end
        state.chargeBarProjectionError = nil
        if type(sprite.Render) == "function" then
            pcall(sprite.Render, sprite, renderPosition, newVector(0, 0), newVector(0, 0))
        end
        return nil
    end
    local function useItem(_, itemId, rng, player, useFlags, activeSlot, customVarData)
        local result = { Discharge = false, Remove = false, ShowAnim = false }
        if tonumber(itemId) ~= BIG_DOG_BARK_ID or not player then
            return result
        end
        local state = getPlayerRuntime(player, true)
        if not state then
            return result
        end
        if isBusy(state.mode) or state.echoActive then
            return result
        end
        local current, remembered = resolveDirection(
            movementInput(player),
            state.lastMoveDirection,
            hasCollectible(player, WIND_CHARGE_ROD_ID)
        )
        if vectorLengthSquared(movementInput(player)) > 0.000001 then
            state.lastMoveDirection = remembered
        end
        local dog = ensureDog(player, state)
        if hasCollectible(player, WIND_CHARGE_ROD_ID) then
            setChargeBarPhase(state, nil)
            if not dog then
                state.mode = "follow"
                return result
            end
            local dash = launch(player, current, {
                startPosition = dog.Position,
            })
            if dash then
                dog.Position = copyVector(dash.startPosition)
            end
            return result
        end

        local tears = 30 / math.max(0.0001, (tonumber(player.MaxFireDelay) or 0) + 1)
        state.mode = "charging"
        state.chargeStartFrame = runtime.frame
        state.chargeFrames = getChargeFrames(tears)
        state.chargeSlot = activeSlot
        state.chargeSawHeld = true
        state.chargeReady = false
        setChargeBarPhase(state, "charging")
        beginChargeSoundSchedule(state)
        return result
    end

    local function postPlayerUpdate(_, player)
        if not player then
            return nil
        end
        local state = getPlayerRuntime(player, true)
        local input = movementInput(player)
        local _, remembered = resolveDirection(input, state.lastMoveDirection, false)
        if vectorLengthSquared(input) > 0.000001 then
            state.lastMoveDirection = remembered
        end

        if playerIsDead(player) or not hasBigDogActive(player) then
            if state.dog or state.echoEntity or state.mode ~= "follow" then
                clearPlayerTransient(state, true)
            end
            return nil
        end

        if state.dog and not entityExists(state.dog) then
            state.dog = nil
            if state.mode == "dash" then
                state.dash = nil
                state.mode = "follow"
            end
        end
        if state.echoEntity and not entityExists(state.echoEntity) then
            state.echoEntity = nil
            state.echoData = nil
            state.echoActive = false
        end
        local dog = ensureDog(player, state)

        if state.mode == "charging" then
            local elapsed = runtime.frame - (tonumber(state.chargeStartFrame) or runtime.frame)
            local required = tonumber(state.chargeFrames) or math.huge
            if actionPressed(player, state.chargeSlot) then
                state.chargeSawHeld = true
                updateChargeSoundSchedule(state)
                if elapsed >= required and state.chargeReady ~= true then
                    state.chargeReady = true
                    setChargeBarPhase(state, "start_charged")
                end
                return nil
            end
            if state.chargeSawHeld then
                local wasReady = state.chargeReady == true or elapsed >= required
                local releaseChargePitch = state.chargeSoundPitch
                state.mode = "follow"
                clearChargeGameplay(state)
                setChargeBarPhase(state, "disappear")
                if wasReady and dog then
                    local direction = resolveDirection(input, state.lastMoveDirection, false)
                    local dash = launch(player, direction, {
                        ignoreBusy = true,
                        startPosition = dog.Position,
                        chargeSoundPitch = releaseChargePitch,
                    })
                    if dash then
                        dog.Position = copyVector(dash.startPosition)
                    end
                end
            end
        end
        return nil
    end

    local function prePickupCollision(_, pickup, collider, low)
        local player = collider
        if collider and type(collider.ToPlayer) == "function" then
            local ok, converted = pcall(collider.ToPlayer, collider)
            if ok then
                player = converted
            end
        end
        if player then
            captureFoodPickup(pickup, player, runtime.frame)
        end
        return nil
    end

    local function npcInit(_, npc)
        registerRoomTarget(npc)
        return nil
    end

    local function entityRemove(_, entity)
        local key = entityKey(entity)
        if key == "" or runtime.roomTargetKeys[key] ~= true then
            return nil
        end
        runtime.roomTargetKeys[key] = nil
        local kept = {}
        for _, reference in ipairs(runtime.roomTargets) do
            if entityReferenceKey(reference) ~= key then
                kept[#kept + 1] = reference
            end
        end
        runtime.roomTargets = kept
        runtime.roomTargetVersion = runtime.roomTargetVersion + 1
        for _, state in pairs(runtime.players) do
            state.roomChewed[key] = nil
            if state.chewTargetKey == key then
                state.chewTarget = nil
                state.chewTargetKey = nil
                state.chewSearchPending = true
            end
        end
        return nil
    end

    local function resolvePillEffectId()
        if not Isaac then
            return -1
        end
        for _, name in ipairs(PILL_NAMES) do
            for _, methodName in ipairs({ "GetPillEffectByName", "GetPillEffectIdByName" }) do
                local method = Isaac[methodName]
                if type(method) == "function" then
                    local ok, id = pcall(method, name)
                    if ok and (tonumber(id) or -1) >= 0 then
                        return tonumber(id)
                    end
                end
            end
        end
        return -1
    end

    local pillEffectId = resolvePillEffectId()

    local function usePill(_, pillEffect, player, useFlags)
        if pillEffectId < 0 then
            pillEffectId = resolvePillEffectId()
        end
        if tonumber(pillEffect) == pillEffectId and pillEffectId >= 0 then
            useWindPill(player)
        end
        return nil
    end

    local function clearAllTrails()
        for _, trail in ipairs(runtime.trails) do
            removeTrailVisuals(trail)
        end
        runtime.trails = {}
        runtime.trailById = {}
        runtime.trailCandidates = {}
        runtime.lastTrailAppliedFrame = nil
    end
    local function scanCurrentRoomTargets()
        runtime.roomTargets = {}
        runtime.roomTargetKeys = {}
        runtime.roomTargetVersion = runtime.roomTargetVersion + 1
        if not Isaac or type(Isaac.GetRoomEntities) ~= "function" then
            return
        end
        local ok, entities = pcall(Isaac.GetRoomEntities)
        if not ok or type(entities) ~= "table" then
            return
        end
        for _, entity in ipairs(entities) do
            registerRoomTarget(entity)
        end
    end

    local function newRoom()
        runtime.pendingFood = {}
        clearAllTrails()
        for _, state in pairs(runtime.players) do
            removeEntity(state.dog)
            removeEntity(state.echoEntity)
            state.dog = nil
            state.echoEntity = nil
            state.echoData = nil
            state.echoActive = false
            state.dash = nil
            state.mode = "follow"
            state.chargeStartFrame = nil
            state.chargeFrames = nil
            state.chargeSlot = nil
            state.chargeSawHeld = false
            state.chargeReady = false
            clearChargeSoundSchedule(state)
            state.chargeBarPhase = nil
            state.chargeBarVisible = false
            state.chewTarget = nil
            state.chewTargetKey = nil
            state.chewPauseUntil = nil
            state.chewSearchPending = true
            state.lastChewSearchVersion = -1
            state.nextChewSearchFrame = 0
            state.chewPath = nil
            state.chewPathNode = 1
            state.chewPathTargetKey = nil
            state.nextChewPathFrame = 0
            state.chewPathFailureCount = 0
            state.chewMoveVelocity = nil
            state.chewSafePosition = nil
            state.nextChewSafeFrame = 0
            state.chewWindupDirection = nil
            state.chewLungeDirection = nil
            state.chewLungeStart = nil
            state.chewLungeTravel = nil
            state.chewHitConsumed = false
            state.chewAnimation = nil
            state.roomChewed = {}
        end
        scanCurrentRoomTargets()
        return nil
    end

    local function newLevel()
        -- MC_POST_NEW_ROOM already reset the new floor's starting room.
        return nil
    end

    local function postUpdate()
        applyTrailCandidates(runtime.frame)
        runtime.frame = runtime.frame + 1

        settleFoodPickups(runtime.frame)
        cleanupExpiredTrails(runtime.frame)
        return nil
    end

    local function gameStarted(_, isContinued)
        clearAllTrails()
        runtime.frame = 0
        runtime.serial = 0
        runtime.trailSerial = 0
        runtime.players = {}
        runtime.pendingFood = {}
        runtime.roomTargets = {}
        runtime.roomTargetKeys = {}
        runtime.roomTargetVersion = 0
        runtime.chewSearchCount = 0
        runtime.savedAtExit = false
        runtime.testRunSeed = nil

        if isContinued ~= true then
            resetSavedState(currentRunSeed())
            save()
        else
            getSavedState()
        end
        scanCurrentRoomTargets()
        return nil
    end

    local function preGameExit()
        runtime.savedAtExit = true
        save()
        return nil
    end

    local function resetForTest(seed)
        clearAllTrails()
        runtime.frame = 0
        runtime.serial = 0
        runtime.trailSerial = 0
        runtime.players = {}
        runtime.pendingFood = {}
        runtime.roomTargets = {}
        runtime.roomTargetKeys = {}
        runtime.roomTargetVersion = 0
        runtime.chewSearchCount = 0
        runtime.trails = {}
        runtime.trailById = {}
        runtime.trailCandidates = {}
        runtime.lastTrailAppliedFrame = nil
        runtime.fallbackSaveRoot = {}
        runtime.testRunSeed = tostring(seed or "test")
        runtime.savedAtExit = false
        resetSavedState(runtime.testRunSeed)
        return runtime
    end

    local Callbacks = {
        UseItem = useItem,
        PlayerUpdate = postPlayerUpdate,
        PostPlayerUpdate = postPlayerUpdate,
        PlayerRender = postPlayerRender,
        PrePickupCollision = prePickupCollision,
        NPCInit = npcInit,
        EntityRemove = entityRemove,
        UsePill = usePill,
        UpdateDog = updateDog,
        UpdateEcho = updateEcho,
        UpdateTrail = updateTrail,
        PostUpdate = postUpdate,
        NewRoom = newRoom,
        NewLevel = newLevel,
        GameStarted = gameStarted,
        PreGameExit = preGameExit,
    }

    Neverbirth.BigDogBarkTestAPI = {
        ItemId = BIG_DOG_BARK_ID,
        RodItemId = WIND_CHARGE_ROD_ID,
        EchoItemId = ECHO_SHARD_ID,
        PillEffectId = pillEffectId,
        Constants = Constants,
        SoundNames = SOUND_NAMES,
        Runtime = runtime,
        GetChargeSeconds = getChargeSeconds,
        GetChargeFrames = getChargeFrames,
        ResolveDirection = resolveDirection,
        HasBigDogActive = hasBigDogActive,
        GetChargeProgress = chargeProgress,
        IsBusy = isBusy,
        ComputeDashDamage = computeDashDamage,
        ComputeEchoDamage = computeEchoDamage,
        ComputeChewDamage = computeChewDamage,
        ApplyVelocityImpulse = applyVelocityImpulse,
        EntityKey = entityKey,
        ResolveEntityReference = resolveEntityReference,
        RegisterHit = registerHit,
        DamageOnce = damageOnce,
        PointSegmentDistanceSquared = pointSegmentDistanceSquared,
        CreateEchoFromDash = createEchoFromDash,
        BeginChewPause = beginChewPause,
        IsChewPauseComplete = isChewPauseComplete,
        GetPlayerRecord = getPlayerRecord,
        CaptureFoodPickup = captureFoodPickup,
        SettleFoodPickups = settleFoodPickups,
        SpawnOrRefreshTrail = spawnOrRefreshTrail,
        SubmitTrailCandidates = submitTrailCandidates,
        ApplyTrailCandidates = applyTrailCandidates,
        SelectChewTarget = selectChewTarget,
        RegisterRoomTarget = registerRoomTarget,
        UpdateChew = updateChew,
        BuildChewGridPath = buildChewGridPath,
        ShouldRefreshChewPath = shouldRefreshChewPath,
        SpriteEventTriggered = spriteEventTriggered,
        UseWindPill = useWindPill,
        PlaySoundCue = playSoundCue,
        Launch = launch,
        ResetForTest = resetForTest,
        Callbacks = Callbacks,
    }

    if BIG_DOG_BARK_ID <= 0 then
        debugLog("Big Dog Bark item id was not resolved; runtime callbacks stay registered for tests and food history")
    end

    if ModCallbacks then
        if ModCallbacks.MC_USE_ITEM and BIG_DOG_BARK_ID > 0 then
            Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, useItem, BIG_DOG_BARK_ID)
        end
        if ModCallbacks.MC_POST_PEFFECT_UPDATE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, postPlayerUpdate)
        end
        if ModCallbacks.MC_POST_PLAYER_RENDER then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, postPlayerRender)
        end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, prePickupCollision, COLLECTIBLE_PICKUP)
        end
        if ModCallbacks.MC_POST_NPC_INIT then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, npcInit)
        end
        if ModCallbacks.MC_POST_ENTITY_REMOVE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, entityRemove)
        end
        if ModCallbacks.MC_USE_PILL then
            if pillEffectId >= 0 then
                Neverbirth:AddCallback(ModCallbacks.MC_USE_PILL, usePill, pillEffectId)
            else
                Neverbirth:AddCallback(ModCallbacks.MC_USE_PILL, usePill)
            end
        end
        if ModCallbacks.MC_POST_EFFECT_UPDATE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, updateDog, DOG_VARIANT)
            Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, updateEcho, ECHO_VARIANT)
            Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, updateTrail, TRAIL_VARIANT)
        end
        if ModCallbacks.MC_POST_UPDATE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
        end
        if ModCallbacks.MC_POST_NEW_ROOM then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
        end
        if ModCallbacks.MC_POST_NEW_LEVEL then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
        end
        if ModCallbacks.MC_POST_GAME_STARTED then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
        end
        if ModCallbacks.MC_PRE_GAME_EXIT then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
        end
    end

    return Neverbirth.BigDogBarkTestAPI
end
