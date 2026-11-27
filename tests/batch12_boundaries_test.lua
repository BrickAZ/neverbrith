local build = dofile('tests/support/everchanging_fixture.lua')
local groups = 0
local function check(name, fn) fn(); groups = groups + 1; print('PASS ' .. name) end
local function eq(a, b) assert(a == b, tostring(a) .. ' ~= ' .. tostring(b)) end
check('live Store replacement, seed coercion, normalization and Save cadence', function()
    local e = build(); local p = e.player(17); local api = e.api
    e.saved = { runSeed = 12, players = { ['17'] = { knownCopies = '2.8', rollCount = '-3', styleId = 'unknown' } } }
    local state = api.GetPlayerState(p); eq(state.knownCopies, 2); eq(state.rollCount, 0); eq(state.styleId, nil); eq(#e.saves, 0)
    p.count = 2; api.SyncPlayer(p); eq(#p.draws, 1); eq(#e.saves, 1); eq(state.rollCount, 1)
    p.count = 4; api.SyncPlayer(p); eq(#p.draws, 3); eq(#e.saves, 2)
    p.count = 1; api.SyncPlayer(p); eq(#p.draws, 3); eq(#e.saves, 3)
    p.count = 0; api.SyncPlayer(p); eq(state.styleId, nil); eq(state.rollCount, 3); eq(#e.saves, 4)
    api.SyncPlayer(p); eq(#e.saves, 4)
    e.saved = { runSeed = '12', players = {} }; assert(api.GetPlayerState(p) ~= state)
    e.seed = '13'; api.GetPlayerState(p); eq(e.saved.runSeed, '13'); eq(#e.saves, 5)
end)
check('RNG failure and retry preserve copies and successful roll count', function()
    local e = build(); local p = e.player(1); p.count = 2; p.failRng = true
    e.api.SyncPlayer(p); local s = e.api.GetPlayerState(p)
    eq(#p.draws, 2); eq(s.knownCopies, 2); eq(s.rollCount, 0); eq(s.styleId, nil)
    p.failRng = false; e.api.SyncPlayer(p); eq(#p.draws, 3); eq(s.rollCount, 1); eq(#e.saves, 2)
end)
check('failed resource cache and one diagnostic survive repeats and reset on unload', function()
    local e = build(); local style = e.api.StyleRegistry[1]; local path = style.resources.head.costume
    e.lookup = function() return -1 end
    eq(e.api.ResolveStyleResources(style), nil); eq(e.api.ResolveStyleResources(style), nil)
    eq(e.lookups[path], 1); eq(#e.logs, 3)
    e.event('MC_PRE_MOD_UNLOAD', e.mod); e.lookup = function() return 321 end
    eq(e.api.ResolveStyleResources(style).costumes[1].id, 321); eq(e.lookups[path], 2)
end)
check('deferred failure cache preserves reentrant resolution', function()
    local e = build(); local style = e.api.StyleRegistry[1]; local nested, inside
    e.lookup = function()
        if not inside then inside = true; nested = e.api.ResolveStyleResources(style); return 456 end
        return 123
    end
    eq(e.api.ResolveStyleResources(style).costumes[1].id, 456); eq(nested.costumes[1].id, 123)
    eq(e.api.ResolveStyleResources(style).costumes[1].id, 456)
end)
check('lookup reentering unload publishes into the replacement cache', function()
    for _, result in ipairs({456, -1}) do
        local e = build(); local style = e.api.StyleRegistry[1]; local path = style.resources.head.costume
        e.lookup = function() e.event('MC_PRE_MOD_UNLOAD', e.mod); return result end
        local first = e.api.ResolveStyleResources(style)
        e.lookup = function() return 789 end
        local second = e.api.ResolveStyleResources(style)
        eq(e.lookups[path], 1)
        if result > 0 then eq(first.costumes[1].id, result); eq(second.costumes[1].id, result)
        else eq(first, nil); eq(second, nil) end
    end
end)
check('pair rollback clears both halves and leaves third player unchanged', function()
    local e = build(); local j, s, third = e.player(1,19), e.player(2,20), e.player(3)
    j.twin, s.twin = s, j; j.count, third.count = 1, 1
    assert(e.api.ForceStyle(third, 'blue_banana_peel')); local thirdData = third.data.neverbirth_everchanging_runtime
    local style = e.api.StyleRegistry.byId.tantan_daodao_twins
    s.failCostume = e.api.ResolveStyleResources(style, 'esau').costumes[2].id
    eq(e.api.ForceStyle(j, style.id), false); eq(next(j.costumes), nil); eq(next(s.costumes), nil)
    eq(third.data.neverbirth_everchanging_runtime, thirdData); eq(thirdData.appliedStyleId, 'blue_banana_peel')
    s.failCostume = nil; assert(e.api.ForceStyle(j, style.id)); eq(#j.draws, 0); eq(#s.draws, 0)
    eq(e.api.GetRuntime(s).appliedRole, 'esau')
end)
check('full ANM2 playback, drift repair and third-party ownership', function()
    local e = build(); local p = e.player(1); p.count = 1; e.fullStyle()
    local sprite = p:GetSprite(); assert(e.api.ForceStyle(p, 'test_full'))
    eq(sprite.filename, 'gfx/test_full.anm2'); eq(sprite.frame, 7); eq(sprite.overlayFrame, 2)
    sprite.filename = 'gfx/001.000_player.anm2'; e.api.SyncPlayer(p); eq(sprite.filename, 'gfx/test_full.anm2')
    eq(#p.draws, 0); eq(#e.saves, 1)
    sprite.filename = 'gfx/other_mod.anm2'; p.count = 0; e.api.SyncPlayer(p); eq(sprite.filename, 'gfx/other_mod.anm2')
end)
check('exit, Continue, same-seed new run and disposed instance', function()
    local e = build(); local p = e.player(1); p.count = 1; e.api.SyncPlayer(p)
    local selected = e.api.GetPlayerState(p).styleId; local rolls = #p.draws
    e.event('MC_PRE_GAME_EXIT', true); eq(next(p.costumes), nil); eq(next(p.data), nil)
    eq(e.api.SyncPlayer(p), false); e.event('MC_POST_GAME_STARTED', true)
    eq(e.api.GetPlayerState(p).styleId, selected); eq(#p.draws, rolls); assert(next(p.costumes))
    e.event('MC_POST_GAME_STARTED', false); eq(e.api.GetPlayerState(p).rollCount, 1); eq(#p.draws, rolls + 1)
    e.event('MC_PRE_MOD_UNLOAD', {}); assert(next(p.costumes))
    e.event('MC_PRE_MOD_UNLOAD', e.mod); local calls = #e.calls
    e.event('MC_PRE_MOD_UNLOAD', e.mod); e.event('MC_POST_GAME_STARTED', true); e.api.SyncPlayer(p)
    eq(#e.calls, calls); eq(e.api.GetRuntime(p), nil); eq(next(p.data), nil)
end)
check('ANM2 load failure and removal failure keep original failure boundaries', function()
    local e = build(); local p = e.player(1); p.count = 1; e.fullStyle(); p.failLoad = true
    eq(e.api.ForceStyle(p, 'test_full'), false); eq(e.api.GetRuntime(p).failedStyleId, 'test_full')
    p.failLoad = false; assert(e.api.ForceStyle(p, 'blue_banana_peel')); p.failRemove = true
    e.event('MC_PRE_GAME_EXIT', false); eq(next(p.data), nil)
    -- Native removal failure was swallowed before extraction; ownership is still released.
    assert(next(p.costumes))
end)
print('batch12 boundaries: ' .. groups .. ' groups passed')
