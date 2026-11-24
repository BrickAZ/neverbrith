# RingoTsuga Two-Piece Headgear Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the current three-layer Ringo costume with a face-free full headgear overlay and a newly drawn white T-shirt overlay.

**Architecture:** Keep Everchanging's existing Null Costume carrier, but shrink the Ringo style from `head + face + body` to `head + body`. Generate both atlases deterministically from the existing PowerShell art generator, register two new ANM2 paths, and delete the obsolete live Ringo resources after all references move.

**Tech Stack:** PowerShell 7, System.Drawing, Isaac ANM2 XML, `content/costumes2.xml`, Lua, existing PowerShell/Lua tests.

## Global Constraints

- Preserve the vanilla Isaac face, skin, hands, feet, pivots, crop order, and unrelated collectible costumes.
- Headgear uses `head4`, 256×64 RGBA, eight 32×64 frames.
- T-shirt uses `body0`, 256×256 RGBA, forty visible 32×32 movement frames.
- Visible pixels use binary alpha; transparent pixels have RGB zero.
- No face layer, face pixels, runtime suppression, or third Ringo costume registration remains.
- Do not modify `_backups`; no commit is created in the existing dirty worktree.

---

### Task 1: Make the two-piece contract fail

**Files:**
- Modify: `tests/ringotsuga_accessory_atlas_visual_test.ps1`
- Modify: `tests/ringotsuga_accessory_anm2_visual_test.ps1`

**Interfaces:**
- Consumes: current Ringo three-layer PNG, ANM2, XML, and Lua paths.
- Produces: assertions for `costume_ringotsuga_headgear.*`, `costume_ringotsuga_white_tshirt.*`, and exactly two style slots.

- [ ] Replace the atlas specs with headgear and T-shirt specs; assert the headgear contains no skin, iris, tear, or face-plane pixels.
- [ ] Assert a broad transparent face aperture in front and side cells, true phase differences, mirrored left/right cells, T-shirt neckline transparency, short sleeves, curved hem, and no pixels at foot rows.
- [ ] Assert ANM2 paths/layers and `slots = { "head", "body" }`; reject old `face`, `apple_shell`, `hoodie`, and `apple_storyteller` runtime references.
- [ ] Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
pwsh -NoProfile -File tests/ringotsuga_accessory_anm2_visual_test.ps1
```

Expected: both fail because the two new resource paths and two-slot contract do not exist.

### Task 2: Generate completely new headgear and T-shirt atlases

**Files:**
- Modify: `tools/generate-ringotsuga-accessory-atlases.ps1`
- Create: `resources/gfx/characters/costumes/costume_ringotsuga_headgear.png`
- Create: `resources/gfx/characters/costumes/costume_ringotsuga_white_tshirt.png`
- Modify: `reports/ringotsuga_accessory_atlases_preview.png`

**Interfaces:**
- Produces: `Draw-RingoHeadgear(View, Phase)` and `Draw-WhiteTShirtFrame(View, Phase)` output atlases.

- [ ] Replace `Draw-RingoHair` and `Draw-FacePlane` with one face-free headgear renderer that draws red shell, cream fringe, stem, and leaf around a transparent face aperture.
- [ ] Replace `Draw-HoodieFrame` with a new short-sleeve T-shirt renderer using off-white fill, gray shading, a transparent neckline, and a one-pixel muted-green seam.
- [ ] Remove face atlas creation/compositing; preview vanilla head and body first, then T-shirt and headgear.
- [ ] Run:

```powershell
pwsh -NoProfile -File tools/generate-ringotsuga-accessory-atlases.ps1
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: the atlas contract passes.

### Task 3: Wire exactly two Null Costumes

**Files:**
- Create: `resources/gfx/characters/costume_ringotsuga_headgear.anm2`
- Create: `resources/gfx/characters/costume_ringotsuga_white_tshirt.anm2`
- Modify: `content/costumes2.xml`
- Modify: `main.lua`

**Interfaces:**
- Head path: `gfx/characters/costume_ringotsuga_headgear.anm2`.
- Body path: `gfx/characters/costume_ringotsuga_white_tshirt.anm2`.

- [ ] Adapt the existing head and body ANM2 crop/pivot contracts to the new spritesheet paths and keep all animation names unchanged.
- [ ] Keep Ringo costume IDs 17498 for head and 17500 for body; remove face ID 17499.
- [ ] Change the style to `slots = { "head", "body" }`, update resources and metadata, and leave collectible costume suppression absent.
- [ ] Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_anm2_visual_test.ps1
lua tests/everchanging_behavior_test.lua
lua tests/everchanging_full_anm2_contract_test.lua
```

Expected: all pass.

### Task 4: Remove obsolete live resources and verify

**Files:**
- Delete: old live `costume_ringotsuga_apple_shell.*`, `costume_ringotsuga_face.*`, `costume_ringotsuga_hoodie.*`, and `costume_ringotsuga_apple_storyteller.*`
- Preserve: `resources/gfx/characters/costumes/_backups/**`

- [ ] Prove with `rg` that no runtime reference points to any obsolete path.
- [ ] Delete only the proven-obsolete live files.
- [ ] Run the generator and the complete relevant test suite again.
- [ ] Run:

```powershell
pwsh -NoProfile -File docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1 -Root .
git diff --check
```

Expected: zero validation failures; any pre-existing vanilla player-path warnings are reported separately.
