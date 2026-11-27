-- Exercise the real item callbacks, including exact pool draw order and save reload.
local loadMod = assert(loadfile('tests/angelbox_behavior_test.lua'))('--fixture')
local function equal(actual, expected, label)
    assert(actual == expected, label .. ': expected ' .. tostring(expected) .. ', got ' .. tostring(actual))
end
local checks = 0
for _, name in ipairs({ 'Angelbox', 'Devilbox' }) do
    local function setup(count, store)
        local env = loadMod(store)
        local item = env.items[name]
        local use = env.getCallback(ModCallbacks.MC_USE_ITEM, item)
        env.room.GetSpawnSeed = function() return 0 end
        for index = 1, count do
            local player = env.newPlayer({ initSeed = index * 111, activeItems = { [0] = item }, activeCharges = { [0] = 4 } })
            equal(use(env.mod, item, nil, player, 0, 0), true, name .. ' first use')
            player:SetActiveCharge(4, 0)
            equal(use(env.mod, item, nil, player, 0, 0), true, name .. ' queue reward')
        end
        local enter = env.mod[name == 'Angelbox' and 'SpawnAngelboxRewardOnNewRoom' or 'SpawnDevilboxRewardOnNewRoom']
        local function settle()
            env.room.roomType = name == 'Angelbox' and RoomType.ROOM_ANGEL or RoomType.ROOM_DEVIL
            enter(env.mod)
        end
        return env, settle
    end
    local first, second, pool = name == 'Angelbox' and 331 or 278, name == 'Angelbox' and 643 or 292, name == 'Angelbox' and 4 or 3
    do
        local env, settle = setup(2)
        local draws, sequence = {}, { 1, first, first, second }
        function env.itemPool:GetCollectible(actualPool, decrease, seed, fallback)
            draws[#draws + 1] = seed
            equal(actualPool, pool, name .. ' pool')
            equal(decrease, false, name .. ' no pool depletion')
            equal(fallback, 0, name .. ' null fallback')
            return sequence[#draws]
        end
        settle()
        equal(#env.spawned, 2, name .. ' two owners')
        equal(env.spawned[1].SubType, first, name .. ' first quality match')
        equal(env.spawned[2].SubType, second, name .. ' prefer distinct reward')
        equal(table.concat(draws, ','), '1007922,1015841,2007925,2015844', name .. ' exact draw order')
        settle()
        equal(#draws, 4, name .. ' no repeated reward draw')
        checks = checks + 1
    end
    do
        local env, settle = setup(2)
        local draws = 0
        function env.itemPool:GetCollectible() draws = draws + 1; return first end
        settle()
        equal(draws, 121, name .. ' duplicate search limit')
        equal(env.spawned[2].SubType, first, name .. ' duplicate retained before fallback')
        checks = checks + 1
    end
    for _, mode in ipairs({ 'invalid-pool', 'missing-pool', 'missing-config' }) do
        local env, settle = setup(2)
        local draws = 0
        function env.itemPool:GetCollectible() draws = draws + 1; return 0 end
        if mode == 'missing-pool' then env.itemPool.GetCollectible = nil end
        if mode == 'missing-config' then Isaac.GetItemConfig = function() return nil end end
        settle()
        equal(draws, mode == 'missing-pool' and 0 or 240, name .. ' ' .. mode .. ' draw budget')
        equal(env.spawned[1].SubType, first, name .. ' ' .. mode .. ' first fallback')
        equal(env.spawned[2].SubType, second, name .. ' ' .. mode .. ' second fallback')
        checks = checks + 1
    end
    do
        local env = setup(2)
        local store = env.savedStore
        local section = name == 'Angelbox' and 'angelbox' or 'devilbox'
        local other = name == 'Angelbox' and 'devilbox' or 'angelbox'
        store.snapshot.sentinel = { keep = 123 }
        store.snapshot[other].sentinel = 'other box'
        -- An older version stored a numeric pending count. Both formats stay readable.
        local floorKey = next(store.snapshot[section].pendingRewards)
        assert(floorKey, name .. ' saved pending floor')
        store.snapshot[section].pendingRewards[floorKey] = 2
        local reloaded = loadMod(store)
        reloaded.room.GetSpawnSeed = function() return 0 end
        reloaded.itemPool.GetCollectible = nil
        reloaded.room.roomType = name == 'Angelbox' and RoomType.ROOM_ANGEL or RoomType.ROOM_DEVIL
        local enter = reloaded.mod[name == 'Angelbox' and 'SpawnAngelboxRewardOnNewRoom' or 'SpawnDevilboxRewardOnNewRoom']
        enter(reloaded.mod); enter(reloaded.mod)
        equal(#reloaded.spawned, 2, name .. ' legacy pending rewards after reload')
        equal(store.snapshot.sentinel.keep, 123, name .. ' unknown save data retained')
        equal(store.snapshot[other].sentinel, 'other box', name .. ' other region retained')
        equal(store.snapshot[section].pendingRewards[floorKey], nil, name .. ' pending cleared after delivery')
        checks = checks + 1
    end
end
print('box reward selection: ' .. checks .. ' real-consumer scenarios passed')
