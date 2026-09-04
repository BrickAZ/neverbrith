return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = context.ItemId or -1
    local SLOT_TRINKET_ID = context.TrinketId or -1
    local VANILLA_COLLECTIBLE_LIMIT = (CollectibleType and CollectibleType.NUM_COLLECTIBLES) or 733
    local MAX_REROLL_ATTEMPTS = 40
    local HEALTH_CAP = 12
    local KEY_CAP = 2
    local BOMB_CAP = 1
    local COIN_CAP = 20
    local COIN_DEAL_CAP = 35
    local ROOM_CHARGE_INTERVAL = 2

    local SLOT_PRIMARY = (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    local SLOT_SECONDARY = (ActiveSlot and ActiveSlot.SLOT_SECONDARY) or 1
    local PICKUP_COLLECTIBLE = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local PICKUP_TRINKET = (PickupVariant and PickupVariant.PICKUP_TRINKET) or 350
    local ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local ENTITY_PLAYER = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local ITEM_ACTIVE = (ItemType and ItemType.ITEM_ACTIVE) or 3

    local REQUIRED_CURSES =
        ((LevelCurse and LevelCurse.CURSE_OF_DARKNESS) or 1)
        | ((LevelCurse and LevelCurse.CURSE_OF_THE_LOST) or 4)
        | ((LevelCurse and LevelCurse.CURSE_OF_THE_UNKNOWN) or 8)
        | ((LevelCurse and LevelCurse.CURSE_OF_MAZE) or 32)

    local IDS = {
        Sol = (CollectibleType and CollectibleType.COLLECTIBLE_SOL) or 588,
        BlackCandle = (CollectibleType and CollectibleType.COLLECTIBLE_BLACK_CANDLE) or 260,
        Schoolbag = (CollectibleType and CollectibleType.COLLECTIBLE_SCHOOLBAG) or 534,
        LittleHorn = (CollectibleType and CollectibleType.COLLECTIBLE_LITTLE_HORN) or 503,
        Euthanasia = (CollectibleType and CollectibleType.COLLECTIBLE_EUTHANASIA) or 496,
        FruitCake = (CollectibleType and CollectibleType.COLLECTIBLE_FRUIT_CAKE) or 418,
        PoundOfFlesh = (CollectibleType and CollectibleType.COLLECTIBLE_POUND_OF_FLESH) or 672,
        TheWiz = (CollectibleType and CollectibleType.COLLECTIBLE_THE_WIZ) or 358,
        CurseOfTheTower = (CollectibleType and CollectibleType.COLLECTIBLE_CURSE_OF_THE_TOWER) or 371,
        CursedEye = (CollectibleType and CollectibleType.COLLECTIBLE_CURSED_EYE) or 316,
        MonkeyPaw = (TrinketType and TrinketType.TRINKET_MONKEY_PAW) or 20,
        KeepersBargain = (TrinketType and TrinketType.TRINKET_KEEPERS_BARGAIN) or 171,
    }

    local BANNED_COLLECTIBLES = {
        [IDS.Sol] = true,
        [IDS.BlackCandle] = true,
        [IDS.Schoolbag] = true,
        [IDS.LittleHorn] = true,
        [IDS.Euthanasia] = true,
        [IDS.FruitCake] = true,
    }

    local PROTECTED_COLLECTIBLES = {
        IDS.TheWiz,
        IDS.CurseOfTheTower,
        IDS.CursedEye,
    }
    local PROTECTED_SET = {}
    for _, id in ipairs(PROTECTED_COLLECTIBLES) do PROTECTED_SET[id] = true end

    local runtime = {
        damageRewrite = {},
        pendingTrades = {},
        pendingRingPickups = {},
        spawningCompensation = false,
        rerollDepth = 0,
        lastCurseCheckFrame = -1,
        roomVisit = 0,
    }
    local EnforceCurrentFloorCurses

    local function DebugLog(message)
        if context.DebugLog then
            context.DebugLog("[Seven Curses] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[neverbirth][Seven Curses] " .. tostring(message))
        end
    end

    local function Save()
        if context.Save then context.Save() end
    end

    local function GetRunSeed()
        if context.GetCurrentRunSeed then return tostring(context.GetCurrentRunSeed()) end
        local game = Game and Game()
        local seeds = game and game.GetSeeds and game:GetSeeds()
        if seeds and seeds.GetStartSeed then return tostring(seeds:GetStartSeed()) end
        return "unknown"
    end

    local function GetSaveRoot()
        if context.GetSaveRoot then return context.GetSaveRoot() end
        Neverbirth.RingOfSevenCursesSave = Neverbirth.RingOfSevenCursesSave or {}
        return Neverbirth.RingOfSevenCursesSave
    end

    local function GetSavedState()
        local root = GetSaveRoot()
        local runSeed = GetRunSeed()
        local state = root.ringOfSevenCurses
        if type(state) ~= "table" or tostring(state.runSeed) ~= runSeed then
            state = { runSeed = runSeed, players = {} }
            root.ringOfSevenCurses = state
        end
        if type(state.players) ~= "table" then state.players = {} end
        return state
    end

    local function GetPlayerKey(player)
        if player and player.InitSeed ~= nil then return tostring(player.InitSeed) end
        if player and player.ControllerIndex ~= nil then return "controller:" .. tostring(player.ControllerIndex) end
        if GetPtrHash and player then return "ptr:" .. tostring(GetPtrHash(player)) end
        return tostring(player)
    end

    local function GetPlayerState(player, create)
        local players = GetSavedState().players
        local key = GetPlayerKey(player)
        local state = players[key]
        if not state and create then
            state = {
                active = false,
                roomProgress = 0,
                lastRoomKey = nil,
                nativeSecondary = 0,
                protectedCounts = {},
            }
            players[key] = state
        end
        if state then
            state.roomProgress = tonumber(state.roomProgress) or 0
            state.nativeSecondary = tonumber(state.nativeSecondary) or 0
            state.protectedCounts = type(state.protectedCounts) == "table" and state.protectedCounts or {}
        end
        return state
    end

    local function GetPlayers()
        if context.GetPlayers then return context.GetPlayers() or {} end
        local result = {}
        local game = Game and Game()
        local count = game and game.GetNumPlayers and game:GetNumPlayers() or 0
        for index = 0, count - 1 do result[#result + 1] = Isaac.GetPlayer(index) end
        return result
    end

    local function IsPlayerActive(player)
        local state = player and GetPlayerState(player, false)
        return state and state.active == true or false
    end

    local function AnyPlayerActive()
        for _, player in ipairs(GetPlayers()) do
            if IsPlayerActive(player) then return true end
        end
        return false
    end

    local function GetRoomKey()
        if context.GetRoomKey then return tostring(context.GetRoomKey()) end
        local game = Game and Game()
        local level = game and game.GetLevel and game:GetLevel()
        if not level then return "unknown-room" end
        local stage = level.GetStage and level:GetStage() or 0
        local dimension = level.GetDimension and level:GetDimension() or 0
        local index = level.GetCurrentRoomIndex and level:GetCurrentRoomIndex() or 0
        return table.concat({ tostring(stage), tostring(index), tostring(dimension) }, ":")
    end

    local function GetFrameCount()
        local game = Game and Game()
        return game and game.GetFrameCount and game:GetFrameCount() or 0
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
        if type(record) ~= "table" or record.itemId ~= pickup.SubType or record.dropSeed ~= dropSeed then
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

    local function GetCollectibleConfig(itemId)
        if not Isaac or not Isaac.GetItemConfig then return nil end
        local itemConfig = Isaac.GetItemConfig()
        if not itemConfig or not itemConfig.GetCollectible then return nil end
        return itemConfig:GetCollectible(itemId)
    end

    local function GetCollectibleCount(player, itemId)
        if not player or not player.GetCollectibleNum then return 0 end
        return player:GetCollectibleNum(itemId, true) or player:GetCollectibleNum(itemId) or 0
    end

    local function HasCollectible(player, itemId)
        if not player then return false end
        if player.HasCollectible then return player:HasCollectible(itemId, true) end
        return GetCollectibleCount(player, itemId) > 0
    end

    local function GetTrinketMultiplier(player, trinketId)
        if not player or not player.GetTrinketMultiplier then return 0 end
        return player:GetTrinketMultiplier(trinketId) or 0
    end

    local function RequestCaches(player)
        if not player then return end
        local flags =
            ((CacheFlag and CacheFlag.CACHE_DAMAGE) or 1)
            | ((CacheFlag and CacheFlag.CACHE_FIREDELAY) or 2)
            | ((CacheFlag and CacheFlag.CACHE_SHOTSPEED) or 4)
            | ((CacheFlag and CacheFlag.CACHE_FLYING) or 128)
            | ((CacheFlag and CacheFlag.CACHE_LUCK) or 1024)
        if player.AddCacheFlags then player:AddCacheFlags(flags) end
        if player.EvaluateItems then player:EvaluateItems() end
    end

    local function RemoveAllCopies(player, itemId)
        if not player or not player.RemoveCollectible then return false end
        local changed = false
        local count = GetCollectibleCount(player, itemId)
        for _ = 1, math.min(count, 64) do
            player:RemoveCollectible(itemId)
            changed = true
        end
        return changed
    end

    local function RemoveBannedTrinket(player)
        if not player or not player.TryRemoveTrinket then return false end
        local changed = false
        local count = math.min(GetTrinketMultiplier(player, IDS.MonkeyPaw), 64)
        for _ = 1, count do
            if player:TryRemoveTrinket(IDS.MonkeyPaw) then changed = true end
        end
        return changed
    end

    local function DropHeldTrinkets(player)
        if not player or not player.GetTrinket or not player.TryRemoveTrinket then return false end
        local changed = false
        local held = { player:GetTrinket(0) or 0, player:GetTrinket(1) or 0 }
        for slot = 0, 1 do
            local trinketId = held[slot + 1]
            if trinketId > 0 and trinketId ~= SLOT_TRINKET_ID and player:TryRemoveTrinket(trinketId) then
                changed = true
                if Isaac and Isaac.Spawn and player.Position then
                    Isaac.Spawn(ENTITY_PICKUP, PICKUP_TRINKET, trinketId, player.Position,
                        (Vector and Vector.Zero) or Vector(0, 0), player)
                end
            end
        end
        return changed
    end

    local function EnsureSlotTrinket(player)
        if SLOT_TRINKET_ID <= 0 or not player or not player.GetTrinket or not player.AddTrinket then return false end
        if player:GetTrinket(0) == SLOT_TRINKET_ID or player:GetTrinket(1) == SLOT_TRINKET_ID then return false end
        player:AddTrinket(SLOT_TRINKET_ID, false)
        return player:GetTrinket(0) == SLOT_TRINKET_ID or player:GetTrinket(1) == SLOT_TRINKET_ID
    end

    local function RemoveBannedSources(player)
        local changed = false
        for itemId in pairs(BANNED_COLLECTIBLES) do
            if RemoveAllCopies(player, itemId) then changed = true end
        end
        if RemoveBannedTrinket(player) then changed = true end
        return changed
    end

    local function ProtectCompatibleCollectibles(player, state)
        local changed = false
        for _, itemId in ipairs(PROTECTED_COLLECTIBLES) do
            local key = tostring(itemId)
            local current = GetCollectibleCount(player, itemId)
            local protected = tonumber(state.protectedCounts[key]) or 0
            if current > protected then
                state.protectedCounts[key] = current
                changed = true
            elseif current < protected and player.AddCollectible then
                for _ = current + 1, protected do player:AddCollectible(itemId, 0, false) end
                changed = true
            end
        end
        return changed
    end

    local function EnsureRingInPrimary(player, state)
        if not state or not state.active or not player or not player.GetActiveItem then return false end
        if player:GetActiveItem(SLOT_PRIMARY) == ITEM_ID then return false end
        if player.AddCollectible then
            player:AddCollectible(ITEM_ID, 0, false, SLOT_PRIMARY)
            DebugLog("restored protected primary active for player " .. GetPlayerKey(player))
            return true
        end
        return false
    end

    local function EnsureNativeSecondary(player, state)
        local itemId = state and tonumber(state.nativeSecondary) or 0
        if itemId <= 0 or not player or not player.GetActiveItem then return false end
        if player:GetActiveItem(SLOT_SECONDARY) == itemId then return false end
        if player.AddCollectible then
            player:AddCollectible(itemId, 0, false, SLOT_SECONDARY)
            DebugLog("restored retained native secondary for player " .. GetPlayerKey(player))
            return true
        end
        return false
    end

    local function GetTotalHealthCapacity(player)
        if not player then return 0 end
        local maxHearts = player.GetMaxHearts and player:GetMaxHearts() or 0
        local soulHearts = player.GetSoulHearts and player:GetSoulHearts() or 0
        local boneHearts = player.GetBoneHearts and player:GetBoneHearts() or 0
        local eternalHearts = player.GetEternalHearts and player:GetEternalHearts() or 0
        return math.max(0, maxHearts) + math.max(0, soulHearts)
            + math.max(0, boneHearts) * 2 + math.max(0, eternalHearts)
    end

    local function ClampHealth(player)
        local overflow = GetTotalHealthCapacity(player) - HEALTH_CAP
        if overflow <= 0 then return false end
        local changed = false

        if overflow > 0 and player.GetEternalHearts and player.AddEternalHearts then
            local remove = math.min(overflow, math.max(0, player:GetEternalHearts() or 0))
            if remove > 0 then player:AddEternalHearts(-remove); overflow = overflow - remove; changed = true end
        end
        if overflow > 0 and player.GetSoulHearts and player.AddSoulHearts then
            local remove = math.min(overflow, math.max(0, player:GetSoulHearts() or 0))
            if remove > 0 then player:AddSoulHearts(-remove); overflow = overflow - remove; changed = true end
        end
        if overflow > 0 and player.GetBoneHearts and player.AddBoneHearts then
            local available = math.max(0, player:GetBoneHearts() or 0)
            local remove = math.min(available, math.ceil(overflow / 2))
            if remove > 0 then player:AddBoneHearts(-remove); overflow = math.max(0, overflow - remove * 2); changed = true end
        end
        if overflow > 0 and player.GetMaxHearts and player.AddMaxHearts then
            local remove = math.min(overflow, math.max(0, player:GetMaxHearts() or 0))
            if remove > 0 then player:AddMaxHearts(-remove, false); changed = true end
        end
        return changed
    end

    local function IsKeeper(player)
        if not player or not player.GetPlayerType then return false end
        local playerType = player:GetPlayerType()
        return playerType == ((PlayerType and PlayerType.PLAYER_KEEPER) or 14)
            or playerType == ((PlayerType and PlayerType.PLAYER_KEEPER_B) or 33)
    end

    local function GetCoinCap(player)
        if IsKeeper(player) then return nil end
        if HasCollectible(player, IDS.PoundOfFlesh)
            or GetTrinketMultiplier(player, IDS.KeepersBargain) > 0 then
            return COIN_DEAL_CAP
        end
        return COIN_CAP
    end

    local function ClampResources(player)
        local changed = false
        if player.GetNumKeys and player.AddKeys then
            local current = player:GetNumKeys()
            if current > KEY_CAP then player:AddKeys(KEY_CAP - current); changed = true end
        end
        if player.GetNumBombs and player.AddBombs then
            local current = player:GetNumBombs()
            if current > BOMB_CAP then player:AddBombs(BOMB_CAP - current); changed = true end
        end
        local cap = GetCoinCap(player)
        if cap and player.GetNumCoins and player.AddCoins then
            local current = player:GetNumCoins()
            if current > cap then player:AddCoins(cap - current); changed = true end
        end
        return changed
    end

    local function IsValidEnemy(npc)
        if not npc then return false end
        if npc.Exists and not npc:Exists() then return false end
        if npc.IsDead and npc:IsDead() then return false end
        if npc.IsActiveEnemy and not npc:IsActiveEnemy(false) then return false end
        if npc.IsVulnerableEnemy and not npc:IsVulnerableEnemy() then return false end
        if npc.HasEntityFlags then
            local friendly = (EntityFlag and EntityFlag.FLAG_FRIENDLY) or 1
            local charm = (EntityFlag and EntityFlag.FLAG_CHARM) or 2
            if npc:HasEntityFlags(friendly) or npc:HasEntityFlags(charm) then return false end
        end
        return (npc.MaxHitPoints or 0) > 0
    end

    local function DoubleNpcHealth(npc)
        if not AnyPlayerActive() or not IsValidEnemy(npc) then return false end
        local data = npc.GetData and npc:GetData() or nil
        if data and data.NeverbirthSevenCursesHealthDoubled then return false end
        if data then data.NeverbirthSevenCursesHealthDoubled = true end
        npc.MaxHitPoints = math.max(0, npc.MaxHitPoints or 0) * 2
        npc.HitPoints = math.min(npc.MaxHitPoints, math.max(0, npc.HitPoints or 0) * 2)
        return true
    end

    local function ScanCurrentRoomEnemies()
        if not AnyPlayerActive() or not Isaac or not Isaac.GetRoomEntities then return end
        for _, entity in ipairs(Isaac.GetRoomEntities()) do
            local npc = entity.ToNPC and entity:ToNPC() or nil
            if npc then DoubleNpcHealth(npc) end
        end
    end

    local function ActivatePlayer(player)
        if not player then return false end
        local state = GetPlayerState(player, true)
        if state.active then return false end

        state.active = true
        state.roomProgress = 0
        state.lastRoomKey = GetRoomKey()
        RemoveBannedSources(player)
        state.nativeSecondary = player.GetActiveItem and (player:GetActiveItem(SLOT_SECONDARY) or 0) or 0
        state.protectedCounts = {}
        for _, itemId in ipairs(PROTECTED_COLLECTIBLES) do
            state.protectedCounts[tostring(itemId)] = GetCollectibleCount(player, itemId)
        end
        DropHeldTrinkets(player)
        EnsureSlotTrinket(player)
        RequestCaches(player)
        ClampResources(player)
        ClampHealth(player)
        EnforceCurrentFloorCurses()
        ScanCurrentRoomEnemies()
        Save()
        DebugLog("run contract activated for player " .. GetPlayerKey(player))
        return true
    end

    local function ForceCurses(curses)
        return (tonumber(curses) or 0) | REQUIRED_CURSES
    end

    EnforceCurrentFloorCurses = function()
        if not AnyPlayerActive() then return false end
        local game = Game and Game()
        local level = game and game.GetLevel and game:GetLevel()
        if not level or not level.AddCurse then return false end
        local current = level.GetCurses and level:GetCurses() or 0
        local missing = REQUIRED_CURSES & (~current)
        if missing ~= 0 then level:AddCurse(missing, false); return true end
        return false
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

    local function AddSecondaryCharge(player, state)
        local itemId = tonumber(state.nativeSecondary) or 0
        if itemId <= 0 or not player.GetActiveItem or player:GetActiveItem(SLOT_SECONDARY) ~= itemId then return false end
        if not player.GetActiveCharge or not player.SetActiveCharge then return false end
        local config = GetCollectibleConfig(itemId)
        local maxCharge = config and tonumber(config.MaxCharges) or 0
        local current = player:GetActiveCharge(SLOT_SECONDARY) or 0
        if maxCharge > 0 and current >= maxCharge then return false end
        player:SetActiveCharge(maxCharge > 0 and math.min(maxCharge, current + 1) or current + 1, SLOT_SECONDARY)
        return true
    end

    local function ReconcilePlayer(player)
        if not player then return false end
        ConfirmNativeActiveDrop(player)
        local state = GetPlayerState(player, true)
        local primary = player.GetActiveItem and player:GetActiveItem(SLOT_PRIMARY) or 0
        if not state.active and (primary == ITEM_ID or HasCollectible(player, ITEM_ID)) then ActivatePlayer(player) end
        state = GetPlayerState(player, true)
        if not state.active then return false end

        local changed = EnsureRingInPrimary(player, state)
        if EnsureNativeSecondary(player, state) then changed = true end
        if RemoveBannedSources(player) then changed = true end
        if DropHeldTrinkets(player) then changed = true end
        if EnsureSlotTrinket(player) then changed = true end
        if ProtectCompatibleCollectibles(player, state) then changed = true end
        if ClampResources(player) then changed = true end
        if ClampHealth(player) then changed = true end
        if player.CanFly then player.CanFly = false end
        if changed then Save() end
        return changed
    end

    local function OnUseItem(_, itemId)
        if itemId ~= ITEM_ID then return nil end
        return { Discharge = false, Remove = false, ShowAnim = false }
    end

    local function OnEvaluateCache(_, player, cacheFlag)
        if not IsPlayerActive(player) then return end
        if cacheFlag == ((CacheFlag and CacheFlag.CACHE_DAMAGE) or 1) then
            player.Damage = player.Damage * 0.75
        elseif cacheFlag == ((CacheFlag and CacheFlag.CACHE_FIREDELAY) or 2) then
            player.MaxFireDelay = (player.MaxFireDelay + 1) / 0.75 - 1
        elseif cacheFlag == ((CacheFlag and CacheFlag.CACHE_SHOTSPEED) or 4) then
            player.ShotSpeed = player.ShotSpeed * 1.25
        elseif cacheFlag == ((CacheFlag and CacheFlag.CACHE_LUCK) or 1024) then
            player.Luck = player.Luck - 5
        elseif cacheFlag == ((CacheFlag and CacheFlag.CACHE_FLYING) or 128) then
            player.CanFly = false
        end
    end

    local function OnPostPEffectUpdate(_, player)
        ReconcilePlayer(player)
        SettleTradeCandidates()
        local frame = GetFrameCount()
        if frame ~= runtime.lastCurseCheckFrame and frame % 10 == 0 then
            runtime.lastCurseCheckFrame = frame
            EnforceCurrentFloorCurses()
        end
    end

    local function OnPostNewRoom()
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        runtime.roomVisit = runtime.roomVisit + 1
        local roomKey = GetRoomKey()
        local changed = false
        for _, player in ipairs(GetPlayers()) do
            local state = GetPlayerState(player, false)
            if state and state.active and state.lastRoomKey ~= roomKey then
                state.lastRoomKey = roomKey
                state.roomProgress = state.roomProgress + 1
                if state.roomProgress >= ROOM_CHARGE_INTERVAL then
                    state.roomProgress = state.roomProgress - ROOM_CHARGE_INTERVAL
                    AddSecondaryCharge(player, state)
                end
                changed = true
            end
            ReconcilePlayer(player)
        end
        ScanCurrentRoomEnemies()
        EnforceCurrentFloorCurses()
        if changed then Save() end
    end

    local function OnPostNewLevel()
        EnforceCurrentFloorCurses()
        ScanCurrentRoomEnemies()
    end

    local function SpawnStartingPedestal()
        local state = GetSavedState()
        if state.startingPedestalSpawned then return false end
        local config = ITEM_ID > 0 and GetCollectibleConfig(ITEM_ID) or nil
        if not config or config.Type ~= ITEM_ACTIVE or not Isaac or not Isaac.Spawn then
            DebugLog("starting pedestal skipped: ring registration is unavailable")
            return false
        end
        local game = Game and Game()
        local room = game and game.GetRoom and game:GetRoom()
        if not room or not room.GetCenterPos or not room.FindFreePickupSpawnPosition or not Vector then
            DebugLog("starting pedestal skipped: starting room is unavailable")
            return false
        end

        -- Keep the pedestal away from the central player spawn and let the room
        -- resolve walls, pits, and existing pickups. This is one shared reward.
        local ok, pickup = pcall(function()
            local center = room:GetCenterPos()
            local position = room:FindFreePickupSpawnPosition(Vector(center.X, center.Y - 40), 40, true, false)
            if not position then return nil end
            local entity = Isaac.Spawn(ENTITY_PICKUP, PICKUP_COLLECTIBLE, ITEM_ID, position, Vector.Zero, nil)
            return entity and entity.ToPickup and entity:ToPickup() or nil
        end)
        if not ok or not pickup or pickup.Variant ~= PICKUP_COLLECTIBLE or pickup.SubType ~= ITEM_ID then
            DebugLog("starting pedestal failed: " .. tostring(ok and "no valid ring pickup returned" or pickup))
            return false
        end
        state.startingPedestalSpawned = true
        return true
    end

    local function OnPostGameStarted(_, isContinue)
        runtime.damageRewrite = {}
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        runtime.spawningCompensation = false
        runtime.rerollDepth = 0
        runtime.lastCurseCheckFrame = -1
        runtime.roomVisit = 0
        if not isContinue then
            local root = GetSaveRoot()
            root.ringOfSevenCurses = { runSeed = GetRunSeed(), players = {}, startingPedestalSpawned = false }
            -- A false continue flag is a new run even if its seed is reused.
            -- Neither room/level callbacks nor continue may issue this reward.
            SpawnStartingPedestal()
            Save()
        else
            GetSavedState()
        end
        for _, player in ipairs(GetPlayers()) do ReconcilePlayer(player) end
        EnforceCurrentFloorCurses()
        ScanCurrentRoomEnemies()
    end

    local function OnPreGameExit()
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        Save()
    end

    local function OnPostCurseEval(_, curses)
        if not AnyPlayerActive() then return nil end
        return ForceCurses(curses)
    end

    local function OnPostNpcInit(_, npc)
        DoubleNpcHealth(npc)
    end

    local function OnEntityTakeDamage(_, entity, amount, flags, source, countdown)
        local player = entity and entity.ToPlayer and entity:ToPlayer() or nil
        if not player or not IsPlayerActive(player) or (tonumber(amount) or 0) <= 0 then return nil end
        local key = GetPlayerKey(player)
        if runtime.damageRewrite[key] then return nil end
        runtime.damageRewrite[key] = true
        local ok, err = pcall(player.TakeDamage, player, amount * 2, flags, source, countdown)
        runtime.damageRewrite[key] = nil
        if not ok then DebugLog("failed to rewrite incoming damage: " .. tostring(err)); return nil end
        return false
    end

    local function OnPostGetCollectible(_, selected, poolType, decrease, seed)
        -- Do not substitute pool results: the original forbidden item must be
        -- visible. Compensation is settled by the actual pedestal, not a draw.
        return nil
    end

    local function OnPostPickupUpdate(_, pickup)
        CompensateForbiddenPedestal(pickup)
    end

    local function OnPostTrinketUpdate(_, pickup)
        if SLOT_TRINKET_ID <= 0 or not AnyPlayerActive() or not pickup
            or pickup.Variant ~= PICKUP_TRINKET or pickup.SubType ~= SLOT_TRINKET_ID then return end
        if pickup.Remove then pickup:Remove() end
    end

    local function OnPrePickupCollision(_, pickup, collider)
        local player = collider and collider.ToPlayer and collider:ToPlayer() or nil
        if not player then return nil end
        if not IsPlayerActive(player) then
            if pickup.Variant == PICKUP_COLLECTIBLE and pickup.SubType == ITEM_ID
                and (pickup.Wait or 0) <= 0 and player.GetActiveItem then
                local previous = player:GetActiveItem(SLOT_PRIMARY)
                if previous and previous > 0 and previous ~= ITEM_ID then
                    runtime.pendingRingPickups[GetPlayerKey(player)] = {
                        pickup = pickup, player = player, itemId = previous,
                        roomKey = GetRoomKey(), frame = GetFrameCount(),
                    }
                end
            end
            return nil
        end
        if pickup.Variant == PICKUP_TRINKET then return true end
        if pickup.Variant ~= PICKUP_COLLECTIBLE then return nil end
        local data = pickup.GetData and pickup:GetData() or nil
        if IsForbiddenCollectible(pickup.SubType) then return true end
        -- Morph/rerolls may keep GetData(). A previous failed Q4 attempt must
        -- never make the now-legal item permanently uncollectible.
        if data then data.NeverbirthSevenCursesBlocked = nil end
        local config = GetCollectibleConfig(pickup.SubType)
        if config and config.Type == ITEM_ACTIVE then return true end
        RegisterTradeCandidate(pickup, player)
        return nil
    end

    if Neverbirth and Neverbirth.AddCallback and ITEM_ID > 0 then
        if ModCallbacks.MC_USE_ITEM then Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, OnUseItem, ITEM_ID) end
        if ModCallbacks.MC_EVALUATE_CACHE then Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, OnEvaluateCache) end
        if ModCallbacks.MC_POST_PEFFECT_UPDATE then Neverbirth:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, OnPostPEffectUpdate) end
        if ModCallbacks.MC_POST_NEW_ROOM then Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, OnPostNewRoom) end
        if ModCallbacks.MC_POST_NEW_LEVEL then Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, OnPostNewLevel) end
        if ModCallbacks.MC_POST_GAME_STARTED then Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, OnPostGameStarted) end
        if ModCallbacks.MC_PRE_GAME_EXIT then Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, OnPreGameExit) end
        if ModCallbacks.MC_POST_CURSE_EVAL then Neverbirth:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, OnPostCurseEval) end
        if ModCallbacks.MC_POST_NPC_INIT then Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, OnPostNpcInit) end
        if ModCallbacks.MC_ENTITY_TAKE_DMG then Neverbirth:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, OnEntityTakeDamage, ENTITY_PLAYER) end
        if ModCallbacks.MC_POST_GET_COLLECTIBLE then Neverbirth:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, OnPostGetCollectible) end
        if ModCallbacks.MC_POST_PICKUP_UPDATE then Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, OnPostPickupUpdate, PICKUP_COLLECTIBLE) end
        if ModCallbacks.MC_POST_PICKUP_UPDATE then Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, OnPostTrinketUpdate, PICKUP_TRINKET) end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, OnPrePickupCollision) end
    end

    Neverbirth.RingOfSevenCursesTestAPI = {
        ItemId = ITEM_ID,
        TrinketId = SLOT_TRINKET_ID,
        RequiredCurses = REQUIRED_CURSES,
        ActivatePlayer = ActivatePlayer,
        GetPlayerState = function(player) return GetPlayerState(player, false) end,
        GetSavedState = GetSavedState,
        GetCoinCap = GetCoinCap,
        ClampResources = ClampResources,
        GetTotalHealthCapacity = GetTotalHealthCapacity,
        ClampHealth = ClampHealth,
        IsForbiddenCollectible = IsForbiddenCollectible,
        ForceCurses = ForceCurses,
        DoubleNpcHealth = DoubleNpcHealth,
        RerollForbiddenSelection = RerollForbiddenSelection,
        ReplaceForbiddenPedestal = CompensateForbiddenPedestal,
        RegisterTradeCandidate = RegisterTradeCandidate,
        SettleTradeCandidates = SettleTradeCandidates,
        ReconcilePlayer = ReconcilePlayer,
        Callbacks = {
            UseItem = OnUseItem,
            EvaluateCache = OnEvaluateCache,
            PostPEffectUpdate = OnPostPEffectUpdate,
            PostNewRoom = OnPostNewRoom,
            PostNewLevel = OnPostNewLevel,
            PostGameStarted = OnPostGameStarted,
            PostCurseEval = OnPostCurseEval,
            PostNpcInit = OnPostNpcInit,
            EntityTakeDamage = OnEntityTakeDamage,
            PostGetCollectible = OnPostGetCollectible,
            PostPickupUpdate = OnPostPickupUpdate,
            PostTrinketUpdate = OnPostTrinketUpdate,
            PrePickupCollision = OnPrePickupCollision,
        },
        ResetForTest = function()
            local root = GetSaveRoot()
            root.ringOfSevenCurses = { runSeed = GetRunSeed(), players = {} }
            runtime.damageRewrite = {}
            runtime.pendingTrades = {}
            runtime.pendingRingPickups = {}
            runtime.spawningCompensation = false
            runtime.rerollDepth = 0
            runtime.lastCurseCheckFrame = -1
            runtime.roomVisit = 0
        end,
    }
end
