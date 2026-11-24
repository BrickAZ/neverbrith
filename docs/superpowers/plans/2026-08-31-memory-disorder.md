# Memory Disorder Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement the `Memory Disorder` passive as a per-player, deterministic, reversible room-entry character transformation with temporary component/health ledgers and a run-persistent optional Void entrance entitlement.

**Architecture:** `main.lua` remains the bootstrap and save-root provider. A new `memory_disorder.lua` module owns all runtime behavior and exposes a focused test API. Registration uses stable local id 55 and the vanilla Breakfast colored icon as the static fallback; no pool, tags, weight, ANM2, or third-party dependency is added.

**Tech Stack:** Isaac Repentance Lua API, project `include(...)` modules, XML content registration, project JSON SaveData root, standalone Lua behavior tests, PowerShell validators.

## Global Constraints

- Preserve every pre-existing working-tree change and do not reformat unrelated code.
- Do not add REPENTOGON, StageAPI, EID, or another dependency as a requirement.
- Use real `EntityPlayer:ChangePlayerType`; a costume-only result is forbidden.
- Pickup room never transforms; the next actual room entry starts a 30-frame transition and switches on frame 15.
- Losing the last copy immediately restores the pre-pickup character and removes only owned temporary identity components; the run Void flag persists.
- Pool, weight, and tags remain absent from source because the user has not approved them.
- Static, scripted, and in-game evidence remain separate.

---

### Task 1: Contract-first behavior fixture

**Files:**
- Create: `tests/memory_disorder_behavior_test.lua`
- Read: `tests/yins_curse_behavior_test.lua`
- Read: `tests/night_of_the_cowards_behavior_test.lua`

**Interfaces:**
- Consumes: module initializer `dofile("memory_disorder.lua")(mod, context)`.
- Produces: fixture callbacks plus `api.Constants`, `api.GetRuntimeState`, `api.GetSavedState`, `api.BuildVanillaCandidates`, `api.BeginRoomTransitions`, `api.AdvanceFrame`, `api.ResolveIdentitySwitch`, `api.OnOwnershipUpdate`, and `api.TrySpawnVoidPortal`.

- [ ] Write a failing Lua test fixture with callable `Vector`, `RNG`, `Game`, `Isaac.GetPersistentGameData`, `ItemConfig`, `EntityPlayer`, active/pocket slots, heart methods, callback registry, and two distinct players.
- [ ] Add failing assertions for pickup-room no-switch, next-room transition frame 15, frame 30 cleanup, repeat-room switching, and loss restoring the original type.
- [ ] Add failing assertions for unlocked-profile filtering, deterministic candidate choice, empty mod whitelist, temporary component removal, permanent same-ID preservation, active/pocket restoration, and health preservation.
- [ ] Add failing assertions for per-player isolation, Breakfast ID 25 icon fallback, icon selection not granting items, run Void flag persistence after item loss, new-run reset, legal-node portal attempt, and ordinary-boss rejection.
- [ ] Run `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\memory_disorder_behavior_test.lua` and verify it fails because `memory_disorder.lua` does not exist.

### Task 2: Registration and bootstrap shell

**Files:**
- Modify: `content/items.xml`
- Modify: `content/items.en_us.xml`
- Modify: `content/items.zh_cn.xml`
- Modify: `generated/neverbirth_collectibles.lua`
- Modify: `main.lua`
- Create: `memory_disorder.lua`

**Interfaces:**
- Consumes: `Items.MemoryDisorder`, `GetPlayers`, `GetCurrentRunSeed`, `EnsureMusicboxDataLoaded`, `SaveMusicboxData`, `musicboxSaveData`.
- Produces: `initializeMemoryDisorder(Neverbirth, context)` and `Neverbirth.MemoryDisorderTestAPI`.

- [ ] Append local id 55 as a Q0 passive named `Memory Disorder`; set `gfx="Collectibles_025_Breakfast.png"`; omit tags and all pool entries.
- [ ] Add English `Memory Disorder / Who am I?` and Chinese `记忆紊乱 / 我是谁？` registrations with the same local id and gfx fallback.
- [ ] Append the generated collectible mapping `{ localId = 55, englishName = "Memory Disorder", names = { "Memory Disorder", "记忆紊乱" } }`.
- [ ] Add item-name lookup, EID copy, pickup-banner copy, `musicboxSaveData.memoryDisorder` initialization, and a final bootstrap include that injects save/player/run-seed helpers.
- [ ] Create a minimal module that returns the required test API and registers no unsafe guessed callback.
- [ ] Run the focused test and confirm failures have moved from missing module to unimplemented behavior assertions.

### Task 3: Deterministic profiles and room transition state machine

**Files:**
- Modify: `memory_disorder.lua`
- Modify: `tests/memory_disorder_behavior_test.lua`

**Interfaces:**
- Produces: `VANILLA_CHARACTER_PROFILES`, public empty `MemoryDisorderCharacterProfiles`, `buildUnlockedCandidates(player)`, `chooseProfile(state, roomIdentity)`, and transition phases `idle -> darkening -> switch -> lightening -> idle`.

- [ ] Define explicit selectable vanilla profiles for PlayerTypes 0–10, 13–16, 18–19, and 21–37 using the achievement ids read from `resources-dlc3/players.xml`.
- [ ] Exclude internal derived types 11, 12, 17, 20, 38, 39, and 40 from the top-level candidate list.
- [ ] Gate non-Isaac profiles through the discovered persistent unlock API; on API failure return Isaac only and log once.
- [ ] Seed a per-player RNG from current run seed, stable player key, and transition serial; allow consecutive repeats.
- [ ] Detect acquisition by count edge, save the original PlayerType, set the run Void flag, and arm only the next room entry.
- [ ] Start one transition per holder on `MC_POST_NEW_ROOM`; advance it only from one update authority; resolve the identity once at frame 15 and destroy it after frame 29.
- [ ] On last-copy loss, cancel any transition, remove temporary identity state, restore original type, and retain the saved Void entitlement.
- [ ] Run the focused tests and keep them green before continuing.

### Task 4: Reversible temporary components, slots, and health

**Files:**
- Modify: `memory_disorder.lua`
- Modify: `tests/memory_disorder_behavior_test.lua`

**Interfaces:**
- Produces: `captureIdentitySnapshot`, `removeTemporaryKit`, `changePlayerType`, `captureAutomaticKitDelta`, `applyProfileKit`, `captureHealthLedger`, `applyHealthForProfile`, `restorePermanentSlots`, and `restoreOriginalIdentity`.

- [ ] Snapshot primary, secondary, pocket active, and both pocket consumable slots with normal/battery charge before the first temporary identity occupies them.
- [ ] Remove only ledger-owned temporary collectible counts, then calculate automatic post-`ChangePlayerType` deltas before adding any missing profile components.
- [ ] Apply explicit `players.xml` starting collectibles and pocket actives for profiles that declare them; record every actual addition in the temporary ledger.
- [ ] Restore permanent active/pocket slots and their charges when leaving an identity or losing the item.
- [ ] Capture max red, red, soul/black, bone, rotten, eternal, golden, and broken heart surfaces before a switch; preserve non-carryable values in the latent ledger.
- [ ] Apply Lost, Keeper, Forgotten/Soul, Bethany, and ordinary-character health adapters without resetting to character starting HP.
- [ ] Use `GetOtherTwin` when present for twin/soul branches; when absent, keep the real PlayerType, emit a one-time compatibility diagnostic, and expose the missing branch in the test API rather than spawning a fake player.
- [ ] Add and run tests for same-ID permanent content, slot charge restoration, real damage persistence, non-carryable latent health, and two-player independence.

### Task 5: Presentation and random icon state

**Files:**
- Modify: `memory_disorder.lua`
- Modify: `tests/memory_disorder_behavior_test.lua`

**Interfaces:**
- Produces: `transitionDarkness(frame)`, `renderTransitionOverlay`, `buildIconCandidates`, and per-player `currentIconId`.

- [ ] Implement pure darkness calculation: frame 0 is clear, frame 14 is maximum, frame 15 remains maximum, frame 29 returns to clear, frame 30 has no overlay state.
- [ ] Keep rendering presentation-only and suppress it when paused/menu state or the chosen render pass would place it over HUD; if the base callback cannot prove HUD separation, route through the already-used `Game():Darken` call and retain in-game calibration as required evidence.
- [ ] Build and cache visible collectible icon candidates from `ItemConfig`, excluding self, invalid entries, and empty gfx paths.
- [ ] Select and save an icon ID at each successful identity switch; if the list is empty select collectible 25.
- [ ] Do not call `AddCollectible` for icon selection and do not create a new HUD panel.
- [ ] Add scripted tests for the darkness curve, interruption cleanup, candidate filtering, deterministic icon choice, and no inventory mutation.

### Task 6: Run-persistent Void entitlement and portal eligibility

**Files:**
- Modify: `memory_disorder.lua`
- Modify: `tests/memory_disorder_behavior_test.lua`

**Interfaces:**
- Produces: `isVoidTerminalNode(roomContext)`, `hasExistingVoidPortal`, `trySpawnVoidPortal`, new-run reset, continue reconstruction, and one-room spawn deduplication.

- [ ] Save `memoryDisorderVoidUnlockedThisRun=true` on the first acquisition edge and save immediately.
- [ ] Preserve it through item loss and continued games with the same run seed; reset it when a non-continued new run starts or the run seed changes.
- [ ] Express terminal eligibility as an explicit stage/room/boss predicate and reject ordinary Boss, Mom, and Mom's Heart contexts.
- [ ] After an eligible terminal room is cleared, reuse an existing native portal if present; otherwise spawn exactly one `EffectVariant.PORTAL_TELEPORT` native Void portal at a safe room position.
- [ ] Never teleport the player and never remove or replace unrelated portals.
- [ ] Add tests for entitlement persistence, new-run reset, deduplication, legal node, ordinary boss rejection, and no-holder-but-entitled behavior.
- [ ] Mark portal destination and the exact supported terminal-node set as mandatory real-game evidence; the Lua fixture proves only the owned predicate and spawn request.

### Task 7: Verification and handoff

**Files:**
- Modify only if a focused test exposes a defect in the files listed above.

**Interfaces:**
- Produces: reproducible static/scripted results and a separate in-game checklist.

- [ ] Run `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\memory_disorder_behavior_test.lua`.
- [ ] Run `C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe -p memory_disorder.lua` and the closest available full-entry load check for `main.lua`.
- [ ] Run `powershell -ExecutionPolicy Bypass -File docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1 -Root .` if the file exists.
- [ ] Run `powershell -ExecutionPolicy Bypass -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .` if the file exists.
- [ ] Run focused localization/registration tests and then `git diff --check -- memory_disorder.lua tests/memory_disorder_behavior_test.lua main.lua content/items.xml content/items.en_us.xml content/items.zh_cn.xml generated/neverbirth_collectibles.lua docs/superpowers/specs/2026-08-31-memory-disorder-design.md docs/superpowers/plans/2026-08-31-memory-disorder.md`.
- [ ] Report static, scripted, and in-game results separately. Do not call Jacob/Esau, Forgotten/Soul, Tainted Jacob, Eden resource generation, overlay/HUD order, save/continue, or native Void traversal complete until each has actual in-game evidence.
