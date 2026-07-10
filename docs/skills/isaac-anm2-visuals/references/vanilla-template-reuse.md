# Vanilla Template Reuse Reference

Use this when a visual can reuse a vanilla Isaac `.anm2` instead of creating a new skeleton from scratch.

## When To Use

Prefer template reuse when:

- The visual behaves like an existing pickup, collectible, trinket, coin, heart, bomb, card, or grid object.
- Only the spritesheet art changes.
- The animation timing and layers can stay vanilla.
- The code only needs a static or familiar frame from an existing animation.

This reduces risk because vanilla `.anm2` files already have correct animation names, pivots, roots, and gameplay expectations.

## Common Reuse Patterns

Lua can load a vanilla `.anm2`, then replace or select spritesheets:

```lua
local sprite = Sprite()
sprite:Load("gfx/005.100_collectible.anm2", false)
sprite:ReplaceSpritesheet(1, "gfx/items/collectibles/item_name.png")
sprite:LoadGraphics()
sprite:Play("ShopIdle", true)
```

Only use `ReplaceSpritesheet` indices after inspecting the template or copying from a proven local reference.

## Reference Examples

Reverie contains many examples that load vanilla pickup, trinket, coin, grid, and collectible animations from Lua. Search:

- `gfx/005.100_collectible.anm2`
- `gfx/005.350_trinket.anm2`
- `gfx/005.021_penny.anm2`
- `gfx/grid/grid_rock.anm2`

YSD and neverbrith are smaller; use them for custom `.anm2` examples, not broad vanilla reuse coverage.

## Decision Rule

If the requested visual is just "like a vanilla pickup but with new art", reuse a vanilla template.

If the visual needs custom layer motion, custom animation names, or a non-vanilla layout, create a small custom `.anm2`.

## Checklist

- The chosen vanilla template matches the gameplay object.
- Animation name exists in the vanilla template.
- Spritesheet index is verified, not guessed.
- Replacement PNG dimensions match the template crop expectations.
- `LoadGraphics()` is called after `ReplaceSpritesheet`.
- The code has a fallback or clear failure mode if the template path changes.
