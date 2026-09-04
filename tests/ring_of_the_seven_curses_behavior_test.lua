local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

ActiveSlot = { SLOT_PRIMARY = 0, SLOT_SECONDARY = 1, SLOT_POCKET = 2 }
CacheFlag = {
    CACHE_DAMAGE = 1,
    CACHE_FIREDELAY = 2,
    CACHE_SHOTSPEED = 4,
    CACHE_FLYING = 128,
    CACHE_LUCK = 1024,
}
CollectibleType = {
    COLLECTIBLE_BLACK_CANDLE = 260,
    COLLECTIBLE_CURSED_EYE = 316,
    COLLECTIBLE_THE_WIZ = 358,
    COLLECTIBLE_CURSE_OF_THE_TOWER = 371,
    COLLECTIBLE_FRUIT_CAKE = 418,
    COLLECTIBLE_EUTHANASIA = 496,
    COLLECTIBLE_LITTLE_HORN = 503,
    COLLECTIBLE_SCHOOLBAG = 534,
    COLLECTIBLE_SOL = 588,
    COLLECTIBLE_POUND_OF_FLESH = 672,
    NUM_COLLECTIBLES = 733,
}
TrinketType = { TRINKET_MONKEY_PAW = 20, TRINKET_KEEPERS_BARGAIN = 171 }
PlayerType = { PLAYER_KEEPER = 14, PLAYER_KEEPER_B = 33 }
ItemType = { ITEM_ACTIVE = 3 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_NPC = 10 }
PickupVariant = { PICKUP_COLLECTIBLE = 100, PICKUP_TRINKET = 350 }
EntityFlag = { FLAG_FRIENDLY = 1, FLAG_CHARM = 2 }
LevelCurse = {
    CURSE_OF_DARKNESS = 1,
    CURSE_OF_THE_LOST = 4,
    CURSE_OF_THE_UNKNOWN = 8,
    CURSE_OF_MAZE = 32,
}
RoomType = { ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
ModCallbacks = {
    MC_USE_ITEM = 1,
    MC_EVALUATE_CACHE = 2,
    MC_POST_PEFFECT_UPDATE = 3,
    MC_POST_NEW_ROOM = 4,
    MC_POST_NEW_LEVEL = 5,
    MC_POST_GAME_STARTED = 6,
    MC_PRE_GAME_EXIT = 7,
    MC_POST_CURSE_EVAL = 8,
    MC_POST_NPC_INIT = 9,
    MC_ENTITY_TAKE_DMG = 10,
    MC_POST_GET_COLLECTIBLE = 11,
    MC_POST_PICKUP_UPDATE = 12,
    MC_PRE_PICKUP_COLLISION = 13,
}
local vectorValueType = {}
Vector = setmetatable({ Zero = setmetatable({ X = 0, Y = 0 }, vectorValueType) }, {
    __call = function(_, x, y) return setmetatable({ X = x or 0, Y = y or 0 }, vectorValueType) end,
})

local itemConfigs = {}
for id = 1, 900 do itemConfigs[id] = { Quality = 0, Type = 1, MaxCharges = 6 } end
itemConfigs[105] = { Quality = 4, Type = ItemType.ITEM_ACTIVE, MaxCharges = 6 }
itemConfigs[500] = { Quality = 4, Type = 1, MaxCharges = 0 }
itemConfigs[800] = { Quality = 0, Type = 1, MaxCharges = 0 }
itemConfigs[700] = { Quality = 0, Type = ItemType.ITEM_ACTIVE, MaxCharges = 6 }
itemConfigs[9000] = { Quality = 0, Type = ItemType.ITEM_ACTIVE, MaxCharges = 0 }

Isaac = {
    GetItemConfig = function()
        return { GetCollectible = function(_, id) return itemConfigs[id] end }
    end,
    GetRoomEntities = function() return {} end,
    Spawn = function() return nil end,
}

local currentRoomKey = "1:1:0"
local saveRoot = {}
local players = {}
local callbacks = {}
local mod = {}
local debugMessages = {}
function mod:AddCallback(callbackId, fn, filter)
    callbacks[#callbacks + 1] = { id = callbackId, fn = fn, filter = filter }
end

local function makePlayer(seed, playerType)
    local player = {
        InitSeed = seed,
        ControllerIndex = seed,
        playerType = playerType or 0,
        activeItems = { [0] = 9000, [1] = 700, [2] = 0 },
        activeCharges = { [0] = 0, [1] = 0, [2] = 0 },
        collectibles = {},
        trinkets = { [15] = 1 },
        heldTrinkets = { [0] = 15, [1] = 0 },
        Damage = 4,
        MaxFireDelay = 9,
        ShotSpeed = 1,
        Luck = 2,
        CanFly = true,
        keys = 9,
        bombs = 8,
        coins = 99,
        maxHearts = 8,
        soulHearts = 6,
        boneHearts = 1,
        eternalHearts = 1,
        brokenHearts = 0,
        damageCalls = {},
    }
    function player:GetPlayerType() return self.playerType end
    function player:GetActiveItem(slot) return self.activeItems[slot] or 0 end
    function player:GetActiveCharge(slot) return self.activeCharges[slot] or 0 end
    function player:SetActiveCharge(value, slot) self.activeCharges[slot] = value end
    function player:AddCollectible(id, charge, firstTime, slot)
        self.collectibles[id] = (self.collectibles[id] or 0) + 1
        if slot ~= nil then self.activeItems[slot] = id end
    end
    function player:RemoveCollectible(id)
        self.collectibles[id] = math.max(0, (self.collectibles[id] or 0) - 1)
    end
    function player:GetCollectibleNum(id) return self.collectibles[id] or 0 end
    function player:HasCollectible(id) return (self.collectibles[id] or 0) > 0 or self.activeItems[0] == id end
    function player:GetTrinketMultiplier(id) return self.trinkets[id] or 0 end
    function player:HasTrinket(id) return (self.trinkets[id] or 0) > 0 end
    function player:GetTrinket(slot) return self.heldTrinkets[slot] or 0 end
    function player:AddTrinket(id)
        for slot = 0, 1 do
            if (self.heldTrinkets[slot] or 0) == 0 then
                self.heldTrinkets[slot] = id
                self.trinkets[id] = (self.trinkets[id] or 0) + 1
                return
            end
        end
    end
    function player:TryRemoveTrinket(id)
        if (self.trinkets[id] or 0) > 0 then
            for slot = 0, 1 do
                if self.heldTrinkets[slot] == id then
                    self.heldTrinkets[slot] = 0
                    break
                end
            end
            self.trinkets[id] = self.trinkets[id] - 1
            return true
        end
        return false
    end
    function player:GetNumKeys() return self.keys end
    function player:AddKeys(delta) self.keys = self.keys + delta end
    function player:GetNumBombs() return self.bombs end
    function player:AddBombs(delta) self.bombs = self.bombs + delta end
    function player:GetNumCoins() return self.coins end
    function player:AddCoins(delta) self.coins = self.coins + delta end
    function player:GetMaxHearts() return self.maxHearts end
    function player:AddMaxHearts(delta) self.maxHearts = math.max(0, self.maxHearts + delta) end
    function player:GetSoulHearts() return self.soulHearts end
    function player:AddSoulHearts(delta) self.soulHearts = math.max(0, self.soulHearts + delta) end
    function player:GetBoneHearts() return self.boneHearts end
    function player:AddBoneHearts(delta) self.boneHearts = math.max(0, self.boneHearts + delta) end
    function player:GetEternalHearts() return self.eternalHearts end
    function player:AddEternalHearts(delta) self.eternalHearts = math.max(0, self.eternalHearts + delta) end
    function player:AddBrokenHearts(delta) self.brokenHearts = self.brokenHearts + delta end
    function player:AddCacheFlags() end
    function player:EvaluateItems() end
    function player:TakeDamage(amount, flags, source, countdown)
        self.damageCalls[#self.damageCalls + 1] = { amount = amount, flags = flags, source = source, countdown = countdown }
    end
    function player:ToPlayer() return self end
    return player
end

local initialize = assert(loadfile("ring_of_the_seven_curses.lua"))()
initialize(mod, {
    ItemId = 9000,
    TrinketId = 9900,
    GetPlayers = function() return players end,
    GetSaveRoot = function() return saveRoot end,
    Save = function() end,
    GetCurrentRunSeed = function() return "test-run" end,
    GetRoomKey = function() return currentRoomKey end,
    DebugLog = function(message) debugMessages[#debugMessages + 1] = message end,
})

local api = assert(mod.RingOfSevenCursesTestAPI, "test API must be exposed")
local player = makePlayer(101)
players = { player }
api.ResetForTest()
api.ActivatePlayer(player)
assertTruthy(api.GetPlayerState(player).active, "pickup permanently activates the per-player run contract")
assertEquals(player:GetTrinket(0), api.TrinketId, "activation replaces held trinkets with the visual slot seal")
assertEquals(player:GetTrinketMultiplier(15), 0, "the previous held trinket is no longer equipped")

player:TryRemoveTrinket(api.TrinketId)
api.ReconcilePlayer(player)
assertEquals(player:GetTrinket(0), api.TrinketId, "dropping the visual slot seal restores it immediately")

local useResult = api.Callbacks.UseItem(nil, api.ItemId, nil, player)
assertEquals(useResult.Discharge, false, "using the ring never discharges it")
assertEquals(useResult.Remove, false, "using the ring never removes it")

api.Callbacks.EvaluateCache(nil, player, CacheFlag.CACHE_DAMAGE)
api.Callbacks.EvaluateCache(nil, player, CacheFlag.CACHE_FIREDELAY)
api.Callbacks.EvaluateCache(nil, player, CacheFlag.CACHE_SHOTSPEED)
api.Callbacks.EvaluateCache(nil, player, CacheFlag.CACHE_LUCK)
api.Callbacks.EvaluateCache(nil, player, CacheFlag.CACHE_FLYING)
assertEquals(player.Damage, 3, "damage multiplier")
assertEquals(player.MaxFireDelay, (9 + 1) / 0.75 - 1, "fire-rate multiplier uses frequency conversion")
assertEquals(player.ShotSpeed, 1.25, "shot-speed multiplier")
assertEquals(player.Luck, -3, "one permanent -5 luck penalty")
assertEquals(player.CanFly, false, "flight is disabled")

assertEquals(api.GetCoinCap(player), 20, "normal coin cap")
player.collectibles[CollectibleType.COLLECTIBLE_POUND_OF_FLESH] = 1
assertEquals(api.GetCoinCap(player), 35, "Pound of Flesh raises non-Keeper cap")
player.playerType = PlayerType.PLAYER_KEEPER
assertEquals(api.GetCoinCap(player), nil, "Keeper coin cap exemption")
player.playerType = 0
player.collectibles[CollectibleType.COLLECTIBLE_POUND_OF_FLESH] = 0
api.ClampResources(player)
assertEquals(player.keys, 2, "key cap")
assertEquals(player.bombs, 1, "bomb cap")
assertEquals(player.coins, 20, "coin cap")

api.ClampHealth(player)
assertEquals(api.GetTotalHealthCapacity(player), 12, "health capacity is trimmed to 12 half-hearts")

assertTruthy(api.IsForbiddenCollectible(500), "quality 4 is forbidden")
assertTruthy(api.IsForbiddenCollectible(800), "modded collectible is forbidden")
assertEquals(api.IsForbiddenCollectible(CollectibleType.COLLECTIBLE_THE_WIZ), false, "The Wiz is exempt")
assertEquals(api.IsForbiddenCollectible(CollectibleType.COLLECTIBLE_CURSE_OF_THE_TOWER), false, "Curse of the Tower is exempt")
assertEquals(api.IsForbiddenCollectible(CollectibleType.COLLECTIBLE_CURSED_EYE), false, "Cursed Eye is exempt")
assertEquals(api.IsForbiddenCollectible(api.ItemId), false, "the ring itself is obtainable")

itemConfigs[699] = nil
local rerollCandidates = { 500, 800, 700, 699, 25 }
local rerollCalls = {}
local itemPool = {}
function itemPool:GetCollectible(poolType, decrease, seed)
    rerollCalls[#rerollCalls + 1] = { poolType = poolType, decrease = decrease, seed = seed }
    return table.remove(rerollCandidates, 1)
end
local replacement, rerollSuccess = api.RerollForbiddenSelection(500, 7, true, 1234, itemPool)
assertTruthy(rerollSuccess, "same-pool reroll eventually finds a legal candidate")
assertEquals(replacement, 25, "same-pool reroll skips Q4, modded, slot-blocked active and missing-config candidates")
assertEquals(#rerollCalls, 5, "reroll attempts are finite and sequential")
for _, call in ipairs(rerollCalls) do
    assertEquals(call.poolType, 7, "reroll preserves originating pool")
    assertEquals(call.decrease, true, "reroll preserves pool decrease semantics")
end

local forced = api.ForceCurses(64)
assertEquals(forced, 64 | 1 | 4 | 8 | 32, "four required curses preserve unrelated curses")

local npcData = {}
local npc = { MaxHitPoints = 20, HitPoints = 15 }
function npc:GetData() return npcData end
function npc:IsActiveEnemy() return true end
function npc:IsVulnerableEnemy() return true end
function npc:HasEntityFlags() return false end
assertTruthy(api.DoubleNpcHealth(npc), "enemy health is doubled once")
assertEquals(npc.MaxHitPoints, 40, "doubled max health")
assertEquals(npc.HitPoints, 30, "current health scales with max health")
assertEquals(api.DoubleNpcHealth(npc), false, "same enemy is not doubled twice")

currentRoomKey = "1:2:0"
api.Callbacks.PostNewRoom()
assertEquals(player.activeCharges[1], 0, "first new room only advances the counter")
currentRoomKey = "1:3:0"
api.Callbacks.PostNewRoom()
assertEquals(player.activeCharges[1], 1, "every second room charges retained native secondary")
api.Callbacks.PostNewRoom()
assertEquals(player.activeCharges[1], 1, "re-enter callback for the same room does not duplicate charge progress")

player.collectibles[CollectibleType.COLLECTIBLE_SOL] = 1
player.trinkets[TrinketType.TRINKET_MONKEY_PAW] = 1
player.activeItems[0] = 123
api.ReconcilePlayer(player)
assertEquals(player.collectibles[CollectibleType.COLLECTIBLE_SOL], 0, "banned collectible is removed")
assertEquals(player.trinkets[TrinketType.TRINKET_MONKEY_PAW], 0, "banned trinket is removed")
assertEquals(player.activeItems[0], api.ItemId, "the primary ring is restored after replacement")

player.collectibles[CollectibleType.COLLECTIBLE_THE_WIZ] = 2
api.ReconcilePlayer(player)
player.collectibles[CollectibleType.COLLECTIBLE_THE_WIZ] = 1
api.ReconcilePlayer(player)
assertEquals(player.collectibles[CollectibleType.COLLECTIBLE_THE_WIZ], 2, "protected cursed collectible copies are restored")

local activePickup = {
    Variant = PickupVariant.PICKUP_COLLECTIBLE,
    SubType = 700,
    InitSeed = 7001,
    GetData = function() return {} end,
}
assertEquals(api.Callbacks.PrePickupCollision(nil, activePickup, player), true,
    "another active item cannot replace the bound primary slot")
local staleData = { NeverbirthSevenCursesBlocked = true }
local stalePickup = { Variant = 100, SubType = 25, InitSeed = 2502, GetData = function() return staleData end }
assertEquals(api.Callbacks.PrePickupCollision(nil, stalePickup, player), nil,
    "a legal replacement must not inherit a previous Q4 collision lock")
assertEquals(staleData.NeverbirthSevenCursesBlocked, nil, "obsolete collision lock is cleared")
local trinketPickup = { Variant = PickupVariant.PICKUP_TRINKET, SubType = 10 }
assertEquals(api.Callbacks.PrePickupCollision(nil, trinketPickup, player), true,
    "the trinket slot is mechanically blocked")

local droppedSlotSeal = {
    Variant = PickupVariant.PICKUP_TRINKET,
    SubType = api.TrinketId,
    removed = false,
    Remove = function(self) self.removed = true end,
}
api.Callbacks.PostTrinketUpdate(nil, droppedSlotSeal)
assertTruthy(droppedSlotSeal.removed, "a dropped technical slot seal is removed instead of polluting the room")
local ordinaryTrinket = {
    Variant = PickupVariant.PICKUP_TRINKET,
    SubType = 10,
    removed = false,
    Remove = function(self) self.removed = true end,
}
api.Callbacks.PostTrinketUpdate(nil, ordinaryTrinket)
assertEquals(ordinaryTrinket.removed, false, "the cleanup callback never removes ordinary trinkets")

local gameFrame = 100
local fakeRoom = { GetType = function() return RoomType.ROOM_DEVIL end }
local fakeLevel = { GetCurrentRoomIndex = function() return 1 end }
Game = function()
    return {
        GetFrameCount = function() return gameFrame end,
        GetRoom = function() return fakeRoom end,
        GetLevel = function() return fakeLevel end,
    }
end
local tradePickup = { SubType = 25, InitSeed = 2501 }
assertTruthy(api.RegisterTradeCandidate(tradePickup, player), "deal pedestal is tracked before acquisition")
player.collectibles[25] = 1
gameFrame = 101
api.SettleTradeCandidates()
assertEquals(player.brokenHearts, 1, "confirmed deal acquisition grants exactly one broken heart")
api.SettleTradeCandidates()
assertEquals(player.brokenHearts, 1, "same pedestal cannot grant a second broken heart")

local playerTwo = makePlayer(202)
playerTwo.activeItems[0] = api.ItemId
playerTwo.activeItems[1] = 700
players = { player, playerTwo }
api.ActivatePlayer(playerTwo)
currentRoomKey = "1:4:0"
api.Callbacks.PostNewRoom()
currentRoomKey = "1:5:0"
api.Callbacks.PostNewRoom()
assertEquals(player.activeCharges[1], 2, "player one keeps independent room-charge state")
assertEquals(playerTwo.activeCharges[1], 1, "player two keeps independent room-charge state")

api.Callbacks.EntityTakeDamage(nil, player, 1, 0, { Ref = nil }, 30)
assertEquals(#player.damageCalls, 1, "incoming hit is rewritten once")
assertEquals(player.damageCalls[1].amount, 2, "incoming damage is doubled")

-- The starting pedestal is run-owned, not one reward per co-op player.
local startPlayerOne = makePlayer(303)
local startPlayerTwo = makePlayer(404)
startPlayerOne.activeItems = {}
startPlayerTwo.activeItems = {}
players = { startPlayerOne, startPlayerTwo }
local startSpawnCalls = {}
local safeStartPosition = Vector(360, 240)
local startRoom = {
    GetCenterPos = function() return Vector(320, 280) end,
    FindFreePickupSpawnPosition = function(_, position)
        assertTruthy(position, "starting reward asks the room for a safe position")
        return safeStartPosition
    end,
}
Game = function()
    return {
        GetFrameCount = function() return 0 end,
        GetRoom = function() return startRoom end,
        GetLevel = function() return fakeLevel end,
    }
end
Isaac.Spawn = function(entityType, variant, subtype, position, velocity, spawner)
    local pickup = { Type = entityType, Variant = variant, SubType = subtype }
    function pickup:ToPickup() return self end
    startSpawnCalls[#startSpawnCalls + 1] = {
        pickup = pickup, position = position, velocity = velocity, spawner = spawner,
    }
    return pickup
end
api.ResetForTest()
api.Callbacks.PostGameStarted(nil, true)
assertEquals(#startSpawnCalls, 0, "continuing an older save without a spawn marker never backfills the reward")
api.Callbacks.PostGameStarted(nil, false)
assertEquals(#startSpawnCalls, 1, "a fresh co-op run spawns exactly one shared ring pedestal")
assertEquals(startSpawnCalls[1].pickup.Type, EntityType.ENTITY_PICKUP, "starting reward is a pickup")
assertEquals(startSpawnCalls[1].pickup.Variant, PickupVariant.PICKUP_COLLECTIBLE, "starting reward is a collectible pedestal")
assertEquals(startSpawnCalls[1].pickup.SubType, api.ItemId, "starting reward is the registered ring")
assertEquals(startSpawnCalls[1].position, safeStartPosition, "starting pedestal uses the room's safe position")
assertEquals(startSpawnCalls[1].spawner, nil, "starting reward is room-owned, not assigned to a co-op player")
assertEquals(startPlayerOne:GetActiveItem(0), 0, "spawning never equips the ring on player one")
assertEquals(startPlayerTwo:GetActiveItem(0), 0, "spawning never equips the ring on player two")
assertTruthy(api.GetSavedState().startingPedestalSpawned, "successful starting spawn is recorded in run data")

api.Callbacks.PostPEffectUpdate(nil, startPlayerOne)
api.Callbacks.PostPEffectUpdate(nil, startPlayerTwo)
api.Callbacks.PostNewRoom()
api.Callbacks.PostNewLevel()
api.Callbacks.PostGameStarted(nil, true)
assertEquals(#startSpawnCalls, 1, "updates, rooms, floors, and continue never repeat the starting reward")

api.Callbacks.PostGameStarted(nil, false)
assertEquals(#startSpawnCalls, 2, "another fresh run spawns again even when its start seed is unchanged")

local registeredRingConfig = itemConfigs[api.ItemId]
itemConfigs[api.ItemId] = nil
api.Callbacks.PostGameStarted(nil, false)
assertEquals(#startSpawnCalls, 2, "missing ring registration never creates an invalid pedestal")
assertEquals(api.GetSavedState().startingPedestalSpawned, false, "failed validation is not recorded as a spawn")
itemConfigs[api.ItemId] = registeredRingConfig

Isaac.Spawn = function() error("simulated spawn failure") end
local startOk = pcall(api.Callbacks.PostGameStarted, nil, false)
assertTruthy(startOk, "a failed owned starting spawn must not prevent the game from loading")
assertEquals(api.GetSavedState().startingPedestalSpawned, false, "failed engine spawn is not recorded as success")

local xml = readFile("content/items.xml")
-- Regressions from the in-game Q4 report: test the actual pickup transaction,
-- not just the isolated pool-selection helper.
api.ResetForTest()
player = makePlayer(707)
players = { player }
api.ActivatePlayer(player)
local drawCount, poolMode, frame = 0, "legal", 100
local rewards, spawnMode = {}, "normal"
local room = {
    GetType = function() return 2 end,
    FindFreePickupSpawnPosition = function(_, position) return position end,
    IsPositionInRoom = function() return true end,
    GetGridCollisionAtPos = function() return 0 end,
}
local pickupPool = {
    GetPoolForRoom = function() return 7 end,
    GetCollectible = function(_, poolType)
        assertEquals(poolType, 7, "pedestal replacement keeps the selected room pool")
        drawCount = drawCount + 1
        if poolMode == "error" then error("simulated engine pool failure") end
        return poolMode == "legal" and 25 or 500
    end,
}
Game = function()
    return {
        GetRoom = function() return room end,
        GetItemPool = function() return pickupPool end,
        GetFrameCount = function() return frame end,
    }
end
local function makePedestal(seed)
    local data = { NeverbirthSevenCursesBlocked = true }
    local pickup = { Variant = 100, SubType = 500, InitSeed = seed, Visible = true, Wait = 0,
        Price = -2, ShopItemId = 4, AutoUpdatePrice = false, OptionsPickupIndex = 6,
        Position = Vector(120, 150), dropSeed = seed * 2, removed = false }
    function pickup:Exists() return not self.removed end
    function pickup:ToPickup() return self end
    function pickup:Remove() self.removed = true end
    function pickup:GetDropRNG() return { GetSeed = function() return self.dropSeed end } end
    function pickup:GetData() return data end
    function pickup:Morph(kind, variant, subtype)
        self.Variant, self.SubType = variant, subtype
        self.Price, self.ShopItemId, self.AutoUpdatePrice, self.OptionsPickupIndex = 0, -1, true, 0
        data = { NeverbirthSevenCursesBlocked = true }
    end
    return pickup
end
Isaac.Spawn = function(kind, variant, subtype, position, velocity, spawner)
    if spawnMode == "fail" then error("simulated compensation spawn failure") end
    assertEquals(kind, 5, "compensation is a native pickup")
    assertEquals(variant, 100, "compensation is a collectible")
    assertEquals(getmetatable(position), vectorValueType, "Spawn receives a constructed Vector position")
    assertEquals(getmetatable(velocity), vectorValueType, "Spawn receives a constructed Vector velocity")
    assertTruthy(not api.IsForbiddenCollectible(subtype), "candidate is validated before Spawn")
    assertTruthy(position.X ~= spawner.Position.X or position.Y ~= spawner.Position.Y,
        "compensation is beside the source, not on top of it")
    local reward = makePedestal(90000 + #rewards)
    reward.SubType = (spawnMode == "modded" or spawnMode == "morph-error") and 800 or subtype
    if spawnMode == "morph-error" then
        reward.Morph = function() error("simulated owned compensation Morph failure") end
    end
    reward.Position = position
    rewards[#rewards + 1] = reward
    -- Model a re-entrant pickup callback while the owned spawn is in flight.
    api.Callbacks.PostPickupUpdate(nil, reward)
    return reward
end
assertEquals(api.Callbacks.PostGetCollectible(nil, 500, 7, true, 300), nil,
    "pool selection must not silently replace the Q4 before it appears")
assertEquals(drawCount, 0, "ordinary pool selection does not draw compensation")
local morphedPickup = makePedestal(8001)
api.Callbacks.PostPickupUpdate(nil, morphedPickup)
assertEquals(morphedPickup.SubType, 500, "original Q4 is retained visibly")
assertEquals(#rewards, 1, "one legal compensation is created")
assertEquals(rewards[1].SubType, 25, "compensation can be a legal non-Q4 item")
assertEquals(morphedPickup.Price, -2, "source deal price is untouched")
assertEquals(rewards[1].Price, -2, "compensation preserves the trade cost")
assertEquals(morphedPickup.ShopItemId, 4, "source shop identity is untouched")
assertEquals(morphedPickup.OptionsPickupIndex, 6, "source choice group is untouched")
assertEquals(rewards[1].OptionsPickupIndex, 0, "taking compensation must not erase the original Q4")
assertEquals(morphedPickup.AutoUpdatePrice, false, "source price mode is untouched")
assertEquals(morphedPickup.Position.X, 120, "original position is unchanged")
assertEquals(api.Callbacks.PrePickupCollision(nil, morphedPickup, player), true, "original Q4 is not collectible")
assertEquals(api.Callbacks.PrePickupCollision(nil, rewards[1], player), nil, "compensation is collectible")
rewards[1]:Remove()
for _ = 1, 20 do api.Callbacks.PostPickupUpdate(nil, morphedPickup) end
assertEquals(#rewards, 1, "taking compensation does not rearm the unchanged Q4")
api.Callbacks.PostNewRoom()
local reloadedPickup = makePedestal(8001)
api.Callbacks.PostPickupUpdate(nil, reloadedPickup)
api.Callbacks.PostGameStarted(nil, true)
api.Callbacks.PostPickupUpdate(nil, makePedestal(8001))
assertEquals(#rewards, 1, "room re-entry and continue do not duplicate compensation")
morphedPickup.SubType = 25
api.Callbacks.PostPickupUpdate(nil, morphedPickup)
assertEquals(api.Callbacks.PrePickupCollision(nil, morphedPickup, player), nil, "external legal reroll is collectible")
morphedPickup.SubType = 500
api.Callbacks.PostPickupUpdate(nil, morphedPickup)
assertEquals(#rewards, 2, "a new Q4 after an observed legal result awards again")
morphedPickup.dropSeed = morphedPickup.dropSeed + 1
api.Callbacks.PostPickupUpdate(nil, morphedPickup)
assertEquals(#rewards, 3, "same-ID Q4 with a changed reroll seed awards once again")
api.Callbacks.PostPickupUpdate(nil, morphedPickup)
assertEquals(#rewards, 3, "the same reroll generation is not settled twice")
morphedPickup.InitSeed = 18001
api.Callbacks.PostPickupUpdate(nil, morphedPickup)
assertEquals(#rewards, 4, "engine reseeding the pedestal is a new generation")
spawnMode = "modded"
api.Callbacks.PostPickupUpdate(nil, makePedestal(8100))
assertEquals(#rewards, 5, "a spawn modifier cannot create recursive compensation chains")
assertEquals(rewards[5].SubType, 25, "spawned compensation is revalidated and corrected in place")
spawnMode = "morph-error"
local morphErrorSource = makePedestal(8101)
api.Callbacks.PostPickupUpdate(nil, morphErrorSource)
assertEquals(#rewards, 6, "a failed correction does not spawn another reward")
assertEquals(rewards[6]:Exists(), false, "an error after Spawn cleans up only the owned reward")
assertEquals(morphErrorSource:Exists(), true, "owned correction failure never removes the source")
assertEquals(morphErrorSource.SubType, 500, "owned correction failure preserves the original Q4")
spawnMode = "normal"

poolMode, drawCount = "forbidden", 0
local failedPickup = makePedestal(8002)
api.Callbacks.PostPickupUpdate(nil, failedPickup)
assertEquals(drawCount, 40, "selection has a finite retry budget")
for _ = 1, 20 do api.Callbacks.PostPickupUpdate(nil, failedPickup) end
assertEquals(drawCount, 40, "a failed pedestal does not reroll 40 more times every frame")
assertEquals(failedPickup.SubType, 500, "failure never replaces the original with an empty item")
assertEquals(api.Callbacks.PrePickupCollision(nil, failedPickup, player), true,
    "failed forbidden source remains blocked")
failedPickup.SubType = 25
assertEquals(api.Callbacks.PrePickupCollision(nil, failedPickup, player), nil,
    "an external legal reroll releases the old failed source")

poolMode, drawCount = "error", 0
debugMessages = {}
api.Callbacks.PostPickupUpdate(nil, makePedestal(8003))
assertEquals(drawCount, 1, "an engine API error aborts rather than repeating the same invalid call")
assertTruthy(table.concat(debugMessages, "\n"):find("simulated engine pool failure", 1, true),
    "the engine error is not concealed as an empty item pool")
drawCount = 0
pickupPool.GetPoolForRoom = function() return -1 end
local sourcelessPickup = makePedestal(8004)
api.Callbacks.PostPickupUpdate(nil, sourcelessPickup)
assertEquals(drawCount, 0, "an invalid source pool is never passed into GetCollectible")
assertEquals(sourcelessPickup.SubType, 500, "no arbitrary fallback item replaces an unknown-pool source")

-- A native active dropped by the confirmed ring pickup is an old possession,
-- not a new encounter. This must not be implemented as a global c105 whitelist.
pickupPool.GetPoolForRoom = function() return 7 end
poolMode, drawCount = "legal", 0
api.ResetForTest()
player = makePlayer(808)
player.activeItems[0] = 105
players = { player }
rewards = {}
local swappedD6 = makePedestal(8200)
swappedD6.SubType = api.ItemId
api.Callbacks.PrePickupCollision(nil, swappedD6, player)
assertEquals(api.GetPlayerState(player) and api.GetPlayerState(player).active, nil,
    "collision alone does not activate the contract")
player.activeItems[0], swappedD6.SubType = api.ItemId, 105
swappedD6.dropSeed = 82001
api.Callbacks.PostPEffectUpdate(nil, player)
api.Callbacks.PostPickupUpdate(nil, swappedD6)
assertEquals(swappedD6.SubType, 105, "character-native D6 stays on its own pedestal")
assertEquals(#rewards, 0, "swapped character-native D6 generates no compensation")
api.Callbacks.PostGameStarted(nil, true)
local continuedD6 = makePedestal(8200)
continuedD6.SubType, continuedD6.dropSeed = 105, 82001
api.Callbacks.PostPickupUpdate(nil, continuedD6)
assertEquals(#rewards, 0, "native-source exemption survives continue")
local newD6 = makePedestal(8201)
newD6.SubType = 105
api.Callbacks.PostPickupUpdate(nil, newD6)
assertEquals(#rewards, 1, "a newly encountered D6 is not globally exempted")
local secondPlayer = makePlayer(809)
players[2] = secondPlayer
api.ActivatePlayer(secondPlayer)
api.Callbacks.PostPickupUpdate(nil, newD6)
assertEquals(#rewards, 1, "two ring owners do not duplicate a shared pedestal reward")
swappedD6.SubType = 500
api.Callbacks.PostPickupUpdate(nil, swappedD6)
assertEquals(#rewards, 2, "an external reroll ends the old-possession exemption")

local rewardCount = #rewards
spawnMode = "fail"
local failedSpawn = makePedestal(8300)
api.Callbacks.PostPickupUpdate(nil, failedSpawn)
api.Callbacks.PostPickupUpdate(nil, failedSpawn)
assertEquals(#rewards, rewardCount, "spawn failure does not issue a phantom reward")
assertEquals(failedSpawn.SubType, 500, "spawn failure preserves original Q4")
spawnMode = "normal"
failedSpawn.dropSeed = failedSpawn.dropSeed + 1
api.Callbacks.PostPickupUpdate(nil, failedSpawn)
assertEquals(#rewards, rewardCount + 1, "a new reroll may retry after a failed spawn")

local noSpaceCount = #rewards
room.FindFreePickupSpawnPosition = function() return Vector(120, 150) end
api.Callbacks.PostPickupUpdate(nil, makePedestal(8301))
assertEquals(#rewards, noSpaceCount, "no safe separate position means no overlapping compensation")
room.FindFreePickupSpawnPosition = function(_, position) return position end

local pendingPlayer = makePlayer(810)
pendingPlayer.activeItems[0] = 105
players[3] = pendingPlayer
local canceledRing = makePedestal(8400)
canceledRing.SubType = api.ItemId
api.Callbacks.PrePickupCollision(nil, canceledRing, pendingPlayer)
frame = frame + 16
api.Callbacks.PostPEffectUpdate(nil, pendingPlayer)
pendingPlayer.activeItems[0], canceledRing.SubType = api.ItemId, 105
api.Callbacks.PostPEffectUpdate(nil, pendingPlayer)
api.Callbacks.PostPickupUpdate(nil, canceledRing)
assertEquals(#rewards, noSpaceCount + 1, "expired collision is not proof of a native active swap")

local moddedSource = makePedestal(8401)
moddedSource.SubType = 800
api.Callbacks.PostPickupUpdate(nil, moddedSource)
assertEquals(moddedSource.SubType, 800, "modded source is retained rather than overwritten")
assertEquals(#rewards, noSpaceCount + 2, "modded source gets one validated compensation")
assertEquals(api.Callbacks.PrePickupCollision(nil, moddedSource, player), true, "modded source stays blocked")

-- Read-only generation state contains no engine objects, and reload into a
-- fresh module reconstructs settlement from the saved plain tables.
local function assertPlain(value, seen)
    assertTruthy(type(value) ~= "function" and type(value) ~= "userdata", "saved data is plain")
    if type(value) ~= "table" then return end
    seen = seen or {}
    if seen[value] then error("saved data cannot contain cycles") end
    seen[value] = true
    for key, entry in pairs(value) do assertPlain(key, seen); assertPlain(entry, seen) end
    seen[value] = nil
end
assertPlain(saveRoot)
local reloadMod = { AddCallback = function() end }
initialize(reloadMod, {
    ItemId = 9000, TrinketId = 9900,
    GetPlayers = function() return players end,
    GetSaveRoot = function() return saveRoot end,
    GetCurrentRunSeed = function() return "test-run" end,
    GetRoomKey = function() return currentRoomKey end,
})
local reloadAPI = reloadMod.RingOfSevenCursesTestAPI
local rewardCountBeforeReload = #rewards
reloadAPI.Callbacks.PostGameStarted(nil, true)
local restoredModded = makePedestal(8401)
restoredModded.SubType = 800
reloadAPI.Callbacks.PostPickupUpdate(nil, restoredModded)
assertEquals(#rewards, rewardCountBeforeReload, "module reload does not duplicate a completed compensation")

local pickupUpdateRegistered, collisionRegistered = false, false
for _, callback in ipairs(callbacks) do
    if callback.id == ModCallbacks.MC_POST_PICKUP_UPDATE and callback.filter == 100 then
        pickupUpdateRegistered = callback.fn == api.Callbacks.PostPickupUpdate
    elseif callback.id == ModCallbacks.MC_PRE_PICKUP_COLLISION then
        collisionRegistered = callback.fn == api.Callbacks.PrePickupCollision
    end
end
assertTruthy(pickupUpdateRegistered, "real collectible update callback is registered with the narrow filter")
assertTruthy(collisionRegistered, "real collision callback is registered")

assertTruthy(xml:find('name="Ring of the Seven Curses"', 1, true), "English registration exists")
assertTruthy(xml:find('gfx="RingOfTheSevenCurses.png"', 1, true), "icon path is registered")
assertTruthy(xml:find('name="Ring of the Seven Curses"[^>]-quality="0"', 1), "quality is locked to 0")
assertTruthy(xml:find('name="Ring of the Seven Curses"[^>]-maxcharges="0"', 1), "maximum charge is locked to 0")
assertTruthy(xml:find("name=\"Ring of the Seven Curses\"[^>]-description=\"This world isn't worth it%.\"", 1),
    "English subtitle is registered")
assertTruthy(xml:find('<trinket[^>]-name="Seven Curses Slot Seal"[^>]-gfx="447586_trinket%.png"[^>]-id="1"[^>]-hidden="true"', 1),
    "the hidden slot-seal trinket uses the delivered visual placeholder")
for _, suffix in ipairs({ "", ".en_us", ".zh_cn" }) do
    local localizedXml = readFile("content/items" .. suffix .. ".xml")
    local root = assert(localizedXml:match('gfxroot="([^"]+)"'))
    local trinket = assert(localizedXml:match('<trinket[^>]-name="Seven Curses Slot Seal"[^>]+>'))
    local gfx = assert(trinket:match('gfx="([^"]+)"'))
    -- The native loader inserts the category folder itself, as in vanilla
    -- items.xml and Samael's hidden, visibly held Feather trinket.
    local png = readFile("resources/" .. root .. "Trinkets/" .. gfx)
    local width, height = string.unpack(">I4I4", png, 17)
    assertEquals(width, 32, "native trinket HUD texture width")
    assertEquals(height, 32, "native trinket HUD texture height")
end

local pools = readFile("content/itempools.xml")
assertEquals(pools:find("Ring of the Seven Curses", 1, true), nil, "the item is intentionally absent from every item pool")

print("ring_of_the_seven_curses_behavior_test: ok")
