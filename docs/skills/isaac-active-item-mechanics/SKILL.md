---
name: isaac-active-item-mechanics
description: Design, implement, review, or write handoff prompts for complex active-item mechanics in Binding of Isaac Repentance mods, especially neverbrith. Use this whenever an active item involves conditional use, failed-use charge policy, charge slots, held input, option selection, temporary UI, render callbacks, room/floor limits, card/pill interaction, or multi-step state. Also use isaac-state-lifecycle for any active item mode, timer, cooldown, room/floor reset, or SaveData behavior.
---

# Isaac Active Item Mechanics

Use this skill when an active item is more than a simple `MC_USE_ITEM` shell.

The goal is to stop a common failure: Codex sees "active item" and writes only XML plus `MC_USE_ITEM`, while the real design depends on input state, charge slots, temporary UI, room or floor state, card/pill callbacks, render callbacks, or a failure path that must not consume charge.

## First Move

Before editing or writing a prompt:

1. Read the current neverbrith item registration rules if the item is new: `../isaac-neverbrith-dev/references/item-basic-spec.md` and `../isaac-neverbrith-dev/references/item-registration.md`.
2. Read the closest active item in the current repo before copying a callback shape.
3. If using reference mods, prefer `E:/Isaac - Repentance/ysd/scripts/items/untuned_piano.lua` for complex active interaction and `E:/Isaac - Repentance/ysd/main.lua` for charge/data helpers.

Do not treat the active item callback as the whole mechanic. `MC_USE_ITEM` decides whether use begins and whether charge is consumed; the effect may live elsewhere.

## Route The Active Mechanic

Classify the design into one or more routes:

- **Use boundary and charge policy**: conditional use, failed use, zero-charge active, charge refund, or slot-specific charge. Read `references/use-callback-charge.md`.
- **Held input or option selection**: long press, two-button combo, directional input, menu selection, or keyboard/controller interception. Read `references/input-selection.md`.
- **Temporary UI or render feedback**: charge meter, choice panel, screen overlay, text prompt, highlight, or custom render while the item is active. Read `references/ui-render-active.md`.
- **Room/floor/run state**: once per room, once per floor, reset on new room, reset on new level, persistent unlock/knowledge state, or rollback. Read `references/room-floor-state.md` and use `isaac-state-lifecycle` for ownership, keying, reset, or SaveData details.
- **Card/pill/pocket interaction**: active item triggers a card/pill-like effect, reads pocket slots, consumes pocket items, or reacts to `MC_USE_CARD` / `MC_USE_PILL`. Read `references/card-pill-active.md` and use `isaac-cards-pockets` for custom card/rune/pill registration, generation, or blank-card issues.

If the active item also changes stats, intercepts damage, spawns registered entities, uses anm2 visuals, plays sound/shader feedback, or stores state beyond one callback, use the relevant sibling skill for that part.

## Hard Rules

- Separate "pressing the active item" from "the continuing mechanic after use".
- State whether failed use consumes charge. If not, specify the callback return boundary and any manual charge restoration.
- State which active slot matters. Do not assume pocket active, primary slot, or all slots.
- State lifetime: one frame, timed, until room clear, until new room, until new level, or persistent.
- For input-based mechanics, specify whether input is checked in `MC_INPUT_ACTION`, `MC_POST_PLAYER_UPDATE`, `MC_POST_RENDER`, or a helper already used by the repo.
- For render-based mechanics, specify screen-space versus world-space and hand off SFX/shader/render details to `isaac-audio-render-feedback` when needed.
- For new item metadata, do not invent missing quality, pools, text, or art. Keep `TBD` fields explicit.
- For debugging an active item that does not trigger or consumes charge incorrectly, use `isaac-testing-debugging` before guessing a fix.

## Reference Mods

- YSD complex active reference: `E:/Isaac - Repentance/ysd/scripts/items/untuned_piano.lua`.
- YSD data and charge helpers: `E:/Isaac - Repentance/ysd/main.lua`.
- Reverie large active examples live under `E:/Isaac - Repentance/reverie/scripts/items/`.

Use these as pattern references, not as code to copy blindly into neverbrith.

## Handoff Prompt Template

When writing a prompt for another Codex agent, include:

```markdown
## Active Mechanic Spec

- Item:
- Active slot policy:
- Use trigger:
- Failed-use charge policy:
- Continuing callbacks after use:
- Input route:
- UI/render route:
- Room/floor/reset route:
- Card/pill/pocket interaction:
- State owner and lifetime:
- Related sibling skills:
- Existing examples to read:
- Required tests:
```

## Final Review

Before saying the active mechanic is complete, report:

- Which active routes were used.
- The exact charge-consumption rule.
- The callbacks involved after `MC_USE_ITEM`.
- The state keys and when they reset.
- Any UI/render/input behavior that still needs in-game verification.
