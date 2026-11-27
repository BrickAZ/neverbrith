local fixture = dofile('tests/support/traffic_fixture.lua')
local e = fixture()
local legacy = { pendingHeatRefreshes = {}, visuals = {}, choiceLinks = {} }
local views = dofile('scripts/features/little_leather_shoes/runtime_views.lua')(legacy)
local function denied(fn, label)
    local ok, message = pcall(fn)
    assert(not ok and tostring(message):find('outside owner', 1, true), label)
end
denied(function() return views.Heat.floorTraffic end, 'heat cannot read floor state')
denied(function() views.Rewards.pendingHeatRefreshes = {} end, 'rewards cannot reset heat')
denied(function() views.Presentation.trafficInventorySeen = {} end, 'render owner cannot write inventory')
local oldQueue = legacy.pendingHeatRefreshes
views.Heat.pendingHeatRefreshes = {}
assert(legacy.pendingHeatRefreshes ~= oldQueue, 'owner replaces the actual public queue')
local externalQueue = {}; legacy.pendingHeatRefreshes = externalQueue
assert(views.Heat.pendingHeatRefreshes == externalQueue, 'view follows public queue replacement')

local frame, saves, cacheRefreshes = 100, 0, 0
local stored = { unrelated = 'keep', heatByPlayer = {} }
local player = e.player(901)
function player:EvaluateItems() cacheRefreshes = cacheRefreshes + 1 end
local heat = dofile('scripts/features/traffic_heat.lua')({ AddCallback = function() end }, {
    Store = { Get = function() return stored end, Replace = function(value) stored = value end,
        Save = function() saves = saves + 1 end },
    RefreshRuntime = views.Heat, GetFrame = function() return frame end,
    GetPlayers = function() return { player } end, PlayerKey = function(value) return tostring(value.InitSeed) end,
    Call = function(value, name) return value[name](value), true end, Log = function() end,
})
heat.Add(player); heat.ProcessRefreshes()
assert(saves == 1 and cacheRefreshes == 0, 'same-frame work must wait')
assert(stored.unrelated == 'keep', 'heat preserves unknown section fields')
frame = frame + 1; heat.ProcessRefreshes()
assert(cacheRefreshes == 1 and next(legacy.pendingHeatRefreshes) == nil, 'clock query controls refresh')
stored = { heatByPlayer = { ['901'] = 3 } }
player.MaxFireDelay = 9; heat.Evaluate(nil, player, CacheFlag.CACHE_FIREDELAY)
assert(math.abs(player.MaxFireDelay - (30 / 4.5 - 1)) < 0.000001, 'cache reads replaced store, not old save')
heat.QueueOwnedRefreshes(); local queued = legacy.pendingHeatRefreshes
heat.ResetTransient(); frame = frame + 1; heat.ProcessRefreshes()
assert(legacy.pendingHeatRefreshes ~= queued and cacheRefreshes == 1, 'reset cancels stale refresh')
assert(stored.heatByPlayer['901'] == 3, 'transient reset keeps saved heat')

local finished = 0
local presentation = dofile('scripts/features/little_leather_shoes/presentation.lua')({
    Runtime = views.Presentation, Animations = { [1] = 'animation' },
    Rules = dofile('scripts/features/little_leather_shoes/rules.lua')({ Items = e.items }),
    CopyPosition = function(value) return Vector(value.X, value.Y) end,
    GetHudState = function() return true, 6 end,
})
presentation.ResetFloor()
presentation.QueuePickup(1, Vector(20, 30), true)
for _ = 1, 20 do presentation.Render() end
assert(legacy.visuals[1].frames == 0 and legacy.visuals[1].sprite.updates == 0, 'render never advances pickup lifetime')
for _ = 1, 7 do presentation.AdvancePickups(function() finished = finished + 1 end) end
assert(finished == 0, 'no early notification')
local ok = pcall(function() presentation.AdvancePickups(function() error('delivery failed') end) end)
assert(not ok and #legacy.visuals == 1, 'delivery failure preserves old removal ordering')
presentation.AdvancePickups(function(value)
    assert(value.chest and value.position.X == 20, 'notification retains request data')
    finished = finished + 1
end)
assert(finished == 1 and #legacy.visuals == 0, 'successful delivery is removed once')
assert(#e.spawned == 0 and cacheRefreshes == 1, 'presentation has no reward or heat side effects')
print('batch4 dependencies: restricted owners, live store/clock, render and failure boundaries passed')
