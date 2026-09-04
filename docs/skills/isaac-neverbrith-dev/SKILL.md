---
name: isaac-neverbrith-dev
description: Develop items for the Binding of Isaac Repentance mod `neverbrith`. Use this whenever the user asks to add, implement, fix, review, or prompt another agent to code a neverbrith item, especially for item registration, passive/active XML setup, MC_EVALUATE_CACHE stat effects, MC_USE_ITEM callback wiring, or MC_ENTITY_TAKE_DMG damage interception. This skill is intentionally strict because Isaac mod code is easy to break with plausible-looking Lua. 中文触发：道具、被动道具、主动道具、道具注册、道具池、品质、属性、伤害、受伤、拦截伤害、叠加。
---

# Isaac Neverbrith Item Development

Use this skill for code or code-prompt work in the `neverbrith` Binding of Isaac mod.

Before suggesting or applying item identity, mechanic, visual, pool, quality, or tag decisions, read `../isaac-neverbrith-router/references/user-decision-authority.md`. Preserve explicit user choices and leave omissions as `TBD`.

The goal is not to invent a new architecture. The goal is to keep future item work close to the known-good patterns already present in this repository, especially around item registration, stat cache handling, and damage interception.

## First Move

Before editing or writing a code prompt, inspect the current repository state:

1. Read `main.lua` to identify the bootstrap/load path, then locate the file that currently owns the closest existing item implementation. Do not assume `main.lua` is the implementation owner after modularization.
2. Read `content/items.xml`, `content/items.en_us.xml`, and `content/items.zh_cn.xml` when item metadata is involved.
3. Read `content/itempools.xml`, `content/itempools.en_us.xml`, and `content/itempools.zh_cn.xml` when pools or weights are involved.
4. Read one matching behavior test under `tests/` before adding a new behavior.

Do not rely on memory of Isaac callbacks when the repo already has a working example.

## Basic Item Spec Gate

For any new item, item rewrite, item handoff prompt, or item review, read `references/item-basic-spec.md` before route-specific references.

The item's basic identity must be explicit before implementation. Do not guess missing fundamentals such as active/passive type, display names, quality, item pools, pickup text, collectible art, or whether the visual request changes Isaac's body versus adds a separate effect.

If a user intentionally leaves a field undecided, mark it as `TBD` in the handoff or final report and avoid silently filling it with a default. In this mod, guessed metadata is a common source of plausible-looking but wrong item work.

## Route The Task

Classify the request into one or more routes:

- **Item registration**: For `items*.xml`, explicit stable local id, `gfxroot + gfx`, colored icon, and native ESC/death-portrait boundary, use `isaac-collectible-registration` first; then read `references/item-registration.md` for Neverbirth lookup and callback wiring.
- **Passive behavior and stat cache**: Use `isaac-passive-collectibles` for held ownership, count, acquisition/loss, cache and co-op contracts, then read `references/stat-cache.md` for current project conventions.
- **Damage interception**: Use `isaac-damage-health-contracts` for cancellation, replacement, health, lethal, repeat and re-entry semantics, then read `references/damage-interception.md` for the current implementation owner.
- **Item economy**: The task chooses quality, pools, weights, depletion, tags, unlocks, or rarity. Use `isaac-item-economy` before editing `itempools*.xml`.

If a request says "active item" but the hard part is damage, room state, or stats, route by the hard part. Active-item effect logic is not one generic template.

If the request gives a mechanic in natural language but its trigger, success/failure, exclusions, repeated behavior, or settlement is ambiguous, use `isaac-mechanic-contracts` before selecting callbacks.

If a request says "trinket", "smelted", "gulped", or "golden trinket", use `isaac-trinkets` instead of this collectible-item skill.

## Implementation Rules

- Keep changes scoped to the requested item or shared helper needed by that item.
- Prefer the helper and callback style of the current implementation owner. `main.lua` remains the place to inspect bootstrapping and load order, but new item logic belongs beside the closest owned item logic unless the current project pattern says otherwise.
- For each new item, update all language variants that exist in the repo. Do not update only `content/items.xml` if `items.en_us.xml` and `items.zh_cn.xml` also exist.
- If behavior is non-trivial, add or extend a Lua behavior test under `tests/`.
- If callback choice, filter, return policy, or cache refresh is non-trivial, use `isaac-callback-contracts` before registering it.
- After file changes, use `isaac-validators` for static XML/path/language checks when possible.
- When writing a prompt for another coding agent, include the route, files to read, reference item examples, edge cases, and expected tests.

## Known Project Conventions

- The folder is spelled `neverbrith`, while the registered mod name in code may use `neverbirth`. Preserve existing naming unless the user explicitly asks to fix naming.
- Existing item examples include `EssentialBalm`, `Wuhu`, `Chunyao`, `Musicbox`, `UncutCord`, `BloodSkullGu`, `EmptyCradle`, `GoodGirlOfBabylon`, `Angelbox`, and `Devilbox`.
- The user usually wants Chinese discussion, but code identifiers and XML internal names should follow the existing English naming style.

## Required Final Check

Before saying the work is done, report:

- Which route(s) were used.
- Which files were changed or, for prompts, which files the coding agent must read.
- Which tests were run or which tests still need to be added.
- Any damage flags, cache flags, or XML language files that were intentionally left untouched.
