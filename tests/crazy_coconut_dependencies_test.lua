-- A collectible collision must work with only this feature's declared dependencies.
function include(name) return dofile(name:gsub('%.', '/') .. '.lua') end
EntityType = { ENTITY_PICKUP = 5 }
PickupVariant = { PICKUP_COLLECTIBLE = 100 }
local root, mod = nil, {}
local player = { InitSeed = 10, Damage = 3.5 }
function player:GetCollectibleNum(id) return id == 1 and 1 or 0 end
function player:ToPlayer() return self end
dofile('scripts/features/crazy_coconut.lua')(mod, {
    Store = { Get = function() return root end, Replace = function(value) root = value end, Save = function() end },
    Items = { CrazyCoconut = 1 }, GetPlayers = function() return { player } end,
    GetCurrentRunSeed = function() return 'test-run' end,
    IsValidItemId = function(id) return type(id) == 'number' and id > 0 end, Log = function() end,
})
assert(mod.CondomEntityPickup == nil and mod.CondomCollectibleVariant == nil)
local pickup = { Type = 5, Variant = 100, SubType = 2, InitSeed = 20 }
assert(mod:HandleCrazyCoconutCollectiblePickup(pickup, player) == nil)
assert(root and root.pending['10'] and #root.pending['10'] == 1,
    'standalone coconut must queue a valid collectible collision without Condom exports')
local candidate = root.pending['10'][1]
assert(candidate.itemId == 2 and candidate.coconutCount == 1 and candidate.beforeDamage == 3.5)
assert(candidate.sourceKey == '10:20' and mod.CrazyCoconutPickupSources['10:20'] == pickup)
mod:HandleCrazyCoconutCollectiblePickup(pickup, player)
assert(#root.pending['10'] == 1, 'same source remains deduplicated')
print('crazy coconut declared dependencies: valid collision, original candidate values and deduplication passed')
