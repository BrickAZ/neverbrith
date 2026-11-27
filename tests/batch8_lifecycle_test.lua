local savedArg = arg
arg = { '--fixture' }
local goodGirl = dofile('tests/good_girl_of_babylon_behavior_test.lua')
local moon = dofile('tests/moon_is_beautiful_behavior_test.lua')
arg = savedArg
local env = goodGirl()
local first = env.newPlayer({ initSeed = 101, rngSequence = { 99, 0, 0 } })
local second = env.newPlayer({ initSeed = 202 })
env.runDamage(first, 1, DamageFlag.DAMAGE_RED_HEARTS)
local state = GetGoodGirlState(first)
assert(state.echoFrames == 150 and state.broken and not GetGoodGirlState(second).broken)
env.runPostUpdate(149)
assert(state.echoFrames == 1 and state.echoEffect, 'echo remains until last tick')
env.runPostUpdate()
assert(state.echoFrames == 0 and not state.echoEffect, 'echo expiry removes its effect')
env.setRoomClear(true)
env.runPostUpdate()
assert(state.rewarded and first.rngIndex == 0, 'ineligible clear consumes settlement without random roll')
first.hearts = 6
env.runPostUpdate(3)
assert(first.rngIndex == 0, 'settlement cannot be retried in the same room')
env.runNewRoom()
env.runPostUpdate()
assert(first.rngIndex == 1 and GetGoodGirlState(first).rewarded, 'eligible failed roll consumes settlement once')
env.runPostUpdate(3)
assert(first.rngIndex == 1)
env.setRoomClear(false)
env.runDamage(first, 1, DamageFlag.DAMAGE_RED_HEARTS)
state = GetGoodGirlState(first)
Neverbirth:ResetFolkHorrorItemState(true)
assert(GetGoodGirlState(first) == state and state.broken, 'continue preserves Good Girl runtime contract')
Neverbirth:ResetFolkHorrorItemState(false)
assert(next(Neverbirth.GoodGirl.states) == nil and next(Neverbirth.GoodGirl.costumeStates) == nil)

env = moon()
first = env.newPlayer({ initSeed = 101, firing = false })
second = env.newPlayer({ initSeed = 202, firing = true })
local enemy = env.newEnemy()
env.runPostUpdate(59)
state = Neverbirth.Moon.GetRoomState()
local frame = state.frame
for _ = 1, 5 do env.runRender() end
assert(state.frame == frame and not state.triggered, 'render never advances silence')
env.runPostUpdate()
assert(state.triggered and state.bonusPlayers[tostring(first.InitSeed)] == true)
assert(state.bonusPlayers[tostring(second.InitSeed)] ~= true, 'only triggering player gets room bonus')
local rewards, rolls = 0, 0
first.GetCollectibleRNG = function() return { RandomInt = function() rolls=rolls+1; return 0 end } end
Neverbirth.Moon.SpawnReward = function() rewards = rewards + 1 end
env.runDeath(enemy)
env.runDeath(enemy)
assert(rewards == 1 and rolls == 1, 'NPC_DEATH and ENTITY_KILL share one reward claim')
env.runNewRoom()
state = Neverbirth.Moon.GetRoomState()
first.firing = false
env.runPostUpdate(59)
first.firing = true
env.runPostUpdate()
assert(state.playerStates[tostring(first.InitSeed)].silenceFrames == 0)
first.firing = false
env.runPostUpdate(60)
assert(state.triggered, 'sixtieth silent update at frame 119 remains eligible')
env.runNewLevel()
assert(not Neverbirth.Moon.GetRoomState().triggered)
Neverbirth.Moon.waveDamageDepth = 2
Neverbirth.Moon.bossBonusDepth = 3
env.runGameStarted()
assert(Neverbirth.Moon.waveDamageDepth == 0 and Neverbirth.Moon.bossBonusDepth == 0)
print('batch8 lifecycle: echo boundary, one clear claim, continue/new-run, multiplayer silence, render isolation, double death, firing reset and final window frame passed')
