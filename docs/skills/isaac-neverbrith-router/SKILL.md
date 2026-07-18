---
name: isaac-neverbrith-router
description: First-pass dispatcher for Binding of Isaac Repentance `neverbrith` mod work. Use this before implementing, fixing, reviewing, or writing a handoff prompt for any neverbrith gameplay, item, trinket, card, challenge, entity, visual, audio, description, validation, debugging, architecture, or stateful mechanic, especially when the user's request mixes "change Isaac himself", "special effect", "entity", "card", "challenge", "active item", UI, sounds, descriptions, tests, or save/state behavior. This skill exists to prevent choosing the wrong Isaac modding surface at the start.
---

# Isaac Neverbrith Router

Use this skill as the first stop for neverbrith implementation and handoff work.

The goal is to classify the user's request before writing code. Many Isaac mod bugs come from choosing the wrong surface: treating a registered entity as a loose sprite, treating a player costume as a visual effect, treating a card as a collectible, or putting persistent state in a table that only survives one room.

## First Move

Before editing or writing a code prompt:

1. Restate the user's request as one or more content surfaces.
2. Identify whether the request changes gameplay, visuals, descriptions, audio/render feedback, saved state, or only metadata.
3. Load every sibling skill needed for those surfaces before implementation.
4. If the request is underspecified, keep unknown fields as `TBD` instead of inventing defaults.

Read `references/task-classification.md` for the classification checklist and `references/skill-routing-matrix.md` for the sibling skill map.

## Content Surfaces

Classify the task into one or more of these surfaces:

- **Collectible item**: passive or active item registration, XML metadata, item pools, stat cache, damage interception. Use `isaac-neverbrith-dev`.
- **Trinket**: `trinkets.xml`, held/smelted/golden behavior, `Isaac.GetTrinketIdByName`, `player:HasTrinket`, `GetTrinketMultiplier`. Use `isaac-trinkets`.
- **Complex active item**: held input, charge policy, slot handling, temporary UI, card/pill interaction, room/floor state. Use `isaac-active-item-mechanics`.
- **Card, rune, soul stone, or pill**: `pocketitems.xml`, `MC_USE_CARD`, `MC_GET_CARD`, blank card art, HUD keys. Use `isaac-cards-pockets`.
- **Challenge**: `content/challenges.xml`, challenge starting inventory, stage restrictions, special rules, non-leak checks. Use `isaac-challenges`.
- **Registered entity**: `entities2.xml`, type/variant/subtype, effect/familiar/tear/pickup/NPC behavior, collision, entity callbacks. Use `isaac-entities`.
- **ANM2 visual asset**: costume, loose Lua `Sprite`, UI/HUD sprite, EID icon, vanilla animation template reuse. Use `isaac-anm2-visuals`.
- **Audio/render feedback**: SFX, music, shader parameters, `MC_POST_RENDER`, `MC_GET_SHADER_PARAMS`, input interception for feedback. Use `isaac-audio-render-feedback`.
- **Descriptions and optional compat**: EID, XML localization, MCM, Encyclopedia, Boss Bars, StageAPI, CuerLib optional gates. Use `isaac-compat-descriptions`.
- **State lifecycle**: `GetData()`, local state tables, room/floor/run reset, SaveData/LoadData, reload safety. Use `isaac-state-lifecycle`.
- **Validation or debugging**: static checks, XML parse, duplicate ids, missing assets, failing tests, in-game verification plan, symptom triage. Use `isaac-validators` and/or `isaac-testing-debugging`.
- **Architecture**: module boundaries, callback registration organization, shared helpers, load order, reducing `main.lua` growth. Use `isaac-mod-architecture`.

## Hard Routing Rules

- If the request says "effect" but needs collision, AI, HP, targeting, pickup behavior, variant/subtype, or damage contact, route to `isaac-entities`.
- If the request says "change Isaac" or "on Isaac's body", decide between costume/player overlay and gameplay stat/body changes before touching anm2.
- If the request says "card" or "rune", do not route it through collectible item registration.
- If the request says "trinket", "gulped", "smelted", or "golden trinket", do not route it through collectible item registration.
- If the request says "active item", route by the hard part: charge/input/UI/state/damage/card interaction, not by `MC_USE_ITEM` alone.
- If any behavior survives beyond one frame, explicitly route to `isaac-state-lifecycle`.
- If the request includes player-facing text, route to `isaac-compat-descriptions` even when the main mechanic belongs elsewhere.
- If the request includes a visible asset, route to `isaac-anm2-visuals` or `isaac-entities` depending on whether the visual is only a sprite/costume or a registered entity.
- If the request asks "how do I know this works", "check it", "verify", or reports a bug symptom, route to `isaac-testing-debugging` and run `isaac-validators` where possible.
- If the request touches many files, moves callbacks, or adds a reusable helper, route to `isaac-mod-architecture` before editing structure.

## Required Output Before Implementation

For non-trivial work, produce a short routing block before editing:

```markdown
## Isaac Route

- Primary surface:
- Secondary surfaces:
- Skills to load:
- Files to inspect first:
- Unknown fields kept as TBD:
- In-game checks needed:
```

Then do the work using the selected sibling skills.

## Final Review

Before saying the task is complete, report:

- Which route was selected and why.
- Which sibling skills were used.
- Which files were changed or should be read by the next agent.
- Which surfaces were intentionally not touched.
- Which checks were automated and which still need in-game verification.
