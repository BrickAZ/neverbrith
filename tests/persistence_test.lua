local Persistence = dofile('scripts/runtime/persistence.lua')
local loads, saves, initializations, errors = 0, 0, 0, 0
local original = { musicboxDeathDebt = { debts = { a = { timer = 42 } } }, unknownFuture = { keep = true } }
local encodedRoot
local mod = {
    HasData = function() return true end,
    LoadData = function() loads = loads + 1; return 'legacy-save' end,
    SaveData = function(_, value) assert(value == 'encoded'); saves = saves + 1 end,
}
local json = {
    decode = function(value) assert(value == 'legacy-save'); return original end,
    encode = function(value) encodedRoot = value; return 'encoded' end,
}
local store = Persistence.Create(mod, {
    Json = json, Log = function() errors = errors + 1 end,
    Initialize = function(root) initializations = initializations + 1; root.legacyDefault = {} end,
})
local box = store.Section('musicboxDeathDebt', function(value) value.debts = value.debts or {} end)
assert(loads == 0, 'construction and section wiring must not load before the game context')
assert(box.Get().debts.a.timer == 42)
assert(store.GetRoot() == original and store.GetRoot() == original)
assert(loads == 1 and initializations == 1, 'single shared root and initialization')
original.musicboxDeathDebt = { debts = { b = { timer = 5 } } }
assert(box.Get() == original.musicboxDeathDebt and box.Get().debts.b.timer == 5, 'read replaced region, not stale captured table')
local replacement={debts={c={timer=8}}}
assert(box.Replace(replacement)==replacement and box.Get()==replacement)
assert(original.musicboxDeathDebt==replacement and original.unknownFuture.keep)
assert(box.Save() == true and saves == 1 and encodedRoot == original)
assert(encodedRoot.unknownFuture.keep == true, 'unmigrated and unknown fields survive')
json.encode = function() error('cannot encode') end
assert(store.Save() == false and saves == 1 and errors == 1, 'encoding failure must never write replacement data')
local blank = Persistence.Create({ HasData = function() return false end }, { Json = json })
assert(type(blank.Section('new').Get()) == 'table' and blank.Save() == false)
-- A failed load is not a new save. No consumer may publish or write a partial root.
for _, failure in ipairs({ 'has-data', 'read', 'decode', 'root-type', 'initialize', 'reentrant' }) do
    local writes, attempts, logs = 0, 0, 0
    local failed
    failed = Persistence.Create({
        HasData = function()
            attempts = attempts + 1
            if failure == 'has-data' then error('storage unavailable') end
            return true
        end,
        LoadData = function()
            if failure == 'read' then error('read failed') end
            return 'original bytes'
        end,
        SaveData = function() writes = writes + 1 end,
    }, {
        Json = {
            decode = function()
                if failure == 'decode' then error('bad JSON') end
                if failure == 'root-type' then return false end
                return { untouched = true }
            end,
            encode = function() error('failed load must never reach encoding') end,
        },
        Initialize = function(data)
            data.partial = true
            if failure == 'initialize' then error('schema failed') end
            if failure == 'reentrant' then failed.GetRoot() end
        end,
        Log = function() logs = logs + 1 end,
    })
    local region = failed.Section('musicboxDeathDebt')
    assert(not pcall(failed.GetRoot), failure .. ': failed root must not be returned')
    assert(not pcall(region.Get), failure .. ': no empty region fallback')
    assert(not pcall(region.Replace, {}), failure .. ': no replacement after failure')
    assert(failed.Save() == false and failed.Save() == false, failure .. ': Save must be contained')
    assert(writes == 0 and attempts == 1 and logs == 1,
        failure .. ': preserve original bytes, latch failed instance, log once')
end

local writeAttempts, writeLogs, allowWrite = 0, 0, false
local writable = Persistence.Create({
    HasData = function() return false end,
    SaveData = function()
        writeAttempts = writeAttempts + 1
        if not allowWrite then error('disk write failed') end
    end,
}, {
    Json = { encode = function() return 'encoded' end },
    Log = function() writeLogs = writeLogs + 1 end,
})
local retained = writable.GetRoot()
retained.existing = 42
assert(writable.Save() == false and writeAttempts == 1 and writeLogs == 1)
allowWrite = true
assert(writable.Save() == true and writable.GetRoot() == retained and retained.existing == 42,
    'a transient write failure keeps the valid root available for retry')
print('persistence tests passed: lazy root, legacy fields, failed loads, reentrancy, safe writes and retry')
