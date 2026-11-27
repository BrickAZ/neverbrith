-- Shared acquisition ledger and health grants. Item rules and combat belong to individual features.
return function(Neverbirth, dependencies)
    -- Keep native bindings beside handlers; invoke at their original installation phase.
    local callbackInstallers = {}
    local Store = assert(dependencies.Store)
    local GetPlayers = assert(dependencies.GetPlayers)
    local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
    local IsValidItemId = assert(dependencies.IsValidItemId)
    local DebugLog = dependencies.Log
    local ITEM_DEFS = assert(dependencies.Definitions)
    local ITEM_BY_ID = {}
    for _, def in ipairs(ITEM_DEFS) do
        if IsValidItemId(def.itemId) then
            ITEM_BY_ID[def.itemId] = def
        end
    end

    local CACHE_DAMAGE = (CacheFlag and CacheFlag.CACHE_DAMAGE) or 1
    local CACHE_SPEED = (CacheFlag and CacheFlag.CACHE_SPEED) or 8
    local CACHE_FIREDELAY = (CacheFlag and CacheFlag.CACHE_FIREDELAY) or 16
    local CACHE_RANGE = (CacheFlag and CacheFlag.CACHE_RANGE) or 64
    local CACHE_LUCK = (CacheFlag and CacheFlag.CACHE_LUCK) or 1024
    local PLAYER_ENTITY = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local RECONCILE_INTERVAL = 15
    local PICKUP_SETTLE_FRAMES = 2
    local runtime = {
        frame = 0,
        pending = {},
        incompatibleHealthLogged = {},
    }
    local running, disposed = true, false

    local function playerKey(player)
        return tostring(player and player.InitSeed or "")
    end

    local itemCount = dependencies.Stats.Count
    local function resetRunData()
        local data = {
            runSeed = GetCurrentRunSeed(),
            players = {},
        }
        Store.Replace(data)
        Store.Save()
        return data
    end

    local function runData()
        local data = Store.Get()
        if type(data) ~= "table" or tostring(data.runSeed or "") ~= tostring(GetCurrentRunSeed() or "") then
            return resetRunData()
        end
        if type(data.players) ~= "table" then data.players = {} end
        return data
    end

    local function playerRecord(player, create)
        local key = playerKey(player)
        if key == "" then return nil end
        local data = runData()
        local record = data.players[key]
        if type(record) ~= "table" and create then
            record = { counts = {} }
            data.players[key] = record
        end
        if type(record) == "table" and type(record.counts) ~= "table" then record.counts = {} end
        return record
    end

    local function getProcessedCount(player, itemId)
        local record = playerRecord(player, false)
        if not record then return 0 end
        return math.max(0, math.floor(tonumber(record.counts[tostring(itemId)] or record.counts[itemId]) or 0))
    end

    local function setProcessedCount(player, itemId, count)
        local record = playerRecord(player, true)
        if not record then return false end
        record.counts[tostring(itemId)] = math.max(0, math.floor(tonumber(count) or 0))
        return true
    end

    local addTears = dependencies.Stats.AddTears
    local function grantPickupBenefits(player, def, copies)
        copies = math.max(0, math.floor(tonumber(copies) or 0))
        if not player or not def or copies <= 0 then return false end

        local beforeMax = player.GetMaxHearts and (tonumber(player:GetMaxHearts()) or 0) or 0
        if player.AddMaxHearts then
            pcall(function() player:AddMaxHearts(2 * copies, true) end)
        end
        local afterMax = player.GetMaxHearts and (tonumber(player:GetMaxHearts()) or beforeMax) or beforeMax
        if afterMax > beforeMax and player.AddHearts then
            -- AddHearts clamps at the new maximum, so this fills all red hearts without
            -- changing soul-only/coin/other custom health models when AddMaxHearts refuses.
            pcall(function() player:AddHearts(afterMax) end)
        elseif afterMax <= beforeMax then
            local key = playerKey(player)
            if key ~= "" and not runtime.incompatibleHealthLogged[key] then
                runtime.incompatibleHealthLogged[key] = true
                DebugLog("[neverbirth] Dog food red-heart container skipped for incompatible player " .. key)
            end
        end

        if def.soulHeartHalfUnits and player.AddSoulHearts then
            pcall(function() player:AddSoulHearts(def.soulHeartHalfUnits * copies) end)
        end
        return true
    end

    local function reconcilePlayerItem(player, def)
        local current = itemCount(player, def.itemId)
        local processed = getProcessedCount(player, def.itemId)
        if current > processed then
            grantPickupBenefits(player, def, current - processed)
            setProcessedCount(player, def.itemId, current)
            return true
        elseif current < processed then
            -- Losing/rerolling a copy lowers the baseline, so a later genuine reacquisition
            -- receives its one-time pickup reward exactly once again.
            setProcessedCount(player, def.itemId, current)
            return true
        end
        return false
    end

    local function hasPendingPlayerItem(player, itemId)
        local key = playerKey(player)
        for _, pending in pairs(runtime.pending) do
            if pending.playerKey == key and pending.itemId == itemId then return true end
        end
        return false
    end

    local function pickupKey(pickup)
        if pickup and pickup.InitSeed ~= nil then return "seed:" .. tostring(pickup.InitSeed) end
        return tostring(pickup)
    end

    local function trackPickupCollision(_, pickup, collider)
        if not running or disposed then return nil end
        if not pickup or pickup.Type ~= PICKUP_ENTITY or pickup.Variant ~= COLLECTIBLE_PICKUP then return nil end
        local def = ITEM_BY_ID[tonumber(pickup.SubType) or 0]
        if not def then return nil end
        local player = collider and collider.ToPlayer and collider:ToPlayer() or nil
        if not player then return nil end
        local key = playerKey(player) .. "|" .. pickupKey(pickup)
        if not runtime.pending[key] then
            runtime.pending[key] = {
                player = player,
                playerKey = playerKey(player),
                itemId = def.itemId,
                beforeCount = itemCount(player, def.itemId),
                due = runtime.frame + PICKUP_SETTLE_FRAMES,
            }
        end
        return nil
    end
    function callbackInstallers.trackPickupCollision()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, trackPickupCollision, COLLECTIBLE_PICKUP)
    end

    local function processPending()
        local changed = false
        for key, pending in pairs(runtime.pending) do
            if runtime.frame >= (pending.due or 0) then
                local player = pending.player
                local def = ITEM_BY_ID[pending.itemId]
                if player and def then
                    local current = itemCount(player, pending.itemId)
                    local processed = getProcessedCount(player, pending.itemId)
                    local baseline = math.max(processed, tonumber(pending.beforeCount) or 0)
                    if current > baseline then
                        grantPickupBenefits(player, def, current - baseline)
                        setProcessedCount(player, pending.itemId, current)
                        changed = true
                    elseif current < processed then
                        setProcessedCount(player, pending.itemId, current)
                        changed = true
                    end
                end
                runtime.pending[key] = nil
            end
        end
        return changed
    end

    local function reconcileInventory()
        local changed = false
        for _, player in ipairs(GetPlayers()) do
            for _, def in ipairs(ITEM_DEFS) do
                if IsValidItemId(def.itemId) and not hasPendingPlayerItem(player, def.itemId) then
                    changed = reconcilePlayerItem(player, def) or changed
                end
            end
        end
        return changed
    end

    local function update()
        if not running or disposed then return nil end
        runtime.frame = runtime.frame + 1
        local changed = processPending()
        if runtime.frame % RECONCILE_INTERVAL == 0 then
            changed = reconcileInventory() or changed
        end
        if changed then Store.Save() end
        return nil
    end
    function callbackInstallers.update()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    end

    local function evaluate(_, player, cacheFlag)
        if not player then return nil end
        for _, def in ipairs(ITEM_DEFS) do if def.Evaluate then def.Evaluate(player, cacheFlag) end end
        return nil
    end
    function callbackInstallers.evaluate()
        return Neverbirth:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, evaluate)
    end

    local combat = dependencies.Combat.CreateCombat(Neverbirth, { ItemCount = itemCount, PlayerKey = playerKey, GetFrame = function() return runtime.frame end })
    local markDentalTear, dentalCollision = combat.MarkTear, combat.Collision
    local eligibleDentalTarget, applyDentalPush = combat.EligibleTarget, combat.ApplyPush

    local function initializeContinuedPlayers()
        local changed = false
        for _, player in ipairs(GetPlayers()) do
            if not playerRecord(player, false) then
                for _, def in ipairs(ITEM_DEFS) do
                    if IsValidItemId(def.itemId) then setProcessedCount(player, def.itemId, itemCount(player, def.itemId)) end
                end
                changed = true
            end
        end
        if changed then Store.Save() end
    end

    local function gameStarted(_, isContinued)
        if disposed then return end
        running = true
        runtime.frame = 0
        runtime.pending = {}
        runtime.incompatibleHealthLogged = {}
        if isContinued then
            runData()
            initializeContinuedPlayers()
        else
            resetRunData()
        end
        return nil
    end
    function callbackInstallers.gameStarted()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    end

    local function exit()
        running = false
        runtime.pending = {}
        runtime.incompatibleHealthLogged = {}
    end
    function callbackInstallers.exit()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, exit)
    end

    local function unload(_, unloaded)
        if unloaded ~= nil and unloaded ~= Neverbirth then return end
        exit()
        disposed = true
    end
    function callbackInstallers.unload()
        return Neverbirth:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, unload)
    end

    local function resetTransient()
        runtime.pending = {}
        return nil
    end
    function callbackInstallers.resetTransient()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, resetTransient)
    end
    function callbackInstallers.resetTransient2()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, resetTransient)
    end

    Neverbirth.DogFoodSeriesTestAPI = {
        ItemDefs = ITEM_DEFS,
        ItemById = ITEM_BY_ID,
        Runtime = runtime,
        AddTears = addTears,
        GrantPickupBenefits = grantPickupBenefits,
        ReconcilePlayerItem = reconcilePlayerItem,
        GetProcessedCount = getProcessedCount,
        EligibleDentalTarget = eligibleDentalTarget,
        ApplyDentalPush = applyDentalPush,
        Callbacks = {
            Evaluate = evaluate,
            TrackPickupCollision = trackPickupCollision,
            Update = update,
            MarkDentalTear = markDentalTear,
            DentalCollision = dentalCollision,
            GameStarted = gameStarted,
        },
    }

    callbackInstallers.evaluate()
    callbackInstallers.update()
    if ModCallbacks.MC_PRE_PICKUP_COLLISION then
        callbackInstallers.trackPickupCollision()
    end
    combat.InstallCallbacks()
    if ModCallbacks.MC_POST_NEW_ROOM then
        callbackInstallers.resetTransient()
    end
    if ModCallbacks.MC_POST_NEW_LEVEL then
        callbackInstallers.resetTransient2()
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        callbackInstallers.gameStarted()
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then callbackInstallers.exit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then callbackInstallers.unload() end

    return { Evaluate = evaluate }
end
