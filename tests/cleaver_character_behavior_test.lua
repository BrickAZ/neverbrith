local support = dofile("tests/support/cleaver_character_fixture.lua")()
local assertEquals = support.assertEquals
local assertNear = support.assertNear
local assertTruthy = support.assertTruthy
local readFile = support.readFile
local readPngInfo = support.readPngInfo
local loadNeverbirth = support.loadNeverbirth
local burnState = support.burnState
local configureCleaver = support.configureCleaver
local shadowFor = support.shadowFor

local function test_stranger_is_unregistered_but_cleaver_assets_remain_available()
    local players = readFile("content/players.xml")
    assertEquals(players:match('<player name="Stranger"'), nil, "players.xml must keep Stranger unregistered")
    assertEquals(players:match('<player name="Dante"'), nil, "players.xml must keep Dante unregistered while custom characters are disabled")

    local liveCharacterMenu = io.open("content/gfx/CharacterMenu.anm2", "rb")
    if liveCharacterMenu then liveCharacterMenu:close() end
    assertEquals(liveCharacterMenu, nil, "unregistered characters must not retain a live character-menu entry")
    -- Preserve the art contract only in the archive, outside native menu discovery.
    local characterMenu = readFile("content/gfx/CharacterMenu.anm2.disabled")
    assertTruthy(characterMenu:match('<Spritesheet Id="1" Path="stranger_not_yet_name%.png"'),
        "Stranger character menu should load the dedicated NOT YET name sheet")
    assertTruthy(characterMenu:match('<Spritesheet Id="2" Path="stranger_not_yet_item%.png"'),
        "Stranger character menu should load the dedicated NOT YET item-name sheet")
    assertTruthy(characterMenu:match('<Layer Id="3" Name="Name" SpritesheetId="1"'),
        "Stranger Name layer should use the dedicated 80x32 NOT YET sheet")
    assertTruthy(characterMenu:match('<Layer Id="8" Name="Item Name" SpritesheetId="2"'),
        "Stranger Item Name layer should use the dedicated 112x32 NOT YET sheet")
    local itemIconLayer = characterMenu:match('<LayerAnimation LayerId="7".-</LayerAnimation>')
    assertTruthy(itemIconLayer and itemIconLayer:match('Visible="false"'),
        "Stranger Item Icon layer should be hidden instead of showing D6 or another icon")
    local nameLayer = characterMenu:match('<LayerAnimation LayerId="3".-</LayerAnimation>')
    assertTruthy(nameLayer and nameLayer:match('XCrop="0" YCrop="0" Width="80" Height="32"'),
        "Stranger Name frame should crop the complete 80x32 NOT YET sheet")
    local itemNameLayer = characterMenu:match('<LayerAnimation LayerId="8".-</LayerAnimation>')
    assertTruthy(itemNameLayer and itemNameLayer:match('XCrop="0" YCrop="0" Width="112" Height="32"'),
        "Stranger Item Name frame should crop the complete 112x32 NOT YET sheet")
    assertEquals(characterMenu:find("stranger_not_yet_preview.png", 1, true), nil,
        "the 480x270 preview is reference-only and must not be loaded by CharacterMenu.anm2")

    local notYetName = readPngInfo("content/gfx/stranger_not_yet_name.png")
    assertEquals(notYetName.width, 80, "Stranger NOT YET name sheet width")
    assertEquals(notYetName.height, 32, "Stranger NOT YET name sheet height")
    assertEquals(notYetName.colorType, 6, "Stranger NOT YET name sheet must preserve RGBA transparency")
    local notYetItem = readPngInfo("content/gfx/stranger_not_yet_item.png")
    assertEquals(notYetItem.width, 112, "Stranger NOT YET item-name sheet width")
    assertEquals(notYetItem.height, 32, "Stranger NOT YET item-name sheet height")
    assertEquals(notYetItem.colorType, 6, "Stranger NOT YET item-name sheet must preserve RGBA transparency")

    local env = loadNeverbirth({ strangerPlayerType = 777 })
    assertEquals(Neverbirth.Cleaver.Config.Registered, false, "production Cleaver character support should be disabled")
    assertEquals(Neverbirth.Cleaver.Config.PlayerType, nil, "an unregistered Stranger must not resolve a PlayerType")
    Neverbirth.Cleaver.Config.PlayerType = 777
    local staleTypePlayer = env.newPlayer({ playerType = 777 })
    assertEquals(Neverbirth.Cleaver.IsEnabled(staleTypePlayer), false, "a stale Stranger PlayerType must stay disabled after unregistering the character")
    assertEquals(Neverbirth.Cleaver.Config.CleaverVisualTimeout, 22, "11 authored frames at 30 FPS must last 22 game ticks")
    assertEquals(Neverbirth.Cleaver.Config.SwingDurationTicks, 22, "sweep duration must match the complete 11-frame animation")
    assertEquals(Neverbirth.Cleaver.Config.HoldVisualPath, "gfx/Effects/CleaverAttack/stranger_machete.anm2", "idle must use the Stranger machete actor")
    assertEquals(Neverbirth.Cleaver.Config.CleaverVisualPath, "gfx/Effects/CleaverAttack/stranger_machete.anm2", "swing must use the Stranger machete actor")
    local macheteAnm2 = readFile("resources/gfx/Effects/CleaverAttack/stranger_machete.anm2")
    local function containsAnimation(xml, name)
        return xml:match('<Animation[^>]-Name="' .. name .. '"') ~= nil
    end
    assertTruthy(macheteAnm2:match('Spritesheet Id="0" Path="stranger_machete_swing_11f%.png"'), "machete actor must use the shared 11-frame spritesheet")
    for _, direction in ipairs({ "Up", "Down", "Left", "Right" }) do
        for _, variant in ipairs({ "A", "B" }) do
            assertTruthy(containsAnimation(macheteAnm2, "Idle" .. direction .. "_" .. variant), "machete actor should provide A/B idle animations")
            assertTruthy(containsAnimation(macheteAnm2, "Swing" .. direction .. "_" .. variant), "machete actor should provide A/B swing animations")
        end
    end
    assertTruthy(macheteAnm2:match('Event Name="Hit"') and macheteAnm2:match('Trigger EventId="0" AtFrame="3"'), "machete actor should retain its authored Hit event")
    for _, animation in ipairs({ "SwingUp_A", "SwingUp_B", "SwingDown_A", "SwingDown_B", "SwingLeft_A", "SwingLeft_B", "SwingRight_A", "SwingRight_B" }) do
        local block = macheteAnm2:match('<Animation[^>]-Name="' .. animation .. '"[^>]*>(.-)</Animation>')
        assertTruthy(block, animation .. " should exist")
        local frames = 0
        for _ in block:gmatch('XPivot="(%d+)" YPivot="(%d+)"') do frames = frames + 1 end
        assertEquals(frames, 11, animation .. " should retain all eleven hand-anchored frames")
    end
    local sheet = readPngInfo("resources/gfx/Effects/CleaverAttack/stranger_machete_swing_11f.png")
    assertEquals(sheet.width, 1056, "machete 11-frame spritesheet width")
    assertEquals(sheet.height, 896, "machete 11-frame spritesheet height")
    assertEquals(sheet.colorType, 6, "machete spritesheet must preserve RGBA transparency")
end
local function test_stranger_starts_with_cleaver_but_does_not_depend_on_the_item()
    local env = loadNeverbirth()
    configureCleaver()
    local stranger = env.newPlayer({ playerType = 42, collectibles = {} })
    assertTruthy(Neverbirth.Cleaver.IsEnabled(stranger), "Stranger must enable the system even before the visible starting item is granted")
    env.runGameStarted(false)
    assertEquals(stranger:GetCollectibleNum(env.items.Cleaver), 1, "a new Stranger run must grant one Cleaver")
    assertTruthy(Neverbirth.Cleaver.IsEnabled(stranger), "the starting item must not be the gameplay gate")
    stranger.collectibles[env.items.Cleaver] = 0
    assertTruthy(Neverbirth.Cleaver.IsEnabled(stranger), "losing the visible Cleaver item must not disable Stranger's character mechanic")
    env.runGameStarted(true)
    assertEquals(stranger:GetCollectibleNum(env.items.Cleaver), 0, "continued runs must not duplicate the visible starting item")
end
local function test_cleaver_has_a_persistent_handheld_visual_outside_swings()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(40, 50) })
    env.runPostUpdate()
    local state = Neverbirth.Cleaver.GetState(player)
    assertTruthy(state.holdVisual and state.holdVisual.sprite, "an enabled Stranger must create one persistent held-cleaver Sprite")
    assertEquals(state.holdVisual.animation, "IdleDown_A", "a stationary Stranger should use the A downward idle pose before the first swing")
    assertEquals(state.holdVisual.sprite.Scale.X, 0.5, "the held-cleaver Sprite must use the shared half-scale actor")
    assertEquals(state.holdVisual.sprite.Scale.Y, 0.5, "the held-cleaver Sprite must use the shared half-scale actor")
    env.runRender()
    local rendered = false
    for _, event in ipairs(env.spriteEvents) do rendered = rendered or (event.type == "render" and event.animation == "IdleDown_A") end
    assertTruthy(rendered, "the held-cleaver Sprite should render while not swinging")
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "first swing should start")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    env.runPostUpdate()
    assertEquals(state.holdVisual.animation, "IdleRight_A", "after a completed A swing, the held cleaver should preserve its direction and A pose")
end
local function test_non_cleaver_players_are_fully_isolated()
    local env = loadNeverbirth()
    local normal = env.newPlayer({ playerType = 0 })
    local enemy = env.newEnemy()
    env.runPostUpdate()
    assertEquals(next(Neverbirth.Cleaver.shadows), nil, "normal players must not create shadows")
    assertEquals(Neverbirth.Cleaver.TrySwing(normal, Vector(1, 0)), false, "normal players must not swing")
    local tear = { SpawnerEntity = normal }
    env.runPostFireTear(tear)
    assertEquals(tear.removed, nil, "normal player tears must remain untouched")
end

local function test_player_shooting_input_starts_a_swing_without_raw_trigger_state()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), shootingInput = Vector(1, 0) })
    env.runPostUpdate()
    assertTruthy(Neverbirth.Cleaver.GetState(player).swing, "player:GetShootingInput must start a swing even when Input.IsActionTriggered is unavailable")
end
local function test_raw_shoot_trigger_starts_a_swing_and_spawns_the_native_hitbox_at_the_authored_frame()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertEquals(env.runInput(player, InputHook.IS_ACTION_TRIGGERED, ButtonAction.ACTION_SHOOTRIGHT), nil, "Cleaver must not depend on MC_INPUT_ACTION interception")
    env.triggerShoot(player, ButtonAction.ACTION_SHOOTRIGHT)
    local state = Neverbirth.Cleaver.GetState(player)
    assertTruthy(state.swing, "raw shooting input should start the Lua swing state")
    assertEquals(env.getLatestKnife(), nil, "the invisible carrier must not exist before its configured fallback tick")
    local beforeCarrier = Neverbirth.Cleaver.Config.SwingCarrierFallbackTick - (state.swing.tick or 0) - 1
    if beforeCarrier > 0 then env.runPostUpdate(beforeCarrier) end
    assertEquals(env.getLatestKnife(), nil, "early authored frames must remain visual-only")
    env.runPostUpdate()
    local knife = env.getLatestKnife()
    assertTruthy(knife, "the configured carrier tick must create one native EntityKnife")
    assertEquals(knife.Variant, 10, "Cleaver must use the native Spirit Sword knife carrier")
    assertEquals(knife.SubType, Neverbirth.Cleaver.Config.KnifeSubType, "Cleaver must identify its native knife with a private subtype")
    assertEquals(knife.CollisionDamage, 0, "the hidden native carrier must not contribute a circular collision damage source")
    assertEquals(knife.Parent, player, "native knife must retain its owner for the swing lifetime")
    assertNear(knife.Size, 1, 0.0001, "the hidden native carrier must not expose a large circular collision radius")
    assertEquals(knife.EntityCollisionClass, EntityCollisionClass.ENTCOLL_NONE, "the hidden carrier must leave collision to the Lua sweep")
    env.runKnifeUpdate(knife)
    assertEquals(knife.Variant, 0, "after spawning as Spirit Sword, the native carrier must reset to the default knife variant")
    assertEquals(player.shootingCooldown, Neverbirth.Cleaver.Config.SwingCooldownFrames, "raw swing should set the configured shooting cooldown")
    local tear = env.newTear(player)
    env.runPostFireTear(tear)
    assertTruthy(tear.removed, "post-fire fallback must remove any vanilla tear that bypasses the swing input")
end
local function test_post_fire_tear_resolves_player_owner_before_replacing_shot()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    local ownerProxy = {
        ToPlayer = function()
            return player
        end,
    }
    local tear = {
        SpawnerEntity = ownerProxy,
        Position = Vector(8, 0),
        Velocity = Vector(8, 0),
        Remove = function(self)
            self.removed = true
        end,
    }
    env.runPostFireTear(tear)
    assertTruthy(tear.removed, "a tear whose owner resolves through ToPlayer must be removed")
    assertEquals(Neverbirth.Cleaver.GetState(player).swing, nil, "post-fire cleanup must not become the primary melee trigger")
end

local function test_raw_shoot_trigger_uses_the_manual_cleaver_visual()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    env.triggerShoot(player, ButtonAction.ACTION_SHOOTRIGHT)
    local state = Neverbirth.Cleaver.GetState(player)
    assertTruthy(state.swing and state.swing.visual, "raw input must own a manual CleaverAttack visual")
    assertEquals(state.swing.visual.animation, "SwingRight_A", "the first right input must select the A machete swing")
    local remaining = Neverbirth.Cleaver.Config.SwingCarrierFallbackTick - (state.swing.tick or 0)
    if remaining > 0 then env.runPostUpdate(remaining) end
    local knife = env.getLatestKnife()
    assertTruthy(knife, "the visual must create one native EntityKnife at its carrier tick")
    assertEquals(state.swing.nativeKnife, knife, "the active swing must own the carrier spawned by its visual")
end
local function test_swing_uses_shared_scale_and_advances_at_thirty_fps()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "swing should begin")
    local swing = Neverbirth.Cleaver.GetState(player).swing
    assertEquals(swing.visual.sprite.Scale.X, 0.5, "swing must use the same half scale as the held actor")
    assertEquals(swing.visual.sprite.Scale.Y, 0.5, "swing must use the same half scale as the held actor")
    env.runPostUpdate()
    assertEquals(swing.visual.sprite.updates, 0, "30 FPS animation must not advance on the first 60 FPS game tick")
    env.runPostUpdate()
    assertEquals(swing.visual.sprite.updates, 1, "30 FPS animation must advance once after two game ticks")
    local playCount = 0
    for _, event in ipairs(env.spriteEvents) do
        if event.type == "play" and event.animation == "SwingRight_A" then playCount = playCount + 1 end
    end
    assertEquals(playCount, 1, "one swing must Play its A/B animation exactly once instead of restarting every update")
end

local function test_swing_alternates_a_and_b_and_resolves_the_hit_once()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "first swing should begin")
    local first = Neverbirth.Cleaver.GetState(player).swing
    assertEquals(first.variant, "A", "first swing must use the A animation")
    assertEquals(first.visual.animation, "SwingRight_A", "first swing must play SwingRight_A")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    assertEquals(env.getKnifeCount(), 1, "one complete swing must create only one hidden carrier")
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "second swing should begin after the full 22-tick animation")
    local second = Neverbirth.Cleaver.GetState(player).swing
    assertEquals(second.variant, "B", "second swing must alternate to the B animation")
    assertEquals(second.visual.animation, "SwingRight_B", "second swing must play SwingRight_B")
end
local function test_combat_targets_create_one_shadow_and_later_spawns_are_tracked()
    local env = loadNeverbirth()
    configureCleaver()
    local cleaver = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    local ally = env.newPlayer({ playerType = 0, position = Vector(20, 0) })
    local boss = env.newEnemy({ boss = true, position = Vector(60, 0), size = 30 })
    env.runPostUpdate()
    local bossShadow = shadowFor(boss, "enemy")
    assertTruthy(bossShadow, "boss should receive a shadow")
    assertTruthy(shadowFor(cleaver, "player"), "cleaver player should receive a shadow")
    assertTruthy(shadowFor(ally, "player"), "co-op player should receive a shadow")
    assertNear(bossShadow.position.X, 60, 0.001, "shadow should retain entry position")
    boss.Position = Vector(90, 0)
    assertNear(bossShadow.position.X, 60, 0.001, "shadow should not follow the target")
    local spawned = env.newEnemy({ position = Vector(40, 30) })
    local invulnerableSpawn = env.newEnemy({ position = Vector(45, 30), vulnerable = false, activeEnemy = true })
    env.runPostUpdate()
    assertTruthy(shadowFor(spawned, "enemy"), "wave, summon, and split spawns should receive shadows")
    assertTruthy(shadowFor(invulnerableSpawn, "enemy"), "an active spawning enemy should receive its shadow before it becomes vulnerable")
end

local function test_swing_hits_enemy_body_and_past_shadow_then_refreshes_shadow()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    local enemy = env.newEnemy({ position = Vector(50, 0), size = 10 })
    env.runPostUpdate()
    assertNear(Neverbirth.Cleaver.GetSwingRange(player), 160, 0.0001, "normal-size Stranger should reach the requested long cleaver range")
    enemy.Position = Vector(150, 0)
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "Stranger should start a melee swing")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingCarrierFallbackTick)
    local knife = env.getLatestKnife()
    assertTruthy(knife, "swing should own an EntityKnife carrier at its configured lifecycle tick")
    assertEquals(knife.EntityCollisionClass, EntityCollisionClass.ENTCOLL_NONE, "manual sweep must not expose a native circular hitbox")
    assertEquals(env.runKnifeCollision(knife, enemy), true, "the native carrier must suppress a duplicate body collision while the swing is active")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks - Neverbirth.Cleaver.Config.SwingCarrierFallbackTick)
    assertNear(enemy.damageTaken, 8.5, 0.0001, "one full sweep must deal 0.5 body damage plus one 2x Damage shadow hit")
    assertNear(enemy.Velocity.X, 8, 0.0001, "body hit must apply the configured strong knockback")
    local refreshed = shadowFor(enemy, "enemy")
    assertTruthy(refreshed, "living enemy should receive a refreshed shadow")
    assertNear(refreshed.position.X, 150, 0.001, "refreshed enemy shadow should use the target's current position")
    assertTruthy(refreshed.sprite and refreshed.sprite ~= enemy:GetSprite(), "past shadow must render a snapshot sprite rather than recoloring the live enemy sprite")
end

local function test_swing_sweeps_the_full_front_semicircle_without_repeating_hits()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    local upper = env.newEnemy({ position = Vector(90, -70), size = 8 })
    local center = env.newEnemy({ position = Vector(130, 0), size = 8 })
    local lower = env.newEnemy({ position = Vector(90, 70), size = 8 })
    env.runPostUpdate()
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "rightward A sweep should start")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    for _, enemy in ipairs({ upper, center, lower }) do
        assertNear(enemy.damageTaken, 8.5, 0.0001, "every side and center target in the front semicircle should receive body plus shadow settlement once")
    end
end

local function test_a_and_b_paths_are_opposite_for_all_input_directions()
    local cases = {
        { input = Vector(0, -1), aStart = Vector(-1, 0), aEnd = Vector(1, 0) },
        { input = Vector(0, 1), aStart = Vector(1, 0), aEnd = Vector(-1, 0) },
        { input = Vector(-1, 0), aStart = Vector(0, 1), aEnd = Vector(0, -1) },
        { input = Vector(1, 0), aStart = Vector(0, -1), aEnd = Vector(0, 1) },
    }
    for _, case in ipairs(cases) do
        local a = { direction = case.input, variant = "A" }
        local b = { direction = case.input, variant = "B" }
        local aStart, aEnd = Neverbirth.Cleaver.GetSweepDirection(a, 0), Neverbirth.Cleaver.GetSweepDirection(a, 1)
        local bStart, bEnd = Neverbirth.Cleaver.GetSweepDirection(b, 0), Neverbirth.Cleaver.GetSweepDirection(b, 1)
        assertNear(aStart.X, case.aStart.X, 0.0001, "A sweep must start on the authored first side")
        assertNear(aStart.Y, case.aStart.Y, 0.0001, "A sweep must start on the authored first side")
        assertNear(aEnd.X, case.aEnd.X, 0.0001, "A sweep must end on the authored opposite side")
        assertNear(aEnd.Y, case.aEnd.Y, 0.0001, "A sweep must end on the authored opposite side")
        assertNear(bStart.X, case.aEnd.X, 0.0001, "B sweep must reverse the A start/end path")
        assertNear(bStart.Y, case.aEnd.Y, 0.0001, "B sweep must reverse the A start/end path")
        assertNear(bEnd.X, case.aStart.X, 0.0001, "B sweep must reverse the A start/end path")
        assertNear(bEnd.Y, case.aStart.Y, 0.0001, "B sweep must reverse the A start/end path")
    end
end

local function test_swing_lasts_all_twenty_two_ticks()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0) })
    assertTruthy(Neverbirth.Cleaver.TrySwing(player, Vector(1, 0)), "swing should start")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks - 1)
    assertTruthy(Neverbirth.Cleaver.GetState(player).swing, "swing must remain active through tick 21")
    env.runPostUpdate()
    assertEquals(Neverbirth.Cleaver.GetState(player).swing, nil, "swing must finish only after the 22nd tick")
end
local function test_swing_reach_and_width_ignore_range_and_body_size()
    local env = loadNeverbirth()
    configureCleaver()
    local normal = env.newPlayer({ playerType = 42, size = 20, tearRange = 260 })
    local large = env.newPlayer({ playerType = 42, size = 80, tearRange = 800 })
    assertNear(Neverbirth.Cleaver.GetSwingRange(normal), Neverbirth.Cleaver.Config.BaseSwingRange, 0.0001, "normal Stranger reach must use the fixed config")
    assertNear(Neverbirth.Cleaver.GetSwingRange(large), Neverbirth.Cleaver.Config.BaseSwingRange, 0.0001, "body size and range must not change Stranger reach")
    assertNear(Neverbirth.Cleaver.GetSwingHalfWidth(normal), Neverbirth.Cleaver.Config.BaseSwingHalfWidth, 0.0001, "normal Stranger blade width must use the fixed config")
    assertNear(Neverbirth.Cleaver.GetSwingHalfWidth(large), Neverbirth.Cleaver.Config.BaseSwingHalfWidth, 0.0001, "body size and range must not change Stranger blade width")
end
local function test_one_swing_hits_multiple_shadows()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    local first = env.newEnemy({ position = Vector(50, 0), size = 8 })
    local second = env.newEnemy({ position = Vector(60, 20), size = 8 })
    env.runPostUpdate()
    Neverbirth.Cleaver.TrySwing(player, Vector(1, 0))
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    assertNear(first.damageTaken, 8.5, 0.0001, "first enemy should receive body and shadow damage once")
    assertNear(second.damageTaken, 8.5, 0.0001, "second enemy should receive body and shadow damage once")
end
local function test_player_shadow_recoil_uses_shadow_owner_damage_in_isaac_half_heart_units()
    for _, case in ipairs({
        { damage = 2.0, units = 0 }, { damage = 3.5, units = 0 }, { damage = 4.0, units = 1 },
        { damage = 4.5, units = 2 }, { damage = 5.5, units = 4 },
    }) do
        local env = loadNeverbirth()
        configureCleaver()
        local attacker = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 2 })
        local target = env.newPlayer({ playerType = 0, position = Vector(50, 0), damage = case.damage })
        env.newEnemy({ position = Vector(90, 0) })
        env.runPostUpdate()
        Neverbirth.Cleaver.TrySwing(attacker, Vector(1, 0))
        env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
        if case.units == 0 then
            assertEquals(#target.damageCalls, 0, "Shadow-owner Damage " .. tostring(case.damage) .. " should not recoil")
        else
            assertEquals(target.damageCalls[1].amount, case.units, "Shadow-owner Damage " .. tostring(case.damage) .. " should use correct Isaac half-heart units")
            assertEquals(target.damageCalls[1].source.Entity, attacker, "co-op recoil should damage the shadow owner using the attacker as source")
        end
        assertEquals(shadowFor(target, "player"), nil, "a hit player shadow should stay consumed for this room")
    end
end
local function test_self_shadow_uses_the_normal_player_damage_pipeline()
    local env = loadNeverbirth()
    configureCleaver()
    local stranger = env.newPlayer({ playerType = 42, position = Vector(0, 0), damage = 4 })
    env.newEnemy({ position = Vector(120, 0) })
    env.runPostUpdate()
    assertTruthy(shadowFor(stranger, "player"), "Stranger should have a self shadow in combat")
    assertTruthy(Neverbirth.Cleaver.TrySwing(stranger, Vector(1, 0)), "Stranger should swing at the self shadow")
    env.runPostUpdate(Neverbirth.Cleaver.Config.SwingDurationTicks)
    assertEquals(#stranger.damageCalls, 1, "self-shadow recoil must call Player:TakeDamage once")
    assertEquals(stranger.damageCalls[1].amount, 1, "Damage 4.0 should recoil for one Isaac half-heart unit")
    assertEquals(stranger.damageCalls[1].source.Entity, stranger, "self recoil should retain the attacking Stranger as normal damage source")
end
local function test_stat_caps_and_conversion_are_recalculated_from_raw_stats()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, damage = 3.5, maxFireDelay = 6.5, tearRange = 320, shotSpeed = 1.5 })
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.MaxFireDelay, 30 / 2.73 - 1, 0.0001, "tears display should cap at 2.73")
    assertNear(player.TearRange, 260, 0.0001, "range display should cap at 6.50")
    assertNear(player.ShotSpeed, 1.0, 0.0001, "shot speed display should cap at 1.00")
    assertNear(player.Damage, 2 + (0.40 * (4 - 2.73)) + 0.10 * (8 - 6.5) + 0.50 * (1.5 - 1), 0.0001, "positive raw overflow should convert to damage")

    player.Damage = 3.5
    player.MaxFireDelay = 14
    player.TearRange = 200
    player.ShotSpeed = 0.5
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.Damage, 2 + 0.40 * (2 - 2.73) + 0.10 * (5 - 6.5) + 0.50 * (0.5 - 1), 0.0001, "negative raw stats should reduce damage through the same conversion")
end

local function test_stat_conversion_respects_per_stat_and_total_caps()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42, damage = 3.5, maxFireDelay = 2, tearRange = 1000, shotSpeed = 5 })
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.Damage, 3.5, 0.0001, "positive conversions must cap at +1.50 total Damage")

    player.Damage = 3.5
    player.MaxFireDelay = 59
    player.TearRange = 0
    player.ShotSpeed = 0
    env.runEvaluate(player, CacheFlag.CACHE_FIREDELAY)
    env.runEvaluate(player, CacheFlag.CACHE_RANGE)
    env.runEvaluate(player, CacheFlag.CACHE_SHOTSPEED)
    env.runEvaluate(player, CacheFlag.CACHE_DAMAGE)
    assertNear(player.Damage, 0.5, 0.0001, "each negative conversion must clamp at -0.50 Damage")
end
local function test_item_loss_style_type_change_and_new_room_clear_runtime_state()
    local env = loadNeverbirth()
    configureCleaver()
    local player = env.newPlayer({ playerType = 42 })
    env.newEnemy()
    env.runPostUpdate()
    assertTruthy(next(Neverbirth.Cleaver.shadows) ~= nil, "enabled player should create combat shadows")
    player.PlayerType = 0
    env.runPostUpdate()
    assertEquals(Neverbirth.Cleaver.states[tostring(player.InitSeed)], nil, "changing away from the bound type should clear player state")
    assertEquals(next(Neverbirth.Cleaver.shadows), nil, "no enabled player should clear all shadows")
    player.PlayerType = 42
    env.runPostUpdate()
    env.runNewRoom()
    assertEquals(next(Neverbirth.Cleaver.shadows), nil, "new room should clear old room shadows")
    env.runGameStarted()
    assertEquals(next(Neverbirth.Cleaver.states), nil, "new game should not retain cleaver state")
end

test_stranger_is_unregistered_but_cleaver_assets_remain_available()
test_stranger_starts_with_cleaver_but_does_not_depend_on_the_item()
test_cleaver_has_a_persistent_handheld_visual_outside_swings()
test_non_cleaver_players_are_fully_isolated()
test_player_shooting_input_starts_a_swing_without_raw_trigger_state()
test_raw_shoot_trigger_starts_a_swing_and_spawns_the_native_hitbox_at_the_authored_frame()
test_post_fire_tear_resolves_player_owner_before_replacing_shot()
test_raw_shoot_trigger_uses_the_manual_cleaver_visual()
test_swing_uses_shared_scale_and_advances_at_thirty_fps()
test_swing_alternates_a_and_b_and_resolves_the_hit_once()
test_combat_targets_create_one_shadow_and_later_spawns_are_tracked()
test_swing_hits_enemy_body_and_past_shadow_then_refreshes_shadow()
test_swing_sweeps_the_full_front_semicircle_without_repeating_hits()
test_a_and_b_paths_are_opposite_for_all_input_directions()
test_swing_lasts_all_twenty_two_ticks()
test_swing_reach_and_width_ignore_range_and_body_size()
test_one_swing_hits_multiple_shadows()
test_player_shadow_recoil_uses_shadow_owner_damage_in_isaac_half_heart_units()
test_self_shadow_uses_the_normal_player_damage_pipeline()
test_stat_caps_and_conversion_are_recalculated_from_raw_stats()
test_stat_conversion_respects_per_stat_and_total_caps()
test_item_loss_style_type_change_and_new_room_clear_runtime_state()

local inputFixture = loadNeverbirth()
configureCleaver()
local keyboardPlayer = inputFixture.newPlayer({ playerType = 42, controllerIndex = 4294967294 })
Input.IsActionTriggered = function(action, controller)
    return action == ButtonAction.ACTION_SHOOTRIGHT and controller == keyboardPlayer.ControllerIndex
end
inputFixture.runPostUpdate()
assertTruthy(Neverbirth.Cleaver.GetState(keyboardPlayer).swing, "the raw shoot fallback must read the owning Repentance+ keyboard")
Input.IsActionTriggered = function(action, controller)
    return action == ButtonAction.ACTION_SHOOTRIGHT and controller == 0
end
assertEquals(Neverbirth.Cleaver.GetTriggeredShootDirection({}), nil, "the shoot fallback must not borrow controller zero")

print("cleaver character behavior tests passed")
