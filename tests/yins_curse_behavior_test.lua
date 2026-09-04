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

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function makePlayer(hasBlackCandle)
    return {
        InitSeed = hasBlackCandle and 1001 or 1002,
        HasCollectible = function(_, itemId)
            return itemId == 260 and hasBlackCandle
        end,
    }
end

local function makePickup(itemId)
    local data = {}
    local pickup = {
        Type = 5,
        Variant = 100,
        SubType = itemId,
        Visible = true,
        Wait = 0,
        EntityCollisionClass = 1,
        Position = Vector(320, 280),
        InitSeed = itemId * 10,
        removed = false,
        morphedTo = nil,
    }
    function pickup:GetData()
        return data
    end
    function pickup:Exists()
        return not self.removed
    end
    function pickup:Morph(entityType, variant, subtype, keepPrice, keepSeed, ignoreModifiers)
        self.Type = entityType
        self.Variant = variant
        self.SubType = subtype
        self.morphedTo = subtype
        self.morphArgs = { keepPrice, keepSeed, ignoreModifiers }
    end
    return pickup
end

dofile("tests/localization_test.lua")

local api = Neverbirth and Neverbirth.YinsCurseTestAPI
assertTruthy(api, "Yin's Curse test API must be registered")
assertEquals(api.ItemId > 0, true, "Yin's Curse runtime item id")
assertEquals(api.BlackCandleId, 260, "Black Candle collectible id")
assertEquals(api.IpecacId, 149, "Ipecac collectible id")

-- A normal pedestal collision snapshots Black Candle before the item is added.
api.ResetForTest("collision-run")
local collisionCount = 0
local collisionPlayer = {
    InitSeed = 2001,
    HasCollectible = function(_, itemId)
        return itemId == 260
    end,
    GetCollectibleNum = function()
        return collisionCount
    end,
}
assertEquals(api.Callbacks.PrePickupCollision(nil, makePickup(api.ItemId), collisionPlayer, false), nil,
    "normal pedestal collision is never cancelled")
collisionPlayer.HasCollectible = function() return false end
collisionCount = 1
api.Callbacks.PostUpdate()
assertEquals(api.GetSavedState().q4Mode, "bonus_root",
    "route uses the pre-pickup Black Candle snapshot")

local function q4Config(itemId)
    if itemId == 900 or itemId == 901 then
        return { Quality = 4 }
    end
    return { Quality = 0 }
end

-- No Black Candle at the first acquisition locks replace_root.
api.ResetForTest("replace-run")
assertEquals(api.RecordFirstAcquisition(makePlayer(false)), true, "first acquisition activates the run curse")
local state = api.GetSavedState()
assertEquals(state.yinCurseActive, true, "run curse active")
assertEquals(state.q4Mode, "replace_root", "route without Black Candle")
assertEquals(state.firstQ4Resolved, false, "first Q4 initially unresolved")

local firstQ4 = makePickup(900)
assertEquals(api.ProcessCandidate(firstQ4, {
    getCollectibleConfig = q4Config,
}), true, "first visible Q4 is resolved")
assertEquals(firstQ4.morphedTo, 149, "first Q4 is replaced with Ipecac")
assertEquals(api.GetSavedState().firstQ4Resolved, true, "replace route resolves globally")
assertEquals(api.ProcessCandidate(makePickup(901), {
    getCollectibleConfig = q4Config,
}), false, "a second Q4 is ignored")

-- Black Candle at the first acquisition locks bonus_root and preserves the Q4.
api.ResetForTest("bonus-run")
assertEquals(api.RecordFirstAcquisition(makePlayer(true)), true, "Black Candle acquisition activates the run curse")
assertEquals(api.GetSavedState().q4Mode, "bonus_root", "route with Black Candle")
local bonusQ4 = makePickup(900)
local spawnedIpecac = 0
assertEquals(api.ProcessCandidate(bonusQ4, {
    getCollectibleConfig = q4Config,
    spawnBonusIpecac = function(sourcePickup)
        assertEquals(sourcePickup, bonusQ4, "bonus Ipecac source pedestal")
        spawnedIpecac = spawnedIpecac + 1
        return makePickup(149)
    end,
}), true, "bonus route resolves first Q4")
assertEquals(bonusQ4.SubType, 900, "bonus route preserves the Q4")
assertEquals(spawnedIpecac, 1, "bonus route spawns exactly one Ipecac")

-- Later Black Candle changes only explosion immunity, never the locked Q4 route.
api.ResetForTest("late-candle-run")
api.RecordFirstAcquisition(makePlayer(false))
assertEquals(api.GetSavedState().q4Mode, "replace_root", "late-candle route starts as replacement")
assertEquals(api.DecideExplosionDamage(makePlayer(true), api.ExplosionDamageFlag), false,
    "Black Candle directly cancels delivered explosion damage")
assertEquals(api.GetSavedState().q4Mode, "replace_root", "late Black Candle does not change Q4 route")
assertEquals(api.DecideExplosionDamage(makePlayer(false), api.ExplosionDamageFlag), nil,
    "without Black Candle, delivered explosion damage is not cancelled")
assertEquals(api.DecideExplosionDamage(makePlayer(true), 0), nil,
    "non-explosion damage is untouched")

-- Removing the item or clearing runtime-only tables cannot clear the saved run curse.
local beforeRuntimeReset = api.GetSavedState()
api.ResetRuntimeOnly()
local afterRuntimeReset = api.GetSavedState()
assertEquals(afterRuntimeReset.yinCurseActive, true, "item removal/runtime reset cannot clear run curse")
assertEquals(afterRuntimeReset.q4Mode, beforeRuntimeReset.q4Mode, "runtime reset preserves Q4 route")

-- A continued game with the same run seed preserves all resolved state.
api.ResetForTest("TEST RUN")
api.RecordFirstAcquisition(makePlayer(false))
api.ProcessCandidate(makePickup(900), { getCollectibleConfig = q4Config })
api.Callbacks.PreGameExit()
api.Callbacks.GameStarted(nil, true)
local continuedState = api.GetSavedState()
assertEquals(continuedState.yinCurseActive, true, "continued run keeps the permanent curse")
assertEquals(continuedState.q4Mode, "replace_root", "continued run keeps the route snapshot")
assertEquals(continuedState.firstQ4Resolved, true, "continued run keeps the resolved first Q4")

-- Multiple copies never reset the route or grant another first-Q4 resolution.
assertEquals(api.RecordFirstAcquisition(makePlayer(true)), false, "later copies do not reactivate")
assertEquals(api.GetSavedState().q4Mode, "replace_root", "later copy cannot change route")

-- Callback contracts: collision and normal damage paths must not cancel pickups/hits.
local collisionResult = api.Callbacks.PrePickupCollision(nil, makePickup(api.ItemId), makePlayer(false), false)
assertEquals(collisionResult, nil, "pickup collision callback must not cancel the pedestal")
local damageResult = api.Callbacks.PlayerDamage(nil, makePlayer(false), 1, 0, nil, 0)
assertEquals(damageResult, nil, "ordinary damage callback remains nil")

-- Registration and implementation stay scoped: Q0 passive, no pool entry, no global ItemConfig scan.
local itemsXml = readFile("content/items.xml")
local yinBlock = itemsXml:match('<passive[^>]-name="Yin&apos;s Curse"[^>]*/>')
    or itemsXml:match('<passive[^>]-name="Yin\'s Curse"[^>]*/>')
assertTruthy(yinBlock, "Yin's Curse must be registered as a passive")
assertTruthy(yinBlock:find('quality="0"', 1, true), "Yin's Curse must be quality 0")
assertTruthy(yinBlock:find('gfx="yins_curse.png"', 1, true), "Yin's Curse icon path")

for _, poolPath in ipairs({
    "content/itempools.xml",
    "content/itempools.en_us.xml",
    "content/itempools.zh_cn.xml",
}) do
    assertEquals(readFile(poolPath):find("Yin's Curse", 1, true), nil, poolPath .. " must not contain Yin's Curse")
    assertEquals(readFile(poolPath):find("阴的诅咒", 1, true), nil, poolPath .. " must not contain 阴的诅咒")
end

local source = readFile("main.lua")
local block = readFile("yins_curse.lua")
assertEquals(block:find("GetCollectibles", 1, true), nil, "must not enumerate the global ItemConfig collection")
assertTruthy(block:find("MC_PRE_PICKUP_COLLISION", 1, true), "must snapshot normal pedestal pickup")
assertTruthy(block:find("MC_POST_PICKUP_UPDATE", 1, true), "must observe visible/rerolled Q4 pedestals")

print("Yin's Curse behavior tests passed.")
