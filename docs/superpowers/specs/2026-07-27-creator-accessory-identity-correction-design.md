# Creator Accessory Identity Correction

## Goal

Correct the Tantan, Daodao, and Yoontoons accessories after the first
floating-hair pass:

- Daodao no longer uses tissue strips.
- Yoontoons reads as long, wavy black hair with a blue hair accent rather than
  a generic short hairstyle.
- Tantan and Yoontoons keep their glasses identity without drawing complete
  frames over Isaac's eyes.

## Locked Decisions

- Keep the existing Null Costume carrier and directional head animations.
- Keep the normal Jacob/Esau-only eligibility and role assignment:
  - normal Jacob represents Daodao;
  - normal Esau represents Tantan.
- Keep Yoontoons available as its existing universal Everchanging style.
- Daodao becomes a head-only accessory. Tissue strips are removed from the
  visible design.
- Use the approved **micro half-rim** glasses approach for both Tantan and
  Yoontoons.
- Do not replace Isaac's base player skin, face, body, portraits, menus, or HUD.

## Resource-Purpose Card

| Field | Decision |
| --- | --- |
| Asset purpose | Player head and lightweight face accessories |
| Display surface | In-run player costume layers |
| Carrier / mapping | Existing `type="none"` Null Costumes and their current directional ANM2 files |
| Animation need | Required: `HeadDown`, `HeadRight`, `HeadUp`, and `HeadLeft` |
| Not for | Base player skin, full character replacement, body layer, portrait, menu, HUD, EID, or world effect |

## Visual Design

### Daodao

- Retain the authored blue hair piece.
- Remove the `face` slot from Daodao's paired style resources so only the hair
  costume is applied.
- Keep the existing tissue ANM2/XML registration for compatibility, but make
  its PNG atlas fully transparent and leave it unused by the style.
- No replacement cheek mark, tear, paper strip, or other face decoration is
  introduced.

### Tantan Glasses

- Keep pink hair unchanged unless a pixel must move to prevent a collision with
  the new frame.
- Replace the current long red bars and bridge with two short upper-rim
  segments plus tiny outward temple marks.
- Do not draw a center bridge, lower rims, filled lenses, or pixels over the
  vanilla pupils.
- Use muted dark red for the structural pixels and reserve bright red for at
  most one highlight pixel per visible rim.
- The glasses should read as a red identity cue at native size, not as a second
  pair of eyes.

### Yoontoons Hair

Official identity reference:

- https://www.youtube.com/channel/UCP2pss2ZGxMAaDdqEYUzLRw
- https://crowdmade.com/collections/yoontoons/creator_yoontoons

The new hair must use:

- a dark black-blue crown with a readable center or asymmetric part;
- long, loose, wavy side locks that extend below the vanilla eye line and sit
  outside the cheeks;
- an asymmetric front curl rather than a continuous helmet band;
- a small blue ribbon or tied-back accent and a restrained blue highlight;
- open central face space in front and side views.

The hair must not become a complete recolored Isaac head, a smooth circular
cap, a rigid hood, or a short symmetrical bob.

### Yoontoons Glasses

- Replace the current full rectangular frames with two short dark-brown upper
  rims and tiny outward temple marks.
- Add no center bridge and no lower rim.
- Use one restrained amber highlight pixel on each visible front rim.
- Keep every vanilla pupil and the central nose/mouth area unobstructed.
- In side views, render one short upper rim and one outer temple mark only.

## Atlas and Runtime Contract

- Preserve the six existing PNG canvas sizes:
  - hair atlases: `256x64`;
  - face atlases: `256x32`.
- Preserve the existing eight-cell direction/phase layout.
- Preserve all six ANM2 filenames, costume XML IDs, priorities, animation
  names, and spritesheet paths.
- Change the Daodao paired runtime resource set from `head + face` to `head`
  only.
- Do not change pair rollback, reroll selection, compatibility checks, or
  Everchanging ownership/lifecycle behavior.

## Static Acceptance Checks

1. Every pixel of `costume_daodao_tissue_tears.png` has alpha zero.
2. Daodao's paired role declares only the `head` slot and no tissue costume
   resource.
3. Tantan and Yoontoons front glasses contain no center bridge, lower rim, or
   filled lens block.
4. Each front rim remains a small disconnected upper cue rather than a line
   spanning the face.
5. Yoontoons front and side hair cells contain visible outer side-lock pixels
   below the vanilla eye line while retaining a transparent central face
   aperture.
6. The hair and glasses atlases remain deterministic RGBA PNGs with no detached
   dark/red pixels outside their intended connected shapes.
7. Existing ANM2 paths and directional animation contracts still pass.

## In-Game Acceptance

- Daodao shows blue hair only, with no paper or tissue pixels in any direction.
- Tantan's red accents do not merge with the pupils or resemble thick red
  eyebrows.
- Yoontoons reads first as long black wavy hair with a blue accent.
- Yoontoons' glasses remain recognizable without covering the eyes.
- All three appearances remain stable after room transitions, item pickups,
  rerolls, damage animations, and costume refreshes.
- Other player appearances and unrelated Everchanging styles remain unchanged.

## Scope Exclusions

- No new collectible or gameplay mechanic.
- No full player skin or body costume.
- No portrait, menu, HUD, EID, or item-art changes.
- No deletion or renaming of existing costume resources.
- No unrelated cleanup of the dirty working tree.
