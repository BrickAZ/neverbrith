local compose = dofile('scripts/runtime/legacy_save_schema.lua')
local Persistence = dofile('scripts/runtime/persistence.lua')
local declarations = {
    dofile('scripts/features/musicbox/save_schema.lua'),
    dofile('scripts/features/boxes/angelbox_save_schema.lua'),
    dofile('scripts/features/boxes/devilbox_save_schema.lua'),
    dofile('scripts/features/between_death_and_life/save_schema.lua'),
    dofile('scripts/systems/dice_set/save_schema.lua'),
    dofile('scripts/features/condom/save_schema.lua'),
    dofile('scripts/features/utility_knife/save_schema.lua'),
    dofile('scripts/features/crazy_coconut/save_schema.lua'),
    dofile('scripts/features/black_taisui/save_schema.lua'),
    dofile('scripts/features/certificate_of_neverbirth/save_schema.lua'),
    dofile('scripts/features/house_vs_elephant/save_schema.lua'),
    dofile('scripts/features/everchanging/save_schema.lua'),
    dofile('scripts/features/dog_food_series/save_schema.lua'),
    dofile('scripts/features/big_dog_bark/save_schema.lua'),
    dofile('scripts/features/yins_curse/save_schema.lua'),
    dofile('scripts/features/revive_my_love/save_schema.lua'),
    dofile('scripts/features/memory_disorder/save_schema.lua'),
    dofile('scripts/features/ring_of_the_seven_curses/save_schema.lua'),
    dofile('scripts/features/night_of_the_cowards/save_schema.lua'),
}
local expected = {
    musicboxDeathDebt = {debts={}},
    angelbox = {players={},pendingRewards={},enteredAngelFloors={},appliedChanceFloors={},forcedAngelFloors={}},
    devilbox = {players={},pendingRewards={},enteredDevilFloors={},appliedChanceFloors={},forcedDevilFloors={}},
    deathTrial = {spawnedByFloor={},preActivationBossClearedFloors={}},
    diceSet = {players={}},
    condom = {banned={}},
    utilityKnife = {players={}},
    crazyCoconut = {players={},playerCounts={},pending={},naturalDamage={}},
    blackTaisui = {players={}},
    certificateOfNeverbirth = {},
    houseVsElephant = {},
    everchanging = {},
    dogFoodSeries = {},
    bigDogBark = {},
    yinCurse = {},
    reviveMyLove = {},
    memoryDisorder = {},
    ringOfSevenCurses = {},
    nightOfTheCowards = {},
}
local function equal(a, b)
    if type(a) ~= type(b) then return false end
    if type(a) ~= 'table' then return a == b end
    for key, value in pairs(a) do if not equal(value, b[key]) then return false end end
    for key in pairs(b) do if a[key] == nil then return false end end
    return true
end
local function copy(value)
    if type(value) ~= 'table' then return value end
    local out = {}
    for k,v in pairs(value) do out[k] = copy(v) end
    return out
end
local initialize = compose(declarations)
local blank = {}
assert(initialize(blank) == nil and equal(blank, expected), 'first-save fields must retain the exact old shape')
local old = {unknownFuture={flag=false, version=99}, scalar=false}
for name, region in pairs(expected) do
    old[name] = copy(region)
    old[name].unknownField = false
    for field in pairs(region) do old[name][field] = {saved=9, nested={value=false}} end
end
local oldCopy = copy(old)
local oldRegions = {}
for name in pairs(expected) do oldRegions[name] = old[name] end
initialize(old)
assert(equal(old, oldCopy), 'valid old data and unknown fields must survive')
for name in pairs(expected) do assert(old[name] == oldRegions[name], 'existing region identity must survive') end
local malformed = {unknownFuture='keep'}
for name in pairs(expected) do malformed[name] = false end
initialize(malformed)
local repaired = copy(expected); repaired.unknownFuture = 'keep'
assert(equal(malformed, repaired), 'old scalar-region repair contract')
for name, region in pairs(expected) do
    for field in pairs(region) do malformed[name][field] = 'old invalid scalar' end
end
initialize(malformed)
assert(equal(malformed, repaired), 'old nested-table repair contract')

-- Composition is pure, ordered and captures declarations without retaining the caller array.
local order, calls = {}, 0
local first = {Name='first', Initialize=function(region)
    order[#order+1]='first'; calls=calls+1; region.flag=false
end}
local input = {first, {Name='second', Initialize=function(region)order[#order+1]='second';region.ready=true end}}
local initializePair = compose(input)
assert(calls == 0)
first.Name='changed';first.Initialize=function()error('mutated declaration must not replace initializer')end
input[2]=nil
local pair={}
initializePair(pair)
assert(table.concat(order, ',')=='first,second' and pair.first.flag==false and pair.second.ready)
assert(pair.changed==nil)
-- Invalid/missing/duplicate declarations fail during composition before any user data is read.
for _, bad in ipairs({
    false, {}, {legacyRegion={}}, {{Name=''}}, {{Name='one',Initialize=false}},
    {{Name='duplicate'}, {Name='duplicate'}},
    {[1]={Name='one'},[3]={Name='three'}},
    {{Name='one'}, extra=true},
}) do assert(not pcall(compose,bad), 'invalid owner declarations must fail') end

-- First Save, rather than gameplay/Section.Get, initializes all old regions once.
local loads, writes, encodes = 0,0,0
local encoded
local store = Persistence.Create({
    HasData=function()loads=loads+1;return false end,
    SaveData=function(_,payload)assert(payload=='encoded');writes=writes+1 end,
},{
    Json={encode=function(root)encodes=encodes+1;encoded=root;return 'encoded'end},
    Initialize=initialize,
})
store.Scope('notInitializedByLegacy')
store.Section('notRead')
assert(loads==0 and writes==0, 'wiring must remain lazy')
assert(store.Save() and loads==1 and writes==1 and encodes==1)
assert(equal(encoded, expected), 'first Save must not add lazy-only regions')
local root=store.GetRoot()
root.musicboxDeathDebt=false
assert(store.Save() and root.musicboxDeathDebt==false and writes==2 and loads==1,
    'owner first-load initialization must not become per-save normalization')

local reads, deniedWrites, logs = 0,0,0
local badStore = Persistence.Create({
    HasData=function()reads=reads+1;return false end,
    SaveData=function()deniedWrites=deniedWrites+1 end,
},{
    Json={encode=function()error('failed load must not encode')end},
    Initialize=compose({{Name='broken',Initialize=function(region)region.partial=true;error('broken owner')end}}),
    Log=function()logs=logs+1 end,
})
assert(not pcall(badStore.GetRoot))
assert(not pcall(badStore.GetRoot) and not badStore.Save())
assert(reads==1 and deniedWrites==0 and logs==1, 'owner failure must retain failed-load protection')
print('persistence owner schemas: 19 exact regions, valid/invalid old data, lazy first Save, declaration errors and failed-load protection passed')
