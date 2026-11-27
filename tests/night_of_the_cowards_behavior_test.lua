local fixture = dofile("tests/support/night_of_the_cowards_fixture.lua")
local assertEquals = fixture.assertEquals
local assertTruthy = fixture.assertTruthy
local makeEnvironment = fixture.makeEnvironment
local makePlayer = fixture.makePlayer
local makeNpc = fixture.makeNpc

local function test_normal_enemy_transforms_and_receives_one_cached_aura()
    local env = makeEnvironment()
    env.update()
    local enemy = makeNpc({ seed = 101 })

    env.updateNpc(enemy)
    assertEquals(enemy.Type, EntityType.ENTITY_HOST, "normal enemies should morph into Host type")
    assertTruthy(enemy.Variant == 0 or enemy.Variant == 1 or enemy.Variant == 3,
        "Host variant must be Host, Red Host, or Hard Host")
    assertEquals(enemy.morphCalls, 1, "each enemy should morph once")
    assertEquals(#env.effects, 1, "each enemy should own one aura")

    local aura = env.effects[1]
    assertEquals(aura.Variant, EffectVariant.HALO, "aura must reuse the original Halo Effect variant")
    assertEquals(aura.SubType, 3, "aura must reuse the original Curse Halo subtype")
    assertEquals(aura.sprite.loadCount, 0, "the engine-owned original Halo ANM2 must not be reloaded")
    assertEquals(aura.sprite.playCount, 0, "the engine-owned original Halo animation must start itself")
    assertEquals(aura.removed, false, "the aura must survive without a Repentogon-only FollowParent method")
    assertEquals(aura.sprite.PlaybackSpeed, 1.0, "the persistent aura must use the vanilla 1.0 playback rate")
    assertEquals((aura.addedFlags or 0) & EntityFlag.FLAG_RENDER_FLOOR, 0,
        "a moving aura must never enter the persistent floor-render layer")
    assertEquals(aura.SpriteScale, Vector(0.75, 0.75),
        "the Curse Halo must reuse the native cursed-head 75% visual footprint")
    assertEquals(aura.SpriteOffset, Vector(0, -16),
        "the Curse Halo must reuse the native cursed-head vertical anchor")
    assertTruthy(aura.DepthOffset < 0, "the attached aura must render beneath its owner by depth, not as floor paint")

    env.updateNpc(enemy)
    assertEquals(#env.effects, 1, "repeated NPC updates must reuse the cached aura")
    assertEquals(aura.removed, false, "repeated NPC updates must not delete and respawn the aura")
    assertEquals(aura.sprite.loadCount, 0, "NPC updates must never reload the original ANM2")
end

local function test_original_cursed_death_head_keeps_its_native_single_aura()
    local env = makeEnvironment()
    env.update()
    local cursedDeathHead = makeNpc({ type = 212, variant = 2, vulnerable = false })

    env.updateNpc(cursedDeathHead)
    assertEquals(cursedDeathHead.Type, 212,
        "the original Cursed Death's Head must keep its native entity identity")
    assertEquals(cursedDeathHead.Variant, 2,
        "the original Cursed Death's Head must keep its native variant")
    assertEquals(cursedDeathHead.morphCalls, 0,
        "the original Cursed Death's Head must not be replaced before its native aura renders")
    assertEquals(#env.effects, 0,
        "the original Cursed Death's Head already owns a native aura and must not receive a duplicate")

    env.setNearby({ cursedDeathHead })
    env.update()
    assertEquals(env.input(env.players[1], InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "the native Cursed Death's Head aura must still apply the shared fear gameplay state")
    assertEquals(#env.luaSprites, 1, "the native aura must still create the player's Fear feedback sprite")
end

local function test_boss_keeps_identity_but_still_gets_an_aura()
    local env = makeEnvironment()
    env.update()
    local boss = makeNpc({ boss = true, type = 20, variant = 2 })
    env.updateNpc(boss)
    assertEquals(boss.Type, 20, "bosses must not morph")
    assertEquals(boss.morphCalls, 0, "bosses must not be transformed")
    assertEquals(#env.effects, 1, "all hostile enemies, including bosses, should emit the aura")
end

local function test_aura_follows_owner_and_cleans_up_on_loss()
    local env = makeEnvironment()
    env.update()
    local enemy = makeNpc()
    env.updateNpc(enemy)
    local aura = env.effects[1]

    enemy.Position = Vector(220, 180)
    env.updateEffect(aura)
    assertEquals(aura.Position, enemy.Position, "the single non-floor aura should follow its owner without respawning")

    env.players[1].collectibleCount = 0
    env.update()
    assertTruthy(aura.removed, "losing the last team copy should remove owned auras")
end

local function test_original_fear_visual_and_shoot_input_blocking()
    local env = makeEnvironment()
    assertEquals(type(Sprite), "table",
        "the regression fixture must model an engine-callable Sprite constructor")
    env.update()
    local enemy = makeNpc({ position = Vector(100, 100) })
    env.updateNpc(enemy)
    env.setNearby({ enemy })
    env.update()

    local player = env.players[1]
    assertEquals(player.fearCalls, 0, "the unsupported Player:AddFear route must not be used")
    assertEquals(#env.luaSprites, 1, "one cached player Fear sprite should be created on entry")
    local fearSprite = env.luaSprites[1]
    assertEquals(fearSprite.path, "gfx/statuseffects.anm2", "player feedback must reuse vanilla status art")
    assertEquals(fearSprite.animation, "Fear", "player feedback must play the vanilla Fear animation")
    env.renderPlayer(player, Vector(200, -100))
    assertEquals(fearSprite.renderCount, 1, "the Fear status sprite must render while inside the aura")
    assertEquals(fearSprite.renderPosition.X, player.Position.X,
        "the Fear sprite must convert its world anchor exactly once")
    assertEquals(fearSprite.renderPosition.Y, player.Position.Y - 24,
        "the Fear sprite must use the standard-size player head anchor and ignore callback render offsets")
    env.update()
    assertEquals(fearSprite.loadCount, 1, "the player Fear sprite must be loaded only once")
    assertEquals(fearSprite.playCount, 1, "the player Fear animation must not restart every update")
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "held shoot input should be blocked")
    assertEquals(env.input(player, InputHook.IS_ACTION_TRIGGERED, ButtonAction.ACTION_SHOOTRIGHT), false,
        "triggered shoot input should be blocked")
    assertEquals(env.input(player, InputHook.GET_ACTION_VALUE, ButtonAction.ACTION_SHOOTUP), 0,
        "analog shoot value should be zeroed")
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_LEFT), nil,
        "movement input should remain untouched")
end

local function test_fear_gameplay_radius_matches_the_scaled_visual_radius()
    local env = makeEnvironment()
    env.update()
    local player = env.players[1]
    local enemy = makeNpc({ position = Vector(player.Position.X + 47, player.Position.Y) })
    env.updateNpc(enemy)
    env.setNearby({ enemy })

    env.update()
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "a player inside the 48px aura must be shoot-locked")

    enemy.Position = Vector(player.Position.X + 49, player.Position.Y)
    env.update()
    assertEquals(env.input(player, InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), nil,
        "a player outside the 48px aura must not remain shoot-locked")
end

local function test_holder_receives_one_real_transcendence_collectible()
    local env = makeEnvironment()
    local holder = env.players[1]
    local nonHolder = env.players[2]

    env.update()
    assertEquals(#holder.addCollectibleCalls, 1, "the holder should receive exactly one real collectible")
    assertEquals(holder.addCollectibleCalls[1].itemId, CollectibleType.COLLECTIBLE_TRANSCENDENCE,
        "the granted collectible must be c20 Transcendence")
    assertEquals(holder.collectibleCounts[CollectibleType.COLLECTIBLE_TRANSCENDENCE], 1,
        "c20 must exist in the holder's actual inventory")
    assertEquals(#nonHolder.addCollectibleCalls, 0, "c20 must not leak to non-holders")
    assertEquals(holder.CanFly, false, "Night of the Cowards must no longer write CanFly directly")

    env.update()
    assertEquals(#holder.addCollectibleCalls, 1, "repeated updates must not grant duplicate c20 copies")
    assertEquals(env.getSaveCalls(), 1, "the one-time c20 grant marker must be persisted")
end

local function test_room_change_removes_old_auras_and_shoot_lock()
    local env = makeEnvironment()
    env.update()
    local enemy = makeNpc({ position = Vector(100, 100) })
    env.updateNpc(enemy)
    env.setNearby({ enemy })
    env.update()

    local aura = env.effects[1]
    assertEquals(env.input(env.players[1], InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), false,
        "the player should initially be shoot-locked inside the aura")

    env.newRoom()
    assertTruthy(aura.removed, "room changes should remove the previous room's owned aura entities")
    assertEquals(env.input(env.players[1], InputHook.IS_ACTION_PRESSED, ButtonAction.ACTION_SHOOTLEFT), nil,
        "room changes should clear stale shoot-lock state")
end

local function readFile(path)
    local file = assert(io.open(path, "rb"))
    local text = file:read("*a")
    file:close()
    return text
end

local function test_registration_and_asset_contract()
    local items = readFile("content/items.xml")
    local english = readFile("content/items.en_us.xml")
    local chinese = readFile("content/items.zh_cn.xml")
    local pools = readFile("content/itempools.xml")
    local englishPools = readFile("content/itempools.en_us.xml")
    local chinesePools = readFile("content/itempools.zh_cn.xml")
    local entities = readFile("content/entities2.xml")
    local source = dofile("tests/support/read_lua_module_tree.lua")("night_of_the_cowards.lua")

    assertTruthy(items:find('<passive name="Night of the Cowards"', 1, true), "base item registration")
    assertEquals(items:find('name="Night of the Cowards" cache="flying"', 1, true), nil,
        "base item must not provide scripted flight")
    assertEquals(english:find('name="Night of the Cowards" cache="flying"', 1, true), nil,
        "English item must not provide scripted flight")
    assertEquals(chinese:find('name="胆小鬼之夜" cache="flying"', 1, true), nil,
        "Chinese item must not provide scripted flight")
    assertTruthy(english:find('name="Night of the Cowards"', 1, true), "English localization")
    assertTruthy(chinese:find('name="胆小鬼之夜"', 1, true), "Chinese localization")
    assertTruthy(pools:find('<Pool Name="devil">', 1, true) and pools:find('Name="Night of the Cowards"', 1, true),
        "base Devil pool")
    assertTruthy(englishPools:find('<Pool Name="greedDevil">', 1, true) and englishPools:find('Name="Night of the Cowards"', 1, true),
        "English Greed Devil pool")
    assertTruthy(chinesePools:find('<Pool Name="greedDevil">', 1, true) and chinesePools:find('Name="胆小鬼之夜"', 1, true),
        "Chinese Greed Devil pool")
    assertEquals(entities:find('variant="3021"', 1, true), nil,
        "the obsolete custom Fear Aura Effect must be unregistered")
    assertTruthy(source:find("EffectVariant.HALO", 1, true),
        "enemy auras must reuse the original Halo Effect")
    assertEquals(source:find("FollowParent", 1, true), nil,
        "base Repentance does not expose Effect:FollowParent and must not depend on it")
    assertTruthy(source:find("PlaybackSpeed", 1, true),
        "the reused vanilla Halo must explicitly retain the original playback rate")
    assertEquals(source:find("FLAG_RENDER_FLOOR", 1, true), nil,
        "moving enemy auras must never use the persistent floor-render flag")
    assertTruthy(source:find("AuraSubtype", 1, true),
        "enemy auras must select the original Curse Halo subtype")
    assertEquals(source:find("AddFear", 1, true), nil,
        "the unsupported Player:AddFear route must be removed")
    assertEquals(source:find("player.CanFly", 1, true), nil,
        "Night of the Cowards must not write CanFly directly")
    assertEquals(source:find("EFFECT_NULL", 1, true), nil, "the aura must not use the unregistered null Effect carrier")
    assertEquals(source:find("effect.Timeout", 1, true), nil, "the aura must not write an invalid Timeout member")
    assertTruthy(source:find("gfx/statuseffects.anm2", 1, true),
        "player Fear feedback must reuse the original status ANM2")
    assertTruthy(source:find("COLLECTIBLE_TRANSCENDENCE", 1, true),
        "flight must be granted through the original c20 collectible")
end

local tests = {
    test_normal_enemy_transforms_and_receives_one_cached_aura,
    test_original_cursed_death_head_keeps_its_native_single_aura,
    test_boss_keeps_identity_but_still_gets_an_aura,
    test_aura_follows_owner_and_cleans_up_on_loss,
    test_original_fear_visual_and_shoot_input_blocking,
    test_fear_gameplay_radius_matches_the_scaled_visual_radius,
    test_holder_receives_one_real_transcendence_collectible,
    test_room_change_removes_old_auras_and_shoot_lock,
    test_registration_and_asset_contract,
}

for _, test in ipairs(tests) do test() end
print("night_of_the_cowards_behavior_test: ok")
