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
assertEquals(#englishRows, 36, "default items.xml collectible count")
assertEquals(#templateRows, 36, "English template collectible count")
assertEquals(#chineseRows, 36, "Chinese template collectible count")

local certificate = englishRows[#englishRows]
assertEquals(certificate.localId, 36, "Certificate local ID must append without renumbering existing items")
assertEquals(certificate.name, "Certificate of Neverbirth", "default Certificate name")
assertTruthy(certificate.attributes:find('quality="0"', 1, true), "Certificate quality must be zero")
assertTruthy(certificate.attributes:find('maxcharges="0"', 1, true), "Certificate must require no charge")
assertTruthy(certificate.attributes:find('gfx="certificate_of_neverbirth.png"', 1, true), "Certificate icon path")
assertTruthy(chineseXml:find('name="未生证明"', 1, true), "Chinese Certificate registration")

for _, path in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml", "content/itempools.zh_cn.xml" }) do
    local pools = readFile(path)
    assertEquals(pools:find("Certificate of Neverbirth", 1, true), nil, path .. " must not contain Certificate")
    assertEquals(pools:find("未生证明", 1, true), nil, path .. " must not contain localized Certificate")
end

local generated = assert(dofile("generated/neverbirth_collectibles.lua"), "generated registry should return a table")
assertEquals(#generated, #englishRows, "generated registry count must match items.xml exactly")
local seenRuntimeNames = {}
for index, row in ipairs(generated) do
    assertEquals(row.localId, englishRows[index].localId, "generated registry must stay sorted by local ID")
    assertEquals(row.englishName, englishRows[index].name, "generated registry must use default English registration name")
    assertEquals(seenRuntimeNames[row.englishName], nil, "generated registry must not duplicate names")
    seenRuntimeNames[row.englishName] = true
end
assertTruthy(seenRuntimeNames["Certificate of Neverbirth"], "Certificate itself must be in the generated registry")
local entitiesXml = readFile("content/entities2.xml")
assertTruthy(entitiesXml:find('name="Certificate Return Portal"', 1, true), "return portal must be a registered owned effect")
assertTruthy(entitiesXml:find('variant="3016"', 1, true), "return portal must use the appended stable effect variant")
assertTruthy(entitiesXml:find('anm2path="Effects/traffic_choice_link.anm2"', 1, true), "return portal placeholder asset must exist")

local source = readFile("main.lua")
local block = source:match("%-%- CERTIFICATE_OF_NEVERBIRTH_BEGIN(.-)%-%- CERTIFICATE_OF_NEVERBIRTH_END")
assertTruthy(block, "main.lua should contain an isolated Certificate runtime block")
assertTruthy(block:find('include("generated.neverbirth_collectibles")', 1, true), "runtime must consume the generated registry")
assertEquals(block:find("GetCollectibles", 1, true), nil, "runtime must not scan the global ItemConfig collectible range")
assertEquals(block:find("GetConfig", 1, true), nil, "runtime must not inspect global ItemConfig to infer mod ownership")
assertTruthy(block:find("MC_USE_ITEM", 1, true), "Certificate must register a filtered use callback")
assertTruthy(block:find("MC_POST_NEW_ROOM", 1, true), "gallery spawning must run on room entry")
assertTruthy(block:find("MC_PRE_PICKUP_COLLISION", 1, true), "owned pedestal collection must update reload state")
assertEquals(block:find("GRID_PRESSURE_PLATE", 1, true), nil, "gallery must not depend on one-shot pressure plates")
assertEquals(block:find("ToPressurePlate", 1, true), nil, "gallery must not read one-shot pressure plate state")
assertTruthy(block:find('"Certificate Return Portal"', 1, true), "gallery must resolve its owned return portal effect")
assertTruthy(block:find("StartRoomTransition", 1, true), "gallery must use a real room transition")
assertEquals(block:find("target.Data = source.Data", 1, true), nil, "gallery must not copy RoomDescriptor.Data across dimensions")
assertEquals(block:find("COLLECTIBLE_DEATH_CERTIFICATE", 1, true), nil, "Certificate must not reference the vanilla Death Certificate item")
assertEquals(block:find("UseActiveItem", 1, true), nil, "Certificate must not execute another active item's effect")
assertEquals(block:find("OptionsPickupIndex", 1, true), nil, "Certificate must not use the Repentance-incompatible pedestal choice property")
assertEquals(block:find("MakeRedRoomDoor", 1, true), nil, "gallery entry must not depend on red-room creation")
assertTruthy(block:find('local GALLERY_ROOM_COMMAND = "goto s.default.2"', 1, true), "gallery must define its independent debug-room entry")
assertTruthy(block:find("Isaac.ExecuteCommand(GALLERY_ROOM_COMMAND)", 1, true), "gallery must execute its independent room entry")

dofile("tests/localization_test.lua")
Vector = setmetatable({}, {
    __call = function(_, x, y)
        return { X = x or 0, Y = y or 0, IsIsaacVector = true }
    end,
})
local api = assert(Neverbirth and Neverbirth.CertificateOfNeverbirthTestAPI, "Certificate runtime test API should load")
assertEquals(api.GetGeneratedCount(), 36, "runtime registry should expose all registered collectibles")
assertEquals(api.GetGalleryCapacity(), 32, "each gallery room must contain at most 32 collectibles")

local resolved, missing = api.ResolveRegistry(function() return -1 end)
assertEquals(#resolved, 0, "invalid resolver results must not be accepted")
assertEquals(#missing, 36, "invalid resolver must report every unresolved registered name")

local nextId = 1000
local idsByName = {}
for _, row in ipairs(generated) do idsByName[row.englishName] = nextId; nextId = nextId + 1 end
resolved, missing = api.ResolveRegistry(function(name) return idsByName[name] end)
assertEquals(#resolved, 36, "valid resolver must retain every generated collectible")
assertEquals(#missing, 0, "valid resolver must have no unresolved entries")
for index = 2, #resolved do
    assertTruthy(resolved[index - 1].localId < resolved[index].localId, "resolved registry must remain local-ID sorted")
end

local positions, overflow = api.AssignPositions(resolved, api.MakeTestPositions(40))
assertEquals(#positions, 36, "one position must be assigned to every collectible")
assertEquals(#overflow, 0, "sufficient capacity must not omit collectibles")
positions, overflow = api.AssignPositions(resolved, api.MakeTestPositions(35))
assertEquals(#positions, 0, "capacity failure must be atomic instead of partially spawning")
assertEquals(#overflow, 1, "capacity failure must report the exact omitted ID count")
assertEquals(overflow[1].localId, 36, "capacity report must preserve sorted missing IDs")

local sessionA = api.NewSession("player-a", 10, 0, { x = 100, y = 120 }, resolved)
local sessionB = api.NewSession("player-b", -3, 2, { x = 200, y = 220 }, resolved)
assertEquals(api.GetPageCount(sessionA), 2, "36 collectibles require two gallery rooms")
assertEquals(#api.GetPageRows(sessionA, 1), 32, "first gallery room contains 32 collectibles")
assertEquals(#api.GetPageRows(sessionA, 2), 4, "second gallery room may remain mostly empty")
assertTruthy(sessionA.token ~= sessionB.token, "co-op/nested sessions need unique tokens")
assertEquals(sessionA.initiatorKey, "player-a", "first session owns its initiator")
assertEquals(sessionB.originRoomIndex, -3, "nested session keeps its independent origin")
assertEquals(api.MarkCollected(sessionA, resolved[1].runtimeId), true, "first owned pedestal collection updates remaining IDs")
assertEquals(api.MarkCollected(sessionA, resolved[1].runtimeId), false, "same pedestal cannot be recorded twice")
assertEquals(#api.GetRemainingRows(sessionA), 35, "room reload restores only uncollected pedestals")
assertEquals(#api.GetRemainingRows(sessionB), 36, "another session must remain independent")

local callbacks = assert(api.Callbacks, "runtime should expose its actual callback handlers")
assertEquals(callbacks.NewRoom({}), nil, "new-room callback must return nil")
assertEquals(callbacks.PickupCollision({}, nil, nil), nil, "normal pickup callback must return nil")
assertEquals(callbacks.Update({}), nil, "update callback must return nil")

local certState = assert(Neverbirth.CertificateOfNeverbirthState, "runtime state should be exposed")
local persistent = api.GetPersistentData()
persistent.stack = {}
persistent.nextToken = 1
persistent.galleryNetwork = nil
certState.pendingPickups = {}
certState.transition = nil

local currentRoomIndex = 84
local originRoomIndex = 84
local galleryRoomIndex = -3
local currentDimensionValue = 0
local descriptors = {
    [originRoomIndex] = { Data = { Name = "origin" }, GridIndex = originRoomIndex, SafeGridIndex = originRoomIndex },
    [galleryRoomIndex] = { Data = { Name = "independent-gallery" }, GridIndex = galleryRoomIndex, SafeGridIndex = galleryRoomIndex },
}
local roomsByIndex = {}
local function createRoom(index)
    local model = { index = index, clear = false }
    function model:GetCenterPos() return Vector(320, 280) end
    function model:IsPositionInRoom(position, margin)
        margin = tonumber(margin) or 0
        return position.X >= 40 + margin and position.X <= 600 - margin
            and position.Y >= 120 + margin and position.Y <= 440 - margin
    end
    function model:GetGridCollisionAtPos() return 0 end
    function model:GetGridIndex(position) return math.floor(position.X) + math.floor(position.Y) * 1000 end
    function model:GetGridSize() return 0 end
    function model:GetGridEntity() return nil end
    function model:SetClear(value) self.clear = value == true end
    roomsByIndex[index] = model
    return model
end
createRoom(originRoomIndex)
createRoom(galleryRoomIndex)

local level = {}
function level:GetCurrentRoomIndex() return currentRoomIndex end
function level:GetCurrentRoomDesc() return descriptors[currentRoomIndex] end
function level:GetRoomByIdx(index, dimension)
    if dimension ~= nil and dimension ~= 0 then return nil end
    return descriptors[index]
end
function level:GetStage() return 1 end
function level:GetStageType() return 0 end
function level:GetStartingRoomIndex() return originRoomIndex end

local transitions = {}
local runtimePlayers = {}
local game = {
    GetSeeds = function() return { GetStartSeedString = function() return "TEST RUN" end } end,
    GetLevel = function() return level end,
    GetRoom = function() return roomsByIndex[currentRoomIndex] end,
    GetNumPlayers = function() return #runtimePlayers end,
    StartRoomTransition = function(_, index, direction, animation, player, dimension)
        transitions[#transitions + 1] = { index = index, direction = direction, dimension = dimension, player = player }
    end,
}
Game = function() return game end
GetPtrHash = function(value) return value end

local executedCommands = {}
local function newPlayer(seed, x, y)
    local player = { InitSeed = seed, Position = Vector(x, y), counts = {} }
    function player:ToPlayer() return self end
    function player:GetCollectibleNum(id) return self.counts[id] or 0 end
    return player
end
local playerA = newPlayer(7001, 111, 222)
local playerB = newPlayer(7002, 333, 222)
runtimePlayers = { playerA, playerB }
Isaac.GetPlayer = function(index) return runtimePlayers[(index or 0) + 1] end
Isaac.ExecuteCommand = function(command)
    executedCommands[#executedCommands + 1] = command
    if command == "goto s.default.2" then currentRoomIndex = galleryRoomIndex end
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
Isaac.Spawn = function(entityType, variant, subtype, position, velocity)
    assertTruthy(position and position.IsIsaacVector == true, "Isaac.Spawn position must be a real Vector")
    assertTruthy(velocity and velocity.IsIsaacVector == true, "Isaac.Spawn velocity must be a real Vector")
    local entity = {
        Type = entityType, Variant = variant, SubType = subtype, Position = position,
        RoomIndex = currentRoomIndex, InitSeed = 9000 + #spawned, exists = true, data = {},
    }
    function entity:GetData() return self.data end
    function entity:Exists() return self.exists end
    function entity:Remove() self.exists = false end
    spawned[#spawned + 1] = entity
    return entity
end

local function activePedestals()
    local result = {}
    for _, entity in ipairs(spawned) do
        if entity.exists and entity.RoomIndex == currentRoomIndex
            and entity.Type == 5 and entity.Variant == 100 then result[#result + 1] = entity end
    end
    return result
end
local function activeGalleryPortals(role)
    local result = {}
    for _, entity in ipairs(spawned) do
        local data = entity.GetData and entity:GetData() or nil
        if entity.exists and entity.RoomIndex == currentRoomIndex
            and entity.Type == 1000 and entity.Variant == 3016
            and data and data.NeverbirthCertificateGalleryPortal
            and (role == nil or data.NeverbirthCertificatePortalRole == role) then result[#result + 1] = entity end
    end
    return result
end
local function armAndEnterPortal(role, player)
    for _ = 1, 11 do callbacks.Update({}) end
    local portal = activeGalleryPortals(role)[1]
    assertTruthy(portal, "expected active gallery portal role=" .. tostring(role))
    player.Position = portal.Position
    callbacks.Update({})
end

local certificateId = api.GetItemId()
local useResult = callbacks.UseItem({}, certificateId, nil, playerA, 0, 0, 0)
assertEquals(useResult.Discharge, false, "zero-charge Certificate use must not discharge")
assertEquals(useResult.Remove, false, "reusable Certificate use must not remove the active item")
assertEquals(useResult.ShowAnim, true, "successful Certificate use should show its use animation")
assertEquals(#persistent.stack, 1, "successful use creates one player-bound session")
assertEquals(executedCommands[#executedCommands], "goto s.default.2", "entry must use the independent gallery room")
local firstGallerySession = persistent.stack[1]
assertEquals(firstGallerySession.galleryPageIndex, 1, "new sessions begin on page one")
assertEquals(firstGallerySession.galleryPageCount, 2, "36 collectibles require two independent gallery pages")

callbacks.NewRoom({})
assertEquals(currentRoomIndex, galleryRoomIndex, "independent entry reaches the gallery room")
assertEquals(#activePedestals(), 32, "first gallery page caps its pedestal count at 32")
assertEquals(#activeGalleryPortals("return"), 1, "first gallery page keeps one central return mechanism")
assertEquals(#activeGalleryPortals("previous"), 0, "first gallery page has no previous-page mechanism")
assertEquals(#activeGalleryPortals("next"), 1, "first gallery page connects to page two")
assertEquals(activeGalleryPortals("return")[1].Position.X, 320, "return mechanism stays at room center X")
assertEquals(activeGalleryPortals("return")[1].Position.Y, 280, "return mechanism stays at room center Y")
local firstPagePedestals = activePedestals()
local minimumSpacingSquared = math.huge
for left = 1, #firstPagePedestals - 1 do
    for right = left + 1, #firstPagePedestals do
        local dx = firstPagePedestals[left].Position.X - firstPagePedestals[right].Position.X
        local dy = firstPagePedestals[left].Position.Y - firstPagePedestals[right].Position.Y
        minimumSpacingSquared = math.min(minimumSpacingSquared, dx * dx + dy * dy)
    end
end
assertEquals(minimumSpacingSquared, 64 * 64, "8x4 gallery grid keeps 64 pixels between nearest pedestals")

armAndEnterPortal("next", playerA)
assertEquals(executedCommands[#executedCommands], "goto s.default.2", "next-page mechanism reloads the independent room")
callbacks.NewRoom({})
assertEquals(firstGallerySession.galleryPageIndex, 2, "next-page mechanism selects page two")
assertEquals(#activePedestals(), 4, "second gallery page may remain mostly empty")
assertEquals(#activeGalleryPortals("previous"), 1, "second gallery page connects back to page one")
assertEquals(#activeGalleryPortals("next"), 0, "last gallery page has no next-page mechanism")
assertEquals(#activeGalleryPortals("return"), 1, "second gallery page also keeps its central return mechanism")

armAndEnterPortal("previous", playerA)
callbacks.NewRoom({})
assertEquals(firstGallerySession.galleryPageIndex, 1, "previous-page mechanism restores page one")
local selected = activePedestals()[1]
assertEquals(callbacks.PickupCollision({}, selected, playerA), nil, "owned pedestal collision never cancels pickup")
selected.exists = false
callbacks.Update({})
callbacks.NewRoom({})
assertEquals(#activePedestals(), 31, "re-entering page one restores only uncollected pedestals")

local commandsBeforeNested = #executedCommands
local nestedUse = callbacks.UseItem({}, certificateId, nil, playerB, 0, 0, 0)
assertEquals(nestedUse.Remove, false, "nested Certificate use remains reusable")
assertEquals(#persistent.stack, 2, "nested/co-op use creates an independent inner session")
assertEquals(#executedCommands, commandsBeforeNested + 1, "nested use opens its own gallery view")
callbacks.NewRoom({})
assertEquals(#activePedestals(), 32, "inner session starts from its own page-one view")
armAndEnterPortal("return", playerB)
assertEquals(#persistent.stack, 1, "inner central mechanism returns only the inner session")
assertEquals(#activePedestals(), 31, "inner return restores the outer session view")

armAndEnterPortal("return", playerA)
assertEquals(transitions[#transitions].index, originRoomIndex, "outer central mechanism returns to the original room")
currentRoomIndex = originRoomIndex
callbacks.NewRoom({})
assertEquals(#persistent.stack, 0, "completed return ends the gallery session")
assertEquals(playerA.Position.X, 111, "return restores initiating room X position")
assertEquals(playerA.Position.Y, 222, "return restores initiating room Y position")

playerA.Position = Vector(444, 222)
local repeatedUse = callbacks.UseItem({}, certificateId, nil, playerA, 0, 0, 0)
assertEquals(repeatedUse.ShowAnim, true, "Certificate can start a fresh session after returning")
assertEquals(executedCommands[#executedCommands], "goto s.default.2", "repeated use re-enters the independent gallery")
callbacks.NewRoom({})
assertEquals(#activeGalleryPortals("return"), 1, "repeated visit restores the central mechanism")
armAndEnterPortal("return", playerA)
currentRoomIndex = originRoomIndex
callbacks.NewRoom({})
assertEquals(#persistent.stack, 0, "repeated return completes without stale session state")

local stalePortal = Isaac.Spawn(1000, 3016, 0, Vector(320, 280), Vector(0, 0))
stalePortal:GetData().NeverbirthCertificateGalleryPortal = true
stalePortal:GetData().NeverbirthCertificateSessionToken = "stale"
callbacks.NewRoom({})
assertEquals(#activeGalleryPortals(), 0, "room reload removes an owned gallery mechanism whose session no longer exists")

print("certificate of neverbirth behavior tests passed")
