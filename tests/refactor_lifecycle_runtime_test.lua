-- Direct feature factories use the production dependencies; each case owns its Mod and Store.
local baseline, originalDofile = arg and arg[1], dofile
if baseline then
    dofile = function(path)
        if not path:match('^tests[/\\]') and not path:match('^%a:') then
            local candidate = baseline .. '/' .. path
            local file = io.open(candidate, 'r')
            if file then file:close(); return originalDofile(candidate) end
        end
        return originalDofile(path)
    end
end
local loaded = dofile('tests/support/neverbirth_fixture.lua')()
local failures, passed = {}, 0
local function check(name, run)
    local ok, message = pcall(run)
    if ok then passed = passed + 1; print('PASS ' .. name)
    else failures[#failures + 1] = name .. ': ' .. tostring(message); print('FAIL ' .. failures[#failures]) end
end
local function equal(a, b, why) assert(a == b, why .. ': expected ' .. tostring(b) .. ', got ' .. tostring(a)) end
local function upvalue(fn, wanted)
    for i = 1, 100 do
        local name, value = debug.getupvalue(fn, i)
        if not name then break end
        if name == wanted then return value end
    end
    error('missing runtime owner ' .. wanted)
end
local function fresh(path, value)
    local callbacks, players, storeValue = {}, {}, value or {}
    local mod = {}
    function mod:AddCallback(id, fn, filter)
        callbacks[id] = callbacks[id] or {}; callbacks[id][#callbacks[id] + 1] = fn
    end
    function mod:AddPriorityCallback(id, priority, fn, filter) self:AddCallback(id, fn, filter) end
    local store = { Get = function() return storeValue end, Replace = function(v) storeValue = v end,
        Save = function() end }
    local deps = { Store = store, Items = loaded.itemIds, GetPlayers = function() return players end,
        GetCurrentRunSeed = function() return 'same-seed' end, IsValidItemId = function(id) return type(id) == 'number' and id > 0 end,
        Log = function() end, ItemId = loaded.itemIds.Needletick,
        GetHouseCarrier = function() return nil end, GetCertificateCarrier = function() return nil end }
    local api = dofile('scripts/features/' .. path .. '.lua')(mod, deps)
    local function event(id, ...)
        for _, fn in ipairs(callbacks[id] or {}) do fn(mod, ...) end
    end
    return { mod = mod, callbacks = callbacks, players = players, store = store, api = api, event = event }
end

check('ACE unload restores slowdown and releases pending NPCs exactly once', function()
    local e = fresh('ace_anti_cheat_system')
    local runtime = e.mod.ACEAntiCheatTestAPI.Runtime
    local restores = 0
    runtime.slowRoom = { SetBrokenWatchState = function(_, value) equal(value, 2, 'previous room state'); restores = restores + 1 end }
    runtime.previousBrokenWatchState, runtime.lockUntilMs, runtime.active = 2, 5000, true
    runtime.pendingDamage = { { entity = {} } }
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, {})
    equal(runtime.active, true, 'another Mod cannot dispose this instance')
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    equal(runtime.active, false, 'unload deactivates audit')
    equal(next(runtime.pendingDamage), nil, 'unload drops NPC queue')
    equal(runtime.slowRoom, nil, 'unload drops Room reference')
    equal(runtime.lockUntilMs, 0, 'unload cancels wall-clock deadline')
    equal(restores, 1, 'room slowdown restored once')
    e.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    e.event(ModCallbacks.MC_POST_UPDATE)
    equal(runtime.frame, 0, 'disposed callbacks cannot restart their clock')
end)

for _, spec in ipairs({
    { path = 'certificate_of_neverbirth', api = 'CertificateOfNeverbirthTestAPI', pending = 'pendingPickups' },
    { path = 'house_vs_elephant', api = 'HouseVsElephantTestAPI', pending = 'pending' },
}) do
    check(spec.path .. ' exit/unload releases native references without changing saved data', function()
        local e = fresh(spec.path)
        local api = e.mod[spec.api]
        local state = upvalue(api.Callbacks.Update, 'state')
        local saved = api.GetPersistentData()
        saved.sentinel = { preserve = 7 }
        state[spec.pending] = { pending = { player = {}, pickup = {} } }
        state.controlEntities, state.transition, state.frame = { [1] = { ['return'] = {} } }, { due = 30 }, 22
        e.event(ModCallbacks.MC_PRE_GAME_EXIT, true)
        equal(next(state[spec.pending]), nil, 'exit releases pending player/pickup references')
        equal(next(state.controlEntities), nil, 'exit releases portal references')
        equal(state.transition, nil, 'exit cancels virtual transition timer')
        equal(e.store.Get().sentinel.preserve, 7, 'saved fields survive cleanup')
        local frame = state.frame
        api.Callbacks.Update(e.mod)
        equal(state.frame, frame, 'menu update cannot recreate work')
        e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
        e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
        api.Callbacks.GameStarted(e.mod, false)
        equal(e.store.Get().sentinel.preserve, 7, 'disposed start cannot overwrite the Store')
    end)
end

check('certificate and House distinguish a same-seed new run from Continue', function()
    local cert = fresh('certificate_of_neverbirth', { runSeed = 'same-seed', nextToken = 9, stack = {} })
    cert.event(ModCallbacks.MC_POST_GAME_STARTED, true)
    equal(cert.store.Get().nextToken, 9, 'certificate Continue preserves token sequence')
    cert.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    equal(cert.store.Get().nextToken, 1, 'certificate same-seed new run resets token sequence')
    local house = fresh('house_vs_elephant')
    local saved = house.mod.HouseVsElephantTestAPI.GetPersistentData()
    saved.nextSequence, saved.nextSessionToken = 12, 4
    house.event(ModCallbacks.MC_POST_GAME_STARTED, true)
    equal(house.store.Get().nextSequence, 12, 'House Continue preserves encounter sequence')
    house.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    equal(house.store.Get().nextSequence, 1, 'House same-seed new run clears encounter sequence')
end)

check('Little Leather Shoes exit clears owned native queues and cancels delayed rewards', function()
    local e = fresh('little_leather_shoes/init')
    local state = e.mod.LittleLeatherShoesState
    state.splitWatch, state.pendingReturns = { { source = {} } }, { { snapshot = {} } }
    state.pendingHeatRefreshes = { owner = { player = {}, due = 2 } }
    state.visuals, state.choiceLinks, state.hudFonts, state.hudSprite = { { sprite = {}, chest = true } }, { [1] = { sprite = {} } }, { en = {} }, {}
    state.trafficPedestals, state.trafficAcquisitions = { [1] = {} }, { [1] = { player = {} } }
    e.event(ModCallbacks.MC_PRE_GAME_EXIT, true)
    for _, key in ipairs({ 'splitWatch', 'pendingReturns', 'pendingHeatRefreshes', 'visuals', 'choiceLinks', 'hudFonts', 'trafficPedestals', 'trafficAcquisitions' }) do
        equal(next(state[key]), nil, 'exit releases ' .. key)
    end
    equal(state.hudSprite, nil, 'exit releases HUD Sprite')
    equal(state.floorEnabled, false, 'exit closes floor logic')
    local frame = state.frame
    e.event(ModCallbacks.MC_POST_UPDATE)
    equal(state.frame, frame, 'exit blocks delayed reward timers')
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    e.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    equal(state.frame, frame, 'unloaded shoes cannot resume')
end)

check('Everchanging exit restores cosmetic ownership and Continue keeps saved selection', function()
    local e = fresh('everchanging', { runSeed = 'same-seed', players = { ['17'] = { knownCopies = 0, rollCount = 4 } } })
    local p = { InitSeed = 17, data = {}, removed = {} }
    function p:GetData() return self.data end
    function p:GetCollectibleNum() return 0 end
    function p:GetPlayerType() return 0 end
    function p:TryRemoveNullCostume(id) self.removed[#self.removed + 1] = id end
    e.players[1] = p
    local api = e.mod.EverchangingTestAPI
    local runtime = api.GetRuntime(p)
    runtime.appliedCostumeIds, runtime.appliedStyleId = { 17495 }, 'blue_banana_peel'
    e.event(ModCallbacks.MC_PRE_GAME_EXIT, true)
    equal(#p.removed, 1, 'exit removes only the applied costume')
    equal(e.store.Get().players['17'].rollCount, 4, 'exit preserves random history')
    e.event(ModCallbacks.MC_POST_GAME_STARTED, true)
    equal(e.store.Get().players['17'].rollCount, 4, 'Continue preserves random history')
    e.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    equal(e.store.Get().players['17'].rollCount, 0, 'same-seed new run resets random history')
    runtime = api.GetRuntime(p); runtime.appliedCostumeIds = { 17496 }
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, {})
    equal(#p.removed, 1, 'unrelated unload leaves costumes')
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    equal(#p.removed, 2, 'owned unload restores costume exactly once')
    api.Callbacks.PlayerUpdate(e.mod, p)
    equal(next(p.data), nil, 'disposed player update cannot recreate runtime')
end)

check('Boss Order unload invalidates encounter token and drops queued member references', function()
    local e = fresh('boss_order')
    local reward = e.mod.RewardBossOrderTarget
    local encounter = { status = 'active', runToken = upvalue(reward, 'bossOrderRunToken'),
        entityType = 19, variant = 0, subtype = 0, members = {} }
    local live = { entity = {} }
    local dead = { entity = {} }
    encounter.members = { dead, live }
    local npc = { Type = 19, Variant = 0, SubType = 0, Position = Vector(10, 20), data = {
        neverbirthBossOrderTarget = true, neverbirthBossOrderEncounter = encounter, neverbirthBossOrderMember = dead } }
    function npc:GetData() return self.data end
    e.mod:RewardBossOrderTarget(npc)
    equal(dead.entity, nil, 'death releases the dead member immediately')
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    e.event(ModCallbacks.MC_PRE_MOD_UNLOAD, e.mod)
    equal(live.entity, nil, 'unload releases remaining member references')
    assert(encounter.runToken ~= upvalue(reward, 'bossOrderRunToken'), 'unload invalidates previous run token')
end)

check('ACE Continue and same-seed new run both reset its temporary audit contract', function()
    local e = fresh('ace_anti_cheat_system')
    local runtime = e.mod.ACEAntiCheatTestAPI.Runtime
    for _, continued in ipairs({ true, false }) do
        runtime.active, runtime.lockUntilMs, runtime.frame = true, 5000, 31
        runtime.pendingDamage, runtime.roomOneHitKills = { { entity = {} } }, 2
        e.event(ModCallbacks.MC_POST_GAME_STARTED, continued)
        equal(runtime.active, false, 'audit is temporary for both start modes')
        equal(runtime.lockUntilMs, 0, 'start cancels audit deadline')
        equal(next(runtime.pendingDamage), nil, 'start drops NPC queue')
        equal(runtime.roomOneHitKills, 0, 'start resets temporary kill counter')
    end
end)

check('real gallery collisions lose player/pickup roots at exit', function()
    for _, spec in ipairs({
        { path = 'certificate_of_neverbirth', api = 'CertificateOfNeverbirthTestAPI', pending = 'pendingPickups' },
        { path = 'house_vs_elephant', api = 'HouseVsElephantTestAPI', pending = 'pending' },
    }) do
        local e = fresh(spec.path)
        local api, token = e.mod[spec.api], 'session:1'
        local value = api.GetPersistentData()
        local session = { token = token, selected = {}, selectedCount = 0, phase = 'active' }
        if spec.pending == 'pendingPickups' then session.selected = false; value.stack = { session }
        else value.session = session end
        local player = { InitSeed = 17, GetCollectibleNum = function() return 0 end }
        function player:ToPlayer() return self end
        local pickup = { Type = 5, Variant = 100, SubType = 12, InitSeed = 19 }
        function pickup:GetData() return { NeverbirthCertificateSessionToken = token,
            NeverbirthHouseSessionToken = token, NeverbirthHouseCandidateIndex = 1 } end
        api.Callbacks.PickupCollision(e.mod, pickup, player)
        local state = upvalue(api.Callbacks.Update, 'state')
        local _, pending = next(state[spec.pending])
        assert(pending and pending.player == player and pending.pickup == pickup, 'real collision must establish both roots')
        e.event(ModCallbacks.MC_PRE_GAME_EXIT, true)
        equal(next(state[spec.pending]), nil, 'exit drops the real collision queue')
    end
end)

check('traffic Continue restores permanent heat after item loss; new run clears the cache', function()
    local e = dofile('tests/support/traffic_fixture.lua')()
    local player = e.player(17, { [e.items.TrafficHeat] = 1 })
    e.update(2)
    equal(player:GetCollectibleNum(e.items.TrafficHeat), 0, 'heat pickup is already consumed')
    assert(player.MaxFireDelay < 9, 'heat has applied to the player cache')
    e.event(ModCallbacks.MC_PRE_GAME_EXIT, true)
    local refreshes = player.evaluations
    e.event(ModCallbacks.MC_POST_GAME_STARTED, true)
    e.update()
    equal(player.evaluations, refreshes + 1, 'Continue refreshes permanent heat without an inventory item')
    equal(e.api.GetPersistentData().heatByPlayer['17'], 1, 'Continue preserves earned stack')
    e.event(ModCallbacks.MC_POST_NEW_LEVEL)
    e.update()
    equal(player.evaluations, refreshes + 2, 'new floor restores the same permanent cache')
    e.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    equal(next(e.api.GetPersistentData().heatByPlayer), nil, 'same-seed new run clears permanent stacks')
    equal(player.MaxFireDelay, 9, 'new run removes stale cache bonus')
end)

check('private helper factories do not overwrite earlier feature instances', function()
    local first, second = fresh('needletick'), fresh('needletick')
    equal(first.mod.NeedletickPcallBoolean, nil, 'Needletick helper remains private')
    equal(first.mod.NeedletickTearVariant, nil, 'Needletick resource cache remains private')
    equal(first.mod.NeedletickLuckCap, 10, 'fortune audit bridge survives')
    equal(second.mod.GetNeedletickChance(10), 0.15, 'existing chance test bridge survives')
    local certA, certB = fresh('certificate_of_neverbirth'), fresh('certificate_of_neverbirth')
    local stateB = certB.mod.CertificateOfNeverbirthState
    stateB.pendingPickups.keep = { player = {} }
    certA.event(ModCallbacks.MC_PRE_MOD_UNLOAD, certA.mod)
    assert(stateB.pendingPickups.keep, 'old instance cleanup cannot erase a newer instance queue')
end)

dofile = originalDofile
if #failures > 0 then error(tostring(#failures) .. ' runtime lifecycle failures\n' .. table.concat(failures, '\n')) end
print('runtime lifecycle: ' .. passed .. ' cases passed')
