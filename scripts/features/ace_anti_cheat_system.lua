-- Assemble this item once; private modules own behavior and native bindings.
return function(Neverbirth, dependencies)
    assert(dependencies.Items)
    assert(dependencies.GetPlayers)
    assert(dependencies.IsValidItemId)
    assert(dependencies.Log)
    local State = include("scripts.features.ace_anti_cheat_system.state")(Neverbirth, {
        DebugLog = dependencies.Log,
        Items = dependencies.Items,
    })
    local Queries = include("scripts.features.ace_anti_cheat_system.queries")(Neverbirth, {
        GetPlayers = dependencies.GetPlayers,
        IsValidItemId = dependencies.IsValidItemId,
        State = State,
    })
    local Audit = include("scripts.features.ace_anti_cheat_system.audit")(Neverbirth, {
        GetPlayers = dependencies.GetPlayers,
        DebugLog = dependencies.Log,
        State = State,
        Queries = Queries,
    })
    local Combat = include("scripts.features.ace_anti_cheat_system.combat")(Neverbirth, {
        State = State,
        Queries = Queries,
        Audit = Audit,
    })
    local Runtime = include("scripts.features.ace_anti_cheat_system.runtime")(Neverbirth, {
        State = State,
        Queries = Queries,
        Audit = Audit,
        Combat = Combat,
    })
    local runAuditWorkload = Audit.runAuditWorkload
    local updateAuditState = Audit.updateAuditState
    local isEligibleNpc = Combat.isEligibleNpc
    local monitorNpc = Combat.monitorNpc
    local settlePendingForEntity = Combat.settlePendingForEntity
    local handleNpcDeath = Combat.handleNpcDeath
    local npcDamage = Combat.npcDamage
    local npcInit = Combat.npcInit
    local npcDeath = Combat.npcDeath
    local entityKill = Combat.entityKill
    local resetRoomState = Runtime.resetRoomState
    local resetAll = Runtime.resetAll
    local activate = Runtime.activate
    local deactivate = Runtime.deactivate
    local playerDamage = Runtime.playerDamage
    local postUpdate = Runtime.postUpdate
    local newRoom = Runtime.newRoom
    local newLevel = Runtime.newLevel
    local gameStarted = Runtime.gameStarted
    local preGameExit = Runtime.preGameExit
    local preModUnload = Runtime.preModUnload
    local ITEM_ID = State.ITEM_ID
    local FATAL_MESSAGE = State.FATAL_MESSAGE
    local capabilities = State.capabilities
    local runtime = State.runtime

    Neverbirth.ACEAntiCheatTestAPI = {
        ItemId = ITEM_ID,
        FatalMessage = FATAL_MESSAGE,
        Capabilities = capabilities,
        Runtime = runtime,
        IsEligibleNpc = isEligibleNpc,
        MonitorNpc = monitorNpc,
        SettlePendingForEntity = settlePendingForEntity,
        HandleNpcDeath = handleNpcDeath,
        ResetAll = resetAll,
        ResetRoomState = resetRoomState,
        Activate = activate,
        Deactivate = deactivate,
        UpdateAuditState = updateAuditState,
        RunAuditWorkload = runAuditWorkload,
        Callbacks = {
            PlayerDamage = playerDamage,
            NpcDamage = npcDamage,
            NpcInit = npcInit,
            NpcDeath = npcDeath,
            EntityKill = entityKill,
            Update = postUpdate,
            NewRoom = newRoom,
            NewLevel = newLevel,
            GameStarted = gameStarted,
            PreGameExit = preGameExit,
        },
    }

    Runtime.Installers.playerDamage()
    Combat.Installers.npcDamage()
    Runtime.Installers.postUpdate()
    if ModCallbacks.MC_POST_NPC_INIT then Combat.Installers.npcInit() end
    if ModCallbacks.MC_POST_NPC_DEATH then Combat.Installers.npcDeath() end
    if ModCallbacks.MC_POST_ENTITY_KILL then Combat.Installers.entityKill() end
    if ModCallbacks.MC_POST_NEW_ROOM then Runtime.Installers.newRoom() end
    if ModCallbacks.MC_POST_NEW_LEVEL then Runtime.Installers.newLevel() end
    if ModCallbacks.MC_POST_GAME_STARTED then Runtime.Installers.gameStarted() end
    if ModCallbacks.MC_PRE_GAME_EXIT then Runtime.Installers.preGameExit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then Runtime.Installers.preModUnload() end
end
