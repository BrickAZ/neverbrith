---
name: isaac-neverbrith-dev
description: "Use when implementing, reviewing or handing off a collectible change in the neverbrith mod, including XML and generated registration, localized names, item lookups, active-use callbacks, stat cache or damage behavior. 中文触发：neverbrith 道具、生成登记、主动道具、属性缓存、伤害拦截。"
---

# Isaac Neverbrith Item Development

Use this skill for code or code-prompt work in the `neverbrith` Binding of Isaac mod.

Before suggesting or applying item identity, mechanic, visual, pool, quality, or tag decisions, read `../isaac-neverbrith-router/references/user-decision-authority.md`. Preserve explicit user choices and separate undecided design choices from technical discovery.

The goal is not to invent a new architecture. The goal is to keep future item work close to the known-good patterns already present in this repository, especially around item registration, stat cache handling, and damage interception.

## First Move

Before editing or writing a code prompt, confirm the actual checkout and read
its `AGENTS.md` and `docs/agent/index.md`. The bootstrap requires REPENTOGON;
check `main.lua` and the project README for the supported release and startup
behavior. Then inspect the current repository state:

1. Read `main.lua` to identify the bootstrap/load path, then locate the file that currently owns the closest existing item implementation. Do not assume `main.lua` is the implementation owner after modularization.
2. Read `content/items.xml`, `content/items.en_us.xml`, and `content/items.zh_cn.xml` when item metadata is involved.
3. Read `content/itempools.xml`, `content/itempools.en_us.xml`, and `content/itempools.zh_cn.xml` when pools or weights are involved.
4. Read one matching behavior test under `tests/` before adding a new behavior.

Do not rely on memory of Isaac callbacks when the repo already has a working example.

## Basic Item Spec Gate

For a new item, a full redesign or a handoff for either, read `references/item-basic-spec.md`. For a targeted bug fix, path check or metadata change, review the affected fields and preserve the existing item contract.

The item's basic identity must be explicit before implementation. Do not guess missing fundamentals such as active/passive type, display names, quality, item pools, pickup text, collectible art, or whether the visual request changes Isaac's body versus adds a separate effect.

If an unresolved user choice affects the task, record it as `TBD — user decision required`. Discover missing paths, registrations and callback owners from the actual project. In this mod, guessed metadata is a common source of plausible-looking but wrong item work.

## Route The Task

Classify the request into one or more routes:

- **Item registration**: For `items*.xml`, explicit stable local id, `gfxroot + gfx`, colored icon, and native ESC/death-portrait boundary, use `isaac-collectible-registration` first; then read `references/item-registration.md` for Neverbirth lookup and callback wiring.
- **Passive behavior and stat cache**: Use `isaac-passive-collectibles` for held ownership, count, acquisition/loss, cache and co-op contracts, then read `references/stat-cache.md` for current project conventions.
- **Damage interception**: Use `isaac-damage-health-contracts` for cancellation, replacement, health, lethal, repeat and re-entry semantics, then read `references/damage-interception.md` for the current implementation owner.
- **Item economy**: The task chooses quality, pools, weights, depletion, tags, unlocks, or rarity. Use `isaac-item-economy` before editing `itempools*.xml`.

If a request says "active item" but the hard part is damage, room state, or stats, route by the hard part. Active-item effect logic is not one generic template.

If the request gives a mechanic in natural language but its trigger, success/failure, exclusions, repeated behavior, or settlement is ambiguous, use `isaac-mechanic-contracts` before selecting callbacks.

If a request says "trinket", "smelted", "gulped", or "golden trinket", use `isaac-trinkets` instead of this collectible-item skill.

## Project Library And Callback Conventions

For Lua changes, follow the current checkout's [development conventions](../../../docs/agent/development-conventions.md).
Callback handlers and their bindings stay adjacent in the owning file; preserve
explicit installation order. Before reusing or adding shared capabilities, consult
the [public API index](../../../docs/api/index.md). Creating or changing a public
library interface includes its detailed usage contract, real caller and relevant
verification in the same delivery. The project documents own the exact rule and
API facts; do not copy the library manual into this skill.

## Implementation Rules

- Keep changes scoped to the requested item or shared helper needed by that item.
- Prefer the helper and callback style of the current implementation owner. `main.lua` remains the place to inspect bootstrapping and load order, but new item logic belongs beside the closest owned item logic unless the current project pattern says otherwise.
- For each new item, update all language variants that exist in the repo. Do not update only `content/items.xml` if `items.en_us.xml` and `items.zh_cn.xml` also exist.
- If behavior is non-trivial, add or extend a Lua behavior test under `tests/`.
- If callback choice, filter, return policy, or cache refresh is non-trivial, use `isaac-callback-contracts` before registering it.
- After file changes, use the repository checks documented in `docs/agent/testing.md`. The strict route checks synchronization of the generated collectible registry.
- When writing a prompt for another coding agent, include the route, files to read, reference item examples, edge cases, and expected tests.

## Known Project Conventions

- The folder is spelled `neverbrith`, while the registered mod name in code may use `neverbirth`. Preserve existing naming unless the user explicitly asks to fix naming.
- Existing item examples include `EssentialBalm`, `Wuhu`, `Chunyao`, `Musicbox`, `UncutCord`, `BloodSkullGu`, `EmptyCradle`, `GoodGirlOfBabylon`, `Angelbox`, and `Devilbox`.
- The user usually wants Chinese discussion, but code identifiers and XML internal names should follow the existing English naming style.

Use the [shared execution and reporting policy](../isaac-mod-context/references/tbd-disclosure.md)
for applicable completion checks and concise reporting.

## Completion Checks

Review the following where relevant to the change:

- Which route(s) were used.
- Which files were changed or, for prompts, which files the coding agent must read.
- Which tests were run or which tests still need to be added.
- Any damage flags, cache flags, or XML language files that were intentionally left untouched.
