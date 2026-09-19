-- Regression for the confirmed Black Candle contract (2026-09-16).
-- Loads the real module. Native immunity/shield handling below is simulated.
-- These checks cover removal of the erroneous extra immunity from Black Candle.
-- They do NOT prove the still-unimplemented no-Candle immunity suppression.
local function equal(actual, expected, message)
    assert(actual == expected, (message or "assertion failed")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

CollectibleType = {
    COLLECTIBLE_BLACK_CANDLE = 260, COLLECTIBLE_IPECAC = 149,
    COLLECTIBLE_HOST_HAT = 375, COLLECTIBLE_PYROMANIAC = 223,
}
EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5 }
PickupVariant = { PICKUP_COLLECTIBLE = 100 }
DamageFlag = { DAMAGE_EXPLOSION = 1 << 2 }
ModCallbacks = {
    MC_ENTITY_TAKE_DMG = 11, MC_PRE_PLAYER_TAKE_DMG = 1008, MC_POST_UPDATE = 1,
}
Isaac = nil

local callbacks, root = {}, {}
local mod = {}
function mod:AddCallback(id, fn, filter)
    assert(id ~= nil, "registration must use an available callback")
    callbacks[id] = callbacks[id] or {}
    callbacks[id][#callbacks[id] + 1] = { fn = fn, filter = filter }
end
dofile("yins_curse.lua")(mod, {
    ItemId = 9000,
    GetSaveRoot = function() return root end,
    GetCurrentRunSeed = function() return "yin-order" end,
    GetPlayers = function() return {} end,
})
local api = assert(mod.YinsCurseTestAPI)
local EXPLOSION = DamageFlag.DAMAGE_EXPLOSION

local function player(candle, variant, immunityItem)
    local actor = {
        Type = 1, Variant = variant or 0, candle = candle, shield = 1, health = 6,
        immunityItem = immunityItem, nativeEffectCalls = 0,
    }
    function actor:HasCollectible(id)
        return (id == 260 and self.candle) or id == self.immunityItem
    end
    function actor:GetCollectibleNum() return 0 end
    function actor:ToPlayer() return self end
    function actor:TakeDamage() error("Yin must not fabricate a second damage event") end
    function actor:RemoveCollectible() error("Yin must not remove native items") end
    function actor:BlockCollectible() error("Yin must not disable whole items") end
    return actor
end

local function dispatch(id, actor, amount, flags, source, countdown)
    for _, entry in ipairs(callbacks[id] or {}) do
        local key = id == ModCallbacks.MC_PRE_PLAYER_TAKE_DMG and actor.Variant or actor.Type
        if entry.filter == nil or entry.filter == key then
            local result = entry.fn(mod, actor, amount, flags, source, countdown)
            equal(result, nil, "Yin must leave this hit to the player's existing defenses")
        end
    end
end

local function damage(actor, flags, amount, source, countdown)
    amount, countdown = amount or 1, countdown or 0
    dispatch(ModCallbacks.MC_PRE_PLAYER_TAKE_DMG, actor, amount, flags, source, countdown)
    -- A minimal native stand-in, not a reconstruction of all engine branches.
    -- A source must see the original blast and may run its own other effects.
    if (flags & EXPLOSION) ~= 0 and actor.immunityItem
        and actor:HasCollectible(actor.immunityItem) then
        actor.nativeEffectCalls = actor.nativeEffectCalls + 1
        return "native-immunity"
    end
    if actor.shield > 0 then
        actor.shield = actor.shield - 1
        return "native-shield"
    end
    dispatch(ModCallbacks.MC_ENTITY_TAKE_DMG, actor, amount, flags, source, countdown)
    actor.health = actor.health - amount
    actor.lastHit = { amount = amount, flags = flags, source = source, countdown = countdown }
    return "native-health"
end

local function activate()
    api.ResetForTest("yin-order")
    api.RecordFirstAcquisition(player(false))
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then
        passed = passed + 1
        print("PASS " .. name)
    else
        failed = failed + 1
        print("FAIL " .. name .. ": " .. tostring(err))
    end
end

test("Black Candle alone does not cancel explosion health damage", function()
    activate()
    local owner, source = player(true), { Entity = { Type = 4 } }
    owner.shield = 0
    equal(damage(owner, EXPLOSION | (1 << 8), 2, source, 17), "native-health")
    equal(owner.health, 4)
    equal(owner.lastHit.amount, 2)
    equal(owner.lastHit.flags, EXPLOSION | (1 << 8))
    equal(owner.lastHit.source, source)
    equal(owner.lastHit.countdown, 17)
end)

test("Black Candle alone does not preserve Holy Mantle against an explosion", function()
    activate()
    local owner = player(true)
    equal(damage(owner, EXPLOSION), "native-shield")
    equal(owner.shield, 0)
    equal(owner.health, 6)
end)

for _, itemId in ipairs({ 375, 223 }) do
    test("Black Candle leaves immunity and native effects to source " .. itemId, function()
        activate()
        local owner = player(true, 0, itemId)
        equal(damage(owner, EXPLOSION), "native-immunity")
        equal(owner.nativeEffectCalls, 1, "the original blast reaches native item handling")
        equal(owner:HasCollectible(itemId), true, "the source stays held")
        equal(owner.shield, 1)
        equal(owner.health, 6)
    end)
end

test("removing the immunity source leaves Black Candle without immunity", function()
    activate()
    local owner = player(true, 0, 375)
    equal(damage(owner, EXPLOSION), "native-immunity")
    owner.immunityItem, owner.shield = nil, 0
    equal(damage(owner, EXPLOSION), "native-health")
    equal(owner.health, 5)
end)

test("co-op players retain their own defenses regardless of Black Candle", function()
    activate()
    local holder, other = player(true, 0), player(false, 1)
    holder.shield, other.shield = 0, 0
    equal(damage(holder, EXPLOSION), "native-health")
    equal(damage(other, EXPLOSION), "native-health")
    other.candle = true
    equal(damage(other, EXPLOSION), "native-health", "another variant gets no added immunity")
    equal(holder.health, 5)
    equal(other.health, 4)
end)

test("gaining or losing Black Candle alone never grants immunity", function()
    activate()
    local owner = player(false)
    owner.shield = 0
    equal(damage(owner, EXPLOSION), "native-health")
    owner.candle = true
    equal(damage(owner, EXPLOSION), "native-health")
    owner.candle = false
    equal(damage(owner, EXPLOSION), "native-health")
    equal(owner.health, 3)
end)

test("inactive curse leaves normal damage handling intact", function()
    api.ResetForTest("yin-order")
    local owner = player(true)
    equal(damage(owner, EXPLOSION), "native-shield")
    equal(owner.shield, 0)
end)

test("ordinary damage is unchanged with Black Candle and a blast immunity source", function()
    activate()
    local owner = player(true, 0, 375)
    equal(damage(owner, 0), "native-shield")
    equal(owner.shield, 0)
    equal(owner.nativeEffectCalls, 0)
end)

test("runtime reset preserves the curse without granting Black Candle immunity", function()
    activate()
    api.ResetRuntimeOnly()
    local owner = player(true)
    owner.shield = 0
    equal(owner:GetCollectibleNum(api.ItemId), 0)
    equal(damage(owner, EXPLOSION), "native-health")
    equal(api.GetSavedState().yinCurseActive, true)
end)

print(string.format("Yin's Curse Black Candle contract tests: %d passed, %d failed.", passed, failed))
assert(failed == 0, "Yin's Curse Black Candle contract tests failed")
