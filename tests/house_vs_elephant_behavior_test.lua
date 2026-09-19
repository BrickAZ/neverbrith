local function assertTruthy(value, message)
    if not value then error(message or "expected truthy value", 2) end
end

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "rb"), path .. " should exist")
    local value = file:read("*a")
    file:close()
    return value
end

local defaultXml = readFile("content/items.xml")
local englishXml = readFile("content/items.en_us.xml")
local chineseXml = readFile("content/items.zh_cn.xml")
for path, xml in pairs({
    ["content/items.xml"] = defaultXml,
    ["content/items.en_us.xml"] = englishXml,
}) do
    local attributes = xml:gsub("[\r\n]+", " "):match('<active%s+name="House VS Elephant"%s+(.-)/>')
    assertTruthy(attributes, path .. " must register House VS Elephant")
    assertEquals(attributes:match('id="(%d+)"'), "37", path .. " stable local ID")
    assertEquals(attributes:match('quality="(%d+)"'), "4", path .. " quality")
    assertEquals(attributes:match('maxcharges="(%d+)"'), "0", path .. " zero charge")
    assertEquals(attributes:match('gfx="([^"]+)"'), "saikeissho.png", path .. " icon")
    assertEquals(attributes:match('tags="([^"]+)"'), "summonable offensive nochallenge", path .. " tags")
end
assertTruthy(chineseXml:find('name="再契象"', 1, true), "Chinese registration")
assertTruthy(chineseXml:find('description="谁不想急头白脸来一把房子VS大象呢？"', 1, true), "fixed Chinese copy")

for _, path in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml" }) do
    local pools = readFile(path)
    local secret = pools:match('<Pool Name="secret">(.-)</Pool>')
    assertTruthy(secret and secret:find('Name="House VS Elephant" Weight="0.1"', 1, true),
        path .. " hidden-room pool weight")
    local _, count = pools:gsub('Name="House VS Elephant"', "")
    assertEquals(count, 1, path .. " must contain House VS Elephant exactly once")
end
do
    local pools = readFile("content/itempools.zh_cn.xml")
    local secret = pools:match('<Pool Name="secret">(.-)</Pool>')
    assertTruthy(secret and secret:find('Name="再契象" Weight="0.1"', 1, true), "Chinese hidden-room pool weight")
end

local source = readFile("main.lua")
local block = source:match("%-%- HOUSE_VS_ELEPHANT_BEGIN(.-)%-%- HOUSE_VS_ELEPHANT_END")
assertTruthy(block, "main.lua must contain an isolated House VS Elephant block")
assertTruthy(block:find("MC_POST_NEW_ROOM", 1, true), "encounters must be recorded on room entry")
assertTruthy(block:find("MC_PRE_PICKUP_COLLISION", 1, true), "selection must snapshot pedestal collisions")
assertTruthy(block:find("StartRoomTransition", 1, true), "completion must return to the saved room")
assertEquals(block:find("GetCollectibles", 1, true), nil, "must not scan the global ItemConfig collectible range")
assertTruthy(block:find("ITEM_ACTIVE", 1, true), "candidate filtering must explicitly exclude active items")
assertEquals(block:find("COLLECTIBLE_DEATH_CERTIFICATE", 1, true), nil, "must not borrow vanilla Death Certificate")
assertEquals(block:find("MakeRedRoomDoor", 1, true), nil, "must not create Red Rooms")
assertTruthy(block:find("local ITEMS_PER_PAGE = 6", 1, true), "House page size stays centralized at six")
assertTruthy(block:find("NeverbirthHouseGalleryControl", 1, true), "House controls use session-owned entity markers")
assertTruthy(block:find("PrevPress", 1, true) and block:find("ReturnPress", 1, true)
    and block:find("NextPress", 1, true), "House exposes all three press animations")

dofile("tests/localization_test.lua")
local api = assert(Neverbirth and Neverbirth.HouseVsElephantTestAPI, "House runtime test API should load")

local run = api.NewRunData("RUN-A")
local room = { stage = 1, stageType = 0, dimension = 0, safeGridIndex = 12 }
assertEquals(api.RecordEncounter(run, room, { Type = 5, Variant = 100, SubType = 101, InitSeed = 7001 }), true,
    "first pedestal instance is recorded")
assertEquals(api.RecordEncounter(run, room, { Type = 5, Variant = 100, SubType = 101, InitSeed = 7001 }), false,
    "same pedestal instance is recorded once")
assertEquals(api.RecordEncounter(run, room, { Type = 5, Variant = 100, SubType = 101, InitSeed = 7002 }), true,
    "second pedestal with the same collectible ID remains a separate encounter")
assertEquals(api.RecordEncounter(run, room, { Type = 5, Variant = 100, SubType = 202, InitSeed = 7003 }), true,
    "another collectible encounter is recorded")
assertEquals(api.RecordEncounter(run, room, { Type = 5, Variant = 350, SubType = 5, InitSeed = 7004 }), false,
    "non-collectible pickup is ignored")
assertEquals(#run.encounters, 3, "encounter list preserves pedestal instance count")

local playerA = { held = {} }
local playerB = { held = {} }
local candidates = api.BuildCandidates(run.encounters, { playerA, playerB }, function(player, id)
    return player.held[id] == true
end, function(id)
    return id == 202
end)
assertEquals(#candidates, 3, "active encounters are excluded and replaced by Milk fill")
assertEquals(candidates[1].itemId, 101, "first duplicate candidate retained")
assertEquals(candidates[2].itemId, 101, "second duplicate candidate retained")
assertEquals(candidates[3].itemId, 25, "one missing candidate is filled with Milk")
assertEquals(candidates[3].isMilkFallback, true, "Milk fill is marked temporary")

playerA.held[101] = true
candidates = api.BuildCandidates(run.encounters, { playerA, playerB }, function(player, id)
    return player.held[id] == true
end, function(id)
    return id == 202
end)
assertEquals(#candidates, 3, "zero eligible encounters creates three candidates")
for index = 1, 3 do assertEquals(candidates[index].itemId, 25, "all zero-candidate fills are Milk") end

local one = { { itemId = 301, encounterKey = "one" } }
local two = { { itemId = 301, encounterKey = "one" }, { itemId = 302, encounterKey = "two" } }
assertEquals(#api.BuildCandidates(one, {}, function() return false end), 3, "one candidate gets two Milk fills")
assertEquals(#api.BuildCandidates(two, {}, function() return false end), 3, "two candidates get one Milk fill")

local session = api.NewSession("token", candidates)
assertEquals(api.MarkSelected(session, 1), false, "first team selection does not finish")
assertEquals(api.MarkSelected(session, 1), false, "same pedestal cannot count twice")
assertEquals(api.MarkSelected(session, 2), false, "second team selection does not finish")
assertEquals(api.MarkSelected(session, 3), true, "third team selection finishes the shared session")
assertEquals(session.selectedCount, 3, "co-op session has one shared three-pick counter")

local continued = api.NormalizeRunData({ runSeed = "RUN-A", encounters = run.encounters,
    seenKeys = run.seenKeys, nextSequence = run.nextSequence, session = { token = "stale" } }, "RUN-A", true)
assertEquals(#continued.encounters, 3, "continue preserves encounters from the same run")
assertEquals(continued.session, nil, "continue aborts an unfinished special-room session")
local fresh = api.NormalizeRunData(continued, "RUN-B", false)
assertEquals(#fresh.encounters, 0, "a new run clears encounter history")

assertTruthy(Neverbirth.CertificateOfNeverbirthCarrierAPI, "Certificate exposes the shared carrier coordination API")

for _, case in ipairs({ { 1, 1 }, { 6, 1 }, { 7, 2 }, { 12, 2 }, { 13, 3 } }) do
    local pageCandidates = {}
    for index = 1, case[1] do pageCandidates[index] = { itemId = 500 + index, encounterKey = "page:" .. index } end
    local pageSession = api.NewSession("page-" .. case[1], pageCandidates)
    assertEquals(api.GetPageCount(pageSession), case[2], case[1] .. " candidate page count")
    assertEquals(api.GetVirtualEdges(pageSession, 1).previous, nil, "first page has no previous")
    assertEquals(api.GetVirtualEdges(pageSession, case[2]).next, nil, "last page has no next")
end
assertEquals(api.GetControlSubtype("previous"), 0, "previous control subtype")
assertEquals(api.GetControlSubtype("return"), 1, "return control subtype")
assertEquals(api.GetControlSubtype("next"), 2, "next control subtype")
assertEquals(api.GetControlAnimation("previous", "press"), "PrevPress", "previous press animation")
assertEquals(api.GetControlAnimation("return", "press"), "ReturnPress", "return press animation")
assertEquals(api.GetControlAnimation("next", "press"), "NextPress", "next press animation")

local callbacks = assert(api.Callbacks, "runtime callback API")
local currentRoomIndex = 10
local debugRoomIndex = -3
local descriptors = {
    [10] = { SafeGridIndex = 10, GridIndex = 10 },
    [-3] = { SafeGridIndex = -3, GridIndex = -3 },
}
local level = {}
function level:GetCurrentRoomIndex() return currentRoomIndex end
function level:GetCurrentRoomDesc() return descriptors[currentRoomIndex] end
function level:GetRoomByIdx(index, dimension) return dimension == 0 and descriptors[index] or nil end
function level:GetStage() return 1 end
function level:GetStageType() return 0 end
local roomModel = {}
function roomModel:GetCenterPos() return Vector(320, 280) end
function roomModel:GetTopLeftPos() return Vector(40, 120) end
function roomModel:GetBottomRightPos() return Vector(600, 440) end
function roomModel:SetClear(value) self.clear = value end
EntityCollisionClass = { ENTCOLL_NONE = 0 }
GridCollisionClass = { COLLISION_NONE = 0 }

local runtimePlayers = {}
local transitions = {}
local game = {
    GetSeeds = function() return { GetStartSeedString = function() return "HOUSE-RUNTIME" end } end,
    GetLevel = function() return level end,
    GetRoom = function() return roomModel end,
    GetNumPlayers = function() return #runtimePlayers end,
    StartRoomTransition = function(_, index, direction, animation, player, dimension)
        transitions[#transitions + 1] = { index = index, dimension = dimension, player = player }
    end,
}
Game = function() return game end
GetPtrHash = function(value) return value end

local function newPlayer(seed)
    local player = { InitSeed = seed, Position = Vector(111 + seed, 222), held = {}, counts = {}, removed = {} }
    function player:ToPlayer() return self end
    function player:HasCollectible(id) return self.held[id] == true end
    function player:GetCollectibleNum(id) return self.counts[id] or 0 end
    function player:RemoveCollectible(id, ignoreModifiers, slot, removeFromPlayerForm)
        self.removed[#self.removed + 1] = { id = id, slot = slot }
        self.held[id] = nil
    end
    return player
end
local playerOne = newPlayer(1)
local playerTwo = newPlayer(2)
runtimePlayers = { playerOne, playerTwo }
Isaac.GetPlayer = function(index) return runtimePlayers[(index or 0) + 1] end
Isaac.GetEntityVariantByName = function(name) return name == "Certificate Return Portal" and 3016 or -1 end

local roomEntities = {}
local function entityBase(entityType, variant, subtype, seed, position)
    local entity = {
        Type = entityType, Variant = variant, SubType = subtype, InitSeed = seed,
        Position = position or Vector(320, 280), exists = true, data = {},
    }
    function entity:GetData() return self.data end
    function entity:Exists() return self.exists end
    function entity:Remove() self.exists = false end
    return entity
end
local function pedestal(itemId, seed)
    return entityBase(5, 100, itemId, seed, Vector(320, 280))
end
local function initialPedestals()
    return {
        pedestal(401, 8101), pedestal(401, 8102), pedestal(402, 8103),
        pedestal(403, 8104), pedestal(404, 8105), pedestal(405, 8106),
        pedestal(406, 8107), pedestal(407, 8108), pedestal(408, 8109),
    }
end
roomEntities = initialPedestals()
Isaac.GetRoomEntities = function()
    local result = {}
    for _, entity in ipairs(roomEntities) do if entity.exists then result[#result + 1] = entity end end
    return result
end
local allAnimations = {
    PrevIdle = true, PrevDisabled = true, PrevPress = true,
    NextIdle = true, NextDisabled = true, NextPress = true,
    ReturnIdle = true, ReturnPress = true,
}
Isaac.Spawn = function(entityType, variant, subtype, position, velocity)
    local entity = entityBase(entityType, variant, subtype, 9000 + #roomEntities, position)
    if entityType == 1000 and variant == 3016 then
        entity.sprite = { lastAnimation = nil }
        function entity.sprite:HasAnimation(name) return allAnimations[name] == true end
        function entity.sprite:Play(name) self.lastAnimation = name end
        function entity:GetSprite() return self.sprite end
    end
    roomEntities[#roomEntities + 1] = entity
    return entity
end
Isaac.ExecuteCommand = function(command)
    assertEquals(command, "goto s.default.2", "House uses only the approved debug carrier command")
    currentRoomIndex = debugRoomIndex
    roomEntities = {}
    callbacks.NewRoom({})
end
local function activePedestals()
    local result = {}
    for _, entity in ipairs(roomEntities) do
        if entity.exists and entity.Type == 5 and entity.Variant == 100 and entity.SubType > 0 then
            result[#result + 1] = entity
        end
    end
    return result
end
local function activeControls(role)
    local result = {}
    for _, entity in ipairs(roomEntities) do
        local data = entity.GetData and entity:GetData() or nil
        if entity.exists and entity.Type == 1000 and entity.Variant == 3016
            and data and data.NeverbirthHouseGalleryControl
            and (role == nil or data.NeverbirthHouseControlRole == role) then
            result[#result + 1] = entity
        end
    end
    return result
end
local function advance(frames)
    for _ = 1, frames do callbacks.Update({}) end
end
local function movePlayersAway()
    playerOne.Position, playerTwo.Position = Vector(100, 200), Vector(540, 200)
    callbacks.Update({})
end
local function touchControl(role, both)
    advance(11)
    local control = assert(activeControls(role)[1], "active House control " .. role)
    playerOne.Position = control.Position
    playerTwo.Position = both and control.Position or Vector(540, 200)
    callbacks.Update({})
    return control
end
local function takeActiveCandidate(index, player)
    local target = assert(activePedestals()[index], "active House candidate " .. index)
    local itemId = target.SubType
    assertEquals(callbacks.PickupCollision({}, target, player, false), nil, "eligible candidate allows pickup")
    target.SubType = 0
    player.counts[itemId] = player:GetCollectibleNum(itemId) + 1
    callbacks.Update({})
    return target:GetData().NeverbirthHouseCandidateIndex
end

callbacks.GameStarted({}, false)
roomEntities = initialPedestals()
assertEquals(callbacks.NewRoom({}), nil, "room-entry encounter callback returns nil")
local runtimeData = api.GetPersistentData()
assertEquals(#runtimeData.encounters, 9, "room entry records every pedestal instance")
Isaac.GetItemConfig = function()
    return { GetCollectible = function(_, id) return { Type = id == 402 and 3 or 1 } end }
end
playerOne.held[api.GetItemId()] = true
local useResult = callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0)
assertEquals(useResult.ShowAnim, true, "successful House use shows its animation")
assertEquals(useResult.Remove, true, "successful House use removes the active immediately")
assertEquals(currentRoomIndex, debugRoomIndex, "House enters the controlled carrier")
assertEquals(#activePedestals(), 6, "first House page contains six candidates")
assertEquals(#activeControls(), 3, "House spawns previous, return, and next controls")
assertEquals(activeControls("previous")[1]:GetData().NeverbirthHouseControlEnabled, false, "first-page previous is disabled")
assertEquals(activeControls("next")[1]:GetData().NeverbirthHouseControlEnabled, true, "first-page next is enabled")
local certificateApi = assert(Neverbirth.CertificateOfNeverbirthTestAPI, "Certificate callback API")
local blockedCertificate = certificateApi.Callbacks.UseItem({}, certificateApi.GetItemId(), nil, playerOne, 0, 0, 0)
assertEquals(blockedCertificate.ShowAnim, false, "Certificate cannot steal the carrier from an active House session")
assertEquals(#transitions, 0, "suspended Certificate cannot redirect the active House session")

local nextControl = touchControl("next", true)
assertEquals(nextControl:GetSprite().lastAnimation, "NextPress", "House next control plays its press animation")
assertEquals(#activePedestals(), 0, "House page clears during the press animation")
advance(10)
assertEquals(runtimeData.session.pageIndex, 2, "House changes to page two after the animation")
assertEquals(#activePedestals(), 2, "second House page contains the remaining candidates")
assertEquals(activeControls("next")[1]:GetData().NeverbirthHouseControlEnabled, false, "last-page next is disabled")
movePlayersAway()
local selectedIndex = takeActiveCandidate(1, playerOne)
assertEquals(runtimeData.session.selectedCount, 1, "first selection is shared across pages")
local previousControl = touchControl("previous", false)
assertEquals(previousControl:GetSprite().lastAnimation, "PrevPress", "House previous control plays its press animation")
advance(10)
assertEquals(runtimeData.session.pageIndex, 1, "House returns to page one")
assertEquals(#activePedestals(), 6, "unselected first-page candidates rebuild unchanged")
movePlayersAway()
touchControl("next", false)
advance(10)
assertEquals(runtimeData.session.pageIndex, 2, "House can revisit page two")
assertEquals(#activePedestals(), 1, "selected House candidate does not respawn after paging")
for _, pedestal in ipairs(activePedestals()) do
    assertTruthy(pedestal:GetData().NeverbirthHouseCandidateIndex ~= selectedIndex,
        "the selected encounter instance remains absent on revisit")
end
movePlayersAway()
touchControl("previous", false)
advance(10)
assertEquals(runtimeData.session.pageIndex, 1, "House can return from the revisited last page")
assertEquals(#activePedestals(), 6, "first-page candidates remain stable after a full round trip")
movePlayersAway()
takeActiveCandidate(1, playerTwo)
assertEquals(#transitions, 0, "two team picks do not finish the shared session")
takeActiveCandidate(1, playerTwo)
assertEquals(#transitions, 1, "the third team pick still starts exactly one automatic return")
assertEquals(transitions[1].index, 10, "automatic return targets the saved origin room")
assertEquals(#activeControls(), 0, "automatic return clears House controls")
assertEquals(#playerOne.removed, 0, "completion must not delay-remove House or remove it twice")
currentRoomIndex = 10
roomEntities = {}
callbacks.NewRoom({})
assertEquals(api.GetPersistentData().session, nil, "origin arrival closes the completed session exactly once")

playerOne.Position, playerTwo.Position = Vector(112, 222), Vector(113, 222)
local earlyUse = callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0)
assertEquals(earlyUse.Remove, true, "a new House is consumed on a new session")
assertEquals(#activeControls(), 3, "new House session restores all controls")
local returnControl = touchControl("return", true)
assertEquals(returnControl:GetSprite().lastAnimation, "ReturnPress", "House return control plays its press animation")
assertEquals(#transitions, 1, "return waits for its press animation")
advance(13)
assertEquals(#transitions, 2, "return control starts exactly one early return")
assertEquals(transitions[2].index, 10, "early return targets the saved origin room")
currentRoomIndex = 10
roomEntities = {}
callbacks.NewRoom({})
assertEquals(api.GetPersistentData().session, nil, "early return closes the House session")
-- Inventory grants are separate from collision and pedestal removal.
local passed, failed = 0, 0
local function pickupCase(name, body)
    currentRoomIndex = 10
    roomEntities = {}
    callbacks.NewRoom({})
    playerOne.counts, playerTwo.counts = {}, {}
    playerOne.QueuedItem, playerTwo.QueuedItem = nil, nil
    runtimePlayers = { playerOne, playerTwo }
    playerOne.Position, playerTwo.Position = Vector(100, 200), Vector(540, 200)
    assertEquals(callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0).Remove, true,
        "regression session starts")
    local ok, message = pcall(body, api.GetPersistentData().session, #transitions)
    if ok then
        passed = passed + 1
        print("PASS House pickup: " .. name)
    else
        failed = failed + 1
        print("FAIL House pickup: " .. name .. ": " .. tostring(message))
    end
end
local function queueCandidate(pickup, player)
    local itemId = pickup.SubType
    assertEquals(callbacks.PickupCollision({}, pickup, player, false), nil, "valid candidate accepted")
    pickup.SubType = 0
    player.QueuedItem = { Item = { ID = itemId }, Charge = 0, Touched = false }
    return itemId
end
local function grantQueued(player, itemId)
    player.counts[itemId] = player:GetCollectibleNum(itemId) + 1
    player.QueuedItem = nil
    callbacks.Update({})
end

pickupCase("delayed grant survives an empty pedestal and a long pickup animation", function(session)
    local target = activePedestals()[1]
    local itemId = queueCandidate(target, playerOne)
    advance(90)
    assertEquals(session.selectedCount, 0, "queue alone must not finish acquisition")
    grantQueued(playerOne, itemId)
    assertEquals(session.selectedCount, 1, "delayed inventory grant counts once")
    advance(10)
    assertEquals(session.selectedCount, 1, "later updates must not count the same grant again")
end)

pickupCase("third queued choice blocks a fourth before returning after the grant", function(session, priorReturns)
    takeActiveCandidate(1, playerOne)
    takeActiveCandidate(1, playerTwo)
    local itemId = queueCandidate(activePedestals()[1], playerOne)
    local fourth = activePedestals()[1]
    assertEquals(callbacks.PickupCollision({}, fourth, playerTwo, false), true,
        "fourth candidate must be blocked even before the next update")
    advance(30)
    assertEquals(#transitions, priorReturns, "third item must be granted before returning")
    grantQueued(playerOne, itemId)
    assertEquals(session.selectedCount, 3, "shared count reaches exactly three")
    assertEquals(#transitions, priorReturns + 1, "third grant starts one return")
    assertEquals(transitions[#transitions].index, 10, "return uses saved origin")
    assertEquals(#activePedestals(), 0, "remaining candidates are removed")
    assertEquals(#activeControls(), 0, "controls are removed")
    assertEquals(callbacks.PickupCollision({}, fourth, playerTwo, false), true,
        "in-flight return cannot admit a stale fourth collision")
    advance(10)
    assertEquals(#transitions, priorReturns + 1, "return remains single-shot")
end)

pickupCase("three co-op reservations cap a same-update burst at three", function(session, priorReturns)
    local thirdPlayer, fourthPlayer = newPlayer(3), newPlayer(4)
    runtimePlayers = { playerOne, playerTwo, thirdPlayer, fourthPlayer }
    local targets = activePedestals()
    local first = queueCandidate(targets[1], playerOne)
    local second = queueCandidate(targets[2], playerTwo)
    local third = queueCandidate(targets[3], thirdPlayer)
    assertEquals(callbacks.PickupCollision({}, targets[4], fourthPlayer, false), true,
        "co-op cannot reserve a fourth selection in the same update")
    advance(30)
    grantQueued(playerOne, first)
    grantQueued(playerTwo, second)
    assertEquals(session.selectedCount, 2, "two players have settled")
    assertEquals(#transitions, priorReturns, "remaining player is still raising the third item")
    grantQueued(thirdPlayer, third)
    assertEquals(session.selectedCount, 3, "all three players share one quota")
    assertEquals(#transitions, priorReturns + 1, "final co-op grant returns exactly once")
end)

pickupCase("removed or rerolled unacquired pedestals do not consume quota", function(session)
    local targets = activePedestals()
    callbacks.PickupCollision({}, targets[1], playerOne, false)
    targets[1].exists = false
    callbacks.Update({})
    assertEquals(session.selectedCount, 0, "removal without an inventory grant is not a pick")
    callbacks.PickupCollision({}, targets[2], playerTwo, false)
    targets[2].SubType = 999
    advance(8)
    assertEquals(session.selectedCount, 0, "reroll without acquisition is not a pick")
    takeActiveCandidate(1, playerOne)
    assertEquals(session.selectedCount, 1, "a later real acquisition still counts")
end)

pickupCase("failed collisions release reservations for retry", function(session)
    local target = activePedestals()[1]
    callbacks.PickupCollision({}, target, playerOne, false)
    advance(8)
    assertEquals(session.selectedCount, 0, "touching an unavailable pickup consumes nothing")
    local itemId = queueCandidate(target, playerTwo)
    advance(20)
    grantQueued(playerTwo, itemId)
    assertEquals(session.selectedCount, 1, "another player can collect after the failed attempt")
end)

pickupCase("same pedestal and same player cannot reserve twice", function(session)
    local targets = activePedestals()
    assertEquals(targets[1].SubType, targets[2].SubType, "fixture contains duplicate IDs")
    assertEquals(callbacks.PickupCollision({}, targets[1], playerOne, false), nil, "first collision allowed")
    assertEquals(callbacks.PickupCollision({}, targets[1], playerTwo, false), true,
        "other player cannot steal the same pending pedestal")
    assertEquals(callbacks.PickupCollision({}, targets[2], playerOne, false), true,
        "one player cannot reserve two identical items before settling")
    local itemId = targets[1].SubType
    targets[1].SubType = 0
    playerOne.counts[itemId] = 1
    callbacks.Update({})
    assertEquals(session.selectedCount, 1, "one grant consumes one slot")
    takeActiveCandidate(1, playerOne)
    assertEquals(session.selectedCount, 2, "another pedestal with the same item ID counts separately")
end)

for _, role in ipairs({ "next", "return" }) do
    pickupCase("queued pickup prevents " .. role .. " from erasing its confirmation", function(session, priorReturns)
        local itemId = queueCandidate(activePedestals()[1], playerOne)
        touchControl(role, true)
        advance(20)
        assertEquals(session.pageIndex, 1, "page stays put during pickup")
        assertEquals(#transitions, priorReturns, "no early return during pickup")
        assertEquals(session.phase, "active", "pending grant keeps its session")
        movePlayersAway()
        grantQueued(playerOne, itemId)
        assertEquals(session.selectedCount, 1, "pickup survives control contact")
        touchControl(role, false)
        advance(13)
        if role == "next" then
            assertEquals(session.pageIndex, 2, "paging resumes after grant")
        else
            assertEquals(#transitions, priorReturns + 1, "early return resumes after grant")
        end
    end)
end

pickupCase("cancelled queue releases the reservation without a false selection", function(session)
    queueCandidate(activePedestals()[1], playerOne)
    advance(20)
    playerOne.QueuedItem = nil
    advance(8)
    assertEquals(session.selectedCount, 0, "cancelled queued item was not acquired")
    takeActiveCandidate(1, playerOne)
    assertEquals(session.selectedCount, 1, "cancelled queue does not lock later picks")
end)

pickupCase("unrelated pickups are allowed while owned page transitions are locked", function()
    local stale = activePedestals()[1]
    touchControl("next", false)
    assertEquals(callbacks.PickupCollision({}, stale, playerTwo, false), true,
        "page transition must reject late collisions with owned candidates")
    local unrelated = pedestal(601, 56789)
    assertEquals(callbacks.PickupCollision({}, unrelated, playerTwo, false), nil,
        "unowned pickups retain their normal behavior")
end)

pickupCase("an unrelated same-ID grant does not select an untouched pedestal", function(session)
    local target = activePedestals()[1]
    callbacks.PickupCollision({}, target, playerOne, false)
    playerOne.counts[target.SubType] = 1
    advance(8)
    assertEquals(session.selectedCount, 0, "inventory change alone lacks pedestal provenance")
end)

pickupCase("removed queued pedestal waits for inventory instead of returning early", function(session, priorReturns)
    takeActiveCandidate(1, playerOne)
    takeActiveCandidate(1, playerTwo)
    local target = activePedestals()[1]
    local itemId = queueCandidate(target, playerOne)
    target.exists = false
    advance(30)
    assertEquals(session.selectedCount, 2, "removing queued source cannot settle the third item")
    assertEquals(#transitions, priorReturns, "return must wait for the pending grant")
    grantQueued(playerOne, itemId)
    assertEquals(session.selectedCount, 3, "removed source still has a tracked legitimate grant")
    assertEquals(#transitions, priorReturns + 1, "grant triggers return")
end)

pickupCase("continue aborts queued selection and releases its reservation", function(_, priorReturns)
    local itemId = queueCandidate(activePedestals()[1], playerOne)
    advance(10)
    callbacks.GameStarted({}, true)
    assertEquals(api.GetPersistentData().session, nil, "continue follows existing session-abort policy")
    assertEquals(#transitions, priorReturns + 1, "continue requests recovery to original room")
    currentRoomIndex = 10
    roomEntities = {}
    callbacks.NewRoom({})
    grantQueued(playerOne, itemId)
    assertEquals(#transitions, priorReturns + 1, "late grant from aborted session does not return again")
    callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0)
    takeActiveCandidate(1, playerOne)
    assertEquals(api.GetPersistentData().session.selectedCount, 1, "new session gets a fresh quota")
end)

local function encounterCase(name, body)
    currentRoomIndex = 10
    roomEntities = {}
    callbacks.NewRoom({})
    local data = api.GetPersistentData()
    data.encounters, data.seenKeys, data.nextSequence = {}, {}, 1
    runtimePlayers = { playerOne, playerTwo }
    playerOne.counts, playerTwo.counts = {}, {}
    playerOne.QueuedItem, playerTwo.QueuedItem = nil, nil
    callbacks.NewRoom({})
    local ok, message = pcall(body, data)
    if ok then
        passed = passed + 1
        print("PASS House encounter: " .. name)
    else
        failed = failed + 1
        print("FAIL House encounter: " .. name .. ": " .. tostring(message))
    end
end
local function updatePedestal(pickup)
    -- Dispatch only the House handler through its actual registration/filter.
    for _, registration in ipairs(NeverbirthLocalizationTestCallbacks[ModCallbacks.MC_POST_PICKUP_UPDATE] or {}) do
        if registration.fn == callbacks.PickupUpdate
            and (registration.param == nil or registration.param == pickup.Variant) then
            assertEquals(registration.fn(Neverbirth, pickup), nil, "observation does not override pickup updates")
        end
    end
end

encounterCase("late reward pedestals are remembered without re-entering the room", function(data)
    local late = pedestal(603, 92001)
    roomEntities = { late }
    local scan = Isaac.GetRoomEntities
    Isaac.GetRoomEntities = function() error("pickup observation must not scan the whole room") end
    local ok, message = pcall(function()
        for _ = 1, 20 do updatePedestal(late) end
    end)
    Isaac.GetRoomEntities = scan
    assertTruthy(ok, message)
    assertEquals(#data.encounters, 1, "a reward born after room entry must be remembered")
    assertEquals(data.encounters[1].itemId, 603, "remember the actual late item")
    callbacks.NewRoom({})
    assertEquals(#data.encounters, 1, "room re-entry does not duplicate the same instance")
end)

encounterCase("late candidates above three remain available across pages", function(data)
    for index = 1, 8 do
        local late = pedestal(610 + index, 92100 + index)
        roomEntities[#roomEntities + 1] = late
        updatePedestal(late)
    end
    assertEquals(#data.encounters, 8, "all eight late pedestals are remembered")
    callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0)
    assertEquals(#data.session.candidates, 8, "three-pick quota does not truncate the candidate list")
    assertEquals(#activePedestals(), 6, "first page displays six")
    touchControl("next", false)
    advance(10)
    assertEquals(#activePedestals(), 2, "next page displays the remaining two")
    for _, pickup in ipairs(activePedestals()) do updatePedestal(pickup) end
    assertEquals(#data.encounters, 8, "selection copies never feed back into history")
end)

encounterCase("duplicate item IDs on different late pedestals retain both instances", function(data)
    updatePedestal(pedestal(603, 92201))
    updatePedestal(pedestal(603, 92202))
    updatePedestal(pedestal(603, 92201))
    assertEquals(#data.encounters, 2, "instance keys preserve duplicates but reject repeated observations")
end)

encounterCase("late initialization waits for a valid collectible subtype", function(data)
    local late = pedestal(0, 92301)
    updatePedestal(late)
    assertEquals(#data.encounters, 0, "empty pedestal has no candidate")
    late.SubType = 604
    updatePedestal(late)
    assertEquals(#data.encounters, 1, "resolved subtype is observed on a later update")
    late.SubType = 605
    updatePedestal(late)
    assertEquals(#data.encounters, 1, "same instance keeps the established first-encounter rule")
    assertEquals(data.encounters[1].itemId, 604, "first seen subtype remains authoritative")
end)

encounterCase("temporary galleries and non-collectible pickups do not pollute history", function(data)
    local owned = pedestal(606, 92401)
    owned:GetData().NeverbirthHouseSessionToken = "old-house"
    updatePedestal(owned)
    local certificate = pedestal(607, 92402)
    certificate:GetData().NeverbirthCertificateSessionToken = "certificate"
    updatePedestal(certificate)
    updatePedestal(entityBase(5, 10, 1, 92403))
    currentRoomIndex = -3
    callbacks.NewRoom({})
    updatePedestal(pedestal(608, 92404))
    assertEquals(#data.encounters, 0, "temporary and unrelated pickups are excluded")
end)

encounterCase("late history survives continue without duplication", function(data)
    local late = pedestal(609, 92501)
    roomEntities = { late }
    updatePedestal(late)
    assertEquals(#data.encounters, 1, "late encounter is present before continue")
    callbacks.GameStarted({}, true)
    updatePedestal(late)
    assertEquals(#api.GetPersistentData().encounters, 1, "same-run reload retains exactly one encounter")
end)

encounterCase("use snapshots a pedestal before its first update callback", function(data)
    roomEntities = { pedestal(620, 92601) }
    assertEquals(#data.encounters, 0, "no update event has delivered the new pedestal")
    callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0)
    assertEquals(#data.encounters, 1, "use observes the actual room before building candidates")
    assertEquals(data.session.candidates[1].itemId, 620, "new item is available immediately")
    assertEquals(data.session.candidates[1].isMilkFallback, false, "actual item is not replaced by fallback")
end)

encounterCase("saved six-item scenario still filters the three active items", function(data)
    local ids = { 44, 788, 480, 150, 278, 51 }
    local active = { [44] = true, [788] = true, [480] = true }
    local originalConfig = Isaac.GetItemConfig
    Isaac.GetItemConfig = function()
        return { GetCollectible = function(_, id) return { Type = active[id] and 3 or (id == 278 and 2 or 1) } end }
    end
    local ok, message = pcall(function()
        for index, id in ipairs(ids) do
            local item = pedestal(id, 92700 + index)
            roomEntities[#roomEntities + 1] = item
            updatePedestal(item)
        end
        assertEquals(#data.encounters, 6, "all six historical sources are recorded")
        callbacks.UseItem({}, api.GetItemId(), nil, playerOne, 0, 0, 0)
        assertEquals(#data.session.candidates, 3, "user-confirmed active exclusion remains in effect")
        assertEquals(data.session.candidates[1].itemId, 150, "Tough Love retained")
        assertEquals(data.session.candidates[2].itemId, 278, "Dark Bum retained")
        assertEquals(data.session.candidates[3].itemId, 51, "Pentagram retained")
    end)
    Isaac.GetItemConfig = originalConfig
    assertTruthy(ok, message)
end)

print(string.format("House pickup/encounter regressions: %d passed, %d failed", passed, failed))
assertEquals(failed, 0, "House pickup regressions")
print("house vs elephant behavior tests passed")
