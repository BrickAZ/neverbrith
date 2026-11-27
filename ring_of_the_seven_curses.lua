-- Assemble this item once; private modules own behavior and native bindings.
return function(Neverbirth, context)
    context = context or {}
    local State = include("scripts.features.ring_of_the_seven_curses.state")(Neverbirth, {
        context = context,
    })
    local Inventory = include("scripts.features.ring_of_the_seven_curses.inventory")(Neverbirth, {
        State = State,
    })
    local World = include("scripts.features.ring_of_the_seven_curses.world")(Neverbirth, {
        State = State,
        Inventory = Inventory,
    })
    local Rewards = include("scripts.features.ring_of_the_seven_curses.rewards")(Neverbirth, {
        State = State,
        Inventory = Inventory,
    })
    local Runtime = include("scripts.features.ring_of_the_seven_curses.runtime")(Neverbirth, {
        State = State,
        Inventory = Inventory,
        World = World,
        Rewards = Rewards,
    })
    local GetSavedState = State.GetSavedState
    local GetPlayerState = State.GetPlayerState
    local GetTotalHealthCapacity = Inventory.GetTotalHealthCapacity
    local ClampHealth = Inventory.ClampHealth
    local GetCoinCap = Inventory.GetCoinCap
    local ClampResources = Inventory.ClampResources
    local DoubleNpcHealth = World.DoubleNpcHealth
    local ForceCurses = World.ForceCurses
    local ActivatePlayer = World.ActivatePlayer
    local IsForbiddenCollectible = Rewards.IsForbiddenCollectible
    local RerollForbiddenSelection = Rewards.RerollForbiddenSelection
    local CompensateForbiddenPedestal = Rewards.CompensateForbiddenPedestal
    local RegisterTradeCandidate = Rewards.RegisterTradeCandidate
    local SettleTradeCandidates = Rewards.SettleTradeCandidates
    local ReconcilePlayer = Runtime.ReconcilePlayer
    local OnUseItem = Runtime.OnUseItem
    local OnEvaluateCache = Runtime.OnEvaluateCache
    local OnPostPEffectUpdate = Runtime.OnPostPEffectUpdate
    local OnPostNewRoom = Runtime.OnPostNewRoom
    local OnPostNewLevel = Runtime.OnPostNewLevel
    local OnPostGameStarted = Runtime.OnPostGameStarted
    local OnPreGameExit = Runtime.OnPreGameExit
    local OnPostCurseEval = Runtime.OnPostCurseEval
    local OnPostNpcInit = Runtime.OnPostNpcInit
    local OnEntityTakeDamage = Runtime.OnEntityTakeDamage
    local OnPostGetCollectible = Runtime.OnPostGetCollectible
    local OnPostPickupUpdate = Runtime.OnPostPickupUpdate
    local OnPostTrinketUpdate = Runtime.OnPostTrinketUpdate
    local OnPreBedCollision = Runtime.OnPreBedCollision
    local OnPrePickupCollision = Runtime.OnPrePickupCollision
    local ITEM_ID = State.ITEM_ID
    local SLOT_TRINKET_ID = State.SLOT_TRINKET_ID
    local REQUIRED_CURSES = State.REQUIRED_CURSES

    if Neverbirth and Neverbirth.AddCallback and ITEM_ID > 0 then
        if ModCallbacks.MC_USE_ITEM then Runtime.Installers.OnUseItem() end
        if ModCallbacks.MC_EVALUATE_CACHE then Runtime.Installers.OnEvaluateCache() end
        if ModCallbacks.MC_POST_PEFFECT_UPDATE then Runtime.Installers.OnPostPEffectUpdate() end
        if ModCallbacks.MC_POST_NEW_ROOM then Runtime.Installers.OnPostNewRoom() end
        if ModCallbacks.MC_POST_NEW_LEVEL then Runtime.Installers.OnPostNewLevel() end
        if ModCallbacks.MC_POST_GAME_STARTED then Runtime.Installers.OnPostGameStarted() end
        if ModCallbacks.MC_PRE_GAME_EXIT then Runtime.Installers.OnPreGameExit() end
        if ModCallbacks.MC_POST_CURSE_EVAL then Runtime.Installers.OnPostCurseEval() end
        if ModCallbacks.MC_POST_NPC_INIT then Runtime.Installers.OnPostNpcInit() end
        if ModCallbacks.MC_ENTITY_TAKE_DMG then Runtime.Installers.OnEntityTakeDamage() end
        if ModCallbacks.MC_POST_GET_COLLECTIBLE then Runtime.Installers.OnPostGetCollectible() end
        if ModCallbacks.MC_POST_PICKUP_UPDATE then Runtime.Installers.OnPostPickupUpdate() end
        if ModCallbacks.MC_POST_PICKUP_UPDATE then Runtime.Installers.OnPostTrinketUpdate() end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then Runtime.Installers.OnPrePickupCollision() end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then Runtime.Installers.OnPreBedCollision() end
    end

    -- Production query shared with damage consumers; no test API dependency.
    Neverbirth.GetRingOfSevenCursesIncomingDamageMultiplier = State.GetIncomingDamageMultiplier

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
            PreBedCollision = OnPreBedCollision,
        },
        ResetForTest = State.ResetForTest,
    }
end
