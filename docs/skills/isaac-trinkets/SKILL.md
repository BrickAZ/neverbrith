---
name: isaac-trinkets
description: Add, fix, review, or write handoff prompts for custom trinkets in the Binding of Isaac Repentance `neverbrith` mod. Use this whenever a task mentions trinkets.xml, custom trinket, smelted/gulped trinket behavior, golden trinkets, trinket multipliers, Isaac.GetTrinketIdByName, player:HasTrinket, trinket pools/drops, trinket descriptions, or trinket costumes/icons. This skill keeps trinket registration and behavior separate from collectible item logic.
---

# Isaac Trinkets

Use this skill for custom trinket work in neverbrith.

The goal is to prevent treating trinkets as smaller collectible items. Trinkets have different XML, id lookup, ownership, smelted behavior, golden trinket multipliers, and drop/pool surfaces.

## First Move

Before editing or writing a prompt:

1. Read `content/trinkets.xml` and language variants if they exist.
2. Search current code for `GetTrinketIdByName`, `HasTrinket`, `GetTrinketMultiplier`, `TRINKET`, `gulp`, and `smelt`.
3. If no local trinket exists, inspect YSD and Reverie trinket examples before writing a new pattern.
4. If the trinket changes stats, use `isaac-neverbrith-dev` stat-cache rules for cache behavior.
5. If the trinket has state, use `isaac-state-lifecycle`.
6. If the trinket has costume/icon visuals or EID text, use `isaac-anm2-visuals` and `isaac-compat-descriptions`.

## Route The Trinket

- **Registration and metadata**: `trinkets.xml`, internal name, display names, pickup text, description, tags, quality-like review if the repo uses one. Read `references/trinket-registration.md`.
- **Ownership and multipliers**: held, smelted/gulped, golden trinket, `player:HasTrinket`, `player:GetTrinketMultiplier`, per-player behavior. Read `references/ownership-multipliers.md`.
- **Behavior route**: stat cache, damage interception, room effects, drops, pickups, entity interaction, or active/passive style callbacks. Read `references/trinket-behavior.md`.
- **Descriptions and visuals**: localization, EID, icons, costumes. Use sibling skills as needed.
- **Final review**: read `references/trinket-review-checklist.md`.

## Hard Rules

- Do not register a trinket as a collectible item.
- Do not use collectible id lookup for trinket behavior.
- Do not ignore smelted/gulped behavior if the effect should still apply after the trinket is swallowed.
- Do not forget golden trinket multiplier behavior; state whether the effect scales or intentionally does not.
- Do not use one global boolean for a player-held trinket effect.
- Do not update only one language file when the repo has language variants.

## Handoff Prompt Template

```markdown
## Trinket Spec

- Display name:
- Internal name:
- XML registration:
- Lua id lookup:
- Held/smelted/golden behavior:
- Multiplier rule:
- Callback route:
- State owner:
- Visual/EID surfaces:
- Existing examples to read:
- Required tests/manual checks:
```

## Final Review

Before saying trinket work is complete, report:

- XML and language files touched.
- Lua id lookup used.
- Held, smelted, and golden behavior.
- Multiplier rule.
- Callbacks touched.
- Tests run and in-game checks still needed.
