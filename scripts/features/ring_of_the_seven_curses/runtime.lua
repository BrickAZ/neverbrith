-- Private runtime ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local ITEM_ID = deps.State.ITEM_ID
    local SLOT_TRINKET_ID = deps.State.SLOT_TRINKET_ID
    local ROOM_CHARGE_INTERVAL = deps.State.ROOM_CHARGE_INTERVAL
    local SLOT_PRIMARY = deps.State.SLOT_PRIMARY
    local PICKUP_COLLECTIBLE = deps.State.PICKUP_COLLECTIBLE
    local PICKUP_TRINKET = deps.State.PICKUP_TRINKET
    local PICKUP_BED = deps.State.PICKUP_BED
    local MOMS_BED_SUBTYPE = deps.State.MOMS_BED_SUBTYPE
    local ENTITY_PICKUP = deps.State.ENTITY_PICKUP
    local ENTITY_PLAYER = deps.State.ENTITY_PLAYER
    local ITEM_ACTIVE = deps.State.ITEM_ACTIVE
    local runtime = deps.State.runtime
    local DebugLog = deps.State.DebugLog
    local Save = deps.State.Save
    local GetRunSeed = deps.State.GetRunSeed
    local GetSaveRoot = deps.State.GetSaveRoot
    local GetSavedState = deps.State.GetSavedState
    local GetPlayerKey = deps.State.GetPlayerKey
    local GetPlayerState = deps.State.GetPlayerState
    local GetPlayers = deps.State.GetPlayers
    local IsPlayerActive = deps.State.IsPlayerActive
    local AnyPlayerActive = deps.State.AnyPlayerActive
    local GetRoomKey = deps.State.GetRoomKey
    local GetFrameCount = deps.State.GetFrameCount
    local GetCollectibleConfig = deps.Inventory.GetCollectibleConfig
    local HasCollectible = deps.Inventory.HasCollectible
    local DropHeldTrinkets = deps.Inventory.DropHeldTrinkets
    local EnsureSlotTrinket = deps.Inventory.EnsureSlotTrinket
    local RemoveBannedSources = deps.Inventory.RemoveBannedSources
    local ProtectCompatibleCollectibles = deps.Inventory.ProtectCompatibleCollectibles
    local EnsureRingInPrimary = deps.Inventory.EnsureRingInPrimary
    local EnsureNativeSecondary = deps.Inventory.EnsureNativeSecondary
    local ClampHealth = deps.Inventory.ClampHealth
    local ClampResources = deps.Inventory.ClampResources
    local AddSecondaryCharge = deps.Inventory.AddSecondaryCharge
    local DoubleNpcHealth = deps.World.DoubleNpcHealth
    local ScanCurrentRoomEnemies = deps.World.ScanCurrentRoomEnemies
    local ForceCurses = deps.World.ForceCurses
    local EnforceCurrentFloorCurses = deps.World.EnforceCurrentFloorCurses
    local ActivatePlayer = deps.World.ActivatePlayer
    local ConfirmNativeActiveDrop = deps.Rewards.ConfirmNativeActiveDrop
    local IsForbiddenCollectible = deps.Rewards.IsForbiddenCollectible
    local CompensateForbiddenPedestal = deps.Rewards.CompensateForbiddenPedestal
    local RegisterTradeCandidate = deps.Rewards.RegisterTradeCandidate
    local SettleTradeCandidates = deps.Rewards.SettleTradeCandidates

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
    function callbackInstallers.OnUseItem()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, OnUseItem, ITEM_ID)
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
    function callbackInstallers.OnEvaluateCache()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, OnEvaluateCache)
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
    function callbackInstallers.OnPostPEffectUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, OnPostPEffectUpdate)
    end

    local function RemoveExpiredRingPickup(pickup)
        if not pickup or pickup.Type ~= ENTITY_PICKUP or pickup.Variant ~= PICKUP_COLLECTIBLE
            or pickup.SubType ~= ITEM_ID or not GetSavedState().startingPedestalExpired then return false end
        pickup:Remove()
        return true
    end

    local function UpdateStartingPedestalAvailability()
        local state = GetSavedState()
        if state.startingPedestalSpawned and not state.startingPedestalRoomKey
            and not state.startingPedestalExpired then
            -- Older saves have no offer history. Only a verified first visit
            -- to the first floor's starting room can still retain the offer.
            local game = Game and Game()
            local level = game and game.GetLevel and game:GetLevel()
            local desc = level and level.GetCurrentRoomDesc and level:GetCurrentRoomDesc()
            local firstVisit = level and level.GetStage and level:GetStage() == 1
                and level.GetCurrentRoomIndex and level.GetStartingRoomIndex
                and level:GetCurrentRoomIndex() == level:GetStartingRoomIndex()
                and (not level.GetDimension or level:GetDimension() == 0)
                and desc and desc.VisitedCount == 1
            if firstVisit then
                state.startingPedestalRoomKey = GetRoomKey()
            else
                state.startingPedestalExpired = true
            end
            Save()
        end
        if state.startingPedestalRoomKey and not state.startingPedestalExpired
            and state.startingPedestalRoomKey ~= GetRoomKey() then
            -- The first departure closes this run's offer permanently, even
            -- when the starting room's saved entities are restored later.
            state.startingPedestalExpired = true
            Save()
        end
        if state.startingPedestalExpired and Isaac and Isaac.GetRoomEntities then
            for _, entity in ipairs(Isaac.GetRoomEntities()) do
                RemoveExpiredRingPickup(entity)
            end
        end
    end

    local function OnPostNewRoom()
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        runtime.roomVisit = runtime.roomVisit + 1
        UpdateStartingPedestalAvailability()
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
    function callbackInstallers.OnPostNewRoom()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, OnPostNewRoom)
    end

    local function OnPostNewLevel()
        EnforceCurrentFloorCurses()
        ScanCurrentRoomEnemies()
    end
    function callbackInstallers.OnPostNewLevel()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, OnPostNewLevel)
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
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        runtime.spawningCompensation = false
        runtime.rerollDepth = 0
        runtime.lastCurseCheckFrame = -1
        runtime.roomVisit = 0
        if not isContinue then
            local root = GetSaveRoot()
            root.ringOfSevenCurses = {
                runSeed = GetRunSeed(), players = {}, startingPedestalSpawned = false,
                startingPedestalRoomKey = GetRoomKey(), startingPedestalExpired = false,
            }
            -- A false continue flag is a new run even if its seed is reused.
            -- Neither room/level callbacks nor continue may issue this reward.
            SpawnStartingPedestal()
            Save()
        else
            UpdateStartingPedestalAvailability()
        end
        for _, player in ipairs(GetPlayers()) do ReconcilePlayer(player) end
        EnforceCurrentFloorCurses()
        ScanCurrentRoomEnemies()
    end
    function callbackInstallers.OnPostGameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, OnPostGameStarted)
    end

    local function OnPreGameExit()
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        Save()
    end
    function callbackInstallers.OnPreGameExit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, OnPreGameExit)
    end

    local function OnPostCurseEval(_, curses)
        if not AnyPlayerActive() then return nil end
        return ForceCurses(curses)
    end
    function callbackInstallers.OnPostCurseEval()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_CURSE_EVAL, OnPostCurseEval)
    end

    local function OnPostNpcInit(_, npc)
        DoubleNpcHealth(npc)
    end
    function callbackInstallers.OnPostNpcInit()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_INIT, OnPostNpcInit)
    end

    local function OnEntityTakeDamage(_, entity, amount, flags, source, countdown)
        local player = entity and entity.ToPlayer and entity:ToPlayer() or nil
        if not player or not IsPlayerActive(player) or (tonumber(amount) or 0) <= 0 then return nil end
        return { Damage = amount * 2 }
    end
    function callbackInstallers.OnEntityTakeDamage()
        return Neverbirth:AddPriorityCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, CallbackPriority.EARLY, OnEntityTakeDamage, ENTITY_PLAYER)
    end

    local function OnPostGetCollectible(_, selected, poolType, decrease, seed)
        -- Do not substitute pool results: the original forbidden item must be
        -- visible. Compensation is settled by the actual pedestal, not a draw.
        return nil
    end
    function callbackInstallers.OnPostGetCollectible()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GET_COLLECTIBLE, OnPostGetCollectible)
    end

    local function OnPostPickupUpdate(_, pickup)
        if RemoveExpiredRingPickup(pickup) then return end
        CompensateForbiddenPedestal(pickup)
    end
    function callbackInstallers.OnPostPickupUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, OnPostPickupUpdate, PICKUP_COLLECTIBLE)
    end

    local function OnPostTrinketUpdate(_, pickup)
        if SLOT_TRINKET_ID <= 0 or not AnyPlayerActive() or not pickup
            or pickup.Variant ~= PICKUP_TRINKET or pickup.SubType ~= SLOT_TRINKET_ID then return end
        if pickup.Remove then pickup:Remove() end
    end
    function callbackInstallers.OnPostTrinketUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, OnPostTrinketUpdate, PICKUP_TRINKET)
    end

    local function OnPreBedCollision(_, pickup, collider)
        if not pickup or pickup.Variant ~= PICKUP_BED or pickup.SubType == MOMS_BED_SUBTYPE then return nil end
        local player = collider and collider.ToPlayer and collider:ToPlayer() or nil
        if not IsPlayerActive(player) then return nil end
        -- Both clean and dirty Isaac beds use the same pickup variant.
        -- false keeps the physical collision but skips the native sleep code.
        return false
    end
    function callbackInstallers.OnPreBedCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, OnPreBedCollision, PICKUP_BED)
    end

    local function OnPrePickupCollision(_, pickup, collider)
        if RemoveExpiredRingPickup(pickup) then return true end
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
    function callbackInstallers.OnPrePickupCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, OnPrePickupCollision)
    end

    return {
        ReconcilePlayer = ReconcilePlayer,
        OnUseItem = OnUseItem,
        OnEvaluateCache = OnEvaluateCache,
        OnPostPEffectUpdate = OnPostPEffectUpdate,
        RemoveExpiredRingPickup = RemoveExpiredRingPickup,
        UpdateStartingPedestalAvailability = UpdateStartingPedestalAvailability,
        OnPostNewRoom = OnPostNewRoom,
        OnPostNewLevel = OnPostNewLevel,
        SpawnStartingPedestal = SpawnStartingPedestal,
        OnPostGameStarted = OnPostGameStarted,
        OnPreGameExit = OnPreGameExit,
        OnPostCurseEval = OnPostCurseEval,
        OnPostNpcInit = OnPostNpcInit,
        OnEntityTakeDamage = OnEntityTakeDamage,
        OnPostGetCollectible = OnPostGetCollectible,
        OnPostPickupUpdate = OnPostPickupUpdate,
        OnPostTrinketUpdate = OnPostTrinketUpdate,
        OnPreBedCollision = OnPreBedCollision,
        OnPrePickupCollision = OnPrePickupCollision,
        Installers = callbackInstallers,
    }
end
