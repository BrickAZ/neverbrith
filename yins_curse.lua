-- Assemble this item once; private modules own behavior and native bindings.
return function(Neverbirth, context)
    context = context or {}
    local State = include("scripts.features.yins_curse.state")(Neverbirth, {
        context = context,
    })
    local Queries = include("scripts.features.yins_curse.queries")(Neverbirth, {
        context = context,
        State = State,
    })
    local Pedestals = include("scripts.features.yins_curse.pedestals")(Neverbirth, {
        State = State,
    })
    local Acquisition = include("scripts.features.yins_curse.acquisition")(Neverbirth, {
        State = State,
        Queries = Queries,
        Pedestals = Pedestals,
    })
    local Runtime = include("scripts.features.yins_curse.runtime")(Neverbirth, {
        State = State,
        Queries = Queries,
        Pedestals = Pedestals,
        Acquisition = Acquisition,
    })
    local debugLog = State.debugLog
    local getSavedState = State.getSavedState
    local resetRuntimeOnly = State.resetRuntimeOnly
    local resetForTest = State.resetForTest
    local isVisibleInteractableCollectible = Pedestals.isVisibleInteractableCollectible
    local processCandidate = Pedestals.processCandidate
    local processCurrentRoom = Pedestals.processCurrentRoom
    local pickupInit = Pedestals.pickupInit
    local pickupUpdate = Pedestals.pickupUpdate
    local recordFirstAcquisition = Acquisition.recordFirstAcquisition
    local prePickupCollision = Acquisition.prePickupCollision
    local postAddCollectible = Acquisition.postAddCollectible
    local postUpdate = Runtime.postUpdate
    local newRoom = Runtime.newRoom
    local gameStarted = Runtime.gameStarted
    local preGameExit = Runtime.preGameExit
    local preExplosionImmunity = Runtime.preExplosionImmunity
    local ITEM_ID = State.ITEM_ID
    local BLACK_CANDLE_ID = State.BLACK_CANDLE_ID
    local IPECAC_ID = State.IPECAC_ID
    local runtime = State.runtime

    Neverbirth.YinsCurseTestAPI = {
        ItemId = ITEM_ID,
        BlackCandleId = BLACK_CANDLE_ID,
        IpecacId = IPECAC_ID,
        Runtime = runtime,
        GetSavedState = getSavedState,
        ResetForTest = resetForTest,
        ResetRuntimeOnly = resetRuntimeOnly,
        RecordFirstAcquisition = recordFirstAcquisition,
        IsVisibleInteractableCollectible = isVisibleInteractableCollectible,
        ProcessCandidate = processCandidate,
        ProcessCurrentRoom = processCurrentRoom,
        Callbacks = {
            PreExplosionImmunity = preExplosionImmunity,
            PrePickupCollision = prePickupCollision,
            PostAddCollectible = postAddCollectible,
            PostUpdate = postUpdate,
            PickupInit = pickupInit,
            PickupUpdate = pickupUpdate,
            NewRoom = newRoom,
            GameStarted = gameStarted,
            PreGameExit = preGameExit,
        },
    }

    if ITEM_ID <= 0 then
        debugLog("Runtime item ID was not found; callbacks were not registered")
        return
    end

    local explosionApiReady = false
    if Isaac and type(Isaac.GetPlayerExplosionImmunityAPIVersion) == "function"
        and ModCallbacks.MC_PRE_PLAYER_EXPLOSION_IMMUNITY then
        local ok, version = pcall(Isaac.GetPlayerExplosionImmunityAPIVersion)
        explosionApiReady = ok and version == 1
    end
    if explosionApiReady then
        Runtime.Installers.preExplosionImmunity()
    else
        debugLog("精确爆炸免疫封锁未启用：需要完整的 Explosion Immunity API v1 原生构建及配套脚本。")
    end
    if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
        Acquisition.Installers.postAddCollectible()
    end
    Runtime.Installers.postUpdate()
    if ModCallbacks.MC_PRE_PICKUP_COLLISION then
        Acquisition.Installers.prePickupCollision()
    end
    if ModCallbacks.MC_POST_PICKUP_INIT then
        Pedestals.Installers.pickupInit()
    end
    if ModCallbacks.MC_POST_PICKUP_UPDATE then
        Pedestals.Installers.pickupUpdate()
    end
    if ModCallbacks.MC_POST_NEW_ROOM then
        Runtime.Installers.newRoom()
    end
    if ModCallbacks.MC_POST_GAME_STARTED then
        Runtime.Installers.gameStarted()
    end
    if ModCallbacks.MC_PRE_GAME_EXIT then
        Runtime.Installers.preGameExit()
    end
end
