-- Selectable identities and compatibility profiles; starting-kit data remains owned by this item.
return function(Neverbirth, context, deps)
    local playerType = deps.playerType
    local SLOT_PRIMARY = deps.SLOT_PRIMARY
    local SLOT_POCKET = deps.SLOT_POCKET
    local POCKET_PRIMARY = deps.POCKET_PRIMARY

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

    local function profileForType(value)
        return profilesByType[value] or { id = "unknown", playerType = value, healthMode = "ordinary" }
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

    return {
        profileForType = profileForType,
        buildVanillaCandidates = buildVanillaCandidates,
        buildAllCandidates = buildAllCandidates,
        findProfile = findProfile,
        VANILLA_PROFILES = VANILLA_PROFILES,
        profilesById = profilesById,
    }
end
