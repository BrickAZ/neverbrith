local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function readFile(path, mode)
    local file = assert(io.open(path, mode or "r"))
    local value = file:read("*a")
    file:close()
    return value
end

local function uint32be(text, offset)
    local a, b, c, d = text:byte(offset, offset + 3)
    return ((a * 256 + b) * 256 + c) * 256 + d
end
local function itemBlock(text, name)
    local escaped = name:gsub("([^%w])", "%%%1")
    return text:match('<passive%s+name="' .. escaped .. '"(.-)/>')
end

dofile("tests/localization_test.lua")

PlayerType = {
    PLAYER_JACOB = 19,
    PLAYER_ESAU = 20,
    PLAYER_JACOB_B = 39,
}

for _, entry in ipairs({
    { path = "content/items.xml", name = "Everchanging" },
    { path = "content/items.en_us.xml", name = "Everchanging" },
    { path = "content/items.zh_cn.xml", name = "千变万化" },
}) do
    local block = assert(itemBlock(readFile(entry.path), entry.name), entry.path .. " should register Everchanging")
    assertEquals(block:match('id="(.-)"'), "38", entry.path .. " Everchanging local id")
    assertEquals(block:match('quality="(.-)"'), "0", entry.path .. " Everchanging quality")
    assertEquals(block:match('gfx="(.-)"'), "Everchanging.png", entry.path .. " Everchanging icon")
    assertEquals(block:match('cache="(.-)"'), nil, entry.path .. " must not declare a stat cache")
end

for _, path in ipairs({ "content/itempools.xml", "content/itempools.en_us.xml", "content/itempools.zh_cn.xml" }) do
    local text = readFile(path)
    assertEquals(text:find("Everchanging", 1, true), nil, path .. " must not contain Everchanging")
    assertEquals(text:find("千变万化", 1, true), nil, path .. " must not contain localized Everchanging")
end

local icon = readFile("resources/gfx/Items/Collectibles/Everchanging.png", "rb")
assertEquals(icon:sub(1, 8), "\137PNG\r\n\26\n", "Everchanging icon PNG signature")
assertEquals(uint32be(icon, 17), 32, "Everchanging icon width")
assertEquals(uint32be(icon, 21), 32, "Everchanging icon height")

local ringoHeadgearAnm2Path = "gfx/characters/costume_ringotsuga_headgear.anm2"
local costumeConfig = readFile("content/costumes2.xml")
local tokarevBody = readFile("resources/gfx/characters/costumes/costume_tokarev_cloak_body.png", "rb")
local tokarevHead = readFile("resources/gfx/characters/costumes/costume_tokarev_cloak_head.png", "rb")
local tokarevFace = readFile("resources/gfx/characters/costumes/costume_tokarev_face.png", "rb")
assertEquals(tokarevBody,
    readFile("resources/gfx/characters/costumes/costume_tokarev_cloak_body_candidate.png", "rb"),
    "Tokarev production body must match the approved candidate")
assertEquals(tokarevHead,
    readFile("resources/gfx/characters/costumes/costume_tokarev_cloak_head_candidate.png", "rb"),
    "Tokarev production head must match the approved candidate")
assertEquals(uint32be(tokarevBody, 17), 256, "Tokarev body width")
assertEquals(uint32be(tokarevBody, 21), 256, "Tokarev body height")
assertEquals(uint32be(tokarevHead, 17), 256, "Tokarev head width")
assertEquals(uint32be(tokarevHead, 21), 32, "Tokarev head height")
assertEquals(uint32be(tokarevFace, 17), 256, "Tokarev face width")
assertEquals(uint32be(tokarevFace, 21), 32, "Tokarev face height")
local tokarevAnm2Path = "gfx/characters/costume_tokarev_cloak.anm2"
local tokarevFaceAnm2Path = "gfx/characters/costume_tokarev_face.anm2"
local tokarevAnm2 = readFile("resources/gfx/characters/costume_tokarev_cloak.anm2")
local tokarevFaceAnm2 = readFile("resources/gfx/characters/costume_tokarev_face.anm2")
assertTruthy(tokarevAnm2:find([[Path="costumes\costume_tokarev_cloak_body.png"]], 1, true),
    "Tokarev ANM2 must use the approved body sheet")
assertTruthy(tokarevAnm2:find([[Path="costumes\costume_tokarev_cloak_head.png"]], 1, true),
    "Tokarev ANM2 must use the approved head sheet")
assertTruthy(tokarevAnm2:find('Layer Name="body0"', 1, true), "Tokarev ANM2 body0 layer")
assertTruthy(tokarevAnm2:find('Layer Name="head4"', 1, true), "Tokarev ANM2 head4 layer")
assertTruthy(tokarevFaceAnm2:find([[Path="costumes\costume_tokarev_face.png"]], 1, true),
    "Tokarev face ANM2 must use the approved face sheet")
assertTruthy(tokarevFaceAnm2:find('Layer Name="head2"', 1, true), "Tokarev face ANM2 head2 layer")
assertTruthy(costumeConfig:find('id="17496"', 1, true), "Tokarev Null Costume id")
assertTruthy(costumeConfig:find('anm2path="costume_tokarev_cloak.anm2"', 1, true),
    "Tokarev Null Costume path")
assertTruthy(costumeConfig:find('anm2path="costume_tokarev_cloak.anm2"%s+type="none"', 1),
    "Tokarev must be registered as a type=none Null Costume")
assertTruthy(costumeConfig:find('id="17497"', 1, true), "Tokarev face Null Costume id")
assertTruthy(costumeConfig:find('anm2path="costume_tokarev_face.anm2"', 1, true),
    "Tokarev face Null Costume path")
assertTruthy(costumeConfig:find('anm2path="costume_tokarev_face.anm2"%s+type="none"', 1),
    "Tokarev face must be registered as a type=none Null Costume")
assertEquals(costumeConfig:find('costume_ringotsuga_apple_storyteller.anm2', 1, true), nil,
    "RingoTsuga full skin must not be registered as a Null Costume")
assertTruthy(costumeConfig:find('id="17498"', 1, true), "Ringo headgear Null Costume id")
assertTruthy(costumeConfig:find('anm2path="costume_ringotsuga_headgear.anm2"', 1, true),
    "Ringo headgear Null Costume path")
assertEquals(costumeConfig:find('id="17500"', 1, true), nil, "Ringo T-shirt costume id must be removed")
assertEquals(costumeConfig:find('costume_ringotsuga_white_tshirt.anm2', 1, true), nil,
    "Ringo T-shirt costume path must be removed")

local api = assert(Neverbirth.EverchangingTestAPI, "Everchanging test API should exist")
assertEquals(type(api.StyleRegistry), "table", "StyleRegistry API")
assertEquals(#api.StyleRegistry, 5, "Everchanging style registry size")
assertEquals(api.StyleRegistry[1].id, "blue_banana_peel", "first style id")
assertEquals(api.StyleRegistry[1].slots[1], "head", "banana style slot")
assertEquals(api.StyleRegistry[2].id, "tokarev_cloak", "Tokarev style id")
assertEquals(api.StyleRegistry[2].slots[1], "accessory", "Tokarev style slot")
assertEquals(api.StyleRegistry[2].slots[2], "face", "Tokarev face slot")
assertEquals(api.StyleRegistry[2].full, false, "Tokarev must remain an accessory style")
assertEquals(api.StyleRegistry[2].resources.accessory.costume, tokarevAnm2Path,
    "Tokarev style must own the cloak Null Costume")
assertEquals(api.StyleRegistry[2].resources.face.costume, tokarevFaceAnm2Path,
    "Tokarev style must own the independent face Null Costume")
assertEquals(api.StyleRegistry[3].id, "ringotsuga_apple_storyteller", "Ringo style id")
assertEquals(api.StyleRegistry[3].slots[1], "head", "Ringo headgear slot")
assertEquals(api.StyleRegistry[3].slots[2], nil, "Ringo has no body or face slot")
assertEquals(api.StyleRegistry[3].resources.body, nil, "Ringo has no body resource")
assertEquals(api.StyleRegistry[3].full, false, "RingoTsuga must be an accessory style")
assertEquals(api.StyleRegistry[3].resources.head.costume, ringoHeadgearAnm2Path,
    "Ringo style must own the headgear Null Costume")
assertEquals(api.StyleRegistry[3].resources.full, nil,
    "Ringo style must not replace the complete player ANM2")
local twinsStyle = api.StyleRegistry.byId.tantan_daodao_twins
local yoonStyle = api.StyleRegistry.byId.yoontoons_storyteller
assertTruthy(twinsStyle and twinsStyle.pairRoles, "paired twin style")
assertEquals(twinsStyle.pairRoles.jacob.slots[1], "head", "Daodao head slot")
assertEquals(twinsStyle.pairRoles.jacob.slots[2], nil, "Daodao has no face slot")
assertEquals(twinsStyle.pairRoles.jacob.resources.face, nil, "Daodao has no face resource")
assertEquals(yoonStyle.resources.head.costume,
    "gfx/characters/costume_yoontoons_hair.anm2", "Yoontoons hair path")
assertEquals(yoonStyle.resources.face.costume,
    "gfx/characters/costume_yoontoons_glasses.anm2", "Yoontoons glasses path")
assertEquals(type(api.Callbacks.PlayerUpdate), "function", "player update callback")
assertEquals(type(api.Callbacks.NewRoom), "function", "new room callback")
assertEquals(type(api.Callbacks.GameStarted), "function", "game start callback")
assertEquals(type(api.Callbacks.ExecuteCommand), "function", "debug command callback")

local runtimePlayers = {}
function Game()
    return {
        GetSeeds = function()
            return { GetStartSeedString = function() return "EVERCHANGING TEST RUN" end }
        end,
        GetNumPlayers = function()
            return #runtimePlayers
        end,
    }
end

Isaac.GetPlayer = function(index)
    return runtimePlayers[(index or 0) + 1]
end
Isaac.GetCostumeIdByPath = function(path)
    local ids = {
        ["gfx/characters/costume_blue_banana_peel.anm2"] = 17495,
        ["gfx/characters/costume_tokarev_cloak.anm2"] = 17496,
        ["gfx/characters/costume_tokarev_face.anm2"] = 17497,
        ["gfx/characters/costume_ringotsuga_headgear.anm2"] = 17498,
        ["gfx/characters/costume_tantan_hair.anm2"] = 17501,
        ["gfx/characters/costume_tantan_glasses.anm2"] = 17502,
        ["gfx/characters/costume_daodao_hair.anm2"] = 17503,
        ["gfx/characters/costume_daodao_tissue_tears.anm2"] = 17504,
        ["gfx/characters/costume_yoontoons_hair.anm2"] = 17505,
        ["gfx/characters/costume_yoontoons_glasses.anm2"] = 17506,
    }
    assertTruthy(ids[path], "registered costume path: " .. tostring(path))
    return ids[path]
end
local tokarevResources = api.ResolveStyleResources(api.StyleRegistry[2])
assertEquals(#tokarevResources.costumes, 2, "Tokarev resolves two costumes")
assertEquals(tokarevResources.costumes[1].id, 17496, "Tokarev cloak id")
assertEquals(tokarevResources.costumes[2].id, 17497, "Tokarev face id")
local ringoResources = api.ResolveStyleResources(api.StyleRegistry[3])
assertEquals(ringoResources.playerAnm2, nil, "resolved RingoTsuga must keep the player ANM2")
assertEquals(#ringoResources.costumes, 1, "resolved RingoTsuga style adds one headgear costume")
assertEquals(ringoResources.costumes[1].id, 17498, "Ringo headgear id")
Isaac.GetPlayerTypeByName = function(name)
    if name == "Stranger" then return 9001 end
    return -1
end
local collectibleConfigs = {
    [200] = { ID = 200, Name = "Test Head Costume" },
}
Isaac.GetItemConfig = function()
    return {
        GetCollectibles = function()
            return { Size = 201 }
        end,
        GetCollectible = function(_, itemId)
            return collectibleConfigs[itemId]
        end,
    }
end

local function makePlayer(seed, spriteFilename, playerType)
    local data = {}
    local counts = {}
    local rngCalls = 0
    local spriteReads = 0
    local otherTwin = nil
    local failCostumeId = nil
    local originalPath = spriteFilename or "gfx/001.000_player.anm2"
    local sprite = {
        filename = originalPath,
        loads = 0,
        loadedPaths = {},
        animation = "WalkDown",
        frame = 7,
        overlayAnimation = "HeadDown",
        overlayFrame = 2,
    }
    function sprite:GetFilename()
        return self.filename
    end
    function sprite:GetAnimation()
        return self.animation
    end
    function sprite:GetFrame()
        return self.frame
    end
    function sprite:GetOverlayAnimation()
        return self.overlayAnimation
    end
    function sprite:GetOverlayFrame()
        return self.overlayFrame
    end
    function sprite:Load(path, loadGraphics)
        assertEquals(loadGraphics, true, "player ANM2 must load its graphics immediately")
        self.filename = path
        self.loads = self.loads + 1
        self.loadedPaths[#self.loadedPaths + 1] = path
        self.animation = "WalkDown"
        self.frame = 0
        self.overlayAnimation = ""
        self.overlayFrame = 0
    end
    function sprite:SetFrame(animation, frame)
        self.animation = animation
        self.frame = frame
    end
    function sprite:SetOverlayFrame(animation, frame)
        self.overlayAnimation = animation
        self.overlayFrame = frame
    end
    local player = {
        InitSeed = seed,
        addedCostumes = 0,
        removedCostumes = 0,
        addedCostumeIds = {},
        removedCostumeIds = {},
        GetData = function() return data end,
        GetCollectibleNum = function(_, itemId) return counts[itemId] or 0 end,
        GetCollectibleCount = function()
            local total = 0
            for _, count in pairs(counts) do
                total = total + count
            end
            return total
        end,
        HasCollectible = function(_, itemId) return (counts[itemId] or 0) > 0 end,
        GetCollectibleRNG = function()
            return {
                RandomInt = function(_, maximum)
                    rngCalls = rngCalls + 1
                    assertTruthy(maximum > 0, "RNG maximum must be positive")
                    return (seed + rngCalls - 1) % maximum
                end,
            }
        end,
        GetSprite = function()
            spriteReads = spriteReads + 1
            return sprite
        end,
        GetPlayerType = function() return playerType or 0 end,
        AddNullCostume = function(self, costumeId)
            if costumeId == failCostumeId then
                error("injected costume failure " .. costumeId)
            end
            assertTruthy(costumeId >= 17495 and costumeId <= 17506,
                "added costume id")
            self.addedCostumes = self.addedCostumes + 1
            self.lastAddedCostumeId = costumeId
            self.addedCostumeIds[#self.addedCostumeIds + 1] = costumeId
        end,
        TryRemoveNullCostume = function(self, costumeId)
            assertTruthy(costumeId >= 17495 and costumeId <= 17506,
                "removed costume id")
            self.removedCostumes = self.removedCostumes + 1
            self.lastRemovedCostumeId = costumeId
            self.removedCostumeIds[#self.removedCostumeIds + 1] = costumeId
        end,
        removedCollectibleCostumes = {},
        addedCollectibleCostumes = {},
        RemoveCostume = function(self, config)
            local itemId = config and config.ID
            self.removedCollectibleCostumes[itemId] = (self.removedCollectibleCostumes[itemId] or 0) + 1
        end,
        AddCostume = function(self, config, itemStateOnly)
            assertEquals(itemStateOnly, false, "restored collectible costume must use the normal costume route")
            local itemId = config and config.ID
            self.addedCollectibleCostumes[itemId] = (self.addedCollectibleCostumes[itemId] or 0) + 1
        end,
    }
    function player:SetEverchangingCount(value) counts[api.GetItemId()] = value end
    function player:SetCollectibleCount(itemId, value) counts[itemId] = value end
    function player:GetRemovedCollectibleCostumeCount(itemId)
        return self.removedCollectibleCostumes[itemId] or 0
    end
    function player:GetAddedCollectibleCostumeCount(itemId)
        return self.addedCollectibleCostumes[itemId] or 0
    end
    function player:GetRngCalls() return rngCalls end
    function player:GetSpriteReads() return spriteReads end
    function player:GetSpriteFilename() return sprite.filename end
    function player:GetSpriteLoadCalls() return sprite.loads end
    function player:GetLoadedSpritePath(index) return sprite.loadedPaths[index] end
    function player:SetSpritePlayback(animation, frame, overlayAnimation, overlayFrame)
        sprite.animation = animation
        sprite.frame = frame
        sprite.overlayAnimation = overlayAnimation or ""
        sprite.overlayFrame = overlayFrame or 0
    end
    function player:GetSpritePlayback()
        return sprite.animation, sprite.frame, sprite.overlayAnimation, sprite.overlayFrame
    end
    function player:SimulateEngineSpriteReset()
        sprite.filename = originalPath
    end
    function player:SetOtherTwin(value) otherTwin = value end
    function player:GetOtherTwin() return otherTwin end
    function player:SetFailCostumeId(value) failCostumeId = value end
    return player
end
local jacob = makePlayer(901, nil, PlayerType.PLAYER_JACOB)
local esau = makePlayer(902, nil, PlayerType.PLAYER_ESAU)
jacob:SetOtherTwin(esau)
esau:SetOtherTwin(jacob)
assertEquals(api.GetNormalTwinRole(jacob), "jacob", "Jacob role")
assertEquals(api.GetNormalTwinRole(esau), "esau", "Esau role")
assertTruthy(api.IsStyleEligible(jacob, twinsStyle), "normal Jacob pair eligibility")
assertEquals(api.IsStyleEligible(makePlayer(903, nil, PlayerType.PLAYER_JACOB_B), twinsStyle),
    false, "tainted Jacob pair exclusion")
assertEquals(api.IsStyleEligible(makePlayer(904), twinsStyle), false, "ordinary player pair exclusion")

local jacobResources = api.ResolveStyleResources(twinsStyle, "jacob")
local esauResources = api.ResolveStyleResources(twinsStyle, "esau")
assertEquals(#jacobResources.costumes, 1, "Daodao resolves hair only")
assertEquals(jacobResources.costumes[1].id, 17503, "Daodao hair on Jacob")
assertEquals(esauResources.costumes[1].id, 17501, "Tantan hair on Esau")
assertEquals(esauResources.costumes[2].id, 17502, "Tantan glasses on Esau")

local pairOnly = api.BuildStyleRegistry({ api.StyleSpecs[4] })
assertEquals(api.SelectStyle(makePlayer(905), nil, pairOnly), nil,
    "ordinary players cannot roll the pair style")

local jacob = makePlayer(1001, nil, PlayerType.PLAYER_JACOB)
local esau = makePlayer(1002, nil, PlayerType.PLAYER_ESAU)
local third = makePlayer(1003)
jacob:SetOtherTwin(esau)
esau:SetOtherTwin(jacob)
runtimePlayers = { jacob, esau, third }
api.ResetRunState()

third:SetEverchangingCount(1)
assertTruthy(api.ForceStyle(third, "yoontoons_storyteller"), "preload unrelated player style")
local thirdAdds = third.addedCostumes

esau:SetEverchangingCount(1)
assertTruthy(api.ForceStyle(esau, "yoontoons_storyteller"), "preload Esau local style")
assertEquals(esau.lastAddedCostumeId, 17506, "Yoontoons face is applied")

jacob:SetEverchangingCount(1)
esau:SetFailCostumeId(17502)
local failedPair, failedPairMessage = api.ForceStyle(jacob, "tantan_daodao_twins")
assertEquals(failedPair, false, "pair application failure propagates")
assertEquals(failedPairMessage, "style application failed", "pair failure message")
assertEquals(api.GetRuntime(jacob).appliedStyleId, nil, "Jacob half rolls back")
assertEquals(api.GetRuntime(esau).appliedStyleId, nil, "Esau half rolls back")
assertEquals(jacob.lastRemovedCostumeId, 17503, "Jacob partial pair resources removed")
assertEquals(esau.lastRemovedCostumeId, 17501, "Esau partial pair resources removed")
assertEquals(third.addedCostumes, thirdAdds, "pair rollback does not touch unrelated player")

esau:SetFailCostumeId(nil)
local rngBeforePair = jacob:GetRngCalls()
assertTruthy(api.ForceStyle(jacob, "tantan_daodao_twins"), "force pair style from Jacob")
assertEquals(jacob.addedCostumeIds[#jacob.addedCostumeIds], 17503, "Jacob receives Daodao hair only")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds-1], 17501, "Esau receives Tantan hair")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds], 17502, "Esau receives Tantan glasses")
assertEquals(jacob:GetRngCalls(), rngBeforePair, "debug force consumes no RNG")

local jacobAdds = jacob.addedCostumes
local esauAdds = esau.addedCostumes
api.SyncPlayer(jacob)
api.SyncPlayer(esau)
assertEquals(jacob.addedCostumes, jacobAdds, "ordinary pair sync is idempotent for Jacob")
assertEquals(esau.addedCostumes, esauAdds, "ordinary pair sync is idempotent for Esau")
assertEquals(third.addedCostumes, thirdAdds, "pair sync does not touch unrelated player")

api.Callbacks.NewRoom(nil)
api.Callbacks.PlayerUpdate(nil, jacob)
api.Callbacks.PlayerUpdate(nil, esau)
api.Callbacks.PlayerUpdate(nil, third)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "room change keeps Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "room change keeps Esau role")
assertEquals(third.addedCostumes, thirdAdds, "room sync leaves unrelated player idempotent")

api.Callbacks.NewLevel(nil)
api.Callbacks.PlayerUpdate(nil, jacob)
api.Callbacks.PlayerUpdate(nil, esau)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "level change keeps Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "level change keeps Esau role")

api.ClearRuntime(jacob, true)
api.ClearRuntime(esau, true)
api.Callbacks.GameStarted(nil, true)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "continue restores Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "continue restores Esau role")
assertEquals(jacob:GetRngCalls(), rngBeforePair, "lifecycle restore does not redraw")

jacob:SetEverchangingCount(0)
api.SyncPlayer(jacob)
assertEquals(api.GetPlayerState(jacob).styleId, nil, "pair owner style clears on item loss")
assertEquals(api.GetPlayerState(esau).styleId, "yoontoons_storyteller", "Esau saved local style survives")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds-1], 17505, "Esau restores Yoontoons hair")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds], 17506, "Esau restores Yoontoons glasses")

jacob:SetEverchangingCount(1)
assertTruthy(api.ForceStyle(jacob, "tantan_daodao_twins"), "restore pair style")
local pairRng = jacob:GetRngCalls()
jacob:SetOtherTwin(nil)
esau:SetOtherTwin(nil)
api.SyncPlayer(jacob)
api.SyncPlayer(esau)
assertEquals(api.GetRuntime(jacob).appliedStyleId, nil, "missing partner clears Jacob half")
assertEquals(api.GetRuntime(esau).appliedStyleId, "yoontoons_storyteller", "Esau returns to local style")
jacob:SetOtherTwin(esau)
esau:SetOtherTwin(jacob)
api.SyncPlayer(jacob)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "rejoined Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "rejoined Esau role")
assertEquals(jacob:GetRngCalls(), pairRng, "rejoin does not redraw")
assertEquals(api.GetRuntime(third).appliedStyleId, "yoontoons_storyteller",
    "unrelated player style survives pair separation and rejoin")
assertEquals(third.addedCostumes, thirdAdds,
    "unrelated player receives no duplicate costume applications")

local first = makePlayer(101)
local second = makePlayer(202)
runtimePlayers = { first, second }
api.ResetRunState()

assertEquals(api.Callbacks.PlayerUpdate(nil, first), nil, "player callback return without item")
assertEquals(first.addedCostumes, 0, "non-holder must remain unchanged")
first:SetEverchangingCount(1)
first:SetSpritePlayback("UseItem", 4, "HeadDown", 2)
assertEquals(api.Callbacks.PlayerUpdate(nil, first), nil, "first acquisition callback return")
assertEquals(first.addedCostumes, 2, "Tokarev applies cloak and face Null Costumes")
assertEquals(first.addedCostumeIds[1], 17496, "Tokarev cloak applies first")
assertEquals(first.addedCostumeIds[2], 17497, "Tokarev face applies second")
assertEquals(first:GetRngCalls(), 1, "first acquisition draws once")
assertEquals(api.GetPlayerState(first).styleId, "tokarev_cloak", "selected style is persisted")
assertEquals(first:GetSpriteFilename(), "gfx/001.000_player.anm2",
    "accessory styles must keep the original player ANM2")
assertEquals(first:GetSpriteLoadCalls(), 0, "accessory styles must not load a player ANM2")
local animation, frame, overlayAnimation, overlayFrame = first:GetSpritePlayback()
assertEquals(animation, "UseItem", "accessory application preserves the active player animation")
assertEquals(frame, 4, "accessory application preserves the active player frame")
assertEquals(overlayAnimation, "HeadDown", "accessory application preserves the active overlay animation")
assertEquals(overlayFrame, 2, "accessory application preserves the active overlay frame")

api.Callbacks.PlayerUpdate(nil, first)
assertEquals(first:GetRngCalls(), 1, "ordinary updates must not redraw")
assertEquals(first:GetSpriteLoadCalls(), 0, "ordinary updates must not load the player ANM2")

first:SetCollectibleCount(200, 1)
api.Callbacks.PlayerUpdate(nil, first)
api.Callbacks.PlayerUpdate(nil, first)
api.Callbacks.PlayerUpdate(nil, first)
assertEquals(first:GetRemovedCollectibleCostumeCount(200), 0,
    "Ringo accessories must never suppress another collectible costume")
assertEquals(first:GetAddedCollectibleCostumeCount(200), 0,
    "Ringo accessories must not synthesize collectible costume restoration")
assertEquals(first:GetSpriteLoadCalls(), 0,
    "collectible pickups must not trigger player ANM2 replacement")

first:SetEverchangingCount(2)
api.Callbacks.PlayerUpdate(nil, first)
assertEquals(first:GetRngCalls(), 2, "second copy performs exactly one new draw")
assertEquals(api.GetPlayerState(first).styleId, "blue_banana_peel", "second copy rerolls to the other style")
assertEquals(first.removedCostumes, 2, "switching away removes both Tokarev costumes")
assertEquals(first.removedCostumeIds[1], 17496, "Tokarev cloak removal order")
assertEquals(first.removedCostumeIds[2], 17497, "Tokarev face removal order")
assertEquals(first:GetSpriteFilename(), "gfx/001.000_player.anm2",
    "switching accessories keeps the original player ANM2")
assertEquals(first:GetSpriteLoadCalls(), 0, "switching accessories must not restore a replaced player ANM2")
assertEquals(first:GetAddedCollectibleCostumeCount(200), 0,
    "switching away must not alter another collectible costume")
assertEquals(first.lastAddedCostumeId, 17495, "second copy applies the alternate style")

second:SetEverchangingCount(1)
api.Callbacks.PlayerUpdate(nil, second)
assertEquals(second.addedCostumes, 1, "co-op holder applies the Ringo headgear")
assertEquals(second.addedCostumeIds[1], 17498, "co-op holder applies the Ringo headgear")
assertEquals(second:GetRngCalls(), 1, "co-op RNG is independent")
second:SetEverchangingCount(0)
api.Callbacks.PlayerUpdate(nil, second)
assertEquals(second.removedCostumes, 1, "losing Ringo removes the headgear")
assertEquals(second.removedCostumeIds[1], 17498, "Ringo headgear removal order")
local styleBeforeRoomChange = api.GetPlayerState(first).styleId
api.Callbacks.NewRoom(nil)
api.Callbacks.PlayerUpdate(nil, first)
assertEquals(api.GetPlayerState(first).styleId, styleBeforeRoomChange, "room changes must not redraw")
assertEquals(first:GetRngCalls(), 2, "room changes must not consume item RNG")

api.ClearRuntime(first, false)
assertEquals(api.Callbacks.GameStarted(nil, true), nil, "continued game callback return")
assertEquals(api.GetPlayerState(first).styleId, "blue_banana_peel", "continue keeps the selected style")
assertTruthy(first.addedCostumes >= 2, "continue restores the saved visual")

first:SetEverchangingCount(0)
api.Callbacks.PlayerUpdate(nil, first)
assertEquals(api.GetPlayerState(first).styleId, nil, "losing all copies clears the style")
assertTruthy(first.removedCostumes >= 1, "losing all copies removes the Everchanging costume")

local incompatible = makePlayer(303, "gfx/characters/nonstandard_character.anm2")
runtimePlayers = { incompatible }
api.ResetRunState()
incompatible:SetEverchangingCount(1)
api.Callbacks.PlayerUpdate(nil, incompatible)
assertEquals(api.GetPlayerState(incompatible).styleId, "yoontoons_storyteller", "incompatible holder still saves a style")
assertEquals(incompatible.addedCostumes, 0, "incompatible skeleton must not receive the costume")
local incompatibleSpriteReads = incompatible:GetSpriteReads()
api.Callbacks.PlayerUpdate(nil, incompatible)
assertEquals(incompatible:GetSpriteReads(), incompatibleSpriteReads,
    "an incompatible style must not retry on every ordinary frame")

local stranger = makePlayer(404, "gfx/001.000_player.anm2", 9001)
runtimePlayers = { stranger }
api.ResetRunState()
stranger:SetEverchangingCount(1)
api.Callbacks.PlayerUpdate(nil, stranger)
assertEquals(api.GetPlayerState(stranger).styleId, "blue_banana_peel", "Stranger still saves a style")
assertEquals(stranger.addedCostumes, 0, "Stranger must not receive the costume")

local emptyRegistry = api.BuildStyleRegistry({})
assertEquals(#emptyRegistry, 0, "empty style specs should build an empty registry")
assertEquals(api.SelectStyle(first, nil, emptyRegistry), nil, "empty registry must safely keep the normal appearance")

local invalidRegistry = api.BuildStyleRegistry({
    { id = "bad_slot", slots = { "hat" }, resources = { hat = { costume = "gfx/bad.anm2" } } },
    { id = "bad_full", slots = { "full", "head" }, resources = {
        full = { costume = "gfx/full.anm2" }, head = { costume = "gfx/head.anm2" },
    }, full = true },
})
assertEquals(#invalidRegistry, 0, "invalid slot and mixed full styles must be rejected")

local multiRegistry = api.BuildStyleRegistry({
    { id = "first", slots = { "head" }, resources = { head = { costume = "gfx/first.anm2" } } },
    { id = "second", slots = { "face" }, resources = { face = { costume = "gfx/second.anm2" } } },
})
local rerollPlayer = makePlayer(606)
assertEquals(api.SelectStyle(rerollPlayer, "first", multiRegistry).id, "second",
    "multi-style rerolls must exclude the current style")
assertEquals(rerollPlayer:GetRngCalls(), 1, "multi-style reroll consumes one collectible RNG draw")

local debugPlayer = makePlayer(808)
runtimePlayers = { debugPlayer }
api.ResetRunState()
debugPlayer:SetEverchangingCount(1)
api.Callbacks.PlayerUpdate(nil, debugPlayer)
assertEquals(api.GetPlayerState(debugPlayer).styleId, "blue_banana_peel",
    "debug holder starts on a non-Ringo style")
local debugRngCalls = debugPlayer:GetRngCalls()
assertEquals(
    api.Callbacks.ExecuteCommand(nil, "nb_everchanging", "ringo"),
    "[neverbirth] Everchanging: forced style ringotsuga_apple_storyteller",
    "debug command must return its console output string")
assertEquals(api.GetPlayerState(debugPlayer).styleId, "ringotsuga_apple_storyteller",
    "debug command forces the persisted Ringo style")
assertEquals(debugPlayer:GetRngCalls(), debugRngCalls,
    "debug forcing must not consume collectible RNG")
assertEquals(debugPlayer.addedCostumes, 2,
    "debug forcing replaces the banana with the Ringo headgear")
assertEquals(debugPlayer.addedCostumeIds[2], 17498, "debug command applies Ringo headgear")
assertEquals(
    api.Callbacks.ExecuteCommand(nil, "nb_everchanging", "yoontoons"),
    "[neverbirth] Everchanging: forced style yoontoons_storyteller",
    "Yoontoons debug alias")
assertEquals(
    api.Callbacks.ExecuteCommand(nil, "nb_everchanging", "twins"),
    "[neverbirth] Everchanging: style is not eligible for the current player",
    "pair alias rejects an ordinary player")
assertEquals(api.Callbacks.ExecuteCommand(nil, "unrelated_command", "ringo"), nil,
    "unrelated console command return")
assertEquals(api.GetPlayerState(debugPlayer).styleId, "yoontoons_storyteller",
    "ineligible and unrelated console commands must not alter Everchanging")

local missingStyle = {
    id = "missing_resource",
    slots = { "head" },
    resources = { head = { costume = "gfx/characters/missing_everchanging_costume.anm2" } },
}
assertEquals(api.ResolveStyleResources(missingStyle), nil, "missing costume resources must safely fall back")

local fresh = makePlayer(707)
runtimePlayers = { fresh }
api.ResetRunState()
fresh:SetEverchangingCount(1)
api.Callbacks.PlayerUpdate(nil, fresh)
assertEquals(api.GetPlayerState(fresh).styleId, "yoontoons_storyteller", "fresh test holder gets a style")
assertEquals(fresh.addedCostumes, 2, "fresh holder applies Yoontoons hair and glasses")
assertEquals(fresh:GetSpriteFilename(), "gfx/001.000_player.anm2",
    "fresh holder keeps the original player ANM2")
fresh:SetEverchangingCount(0)
assertEquals(api.Callbacks.GameStarted(nil, false), nil, "fresh game callback return")
assertEquals(api.GetPlayerState(fresh).styleId, nil, "fresh game must clear the prior run style")
assertEquals(api.GetPlayerState(fresh).knownCopies, 0, "fresh game must clear prior copy tracking")
assertEquals(fresh:GetSpriteFilename(), "gfx/001.000_player.anm2",
    "fresh game cleanup must keep the original player ANM2")
assertEquals(api.Callbacks.PlayerInit(nil, fresh), nil, "player init callback return")
assertEquals(api.Callbacks.NewRoom(nil), nil, "new room callback return")
assertEquals(api.Callbacks.NewLevel(nil), nil, "new level callback return")
local mainText = readFile("main.lua")
local block = assert(mainText:match("%-%- EVERCHANGING_BEGIN(.-)%-%- EVERCHANGING_END"), "Everchanging source block")
assertTruthy(block:find("sprite:Load(anm2Path, true)", 1, true),
    "Everchanging full skins must load a complete player ANM2")
assertEquals(block:find("ReplaceSpritesheet", 1, true), nil,
    "Everchanging must not use the failed single-spritesheet route")
assertEquals(block:find("GetSpritesheetPath", 1, true), nil,
    "Everchanging must not infer player state from layer zero")
assertTruthy(block:find("MC_POST_PLAYER_UPDATE", 1, true),
    "Everchanging full-skin synchronization must use the player update surface")
assertTruthy(block:find(
        "Neverbirth:AddCallback(ModCallbacks.MC_EXECUTE_CMD, OnEverchangingExecuteCommand)",
        1,
        true
    ),
    "Everchanging debug command callback must be registered exactly once")
assertEquals(block:find("MC_POST_PEFFECT_UPDATE", 1, true), nil,
    "Everchanging must not keep the old player-effects update surface")
assertEquals(block:find("MC_EVALUATE_CACHE", 1, true), nil, "Everchanging must not register a stat cache callback")
assertEquals(block:find("GetRoomEntities", 1, true), nil, "Everchanging must not scan room entities")

print("everchanging behavior tests passed")
