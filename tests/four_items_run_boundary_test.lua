-- Real owners installed through main.lua; model NEW_ROOM before GAME_STARTED.
local fixture = dofile('tests/support/traffic_fixture.lua')
local failures, checks = {}, 0
local function check(name, fn)
    local ok, err = pcall(fn)
    checks = checks + 1
    if ok then print('PASS ' .. name) else failures[#failures + 1] = name .. ': ' .. tostring(err) end
end
local function setupRoom(e)
    e.player(202)
    local transitions = {}
    local game = Game()
    function game:StartRoomTransition(index) transitions[#transitions + 1] = index; return true end
    return transitions
end
local function certificateSession(api)
    local data = api.GetPersistentData()
    local session = api.NewSession('202', 42, 0, Vector(123, 234), {})
    session.phase = 'active'
    data.stack, data.nextToken, data.extension = { session }, 19, 'keep-certificate'
    return data, session
end
check('certificate defers frame-zero room before clearing same-seed new run', function()
    local e = fixture(); local transitions = setupRoom(e)
    local api = Neverbirth.CertificateOfNeverbirthTestAPI
    local data = certificateSession(api)
    api.Callbacks.NewRoom(Neverbirth)
    assert(#transitions == 0, 'early NEW_ROOM must not request the old origin')
    api.Callbacks.GameStarted(Neverbirth, false)
    assert(#transitions == 0 and #data.stack == 0 and data.nextToken == 1)
    assert(data.extension == 'keep-certificate')
    api.Callbacks.PreGameExit(Neverbirth)
    local saved = e.saved()
    assert(#saved.certificateOfNeverbirth.stack == 0)
end)
check('certificate Continue retains its session and existing return behavior', function()
    local e = fixture(); local transitions = setupRoom(e)
    local api = Neverbirth.CertificateOfNeverbirthTestAPI
    local data, session = certificateSession(api)
    api.Callbacks.NewRoom(Neverbirth) -- frame-zero Continue is also resolved by GAME_STARTED
    api.Callbacks.GameStarted(Neverbirth, true)
    assert(#transitions == 1 and transitions[1] == 42)
    assert(data.stack[1] == session and data.nextToken == 19 and session.phase == 'returning')
end)
local function houseHistory(api)
    local data = api.GetPersistentData()
    local room = { stage = 1, stageType = 0, dimension = 0, safeGridIndex = 42 }
    local pickup = { Type = 5, Variant = 100, SubType = 201, InitSeed = 777, GetData = function() return {} end }
    assert(api.RecordEncounter(data, room, pickup))
    data.extension, data.nextSessionToken = 'keep-house', 17
    return data, room, pickup, data.encounters[1].encounterKey
end
check('house clears old history dedup counters and session before room work', function()
    local e = fixture(); local transitions = setupRoom(e)
    local api = Neverbirth.HouseVsElephantTestAPI
    local data, room, pickup, key = houseHistory(api)
    data.session = { phase = 'active', token = 'old', initiatorKey = '202', originRoomIndex = 42,
        originSafeGridIndex = 42, originDimension = 0, candidates = {}, spawnedPedestals = {} }
    api.Callbacks.NewRoom(Neverbirth)
    assert(#transitions == 0, 'early NEW_ROOM must not process old house session')
    api.Callbacks.GameStarted(Neverbirth, false)
    data = api.GetPersistentData()
    assert(#transitions == 0 and data.session == nil)
    assert(#data.encounters == 0 and next(data.seenKeys) == nil)
    assert(data.nextSequence == 1 and data.nextSessionToken == 1 and data.extension == 'keep-house')
    assert(api.RecordEncounter(data, room, pickup), 'same spawn key in a new run must be accepted')
    assert(data.seenKeys[key] and #data.encounters == 1)
end)
check('house Continue preserves encounter history and counters', function()
    local e = fixture(); setupRoom(e)
    local api = Neverbirth.HouseVsElephantTestAPI
    local data, room, pickup, key = houseHistory(api)
    api.Callbacks.GameStarted(Neverbirth, true)
    assert(data.seenKeys[key] and #data.encounters == 1 and data.nextSequence == 2 and data.nextSessionToken == 17)
    assert(not api.RecordEncounter(data, room, pickup))
end)
check('certificate old save reload distinguishes new game from Continue', function()
    local e = fixture(); setupRoom(e)
    local api = Neverbirth.CertificateOfNeverbirthTestAPI
    certificateSession(api); api.Callbacks.PreGameExit(Neverbirth)
    local saved = e.saved()
    for _, continued in ipairs({ false, true }) do
        local restored = fixture({ Saved = saved }); local transitions = setupRoom(restored)
        api = Neverbirth.CertificateOfNeverbirthTestAPI
        api.Callbacks.NewRoom(Neverbirth)
        api.Callbacks.GameStarted(Neverbirth, continued)
        local data = api.GetPersistentData()
        assert(data.extension == 'keep-certificate')
        if continued then
            assert(#transitions == 1 and transitions[1] == 42 and #data.stack == 1 and data.nextToken == 19)
        else
            assert(#transitions == 0 and #data.stack == 0 and data.nextToken == 1)
        end
    end
end)
check('house old save reload distinguishes new game from Continue', function()
    local e = fixture(); setupRoom(e)
    local api = Neverbirth.HouseVsElephantTestAPI
    local _, room, pickup, key = houseHistory(api)
    api.Callbacks.PreGameExit(Neverbirth)
    local saved = e.saved()
    for _, continued in ipairs({ false, true }) do
        local restored = fixture({ Saved = saved }); setupRoom(restored)
        api = Neverbirth.HouseVsElephantTestAPI
        api.Callbacks.NewRoom(Neverbirth)
        api.Callbacks.GameStarted(Neverbirth, continued)
        local data = api.GetPersistentData()
        assert(data.extension == 'keep-house')
        if continued then
            assert(data.seenKeys[key] and #data.encounters == 1 and data.nextSequence == 2 and data.nextSessionToken == 17)
            assert(not api.RecordEncounter(data, room, pickup))
        else
            assert(next(data.seenKeys) == nil and #data.encounters == 0 and data.nextSequence == 1 and data.nextSessionToken == 1)
        end
    end
end)
local function heatSave()
    return { extension = 'keep-root', littleLeatherShoes = {
        extension = 'keep-heat', heatByPlayer = { ['101'] = 2, ['202'] = 3, absent = 7 } } }
end
check('heat clears all previous players and refreshes their initial caches', function()
    local e = fixture({ Saved = heatSave() })
    local a, b, c = e.player(101), e.player(202), e.player(303)
    a:EvaluateItems(); b:EvaluateItems()
    assert(a.MaxFireDelay < 9 and b.MaxFireDelay < 9)
    e.event(ModCallbacks.MC_POST_GAME_STARTED, false)
    assert(next(e.api.GetPersistentData().heatByPlayer) == nil)
    assert(a.MaxFireDelay == 9 and b.MaxFireDelay == 9 and c.evaluations == 0)
    local count = a.evaluations + b.evaluations
    e.update(3)
    assert(a.evaluations + b.evaluations == count, 'no stale deferred player refresh')
    local saved = e.saved()
    assert(saved.extension == 'keep-root' and saved.littleLeatherShoes.extension == 'keep-heat')
    assert(next(saved.littleLeatherShoes.heatByPlayer) == nil)
    e.api.AddHeat(a); e.update()
    assert(e.api.GetPersistentData().heatByPlayer['101'] == 1)
end)
check('heat Continue restores saved stacks without multiplying them', function()
    local e = fixture({ Saved = heatSave() }); local a = e.player(101)
    e.event(ModCallbacks.MC_POST_GAME_STARTED, true); e.update(3)
    assert(e.api.GetPersistentData().heatByPlayer['101'] == 2 and a.MaxFireDelay == 6.5)
    assert(a.evaluations == 1)
    e.event(ModCallbacks.MC_POST_GAME_STARTED, true); e.update(3)
    assert(e.api.GetPersistentData().heatByPlayer['101'] == 2 and a.MaxFireDelay == 6.5)
end)
check('heat same-instance new player cannot inherit pending refresh or growth', function()
    local e = fixture(); local old = e.player(101)
    e.api.AddHeat(old); e.api.AddHeat(old) -- pending refresh still references the old entity
    e.players[1] = nil
    local fresh = e.player(101)
    fresh:EvaluateItems() -- engine initial cache before GAME_STARTED
    e.event(ModCallbacks.MC_POST_GAME_STARTED, false); e.update(3)
    assert(fresh.MaxFireDelay == 9 and old.evaluations == 0)
    assert(next(e.api.GetPersistentData().heatByPlayer) == nil)
end)
if #failures > 0 then error(table.concat(failures, '\n')) end
print('four item persistent run boundary cases passed: ' .. checks)
