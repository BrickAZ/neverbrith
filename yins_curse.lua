return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = tonumber(context.ItemId) or -1
    local BLACK_CANDLE_ID = (CollectibleType and CollectibleType.COLLECTIBLE_BLACK_CANDLE) or 260
    local IPECAC_ID = (CollectibleType and CollectibleType.COLLECTIBLE_IPECAC) or 149
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local NO_ENTITY_COLLISION = (EntityCollisionClass and EntityCollisionClass.ENTCOLL_NONE) or 0
    local NO_GRID_COLLISION = (GridCollisionClass and GridCollisionClass.COLLISION_NONE) or 0
    local PENDING_PICKUP_TIMEOUT = 8

    local runtime = {
        frame = 0,
        serial = 0,
        playerCounts = {},
        pending = {},
        failedBonusCandidates = {},
        resolvingQ4 = false,
        testRunSeed = nil,
    }

    local function debugLog(message)
        if type(context.DebugLog) == "function" then
            context.DebugLog("[neverbirth][Yin's Curse] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[neverbirth][Yin's Curse] " .. tostring(message))
        end
    end

    local function getSaveRoot()
        if type(context.GetSaveRoot) ~= "function" then
            return nil
        end
        local ok, root = pcall(context.GetSaveRoot)
        if not ok or type(root) ~= "table" then
            return nil
        end
        if type(root.yinCurse) ~= "table" then
            root.yinCurse = {}
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

    local function resetSavedState(runSeed)
        local root = getSaveRoot()
        if not root then
            return nil
        end
        root.yinCurse = {
            runSeed = tostring(runSeed or currentRunSeed()),
            yinCurseActive = false,
            q4Mode = nil,
            firstQ4Resolved = false,
        }
        return root.yinCurse
    end

    local function getSavedState()
        local root = getSaveRoot()
        if not root then
            return nil
        end
        local state = root.yinCurse
        local runSeed = currentRunSeed()
        if tostring(state.runSeed or "") ~= runSeed then
            state = resetSavedState(runSeed)
        end
        state.yinCurseActive = state.yinCurseActive == true
        state.firstQ4Resolved = state.firstQ4Resolved == true
        if state.q4Mode ~= "bonus_root" and state.q4Mode ~= "replace_root" then
            state.q4Mode = nil
        end
        return state
    end

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local function toPlayer(entity)
        if not entity then
            return nil
        end
        if type(entity.ToPlayer) == "function" then
            local ok, player = pcall(entity.ToPlayer, entity)
            if ok and player then
                return player
            end
        end
        if type(entity.HasCollectible) == "function" then
            return entity
        end
        return nil
    end

    local function hasCollectible(player, itemId)
        if not player or type(player.HasCollectible) ~= "function" then
            return false
        end
        local ok, held = pcall(player.HasCollectible, player, itemId)
        return ok and held == true
    end

    local function collectibleCount(player)
        if not player or type(player.GetCollectibleNum) ~= "function" or ITEM_ID <= 0 then
            return 0
        end
        local ok, count = pcall(player.GetCollectibleNum, player, ITEM_ID, true)
        return ok and math.max(0, math.floor(tonumber(count) or 0)) or 0
    end

    local function getPlayers()
        if type(context.GetPlayers) ~= "function" then
            return {}
        end
        local ok, players = pcall(context.GetPlayers)
        return ok and type(players) == "table" and players or {}
    end

    local processCurrentRoom

    local function recordFirstAcquisition(player, blackCandleSnapshot)
        local state = getSavedState()
        if not state or state.yinCurseActive then
            return false
        end
        local hadBlackCandle = blackCandleSnapshot
        if hadBlackCandle == nil then
            hadBlackCandle = hasCollectible(player, BLACK_CANDLE_ID)
        end
        state.yinCurseActive = true
        state.q4Mode = hadBlackCandle and "bonus_root" or "replace_root"
        state.firstQ4Resolved = false
        save()
        if processCurrentRoom then
            processCurrentRoom()
        end
        return true
    end

    local function pickupExists(pickup)
        if not pickup then
            return false
        end
        if type(pickup.Exists) == "function" then
            local ok, exists = pcall(pickup.Exists, pickup)
            if ok and not exists then
                return false
            end
        end
        return true
    end

    local function isIpecacPedestal(pickup)
        return pickupExists(pickup)
            and tonumber(pickup.Type) == PICKUP_ENTITY
            and tonumber(pickup.Variant) == COLLECTIBLE_PICKUP
            and tonumber(pickup.SubType) == IPECAC_ID
    end

    local function markGeneratedIpecac(pickup)
        if type(pickup.GetData) == "function" then
            local ok, data = pcall(pickup.GetData, pickup)
            if ok and type(data) == "table" then
                data.NeverbirthYinGeneratedIpecac = true
            end
        end
    end

    local function isVisibleInteractableCollectible(pickup)
        if not pickupExists(pickup)
            or tonumber(pickup.Type) ~= PICKUP_ENTITY
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
            or (tonumber(pickup.SubType) or 0) <= 0
            or pickup.Visible == false
            or (tonumber(pickup.Wait) or 0) > 0
        then
            return false
        end
        if pickup.EntityCollisionClass ~= nil
            and tonumber(pickup.EntityCollisionClass) == NO_ENTITY_COLLISION
        then
            return false
        end
        return true
    end

    local function getCollectibleConfig(itemId)
        if not Isaac or type(Isaac.GetItemConfig) ~= "function" then
            return nil
        end
        local okConfig, itemConfig = pcall(Isaac.GetItemConfig)
        if not okConfig or not itemConfig or type(itemConfig.GetCollectible) ~= "function" then
            return nil
        end
        local okItem, item = pcall(itemConfig.GetCollectible, itemConfig, itemId)
        return okItem and item or nil
    end

    local function distanceSquared(left, right)
        local dx = (tonumber(left and left.X) or 0) - (tonumber(right and right.X) or 0)
        local dy = (tonumber(left and left.Y) or 0) - (tonumber(right and right.Y) or 0)
        return dx * dx + dy * dy
    end

    local function isSafeBonusPosition(room, position, sourcePosition)
        if not position or distanceSquared(position, sourcePosition) < 48 * 48 then
            return false
        end
        if room and type(room.IsPositionInRoom) == "function" then
            local ok, inside = pcall(room.IsPositionInRoom, room, position, 24)
            if ok and not inside then
                return false
            end
        end
        if room and type(room.GetGridCollisionAtPos) == "function" then
            local ok, collision = pcall(room.GetGridCollisionAtPos, room, position)
            if ok and tonumber(collision) ~= NO_GRID_COLLISION then
                return false
            end
        end
        if room and type(room.GetDoor) == "function" then
            for slot = 0, 7 do
                local ok, door = pcall(room.GetDoor, room, slot)
                if ok and door and door.Position and distanceSquared(position, door.Position) < 56 * 56 then
                    return false
                end
            end
        end
        if Isaac and type(Isaac.GetRoomEntities) == "function" then
            local ok, entities = pcall(Isaac.GetRoomEntities)
            if ok and type(entities) == "table" then
                for _, entity in ipairs(entities) do
                    if tonumber(entity.Type) == PICKUP_ENTITY
                        and tonumber(entity.Variant) == COLLECTIBLE_PICKUP
                        and entity.Position
                        and distanceSquared(position, entity.Position) < 48 * 48
                    then
                        return false
                    end
                end
            end
        end
        return true
    end

    local function findBonusPosition(sourcePickup)
        if not sourcePickup or not sourcePickup.Position or not Vector then
            return nil
        end
        local room = nil
        if Game then
            local okGame, game = pcall(Game)
            if okGame and game and type(game.GetRoom) == "function" then
                local okRoom, resolvedRoom = pcall(game.GetRoom, game)
                if okRoom then
                    room = resolvedRoom
                end
            end
        end
        local offsets = {
            Vector(80, 0), Vector(-80, 0), Vector(0, 80), Vector(0, -80),
            Vector(72, 56), Vector(-72, 56), Vector(72, -56), Vector(-72, -56),
        }
        for _, offset in ipairs(offsets) do
            local desired = sourcePickup.Position + offset
            local candidate = desired
            if room and type(room.FindFreePickupSpawnPosition) == "function" then
                local ok, freePosition = pcall(room.FindFreePickupSpawnPosition, room, desired, 40, true, false)
                if ok and freePosition then
                    candidate = freePosition
                end
            end
            if isSafeBonusPosition(room, candidate, sourcePickup.Position) then
                return candidate
            end
        end
        if room and type(room.GetCenterPos) == "function" then
            local okCenter, center = pcall(room.GetCenterPos, room)
            if okCenter and center then
                local desired = center + Vector(0, 64)
                local candidate = desired
                if type(room.FindFreePickupSpawnPosition) == "function" then
                    local okFree, freePosition = pcall(room.FindFreePickupSpawnPosition, room, desired, 40, true, false)
                    if okFree and freePosition then
                        candidate = freePosition
                    end
                end
                if isSafeBonusPosition(room, candidate, sourcePickup.Position) then
                    return candidate
                end
            end
        end
        return nil
    end

    local function spawnBonusIpecac(sourcePickup)
        if not Isaac or type(Isaac.Spawn) ~= "function" then
            return nil
        end
        local position = findBonusPosition(sourcePickup)
        if not position then
            debugLog("No safe adjacent position was found for bonus Ipecac")
            return nil
        end
        local velocity = Vector and Vector(0, 0) or { X = 0, Y = 0 }
        local ok, entity = pcall(
            Isaac.Spawn,
            PICKUP_ENTITY,
            COLLECTIBLE_PICKUP,
            IPECAC_ID,
            position,
            velocity,
            sourcePickup
        )
        if not ok or not entity then
            return nil
        end
        local pickup = entity
        if type(entity.ToPickup) == "function" then
            local okPickup, converted = pcall(entity.ToPickup, entity)
            if okPickup and converted then
                pickup = converted
            end
        end
        if isIpecacPedestal(pickup) and pickup.OptionsPickupIndex ~= nil then
            pickup.OptionsPickupIndex = 0
        end
        return pickup
    end

    local function processCandidate(pickup, options)
        options = options or {}
        local state = getSavedState()
        if not state
            or not state.yinCurseActive
            or state.firstQ4Resolved
            or runtime.resolvingQ4
            or not isVisibleInteractableCollectible(pickup)
        then
            return false
        end
        local itemId = math.floor(tonumber(pickup.SubType) or 0)
        if itemId == IPECAC_ID then
            return false
        end
        local configGetter = options.getCollectibleConfig or getCollectibleConfig
        local itemConfig = configGetter(itemId)
        if not itemConfig or tonumber(itemConfig.Quality) ~= 4 then
            return false
        end

        runtime.resolvingQ4 = true
        local resolved = false
        if state.q4Mode == "bonus_root" then
            local key = pickup.InitSeed or pickup
            if runtime.failedBonusCandidates[key] == itemId then
                runtime.resolvingQ4 = false
                return false
            end
            local spawner = options.spawnBonusIpecac or spawnBonusIpecac
            local ok, ipecacPickup = pcall(spawner, pickup)
            resolved = ok and isIpecacPedestal(ipecacPickup)
            if resolved then
                markGeneratedIpecac(ipecacPickup)
            else
                -- A spawn modifier may redirect/remove the result. Do not
                -- duplicate that side effect every frame; retry on room re-entry
                -- or a different pedestal subtype without spending the reward.
                runtime.failedBonusCandidates[key] = itemId
            end
        elseif state.q4Mode == "replace_root" and type(pickup.Morph) == "function" then
            local ok = pcall(
                pickup.Morph,
                pickup,
                PICKUP_ENTITY,
                COLLECTIBLE_PICKUP,
                IPECAC_ID,
                true,
                true,
                true
            )
            -- REPENTOGON PRE_PICKUP_MORPH can veto/redirect without throwing.
            resolved = ok and isIpecacPedestal(pickup)
            if resolved then
                markGeneratedIpecac(pickup)
            end
        end
        if resolved then
            state.firstQ4Resolved = true
            save()
        else
            debugLog("Failed to resolve the first visible quality 4 pedestal; it was preserved")
        end
        runtime.resolvingQ4 = false
        return resolved
    end

    processCurrentRoom = function()
        local state = getSavedState()
        if not state or not state.yinCurseActive or state.firstQ4Resolved
            or not Isaac or type(Isaac.GetRoomEntities) ~= "function"
        then
            return false
        end
        local ok, entities = pcall(Isaac.GetRoomEntities)
        if not ok or type(entities) ~= "table" then
            return false
        end
        table.sort(entities, function(left, right)
            return (tonumber(left and left.InitSeed) or 0) < (tonumber(right and right.InitSeed) or 0)
        end)
        for _, entity in ipairs(entities) do
            local pickup = entity
            if type(entity.ToPickup) == "function" then
                local okPickup, converted = pcall(entity.ToPickup, entity)
                if okPickup and converted then
                    pickup = converted
                end
            end
            if processCandidate(pickup) then
                return true
            end
        end
        return false
    end

    local function prePickupCollision(_, pickup, collider, low)
        if ITEM_ID <= 0
            or not pickup
            or tonumber(pickup.Variant) ~= COLLECTIBLE_PICKUP
            or tonumber(pickup.SubType) ~= ITEM_ID
        then
            return nil
        end
        local player = toPlayer(collider)
        if not player then
            return nil
        end
        local key = playerKey(player)
        if runtime.pending[key] == nil then
            runtime.serial = runtime.serial + 1
            runtime.pending[key] = {
                player = player,
                beforeCount = collectibleCount(player),
                hadBlackCandle = hasCollectible(player, BLACK_CANDLE_ID),
                frame = runtime.frame,
                serial = runtime.serial,
            }
        end
        return nil
    end

    local function postAddCollectible(_, itemId, charge, firstTime, slot, varData, player)
        if itemId ~= ITEM_ID or not player then
            return nil
        end
        local current = collectibleCount(player)
        if current <= 0 then
            return nil
        end
        local key = playerKey(player)
        local pending = runtime.pending[key]
        local hadBlackCandle
        if pending and current > pending.beforeCount then
            hadBlackCandle = pending.hadBlackCandle
        end
        -- REPENTOGON 1.0.12a calls POST_ADD after native AddCollectible.
        -- Commit before another callback can remove Yin or change Black Candle.
        -- Normal pedestals retain their pre-collision Black Candle snapshot.
        recordFirstAcquisition(player, hadBlackCandle)
        runtime.playerCounts[key] = current
        runtime.pending[key] = nil
        return nil
    end

    local function settleAcquisitions()
        local pending = {}
        for key, entry in pairs(runtime.pending) do
            entry.key = key
            pending[#pending + 1] = entry
        end
        table.sort(pending, function(left, right)
            return (tonumber(left.serial) or 0) < (tonumber(right.serial) or 0)
        end)
        for _, entry in ipairs(pending) do
            local current = collectibleCount(entry.player)
            if current > (tonumber(entry.beforeCount) or 0) then
                recordFirstAcquisition(entry.player, entry.hadBlackCandle)
                runtime.playerCounts[entry.key] = current
                runtime.pending[entry.key] = nil
            elseif runtime.frame - (tonumber(entry.frame) or runtime.frame) > PENDING_PICKUP_TIMEOUT then
                runtime.pending[entry.key] = nil
            end
        end

        for _, player in ipairs(getPlayers()) do
            local key = playerKey(player)
            local current = collectibleCount(player)
            local previous = runtime.playerCounts[key]
            if previous == nil then
                previous = 0
            end
            if current > previous and runtime.pending[key] == nil then
                recordFirstAcquisition(player, nil)
            end
            runtime.playerCounts[key] = current
        end
    end

    local function postUpdate()
        runtime.frame = runtime.frame + 1
        settleAcquisitions()
        return nil
    end

    local function pickupInit(_, pickup)
        processCandidate(pickup)
        return nil
    end

    local function pickupUpdate(_, pickup)
        processCandidate(pickup)
        return nil
    end

    local function newRoom()
        runtime.pending = {}
        runtime.failedBonusCandidates = {}
        processCurrentRoom()
        return nil
    end

    local function initializePlayerCounts()
        runtime.playerCounts = {}
        for _, player in ipairs(getPlayers()) do
            runtime.playerCounts[playerKey(player)] = collectibleCount(player)
        end
    end

    local function gameStarted(_, isContinued)
        runtime.frame = 0
        runtime.serial = 0
        runtime.pending = {}
        runtime.failedBonusCandidates = {}
        runtime.resolvingQ4 = false
        runtime.testRunSeed = nil
        if not isContinued then
            resetSavedState(currentRunSeed())
            save()
        else
            getSavedState()
        end
        initializePlayerCounts()
        local state = getSavedState()
        if state and not state.yinCurseActive then
            for _, player in ipairs(getPlayers()) do
                if collectibleCount(player) > 0 then
                    recordFirstAcquisition(player, nil)
                    break
                end
            end
        end
        processCurrentRoom()
        return nil
    end

    local function preGameExit()
        local state = getSavedState()
        if state and state.yinCurseActive then
            save()
        end
        runtime.pending = {}
        return nil
    end

    local function resetRuntimeOnly()
        runtime.frame = 0
        runtime.serial = 0
        runtime.playerCounts = {}
        runtime.pending = {}
        runtime.failedBonusCandidates = {}
        runtime.resolvingQ4 = false
    end

    local function resetForTest(runSeed)
        resetRuntimeOnly()
        runtime.testRunSeed = tostring(runSeed or "test")
        resetSavedState(runtime.testRunSeed)
        return getSavedState()
    end

    Neverbirth.YinsCurseTestAPI = {
        ItemId = ITEM_ID,
        BlackCandleId = BLACK_CANDLE_ID,
        IpecacId = IPECAC_ID,
        Runtime = runtime,
        GetSavedState = getSavedState,
        ResetForTest = resetForTest,
        ResetRuntimeOnly = resetRuntimeOnly,
        RecordFirstAcquisition = recordFirstAcquisition,
        IsVisibleInteractableCollectible = isVisibleInteractableCollectible,
        ProcessCandidate = processCandidate,
        ProcessCurrentRoom = processCurrentRoom,
        Callbacks = {
            PrePickupCollision = prePickupCollision,
            PostAddCollectible = postAddCollectible,
            PostUpdate = postUpdate,
            PickupInit = pickupInit,
            PickupUpdate = pickupUpdate,
            NewRoom = newRoom,
            GameStarted = gameStarted,
            PreGameExit = preGameExit,
        },
    }

    if ITEM_ID <= 0 then
        debugLog("Runtime item ID was not found; callbacks were not registered")
        return
    end

    -- TODO: suppress only explosion immunity when the curse is active and the
    -- damaged player lacks Black Candle, preserving every source's other effects.
    -- 1.0.12a PRE damage can cancel a hit but cannot bypass native immunity.
    -- Black Candle must never grant immunity itself. Do not cancel hits here or
    -- disable whole items as a substitute; see reports/yins-curse/2026-09-16-black-candle-contract.md.
    if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, postAddCollectible, ITEM_ID)
    end
    Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, postUpdate)
    if ModCallbacks.MC_PRE_PICKUP_COLLISION then
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, prePickupCollision, COLLECTIBLE_PICKUP)
    end
    if ModCallbacks.MC_POST_PICKUP_INIT then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, pickupInit, COLLECTIBLE_PICKUP)
    end
    if ModCallbacks.MC_POST_PICKUP_UPDATE then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, pickupUpdate, COLLECTIBLE_PICKUP)
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
end
