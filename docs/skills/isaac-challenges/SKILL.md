---
name: isaac-challenges
description: Add, implement, review, or write handoff prompts for custom challenges in Binding of Isaac Repentance mods, especially neverbrith. Use this whenever the user mentions challenges, challenge id, content/challenges.xml, starting items, starting trinkets, challenge-only rules, roomfilter, cursefilter, endstage, canshoot, forced floors, challenge scripts, or Isaac.GetChallenge(). Also use isaac-state-lifecycle for once-per-room/floor challenge rules or any state that must not leak into normal runs.
---

# Isaac Custom Challenges

Use this skill for custom challenge work in Isaac Repentance mods.

The goal is to stop a common failure: Codex adds `content/challenges.xml` metadata but forgets the Lua module, load entry, challenge-id lookup, or `Isaac.GetChallenge()` guard, causing rules to leak into normal runs.

## First Move

Before editing or writing a prompt:

1. Read the current mod's `content/challenges.xml` if it exists.
2. Read the current mod's challenge loading pattern in `main.lua` or the content registry.
3. Read the closest challenge Lua script in the current mod. If none exists, use YSD as the small reference and Reverie as the broad reference.
4. If the challenge gives custom items, cards, visuals, sounds, stateful rules, or descriptions, use the relevant sibling skill for those surfaces. Use `isaac-cards-pockets` for custom starting cards, runes, soul stones, pills, or blank-card generation issues. Use `isaac-state-lifecycle` for once-per-room/floor/run rules and no-leak cleanup.
5. After file changes, use `isaac-validators` for XML/path checks and `isaac-testing-debugging` for challenge leakage verification.

## Reference Mods

- YSD has one simple custom challenge: `E:/Isaac - Repentance/ysd/content/challenges.xml`, `E:/Isaac - Repentance/ysd/scripts/challenges/endless_r.lua`, and the load entry in `E:/Isaac - Repentance/ysd/main.lua`.
- Reverie has ten custom challenges: `E:/Isaac - Repentance/reverie/content/challenges.xml`, challenge scripts under `E:/Isaac - Repentance/reverie/scripts/challenges/`, and load entries in `E:/Isaac - Repentance/reverie/scripts/contents.lua`.

## Route The Challenge

Classify the challenge into one or more routes:

- **Challenge XML registration**: name, id, starting items/trinkets/card/pill, player type, endstage, filters, curses, health, coins, difficulty, shooting rules. Read `references/challenge-xml.md`.
- **Challenge Lua gate and loading**: challenge id lookup, `Isaac.GetChallenge()` guard, module include, callback registration, no-leak rules. Read `references/lua-gate-loading.md`.
- **Starting inventory and item pools**: scripted starting collectibles, smelted trinkets, pocket active, item-pool removal, first-run-only logic. Read `references/starting-inventory.md`.
- **Room, floor, curse, and spawn rules**: forced stage, room filters, curse filters, entity/item spawn replacement, once-per-room/floor logic. Read `references/room-floor-rules.md` and use `isaac-state-lifecycle` for state owner/reset details.
- **Challenge behavior restrictions**: no shooting, replacement card drops, boss/NPC modifications, damage rules, completion conditions, and interaction with other skills. Read `references/challenge-behavior.md`.
- **Final challenge review**: before handoff or final answer, read `references/challenge-review-checklist.md`.

## Hard Rules

- Every challenge-only Lua behavior must be gated by `Isaac.GetChallenge() == <challenge id>`.
- Do not guess `challenge id`; preserve existing ids and choose an unused id only after reading `content/challenges.xml`.
- Do not use display name, XML id, and Lua variable name interchangeably. Keep all three explicit.
- Do not put all restrictions in XML if they need runtime Lua callbacks.
- Do not let callback behavior leak into normal runs, other challenges, continued saves, or non-first-run starts.
- If using `MC_POST_GAME_STARTED`, decide whether behavior runs on continued saves.
- If a challenge removes items from the item pool, state why and when it happens.

## Handoff Prompt Template

```markdown
## Challenge Spec

- Display name:
- Internal Lua name:
- XML id:
- Challenge id lookup:
- Player type:
- Starting items/trinkets/card/pill:
- Starting health/coins/stats:
- End stage / path:
- Room filters:
- Curse filters / forced curses:
- Shooting or input restrictions:
- Runtime Lua rules:
- Reset/lifetime:
- Load entry:
- Related sibling skills:
- Existing examples to read:
- Required tests:
```

## Final Review

Before saying the challenge work is complete, report:

- The XML challenge entry and id.
- The Lua module and load entry.
- Every callback used and its `Isaac.GetChallenge()` gate.
- Whether start logic runs on continued saves.
- Any item-pool removals, forced floors, spawn replacements, or restrictions.
- Tests run or manual in-game checks still needed.
