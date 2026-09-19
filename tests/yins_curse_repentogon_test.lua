-- Real module + registered callback tests. Native pickup/damage internals are
-- simulated; this is not evidence of an in-game run.
local function equal(actual, expected, message)
    assert(actual == expected, (message or "assertion failed")
        .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
end

CollectibleType = { COLLECTIBLE_BLACK_CANDLE = 260, COLLECTIBLE_IPECAC = 149 }
EntityType = { ENTITY_PLAYER = 1, ENTITY_PICKUP = 5 }
PickupVariant = { PICKUP_COLLECTIBLE = 100 }
DamageFlag = { DAMAGE_EXPLOSION = 4 }
ModCallbacks = {
    MC_PRE_PLAYER_TAKE_DMG = 1008, MC_POST_ADD_COLLECTIBLE = 1005,
    MC_POST_UPDATE = 1, MC_PRE_PICKUP_COLLISION = 38,
    MC_POST_PICKUP_INIT = 34, MC_POST_PICKUP_UPDATE = 35,
    MC_POST_NEW_ROOM = 19, MC_POST_GAME_STARTED = 15, MC_PRE_GAME_EXIT = 17,
}
local YIN, Q4 = 9000, 900
local function pickup(id)
    local item = {
        Type = 5, Variant = 100, SubType = id, Visible = true,
        Wait = 0, EntityCollisionClass = 1, InitSeed = id, data = {},
    }
    function item:Exists() return not self.removed end
    function item:ToPickup() return self end
    function item:GetData() return self.data end
    function item:Morph(t, v, s) self.Type, self.Variant, self.SubType = t, v, s end
    return item
end

local function setup(candle)
    local actor = { InitSeed = 123, count = 0, candle = candle == true }
    function actor:HasCollectible(id) return id == 260 and self.candle end
    function actor:GetCollectibleNum(id) return id == YIN and self.count or 0 end
    function actor:ToPlayer() return self end
    local world = { players = { actor }, entities = {}, seed = "test", saves = 0 }
    local config = { GetCollectible = function(_, id) return { Quality = id == Q4 and 4 or 0 } end }
    Isaac = {
        GetRoomEntities = function() return world.entities end,
        GetItemConfig = function() return config end,
        DebugString = function() end,
    }
    local root, registrations, mod = {}, {}, {}
    function mod:AddCallback(id, fn, filter)
        registrations[id] = registrations[id] or {}
        table.insert(registrations[id], { fn = fn, filter = filter })
    end
    dofile("yins_curse.lua")(mod, {
        ItemId = YIN, GetSaveRoot = function() return root end,
        GetCurrentRunSeed = function() return world.seed end,
        GetPlayers = function() return world.players end,
        Save = function() world.saves = world.saves + 1 end,
    })
    function world:dispatch(id, filter, ...)
        local result
        for _, callback in ipairs(registrations[id] or {}) do
            if callback.filter == nil or callback.filter == filter then
                result = callback.fn(mod, ...)
            end
        end
        return result
    end
    function world:add(id, player)
        player = player or actor
        if id == YIN then player.count = player.count + 1 end
        return self:dispatch(ModCallbacks.MC_POST_ADD_COLLECTIBLE, id, id, 0, true, 0, 0, player)
    end
    world:dispatch(ModCallbacks.MC_POST_GAME_STARTED, nil, false)
    return world, actor, mod.YinsCurseTestAPI, registrations
end

local passed, failed = 0, 0
local function test(name, fn)
    local ok, err = pcall(fn)
    if ok then passed = passed + 1; print("PASS " .. name)
    else failed = failed + 1; print("FAIL " .. name .. ": " .. tostring(err)) end
end

test("real AddCollectible activates before the next update and survives immediate removal", function()
    local world, actor, api = setup(false)
    equal(world:add(YIN), nil, "POST callback returns nothing")
    equal(api.GetSavedState().yinCurseActive, true, "activate at actual addition")
    actor.count = 0
    world:dispatch(ModCallbacks.MC_POST_UPDATE)
    local q4 = pickup(Q4)
    world:dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, 100, q4)
    equal(q4.SubType, 149, "the permanent curse survives removal")
end)

test("same-frame Black Candle changes cannot change the acquisition snapshot", function()
    local world, actor, api = setup(true)
    world:add(YIN)
    actor.candle = false
    world:dispatch(ModCallbacks.MC_POST_UPDATE)
    equal(api.GetSavedState().q4Mode, "bonus_root", "snapshot is taken at addition")
end)

test("normal pedestal preserves its pre-pickup candle snapshot", function()
    local world, actor, api = setup(true)
    world:dispatch(ModCallbacks.MC_PRE_PICKUP_COLLISION, 100, pickup(YIN), actor, false)
    actor.candle = false
    world:add(YIN)
    equal(api.GetSavedState().q4Mode, "bonus_root")
end)

test("other collectibles do not activate Yin; POST is filtered by item ID", function()
    local world, _, api, registrations = setup(false)
    world:add(1234)
    equal(api.GetSavedState().yinCurseActive, false)
    local callbacks = registrations[ModCallbacks.MC_POST_ADD_COLLECTIBLE] or {}
    equal(#callbacks, 1, "one acquisition owner")
    equal(callbacks[1].filter, YIN, "collectible filter")
end)

test("cancelled pedestal contact grants nothing", function()
    local world, actor, api = setup(true)
    world:dispatch(ModCallbacks.MC_PRE_PICKUP_COLLISION, 100, pickup(YIN), actor, false)
    for _ = 1, 10 do world:dispatch(ModCallbacks.MC_POST_UPDATE) end
    equal(api.GetSavedState().yinCurseActive, false)
end)

test("Q4 already in the room resolves on acquisition exactly once", function()
    local world, _, api = setup(false)
    local first, second = pickup(Q4), pickup(Q4)
    second.InitSeed = first.InitSeed + 1
    world.entities = { second, first }
    world:add(YIN)
    equal(first.SubType, 149)
    equal(second.SubType, Q4)
    world:add(YIN)
    world:dispatch(ModCallbacks.MC_POST_UPDATE)
    equal(second.SubType, Q4)
    equal(api.GetSavedState().firstQ4Resolved, true)
end)

test("vetoed Morph does not consume the only Q4 opportunity", function()
    local world, actor, api = setup(false)
    api.RecordFirstAcquisition(actor)
    local q4 = pickup(Q4)
    q4.Morph = function() end -- REPENTOGON MC_PRE_PICKUP_MORPH may cancel without throwing.
    world:dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, 100, q4)
    equal(q4.SubType, Q4)
    equal(api.GetSavedState().firstQ4Resolved, false, "no success without a changed pedestal")
    equal(q4.data.NeverbirthYinGeneratedIpecac, nil, "failed mutation has no generated marker")
    q4.Morph = function(self, t, v, s) self.Type, self.Variant, self.SubType = t, v, s end
    world:dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, 100, q4)
    equal(q4.SubType, 149)
    equal(api.GetSavedState().firstQ4Resolved, true)
end)

test("redirected Morph and removed pedestal also preserve the opportunity", function()
    for _, mutation in ipairs({
        function(self) self.SubType = 123 end,
        function(self) self.SubType = 149; self.removed = true end,
    }) do
        local _, actor, api = setup(false)
        api.RecordFirstAcquisition(actor)
        local q4 = pickup(Q4)
        q4.Morph = mutation
        equal(api.ProcessCandidate(q4), false)
        equal(api.GetSavedState().firstQ4Resolved, false)
    end
end)

test("bonus spawn must actually return a surviving Ipecac pedestal", function()
    local _, actor, api = setup(true)
    api.RecordFirstAcquisition(actor)
    local q4 = pickup(Q4)
    local attempts = 0
    local options = { spawnBonusIpecac = function() attempts = attempts + 1; return pickup(123) end }
    equal(api.ProcessCandidate(q4, options), false)
    equal(api.ProcessCandidate(q4, options), false)
    equal(attempts, 1, "a redirected spawn cannot duplicate loot every frame")
    equal(api.GetSavedState().firstQ4Resolved, false)
    equal(q4.SubType, Q4)
    api.Callbacks.NewRoom()
    equal(api.ProcessCandidate(q4, { spawnBonusIpecac = function() return pickup(149) end }), true)
    equal(api.GetSavedState().firstQ4Resolved, true)
end)

test("continue retains the route after removal; a new run resets it", function()
    local world, actor, api = setup(true)
    world:add(YIN)
    actor.count, actor.candle = 0, false
    world:dispatch(ModCallbacks.MC_PRE_GAME_EXIT, nil, true)
    world:dispatch(ModCallbacks.MC_POST_GAME_STARTED, nil, true)
    equal(api.GetSavedState().yinCurseActive, true)
    equal(api.GetSavedState().q4Mode, "bonus_root")
    world.seed = "new-run"
    world:dispatch(ModCallbacks.MC_POST_GAME_STARTED, nil, false)
    equal(api.GetSavedState().yinCurseActive, false)
end)

test("an item wisp is not a permanent acquisition", function()
    local world, actor, api = setup(false)
    function actor:GetCollectibleNum(id, onlyTrueItems)
        return onlyTrueItems and 0 or 1
    end
    world:dispatch(ModCallbacks.MC_POST_UPDATE)
    equal(api.GetSavedState().yinCurseActive, false)
end)

test("actual bonus path uses constructed vectors and creates one independent pedestal", function()
    local world, _, api = setup(true)
    local vectorMeta = {}
    Vector = setmetatable({}, { __call = function(_, x, y)
        return setmetatable({ X = x, Y = y }, vectorMeta)
    end })
    vectorMeta.__add = function(a, b) return Vector(a.X + b.X, a.Y + b.Y) end
    local q4 = pickup(Q4)
    q4.Position, q4.OptionsPickupIndex = Vector(320, 280), 7
    world.entities = { q4 }
    local room = {
        FindFreePickupSpawnPosition = function(_, p) return p end,
        IsPositionInRoom = function() return true end,
        GetGridCollisionAtPos = function() return 0 end,
        GetDoor = function() return nil end,
    }
    Game = setmetatable({}, { __call = function() return { GetRoom = function() return room end } end })
    local spawned, calls = nil, 0
    Isaac.Spawn = function(t, v, id, position, velocity, source)
        equal(getmetatable(position), vectorMeta, "spawn position must use Vector")
        equal(getmetatable(velocity), vectorMeta, "spawn velocity must use Vector")
        equal(t, 5); equal(v, 100); equal(id, 149); equal(source, q4)
        assert((position.X - q4.Position.X)^2 + (position.Y - q4.Position.Y)^2 >= 48^2)
        calls = calls + 1
        spawned = pickup(id)
        spawned.OptionsPickupIndex = 7
        -- Exercise synchronous spawn callbacks: they cannot consume twice.
        world:dispatch(ModCallbacks.MC_POST_PICKUP_INIT, 100, spawned)
        return spawned
    end
    world:add(YIN)
    equal(calls, 1)
    equal(q4.SubType, Q4)
    equal(q4.OptionsPickupIndex, 7)
    equal(spawned.OptionsPickupIndex, 0)
    equal(spawned.data.NeverbirthYinGeneratedIpecac, true)
    equal(api.GetSavedState().firstQ4Resolved, true)
    world:dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, 100, q4)
    equal(calls, 1)
    Vector, Game = nil, nil
end)

test("invisible or unready Q4 waits until interactable", function()
    local world, _, api = setup(false)
    world:add(YIN)
    local q4 = pickup(Q4)
    q4.Wait = 20
    world:dispatch(ModCallbacks.MC_POST_PICKUP_INIT, 100, q4)
    equal(api.GetSavedState().firstQ4Resolved, false)
    q4.Wait, q4.Visible = 0, false
    world:dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, 100, q4)
    equal(api.GetSavedState().firstQ4Resolved, false)
    q4.Visible = true
    world:dispatch(ModCallbacks.MC_POST_PICKUP_UPDATE, 100, q4)
    equal(q4.SubType, 149)
end)

print(string.format("Yin REPENTOGON tests: %d passed, %d failed", passed, failed))
assert(failed == 0, "Yin REPENTOGON regression failed")
