# Lua Sprite Effects Reference

Use this when a visual is not an Isaac entity and is controlled manually by Lua.

## When To Use

Use manual `Sprite` loading for:

- One-shot hit flashes or reward bursts.
- Floating labels or icons near a player.
- Rings, halos, pulses, slash effects, warning marks, and temporary overlays.
- Visuals that do not need entity collision or an `entities2.xml` registration.

If the visual needs collision, AI, entity update callbacks, or an `EntityType/Variant`, this becomes the skipped entity-registration route.

## Files To Check

- The `.anm2` file.
- Its spritesheet PNGs.
- `main.lua` for `Sprite:Load`, `:Play`, `:Update`, `:Render`, `:IsFinished`.
- Tests that stub `Sprite`.

Reference examples:

- neverbrith: `resources/gfx/Effects/GoodGirlOfBabylon/GoodGirlHalo.anm2`
- neverbrith: `resources/gfx/Effects/CoinSwordQi/CoinSwordQi.anm2`
- YSD: `resources/gfx/ysd_bone.anm2`
- Reverie: `resources/gfx/reverie/1000.5821_music wave.anm2`

## Basic Runtime Pattern

```lua
local effect = {
    sprite = Sprite(),
    position = player.Position + Vector(0, -36),
    timer = 30,
}

effect.sprite:Load("gfx/Effects/ItemName/ItemNameEffect.anm2", true)
effect.sprite:Play("Idle", true)
```

In update/render logic:

```lua
effect.sprite:Update()
effect.sprite:Render(effect.position)
effect.timer = effect.timer - 1
```

Use `:IsFinished("AnimationName")` for one-shot animations when the `.anm2` is non-looping.

## ANM2 Shape

For first versions, prefer:

- One spritesheet.
- One layer.
- `Idle` for looped effects.
- `Appear`, `Idle`, `Disappear` only if code actually transitions between them.
- Pivots centered on the visual's intended anchor.

Read the `.anm2` before coding. If the file only has `Idle`, do not call `Play("Pulse")`.

## Lifetime Rules

- Store active effects in a table.
- Remove expired effects from the table.
- Keep state per player when the visual follows a player.
- Do not create a new `Sprite()` every render frame.
- For paused or room-transition behavior, decide whether the effect should freeze, vanish, or persist.

## Checklist

- Lua path matches the real resource path.
- All animation names used by code exist in the `.anm2`.
- Looped and one-shot animations are handled differently.
- Sprites are updated before render when animation should advance.
- Expired sprites are removed.
- Tests assert `Load`, `Play`, `Render`, and expiration behavior when practical.
