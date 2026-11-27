local loadFixture = dofile('tests/support/neverbirth_fixture.lua')
local function load(options)
    options = options or {}
    local onCreated = options.OnModCreated
    options.OnModCreated = function(...)
        -- This scenario needs two optional events absent from the generic fixture.
        ModCallbacks.MC_POST_NPC_DEATH = ModCallbacks.MC_POST_NPC_DEATH or 32001
        ModCallbacks.MC_PRE_PICKUP_RENDER = ModCallbacks.MC_PRE_PICKUP_RENDER or 32002
        if onCreated then onCreated(...) end
    end
    return loadFixture(options)
end
local parts = {'player_access','profiles','health','inventory','state','icons','pairs','identity','void_route','lifecycle'}
local imports, registrations = {}, {}
local e = load({
    OnInclude = function(name) imports[name] = (imports[name] or 0) + 1 end,
    AfterRegister = function(_, event, fn, param)
        if debug.getinfo(fn, 'S').source:find('/memory_disorder/', 1, true) then
            registrations[#registrations + 1] = {event, param}
        end
    end,
})
assert(imports['scripts.features.memory_disorder'] == 1)
for _, part in ipairs(parts) do assert(imports['scripts.features.memory_disorder.' .. part] == 1, part) end
local expected = {
    {ModCallbacks.MC_POST_UPDATE}, {ModCallbacks.MC_POST_NEW_ROOM},
    {ModCallbacks.MC_POST_GAME_STARTED}, {ModCallbacks.MC_PRE_GAME_EXIT},
    {ModCallbacks.MC_POST_PLAYER_INIT}, {ModCallbacks.MC_POST_NPC_DEATH},
    {ModCallbacks.MC_POST_ADD_COLLECTIBLE}, {ModCallbacks.MC_POST_PICKUP_UPDATE,100},
    {ModCallbacks.MC_PRE_PICKUP_RENDER,100}, {ModCallbacks.MC_PRE_PICKUP_COLLISION,100},
    {ModCallbacks.MC_PRE_PLAYER_RENDER},
}
assert(#registrations == #expected, 'callback count')
for i, row in ipairs(expected) do
    assert(registrations[i][1] == row[1] and registrations[i][2] == row[2], 'callback order/filter ' .. i)
end

local function failedLoad(options, marker)
    local previous, mod, rows = Neverbirth
    options.OnModCreated = function(m, c) mod, rows = m, c end
    local ok, err = pcall(load, options)
    assert(not ok and tostring(err):find(marker, 1, true), tostring(err))
    assert(Neverbirth == previous, 'previous global mod restored')
    assert(mod.MemoryDisorder == nil and mod.MemoryDisorderCharacterProfiles == nil, 'partial exports removed')
    for _, list in pairs(rows) do assert(#list == 0, 'partial callbacks removed') end
end
for _, part in ipairs(parts) do
    local marker = 'missing memory module ' .. part
    failedLoad({OnInclude = function(name)
        if name == 'scripts.features.memory_disorder.' .. part then error(marker) end
    end}, marker)
end
for failAt = 1, #expected do
    local count, marker = 0, 'memory callback failure ' .. failAt
    failedLoad({AfterRegister = function(_, _, fn)
        if debug.getinfo(fn, 'S').source:find('/memory_disorder/', 1, true) then
            count = count + 1
            if count == failAt then error(marker) end
        end
    end}, marker)
end
local old = Neverbirth.MemoryDisorder
old.Runtime.roomSerial = 123
load()
assert(Neverbirth.MemoryDisorder ~= old and Neverbirth.MemoryDisorder.Runtime ~= old.Runtime)
assert(Neverbirth.MemoryDisorder.Runtime.roomSerial == 0, 'fresh installation owns fresh runtime')
assert(Neverbirth.MemoryDisorder.MemoryDisorderCharacterProfiles == Neverbirth.MemoryDisorderCharacterProfiles)
print('memory_disorder_loading_test: 10 module failures, 11 callback rollback stages, ordering and fresh instances passed')
