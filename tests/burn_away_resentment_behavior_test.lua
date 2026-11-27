local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error((message or "assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertNear(actual, expected, epsilon, message)
    if math.abs(actual - expected) > (epsilon or 0.0001) then
        error((message or "assertion failed") .. ": expected near " .. tostring(expected) .. ", got " .. tostring(actual), 2)
    end
end

local function assertTruthy(value, message)
    if not value then
        error(message or "expected truthy value", 2)
    end
end

local function readFile(path)
    local file = assert(io.open(path, "r"), path .. " should exist")
    local text = file:read("*a")
    file:close()
    return text
end

local function readPngInfo(path)
    local file = assert(io.open(path, "rb"), path .. " should exist")
    local header = file:read(26)
    local fileSize = file:seek("end")
    file:close()
    assertTruthy(header and #header >= 26, path .. " should have a PNG header")

    local function readU32(offset)
        local a, b, c, d = string.byte(header, offset, offset + 3)
        return ((a * 256 + b) * 256 + c) * 256 + d
    end

    return {
        width = readU32(17),
        height = readU32(21),
        colorType = string.byte(header, 26),
        fileSize = fileSize,
    }
end

local loadNeverbirth = dofile("tests/support/burn_away_resentment_fixture.lua")

local function burnState(player)
    return Neverbirth.BurnAwayResentment.GetState(player)
end

local function test_burn_away_resentment_visual_resources_match_runtime_contract()
    local status = readFile("resources/gfx/Effects/BurnAwayResentment/ResentmentStatus.anm2")
    local burst = readFile("resources/gfx/Effects/BurnAwayResentment/PurgeWave.anm2")
    local statusPng = readPngInfo("resources/gfx/Effects/BurnAwayResentment/ResentmentStatus.png")
    local burstPng = readPngInfo("resources/gfx/Effects/BurnAwayResentment/PurgeWave.png")
    assertTruthy(status:find('DefaultAnimation="Resentment"', 1, true), "status ANM2 should default to Resentment")
    assertTruthy(status:find('Animation Name="Resentment" FrameNum="5" Loop="false"', 1, true), "status ANM2 should expose five resentment frames")
    assertTruthy(status:find('Animation Name="Ready" FrameNum="4" Loop="true"', 1, true), "status ANM2 should expose looping Ready")
    assertTruthy(status:find('Animation Name="Clarity" FrameNum="6" Loop="false"', 1, true), "status ANM2 should expose six clarity frames")
    assertTruthy(burst:find('DefaultAnimation="Burst"', 1, true), "purge ANM2 should default to Burst")
    assertTruthy(burst:find('Animation Name="Burst" FrameNum="12" Loop="false"', 1, true), "purge ANM2 should expose the 12-frame burst")
    assertEquals(statusPng.width, 288, "status PNG width")
    assertEquals(statusPng.height, 144, "status PNG height")
    assertEquals(burstPng.width, 384, "burst PNG width")
    assertEquals(burstPng.height, 288, "burst PNG height")
end

local function test_xml_registers_burn_away_resentment()
    local items = readFile("content/items.xml")
    local zh = readFile("content/items.zh_cn.xml")
    local en = readFile("content/items.en_us.xml")
    local pools = readFile("content/itempools.xml")
    assertTruthy(items:find('name="Burn Away the Resentment"', 1, true), "default XML should register Burn Away the Resentment")
    assertTruthy(zh:find('name="焚尽郁结"', 1, true), "Chinese XML should register 焚尽郁结")
    assertTruthy(en:find('name="Burn Away the Resentment"', 1, true), "English XML should register Burn Away the Resentment")
    assertTruthy(pools:find('<Pool Name="curse">', 1, true) and pools:find('Name="Burn Away the Resentment"', 1, true), "curse pool should contain Burn Away the Resentment")
    assertTruthy(pools:find('<Pool Name="devil">', 1, true), "devil pool should exist")
end

local function clearCurrentRoom(env, enemy)
    enemy.removed = true
    env.setRoomClear(true)
    env.runPostUpdate()
end

local function test_initial_layers_and_room_clear_stacks()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 10 })
    local enemy = env.newEnemy()
    env.runPostUpdate()
    assertEquals(burnState(player).currentLayers, 2, "first pickup should grant exactly 2 layers")
    env.runPostUpdate(3)
    assertEquals(burnState(player).currentLayers, 2, "holding extra update frames should not repeat initial layers")
    clearCurrentRoom(env, enemy)
    assertEquals(burnState(player).currentLayers, 3, "first normal hostile clear should add 1 layer")
    env.runPostUpdate(2)
    assertEquals(burnState(player).currentLayers, 3, "same room clear should count once")

    env.runNewRoom()
    env.setRoomClear(false)
    local nextEnemy = env.newEnemy()
    env.runPostUpdate()
    clearCurrentRoom(env, nextEnemy)
    assertEquals(burnState(player).currentLayers, 4, "second hostile room should add one more layer")
end

local function test_boss_clear_adds_two_layers()
    local env = loadNeverbirth({ roomType = 5 })
    local player = env.newPlayer()
    local boss = env.newEnemy({ boss = true })
    env.runPostUpdate()
    clearCurrentRoom(env, boss)
    assertEquals(burnState(player).currentLayers, 4, "boss clear should add normal 1 plus bonus 1")
end

local function test_ready_direct_hit_purges_once()
    local env = loadNeverbirth()
    local player = env.newPlayer({ damage = 10 })
    local enemy = env.newEnemy()
    env.runPostUpdate()
    local state = burnState(player)
    state.currentLayers = 6
    state.readyRoomKey = state.roomKey
    env.runDamage(enemy, 1, { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player })
    assertEquals(enemy.damageTaken, 30, "ready direct player hit should deal 300% damage")
    assertEquals(enemy.burnDuration, 90, "ready purge should burn enemies for 3 seconds")
    assertEquals(state.currentLayers, 0, "ready purge should consume all layers")
    assertEquals(state.pendingClarity, 6, "ready purge should bank 6 clarity")
    assertTruthy(state.floorSettled, "ready purge should settle the floor")
    env.runDamage(enemy, 1, { Type = EntityType.ENTITY_TEAR, SpawnerEntity = player })
    assertEquals(enemy.damageTaken, 30, "settled floor must not recurse or purge twice")
end

local function test_hurt_purges_after_real_health_loss()
    for layers = 3, 6 do
        local env = loadNeverbirth()
        local player = env.newPlayer({ damage = 10, hearts = 8 })
        local enemy = env.newEnemy()
        env.runPostUpdate()
        local state = burnState(player)
        state.currentLayers = layers
        env.runDamage(player, 1, enemy)
        assertEquals(enemy.damageTaken, 0, "damage callback must not burst before health loss is confirmed")
        player.hearts = player.hearts - 2
        env.runPostUpdate()
        assertEquals(enemy.damageTaken, layers * 5, "hurt purge multiplier should match spent layers")
        assertEquals(enemy.burnDuration, 90, "hurt purge should burn for 3 seconds")
        assertEquals(state.pendingClarity, layers, "hurt purge should bank exactly spent layers")
        assertTruthy(state.floorSettled, "hurt purge should settle the floor")
    end
end

local function test_invalid_or_blocked_hurt_does_not_purge()
    local invalidFlags = { DamageFlag.DAMAGE_FAKE, DamageFlag.DAMAGE_IV_BAG, DamageFlag.DAMAGE_DEVIL, DamageFlag.DAMAGE_CURSED_DOOR, DamageFlag.DAMAGE_SPIKES }
    for _, flags in ipairs(invalidFlags) do
        local env = loadNeverbirth()
        local player = env.newPlayer({ hearts = 8 })
        local enemy = env.newEnemy()
        env.runPostUpdate()
        local state = burnState(player)
        state.currentLayers = 4
        env.runDamageRef(player, 1, EntityRef(enemy), flags)
        player.hearts = player.hearts - 2
        env.runPostUpdate(3)
        assertEquals(enemy.damageTaken, 0, "excluded damage flags must not purge")
        assertEquals(state.currentLayers, 4, "excluded damage must keep layers")
    end

    local shielded = loadNeverbirth()
    local player = shielded.newPlayer({ hearts = 8 })
    local enemy = shielded.newEnemy()
    shielded.runPostUpdate()
    local state = burnState(player)
    state.currentLayers = 4
    shielded.runDamage(player, 1, enemy)
    shielded.runPostUpdate(3)
    assertEquals(enemy.damageTaken, 0, "blocked damage with no health loss must not purge")
    assertEquals(state.currentLayers, 4, "blocked damage must keep layers")

    local sacrifice = loadNeverbirth({ roomType = 13 })
    local sacrificePlayer = sacrifice.newPlayer({ hearts = 8 })
    local sacrificeEnemy = sacrifice.newEnemy()
    sacrifice.runPostUpdate()
    local sacrificeState = burnState(sacrificePlayer)
    sacrificeState.currentLayers = 4
    sacrifice.runDamage(sacrificePlayer, 1, sacrificeEnemy)
    sacrificePlayer.hearts = sacrificePlayer.hearts - 2
    sacrifice.runPostUpdate(3)
    assertEquals(sacrificeEnemy.damageTaken, 0, "sacrifice room damage must not purge")
    assertEquals(sacrificeState.currentLayers, 4, "sacrifice room damage must keep layers")
end

local function test_floor_transition_cache_and_independent_players()
    local env = loadNeverbirth()
    local first = env.newPlayer({ damage = 10, maxFireDelay = 10, moveSpeed = 1 })
    local second = env.newPlayer({ damage = 10, maxFireDelay = 10, moveSpeed = 1 })
    env.runPostUpdate()
    local firstState = burnState(first)
    local secondState = burnState(second)
    firstState.currentLayers = 3
    secondState.currentLayers = 5
    env.runNewLevel()
    assertEquals(firstState.currentLayers, 0, "new level should clear old resentment")
    assertEquals(firstState.currentFloorClarity, 3, "new level should convert unsettled layers to clarity")
    assertEquals(secondState.currentFloorClarity, 5, "players should settle clarity independently")
    env.runEvaluate(first, CacheFlag.CACHE_DAMAGE)
    env.runEvaluate(first, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(first, CacheFlag.CACHE_SPEED)
    assertNear(first.Damage, 11.05, 0.0001, "3 clarity should add 1.05 damage")
    assertNear(first.MaxFireDelay, 9.64, 0.0001, "3 clarity should lower MaxFireDelay by 0.36")
    assertNear(first.MoveSpeed, 1, 0.0001, "new level should remove resentment speed penalty")
end

local function test_item_loss_and_runtime_reset_clear_state_and_visuals()
    local env = loadNeverbirth()
    local player = env.newPlayer()
    env.runPostUpdate()
    env.runRender()
    assertTruthy(#env.spriteEvents > 0, "status visual should attempt Sprite rendering while the item is held")
    player.collectibles[env.items.BurnAwayResentment] = 0
    env.runPostUpdate()
    assertEquals(Neverbirth.BurnAwayResentment.states[tostring(player.InitSeed)], nil, "item loss should clear runtime state")
    player.collectibles[env.items.BurnAwayResentment] = 1
    env.runPostUpdate()
    assertEquals(burnState(player).currentLayers, 2, "reacquiring should start a fresh holding with 2 layers")
    env.runGameStarted()
    assertEquals(next(Neverbirth.BurnAwayResentment.states), nil, "new run should not retain state")
end

test_burn_away_resentment_visual_resources_match_runtime_contract()
test_xml_registers_burn_away_resentment()
test_initial_layers_and_room_clear_stacks()
test_boss_clear_adds_two_layers()
test_ready_direct_hit_purges_once()
test_hurt_purges_after_real_health_loss()
test_invalid_or_blocked_hurt_does_not_purge()
test_floor_transition_cache_and_independent_players()
test_item_loss_and_runtime_reset_clear_state_and_visuals()

print("burn away resentment behavior tests passed")
