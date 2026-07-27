# Creator Accessory Identity Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove Daodao's tissues, redraw Yoontoons as long wavy black hair with a blue accent, and replace both glasses designs with sparse upper-rim cues that do not cover Isaac's eyes.

**Architecture:** Keep the existing Null Costume and ANM2 contracts. Change Daodao's paired runtime role to head-only, make the retained tissue atlas transparent, and update only the deterministic atlas generator for the new hair and glasses pixels. Strengthen the runtime and atlas contracts before changing implementation.

**Tech Stack:** Lua 5.3 behavior tests, PowerShell 7, `System.Drawing`, RGBA PNG atlases, Isaac Null Costume ANM2.

## Global Constraints

- Preserve the existing costume ANM2 filenames, XML ids, priorities, and directional animation names.
- Preserve normal Jacob as Daodao and normal Esau as Tantan.
- Preserve Yoontoons eligibility and Everchanging lifecycle behavior.
- Do not replace the player ANM2 or edit player body, portraits, menus, HUD, or EID.
- Do not delete or rename the retained Daodao tissue resource.
- Do not stage unrelated changes from the dirty working tree.

## File Structure

- `main.lua`: owns the active Everchanging style resources; Daodao changes from `head + face` to `head`.
- `tests/everchanging_behavior_test.lua`: proves the paired role resolves and applies one Daodao costume.
- `tools/generate-creator-accessory-atlases.ps1`: deterministically draws all six atlases and the composite preview.
- `tests/creator_accessory_atlas_visual_test.ps1`: owns RGBA, coverage, transparency, face-clearance, sparse-glasses, and long-side-lock contracts.
- `resources/gfx/characters/costumes/costume_daodao_tissue_tears.png`: retained compatibility atlas, fully transparent.
- `resources/gfx/characters/costumes/costume_tantan_glasses.png`: sparse red upper-rim cues.
- `resources/gfx/characters/costumes/costume_yoontoons_hair.png`: long wavy black-blue hair and blue accent.
- `resources/gfx/characters/costumes/costume_yoontoons_glasses.png`: sparse brown/amber upper-rim cues.
- `reports/creator_accessory_atlases_preview.png`: regenerated four-direction review sheet.

---

### Task 1: Make Daodao Runtime Head-Only

**Files:**
- Modify: `tests/everchanging_behavior_test.lua:131-137,350-395`
- Modify: `main.lua:18229-18248`

**Interfaces:**
- Consumes: `STYLE_SPECS`, `ResolveStyleResources(style, role)`, and paired costume rollback.
- Produces: a `jacob` role whose only slot is `head` and whose only resolved costume id is `17503`.

- [ ] **Step 1: Write the failing runtime assertions**

Change the paired-role assertions to:

```lua
assertEquals(twinsStyle.pairRoles.jacob.slots[1], "head", "Daodao head slot")
assertEquals(twinsStyle.pairRoles.jacob.slots[2], nil, "Daodao has no face slot")
assertEquals(twinsStyle.pairRoles.jacob.resources.face, nil, "Daodao has no face resource")

local jacobResources = api.ResolveStyleResources(twinsStyle, "jacob")
local esauResources = api.ResolveStyleResources(twinsStyle, "esau")
assertEquals(#jacobResources.costumes, 1, "Daodao resolves hair only")
assertEquals(jacobResources.costumes[1].id, 17503, "Daodao hair on Jacob")
assertEquals(esauResources.costumes[1].id, 17501, "Tantan hair on Esau")
assertEquals(esauResources.costumes[2].id, 17502, "Tantan glasses on Esau")
```

Update pair rollback/application assertions so Jacob's last applied and removed
costume is `17503`, while Esau still receives `17501` then `17502`.

- [ ] **Step 2: Run the behavior test and verify RED**

Run:

```powershell
lua tests/everchanging_behavior_test.lua
```

Expected: FAIL because Daodao still declares and resolves the tissue face
costume.

- [ ] **Step 3: Make the minimal runtime change**

Replace only the Jacob role resource set:

```lua
jacob = {
    slots = { "head" },
    resources = {
        head = { costume = "gfx/characters/costume_daodao_hair.anm2" },
    },
},
```

- [ ] **Step 4: Run the behavior test and verify GREEN**

Run:

```powershell
lua tests/everchanging_behavior_test.lua
```

Expected: `everchanging behavior tests passed`.

- [ ] **Step 5: Record a no-stage checkpoint**

Do not stage or commit `main.lua` or the pre-existing untracked behavior test
from this task. The active Everchanging block is not present in `HEAD`; staging
either complete file would capture unrelated prior work. Preserve the verified
working-tree change for in-game use and report this boundary explicitly.

---

### Task 2: Lock the Corrected Pixel Contract

**Files:**
- Modify: `tests/creator_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: six existing costume PNGs, `Get-CellVisibleCount`, and `Get-RegionVisibleCount`.
- Produces: failing contracts for a transparent tissue atlas, sparse glasses, and long Yoontoons side locks.

- [ ] **Step 1: Permit the tissue atlas to be globally blank**

Add `AllowBlank=$true` to the `daodao_tissue_tears` asset and change the face
coverage branch:

```powershell
} elseif($asset.AllowBlank) {
    Assert-True ($visible -eq 0) "$($asset.Name) cell $cell must be blank"
} elseif($cell -in 4,5) {
```

- [ ] **Step 2: Add whole-atlas and glasses helpers**

Add:

```powershell
function Get-VisibleCount([Drawing.Bitmap]$Bitmap) {
    $count=0
    for($y=0; $y -lt $Bitmap.Height; $y++) {
        for($x=0; $x -lt $Bitmap.Width; $x++) {
            if($Bitmap.GetPixel($x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}
```

- [ ] **Step 3: Add the new identity assertions**

Open `costume_yoontoons_glasses.png` in the final test block and assert:

```powershell
Assert-True ((Get-VisibleCount $daodaoTissues) -eq 0) `
    "Daodao tissue atlas must be fully transparent"
foreach($cell in 0,1) {
    Assert-True ((Get-CellVisibleCount $tantanGlasses $cell 32) -le 10) `
        "Tantan glasses must remain micro half-rims"
    Assert-True ((Get-CellVisibleCount $yoonGlasses $cell 32) -le 10) `
        "Yoontoons glasses must remain micro half-rims"
    Assert-RegionBlank $tantanGlasses $cell 13 18 10 18 `
        "Tantan glasses must have no center bridge"
    Assert-RegionBlank $yoonGlasses $cell 13 18 10 18 `
        "Yoontoons glasses must have no center bridge"
    Assert-True (
        (Get-RegionVisibleCount $yoonHair $cell 1 7 32 41) -gt 0 -and
        (Get-RegionVisibleCount $yoonHair $cell 24 30 32 41) -gt 0
    ) "Yoontoons front hair must have long outer side locks"
}
```

Dispose `$yoonGlasses` in the final cleanup.

- [ ] **Step 4: Run the atlas test and verify RED**

Run:

```powershell
& tests/creator_accessory_atlas_visual_test.ps1 -Root (Resolve-Path .)
```

Expected: FAIL because the tissue atlas is visible, both glasses atlases exceed
the micro-rim limit, and the current Yoontoons hair ends too high.

---

### Task 3: Redraw the Generator and Atlases

**Files:**
- Modify: `tools/generate-creator-accessory-atlases.ps1`
- Regenerate: `resources/gfx/characters/costumes/costume_daodao_tissue_tears.png`
- Regenerate: `resources/gfx/characters/costumes/costume_tantan_glasses.png`
- Regenerate: `resources/gfx/characters/costumes/costume_yoontoons_hair.png`
- Regenerate: `resources/gfx/characters/costumes/costume_yoontoons_glasses.png`
- Regenerate: `reports/creator_accessory_atlases_preview.png`

**Interfaces:**
- Consumes: the existing `256x64` hair and `256x32` face atlas layout.
- Produces: deterministic RGBA atlases that satisfy Task 2.

- [ ] **Step 1: Remove Daodao face drawing**

Delete `Draw-DaodaoFrontTissues` and `Draw-DaodaoSideTissue`. Change the Daodao
branch of `Draw-FaceCell` to return without drawing:

```powershell
} elseif($Persona -eq 'daodao') {
    return
} else {
```

- [ ] **Step 2: Replace Tantan glasses with disconnected micro rims**

Use three structural pixels plus one highlight pixel per front rim:

```powershell
function Draw-TantanFrontGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 9 11 $y $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 10 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 8 ($y+1) $palette.TantanGlass
    Fill-LocalSpan $Bitmap $Cell 32 20 22 $y $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 21 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 23 ($y+1) $palette.TantanGlass
}
```

The side view uses `x=20..23` on one row plus one outward temple pixel, with no
lower row or bridge.

- [ ] **Step 3: Redraw Yoontoons hair rows**

Keep an asymmetric parted crown around `y=10..19`, then use uneven waves whose
outer locks continue through `y=38..40`. Front cells must keep `x=8..23`
transparent below the crown, while both outer sides have connected lock
segments. Right-view rows retain the visible-side long lock; left views remain
mirrored by the existing generator.

Place the blue ribbon as a connected `2x2` or `3x2` accent on the outer crown
and add at most two connected blue highlight pixels inside a side lock.

- [ ] **Step 4: Replace Yoontoons glasses with disconnected micro rims**

Use the same sparse geometry as Tantan, substituting dark brown structure and
one amber highlight pixel per front rim. Do not draw a bridge or lower frame.

- [ ] **Step 5: Regenerate all atlases**

Run:

```powershell
& tools/generate-creator-accessory-atlases.ps1 -Root (Resolve-Path .)
```

Expected: all six costume PNG paths and the preview path are printed.

- [ ] **Step 6: Run the atlas test and verify GREEN**

Run:

```powershell
& tests/creator_accessory_atlas_visual_test.ps1 -Root (Resolve-Path .)
```

Expected: `creator accessory atlas visual contract passed`.

- [ ] **Step 7: Verify deterministic output**

Hash the six PNGs, rerun the generator, and compare hashes. Expected: all six
SHA-256 values are unchanged.

- [ ] **Step 8: Commit only the clean art subset**

Stage only the generator, atlas test, modified PNGs, and preview. Do not stage
`main.lua`, `tests/everchanging_behavior_test.lua`, or unrelated working-tree
files.

```powershell
git commit -m "art: correct creator accessory identities"
```

---

### Task 4: Full Static Regression

**Files:**
- Verify only; no planned production edits.

**Interfaces:**
- Consumes: the corrected runtime and atlas outputs.
- Produces: fresh static evidence and a precise in-game handoff.

- [ ] **Step 1: Run focused visual and behavior tests**

```powershell
& tests/creator_accessory_atlas_visual_test.ps1 -Root (Resolve-Path .)
& tests/creator_accessory_anm2_visual_test.ps1 -Root (Resolve-Path .)
& tests/everchanging_atlas_visual_test.ps1 -Root (Resolve-Path .)
lua tests/everchanging_behavior_test.lua
lua tests/everchanging_full_anm2_contract_test.lua
```

Expected: all five commands exit `0`.

- [ ] **Step 2: Parse Lua and costume XML**

```powershell
luac -p main.lua
$null=[xml](Get-Content -Raw content\costumes2.xml)
```

Expected: both commands exit `0`.

- [ ] **Step 3: Run project validators**

```powershell
& docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1 `
    -Root (Resolve-Path .) -ModObjectName Neverbirth
& docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 `
    -Root (Resolve-Path .)
```

Expected: `0 failure(s)` from both validators; the three known vanilla
`players.xml` path warnings may remain.

- [ ] **Step 4: Check final scope**

```powershell
git diff --check
git status --short
```

Expected: no whitespace errors; report unrelated pre-existing changes
separately. Confirm that the Task 3 commit contains only its declared clean art
subset.

- [ ] **Step 5: Hand off in-game verification**

Use `nb_everchanging twins` on normal Jacob/Esau and
`nb_everchanging yoontoons` on an eligible ordinary player. Check four
directions, firing, damage, item pickup, room transition, reroll, and costume
refresh. Static tests do not substitute for these in-game observations.
