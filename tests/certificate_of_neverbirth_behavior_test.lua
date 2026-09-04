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

local function xmlCollectibles(path)
    local text = readFile(path)
    local flattened = text:gsub("[\r\n]+", " ")
    local rows = {}
    for _, tag in ipairs({ "active", "passive", "familiar" }) do
        for attributes in flattened:gmatch("<" .. tag .. "%s+(.-)/>") do
            local id = tonumber(attributes:match('id="(%d+)"'))
            local name = attributes:match('name="([^"]+)"')
            if id and name then rows[#rows + 1] = { localId = id, name = name, attributes = attributes } end
        end
    end
    table.sort(rows, function(a, b) return a.localId < b.localId end)
    return rows, text
end

local englishRows, englishXml = xmlCollectibles("content/items.xml")
local templateRows = xmlCollectibles("content/items.en_us.xml")
local chineseRows, chineseXml = xmlCollectibles("content/items.zh_cn.xml")
assertTruthy(#englishRows > 0, "default items.xml should register collectibles")
assertEquals(#templateRows, #englishRows, "English template collectible count")
assertEquals(#chineseRows, #englishRows, "Chinese template collectible count")

local certificate = englishRows[36]
assertEquals(certificate.localId, 36, "Certificate local ID")
assertEquals(certificate.name, "Certificate of Neverbirth", "default Certificate name")
assertTruthy(certificate.attributes:find('quality="0"', 1, true), "Certificate quality")
assertTruthy(certificate.attributes:find('maxcharges="0"', 1, true), "Certificate zero charge")
assertTruthy(certificate.attributes:find('gfx="certificate_of_neverbirth.png"', 1, true), "Certificate icon")
assertTruthy(chineseXml:find('name="未生证明"', 1, true), "Chinese Certificate registration")
for _, path in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml", "content/itempools.zh_cn.xml" }) do
    local pools = readFile(path)
    assertEquals(pools:find("Certificate of Neverbirth", 1, true), nil, path .. " excludes Certificate")
    assertEquals(pools:find("未生证明", 1, true), nil, path .. " excludes localized Certificate")
end

local generated = assert(dofile("generated/neverbirth_collectibles.lua"), "generated registry")
assertEquals(#generated, #englishRows, "generated registry count")
for index, row in ipairs(generated) do
    assertEquals(row.localId, englishRows[index].localId, "generated registry stable local-ID order")
    assertEquals(row.englishName, englishRows[index].name, "generated registry default name")
end
assertEquals(generated[36].englishName, "Certificate of Neverbirth", "Certificate is included in gallery candidates")

local entitiesXml = readFile("content/entities2.xml")
assertTruthy(entitiesXml:find('name="Certificate Return Portal"', 1, true), "owned gallery control effect registration")
assertTruthy(entitiesXml:find('variant="3016"', 1, true), "stable gallery control variant")
assertTruthy(entitiesXml:find('anm2path="effects/archive_controls.anm2"', 1, true), "gallery control ANM2 registration")
local controlAnm2 = readFile("resources/gfx/effects/archive_controls.anm2")
for _, animation in ipairs({
    "PrevIdle", "PrevDisabled", "PrevPress", "NextIdle", "NextDisabled", "NextPress",
    "ReturnIdle", "ReturnPress",
}) do
    assertTruthy(controlAnm2:find('Animation Name="' .. animation .. '"', 1, true), "archive control animation " .. animation)
end
for _, image in ipairs({ "archive_prev.png", "archive_next.png", "archive_return.png" }) do
    assertTruthy(controlAnm2:find('Path="' .. image .. '"', 1, true), "archive control sheet " .. image)
    local file = io.open("resources/gfx/effects/" .. image, "rb")
    assertTruthy(file ~= nil, "archive control PNG exists: " .. image)
    if file then file:close() end
end

local source = readFile("main.lua")
local block = source:match("%-%- CERTIFICATE_OF_NEVERBIRTH_BEGIN(.-)%-%- CERTIFICATE_OF_NEVERBIRTH_END")
assertTruthy(block, "isolated Certificate runtime block")
assertTruthy(block:find('include("generated.neverbirth_collectibles")', 1, true), "runtime consumes generated registry")
assertTruthy(block:find("local ITEMS_PER_PAGE = 6", 1, true), "page size is centralized at six")
assertEquals(block:find("GetCollectibles", 1, true), nil, "no global ItemConfig inventory scan")
assertEquals(block:find("GetConfig", 1, true), nil, "no global ItemConfig ownership inference")
assertEquals(block:find("GRID_PRESSURE_PLATE", 1, true), nil, "no one-shot pressure plate")
assertEquals(block:find("COLLECTIBLE_DEATH_CERTIFICATE", 1, true), nil, "does not borrow Death Certificate")
assertEquals(block:find("MakeRedRoomDoor", 1, true), nil, "does not allocate Red Rooms")
assertTruthy(block:find("MC_USE_ITEM", 1, true), "filtered use callback")
assertTruthy(block:find("MC_PRE_PICKUP_COLLISION", 1, true), "pickup confirmation callback")
assertTruthy(block:find("NeverbirthCertificatePortalEnabled", 1, true), "control enabled state is explicit")
assertTruthy(block:find("NeverbirthCertificateSessionToken", 1, true), "owned entities carry session token")
assertTruthy(block:find("ReturnPress", 1, true), "return press interface")
assertTruthy(block:find("NextPress", 1, true), "next press interface")
assertTruthy(block:find("PrevPress", 1, true), "previous press interface")

dofile("tests/localization_test.lua")
Vector = setmetatable({}, {
    __call = function(_, x, y) return { X = x or 0, Y = y or 0, IsIsaacVector = true } end,
})
EntityCollisionClass = { ENTCOLL_NONE = 0 }
GridCollisionClass = { COLLISION_NONE = 0 }

local api = assert(Neverbirth and Neverbirth.CertificateOfNeverbirthTestAPI, "Certificate test API")
assertEquals(api.GetGeneratedCount(), #englishRows, "runtime registry count")
assertEquals(api.GetGalleryCapacity(), 6, "central page capacity")
assertEquals(api.GetControlSubtype("previous"), 0, "previous stable subtype")
assertEquals(api.GetControlSubtype("return"), 1, "return stable subtype")
assertEquals(api.GetControlSubtype("next"), 2, "next stable subtype")
assertEquals(api.GetControlAnimation("previous", "disabled"), "PrevDisabled", "previous disabled animation")
assertEquals(api.GetControlAnimation("next", "press"), "NextPress", "next press animation")
assertEquals(api.GetControlAnimation("return", "press"), "ReturnPress", "return press animation")

local resolved, missing = api.ResolveRegistry(function() return -1 end)
assertEquals(#resolved, 0, "invalid resolver rejected")
assertEquals(#missing, #englishRows, "invalid resolver reports all rows")
local nextId, idsByName = 1000, {}
for _, row in ipairs(generated) do idsByName[row.englishName] = nextId; nextId = nextId + 1 end
resolved, missing = api.ResolveRegistry(function(name) return idsByName[name] end)
assertEquals(#resolved, #englishRows, "all generated rows resolve")
assertEquals(#missing, 0, "no unresolved rows")
for index = 2, #resolved do
    assertTruthy(resolved[index - 1].localId < resolved[index].localId, "candidate order is local-ID ascending")
end

local function rowsOf(count)
    local rows = {}
    for index = 1, count do
        rows[index] = { localId = index, englishName = "item-" .. index, runtimeId = 2000 + index }
    end
    return rows
end
for _, case in ipairs({ { 1, 1 }, { 6, 1 }, { 7, 2 }, { 12, 2 }, { 13, 3 } }) do
    local session = api.NewSession("case-" .. case[1], 10, 0, Vector(0, 0), rowsOf(case[1]))
    assertEquals(api.GetPageCount(session), case[2], case[1] .. " candidate page count")
    assertEquals(api.IsControlEnabled(session, "return"), true, "return always enabled")
    assertEquals(api.IsControlEnabled(session, "previous"), false, "first page previous disabled")
    assertEquals(api.IsControlEnabled(session, "next"), case[2] > 1, "first page next state")
    session.galleryPageIndex = case[2]
    assertEquals(api.IsControlEnabled(session, "previous"), case[2] > 1, "last page previous state")
    assertEquals(api.IsControlEnabled(session, "next"), false, "last page next disabled")
end

local pagingSession = api.NewSession("stable-order", 10, 0, Vector(0, 0), resolved)
local expectedPageCount = math.max(1, math.ceil(#resolved / api.GetGalleryCapacity()))
local expectedLastPageCount = #resolved - (expectedPageCount - 1) * api.GetGalleryCapacity()
assertEquals(api.GetPageCount(pagingSession), expectedPageCount, "current candidates use the expected page count")
local flattenedIds = {}
for page = 1, api.GetPageCount(pagingSession) do
    local pageRows = api.GetPageRows(pagingSession, page)
    assertEquals(#pageRows, page < expectedPageCount and api.GetGalleryCapacity() or expectedLastPageCount,
        "page row count " .. page)
    for _, row in ipairs(pageRows) do flattenedIds[#flattenedIds + 1] = row.localId end
end
assertEquals(#flattenedIds, #resolved, "paging loses or duplicates no candidates")
for index, localId in ipairs(flattenedIds) do assertEquals(localId, index, "stable candidate order at " .. index) end

local callbacks = assert(api.Callbacks, "runtime callback handles")
assertEquals(callbacks.NewRoom({}), nil, "normal new-room callback returns nil")
assertEquals(callbacks.PickupCollision({}, nil, nil), nil, "normal pickup callback returns nil")
assertEquals(callbacks.Update({}), nil, "normal update callback returns nil")

local certState = assert(Neverbirth.CertificateOfNeverbirthState, "runtime state")
local persistent = api.GetPersistentData()
persistent.stack = {}
persistent.nextToken = 1
certState.pendingPickups = {}
certState.transition = nil
certState.controlEntities = {}
certState.frame = 0

local currentRoomIndex, originRoomIndex, currentDimensionValue = 84, 84, 0
local debugRoomIndex = -3
local descriptors = {
    [originRoomIndex] = { Data = { Name = "origin", Shape = 1, Doors = 15 }, GridIndex = originRoomIndex, SafeGridIndex = originRoomIndex },
}
local roomsByIndex = {}
local function createRoom(index)
    local room = { index = index, clear = false }
    function room:GetCenterPos() return Vector(320, 280) end
    function room:GetTopLeftPos() return Vector(40, 120) end
    function room:GetBottomRightPos() return Vector(600, 440) end
    function room:IsPositionInRoom(position, margin)
        margin = tonumber(margin) or 0
        return position.X >= 40 + margin and position.X <= 600 - margin
            and position.Y >= 120 + margin and position.Y <= 440 - margin
    end
    function room:GetGridCollisionAtPos() return 0 end
    function room:GetGridIndex(position) return math.floor(position.X) + math.floor(position.Y) * 1000 end
    function room:GetGridSize() return 0 end
    function room:GetGridEntity() return nil end
    function room:SetClear(value) self.clear = value == true end
    roomsByIndex[index] = room
    return room
end
createRoom(originRoomIndex)

local level = {}
function level:GetCurrentRoomIndex() return currentRoomIndex end
function level:GetCurrentRoomDesc() return descriptors[currentRoomIndex] end
function level:GetRoomByIdx(index, dimension)
    if dimension ~= nil and dimension ~= currentDimensionValue then return nil end
    return descriptors[index]
end
function level:GetStage() return 1 end
function level:GetStageType() return 0 end
function level:GetStartingRoomIndex() return originRoomIndex end

local transitions, runtimePlayers = {}, {}
local game = {
    GetSeeds = function() return { GetStartSeedString = function() return "CERTIFICATE PAGING TEST" end } end,
    GetLevel = function() return level end,
    GetRoom = function() return roomsByIndex[currentRoomIndex] end,
    GetNumPlayers = function() return #runtimePlayers end,
    StartRoomTransition = function(_, index, direction, animation, player, dimension)
        transitions[#transitions + 1] = { index = index, direction = direction, dimension = dimension, player = player }
    end,
}
Game = function() return game end
GetPtrHash = function(value) return value end

local function newPlayer(seed, x, y)
    local player = { InitSeed = seed, Position = Vector(x, y), counts = {} }
    function player:ToPlayer() return self end
    function player:GetCollectibleNum(id) return self.counts[id] or 0 end
    return player
end
local playerA, playerB = newPlayer(7001, 111, 222), newPlayer(7002, 333, 222)
runtimePlayers = { playerA, playerB }
Isaac.GetPlayer = function(index) return runtimePlayers[(index or 0) + 1] end

local executedCommands = {}
Isaac.ExecuteCommand = function(command)
    assertEquals(command, "goto s.default.2", "approved carrier command only")
    executedCommands[#executedCommands + 1] = command
    currentRoomIndex = debugRoomIndex
    if not descriptors[debugRoomIndex] then
        descriptors[debugRoomIndex] = { Data = { Name = "certificate-carrier", Shape = 1, Doors = 0 }, GridIndex = debugRoomIndex, SafeGridIndex = debugRoomIndex }
        createRoom(debugRoomIndex)
    end
    callbacks.NewRoom({})
end
Isaac.GetEntityVariantByName = function(name) return name == "Certificate Return Portal" and 3016 or -1 end

local spawned = {}
Isaac.GetRoomEntities = function()
    local result = {}
    for _, entity in ipairs(spawned) do
        if entity.RoomIndex == currentRoomIndex and entity.exists then result[#result + 1] = entity end
    end
    return result
end
local allAnimations = {
    PrevIdle = true, PrevDisabled = true, PrevPress = true,
    NextIdle = true, NextDisabled = true, NextPress = true,
    ReturnIdle = true, ReturnPress = true,
}
Isaac.Spawn = function(entityType, variant, subtype, position, velocity)
    assertTruthy(position and position.IsIsaacVector == true, "spawn position is Vector")
    assertTruthy(velocity and velocity.IsIsaacVector == true, "spawn velocity is Vector")
    local entity = {
        Type = entityType, Variant = variant, SubType = subtype, Position = position,
        RoomIndex = currentRoomIndex, InitSeed = 9000 + #spawned, exists = true, data = {},
    }
    function entity:GetData() return self.data end
    function entity:Exists() return self.exists end
    function entity:Remove() self.exists = false end
    if entityType == 1000 and variant == 3016 then
        entity.sprite = { lastAnimation = nil }
        function entity.sprite:HasAnimation(name) return allAnimations[name] == true end
        function entity.sprite:Play(name) self.lastAnimation = name end
        function entity:GetSprite() return self.sprite end
    end
    spawned[#spawned + 1] = entity
    return entity
end

local function activePedestals()
    local result = {}
    for _, entity in ipairs(spawned) do
        if entity.exists and entity.RoomIndex == currentRoomIndex and entity.Type == 5 and entity.Variant == 100 then
            result[#result + 1] = entity
        end
    end
    return result
end
local function activeControls(role)
    local result = {}
    for _, entity in ipairs(spawned) do
        local data = entity.GetData and entity:GetData() or nil
        if entity.exists and entity.RoomIndex == currentRoomIndex and entity.Type == 1000 and entity.Variant == 3016
            and data and data.NeverbirthCertificateGalleryPortal
            and (role == nil or data.NeverbirthCertificatePortalRole == role) then
            result[#result + 1] = entity
        end
    end
    return result
end
local function advance(frames)
    for _ = 1, frames do callbacks.Update({}) end
end
local function movePlayersAway()
    playerA.Position, playerB.Position = Vector(100, 200), Vector(540, 200)
    callbacks.Update({})
end
local function touchControl(role, both)
    advance(11)
    local control = assert(activeControls(role)[1], "active control " .. role)
    playerA.Position = control.Position
    if both then playerB.Position = control.Position else playerB.Position = Vector(540, 200) end
    callbacks.Update({})
    return control
end
local function finishPagePress() advance(10) end
local function finishReturnPress() advance(13) end

local certificateId = api.GetItemId()
persistent = api.GetPersistentData()
persistent.stack = {}
persistent.nextToken = 1
certState.pendingPickups = {}
certState.transition = nil
certState.controlEntities = {}
certState.frame = 0
local useResult = callbacks.UseItem({}, certificateId, nil, playerA, 0, 0, 0)
assertEquals(useResult.Discharge, false, "zero-charge use does not discharge")
assertEquals(useResult.Remove, false, "successful use keeps the reusable debug Certificate")
assertEquals(useResult.ShowAnim, true, "successful use animation")
assertEquals(#persistent.stack, 1, "one shared session")
assertEquals(#executedCommands, 1, "carrier entered once")
local session = persistent.stack[1]
assertEquals(session.galleryPageIndex, 1, "starts on page one")
assertEquals(session.galleryPageCount, expectedPageCount, "runtime uses the generated registry page count")
assertEquals(#activePedestals(), 6, "first page has six pedestals")
assertEquals(#activeControls(), 3, "all three controls always exist")
local prev, ret, nxt = activeControls("previous")[1], activeControls("return")[1], activeControls("next")[1]
assertEquals(prev.SubType, 0, "previous subtype")
assertEquals(ret.SubType, 1, "return subtype")
assertEquals(nxt.SubType, 2, "next subtype")
assertEquals(prev:GetData().NeverbirthCertificatePortalEnabled, false, "first-page previous disabled")
assertEquals(prev:GetSprite().lastAnimation, "PrevDisabled", "first-page previous disabled visual")
assertEquals(ret:GetData().NeverbirthCertificatePortalEnabled, true, "return enabled")
assertEquals(ret:GetSprite().lastAnimation, "ReturnIdle", "return idle visual")
assertEquals(nxt:GetData().NeverbirthCertificatePortalEnabled, true, "first-page next enabled")
assertEquals(nxt:GetSprite().lastAnimation, "NextIdle", "next idle visual")
assertTruthy(prev.Position.X < ret.Position.X and ret.Position.X < nxt.Position.X, "controls ordered left-center-right")
assertEquals(prev.Position.Y, ret.Position.Y, "controls share bottom row")
assertEquals(ret.Position.Y, nxt.Position.Y, "controls share bottom row")
assertTruthy(ret.Position.Y > 320, "controls derive from safe bottom area")

local xSeen, ySeen = {}, {}
for _, pedestal in ipairs(activePedestals()) do
    xSeen[pedestal.Position.X] = true
    ySeen[pedestal.Position.Y] = true
end
local xCount, yCount = 0, 0
for _ in pairs(xSeen) do xCount = xCount + 1 end
for _ in pairs(ySeen) do yCount = yCount + 1 end
assertEquals(xCount, 3, "gallery layout has three columns")
assertEquals(yCount, 2, "gallery layout has two rows")

advance(11)
playerA.Position = prev.Position
callbacks.Update({})
assertEquals(certState.transition, nil, "disabled previous cannot trigger")
assertEquals(session.galleryPageIndex, 1, "disabled previous keeps page one")
movePlayersAway()

local nextPressed = touchControl("next", true)
assertEquals(certState.transition.mode, "virtual", "co-op contact creates one transition")
assertEquals(certState.transition.targetPage, 2, "next targets page two")
assertEquals(nextPressed:GetSprite().lastAnimation, "NextPress", "next press animation")
assertEquals(#activePedestals(), 0, "page pedestals clear immediately on press")
local transitionObject = certState.transition
callbacks.Update({})
assertEquals(certState.transition, transitionObject, "locked transition cannot duplicate")
finishPagePress()
assertEquals(session.galleryPageIndex, 2, "page changes after press animation")
assertEquals(#activePedestals(), 6, "page two has six pedestals")
assertEquals(#activeControls(), 3, "page two rebuilds all controls")
assertEquals(activeControls("previous")[1]:GetData().NeverbirthCertificatePortalEnabled, true, "middle page previous enabled")
assertEquals(activeControls("next")[1]:GetData().NeverbirthCertificatePortalEnabled, true, "middle page next enabled")
local pageAfterFirstPress = session.galleryPageIndex
advance(25)
assertEquals(session.galleryPageIndex, pageAfterFirstPress, "standing on rebuilt next control cannot chain pages")
movePlayersAway()

for target = 3, expectedPageCount do
    local control = touchControl("next", target == 3)
    assertEquals(control:GetSprite().lastAnimation, "NextPress", "next press animation page " .. target)
    finishPagePress()
    assertEquals(session.galleryPageIndex, target, "reached page " .. target)
    movePlayersAway()
end
assertEquals(#activePedestals(), expectedLastPageCount, "last page has the generated registry remainder")
assertEquals(activeControls("next")[1]:GetData().NeverbirthCertificatePortalEnabled, false, "last-page next disabled")
assertEquals(activeControls("next")[1]:GetSprite().lastAnimation, "NextDisabled", "last-page next disabled visual")
advance(11)
playerA.Position = activeControls("next")[1].Position
callbacks.Update({})
assertEquals(session.galleryPageIndex, expectedPageCount, "disabled last-page next cannot trigger")
assertEquals(certState.transition, nil, "disabled last-page next creates no transition")
movePlayersAway()

local previousPressed = touchControl("previous", false)
assertEquals(previousPressed:GetSprite().lastAnimation, "PrevPress", "previous press animation")
finishPagePress()
assertEquals(session.galleryPageIndex, expectedPageCount - 1, "previous returns to prior page")
movePlayersAway()

local selected = activePedestals()[1]
local selectedId = selected.SubType
local beforeTransitions = #transitions
local pageBeforePickup = session.galleryPageIndex
local pageCountBeforePickup = #activePedestals()
assertEquals(callbacks.PickupCollision({}, selected, playerA), nil, "candidate collision never cancels pickup")
playerA.counts[selectedId] = 1
selected.exists = false
callbacks.Update({})
assertEquals(session.selected, false, "successful pickup does not end the debug session")
assertEquals(#activePedestals(), pageCountBeforePickup - 1, "only the taken pedestal disappears before a page refresh")
assertEquals(#activeControls(), 3, "pickup keeps all gallery controls")
assertEquals(#transitions, beforeTransitions, "pickup never returns to origin")

local nextAfterPickup = touchControl("next", false)
assertEquals(nextAfterPickup:GetSprite().lastAnimation, "NextPress", "page switch remains available after pickup")
finishPagePress()
movePlayersAway()
local previousAfterPickup = touchControl("previous", false)
assertEquals(previousAfterPickup:GetSprite().lastAnimation, "PrevPress", "previous page remains available after pickup")
finishPagePress()
assertEquals(session.galleryPageIndex, pageBeforePickup, "returns to the page containing the taken pedestal")
assertEquals(#activePedestals(), pageCountBeforePickup, "returning to a page rebuilds every pedestal, including taken items")
local refreshedSelected = nil
for _, pedestal in ipairs(activePedestals()) do
    if pedestal.SubType == selectedId then refreshedSelected = pedestal; break end
end
assertTruthy(refreshedSelected, "taken item is available again after the page is rebuilt")
movePlayersAway()

local rewardCountsBefore = {}
for id, count in pairs(playerA.counts) do rewardCountsBefore[id] = count end
local returnControl = touchControl("return", true)
assertEquals(returnControl:GetSprite().lastAnimation, "ReturnPress", "return press animation")
assertEquals(#activePedestals(), 0, "return clears page immediately")
finishReturnPress()
assertEquals(transitions[#transitions].index, originRoomIndex, "return control targets origin")
currentRoomIndex = originRoomIndex
callbacks.NewRoom({})
assertEquals(#persistent.stack, 0, "return control ends session")
assertEquals(#activeControls(), 0, "no controls outside special room")
for id, count in pairs(rewardCountsBefore) do assertEquals(playerA.counts[id], count, "return grants no item") end

playerA.Position, playerB.Position = Vector(444, 222), Vector(333, 222)
local secondUse = callbacks.UseItem({}, certificateId, nil, playerA, 0, 0, 0)
assertEquals(secondUse.Remove, false, "reusing Certificate still keeps the active item")
assertEquals(#executedCommands, 2, "reuse creates a fresh gallery session")
assertEquals(#activePedestals(), 6, "fresh session repopulates the complete first page")
local secondReturn = touchControl("return", false)
assertEquals(secondReturn:GetSprite().lastAnimation, "ReturnPress", "reused session keeps the return control")
finishReturnPress()
currentRoomIndex = originRoomIndex
callbacks.NewRoom({})
assertEquals(#api.GetPersistentData().stack, 0, "reused session also ends only through the return control")

local stale = Isaac.Spawn(1000, 3016, 1, Vector(320, 400), Vector(0, 0))
stale:GetData().NeverbirthCertificateGalleryPortal = true
stale:GetData().NeverbirthCertificateSessionToken = "stale"
callbacks.NewRoom({})
assertEquals(#activeControls(), 0, "owned stale controls are cleaned with no active session")

print("certificate of neverbirth behavior tests passed")
