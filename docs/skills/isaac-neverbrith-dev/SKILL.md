---
name: isaac-neverbrith-dev
description: Develop items for the Binding of Isaac Repentance mod `neverbrith`. Use this whenever the user asks to add, implement, fix, review, or prompt another agent to code a neverbrith item, especially for item registration, passive/active XML setup, MC_EVALUATE_CACHE stat effects, MC_USE_ITEM callback wiring, or MC_ENTITY_TAKE_DMG damage interception. This skill is intentionally strict because Isaac mod code is easy to break with plausible-looking Lua.
---

# Isaac Neverbrith Item Development

Use this skill for code or code-prompt work in the `neverbrith` Binding of Isaac mod.

The goal is not to invent a new architecture. The goal is to keep future item work close to the known-good patterns already present in this repository, especially around item registration, stat cache handling, and damage interception.

## First Move

Before editing or writing a code prompt, inspect the current repository state:

1. Read `main.lua` around the closest existing item implementation.
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

- **Item registration**: The task asks how to define an active/passive item, add XML metadata, register `Items.<Name>`, attach callbacks, write EID/localization, or place the item in pools. Read `references/item-registration.md`.
- **Stat cache**: The task changes damage, tears, fire delay, speed, range, luck, tear flags, tear color, familiars, or temporary stat bonuses. Read `references/stat-cache.md`.
- **Damage interception**: The task reacts to, blocks, rewrites, delays, classifies, or rewards player damage. Read `references/damage-interception.md`.

If a request says "active item" but the hard part is damage, room state, or stats, route by the hard part. Active-item effect logic is not one generic template.

If a request says "trinket", "smelted", "gulped", or "golden trinket", use `isaac-trinkets` instead of this collectible-item skill.

## Implementation Rules

- Keep changes scoped to the requested item or shared helper needed by that item.
- Prefer existing helper style in `main.lua`: local constants, local state tables keyed by `player.InitSeed`, small local helper functions, then `Neverbirth:AddCallback(...)`.
- For each new item, update all language variants that exist in the repo. Do not update only `content/items.xml` if `items.en_us.xml` and `items.zh_cn.xml` also exist.
- If behavior is non-trivial, add or extend a Lua behavior test under `tests/`.
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
