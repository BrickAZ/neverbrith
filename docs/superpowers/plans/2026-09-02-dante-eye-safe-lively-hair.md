# Dante Eye-Safe Lively Hair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Rebuild Dante's eight-frame `512x64` hair Costume so every visible eye/tear/mouth feature remains readable at native `1x` while the hair gains restrained A/B bob and tip lag appropriate to Devil May Cry 5 Dante.

**Architecture:** Keep the existing Null Costume, ANM2, XML registration, Lua lifecycle, pivots, crops, and two-frame directional animations. Replace the broad face-window heuristic with an exact per-frame protected-feature mask, then refactor the deterministic PowerShell generator into fill, outer-boundary, selective-strand, highlight, and frame-composition stages. Regenerate the PNG and evidence only after the current asset is proven red by both face-protection and motion tests.

**Tech Stack:** PowerShell 7, `System.Drawing`, binary-alpha PNG, Isaac `.anm2` XML, Lua lifecycle already present, project PowerShell/Lua validators.

## Global Constraints

- Character appearance may reference only CAPCOM Devil May Cry 5 standard Dante.
- Do not reference Devil May Cry 1-4, animation, reboot/remake, crossover, fan art, or any other version.
- Chusheng is a read-only technical-quality comparison only; copy no ears, brown-hair design, silhouette, palette, pixels, Lua, or resource paths.
- Keep the normal hair as the existing `512x64` `type="none"` Null Costume; do not bake it back into the six normal `32x32` base-head cells.
- Keep `costume_dante_hair.anm2` animation names, two-frame timing, crops, `XPivot=32`, `YPivot=44`, and `YPosition=-5` unchanged unless new coordinate evidence disproves the current contract.
- Keep binary Alpha: every output pixel Alpha is `0` or `255`.
- Add no guns, swords, attacks, Projectile, Laser, damage, stats, starting items, sounds, or gameplay behavior.
- Preserve unrelated dirty-worktree changes.
- Do not commit or push. The current user boundary overrides the plan skill's normal commit checkpoints; use explicit review checkpoints instead.
- Treat automated tests as regression evidence only. Native `1x`, real Isaac rendering, and user approval remain separate states.

---

## File Map

- Create `tests/dante_character_hair_face_protection_test.ps1`: derive protected eye/tear/mouth coordinates from the actual base-head frames and fail on any hair Alpha overlap.
- Create `tests/dante_character_hair_motion_contract_test.ps1`: measure A/B Alpha-shape change and vertical centroid movement without treating the metrics as beauty proof.
- Modify `tools/rebuild-dante-separated-hair.ps1`: replace closed-outline-per-piece construction with fill masses, one computed subject boundary, selective internal separators, broken highlights, safe face corridors, and explicit phase motion.
- Modify `resources/gfx/characters/costumes/costume_dante_hair.png`: deterministic output from the rebuilt generator.
- Modify `tools/render-dante-hair-evidence.ps1`: retain correct official pivot composite and add per-frame protected-feature overlap labels.
- Run `tools/render-dante-character-evidence.ps1` unchanged: regenerate the normal-player composite from the revised hair sheet.
- Modify `reports/dante-character/dante-hair-costume-contact-sheet.png`: regenerated raw/native-1x/4x evidence.
- Modify `reports/dante-character/dante-native-1x-transparent.png`: regenerated transparent-context normal frames.
- Modify `reports/dante-character/dante-native-1x-backgrounds.png`: regenerated checkerboard/white/room-color evidence.
- Modify `reports/dante-character/dante-native-4x-inspection.png`: regenerated nearest-neighbour inspection.
- Modify `reports/dante-character/validation-report.md`: replace the current eye-occlusion failure with measured post-fix results while preserving in-game and user-approval boundaries.
- Modify `docs/skill-tests/dante-character-source-ledger.md`: update the deterministic hair/evidence hashes only; keep source boundaries unchanged.

---

### Task 1: Add the exact face-protection regression

**Files:**
- Create: `tests/dante_character_hair_face_protection_test.ps1`
- Read: `resources/gfx/characters/costumes/character_dante.png`
- Read: `resources/gfx/characters/costumes/costume_dante_hair.png`
- Read: `E:\Isaac - Repentance\resources\gfx\001.000_player.anm2`

**Interfaces:**
- Consumes: official normal-head crops `0,32,64,96`, official left-facing mirror, and the current hair crops `0..448` in `64px` steps.
- Produces: process exit `0` only when all six visible-face hair frames have zero protected-feature overlap; failure text names frame and coordinates.

- [ ] **Step 1: Create the failing test with actual base-frame mapping**

Create the file with these core definitions and the existing project's `Open-BitmapCopy`/`Assert-True` helpers:

```powershell
$frames = @(
    [pscustomobject]@{ Name='Down A'; HairIndex=0; HeadX=0;  Mirror=$false },
    [pscustomobject]@{ Name='Down B'; HairIndex=1; HeadX=32; Mirror=$false },
    [pscustomobject]@{ Name='Right A';HairIndex=2; HeadX=64; Mirror=$false },
    [pscustomobject]@{ Name='Right B';HairIndex=3; HeadX=96; Mirror=$false },
    [pscustomobject]@{ Name='Left A'; HairIndex=6; HeadX=64; Mirror=$true  },
    [pscustomobject]@{ Name='Left B'; HairIndex=7; HeadX=96; Mirror=$true  }
)

function Test-IsProtectedFacePixel {
    param([Drawing.Color]$Pixel, [int]$X, [int]$Y)
    if ($Pixel.A -eq 0) { return $false }
    $darkFeature = $X -ge 6 -and $X -le 25 -and $Y -ge 11 -and $Y -le 20 -and
        (($Pixel.R + $Pixel.G + $Pixel.B) -le 210)
    $tearFeature = $X -ge 5 -and $X -le 26 -and $Y -ge 15 -and $Y -le 27 -and
        ($Pixel.G -ge ($Pixel.R + 20)) -and ($Pixel.B -ge ($Pixel.R + 20))
    return $darkFeature -or $tearFeature
}
```

For each descriptor, read the 32x32 base pixel at `HeadX + sourceX,y`, where `sourceX = 31-x` for mirrored Left frames. Map every protected base coordinate to the 64x64 Costume coordinate `x+16,y+16`. If the corresponding hair pixel is opaque, append:

```powershell
"$($frame.Name): head=$x,$y hair=$($x+16),$($y+16)"
```

Finish with:

```powershell
Assert-True ($violations.Count -eq 0) (
    "Dante hair overlaps protected eye/tear/mouth pixels:`n" + ($violations -join "`n")
)
Write-Output 'Dante hair face-protection contract passed: protected overlap=0 for six visible-face frames'
```

- [ ] **Step 2: Run the test and record RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_face_protection_test.ps1
```

Expected: nonzero exit. The output must include `Down A` and at least one concrete `head=x,y hair=x,y` pair. If the current asset passes, stop and correct the mask against the supplied failing preview before touching the generator.

- [ ] **Step 3: Keep the old broad-window assertion only as a density warning**

In `tests/dante_character_hair_costume_contract_test.ps1`, rename the conceptual role of `faceTransparency` in comments/output to `broadFaceWindowTransparency`. Do not use it as eye-visibility evidence. The new zero-overlap test owns eye/tear/mouth safety.

- [ ] **Step 4: Review checkpoint**

Confirm only the new test and wording changed, the current PNG is untouched, and RED is reproducible. Do not commit.

---

### Task 2: Add the restrained-motion regression

**Files:**
- Create: `tests/dante_character_hair_motion_contract_test.ps1`
- Read: `resources/gfx/characters/costumes/costume_dante_hair.png`

**Interfaces:**
- Consumes: eight 64x64 binary-alpha frames in Down, Right, Up, Left A/B order.
- Produces: per-direction `alphaXor`, `centroidDeltaY`, and row-edge-change diagnostics; process exit `0` only after restrained motion exists in every pair.

- [ ] **Step 1: Write a frame measurement helper**

Use decoded Alpha, not RGB. Return these properties:

```powershell
[pscustomobject]@{
    Visible = $visible             # bool[4096]
    Count = $count
    CentroidX = $sumX / $count
    CentroidY = $sumY / $count
    RowMin = $rowMin               # int[64], -1 when empty
    RowMax = $rowMax               # int[64], -1 when empty
}
```

For each A/B pair calculate:

```powershell
$alphaXor = 0
for ($i = 0; $i -lt 4096; $i++) {
    if ($a.Visible[$i] -xor $b.Visible[$i]) { $alphaXor++ }
}
$centroidDeltaY = $b.CentroidY - $a.CentroidY
$rowsWithEdgeChange = 0
for ($y = 0; $y -lt 64; $y++) {
    if ($a.RowMin[$y] -ne $b.RowMin[$y] -or $a.RowMax[$y] -ne $b.RowMax[$y]) {
        $rowsWithEdgeChange++
    }
}
```

- [ ] **Step 2: Encode regression bands as warnings against rigidity, not aesthetic scores**

Use this direction table:

```powershell
$pairs = @(
    [pscustomobject]@{ Name='Down'; A=0; B=1; MinAlphaXor=48; MinDeltaY=0.50; MaxDeltaY=2.25; MinRows=8  },
    [pscustomobject]@{ Name='Right';A=2; B=3; MinAlphaXor=64; MinDeltaY=0.75; MaxDeltaY=2.50; MinRows=12 },
    [pscustomobject]@{ Name='Up';   A=4; B=5; MinAlphaXor=96; MinDeltaY=0.75; MaxDeltaY=2.75; MinRows=14 },
    [pscustomobject]@{ Name='Left'; A=6; B=7; MinAlphaXor=64; MinDeltaY=0.75; MaxDeltaY=2.50; MinRows=12 }
)
```

Assert all three measurements for each pair and print the measured values. Keep the final message explicit:

```powershell
Write-Output 'Dante hair restrained-motion regression passed; native-1x visual review is still required'
```

- [ ] **Step 3: Run the test and record RED**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_motion_contract_test.ps1
```

Expected: nonzero exit. Current Up must fail with `alphaXor=0` and `centroidDeltaY=0`. Down/side pairs must also fail at least one band.

- [ ] **Step 4: Review checkpoint**

Confirm the current PNG is still untouched and both new regressions fail for their intended reasons. Do not commit.

---

### Task 3: Refactor the generator around one subject boundary

**Files:**
- Modify: `tools/rebuild-dante-separated-hair.ps1`
- Test: `tests/dante_character_hair_generator_idempotency_test.ps1`
- Test: `tests/dante_character_hair_face_protection_test.ps1`

**Interfaces:**
- Consumes: named palette roles, explicit polygon/line coordinates, direction, and phase.
- Produces: a deterministic 64x64 frame bitmap whose internal fill pieces do not receive closed outlines; a 512x64 sheet assembled from eight frames.

- [ ] **Step 1: Replace `Add-Piece` with separated fill and boundary responsibilities**

Add these helpers:

```powershell
function Add-FillPiece {
    param(
        [Drawing.Graphics]$Graphics,
        [Drawing.Color]$Fill,
        [int[]]$Coordinates,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0
    )
    $translated = [Collections.Generic.List[Drawing.Point]]::new()
    foreach ($point in (New-Points -Coordinates $Coordinates)) {
        $translated.Add([Drawing.Point]::new($point.X + $OffsetX, $point.Y + $OffsetY))
    }
    $brush = [Drawing.SolidBrush]::new($Fill)
    try {
        $Graphics.FillPolygon($brush, $translated.ToArray(), [Drawing.Drawing2D.FillMode]::Winding)
    }
    finally { $brush.Dispose() }
}

function Apply-SubjectBoundary {
    param([Drawing.Bitmap]$Frame)
    $visible = [bool[]]::new(4096)
    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 64; $x++) {
            $visible[$y * 64 + $x] = $Frame.GetPixel($x, $y).A -gt 0
        }
    }
    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 64; $x++) {
            if (-not $visible[$y * 64 + $x]) { continue }
            $boundary = $false
            foreach ($delta in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
                $nx=$x+$delta[0]; $ny=$y+$delta[1]
                if ($nx -lt 0 -or $nx -ge 64 -or $ny -lt 0 -or $ny -ge 64 -or
                    -not $visible[$ny * 64 + $nx]) { $boundary=$true; break }
            }
            if ($boundary) { $Frame.SetPixel($x, $y, $Outline) }
        }
    }
}
```

Keep `Add-Strand`, but make it accept frame-local coordinates with optional X/Y offsets. Each `Draw-DownHair`/`Draw-RightHair`/`Draw-UpHair`/`Draw-LeftHair` function draws every fill mass first, calls `Apply-SubjectBoundary` exactly once, and then draws its own short separators and broken highlights. This keeps the sequencing explicit and prevents internal fill polygons from becoming individually sealed plates.

- [ ] **Step 2: Draw each frame on its own 64x64 bitmap**

Add:

```powershell
function New-HairFrame {
    param([ValidateSet('Down','Right','Up','Left')]$Direction, [ValidateSet(0,1)][int]$Phase)
    $frame = [Drawing.Bitmap]::new(64,64,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($frame)
    try {
        $g.Clear([Drawing.Color]::Transparent)
        $g.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
        $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $g.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        & (Get-Command "Draw-$($Direction)Hair") $frame $g $Phase
        return $frame
    }
    finally { $g.Dispose() }
}
```

Assemble the output sheet by drawing each returned frame unscaled at `frameIndex*64,0`. Dispose every frame after copying it.

- [ ] **Step 3: Add an output-time face-mask gate**

After assembling all frames but before saving, call a shared local function that implements the same protected-feature mapping as Task 1. Throw with frame and coordinate list on any overlap. This makes the generator refuse to publish an eye-covering sheet even when the standalone test is skipped.

- [ ] **Step 4: Verify the refactor remains deterministic before the art turns green**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_generator_idempotency_test.ps1
```

Expected at this intermediate point: deterministic hash check passes, while face-protection and motion tests may remain red until Tasks 4 and 5 finish.

- [ ] **Step 5: Review checkpoint**

Confirm the only continuous dark boundary is the computed subject boundary plus explicitly named short internal separators. Do not commit.

---

### Task 4: Redraw Down A/B around the protected face

**Files:**
- Modify: `tools/rebuild-dante-separated-hair.ps1`
- Generate: `resources/gfx/characters/costumes/costume_dante_hair.png`
- Test: `tests/dante_character_hair_face_protection_test.ps1`
- Test: `tests/dante_character_hair_motion_contract_test.ps1`

**Interfaces:**
- Consumes: Task 3 frame builder and face-mask gate.
- Produces: frame 0/1 with readable eyes, off-centre DMC5 fringe, cheek-exterior side locks, and a one-pixel restrained phase bob.

- [ ] **Step 1: Enforce the Down safe corridors in the authored coordinates**

For composite rows `y=29..36`, keep the central face corridor `x=22..41` transparent. Side locks may occupy `x<=21` or `x>=42`. Central fringe pieces inside `x=24..40` must end at `y<=28`.

Use a crown/rear mass bounded approximately by `x=16..49, y=10..29`, then attach unequal external locks:

```powershell
$downLeftLockA  = @(18,22, 22,22, 22,29, 21,36, 20,44, 18,48, 16,44, 17,34)
$downRightLockA = @(42,22, 47,23, 48,29, 47,36, 46,43, 43,47, 42,39)
$downShortBangA = @(25,13, 31,12, 33,16, 31,21, 29,27, 26,28, 27,22, 24,18)
$downSweepBangA = @(31,13, 38,14, 42,18, 41,23, 39,28, 35,28, 36,23, 33,20)
```

Phase B moves the crown/rear mass down one pixel, keeps every central bang endpoint at or above `y=28`, and moves only external lock tips one additional pixel down/outward. Do not translate the protected face corridor into the hair.

- [ ] **Step 2: Replace broad white columns with broken flow highlights**

Use short line/pixel groups no longer than 5 connected pixels, aligned from crown toward the relevant lock. No `Shine` group may form a full-height vertical stripe. Keep the brightest role sparse and separated by Mid/Light pixels.

- [ ] **Step 3: Generate and run the focused tests**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rebuild-dante-separated-hair.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_face_protection_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_motion_contract_test.ps1
```

Expected: Down face overlap becomes `0`; Down motion passes its band. Side/Up failures remain acceptable at this checkpoint and must name those directions only.

- [ ] **Step 4: Review checkpoint**

Render the existing contact sheet and inspect Down A/B at native `1x`. Both eyes must read without captions; the result must not become a symmetric U-shaped curtain. Do not commit.

---

### Task 5: Redraw Right/Left and Up A/B

**Files:**
- Modify: `tools/rebuild-dante-separated-hair.ps1`
- Generate: `resources/gfx/characters/costumes/costume_dante_hair.png`
- Test: `tests/dante_character_hair_face_protection_test.ps1`
- Test: `tests/dante_character_hair_motion_contract_test.ps1`

**Interfaces:**
- Consumes: completed Down frames, Task 3 frame builder, and direction-specific safe corridors.
- Produces: four side frames with visible facing eye and two back frames with actual shape motion and no transparent scalp gutters.

- [ ] **Step 1: Author Right A/B without crossing the visible eye**

For composite rows `y=28..36`, leave `x=32..38` transparent. Keep rear locks primarily at `x=15..28`; curve the front sweep around the eye at `x>=39`. Phase B moves the main mass down 1–2 pixels and moves only the rear/external tips one additional pixel. Preserve the face gate in both phases.

- [ ] **Step 2: Author Left A/B independently**

For composite rows `y=28..36`, leave `x=25..32` transparent. Keep the front sweep primarily at `x<=24` and the rear locks at `x>=36`. Do not mirror the Right pixels. Give Left a different part, crown highlight break, rear volume, and terminal lengths while preserving the same Dante identity.

- [ ] **Step 3: Rebuild Up A/B as overlapping tapered locks**

Use one filled back mass with a computed outer boundary. Divide it with short dark separators that start below the crown. Phase B moves the crown down 1–2 pixels and changes at least three terminal lock tips; never carve transparent vertical gutters through the back mass.

- [ ] **Step 4: Generate and run both new regressions**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\rebuild-dante-separated-hair.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_face_protection_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_motion_contract_test.ps1
```

Expected: both commands exit `0`; output reports zero protected overlap for six visible-face frames and passing motion diagnostics for all four pairs.

- [ ] **Step 5: Run existing hair/static regressions**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_costume_contract_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_hair_generator_idempotency_test.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tests\dante_character_full_atlas_visual_test.ps1
```

Expected: all exit `0`. If an old fill-ratio or minimum-color assertion rejects a visually valid frame, revise that assertion into a blank/density warning rather than filling the crop to satisfy it.

- [ ] **Step 6: Review checkpoint**

Inspect all eight raw frames at `1x` and `4x`. Confirm eyes remain visible, tips taper, highlights break along flow, Up A/B differ in silhouette, and no direction looks like a different hairstyle. Do not commit.

---

### Task 6: Regenerate evidence with explicit overlap reporting

**Files:**
- Modify: `tools/render-dante-hair-evidence.ps1`
- Read/Run unchanged: `tools/render-dante-character-evidence.ps1`
- Generate: `reports/dante-character/dante-hair-costume-contact-sheet.png`
- Generate: `reports/dante-character/dante-native-1x-transparent.png`
- Generate: `reports/dante-character/dante-native-1x-backgrounds.png`
- Generate: `reports/dante-character/dante-native-4x-inspection.png`

**Interfaces:**
- Consumes: revised hair PNG and the same official-pivot base-head composite.
- Produces: raw, native-1x, 4x, and multi-background evidence; visible-face labels include `protected overlap: 0`.

- [ ] **Step 1: Share the face-protection measurement logic with the renderer**

Add a renderer-local `Measure-ProtectedOverlap` using the same frame descriptors, source-pixel predicate, mirror handling, and `+16,+16` mapping as the test. Return an integer count and render it below each native `1x` visible-face composite.

- [ ] **Step 2: Keep the official pivot composite unchanged**

Retain:

```powershell
$g.DrawImageUnscaled($head, 16, 16)
$g.DrawImage($hair,
    [Drawing.Rectangle]::new(0,0,64,64),
    [Drawing.Rectangle]::new($FrameIndex * 64,0,64,64),
    [Drawing.GraphicsUnit]::Pixel)
```

Do not raise the preview layer independently of the runtime ANM2.

- [ ] **Step 3: Regenerate all evidence**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File tools\render-dante-hair-evidence.ps1
powershell -NoProfile -ExecutionPolicy Bypass -File tools\render-dante-character-evidence.ps1
```

Expected: both exit `0`; every named PNG exists at its native documented size.

- [ ] **Step 4: Perform native-scale visual review**

Review without relying on labels:

- Down A/B: both eyes and mouth readable at native `1x`;
- Right/Left A/B: facing eye and tear readable;
- A/B: movement visible but not bouncy or anime-like;
- Up A/B: no exposed scalp and visible terminal change;
- checkerboard, white, and room-color backgrounds: no detached dark pixels or backing plate;
- `4x`: no flat-ended rectangular locks, sealed inner plates, or full-height white stripes.

Record `visual: provisional native-1x pass` only if every item passes. User approval remains absent until the new board is shown to the user.

- [ ] **Step 5: Review checkpoint**

Compare the new board with the user-supplied failing board. The change must be visible in the actual `1x` row, not only in the enlarged row. Do not commit.

---

### Task 7: Update reports and run the complete verification surface

**Files:**
- Modify: `reports/dante-character/validation-report.md`
- Modify: `docs/skill-tests/dante-character-source-ledger.md`
- Test: all Dante-specific PowerShell/Lua tests

**Interfaces:**
- Consumes: final deterministic hashes, overlap/motion diagnostics, evidence images, and validator output.
- Produces: an honest delivery record separating static, native-1x, in-game, and user-approval states.

- [ ] **Step 1: Compute and record final hashes**

Run:

```powershell
Get-FileHash -Algorithm SHA256 -LiteralPath `
  'resources\gfx\characters\costumes\costume_dante_hair.png', `
  'reports\dante-character\dante-hair-costume-contact-sheet.png'
```

Update only the matching hash fields in the report and source ledger. Preserve the DMC5-only and Chusheng technical-only boundaries verbatim.

- [ ] **Step 2: Run all Dante PowerShell tests, including the two new files**

Run each `tests\dante_character_*test.ps1` file with `powershell -NoProfile -ExecutionPolicy Bypass -File`. Expected: every command exits `0`; the face test prints zero overlap and the motion test retains the native-1x disclaimer.

- [ ] **Step 3: Run Lua and XML checks**

Run:

```powershell
lua tests\dante_character_hair_lifecycle_test.lua
luac -p main.lua
luac -p dante_character.lua
lua tests\localization_test.lua
```

Parse `content\players.xml`, `content\costumes2.xml`, and `resources\gfx\characters\costume_dante_hair.anm2` as XML. Expected: all exit successfully.

- [ ] **Step 4: Run project validators**

Run:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth
powershell -NoProfile -ExecutionPolicy Bypass -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .
```

Expected: zero failures. Report warning counts separately and do not attribute unrelated worktree warnings to this fix.

- [ ] **Step 5: Run targeted diff and workspace checks**

Run `git diff --check` against the files in this plan, then list targeted `git status --short`. Confirm no temporary patch, generated diagnostic copy, or unrelated user file is included. Do not commit or push.

- [ ] **Step 6: Final delivery state**

Report no more than the evidence supports:

```text
technical: static pass
visual: provisional native-1x pass
in-game: not verified
user approval: pending review of the new evidence board
```

If any visual review item fails, keep `visual: failed`, fix the pixels, regenerate evidence, and rerun the affected tests before delivery.
