-- Test real boundaries without installing the peer item or an unrelated shared system.
local savedArg = arg; arg = { '--fixture' }
local fixture = dofile('tests/folk_horror_items_behavior_test.lua'); arg = savedArg
fixture()
local rules = dofile('scripts/features/coin_sewn_sword/rules.lua')
local fake = { AvadaKedavra = { OwnsAttack = function() return false end } }
local wallet, operations, failSpawn = 6, {}, false
local player = { Position = Vector(0, 0), InitSeed = 7,
    DischargeActiveItem = function(_, slot) operations[#operations + 1] = 'charge:' .. slot end,
    TakeDamage = function(_, amount) operations[#operations + 1] = 'blood:' .. amount end }
local attack = dofile('scripts/features/coin_sewn_sword/attack.lua')(fake, {
    Rules = rules, Aiming = { GetBaseDirection = function() return Vector(1, 0) end },
    World = {
        GetPlayerCoins = function() return wallet end,
        AddPlayerCoins = function(_, amount) wallet = wallet + amount; operations[#operations + 1] = 'coin:' .. amount end,
        SpawnFolkEffect = function() operations[#operations + 1] = 'creep' end,
    },
    SpawnQi = function(_, multiplier, mode)
        operations[#operations + 1] = mode .. ':' .. multiplier
        if failSpawn then error('spawn failure') end
    end,
})
assert(attack.Fire(player, Vector(1, 0), 1))
assert(wallet == 0 and #operations == 9 and operations[1] == 'coin:-6' and operations[9] == 'charge:1')
operations = {}; wallet = 0
assert(attack.Fire(player, Vector(1, 0), 0))
assert(table.concat(operations, ',') == 'blood:1,creep,blood:4.0,charge:0', 'blood ordering')
operations = {}; wallet = 5; failSpawn = true
assert(not pcall(attack.Fire, player, Vector(1, 0), 0), 'spawn failure must propagate')
assert(wallet == 0 and #operations == 2, 'preserve pay-before-spawn failure behavior without falsely discharging')
operations = {}; wallet = 6; fake.AvadaKedavra.OwnsAttack = function() return true end
assert(attack.Fire(player, Vector(1, 0), 0) == false and wallet == 6 and #operations == 0, 'attack owner prevents settlement')

local room = 'one'
local createState = dofile('scripts/features/coin_faced_mask/state.lua')
local deps = { GetPlayerKey = function(p) return tostring(p.InitSeed) end, GetRoomKey = function() return room end }
local state, other = createState(deps), createState(deps)
state.Replace(player, true)
assert(other.Find(player) == nil, 'independent module instances cannot share players')
assert(state.Consume(player) and not state.Consume(player), 'protection consumed once')
state.Break(player, -2)
local old = state.Find(player)
state.Reset(); state.Replace(player, true)
assert(old.luckPenalty == -2 and state.Find(player) ~= old and state.Find(player).luckPenalty == 0, 'reset creates fresh state')
room = 'two'; assert(not state.Consume(player), 'stale room protection cannot block')

local added, removed, paths = 0, 0, 0
Isaac.GetCostumeIdByPath = function() paths = paths + 1; return paths end
player.AddNullCostume = function() added = added + 1 end
player.TryRemoveNullCostume = function() removed = removed + 1 end
local presentation = dofile('scripts/features/coin_faced_mask/presentation.lua')({}, { GetPlayerKey = deps.GetPlayerKey })
presentation.Apply(player, 'active')
local initialAdded, initialRemoved = added, removed
for _ = 1, 20 do presentation.Apply(player, 'active') end
assert(added == initialAdded and removed == initialRemoved and paths == 2, 'idle presentation does not churn costumes')
presentation.ClearPlayerCostume(player); presentation.ResetRuntime(); presentation.Apply(player, 'active')
assert(paths == 2 and added == initialAdded + 1, 'runtime reset preserves resource cache and reapplies costume')
assert(wallet == 6, 'presentation has no wallet dependency')
print('batch6 dependencies: settlement ordering/failure, attack ownership, isolated room state and costume cache passed')
