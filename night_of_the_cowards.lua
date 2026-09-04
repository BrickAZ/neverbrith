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

    local function zeroVector()
        if Vector then
            local ok, value = pcall(function() return Vector.Zero end)
            if ok and value then return value end
        end
        if type(Vector) == "function" then return Vector(0, 0) end
        return nil
    end

    local function debugLog(message)
        if type(context.DebugLog) == "function" then
            context.DebugLog("[Night of the Cowards] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[Night of the Cowards] " .. tostring(message))
        end
    end

    local function getPlayers()
        if type(context.GetPlayers) ~= "function" then return {} end
        local ok, players = pcall(context.GetPlayers)
        return ok and type(players) == "table" and players or {}
    end

    local function makeVector(x, y)
        if type(Vector) == "function" or type(Vector) == "table" then
            local ok, value = pcall(Vector, tonumber(x) or 0, tonumber(y) or 0)
            if ok and value then return value end
        end
        return { X = tonumber(x) or 0, Y = tonumber(y) or 0 }
    end

    local function playerKey(player)
        return tostring(math.floor(tonumber(player and player.InitSeed) or -1))
    end

    local function currentRunSeed()
        if type(context.GetCurrentRunSeed) ~= "function" then return 0 end
        local ok, seed = pcall(context.GetCurrentRunSeed)
        return ok and math.floor(tonumber(seed) or 0) or 0
    end

    local function getPersistentData()
        if type(context.GetSaveRoot) ~= "function" then
            return { c20Granted = runtime.localC20Grants }
        end
        local ok, root = pcall(context.GetSaveRoot)
        if not ok or type(root) ~= "table" then
            return { c20Granted = runtime.localC20Grants }
        end

        local seed = currentRunSeed()
        local data = root.nightOfTheCowards
        if type(data) ~= "table" or tonumber(data.runSeed) ~= seed then
            data = { runSeed = seed, c20Granted = {} }
            root.nightOfTheCowards = data
        end
        if type(data.c20Granted) ~= "table" then data.c20Granted = {} end
        return data
    end

    local function savePersistentData()
        if type(context.Save) == "function" then pcall(context.Save) end
    end

    local function collectibleCount(player)
        if ITEM_ID <= 0 or not player then return 0 end
        if type(player.GetCollectibleNum) == "function" then
            local ok, count = pcall(player.GetCollectibleNum, player, ITEM_ID)
            if ok then return math.max(0, math.floor(tonumber(count) or 0)) end
        end
        if type(player.HasCollectible) == "function" then
            local ok, held = pcall(player.HasCollectible, player, ITEM_ID)
            if ok and held == true then return 1 end
        end
        return 0
    end

    local function grantTranscendenceOnce(player)
        if not player or collectibleCount(player) <= 0 or FLIGHT_ITEM_ID <= 0 then return false end
        local data = getPersistentData()
        local key = playerKey(player)
        if data.c20Granted[key] == true then return false end
        if type(player.AddCollectible) ~= "function" then
            debugLog("cannot grant c20: Player:AddCollectible is unavailable")
            return false
        end

        local ok, err = pcall(player.AddCollectible, player, FLIGHT_ITEM_ID, 0, false)
        if not ok then
            debugLog("c20 grant failed: " .. tostring(err))
            return false
        end
        data.c20Granted[key] = true
        savePersistentData()
        return true
    end

    local function anyPlayerHasItem()
        for _, player in ipairs(getPlayers()) do
            if collectibleCount(player) > 0 then return true end
        end
        return false
    end

    local function entityExists(entity)
        if not entity then return false end
        if type(entity.Exists) == "function" then
            local ok, exists = pcall(entity.Exists, entity)
            return ok and exists == true
        end
        return true
    end

    local function entityIsDead(entity)
        if not entity or type(entity.IsDead) ~= "function" then return false end
        local ok, dead = pcall(entity.IsDead, entity)
        return ok and dead == true
    end

    local function toNpc(entity)
        if not entity then return nil end
        if type(entity.ToNPC) == "function" then
            local ok, npc = pcall(entity.ToNPC, entity)
            if ok and npc then return npc end
        end
        if type(entity.IsActiveEnemy) == "function" then return entity end
        return nil
    end

    local function toPlayer(entity)
        if not entity then return nil end
        if type(entity.ToPlayer) == "function" then
            local ok, player = pcall(entity.ToPlayer, entity)
            if ok and player then return player end
        end
        if tonumber(entity.Type) == PLAYER_ENTITY then return entity end
        return nil
    end

    local function hasEntityFlag(entity, flag)
        if not flag or not entity or type(entity.HasEntityFlags) ~= "function" then return false end
        local ok, result = pcall(entity.HasEntityFlags, entity, flag)
        return ok and result == true
    end

    local function isAuraEnemy(entity)
        local npc = toNpc(entity)
        if not npc or not entityExists(npc) or entityIsDead(npc) then return false end
        if hasEntityFlag(npc, FRIENDLY_FLAG) or hasEntityFlag(npc, CHARM_FLAG) then return false end
        if type(npc.IsActiveEnemy) == "function" then
            local ok, active = pcall(npc.IsActiveEnemy, npc, false)
            if not ok or active ~= true then return false end
        end
        return true
    end

    local function isNativeCursedDeathHead(entity)
        local npc = toNpc(entity)
        return npc ~= nil
            and tonumber(npc.Type) == CURSED_DEATH_HEAD_TYPE
            and tonumber(npc.Variant) == CURSED_DEATH_HEAD_VARIANT
    end

    local function isBoss(npc)
        if not npc or type(npc.IsBoss) ~= "function" then return false end
        local ok, result = pcall(npc.IsBoss, npc)
        return ok and result == true
    end

    local function isVulnerable(npc)
        if not npc or type(npc.IsVulnerableEnemy) ~= "function" then return true end
        local ok, result = pcall(npc.IsVulnerableEnemy, npc)
        return ok and result == true
    end

    local function isTransformableEnemy(entity)
        local npc = toNpc(entity)
        return isAuraEnemy(npc)
            and not isNativeCursedDeathHead(npc)
            and not isBoss(npc)
            and isVulnerable(npc)
            and tonumber(npc.Type) ~= HOST_ENTITY
    end

    local function getData(entity)
        if not entity or type(entity.GetData) ~= "function" then return nil end
        local ok, data = pcall(entity.GetData, entity)
        return ok and type(data) == "table" and data or nil
    end

    local function stableHostVariant(npc)
        local seed = math.abs(math.floor(tonumber(npc and npc.InitSeed) or 0))
        return HOST_VARIANTS[(seed % #HOST_VARIANTS) + 1]
    end

    local function transformEnemy(npc)
        local data = getData(npc)
        if not data or data[TRANSFORMED_DATA_KEY] then return false end
        data[TRANSFORMED_DATA_KEY] = true
        if not isTransformableEnemy(npc) then return false end

        local champion = -1
        if type(npc.GetChampionColorIdx) == "function" then
            local ok, value = pcall(npc.GetChampionColorIdx, npc)
            if ok then champion = tonumber(value) or -1 end
        end
        local variant = stableHostVariant(npc)
        local ok, err = pcall(npc.Morph, npc, HOST_ENTITY, variant, 0, champion)
        if not ok then
            data[TRANSFORMED_DATA_KEY] = nil
            debugLog("enemy morph failed: " .. tostring(err))
            return false
        end
        return true
    end

    local function removeAura(effect)
        if not effect then return end
        local effectData = getData(effect)
        local owner = effectData and effectData[AURA_OWNER_KEY] or nil
        local ownerData = getData(owner)
        if ownerData and ownerData[AURA_DATA_KEY] == effect then
            ownerData[AURA_DATA_KEY] = nil
        end
        if effectData then effectData[AURA_OWNER_KEY] = nil end
        if entityExists(effect) and type(effect.Remove) == "function" then
            pcall(effect.Remove, effect)
        end
    end

    local function clearAuras()
        for _, effect in ipairs(runtime.auras) do removeAura(effect) end
        runtime.auras = {}
    end

    local function ensureAura(npc)
        if isNativeCursedDeathHead(npc) then return nil end
        if not isAuraEnemy(npc) then return nil end
        local npcData = getData(npc)
        if not npcData then return nil end
        local current = npcData[AURA_DATA_KEY]
        if entityExists(current) then return current end
        npcData[AURA_DATA_KEY] = nil

        if AURA_VARIANT <= 0 or not Isaac or type(Isaac.Spawn) ~= "function" or not npc.Position then
            return nil
        end
        local velocity = zeroVector()
        local ok, effect = pcall(Isaac.Spawn, EFFECT_ENTITY, AURA_VARIANT, AURA_SUBTYPE, npc.Position, velocity, npc)
        if not ok or not effect then return nil end

        effect.Parent = npc
        effect.EntityCollisionClass = NO_ENTITY_COLLISION
        effect.GridCollisionClass = NO_GRID_COLLISION
        effect.Velocity = velocity
        effect.SpriteScale = makeVector(AURA_VISUAL_SCALE, AURA_VISUAL_SCALE)
        effect.SpriteOffset = makeVector(0, AURA_VISUAL_OFFSET_Y)
        effect.DepthOffset = AURA_DEPTH_OFFSET

        -- Keep one ordinary (non-floor) Halo instance alive at the vanilla playback rate.
        -- Base Repentance has no Effect parent-follow method, so MC_POST_EFFECT_UPDATE
        -- moves this same instance without restarting its animation.
        if type(effect.GetSprite) == "function" then
            local spriteOk, sprite = pcall(effect.GetSprite, effect)
            if spriteOk and sprite then sprite.PlaybackSpeed = AURA_PLAYBACK_SPEED end
        end

        local effectData = getData(effect)
        if effectData then effectData[AURA_OWNER_KEY] = npc end
        npcData[AURA_DATA_KEY] = effect
        runtime.auras[#runtime.auras + 1] = effect
        return effect
    end

    local function clearPlayerBlocks()
        for player in pairs(runtime.blockedPlayers) do
            local data = getData(player)
            if data then data[PLAYER_BLOCK_DATA_KEY] = nil end
        end
        runtime.blockedPlayers = {}
    end

    local function ensurePlayerFearSprite(player)
        local key = playerKey(player)
        local sprite = runtime.fearSprites[key]
        if sprite then return sprite end
        local ok, created = pcall(function()
            return Sprite()
        end)
        if not ok or not created or type(created.Load) ~= "function" then
            debugLog("player Fear Sprite constructor is unavailable")
            return nil
        end
        local loaded, err = pcall(created.Load, created, PLAYER_FEAR_ANM2, true)
        if not loaded then
            debugLog("player Fear sprite load failed: " .. tostring(err))
            return nil
        end
        runtime.fearSprites[key] = created
        return created
    end

    local function setPlayerBlocked(player, blocked)
        local wasBlocked = runtime.blockedPlayers[player] == true
        local data = getData(player)
        if data then data[PLAYER_BLOCK_DATA_KEY] = blocked == true or nil end
        if blocked then
            runtime.blockedPlayers[player] = true
            local sprite = ensurePlayerFearSprite(player)
            if sprite then
                if not wasBlocked and type(sprite.Play) == "function" then
                    pcall(sprite.Play, sprite, PLAYER_FEAR_ANIMATION, true)
                end
                if type(sprite.Update) == "function" then pcall(sprite.Update, sprite) end
            end
        else
            runtime.blockedPlayers[player] = nil
        end
    end

    local function isPlayerBlocked(player)
        if runtime.blockedPlayers[player] then return true end
        local data = getData(player)
        return data and data[PLAYER_BLOCK_DATA_KEY] == true or false
    end

    local function distanceSquared(left, right)
        local dx = (tonumber(left and left.X) or 0) - (tonumber(right and right.X) or 0)
        local dy = (tonumber(left and left.Y) or 0) - (tonumber(right and right.Y) or 0)
        return dx * dx + dy * dy
    end

    local function findAuraEnemy(player)
        if not player or not player.Position or not Isaac or type(Isaac.FindInRadius) ~= "function" then
            return nil
        end
        local ok, entities = pcall(Isaac.FindInRadius, player.Position, AURA_RADIUS, ENEMY_PARTITION)
        if not ok or type(entities) ~= "table" then return nil end
        for _, entity in ipairs(entities) do
            if isAuraEnemy(entity)
                and entity.Position
                and distanceSquared(player.Position, entity.Position) <= AURA_RADIUS_SQUARED
            then
                return entity
            end
        end
        return nil
    end

    local function applyPlayerAuraState(player)
        local enemy = findAuraEnemy(player)
        if not enemy then
            setPlayerBlocked(player, false)
            return false
        end
        setPlayerBlocked(player, true)
        return true
    end

    local function getPlayerFearWorldPosition(player)
        if not player or not player.Position then return nil end
        local size = math.max(0, tonumber(player.Size) or 20)
        local headOffset = math.max(18, size + 4)
        return makeVector(player.Position.X, player.Position.Y - headOffset)
    end

    local function postPlayerRender(_, player, _renderOffset)
        if not player or not player.Position or not isPlayerBlocked(player) then return nil end
        local sprite = runtime.fearSprites[playerKey(player)]
        if not sprite or type(sprite.Render) ~= "function" or not Isaac
            or type(Isaac.WorldToScreen) ~= "function"
        then
            return nil
        end

        local worldPosition = getPlayerFearWorldPosition(player)
        local ok, screenPosition = pcall(Isaac.WorldToScreen, worldPosition)
        if not ok or not screenPosition then return nil end
        local zero = zeroVector()
        pcall(sprite.Render, sprite, screenPosition, zero, zero)
        return nil
    end

    local function setActive(active)
        active = active == true
        if runtime.active == active then return end
        runtime.active = active
        if not active then
            clearPlayerBlocks()
            clearAuras()
        end
    end

    local function npcUpdate(_, npc)
        if not runtime.active or not isAuraEnemy(npc) then return nil end
        transformEnemy(npc)
        ensureAura(npc)
        return nil
    end

    local function effectUpdate(_, effect)
        local data = getData(effect)
        local owner = data and data[AURA_OWNER_KEY] or nil
        if not owner then return nil end
        if not runtime.active or not isAuraEnemy(owner) then
            removeAura(effect)
            return nil
        end
        effect.Position = owner.Position
        effect.Velocity = zeroVector() or effect.Velocity
        return nil
    end

    local function postUpdate()
        for _, player in ipairs(getPlayers()) do grantTranscendenceOnce(player) end
        setActive(anyPlayerHasItem())
        if not runtime.active then return nil end
        for _, player in ipairs(getPlayers()) do applyPlayerAuraState(player) end
        return nil
    end

    local SHOOT_ACTIONS = {
        [ButtonAction and ButtonAction.ACTION_SHOOTLEFT or 4] = true,
        [ButtonAction and ButtonAction.ACTION_SHOOTRIGHT or 5] = true,
        [ButtonAction and ButtonAction.ACTION_SHOOTUP or 6] = true,
        [ButtonAction and ButtonAction.ACTION_SHOOTDOWN or 7] = true,
    }

    local function inputAction(_, entity, inputHook, buttonAction)
        local player = toPlayer(entity)
        if not player or not isPlayerBlocked(player) or not SHOOT_ACTIONS[buttonAction] then return nil end
        if InputHook and inputHook == InputHook.GET_ACTION_VALUE then return 0 end
        if not InputHook
            or inputHook == InputHook.IS_ACTION_PRESSED
            or inputHook == InputHook.IS_ACTION_TRIGGERED
        then
            return false
        end
        return nil
    end

    local function newRoom()
        clearPlayerBlocks()
        clearAuras()
        setActive(anyPlayerHasItem())
        return nil
    end

    local function gameStarted()
        clearPlayerBlocks()
        clearAuras()
        runtime.fearSprites = {}
        runtime.active = false
        getPersistentData()
        return nil
    end

    local function preGameExit()
        clearPlayerBlocks()
        clearAuras()
        runtime.fearSprites = {}
        runtime.active = false
        return nil
    end

    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    if ModCallbacks.MC_NPC_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_NPC_UPDATE, npcUpdate)
    end
    if ModCallbacks.MC_POST_EFFECT_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, effectUpdate, AURA_VARIANT)
    end
    if ModCallbacks.MC_POST_PLAYER_RENDER then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_RENDER, postPlayerRender)
    end
    if ModCallbacks.MC_INPUT_ACTION then
        if InputHook then
            Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction, InputHook.IS_ACTION_PRESSED)
            Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction, InputHook.IS_ACTION_TRIGGERED)
            Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction, InputHook.GET_ACTION_VALUE)
        else
            Neverbirth:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction)
        end
    end
    if ModCallbacks.MC_POST_NEW_ROOM then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, preGameExit)
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
        IsAuraEnemy = isAuraEnemy,
        IsNativeCursedDeathHead = isNativeCursedDeathHead,
        AuraVisualScale = AURA_VISUAL_SCALE,
        AuraVisualOffsetY = AURA_VISUAL_OFFSET_Y,
        AuraDepthOffset = AURA_DEPTH_OFFSET,
        AuraPlaybackSpeed = AURA_PLAYBACK_SPEED,
        GetPlayerFearWorldPosition = getPlayerFearWorldPosition,
        IsTransformableEnemy = isTransformableEnemy,
        StableHostVariant = stableHostVariant,
        TransformEnemy = transformEnemy,
        EnsureAura = ensureAura,
        ClearAuras = clearAuras,
        ApplyPlayerAuraState = applyPlayerAuraState,
        GrantTranscendenceOnce = grantTranscendenceOnce,
        GetPersistentData = getPersistentData,
        Callbacks = {
            Update = postUpdate,
            NpcUpdate = npcUpdate,
            EffectUpdate = effectUpdate,
            PlayerRender = postPlayerRender,
            InputAction = inputAction,
            NewRoom = newRoom,
            GameStarted = gameStarted,
            PreGameExit = preGameExit,
        },
    }
    Neverbirth.NightOfTheCowardsTestAPI = api
    return api
end
