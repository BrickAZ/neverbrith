-- Exercise shared-query consumption and installation-local runtime ownership.
local loader = dofile('tests/support/neverbirth_fixture.lua')
loader()
local first = Neverbirth
local a = first.ACEAntiCheatTestAPI
a.Runtime.pendingDamage = { { entity = {}, beforeHp = 2 } }
a.Runtime.roomOneHitKills = 2
local y = first.YinsCurseTestAPI
y.ResetForTest('boundary'); y.Runtime.pending.owner = { frame = 1 }
loader()
assert(Neverbirth ~= first)
assert(Neverbirth.ACEAntiCheatTestAPI.Runtime ~= a.Runtime)
assert(#Neverbirth.ACEAntiCheatTestAPI.Runtime.pendingDamage == 0)
assert(Neverbirth.ACEAntiCheatTestAPI.Runtime.roomOneHitKills == 0)
assert(Neverbirth.YinsCurseTestAPI.Runtime ~= y.Runtime)
assert(next(Neverbirth.YinsCurseTestAPI.Runtime.pending) == nil)
assert(#a.Runtime.pendingDamage == 1 and y.Runtime.pending.owner, 'independent instances')

local includeNative = include
local calls = 0
include = function(name)
    local value = includeNative(name)
    if name == 'scripts.runtime.world_queries' then
        local original = value.TryGame
        value.TryGame = function() calls = calls + 1; return original() end
    end
    return value
end
local query = include('scripts.features.ace_anti_cheat_system.queries')({}, {
    State = { ITEM_ID = 99 }, GetPlayers = function() return {} end,
    IsValidItemId = function(id) return id > 0 end,
})
local before = Game
for _, value in ipairs({false, 42, 'game'}) do
    Game = function() return value end
    assert(query.currentGame() == (value or nil), 'shared query return boundary')
end
Game = function() error('engine unavailable') end
assert(query.currentGame() == nil)
assert(calls == 4, 'actual shared-query consumer')
Game = setmetatable({}, { __call = function() error('must not invoke callable table') end })
assert(query.currentGame() == nil and calls == 4, 'ACE strict function guard')
Game, include = before, includeNative

-- ACE retains its distinct numeric count/fallback contract, unlike Yin or ring.
assert(query.itemCount({GetCollectibleNum=function() return 1.5 end}) == 1.5)
assert(query.itemCount({GetCollectibleNum=function() return '2' end,
    HasCollectible=function() return true end}) == 1)
assert(query.itemCount({GetCollectibleNum=function() error('no count') end,
    HasCollectible=function() return false end}) == 0)
print('batch15 boundaries: isolated installations, shared query failure/false/type boundaries, item count policy passed')
