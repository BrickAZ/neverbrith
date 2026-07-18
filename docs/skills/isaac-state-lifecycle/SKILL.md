---
name: isaac-state-lifecycle
description: Design, implement, review, or write handoff prompts for state lifecycle in Binding of Isaac Repentance neverbrith mechanics. Use this whenever a task mentions temporary state, GetData(), local tables, per-player data, room/floor/run reset, challenge-only state, active-item mode, cooldowns, timers, delayed effects, SaveData/LoadData, reload safety, seeded keys, or bugs that persist/leak between rooms, floors, runs, players, or game reloads.
---

# Isaac State Lifecycle

Use this skill whenever a mechanic needs memory.

The goal is to make state ownership explicit. Isaac mods often look correct for one room and then break after a room transition, save/reload, second player, item loss, challenge exit, or repeated callback.

## First Move

Before editing or writing a prompt:

1. Identify every piece of state the mechanic needs.
2. Assign each state piece an owner: player, entity, room, floor, run, challenge, item instance, UI mode, or saved mod data.
3. Define when the state is created, updated, read, reset, and destroyed.
4. Decide whether the state must survive save/reload. If not, keep it runtime-only.

Read `references/state-ownership.md`, then choose the reset/save references as needed.

## Route The State

- **Runtime owner**: player `InitSeed`, entity `GetData()`, room-local tables, UI state, active-item mode, cooldowns, timers. Read `references/state-ownership.md`.
- **Reset lifecycle**: new room, new level, new run, challenge start/end, player death, item loss, entity remove, game exit. Read `references/reset-lifecycle.md`.
- **Saved data**: `SaveData`, `LoadData`, JSON/plain table serialization, versioning, reload reconstruction. Read `references/savedata.md`.
- **Final review**: read `references/state-review-checklist.md`.

## Hard Rules

- Do not store live `Entity`, `Player`, `Sprite`, `Room`, or other userdata in saved data.
- Do not key player state by player index alone when twins/co-op or reordering can matter. Prefer stable seeds or existing project helper patterns.
- Do not leave room-only effects in run-level tables without room cleanup.
- Do not reset persistent run state on every frame or every render callback.
- Do not mutate gameplay state in pure render callbacks unless the existing repo already uses that exact pattern for a reason.
- If a state can leak into normal runs from a challenge or into other players, add an explicit gate and cleanup rule.
- If the user did not specify persistence, default to runtime-only and mark persistence as `TBD` in handoff prompts.

## Handoff Prompt Template

```markdown
## State Lifecycle Spec

- Mechanic:
- State fields:
- State owner:
- Keying strategy:
- Create/update/read callbacks:
- Reset conditions:
- Save/reload behavior:
- Userdata that must not be serialized:
- Leak-prevention gates:
- Tests/manual checks:
```

## Final Review

Before saying the stateful mechanic is complete, report:

- Every state owner and key.
- The callbacks that create/update/reset it.
- Whether it is runtime-only or saved.
- How reload, room transition, floor transition, death, and challenge exit behave.
- Any manual in-game lifecycle checks still needed.
