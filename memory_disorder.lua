return function(Neverbirth, context)
    context = context or {}

    local ITEM_ID = context.ItemId or 0
    local FALLBACK_ICON_ID = 0 -- Neutral question mark when no unseen passive remains.
    local QUESTION_MARK_GFX = "gfx/items/collectibles/questionmark.png"
    local SAVE_VERSION = 1
    local TRANSITION_SWITCH_FRAME = 15
    local TRANSITION_END_FRAME = 30
    local MAX_DARKNESS = 0.55

    local SLOT_PRIMARY = ActiveSlot and ActiveSlot.SLOT_PRIMARY or 0
    local SLOT_SECONDARY = ActiveSlot and ActiveSlot.SLOT_SECONDARY or 1
    local SLOT_POCKET = ActiveSlot and ActiveSlot.SLOT_POCKET or 2
    local POCKET_PRIMARY = PocketItemSlot and PocketItemSlot.SLOT_PRIMARY or 0
    local POCKET_SECONDARY = PocketItemSlot and PocketItemSlot.SLOT_SECONDARY or 1

    local runtime = {
        states = {},
        roomSerial = 0,
        iconCandidates = nil,
        iconConfigs = {},
        collectibleGfx = {},
        iconHistoryPlayers = {},
        iconHistoryDirty = false,
        portalSpawnedThisRoom = false,
        terminalKind = nil,
        diagnostics = {},
    }

    Neverbirth.MemoryDisorderCharacterProfiles = Neverbirth.MemoryDisorderCharacterProfiles or {}

    local function debugLog(message)
        if context.DebugLog then context.DebugLog(message) end
    end

    local function diagnosticOnce(key, message)
        if runtime.diagnostics[key] then return end
        runtime.diagnostics[key] = true
        debugLog("[neverbirth][memory-disorder] " .. message)
    end

    local function safeCall(object, methodName, ...)
        local method = object and object[methodName]
        if type(method) ~= "function" then return nil, false end
        local ok, result = pcall(method, object, ...)
        if not ok then return nil, false end
        return result, true
    end

    local function numberCall(object, methodName, ...)
        local value = safeCall(object, methodName, ...)
        return tonumber(value) or 0
    end

    local function copyTable(source)
        local result = {}
        for key, value in pairs(source or {}) do
            if type(value) == "table" then
                result[key] = copyTable(value)
            else
                result[key] = value
            end
        end
        return result
    end

    local function playerType(name, fallback)
        if PlayerType and PlayerType[name] ~= nil then return PlayerType[name] end
        return fallback
    end

    -- This table deliberately lists selectable top-level vanilla identities only.
    -- Internal derived bodies (Soul, Esau, Lazarus II, Black Judas and the two
    -- Tainted Lazarus forms) are created by their owning identity, never rolled.
    local VANILLA_PROFILES = {
        { id = "isaac", playerType = playerType("PLAYER_ISAAC", 0), healthMode = "ordinary" },
        { id = "magdalene", playerType = playerType("PLAYER_MAGDALENE", 1), achievement = 1,
            actives = { { id = 45, slot = SLOT_PRIMARY, charge = 4 } }, healthMode = "ordinary" },
        { id = "cain", playerType = playerType("PLAYER_CAIN", 2), achievement = 2,
            collectibles = { 46 }, healthMode = "ordinary" },
        { id = "judas", playerType = playerType("PLAYER_JUDAS", 3), achievement = 3,
            actives = { { id = 34, slot = SLOT_PRIMARY, charge = 3 } }, healthMode = "ordinary" },
        { id = "blue_baby", playerType = playerType("PLAYER_BLUEBABY", 4), achievement = 32,
            actives = { { id = 36, slot = SLOT_PRIMARY, charge = 1 } }, healthMode = "soul_only" },
        { id = "eve", playerType = playerType("PLAYER_EVE", 5), achievement = 42,
            collectibles = { 122, 117 }, healthMode = "ordinary" },
        { id = "samson", playerType = playerType("PLAYER_SAMSON", 6), achievement = 67,
            collectibles = { 157 }, healthMode = "ordinary" },
        { id = "azazel", playerType = playerType("PLAYER_AZAZEL", 7), achievement = 79,
            pocketCards = { [POCKET_PRIMARY] = 1 }, healthMode = "ordinary" },
        { id = "lazarus", playerType = playerType("PLAYER_LAZARUS", 8), achievement = 80,
            randomPill = true, healthMode = "ordinary" },
        { id = "eden", playerType = playerType("PLAYER_EDEN", 9), achievement = 81,
            healthMode = "ordinary", highRisk = "eden_random_start" },
        { id = "the_lost", playerType = playerType("PLAYER_THELOST", 10), achievement = 82,
            actives = { { id = 609, slot = SLOT_PRIMARY, charge = 2 } }, healthMode = "lost" },
        { id = "lilith", playerType = playerType("PLAYER_LILITH", 13), achievement = 199,
            actives = { { id = 357, slot = SLOT_PRIMARY, charge = 3 } }, collectibles = { 412 }, healthMode = "ordinary" },
        { id = "keeper", playerType = playerType("PLAYER_KEEPER", 14), achievement = 251,
            healthMode = "keeper", keeperHeartCap = 6 },
        { id = "apollyon", playerType = playerType("PLAYER_APOLLYON", 15), achievement = 340,
            actives = { { id = 477, slot = SLOT_PRIMARY, charge = 6 } }, healthMode = "ordinary" },
        { id = "the_forgotten", playerType = playerType("PLAYER_THEFORGOTTEN", 16), achievement = 390,
            healthMode = "forgotten", highRisk = "requires_engine_twin" },
        { id = "bethany", playerType = playerType("PLAYER_BETHANY", 18), achievement = 404,
            collectibles = { 584 }, healthMode = "ordinary", highRisk = "soul_charge_resource" },
        { id = "jacob", playerType = playerType("PLAYER_JACOB", 19), achievement = 405,
            healthMode = "jacob", highRisk = "requires_engine_twin" },

        { id = "isaac_b", playerType = playerType("PLAYER_ISAAC_B", 21), achievement = 474, healthMode = "ordinary" },
        { id = "magdalene_b", playerType = playerType("PLAYER_MAGDALENE_B", 22), achievement = 475,
            pocketActives = { { id = 45, slot = SLOT_POCKET, charge = 4 } }, healthMode = "ordinary" },
        { id = "cain_b", playerType = playerType("PLAYER_CAIN_B", 23), achievement = 476,
            pocketActives = { { id = 710, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary" },
        { id = "judas_b", playerType = playerType("PLAYER_JUDAS_B", 24), achievement = 477,
            pocketActives = { { id = 705, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary" },
        { id = "blue_baby_b", playerType = playerType("PLAYER_BLUEBABY_B", 25), achievement = 478,
            pocketActives = { { id = 715, slot = SLOT_POCKET, charge = 0 } }, healthMode = "soul_only" },
        { id = "eve_b", playerType = playerType("PLAYER_EVE_B", 26), achievement = 479,
            pocketActives = { { id = 713, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary" },
        { id = "samson_b", playerType = playerType("PLAYER_SAMSON_B", 27), achievement = 480, healthMode = "ordinary" },
        { id = "azazel_b", playerType = playerType("PLAYER_AZAZEL_B", 28), achievement = 481,
            pocketCards = { [POCKET_PRIMARY] = 1 }, healthMode = "ordinary" },
        { id = "lazarus_b", playerType = playerType("PLAYER_LAZARUS_B", 29), achievement = 482,
            pocketActives = { { id = 711, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary" },
        { id = "eden_b", playerType = playerType("PLAYER_EDEN_B", 30), achievement = 483,
            healthMode = "ordinary", highRisk = "eden_random_start" },
        { id = "the_lost_b", playerType = playerType("PLAYER_THELOST_B", 31), achievement = 484,
            pocketCards = { [POCKET_PRIMARY] = 51 }, healthMode = "lost" },
        { id = "lilith_b", playerType = playerType("PLAYER_LILITH_B", 32), achievement = 485, healthMode = "ordinary" },
        { id = "keeper_b", playerType = playerType("PLAYER_KEEPER_B", 33), achievement = 486,
            healthMode = "keeper", keeperHeartCap = 4 },
        { id = "apollyon_b", playerType = playerType("PLAYER_APOLLYON_B", 34), achievement = 487,
            pocketActives = { { id = 706, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary" },
        { id = "the_forgotten_b", playerType = playerType("PLAYER_THEFORGOTTEN_B", 35), achievement = 488,
            healthMode = "forgotten", highRisk = "requires_engine_twin" },
        { id = "bethany_b", playerType = playerType("PLAYER_BETHANY_B", 36), achievement = 489,
            pocketActives = { { id = 712, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary",
            highRisk = "blood_charge_resource" },
        { id = "jacob_b", playerType = playerType("PLAYER_JACOB_B", 37), achievement = 490,
            pocketActives = { { id = 722, slot = SLOT_POCKET, charge = 0 } }, healthMode = "ordinary",
            highRisk = "dark_esau_engine_state" },
    }

    local profilesById = {}
    local profilesByType = {}
    for _, profile in ipairs(VANILLA_PROFILES) do
        profilesById[profile.id] = profile
        profilesByType[profile.playerType] = profile
    end

    local function currentRunSeed()
        if context.GetCurrentRunSeed then return tostring(context.GetCurrentRunSeed()) end
        if Game then
            local ok, game = pcall(Game)
            if ok and game and game.GetSeeds then
                local seeds = game:GetSeeds()
                if seeds and seeds.GetStartSeed then return tostring(seeds:GetStartSeed()) end
            end
        end
        return "0"
    end

    local function ensureSavedState()
        local root = context.GetSaveRoot and context.GetSaveRoot() or {}
        if type(root.memoryDisorder) ~= "table" then root.memoryDisorder = {} end
        local saved = root.memoryDisorder
        if saved.version ~= SAVE_VERSION or saved.runSeed ~= currentRunSeed() then
            saved.version = SAVE_VERSION
            saved.runSeed = currentRunSeed()
            saved.memoryDisorderVoidUnlockedThisRun = false
            saved.players = {}
            saved.pickedIconItems = {}
            saved.pedestalIconIds = {}
        end
        if type(saved.players) ~= "table" then saved.players = {} end
        if type(saved.pickedIconItems) ~= "table" then saved.pickedIconItems = {} end
        if type(saved.pedestalIconIds) ~= "table" then saved.pedestalIconIds = {} end
        if saved.memoryDisorderVoidUnlockedThisRun ~= true then
            saved.memoryDisorderVoidUnlockedThisRun = false
        end
        return saved
    end

    local function save()
        if context.Save then context.Save() end
    end

    local function playerKey(player)
        local initSeed = player and player.InitSeed or 0
        local controller = player and player.ControllerIndex or 0
        return tostring(initSeed) .. ":" .. tostring(controller)
    end

    local function runtimePlayerKey(player)
        if not player then return nil end
        -- Engine calls can wrap the same native player in different Lua userdata.
        -- Keep pointer identity only in runtime state, never in the save data.
        if type(GetPtrHash) == "function" then
            return tostring(GetPtrHash(player)) .. ":" .. tostring(player.InitSeed or 0)
        end
        return playerKey(player)
    end

    local function getPlayers()
        if context.GetPlayers then return context.GetPlayers() or {} end
        local result = {}
        if Game then
            local ok, game = pcall(Game)
            if ok and game and game.GetNumPlayers then
                for index = 0, game:GetNumPlayers() - 1 do
                    result[#result + 1] = Isaac.GetPlayer(index)
                end
            end
        end
        return result
    end

    local function playerExists(player)
        local value, ok = safeCall(player, "Exists")
        return not ok or value ~= false
    end

    local function playerIsDead(player)
        local value, ok = safeCall(player, "IsDead")
        return ok and value == true
    end

    local function getPlayerType(player)
        local value = safeCall(player, "GetPlayerType")
        return value or playerType("PLAYER_ISAAC", 0)
    end

    local function getCollectibleCount(player, itemId)
        local value = safeCall(player, "GetCollectibleNum", itemId, true)
        if value == nil then value = safeCall(player, "GetCollectibleNum", itemId) end
        return tonumber(value) or 0
    end

    local function pairMain(player)
        local kind = getPlayerType(player)
        local expected = ({ [20] = 19, [40] = 35, [17] = 16 })[kind]
        if not expected then return player end
        for _, method in ipairs({ "GetMainTwin", "GetOtherTwin", "GetSubPlayer" }) do
            local candidate = safeCall(player, method)
            if candidate and playerExists(candidate) and getPlayerType(candidate) == expected
                and candidate.ControllerIndex == player.ControllerIndex then return candidate end
        end
        return player
    end

    local function pairPartner(player)
        local expected = ({ [19] = 20, [35] = 40, [16] = 17 })[getPlayerType(player)]
        if not expected then return nil end
        for _, method in ipairs({ "GetOtherTwin", "GetSubPlayer" }) do
            local other = safeCall(player, method)
            if other and playerExists(other) and getPlayerType(other) == expected
                and other.ControllerIndex == player.ControllerIndex then return other end
        end
        return nil
    end

    local function hasItem(player)
        if not player or ITEM_ID <= 0 then return false end
        local value, ok = safeCall(player, "HasCollectible", ITEM_ID)
        if ok and value == true then return true end
        if getCollectibleCount(player, ITEM_ID) > 0 then return true end
        local other = pairPartner(player)
        return other ~= nil and getCollectibleCount(other, ITEM_ID) > 0
    end

    local function slotSnapshot(player, slot)
        return {
            item = numberCall(player, "GetActiveItem", slot),
            charge = numberCall(player, "GetActiveCharge", slot),
            battery = numberCall(player, "GetBatteryCharge", slot),
        }
    end

    local function captureSlots(player)
        return {
            [SLOT_PRIMARY] = slotSnapshot(player, SLOT_PRIMARY),
            [SLOT_SECONDARY] = slotSnapshot(player, SLOT_SECONDARY),
            [SLOT_POCKET] = slotSnapshot(player, SLOT_POCKET),
        }
    end

    local function capturePockets(player)
        return {
            cards = {
                [POCKET_PRIMARY] = numberCall(player, "GetCard", POCKET_PRIMARY),
                [POCKET_SECONDARY] = numberCall(player, "GetCard", POCKET_SECONDARY),
            },
            pills = {
                [POCKET_PRIMARY] = numberCall(player, "GetPill", POCKET_PRIMARY),
                [POCKET_SECONDARY] = numberCall(player, "GetPill", POCKET_SECONDARY),
            },
        }
    end

    local HEALTH_FIELDS = {
        { key = "maxHearts", getter = "GetMaxHearts", adder = "AddMaxHearts" },
        { key = "hearts", getter = "GetHearts", adder = "AddHearts" },
        { key = "soulHearts", getter = "GetSoulHearts", adder = "AddSoulHearts" },
        { key = "blackMask", getter = "GetBlackHearts" },
        { key = "boneHearts", getter = "GetBoneHearts", adder = "AddBoneHearts" },
        { key = "rottenHearts", getter = "GetRottenHearts", adder = "AddRottenHearts" },
        { key = "eternalHearts", getter = "GetEternalHearts", adder = "AddEternalHearts" },
        { key = "goldenHearts", getter = "GetGoldenHearts", adder = "AddGoldenHearts" },
        { key = "brokenHearts", getter = "GetBrokenHearts", adder = "AddBrokenHearts" },
        { key = "soulCharge", getter = "GetSoulCharge" },
        { key = "bloodCharge", getter = "GetBloodCharge" },
    }

    local function readHealth(player)
        local result = {}
        for _, field in ipairs(HEALTH_FIELDS) do
            result[field.key] = numberCall(player, field.getter)
        end
        if getPlayerType(player) == playerType("PLAYER_THEFORGOTTEN", 16) then
            local soul = pairPartner(player)
            if soul then
                result.soulHearts = numberCall(soul, "GetSoulHearts")
                result.blackMask = numberCall(soul, "GetBlackHearts")
            end
        end
        return result
    end

    local function adjustHealth(player, getter, adder, target)
        local current = numberCall(player, getter)
        local difference = (tonumber(target) or 0) - current
        if difference ~= 0 then safeCall(player, adder, difference) end
    end

    local function clearHealth(player)
        -- Clear secondary counters before their containers so no value is cloned.
        for _, field in ipairs({
            { "GetBrokenHearts", "AddBrokenHearts" },
            { "GetGoldenHearts", "AddGoldenHearts" },
            { "GetEternalHearts", "AddEternalHearts" },
            { "GetRottenHearts", "AddRottenHearts" },
            { "GetBoneHearts", "AddBoneHearts" },
            { "GetSoulHearts", "AddSoulHearts" },
            { "GetHearts", "AddHearts" },
            { "GetMaxHearts", "AddMaxHearts" },
        }) do
            local amount = numberCall(player, field[1])
            if amount ~= 0 then safeCall(player, field[2], -amount) end
        end
    end

    local function addSoulLedger(player, total, blackMask)
        total = math.max(0, tonumber(total) or 0)
        blackMask = math.max(0, tonumber(blackMask) or 0)
        for index = 0, total - 1 do
            local isBlack = math.floor(blackMask / (2 ^ math.floor(index / 2))) % 2 == 1
            if isBlack then
                safeCall(player, "AddBlackHearts", 1)
            else
                safeCall(player, "AddSoulHearts", 1)
            end
        end
    end

    local function healthMode(player, profile)
        local kind = getPlayerType(player)
        if kind == playerType("PLAYER_BETHANY", 18) then return "red_only" end
        local native = safeCall(player, "GetHealthType")
        if native == 1 then return "soul_only" end
        if native == 2 then return "lost" end
        if native == 3 then return "keeper" end
        if native == 4 then return "bone" end
        if kind == 12 or kind == 17 or kind == 24 or kind == 35 or kind == 36 or kind == 40 then return "soul_only" end
        if kind == 16 then return "bone" end
        return profile and profile.healthMode or "ordinary"
    end

    local function healthAmount(health)
        return (health.hearts or 0) + (health.soulHearts or 0) + (health.boneHearts or 0) * 2
    end

    local function restoreCharges(player, ledger)
        for _, entry in ipairs({ {"soulCharge", "SetSoulCharge", "GetSoulCharge", "AddSoulCharge"},
            {"bloodCharge", "SetBloodCharge", "GetBloodCharge", "AddBloodCharge"} }) do
            if ledger[entry[1]] ~= nil then
                local _, ok = safeCall(player, entry[2], ledger[entry[1]])
                if not ok then adjustHealth(player, entry[3], entry[4], ledger[entry[1]]) end
            end
        end
    end

    local function applyHealth(player, ledger, profile)
        ledger = ledger or readHealth(player)
        profile = profile or { healthMode = "ordinary" }
        local mode = healthMode(player, profile)
        -- Lost is alive through a native hidden half-heart. Never clear it.
        if mode == "lost" then
            if numberCall(player, "GetSoulHearts") < 1 then safeCall(player, "AddSoulHearts", 1) end
            restoreCharges(player, ledger)
            return mode
        end
        local projected = copyTable(ledger)
        local total = healthAmount(ledger)
        if mode == "soul_only" then
            projected.maxHearts, projected.hearts, projected.boneHearts = 0, 0, 0
            projected.soulHearts, projected.rottenHearts = total, 0
        elseif mode == "red_only" or mode == "keeper" then
            projected.soulHearts, projected.boneHearts = 0, 0
            projected.maxHearts = math.max(ledger.maxHearts or 0, math.ceil(total / 2) * 2)
            if mode == "keeper" then
                local limit = numberCall(player, "GetHeartLimit")
                if limit <= 0 then limit = profile.keeperHeartCap or 6 end
                projected.maxHearts = math.min(projected.maxHearts, limit, profile.keeperHeartCap or 6)
                projected.rottenHearts = 0
            end
            projected.hearts = math.min(total, projected.maxHearts)
        elseif mode == "bone" then
            projected.boneHearts = math.max(ledger.boneHearts or 0, math.ceil((ledger.maxHearts or 0) / 2))
            if projected.boneHearts == 0 and total > 0 then projected.boneHearts = 1 end
            projected.maxHearts = 0
        end
        local soulTarget = mode == "bone" and pairPartner(player) or player
        clearHealth(player)
        if soulTarget and soulTarget ~= player then clearHealth(soulTarget) end
        adjustHealth(player, "GetBrokenHearts", "AddBrokenHearts", projected.brokenHearts)
        adjustHealth(player, "GetMaxHearts", "AddMaxHearts", projected.maxHearts)
        adjustHealth(player, "GetBoneHearts", "AddBoneHearts", projected.boneHearts)
        adjustHealth(player, "GetHearts", "AddHearts", math.min(projected.hearts or 0,
            (projected.maxHearts or 0) + (projected.boneHearts or 0) * 2))
        addSoulLedger(soulTarget or player, projected.soulHearts, projected.blackMask)
        adjustHealth(player, "GetRottenHearts", "AddRottenHearts", projected.rottenHearts)
        adjustHealth(player, "GetEternalHearts", "AddEternalHearts", projected.eternalHearts)
        adjustHealth(player, "GetGoldenHearts", "AddGoldenHearts", projected.goldenHearts)
        restoreCharges(player, ledger)
        return mode
    end

    local function profileForType(value)
        return profilesByType[value] or { id = "unknown", playerType = value, healthMode = "ordinary" }
    end

    local function copySoulColors(mask, start, sourceMask, sourceStart, count)
        mask, sourceMask = mask or 0, sourceMask or 0
        for offset = 0, count - 1 do
            local bit = 2 ^ math.floor((start + offset) / 2)
            local sourceBit = 2 ^ math.floor((sourceStart + offset) / 2)
            local current = math.floor(mask / bit) % 2
            local desired = math.floor(sourceMask / sourceBit) % 2
            mask = mask + (desired - current) * bit
        end
        return mask
    end

    local function captureHealthLedger(player, state)
        local profile = state.currentProfile or profileForType(getPlayerType(player))
        if healthMode(player, profile) == "lost" then return end

        local current = readHealth(player)
        local applied = state.appliedHealth or current
        if state.healthProjection and state.healthProjection ~= "ordinary" and state.healthProjection ~= "jacob" then
            local ledger = state.healthLedger
            local delta = healthAmount(current) - healthAmount(applied)
            local preferred = state.healthProjection == "soul_only" and "soulHearts" or "hearts"
            local soulProjection = state.healthProjection == "soul_only"
            local tail = soulProjection and (state.projectedSoulTail or 0) or 0
            if delta >= 0 then
                ledger[preferred] = (ledger[preferred] or 0) + delta
                if soulProjection then tail = tail + delta end
            else
                local loss = -delta
                local tailLoss = math.min(tail, loss)
                ledger.soulHearts = math.max(0, (ledger.soulHearts or 0) - tailLoss)
                tail, loss = tail - tailLoss, loss - tailLoss
                local other = preferred == "hearts" and "soulHearts" or "hearts"
                -- Converted health was appended outside the native heart pool.
                local order = state.healthProjection == "soul_only"
                    and {"hearts", "boneHearts", "soulHearts"} or {preferred, other, "boneHearts"}
                for _, key in ipairs(order) do
                    local unit = key == "boneHearts" and 2 or 1
                    local available = (ledger[key] or 0) * unit
                    local removed = math.min(available, loss)
                    ledger[key] = math.max(0, (ledger[key] or 0) - math.ceil(removed / unit))
                    loss = loss - removed
                end
            end
            if soulProjection then
                local nativeSouls = math.max(0, math.min((ledger.soulHearts or 0) - tail, current.soulHearts - tail))
                ledger.blackMask = copySoulColors(ledger.blackMask, 0, current.blackMask, 0, nativeSouls)
                if tail > 0 then
                    ledger.blackMask = copySoulColors(ledger.blackMask, (ledger.soulHearts or 0) - tail,
                        current.blackMask, current.soulHearts - tail, tail)
                end
                state.projectedSoulTail = tail
                ledger.blackMask = (ledger.blackMask or 0) % (2 ^ math.ceil((ledger.soulHearts or 0) / 2))
            end
            if state.healthProjection == "red_only" or state.healthProjection == "keeper" then
                ledger.maxHearts = math.max(0, (ledger.maxHearts or 0) + current.maxHearts - (applied.maxHearts or 0))
            end
            for _, key in ipairs({"brokenHearts", "goldenHearts", "eternalHearts", "soulCharge", "bloodCharge"}) do
                ledger[key] = math.max(0, (ledger[key] or 0) + current[key] - (applied[key] or 0))
            end
            -- Advancing the baseline makes save + continue + next switch idempotent.
            state.appliedHealth = current
            return
        end
        if profile.healthMode == "soul_only" then
            state.healthLedger.soulHearts = math.max(0,
                (state.healthLedger.soulHearts or 0) + current.soulHearts - (applied.soulHearts or 0))
            state.healthLedger.blackMask = current.blackMask
            state.healthLedger.boneHearts = math.max(0,
                (state.healthLedger.boneHearts or 0) + current.boneHearts - (applied.boneHearts or 0))
            return
        end
        if profile.healthMode == "keeper" then
            state.healthLedger.maxHearts = math.max(0,
                (state.healthLedger.maxHearts or 0) + current.maxHearts - (applied.maxHearts or 0))
            state.healthLedger.hearts = math.max(0,
                (state.healthLedger.hearts or 0) + current.hearts - (applied.hearts or 0))
            state.healthLedger.brokenHearts = current.brokenHearts
            return
        end
        state.healthLedger = current
    end

    local function makeState(player, savedPlayer)
        local state = {
            player = player,
            key = playerKey(player),
            originalType = savedPlayer and savedPlayer.originalType or getPlayerType(player),
            currentProfile = nil,
            currentProfileId = savedPlayer and savedPlayer.currentProfileId or nil,
            transition = nil,
            armedForNextRoom = savedPlayer and savedPlayer.armedForNextRoom ~= false or true,
            temporaryCopies = copyTable(savedPlayer and savedPlayer.temporaryCopies or {}),
            permanentCounts = copyTable(savedPlayer and savedPlayer.permanentCounts or {}),
            temporaryActiveSlots = copyTable(savedPlayer and savedPlayer.temporaryActiveSlots or {}),
            temporaryPocketCards = copyTable(savedPlayer and savedPlayer.temporaryPocketCards or {}),
            permanentSlots = copyTable(savedPlayer and savedPlayer.permanentSlots or captureSlots(player)),
            permanentPockets = copyTable(savedPlayer and savedPlayer.permanentPockets or capturePockets(player)),
            healthLedger = copyTable(savedPlayer and savedPlayer.healthLedger or readHealth(player)),
            appliedHealth = savedPlayer and savedPlayer.appliedHealth and copyTable(savedPlayer.appliedHealth) or nil,
            healthProjection = savedPlayer and savedPlayer.healthProjection or nil,
            projectedSoulTail = savedPlayer and savedPlayer.projectedSoulTail or 0,
            pairSnapshots = copyTable(savedPlayer and savedPlayer.pairSnapshots or {}),
            pairProxies = copyTable(savedPlayer and savedPlayer.pairProxies or {}),
            currentIconId = savedPlayer and savedPlayer.currentIconId or FALLBACK_ICON_ID,
            switchSerial = savedPlayer and savedPlayer.switchSerial or 0,
        }
        if state.currentProfileId then state.currentProfile = profilesById[state.currentProfileId] end
        return state
    end

    local function persistState(state)
        local saved = ensureSavedState()
        saved.players[state.key] = {
            active = true,
            originalType = state.originalType,
            currentProfileId = state.currentProfile and state.currentProfile.id or state.currentProfileId,
            armedForNextRoom = state.armedForNextRoom,
            temporaryCopies = copyTable(state.temporaryCopies),
            permanentCounts = copyTable(state.permanentCounts),
            temporaryActiveSlots = copyTable(state.temporaryActiveSlots),
            temporaryPocketCards = copyTable(state.temporaryPocketCards),
            permanentSlots = copyTable(state.permanentSlots),
            permanentPockets = copyTable(state.permanentPockets),
            healthLedger = copyTable(state.healthLedger),
            appliedHealth = copyTable(state.appliedHealth),
            healthProjection = state.healthProjection,
            projectedSoulTail = state.projectedSoulTail,
            pairSnapshots = copyTable(state.pairSnapshots),
            pairProxies = copyTable(state.pairProxies),
            currentIconId = state.currentIconId,
            switchSerial = state.switchSerial,
        }
    end

    local function isAchievementUnlocked(achievement)
        if not achievement then return true end
        if context.IsAchievementUnlocked then
            local ok, value = pcall(context.IsAchievementUnlocked, achievement)
            return ok and value == true
        end
        if Isaac and Isaac.GetPersistentGameData then
            local ok, value = pcall(function()
                local persistent = Isaac.GetPersistentGameData()
                return persistent and persistent:Unlocked(achievement)
            end)
            return ok and value == true
        end
        return false
    end

    local function buildVanillaCandidates()
        local result = {}
        for _, profile in ipairs(VANILLA_PROFILES) do
            if not profile.achievement or isAchievementUnlocked(profile.achievement) then
                result[#result + 1] = profile
            end
        end
        return result
    end

    local function buildAllCandidates(player)
        local result = buildVanillaCandidates(player)
        for _, profile in ipairs(Neverbirth.MemoryDisorderCharacterProfiles) do
            local compatible = type(profile) == "table" and profile.id and profile.playerType ~= nil
            if compatible and type(profile.isCompatible) == "function" then
                local ok, value = pcall(profile.isCompatible, player, context)
                compatible = ok and value == true
            end
            if compatible then result[#result + 1] = profile end
        end
        return result
    end

    local function findProfile(id)
        if profilesById[id] then return profilesById[id] end
        for _, profile in ipairs(Neverbirth.MemoryDisorderCharacterProfiles) do
            if profile.id == id then return profile end
        end
        return nil
    end

    local function seedHash(text)
        local value = 2166136261
        text = tostring(text or "")
        for index = 1, #text do
            value = (value * 16777619 + string.byte(text, index)) % 2147483647
        end
        return math.max(1, value)
    end

    local function randomIndex(count, player, salt)
        if count <= 1 then return 1 end
        local seed = seedHash(currentRunSeed() .. ":" .. playerKey(player) .. ":" .. tostring(salt or 0))
        local ok, value = pcall(function()
            local rng = RNG()
            rng:SetSeed(seed, 35)
            return rng:RandomInt(count) + 1
        end)
        if ok and type(value) == "number" and value >= 1 and value <= count then return value end
        -- Only used by the isolated Lua test harness or if the engine RNG
        -- constructor is unavailable. The fallback remains seed-deterministic.
        return (seed % count) + 1
    end

    local function updatePermanentSlots(player, state)
        for _, slot in ipairs({ SLOT_PRIMARY, SLOT_SECONDARY, SLOT_POCKET }) do
            local current = slotSnapshot(player, slot)
            local temporary = state.temporaryActiveSlots[slot]
            if not temporary or current.item ~= temporary.id then
                state.permanentSlots[slot] = current
            end
        end
        for _, slot in ipairs({ POCKET_PRIMARY, POCKET_SECONDARY }) do
            local temporary = state.temporaryPocketCards[slot]
            local currentCard = numberCall(player, "GetCard", slot)
            local currentPill = numberCall(player, "GetPill", slot)
            if not temporary or (currentCard ~= temporary.card and currentPill ~= temporary.pill) then
                state.permanentPockets.cards[slot] = currentCard
                state.permanentPockets.pills[slot] = currentPill
            end
        end
    end

    local function reconcileTemporaryCopies(player, state)
        for itemId, temporaryCount in pairs(state.temporaryCopies) do
            local baseline = tonumber(state.permanentCounts[itemId]) or 0
            local actual = getCollectibleCount(player, tonumber(itemId) or itemId)
            local expected = baseline + temporaryCount
            if actual > expected then
                state.permanentCounts[itemId] = baseline + (actual - expected)
            elseif actual < expected then
                local missing = expected - actual
                local removedTemporary = math.min(temporaryCount, missing)
                state.temporaryCopies[itemId] = temporaryCount - removedTemporary
                missing = missing - removedTemporary
                if missing > 0 then state.permanentCounts[itemId] = math.max(0, baseline - missing) end
            end
        end
    end

    local function removeSlotItem(player, itemId, slot)
        if not itemId or itemId == 0 then return end
        safeCall(player, "RemoveCollectible", itemId, true, slot, false)
        if numberCall(player, "GetActiveItem", slot) == itemId then
            safeCall(player, "RemoveCollectibleFromSlot", slot)
        end
    end

    local function restoreSlot(player, slot, snapshot)
        snapshot = snapshot or { item = 0, charge = 0, battery = 0 }
        local current = numberCall(player, "GetActiveItem", slot)
        if current ~= 0 and current ~= snapshot.item then
            removeSlotItem(player, current, slot)
        end
        if snapshot.item and snapshot.item ~= 0 then
            local after = numberCall(player, "GetActiveItem", slot)
            if after ~= snapshot.item then
                safeCall(player, "AddCollectible", snapshot.item, snapshot.charge or 0, false, slot)
            end
            safeCall(player, "SetActiveCharge", (snapshot.charge or 0) + (snapshot.battery or 0), slot)
        end
    end

    local function removeTemporaryComponents(player, state)
        updatePermanentSlots(player, state)
        reconcileTemporaryCopies(player, state)

        for slot, temporary in pairs(state.temporaryActiveSlots) do
            local current = numberCall(player, "GetActiveItem", slot)
            if current == temporary.id then
                removeSlotItem(player, temporary.id, slot)
                local temporaryCount = tonumber(state.temporaryCopies[temporary.id]
                    or state.temporaryCopies[tostring(temporary.id)]) or 0
                state.temporaryCopies[tostring(temporary.id)] = nil
                if temporaryCount > 0 then state.temporaryCopies[temporary.id] = temporaryCount - 1 end
            end
        end
        for itemId, count in pairs(state.temporaryCopies) do
            for _ = 1, math.max(0, tonumber(count) or 0) do
                safeCall(player, "RemoveCollectible", tonumber(itemId) or itemId)
            end
        end
        for slot, temporary in pairs(state.temporaryPocketCards) do
            local card = numberCall(player, "GetCard", slot)
            local pill = numberCall(player, "GetPill", slot)
            if temporary.card and card == temporary.card then safeCall(player, "SetCard", slot, 0) end
            if temporary.pill and pill == temporary.pill then safeCall(player, "SetPill", slot, 0) end
        end

        state.temporaryCopies = {}
        state.permanentCounts = {}
        state.temporaryActiveSlots = {}
        state.temporaryPocketCards = {}

        for _, slot in ipairs({ SLOT_PRIMARY, SLOT_SECONDARY, SLOT_POCKET }) do
            restoreSlot(player, slot, state.permanentSlots[slot])
        end
        for _, slot in ipairs({ POCKET_PRIMARY, POCKET_SECONDARY }) do
            safeCall(player, "SetCard", slot, state.permanentPockets.cards[slot] or 0)
            safeCall(player, "SetPill", slot, state.permanentPockets.pills[slot] or 0)
        end
    end

    local function temporaryCount(state, itemId)
        return tonumber(state.temporaryCopies[itemId] or state.temporaryCopies[tostring(itemId)]) or 0
    end

    local function recordTemporaryCopy(state, itemId, before, after)
        local added = math.max(0, (after or 0) - (before or 0))
        if added <= 0 then return 0 end
        state.permanentCounts[tostring(itemId)] = nil
        state.permanentCounts[itemId] = before or 0
        local tracked = temporaryCount(state, itemId)
        state.temporaryCopies[tostring(itemId)] = nil
        state.temporaryCopies[itemId] = tracked + added
        return added
    end

    local function addTemporaryCollectible(player, state, itemId, charge, slot)
        local before = getCollectibleCount(player, itemId)
        safeCall(player, "AddCollectible", itemId, charge or 0, false, slot)
        local after = getCollectibleCount(player, itemId)
        if after <= before then return false end
        recordTemporaryCopy(state, itemId, before, after)
        if slot ~= nil then state.temporaryActiveSlots[slot] = { id = itemId } end
        return true
    end

    local function addProfileComponents(player, state, profile)
        local required = {}
        local function nextRequired(itemId)
            required[itemId] = (required[itemId] or 0) + 1
            return required[itemId]
        end

        for _, itemId in ipairs(profile.collectibles or {}) do
            local desired = nextRequired(itemId)
            if temporaryCount(state, itemId) < desired then
                addTemporaryCollectible(player, state, itemId, 0, nil)
            end
        end
        for _, active in ipairs(profile.actives or {}) do
            local slot = active.slot or SLOT_PRIMARY
            local desired = nextRequired(active.id)
            if temporaryCount(state, active.id) < desired then
                addTemporaryCollectible(player, state, active.id, active.charge or 0, slot)
            else
                state.temporaryActiveSlots[slot] = { id = active.id }
                safeCall(player, "SetActiveCharge", active.charge or 0, slot)
            end
        end
        for _, active in ipairs(profile.pocketActives or {}) do
            local slot = active.slot or SLOT_POCKET
            local desired = nextRequired(active.id)
            if temporaryCount(state, active.id) < desired then
                local before = getCollectibleCount(player, active.id)
                safeCall(player, "SetPocketActiveItem", active.id, slot, false)
                local after = getCollectibleCount(player, active.id)
                if after > before then recordTemporaryCopy(state, active.id, before, after) end
            end
            state.temporaryActiveSlots[slot] = { id = active.id }
            safeCall(player, "SetActiveCharge", active.charge or 0, slot)
        end
        for slot, card in pairs(profile.pocketCards or {}) do
            safeCall(player, "SetCard", slot, card)
            state.temporaryPocketCards[slot] = { card = card }
        end
        if profile.randomPill then
            local pill = 0
            if context.GetRandomPill then
                pill = context.GetRandomPill(player, state.switchSerial) or 0
            elseif Game then
                local ok, value = pcall(function()
                    local game = Game()
                    local pool = game:GetItemPool()
                    return pool:GetPill(seedHash(playerKey(player) .. ":" .. state.switchSerial))
                end)
                if ok then pill = value or 0 end
            end
            if pill ~= 0 then
                safeCall(player, "SetPill", POCKET_PRIMARY, pill)
                state.temporaryPocketCards[POCKET_PRIMARY] = { pill = pill }
            end
        end
        if type(profile.onApply) == "function" then
            local ok, errorMessage = pcall(profile.onApply, player, state, context)
            if not ok then diagnosticOnce("profile-apply-" .. tostring(profile.id), "profile " .. tostring(profile.id) .. " apply failed: " .. tostring(errorMessage)) end
        end
    end

    local function getCollectibleConfigs()
        if context.GetCollectibleConfigs then return context.GetCollectibleConfigs() end
        if Isaac and Isaac.GetItemConfig then
            local config = Isaac.GetItemConfig()
            if config and config.GetCollectibles then return config:GetCollectibles() end
        end
        return nil
    end

    local function buildIconCandidates()
        local result = {}
        runtime.iconConfigs = {}
        runtime.collectibleGfx = {}
        local configs = getCollectibleConfigs()
        local function consider(config)
            if not config then return end
            local id = tonumber(config.ID)
            local gfx = config.GfxFileName or config.GfxFile or config.gfx
            local hidden = config.Hidden == true or config.Hidden == 1
            if id and id > 0 and type(gfx) == "string" and gfx ~= "" then
                runtime.collectibleGfx[id] = gfx
            end
            if id and id > 0 and id ~= ITEM_ID and not hidden
                and config.Type == (ItemType and ItemType.ITEM_PASSIVE or 1)
                and type(gfx) == "string" and gfx ~= "" then
                result[#result + 1] = id
                runtime.iconConfigs[id] = config
            end
        end
        -- ItemConfigList:Get returns opaque userdata. Use Size only for the ID range
        -- and GetCollectible for typed ItemConfig.Item values (including modded IDs).
        if configs and configs.Size then
            local itemConfig = Isaac and Isaac.GetItemConfig and Isaac.GetItemConfig()
            if itemConfig then
                for id = 1, configs.Size - 1 do consider(itemConfig:GetCollectible(id)) end
            end
        elseif type(configs) == "table" then
            for _, config in pairs(configs) do consider(config) end
        end
        table.sort(result)
        runtime.iconCandidates = result
        return result
    end

    local function rememberPickedIcon(itemId)
        itemId = tonumber(itemId)
        if not itemId or itemId <= 0 then return end
        local seen = ensureSavedState().pickedIconItems
        local key = tostring(itemId) -- JSON object keys must survive a save/load round trip.
        if not seen[key] then
            seen[key] = true
            runtime.iconHistoryDirty = true
        end
    end

    local function importIconHistory(player)
        if not player then return end
        local history = safeCall(player, "GetHistory")
        local entries = safeCall(history, "GetCollectiblesHistory")
        for _, entry in ipairs(type(entries) == "table" and entries or {}) do
            if safeCall(entry, "IsTrinket") ~= true then
                rememberPickedIcon(safeCall(entry, "GetItemID"))
            end
        end
        -- Also include starting items and real inventory missing from the history HUD.
        for _, id in ipairs(runtime.iconCandidates or buildIconCandidates()) do
            if numberCall(player, "GetCollectibleNum", id, true) > 0 then rememberPickedIcon(id) end
        end
        runtime.iconHistoryPlayers[runtimePlayerKey(player)] = true
    end

    local function syncIconHistory()
        for _, player in ipairs(getPlayers()) do importIconHistory(player) end
    end

    local function iconIsEligible(id)
        return runtime.iconConfigs[id] ~= nil and not ensureSavedState().pickedIconItems[tostring(id)]
    end

    local function selectIcon(player, salt, previous)
        local available, alternatives = {}, {}
        for _, id in ipairs(runtime.iconCandidates or buildIconCandidates()) do
            if iconIsEligible(id) then
                available[#available + 1] = id
                if id ~= previous then alternatives[#alternatives + 1] = id end
            end
        end
        if #alternatives > 0 then available = alternatives end
        if #available == 0 then return FALLBACK_ICON_ID end
        return available[randomIndex(#available, player, salt)]
    end

    local function chooseIcon(player)
        syncIconHistory()
        local state = runtime.states[runtimePlayerKey(pairMain(player))]
        local salt = "icon:" .. runtime.roomSerial .. ":" .. (state and state.switchSerial or 0)
        local selected = selectIcon(player, salt, state and state.currentIconId)
        if state then state.currentIconId = selected end
        return selected
    end

    local function iconGfx(id)
        local config = runtime.iconConfigs[id]
        return config and (config.GfxFileName or config.GfxFile or config.gfx) or QUESTION_MARK_GFX
    end

    local function pickupIconRecord(pickup)
        local data = safeCall(pickup, "GetData")
        return data and data.NeverbirthMemoryDisorderIcon, data
    end

    local function pickupIsBlind(pickup)
        if safeCall(pickup, "IsBlind") == true then return true end
        if Game and LevelCurse then
            local level = Game():GetLevel()
            local curses = numberCall(level, "GetCurses")
            return (curses & (LevelCurse.CURSE_OF_BLIND or 0)) ~= 0
        end
        return false
    end

    local function updatePickupIcon(pickup)
        if not pickup then return end
        local record, data = pickupIconRecord(pickup)
        if pickup.SubType ~= ITEM_ID then
            if record then
                -- A rerolled pedestal must stop wearing our old disguise.
                -- ReloadGraphics is not part of REPENTOGON 1.0.12a.
                -- Restore only a layer still bearing our replacement; otherwise
                -- preserve the engine's new artwork (including blind/empty states).
                local sprite = safeCall(pickup, "GetSprite")
                local layer = safeCall(sprite, "GetLayer", 1)
                local actual = safeCall(layer, "GetSpritesheetPath")
                local gfx = runtime.collectibleGfx[pickup.SubType]
                if gfx and record.appliedGfx and actual == record.appliedGfx then
                    if pickupIsBlind(pickup) then gfx = QUESTION_MARK_GFX end
                    local _, replaced = safeCall(sprite, "ReplaceSpritesheet", 1, gfx)
                    if replaced then safeCall(sprite, "LoadGraphics") end
                end
                data.NeverbirthMemoryDisorderIcon = nil
            end
            return
        end
        if not data then return end
        for _, player in ipairs(getPlayers()) do
            if not runtime.iconHistoryPlayers[runtimePlayerKey(player)] then importIconHistory(player) end
        end
        local roomSeed = Game and numberCall(Game():GetRoom(), "GetSpawnSeed") or 0
        local key = tostring(roomSeed) .. ":" .. tostring(pickup.InitSeed)
        local savedIcons = ensureSavedState().pedestalIconIds
        if not record and savedIcons[key] ~= nil then record = { id = savedIcons[key] } end
        if not record or (record.id ~= FALLBACK_ICON_ID and not iconIsEligible(record.id)) then
            local salt = "pedestal:" .. key
            local previous = record and record.id
            record = { id = selectIcon(nil, salt, previous) }
            savedIcons[key] = record.id
            runtime.iconHistoryDirty = true
        end
        data.NeverbirthMemoryDisorderIcon = record
    end

    local function renderPickupIcon(pickup)
        if not pickup or pickup.SubType ~= ITEM_ID then return end
        local record = pickupIconRecord(pickup)
        if not record then return end
        local blind = pickupIsBlind(pickup)
        local gfx = (blind or not iconIsEligible(record.id)) and QUESTION_MARK_GFX or iconGfx(record.id)
        local sprite = safeCall(pickup, "GetSprite")
        -- REPENTOGON layer state lets us notice engine graphic reloads without
        -- reloading a spritesheet on every render. Never restart its animation.
        local layer = safeCall(sprite, "GetLayer", 1)
        local actual = safeCall(layer, "GetSpritesheetPath")
        if actual ~= gfx and (actual ~= nil or record.appliedGfx ~= gfx) then
            local _, replaced = safeCall(sprite, "ReplaceSpritesheet", 1, gfx)
            if replaced then
                safeCall(sprite, "LoadGraphics")
                record.appliedGfx = gfx
            end
        end
    end

    local function capturePickupIcon(pickup, collider)
        if not pickup or pickup.SubType ~= ITEM_ID then return end
        local player = safeCall(collider, "ToPlayer")
        local data = safeCall(player, "GetData")
        local record = pickupIconRecord(pickup)
        if data and record then data.NeverbirthMemoryDisorderHeldIcon = record.id end
        -- No return: this callback never authorizes, cancels or grants a pickup.
    end

    local function renderHeldIcon(player)
        local queued = player and player.QueuedItem
        if not queued or not queued.Item or queued.Item.ID ~= ITEM_ID then return end
        local data = safeCall(player, "GetData")
        local state = runtime.states[runtimePlayerKey(pairMain(player))]
        local id = data and data.NeverbirthMemoryDisorderHeldIcon or (state and state.currentIconId)
        if not iconIsEligible(id) then id = state and state.currentIconId end
        if not iconIsEligible(id) then id = FALLBACK_ICON_ID end
        local sprite = safeCall(player, "GetHeldSprite")
        local gfx = iconGfx(id)
        local layer = safeCall(sprite, "GetLayer", 0)
        if safeCall(layer, "GetSpritesheetPath") ~= gfx then
            local _, replaced = safeCall(sprite, "ReplaceSpritesheet", 0, gfx)
            if replaced then safeCall(sprite, "LoadGraphics") end
        end
    end

    local eidIconOwner
    local function registerIconDescription()
        if not EID or EID == eidIconOwner or type(EID.addDescriptionModifier) ~= "function"
            or type(EID.createItemIconObject) ~= "function" then return end
        EID:addDescriptionModifier("neverbirth Memory Disorder icon", function(desc)
            return desc.ObjType == 5 and desc.ObjVariant == 100 and desc.ObjSubType == ITEM_ID
        end, function(desc)
            local record = desc.Entity and pickupIconRecord(desc.Entity)
            local player = desc.Player or desc.PlayerEntity or EID.player
            local state = player and runtime.states[runtimePlayerKey(pairMain(player))]
            local id = record and record.id or (state and state.currentIconId)
            if desc.Entity and pickupIsBlind(desc.Entity) then id = FALLBACK_ICON_ID end
            if iconIsEligible(id) then
                desc.Icon = EID:createItemIconObject("Collectible" .. id)
            elseif EID.InlineIcons then
                desc.Icon = EID.InlineIcons.QuestionMark
            end
            return desc
        end)
        eidIconOwner = EID
    end

    local function collectibleSnapshot(player)
        local list, ok = safeCall(player, "GetCollectiblesList")
        if not ok or type(list) ~= "table" then return nil end
        local result = {}
        for id, count in pairs(list) do
            id, count = tonumber(id), tonumber(count)
            if id and count and id > 0 and count > 0 then result[tostring(id)] = count end
        end
        return result
    end

    local function snapshotPartner(player)
        -- Normal Forgotten forms share inventory and are native subplayers,
        -- not co-op actors. Their combined health is handled by read/applyHealth.
        if getPlayerType(player) == 16 then return nil end
        local other = pairPartner(player)
        if not other then return nil end
        local inventory = collectibleSnapshot(other)
        if not inventory then return nil, "partner inventory API unavailable" end
        return {
            player = other, runtimeKey = runtimePlayerKey(other), mainType = getPlayerType(player),
            snapshot = { playerType = getPlayerType(other), health = readHealth(other),
                collectibles = inventory, slots = captureSlots(other), pockets = capturePockets(other),
                smeltedTrinkets = copyTable(safeCall(other, "GetSmeltedTrinkets")),
                trinkets = { numberCall(other, "GetTrinket", 0), numberCall(other, "GetTrinket", 1) } },
        }
    end

    local function canSwitchPair(player, targetType)
        if getPlayerType(player) == targetType then return true end
        if (targetType == 19 or targetType == 35)
            and not (PlayerManager and type(PlayerManager.RemoveCoPlayer) == "function") then return false end
        local other = pairPartner(player)
        if other and getPlayerType(player) ~= 16 then
            if not (PlayerManager and type(PlayerManager.RemoveCoPlayer) == "function") then
                diagnosticOnce("pair-remove-api", "Pair switch skipped: safe extra-player removal API unavailable")
                return false
            end
            if not collectibleSnapshot(other) then
                diagnosticOnce("pair-inventory-api", "Pair switch skipped: cannot preserve partner inventory")
                return false
            end
        end
        return true
    end

    local function parkPartner(player, state, prior)
        if not prior then return end
        local key = tostring(prior.mainType)
        state.pairSnapshots[key] = prior.snapshot
        -- Carry the item's ownership while its original holder is parked. The
        -- rest of that partner's inventory remains in its own saved snapshot.
        local count = tonumber(prior.snapshot.collectibles[tostring(ITEM_ID)]) or 0
        if count > 0 then
            local before = getCollectibleCount(player, ITEM_ID)
            for _ = 1, count do safeCall(player, "AddCollectible", ITEM_ID, 0, false) end
            state.pairProxies[key] = (state.pairProxies[key] or 0) + math.max(0, getCollectibleCount(player, ITEM_ID) - before)
        end
    end

    local function removeFormerPartner(player, prior)
        if not prior or prior.mainType == 16 then return true end
        -- Reacquire a live wrapper after ChangePlayerType. Never call Remove on
        -- a stale userdata, the main player, or an unrelated co-op participant.
        for _, candidate in ipairs(getPlayers()) do
            if runtimePlayerKey(candidate) == prior.runtimeKey and playerExists(candidate)
                and getPlayerType(candidate) == prior.snapshot.playerType
                and runtimePlayerKey(candidate) ~= runtimePlayerKey(player) then
                local ok = pcall(PlayerManager.RemoveCoPlayer, candidate)
                if not ok then return false end
            end
        end
        for _, candidate in ipairs(getPlayers()) do
            if runtimePlayerKey(candidate) == prior.runtimeKey and playerExists(candidate) then return false end
        end
        return true
    end

    local function ensureNativePair(player)
        local kind = getPlayerType(player)
        if kind ~= 19 and kind ~= 35 then return true end
        if pairPartner(player) then return true end
        -- A surviving former partner can prevent native target-pair creation.
        -- Retry only after that exact former partner has been removed.
        safeCall(player, "ChangePlayerType", kind)
        return pairPartner(player) ~= nil
    end

    local function restorePartner(player, state, losingItem)
        local other = pairPartner(player)
        if not other then return end
        local key = tostring(getPlayerType(player))
        local saved = state.pairSnapshots[key]
        if not saved then return end -- First native creation supplies its kit.
        local desired = copyTable(saved.collectibles)
        local proxy = tonumber(state.pairProxies[key]) or 0
        local returned = math.min(proxy, getCollectibleCount(player, ITEM_ID))
        if proxy > 0 then
            for _ = 1, returned do safeCall(player, "RemoveCollectible", ITEM_ID) end
            desired[tostring(ITEM_ID)] = losingItem and 0 or returned
            state.pairProxies[key] = nil
        elseif losingItem then
            desired[tostring(ITEM_ID)] = 0
        end
        for _, slot in ipairs({ SLOT_PRIMARY, SLOT_SECONDARY, SLOT_POCKET }) do
            restoreSlot(other, slot, saved.slots[slot] or saved.slots[tostring(slot)])
        end
        local actual = collectibleSnapshot(other) or {}
        for id, count in pairs(actual) do
            for _ = 1, math.max(0, count - (desired[id] or 0)) do safeCall(other, "RemoveCollectible", tonumber(id)) end
        end
        for id, count in pairs(desired) do
            for _ = 1, math.max(0, count - getCollectibleCount(other, tonumber(id))) do
                safeCall(other, "AddCollectible", tonumber(id), 0, false)
            end
        end
        for _, slot in ipairs({ POCKET_PRIMARY, POCKET_SECONDARY }) do
            safeCall(other, "SetCard", slot, saved.pockets.cards[slot] or saved.pockets.cards[tostring(slot)] or 0)
            safeCall(other, "SetPill", slot, saved.pockets.pills[slot] or saved.pockets.pills[tostring(slot)] or 0)
        end
        for slot = 0, 1 do
            local current = numberCall(other, "GetTrinket", slot)
            if current ~= 0 then safeCall(other, "TryRemoveTrinket", current) end
        end
        for _, id in ipairs(saved.trinkets or {}) do if id ~= 0 then safeCall(other, "AddTrinket", id, false) end end
        local smelted = safeCall(other, "GetSmeltedTrinkets") or {}
        for id, counts in pairs(saved.smeltedTrinkets or {}) do
            local current = smelted[tonumber(id)] or smelted[tostring(id)] or {}
            for _, entry in ipairs({ {"trinketAmount", 0}, {"goldenTrinketAmount", 32768} }) do
                for _ = 1, math.max(0, (counts[entry[1]] or 0) - (current[entry[1]] or 0)) do
                    safeCall(other, "AddSmeltedTrinket", tonumber(id) + entry[2], false)
                end
            end
        end
        applyHealth(other, saved.health, profileForType(saved.playerType))
        state.pairSnapshots[key] = nil -- A live partner is now authoritative.
    end

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

    local VALID_TERMINALS = {
        hush = true,
        bossrush = true,
        mega_satan = true,
        ultra_greedier = true,
    }

    local function hasExistingVoidPortal()
        if context.HasExistingVoidPortal then return context.HasExistingVoidPortal() == true end
        if not (Game and GridEntityType and GridEntityType.GRID_TRAPDOOR) then return false end
        local ok, found = pcall(function()
            local room = Game():GetRoom()
            for index = 0, room:GetGridSize() - 1 do
                local grid = room:GetGridEntity(index)
                if grid and grid:GetType() == GridEntityType.GRID_TRAPDOOR and grid.VarData == 1 then
                    return true
                end
            end
            return false
        end)
        if ok then return found == true end
        return false
    end

    local function findVoidPortalPosition(room)
        local centerIndex = room:GetGridIndex(room:GetCenterPos())
        local width = room:GetGridWidth()
        local offsets = { 0, -1, 1, -width, width, -width - 1, -width + 1, width - 1, width + 1 }
        for _, offset in ipairs(offsets) do
            local index = centerIndex + offset
            if index >= 0 and index < room:GetGridSize() and not room:GetGridEntity(index) then
                local position = room:GetGridPosition(index)
                if not room.GetGridCollisionAtPos or room:GetGridCollisionAtPos(position) == 0 then
                    return position
                end
            end
        end
        return nil
    end

    local function spawnVoidPortal(roomContext)
        if context.SpawnVoidPortal then return context.SpawnVoidPortal(roomContext) end
        if not (Isaac and Isaac.GridSpawn and Game and GridEntityType and GridEntityType.GRID_TRAPDOOR) then return nil end
        local game = Game()
        local room = game:GetRoom()
        local position = findVoidPortalPosition(room)
        if not position then return nil end
        local portal = Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 1, position, true)
        if not portal then return nil end
        portal.VarData = 1
        local sprite = portal.GetSprite and portal:GetSprite() or nil
        if sprite then sprite:Load("gfx/grid/voidtrapdoor.anm2", true) end
        return portal
    end

    local function trySpawnVoidPortal(roomContext)
        local saved = ensureSavedState()
        if not saved.memoryDisorderVoidUnlockedThisRun then return false end
        if type(roomContext) ~= "table" or not VALID_TERMINALS[roomContext.kind] or roomContext.clear ~= true then return false end
        if runtime.portalSpawnedThisRoom or hasExistingVoidPortal() then return false end
        local portal = spawnVoidPortal(roomContext)
        if not portal then return false end
        runtime.portalSpawnedThisRoom = true
        return true
    end

    local function liveRoomContext()
        if context.GetRoomContext then return context.GetRoomContext(runtime.terminalKind) end
        if not Game then return nil end
        local ok, result = pcall(function()
            local game = Game()
            local room = game:GetRoom()
            local level = game:GetLevel()
            local kind = runtime.terminalKind
            if RoomType and room:GetType() == RoomType.ROOM_BOSSRUSH then kind = "bossrush" end
            if not kind and game.IsGreedMode and game:IsGreedMode() and LevelStage
                and level:GetStage() == LevelStage.STAGE7_GREED and RoomType and room:GetType() == RoomType.ROOM_BOSS then
                kind = "ultra_greedier"
            end
            if not kind and LevelStage and level:GetStage() == LevelStage.STAGE4_3
                and RoomType and room:GetType() == RoomType.ROOM_BOSS then
                kind = "hush"
            end
            return { kind = kind, clear = room:IsClear() }
        end)
        return ok and result or nil
    end

    local function onNpcDeath(npc)
        if not npc or not EntityType then return end
        if EntityType.ENTITY_HUSH and npc.Type == EntityType.ENTITY_HUSH then
            runtime.terminalKind = "hush"
        elseif (EntityType.ENTITY_MEGA_SATAN and npc.Type == EntityType.ENTITY_MEGA_SATAN)
            or (EntityType.ENTITY_MEGA_SATAN_2 and npc.Type == EntityType.ENTITY_MEGA_SATAN_2) then
            runtime.terminalKind = "mega_satan"
        elseif EntityType.ENTITY_ULTRA_GREED and npc.Type == EntityType.ENTITY_ULTRA_GREED then
            local greedier = Game and Game().Difficulty == (Difficulty and Difficulty.DIFFICULTY_GREEDIER or 3)
            if greedier then runtime.terminalKind = "ultra_greedier" end
        end
    end

    local function onPostUpdate()
        registerIconDescription()
        local livePlayers = {}
        local stateChanged = false
        for _, player in ipairs(getPlayers()) do
            if not runtime.iconHistoryPlayers[runtimePlayerKey(player)] then importIconHistory(player) end
            player = pairMain(player)
            local key = runtimePlayerKey(player)
            livePlayers[key] = true
            onOwnershipUpdate(player)
            local state = runtime.states[key]
            if state and runtime.iconHistoryDirty and not iconIsEligible(state.currentIconId) then
                chooseIcon(player)
                persistState(state)
            end
            if state and playerIsDead(player) and state.transition then
                state.transition = nil
                persistState(state)
                stateChanged = true
            end
        end
        for key, state in pairs(runtime.states) do
            if not livePlayers[key] or not playerExists(state.player) then
                persistState(state)
                runtime.states[key] = nil
                stateChanged = true
            end
        end
        if stateChanged or runtime.iconHistoryDirty then save() end
        runtime.iconHistoryDirty = false
        advanceFrame()
        local roomContext = liveRoomContext()
        if roomContext then trySpawnVoidPortal(roomContext) end
    end

    local function onNewRoom()
        syncIconHistory()
        runtime.portalSpawnedThisRoom = false
        runtime.terminalKind = nil
        for _, player in ipairs(getPlayers()) do onOwnershipUpdate(player) end
        beginRoomTransitions("room:" .. tostring(runtime.roomSerial + 1))
    end

    local function onGameStarted(continued)
        runtime.states = {}
        runtime.roomSerial = 0
        runtime.portalSpawnedThisRoom = false
        runtime.terminalKind = nil
        runtime.diagnostics = {}
        runtime.iconCandidates = nil
        runtime.iconConfigs = {}
        runtime.collectibleGfx = {}
        runtime.iconHistoryPlayers = {}
        runtime.iconHistoryDirty = false
        local root = context.GetSaveRoot and context.GetSaveRoot() or {}
        if not continued then
            root.memoryDisorder = {
                version = SAVE_VERSION,
                runSeed = currentRunSeed(),
                memoryDisorderVoidUnlockedThisRun = false,
                players = {},
                pickedIconItems = {},
                pedestalIconIds = {},
            }
            save()
        else
            ensureSavedState()
            syncIconHistory()
            for _, player in ipairs(getPlayers()) do onOwnershipUpdate(player) end
        end
        syncIconHistory()
    end

    local function onPreGameExit()
        syncIconHistory()
        for _, state in pairs(runtime.states) do
            local player = state.player
            captureHealthLedger(player, state)
            reconcileTemporaryCopies(player, state)
            updatePermanentSlots(player, state)
            persistState(state)
        end
        save()
        runtime.states = {}
    end

    local api = {
        Constants = {
            ITEM_ID = ITEM_ID,
            FALLBACK_ICON_ID = FALLBACK_ICON_ID,
            TRANSITION_SWITCH_FRAME = TRANSITION_SWITCH_FRAME,
            TRANSITION_END_FRAME = TRANSITION_END_FRAME,
        },
        MemoryDisorderCharacterProfiles = Neverbirth.MemoryDisorderCharacterProfiles,
        VanillaProfiles = VANILLA_PROFILES,
        BuildVanillaCandidates = buildVanillaCandidates,
        BuildAllCandidates = buildAllCandidates,
        FindProfile = findProfile,
        OnOwnershipUpdate = onOwnershipUpdate,
        ResolveIdentitySwitch = resolveIdentitySwitch,
        BeginRoomTransitions = beginRoomTransitions,
        AdvanceFrame = advanceFrame,
        TransitionDarkness = transitionDarkness,
        ChooseIcon = chooseIcon,
        InvalidateIconCache = function() runtime.iconCandidates = nil; runtime.iconConfigs = {} end,
        RememberPickedIcon = rememberPickedIcon,
        TrySpawnVoidPortal = trySpawnVoidPortal,
        GetRuntimeState = function(player) return runtime.states[runtimePlayerKey(pairMain(player))] end,
        GetSavedState = ensureSavedState,
        OnGameStarted = onGameStarted,
        OnPreGameExit = onPreGameExit,
        OnNpcDeath = onNpcDeath,
        Runtime = runtime,
    }

    Neverbirth.MemoryDisorder = api

    if ModCallbacks then
        Neverbirth:AddCallback(ModCallbacks.MC_POST_UPDATE, onPostUpdate)
        Neverbirth:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, onNewRoom)
        Neverbirth:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, function(_, continued) onGameStarted(continued) end)
        Neverbirth:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, onPreGameExit)
        if ModCallbacks.MC_POST_PLAYER_INIT then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, function(_, player) onOwnershipUpdate(player) end)
        end
        if ModCallbacks.MC_POST_NPC_DEATH then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc) onNpcDeath(npc) end)
        end
        if ModCallbacks.MC_POST_ADD_COLLECTIBLE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, function(_, id) rememberPickedIcon(id) end)
        end
        if ModCallbacks.MC_POST_PICKUP_UPDATE then
            Neverbirth:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, function(_, pickup) updatePickupIcon(pickup) end, 100)
        end
        if ModCallbacks.MC_PRE_PICKUP_RENDER then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_RENDER, function(_, pickup) renderPickupIcon(pickup) end, 100)
        end
        if ModCallbacks.MC_PRE_PICKUP_COLLISION then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, function(_, pickup, collider) capturePickupIcon(pickup, collider) end, 100)
        end
        if ModCallbacks.MC_PRE_PLAYER_RENDER then
            Neverbirth:AddCallback(ModCallbacks.MC_PRE_PLAYER_RENDER, function(_, player) renderHeldIcon(player) end)
        end
    end

    return api
end
