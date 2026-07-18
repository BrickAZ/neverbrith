---
name: isaac-compat-descriptions
description: Handle optional dependency compatibility and player-facing descriptions for Binding of Isaac Repentance mods, especially neverbrith. Use this whenever a task mentions EID, item descriptions, Chinese/English text, Encyclopedia, Mod Config Menu, StageAPI, Boss Bars, CuerLib, optional dependencies, load guards, translations, wiki text, or keeping XML/EID/compat descriptions synchronized.
---

# Isaac Compatibility And Descriptions

Use this skill for optional mod integrations and player-facing text surfaces.

The goal is to prevent two common mistakes: loading optional dependencies as if they always exist, and updating one text surface while leaving XML, EID, wiki, or translations inconsistent.

## First Move

Before editing or writing a prompt:

1. Inspect neverbrith's current description/localization pattern in `main.lua`, `content/items*.xml`, and any EID-related blocks.
2. If using reference mods, use YSD for simple optional guards and Reverie for broad compatibility layout.
3. Decide which surfaces are involved: XML, EID, Encyclopedia/wiki, MCM, StageAPI, Boss Bars, CuerLib translations, or metadata.

## Route The Task

- **EID and inline icons**: item/card/trinket descriptions, icons, transformation icons, button icons, charge icons. Read `references/eid-descriptions.md`. For custom card/rune/soul stone/pill registration, generation, or blank card art, use `isaac-cards-pockets`.
- **Localization sync**: default XML, English XML, Chinese XML, EID language files, metadata, and translation tables. Read `references/localization-sync.md`.
- **Optional dependency gates**: `if EID then`, `if CuerLib then`, `if StageAPI then`, `if ModConfigMenu then`, or graceful fallback. Read `references/optional-dependency-gates.md`.
- **MCM / Encyclopedia / Boss Bars / StageAPI**: config pages, wiki entries, boss bar support, stage API hooks. Read `references/compat-modules.md`.
- **Load order and module organization**: include/require order, descriptions folder, compatibility folder, and avoiding hard failure on missing optional mods. Read `references/load-order.md`.

## Hard Rules

- Optional dependencies must be guarded unless the mod intentionally requires them and the requirement is documented.
- Do not call EID, Encyclopedia, MCM, StageAPI, or CuerLib APIs before confirming the object exists or the project declares it required.
- Do not mix Chinese text into English description surfaces or English-only text into Chinese surfaces unless the design explicitly wants bilingual text.
- Keep collectible/card/trinket ids distinct. Use the matching `Isaac.GetItemIdByName`, `Isaac.GetCardIdByName`, or `Isaac.GetTrinketIdByName`.
- When a mechanic changes, update descriptions in all relevant surfaces or report why a surface was intentionally left untouched.

## Reference Mods

- YSD simple gates: `E:/Isaac - Repentance/ysd/main.lua`.
- YSD EID language split: `E:/Isaac - Repentance/ysd/descriptions/`.
- Reverie compatibility entry: `E:/Isaac - Repentance/reverie/main.lua`.
- Reverie compatibility modules: `E:/Isaac - Repentance/reverie/compatilities/`.
- Reverie description data: `E:/Isaac - Repentance/reverie/descriptions/`.

## Handoff Prompt Template

```markdown
## Compatibility And Description Spec

- Content type:
- Text surfaces to update:
- Languages:
- Optional dependencies:
- Required dependency gates:
- Icon/inline icon assets:
- Config/wiki/boss-bar surfaces:
- Existing examples to read:
- Surfaces intentionally left unchanged:
- Required tests or manual checks:
```

## Final Review

Before saying the work is complete, report:

- Which text and compatibility surfaces were touched.
- Which optional dependency gates were used.
- Which ids were resolved as collectible/card/trinket/player/entity.
- Which languages were updated.
- Any compatibility behavior that still needs in-game verification.
