# RingoTsuga Official Mascot Accessories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redraw the three installed RingoTsuga costume atlases as an official-mascot-first apple persona with large cream eyes and a light gray-white shirt, without changing any existing ANM2, Costume, or Lua integration contract.

**Architecture:** Keep the current `head4 + head2 + body0` Null Costume decomposition and fixed atlas coordinates. Update the independent visual-contract test first, then replace only the deterministic pixel data in the PowerShell generator, regenerate the three PNGs and preview, and finally prove that all protected integration files remained byte-identical.

**Tech Stack:** PowerShell 7, `System.Drawing`, RGBA PNG hard-pixel atlases, project-local PowerShell visual tests, existing Lua/validator regression commands.

## Global Constraints

- The approved design is a warm coral-red apple persona head, large cream eyes, a broad green leaf, short brown stem, tiny mouth, minimal cyan tears, and a light gray-white shirt.
- Keep `resources/gfx/characters/costume_ringotsuga_apple_shell.anm2`, `resources/gfx/characters/costume_ringotsuga_face.anm2`, and `resources/gfx/characters/costume_ringotsuga_hoodie.anm2` unchanged.
- Keep Costume IDs `17498`, `17499`, and `17500`, their priorities, and the existing `head/face/body` Lua slots unchanged.
- Apple shell remains `256x64`, eight `32x64` cells, `head4`, `XPivot=16`, `YPivot=44`.
- Face remains `256x32`, eight `32x32` cells, `head2`, `XPivot=16`, `YPivot=28`; Up cells remain transparent.
- Shirt remains at the compatibility path `costume_ringotsuga_hoodie.png`, `256x256`, forty populated `32x32` cells, `body0`, `XPivot=16`, `YPivot=25`.
- Visible alpha is exactly `255`; transparent pixels are exactly RGBA `0,0,0,0`.
- No pure-black visible pixels, antialiasing, gradients, dithering, semi-transparent pixels, detached black/red fringe, dirty transparent RGB, or cross-cell drawing.
- External Ringo imagery is semantic reference only and must not be pasted or scaled into an atlas.
- Static checks and preview review do not count as in-game proof.

## File Structure

- Modify `tests/ringotsuga_accessory_atlas_visual_test.ps1`: owns palette, alpha, crop occupancy, mascot identity, silhouette, and legacy-color rejection checks.
- Modify `tools/generate-ringotsuga-accessory-atlases.ps1`: owns every pixel in the three atlases and the review preview.
- Regenerate `resources/gfx/characters/costumes/costume_ringotsuga_apple_shell.png`: `head4` apple silhouette, stem, leaf, and front/side opening.
- Regenerate `resources/gfx/characters/costumes/costume_ringotsuga_face.png`: `head2` inner apple plane, cream eyes, pupils, mouth, and minimal tears.
- Regenerate `resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png`: `body0` light gray-white shirt and dark gray limbs; path name remains unchanged for compatibility.
- Regenerate `reports/ringotsuga_accessory_atlases_preview.png`: zoomed atlas rows plus four composite directions and native-size composite samples.
- Do not modify `main.lua`, `content/costumes2.xml`, or any Ringo ANM2.

---

### Task 1: Replace the old visual contract with the approved mascot contract

**Files:**
- Modify: `tests/ringotsuga_accessory_atlas_visual_test.ps1`
- Read only: `docs/superpowers/specs/2026-07-25-ringotsuga-official-mascot-accessories-design.md`

**Interfaces:**
- Consumes: the three existing fixed-path PNGs and their current crop grid.
- Produces: a deterministic test that rejects the old cyan-square-eye/navy-body artwork and accepts only the approved palette and identity signals.

- [ ] **Step 1: Record hashes for protected integration files**

Run:

```powershell
$protected = @(
    'main.lua',
    'content\costumes2.xml',
    'resources\gfx\characters\costume_ringotsuga_apple_shell.anm2',
    'resources\gfx\characters\costume_ringotsuga_face.anm2',
    'resources\gfx\characters\costume_ringotsuga_hoodie.anm2'
)
$baseline = foreach ($path in $protected) {
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $path
    [pscustomobject]@{ Path = $path; Hash = $hash.Hash }
}
$baseline | ConvertTo-Json | Set-Content -Encoding UTF8 -LiteralPath 'C:\tmp\ringotsuga-protected-hashes.json'
```

Expected: `C:\tmp\ringotsuga-protected-hashes.json` contains five path/hash records and no project file changes.

- [ ] **Step 2: Replace the test palette**

Replace the current `$palette` assignment with:

```powershell
$palette = @(
    [System.Drawing.Color]::FromArgb(255, 51, 32, 38),    # AppleEdge
    [System.Drawing.Color]::FromArgb(255, 109, 52, 56),   # AppleInnerEdge
    [System.Drawing.Color]::FromArgb(255, 169, 67, 62),   # AppleDark
    [System.Drawing.Color]::FromArgb(255, 217, 102, 85),  # Apple
    [System.Drawing.Color]::FromArgb(255, 240, 128, 104), # AppleLight
    [System.Drawing.Color]::FromArgb(255, 246, 160, 128), # AppleShine
    [System.Drawing.Color]::FromArgb(255, 240, 227, 202), # EyeCream
    [System.Drawing.Color]::FromArgb(255, 48, 38, 42),    # FaceDark
    [System.Drawing.Color]::FromArgb(255, 114, 215, 215), # Tear
    [System.Drawing.Color]::FromArgb(255, 58, 42, 36),    # StemDark
    [System.Drawing.Color]::FromArgb(255, 111, 77, 50),   # Stem
    [System.Drawing.Color]::FromArgb(255, 52, 88, 68),    # LeafDark
    [System.Drawing.Color]::FromArgb(255, 86, 130, 93),   # Leaf
    [System.Drawing.Color]::FromArgb(255, 126, 163, 108), # LeafLight
    [System.Drawing.Color]::FromArgb(255, 40, 40, 44),    # ShirtEdge
    [System.Drawing.Color]::FromArgb(255, 160, 157, 149), # ShirtShadow
    [System.Drawing.Color]::FromArgb(255, 211, 206, 194), # Shirt
    [System.Drawing.Color]::FromArgb(255, 238, 230, 215), # ShirtLight
    [System.Drawing.Color]::FromArgb(255, 58, 53, 57)     # Limb
)
```

Also change the body atlas label from `'hoodie'` to `'shirt'` and lower its per-cell `MinimumPixels` from `95` to `70` so the test allows the approved smaller body silhouette.

- [ ] **Step 3: Add reusable color-count and row-coverage helpers**

Add after `Get-VisibleCount`:

```powershell
function Get-ColorCount {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int[]]$Rgb
    )

    $count = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.A -eq 255 -and
                $pixel.R -eq $Rgb[0] -and
                $pixel.G -eq $Rgb[1] -and
                $pixel.B -eq $Rgb[2]) {
                $count++
            }
        }
    }
    return $count
}

function Get-VisibleXs {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Cell,
        [int]$CellWidth,
        [int]$Y
    )

    $originX = $Cell * $CellWidth
    $xs = @()
    for ($x = 0; $x -lt $CellWidth; $x++) {
        if ($Bitmap.GetPixel($originX + $x, $Y).A -eq 255) {
            $xs += $x
        }
    }
    return @($xs)
}

function Get-CellColorCount {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Cell,
        [int]$CellWidth,
        [int]$CellHeight,
        [int[]]$Rgb
    )

    $originX = $Cell * $CellWidth
    $count = 0
    for ($y = 0; $y -lt $CellHeight; $y++) {
        for ($x = 0; $x -lt $CellWidth; $x++) {
            $pixel = $Bitmap.GetPixel($originX + $x, $y)
            if ($pixel.A -eq 255 -and
                $pixel.R -eq $Rgb[0] -and
                $pixel.G -eq $Rgb[1] -and
                $pixel.B -eq $Rgb[2]) {
                $count++
            }
        }
    }
    return $count
}
```

- [ ] **Step 4: Replace legacy identity assertions**

Delete the old `$faceCyan`, `$faceRed`, and navy-specific expectations. Add inside the existing `try` block after the shell opening/back checks:

```powershell
$topRow = Get-VisibleXs -Bitmap $shell -Cell 0 -CellWidth 32 -Y 22
$bellyRow = Get-VisibleXs -Bitmap $shell -Cell 0 -CellWidth 32 -Y 34
$bottomRow = Get-VisibleXs -Bitmap $shell -Cell 0 -CellWidth 32 -Y 45
if ($topRow -contains 15 -or $topRow -contains 16) {
    throw 'apple shell front lacks the approved top cleft'
}
if ($bellyRow.Count -lt 24) {
    throw "apple shell front is not broad enough at the belly: $($bellyRow.Count)"
}
if ($bottomRow.Count -gt 12) {
    throw "apple shell front does not taper at the bottom: $($bottomRow.Count)"
}

$leafPixels = 0
for ($y = 14; $y -le 22; $y++) {
    for ($x = 17; $x -le 27; $x++) {
        $pixel = $shell.GetPixel($x, $y)
        if ($pixel.A -eq 255 -and $pixel.G -gt $pixel.R) {
            $leafPixels++
        }
    }
}
if ($leafPixels -lt 24) {
    throw "apple shell leaf is too small or narrow: $leafPixels"
}

$eyeCream = Get-ColorCount -Bitmap $face -Rgb @(240, 227, 202)
$tearPixels = Get-ColorCount -Bitmap $face -Rgb @(114, 215, 215)
$frontEyeCream = Get-CellColorCount -Bitmap $face -Cell 0 -CellWidth 32 -CellHeight 32 -Rgb @(240, 227, 202)
if ($eyeCream -lt 220) { throw "too few cream mascot-eye pixels: $eyeCream" }
if ($frontEyeCream -lt 60) { throw "front mascot eyes are too small: $frontEyeCream" }
if ($tearPixels -lt 12 -or $tearPixels -gt 80) {
    throw "cyan must remain a minimal tear accent, got $tearPixels pixels"
}

$shirtBase = Get-ColorCount -Bitmap $hoodie -Rgb @(211, 206, 194)
$shirtLight = Get-ColorCount -Bitmap $hoodie -Rgb @(238, 230, 215)
$legacyNavy = `
    (Get-ColorCount -Bitmap $hoodie -Rgb @(20, 43, 79)) + `
    (Get-ColorCount -Bitmap $hoodie -Rgb @(27, 70, 125)) + `
    (Get-ColorCount -Bitmap $hoodie -Rgb @(42, 105, 169))
if (($shirtBase + $shirtLight) -lt 1700) {
    throw "too few light-shirt pixels: $($shirtBase + $shirtLight)"
}
if ($legacyNavy -ne 0) {
    throw "legacy navy hoodie pixels remain: $legacyNavy"
}
```

Keep the current binary-alpha, transparent-RGB, palette-membership, pure-black, cell occupancy, component count, shell opening/back, and right/left mirror assertions.

- [ ] **Step 5: Run the new contract and verify RED**

Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: non-zero exit. The first failure must be caused by the old artwork violating the new palette or mascot identity contract, not by a syntax or missing-file error.

- [ ] **Step 6: Commit the failing visual contract**

```powershell
git add -- tests/ringotsuga_accessory_atlas_visual_test.ps1
git commit -m "test: define Ringo official mascot visual contract"
```

Expected: one commit containing only the visual test.

---

### Task 2: Redraw all three atlases in the deterministic generator

**Files:**
- Modify: `tools/generate-ringotsuga-accessory-atlases.ps1`
- Regenerate: `resources/gfx/characters/costumes/costume_ringotsuga_apple_shell.png`
- Regenerate: `resources/gfx/characters/costumes/costume_ringotsuga_face.png`
- Regenerate: `resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png`
- Regenerate: `reports/ringotsuga_accessory_atlases_preview.png`
- Test: `tests/ringotsuga_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: the locked palette and identity checks from Task 1; existing `Set-LocalPixel`, `Fill-LocalSpan`, `Fill-LocalRect`, `Copy-Cell`, and `Mirror-Cell` helpers.
- Produces: three deterministic, installed, fixed-grid PNG atlases and one nearest-neighbor review preview.

- [ ] **Step 1: Replace the generator palette**

Replace the current `$palette` block with:

```powershell
$palette = @{
    Transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    AppleEdge = [System.Drawing.Color]::FromArgb(255, 51, 32, 38)
    AppleInnerEdge = [System.Drawing.Color]::FromArgb(255, 109, 52, 56)
    AppleDark = [System.Drawing.Color]::FromArgb(255, 169, 67, 62)
    Apple = [System.Drawing.Color]::FromArgb(255, 217, 102, 85)
    AppleLight = [System.Drawing.Color]::FromArgb(255, 240, 128, 104)
    AppleShine = [System.Drawing.Color]::FromArgb(255, 246, 160, 128)
    EyeCream = [System.Drawing.Color]::FromArgb(255, 240, 227, 202)
    FaceDark = [System.Drawing.Color]::FromArgb(255, 48, 38, 42)
    Tear = [System.Drawing.Color]::FromArgb(255, 114, 215, 215)
    StemDark = [System.Drawing.Color]::FromArgb(255, 58, 42, 36)
    Stem = [System.Drawing.Color]::FromArgb(255, 111, 77, 50)
    LeafDark = [System.Drawing.Color]::FromArgb(255, 52, 88, 68)
    Leaf = [System.Drawing.Color]::FromArgb(255, 86, 130, 93)
    LeafLight = [System.Drawing.Color]::FromArgb(255, 126, 163, 108)
    ShirtEdge = [System.Drawing.Color]::FromArgb(255, 40, 40, 44)
    ShirtShadow = [System.Drawing.Color]::FromArgb(255, 160, 157, 149)
    Shirt = [System.Drawing.Color]::FromArgb(255, 211, 206, 194)
    ShirtLight = [System.Drawing.Color]::FromArgb(255, 238, 230, 215)
    Limb = [System.Drawing.Color]::FromArgb(255, 58, 53, 57)
}
```

- [ ] **Step 2: Redraw the `head4` apple silhouette**

Replace `Draw-AppleSilhouette` while keeping its signature. Use these exact outer rows for the apple body:

```powershell
$edgeSpans = @(
    @(22, 12, 14), @(22, 17, 19),
    @(23, 9, 22), @(24, 6, 25), @(25, 4, 27),
    @(26, 3, 28), @(27, 2, 29), @(28, 2, 29),
    @(29, 2, 30), @(30, 2, 30), @(31, 2, 30),
    @(32, 2, 30), @(33, 2, 30), @(34, 2, 30),
    @(35, 2, 30), @(36, 2, 30), @(37, 2, 30),
    @(38, 2, 30), @(39, 3, 29), @(40, 3, 28),
    @(41, 4, 27), @(42, 5, 26), @(43, 7, 24),
    @(44, 10, 22), @(45, 13, 19)
)
```

Draw each row with `AppleEdge`, then draw the interior one pixel inset using `Apple`. Preserve the split row at `y=22`; do not fill `x=15..16`, which creates the approved top cleft. Add:

```powershell
foreach ($span in $edgeSpans) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.AppleEdge
    if (($span[2] - $span[1]) -ge 2) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
            -Y $span[0] -X1 ($span[1] + 1) -X2 ($span[2] - 1) -Color $palette.Apple
    }
}
foreach ($span in @(
    @(24, 10, 17), @(25, 8, 16), @(26, 7, 14),
    @(27, 6, 12), @(28, 5, 9)
)) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.AppleLight
}
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 25 -X1 10 -X2 13 -Color $palette.AppleShine
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 38 -X1 3 -X2 6 -Color $palette.AppleDark
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 39 -X1 4 -X2 8 -Color $palette.AppleDark
```

Draw the short stem and broad leaf with:

```powershell
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 14 -Y1 14 -X2 17 -Y2 21 -Color $palette.StemDark
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 15 -Y1 15 -X2 16 -Y2 21 -Color $palette.Stem
foreach ($span in @(
    @(15, 20, 24), @(16, 18, 26), @(17, 17, 27),
    @(18, 17, 27), @(19, 18, 26), @(20, 19, 25),
    @(21, 21, 23)
)) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.LeafDark
}
foreach ($span in @(
    @(16, 20, 23), @(17, 19, 25), @(18, 18, 25),
    @(19, 19, 24), @(20, 20, 23)
)) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Leaf
}
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 16 -X1 21 -X2 23 -Color $palette.LeafLight
```

Keep the existing front/side/back branch structure, but use these openings:

```powershell
$holeSpans = if ($View -eq 'front') {
    @(
        @(27, 10, 21), @(28, 8, 23), @(29, 7, 24),
        @(30, 6, 25), @(31, 6, 25), @(32, 6, 25),
        @(33, 6, 25), @(34, 6, 25), @(35, 6, 25),
        @(36, 6, 25), @(37, 7, 24), @(38, 7, 24),
        @(39, 8, 23), @(40, 10, 21), @(41, 12, 19)
    )
}
else {
    @(
        @(27, 17, 23), @(28, 15, 25), @(29, 14, 26),
        @(30, 13, 27), @(31, 13, 27), @(32, 13, 27),
        @(33, 13, 27), @(34, 13, 27), @(35, 13, 27),
        @(36, 14, 26), @(37, 15, 25), @(38, 17, 23)
    )
}
```

Process the back/opening branch with:

```powershell
if ($View -eq 'back') {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 29 -X1 25 -X2 27 -Color $palette.AppleDark
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 30 -X1 26 -X2 28 -Color $palette.AppleDark
    return
}

foreach ($span in $holeSpans) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Transparent
    Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -X ($span[1] - 1) -Y $span[0] -Color $palette.AppleInnerEdge
    Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -X ($span[2] + 1) -Y $span[0] -Color $palette.AppleInnerEdge
}
$firstHole = $holeSpans[0]
$lastHole = $holeSpans[-1]
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
    -Y ($firstHole[0] - 1) -X1 $firstHole[1] -X2 $firstHole[2] -Color $palette.AppleInnerEdge
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
    -Y ($lastHole[0] + 1) -X1 $lastHole[1] -X2 $lastHole[2] -Color $palette.AppleInnerEdge
```

- [ ] **Step 3: Redraw `head2` with large cream mascot eyes**

Keep the current `Draw-FacePlane` signature. Replace its red connected inner-face plane with:

```powershell
$edgeSpans = @(
    @(6, 13, 18), @(7, 10, 21), @(8, 8, 23),
    @(9, 7, 24), @(10, 6, 25), @(11, 5, 26),
    @(12, 5, 26), @(13, 5, 26), @(14, 5, 26),
    @(15, 5, 26), @(16, 5, 26), @(17, 5, 26),
    @(18, 5, 26), @(19, 5, 26), @(20, 5, 26),
    @(21, 6, 25), @(22, 6, 25), @(23, 7, 24),
    @(24, 9, 22), @(25, 12, 19), @(26, 14, 17)
)
foreach ($span in $edgeSpans) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.AppleInnerEdge
    if (($span[2] - $span[1]) -ge 2) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
            -Y $span[0] -X1 ($span[1] + 1) -X2 ($span[2] - 1) -Color $palette.Apple
    }
}
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 9 -X1 10 -X2 15 -Color $palette.AppleLight
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 10 -X1 8 -X2 12 -Color $palette.AppleLight
```

Replace the front facial features with:

```powershell
foreach ($span in @(
    @(12, 9, 12), @(13, 7, 13), @(14, 7, 13),
    @(15, 7, 13), @(16, 7, 13), @(17, 7, 13), @(18, 9, 12),
    @(12, 19, 22), @(13, 18, 24), @(14, 18, 24),
    @(15, 18, 24), @(16, 18, 24), @(17, 18, 24), @(18, 19, 22)
)) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.EyeCream
}
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 10 -Y1 15 -X2 11 -Y2 16 -Color $palette.FaceDark
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 20 -Y1 14 -X2 21 -Y2 15 -Color $palette.FaceDark
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 21 -X1 14 -X2 17 -Color $palette.FaceDark
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 22 -X1 15 -X2 16 -Color $palette.FaceDark
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 19 -X1 9 -X2 10 -Color $palette.Tear
Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X 9 -Y 20 -Color $palette.Tear
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 19 -X1 21 -X2 22 -Color $palette.Tear
Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X 22 -Y 20 -Color $palette.Tear
```

Replace the side features with:

```powershell
foreach ($span in @(
    @(12, 19, 22), @(13, 17, 24), @(14, 17, 24),
    @(15, 17, 24), @(16, 17, 24), @(17, 17, 24), @(18, 19, 22)
)) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 `
        -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.EyeCream
}
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 20 -Y1 14 -X2 21 -Y2 15 -Color $palette.FaceDark
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 20 -X1 25 -X2 26 -Color $palette.FaceDark
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y 19 -X1 21 -X2 22 -Color $palette.Tear
Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X 22 -Y 20 -Color $palette.Tear
```

Continue copying Down frame `0 -> 1`, side frame `2 -> 3`, mirroring `2 -> 6`, copying `6 -> 7`, and leaving Up cells `4,5` untouched.

- [ ] **Step 4: Redraw `body0` as a light gray-white shirt**

Keep the `Draw-HoodieFrame` name and signature for compatibility. Keep the existing bob and step sequences. Replace navy spans with:

```powershell
$edgeSpans = if ($View -eq 'right') {
    @(
        @(12, 13, 19), @(13, 11, 21), @(14, 10, 22),
        @(15, 9, 23), @(16, 8, 23), @(17, 8, 23),
        @(18, 8, 23), @(19, 8, 23), @(20, 8, 23),
        @(21, 8, 23), @(22, 9, 22), @(23, 9, 22),
        @(24, 10, 21), @(25, 11, 20)
    )
}
else {
    @(
        @(12, 13, 18), @(13, 11, 20), @(14, 10, 21),
        @(15, 9, 22), @(16, 8, 23), @(17, 8, 23),
        @(18, 8, 23), @(19, 8, 23), @(20, 8, 23),
        @(21, 8, 23), @(22, 9, 22), @(23, 9, 22),
        @(24, 10, 21), @(25, 11, 20)
    )
}
$fillSpans = @(
    @(13, 13, 18), @(14, 11, 20), @(15, 10, 21),
    @(16, 9, 22), @(17, 9, 22), @(18, 9, 22),
    @(19, 9, 22), @(20, 9, 22), @(21, 9, 22),
    @(22, 10, 21), @(23, 10, 21), @(24, 12, 19)
)
```

Draw the shirt rows and view-specific details with:

```powershell
foreach ($span in $edgeSpans) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY `
        -Y ($span[0] + $bob) -X1 $span[1] -X2 $span[2] -Color $palette.ShirtEdge
}
foreach ($span in $fillSpans) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY `
        -Y ($span[0] + $bob) -X1 $span[1] -X2 $span[2] -Color $palette.Shirt
}
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 7 -Y1 (17 + $bob) -X2 9 -Y2 (21 + $bob) -Color $palette.Limb
Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 22 -Y1 (17 + $bob) -X2 24 -Y2 (21 + $bob) -Color $palette.Limb
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (14 + $bob) -X1 11 -X2 18 -Color $palette.ShirtLight
Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (23 + $bob) -X1 11 -X2 20 -Color $palette.ShirtShadow
if ($View -eq 'front') {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY `
        -Y (14 + $bob) -X1 14 -X2 17 -Color $palette.ShirtShadow
}
elseif ($View -eq 'back') {
    Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY `
        -X 12 -Y (14 + $bob) -Color $palette.ShirtLight
}
else {
    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY `
        -X1 22 -Y1 (18 + $bob) -X2 22 -Y2 (22 + $bob) -Color $palette.ShirtShadow
}
```

Animate feet without detaching them:

```powershell
if ($step -lt 0) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (26 + $bob) -X1 10 -X2 13 -Color $palette.Limb
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (25 + $bob) -X1 18 -X2 20 -Color $palette.Limb
}
elseif ($step -gt 0) {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (25 + $bob) -X1 11 -X2 13 -Color $palette.Limb
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (26 + $bob) -X1 18 -X2 21 -Color $palette.Limb
}
else {
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (25 + $bob) -X1 11 -X2 13 -Color $palette.Limb
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (25 + $bob) -X1 18 -X2 20 -Color $palette.Limb
}
```

Continue drawing Right/Down/Up for all ten phases and mirroring Right into Left.

- [ ] **Step 5: Add native-size composites to the preview**

Keep the current checkerboard, zoomed atlases, and `3x` four-direction composites. After each direction's zoomed composite is drawn, also draw it at scale `1`:

```powershell
Draw-ScaledRegion -Source $composite -Target $preview `
    -SourceX 0 -SourceY 0 -Width 64 -Height 64 `
    -TargetX 1160 -TargetY (76 + ($index * 230)) -Scale 1
```

This preview is review-only and must not be referenced by ANM2 or XML.

- [ ] **Step 6: Generate the three atlases and preview**

Run:

```powershell
pwsh -NoProfile -File tools/generate-ringotsuga-accessory-atlases.ps1
```

Expected: output confirms the three costume PNG paths and `reports/ringotsuga_accessory_atlases_preview.png` were generated.

- [ ] **Step 7: Run the mascot visual contract and verify GREEN**

Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
```

Expected:

```text
Ringo accessory atlas visual contract passed
```

If the failure reports a disconnected component, change the owning frame so the limb, leaf, eye overlay, or foot touches its intended body; do not weaken the component assertion.

- [ ] **Step 8: Review the generated preview at zoomed and native sizes**

Open:

```text
reports/ringotsuga_accessory_atlases_preview.png
```

Approve only if all four directions:

- read as one apple-headed person rather than stacked circles;
- have a visible top cleft, short stem, and broad leaf;
- use large cream eyes with small pupils;
- use cyan only as short tears;
- have a visibly smaller light gray-white shirt body;
- contain no black/red fringe or detached pixels.

If any check fails, adjust only the three drawing functions, regenerate, and repeat Steps 6–8 before committing.

- [ ] **Step 9: Commit generator and generated art**

```powershell
git add -- `
    tools/generate-ringotsuga-accessory-atlases.ps1 `
    resources/gfx/characters/costumes/costume_ringotsuga_apple_shell.png `
    resources/gfx/characters/costumes/costume_ringotsuga_face.png `
    resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png `
    reports/ringotsuga_accessory_atlases_preview.png
git commit -m "art: redraw Ringo as official apple mascot"
```

Expected: one commit containing only the generator, three atlases, and review preview.

---

### Task 3: Prove integration stability and prepare the in-game check

**Files:**
- Test: `tests/ringotsuga_accessory_atlas_visual_test.ps1`
- Test: `tests/ringotsuga_accessory_anm2_visual_test.ps1`
- Read only: `main.lua`
- Read only: `content/costumes2.xml`
- Read only: the three Ringo ANM2 files

**Interfaces:**
- Consumes: the passing atlases from Task 2 and the protected-file baseline from Task 1.
- Produces: static proof that art changed without integration drift, plus a precise game verification checklist.

- [ ] **Step 1: Re-run both Ringo contracts**

Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
pwsh -NoProfile -File tests/ringotsuga_accessory_anm2_visual_test.ps1
```

Expected:

```text
Ringo accessory atlas visual contract passed
Ringo accessory ANM2 and integration contract passed
```

- [ ] **Step 2: Verify protected integration files remained byte-identical**

Run:

```powershell
$baseline = Get-Content -Raw -LiteralPath 'C:\tmp\ringotsuga-protected-hashes.json' | ConvertFrom-Json
$changed = @()
foreach ($entry in $baseline) {
    $current = (Get-FileHash -Algorithm SHA256 -LiteralPath $entry.Path).Hash
    if ($current -ne $entry.Hash) {
        $changed += $entry.Path
    }
}
if ($changed.Count -gt 0) {
    throw "protected Ringo integration files changed: $($changed -join ', ')"
}
Write-Output 'Ringo protected integration hashes unchanged'
```

Expected:

```text
Ringo protected integration hashes unchanged
```

- [ ] **Step 3: Run adjacent visual regressions**

Run:

```powershell
pwsh -NoProfile -File tests/tokarev_face_visual_test.ps1
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests\blue_banana_peel_skin_behavior_test.lua
```

Expected: both adjacent accessory checks pass without modifying their assets.

- [ ] **Step 4: Run Everchanging regressions**

Run:

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests\everchanging_behavior_test.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests\everchanging_full_anm2_contract_test.lua
```

Expected: both tests exit `0` and report their existing pass messages.

- [ ] **Step 5: Record the game verification checklist**

In game, validate:

1. Down/Right/Up/Left idle and continuous movement;
2. firing, hurt, pickup, and common collectible Costume overlap;
3. repeated Everchanging selection, room transition, and continued run;
4. head/face/body cleanup when Ringo is no longer selected;
5. no dirty transparent fringe, detached black/red pixels, clipping, jitter, or foot drift;
6. first-read identity is Ringo's apple mascot, with the light gray-white shirt visible beneath the head.

Do not report the redraw as game-verified until the user supplies or confirms this runtime result.

- [ ] **Step 6: Inspect final scoped diff**

Run:

```powershell
git status --short -- `
    tests/ringotsuga_accessory_atlas_visual_test.ps1 `
    tools/generate-ringotsuga-accessory-atlases.ps1 `
    resources/gfx/characters/costumes/costume_ringotsuga_apple_shell.png `
    resources/gfx/characters/costumes/costume_ringotsuga_face.png `
    resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png `
    reports/ringotsuga_accessory_atlases_preview.png
```

Expected: no uncommitted changes remain in the six implementation files. Unrelated pre-existing worktree changes remain untouched.

