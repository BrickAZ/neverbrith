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

local mainText = readFile("main.lua")
assertEquals(mainText:find("-- BLUE_BANANA_PEEL_SKIN_BEGIN", 1, true), nil,
    "the removed pill-earned Blue Banana Peel block must stay absent")
assertEquals(mainText:find("BlueBananaPeelSkinTestAPI", 1, true), nil,
    "the removed pill-earned Blue Banana Peel API must stay absent")
assertEquals(mainText:find("musicboxSaveData.blueBananaPeel", 1, true), nil,
    "the removed pill-earned entitlement must not keep saved state")
assertEquals(mainText:find("OnBlueBananaPeelUsePill", 1, true), nil,
    "swallowing a pill must no longer grant the Blue Banana Peel")

local costumesXml = readFile("content/costumes2.xml")
local blueCostumeBlock = costumesXml:match('<costume%s+.-id="17495".-/>')
assertTruthy(blueCostumeBlock, "costumes2.xml should register costume id 17495")
assertTruthy(blueCostumeBlock:find('anm2path="costume_blue_banana_peel.anm2"', 1, true),
    "costume XML should use the Blue Banana Peel ANM2")
assertTruthy(blueCostumeBlock:find('priority="98"', 1, true),
    "Blue Banana Peel should keep high costume priority 98")

local anm2 = readFile("resources/gfx/characters/costume_blue_banana_peel.anm2")
assertTruthy(anm2:find('Path="costumes\\costume_blue_banana_peel.png"', 1, true),
    "ANM2 should reference the Blue Banana Peel PNG")
for _, animationName in ipairs({ "HeadDown", "HeadRight", "HeadUp", "HeadLeft" }) do
    assertTruthy(anm2:find('Animation Name="' .. animationName .. '"', 1, true),
        "ANM2 should contain " .. animationName)
end

local png = readFile("resources/gfx/characters/costumes/costume_blue_banana_peel.png", "rb")
assertEquals(png:sub(1, 8), "\137PNG\r\n\26\n", "PNG signature")
assertEquals(uint32be(png, 17), 256, "Blue Banana Peel PNG width")
assertEquals(uint32be(png, 21), 64, "Blue Banana Peel PNG height")
assertEquals(png:byte(26), 6, "Blue Banana Peel PNG should be RGBA")

print("blue banana peel resource tests passed")
