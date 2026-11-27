-- Private state ownership; constructed once by the item entry.
return function(Neverbirth, deps)
    local context = deps.context

    local ITEM_ID = context.ItemId or -1
    local SLOT_TRINKET_ID = context.TrinketId or -1
    local VANILLA_COLLECTIBLE_LIMIT = (CollectibleType and CollectibleType.NUM_COLLECTIBLES) or 733
    local MAX_REROLL_ATTEMPTS = 40
    local HEALTH_CAP = 12
    local KEY_CAP = 2
    local BOMB_CAP = 1
    local COIN_CAP = 20
    local COIN_DEAL_CAP = 35
    local ROOM_CHARGE_INTERVAL = 2

    local SLOT_PRIMARY = (ActiveSlot and ActiveSlot.SLOT_PRIMARY) or 0
    local SLOT_SECONDARY = (ActiveSlot and ActiveSlot.SLOT_SECONDARY) or 1
    local PICKUP_COLLECTIBLE = (PickupVariant and PickupVariant.PICKUP_COLLECTIBLE) or 100
    local PICKUP_TRINKET = (PickupVariant and PickupVariant.PICKUP_TRINKET) or 350
    local PICKUP_BED = (PickupVariant and PickupVariant.PICKUP_BED) or 380
    -- resources-dlc3/entities2.xml: Mom's Bed is 5.380.10. The shipped
    -- BedSubType.BED_MOM enum incorrectly says 1 in Repentance 1.7.9b.
    local MOMS_BED_SUBTYPE = 10
    local ENTITY_PICKUP = (EntityType and EntityType.ENTITY_PICKUP) or 5
    local ENTITY_PLAYER = (EntityType and EntityType.ENTITY_PLAYER) or 1
    local ITEM_ACTIVE = (ItemType and ItemType.ITEM_ACTIVE) or 3

    local REQUIRED_CURSES =
        ((LevelCurse and LevelCurse.CURSE_OF_DARKNESS) or 1)
        | ((LevelCurse and LevelCurse.CURSE_OF_THE_LOST) or 4)
        | ((LevelCurse and LevelCurse.CURSE_OF_THE_UNKNOWN) or 8)
        | ((LevelCurse and LevelCurse.CURSE_OF_MAZE) or 32)

    local IDS = {
        Sol = (CollectibleType and CollectibleType.COLLECTIBLE_SOL) or 588,
        BlackCandle = (CollectibleType and CollectibleType.COLLECTIBLE_BLACK_CANDLE) or 260,
        Schoolbag = (CollectibleType and CollectibleType.COLLECTIBLE_SCHOOLBAG) or 534,
        LittleHorn = (CollectibleType and CollectibleType.COLLECTIBLE_LITTLE_HORN) or 503,
        Euthanasia = (CollectibleType and CollectibleType.COLLECTIBLE_EUTHANASIA) or 496,
        FruitCake = (CollectibleType and CollectibleType.COLLECTIBLE_FRUIT_CAKE) or 418,
        PoundOfFlesh = (CollectibleType and CollectibleType.COLLECTIBLE_POUND_OF_FLESH) or 672,
        TheWiz = (CollectibleType and CollectibleType.COLLECTIBLE_THE_WIZ) or 358,
        CurseOfTheTower = (CollectibleType and CollectibleType.COLLECTIBLE_CURSE_OF_THE_TOWER) or 371,
        CursedEye = (CollectibleType and CollectibleType.COLLECTIBLE_CURSED_EYE) or 316,
        MonkeyPaw = (TrinketType and TrinketType.TRINKET_MONKEY_PAW) or 20,
        KeepersBargain = (TrinketType and TrinketType.TRINKET_KEEPERS_BARGAIN) or 171,
    }

    local BANNED_COLLECTIBLES = {
        [IDS.Sol] = true,
        [IDS.BlackCandle] = true,
        [IDS.Schoolbag] = true,
        [IDS.LittleHorn] = true,
        [IDS.Euthanasia] = true,
        [IDS.FruitCake] = true,
    }

    local PROTECTED_COLLECTIBLES = {
        IDS.TheWiz,
        IDS.CurseOfTheTower,
        IDS.CursedEye,
    }
    local PROTECTED_SET = {}
    for _, id in ipairs(PROTECTED_COLLECTIBLES) do PROTECTED_SET[id] = true end

    local runtime = {
        pendingTrades = {},
        pendingRingPickups = {},
        spawningCompensation = false,
        rerollDepth = 0,
        lastCurseCheckFrame = -1,
        roomVisit = 0,
    }


    local function DebugLog(message)
        if context.DebugLog then
            context.DebugLog("[Seven Curses] " .. tostring(message))
        elseif Isaac and Isaac.DebugString then
            Isaac.DebugString("[neverbirth][Seven Curses] " .. tostring(message))
        end
    end

    local function Save()
        if context.Save then context.Save() end
    end

    local function GetRunSeed()
        if context.GetCurrentRunSeed then return tostring(context.GetCurrentRunSeed()) end
        local game = Game and Game()
        local seeds = game and game.GetSeeds and game:GetSeeds()
        if seeds and seeds.GetStartSeed then return tostring(seeds:GetStartSeed()) end
        return "unknown"
    end

    local function GetSaveRoot()
        if context.GetSaveRoot then return context.GetSaveRoot() end
        Neverbirth.RingOfSevenCursesSave = Neverbirth.RingOfSevenCursesSave or {}
        return Neverbirth.RingOfSevenCursesSave
    end

    local function GetSavedState()
        local root = GetSaveRoot()
        local runSeed = GetRunSeed()
        local state = root.ringOfSevenCurses
        if type(state) ~= "table" or tostring(state.runSeed) ~= runSeed then
            state = { runSeed = runSeed, players = {} }
            root.ringOfSevenCurses = state
        end
        if type(state.players) ~= "table" then state.players = {} end
        return state
    end

    local function GetPlayerKey(player)
        if player and player.InitSeed ~= nil then return tostring(player.InitSeed) end
        if player and player.ControllerIndex ~= nil then return "controller:" .. tostring(player.ControllerIndex) end
        if GetPtrHash and player then return "ptr:" .. tostring(GetPtrHash(player)) end
        return tostring(player)
    end

    local function GetPlayerState(player, create)
        local players = GetSavedState().players
        local key = GetPlayerKey(player)
        local state = players[key]
        if not state and create then
            state = {
                active = false,
                roomProgress = 0,
                lastRoomKey = nil,
                nativeSecondary = 0,
                protectedCounts = {},
            }
            players[key] = state
        end
        if state then
            state.roomProgress = tonumber(state.roomProgress) or 0
            state.nativeSecondary = tonumber(state.nativeSecondary) or 0
            state.protectedCounts = type(state.protectedCounts) == "table" and state.protectedCounts or {}
        end
        return state
    end

    local function GetPlayers()
        if context.GetPlayers then return context.GetPlayers() or {} end
        local result = {}
        local game = Game and Game()
        local count = game and game.GetNumPlayers and game:GetNumPlayers() or 0
        for index = 0, count - 1 do result[#result + 1] = Isaac.GetPlayer(index) end
        return result
    end

    local function IsPlayerActive(player)
        local state = player and GetPlayerState(player, false)
        return state and state.active == true or false
    end

    local function AnyPlayerActive()
        for _, player in ipairs(GetPlayers()) do
            if IsPlayerActive(player) then return true end
        end
        return false
    end

    local function GetRoomKey()
        if context.GetRoomKey then return tostring(context.GetRoomKey()) end
        local game = Game and Game()
        local level = game and game.GetLevel and game:GetLevel()
        if not level then return "unknown-room" end
        local stage = level.GetStage and level:GetStage() or 0
        local dimension = level.GetDimension and level:GetDimension() or 0
        local index = level.GetCurrentRoomIndex and level:GetCurrentRoomIndex() or 0
        return table.concat({ tostring(stage), tostring(index), tostring(dimension) }, ":")
    end

    local function GetFrameCount()
        local game = Game and Game()
        return game and game.GetFrameCount and game:GetFrameCount() or 0
    end

    local function GetIncomingDamageMultiplier(_, player)
        local state = GetPlayerState(player, false)
        return state and state.active and 2 or 1
    end

    local function ResetForTest()
        local root = GetSaveRoot()
        root.ringOfSevenCurses = { runSeed = GetRunSeed(), players = {} }
        runtime.pendingTrades = {}
        runtime.pendingRingPickups = {}
        runtime.spawningCompensation = false
        runtime.rerollDepth = 0
        runtime.lastCurseCheckFrame = -1
        runtime.roomVisit = 0
    end

    return {
        GetIncomingDamageMultiplier = GetIncomingDamageMultiplier,
        ResetForTest = ResetForTest,
        DebugLog = DebugLog,
        Save = Save,
        GetRunSeed = GetRunSeed,
        GetSaveRoot = GetSaveRoot,
        GetSavedState = GetSavedState,
        GetPlayerKey = GetPlayerKey,
        GetPlayerState = GetPlayerState,
        GetPlayers = GetPlayers,
        IsPlayerActive = IsPlayerActive,
        AnyPlayerActive = AnyPlayerActive,
        GetRoomKey = GetRoomKey,
        GetFrameCount = GetFrameCount,
        ITEM_ID = ITEM_ID,
        SLOT_TRINKET_ID = SLOT_TRINKET_ID,
        VANILLA_COLLECTIBLE_LIMIT = VANILLA_COLLECTIBLE_LIMIT,
        MAX_REROLL_ATTEMPTS = MAX_REROLL_ATTEMPTS,
        HEALTH_CAP = HEALTH_CAP,
        KEY_CAP = KEY_CAP,
        BOMB_CAP = BOMB_CAP,
        COIN_CAP = COIN_CAP,
        COIN_DEAL_CAP = COIN_DEAL_CAP,
        ROOM_CHARGE_INTERVAL = ROOM_CHARGE_INTERVAL,
        SLOT_PRIMARY = SLOT_PRIMARY,
        SLOT_SECONDARY = SLOT_SECONDARY,
        PICKUP_COLLECTIBLE = PICKUP_COLLECTIBLE,
        PICKUP_TRINKET = PICKUP_TRINKET,
        PICKUP_BED = PICKUP_BED,
        MOMS_BED_SUBTYPE = MOMS_BED_SUBTYPE,
        ENTITY_PICKUP = ENTITY_PICKUP,
        ENTITY_PLAYER = ENTITY_PLAYER,
        ITEM_ACTIVE = ITEM_ACTIVE,
        REQUIRED_CURSES = REQUIRED_CURSES,
        IDS = IDS,
        BANNED_COLLECTIBLES = BANNED_COLLECTIBLES,
        PROTECTED_COLLECTIBLES = PROTECTED_COLLECTIBLES,
        PROTECTED_SET = PROTECTED_SET,
        runtime = runtime,
    }
end
