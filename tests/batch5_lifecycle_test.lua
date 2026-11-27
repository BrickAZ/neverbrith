-- Identical production-entry scenarios run against the saved baseline and candidate.
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
local function eq(a, b, label) assert(a == b, label .. ': ' .. tostring(a) .. ' ~= ' .. tostring(b)) end
local function near(a, b, label) assert(math.abs(a - b) < 0.000001, label) end
local function player(e, seed, black)
    local inventory = { [e.items.CleansedWavyCap] = 1 }
    if black then inventory[e.items.BlackTaisui] = 1 end
    local p = e.newPlayer({ initSeed = seed, collectibles = inventory, moveSpeed = 1, maxFireDelay = 10,
        activeItems = { [1] = e.items.CleansedWavyCap }, activeCharges = { [1] = 900, [0] = 321 } })
    if black then e.mod:SetBlackTaisuiParasiteValue(p, 8) end
    return p
end
do
    local e = fixture({ roomClear = false }); local p = player(e, 101, true)
    local calls, original = 0, p.SetActiveCharge
    function p:SetActiveCharge(value, slot) calls = calls + 1; original(self, value, slot) end
    e.runUse(e.items.CleansedWavyCap, p, 1)
    for _ = 1, 12 do e.runPostRender() end
    eq(calls, 0, 'render cannot process queued charge')
    for i = 1, 3 do e.runPostUpdate(); eq(calls, i, 'exactly three deferred corrections') end
    e.runPostUpdate(); eq(calls, 3, 'no fourth correction')
    eq(p.activeCharges[1], 800, 'secondary slot charge'); eq(p.activeCharges[0], 321, 'primary slot untouched')
    e.runUse(e.items.CleansedWavyCap, p, 1)
    e.runNewLevel(); e.runPostUpdate()
    eq(p.activeCharges[1], 700, 'original charge request and uses survive floor reset')
    local s = e.mod:GetCleansedWavyCapState(p)
    eq(s.cleansedWavyCurrentTears, 0, 'floor reset clears active room bonus')
end
do
    local e = fixture({ roomClear = false, roomIndex = 1 })
    local a, b = player(e, 201, true), player(e, 202, true)
    e.runUse(e.items.CleansedWavyCap, a, 1)
    e.setRoomIndex(2); e.runNewRoom()
    local sa, sb = e.mod:GetCleansedWavyCapState(a), e.mod:GetCleansedWavyCapState(b)
    near(sa.cleansedWavyLingeringSpeed, 0.06, 'room penalty conversion')
    near(sa.cleansedWavyLingeringTears, 0.30, 'room bonus conversion')
    eq(sb.cleansedWavyLingeringTears, 0, 'other player independent')
    e.setRoomClear(true); e.runPostUpdate(); e.runPostUpdate()
    near(sa.cleansedWavyLingeringTears, 0, 'clear decay occurs once')
    sa.sentinel = { keep = 7 }
    e.mod:ResetFolkHorrorItemState(true)
    assert(e.mod:GetCleansedWavyCapState(a) == sa, 'continue preserves existing runtime reference')
    e.runNewLevel(); eq(sa.sentinel.keep, 7, 'floor reset preserves unknown fields')
    e.mod:ResetFolkHorrorItemState(false)
    assert(e.mod:GetCleansedWavyCapState(a) ~= sa, 'new run replaces runtime reference')
end
do
    local e = fixture({ roomClear = false }); local p = player(e, 301, false)
    e.runUse(e.items.CleansedWavyCap, p, 1)
    e.runEvaluate(p, CacheFlag.CACHE_SPEED); e.runEvaluate(p, CacheFlag.CACHE_FIREDELAY)
    eq(p.MoveSpeed, 1, 'preserve existing Black Taisui ownership gate for speed')
    eq(p.MaxFireDelay, 10, 'preserve existing Black Taisui ownership gate for tears')
    e.runPostUpdate(); eq(p.activeCharges[1], 800, 'charge still updates without Black Taisui')
end
do
    local e = fixture(); local p = player(e, 401, true)
    e.mod:SetBlackTaisuiParasiteValue(p, 16)
    assert(e.mod:ApplyBlackTaisuiDeathSave(p, false))
    local s = e.mod:GetBlackTaisuiRuntimeState(p)
    for _ = 1, 20 do e.runPostRender() end
    eq(s.deathSaveFeedbackFrames, 90, 'render cannot advance feedback timer')
    e.runPostUpdate(); eq(s.deathSaveFeedbackFrames, 89, 'gameplay update owns feedback timer')
    assert(not e.mod:BlackTaisuiDeathSaveAvailable(p), 'ward spent on current floor')
    e.runNewLevel(); assert(e.mod:BlackTaisuiDeathSaveAvailable(p), 'next floor restores original ward')
end
dofile = originalDofile
print('batch5 lifecycle: charge slot/timing, multiplayer, state replacement, ownership gates and ward timing passed')
