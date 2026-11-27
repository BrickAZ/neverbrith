local loadTrial = assert(loadfile('tests/between_death_and_life_behavior_test.lua'))('--fixture')
local function fire(env, event, name, ...)
    local count = 0
    for _, entry in ipairs(env.callbacks[event] or {}) do
        if entry.fn == env.mod[name] then count = count + 1; entry.fn(env.mod, ...) end
    end
    assert(count == 1, name .. ' must have exactly one real registration')
end
local first = loadTrial({ hasData = true, savedRoot = { sentinel = { value = 123 } } })
first.runPostAddCollectible(first.newPlayer())
assert(first.savedRoot().deathTrial.active, 'pickup activation must save the trial')

local continued = loadTrial({ hasData = true, savedRoot = first.savedRoot() })
fire(continued, ModCallbacks.MC_POST_GAME_STARTED, 'ResetBetweenDeathLifeState', true)
continued.level.currentRoomIndex = 1
local enemy = continued.newNpc({ type = EntityType.ENTITY_FLY })
continued.runPostNpcInit(enemy)
assert(enemy.champion, 'fresh loader must restore the active trial on continue')
continued.room.roomType, continued.room.clear = RoomType.ROOM_BOSS, true
fire(continued, ModCallbacks.MC_POST_UPDATE, 'UpdateBetweenDeathLifeBossReward')
assert(#continued.spawned == 1 and continued.spawned[1].SubType == continued.items.DeathCertificate, 'continued trial reward')
assert(continued.savedRoot().sentinel.value == 123, 'unrelated save fields survive trial writes')

local rewarded = loadTrial({ hasData = true, savedRoot = continued.savedRoot() })
fire(rewarded, ModCallbacks.MC_POST_GAME_STARTED, 'ResetBetweenDeathLifeState', true)
rewarded.room.roomType, rewarded.room.clear = RoomType.ROOM_BOSS, true
fire(rewarded, ModCallbacks.MC_POST_UPDATE, 'UpdateBetweenDeathLifeBossReward')
assert(#rewarded.spawned == 0, 'a delivered floor reward must not be replayed after reload')
rewarded.level.stage = 2
fire(rewarded, ModCallbacks.MC_POST_UPDATE, 'UpdateBetweenDeathLifeBossReward')
fire(rewarded, ModCallbacks.MC_POST_UPDATE, 'UpdateBetweenDeathLifeBossReward')
assert(#rewarded.spawned == 1, 'new floor has one independent entitlement')

local newSeed = loadTrial({ hasData = true, runSeed = 'OTHER RUN', savedRoot = continued.savedRoot() })
fire(newSeed, ModCallbacks.MC_POST_GAME_STARTED, 'ResetBetweenDeathLifeState', true)
newSeed.level.currentRoomIndex = 1
local freshEnemy = newSeed.newNpc({ type = EntityType.ENTITY_FLY })
newSeed.runPostNpcInit(freshEnemy)
assert(not freshEnemy.champion, 'run seed mismatch must invalidate the previous trial')
fire(newSeed, ModCallbacks.MC_POST_GAME_STARTED, 'ResetBetweenDeathLifeState', false)
assert(newSeed.savedRoot().deathTrial.active == false, 'new run persists reset trial')
assert(newSeed.savedRoot().sentinel.value == 123, 'new run retains unrelated save data')
print('batch3 lifecycle: trial fresh-loader continue, per-floor reward persistence, run seed and unrelated data passed')
