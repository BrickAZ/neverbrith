dofile('tests/support/neverbirth_fixture.lua')()
local data = { players = { untouched = 9 }, meatLumpCounts = {}, meatLumpLives = {}, unknown = 7 }
local saves, failSave = 0, false
local ledger
ledger = dofile('scripts/features/meat_lump/ledger.lua')({
    MeatLumpId = 1, IsValidItemId = function(id) return id == 1 end,
    GetSaveData = function() return data end,
    Store = { Save = function() saves = saves + 1; if failSave then error('save rejected') end end },
})
local p = { InitSeed = 77, copies = 2, GetCollectibleNum = function(self) return self.copies end }
ledger.TrackCopies(p); ledger.TrackCopies(p)
assert(ledger.GetCount(p) == 2 and saves == 1, 'same snapshot must be paid once')
assert(data.players.untouched == 9 and data.unknown == 7, 'ledger owns only its original fields')
p.copies = 0; ledger.TrackCopies(p); p.copies = 1; ledger.TrackCopies(p)
assert(ledger.GetCount(p) == 3, 'remove/reacquire adds only the new copy')
data = { meatLumpCounts = { ['77'] = 1 }, meatLumpLives = { ['77'] = 8 }, unknown = 10 }
assert(ledger.Consume(p) and ledger.GetCount(p) == 7, 'operations follow replacement save data')
failSave = true
assert(not pcall(ledger.Consume, p) and ledger.GetCount(p) == 6, 'save failure retains original mutate-before-save ordering')
failSave = false
local before = saves
local rendered = {}
local hud = dofile('scripts/features/meat_lump/presentation.lua')({
    GetLifeCount = ledger.GetCount, GetOrigin = function() return 132, 28 end,
    RenderText = function(_, text) rendered[#rendered + 1] = text end,
})
for _ = 1, 10 do hud.RenderLife(p, 2, 2) end
assert(saves == before and ledger.GetCount(p) == 6 and rendered[1] == 'P2 +6', 'HUD does not consume or save')

local runtime = { cleansedWavyCurrentSpeed = 0.03, cleansedWavyLingeringSpeed = 0.06,
    cleansedWavyCurrentTears = 0.75, cleansedWavyLingeringTears = 0.30,
    cleansedWavyUses = 2, cleansedWavyChargeDelay = 1, deathSavedFloorKey = 'spent', sentinel = 99 }
local cap = dofile('scripts/features/cleansed_wavy_cap.lua')({}, {
    World = { GetFolkRoomKey = function() return 'room2' end },
    GetRuntimeState = function() return runtime end,
})
p.MoveSpeed, p.MaxFireDelay = 1, 10
cap.ApplySpeed(p); cap.ApplyTears(p)
assert(math.abs(p.MoveSpeed - 0.91) < 0.000001 and math.abs(p.MaxFireDelay - 8.95) < 0.000001,
    'cap obtains its own fields through player interface')
cap.ResetPlayerFloor(p)
assert(runtime.cleansedWavyCurrentSpeed == 0 and runtime.cleansedWavyLingeringTears == 0)
assert(runtime.cleansedWavyUses == 2 and runtime.cleansedWavyChargeDelay == 1, 'floor reset preserves original charge policy')
assert(runtime.deathSavedFloorKey == 'spent' and runtime.sentinel == 99, 'cap cannot reset another owner')
runtime = { cleansedWavyCurrentSpeed = 0.12 }; p.MoveSpeed = 1; cap.ApplySpeed(p)
assert(math.abs(p.MoveSpeed - 0.88) < 0.000001, 'cap uses replacement runtime')
print('batch5 dependencies: live ledger, failure ordering, HUD isolation and player-owned cap state passed')
