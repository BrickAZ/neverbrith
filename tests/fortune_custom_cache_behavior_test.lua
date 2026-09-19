-- Reuse only the established main fixture, not its stale XML assertions or modules.
local f = assert(io.open('tests/condom_utility_knife_behavior_test.lua', 'r'))
local source = f:read('*a'); f:close()
local originalSource = source
source = assert(source:match('^(.-)local function test_xml_registers_requested_items_and_pools'))
source = source:gsub('return dofile%(name %.%. "%.lua"%)', 'return function() end')
source = source:gsub('dofile%("main.lua"%)', [[
    ModCallbacks.MC_EVALUATE_CUSTOM_CACHE = 1224
    ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED = 1095
    ModCallbacks.MC_POST_TRIGGER_TRINKET_ADDED = 1096
    ModCallbacks.MC_POST_TRIGGER_TRINKET_REMOVED = 1097
    ModCallbacks.MC_POST_PLAYER_INIT = 9
    CollectibleType.COLLECTIBLE_MOMS_EYE = 55
    CollectibleType.COLLECTIBLE_LUDOVICO_TECHNIQUE = 329
    TrinketType = {}
    dofile('main.lua')
]])
local env = assert(load(source .. '\nreturn loadNeverbirth()', '@fortune-main-fixture'))()
local mod, tag = env.mod, 'neverbrith_fortune_required_luck'
local function eq(a, b, label) assert(a == b, label .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
assert(type(mod.InvalidateFortuneLuck) == 'function', 'missing public InvalidateFortuneLuck API')
local function event(id, fn, ...)
    local found = false
    for _, r in ipairs(env.callbackRegistrations[id] or {}) do
        if r.fn == fn then r.fn(mod, ...); found = true end
    end
    assert(found, 'Fortune event not registered: ' .. tostring(id))
end
local evaluations, custom, sorts, depth = 0, 0, 0, 0
local originalSort = table.sort
table.sort = function(...) sorts = sorts + 1; return originalSort(...) end
local function player(base)
    local p = env.newPlayer({ luck = base or 0 })
    p.base, p.values, p.pending, p.flags = base or 0, {}, {}, false
    function p:Exists() return not self.removed end
    function p:GetData() self.data = self.data or {}; return self.data end
    function p:GetCustomCacheValue(t) return self.values[t] or 0 end
    function p:AddCacheFlags() self.flags = true end
    function p:AddCustomCacheTag(t, now) self.pending[t] = true; if now then self:EvaluateItems() end end
    function p:EvaluateItems()
        depth = depth + 1; eq(depth, 1, 'no recursive evaluation')
        evaluations = evaluations + 1
        -- 1.0.12a super() normal cache precedes custom cache.
        if self.flags then self.flags = false; self.Luck = self.base; mod:EvaluateFortuneRivallingHeavenGu(self, CacheFlag.CACHE_LUCK) end
        local pending = self.pending; self.pending = {}
        for t in pairs(pending) do
            local value = 0
            for _, r in ipairs(env.callbackRegistrations[1224] or {}) do
                if r.param == t then value = r.fn(mod, self, t, value) or value; custom = custom + 1 end
            end
            self.values[t] = value
        end
        depth = depth - 1
    end
    return p
end
local function update() mod:TrackFortuneRivallingHeavenGuLuckSources() end
local p = player(1)
p.collectibles[env.items.FortuneRivallingHeavenGu] = 1
p.collectibles[55] = 1
update(); eq(p.Luck, 5, 'first flush gets new custom result'); eq(custom, 1, 'one custom evaluation')
eq(mod:EvaluateFortuneCustomCache(p, tag, 20), 20, 'preserve higher incoming custom value')
eq(mod:EvaluateFortuneCustomCache(p, tag, 2), 5, 'raise lower incoming custom value')
eq(mod:EvaluateFortuneCustomCache(p, tag, nil), 5, 'missing incoming custom value defaults to zero')
local n, c, s = evaluations, custom, sorts
for i = 1, 100 do update() end
eq(evaluations, n, '100 unchanged updates no cache work'); eq(custom, c, '100 unchanged updates no cap work'); eq(sorts, s, '100 unchanged updates no sorting')
local logCount = #env.debugMessages
for _, method in ipairs({ 'AddCustomCacheTag', 'AddCacheFlags', 'EvaluateItems' }) do
    local native = p[method]
    p[method] = function() error('injected native failure: ' .. method) end
    mod:InvalidateFortuneLuck(p)
    local ok = pcall(update)
    local runtime = mod.FortuneRivallingHeavenGu.players[p:GetData()]
    eq(runtime.flushing, false, method .. ' failure releases flushing guard')
    eq(runtime.dirty, true, method .. ' failure preserves retry')
    eq(ok, true, method .. ' failure stays isolated')
    update()
    eq(#env.debugMessages, logCount + 1, 'native failures log only once per runtime owner')
    p[method] = native
    update()
    eq(runtime.flushing, false, method .. ' retry releases guard')
    eq(runtime.dirty, false, method .. ' successful retry settles')
    eq(p.Luck, 5, method .. ' retry restores correct luck')
end
p.collectibles[329] = 1; update(); eq(p.Luck, 10, 'condition dependency 5 to 10')
p.collectibles[329] = 0; update(); eq(p.Luck, 5, 'condition dependency 10 to 5')
p.base = 99; mod:InvalidateFortuneLuck(p); update(); eq(p.Luck, 99, 'never lower original luck')
p.base = 1; p.collectibles[env.items.FortuneRivallingHeavenGu] = 3; update(); eq(p.Luck, 5, 'copies do not stack')
p.collectibles[env.items.FortuneRivallingHeavenGu] = 0; update(); eq(p.Luck, 1, 'removal restores baseline')
p.collectibles[env.items.FortuneRivallingHeavenGu] = 1
local external, calls = 8, 0
local resolver = function(_, id, count) eq(id, 987, 'resolver id'); eq(count, 1, 'resolver count'); calls = calls + 1; return external end
eq(mod:RegisterLuckCapResolver(987, resolver), true, 'register resolver')
mod:RegisterLuckCapResolver(987, resolver)
mod:RegisterLuckCapResolver(987, function() error('isolated') end)
mod:RegisterLuckCap(987, -1)
p.collectibles[987] = 1; update(); eq(p.Luck, 8, 'registered cap'); eq(calls, 2, 'duplicates append')
external = 15; mod:InvalidateFortuneLuck(p); update(); eq(p.Luck, 15, 'external explicit invalidation')
external = -1; mod:InvalidateFortuneLuck(p); update(); eq(p.Luck, 5, 'negative and exceptions ignored')
mod:RegisterTrinketLuckCapResolver(987, function(_, _, multiplier) return multiplier * 7 end)
p.trinkets[987] = 1; update(); eq(p.Luck, 7, 'normal trinket')
p.trinkets[987] = 2; update(); eq(p.Luck, 14, 'gold or smelt multiplier snapshot')
p.trinkets[987] = 3; event(1096, mod.OnFortuneTrinketChanged, p, 987 + 32768, false); update(); eq(p.Luck, 21, 'unfiltered golden event')
p.trinkets[987] = 0; event(1097, mod.OnFortuneTrinketChanged, p, 987); update(); eq(p.Luck, 5, 'trinket removal')
local q = player(2); q.collectibles[env.items.FortuneRivallingHeavenGu] = 1; q.collectibles[987] = 1
event(ModCallbacks.MC_POST_PLAYER_INIT, mod.OnFortunePlayerInit, q)
eq(q.Luck, 2, 'player init only queues'); external = 12; update(); eq(q.Luck, 12, 'mature new player inventory')
mod:InvalidateFortuneLuck(); update(); eq(p.Luck, 12, 'all players invalidated'); eq(q.Luck, 12, 'coop independent')
for _, continued in ipairs({ false, true }) do
    external = continued and 17 or 16
    event(ModCallbacks.MC_POST_GAME_STARTED, mod.ResetFortuneLuckRuntime, continued)
    update(); eq(p.Luck, external, 'new or continue preserves registration')
end
external = 4; event(ModCallbacks.MC_POST_NEW_ROOM, mod.InvalidateFortuneLuck); update(); eq(p.Luck, 5, 'room rollback external refresh')
local invalidateOnce = true
mod:RegisterLuckCapResolver(987, function(owner)
    if invalidateOnce then invalidateOnce = false; mod:InvalidateFortuneLuck(owner) end
    return 6
end)
update(); n = custom; update(); eq(custom, n + 1, 'invalidate during flush survives next update')
n = custom; update(); eq(custom, n, 'settled flush not repeated')
q.removed = true; update()
eq(mod.FortuneRivallingHeavenGu.players[q:GetData()], nil, 'removed owner runtime is pruned')
assert(mod.FortuneRivallingHeavenGu.players[p:GetData()], 'live owner runtime is preserved')
event(ModCallbacks.MC_POST_ADD_COLLECTIBLE, mod.OnFortuneCollectibleAdded, 9000, 0, true, 0, 0, p)
n = custom; update(); eq(custom, n + 1, 'any collectible event covers multiplier dependencies')
event(ModCallbacks.MC_POST_TRIGGER_COLLECTIBLE_REMOVED, mod.OnFortuneCollectibleRemoved, p, 9000)
n = custom; update(); eq(custom, n + 1, 'collectible removal invalidation')
table.sort = originalSort
-- Execute the two original Fortune suites unchanged, bypassing only their
-- unrelated XML entry assertion and module includes. The new suite above owns
-- native-order/lifecycle proof; this adapter supplies the newly native value.
local legacy = assert(originalSource:match('(local function test_fortune_rivalling_heaven_gu_uses_complete_audit_registry.-)\ntest_xml_registers_requested_items_and_pools%(%)'))
local adapter = [[
local oldLoad = loadNeverbirth
loadNeverbirth = function(...)
    local e = oldLoad(...)
    local evaluate = e.runEvaluate
    e.runEvaluate = function(p, flag)
        local v = 0
        if e.mod:PlayerHasFortuneRivallingHeavenGu(p) then
            v = e.mod:EvaluateFortuneCustomCache(p, 'neverbrith_fortune_required_luck', 0)
        end
        p.GetCustomCacheValue = function() return v end
        evaluate(p, flag)
    end
    return e
end
]]
assert(load(source .. adapter .. legacy .. '\n' .. [[
test_fortune_rivalling_heaven_gu_uses_complete_audit_registry()
test_public_luck_cap_api_contracts()
]], '@fortune-original-contracts'))()
print('fortune custom cache behavior tests passed (native order, lifecycle, dependency, 100-update performance)')
