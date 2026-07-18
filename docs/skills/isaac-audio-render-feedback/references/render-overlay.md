# Render And Overlay

Use this when drawing sprites, text, charge bars, panels, full-screen overlays, or world-space effects outside entity registration.

## Coordinate Space

- Screen-space: HUD, menus, prompts, charge bars, black screens, selection panels.
- World-space: effects at player/entity/room positions.
- Entity render callback: visuals tied to an entity draw pass.
- Player render callback: visuals tied to the player sprite layer.

## Hard Rules

- State coordinate space before writing render math.
- Do not instantiate `Sprite()` every frame.
- Keep gameplay mutation out of render callbacks.
- Use actual `.anm2` animation names when a sprite is involved.
- Report in-game verification needs for scale, layer order, and overlap.

## Review Checklist

- Render callback is appropriate.
- Sprite ownership is explicit.
- Screen/world conversion is correct for the chosen route.
- Visual stops rendering when state ends.

