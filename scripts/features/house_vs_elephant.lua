-- Creates one instance of each private module and preserves native installation order.
return function(Neverbirth, dependencies)
    local Store = assert(dependencies.Store)
    local Items = assert(dependencies.Items)
    local GetPlayers = assert(dependencies.GetPlayers)
    local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
    local DebugLog = assert(dependencies.Log)
    local GetCertificateCarrier = assert(dependencies.GetCertificateCarrier)
    assert(type(GetCertificateCarrier) == "function", "house requires GetCertificateCarrier")
    local lifetime = { running = true, disposed = false }

    local HOUSE = Items.HouseVsElephant
    local MILK = (CollectibleType and CollectibleType.COLLECTIBLE_BREAKFAST) or 25
    local ACTIVE_ITEM_TYPE = (ItemType and ItemType.ITEM_ACTIVE) or 3
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local SPECIAL_ROOM_INDEX = (GridRooms and GridRooms.ROOM_DEBUG_IDX) or -3
    local SPECIAL_ROOM_COMMAND = "goto s.default.2"
    local NO_DIRECTION = (Direction and Direction.NO_DIRECTION) or -1
    local TELEPORT_ANIMATION = (RoomTransitionAnim and RoomTransitionAnim.TELEPORT) or 3
    local CONFIRM_FRAMES = 4
    local PORTAL_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local PORTAL_NAME = "Certificate Return Portal"
    local ITEMS_PER_PAGE = 6
    local CONTROL_TRIGGER_RADIUS = 24
    local PAGE_PRESS_FRAMES = 10
    local RETURN_PRESS_FRAMES = 13
    local CONTROL_COOLDOWN_FRAMES = 8
    local ARRIVAL_LOCKOUT_FRAMES = 10
    local ROOM_EDGE_MARGIN = 40
    local CONTROL_ROW_RESERVE = 80
    local CONTROL_SUBTYPE = { previous = 0, ["return"] = 1, next = 2 }
    local CONTROL_ROLES = { "previous", "return", "next" }
    local CONTROL_TRIGGER_ORDER = { "return", "previous", "next" }
    local CONTROL_ANIMATIONS = { previous = { idle = "PrevIdle", disabled = "PrevDisabled", press = "PrevPress" }, next = { idle = "NextIdle", disabled = "NextDisabled", press = "NextPress" }, ["return"] = { idle = "ReturnIdle", press = "ReturnPress" } }

    local state = {
        frame = 0, pending = {}, returningAfterContinue = nil, transition = nil, controlEntities = {},
    }

    local Config = {
        HOUSE = HOUSE,
        MILK = MILK,
        ACTIVE_ITEM_TYPE = ACTIVE_ITEM_TYPE,
        PICKUP_ENTITY = PICKUP_ENTITY,
        COLLECTIBLE_PICKUP = COLLECTIBLE_PICKUP,
        SPECIAL_ROOM_INDEX = SPECIAL_ROOM_INDEX,
        SPECIAL_ROOM_COMMAND = SPECIAL_ROOM_COMMAND,
        NO_DIRECTION = NO_DIRECTION,
        TELEPORT_ANIMATION = TELEPORT_ANIMATION,
        CONFIRM_FRAMES = CONFIRM_FRAMES,
        PORTAL_ENTITY = PORTAL_ENTITY,
        PORTAL_NAME = PORTAL_NAME,
        ITEMS_PER_PAGE = ITEMS_PER_PAGE,
        CONTROL_TRIGGER_RADIUS = CONTROL_TRIGGER_RADIUS,
        PAGE_PRESS_FRAMES = PAGE_PRESS_FRAMES,
        RETURN_PRESS_FRAMES = RETURN_PRESS_FRAMES,
        CONTROL_COOLDOWN_FRAMES = CONTROL_COOLDOWN_FRAMES,
        ARRIVAL_LOCKOUT_FRAMES = ARRIVAL_LOCKOUT_FRAMES,
        ROOM_EDGE_MARGIN = ROOM_EDGE_MARGIN,
        CONTROL_ROW_RESERVE = CONTROL_ROW_RESERVE,
        CONTROL_SUBTYPE = CONTROL_SUBTYPE,
        CONTROL_ROLES = CONTROL_ROLES,
        CONTROL_TRIGGER_ORDER = CONTROL_TRIGGER_ORDER,
        CONTROL_ANIMATIONS = CONTROL_ANIMATIONS,
    }
    local Room = include("scripts.systems.archive_room").Create(GetPlayers, "[neverbirth][HouseVsElephant]")
    local Controls = include("scripts.systems.archive_controls")
    local ledger = include("scripts.features.house_vs_elephant.ledger")(Neverbirth, {
        Store = Store,
        GetCurrentRunSeed = GetCurrentRunSeed,
        State = state,
        Lifetime = lifetime,
        Room = Room,
        Config = Config,
    })
    local gallery = include("scripts.features.house_vs_elephant.gallery")(Neverbirth, {
        GetPlayers = GetPlayers,
        Log = DebugLog,
        State = state,
        Room = Room,
        Controls = Controls,
        Config = Config,
        ledger = ledger,
    })
    local flow = include("scripts.features.house_vs_elephant.flow")(Neverbirth, {
        GetCertificateCarrier = GetCertificateCarrier,
        GetPlayers = GetPlayers,
        Log = DebugLog,
        State = state,
        Lifetime = lifetime,
        Config = Config,
        Room = Room,
        ledger = ledger,
        gallery = gallery,
    })
    local pickups = include("scripts.features.house_vs_elephant.pickups")(Neverbirth, {
        State = state,
        Lifetime = lifetime,
        Config = Config,
        Room = Room,
        ledger = ledger,
        gallery = gallery,
        flow = flow,
    })
    local runtime = include("scripts.features.house_vs_elephant.runtime")(Neverbirth, {
        Store = Store,
        GetCurrentRunSeed = GetCurrentRunSeed,
        State = state,
        Lifetime = lifetime,
        ledger = ledger,
        flow = flow,
        pickups = pickups,
    })
    local newRunData = ledger.newRunData
    local normalizeRunData = ledger.normalizeRunData
    local getPersistentData = ledger.getPersistentData
    local encounterKey = ledger.encounterKey
    local recordEncounter = ledger.recordEncounter
    local buildCandidates = ledger.buildCandidates
    local newSession = ledger.newSession
    local markSelected = ledger.markSelected
    local pickupUpdate = ledger.pickupUpdate
    local getPageCount = ledger.getPageCount
    local getPageEntries = ledger.getPageEntries
    local getVirtualEdges = ledger.getVirtualEdges
    local makePositions = gallery.makePositions
    local useItem = flow.useItem
    local newRoom = flow.newRoom
    local pickupCollision = pickups.pickupCollision
    local update = runtime.update
    local gameStarted = runtime.gameStarted
    local preGameExit = runtime.preGameExit
    local preModUnload = runtime.preModUnload
    local callbackInstallers = {
        pickupUpdate = ledger.Installers.pickupUpdate,
        useItem = flow.Installers.useItem,
        pickupCollision = pickups.Installers.pickupCollision,
        newRoom = flow.Installers.newRoom,
        update = runtime.Installers.update,
        gameStarted = runtime.Installers.gameStarted,
        preGameExit = runtime.Installers.preGameExit,
        preModUnload = runtime.Installers.preModUnload,
    }

    Neverbirth.HouseVsElephantCarrierAPI = flow.CarrierAPI

    Neverbirth.HouseVsElephantTestAPI = {
        GetItemId = function() return HOUSE end,
        NewRunData = newRunData, NormalizeRunData = normalizeRunData,
        EncounterKey = encounterKey, RecordEncounter = recordEncounter,
        BuildCandidates = buildCandidates, NewSession = newSession, MarkSelected = markSelected,
        GetPageCount = getPageCount, GetPageEntries = getPageEntries, GetVirtualEdges = getVirtualEdges,
        GetControlSubtype = function(role) return CONTROL_SUBTYPE[role] end,
        GetControlAnimation = function(role, mode)
            return CONTROL_ANIMATIONS[role] and CONTROL_ANIMATIONS[role][mode] or nil
        end,
        MakePositions = makePositions, GetPersistentData = getPersistentData,
        Callbacks = {
            UseItem = useItem, NewRoom = newRoom, PickupCollision = pickupCollision, PickupUpdate = pickupUpdate,
            Update = update, GameStarted = gameStarted, PreGameExit = preGameExit,
        },
    }

    callbackInstallers.useItem()
    if ModCallbacks.MC_POST_NEW_ROOM then callbackInstallers.newRoom() end
    if ModCallbacks.MC_POST_PICKUP_UPDATE then
        callbackInstallers.pickupUpdate()
    end
    if ModCallbacks.MC_PRE_PICKUP_COLLISION then
        callbackInstallers.pickupCollision()
    end
    callbackInstallers.update()
    if ModCallbacks.MC_POST_GAME_STARTED then callbackInstallers.gameStarted() end
    if ModCallbacks.MC_PRE_GAME_EXIT then callbackInstallers.preGameExit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then callbackInstallers.preModUnload() end
    -- The assembly owns this live interface; the Mod field is its compatibility alias.
    return flow.CarrierAPI
end
