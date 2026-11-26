---
name: isaac-state-lifecycle
description: Design, implement, review, or write handoff prompts for state lifecycle in Binding of Isaac Repentance mechanics. Use this whenever a task mentions temporary state, GetData(), local tables, per-player data, room/floor/run reset, challenge-only state, active-item mode, cooldowns, timers, delayed effects, SaveData/LoadData, reload safety, seeded keys, or bugs that persist/leak between rooms, floors, runs, players, or game reloads. Use isaac-mod-context first in an unfamiliar project. 中文触发：状态、临时状态、计时、冷却、换房、换层、重开、死亡、道具丢失、挑战泄漏、存档、读档、延迟结算。
---

# Isaac State Lifecycle

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

Use this skill whenever a mechanic needs memory.

Keep a user-specified lifecycle boundary unchanged. Treat omitted persistence and reset behavior as `TBD` rather than silently selecting a design rule.

The goal is to make state ownership explicit. Isaac mods often look correct for one room and then break after a room transition, save/reload, second player, item loss, challenge exit, or repeated callback.

This skill owns storage and reset, not the meaning of the mechanic. When trigger, success/failure, exclusion, or settlement is still ambiguous, use `isaac-mechanic-contracts` first.

## REPENTOGON Companion

For declared REPENTOGON state, select only the relevant companion:
`isaac-repentogon-callbacks` for load/unload and inventory event timing,
`isaac-repentogon-world` for shared maxima, world references and preview state,
or `isaac-repentogon-ui` for owned UI teardown. Their matching-build lifecycle
contracts take precedence over vanilla-only timing assumptions. This skill owns
stable keys, serialization and recovery; native persisted state must not gain a
second competing SaveData authority.

## First Move

Before editing or writing a prompt:

1. In an unfamiliar project, use `isaac-mod-context` to identify module owners, supported test entry points, and existing state conventions.
2. Identify every piece of state the mechanic needs.
3. Assign each state piece an owner: player, entity, room, floor, run, challenge, item instance, UI mode, or saved mod data.
4. Define when the state is created, updated, read, reset, and destroyed.
5. Record whether the state must survive save/reload. If the user did not specify it, keep save/reload behavior as `TBD`; do not decide it merely from storage convenience.

Read `references/state-ownership.md`, then choose the reset/save references as needed.

## Route The State

- **Runtime owner**: discovered per-player data or a verified player key,
  entity `GetData()`, room-local tables, UI state, active-item mode,
  cooldowns, timers. Read `references/state-ownership.md`.
- **Deferred tasks**: pending closures, delayed initialization, cancellation,
  expiry and owner-generation invalidation. Read
  `references/deferred-task-lifetime.md`; a later callback is neither automatic
  readiness nor permission to reuse stale player/room/module references.
- **Reset lifecycle**: new room, new level, new run, challenge start/end, player death, item loss, entity remove, game exit. Read `references/reset-lifecycle.md`.
- **Saved data**: `SaveData`, `LoadData`, JSON/plain table serialization, versioning, reload reconstruction. Read `references/savedata.md`.
- **Paired-player reconstruction**: custom main/child relationships, controller
  rebinding and parked-body state across exit/continue. Read
  `references/paired-player-reconstruction.md`; current player-list indices and
  a UUID saved without a proven entity reattachment route are not persistence
  strategies.
- **Module instances and cached closures**: stale Mod/entity references, query caches, teardown, rebinding and loader-versus-registration lifetime. Read `references/module-instance-lifecycle.md`; loader selection and export shape belong to `isaac-mod-architecture`.
- **In-run character switch state**: use `isaac-character-switching` as primary
  for capture/mutate/reacquire/reconcile/commit order. This skill owns stable
  keys, serialization, continue/reset and reconstruction, not the identity or
  health conversion itself.
- **Pending entitlement**: a reward earned now but settled only in a later target context. Define its owner, target, settlement, expiry/carry-over policy, and reset boundary; use `isaac-rewards-pickups` for reward selection/spawn.
- **Final review**: read `references/state-review-checklist.md`.

## Clock And Transition Contract

For each timer, cooldown, delayed settlement, or multi-stage mode, record:

- semantic phase and owner;
- timer unit and clock source;
- callback that advances it and the exact start/expiry edge;
- pause, slow-motion, room-transition, and animation-stall behavior;
- permitted next phases, re-entry policy, and idempotent cleanup.

Do not assume an update or render callback runs at a fixed real-time rate. If the requirement is expressed in seconds but the project only exposes frame/update clocks, verify the conversion from the actual update clock and distinguish it from a still-undecided pause policy. A state that has entered must have an exit for success, failure, cancellation, owner invalidation, and every relevant lifecycle boundary.

## Hard Rules

- Do not store live `Entity`, `Player`, `Sprite`, `Room`, or other userdata in saved data.
- Do not key player state by player index alone when twins/co-op or reordering
  can matter. Reuse the current project's per-player data or verified stable
  key; do not recommend a particular seed field without project evidence.
- In an unknown project, name state by purpose and owner, not invented Lua
  field names. Resolve the actual key and field names from discovered code.
- Do not leave room-only effects in run-level tables without room cleanup.
- Do not reset persistent run state on every frame or every render callback.
- Do not mutate gameplay state in pure render callbacks unless the existing repo already uses that exact pattern for a reason.
- Do not let two callbacks advance the same timer or settle the same phase unless the contract names one authority and the other path is read-only.
- Do not serialize a transient state merely because it is inconvenient to reconstruct. Save only when the approved lifecycle requires survival across continue/reload, and reconstruct runtime objects from plain saved data.
- If a state can leak into normal runs from a challenge or into other players, add an explicit gate and cleanup rule.
- Resolve persistence from the conversation, existing approved mechanic and project contract. Preserve that decision during fixes. If a relevant persistence choice is genuinely unresolved, keep it `TBD`; do not add `SaveData` or declare reload loss to be intended behavior without the required design authority.
- A pending reward entitlement must have an owner, target context, settlement condition, and clear/expiry policy. Do not represent it as an unowned global boolean or clear it merely because a target callback fired.

## Handoff Prompt Template

```markdown
## State Lifecycle Spec

- Mechanic:
- State fields:
- State owner:
- Keying strategy:
- Create/update/read callbacks:
- Phase transitions and settlement authority:
- Timer unit / clock / pause behavior:
- Reset conditions:
- Save/reload behavior:
- Userdata that must not be serialized:
- Leak-prevention gates:
- Pending entitlement target / settlement / expiry policy, if applicable:
- Tests/manual checks:
```

## Completion Checks

Review the following where relevant to the change:

- Every state owner and key.
- The callbacks that create/update/reset it.
- Whether it is runtime-only or saved.
- How reload, room transition, floor transition, death, and challenge exit behave.
- Any manual in-game lifecycle checks still needed.
