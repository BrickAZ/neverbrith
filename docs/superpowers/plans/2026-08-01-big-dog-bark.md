# Big Dog Bark Implementation Plan

> **For Codex:** Follow this plan test-first and preserve every unrelated dirty-worktree change.

**Goal:** Add Big Dog Bark, Wind Charge Rod, Echo Shard, and Wind Charge Potion with player-owned dash, echo, pollution trail, food-pickup chew unlock, and saved potion state in ordinary Repentance.

**Architecture:** A new `big_dog_bark.lua` module owns all four mechanics. Big Dog, echo, and pollution are registered Effect entities with player-owned runtime data. `main.lua` only resolves IDs, supplies existing save/player helpers, registers text, and initializes the module.

**Tech Stack:** Isaac Repentance Lua callbacks, XML content registration, ANM2 entity atlases, existing JSON save root, Lua 5.4 behavior tests.

---

## Task 1: Lock registration and behavior contracts in a failing test

**Files:**

- Create: `tests/big_dog_bark_behavior_test.lua`
- Read: `tests/debug_controller_behavior_test.lua`
- Read: `tests/condom_utility_knife_behavior_test.lua`
- Read: `tests/strong_laxative_behavior_test.lua`
- Read: `tests/dog_food_series_behavior_test.lua`

1. Build the standard `RegisterMod`, callback, `Game`, `Isaac`, `Vector`, player, NPC, pickup, and Effect stubs used by current tests.
2. Assert three items XML variants register local IDs 48–50 with the locked names and only Big Dog Bark has `quality="3" maxcharges="0"`.
3. Assert only Big Dog Bark is added to treasure with `Weight="1" DecreaseBy="1" RemoveOn="1"`.
4. Assert pocketitems and entities2 registrations, ANM2 paths, and animation names.
5. Load `main.lua`, obtain `Neverbirth.BigDogBarkTestAPI`, and assert exact callback signatures/normal return contracts.
6. Add failing pure-behavior assertions for charge formula, direction fallback/reversal, busy locks, body/echo formulas, potion multipliers, and co-op isolation.
7. Run the test and confirm it fails because registration/module APIs are absent.

## Task 2: Register items, pill, entities, language, and art contracts

**Files:**

- Modify: `content/items.xml`
- Modify: `content/items.en_us.xml`
- Modify: `content/items.zh_cn.xml`
- Modify: `content/itempools.xml`
- Modify: `content/itempools.en_us.xml`
- Modify: `content/itempools.zh_cn.xml`
- Create: `content/pocketitems.xml`
- Create: `content/pocketitems.en_us.xml`
- Create: `content/pocketitems.zh_cn.xml`
- Modify: `content/entities2.xml`
- Create: `resources/gfx/Effects/BigDogBark/big_dog_entity.anm2`
- Create: `resources/gfx/Effects/BigDogBark/big_dog_echo.anm2`
- Create: `resources/gfx/Effects/BigDogBark/big_dog_creep.anm2`
- Modify (generated): `generated/neverbirth_collectibles.lua`

1. Append ID 48 Big Dog Bark active, ID 49 Wind Charge Rod passive, and ID 50 Echo Shard passive in all items files.
2. Keep Rod/Shard quality absent and omit pool entries because those metadata are deliberately unassigned.
3. Add Big Dog Bark only to treasure with the exact locked pool fields.
4. Add Wind Charge Potion as a custom pill effect in all pocketitems files.
5. Register Effect variants 3017, 3018, and 3019 with collision-free entity metadata.
6. Build ANM2 files from the verified 96×96 atlas grids and exact animation names in the approved design.
7. Run the existing collectible generator so the Certificate gallery automatically includes IDs 48–50.
8. Re-run the registration section of the behavior test.

## Task 3: Bootstrap the module and save state

**Files:**

- Modify: `main.lua`
- Create: `big_dog_bark.lua`

1. Add English/Chinese candidate names and resolve the three collectible IDs.
2. Initialize `musicboxSaveData.bigDogBark` in the existing save loader.
3. Include `big_dog_bark.lua` after existing feature initialization and inject: item IDs, save root, save callback, run seed, player enumeration, item-config access, logger, and entity variants.
4. Register optional EID descriptions without making EID a dependency.
5. Add pickup-banner names with mechanically descriptive subtitles only.
6. In the module, implement run-seed validation and player records containing only `foodPickups`, `chewUnlocked`, and `potionArmed`.
7. Expose one `Neverbirth.BigDogBarkTestAPI` over production functions.

## Task 4: Implement input, direction, dog spawning, and body dash

**Files:**

- Modify: `big_dog_bark.lua`
- Modify: `tests/big_dog_bark_behavior_test.lua`

1. Add pure vector helpers, `GetChargeSeconds`, `GetChargeFrames`, direction resolution, active-slot action mapping, and busy-state checks.
2. Add `MC_USE_ITEM` normal charging and Rod instant reverse launch, always returning non-discharge/non-remove.
3. Add `MC_POST_PLAYER_UPDATE` movement-history recording, hold/release detection, early cancellation, and successful release.
4. Spawn one owner-bound dog Effect for each holder and recreate it only when missing.
5. Implement follow/charge/dash animation selection and 320/480-pixel dash movement.
6. Use local `FindInRadius` hit detection and one-hit-per-dash identity tables.
7. Apply exact body damage and potion knockback/cap; consume potion state only after dash state starts successfully.
8. Run charge/direction/dash/co-op tests.

## Task 5: Implement echo and pollution trail

**Files:**

- Modify: `big_dog_bark.lua`
- Modify: `tests/big_dog_bark_behavior_test.lua`

1. Save actual dash start/end and spawn one Echo Effect only if the owner currently holds Echo Shard.
2. Wait 12 frames, replay the exact path at the same speed, use an independent hit table, and apply the exact 50% formula.
3. Generate/refresh trail Effects every 4 frames and at endpoints; merge nearby/intersecting trails across owners and preserve contributor seeds.
4. In Effect updates, submit local enemy hit candidates only; never call `GetRoomEntities` from the trail hot path.
5. In `MC_POST_UPDATE`, apply one highest trail damage event and one slowing call per enemy per frame.
6. Expire trails after 150 frames and clear stale contributor/entity references.
7. Run echo/trail/overlap/no-player-damage tests.

## Task 6: Implement actual food pickup tracking and autonomous chew

**Files:**

- Modify: `big_dog_bark.lua`
- Modify: `tests/big_dog_bark_behavior_test.lua`

1. Add collectible-pedestal `MC_PRE_PICKUP_COLLISION` snapshots filtered by ItemConfig `TAG_FOOD`.
2. Settle after two frames only when that pedestal produced a real item acquisition; count one event per pedestal instance and persist immediately.
3. Permanently unlock chew for that player on the fourth confirmed food event, including food picked before obtaining Big Dog Bark.
4. Scan the room once on entry and append newly initialized vulnerable enemies via `MC_POST_NPC_INIT`.
5. Implement per-player/per-room target identity, chase, 10% max-health chew hit, and exact 20-frame pause.
6. Treat seek, chew, and pause as active busy states; resume target logic immediately after body dash.
7. Run food-source, wave/summon/split/Boss, pause, room reset, save, and co-op tests.

## Task 7: Implement pill callback and lifecycle cleanup

**Files:**

- Modify: `big_dog_bark.lua`
- Modify: `tests/big_dog_bark_behavior_test.lua`

1. Resolve the custom pill effect by name and register filtered `MC_USE_PILL` with exact arguments.
2. Arm a boolean once; repeated pills leave it true without a counter.
3. Preserve arm/food/unlock across room, floor, and continued runs.
4. Clear dog/echo/trail/charge/chew/target/hit transient state on room, floor, death, new run, game exit, or premature entity loss as appropriate.
5. Ensure one player's callbacks never mutate another player's records or entities.
6. Run pill and lifecycle sections of the behavior test.

## Task 8: Full validation and handoff

**Files:**

- Modify if needed: `tests/localization_test.lua`

1. Run `luac -p main.lua` and `luac -p big_dog_bark.lua`.
2. Run `lua tests/big_dog_bark_behavior_test.lua`.
3. Run `lua tests/localization_test.lua`.
4. Parse every `content/*.xml` file.
5. Run the current neverbrith validator profile if its script exists.
6. Run `git diff --check` and inspect only task-owned diffs.
7. Report modified files, collectible/entity/pill IDs, ANM2 animation names, state machine, deliberately unassigned metadata, exact test output, and in-game verification checklist.
