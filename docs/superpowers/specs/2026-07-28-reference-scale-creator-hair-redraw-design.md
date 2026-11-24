# Reference-Scale Creator Hair Redraw

## Goal

Redraw the Tantan, Daodao, and Yoontoons hair-only Null Costumes so they read
as native-scale hair on top of Isaac's original head instead of oversized
helmet shells.

## Surface Matrix

| Surface | Requested | Source/reference | Output | Carrier evidence | Acceptance |
| --- | --- | --- | --- | --- | --- |
| In-run player skin | No | Vanilla Isaac player atlas | Unchanged | Existing player actor | No base-head or body edits |
| Portrait/name/select/co-op/death art | No | Existing project assets | Unchanged | Existing mappings | No edits |
| Costume / extra head layer | Yes | Current three hair PNGs, vanilla Isaac head, YSD/BMaggy/Satori hair metrics | Three `512x64` RGBA atlases | Existing `head1` Null Costumes, eight `64x64` crops, `XPivot=32`, `YPivot=44`, `YPosition=-5` | Native-scale silhouette, clean face aperture, hard alpha |
| Glasses / face layer | No | Existing creator accessory PNGs | Unchanged | Existing `head2`/face routes | No edits |

## Locked Coordinate Contract

- Preserve the three existing `512x64` canvases and eight ordered `64x64`
  cells: front phase 0/1, right phase 0/1, back phase 0/1, left phase 0/1.
- Preserve the existing hair ANM2 files, animation names, spritesheet paths,
  `head1` layer, pivots, positions, delays, XML ids, priorities, Lua ownership,
  and gameplay.
- A `64x64` cell is a carrier with padding. It is not the required visible
  footprint.
- Draw directly at native one-pixel resolution inside each `64x64` cell. Do
  not author a `32px` cell and upscale it to `64px`.

## Reference Envelope

Measured working references:

| Reference | Average visible bounds |
| --- | --- |
| YSD | `36.5x38` |
| Benighted Maggy | `36.9x31.2` |
| Reverie Satori | `33.5x29` |

The new persona envelopes are:

- Tantan: width `34..38`, height `30..39`.
- Daodao: width `34..39`, height `30..39`.
- Yoontoons: width `36..40`, height `34..42`.
- All visible pixels remain inside local X `12..51` and Y `7..52`.
- No test may require pixels in fixed distant edge bands. Tests constrain
  maximum footprint and anchoring instead of rewarding canvas fill.

## Persona Shapes

### Tantan

- Short pink layered bob.
- Rounded crown broken by a small asymmetric tuft.
- Side-swept fringe formed by two or three tapered locks.
- Short cheek-side locks; the center face and both eyes remain open.

### Daodao

- Blue-grey tousled hair.
- Three separated crown spikes connected to the main crown.
- A visibly parted fringe and compact side locks.
- Shorter lower silhouette than Yoontoons.

### Yoontoons

- Dark navy layered hair.
- Soft uneven crown, open fringe, and two longer but narrow side locks.
- One small cyan-blue accent embedded in the hair mass.
- Longest of the three, but still within the reference-scale envelope.

## Pixel Contract

- Hard pixels only: alpha is exactly `0` or `255`.
- Every transparent pixel stores RGB `0,0,0`.
- Use a one-pixel attached dark outline and three or four flat interior shades.
- No anti-aliasing, semi-transparent fringe, random texture, detached debris,
  or isolated single-pixel dirt.
- Front and side frames keep the eye and mouth bands transparent except for
  controlled upper-forehead bangs.
- Lower rows must split into separate locks rather than closing into a solid
  plate.
- Back frames may close the face opening, but their bottom edge must remain
  layered and irregular.
- Direction pairs use a one-pixel bob/tip variation without changing scale.

## Verification

1. Update the atlas test first so the current oversized PNGs fail their new
   upper-bound and anchoring contracts.
2. Regenerate all three hair PNGs from blank `512x64` canvases.
3. Verify canvas, RGBA, hard alpha, transparent RGB, palette, connected
   components, bounds, anchoring, face clearance, split locks, and paired-frame
   variation.
4. Composite every direction over the original Isaac head at native `1x` and
   nearest-neighbour `4x`.
5. Compare the native preview against the three reference envelopes; a passing
   static test does not override a visibly oversized or helmet-like result.
6. Keep in-game verification separate and pending until the user tests the
   integrated assets.

## Explicit Exclusions

- No glasses, tissue, face, base-head, body, portrait, menu, HUD, collectible,
  Lua behavior, XML registration, or gameplay changes.
- No scaling of the existing oversized masks.
- No copying or compositing reference-mod pixels into the new atlases; the
  references provide coordinate and density evidence only.
