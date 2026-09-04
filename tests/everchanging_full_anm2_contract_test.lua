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

local function readFile(path)
    local file = assert(io.open(path, "r"))
    local value = file:read("*a")
    file:close()
    return value
end

local mainText = readFile("main.lua")
local block = assert(
    mainText:match("%-%- EVERCHANGING_BEGIN(.-)%-%- EVERCHANGING_END"),
    "Everchanging source block"
)

assertEquals(block:find('anm2 = "gfx/characters/costume_ringotsuga_apple_storyteller.anm2"', 1, true), nil,
    "RingoTsuga must no longer register a complete player ANM2")
assertTruthy(block:find('slots = { "head" }', 1, true),
    "RingoTsuga must register only the head accessory slot")
assertTruthy(block:find('costume_ringotsuga_headgear.anm2', 1, true),
    "RingoTsuga must register its complete headgear costume")
for _, costumePath in ipairs({
    "costume_tantan_hair.anm2",
    "costume_tantan_glasses.anm2",
    "costume_daodao_hair.anm2",
    "costume_yoontoons_hair.anm2",
    "costume_yoontoons_glasses.anm2",
}) do
    assertTruthy(block:find(costumePath, 1, true),
        "creator accessory must be registered: " .. costumePath)
end
assertEquals(block:find("costume_daodao_tissue_tears.anm2", 1, true), nil,
    "Daodao tissue tears must not be activated by Everchanging")
for _, forbidden in ipairs({
    "costume_tantan_player.anm2",
    "costume_daodao_player.anm2",
    "costume_yoontoons_player.anm2",
    'id = "tantan_only"',
    'id = "daodao_only"',
}) do
    assertEquals(block:find(forbidden, 1, true), nil,
        "creator accessories must not introduce a full skin or split pair style: " .. forbidden)
end
assertEquals(block:find('costume_ringotsuga_white_tshirt.anm2', 1, true), nil,
    "RingoTsuga must not register a body costume")
assertTruthy(block:find("sprite:Load(anm2Path, true)", 1, true),
    "full styles must load their complete player ANM2")
assertEquals(block:find("ReplaceSpritesheet", 1, true), nil,
    "full styles must not use the failed single-spritesheet route")
assertEquals(block:find("GetSpritesheetPath", 1, true), nil,
    "full styles must not infer player state from layer zero")
assertTruthy(block:find("MC_POST_PLAYER_UPDATE", 1, true),
    "full-skin synchronization must use the player update surface")
assertEquals(block:find("MC_POST_PEFFECT_UPDATE", 1, true), nil,
    "the old player-effects update surface must be removed")

print("everchanging full ANM2 contract tests passed")

