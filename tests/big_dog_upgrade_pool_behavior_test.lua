-- Exercise real module callbacks against a deterministic, depleting item pool.
dofile("tests/localization_test.lua")

local function equal(actual, expected, message)
    assert(actual == expected, message .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

ModCallbacks.MC_POST_GET_COLLECTIBLE = 63
local DOG, ROD, ECHO, ORDINARY, BREAKFAST = 780, 781, 782, 100, 25
local players, registered, saveRoot = {}, {}, {}
local pool = { queue = {}, calls = {}, resets = {}, depleted = {}, nestedDepth = 0, maxDepth = 0 }
local mod = {}
function mod:AddCallback(id, callback, filter)
    registered[id] = registered[id] or {}
    table.insert(registered[id], { callback = callback, filter = filter })
end
local function dispatch(selected, poolType, decrease, seed)
    local result
    for _, entry in ipairs(registered[ModCallbacks.MC_POST_GET_COLLECTIBLE] or {}) do
        local value = entry.callback(mod, selected, poolType, decrease, seed)
        if value ~= nil then result = value end
    end
    return result
end
function pool:ResetCollectible(id)
    self.resets[#self.resets + 1] = id
    self.depleted[id] = nil
end
function pool:GetCollectible(poolType, decrease, seed)
    self.calls[#self.calls + 1] = { poolType = poolType, decrease = decrease, seed = seed }
    if self.fail then error("simulated pool failure") end
    local selected = table.remove(self.queue, 1) or self.repeatItem or ORDINARY
    if self.depleted[selected] then selected = ORDINARY end
    if decrease then self.depleted[selected] = true end
    self.nestedDepth = self.nestedDepth + 1
    self.maxDepth = math.max(self.maxDepth, self.nestedDepth)
    local replacement = dispatch(selected, poolType, decrease, seed)
    self.nestedDepth = self.nestedDepth - 1
    return replacement or selected
end
Game = function() return { GetItemPool = function() return pool end } end

local api = dofile("big_dog_bark.lua")(mod, {
    ItemIds = { BigDogBark = DOG, WindChargeRod = ROD, EchoShard = ECHO },
    GetPlayers = function() return players end,
    GetSaveRoot = function() return saveRoot end,
    GetCurrentRunSeed = function() return "POOL TEST" end,
})
local registrations = registered[ModCallbacks.MC_POST_GET_COLLECTIBLE] or {}
equal(#registrations, 1, "the upgrade availability callback is registered exactly once")
equal(registrations[1].filter, nil, "pool callback uses its documented unfiltered registration")

local function player(slot)
    local value = { activeItems = {}, collectibles = {} }
    if slot ~= nil then value.activeItems[slot] = DOG end
    function value:GetActiveItem(index) return self.activeItems[index] or 0 end
    function value:HasCollectible(id) return self.collectibles[id] == true end
    return value
end
local function reset()
    players = { player() }
    pool.queue, pool.calls, pool.resets, pool.depleted = {}, {}, {}, {}
    pool.repeatItem, pool.fail = nil, nil
    pool.nestedDepth, pool.maxDepth = 0, 0
end

-- Both blocked upgrades are restored after the replacement has been drawn.
reset()
pool.queue = { ROD, ECHO, ORDINARY }
equal(pool:GetCollectible(0, true, 123), ORDINARY, "no owner receives an ordinary replacement")
equal(#pool.resets, 2, "only rejected upgrades have their native depletion undone")
equal(pool.depleted[ROD], nil, "rod remains available for a later owner")
equal(pool.depleted[ECHO], nil, "echo remains available for a later owner")
equal(pool.depleted[ORDINARY], true, "the actual replacement depletes normally")
equal(pool.maxDepth, 2, "repeated blocked candidates do not recurse without a bound")
for _, call in ipairs(pool.calls) do
    equal(call.poolType, 0, "replacement retains the requested pool")
    equal(call.decrease, true, "replacement retains the depletion flag")
    assert(call.seed > 0, "replacement uses a nonzero deterministic seed")
end
local firstRetrySeed = pool.calls[2].seed
reset()
pool.queue = { ROD, ECHO, ORDINARY }
pool:GetCollectible(0, true, 123)
equal(pool.calls[2].seed, firstRetrySeed, "same incoming seed repeats the replacement sequence")

-- Main, Schoolbag and both pocket active slots count as current ownership.
for slot = 0, 3 do
    for _, id in ipairs({ ROD, ECHO }) do
        reset()
        players = { player(slot) }
        pool.queue = { id }
        equal(pool:GetCollectible(0, true, 456), id, "a currently held active permits its upgrade")
        equal(#pool.calls, 1, "allowed selection does not reroll")
        equal(#pool.resets, 0, "allowed selection keeps normal depletion")
        equal(pool.depleted[id], true, "allowed upgrade is consumed normally")
        players[1].activeItems[slot] = nil
        pool.queue = { ORDINARY }
        pool:GetCollectible(0, true, 457)
        players[1].activeItems[slot] = DOG
        equal(pool.depleted[id], true, "losing and reacquiring the dog never replenishes a used upgrade")
    end
end

-- Current shared ownership is read at draw time, without a frame or save latch.
reset()
local owner = player(1)
players = { player(), owner }
equal(dispatch(ROD, 1, false, 700), nil, "a second co-op player opens the shared pool")
owner.activeItems[1] = nil
pool.queue = { ORDINARY }
equal(dispatch(ECHO, 1, false, 700), ORDINARY, "losing the last dog closes the pool immediately")
owner.activeItems[2] = DOG
equal(dispatch(ECHO, 1, false, 700), nil, "reacquiring in a pocket slot immediately reopens it")
players = { player() }
pool.queue = { ORDINARY }
equal(dispatch(ROD, 1, false, 700), ORDINARY, "an absent co-op owner cannot keep the gate open")
equal(pool.calls[#pool.calls].poolType, 1, "shop draws retain their original pool")
equal(#pool.resets, 0, "nondepleting previews never reset native pool state")
players[1].collectibles[DOG] = true
pool.queue = { ORDINARY }
equal(dispatch(ROD, 0, false, 700), ORDINARY, "inventory effects without an active slot do not open the gate")
equal(dispatch(ORDINARY, 0, true, 700), nil, "unrelated items are not replaced")
equal(dispatch(DOG, 0, true, 700), nil, "the prerequisite itself remains available")

-- Continue/new-run handling cannot make past possession an unlock flag.
players = { owner }
api.Callbacks.GameStarted(mod, true)
equal(dispatch(ECHO, 0, false, 701), nil, "continue uses the currently loaded active slots")
owner.activeItems = {}
api.Callbacks.GameStarted(mod, true)
equal(dispatch(ECHO, 0, false, 701), ORDINARY, "continue without the dog stays closed")
api.Callbacks.GameStarted(mod, false)
equal(dispatch(ROD, 0, false, 701), ORDINARY, "a new run without the dog stays closed")

-- Pathological repeaters and engine errors fail closed and release the guard.
reset()
pool.repeatItem = ROD
equal(dispatch(ROD, 0, false, 0), BREAKFAST, "endless blocked previews use the engine's empty-pool fallback")
assert(#pool.calls <= 100, "blocked rerolls are bounded")
equal(#pool.resets, 0, "preview exhaustion has no depletion side effects")
pool.repeatItem = nil
pool.fail = true
pool.depleted[ECHO] = true
equal(dispatch(ECHO, 0, true, 42), BREAKFAST, "a draw failure cannot leak a blocked upgrade")
equal(pool.depleted[ECHO], nil, "failed replacement still restores the rejected upgrade")
pool.fail = false
pool.queue = { ORDINARY }
equal(dispatch(ROD, 0, false, 42), ORDINARY, "the reroll guard is cleared after failure")

print("Big Dog upgrade pool behavior tests passed.")
