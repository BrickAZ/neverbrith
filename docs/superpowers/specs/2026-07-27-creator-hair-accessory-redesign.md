# Creator Hair Accessory Redesign

## Locked direction

- Completely redraw the Tantan, Daodao, and Yoontoons hair-only Null Costumes from blank canvases.
- Use three `512x64` RGBA atlases with eight `64x64` cells.
- Keep the existing `HeadDown`, `HeadRight`, `HeadUp`, and `HeadLeft` animation names and two-frame direction order.
- Change the three hair ANM2 layers from `head4` to `head1`; keep `XPivot=32`, `YPivot=44`, and `YPosition=-5`.
- Preserve the existing XML ids, Lua ownership, costume priority, glasses assets, face assets, and gameplay.
- Do not edit the Isaac base head, face, eyes, body, portraits, menus, or UI.
- Tantan uses short pink layered hair, Daodao uses blue-grey tousled hair, and Yoontoons uses dark navy layered hair with longer side locks.

## Reference findings

- Working reference hairs use `64x64` cells rather than squeezing the silhouette into `32x64`.
- Their visible silhouette extends beyond the vanilla head, while the transparent face opening stays centered on the original head.
- The crown, bangs, side locks, and back tips are separate connected clusters with irregular edges, not one continuous cap.
- Black outline, several interior shades, small directional highlights, and asymmetric tip placement make the result read as hair.
- `head1` is the reference-proven carrier for hair that must sit below `head2` glasses.

## Rejected approaches

1. Patch or inflate the existing `256x64` atlases: this preserves their board-like silhouette and cramped coordinate contract.
2. Fill every row from the left edge to the right edge: this produces a helmet cap and removes negative space between locks.
3. Draw a complete replacement head or face: this conflicts with the requested hair-only accessory and with other costumes.
4. Use anti-aliasing or semi-transparent fringe pixels: this recreates the dirty halo visible in game.

## Shape contract

- Each direction is composed independently from crown, bangs, side locks, and back-tip clusters.
- The main hair mass is connected, but transparent notches remain open between tips.
- Front and side directions preserve an open central face window; the back direction forms a layered rear silhouette.
- Tantan and Daodao use short side locks ending around the cheeks. Yoontoons uses longer side locks but leaves the chin open.
- The outer silhouette must occupy at least `32x26` pixels and extend beyond the central vanilla `32px` head width.
- Every animation pair has a one-pixel bob or tip variation and is not byte-identical.
- Only hard alpha is allowed. Transparent pixels have zero RGB. Detached debris and enclosed transparent holes are forbidden.
- Pure black outline plus four or five intentional hair colors are allowed; no texture noise or single-pixel dirt is allowed.

## Surface matrix

| Surface | Requested | Source | Output | Mapping | Acceptance |
| --- | --- | --- | --- | --- | --- |
| In-run player skin | No | Vanilla Isaac actor | Unchanged | Existing player actor | No edits |
| Portrait/name/select/co-op/death art | No | Existing project assets | Unchanged | Existing mappings | No edits |
| Costume / extra head layer | Yes | Reference costume structure plus original creator palettes | Three `512x64` RGBA PNGs | Existing Null Costumes, revised `head1` ANM2 crops | Eight valid `64x64` cells, clean alpha, layered hair silhouette |
| Glasses / face layer | No | Existing creator glasses | Unchanged | Existing `head2` costume route | No edits in this pass |

## Verification

- The revised atlas and ANM2 tests must fail against the current `256x64` / `head4` implementation before production assets change.
- Static checks cover dimensions, crop manifest, pivots, animation names, palette, hard alpha, transparent RGB cleanliness, coverage, bounding box, connected mass, open face, open tip notches, and frame-pair differences.
- A nearest-neighbor preview must composite each direction over the original Isaac head using the same pivots.
- Existing creator registration and Everchanging contracts must remain green.
- Final visual acceptance still requires an in-game front/right/back/left review.
