-- Private rewards ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local ITEM_ID = deps.State.ITEM_ID
    local VANILLA_COLLECTIBLE_LIMIT = deps.State.VANILLA_COLLECTIBLE_LIMIT
    local MAX_REROLL_ATTEMPTS = deps.State.MAX_REROLL_ATTEMPTS
    local SLOT_PRIMARY = deps.State.SLOT_PRIMARY
    local PICKUP_COLLECTIBLE = deps.State.PICKUP_COLLECTIBLE
    local ENTITY_PICKUP = deps.State.ENTITY_PICKUP
    local BANNED_COLLECTIBLES = deps.State.BANNED_COLLECTIBLES
    local PROTECTED_SET = deps.State.PROTECTED_SET
    local runtime = deps.State.runtime
    local DebugLog = deps.State.DebugLog
    local Save = deps.State.Save
    local GetSavedState = deps.State.GetSavedState
    local GetPlayerKey = deps.State.GetPlayerKey
    local AnyPlayerActive = deps.State.AnyPlayerActive
    local GetRoomKey = deps.State.GetRoomKey
    local GetFrameCount = deps.State.GetFrameCount
    local GetCollectibleConfig = deps.Inventory.GetCollectibleConfig
    local GetCollectibleCount = deps.Inventory.GetCollectibleCount

    local function GetPedestalCycle(pickup)
        -- REPENTOGON 1.0.12a exposes the native choice list (Soul of Isaac,
        -- etc.). Merely displaying another choice is not a new reroll.
        local cycle = pickup.GetCollectibleCycle and pickup:GetCollectibleCycle()
        if type(cycle) ~= "table" or #cycle == 0 then return nil end
        local members, ids = {}, {}
        local function Add(id)
            if type(id) == "number" and id > 0 and not members[tostring(id)] then
                members[tostring(id)] = true
                ids[#ids + 1] = id
            end
        end
        Add(pickup.SubType)
        for _, id in ipairs(cycle) do Add(id) end
        table.sort(ids)
        return table.concat(ids, ":"), members
    end

    local function GetPedestalRecord(pickup)
        local saved = GetSavedState()
        local game = Game and Game()
        local level = game and game.GetLevel and game:GetLevel()
        local floorKey = level and table.concat({
            tostring(level.GetStage and level:GetStage() or 0),
            tostring(level.GetStageType and level:GetStageType() or 0),
            tostring(level.GetDungeonPlacementSeed and level:GetDungeonPlacementSeed() or 0),
        }, ":") or "unknown-floor"
        if saved.pedestalFloor ~= floorKey or type(saved.pedestalRooms) ~= "table" then
            saved.pedestalFloor, saved.pedestalRooms = floorKey, {}
        end
        local roomKey, seedKey = GetRoomKey(), tostring(pickup.InitSeed)
        local rooms = saved.pedestalRooms
        rooms[roomKey] = type(rooms[roomKey]) == "table" and rooms[roomKey] or {}
        local records = rooms[roomKey]
        local data = pickup.GetData and pickup:GetData() or {}
        -- A native reroll can reseed the existing entity. Retain only its latest
        -- record, not one saved entry for every reroll in an endless session.
        local previous = data.NeverbirthSevenCursesRecordKey
        if previous and previous ~= seedKey then records[previous] = nil end
        data.NeverbirthSevenCursesRecordKey = seedKey
        local rng = pickup.GetDropRNG and pickup:GetDropRNG()
        local dropSeed = rng and rng.GetSeed and rng:GetSeed() or pickup.InitSeed
        local record = records[seedKey]
        local cycleKey, members = GetPedestalCycle(pickup)
        if cycleKey then
            if type(record) ~= "table" or record.dropSeed ~= dropSeed or record.cycleKey ~= cycleKey then
                local candidates = {}
                -- Soul of Isaac can add a choice after we already paid for the
                -- original pedestal. Migrate that record, including old saves
                -- and the native starting-active exclusion, without paying again.
                if type(record) == "table" and record.dropSeed == dropSeed
                    and not record.cycleKey and members[tostring(record.itemId)] then
                    candidates[tostring(record.itemId)] = record
                end
                record = { dropSeed = dropSeed, cycleKey = cycleKey, candidates = candidates }
                records[seedKey] = record
            end
            local key = tostring(pickup.SubType)
            local candidate = record.candidates[key]
            if not candidate then
                candidate = { itemId = pickup.SubType, dropSeed = dropSeed, attempted = false }
                record.candidates[key] = candidate
            end
            -- Only the visible choice is checked. Keep only this generation's
            -- bounded native choices; genuine reseeds/replaced cycles reset it.
            return candidate
        end
        if type(record) ~= "table" or record.cycleKey
            or record.itemId ~= pickup.SubType or record.dropSeed ~= dropSeed then
            record = { itemId = pickup.SubType, dropSeed = dropSeed, attempted = false }
            records[seedKey] = record
        end
        return record
    end

    local function ConfirmNativeActiveDrop(player)
        local key = GetPlayerKey(player)
        local pending = runtime.pendingRingPickups[key]
        if not pending then return end
        local pickup = pending.pickup
        if not pickup or (pickup.Exists and not pickup:Exists())
            or pending.roomKey ~= GetRoomKey() or GetFrameCount() - pending.frame > 15 then
            runtime.pendingRingPickups[key] = nil
            return
        end
        -- Collision is only a snapshot. The ring must actually occupy this
        -- player's primary slot and that exact pedestal must contain the old
        -- active. A different D6 elsewhere in the room is never whitelisted.
        if player.GetActiveItem and player:GetActiveItem(SLOT_PRIMARY) == ITEM_ID
            and pickup.SubType == pending.itemId then
            local record = GetPedestalRecord(pickup)
            record.nativeDropOwner, record.attempted = key, true
            runtime.pendingRingPickups[key] = nil
            Save()
        elseif pickup.SubType ~= ITEM_ID then
            runtime.pendingRingPickups[key] = nil
        end
    end

    local function IsForbiddenCollectible(itemId)
        itemId = tonumber(itemId) or 0
        if itemId <= 0 then return true end
        if itemId == ITEM_ID or PROTECTED_SET[itemId] then return false end
        if BANNED_COLLECTIBLES[itemId] then return true end
        if itemId >= VANILLA_COLLECTIBLE_LIMIT then return true end
        local config = GetCollectibleConfig(itemId)
        return config and tonumber(config.Quality) == 4 or false
    end

    local function IsLegalCompensation(itemId)
        local config = GetCollectibleConfig(itemId)
        return config and not IsForbiddenCollectible(itemId)
            and (config.Type == ((ItemType and ItemType.ITEM_PASSIVE) or 1)
                or config.Type == ((ItemType and ItemType.ITEM_FAMILIAR) or 2))
    end

    local function RerollForbiddenSelection(selected, poolType, decrease, seed, itemPool)
        if IsLegalCompensation(selected) then return selected, true end
        if type(poolType) ~= "number" or poolType < 0 then
            DebugLog("reroll preserved c" .. tostring(selected) .. ": source pool unavailable (" .. tostring(poolType) .. ")")
            return selected, false
        end
        local game = Game and Game()
        itemPool = itemPool or (game and game.GetItemPool and game:GetItemPool())
        if not itemPool or not itemPool.GetCollectible then return selected, false end

        for attempt = 1, MAX_REROLL_ATTEMPTS do
            local candidateSeed = ((tonumber(seed) or 1) + attempt * 7919) % 2147483647
            runtime.rerollDepth = runtime.rerollDepth + 1
            local ok, candidate = pcall(itemPool.GetCollectible, itemPool, poolType, decrease, candidateSeed)
            runtime.rerollDepth = math.max(0, runtime.rerollDepth - 1)
            if not ok then
                DebugLog("reroll API failed for c" .. tostring(selected) .. " pool=" .. tostring(poolType)
                    .. ": " .. tostring(candidate))
                return selected, false
            end
            -- A result must be obtainable, not merely non-Q4: the ring locks
            -- the primary active slot, so an active replacement is no reward.
            if candidate and IsLegalCompensation(candidate) then return candidate, true end
        end
        DebugLog("no legal same-pool collectible found after " .. MAX_REROLL_ATTEMPTS .. " attempts")
        return selected, false
    end

    local function GetCurrentRoomPool(seed)
        local game = Game and Game()
        local room = game and game.GetRoom and game:GetRoom()
        local itemPool = game and game.GetItemPool and game:GetItemPool()
        if not room or not itemPool or not itemPool.GetPoolForRoom then return nil, itemPool end
        local roomType = room.GetType and room:GetType() or 1
        local ok, poolType = pcall(function() return itemPool:GetPoolForRoom(roomType, seed or 1) end)
        if not ok then DebugLog("source pool lookup failed: " .. tostring(poolType)); return nil, itemPool end
        return poolType, itemPool
    end

    local function IsVisibleInteractableCollectible(pickup)
        if not pickup or pickup.Variant ~= PICKUP_COLLECTIBLE then return false end
        if pickup.Exists and not pickup:Exists() then return false end
        if pickup.Visible == false then return false end
        if (pickup.Wait or 0) > 0 then return false end
        return (pickup.SubType or 0) > 0
    end

    local function FindCompensationPosition(pickup)
        local game = Game and Game()
        local room = game and game.GetRoom and game:GetRoom()
        if not room or not room.FindFreePickupSpawnPosition or not pickup.Position or not Vector then return nil end
        for _, offset in ipairs({ {40, 0}, {-40, 0}, {0, 40}, {0, -40} }) do
            local desired = Vector(pickup.Position.X + offset[1], pickup.Position.Y + offset[2])
            local position = room:FindFreePickupSpawnPosition(desired, 40, true, false)
            if position then
                local dx, dy = position.X - pickup.Position.X, position.Y - pickup.Position.Y
                if dx * dx + dy * dy >= 32 * 32
                    and (not room.IsPositionInRoom or room:IsPositionInRoom(position, 16))
                    and (not room.GetGridCollisionAtPos or room:GetGridCollisionAtPos(position) == 0) then
                    return position
                end
            end
        end
        return nil
    end

    local function SpawnCompensation(source, itemId, poolType, itemPool, seed, attempt)
        local position = FindCompensationPosition(source)
        if not position or not Isaac or not Isaac.Spawn or not IsLegalCompensation(itemId) then return nil end
        local entity = Isaac.Spawn(ENTITY_PICKUP, PICKUP_COLLECTIBLE, itemId, position, Vector(0, 0), source)
        attempt.entity = entity
        local reward = entity and entity.ToPickup and entity:ToPickup() or nil
        if not reward or reward.Variant ~= PICKUP_COLLECTIBLE then
            if entity and entity.Remove then entity:Remove() end
            return nil
        end
        -- Tainted Isaac or another spawn modifier may change the requested
        -- result. Correct only this owned reward, never spawn another chain.
        if not IsLegalCompensation(reward.SubType) then
            local replacement, success = RerollForbiddenSelection(reward.SubType, poolType, true, seed + 7919, itemPool)
            if success and reward.Morph then
                reward:Morph(ENTITY_PICKUP, PICKUP_COLLECTIBLE, replacement, true, true, true)
            end
        end
        if not IsLegalCompensation(reward.SubType) then
            if reward.Remove then reward:Remove() end
            return nil
        end
        reward.Price, reward.ShopItemId = source.Price or 0, source.ShopItemId or -1
        reward.AutoUpdatePrice = source.AutoUpdatePrice == true
        -- Native option groups delete their other pedestals when collected.
        -- The promised original Q4 must remain after collecting compensation.
        reward.OptionsPickupIndex = 0
        reward.Touched = false
        GetPedestalRecord(reward).attempted = true
        return reward
    end

    local function CompensateForbiddenPedestal(pickup)
        if runtime.spawningCompensation or not IsVisibleInteractableCollectible(pickup) then return false end
        for _, pending in pairs(runtime.pendingRingPickups) do
            if pending.pickup == pickup then ConfirmNativeActiveDrop(pending.player) end
        end
        if not AnyPlayerActive() then return false end
        local record = GetPedestalRecord(pickup)
        local data = pickup.GetData and pickup:GetData() or {}
        -- Old releases left these GetData flags behind after Morph. They no
        -- longer own collision or reward settlement; current contents do.
        data.NeverbirthSevenCursesBlocked, data.NeverbirthSevenCursesFailure = nil, nil
        if record.nativeDropOwner or record.attempted then return false end
        record.attempted = true
        if not IsForbiddenCollectible(pickup.SubType) then Save(); return false end

        local seed = tonumber(record.dropSeed) or tonumber(pickup.InitSeed) or 1
        local poolType, itemPool = GetCurrentRoomPool(seed)
        local itemId, success = RerollForbiddenSelection(pickup.SubType, poolType, true, seed, itemPool)
        local reward
        if success then
            local attempt = {}
            runtime.spawningCompensation = true
            local ok, result = pcall(SpawnCompensation, pickup, itemId, poolType, itemPool, seed, attempt)
            runtime.spawningCompensation = false
            if ok then
                reward = result
            else
                -- An exception can occur after Spawn, for example while a
                -- modifier's result is being corrected. Never leave that
                -- unvalidated owned reward behind or remove the source.
                local entity = attempt.entity
                if entity and entity.Remove then pcall(entity.Remove, entity) end
                DebugLog("compensation spawn failed: " .. tostring(result))
            end
        end
        record.compensated = reward ~= nil
        Save()
        if not reward then
            DebugLog("compensation unavailable; original c" .. tostring(pickup.SubType)
                .. " retained, waiting for an external reroll")
        end
        return reward ~= nil
    end

    local function IsTradeRoom()
        local game = Game and Game()
        local room = game and game.GetRoom and game:GetRoom()
        local level = game and game.GetLevel and game:GetLevel()
        local roomType = room and room.GetType and room:GetType() or -1
        if roomType == ((RoomType and RoomType.ROOM_DEVIL) or 14)
            or roomType == ((RoomType and RoomType.ROOM_ANGEL) or 15) then return true end
        local angelShopIndex = (LevelRoomIdx and LevelRoomIdx.ROOM_ANGEL_SHOP_IDX) or -18
        return level and level.GetCurrentRoomIndex and level:GetCurrentRoomIndex() == angelShopIndex
    end

    local function RegisterTradeCandidate(pickup, player)
        if not IsTradeRoom() or not pickup or not player then return false end
        local itemId = pickup.SubType or 0
        if itemId <= 0 then return false end
        local seed = tostring(pickup.InitSeed or pickup)
        runtime.pendingTrades[seed] = {
            pickup = pickup,
            player = player,
            itemId = itemId,
            before = GetCollectibleCount(player, itemId),
            frame = GetFrameCount(),
        }
        return true
    end

    local function SettleTradeCandidates()
        local now = GetFrameCount()
        for key, pending in pairs(runtime.pendingTrades) do
            local player = pending.player
            if player and GetCollectibleCount(player, pending.itemId) > pending.before then
                if player.AddBrokenHearts then player:AddBrokenHearts(1) end
                runtime.pendingTrades[key] = nil
            elseif now - pending.frame > 15 then
                runtime.pendingTrades[key] = nil
            end
        end
    end

    return {
        GetPedestalCycle = GetPedestalCycle,
        GetPedestalRecord = GetPedestalRecord,
        ConfirmNativeActiveDrop = ConfirmNativeActiveDrop,
        IsForbiddenCollectible = IsForbiddenCollectible,
        IsLegalCompensation = IsLegalCompensation,
        RerollForbiddenSelection = RerollForbiddenSelection,
        GetCurrentRoomPool = GetCurrentRoomPool,
        IsVisibleInteractableCollectible = IsVisibleInteractableCollectible,
        FindCompensationPosition = FindCompensationPosition,
        SpawnCompensation = SpawnCompensation,
        CompensateForbiddenPedestal = CompensateForbiddenPedestal,
        IsTradeRoom = IsTradeRoom,
        RegisterTradeCandidate = RegisterTradeCandidate,
        SettleTradeCandidates = SettleTradeCandidates,
    }
end
