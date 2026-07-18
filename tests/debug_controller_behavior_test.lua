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

local callbacks = {}
local executedCommands = {}
local renderedAnimations = {}
local pressedActions = {}
local DEBUG_CONTROLLER_ID = 753

ModCallbacks = {
    MC_POST_UPDATE = 1,
    MC_USE_ITEM = 2,
    MC_EVALUATE_CACHE = 3,
    MC_POST_RENDER = 4,
    MC_ENTITY_TAKE_DMG = 5,
    MC_PRE_USE_ITEM = 6,
    MC_PRE_PICKUP_COLLISION = 7,
    MC_POST_NEW_ROOM = 8,
    MC_POST_NEW_LEVEL = 9,
    MC_POST_GAME_STARTED = 10,
    MC_POST_FIRE_TEAR = 11,
}

ButtonAction = {
    ACTION_SHOOTLEFT = 1,
    ACTION_SHOOTUP = 2,
    ACTION_SHOOTRIGHT = 3,
    ACTION_SHOOTDOWN = 4,
    ACTION_LEFT = 5,
    ACTION_UP = 6,
    ACTION_RIGHT = 7,
    ACTION_DOWN = 8,
}

CollectibleType = { COLLECTIBLE_NULL = 0, COLLECTIBLE_PLAN_C = 475 }
CacheFlag = {
    CACHE_DAMAGE = 1,
    CACHE_SHOTSPEED = 2,
    CACHE_TEARCOLOR = 4,
    CACHE_SPEED = 8,
    CACHE_FIREDELAY = 16,
    CACHE_TEARFLAG = 32,
    CACHE_LUCK = 1024,
}
DamageFlag = {
    DAMAGE_RED_HEARTS = 1,
    DAMAGE_NOKILL = 2,
    DAMAGE_INVINCIBLE = 4,
}
EntityFlag = { FLAG_CHARM = 1 }
TearFlags = { TEAR_HOMING = 1 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5, ENTITY_TEAR = 2 }
PickupVariant = { PICKUP_HEART = 10, PICKUP_PILL = 70, PICKUP_COLLECTIBLE = 100, PICKUP_TAROTCARD = 300 }
HeartSubType = { HEART_SOUL = 3, HEART_BLACK = 6 }
ItemPoolType = { POOL_TREASURE = 0, POOL_DEVIL = 3, POOL_ANGEL = 4 }
RoomType = { ROOM_DEVIL = 14, ROOM_ANGEL = 15 }
GameStateFlag = {
    STATE_DEVILROOM_SPAWNED = 5,
    STATE_DEVILROOM_VISITED = 6,
}
GridRooms = { ROOM_DEVIL_IDX = -1 }
ActiveSlot = {
    SLOT_PRIMARY = 0,
    SLOT_SECONDARY = 1,
    SLOT_POCKET = 2,
    SLOT_POCKET2 = 3,
}
Card = {
    RUNE_HAGALAZ = 32,
    RUNE_BLACK = 41,
    RUNE_SHARD = 55,
    CARD_SOUL_ISAAC = 81,
    CARD_SOUL_JACOB = 97,
}
SoundEffect = { SOUND_CHOIR_UNLOCK = 1, SOUND_POWERUP2 = 2, SOUND_HOLY = 3 }

local vectorMeta = {
    __add = function(left, right)
        return Vector(left.X + right.X, left.Y + right.Y)
    end,
}
function Vector(x, y)
    return setmetatable({ X = x or 0, Y = y or 0 }, vectorMeta)
end

Color = setmetatable({}, {
    __call = function(_, r, g, b, a, ro, go, bo)
        return { R = r, G = g, B = b, A = a, RO = ro, GO = go, BO = bo }
    end,
})
Color.Default = Color(1, 1, 1, 1, 0, 0, 0)

function EntityRef(entity)
    return { Entity = entity }
end

local player = {
    InitSeed = 1001,
    ControllerIndex = 0,
    Position = Vector(120, 160),
    activeItem = DEBUG_CONTROLLER_ID,
    dead = false,
}

function player:ToPlayer()
    return self
end

function player:IsDead()
    return self.dead
end

function player:HasCollectible(itemId)
    return itemId == DEBUG_CONTROLLER_ID
end

function player:GetCollectibleNum(itemId)
    return itemId == DEBUG_CONTROLLER_ID and 1 or 0
end

function player:GetActiveItem()
    return self.activeItem
end

function Game()
    return {
        GetNumPlayers = function()
            return 1
        end,
        GetSeeds = function()
            return { GetStartSeedString = function() return "TEST RUN" end }
        end,
    }
end

function MusicManager()
    return {
        GetCurrentMusicID = function() return 1 end,
        Play = function() end,
        Fadeout = function() end,
    }
end

Input = {
    IsActionPressed = function(action)
        return pressedActions[action] == true
    end,
}

local function itemIdForName(name)
    local ids = {
        ["Debug Controller"] = DEBUG_CONTROLLER_ID,
        ["调试控制器"] = DEBUG_CONTROLLER_ID,
        EssentialBalm = 733,
        Wuhu = 734,
        Aphrodisiac = 735,
        Musicbox = 736,
        Angelbox = 737,
        Devilbox = 738,
        ds4 = 739,
        ["Uncut Cord"] = 740,
        ["未剪断的脐带"] = 740,
        ["Shredded Tarot"] = 741,
        ["剪碎的塔罗"] = 741,
        ["Sterilization Certificate"] = 742,
        ["绝育证明"] = 742,
        ["Empty Cradle"] = 743,
        ["空摇篮"] = 743,
        ["Blood Skull Gu"] = 744,
        ["血颅蛊"] = 744,
        ["Between Death and Life"] = 745,
        ["生死一念间"] = 745,
        Condom = 746,
        ["避孕套"] = 746,
        ["Utility Knife"] = 747,
        ["美工刀"] = 747,
        ["Coin-Sewn Sword"] = 748,
        ["铜钱剑"] = 748,
        ["Coin-Faced Mask"] = 749,
        ["铜钱面具"] = 749,
        ["Black Taisui"] = 750,
        ["黑太岁"] = 750,
        ["Meat Lump"] = 751,
        ["肉块"] = 751,
        ["Good Girl of Babylon"] = 752,
        ["巴比伦好女孩"] = 752,
    }
    return ids[name] or -1
end

Isaac = {
    GetItemIdByName = itemIdForName,
    GetMusicIdByName = function(name)
        return name == "MusicboxTheme" and 736 or -1
    end,
    GetPlayer = function()
        return player
    end,
    DebugString = function() end,
    ExecuteCommand = function(command)
        executedCommands[#executedCommands + 1] = command
    end,
    GetRoomEntities = function()
        return {}
    end,
    FindByType = function()
        return {}
    end,
    WorldToScreen = function(position)
        return position
    end,
    RenderText = function(text)
        renderedAnimations[#renderedAnimations + 1] = "text:" .. tostring(text)
    end,
}

function Sprite()
    local sprite = { animation = nil, path = nil }
    function sprite:Load(path)
        self.path = path
    end
    function sprite:Play(animation)
        self.animation = animation
    end
    function sprite:Render()
        renderedAnimations[#renderedAnimations + 1] = self.animation
    end
    return sprite
end

function RegisterMod(name, version)
    local mod = { Name = name, Version = version }
    function mod:AddCallback(callbackId, fn, param)
        callbacks[callbackId] = callbacks[callbackId] or {}
        callbacks[callbackId][#callbacks[callbackId] + 1] = { fn = fn, param = param }
    end
    function mod:HasData()
        return false
    end
    function mod:LoadData()
        return "{}"
    end
    function mod:SaveData() end
    return mod
end

package.loaded.json = nil
package.preload.json = function()
    return {
        encode = function() return "{}" end,
        decode = function() return {} end,
    }
end

EID = {
    ModIndicator = {},
    addCollectible = function() end,
    addDescriptionModifier = function() end,
}

dofile("main.lua")

local function findCallback(callbackId, param)
    for _, entry in ipairs(callbacks[callbackId] or {}) do
        if param == nil or entry.param == param then
            return entry.fn
        end
    end
    error("missing callback " .. tostring(callbackId) .. " param " .. tostring(param), 2)
end

local useDebugController = findCallback(ModCallbacks.MC_USE_ITEM, DEBUG_CONTROLLER_ID)

local function callAll(callbackId, ...)
    for _, entry in ipairs(callbacks[callbackId] or {}) do
        pcall(entry.fn, Neverbirth, ...)
    end
end

local function clearInput()
    for key in pairs(pressedActions) do
        pressedActions[key] = nil
    end
end

local function press(actionName)
    clearInput()
    pressedActions[ButtonAction[actionName]] = true
end

local function releaseAndUpdate()
    clearInput()
    callAll(ModCallbacks.MC_POST_UPDATE)
end

local function openMenu()
    useDebugController(Neverbirth, DEBUG_CONTROLLER_ID, nil, player)
end

local function renderContains(animation)
    renderedAnimations = {}
    callAll(ModCallbacks.MC_POST_RENDER)
    for _, value in ipairs(renderedAnimations) do
        if value == animation then
            return true
        end
    end
    return false
end

local function test_root_renders_four_direction_ui()
    openMenu()
    assertTruthy(renderContains("Left"), "root UI should render left key")
    assertTruthy(renderContains("Up"), "root UI should render up key")
    assertTruthy(renderContains("Right"), "root UI should render right key")
    assertTruthy(renderContains("Down"), "root UI should render down key")
end

local function test_left_submenu_executes_debug_1_and_closes()
    releaseAndUpdate()
    press("ACTION_SHOOTLEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Num1"), "left submenu should show debug 1")

    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 1", "left submenu down should execute debug 1")
    assertEquals(renderContains("Num1"), false, "menu should close after executing debug 1")
end

local function test_left_submenu_right_returns_to_root()
    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTLEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Left"), "right from left submenu should return to root")
end

local function test_all_submenu_commands()
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTLEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 4", "up-left should execute debug 4")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 5", "up-up should execute debug 5")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 6", "up-right should execute debug 6")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 7", "right-up should execute debug 7")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 8", "right-right should execute debug 8")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 9", "right-down should execute debug 9")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 10", "down-down should execute debug 10")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Num12"), "down submenu should render debug 12 on the left")
    assertTruthy(renderContains("Num13"), "down submenu should render debug 13 on the right")

    releaseAndUpdate()
    press("ACTION_SHOOTLEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 12", "down-left should execute debug 12")

    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(executedCommands[#executedCommands], "debug 13", "down-right should execute debug 13")
end

local function test_movement_actions_do_not_select_menu_entries()
    openMenu()
    releaseAndUpdate()
    press("ACTION_LEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Left"), "movement left must not select the debug menu")

    press("ACTION_DOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Left"), "movement down must not select the debug menu")
    useDebugController(Neverbirth, DEBUG_CONTROLLER_ID, nil, player)
end

local function test_up_down_and_right_left_and_down_up_return_to_root()
    openMenu()
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Left"), "down from up submenu should return to root")

    releaseAndUpdate()
    press("ACTION_SHOOTRIGHT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTLEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Left"), "left from right submenu should return to root")

    releaseAndUpdate()
    press("ACTION_SHOOTDOWN")
    callAll(ModCallbacks.MC_POST_UPDATE)
    releaseAndUpdate()
    press("ACTION_SHOOTUP")
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertTruthy(renderContains("Left"), "up from down submenu should return to root")
end

local function test_input_debounce_prevents_held_direction_repeating()
    local before = #executedCommands
    releaseAndUpdate()
    press("ACTION_SHOOTLEFT")
    callAll(ModCallbacks.MC_POST_UPDATE)
    callAll(ModCallbacks.MC_POST_UPDATE)
    callAll(ModCallbacks.MC_POST_UPDATE)
    assertEquals(#executedCommands, before, "holding left after entering left submenu should not execute debug 2")
    releaseAndUpdate()
end

local function test_use_again_closes_and_tear_suppression_only_while_open()
    local tear = { removed = false, SpawnerEntity = player }
    function tear:Remove()
        self.removed = true
    end

    callAll(ModCallbacks.MC_POST_FIRE_TEAR, tear)
    assertEquals(tear.removed, true, "open debug menu should suppress player tears")

    useDebugController(Neverbirth, DEBUG_CONTROLLER_ID, nil, player)
    local secondTear = { removed = false, SpawnerEntity = player }
    function secondTear:Remove()
        self.removed = true
    end
    callAll(ModCallbacks.MC_POST_FIRE_TEAR, secondTear)
    assertEquals(secondTear.removed, false, "closed debug menu should not suppress player tears")
end

test_root_renders_four_direction_ui()
test_left_submenu_executes_debug_1_and_closes()
test_left_submenu_right_returns_to_root()
test_all_submenu_commands()
test_movement_actions_do_not_select_menu_entries()
test_up_down_and_right_left_and_down_up_return_to_root()
test_input_debounce_prevents_held_direction_repeating()
test_use_again_closes_and_tear_suppression_only_while_open()

print("debug controller behavior tests passed")
