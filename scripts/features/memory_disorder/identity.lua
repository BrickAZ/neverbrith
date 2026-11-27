-- Ordered identity switching, best-effort recovery, item ownership and room transition timing.
return function(Neverbirth, context, deps)
    local installers = {}
    local diagnosticOnce = deps.diagnosticOnce
    local safeCall = deps.safeCall
    local numberCall = deps.numberCall
    local playerKey = deps.playerKey
    local runtimePlayerKey = deps.runtimePlayerKey
    local playerIsDead = deps.playerIsDead
    local getPlayerType = deps.getPlayerType
    local getCollectibleCount = deps.getCollectibleCount
    local pairMain = deps.pairMain
    local pairPartner = deps.pairPartner
    local hasItem = deps.hasItem
    local randomIndex = deps.randomIndex
    local profileForType = deps.profileForType
    local buildAllCandidates = deps.buildAllCandidates
    local readHealth = deps.readHealth
    local healthMode = deps.healthMode
    local healthAmount = deps.healthAmount
    local applyHealth = deps.applyHealth
    local captureHealthLedger = deps.captureHealthLedger
    local updatePermanentSlots = deps.updatePermanentSlots
    local reconcileTemporaryCopies = deps.reconcileTemporaryCopies
    local removeTemporaryComponents = deps.removeTemporaryComponents
    local recordTemporaryCopy = deps.recordTemporaryCopy
    local addProfileComponents = deps.addProfileComponents
    local ensureSavedState = deps.ensureSavedState
    local save = deps.save
    local makeState = deps.makeState
    local persistState = deps.persistState
    local iconIsEligible = deps.iconIsEligible
    local chooseIcon = deps.chooseIcon
    local snapshotPartner = deps.snapshotPartner
    local canSwitchPair = deps.canSwitchPair
    local parkPartner = deps.parkPartner
    local removeFormerPartner = deps.removeFormerPartner
    local ensureNativePair = deps.ensureNativePair
    local restorePartner = deps.restorePartner
    local VANILLA_PROFILES = deps.VANILLA_PROFILES
    local profilesById = deps.profilesById
    local ITEM_ID = deps.ITEM_ID
    local TRANSITION_SWITCH_FRAME = deps.TRANSITION_SWITCH_FRAME
    local TRANSITION_END_FRAME = deps.TRANSITION_END_FRAME
    local MAX_DARKNESS = deps.MAX_DARKNESS
    local runtime = deps.runtime

    local function resolveIdentitySwitch(player, profile, losingItem)
        player = pairMain(player)
        local state = runtime.states[runtimePlayerKey(player)]
        if not state or not profile or playerIsDead(player) then return false end
        if not canSwitchPair(player, profile.playerType) then return false end
        local previousType = getPlayerType(player)
        if previousType == 20 or previousType == 40 or previousType == 17 then
            diagnosticOnce("orphan-body", "Identity switch skipped: secondary body has no valid main player")
            return false
        end
        local prior = previousType ~= profile.playerType and snapshotPartner(player) or nil

        captureHealthLedger(player, state)
        if healthAmount(state.healthLedger) <= 0 then
            if healthMode(player, state.currentProfile or profileForType(previousType)) == "lost" then
                state.healthLedger.soulHearts = math.max(1, numberCall(player, "GetSoulHearts"))
            else
                return false -- Never turn an actual zero-health/death state into a heal.
            end
        end
        local previousProfile = state.currentProfile
        if state.currentProfile and type(state.currentProfile.onRemove) == "function" then
            local ok, errorMessage = pcall(state.currentProfile.onRemove, player, state, context)
            if not ok then diagnosticOnce("profile-remove-" .. tostring(state.currentProfile.id), "profile " .. tostring(state.currentProfile.id) .. " remove failed: " .. tostring(errorMessage)) end
        end
        removeTemporaryComponents(player, state)

        local beforeById = {}
        for _, candidate in ipairs(VANILLA_PROFILES) do
            for _, itemId in ipairs(candidate.collectibles or {}) do beforeById[itemId] = getCollectibleCount(player, itemId) end
            for _, active in ipairs(candidate.actives or {}) do beforeById[active.id] = getCollectibleCount(player, active.id) end
        end

        if losingItem and prior then
            prior.snapshot.collectibles[tostring(ITEM_ID)] = 0
            state.pairSnapshots[tostring(prior.mainType)] = prior.snapshot
        else
            parkPartner(player, state, prior)
        end
        local function rollback(reason)
            local failedPartner = getPlayerType(player) ~= previousType and snapshotPartner(player) or nil
            removeTemporaryComponents(player, state)
            if getPlayerType(player) ~= previousType then safeCall(player, "ChangePlayerType", previousType) end
            local cleaned = removeFormerPartner(player, failedPartner)
            if getPlayerType(player) == previousType and cleaned and ensureNativePair(player) then
                state.healthProjection = applyHealth(player, state.healthLedger, profileForType(previousType))
                state.projectedSoulTail = 0
                restorePartner(player, state, losingItem)
                state.appliedHealth = readHealth(player)
                if previousProfile then addProfileComponents(player, state, previousProfile) end
            end
            persistState(state)
            save()
            diagnosticOnce(reason, "Identity switch failed; original identity state retained for recovery: " .. reason)
            return false
        end
        local changed = previousType == profile.playerType and pairPartner(player) ~= nil
        if not changed then
            local _, ok = safeCall(player, "ChangePlayerType", profile.playerType)
            changed = ok and getPlayerType(player) == profile.playerType
        end
        if not changed then
            return rollback("change-player-type")
        end
        if not removeFormerPartner(player, prior) then
            return rollback("pair-remove-failed")
        end
        if not ensureNativePair(player) then return rollback("pair-create-failed") end

        -- If the engine automatically injected any known starting component,
        -- record it as temporary before filling missing profile components.
        for itemId, before in pairs(beforeById) do
            local after = getCollectibleCount(player, itemId)
            if after > before then recordTemporaryCopy(state, itemId, before, after) end
        end

        local projection = applyHealth(player, state.healthLedger, profile)
        if projection ~= "lost" and healthAmount(readHealth(player)) <= 0 then
            return rollback("health-restore-failed")
        end
        state.currentProfile = profile
        state.currentProfileId = profile.id
        state.switchSerial = state.switchSerial + 1
        state.healthProjection = projection
        state.projectedSoulTail = 0
        restorePartner(player, state, losingItem)
        state.appliedHealth = readHealth(player)
        if not losingItem then
            addProfileComponents(player, state, profile)
            chooseIcon(player)
        end

        if profile.highRisk then
            diagnosticOnce("high-risk-" .. profile.id,
                "profile " .. profile.id .. " uses real PlayerType but requires in-game verification for " .. profile.highRisk)
        end
        persistState(state)
        save()
        return true
    end

    local function restoreOriginalIdentity(player, state)
        if not resolveIdentitySwitch(player, profileForType(state.originalType), true) then return false end
        local saved = ensureSavedState()
        saved.players[state.key] = nil
        runtime.states[runtimePlayerKey(player)] = nil
        save()
        return true
    end

    local function onOwnershipUpdate(player)
        if not player then return false end
        player = pairMain(player)
        local key = runtimePlayerKey(player)
        local state = runtime.states[key]
        if state then state.player = player end
        local held = hasItem(player)
        if held and not state then
            local saved = ensureSavedState()
            local savedPlayer = saved.players[playerKey(player)]
            state = makeState(player, savedPlayer and savedPlayer.active and savedPlayer or nil)
            runtime.states[key] = state
            if not savedPlayer or not iconIsEligible(state.currentIconId) then chooseIcon(player) end
            saved.memoryDisorderVoidUnlockedThisRun = true
            persistState(state)
            save()
            return true
        elseif not held and state then
            return restoreOriginalIdentity(player, state)
        elseif held and state then
            reconcileTemporaryCopies(player, state)
            updatePermanentSlots(player, state)
        end
        return false
    end
    function installers.onOwnershipUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player) onOwnershipUpdate(player) end)
    end

    local function chooseProfile(player, state)
        local candidates = buildAllCandidates(player)
        if #candidates == 0 then return profilesById.isaac end
        local salt = "identity:" .. runtime.roomSerial .. ":" .. state.switchSerial
        return candidates[randomIndex(#candidates, player, salt)]
    end

    local function transitionDarkness(frame)
        frame = tonumber(frame) or 0
        if frame <= 0 or frame >= 29 then return 0 end
        if frame >= 14 and frame <= 15 then return MAX_DARKNESS end
        if frame < 14 then return MAX_DARKNESS * (frame / 14) end
        return MAX_DARKNESS * ((29 - frame) / 13)
    end

    local function beginRoomTransitions(roomKey)
        runtime.roomSerial = runtime.roomSerial + 1
        for _, state in pairs(runtime.states) do
            local player = state.player
            if hasItem(player) then
                state.transition = {
                    frame = 0,
                    switched = false,
                    roomKey = roomKey,
                }
                state.armedForNextRoom = false
                persistState(state)
            end
        end
        return true
    end

    local function advanceFrame()
        local maximumDarkness = 0
        for _, state in pairs(runtime.states) do
            local player = state.player
            if state.transition then
                state.transition.frame = state.transition.frame + 1
                local frame = state.transition.frame
                maximumDarkness = math.max(maximumDarkness, transitionDarkness(frame))
                if frame == TRANSITION_SWITCH_FRAME and not state.transition.switched then
                    state.transition.switched = true
                    resolveIdentitySwitch(player, chooseProfile(player, state))
                end
                if frame >= TRANSITION_END_FRAME then state.transition = nil end
            end
        end
        if context.Darken then context.Darken(maximumDarkness) end
        return maximumDarkness
    end

    return {
        resolveIdentitySwitch = resolveIdentitySwitch,
        onOwnershipUpdate = onOwnershipUpdate,
        transitionDarkness = transitionDarkness,
        beginRoomTransitions = beginRoomTransitions,
        advanceFrame = advanceFrame,
        Installers = installers,
    }
end
