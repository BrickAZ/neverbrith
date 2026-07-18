# UI And HUD Sprite Reference

Use this for screen-space visuals: counters, meters, choice panels, debug overlays, active-item sub-UI, button hints, and custom HUD pieces.

## Relationship To Lua Effects

UI/HUD sprites are a subtype of manual Lua `Sprite` effects. They use the same `.anm2` mechanics, but their coordinates and lifetime are screen-oriented rather than world-oriented.

Read `lua-sprite-effects.md` first if the basic `Sprite` lifecycle is unclear.

## Files To Check

- `.anm2` under `resources/gfx/ui/`, `resources/gfx/UI/`, or a mod-specific UI folder.
- Lua render callbacks, usually `MC_POST_RENDER`.
- Tests that stub screen rendering.

Reference examples:

- neverbrith: `resources/gfx/UI/DebugController/DebugControllerKeys.anm2`
- YSD: `resources/gfx/ui/active_count.anm2`
- YSD: `resources/gfx/ui/ui_piano.anm2`
- Reverie: `resources/gfx/reverie/ui/select_frame.anm2`
- Reverie: `resources/gfx/reverie/ui/hunger.anm2`

## Runtime Pattern

```lua
local uiSprite = Sprite()
uiSprite:Load("gfx/UI/ItemName/ItemNamePanel.anm2", true)
uiSprite:Play("Idle", true)

function Neverbirth:RenderItemNameUI()
    uiSprite:Update()
    uiSprite:Render(Vector(40, 32))
end

Neverbirth:AddCallback(ModCallbacks.MC_POST_RENDER, Neverbirth.RenderItemNameUI)
```

Use the repo's existing screen-coordinate helpers if available. Do not mix world positions and screen positions without an explicit conversion.

## UI-Specific Rules

- Decide whether the UI is global or per-player.
- Decide whether it renders only when the item is held, only during an active state, or always in debug mode.
- Avoid creating UI sprites inside the render callback.
- Keep animation names simple: `Idle`, `Press`, `Selected`, `Disabled`, or names already present in the file.
- If the UI responds to keyboard/controller input, keep visual state and input state separate.

## Checklist

- UI uses screen coordinates intentionally.
- `MC_POST_RENDER` or the existing render hook owns rendering.
- Sprite object is cached, not recreated each frame.
- The UI has a hide condition.
- Animations used in code exist in the `.anm2`.
- Tests check render calls or state transitions, not pixel-perfect output.
