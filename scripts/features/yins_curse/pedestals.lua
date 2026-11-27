-- Private pedestals ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local IPECAC_ID = deps.State.IPECAC_ID
    local PICKUP_ENTITY = deps.State.PICKUP_ENTITY
    local COLLECTIBLE_PICKUP = deps.State.COLLECTIBLE_PICKUP
    local NO_ENTITY_COLLISION = deps.State.NO_ENTITY_COLLISION
    local NO_GRID_COLLISION = deps.State.NO_GRID_COLLISION
    local runtime = deps.State.runtime
    local debugLog = deps.State.debugLog
    local save = deps.State.save
    local getSavedState = deps.State.getSavedState

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

    local function processCurrentRoom()
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

    local function pickupInit(_, pickup)
        processCandidate(pickup)
        return nil
    end
    function callbackInstallers.pickupInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, pickupInit, COLLECTIBLE_PICKUP)
    end

    local function pickupUpdate(_, pickup)
        processCandidate(pickup)
        return nil
    end
    function callbackInstallers.pickupUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, pickupUpdate, COLLECTIBLE_PICKUP)
    end

    return {
        pickupExists = pickupExists,
        isIpecacPedestal = isIpecacPedestal,
        markGeneratedIpecac = markGeneratedIpecac,
        isVisibleInteractableCollectible = isVisibleInteractableCollectible,
        getCollectibleConfig = getCollectibleConfig,
        distanceSquared = distanceSquared,
        isSafeBonusPosition = isSafeBonusPosition,
        findBonusPosition = findBonusPosition,
        spawnBonusIpecac = spawnBonusIpecac,
        processCandidate = processCandidate,
        processCurrentRoom = processCurrentRoom,
        pickupInit = pickupInit,
        pickupUpdate = pickupUpdate,
        Installers = callbackInstallers,
    }
end
