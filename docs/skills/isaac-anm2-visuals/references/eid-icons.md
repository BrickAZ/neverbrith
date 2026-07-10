# EID Icon ANM2 Reference

Use this for EID inline icons, transformation icons, card/pill icons, item markers, and small text-embedded visuals.

## Files To Check

- `.anm2` icon file.
- PNG spritesheet, usually 16x16, 24x24, or 32x32.
- EID registration code in `main.lua`.
- Tests that stub `EID.InlineIcons` or `EID:addIcon`.

Reference examples:

- neverbrith: `resources/gfx/EID/DiceSetIcon.anm2`
- YSD: `resources/gfx/eid/player_icons.anm2`
- YSD: `resources/gfx/eid/cardpill_icons.anm2`
- Reverie: `resources/gfx/eid/reverie_inline_icons.anm2`
- Reverie: `resources/gfx/eid/reverie_transformation_icons.anm2`

## Path Casing

The current neverbrith Dice Set code loads:

```lua
"gfx/eid/DiceSetIcon.anm2"
```

while the repository path is under `resources/gfx/EID/`. Keep the existing convention for working code, but verify in tests when changing path casing.

## Icon ANM2 Shape

Small icons should usually have:

- One spritesheet.
- One layer.
- One animation name, often `Transformation`, `Icon`, or a specific icon group name.
- Width and height matching EID registration.
- A stable frame index if multiple frames are used.

## EID Registration Pattern

Use existing neverbrith EID support as the local source of truth. A simplified form:

```lua
local iconSprite = Sprite()
iconSprite:Load("gfx/eid/ItemIcon.anm2", true)
iconSprite:Play("Icon", true)

if EID and type(EID.addIcon) == "function" then
    EID:addIcon("neverbirthItemIcon", "Icon", 0, 16, 16, 0, 0, iconSprite)
elseif EID and type(EID.InlineIcons) == "table" then
    EID.InlineIcons.neverbirthItemIcon = { "Icon", 0, 16, 16, 0, 0, iconSprite }
end
```

Do not register an icon until the sprite loads and the animation name is known.

## Checklist

- Icon dimensions match the PNG crop and EID width/height.
- Animation name exists in the `.anm2`.
- Shortcut key is unique and namespaced.
- Fallback behavior exists when EID is missing.
- Tests verify the EID table entry or `addIcon` call.
- English/Chinese EID text uses the same icon markup when intended.
