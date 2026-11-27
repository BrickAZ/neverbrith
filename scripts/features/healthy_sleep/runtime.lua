-- Bed creation, native collision handoff, elapsed time and once-only settlement.
return function(mod, context, State, Presentation, Input, TOTAL)
    local callbackInstallers = {}
    local runtime = State.runtime
    local save = State.save
    local playerKey = State.playerKey
    local floorKey = State.floorKey
    local data = State.data
    local currentFloor = State.currentFloor
    local bedRecord = State.bedRecord
    local sleepState = State.sleepState
    local hasOwner = State.hasOwner
    local inOrigin = State.inOrigin
    local isOwned = State.isOwned
    local restoreOverlayColor = Presentation.restoreOverlayColor
    local overlayActive = Presentation.overlayActive
    local clockPaused = Presentation.clockPaused
    local sampleActions = Input.sampleActions
    local multiplier = Input.multiplier
    local function clearRuntime()
        restoreOverlayColor()
        runtime.ownedOverlay = false
        runtime.candidate, runtime.lastTime, runtime.lastFrame, runtime.held = nil, nil, nil, {}
    end
    local function cancel()
        local bed = bedRecord()
        if not bed or bed.phase == 'settled' then return end
        local changed = bed.phase ~= 'cancelled'
        bed.phase, bed.sleep = 'cancelled', nil
        clearRuntime()
        if inOrigin() then
            for _, entity in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BED, 0, false, false)) do
                if isOwned(entity) then entity:Remove() end
            end
        end
        if changed then save() end -- keep generated=true after loss / cancellation
    end
    local function syncFloor()
        local d, key = data(), floorKey()
        if type(d.floor) ~= 'table' or d.floor.key ~= key then
            clearRuntime()
            runtime.completedUntil = nil
            d.floor = { key=key, room=Game():GetLevel():GetStartingRoomIndex(), generated=false }
            save()
        end
    end
    local function spawnBed()
        local floor = currentFloor()
        if floor.generated or not inOrigin() or not hasOwner() then return end
        local room = Game():GetRoom()
        local pos = room:FindFreePickupSpawnPosition(room:GetCenterPos(), 0, true)
        -- Commit the latch before Spawn: re-entrant callbacks cannot create bed #2.
        floor.generated = true
        floor.bed = { phase='spawning', id=floor.key .. ':bed:1' }
        save()
        local entity = Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BED, 0, pos, Vector.Zero, nil)
        local bed = entity and entity:ToPickup()
        if bed then
            floor.bed.seed, floor.bed.phase = bed.InitSeed, 'available'
            bed:GetData().NeverbirthHealthySleep = floor.bed.id
        else
            floor.bed.phase = 'cancelled'
        end
        save()
    end

    local function beforeCollision(_, pickup, collider)
        if not runtime.ready or not isOwned(pickup) then return end
        local bed = bedRecord()
        if bed.phase == 'cancelled' or bed.phase == 'settled' or bed.sleep then
            return true -- this owned bed has already been consumed
        end
        if collider and collider:ToPlayer() then
            runtime.candidate = { pickup=pickup, seed=pickup.InitSeed, player=playerKey(collider:ToPlayer()) }
        end
        -- nil is intentional: native eligibility, contact and sleep all run.
    end
    function callbackInstallers.beforeCollision()
        return mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, beforeCollision, PickupVariant.PICKUP_BED)
    end
    local function beginNativeSleep(pickup)
        if not isOwned(pickup) or bedRecord().sleep then return end
        local player = pickup.Target and pickup.Target:ToPlayer()
        if not player then return end
        local bed = bedRecord()
        local sprite = player:GetSprite()
        bed.phase = 'sleeping'
        bed.sleep = { id=bed.id .. ':sleep:1', elapsed=0, multiplier=1, settled=false,
            recipients={ [playerKey(player)]={ position={x=player.Position.X,y=player.Position.Y},
                animation=sprite:GetAnimation(), frame=sprite:GetFrame(), rewarded=false } } }
        -- 1.7.9b SleepFillHP iterates bed.Target: RED calls direct full-heal,
        -- SOUL calls AddSoulHearts. Clearing only our pending target defers BOTH.
        -- Touched was set by native collision and remains set (one-use semantics).
        pickup.Target = nil
        runtime.ownedOverlay = true
        runtime.lastTime, runtime.lastFrame, runtime.held = Isaac.GetTime(), nil, {}
        save()
    end
    local function beforeOverlayShow()
        -- Restore before any new overlay loads into this shared engine Sprite.
        restoreOverlayColor()
        runtime.ownedOverlay = false
    end
    function callbackInstallers.beforeOverlayShow()
        return mod:AddCallback(ModCallbacks.MC_PRE_ITEM_OVERLAY_SHOW, beforeOverlayShow)
    end
    local function afterOverlayShow(_, id)
        if not runtime.ready or id ~= Giantbook.SLEEP or not runtime.candidate then return end
        -- Show is called synchronously inside native bed collision, after Target.
        if runtime.candidate.pickup and runtime.candidate.seed == runtime.candidate.pickup.InitSeed then
            beginNativeSleep(runtime.candidate.pickup)
        end
    end
    function callbackInstallers.afterOverlayShow()
        return mod:AddCallback(ModCallbacks.MC_POST_ITEM_OVERLAY_SHOW, afterOverlayShow, Giantbook.SLEEP)
    end
    local function afterCollision(_, pickup, collider)
        local player = collider and collider:ToPlayer()
        if not runtime.candidate or not player or runtime.candidate.player ~= playerKey(player)
            or runtime.candidate.seed ~= pickup.InitSeed then return end
        runtime.candidate = nil
    end
    function callbackInstallers.afterCollision()
        return mod:AddCallback(ModCallbacks.MC_POST_PICKUP_COLLISION, afterCollision, PickupVariant.PICKUP_BED)
    end
    local function settle(sleep)
        -- No re-entry or same-frame duplicate can grant either half twice.
        if sleep.settled then return end
        sleep.settled = true
        bedRecord().phase = 'settled'
        for _, p in ipairs(context.GetPlayers()) do
            local recipient = sleep.recipients[playerKey(p)]
            if recipient and not recipient.rewarded and not p:IsDead() then
                recipient.rewarded = true
                p:AddHearts(math.max(0, p:GetEffectiveMaxHearts() - p:GetHearts()))
                p:AddSoulHearts(6)
            end
        end
        -- A high multiplier can finish before the fixed native movie. Its pending
        -- effect is already detached, so finishing the movie cannot grant again.
        if runtime.ownedOverlay and overlayActive() then ItemOverlay.GetSprite():SetLastFrame() end
        clearRuntime()
        runtime.completedUntil = Isaac.GetTime() + 1500
        save()
    end
    local function update()
        if not runtime.ready then return end
        if runtime.ownedOverlay and not overlayActive() and ItemOverlay.GetDelay() <= 0 then
            restoreOverlayColor()
            runtime.ownedOverlay = false
        end
        syncFloor()
        if not hasOwner() then cancel(); return end
        if bedRecord() and bedRecord().phase == 'cancelled' then cancel();return end
        spawnBed()
        local bed, sleep = bedRecord(), sleepState()
        if not sleep or sleep.settled then return end
        if not inOrigin() then cancel(); return end
        if clockPaused() then runtime.lastTime=nil; return end
        -- Game:GetFrameCount can stand still during a giantbook; the global
        -- counter also deduplicates POST_UPDATE and ITEM_OVERLAY_UPDATE.
        local frame, now = Isaac.GetFrameCount(), Isaac.GetTime()
        if frame == runtime.lastFrame then return end
        runtime.lastFrame = frame
        local elapsed = runtime.lastTime and math.max(0, (now-runtime.lastTime)/1000) or 0
        runtime.lastTime = now
        if bed.phase ~= 'sleeping' then return end
        local alive = false
        for _, p in ipairs(context.GetPlayers()) do
            if sleep.recipients[playerKey(p)] and not p:IsDead() then alive=true;break end
        end
        if not alive then cancel();return end
        sleep.multiplier = multiplier(sampleActions(sleep, false), sleep.recipients)
        sleep.elapsed = math.min(TOTAL, sleep.elapsed + elapsed * sleep.multiplier)
        if sleep.elapsed >= TOTAL then settle(sleep)
        elseif now >= runtime.saveAt then runtime.saveAt=now+1000; save() end
    end
    function callbackInstallers.update()
        return mod:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    end
    function callbackInstallers.update2()
        return mod:AddCallback(ModCallbacks.MC_POST_ITEM_OVERLAY_UPDATE, update)
    end
    return { Installers=callbackInstallers, clearRuntime=clearRuntime, cancel=cancel, syncFloor=syncFloor }
end
