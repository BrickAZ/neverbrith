-- Creates one instance of each private module and preserves native installation order.
return function(Neverbirth, dependencies)
    local Store = assert(dependencies.Store)
    local Items = assert(dependencies.Items)
    local GetPlayers = assert(dependencies.GetPlayers)
    local GetCurrentRunSeed = assert(dependencies.GetCurrentRunSeed)
    local DebugLog = assert(dependencies.Log)
    -- Required lazy provider: the peer is installed after this factory returns.
    local GetHouseCarrier = assert(dependencies.GetHouseCarrier)
    assert(type(GetHouseCarrier) == "function", "certificate requires GetHouseCarrier")
    local lifetime = { running = true, disposed = false }

    local CERTIFICATE = Items.CertificateOfNeverbirth
    local PICKUP_ENTITY = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local COLLECTIBLE_PICKUP = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local PORTAL_ENTITY = (EntityType and EntityType.ENTITY_EFFECT) or 1000
    local PORTAL_NAME = "Certificate Return Portal"
    local ITEMS_PER_PAGE = 6
    local PORTAL_TRIGGER_RADIUS = 24
    local GALLERY_ROOM_INDEX = (GridRooms and GridRooms.ROOM_DEBUG_IDX) or -3
    local GALLERY_ROOM_COMMAND = "goto s.default.2"
    local PAGE_PRESS_FRAMES = 10
    local RETURN_PRESS_FRAMES = 13
    local CONTROL_COOLDOWN_FRAMES = 8
    local ARRIVAL_LOCKOUT_FRAMES = 10
    local ROOM_EDGE_MARGIN = 40
    local CONTROL_ROW_RESERVE = 80
    local CONTROL_SUBTYPE = { previous = 0, ["return"] = 1, next = 2 }
    local CONTROL_ROLES = { "previous", "return", "next" }
    local CONTROL_TRIGGER_ORDER = { "return", "previous", "next" }
    local CONTROL_ANIMATIONS = {
        previous = { idle = "PrevIdle", disabled = "PrevDisabled", press = "PrevPress" },
        next = { idle = "NextIdle", disabled = "NextDisabled", press = "NextPress" },
        ["return"] = { idle = "ReturnIdle", press = "ReturnPress" },
    }
    local TELEPORT_ANIMATION = (RoomTransitionAnim and RoomTransitionAnim.TELEPORT) or 3
    local NO_DIRECTION = (Direction and Direction.NO_DIRECTION) or -1

    local state = {
        registry = {}, missing = {}, pendingPickups = {}, frame = 0, transition = nil,
        nextTransientToken = 1, controlEntities = {},
    }
    -- Existing certificate behavior tests inspect this legacy runtime view.
    Neverbirth.CertificateOfNeverbirthState = state

    local Config = {
        CERTIFICATE = CERTIFICATE,
        PICKUP_ENTITY = PICKUP_ENTITY,
        COLLECTIBLE_PICKUP = COLLECTIBLE_PICKUP,
        PORTAL_ENTITY = PORTAL_ENTITY,
        PORTAL_NAME = PORTAL_NAME,
        ITEMS_PER_PAGE = ITEMS_PER_PAGE,
        PORTAL_TRIGGER_RADIUS = PORTAL_TRIGGER_RADIUS,
        GALLERY_ROOM_INDEX = GALLERY_ROOM_INDEX,
        GALLERY_ROOM_COMMAND = GALLERY_ROOM_COMMAND,
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
        TELEPORT_ANIMATION = TELEPORT_ANIMATION,
        NO_DIRECTION = NO_DIRECTION,
    }
    local Room = include("scripts.systems.archive_room").Create(GetPlayers, "[neverbirth][Certificate]")
    local Controls = include("scripts.systems.archive_controls")
    local ledger = include("scripts.features.certificate_of_neverbirth.ledger")(Neverbirth, {
        Store = Store,
        GetCurrentRunSeed = GetCurrentRunSeed,
        Log = DebugLog,
        State = state,
        Room = Room,
        Config = Config,
    })
    local gallery = include("scripts.features.certificate_of_neverbirth.gallery")(Neverbirth, {
        GetPlayers = GetPlayers,
        Log = DebugLog,
        State = state,
        Room = Room,
        Controls = Controls,
        Config = Config,
        ledger = ledger,
    })
    local flow = include("scripts.features.certificate_of_neverbirth.flow")(Neverbirth, {
        GetHouseCarrier = GetHouseCarrier,
        Log = DebugLog,
        State = state,
        Lifetime = lifetime,
        Config = Config,
        Room = Room,
        ledger = ledger,
        gallery = gallery,
    })
    local pickups = include("scripts.features.certificate_of_neverbirth.pickups")(Neverbirth, {
        State = state,
        Lifetime = lifetime,
        Config = Config,
        ledger = ledger,
    })
    local runtime = include("scripts.features.certificate_of_neverbirth.runtime")(Neverbirth, {
        GetHouseCarrier = GetHouseCarrier,
        State = state,
        Lifetime = lifetime,
        Config = Config,
        ledger = ledger,
        gallery = gallery,
        flow = flow,
        pickups = pickups,
    })
    local getPersistentData = ledger.getPersistentData
    local resolveRegistry = ledger.resolveRegistry
    local refreshRegistry = ledger.refreshRegistry
    local newSession = ledger.newSession
    local getRemainingRows = ledger.getRemainingRows
    local getPageCount = ledger.getPageCount
    local getPageRows = ledger.getPageRows
    local getVirtualEdges = ledger.getVirtualEdges
    local markCollected = ledger.markCollected
    local makeTestPositions = ledger.makeTestPositions
    local assignPositions = ledger.assignPositions
    local controlEnabled = gallery.controlEnabled
    local useItem = flow.useItem
    local newRoom = flow.newRoom
    local pickupCollision = pickups.pickupCollision
    local update = runtime.update
    local gameStarted = runtime.gameStarted
    local preGameExit = runtime.preGameExit
    local preModUnload = runtime.preModUnload
    local generatedRows = ledger.generatedRows
    local callbackInstallers = {
        useItem = flow.Installers.useItem,
        newRoom = flow.Installers.newRoom,
        pickupCollision = pickups.Installers.pickupCollision,
        update = runtime.Installers.update,
        gameStarted = runtime.Installers.gameStarted,
        preGameExit = runtime.Installers.preGameExit,
        preModUnload = runtime.Installers.preModUnload,
    }

    refreshRegistry()
    Neverbirth.CertificateOfNeverbirthCarrierAPI = flow.CarrierAPI
    Neverbirth.CertificateOfNeverbirthTestAPI = {
        GetItemId = function() return CERTIFICATE end,
        GetGeneratedCount = function() return #generatedRows end,
        GetGalleryCapacity = function() return ITEMS_PER_PAGE end,
        GetControlSubtype = function(role) return CONTROL_SUBTYPE[role] end,
        IsControlEnabled = controlEnabled,
        GetControlAnimation = function(role, mode)
            return CONTROL_ANIMATIONS[role] and CONTROL_ANIMATIONS[role][mode] or nil
        end,
        GetPageCount = getPageCount, GetPageRows = getPageRows, GetVirtualEdges = getVirtualEdges,
        ResolveRegistry = resolveRegistry, AssignPositions = assignPositions,
        MakeTestPositions = makeTestPositions, NewSession = newSession,
        MarkCollected = markCollected, GetRemainingRows = getRemainingRows,
        RefreshRegistry = refreshRegistry, GetPersistentData = getPersistentData,
        Callbacks = {
            UseItem = useItem, NewRoom = newRoom, PickupCollision = pickupCollision,
            Update = update, GameStarted = gameStarted, PreGameExit = preGameExit,
        },
    }

    callbackInstallers.useItem()
    if ModCallbacks.MC_POST_NEW_ROOM then callbackInstallers.newRoom() end
    if ModCallbacks.MC_PRE_PICKUP_COLLISION then callbackInstallers.pickupCollision() end
    callbackInstallers.update()
    if ModCallbacks.MC_POST_GAME_STARTED then callbackInstallers.gameStarted() end
    if ModCallbacks.MC_PRE_GAME_EXIT then callbackInstallers.preGameExit() end
    if ModCallbacks.MC_PRE_MOD_UNLOAD then callbackInstallers.preModUnload() end
    -- Same-instance compatibility alias; callers must not create a second owner.
    return flow.CarrierAPI
end
