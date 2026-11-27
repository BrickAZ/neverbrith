-- Run the same behavior contract against a frozen pre-refactor source or the current entry.
local root = arg and arg[1]
local originalDofile = dofile
if root then
    dofile = function(path)
        if not path:match('^tests[/\\]') and not path:match('^%a:') then path = root .. path end
        return originalDofile(path)
    end
end
local savedArg = arg; arg = { '--fixture' }
local fixture = dofile('tests/folk_horror_items_behavior_test.lua'); arg = savedArg
local function eq(a, b, why) assert(a == b, why .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b)) end
local function makePlayer(e, coins, seed, slot)
    return e.newPlayer({ coins = coins, initSeed = seed or 11, shootingInput = Vector(0, 0),
        collectibles = { [e.items.CoinFacedMask] = 1 },
        activeItems = { [slot or 0] = e.items.CoinSewnSword } })
end
local function effects(e)
    local found = {}
    for _, entity in ipairs(e.spawns) do
        if entity.GetData and entity:GetData().NeverbirthCoinSwordQi then found[#found + 1] = entity end
    end
    return found
end
local function fire(e, p, slot)
    e.runUse(e.items.CoinSewnSword, p, slot)
    p.testOptions.shootingInput = Vector(1, 0)
    e.runPrePlayer(p)
end

-- A mask remains armed after spending; the hit then uses the current wallet.
for _, startingCoins in ipairs({ 5, 11, 12 }) do
    local e = fixture(); local p = makePlayer(e, startingCoins); local enemy = e.newEnemy(200, 100)
    e.runNewRoom(); assert(p.nullCostumes[e.costumes.active])
    fire(e, p)
    local spent = math.min(startingCoins, 6)
    eq(p.coins, startingCoins - spent, 'sword payment')
    eq(#effects(e), spent + (spent == 6 and 1 or 0), 'sword volley')
    e.runPostUpdate(); assert(p.nullCostumes[e.costumes.active], 'spending must not preemptively remove armed mask')
    local enough = p.coins >= 5
    local result = e.runDamage(p, 1, 0, enemy)
    if enough then eq(result, false, 'mask blocks') else eq(result, nil, 'broken mask passes damage') end
    eq(p.coins, startingCoins - spent - (enough and 5 or 0), 'one mask payment')
    p.Luck = 0; e.runEvaluate(p, CacheFlag.CACHE_LUCK)
    eq(p.Luck, enough and 0 or -2, 'room penalty')
    p.coins = 20; e.runPostUpdate()
    eq(e.runDamage(p, 1, 0, enemy), nil, 'spent mask cannot reactivate in same room')
    eq(p.coins, 20, 'no second mask payment')
    e.setRoomIndex(2); e.runNewRoom()
    p.Luck = 0; e.runEvaluate(p, CacheFlag.CACHE_LUCK); eq(p.Luck, 0, 'next room clears penalty')
    eq(e.runDamage(p, 1, 0, enemy), false, 'next room rearms mask')
    eq(p.coins, 15, 'next room mask payment')
end

-- Holding does not reserve currency: losing all coins selects blood mode on release.
do
    local e = fixture(); local p = makePlayer(e, 6, 21, 1)
    e.runNewRoom(); e.runUse(e.items.CoinSewnSword, p, 1)
    eq(p.coins, 6, 'holding is free'); eq(#p.dischargedSlots, 0, 'holding keeps charge')
    p.coins = 0; p.testOptions.shootingInput = Vector(1, 0); e.runPrePlayer(p)
    eq(#effects(e), 1, 'one blood sword'); eq(effects(e)[1]:GetData().Mode, 'blood', 'release wallet')
    eq(#p.damageCalls, 1, 'one blood payment'); eq(p.damageCalls[1].amount, 1, 'original blood cost')
    eq(p.dischargedSlots[1], 1, 'release discharges original secondary slot')
    e.runPrePlayer(p); eq(#p.damageCalls, 1, 'release cannot settle twice')
end

-- Input read failures clear the bypass guard, preserve holding, and allow recovery.
do
    local e = fixture(); local p = makePlayer(e, 6)
    e.runUse(e.items.CoinSewnSword, p)
    local get = Input.GetActionValue
    Input.GetActionValue = function() error('input unavailable') end
    e.runPrePlayer(p); eq(e.mod.__coinSwordReadingInput, false, 'read guard cleared on failure')
    eq(p.coins, 6, 'failed input does not pay')
    eq(e.inputResult(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTRIGHT), 0, 'still holding')
    Input.GetActionValue = get
    p.testOptions.shootingInput = Vector(1, 0); e.runPrePlayer(p)
    eq(p.coins, 0, 'recovered release pays once')
    eq(e.inputResult(p, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTRIGHT), false, 'release pass blocked')
    e.runPrePlayer(p)
    eq(e.inputResult(p, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTRIGHT), nil, 'next update releases input')
end

-- Cancellation does not settle costs and does not release another player's hold.
do
    local e = fixture(); local a, b = makePlayer(e, 8, 31), makePlayer(e, 7, 32)
    e.runUse(e.items.CoinSewnSword, a); e.runUse(e.items.CoinSewnSword, b)
    e.runUse(e.items.CoinSewnSword, a)
    eq(a.coins, 8, 'cancel costs no coins'); eq(#a.dischargedSlots, 0, 'cancel keeps charge')
    eq(e.inputResult(a, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTRIGHT), nil, 'cancel releases owner')
    eq(e.inputResult(b, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTRIGHT), 0, 'other player still holds')
    b.activeItems[0] = 0; e.runPrePlayer(b)
    b.activeItems[0] = e.items.CoinSewnSword; b.testOptions.shootingInput = Vector(1, 0); e.runPrePlayer(b)
    eq(b.coins, 7, 'restoring replaced active does not resurrect stale hold'); eq(#effects(e), 0, 'no stale volley')
end

-- Mask removal, continue and new-run reset follow the existing room lifetime.
do
    local e = fixture(); local a, b = makePlayer(e, 5, 41), makePlayer(e, 5, 42)
    e.runNewRoom(); a.coins = 0; e.runDamage(a, 1, 0, e.newEnemy())
    assert(a.nullCostumes[e.costumes.broken] and b.nullCostumes[e.costumes.active])
    e.mod:ResetFolkHorrorItemState(true)
    assert(a.nullCostumes[e.costumes.broken], 'continue preserves current runtime')
    a.collectibles[e.items.CoinFacedMask] = nil; e.runPostUpdate()
    eq(a.nullCostumes[e.costumes.broken], nil, 'loss removes costume')
    a.Luck = 0; e.runEvaluate(a, CacheFlag.CACHE_LUCK); eq(a.Luck, 0, 'loss removes room penalty state')
    eq(e.runDamage(b, 1, 0, e.newEnemy()), false, 'other mask still protects')
    e.mod:ResetFolkHorrorItemState(false)
    a.collectibles[e.items.CoinFacedMask] = 1; a.coins = 5; e.runPostUpdate()
    eq(e.runDamage(a, 1, 0, e.newEnemy()), false, 'new run owns fresh state')
end
dofile = originalDofile
print('batch6 lifecycle: coin interactions, release-time costs, secondary slot, input failure, cancellation, players and room/run reset passed')
