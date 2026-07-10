---
name: isaac-cards-pockets
description: Add, fix, review, or write handoff prompts for custom cards, runes, soul stones, pills, and pocket item generation in Binding of Isaac Repentance mods, especially neverbrith. Use this whenever a task mentions pocketitems.xml, custom card, rune, soul stone, pill effect, blank card art, wrong card pickup, hud icon, cardfronts, MC_USE_CARD, MC_GET_CARD, Isaac.GetCardIdByName, startingcard, or cards generating as blank/abnormal. This skill is strict because card registration, pickup art, HUD art, EID text, and use callbacks must all line up.
---

# Isaac Cards And Pocket Items

Use this skill for custom card/rune/soul stone/pill registration and behavior.

The goal is to prevent "blank" or abnormal cards: a card id exists in Lua, but the pickup/hud art, `pocketitems.xml`, EID icon/text, or use callback does not line up.

## First Move

Before editing or writing a prompt:

1. Read the current mod's `content/pocketitems.xml` if it exists.
2. Read existing card/pocket callbacks in the current mod.
3. If the task touches descriptions, also use `isaac-compat-descriptions`.
4. If the task touches card/hud/icon `.anm2`, also use `isaac-anm2-visuals`.
5. If a challenge grants a starting card, also use `isaac-challenges`.
6. After file changes, use `isaac-validators` for XML/id/asset/path checks when possible.

Reference examples:

- YSD custom soul stone: `E:/Isaac - Repentance/ysd/content/pocketitems.xml`, `E:/Isaac - Repentance/ysd/scripts/pockets/soul_of_ysd.lua`, `E:/Isaac - Repentance/ysd/descriptions/`.
- Reverie many cards/runes/pill effects: `E:/Isaac - Repentance/reverie/content/pocketitems.xml`, `E:/Isaac - Repentance/reverie/scripts/pockets/`, `E:/Isaac - Repentance/reverie/descriptions/rep/`.

## Route The Work

- **Pocket XML registration**: `card`, `rune`, `pilleffect`, ids, pickup art id, hud art key, mimiccharge, type/class. Read `references/pocketitems-xml.md`.
- **Blank or abnormal card prevention**: pickup/hud/icon mismatch, missing cardfront/hud art, duplicate id, wrong pickup id, wrong content type. Read `references/blank-card-prevention.md`.
- **Use callbacks**: `MC_USE_CARD`, `MC_USE_PILL`, effect routing, recursion guards, card/rune ids. Read `references/use-card-pill.md`.
- **Card generation and replacement**: `MC_GET_CARD`, challenge starting cards, random card pools, replacing generated cards. Read `references/card-generation.md`.
- **Descriptions and icons**: EID entries, card icons, XML descriptions, language sync. Read `references/card-descriptions-icons.md`.
- **Final review**: before handing off or final answer, read `references/card-pocket-review-checklist.md`.

## Hard Rules

- Do not mix collectible id, card id, pill effect id, pickup art id, and HUD art key. They are different surfaces.
- Do not add `MC_USE_CARD` without a matching `content/pocketitems.xml` entry for a custom card/rune/soul stone.
- Do not assume `pickup` equals `id`; reference mods often use a different pickup art id.
- Do not leave `hud` missing or mismatched for a custom card that should display in the pocket/HUD.
- Do not update EID or descriptions only; registration and art surfaces must be checked too.
- If a card generates blank/abnormal, inspect XML registration, cardfront/hud assets, EID icon registration, and generation code before changing behavior logic.
- For blank or abnormal cards, prefer `isaac-testing-debugging` plus `isaac-validators` before guessing behavior changes.

## Handoff Prompt Template

```markdown
## Card/Pocket Spec

- Content type: card | rune | soul stone | pill effect
- Display name:
- Internal name:
- pocketitems.xml id:
- pickup art id:
- hud key:
- mimiccharge / class:
- Use callback:
- Generation/replacement route:
- Description/EID surfaces:
- Art/anm2 surfaces:
- Existing examples to read:
- Blank-card prevention checks:
- Required tests/manual checks:
```

## Final Review

Before saying the work is complete, report:

- The `pocketitems.xml` entry.
- The card/rune/pill id lookup used in Lua.
- The use/generation callbacks touched.
- The pickup and HUD art keys.
- The EID/description surfaces touched.
- Any in-game card pickup/HUD visual checks still needed.
