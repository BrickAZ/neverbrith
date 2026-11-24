# Big Dog Chew Maturity Implementation Plan

> **For Codex:** Execute this plan inline with test-driven development. Do not touch unrelated Neverbirth systems.

**Goal:** Replace the current direct-contact autonomous chew with a mature event-driven chase, windup, lunge, hit, recover, and cooldown state machine that consumes the new Big Dog ANM2 events.

**Architecture:** Keep the existing owner-bound Effect entity and cached room target registry. Extend each player's runtime state with target/path/lunge/safe-position fields. Use ANM2 events as the only attack timing source, a cached grid BFS only when line-of-sight movement is blocked, and mark a target as chewed only after accepted non-zero damage.

**Tech Stack:** Repentance Lua callbacks, Effect/Sprite APIs, project Lua behavior tests, `luac` syntax validation.

---

### Task 1: Lock the animation and state contract in tests

**Files:**
- Modify: `tests/big_dog_bark_behavior_test.lua`
- Verify: `resources/gfx/Effects/BigDogBark/big_dog_entity.anm2`

1. Extend the Sprite stub with one-frame `IsEventTriggered` support.
2. Assert the Run/Bite animations and `BiteLungeStart`, `BiteHit`, `BiteEnd` events.
3. Replace old contact-radius constants with the approved approach/lunge/hit/path constants.
4. Add a behavior test proving windup does not damage, lunge locks direction, BiteHit damages only the locked target once, accepted damage marks the room target, BiteEnd enters a 20-frame cooldown, and missing Bite events do not silently fall back to frame numbers.
5. Run the behavior test and confirm RED failures are due to the missing state-machine implementation.

### Task 2: Implement the event-driven chew state machine

**Files:**
- Modify: `big_dog_bark.lua`

1. Add approved constants and per-player transient fields.
2. Add directional animation selection and safe Sprite event helpers without per-frame Sprite loading.
3. Implement target acquisition and direct chase with interpolated velocity.
4. Enter Bite windup within 80 pixels and track the target until `BiteLungeStart`.
5. Lock lunge direction, travel at most 72 pixels at 12 pixels/frame, and resolve only the locked target through a 24-pixel capsule at `BiteHit`.
6. Mark the target chewed only when `TakeDamage` accepts a positive 10%-max-HP hit.
7. Complete recovery only on `BiteEnd`, then enforce the existing exact 20-frame cooldown.
8. Preserve explicit active launch priority and reject launch during windup/lunge/recover/cooldown.

### Task 3: Add cached obstacle routing and rescue

**Files:**
- Modify: `big_dog_bark.lua`
- Modify: `tests/big_dog_bark_behavior_test.lua`

1. Add a room line check for direct chase.
2. Add a four-neighbor grid BFS using only passable cells, cached per target and refreshed at most every 12 frames or when blocked/changed.
3. Save the latest valid dog position and rescue there after repeated path failures; use the owner position only when no saved point is valid.
4. Add tests for stable cached paths, refresh timing, and no global room entity scan in the effect hot path.

### Task 4: Lifecycle cleanup and verification

**Files:**
- Modify: `big_dog_bark.lua`
- Modify: `tests/big_dog_bark_behavior_test.lua`

1. Clear all new path/lunge/event fields on room change, owner loss, reset, and transient cleanup.
2. Run:
   - `C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe -p big_dog_bark.lua`
   - `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\big_dog_bark_behavior_test.lua`
   - `powershell -ExecutionPolicy Bypass -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .`
   - `git diff --check`
3. Report static proof separately from required in-game verification: moving targets, obstacle routing, event timing, co-op ownership, and active-use interruption boundaries.
