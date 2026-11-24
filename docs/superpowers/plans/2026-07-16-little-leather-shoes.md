# Little Leather Shoes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement Little Leather Shoes, deterministic enemy-return chains, floor-scoped traffic settlement, three hidden traffic rewards, HUD, localization, EID, and behavior tests for ordinary Repentance.

**Architecture:** Keep Neverbirth's existing monolithic registration model, but place all new runtime locals inside one trailing `do ... end` block in `main.lua`. Expose a narrow `Neverbirth.LittleLeatherShoesTestAPI` for deterministic pure state tests while real callbacks own entity snapshots, deferred spawns, room settlement, pickups, cache application, rendering, and persistence.

**Tech Stack:** Repentance Lua 5.3, Isaac Lua callbacks, XML item/item-pool registration, existing optional EID table, standalone Lua behavior tests, PowerShell/XML validation.

## Global Constraints

- Target ordinary Repentance; do not require Repentance+ callbacks or APIs.
- Preserve every existing uncommitted user change and do not refactor unrelated items.
- Stable local IDs are 32 Little Leather Shoes, 33 Traffic: Unboxing, 34 Traffic: Exposure, and 35 Traffic: Heat.
- A floor checks shoe ownership once at its start; mid-floor acquisition waits until the next floor.
- Mid-floor loss cancels pending returns and disables future returns, but traffic counting, HUD, and Boss settlement remain active.
- Bosses, minibosses, segmented entities, and runtime-detected death splitters never enter traffic chains.
- Normal callback paths return `nil`; only a genuinely deferred clear award may return `true`.
- EID is optional; unknown external room pools are not guessed.
- Do not create Git commits while the shared worktree contains unrelated uncommitted changes.

---

### Task 1: Register items, pools, localization, banners, EID, and stable My Stuff ID

**Files:**
- Modify: `content/items.xml`
- Modify: `content/items.en_us.xml`
- Modify: `content/items.zh_cn.xml`
- Modify: `content/itempools.xml`
- Modify: `content/itempools.en_us.xml`
- Modify: `content/itempools.zh_cn.xml`
- Modify: `main.lua`
- Modify: `tests/localization_test.lua`
- Modify: `docs/mystuff_item_id_migration.md`
- Modify: `resources/gfx/UI/NeverbirthDeathItems.png`

**Interfaces:**
- Produces: `Items.LittleLeatherShoes`, `Items.TrafficUnboxing`, `Items.TrafficExposure`, `Items.TrafficHeat`.
- Produces: bilingual entries in `EID_DESCRIPTIONS` and `RegisterPickupBannerText`.
- Produces: XML local IDs 32–35 and My Stuff frame 32 only.

- [ ] **Step 1: Extend localization assertions before XML changes**

Add four entries to `expectedXmlItems`, change the baseline count from 31 to 35, and assert IDs, hidden flags, tags, quality, exact pool weights, and exact pickup subtitles.

- [ ] **Step 2: Run the localization test and verify the new assertions fail**

Run: `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\localization_test.lua`

Expected: FAIL because Little Leather Shoes and the three traffic items are not registered.

- [ ] **Step 3: Append the four XML records and three pool entries**

Use `id="32" quality="2" tags="offensive summonable"` for Little Leather Shoes. Use IDs 33–35 with `quality="0" hidden="true" tags="noeden nochallenge nodaily nogreed"`. Add only Little Leather Shoes to treasure and shop at weight 1 and devil at weight 0.1, all with `DecreaseBy="1" RemoveOn="1"`.

- [ ] **Step 4: Add runtime names, EID descriptions, and bilingual banners**

Extend the existing tables, resolving both English and Chinese names. Register the exact approved subtitles through the existing pickup-banner path.

- [ ] **Step 5: Add My Stuff local ID 32**

Resize the existing PNG atlas only if required by its current cell layout, copy a scaled/centered Little Leather Shoes icon into cell 32, and record that the hidden IDs 33–35 intentionally have no My Stuff cells.

- [ ] **Step 6: Re-run localization and My Stuff validation**

Run the localization Lua test and `tools\validate_mystuff_local_ids.ps1`; both must pass.

### Task 2: Build deterministic floor, room, chain, and tier state with tests

**Files:**
- Create: `tests/little_leather_shoes_behavior_test.lua`
- Modify: `main.lua`

**Interfaces:**
- Produces: `Neverbirth.LittleLeatherShoesTestAPI.GetTier(traffic)`.
- Produces: `GetNextTrafficTarget(traffic)`, `GetRoomTraffic(chainDeaths)`, `GetReturnChance(deathCount)`, `ShouldReturn(roll, deathCount)`, `ApplyTearsBonus(maxFireDelay, heatCount)`, and `SetFloorEnabled(hasShoes)`.
- Produces runtime state `Neverbirth.LittleLeatherShoesState` with `floorEnabled`, `returnsEnabled`, `floorTraffic`, `rooms`, `pendingReturns`, `splitWatch`, `choiceGroups`, and visual queues.

- [ ] **Step 1: Write failing pure-state tests**

Assert exact 33/22/11/0 chances, maximum four deaths, max(5,6,2)=6, tier boundaries 5/6/7/8/11/12, next-target display, floor-lock behavior, and exact FireDelay conversion.

- [ ] **Step 2: Run the behavior test and verify it fails**

Run: `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\little_leather_shoes_behavior_test.lua`

Expected: FAIL because the test API and callbacks do not exist.

- [ ] **Step 3: Implement the pure helpers and state reset inside a trailing scope**

Use integer percent rolls in `[0,99]`; `roll < chance` succeeds. Room traffic ignores excluded chains and returns 0 for an empty set. FireDelay uses `30 / (30 / (delay + 1) + 0.5 * count) - 1`.

- [ ] **Step 4: Run the pure-state tests**

Expected: PASS for probability, tier, minimum, ownership, and tears conversion sections.

### Task 3: Integrate eligible NPC registration, dynamic split detection, deferred returns, and room settlement

**Files:**
- Modify: `main.lua`
- Modify: `tests/little_leather_shoes_behavior_test.lua`

**Interfaces:**
- Consumes: Task 2 state and pure helpers.
- Produces: callbacks `InitLittleLeatherShoesNpc(_, npc)`, `KillLittleLeatherShoesEntity(_, entity)`, `UpdateLittleLeatherShoes()`, `PreLittleLeatherShoesClearAward()`, `EnterLittleLeatherShoesRoom()`, and `EnterLittleLeatherShoesFloor()`.

- [ ] **Step 1: Extend tests with NPC factories and callback runners**

Test ordinary initial NPCs, waves, live summons, bosses, minibosses, segmented NPCs, death-spawned split children, deterministic deferred spawn, Champion/full-HP restoration, cancellation after shoe loss, and callback return values.

- [ ] **Step 2: Run the extended test and verify failures**

Expected: FAIL at the first missing NPC registration or deferred-return assertion.

- [ ] **Step 3: Implement registration and exclusion predicates**

Require active hostile vulnerable NPCs; reject boss identity, any valid parent/child relation, valid grouped segments, and entities tagged by the two-frame death-split observation. Do not reject a live summon only because it has a spawner.

- [ ] **Step 4: Implement death snapshots and deterministic deferred return**

Snapshot Type/Variant/SubType/Champion/MaxHitPoints/position and chain metadata in `MC_POST_ENTITY_KILL`. Observe death children before rolling; schedule successful returns for the next update; never spawn inside the kill callback.

- [ ] **Step 5: Implement deferred clear and one-time room settlement**

Return `true` from `MC_PRE_SPAWN_CLEAN_AWARD` only while a split observation or return remains pending. Once released, settle `min(chain deaths)` once and invoke `Room:SpawnClearAward()` once.

- [ ] **Step 6: Run behavior tests**

Expected: PASS for enemy eligibility, split exclusion, return chain, room minimum, re-entry, ownership-loss, and clear-award contracts.

### Task 4: Implement Boss traffic rewards, derivative pickups, mutual choice, Heat persistence, and HUD

**Files:**
- Modify: `main.lua`
- Modify: `tests/little_leather_shoes_behavior_test.lua`

**Interfaces:**
- Consumes: Task 2 tier helpers and Task 3 one-time room settlement.
- Produces: `SpawnTrafficBossReward(tier)`, `InitTrafficPickup(_, pickup)`, `HandleTrafficPickupCollision(_, pickup, collider)`, `EvaluateTrafficHeat(_, player, cacheFlag)`, and `RenderLittleLeatherShoesHud()`.
- Persists: `musicboxSaveData.littleLeatherShoes.heatByPlayer[playerKey]` through the existing `SaveMusicboxData()`.

- [ ] **Step 1: Add failing reward and pickup tests**

Assert 5 none; 6/7 Unboxing; 8/11 Exposure; 12+ Exposure+Heat; Boss reset; pickup-time room pool; chest after animation; atomic choice removal; one Heat increment per genuine pickup; stable repeated cache; separate players.

- [ ] **Step 2: Run tests and verify failures**

Expected: FAIL at missing Boss reward generation.

- [ ] **Step 3: Implement deferred Boss reward spawning**

Spawn tier pedestals only after original Boss clear award timing. Attach one choiceGroup to the level-3 pair and spawn `traffic_choice_link` between them.

- [ ] **Step 4: Implement derivative pedestal collision and effects**

Record before-count and source seed, confirm acquisition on update, then consume the hidden collectible. Unboxing queues its Pickup animation and chest. Exposure calls `GetPoolForRoom(currentRoomType, currentRoomSeed)` at confirmed pickup time and spawns the returned collectible. Level-3 choice is locked and sibling removed at collision time. Every normal collision path returns `nil`.

- [ ] **Step 5: Implement Heat save/cache and HUD rendering**

Increment saved per-player Heat only on confirmed acquisition, call `AddCacheFlags(CACHE_FIREDELAY)` and `EvaluateItems()`, and apply the pure FireDelay conversion in `MC_EVALUATE_CACHE`. Render current traffic, remaining points or MAX, and the existing level animation only while the floor is enabled.

- [ ] **Step 6: Run behavior tests**

Expected: PASS for all tier, reward, pickup, choice, Heat, HUD-state, and reset assertions.

### Task 5: Full validation and diff audit

**Files:**
- Verify all files modified in Tasks 1–4.

**Interfaces:**
- Produces: syntax-clean, XML-parseable, behavior-tested implementation with no unrelated rollback.

- [ ] **Step 1: Parse Lua**

Run: `C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe -p main.lua`

Expected: exit 0.

- [ ] **Step 2: Run focused behavior and localization tests**

Run the new Little Leather Shoes behavior test and `tests\localization_test.lua`.

Expected: both print their pass messages.

- [ ] **Step 3: Run project regression tests**

Run all existing `tests\*_behavior_test.lua` files with the local Lua executable.

Expected: every script exits 0.

- [ ] **Step 4: Parse every content XML file**

Use PowerShell `[xml](Get-Content -Raw <path>)` for each `content\*.xml`.

Expected: no parse exceptions.

- [ ] **Step 5: Run validators and whitespace audit**

Run `tools\validate_mystuff_local_ids.ps1`, the Neverbirth validator profile, and `git diff --check`.

Expected: no errors in the files owned by this feature.

- [ ] **Step 6: Review the exact scoped diff**

Confirm only IDs 32–35 were appended, only the three approved pool entries were added, no unrelated callback/helper was changed, and all normal callback paths preserve original gameplay.
