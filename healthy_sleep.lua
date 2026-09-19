-- Repentance 1.7.9b / REPENTOGON 1.0.12a adapter. No custom bed or ANM2.
-- Native collision chooses bed.Target. Transfer only that bed's pending effect;
-- vanilla red full-heal bypasses AddHearts. See reports/healthy-sleep/2026-09-18-runtime-repair.md.
return function(mod, context)
    if not context.ItemId or context.ItemId <= 0 then return end
    local required = { 'MC_POST_PICKUP_COLLISION', 'MC_PRE_PLAYER_UPDATE',
        'MC_PRE_ITEM_OVERLAY_SHOW', 'MC_POST_ITEM_OVERLAY_SHOW', 'MC_POST_ITEM_OVERLAY_UPDATE' }
    for _, name in ipairs(required) do
        if not ModCallbacks[name] then
            if context.DebugLog then context.DebugLog('[健康睡眠] 缺少原版睡眠接入能力，已停止此道具初始化。') end
            return
        end
    end
    if not ItemOverlay or not ItemOverlay.GetSprite or not ItemOverlay.GetOverlayID then return end

    local TOTAL, HOLD_FRAMES = 28800, 15
    local actions, actionSet = {}, {}
    for _, name in ipairs({ 'ACTION_LEFT', 'ACTION_RIGHT', 'ACTION_UP', 'ACTION_DOWN',
        'ACTION_SHOOTLEFT', 'ACTION_SHOOTRIGHT', 'ACTION_SHOOTUP', 'ACTION_SHOOTDOWN',
        'ACTION_BOMB', 'ACTION_ITEM', 'ACTION_PILLCARD', 'ACTION_DROP' }) do
        local id = ButtonAction[name]
        if id ~= nil and not actionSet[id] then actions[#actions+1], actionSet[id] = id, true end
    end
    local ready, sampling = false, false
    local candidate, lastTime, lastFrame, held, saveAt = nil, nil, nil, {}, 0
    local completedUntil = nil
    local ownedOverlay, overlayColor = false, nil

    local function restoreOverlayColor()
        if overlayColor and ItemOverlay.GetOverlayID() == Giantbook.SLEEP then
            ItemOverlay.GetSprite().Color = overlayColor
        end
        overlayColor = nil
    end

    local function save() context.Save() end
    local function playerKey(player) return tostring(player.InitSeed) end
    local function floorKey()
        local level = Game():GetLevel()
        return table.concat({ level:GetStage(), level:GetStageType(), level:GetDungeonPlacementSeed() }, ':')
    end
    local function data()
        local root, run = context.GetSaveRoot(), context.GetCurrentRunSeed()
        if type(root.healthySleep) ~= 'table' or root.healthySleep.run ~= run then
            root.healthySleep = { version=1, run=run }
        end
        return root.healthySleep
    end
    local function currentFloor()
        local d = data()
        if type(d.floor) ~= 'table' or d.floor.key ~= floorKey() then return nil end
        return d.floor
    end
    local function bedRecord()
        local floor = currentFloor()
        return floor and floor.bed
    end
    local function sleepState()
        local bed = bedRecord()
        return bed and bed.sleep
    end
    local function hasOwner()
        for _, p in ipairs(context.GetPlayers()) do
            if p:HasCollectible(context.ItemId) then return true end
        end
        return false
    end
    local function inOrigin()
        local floor, level = currentFloor(), Game():GetLevel()
        return floor and level:GetDimension() == 0 and level:GetCurrentRoomIndex() == floor.room
    end
    local function isOwned(pickup)
        local bed = bedRecord()
        return pickup and pickup.Variant == PickupVariant.PICKUP_BED and pickup.SubType == 0
            and bed and bed.seed == pickup.InitSeed and inOrigin()
    end
    local function clearRuntime()
        restoreOverlayColor()
        ownedOverlay = false
        candidate, lastTime, lastFrame, held = nil, nil, nil, {}
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
            completedUntil = nil
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

    local function overlayActive()
        return ItemOverlay.GetOverlayID() == Giantbook.SLEEP and ItemOverlay.GetSprite():IsPlaying('Idle')
    end
    local function beforeCollision(_, pickup, collider)
        if not ready or not isOwned(pickup) then return end
        local bed = bedRecord()
        if bed.phase == 'cancelled' or bed.phase == 'settled' or bed.sleep then
            return true -- this owned bed has already been consumed
        end
        if collider and collider:ToPlayer() then
            candidate = { pickup=pickup, seed=pickup.InitSeed, player=playerKey(collider:ToPlayer()) }
        end
        -- nil is intentional: native eligibility, contact and sleep all run.
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
        ownedOverlay = true
        lastTime, lastFrame, held = Isaac.GetTime(), nil, {}
        save()
    end
    local function beforeOverlayShow()
        -- Restore before any new overlay loads into this shared engine Sprite.
        restoreOverlayColor()
        ownedOverlay = false
    end
    local function afterOverlayShow(_, id)
        if not ready or id ~= Giantbook.SLEEP or not candidate then return end
        -- Show is called synchronously inside native bed collision, after Target.
        if candidate.pickup and candidate.seed == candidate.pickup.InitSeed then
            beginNativeSleep(candidate.pickup)
        end
    end
    local function afterCollision(_, pickup, collider)
        local player = collider and collider:ToPlayer()
        if not candidate or not player or candidate.player ~= playerKey(player)
            or candidate.seed ~= pickup.InitSeed then return end
        candidate = nil
    end
    local function clockPaused()
        local game = Game()
        return game:IsPauseMenuOpen() or (game:IsPaused() and not (ownedOverlay and overlayActive()))
    end

    local function sleeper(player)
        if not ready or not player or not inOrigin() then return nil end
        local bed, sleep = bedRecord(), sleepState()
        if not bed or bed.phase ~= 'sleeping' or not sleep or sleep.settled then return nil end
        if player:IsDead() then return nil end
        return sleep.recipients[playerKey(player)]
    end
    local function beforePlayerUpdate(_, player)
        local recipient = sleeper(player)
        if not recipient then return end
        player.Velocity = Vector.Zero
        player.Position = Vector(recipient.position.x, recipient.position.y)
        player:GetSprite():SetFrame(recipient.animation, recipient.frame)
        return true -- skip native player AI only for the native-selected sleepers
    end
    local function inputAction(_, entity, hook, action)
        if sampling or not actionSet[action] or not entity then return end
        local player = entity:ToPlayer()
        if not sleeper(player) then return end
        if hook == InputHook.GET_ACTION_VALUE then return 0 end
        if hook == InputHook.IS_ACTION_PRESSED or hook == InputHook.IS_ACTION_TRIGGERED then return false end
    end
    local function sampleActions(sleep, collecting)
        local matureByPlayer = {}
        sampling = true
        for _, p in ipairs(context.GetPlayers()) do
            local key = playerKey(p)
            if (collecting or sleep.recipients[key]) and not p:IsDead() then
                held[key] = held[key] or {}
                matureByPlayer[key] = {}
                for _, action in ipairs(actions) do
                    -- Engine logical action API merges keyboard/controller/multiple bindings.
                    local down = Input.IsActionPressed(action, p.ControllerIndex)
                    held[key][action] = down and ((held[key][action] or 0) + 1) or 0
                    if held[key][action] >= HOLD_FRAMES then matureByPlayer[key][tostring(action)] = true end
                end
            end
        end
        sampling = false
        return matureByPlayer
    end
    local function multiplier(matureByPlayer, recipients)
        local mature = {}
        for key, values in pairs(matureByPlayer) do
            if recipients[key] then
                for action in pairs(values) do mature[action] = true end
            end
        end
        local n = 0
        for _ in pairs(mature) do n=n+1 end
        return 1 + 3599 * math.sqrt(n)
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
        if ownedOverlay and overlayActive() then ItemOverlay.GetSprite():SetLastFrame() end
        clearRuntime()
        completedUntil = Isaac.GetTime() + 1500
        save()
    end
    local function update()
        if not ready then return end
        if ownedOverlay and not overlayActive() and ItemOverlay.GetDelay() <= 0 then
            restoreOverlayColor()
            ownedOverlay = false
        end
        syncFloor()
        if not hasOwner() then cancel(); return end
        if bedRecord() and bedRecord().phase == 'cancelled' then cancel();return end
        spawnBed()
        local bed, sleep = bedRecord(), sleepState()
        if not sleep or sleep.settled then return end
        if not inOrigin() then cancel(); return end
        if clockPaused() then lastTime=nil; return end
        -- Game:GetFrameCount can stand still during a giantbook; the global
        -- counter also deduplicates POST_UPDATE and ITEM_OVERLAY_UPDATE.
        local frame, now = Isaac.GetFrameCount(), Isaac.GetTime()
        if frame == lastFrame then return end
        lastFrame = frame
        local elapsed = lastTime and math.max(0, (now-lastTime)/1000) or 0
        lastTime = now
        if bed.phase ~= 'sleeping' then return end
        local alive = false
        for _, p in ipairs(context.GetPlayers()) do
            if sleep.recipients[playerKey(p)] and not p:IsDead() then alive=true;break end
        end
        if not alive then cancel();return end
        sleep.multiplier = multiplier(sampleActions(sleep, false), sleep.recipients)
        sleep.elapsed = math.min(TOTAL, sleep.elapsed + elapsed * sleep.multiplier)
        if sleep.elapsed >= TOTAL then settle(sleep)
        elseif now >= saveAt then saveAt=now+1000; save() end
    end
    local function render()
        if not ready then return end
        local sleep = sleepState()
        if not sleep then return end
        local game = Game()
        -- Render observes pause to discard the interval even when updates stop.
        -- It does not advance progress or grant gameplay rewards.
        if clockPaused() then lastTime=nil end
        if not inOrigin() or bedRecord().phase == 'cancelled' then return end
        if sleep.settled and (not completedUntil or Isaac.GetTime() > completedUntil) then return end
        local nativeMovie = ownedOverlay and overlayActive()
        if nativeMovie then
            -- In this build vanilla draws ItemOverlay AFTER MC_POST_RENDER.
            -- Draw the same native sprite here, then make only its later copy
            -- transparent. This puts our clock above it without an ANM2 edit.
            local sprite = ItemOverlay.GetSprite()
            overlayColor = overlayColor or sprite.Color
            sprite.Color = overlayColor
            sprite:Render(Vector(Isaac.GetScreenWidth()/2, Isaac.GetScreenHeight()/2), Vector.Zero, Vector.Zero)
            local c = overlayColor
            sprite.Color = Color(c.R,c.G,c.B,0,c.RO,c.GO,c.BO)
        end
        local hud = game:GetHUD()
        if hud and not hud:IsVisible() and not nativeMovie then return end
        local minutes = math.min(480, math.floor((sleep.elapsed or 0)/60))
        local clock = string.format('%02d:%02d / 08:00', math.floor(minutes/60), minutes%60)
        local x, y = Isaac.GetScreenWidth()/2-47, Isaac.GetScreenHeight()-46
        mod:RenderRuntimeText('', clock, x+1, y+1, 0,0,0,0.85)
        mod:RenderRuntimeText('', clock, x, y, 0.75,0.85,1,1)
    end
    local function gameStarted(_, continued)
        clearRuntime()
        completedUntil = nil
        ready = true
        if not continued then context.GetSaveRoot().healthySleep={version=1,run=context.GetCurrentRunSeed()} end
        syncFloor()
        local bed, sleep = bedRecord(), sleepState()
        if sleep then
            local value = tonumber(sleep.elapsed)
            if not value or value ~= value or value < 0 or value > TOTAL
                or type(sleep.recipients) ~= 'table' then cancel();return end
            for _, recipient in pairs(sleep.recipients) do
                if type(recipient) ~= 'table' or type(recipient.position) ~= 'table'
                    or type(recipient.position.x) ~= 'number' or type(recipient.position.y) ~= 'number'
                    or type(recipient.animation) ~= 'string' or type(recipient.frame) ~= 'number' then
                    cancel();return
                end
            end
            if sleep.nativeSamples ~= nil then
                if type(sleep.nativeSamples) ~= 'table' then cancel();return end
                for _, sample in ipairs(sleep.nativeSamples) do
                    if type(sample) ~= 'table' or type(sample.seconds) ~= 'number'
                        or sample.seconds < 0 or type(sample.mature) ~= 'table' then cancel();return end
                    for _, values in pairs(sample.mature) do
                        if type(values) ~= 'table' then cancel();return end
                    end
                end
            end
        end
        if sleep and not sleep.settled then
            if not next(sleep.recipients) then cancel();return end
            bed.phase = 'sleeping'
            sleep.nativeSamples, sleep.captureClosed, sleep.overlayPlayer = nil, nil, nil
            -- The movie is not replayed on continue; the earned sleep remains.
            for _, pickup in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_BED, 0, false, false)) do
                if isOwned(pickup) then pickup.Target=nil end
            end
        end
    end
    local function newRoom()
        clearRuntime()
        if not ready then return end
        syncFloor()
        local bed = bedRecord()
        if bed and not inOrigin() and bed.sleep and not bed.sleep.settled then cancel() end
    end
    local function newLevel() if ready then syncFloor() end end
    local function exitGame()
        if ready then save() end
        ready = false
        clearRuntime()
    end
    local function gameEnded()
        if ready then context.GetSaveRoot().healthySleep=nil;save() end
        ready=false;clearRuntime()
    end
    local function unload(_, unloadingMod) if unloadingMod == mod then exitGame() end end
    mod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, gameStarted)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, newRoom)
    mod:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, newLevel)
    mod:AddCallback(ModCallbacks.MC_POST_UPDATE, update)
    mod:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, exitGame)
    mod:AddCallback(ModCallbacks.MC_POST_GAME_END, gameEnded)
    mod:AddCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, unload)
    mod:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, beforeCollision, PickupVariant.PICKUP_BED)
    mod:AddCallback(ModCallbacks.MC_POST_PICKUP_COLLISION, afterCollision, PickupVariant.PICKUP_BED)
    mod:AddCallback(ModCallbacks.MC_PRE_ITEM_OVERLAY_SHOW, beforeOverlayShow)
    mod:AddCallback(ModCallbacks.MC_POST_ITEM_OVERLAY_SHOW, afterOverlayShow, Giantbook.SLEEP)
    mod:AddCallback(ModCallbacks.MC_POST_ITEM_OVERLAY_UPDATE, update)
    mod:AddCallback(ModCallbacks.MC_PRE_PLAYER_UPDATE, beforePlayerUpdate)
    mod:AddCallback(ModCallbacks.MC_INPUT_ACTION, inputAction)
    mod:AddCallback(ModCallbacks.MC_POST_RENDER, render)
end
