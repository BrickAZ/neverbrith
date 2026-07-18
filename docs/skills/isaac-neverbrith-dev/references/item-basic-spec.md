# Item Basic Spec Reference

Use this before implementing, reviewing, or writing a handoff prompt for any neverbrith item.

The purpose is to stop the agent from coding a mechanically plausible item with the wrong identity. A Binding of Isaac item is not only Lua behavior; it also has metadata, localization, art, pools, tags, and sometimes a visual carrier.

## Required Basic Fields

Capture these fields before code work:

- English display name.
- Chinese display name.
- Internal Lua/XML name in the repo's existing English identifier style.
- Item type: `passive` or `active`.
- Mechanic summary in one short paragraph.
- Trigger timing: pickup, room clear, damage taken, damage dealt, use button, new floor, cache evaluation, or another callback.
- Stack behavior: no stacking, linear stacking, capped stacking, or special multi-copy rule.
- Quality value.
- Item pools and weights, or an explicit note that pool placement is not decided.
- Tags such as `offensive`, `summonable`, or other existing repo-style tags, or an explicit note that no tag is decided.
- Pickup description text for default, English, and Chinese XML.
- EID description text if the repo's EID block needs it.
- Collectible art path under `resources/gfx/Items/Collectibles/`, or an explicit art handoff.
- Visual carrier, if the item has a visual component: costume/body change, Lua sprite effect, UI/HUD, EID icon, vanilla template art, or registered entity.

## Active Item Extra Fields

For active items, also capture:

- `maxcharges`.
- `initcharge`, if different from the default expectation.
- Whether failed use should consume charge.
- Whether the effect can be used in combat, outside combat, once per room, once per floor, or repeatedly.
- Callback return boundary for `MC_USE_ITEM`.

## Passive Item Extra Fields

For passive items, also capture:

- Whether stats are permanent, conditional, temporary, or event-driven.
- Cache flags needed by the XML `cache` attribute.
- Whether copies multiply the effect.
- Whether the item needs per-player state.

## Do Not Guess

Do not silently default to treasure pool, quality 3, English-only text, or placeholder art when the design did not say so.

Do not treat "active item" as a complete implementation route. The active item shell only registers use input; the actual mechanic may still route to stat cache, damage interception, room state, spawning, visual effects, or another callback.

Do not treat "visual on Isaac" as automatically meaning a costume. If the visual follows the player position but not the body animation, route the visual part through the anm2 visual carrier decision skill.

## Basic Spec Template

When writing a prompt for another Codex agent, include this block near the top:

```markdown
## Item Basic Spec

- English name:
- Chinese name:
- Internal name:
- Type: passive | active
- Mechanic summary:
- Trigger timing:
- Stack behavior:
- Quality:
- Pools/weights:
- Tags:
- Default pickup text:
- English pickup text:
- Chinese pickup text:
- EID text:
- Collectible art:
- Visual carrier:
- Open/TBD fields:
```

For active items, add:

```markdown
- Max charges:
- Initial charge:
- Failed-use charge policy:
- Use frequency:
- MC_USE_ITEM return boundary:
```

For passive items, add:

```markdown
- Stat/cache behavior:
- Cache flags:
- Multi-copy behavior:
- Per-player state:
```

