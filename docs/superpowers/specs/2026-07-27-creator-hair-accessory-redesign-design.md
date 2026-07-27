# Creator Hair Accessory Redesign

## Goal

Redraw the Tantan, Daodao, and Yoontoons head accessories as recognizable
hair and lightweight accents rather than recolored copies of Isaac's complete
head silhouette.

This is an in-run Null Costume redesign. It does not replace Isaac's base
head, face, body, player atlas, portraits, or menus.

## Locked Direction

Use the approved **floating hair-piece** approach:

- Hair creates its own silhouette above and beside Isaac's skull.
- Crown clumps may float two to four native pixels above the vanilla head.
- Only bangs and side locks overlap the upper forehead or temples.
- Large interior and rear-side areas stay transparent; the generator must not
  trace or fill the complete vanilla head alpha.
- The base face, eyes, mouth, and vanilla tear streaks remain readable.

## Persona Treatment

### Tantan

- Pink asymmetrical crown clumps, a side-swept fringe, and short outer locks.
- Replace the thick angular glasses with an open one-pixel red upper frame.
- Do not fill lenses or draw a heavy lower frame.
- Keep only a fine bridge and short temple arms so the eyes remain dominant.

### Daodao

- Blue separated crown spikes, a parted fringe, and small side locks.
- Keep the white tissue motif, but attach it at the outer temples rather than
  below the eyes.
- Angle the tissue strips slightly outward and shorten them.
- Maintain at least a two-pixel horizontal gap from the vanilla tear columns
  in the front-facing composite.

### Yoontoons

- Replace the dark head shell with loose dark waves, an open fringe, and two
  separated side locks.
- Keep the existing orange-red glasses identity, but preserve open lenses and
  the visible eyes.
- Retain the small blue accent inside the hair layer.

## Existing Technical Contract

Preserve the current files, ids, direction mapping, and lifecycle:

- Hair atlases remain transparent `256x64` RGBA PNGs.
- Face/accent atlases remain transparent `256x32` RGBA PNGs.
- Each atlas keeps eight `32`-pixel direction/phase cells.
- ANM2 animations remain `HeadDown`, `HeadRight`, `HeadUp`, and `HeadLeft`.
- Existing costume XML ids, priorities, Lua style ids, Jacob/Esau role
  assignment, pair rollback, and Yoontoons eligibility do not change.
- No current resource is deleted or renamed.

## Files In Scope

- `tools/generate-creator-accessory-atlases.ps1`
- `tests/creator_accessory_atlas_visual_test.ps1`
- The six generated PNGs under
  `resources/gfx/characters/costumes/costume_{tantan,daodao,yoontoons}_*.png`
- `reports/creator_accessory_atlases_preview.png`

The six costume ANM2 files are verification inputs and must not change. If a
new silhouette clips, adjust the pixels to fit the existing crop contract.

## Pixel Rules

- Hard pixels only: alpha is exactly `0` or `255`.
- Transparent pixels normalize to transparent black.
- No detached black/red edge pixels outside a connected hair or accent shape.
- Hair may use controlled silhouette expansion inside each `32x64` cell but
  must not cross cell boundaries.
- Front and side face apertures remain transparent in the hair atlas except
  for approved bangs at the upper edge.
- Tantan glasses must not contain a filled rectangular lens region.
- Daodao tissue pixels must not intersect the vanilla front tear masks.
- Back-facing face/accent cells remain blank where the feature would not be
  visible.

## Preview And Acceptance

Regenerate the composite preview on checkerboard, white, and dark room-like
matte. Review front, right, back, and left at both enlarged and native scale.

Acceptance requires:

1. Each persona reads as hair rather than a helmet at native game size.
2. Isaac's face remains the visual base rather than being replaced.
3. Tantan's eyes stay unobstructed by the red frame.
4. Daodao's paper strips are visually separate from Isaac's tear streaks.
5. All eight atlas cells remain non-clipped and correctly mirrored.
6. Deterministic regeneration produces identical SHA-256 hashes.
7. Existing atlas, ANM2, behavior, Lua syntax, XML parse, and neverbrith
   validator checks retain their current passing status.

## Explicit Exclusions

- No full player skin or complete player ANM2.
- No body, clothing, portrait, HUD, menu, or collectible-art changes.
- No Lua Sprite replacement for the costume carrier.
- No gameplay, item pool, localization, costume id, or state-lifecycle change.
