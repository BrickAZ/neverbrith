# Creator Hair Accessory Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Tantan, Daodao, and Yoontoons head-shell pixels with floating hair pieces while thinning Tantan's glasses and moving Daodao's tissues away from Isaac's vanilla tears.

**Architecture:** Keep the existing Null Costume, ANM2, XML id, and Lua lifecycle contracts unchanged. Replace only the deterministic PowerShell drawing primitives and strengthen the atlas test so it rejects complete-head coverage, filled Tantan lenses, and Daodao pixels in the vanilla tear columns.

**Tech Stack:** PowerShell 7, `System.Drawing`, RGBA PNG atlases, Isaac Null Costume ANM2, Lua 5.4 syntax checks, XML static validation.

## Global Constraints

- Hair atlases remain transparent `256x64` RGBA PNGs with eight `32x64` cells.
- Face/accent atlases remain transparent `256x32` RGBA PNGs with eight `32x32` cells.
- Preserve `HeadDown`, `HeadRight`, `HeadUp`, and `HeadLeft`.
- Do not modify the six costume ANM2 files, costume XML ids/priorities, Lua style ids, role assignment, pair rollback, or Yoontoons eligibility.
- Do not delete or rename any current resource.
- Alpha values are exactly `0` or `255`, and transparent RGB is `0,0,0`.
- No full player skin, body, clothing, portrait, HUD, menu, collectible-art, gameplay, item-pool, localization, or lifecycle change.

---

### Task 1: Lock the floating-hair and face-clearance contract

**Files:**
- Modify: `tests/creator_accessory_atlas_visual_test.ps1`
- Test: `tests/creator_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: Six existing PNG atlases under `resources/gfx/characters/costumes/`.
- Produces: Static assertions that reject helmet coverage, Tantan filled lenses, and Daodao tissue/tear overlap.

- [ ] **Step 1: Add cell-region helpers**

Add these helpers below `Get-CellVisibleCount`:

```powershell
function Get-RegionVisibleCount(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$StartX,
    [int]$EndX,
    [int]$StartY,
    [int]$EndY
) {
    $count=0
    for($y=$StartY; $y -le $EndY; $y++) {
        for($x=$StartX; $x -le $EndX; $x++) {
            if($Bitmap.GetPixel(($Cell*32)+$x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}

function Assert-RegionBlank(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$StartX,
    [int]$EndX,
    [int]$StartY,
    [int]$EndY,
    [string]$Message
) {
    Assert-True ((Get-RegionVisibleCount $Bitmap $Cell $StartX $EndX $StartY $EndY) -eq 0) $Message
}
```

- [ ] **Step 2: Tighten per-cell hair coverage**

Change the three hair maxima from `700/680/680` to `300`, keeping their current minima. This makes a full copied Isaac head fail while allowing sparse crowns, bangs, and side locks.

- [ ] **Step 3: Add protected-region assertions**

After the generic atlas loop, load each affected bitmap and assert:

```powershell
$tantanHair=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_tantan_hair.png')
$tantanGlasses=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_tantan_glasses.png')
$daodaoHair=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_daodao_hair.png')
$daodaoTissues=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_daodao_tissue_tears.png')
$yoonHair=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_yoontoons_hair.png')
try {
    foreach($cell in 0,1) {
        Assert-RegionBlank $tantanHair $cell 8 23 29 43 "Tantan front face must remain open"
        Assert-RegionBlank $daodaoHair $cell 8 23 29 43 "Daodao front face must remain open"
        Assert-RegionBlank $yoonHair $cell 8 23 29 43 "Yoontoons front face must remain open"

        Assert-RegionBlank $tantanGlasses $cell 9 12 14 17 "Tantan left lens must stay open"
        Assert-RegionBlank $tantanGlasses $cell 19 22 14 17 "Tantan right lens must stay open"

        Assert-RegionBlank $daodaoTissues $cell 8 23 11 25 `
            "Daodao tissues must stay outside vanilla tear columns"
    }
} finally {
    $tantanHair.Dispose()
    $tantanGlasses.Dispose()
    $daodaoHair.Dispose()
    $daodaoTissues.Dispose()
    $yoonHair.Dispose()
}
```

- [ ] **Step 4: Run the test and verify RED**

Run:

```powershell
& 'tests/creator_accessory_atlas_visual_test.ps1' -Root (Get-Location).Path
```

Expected: FAIL on one or more of the new coverage/face-clearance assertions because the current generator copies the complete vanilla head and places tissues in the eye columns.

---

### Task 2: Replace head-shell tracing with authored hair silhouettes

**Files:**
- Modify: `tools/generate-creator-accessory-atlases.ps1`
- Modify generated assets:
  - `resources/gfx/characters/costumes/costume_tantan_hair.png`
  - `resources/gfx/characters/costumes/costume_tantan_glasses.png`
  - `resources/gfx/characters/costumes/costume_daodao_hair.png`
  - `resources/gfx/characters/costumes/costume_daodao_tissue_tears.png`
  - `resources/gfx/characters/costumes/costume_yoontoons_hair.png`
  - `resources/gfx/characters/costumes/costume_yoontoons_glasses.png`
- Modify: `reports/creator_accessory_atlases_preview.png`
- Test: `tests/creator_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: Existing palette, `Fill-LocalSpan`, cell layout, preview compositor, and fixed ANM2 crop contract.
- Produces: `Draw-HairCell(Bitmap, Cell, Persona, View, Phase)` using authored row masks instead of vanilla source alpha.

- [ ] **Step 1: Add an outlined row-mask renderer**

Replace the source-alpha boundary route with:

```powershell
function Draw-OutlinedRows(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [object[]]$Rows,
    [string]$Persona,
    [int]$Phase
) {
    $mask=New-Object 'bool[,]' 32,64
    foreach($row in $Rows) {
        $y=[int]$row[0]+$Phase
        for($x=[int]$row[1]; $x -le [int]$row[2]; $x++) {
            $mask[$x,$y]=$true
        }
    }
    foreach($row in $Rows) {
        $y=[int]$row[0]+$Phase
        for($x=[int]$row[1]; $x -le [int]$row[2]; $x++) {
            $boundary=$x -eq 0 -or $x -eq 31 -or $y -eq 0 -or $y -eq 63 -or
                -not $mask[$x-1,$y] -or -not $mask[$x+1,$y] -or
                -not $mask[$x,$y-1] -or -not $mask[$x,$y+1]
            Set-LocalPixel $Bitmap $Cell 32 $x $y `
                (Get-HairColor $Persona $boundary $x $y)
        }
    }
}
```

Use authored front, right, and back row tables inside `Draw-HairCell`; left
remains a mirror of right. Add `Get-HairRows(Persona, View)` with explicit
`@(Y, StartX, EndX)` spans for each of the nine persona/view combinations.
The tables must satisfy these exact coordinate envelopes:

- Tantan front/right/back starts at `y=11`, central crown ends at `y=20`, and
  only side-lock spans may continue through `y=32`.
- Daodao front/right/back starts at `y=9`, central crown ends at `y=17`, uses
  three separated spike spans on `y=9..11`, and only side locks continue
  through `y=29`.
- Yoontoons front/right/back starts at `y=11`, central crown ends at `y=18`,
  uses two separated wave lobes on `y=11..12`, and only side locks continue
  through `y=31`.
- Every front table leaves `x=8..23, y=29..43` empty.
- No row starts before `x=3` or ends after `x=30`.
- Each rendered cell stays between its existing minimum and `300` pixels.

Implement `Draw-HairCell` as:

```powershell
function Draw-HairCell(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [string]$Persona,
    [string]$View,
    [int]$Phase
) {
    $rows=Get-HairRows $Persona $View
    Draw-OutlinedRows $Bitmap $Cell $rows $Persona $Phase
    if($Persona -eq 'yoontoons' -and $View -in @('front','right')) {
        Set-LocalPixel $Bitmap $Cell 32 7 (17+$Phase) $palette.YoonBlue
        Set-LocalPixel $Bitmap $Cell 32 8 (17+$Phase) $palette.YoonBlue
    }
}
```

`Get-HairRows` is data only: its returned spans are the authored art and may
be iterated during visual review without changing this interface or any ANM2.

- [ ] **Step 2: Remove vanilla-head tracing from hair generation**

Change:

```powershell
Draw-HairCell $hair $vanillaHead $cell $persona $view.Name $view.Source $view.Phase
```

to:

```powershell
Draw-HairCell $hair $cell $persona $view.Name $view.Phase
```

Delete `Test-FaceAperture`, `Test-SourceAlpha`, and the `VanillaHead/SourceX`
parameters from `Draw-HairCell`. Keep `$vanillaHead` only for the preview
composite.

- [ ] **Step 3: Thin Tantan's glasses**

Replace `Draw-TantanFrontGlasses` and `Draw-TantanSideGlasses` with upper-rim
only pixels:

```powershell
function Draw-TantanFrontGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=11+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 8 12 $y $palette.TantanGlassLight
    Fill-LocalSpan $Bitmap $Cell 32 19 23 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 7 ($y+1) $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 13 ($y+1) $palette.TantanGlass
    Set-LocalPixel $Bitmap $Cell 32 18 ($y+1) $palette.TantanGlass
    Set-LocalPixel $Bitmap $Cell 32 24 ($y+1) $palette.TantanGlassDark
    Fill-LocalSpan $Bitmap $Cell 32 14 17 ($y+1) $palette.TantanGlassDark
}

function Draw-TantanSideGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=11+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 18 25 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 17 ($y+1) $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 26 ($y+1) $palette.TantanGlassDark
}
```

- [ ] **Step 4: Move Daodao's tissues to the outer temples**

Replace the front tissue function with mirrored outward strips whose visible
pixels stay only in `x=2..7` and `x=24..29`:

```powershell
function Draw-DaodaoFrontTissues([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $left=@(@(11,6,7),@(12,5,7),@(13,5,6),@(14,4,6),@(15,4,5),@(16,3,5),@(17,3,4),@(18,2,4))
    foreach($row in $left) {
        Fill-LocalSpan $Bitmap $Cell 32 $row[1] $row[2] ($row[0]+$OffsetY) $palette.Tissue
        Set-LocalPixel $Bitmap $Cell 32 $row[1] ($row[0]+$OffsetY) $palette.TissueDark
        Set-LocalPixel $Bitmap $Cell 32 $row[2] ($row[0]+$OffsetY) $palette.TissueLight
    }
    foreach($row in $left) {
        $x1=31-$row[2]
        $x2=31-$row[1]
        Fill-LocalSpan $Bitmap $Cell 32 $x1 $x2 ($row[0]+$OffsetY) $palette.Tissue
        Set-LocalPixel $Bitmap $Cell 32 $x1 ($row[0]+$OffsetY) $palette.TissueLight
        Set-LocalPixel $Bitmap $Cell 32 $x2 ($row[0]+$OffsetY) $palette.TissueDark
    }
}
```

Replace `Draw-DaodaoSideTissue` with:

```powershell
function Draw-DaodaoSideTissue([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $rows=@(@(11,12,14),@(12,11,14),@(13,11,13),@(14,10,13),
        @(15,10,12),@(16,9,12),@(17,9,11),@(18,8,11))
    foreach($row in $rows) {
        Fill-LocalSpan $Bitmap $Cell 32 $row[1] $row[2] ($row[0]+$OffsetY) $palette.Tissue
        Set-LocalPixel $Bitmap $Cell 32 $row[1] ($row[0]+$OffsetY) $palette.TissueDark
        Set-LocalPixel $Bitmap $Cell 32 $row[2] ($row[0]+$OffsetY) $palette.TissueLight
    }
}
```

- [ ] **Step 5: Regenerate the six PNGs and preview**

Run:

```powershell
& 'tools/generate-creator-accessory-atlases.ps1' -Root (Get-Location).Path
```

Expected: six `generated ...costume_*.png` lines and one preview line.

- [ ] **Step 6: Run the atlas test and verify GREEN**

Run:

```powershell
& 'tests/creator_accessory_atlas_visual_test.ps1' -Root (Get-Location).Path
```

Expected: `creator accessory atlas visual contract passed`.

- [ ] **Step 7: Inspect the preview at enlarged and native scale**

Open `reports/creator_accessory_atlases_preview.png` and reject the output if:

- any hair reads as a closed helmet;
- a face becomes less readable than vanilla Isaac;
- Tantan's glasses cover either eye;
- Daodao's tissues visually merge with vanilla tears;
- any detached outline pixel appears on checker, white, or dark-red matte.

Adjust only row masks or accent coordinates until all three personas pass.

---

### Task 3: Verify determinism and unchanged integration contracts

**Files:**
- Test: `tests/creator_accessory_atlas_visual_test.ps1`
- Test: `tests/creator_accessory_anm2_visual_test.ps1`
- Test: `tests/everchanging_atlas_visual_test.ps1`
- Test: `tests/everchanging_behavior_test.lua`
- Test: `tests/everchanging_full_anm2_contract_test.lua`
- Verify: `content/costumes2.xml`
- Verify: `main.lua`

**Interfaces:**
- Consumes: Regenerated six PNGs and unchanged ANM2/XML/Lua integration.
- Produces: Hash-stable, statically validated game resources ready for in-game visual verification.

- [ ] **Step 1: Verify deterministic PNG regeneration**

Hash the six PNGs, rerun the generator, hash again, and fail if any SHA-256
changes:

```powershell
$files=Get-ChildItem 'resources/gfx/characters/costumes/costume_tantan_*.png',
    'resources/gfx/characters/costumes/costume_daodao_*.png',
    'resources/gfx/characters/costumes/costume_yoontoons_*.png'
$before=@{}
foreach($file in $files){$before[$file.FullName]=(Get-FileHash $file.FullName -Algorithm SHA256).Hash}
& 'tools/generate-creator-accessory-atlases.ps1' -Root (Get-Location).Path
foreach($file in $files){
    if((Get-FileHash $file.FullName -Algorithm SHA256).Hash -ne $before[$file.FullName]){
        throw "nondeterministic atlas: $($file.FullName)"
    }
}
```

- [ ] **Step 2: Run focused visual and behavior tests**

Run:

```powershell
& 'tests/creator_accessory_atlas_visual_test.ps1' -Root (Get-Location).Path
& 'tests/creator_accessory_anm2_visual_test.ps1' -Root (Get-Location).Path
& 'tests/everchanging_atlas_visual_test.ps1' -Root (Get-Location).Path
lua tests/everchanging_behavior_test.lua
lua tests/everchanging_full_anm2_contract_test.lua
```

Expected: all five contracts print their `passed` messages.

- [ ] **Step 3: Run format and project validators**

Run:

```powershell
luac -p main.lua
[xml](Get-Content -Raw -LiteralPath 'content/costumes2.xml') | Out-Null
& 'docs/skills/isaac-validators/scripts/validate-isaac-mod.ps1' -Root . -ModObjectName Neverbirth
& 'docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1' -Root .
git diff --check
```

Expected: Lua syntax and XML parse succeed; both validators report `0
failure(s)`. The three already-known unresolved vanilla Isaac
`players.xml` warnings may remain.

- [ ] **Step 4: Commit only the clean redraw surface**

Stage exactly:

```powershell
git add -- `
  tools/generate-creator-accessory-atlases.ps1 `
  tests/creator_accessory_atlas_visual_test.ps1 `
  reports/creator_accessory_atlases_preview.png `
  resources/gfx/characters/costumes/costume_tantan_hair.png `
  resources/gfx/characters/costumes/costume_tantan_glasses.png `
  resources/gfx/characters/costumes/costume_daodao_hair.png `
  resources/gfx/characters/costumes/costume_daodao_tissue_tears.png `
  resources/gfx/characters/costumes/costume_yoontoons_hair.png `
  resources/gfx/characters/costumes/costume_yoontoons_glasses.png
git commit -m "art: redraw creator accessories as hair"
```

Before committing, require `git diff --cached --name-only` to contain exactly
those nine paths so no pre-existing dirty work is absorbed.

- [ ] **Step 5: Record in-game checks separately**

Do not claim game verification. Ask the user to check:

1. normal Jacob/Esau front, side, back, firing, and movement frames;
2. Tantan eye readability;
3. Daodao tissue separation from vanilla tears;
4. Yoontoons front/side hair silhouette;
5. interaction with one ordinary item costume on each twin.
