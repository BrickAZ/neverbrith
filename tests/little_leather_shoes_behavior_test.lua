local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > (epsilon or 0.0001) then
        error((message or "assertion failed") .. ": expected near " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end
local function readFile(path)
    local file = assert(io.open(path, "r"), path .. " should exist")
    local text = file:read("*a")
    file:close()
    return text
end

local source = readFile("main.lua")
local block = source:match("%-%- LITTLE_LEATHER_SHOES_BEGIN(.-)%-%- LITTLE_LEATHER_SHOES_END")

assertTruthy(block, "main.lua should contain the isolated Little Leather Shoes runtime block")
assertTruthy(block:find("LittleLeatherShoesTestAPI", 1, true), "runtime block should expose deterministic behavior helpers")
assertTruthy(block:find("MC_POST_NPC_INIT", 1, true), "runtime block should register NPC init handling")
assertTruthy(block:find("MC_POST_ENTITY_KILL", 1, true), "runtime block should register entity death handling")
assertTruthy(block:find("MC_PRE_SPAWN_CLEAN_AWARD", 1, true), "runtime block should own deferred clear settlement")
assertTruthy(block:find("MC_POST_PICKUP_UPDATE", 1, true), "runtime block should track only the three derivative pedestals")
assertEquals(block:find("MC_PRE_PICKUP_COLLISION", 1, true), nil,
    "Traffic rewards must not depend on the pre-collision callback chain")
assertEquals(block:find("pendingPickups", 1, true), nil,
    "Traffic rewards must not depend on collision-created pending records")
assertEquals(block:find("local function initTrafficPickup", 1, true), nil,
    "Traffic rewards must keep the native collectible pedestal sprite")
assertEquals(block:find("MC_POST_PICKUP_INIT", 1, true), nil,
    "Traffic effect ANM2 files must not be loaded into native collectible pedestal sprites")
assertTruthy(block:find("pendingHeatRefreshes", 1, true),
    "Heat must defer its cache refresh until after the pickup queue has settled")
assertTruthy(block:find("resources-dlc3.zh/font/teammeatfontextended10.fnt", 1, true),
    "Chinese Traffic HUD must use the vanilla Repentance Chinese font")
assertTruthy(block:find("DrawStringUTF8", 1, true),
    "Chinese Traffic HUD must use a UTF-8-aware font draw call")
local roomScanCount = 0
for _ in block:gmatch("for _, entity in ipairs%(Isaac%.GetRoomEntities and Isaac%.GetRoomEntities%(%) or {}%) do") do roomScanCount = roomScanCount + 1 end
assertEquals(roomScanCount, 1, "runtime should contain exactly one room-entity scan in the one-time room scan helper")
assertEquals(block:find("FindByType", 1, true), nil, "runtime must not perform a per-frame global entity scan")

dofile("tests/localization_test.lua")
local api = assert(Neverbirth and Neverbirth.LittleLeatherShoesTestAPI, "runtime API should load through the full main.lua entry")
local state = assert(Neverbirth.LittleLeatherShoesState, "runtime state should exist")

assertTruthy(type(api.Render) == "function", "runtime API should expose the real Traffic HUD renderer")
local originalFont, originalKColor, originalOptions = Font, KColor, Options
local originalRenderText = Isaac.RenderText
local loadedFonts, fontDraws, fallbackDraws = {}, {}, {}
KColor = function(r, g, b, a) return { R = r, G = g, B = b, A = a } end
Font = function()
    return {
        Load = function(_, path) loadedFonts[#loadedFonts + 1] = path; return true end,
        DrawStringUTF8 = function(_, text) fontDraws[#fontDraws + 1] = { method = "utf8", text = text } end,
        DrawString = function(_, text) fontDraws[#fontDraws + 1] = { method = "ascii", text = text } end,
    }
end
Options = { Language = "zh" }
Isaac.RenderText = function(text) fallbackDraws[#fallbackDraws + 1] = text end
api.ResetTransientState(true)
state.floorTraffic = 1
api.Render()
assertEquals(loadedFonts[1], "resources-dlc3.zh/font/teammeatfontextended10.fnt",
    "Chinese Traffic HUD should load the vanilla Chinese 10px font")
assertEquals(fontDraws[1].method, "utf8", "Chinese Traffic HUD should use DrawStringUTF8")
assertEquals(fontDraws[1].text, "流量 1 还差 5", "Chinese Traffic HUD should render the intended readable label")
assertEquals(#fallbackDraws, 0, "successful Chinese font rendering must not also draw the ASCII fallback")
api.Render()
assertEquals(#loadedFonts, 1, "Traffic HUD font should be cached instead of loading every render frame")

state.hudFonts = {}
Font = function() return { Load = function() return false end } end
fallbackDraws = {}
api.Render()
assertEquals(fallbackDraws[1], "Traffic 1 Next +5",
    "failed Chinese font loading should fall back to readable ASCII instead of garbled UTF-8")
Font, KColor, Options = originalFont, originalKColor, originalOptions
Isaac.RenderText = originalRenderText

assertEquals(api.GetReturnChance(1), 33, "first death return chance")
assertEquals(api.GetReturnChance(2), 22, "second death return chance")
assertEquals(api.GetReturnChance(3), 11, "third death return chance")
assertEquals(api.GetReturnChance(4), 0, "fourth death must end the chain")
assertEquals(api.ShouldReturn(32, 1), true, "33 percent boundary should succeed below 33")
assertEquals(api.ShouldReturn(33, 1), false, "33 percent boundary should fail at 33")
assertEquals(api.GetRoomTraffic({ { deaths = 5 }, { deaths = 6 }, { deaths = 2 } }), 6,
    "5/6/2 room traffic should use the maximum valid chain death count")
assertEquals(api.GetRoomTraffic({ { deaths = 1, excluded = true } }), 0, "excluded split chains must not contribute")
assertEquals(api.GetTier(5), 0, "five traffic tier")
assertEquals(api.GetTier(6), 1, "six traffic tier")
assertEquals(api.GetTier(7), 1, "seven traffic tier")
assertEquals(api.GetTier(8), 2, "eight traffic tier")
assertEquals(api.GetTier(11), 2, "eleven traffic tier")
assertEquals(api.GetTier(12), 3, "twelve traffic tier")
local target, remaining = api.GetNextTrafficTarget(11)
assertEquals(target, 12, "next target below maximum")
assertEquals(remaining, 1, "remaining traffic below maximum")
target, remaining = api.GetNextTrafficTarget(12)
assertEquals(target, nil, "maximum tier has no next target")
assertEquals(remaining, 0, "maximum tier has no remaining traffic")
assertNear(api.ApplyTearsBonus(9, 1), 30 / 3.5 - 1, 0.0001, "Heat should add exactly 0.5 tears")
assertNear(api.ApplyTearsBonus(9, 2), 30 / 4 - 1, 0.0001, "two genuine Heat pickups should add exactly 1.0 tears")

assertTruthy(type(api.HandleFloorOwnership) == "function", "runtime API should expose floor-locked ownership handling")
api.ResetTransientState(true)
state.floorTraffic = 9
state.pendingReturns = { { due = 10 } }
api.HandleFloorOwnership(false)
assertEquals(state.floorEnabled, true, "mid-floor loss must keep traffic enabled")
assertEquals(state.returnsEnabled, false, "mid-floor loss must disable future returns")
assertEquals(state.floorTraffic, 9, "mid-floor loss must preserve accumulated traffic")
assertEquals(#state.pendingReturns, 0, "mid-floor loss must cancel pending returns")
api.ResetTransientState(false)
api.HandleFloorOwnership(true)
assertEquals(state.floorEnabled, false, "mid-floor acquisition must wait until the next floor")
assertEquals(state.returnsEnabled, false, "mid-floor acquisition must not enable returns")
local callbacks = assert(api.Callbacks, "runtime API should expose the actual callback handlers")
local currentRoomType = 1
local runtimePlayers = {}
local room = {
    GetSpawnSeed = function() return 2468 end,
    GetType = function() return currentRoomType end,
    GetCenterPos = function() return Vector(320, 280) end,
    IsClear = function() return true end,
    IsAmbushDone = function() return true end,
    SpawnClearAward = function(self) self.awards = (self.awards or 0) + 1 end,
}
local itemPool = {
    requestedTypes = {},
    GetPoolForRoom = function(self, roomType)
        self.requestedTypes[#self.requestedTypes + 1] = roomType
        return roomType + 100
    end,
    GetCollectible = function(_, poolType) return poolType + 700 end,
}
Game = function()
    return {
        GetRoom = function() return room end,
        GetLevel = function()
            return {
                GetStage = function() return 1 end,
                GetStageType = function() return 0 end,
                GetDimension = function() return 0 end,
                GetCurrentRoomIndex = function() return 9 end,
            }
        end,
        GetItemPool = function() return itemPool end,
        GetNumPlayers = function() return #runtimePlayers end,
    }
end
Isaac.GetPlayer = function(index) return runtimePlayers[(index or 0) + 1] end

local function newNpc(options)
    options = options or {}
    local npc = {
        Type = options.type or 10,
        Variant = options.variant or 0,
        SubType = options.subtype or 0,
        InitSeed = options.seed or math.random(1000, 9000),
        Position = Vector(100, 100),
        MaxHitPoints = 20,
        HitPoints = 0,
        GroupIdx = options.groupIdx == nil and -1 or options.groupIdx,
        Parent = options.parent,
        Child = options.child,
        ParentNPC = options.parentNpc,
        ChildNPC = options.childNpc,
        SpawnerEntity = options.spawner,
        data = {},
    }
    function npc:GetData() return self.data end
    function npc:ToNPC() return self end
    function npc:IsBoss() return options.isBoss == true end
    function npc:GetBossID() return options.bossId or -1 end
    function npc:IsDead() return false end
    function npc:IsEnemy() return true end
    function npc:IsVulnerableEnemy() return true end
    function npc:IsActiveEnemy() return true end
    function npc:HasEntityFlags() return false end
    function npc:IsChampion() return options.champion == true end
    function npc:GetChampionColorIdx() return options.championColor or -1 end
    return npc
end

api.ResetTransientState(true)
local normal = newNpc({ seed = 1001 })
local summon = newNpc({ seed = 1002, spawner = newNpc({ seed = 5000, isBoss = true }) })
local boss = newNpc({ seed = 1003, isBoss = true })
local miniBoss = newNpc({ seed = 1004, bossId = 12 })
local segment = newNpc({ seed = 1005, parent = { Exists = function() return true end } })
local groupZero = newNpc({ seed = 1007, groupIdx = 0 })
assertEquals(api.IsEligibleNpc(normal), true, "normal enemies should be eligible")
assertEquals(api.IsEligibleNpc(summon), true, "live summons should remain eligible")
assertEquals(api.IsEligibleNpc(boss), false, "Bosses should be excluded")
assertEquals(api.IsEligibleNpc(miniBoss), false, "mini Bosses should be excluded")
assertEquals(api.IsEligibleNpc(segment), false, "segmented enemies should be excluded")
assertEquals(api.IsEligibleNpc(groupZero), true, "GroupIdx zero is the ungrouped default and must remain eligible")
assertEquals(callbacks.NpcInit({}, normal), nil, "NPC init callback should return nil")
assertTruthy(normal.data.NeverbirthLittleLeatherShoesChainId, "normal NPC should receive a chain")
assertEquals(callbacks.NpcInit({}, summon), nil, "summon NPC init callback should return nil")
assertTruthy(summon.data.NeverbirthLittleLeatherShoesChainId, "summon NPC should receive an independent chain")
assertEquals(callbacks.EntityKill({}, normal), nil, "entity kill callback should return nil")
local splitChild = newNpc({ seed = 1006, spawner = normal })
assertEquals(callbacks.NpcInit({}, splitChild), nil, "split-child init callback should return nil")
local chain = state.rooms[normal.data.NeverbirthLittleLeatherShoesRoomKey].chains[normal.data.NeverbirthLittleLeatherShoesChainId]
assertEquals(chain.excluded, true, "death-spawned split child should exclude its parent chain")
assertEquals(splitChild.data.NeverbirthLittleLeatherShoesChainId, nil, "death-spawned split child should not get a chain")
assertEquals(callbacks.PreClearAward({}), true, "pending split observation should defer clear award")

api.ResetTransientState(true)
assertEquals(callbacks.PreClearAward({}), nil, "clear callback without pending entities should return nil")
assertEquals(api.GetRoomTraffic({ 4, 3, 2 }), 4, "numeric chain list should settle to its maximum")
assertEquals(#api.GetRewardItemsForTraffic(5), 0, "five traffic should spawn nothing")
assertEquals(#api.GetRewardItemsForTraffic(6), 1, "six traffic should spawn one reward")
assertEquals(#api.GetRewardItemsForTraffic(7), 1, "seven traffic should spawn one reward")
assertEquals(#api.GetRewardItemsForTraffic(8), 1, "eight traffic should spawn one reward")
assertEquals(#api.GetRewardItemsForTraffic(11), 1, "eleven traffic should spawn one reward")
assertEquals(#api.GetRewardItemsForTraffic(12), 2, "twelve traffic should spawn a choice pair")

local spawned = {}
Isaac.Spawn = function(entityType, variant, subtype, position)
    local pickup = { Type = entityType, Variant = variant, SubType = subtype, Position = position, InitSeed = 8000 + #spawned, data = {}, removed = false }
    function pickup:GetData() return self.data end
    function pickup:Remove() self.removed = true end
    spawned[#spawned + 1] = pickup
    return pickup
end
local pair = api.SpawnTrafficBossReward(3)
assertEquals(#pair, 2, "tier three should create exactly two pedestals")
assertEquals(api.ResolveChoiceAtCollision(pair[1]), true, "first choice should resolve")
assertEquals(pair[2].removed, true, "choosing one tier-three reward should remove the other")
assertEquals(api.ResolveChoiceAtCollision(pair[2]), false, "removed sibling must not resolve a second choice")

currentRoomType = 5
assertEquals(api.ResolveExposure(Vector(200, 200)), true, "Exposure should draw from a valid current room pool")
assertEquals(itemPool.requestedTypes[#itemPool.requestedTypes], 5, "Exposure should use the room type at pickup time")
currentRoomType = 14
assertEquals(api.ResolveExposure(Vector(220, 200)), true, "Exposure should support a later room type")
assertEquals(itemPool.requestedTypes[#itemPool.requestedTypes], 14, "Exposure must not retain its generation-time pool")
assertTruthy(type(api.ProcessTrafficInventory) == "function", "runtime API should expose fixed-ID inventory processing")
assertTruthy(type(callbacks.TrackTrafficPickup) == "function", "runtime must track derivative pedestal positions without collision callbacks")
assertTruthy(type(api.QueuePickupVisual) == "function", "runtime API should expose real Pickup animation queuing")
assertTruthy(type(api.ProcessPickupVisuals) == "function", "runtime API should expose real Pickup animation processing")

Sprite = function()
    return {
        Load = function() end,
        Play = function() end,
        Update = function() end,
        IsFinished = function() return false end,
        Render = function() end,
    }
end

local function newTrafficPlayer(seed, itemId)
    local player = {
        InitSeed = seed,
        Position = Vector(300, 200),
        MaxFireDelay = 10,
        collectibles = { [itemId] = 1 },
        removed = {},
        cacheFlags = {},
    }
    function player:ToPlayer() return self end
    function player:Exists() return true end
    function player:HasCollectible() return false end
    function player:GetCollectibleNum(id) return self.collectibles[id] or 0 end
    function player:RemoveCollectible(id)
        self.removed[id] = (self.removed[id] or 0) + 1
        self.collectibles[id] = math.max(0, (self.collectibles[id] or 0) - 1)
    end
    function player:AddCacheFlags(flag) self.cacheFlags[#self.cacheFlags + 1] = flag end
    function player:EvaluateItems() callbacks.EvaluateHeat({}, self, 16) end
    return player
end

local function newTrafficPedestal(itemId, seed, position)
    local pickup = { Variant = 100, SubType = itemId, InitSeed = seed, Position = position, data = {} }
    function pickup:GetData() return self.data end
    function pickup:Exists() return true end
    function pickup:Remove() self.removed = true end
    return pickup
end

local unboxingId = api.GetRewardItemsForTraffic(6)[1]
api.ResetTransientState(false)
local unboxingPlayer = newTrafficPlayer(420, unboxingId)
local unboxingPickup = newTrafficPedestal(unboxingId, 9200, Vector(250, 200))
runtimePlayers = { unboxingPlayer }
assertEquals(callbacks.TrackTrafficPickup({}, unboxingPickup), nil, "pedestal tracking callback must return nil")
api.Update()
assertEquals(unboxingPlayer.removed[unboxingId], 1, "inventory-observed Unboxing must be consumed exactly once")
assertEquals(#state.visuals, 1, "inventory-observed Unboxing must queue its Pickup animation")
assertEquals(state.visuals[1].chest, true, "inventory-observed Unboxing must queue a normal chest")
api.Update()
assertEquals(unboxingPlayer.removed[unboxingId], 1, "Unboxing must not repeat after removal")

local exposureId = api.GetRewardItemsForTraffic(8)[1]
api.ResetTransientState(false)
currentRoomType = 14
local exposurePlayer = newTrafficPlayer(421, exposureId)
local exposurePickup = newTrafficPedestal(exposureId, 9201, Vector(260, 200))
runtimePlayers = { exposurePlayer }
callbacks.TrackTrafficPickup({}, exposurePickup)
local beforeExposureSpawns = #spawned
api.Update()
assertEquals(exposurePlayer.removed[exposureId], 1, "inventory-observed Exposure must be consumed exactly once")
assertEquals(#spawned, beforeExposureSpawns + 1, "inventory-observed Exposure must spawn one collectible pedestal")
assertEquals(spawned[#spawned].SubType, currentRoomType + 800,
    "Exposure must draw from the room pool at inventory-processing time")

local heatId = api.GetRewardItemsForTraffic(12)[2]
api.ResetTransientState(false)
local heatInventoryPlayer = newTrafficPlayer(422, heatId)
local heatPickup = newTrafficPedestal(heatId, 9202, Vector(270, 200))
runtimePlayers = { heatInventoryPlayer }
callbacks.TrackTrafficPickup({}, heatPickup)
api.Update()
assertEquals(heatInventoryPlayer.removed[heatId], 1, "inventory-observed Heat must be consumed exactly once")
assertEquals(heatInventoryPlayer.MaxFireDelay, 10, "Heat cache refresh must wait until the pickup update has settled")
api.Update()
assertNear(heatInventoryPlayer.MaxFireDelay, 30 / (30 / 11 + 0.5) - 1, 0.0001,
    "inventory-observed Heat must visibly add exactly 0.5 tears")
state.visuals = {}
local chestCount = 0
local originalSpawn = Isaac.Spawn
Isaac.Spawn = function(entityType, variant, subtype, position)
    if variant == 50 then chestCount = chestCount + 1 end
    return originalSpawn(entityType, variant, subtype, position)
end
Sprite = function()
    return {
        Load = function() end,
        Play = function() end,
        Update = function() end,
        IsFinished = function() return false end,
        Render = function() end,
    }
end
api.QueuePickupVisual(unboxingId, Vector(260, 200), true)
assertEquals(chestCount, 0, "Unboxing must keep the original reward order and wait for its Pickup animation")
for _ = 1, 7 do api.ProcessPickupVisuals() end
assertEquals(chestCount, 0, "Unboxing chest must not appear before frame eight")
api.ProcessPickupVisuals()
assertEquals(chestCount, 1, "Unboxing should spawn exactly one normal chest after frame eight")

local heatPlayer = { InitSeed = 501, MaxFireDelay = 9, cacheFlags = {}, evaluations = 0 }
function heatPlayer:AddCacheFlags(flag) self.cacheFlags[#self.cacheFlags + 1] = flag end
function heatPlayer:EvaluateItems() self.evaluations = self.evaluations + 1 end
api.AddHeat(heatPlayer)
assertEquals(api.GetPersistentData().heatByPlayer["501"], 1, "first Heat pickup should persist one player-owned layer")
callbacks.EvaluateHeat({}, heatPlayer, 16)
local firstHeatDelay = heatPlayer.MaxFireDelay
heatPlayer.MaxFireDelay = 9
callbacks.EvaluateHeat({}, heatPlayer, 16)
assertNear(heatPlayer.MaxFireDelay, firstHeatDelay, 0.0001, "repeated cache evaluation should be stable after the engine resets base stats")
api.AddHeat(heatPlayer)
heatPlayer.MaxFireDelay = 9
callbacks.EvaluateHeat({}, heatPlayer, 16)
assertNear(heatPlayer.MaxFireDelay, 30 / 4 - 1, 0.0001, "two genuine Heat pickups should add 1.0 tears")
local secondPlayer = { InitSeed = 502, MaxFireDelay = 9, AddCacheFlags = function() end, EvaluateItems = function() end }
api.AddHeat(secondPlayer)
assertEquals(api.GetPersistentData().heatByPlayer["501"], 2, "first player's Heat count should remain separate")
assertEquals(api.GetPersistentData().heatByPlayer["502"], 1, "second player should own an independent Heat count")

api.ResetTransientState(true)
state.floorTraffic = 5
local bossNpc = newNpc({ seed = 1100 })
api.RegisterNpc(bossNpc)
local bossRoomState = nil
for _, value in pairs(state.rooms) do bossRoomState = value end
local bossChain = bossRoomState.chains[bossNpc.data.NeverbirthLittleLeatherShoesChainId]
bossChain.deaths = 1
currentRoomType = 5
assertEquals(api.SettleCurrentRoom(), 1, "Boss room should settle its room traffic before reward tiering")
assertEquals(state.floorTraffic, 0, "Boss settlement must clear current-floor traffic")
assertEquals(#state.pendingBossRewards, 1, "six final traffic should queue only one highest-tier reward")
assertEquals(api.SettleCurrentRoom(), 1, "re-entering a settled Boss room should report the same room value")
assertEquals(#state.pendingBossRewards, 1, "re-entering a settled Boss room must not duplicate its reward")
assertTruthy(type(api.SpawnReturn) == "function", "runtime API should expose the real deferred return spawn")
api.ResetTransientState(true)
local original = newNpc({ seed = 1300 })
api.RegisterNpc(original)
local originalRoomKey = original.data.NeverbirthLittleLeatherShoesRoomKey
local originalChainId = original.data.NeverbirthLittleLeatherShoesChainId
Isaac.Spawn = function(entityType, variant, subtype, position)
    local returnedNpc = newNpc({ seed = 1301, type = entityType, variant = variant, subtype = subtype, champion = true })
    returnedNpc.Position = position
    callbacks.NpcInit({}, returnedNpc)
    return returnedNpc
end
local returned = api.SpawnReturn({
    roomKey = originalRoomKey,
    deathCount = 1,
    snapshot = {
        type = original.Type,
        variant = original.Variant,
        subtype = original.SubType,
        position = original.Position,
        initSeed = original.InitSeed,
        maxHp = 20,
        champion = true,
        championColor = 2,
        chainId = originalChainId,
        roomKey = originalRoomKey,
    },
})
assertTruthy(returned, "deferred return should spawn an NPC")
assertEquals(returned.data.NeverbirthLittleLeatherShoesChainId, originalChainId, "returned body should inherit the original chain")
local chainCount = 0
for _ in pairs(state.rooms[originalRoomKey].chains) do chainCount = chainCount + 1 end
assertEquals(chainCount, 1, "NPC init during Isaac.Spawn must not create an orphan chain for the returned body")
print("little leather shoes behavior tests passed")
