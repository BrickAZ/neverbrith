local loadMod = dofile('tests/support/neverbirth_fixture.lua')
loadMod()
local moon = Neverbirth.Moon
local player = { InitSeed = 101 }
local config = { GetCard = function(_, id) return id == 8123 and { Name = 'Mod card' } or nil end }
Isaac.GetItemConfig = function() return config end
EID = nil
assert(IsGoodGirlKnownCardSubtype(8123) and moon.IsKnownCardSubtype(8123))
for _, id in ipairs({ 0, -1, 10001, 1 }) do
    assert(not IsGoodGirlKnownCardSubtype(id) and not moon.IsKnownCardSubtype(id))
end
config.GetCard = function() return {} end
assert(not IsGoodGirlKnownCardSubtype(8123) and not moon.IsKnownCardSubtype(8123))
config.GetCard = function() error('config failure') end
assert(not IsGoodGirlKnownCardSubtype(8123) and not moon.IsKnownCardSubtype(8123))
config.GetCard = function(_, id) return id == 8123 and { HudAnim = 'card.anm2' } or nil end
EID = {}
assert(not IsGoodGirlKnownCardSubtype(8123) and not moon.IsKnownCardSubtype(8123))
EID.getObjectName = function() return 'Named mod card' end
assert(not IsGoodGirlKnownCardSubtype(8123) and moon.IsKnownCardSubtype(8123), 'Moon-only name fallback')
EID.getDescriptionObjByID = function() return { Name = '5.300.8123', Description = 'no description available' } end
assert(not IsGoodGirlKnownCardSubtype(8123) and not moon.IsKnownCardSubtype(8123))
EID.getDescriptionObjByID = function() return { Name = 'Mod card', Description = 'Known' } end
assert(IsGoodGirlKnownCardSubtype(8123) and moon.IsKnownCardSubtype(8123))
EID = nil
Card = { CARD_FOOL = 1, RUNE_HAGALAZ = 3, MOD_A = 8123, MOD_ALIAS = 8123 }
local a, b = CollectGoodGirlCardCandidates(), moon.CollectRewardCardCandidates()
assert(#a == 1 and a[1] == 8123 and #b == 1 and b[1] == 8123, 'valid mod enum deduplication')
local calls = {}
local pool = { GetCard = function(_, seed, allowPlaying, allowRunes, onlyRunes)
    calls[#calls+1] = { seed, allowPlaying, allowRunes, onlyRunes }
    return 10001
end }
Game = function() return { GetItemPool = function() return pool end } end
assert(GetGoodGirlRewardCardSubtype(player) == 8123)
assert(#calls == 32, 'Good Girl retains 16 dual rolls')
for i, call in ipairs(calls) do
    assert(call[1] == GetGoodGirlRewardSeed(player, math.floor((i-1)/2)))
    assert(call[2] == true and call[3] == (i % 2 == 1) and call[4] == false)
end
calls = {}
assert(moon.GetRewardCardSubtype(player) == 8123 and #calls == 16, 'Moon retains 8 dual rolls')
assert(moon.GetRewardSeed(player, 0) - GetGoodGirlRewardSeed(player, 0) == 16)
config.GetCard = function() return nil end
assert(GetGoodGirlRewardCardSubtype(player) == 1 and moon.GetRewardCardSubtype(player) == nil, 'distinct empty-candidate policies')
local replaced = 0
moon.GetPoolCardSubtype = function() replaced = replaced + 1; return 8123 end
assert(moon.GetRewardCardSubtype(player) == 8123 and replaced == 1, 'legacy public dispatch remains dynamic')
print('batch8 card policies: config/EID boundaries, mod candidates, seed/roll order, retries, distinct fallbacks and dynamic dispatch passed')
