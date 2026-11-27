-- Owns reward choices and confirmed acquisitions; visuals only report completion.
return function(dependencies)
    -- Native bindings are declared here; the entry chooses their installation phase.
    local callbackInstallers = {}
    local state, presentation = assert(dependencies.Runtime), assert(dependencies.Presentation)
    local unboxing, addHeat = dependencies.Unboxing, dependencies.AddHeat
    local GetPlayers, IsValidItemId = dependencies.GetPlayers, dependencies.IsValidItemId
    local copyPosition, dataOf, entityKey = dependencies.CopyPosition, dependencies.DataOf, dependencies.EntityKey
    local playerKey, roomKey, log = dependencies.PlayerKey, dependencies.RoomKey, dependencies.Log
    local trafficAnm2 = dependencies.Animations
    local rules = assert(dependencies.Rules)
    local isRunning = dependencies.IsRunning or function() return true end
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local UNBOXING, EXPOSURE, HEAT = dependencies.Items.TrafficUnboxing, dependencies.Items.TrafficExposure, dependencies.Items.TrafficHeat
    state.trafficInventorySeen = state.trafficInventorySeen or {}
    local function resetFloor()
        state.trafficPedestals, state.choiceGroups, state.nextChoiceId = {}, {}, 1
        state.trafficAcquisitions = {}
    end
    local function spawnPedestal(itemId, position)
        if not IsValidItemId(itemId) then return nil end
        local pickup = Isaac.Spawn(PICKUP_ENTITY, COLLECTIBLE_PICKUP, itemId, position, Vector(0, 0), nil)
        log("reward item=" .. itemId .. " spawned=" .. tostring(pickup ~= nil))
        return pickup
    end

    local function removeEntity(entity)
        if entity and entity.Remove then pcall(function() entity:Remove() end) end
    end

    local function choiceGroup(a, b, left, right)
        local id = state.nextChoiceId; state.nextChoiceId = id + 1
        state.choiceGroups[id] = { pickups = { a, b }, resolved = false }
        for _, pickup in ipairs({ a, b }) do local data = dataOf(pickup); if data then data.NeverbirthTrafficChoiceGroup = id end end
        presentation.CreateChoiceLink(id, left, right)
    end

    local function spawnBossReward(tier)
        local room = Game():GetRoom(); if not room then return {} end
        local center = room.GetCenterPos and room:GetCenterPos() or Vector(320, 280)
        local items = rules.GetRewardItemsForTier(tier)
        if #items == 1 then return { spawnPedestal(items[1], center) } end
        if #items == 2 then
            local left, right = center + Vector(-40, 0), center + Vector(40, 0)
            local a, b = spawnPedestal(items[1], left), spawnPedestal(items[2], right)
            if a and b then choiceGroup(a, b, left, right) end
            return { a, b }
        end
        return {}
    end

    local function resolveChoice(pickup)
        local data = dataOf(pickup); local id = data and data.NeverbirthTrafficChoiceGroup
        if not id then return true end
        local group = state.choiceGroups[id]; if not group then return true end
        local key = entityKey(pickup)
        if group.resolved then if group.chosen ~= key then removeEntity(pickup); return false end; return true end
        group.resolved = true; group.chosen = key
        for _, other in ipairs(group.pickups) do if entityKey(other) ~= key then removeEntity(other) end end
        presentation.RemoveChoiceLink(id)
        return true
    end

    local function removeCollectible(player, itemId)
        if not player or not player.RemoveCollectible then return end
        for _, attempt in ipairs({
            function() player:RemoveCollectible(itemId, false, 0, true) end,
            function() player:RemoveCollectible(itemId, false, 0) end,
            function() player:RemoveCollectible(itemId, false) end,
            function() player:RemoveCollectible(itemId) end,
        }) do if pcall(attempt) then return end end
    end

    local function visual(itemId, position, chest)
        if presentation.QueuePickup(itemId, position, chest) then unboxing.Grant(position) end
    end

    local exposure = include("scripts.features.traffic_exposure")({ ItemId = EXPOSURE, SpawnPedestal = spawnPedestal, IsValidItemId = IsValidItemId }).Grant
    local function trackTrafficPickup(_, pickup)
        if not isRunning() then return nil end
        local itemId = pickup and tonumber(pickup.SubType) or 0
        if not pickup or pickup.Variant ~= COLLECTIBLE_PICKUP or not trafficAnm2[itemId] then return nil end
        local key = entityKey(pickup)
        local data = dataOf(pickup)
        state.trafficPedestals[key] = {
            pickup = pickup,
            pickupKey = key,
            itemId = itemId,
            position = copyPosition(pickup.Position),
            roomKey = roomKey(),
            choiceGroup = data and data.NeverbirthTrafficChoiceGroup or nil,
        }
        return nil
    end
    function callbackInstallers.InstallTrackPickup(Neverbirth, COLLECTIBLE_PICKUP)
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, trackTrafficPickup, COLLECTIBLE_PICKUP)
    end

    local function resolveTrackedChoice(source)
        local id = source and source.choiceGroup or nil
        if not id then return true end
        local group = state.choiceGroups[id]
        if not group then return true end
        if group.settled or (group.resolved and group.chosen ~= source.pickupKey) then return false end
        group.resolved = true
        group.settled = true
        group.chosen = source.pickupKey
        for _, other in ipairs(group.pickups or {}) do
            if not source or entityKey(other) ~= source.pickupKey then removeEntity(other) end
        end
        presentation.RemoveChoiceLink(id)
        return true
    end

    local boundAcquisitions
    local function bindAcquisitions(service)
        assert(not boundAcquisitions, 'traffic acquisition subscription already installed')
        boundAcquisitions = service
        service.SubscribeAcquisition(function(player, itemId, _, physical, _, receipt)
            if not isRunning() then return end
            if not trafficAnm2[itemId] then return end
            local source
            if physical and receipt and receipt.candidate then
                source = state.trafficPedestals[entityKey(receipt.candidate.pickup)]
                if source and (source.itemId ~= itemId or source.roomKey ~= roomKey()) then source = nil end
            end
            local key = playerKey(player)
            local playerReceipts = state.trafficAcquisitions[key] or {}
            state.trafficAcquisitions[key] = playerReceipts
            local copies = playerReceipts[itemId] or {}
            playerReceipts[itemId] = copies
            -- Keep nonphysical receipts too: same-ID script grants must not borrow
            -- the provenance of a physical copy still in the pickup animation.
            copies[#copies + 1] = { source = source, accepted = resolveTrackedChoice(source) }
        end)
    end

    local function applyTrafficInventoryReward(player, itemId, receipt)
        local source = receipt and receipt.source
        log("reward collected item=" .. itemId .. " player=" .. playerKey(player))
        local position = source and source.position or copyPosition(player and player.Position)
        removeCollectible(player, itemId)
        if receipt and not receipt.accepted then return end
        visual(itemId, position, itemId == UNBOXING)
        if itemId == EXPOSURE then exposure(position) elseif itemId == HEAT then addHeat(player) end
    end

    local trafficInventoryItems = { UNBOXING, EXPOSURE, HEAT }

    local function processTrafficPlayer(player)
        if not player or not player.GetCollectibleNum then return end
        local key = playerKey(player)
        local seen = state.trafficInventorySeen[key]
        if type(seen) ~= "table" then seen = {}; state.trafficInventorySeen[key] = seen end
        for _, itemId in ipairs(trafficInventoryItems) do
            if IsValidItemId(itemId) then
                local current = math.max(0, math.floor(tonumber(player:GetCollectibleNum(itemId)) or 0))
                local previous = math.max(0, math.floor(tonumber(seen[itemId]) or 0))
                if current < previous then previous = current end
                local added = current - previous
                local receipts = state.trafficAcquisitions[key]
                local copies = receipts and receipts[itemId] or {}
                -- Removed acquisitions cannot leave provenance for a later grant.
                local offset = math.max(0, #copies - added)
                for index = 1, added do
                    local receipt = copies[offset + index]
                    applyTrafficInventoryReward(player, itemId, receipt)
                end
                if receipts then receipts[itemId] = nil end
                seen[itemId] = math.max(0, math.floor(tonumber(player:GetCollectibleNum(itemId)) or 0))
            end
        end
        state.trafficAcquisitions[key] = nil
    end

    local function processTrafficInventory()
        for _, player in ipairs(GetPlayers()) do processTrafficPlayer(player) end
    end
    local function processVisuals()
        presentation.AdvancePickups(function(value) if value.chest then unboxing.Grant(value.position) end end)
    end

    return { ResetFloor = resetFloor, ResetRun = function() state.trafficInventorySeen = {}; state.trafficAcquisitions = {} end,
        BindAcquisitions = bindAcquisitions,
        SpawnBossReward = spawnBossReward, ResolveChoice = resolveChoice, TrackPickup = trackTrafficPickup,
        ProcessInventory = processTrafficInventory, ProcessPlayer = processTrafficPlayer,
        QueuePickupVisual = visual, ProcessPickupVisuals = processVisuals, ResolveExposure = exposure,
        InstallTrackPickup = callbackInstallers.InstallTrackPickup,
    }
end
