-- Private input responsibility for the Big Dog family.
return function(Neverbirth, deps)
    local callbackInstallers = {}
    local context = deps.Context
    local BIG_DOG_BARK_ID = deps.BIG_DOG_BARK_ID
    local DOG_VARIANT = deps.DOG_VARIANT
    local Constants = deps.Constants
    local runtime = deps.State.Runtime
    local Rod = deps.Rod
    local newVector = deps.Queries.newVector
    local vectorLengthSquared = deps.Queries.vectorLengthSquared
    local copyVector = deps.Queries.copyVector
    local entityExists = deps.Queries.entityExists
    local entityKey = deps.Queries.entityKey
    local playerIsDead = deps.Queries.playerIsDead
    local hasBigDogActive = deps.Queries.hasBigDogActive
    local getChargeFrames = deps.Rules.getChargeFrames
    local resolveDirection = deps.Rules.resolveDirection
    local isBusy = deps.Rules.isBusy
    local getPlayerRuntime = deps.State.getPlayerRuntime
    local findPlayerByKey = deps.State.findPlayerByKey
    local useWindPill = deps.State.useWindPill
    local clearChargeSoundSchedule = deps.Audio.clearChargeSoundSchedule
    local beginChargeSoundSchedule = deps.Audio.beginChargeSoundSchedule
    local updateChargeSoundSchedule = deps.Audio.updateChargeSoundSchedule
    local removeEntity = deps.Effects.removeEntity
    local setEntityVisualScale = deps.Effects.setEntityVisualScale
    local playDirectionalAnimation = deps.Effects.playDirectionalAnimation
    local markEffectCollisionFree = deps.Effects.markEffectCollisionFree
    local ensureDog = deps.Effects.ensureDog
    local updateFollowPosition = deps.Effects.updateFollowPosition
    local clearPlayerTransient = deps.Lifecycle.clearPlayerTransient
    local launch = deps.Dash.launch
    local updateDash = deps.Dash.updateDash
    local updateChew = deps.Chew.updateChew
    local setChargeBarPhase = deps.Hud.setChargeBarPhase

    local PILL_NAMES = {}
    local seenPillNames = {}
    local requestedPillNames = type(context.PillNames) == "table"
        and context.PillNames
        or { context.PillName }
    for _, name in ipairs(requestedPillNames) do
        name = tostring(name or "")
        if name ~= "" and not seenPillNames[name] then
            seenPillNames[name] = true
            PILL_NAMES[#PILL_NAMES + 1] = name
        end
    end
    for _, name in ipairs({ "Wind Charge Potion", "蓄风药剂" }) do
        if not seenPillNames[name] then
            seenPillNames[name] = true
            PILL_NAMES[#PILL_NAMES + 1] = name
        end
    end


    local function movementInput(player)
        if player and type(player.GetMovementInput) == "function" then
            local ok, value = pcall(player.GetMovementInput, player)
            if ok and value then
                return value
            end
        end
        return newVector(0, 0)
    end

    local function activeAction(slot)
        if not ButtonAction then
            return nil
        end
        local pocket = ActiveSlot and (
            slot == ActiveSlot.SLOT_POCKET or slot == ActiveSlot.SLOT_POCKET2
        )
        return pocket and ButtonAction.ACTION_PILLCARD or ButtonAction.ACTION_ITEM
    end

    local function actionPressed(player, slot)
        local action = activeAction(slot)
        if action == nil or not Input or type(Input.IsActionPressed) ~= "function" then
            return false
        end
        local controller = tonumber(player and (
            player.ControllerIndex or player.ControllerId or player.Controller
        )) or 0
        local ok, held = pcall(Input.IsActionPressed, action, controller)
        return ok and held == true
    end

    local function clearChargeGameplay(state)
        state.chargeStartFrame = nil
        state.chargeFrames = nil
        state.chargeSlot = nil
        state.chargeSawHeld = false
        state.chargeReady = false
        clearChargeSoundSchedule(state)
    end

    local function useItem(_, itemId, rng, player, useFlags, activeSlot, customVarData)
        local result = { Discharge = false, Remove = false, ShowAnim = false }
        if player and Neverbirth.AvadaKedavra and Neverbirth.AvadaKedavra.OwnsAttack(player) then return result end
        if tonumber(itemId) ~= BIG_DOG_BARK_ID or not player then
            return result
        end
        local state = getPlayerRuntime(player, true)
        if not state then
            return result
        end
        if isBusy(state.mode) or state.echoActive then
            return result
        end
        local current, remembered = resolveDirection(
            movementInput(player),
            state.lastMoveDirection,
            Rod.IsHeld(player)
        )
        if vectorLengthSquared(movementInput(player)) > 0.000001 then
            state.lastMoveDirection = remembered
        end
        local dog = ensureDog(player, state)
        if Rod.IsHeld(player) then
            setChargeBarPhase(state, nil)
            if not dog then
                state.mode = "follow"
                return result
            end
            local dash = launch(player, current, {
                startPosition = dog.Position,
            })
            if dash then
                dog.Position = copyVector(dash.startPosition)
            end
            return result
        end

        local tears = 30 / math.max(0.0001, (tonumber(player.MaxFireDelay) or 0) + 1)
        state.mode = "charging"
        state.chargeStartFrame = runtime.frame
        state.chargeFrames = getChargeFrames(tears)
        state.chargeSlot = activeSlot
        state.chargeSawHeld = true
        state.chargeReady = false
        setChargeBarPhase(state, "charging")
        beginChargeSoundSchedule(state)
        return result
    end
    function callbackInstallers.useItem()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_ITEM, useItem, BIG_DOG_BARK_ID)
    end

    local function postPlayerUpdate(_, player)
        if not player then
            return nil
        end
        local state = getPlayerRuntime(player, true)
        local input = movementInput(player)
        local _, remembered = resolveDirection(input, state.lastMoveDirection, false)
        if vectorLengthSquared(input) > 0.000001 then
            state.lastMoveDirection = remembered
        end

        if playerIsDead(player) or not hasBigDogActive(player) then
            if state.dog or state.echoEntity or state.mode ~= "follow" then
                clearPlayerTransient(state, true)
            end
            return nil
        end

        if state.dog and not entityExists(state.dog) then
            state.dog = nil
            if state.mode == "dash" then
                state.dash = nil
                state.mode = "follow"
            end
        end
        if state.echoEntity and not entityExists(state.echoEntity) then
            state.echoEntity = nil
            state.echoData = nil
            state.echoActive = false
        end
        local dog = ensureDog(player, state)

        if state.mode == "charging" then
            local elapsed = runtime.frame - (tonumber(state.chargeStartFrame) or runtime.frame)
            local required = tonumber(state.chargeFrames) or math.huge
            if actionPressed(player, state.chargeSlot) then
                state.chargeSawHeld = true
                updateChargeSoundSchedule(state)
                if elapsed >= required and state.chargeReady ~= true then
                    state.chargeReady = true
                    setChargeBarPhase(state, "start_charged")
                end
                return nil
            end
            if state.chargeSawHeld then
                local wasReady = state.chargeReady == true or elapsed >= required
                local releaseChargePitch = state.chargeSoundPitch
                state.mode = "follow"
                clearChargeGameplay(state)
                setChargeBarPhase(state, "disappear")
                if wasReady and dog then
                    local direction = resolveDirection(input, state.lastMoveDirection, false)
                    local dash = launch(player, direction, {
                        ignoreBusy = true,
                        startPosition = dog.Position,
                        chargeSoundPitch = releaseChargePitch,
                    })
                    if dash then
                        dog.Position = copyVector(dash.startPosition)
                    end
                end
            end
        end
        return nil
    end
    function callbackInstallers.postPlayerUpdate()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, postPlayerUpdate)
    end

    local function updateDog(_, effect)
        if not effect or type(effect.GetData) ~= "function" then
            return nil
        end
        local okData, data = pcall(effect.GetData, effect)
        if not okData or type(data) ~= "table" or data.NeverbirthBigDogDog ~= true then
            return nil
        end
        local key = tostring(data.NeverbirthBigDogOwnerKey or "")
        local state = runtime.players[key]
        local owner = findPlayerByKey(key)
        if not state or not owner or playerIsDead(owner) or not hasBigDogActive(owner) then
            removeEntity(effect)
            if state then
                clearPlayerTransient(state, true)
            end
            return nil
        end
        if state.dog and entityExists(state.dog) and entityKey(state.dog) ~= entityKey(effect) then
            removeEntity(effect)
            return nil
        end
        state.dog = effect
        markEffectCollisionFree(effect)
        setEntityVisualScale(effect, Constants.DOG_VISUAL_SCALE)

        if state.mode == "dash" then
            updateDash(state, effect)
        elseif state.mode == "charging" then
            local direction = state.lastMoveDirection or newVector(1, 0)
            updateFollowPosition(effect, owner, direction)
            playDirectionalAnimation(effect, "Charge", direction)
        else
            updateChew(state, effect, owner)
        end
        return nil
    end
    function callbackInstallers.updateDog()
        return Neverbirth:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, updateDog, DOG_VARIANT)
    end

    local function resolvePillEffectId()
        if not Isaac then
            return -1
        end
        for _, name in ipairs(PILL_NAMES) do
            for _, methodName in ipairs({ "GetPillEffectByName", "GetPillEffectIdByName" }) do
                local method = Isaac[methodName]
                if type(method) == "function" then
                    local ok, id = pcall(method, name)
                    if ok and (tonumber(id) or -1) >= 0 then
                        return tonumber(id)
                    end
                end
            end
        end
        return -1
    end

    local pillEffectId = resolvePillEffectId()

    local function usePill(_, pillEffect, player, useFlags)
        if pillEffectId < 0 then
            pillEffectId = resolvePillEffectId()
        end
        if tonumber(pillEffect) == pillEffectId and pillEffectId >= 0 then
            useWindPill(player)
        end
        return nil
    end
    function callbackInstallers.usePill()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_PILL, usePill, pillEffectId)
    end
    function callbackInstallers.usePill2()
        return Neverbirth:AddCallback(ModCallbacks.MC_USE_PILL, usePill)
    end

    return {
        movementInput = movementInput,
        activeAction = activeAction,
        actionPressed = actionPressed,
        clearChargeGameplay = clearChargeGameplay,
        useItem = useItem,
        postPlayerUpdate = postPlayerUpdate,
        updateDog = updateDog,
        resolvePillEffectId = resolvePillEffectId,
        usePill = usePill,
        Installers = callbackInstallers,
        PillEffectId = pillEffectId,
    }
end
