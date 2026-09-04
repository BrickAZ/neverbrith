local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function assertFalsy(value, message)
    if value then error(message or "expected falsy value", 2) end
end

local function containsProfile(profiles, id)
    for _, profile in ipairs(profiles or {}) do
        if profile.id == id then return true end
    end
    return false
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

Vector = setmetatable({ Zero = { X = 0, Y = 0 } }, {
    __call = function(_, x, y) return { X = x or 0, Y = y or 0 } end,
})

PlayerType = {
    PLAYER_ISAAC = 0,
    PLAYER_MAGDALENE = 1,
    PLAYER_CAIN = 2,
    PLAYER_JUDAS = 3,
    PLAYER_BLUEBABY = 4,
    PLAYER_EVE = 5,
    PLAYER_SAMSON = 6,
    PLAYER_AZAZEL = 7,
    PLAYER_LAZARUS = 8,
    PLAYER_EDEN = 9,
    PLAYER_THELOST = 10,
    PLAYER_LAZARUS2 = 11,
    PLAYER_BLACKJUDAS = 12,
    PLAYER_LILITH = 13,
    PLAYER_KEEPER = 14,
    PLAYER_APOLLYON = 15,
    PLAYER_THEFORGOTTEN = 16,
    PLAYER_THESOUL = 17,
    PLAYER_BETHANY = 18,
    PLAYER_JACOB = 19,
    PLAYER_ESAU = 20,
    PLAYER_ISAAC_B = 21,
    PLAYER_MAGDALENE_B = 22,
    PLAYER_CAIN_B = 23,
    PLAYER_JUDAS_B = 24,
    PLAYER_BLUEBABY_B = 25,
    PLAYER_EVE_B = 26,
    PLAYER_SAMSON_B = 27,
    PLAYER_AZAZEL_B = 28,
    PLAYER_LAZARUS_B = 29,
    PLAYER_EDEN_B = 30,
    PLAYER_THELOST_B = 31,
    PLAYER_LILITH_B = 32,
    PLAYER_KEEPER_B = 33,
    PLAYER_APOLLYON_B = 34,
    PLAYER_THEFORGOTTEN_B = 35,
    PLAYER_BETHANY_B = 36,
    PLAYER_JACOB_B = 37,
}

ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2 }
PocketItemSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1 }
EffectVariant = { PORTAL_TELEPORT = 161 }
EntityType = { ENTITY_EFFECT = 1000 }
GridEntityType = { GRID_TRAPDOOR = 17 }
ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_POST_NEW_ROOM = 2,
    MC_POST_GAME_STARTED = 3,
    MC_PRE_GAME_EXIT = 4,
    MC_POST_PLAYER_INIT = 5,
}

local function makePlayer(seed, playerType)
    local player = {
        InitSeed = seed,
        ControllerIndex = seed,
        playerType = playerType or PlayerType.PLAYER_ISAAC,
        collectibleCounts = {},
        activeItems = { [0] = 100, [1] = 101, [2] = 0 },
        activeCharges = { [0] = 3, [1] = 2, [2] = 0 },
        batteryCharges = { [0] = 1, [1] = 0, [2] = 0 },
        cards = { [0] = 7, [1] = 8 },
        pills = { [0] = 0, [1] = 0 },
        health = {
            maxHearts = 6,
            hearts = 6,
            soulHearts = 2,
            blackHearts = 0,
            boneHearts = 0,
            rottenHearts = 0,
            eternalHearts = 0,
            goldenHearts = 0,
            brokenHearts = 0,
        },
        changeCalls = {},
        changeInjections = {},
        addedCollectibles = {},
        removedCollectibles = {},
        exists = true,
        dead = false,
    }
    function player:GetPlayerType() return self.playerType end
    function player:ChangePlayerType(newType)
        self.playerType = newType
        self.changeCalls[#self.changeCalls + 1] = newType
        local injection = self.changeInjections[newType]
        if injection then
            self.collectibleCounts[injection.id] = (self.collectibleCounts[injection.id] or 0) + 1
            if injection.slot ~= nil then
                self.activeItems[injection.slot] = injection.id
                self.activeCharges[injection.slot] = injection.charge or 0
                self.batteryCharges[injection.slot] = 0
            end
        end
    end
    function player:GetCollectibleNum(id) return self.collectibleCounts[id] or 0 end
    function player:HasCollectible(id) return (self.collectibleCounts[id] or 0) > 0 end
    function player:AddCollectible(id, charge, firstTime, slot)
        self.collectibleCounts[id] = (self.collectibleCounts[id] or 0) + 1
        self.addedCollectibles[#self.addedCollectibles + 1] = id
        if slot ~= nil and slot >= 0 then
            self.activeItems[slot] = id
            self.activeCharges[slot] = charge or 0
        end
    end
    function player:RemoveCollectible(id, ignoreModifiers, slot)
        if (self.collectibleCounts[id] or 0) > 0 then
            self.collectibleCounts[id] = self.collectibleCounts[id] - 1
        end
        if slot ~= nil and self.activeItems[slot] == id then
            self.activeItems[slot] = 0
            self.activeCharges[slot] = 0
            self.batteryCharges[slot] = 0
        end
        self.removedCollectibles[#self.removedCollectibles + 1] = id
    end
    function player:GetActiveItem(slot) return self.activeItems[slot] or 0 end
    function player:GetActiveCharge(slot) return self.activeCharges[slot] or 0 end
    function player:GetBatteryCharge(slot) return self.batteryCharges[slot] or 0 end
    function player:SetActiveCharge(charge, slot) self.activeCharges[slot] = charge end
    function player:SetPocketActiveItem(id, slot, keepInPools)
        self.activeItems[ActiveSlot.SLOT_POCKET] = id
    end
    function player:RemoveCollectibleFromSlot(slot)
        self.activeItems[slot] = 0
        self.activeCharges[slot] = 0
        self.batteryCharges[slot] = 0
    end
    function player:GetCard(slot) return self.cards[slot] or 0 end
    function player:SetCard(slot, id) self.cards[slot] = id end
    function player:GetPill(slot) return self.pills[slot] or 0 end
    function player:SetPill(slot, id) self.pills[slot] = id end
    function player:GetMaxHearts() return self.health.maxHearts end
    function player:GetHearts() return self.health.hearts end
    function player:GetSoulHearts() return self.health.soulHearts end
    function player:GetBlackHearts() return self.health.blackHearts end
    function player:GetBoneHearts() return self.health.boneHearts end
    function player:GetRottenHearts() return self.health.rottenHearts end
    function player:GetEternalHearts() return self.health.eternalHearts end
    function player:GetGoldenHearts() return self.health.goldenHearts end
    function player:GetBrokenHearts() return self.health.brokenHearts end
    function player:AddMaxHearts(amount) self.health.maxHearts = math.max(0, self.health.maxHearts + amount) end
    function player:AddHearts(amount) self.health.hearts = math.max(0, self.health.hearts + amount) end
    function player:AddSoulHearts(amount) self.health.soulHearts = math.max(0, self.health.soulHearts + amount) end
    function player:AddBlackHearts(amount) self.health.soulHearts = math.max(0, self.health.soulHearts + amount) end
    function player:AddBoneHearts(amount) self.health.boneHearts = math.max(0, self.health.boneHearts + amount) end
    function player:AddRottenHearts(amount) self.health.rottenHearts = math.max(0, self.health.rottenHearts + amount) end
    function player:AddEternalHearts(amount) self.health.eternalHearts = math.max(0, self.health.eternalHearts + amount) end
    function player:AddGoldenHearts(amount) self.health.goldenHearts = math.max(0, self.health.goldenHearts + amount) end
    function player:AddBrokenHearts(amount) self.health.brokenHearts = math.max(0, self.health.brokenHearts + amount) end
    function player:Exists() return self.exists end
    function player:IsDead() return self.dead end
    return player
end

local function makeEnvironment()
    local callbacks = {}
    local saves = 0
    local saveRoot = {}
    local runSeed = "MEMORY-RUN-A"
    local unlocked = { [1] = true }
    local players = { makePlayer(101, PlayerType.PLAYER_ISAAC), makePlayer(202, PlayerType.PLAYER_CAIN) }
    local portals = {}
    local iconConfigs = {}

    local mod = {}
    function mod:AddCallback(callbackId, fn, param)
        callbacks[#callbacks + 1] = { id = callbackId, fn = fn, param = param }
    end

    local initialize = assert(dofile("memory_disorder.lua"))
    local api = initialize(mod, {
        ItemId = 9000,
        GetPlayers = function() return players end,
        GetSaveRoot = function() return saveRoot end,
        Save = function() saves = saves + 1 end,
        GetCurrentRunSeed = function() return runSeed end,
        IsAchievementUnlocked = function(id) return unlocked[id] == true end,
        GetCollectibleConfigs = function() return iconConfigs end,
        SpawnVoidPortal = function(roomContext)
            portals[#portals + 1] = roomContext.kind
            return { Variant = EffectVariant.PORTAL_TELEPORT }
        end,
        HasExistingVoidPortal = function() return #portals > 0 end,
        Darken = function() end,
    })

    return {
        api = api,
        players = players,
        saveRoot = saveRoot,
        portals = portals,
        callbacks = callbacks,
        saves = function() return saves end,
        setRunSeed = function(value) runSeed = value end,
        setUnlocked = function(id, value) unlocked[id] = value end,
        setIconConfigs = function(value) iconConfigs = value end,
        setPlayers = function(value) players = value end,
        runPostUpdate = function()
            for _, callback in ipairs(callbacks) do
                if callback.id == ModCallbacks.MC_POST_UPDATE then callback.fn(mod) end
            end
        end,
    }
end

local function test_pickup_arms_next_room_and_switches_on_frame_fifteen()
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibleCounts[env.api.Constants.ITEM_ID] = 1

    assertTruthy(env.api.OnOwnershipUpdate(player), "first pickup edge should be recorded")
    assertEquals(player:GetPlayerType(), PlayerType.PLAYER_ISAAC, "pickup room must not switch")
    assertEquals(env.api.GetSavedState().memoryDisorderVoidUnlockedThisRun, true, "pickup unlocks run Void route")

    env.api.BeginRoomTransitions("room-b")
    for _ = 1, 14 do env.api.AdvanceFrame() end
    assertEquals(#player.changeCalls, 0, "frames 0-14 must not switch")
    env.api.AdvanceFrame()
    assertEquals(#player.changeCalls, 1, "frame 15 switches exactly once")
    for _ = 1, 15 do env.api.AdvanceFrame() end
    assertEquals(env.api.GetRuntimeState(player).transition, nil, "frame 30 clears transition")

    env.api.BeginRoomTransitions("room-a-revisit")
    for _ = 1, 15 do env.api.AdvanceFrame() end
    assertEquals(#player.changeCalls, 2, "re-entering an old room switches again")
end

local function test_unlock_filter_and_internal_types()
    local env = makeEnvironment()
    local candidates = env.api.BuildVanillaCandidates(env.players[1])
    assertTruthy(containsProfile(candidates, "isaac"), "Isaac is always available")
    assertTruthy(containsProfile(candidates, "magdalene"), "an unlocked character is included")
    assertFalsy(containsProfile(candidates, "cain"), "a locked character is excluded")
    for _, profile in ipairs(candidates) do
        assertFalsy(profile.playerType == 11 or profile.playerType == 12 or profile.playerType == 17
            or profile.playerType == 20 or profile.playerType == 38 or profile.playerType == 39
            or profile.playerType == 40, "internal derived types must not be top-level candidates")
    end
    assertEquals(#env.api.MemoryDisorderCharacterProfiles, 0, "mod-character whitelist defaults empty")
end

local function test_mod_character_whitelist_is_explicit()
    local env = makeEnvironment()
    env.api.MemoryDisorderCharacterProfiles[#env.api.MemoryDisorderCharacterProfiles + 1] = {
        id = "approved_mod_character",
        playerType = 9001,
        isCompatible = function() return true end,
    }
    env.api.MemoryDisorderCharacterProfiles[#env.api.MemoryDisorderCharacterProfiles + 1] = {
        id = "disabled_mod_character",
        playerType = 9002,
        isCompatible = function() return false end,
    }

    local candidates = env.api.BuildAllCandidates(env.players[1])
    assertTruthy(containsProfile(candidates, "approved_mod_character"), "explicit compatible profile joins the pool")
    assertFalsy(containsProfile(candidates, "disabled_mod_character"), "disabled profile stays out")
    assertFalsy(containsProfile(candidates, "unregistered_mod_character"), "unregistered mod characters never join")
end

local function test_temporary_components_preserve_permanent_same_id_and_slots()
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibleCounts[9000] = 1
    player.collectibleCounts[45] = 1
    env.api.OnOwnershipUpdate(player)

    local magdalene = assert(env.api.FindProfile("magdalene"))
    env.api.ResolveIdentitySwitch(player, magdalene)
    assertEquals(player.collectibleCounts[45], 2, "Magdalene adds one temporary Yum Heart copy")

    local taintedMagdalene = assert(env.api.FindProfile("magdalene_b"))
    env.api.ResolveIdentitySwitch(player, taintedMagdalene)
    assertEquals(player.collectibleCounts[45], 1, "switch removes only the temporary collectible copy")
    assertEquals(player.activeItems[ActiveSlot.SLOT_POCKET], 45, "temporary pocket active appears")

    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("isaac")))
    assertEquals(player.activeItems[ActiveSlot.SLOT_PRIMARY], 100, "permanent primary active is restored")
    assertEquals((player.activeCharges[ActiveSlot.SLOT_PRIMARY] or 0)
        + (player.batteryCharges[ActiveSlot.SLOT_PRIMARY] or 0), 4, "primary total charge is restored")
    assertEquals(player.activeItems[ActiveSlot.SLOT_POCKET], 0, "temporary pocket active is removed")
    assertEquals(player.cards[0], 7, "permanent primary pocket consumable is preserved")
    assertEquals(player.cards[1], 8, "permanent secondary pocket consumable is preserved")
end

local function test_engine_injected_starting_component_is_not_duplicated()
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibleCounts[9000] = 1
    player.changeInjections[PlayerType.PLAYER_MAGDALENE] = {
        id = 45,
        slot = ActiveSlot.SLOT_PRIMARY,
        charge = 4,
    }
    env.api.OnOwnershipUpdate(player)

    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("magdalene")))
    assertEquals(player.collectibleCounts[45], 1, "engine-injected starting active is not added twice")
    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("isaac")))
    assertEquals(player.collectibleCounts[45], 0, "engine-injected temporary active is removed once")
    assertEquals(player.activeItems[ActiveSlot.SLOT_PRIMARY], 100, "permanent active returns after injected start item")
end

local function test_health_ledger_and_item_loss_restore_original_identity()
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(player)

    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("the_lost")))
    assertEquals(player.health.maxHearts, 0, "Lost cannot actively carry red containers")
    assertEquals(player.health.soulHearts, 0, "Lost cannot actively carry soul hearts")

    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("isaac")))
    assertEquals(player.health.maxHearts, 6, "latent red containers return on a compatible identity")
    assertEquals(player.health.hearts, 6, "latent red health returns")
    assertEquals(player.health.soulHearts, 2, "latent soul health returns")

    player.health.hearts = 2
    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("cain")))
    assertEquals(player.health.hearts, 2, "damage persists across later switches")

    player.collectibleCounts[9000] = 0
    assertTruthy(env.api.OnOwnershipUpdate(player), "loss edge should settle the identity")
    assertEquals(player:GetPlayerType(), PlayerType.PLAYER_ISAAC, "loss restores the pre-pickup character")
    assertEquals(env.api.GetRuntimeState(player), nil, "loss clears player runtime state")
    assertEquals(env.api.GetSavedState().memoryDisorderVoidUnlockedThisRun, true, "loss does not clear Void entitlement")
end

local function test_keeper_cap_does_not_destroy_latent_health()
    local env = makeEnvironment()
    local player = env.players[1]
    player.health.maxHearts = 12
    player.health.hearts = 12
    player.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(player)

    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("keeper")))
    assertEquals(player.health.maxHearts, 6, "Keeper only exposes the supported red-heart cap")
    assertEquals(player.health.hearts, 6, "Keeper visible health is capped")
    player.health.hearts = 4

    env.api.ResolveIdentitySwitch(player, assert(env.api.FindProfile("isaac")))
    assertEquals(player.health.maxHearts, 12, "hidden red-heart containers survive the Keeper identity")
    assertEquals(player.health.hearts, 10, "damage taken as Keeper persists without deleting hidden health")
end

local function test_coop_isolation_and_icon_fallback()
    local env = makeEnvironment()
    local first, second = env.players[1], env.players[2]
    first.collectibleCounts[9000] = 1
    second.collectibleCounts[9000] = 0
    env.api.OnOwnershipUpdate(first)
    env.api.OnOwnershipUpdate(second)
    env.api.ResolveIdentitySwitch(first, assert(env.api.FindProfile("magdalene")))
    assertEquals(second:GetPlayerType(), PlayerType.PLAYER_CAIN, "non-holder identity is untouched")

    second.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(second)
    env.api.BeginRoomTransitions("coop-room")
    for _ = 1, 15 do env.api.AdvanceFrame() end
    assertEquals(#first.changeCalls, 2, "first holder advances its own identity")
    assertEquals(#second.changeCalls, 1, "second holder advances independently")
    assertFalsy(env.api.GetRuntimeState(first) == env.api.GetRuntimeState(second), "co-op holders never share state tables")

    assertEquals(env.api.ChooseIcon(first), 25, "empty icon pool falls back to Breakfast")
    local additionsBefore = #first.addedCollectibles
    env.setIconConfigs({
        { ID = 9000, GfxFileName = "self.png" },
        { ID = 12, GfxFileName = "valid.png" },
        { ID = 13, GfxFileName = "" },
    })
    env.api.InvalidateIconCache()
    assertEquals(env.api.ChooseIcon(first), 12, "valid loaded collectible icon is selected")
    assertEquals(#first.addedCollectibles, additionsBefore, "icon selection never grants the represented item")
end

local function test_player_death_interrupts_transition_and_departure_releases_runtime_state()
    local env = makeEnvironment()
    local first, second = env.players[1], env.players[2]
    first.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(first)
    env.api.BeginRoomTransitions("death-interrupt")

    first.dead = true
    env.runPostUpdate()
    assertEquals(env.api.GetRuntimeState(first).transition, nil, "death cancels a pending identity transition")

    first.dead = false
    env.setPlayers({ second })
    env.runPostUpdate()
    assertEquals(env.api.GetRuntimeState(first), nil, "a departed co-op player releases its runtime userdata state")
    assertTruthy(env.api.GetSavedState().players["101:101"], "departed holder state remains saved for a possible reconnect")
end

local function test_transition_darkness_curve()
    local env = makeEnvironment()
    assertEquals(env.api.TransitionDarkness(0), 0, "transition begins clear")
    assertTruthy(env.api.TransitionDarkness(14) > 0, "frame 14 is dark")
    assertEquals(env.api.TransitionDarkness(14), env.api.TransitionDarkness(15), "frames 14 and 15 share maximum darkness")
    assertEquals(env.api.TransitionDarkness(29), 0, "frame 29 returns to clear")
    assertEquals(env.api.TransitionDarkness(30), 0, "no persistent darkness after transition")
end

local function test_void_entitlement_continue_new_run_and_terminal_filter()
    local env = makeEnvironment()
    local player = env.players[1]
    player.collectibleCounts[9000] = 1
    env.api.OnOwnershipUpdate(player)

    assertTruthy(env.api.TrySpawnVoidPortal({ kind = "hush", clear = true }), "Hush terminal can receive the optional portal")
    assertEquals(#env.portals, 1, "one portal is requested")
    assertFalsy(env.api.TrySpawnVoidPortal({ kind = "hush", clear = true }), "existing portal prevents duplicates")
    assertFalsy(env.api.TrySpawnVoidPortal({ kind = "ordinary_boss", clear = true }), "ordinary bosses are rejected")
    assertFalsy(env.api.TrySpawnVoidPortal({ kind = "mom", clear = true }), "Mom is rejected")
    assertFalsy(env.api.TrySpawnVoidPortal({ kind = "moms_heart", clear = true }), "Mom's Heart is rejected")

    env.api.OnGameStarted(true)
    assertEquals(env.api.GetSavedState().memoryDisorderVoidUnlockedThisRun, true, "continue preserves entitlement")
    env.setRunSeed("MEMORY-RUN-B")
    env.api.OnGameStarted(false)
    assertEquals(env.api.GetSavedState().memoryDisorderVoidUnlockedThisRun, false, "new run clears entitlement")
end

local function test_native_void_portal_uses_grid_trapdoor_contract()
    local oldIsaac, oldGame, oldGridEntityType = Isaac, Game, GridEntityType
    local gridEntities = {}
    local spritePath = nil
    local spawnCall = nil
    local portal = {
        VarData = 0,
        GetType = function() return 17 end,
        GetSprite = function()
            return {
                Load = function(_, path) spritePath = path end,
            }
        end,
    }
    local room = {
        GetGridSize = function() return 9 end,
        GetGridEntity = function(_, index) return gridEntities[index] end,
        GetCenterPos = function() return Vector(40, 40) end,
        GetGridIndex = function() return 4 end,
        GetGridWidth = function() return 3 end,
        GetGridPosition = function(_, index) return Vector(index * 10, 20) end,
        GetGridCollisionAtPos = function() return 0 end,
    }
    GridEntityType = { GRID_TRAPDOOR = 17 }
    Game = function() return { GetRoom = function() return room end } end
    Isaac = {
        GridSpawn = function(gridType, variant, position, forced)
            spawnCall = { gridType = gridType, variant = variant, position = position, forced = forced }
            gridEntities[4] = portal
            return portal
        end,
    }

    local ok, errorMessage = pcall(function()
        local mod = { AddCallback = function() end }
        local saveRoot = {
            memoryDisorder = {
                version = 1,
                runSeed = "PORTAL-RUN",
                memoryDisorderVoidUnlockedThisRun = true,
                players = {},
            },
        }
        local api = assert(dofile("memory_disorder.lua"))(mod, {
            ItemId = 9000,
            GetSaveRoot = function() return saveRoot end,
            GetCurrentRunSeed = function() return "PORTAL-RUN" end,
            GetPlayers = function() return {} end,
        })
        assertTruthy(api.TrySpawnVoidPortal({ kind = "mega_satan", clear = true }), "valid finale creates a native portal")
        assertEquals(spawnCall.gridType, 17, "portal uses GRID_TRAPDOOR")
        assertEquals(spawnCall.variant, 1, "portal uses Void trapdoor variant")
        assertEquals(spawnCall.forced, true, "portal uses the documented forced grid spawn")
        assertEquals(portal.VarData, 1, "portal destination is The Void")
        assertEquals(spritePath, "gfx/grid/voidtrapdoor.anm2", "portal loads the native Void appearance")
    end)

    Isaac, Game, GridEntityType = oldIsaac, oldGame, oldGridEntityType
    if not ok then error(errorMessage, 0) end
end

local function test_registration_contract()
    local items = readFile("content/items.xml")
    local english = readFile("content/items.en_us.xml")
    local chinese = readFile("content/items.zh_cn.xml")
    local generated = readFile("generated/neverbirth_collectibles.lua")
    assertTruthy(items:find('<passive name="Memory Disorder"', 1, true), "base registration")
    assertTruthy(items:find('gfx="Collectibles_025_Breakfast.png" id="55" quality="0"', 1, true), "Breakfast fallback and stable id")
    assertTruthy(english:find('name="Memory Disorder"', 1, true) and english:find('description="Who am I?"', 1, true), "English localization")
    assertTruthy(chinese:find('name="记忆紊乱"', 1, true) and chinese:find('description="我是谁？"', 1, true), "Chinese localization")
    assertTruthy(generated:find('localId = 55', 1, true) and generated:find('englishName = "Memory Disorder"', 1, true), "generated registration")
    for _, path in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml", "content/itempools.zh_cn.xml" }) do
        local pools = readFile(path)
        assertEquals(pools:find("Memory Disorder", 1, true), nil, path .. " must not invent a pool")
        assertEquals(pools:find("记忆紊乱", 1, true), nil, path .. " must not invent a pool")
    end
end

local tests = {
    test_pickup_arms_next_room_and_switches_on_frame_fifteen,
    test_unlock_filter_and_internal_types,
    test_mod_character_whitelist_is_explicit,
    test_temporary_components_preserve_permanent_same_id_and_slots,
    test_engine_injected_starting_component_is_not_duplicated,
    test_health_ledger_and_item_loss_restore_original_identity,
    test_keeper_cap_does_not_destroy_latent_health,
    test_coop_isolation_and_icon_fallback,
    test_player_death_interrupts_transition_and_departure_releases_runtime_state,
    test_transition_darkness_curve,
    test_void_entitlement_continue_new_run_and_terminal_filter,
    test_native_void_portal_uses_grid_trapdoor_contract,
    test_registration_contract,
}

for _, test in ipairs(tests) do test() end
print("memory_disorder_behavior_test: ok")
