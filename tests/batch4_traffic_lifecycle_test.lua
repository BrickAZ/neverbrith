local fixture = dofile('tests/support/traffic_fixture.lua')
local root = arg and arg[1]
local function fresh(saved) return fixture({ Root = root, Saved = saved }) end
local function equal(a, b, label) assert(a == b, label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
local scenarios = 0
do
    local e = fresh()
    local open, heat = e.items.TrafficUnboxing, e.items.TrafficHeat
    local a = e.player(101, { [open] = 2, [heat] = 1 })
    local b = e.player(202, { [heat] = 2 })
    e.update()
    equal(a:GetCollectibleNum(open), 0, 'consume both actual copies')
    equal(a.evaluations + b.evaluations, 0, 'new heat waits until next update')
    equal(e.api.GetPersistentData().heatByPlayer['101'], 1, 'first owner layer')
    equal(e.api.GetPersistentData().heatByPlayer['202'], 2, 'second owner layers')
    for _ = 1, 25 do e.event(ModCallbacks.MC_POST_RENDER) end
    equal(e.count(50), 0, 'renders cannot grant a chest')
    equal(a.evaluations + b.evaluations, 0, 'renders cannot refresh heat')
    e.update(6)
    equal(e.count(50), 0, 'no chest before eighth gameplay update')
    equal(a.evaluations, 1, 'one deferred refresh for first player')
    equal(b.evaluations, 1, 'multiple copies coalesce only refresh work')
    e.update()
    equal(e.count(50), 2, 'eighth update pays each unboxing once')
    e.update(5)
    equal(e.count(50), 2, 'no duplicate inventory reward')
    scenarios = scenarios + 1
end
do
    local e = fresh(); e.finishAfter = 2
    e.player(303, { [e.items.TrafficUnboxing] = 1 })
    e.update(); equal(e.count(50), 0, 'animation is still running')
    e.level.index = 1; e.event(ModCallbacks.MC_POST_NEW_ROOM)
    e.update(); equal(e.count(50), 1, 'original pending animation survives room change')
    e.update(); equal(e.count(50), 1, 'early finish pays once')
    scenarios = scenarios + 1
end
do
    local e = fresh()
    local a = e.player(404, { [e.items.TrafficUnboxing] = 1, [e.items.TrafficHeat] = 1 })
    e.update(); local oldQueue = e.state.pendingHeatRefreshes
    e.level.stage = 2; e.event(ModCallbacks.MC_POST_NEW_LEVEL)
    assert(e.state.pendingHeatRefreshes ~= oldQueue, 'floor reset must replace the legacy queue table')
    e.update(8)
    equal(e.count(50), 0, 'floor reset cancels the old pickup visual and chest')
    equal(a.evaluations, 1, 'owned heat is requeued after the floor reset')
    equal(e.api.GetPersistentData().heatByPlayer['404'], 1, 'floor reset keeps permanent heat')
    scenarios = scenarios + 1
end
do
    local e = fresh()
    local choices = e.api.SpawnTrafficBossReward(3)
    for _, pickup in ipairs(choices) do e.event(ModCallbacks.MC_POST_PICKUP_UPDATE, pickup) end
    local p = e.player(505)
    e.queuePickup(p, choices[1]); e.flushPickup(p)
    e.update()
    assert(choices[2].removed, 'taking Exposure removes the other choice')
    equal(e.pool.draws, 1, 'Exposure uses the current room pool once')
    equal(next(e.state.choiceLinks), nil, 'resolved choice loses its visual link')
    e.update(3); equal(e.pool.draws, 1, 'choice reward is not reissued')
    scenarios = scenarios + 1
end
do
    local e = fresh(); local id = e.items.TrafficUnboxing
    Sprite = nil; e.api.QueuePickupVisual(id, Vector(10, 20), true)
    equal(e.count(50), 1, 'missing Sprite uses original immediate chest fallback')
    Sprite = function() error('constructor failed') end
    e.api.QueuePickupVisual(id, Vector(10, 20), true)
    equal(e.count(50), 1, 'constructor failure retains original no-grant behavior')
    e.api.ProcessPickupVisuals(); equal(e.count(50), 1, 'failed visual has no delayed grant')
    scenarios = scenarios + 1
end
do
    local e = fresh({ sentinel = { keep = 7 } })
    local p = e.player(606, { [e.items.TrafficHeat] = 1 })
    e.update(); local saved = e.saved()
    equal(saved.sentinel.keep, 7, 'heat save preserves unknown data')
    local continued = fresh(saved)
    local restored = continued.player(606)
    continued.event(ModCallbacks.MC_POST_GAME_STARTED, true)
    continued.update()
    equal(restored.evaluations, 1, 'fresh loader continue restores heat cache')
    equal(continued.api.GetPersistentData().heatByPlayer['606'], 1, 'saved layer restored')
    continued.api.AddHeat(restored); restored.gone = true
    continued.update()
    equal(restored.evaluations, 1, 'stale player is not refreshed')
    equal(next(continued.state.pendingHeatRefreshes), nil, 'stale pending work is removed')
    scenarios = scenarios + 1
end
print('batch4 traffic lifecycle: ' .. scenarios .. ' real-entry scenarios passed')
