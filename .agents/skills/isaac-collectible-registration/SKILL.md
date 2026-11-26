---
name: isaac-collectible-registration
description: "Use when Isaac collectible metadata or a colored pedestal/Extra HUD icon needs registration, or when items.xml, gfxroot, gfx, stable local IDs or a missing collectible PNG are the issue. 中文触发：道具注册、彩色底座图标、Extra HUD、gfxroot、gfx、空白贴图。"
---

# Isaac Collectible Registration

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

Use this skill for the registration and colored display-asset chain shared by
active, passive, and familiar collectibles. Use `isaac-mod-context` first in an
unfamiliar project.

## REPENTOGON Companion

For declared REPENTOGON content, use `isaac-repentogon-content` for conditional
XML loading, native stats/tags/cache and generated null-item identities. Its
matching-build XML and ID contract takes precedence over vanilla-only advice;
a null item's costume-association ID is not a collectible/runtime effect ID.
Keep colored-art and ordinary collectible registration responsibilities here;
compat establishes required/optional packaging before extensions are added.

## Task Scope

For a path-only or existing-image fix, trace the affected entry and PNG, make
only the needed change, and report the requested display check. An unrelated
legacy ID migration, new art, pool change or death-portrait work is separate.
For new registration, check the affected entry's stable local ID and its own
assets. For requested PNG generation or suspected transparency defects, use
the relevant alpha and visual checks below.

## Boundary

This skill owns `items.xml` metadata, `gfxroot`, `gfx`, and the matching colored
collectible PNG. It does not own item balance, pools, held behavior, active-item
charge/use logic, familiar AI, custom Lua HUD drawing, or `deathanm2` sketches.

- Use `isaac-item-economy` for quality, tags, pools, weights, and availability.
- Use `isaac-passive-collectibles`, `isaac-active-item-mechanics`, or
  `isaac-familiars` for behavior.
- Use `isaac-anm2-visuals` for native `deathanm2` item sketches shown by ESC
  My Stuff, the collection page, or Last Will. A colored `gfx` PNG neither
  proves nor replaces that ANM2 route.

Default to official Isaac content conventions and discovered project facts. Do
not require a third-party library or reference-mod checkout.

## Stable Local ID Registration Rule

A new custom collectible must have a declared, unique, stable XML-local `id`
under the established registration policy. Verify the affected entry when
reviewing registration. A path-only fix on an existing legacy entry can
proceed without rewriting its identity or other entries.

- Discover the project's existing local-id convention before assigning a value.
- Do not substitute XML order, a temporary ordinal, `Isaac.GetItemIdByName`,
  an `ItemConfig` value, console output, or a current runtime/global number
  such as `733` for the declared local `id`.
- If the requested registration or portrait mapping actually requires migrating
  an existing entry with no stable ID, follow the project’s migration policy.
  Treat changes to established identities as `TBD — user decision required`
  when no approved migration settles them. Keep other IDs and order intact.
- A project-declared custom loader may add a separate visual mapping key, but it
  does not remove the requirement for the collectible entry's declared local
  `id`.


## Native Death Portrait Registration Gate

Apply this additional gate when the user requests a native ESC My Stuff,
collection-page, or Last Will collectible sketch. The universal local-id rule
above already applies to every collectible; this gate only adds the native
portrait mapping work.

1. Discover the exact requested native surface and route it to `isaac-anm2-visuals`.
2. Use the collectible entry's declared, unique, stable local `id` as the
   candidate death-portrait frame key, then inspect the actual ANM2 convention.
3. A project-declared custom loader may add an equally stable mapping key, but
   it cannot replace the required declared local `id`.
4. If the entry lacks its local `id`, the registration and the portrait route
   are blocked pending the project’s established migration. If its mapping
   requires a new user decision, present the affected entries and consequences.
5. Only after the local key and any loader mapping are approved/discovered may
   the ANM2 frame mapping be edited and verified under another mod load order.

## Discover the Registration Chain

Before changing a collectible, record:

- actual `items.xml` path and root `gfxroot` value;
- entry kind (`active`, `passive`, or `familiar`), registered name, and declared stable local `id`;
- entry `gfx` filename and the resolved colored collectible PNG path;
- existing project naming/casing convention and nearby known-good entry;
- which surface is wrong: colored collectible/pedestal display, Extra HUD, or a
  native death-portrait surface that must route to `isaac-anm2-visuals`.
- for a requested native death portrait: declared stable local id, ANM2 frame convention, declared custom loader key if any, or blocked/migration status.

Do not invent a root, filename, id, or image size. A colored collectible resource
chain is valid only after the current project's `gfxroot` plus per-item `gfx`
resolves to a resource under that project's own tree.

## Colored Gfx Rule

The `gfx` chain is native collectible artwork, not a reason to invent a manual
HUD route or a death-portrait route.

- Do not use `MC_POST_RENDER`, `Sprite:Render`, or world/screen coordinates to
  fake a missing native colored collectible image.
- Do not treat a gameplay callback, active charge, cache calculation, or EID
  description as proof the `gfx` path is valid.
- If the colored image is blank/wrong, inspect the XML entry kind, `gfxroot`,
  `gfx` filename, exact PNG existence/casing, and current-project registration
  load path before changing item behavior.
- If the complaint is about the ESC My Stuff sketch, collection-page sketch, or
  Last Will portrait, do not inspect `gfx` as the sole fix; route to
  `isaac-anm2-visuals` and discover `deathanm2`.

## Colored Collectible Transparency Contract

The native colored collectible `gfx` is a cut-out sprite, not a screenshot or a square thumbnail. A missing alpha channel, a flattened export, or a painted black canvas is rendered as an opaque black square behind the item on its pedestal. Treat that as a failed asset contract, not as a Lua, item-pool, or pedestal problem.

- Default contract for a normal colored collectible PNG: an RGBA PNG with a transparent background. Pixels outside the intended icon silhouette must have `alpha = 0`; their stored RGB value is irrelevant to Isaac once alpha is zero.
- A black outline is allowed when it is attached to and follows the item silhouette. An opaque black rectangle filling the image corners or serving as a uniform backdrop is not an outline and must not be exported as the default item art.
- Do not judge transparency from a file browser thumbnail, an image-model preview, or a screenshot with a checkerboard/black/white matte. Decode the delivered PNG alpha channel. A transparent pixel may still store black or white RGB data; it is invisible only when alpha is zero.
- Do not flatten a generated concept image onto black, export as JPEG, or use a black canvas merely because the generator preview used one. Generate or edit the icon as isolated pixel art, then preserve alpha through the final PNG export.
- A deliberately full-frame black object is possible, but it is an exception: record that visual intent explicitly and require a pedestal screenshot. Do not silently treat an accidental rectangular matte as that exception.
- If the PNG is unavailable, record its alpha and visual state as **Unverified — discovery required**. Note whether the file is missing or inaccessible. A path or size check cannot establish alpha.

### Subject Alpha Mask And Background Review

Do not treat “the file has an alpha channel” as proof that its background is transparent. The generation/editing route must create an explicit **subject alpha mask**: the pixels intended to remain visible, including the chosen silhouette, a tightly attached project-appropriate outline, and intentional attached shadow. Final alpha comes from that mask, not from “every non-key-color pixel becomes alpha 255.”

- Chroma-key removal is only an input-cleanup step. It cannot decide whether a black, grey, or brown region is item art or a background plate.
- Dark pixels **inside** the approved subject mask may be clothing, ink, shadow, or a dark item body. Do not delete them by color.
- Outside the subject mask, dark pixels may remain only when they are a deliberately approved outline immediately adjacent to the silhouette. A deep-color rectangle, card, backdrop, or detached shadow outside that mask is a failed export.
- Review deep black, grey, brown, and other low-luminance regions as geometry, not just exact `RGB(0,0,0)`: inspect whether they form a filled rectangle, an inset plate, or a detached component behind the subject.
- When the user, prompt, or discovered project evidence already identifies a region as an accidental backdrop, generated backing plate, or background contamination, treat that fact as decided and fail the export. Do not reopen it as a TBD or ask whether it was intentional. The full-frame exception applies only when the user or project explicitly establishes that intent.
- Inspect the final PNG composited on three backgrounds: a light-grey checkerboard, solid white, and a representative Isaac room-like color. A black preview background is never an acceptance surface because it hides black matte errors.
- When the asset is a spritesheet, make the same review for every discovered ANM2 crop/frame. Whole-sheet dimensions, an alpha channel, and four transparent corners do not prove each animation frame is clean.
For generated art, modified pixels, or a reported alpha defect, use these checks to review the affected surface:

1. The decoded file is PNG with an alpha channel, not a flattened RGB/JPEG substitute.
2. Compare final alpha against the intended subject mask: outside-mask pixels are alpha-zero except for an explicitly approved outline that is immediately adjacent to the silhouette.
3. Inspect all low-luminance opaque regions, including internal inset rectangles rather than only the four corners. A filled or detached dark plate behind an otherwise smaller icon is a review failure unless the user explicitly chose full-frame art.
4. Composite the exported PNG on light-grey checkerboard, solid white, and a room-like background; the silhouette and any allowed dark outline must remain clean and legible at the discovered native icon size.
5. In game, inspect the colored collectible on a normal pedestal against the room floor. File decoding proves alpha data; the pedestal screenshot proves the requested native surface.
6. For an ANM2 spritesheet, read its actual crop manifest and repeat steps 1-5 for every unique crop/frame; do not validate only the atlas as a whole.
- For a requested ESC My Stuff sketch, use the discovered `deathanm2` route in `isaac-anm2-visuals` and verify that separate consumer.

## Colored-Icon Canvas

Use the target project's known-good icon route and measured canvas. A 32×32
transparent PNG is a baseline for a standard colored collectible when no
project or user specification supplies a different size. Generate or replace
art when requested. Preserve the alpha of unaffected pixels when repairing an
existing asset.

## Registration Contract

Use this block for a new registration, a full review or a handoff. For a
focused fix, report the affected entry, resolved path, change and evidence.

```markdown
## Collectible Registration Contract

- Item kind and registered name:
- items.xml and gfxroot:
- Declared stable local id and migration status:
- gfx filename:
- Resolved colored collectible PNG path:
- PNG alpha/background result, subject-mask rule, three-background review, and any full-frame exception:
- Colored display surface(s) to verify:
- Death-portrait surface delegated to ANM2, if requested:
- Death-portrait ANM2 frame convention / custom loader / blocked migration status:
- Economy fields owned elsewhere:
- Behavior fields owned elsewhere:
- Static and in-game verification:
```

Keep the XML entry type aligned with the intended collectible behavior. A valid
PNG does not prove a passive cache effect or active-use callback works; conversely
working Lua does not prove the colored `gfx` path can resolve.

## Validation

Use `isaac-validators` for XML, duplicate-id, asset-path, and available PNG alpha/background checks when the project supports them. Verify in game by acquiring the owned item and checking the requested colored display surface on a normal pedestal; a black rectangular backing is a failure unless explicitly chosen as the item's full-frame art. Verify any ESC/collection/Last Will
sketch separately through `isaac-anm2-visuals`. Do not call a file-existence
check proof of correct in-game rendering.
