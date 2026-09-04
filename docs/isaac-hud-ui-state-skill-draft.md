---
name: isaac-hud-ui-state
description: Design, implement, review, debug, or write handoff prompts for Binding of Isaac: Repentance mod HUD, world-following indicators, prompts, counters, selectors, and short-lived UI state. Use whenever UI coordinates, player-specific display, manual Sprite rendering, pause, room changes, or HUD state cleanup matters.
---

# Isaac HUD and UI State

Use `isaac-mod-context` before an unfamiliar project. Discover existing HUD,
render, asset, state, and multiplayer conventions instead of assuming paths,
animation names, or a UI framework.

## Boundary

This skill governs visual presentation, coordinate domains, UI ownership, and
lifecycle. It does not decide gameplay effects, item balance, or visual asset
authoring. Use `isaac-mechanic-contracts` for gameplay settlement,
`isaac-anm2-visuals` for ANM2 facts, `isaac-state-lifecycle` for durable state,
and `isaac-audio-render-feedback` for broader feedback work.

Default to official Isaac APIs. Third-party UI APIs and REPENTOGON are optional
only after explicit project declaration and runtime/API discovery; they cannot be
the default route or remove a documented official fallback.

## Select the Carrier Before Coding

Classify the display:

- **HUD/screen UI:** fixed to the screen, such as counters and menus.
- **World-following indicator:** attached above a player or entity.
- **Entity visual:** needs engine-world placement or an actual visual entity
  lifecycle.
- **Costume:** only when the requirement explicitly changes player appearance.

Do not use HUD coordinates for world movement or a loose manually rendered sprite
as a collision/AI/damage entity. If an indicator needs collision, damage, AI, HP,
or targeting, route it through `isaac-entities` instead.

## Coordinate Contract

Name the coordinate domain for every position:

- World positions are used for entity logic and world placement.
- Manual `Sprite:Render` uses screen coordinates. Convert an anchored world point
  with `Isaac.WorldToScreen(worldPosition)` before rendering.
- Build a head anchor from the actual owner position plus discovered offset rules;
  treat a fixed Y offset as a provisional visual parameter, not a universal anchor.
- Validate player and NPC anchors separately where size, flying offset, position
  offset, boss scale, or ANM2 pivot can differ.

Do not claim correct placement from code inspection alone. Test the chosen anchor
against the relevant owner classes and record unresolved offsets as `TBD`.

## UI State and Rendering

Keep gameplay settlement out of render callbacks. UI state must identify its owner
and distinguish co-op players; a global boolean is insufficient for an owner-bound
prompt or marker unless the design is explicitly global.

For short-lived UI, define creation, update, visibility, and cleanup for at least:

- duration expiration;
- owner removal, death, or invalidity;
- room/level/run boundary required by the feature;
- pause/menu behavior if the display has timers or input;
- mod reload and stale runtime userdata.

Use stable layout slots or dimensions so text, counters, selection state, and
sprites do not shift unpredictably. Discover resource paths and animation names;
never invent them.

## Output Contract

Return, in order:

1. Confirmed project facts and `TBD` facts.
2. Carrier decision and rejected carriers.
3. Coordinate table: element, owner, world/screen domain, conversion, anchor,
   validation target.
4. UI-state owner, lifecycle, co-op behavior, pause behavior, and cleanup.
5. Asset/ANM2 facts or discovery steps.
6. Verification plan separating static checks, runtime observation, and in-game
   visual proof.

Never call a UI correct merely because it did not crash or because a stub rendered.
