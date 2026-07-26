# Tantan-Daodao Twins and Yoontoons Accessories Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add one normal-Jacob-and-Esau-only paired Everchanging style and one universal Yoontoons accessory style, using six clean hard-pixel Null Costumes without replacing the base player skin or body.

**Architecture:** Extend Everchanging's registry with an eligibility gate and role-specific resource sets, then coordinate the normal Jacob/Esau pair through `GetOtherTwin()` while retaining each player's saved style. Generate three `head4` hair atlases and three `head2` face-accessory atlases from the real vanilla Isaac head reference, register them under append-only costume IDs, and keep all live entity references runtime-only.

**Tech Stack:** Lua 5.4.6, Repentance `PlayerType` and `EntityPlayer:GetOtherTwin()`, Null Costume XML, ANM2 XML, PowerShell 7, `System.Drawing`, existing Lua/PowerShell tests and neverbrith validators.

## Global Constraints

- Locked mapping: Esau is Tantan (pink hair plus red angular glasses); Jacob is Daodao (messy blue hair plus two white tissue-tear strips).
- The paired style is eligible only when the player is part of a verified normal `PLAYER_JACOB`/`PLAYER_ESAU` pair; tainted Jacob and all other players cannot roll it.
- Yoontoons is black outward-curving hair, orange-red glasses and one small blue accent; it has no clothing or body layer.
- All six outputs are separate-decoration assets. They do not alter `Character_001_Isaac.png`, the player ANM2, portraits, name images, co-op portraits, death portraits, HUD or body art.
- Hair uses one `256x64` RGBA atlas, eight `32x64` crops, layer `head4`, pivot `(16,44)`, position `(0,-5)`.
- Glasses and tissue tears use one `256x32` RGBA atlas, eight `32x32` crops, layer `head2`, pivot `(16,28)`, position `(0,-5)`.
- Every visible pixel has alpha `255`; every transparent pixel is `(0,0,0,0)`. No interpolation, semi-transparent pixels, pure-black visible pixels or detached black/red contamination is accepted.
- Source reference is `E:\Isaac - Repentance\resources\gfx\characters\costumes\Character_001_Isaac.png`; semantic creator references guide shape and palette only and are never pasted into the atlas.
- Costume IDs are append-only and locked: `17501` Tantan hair, `17502` Tantan glasses, `17503` Daodao hair, `17504` Daodao tissue tears, `17505` Yoontoons hair, `17506` Yoontoons glasses. Historical removed IDs `17499` and `17500` remain unused.
- Preserve every unrelated dirty-worktree change. Stage and commit only the paths named by the current task.

## Resource-Purpose Card

| Field | Decision |
| --- | --- |
| Asset purpose | Player-body appearance: removable head/face decorations |
| Display surface | In-run player costume layers only |
| Carrier / mapping | Project-owned `type="none"` Null Costumes, `head4` hair and `head2` face layers, applied by Everchanging |
| Animation need | Required: `HeadDown`, `HeadRight`, `HeadUp`, `HeadLeft`, two phase frames each |
| Not for | Base player skin, body clothing, portraits, menus, HUD, EID or world effects |

## Surface Matrix

| Surface | Requested? | Source / reference | Output canvas | Carrier evidence | Acceptance |
| --- | --- | --- | --- | --- | --- |
| In-run base player skin | No | Existing standard player actor | Unchanged | Everchanging currently preserves `001.000_player.anm2` for accessory styles | No spritesheet or ANM2 load |
| Character portrait | No | Unchanged | Unchanged | No `players.xml` work | No new file |
| Character name image | No | Unchanged | Unchanged | No `players.xml` work | No new file |
| Character-select portrait | No | Unchanged | Unchanged | No menu mapping | No new file |
| Co-op portrait | No | Unchanged | Unchanged | No co-op atlas mapping | No new file |
| Death-screen portrait | No | Unchanged | Unchanged | No death-screen mapping | No new file |
| Costume / extra player layer | Yes | Real vanilla Isaac head plus approved creator features | Hair `256x64`; face `256x32` | Existing Ringo `head4`, Tokarev `head2`, `costumes2.xml`, `AddNullCostume` | Hard alpha, clean RGB, four directions, two phases, correct roles |
| Character-specific HUD | No | Unchanged | Unchanged | No HUD route | No new file |

---

### Task 1: Generate and lock the six hard-pixel atlases

**Files:**
- Create: `tools/generate-creator-accessory-atlases.ps1`
- Create: `tests/creator_accessory_atlas_visual_test.ps1`
- Create: `resources/gfx/characters/costumes/costume_tantan_hair.png`
- Create: `resources/gfx/characters/costumes/costume_tantan_glasses.png`
- Create: `resources/gfx/characters/costumes/costume_daodao_hair.png`
- Create: `resources/gfx/characters/costumes/costume_daodao_tissue_tears.png`
- Create: `resources/gfx/characters/costumes/costume_yoontoons_hair.png`
- Create: `resources/gfx/characters/costumes/costume_yoontoons_glasses.png`
- Create: `reports/creator_accessory_atlases_preview.png`

**Interfaces:**
- Consumes: the real vanilla atlas at `E:\Isaac - Repentance\resources\gfx\characters\costumes\Character_001_Isaac.png`.
- Produces: six deterministic PNGs and one non-runtime preview; cell order is down phase 0/1, right phase 0/1, up phase 0/1, left phase 0/1.

- [ ] **Step 1: Write the failing atlas contract**

Create `tests/creator_accessory_atlas_visual_test.ps1` with this asset table and make every assertion operate on decoded pixels:

```powershell
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$assets = @(
    @{ Name='tantan_hair'; Width=256; Height=64; Kind='hair'; Min=120; Max=700;
       Colors=@('#35282C','#92516B','#D97A9A','#F0A7B8') },
    @{ Name='tantan_glasses'; Width=256; Height=32; Kind='face'; Min=0; Max=130;
       Colors=@('#7A2D38','#B73C45','#E45A58') },
    @{ Name='daodao_hair'; Width=256; Height=64; Kind='hair'; Min=110; Max=680;
       Colors=@('#293247','#31486F','#4F6FA0','#7E98BC') },
    @{ Name='daodao_tissue_tears'; Width=256; Height=32; Kind='face'; Min=0; Max=150;
       Colors=@('#A9B0BA','#C7CCD2','#F1F1E8') },
    @{ Name='yoontoons_hair'; Width=256; Height=64; Kind='hair'; Min=110; Max=680;
       Colors=@('#202536','#30384D','#4C566D','#4A9BD1') },
    @{ Name='yoontoons_glasses'; Width=256; Height=32; Kind='face'; Min=0; Max=130;
       Colors=@('#873A35','#B94D3F','#E87955') }
)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Open-BitmapCopy([string]$Path) {
    Assert-True (Test-Path -LiteralPath $Path) "missing atlas: $Path"
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) } finally { $source.Dispose() }
    } finally { $stream.Dispose() }
}
function Get-CellVisibleCount([Drawing.Bitmap]$Bitmap, [int]$Cell, [int]$CellHeight) {
    $count = 0
    for($y=0; $y -lt $CellHeight; $y++) {
        for($x=0; $x -lt 32; $x++) {
            if($Bitmap.GetPixel(($Cell*32)+$x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}

foreach($asset in $assets) {
    $path = Join-Path $Root "resources\gfx\characters\costumes\costume_$($asset.Name).png"
    $bitmap = Open-BitmapCopy $path
    try {
        Assert-True ($bitmap.Width -eq $asset.Width -and $bitmap.Height -eq $asset.Height) `
            "$($asset.Name) canvas"
        $allowed = [Collections.Generic.HashSet[int]]::new()
        foreach($hex in $asset.Colors) {
            [void]$allowed.Add([Drawing.ColorTranslator]::FromHtml($hex).ToArgb())
        }
        for($y=0; $y -lt $bitmap.Height; $y++) {
            for($x=0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x,$y)
                Assert-True ($pixel.A -eq 0 -or $pixel.A -eq 255) "$($asset.Name) semi-alpha at $x,$y"
                if($pixel.A -eq 0) {
                    Assert-True ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0) `
                        "$($asset.Name) dirty transparent RGB at $x,$y"
                } else {
                    Assert-True ($allowed.Contains($pixel.ToArgb())) "$($asset.Name) palette at $x,$y"
                    Assert-True (-not ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0)) `
                        "$($asset.Name) pure black at $x,$y"
                }
            }
        }
        foreach($cell in 0..7) {
            $visible = Get-CellVisibleCount $bitmap $cell ($asset.Height)
            if($asset.Kind -eq 'hair') {
                Assert-True ($visible -ge $asset.Min -and $visible -le $asset.Max) `
                    "$($asset.Name) cell $cell coverage $visible"
            } elseif($cell -in 4,5) {
                Assert-True ($visible -eq 0) "$($asset.Name) back cell $cell must be blank"
            } else {
                Assert-True ($visible -gt 0 -and $visible -le $asset.Max) `
                    "$($asset.Name) cell $cell coverage $visible"
            }
        }
    } finally { $bitmap.Dispose() }
}

Write-Output 'creator accessory atlas visual contract passed'
```

- [ ] **Step 2: Run the atlas contract and verify red**

Run:

```powershell
pwsh -NoProfile -File tests/creator_accessory_atlas_visual_test.ps1 -Root .
```

Expected: FAIL with `missing atlas` for `costume_tantan_hair.png`.

- [ ] **Step 3: Implement the deterministic generator**

Create `tools/generate-creator-accessory-atlases.ps1` using these exact palette and geometry contracts:

```powershell
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$palette = @{
    Clear=[Drawing.Color]::FromArgb(0,0,0,0)
    Outline=[Drawing.ColorTranslator]::FromHtml('#35282C')
    TantanDark=[Drawing.ColorTranslator]::FromHtml('#92516B')
    Tantan=[Drawing.ColorTranslator]::FromHtml('#D97A9A')
    TantanLight=[Drawing.ColorTranslator]::FromHtml('#F0A7B8')
    TantanGlassDark=[Drawing.ColorTranslator]::FromHtml('#7A2D38')
    TantanGlass=[Drawing.ColorTranslator]::FromHtml('#B73C45')
    TantanGlassLight=[Drawing.ColorTranslator]::FromHtml('#E45A58')
    DaodaoOutline=[Drawing.ColorTranslator]::FromHtml('#293247')
    DaodaoDark=[Drawing.ColorTranslator]::FromHtml('#31486F')
    Daodao=[Drawing.ColorTranslator]::FromHtml('#4F6FA0')
    DaodaoLight=[Drawing.ColorTranslator]::FromHtml('#7E98BC')
    TissueDark=[Drawing.ColorTranslator]::FromHtml('#A9B0BA')
    Tissue=[Drawing.ColorTranslator]::FromHtml('#C7CCD2')
    TissueLight=[Drawing.ColorTranslator]::FromHtml('#F1F1E8')
    YoonDark=[Drawing.ColorTranslator]::FromHtml('#202536')
    Yoon=[Drawing.ColorTranslator]::FromHtml('#30384D')
    YoonLight=[Drawing.ColorTranslator]::FromHtml('#4C566D')
    YoonBlue=[Drawing.ColorTranslator]::FromHtml('#4A9BD1')
    YoonGlassDark=[Drawing.ColorTranslator]::FromHtml('#873A35')
    YoonGlass=[Drawing.ColorTranslator]::FromHtml('#B94D3F')
    YoonGlassLight=[Drawing.ColorTranslator]::FromHtml('#E87955')
}

$views = @(
    @{ Name='front'; Source=0; Phase=0 }, @{ Name='front'; Source=32; Phase=1 },
    @{ Name='right'; Source=64; Phase=0 }, @{ Name='right'; Source=96; Phase=1 },
    @{ Name='back'; Source=128; Phase=0 }, @{ Name='back'; Source=160; Phase=1 }
)

function Test-FaceAperture([string]$View,[int]$X,[int]$Y) {
    if($View -eq 'front') { return $X -ge 7 -and $X -le 24 -and $Y -ge 12 -and $Y -le 23 }
    if($View -eq 'right') { return $X -ge 15 -and $X -le 29 -and $Y -ge 11 -and $Y -le 23 }
    return $false
}
function Get-HairColor([string]$Persona,[bool]$Boundary,[int]$X,[int]$Y) {
    if($Persona -eq 'tantan') {
        if($Boundary){return $palette.Outline}; if($X -le 7 -or $Y -ge 22){return $palette.TantanDark}
        if($Y -le 8){return $palette.TantanLight}; return $palette.Tantan
    }
    if($Persona -eq 'daodao') {
        if($Boundary){return $palette.DaodaoOutline}; if($X -le 7 -or $Y -ge 22){return $palette.DaodaoDark}
        if($Y -le 7){return $palette.DaodaoLight}; return $palette.Daodao
    }
    if($Boundary){return $palette.YoonDark}; if($X -le 6 -or $Y -ge 22){return $palette.Yoon}
    return $palette.YoonLight
}
```

Add these bounds-checked helpers before any drawing routine:

```powershell
function New-TransparentBitmap([int]$Width,[int]$Height) {
    $bitmap = [Drawing.Bitmap]::new(
        $Width,
        $Height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear([Drawing.Color]::FromArgb(0,0,0,0))
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}
function Set-LocalPixel(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$CellWidth,
    [int]$X,
    [int]$Y,
    [Drawing.Color]$Color
) {
    if($Cell -lt 0 -or $X -lt 0 -or $X -ge $CellWidth -or
       $Y -lt 0 -or $Y -ge $Bitmap.Height) {
        throw "pixel outside atlas cell=$Cell x=$X y=$Y"
    }
    $globalX = ($Cell * $CellWidth) + $X
    if($globalX -lt 0 -or $globalX -ge $Bitmap.Width) {
        throw "pixel outside atlas x=$globalX"
    }
    $Bitmap.SetPixel($globalX,$Y,$Color)
}
function Fill-LocalSpan(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$CellWidth,
    [int]$StartX,
    [int]$EndX,
    [int]$Y,
    [Drawing.Color]$Color
) {
    if($EndX -lt $StartX) { throw "reversed span $StartX..$EndX" }
    for($x=$StartX; $x -le $EndX; $x++) {
        Set-LocalPixel $Bitmap $Cell $CellWidth $x $Y $Color
    }
}
function Mirror-Cell(
    [Drawing.Bitmap]$Bitmap,
    [int]$SourceCell,
    [int]$TargetCell,
    [int]$CellWidth,
    [int]$CellHeight
) {
    for($y=0; $y -lt $CellHeight; $y++) {
        for($x=0; $x -lt $CellWidth; $x++) {
            $sourceX = ($SourceCell * $CellWidth) + $x
            $targetX = ($TargetCell * $CellWidth) + (($CellWidth - 1) - $x)
            $Bitmap.SetPixel($targetX,$y,$Bitmap.GetPixel($sourceX,$y))
        }
    }
}
function Normalize-TransparentPixels([Drawing.Bitmap]$Bitmap) {
    for($y=0; $y -lt $Bitmap.Height; $y++) {
        for($x=0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x,$y)
            if($pixel.A -eq 0) {
                $Bitmap.SetPixel($x,$y,[Drawing.Color]::FromArgb(0,0,0,0))
            } elseif($pixel.A -ne 255) {
                throw "semi-transparent generated pixel at $x,$y alpha=$($pixel.A)"
            }
        }
    }
}
function Save-Png([Drawing.Bitmap]$Bitmap,[string]$Path) {
    $directory = Split-Path -Parent $Path
    if(-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory)
    }
    Normalize-TransparentPixels $Bitmap
    $Bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
    Write-Output "generated $Path"
}
```

For cells `0..5`, `Draw-HairCell(Persona, View, Phase)` must:

1. read the matching `32x32` source crop from the real vanilla head;
2. draw only source-alpha pixels outside `Test-FaceAperture` at local `Y+16`;
3. choose boundary color from four-neighbor source-alpha checks;
4. add connected signature pixels:
   - Tantan: front tufts `(9,25)..(13,27)` and `(20,25)..(23,27)` at atlas rows `29..33`;
   - Daodao: asymmetrical top spikes `(6,8),(7,7),(8,6),(23,7),(24,5),(25,6)` shifted by phase;
   - Yoontoons: side curls `(4,20),(3,21),(3,22)` and `(27,20),(28,21),(28,22)`, plus blue accent `(9,9),(10,9),(10,10)` in front/right cells.
5. mirror right cells `2/3` into left cells `6/7`.

`Draw-FaceCell(Persona, View, Phase)` must use `offsetY = Phase` and these exact components:

- Tantan front: angular frames around `x=7..13` and `x=18..24`, `y=12+offsetY..17+offsetY`, bridge `x=14..17,y=14+offsetY`; right side uses `x=16..27`; left mirrors right.
- Daodao front: left strip `x=9..11,y=15+offsetY..25+offsetY`, right strip `x=21..23,y=15+offsetY..25+offsetY`; right side keeps only `x=21..23`; left mirrors right.
- Yoontoons front: rounded rectangular frames around `x=7..13` and `x=18..24`, `y=12+offsetY..17+offsetY`, bridge `x=14..17,y=14+offsetY`; right side uses `x=16..27`; left mirrors right.
- Back cells `4/5` remain transparent for every face asset.

The generator must save all six PNGs, normalize transparent RGB, composite vanilla head + hair + face at native scale for front/right/back/left, and save `reports/creator_accessory_atlases_preview.png`. The preview must contain, for every persona and direction, a checkerboard row, an opaque-white row and a representative dark-red room row; each row includes both nearest-neighbor `4x` and native `1x` columns.

- [ ] **Step 4: Run generation and verify green**

Run:

```powershell
pwsh -NoProfile -File tools/generate-creator-accessory-atlases.ps1 -Root .
pwsh -NoProfile -File tests/creator_accessory_atlas_visual_test.ps1 -Root .
```

Expected: six `generated ...` lines, one preview line, then `creator accessory atlas visual contract passed`.

- [ ] **Step 5: Review the preview at game size**

Open `reports/creator_accessory_atlases_preview.png` and reject the task unless all twelve direction composites preserve the vanilla face, the Tantan/Daodao role identities are unambiguous, all three matte rows stay clean, phase 0/1 produces a visible one-pixel motion without resizing the silhouette, and the `1x` column has no visible dirt or disconnected contamination.

- [ ] **Step 6: Commit the art task**

```powershell
git add -- tools/generate-creator-accessory-atlases.ps1 tests/creator_accessory_atlas_visual_test.ps1 resources/gfx/characters/costumes/costume_tantan_hair.png resources/gfx/characters/costumes/costume_tantan_glasses.png resources/gfx/characters/costumes/costume_daodao_hair.png resources/gfx/characters/costumes/costume_daodao_tissue_tears.png resources/gfx/characters/costumes/costume_yoontoons_hair.png resources/gfx/characters/costumes/costume_yoontoons_glasses.png reports/creator_accessory_atlases_preview.png
git diff --cached --name-only
git commit -m "art: add creator accessory atlases"
```

Expected staged set: exactly the nine paths listed above.

### Task 2: Register six ANM2 Null Costumes

**Files:**
- Create: `tests/creator_accessory_anm2_visual_test.ps1`
- Create: `resources/gfx/characters/costume_tantan_hair.anm2`
- Create: `resources/gfx/characters/costume_tantan_glasses.anm2`
- Create: `resources/gfx/characters/costume_daodao_hair.anm2`
- Create: `resources/gfx/characters/costume_daodao_tissue_tears.anm2`
- Create: `resources/gfx/characters/costume_yoontoons_hair.anm2`
- Create: `resources/gfx/characters/costume_yoontoons_glasses.anm2`
- Modify: `content/costumes2.xml`

**Interfaces:**
- Consumes: six PNG paths from Task 1.
- Produces: six `gfx/characters/*.anm2` paths resolvable by `Isaac.GetCostumeIdByPath`.

- [ ] **Step 1: Write the failing ANM2/XML contract**

Create a data-driven `tests/creator_accessory_anm2_visual_test.ps1`:

```powershell
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$specs=@(
 @{Id='17501';Name='tantan_hair';Layer='head4';Height=64;PivotY=44;Priority='98'},
 @{Id='17502';Name='tantan_glasses';Layer='head2';Height=32;PivotY=28;Priority='97'},
 @{Id='17503';Name='daodao_hair';Layer='head4';Height=64;PivotY=44;Priority='98'},
 @{Id='17504';Name='daodao_tissue_tears';Layer='head2';Height=32;PivotY=28;Priority='97'},
 @{Id='17505';Name='yoontoons_hair';Layer='head4';Height=64;PivotY=44;Priority='98'},
 @{Id='17506';Name='yoontoons_glasses';Layer='head2';Height=32;PivotY=28;Priority='97'}
)
[xml]$costumes=Get-Content -Raw -LiteralPath (Join-Path $Root 'content\costumes2.xml')
foreach($spec in $specs){
 $path=Join-Path $Root "resources\gfx\characters\costume_$($spec.Name).anm2"
 Assert-True (Test-Path -LiteralPath $path) "missing ANM2 $($spec.Name)"
 [xml]$anm2=Get-Content -Raw -LiteralPath $path
 $sheet=@($anm2.AnimatedActor.Content.Spritesheets.Spritesheet)
 $layer=@($anm2.AnimatedActor.Content.Layers.Layer)
 Assert-True ($sheet.Count -eq 1) "$($spec.Name) spritesheet count"
 Assert-True (([string]$sheet[0].Path -replace '\\','/') -eq "costumes/costume_$($spec.Name).png") `
  "$($spec.Name) spritesheet path"
 Assert-True ($layer.Count -eq 1 -and [string]$layer[0].Name -eq $spec.Layer) "$($spec.Name) layer"
 foreach($animationName in 'HeadDown','HeadRight','HeadUp','HeadLeft'){
  $animation=@($anm2.AnimatedActor.Animations.Animation)|Where-Object Name -eq $animationName|Select-Object -First 1
  Assert-True ($null -ne $animation) "$($spec.Name) $animationName"
  $frames=@($animation.LayerAnimations.LayerAnimation.Frame)
  Assert-True ($frames.Count -eq 2) "$($spec.Name) $animationName frame count"
  foreach($frame in $frames){
   Assert-True ([int]$frame.Width -eq 32 -and [int]$frame.Height -eq $spec.Height) "$($spec.Name) crop"
   Assert-True ([int]$frame.XPivot -eq 16 -and [int]$frame.YPivot -eq $spec.PivotY) "$($spec.Name) pivot"
   Assert-True ([int]$frame.YPosition -eq -5 -and [int]$frame.Delay -eq 2) "$($spec.Name) timing"
  }
 }
 $entry=@($costumes.costumes.costume)|Where-Object {[string]$_.id -eq $spec.Id}|Select-Object -First 1
 Assert-True ($null -ne $entry) "missing costume id $($spec.Id)"
 Assert-True ([string]$entry.anm2path -eq "costume_$($spec.Name).anm2") "costume path $($spec.Id)"
 Assert-True ([string]$entry.type -eq 'none' -and [string]$entry.priority -eq $spec.Priority) "costume flags $($spec.Id)"
}
foreach($reserved in '17499','17500'){
 Assert-True ((@($costumes.costumes.costume)|Where-Object {[string]$_.id -eq $reserved}).Count -eq 0) `
  "historical removed id reused: $reserved"
}
Write-Output 'creator accessory ANM2 contract passed'
```

- [ ] **Step 2: Run the ANM2 contract and verify red**

Run:

```powershell
pwsh -NoProfile -File tests/creator_accessory_anm2_visual_test.ps1 -Root .
```

Expected: FAIL with `missing ANM2 tantan_hair`.

- [ ] **Step 3: Add the six ANM2 files**

Create each file as a single-layer `AnimatedActor` with `Info Fps="30" Version="104"`, one spritesheet with `Id="0"`, one layer with `Id="0" SpritesheetId="0"`, empty `Nulls`/`Events`, and `DefaultAnimation="HeadDown"`. Use this complete per-file field table:

```text
file                                      sheet path                                      layer  height  YPivot
costume_tantan_hair.anm2                  costumes\costume_tantan_hair.png                head4      64      44
costume_tantan_glasses.anm2               costumes\costume_tantan_glasses.png             head2      32      28
costume_daodao_hair.anm2                  costumes\costume_daodao_hair.png                head4      64      44
costume_daodao_tissue_tears.anm2          costumes\costume_daodao_tissue_tears.png        head2      32      28
costume_yoontoons_hair.anm2               costumes\costume_yoontoons_hair.png             head4      64      44
costume_yoontoons_glasses.anm2            costumes\costume_yoontoons_glasses.png          head2      32      28
```

Every file contains exactly these four animation/frame mappings:

```text
animation   FrameNum  Loop   frame 0 XCrop  frame 1 XCrop
HeadDown           4  false              0             32
HeadRight          4  false             64             96
HeadUp             4  false            128            160
HeadLeft           4  false            192            224
```

For every animation, use one root frame with `Delay="4"`, position `(0,0)`, scale `(100,100)`, rotation `0`, all tint channels `255`, all offsets `0`, alpha `255`, visible `true`. Each layer frame uses the table's height and pivot, `Width="32" XPosition="0" YPosition="-5" XScale="100" YScale="100" YCrop="0" Delay="2" Rotation="0"`, the same tint/offset/alpha values, and visible `true`. Finish every animation with empty `NullAnimations` and `Triggers`; do not add a second layer, spritesheet, animation or interpolation offset. This makes phase movement belong only to atlas pixels.

- [ ] **Step 4: Append the XML registrations**

Insert before `</costumes>` in `content/costumes2.xml`:

```xml
  <costume id="17501" anm2path="costume_tantan_hair.anm2" type="none" priority="98" />
  <costume id="17502" anm2path="costume_tantan_glasses.anm2" type="none" priority="97" />
  <costume id="17503" anm2path="costume_daodao_hair.anm2" type="none" priority="98" />
  <costume id="17504" anm2path="costume_daodao_tissue_tears.anm2" type="none" priority="97" />
  <costume id="17505" anm2path="costume_yoontoons_hair.anm2" type="none" priority="98" />
  <costume id="17506" anm2path="costume_yoontoons_glasses.anm2" type="none" priority="97" />
```

Write each registration as one indented XML element immediately before `</costumes>`; each element has exactly the four attributes shown above: `id`, `anm2path`, `type` and `priority`.

- [ ] **Step 5: Run the ANM2/XML contract and verify green**

Run:

```powershell
pwsh -NoProfile -File tests/creator_accessory_anm2_visual_test.ps1 -Root .
pwsh -NoProfile -File tests/ringotsuga_accessory_anm2_visual_test.ps1 -Root .
```

Expected: both contracts pass; the Ringo test confirms `17499/17500` remain absent.

- [ ] **Step 6: Commit the carrier task**

```powershell
git add -- content/costumes2.xml tests/creator_accessory_anm2_visual_test.ps1 resources/gfx/characters/costume_tantan_hair.anm2 resources/gfx/characters/costume_tantan_glasses.anm2 resources/gfx/characters/costume_daodao_hair.anm2 resources/gfx/characters/costume_daodao_tissue_tears.anm2 resources/gfx/characters/costume_yoontoons_hair.anm2 resources/gfx/characters/costume_yoontoons_glasses.anm2
git diff --cached --name-only
git commit -m "feat: register creator accessory costumes"
```

Expected staged set: exactly the eight paths listed above.

### Task 3: Add role-aware style registration and eligibility filtering

**Files:**
- Modify: `tests/everchanging_behavior_test.lua`
- Modify: `main.lua:18187-18501`

**Interfaces:**
- Produces: `GetNormalTwinRole(player) -> "jacob"|"esau"|nil`.
- Produces: `GetNormalTwinPair(player) -> { jacob=EntityPlayer, esau=EntityPlayer }|nil`.
- Produces: `IsStyleEligibleForPlayer(player, style) -> boolean`.
- Changes: `ResolveStyleResources(style, role)` accepts a role only for paired styles.
- Changes: `SelectStyle(player, currentStyleId, registry)` filters ineligible styles before consuming RNG.

- [ ] **Step 1: Add failing registry and eligibility tests**

In `tests/everchanging_behavior_test.lua`, define test constants after the existing localization test loads:

```lua
PlayerType = {
    PLAYER_JACOB = 19,
    PLAYER_ESAU = 20,
    PLAYER_JACOB_B = 39,
}
```

Extend `makePlayer`:

```lua
local otherTwin = nil
function player:SetOtherTwin(value) otherTwin = value end
function player:GetOtherTwin() return otherTwin end
```

Change the valid added/removed costume ID range to `17495..17506`, extend `Isaac.GetCostumeIdByPath` with IDs `17501..17506`, then assert:

```lua
assertEquals(#api.StyleRegistry, 5, "Everchanging style registry size")
local twinsStyle = api.StyleRegistry.byId.tantan_daodao_twins
local yoonStyle = api.StyleRegistry.byId.yoontoons_storyteller
assertTruthy(twinsStyle and twinsStyle.pairRoles, "paired twin style")
assertEquals(yoonStyle.resources.head.costume,
    "gfx/characters/costume_yoontoons_hair.anm2", "Yoontoons hair path")
assertEquals(yoonStyle.resources.face.costume,
    "gfx/characters/costume_yoontoons_glasses.anm2", "Yoontoons glasses path")

local jacob = makePlayer(901, nil, PlayerType.PLAYER_JACOB)
local esau = makePlayer(902, nil, PlayerType.PLAYER_ESAU)
jacob:SetOtherTwin(esau)
esau:SetOtherTwin(jacob)
assertEquals(api.GetNormalTwinRole(jacob), "jacob", "Jacob role")
assertEquals(api.GetNormalTwinRole(esau), "esau", "Esau role")
assertTruthy(api.IsStyleEligible(jacob, twinsStyle), "normal Jacob pair eligibility")
assertEquals(api.IsStyleEligible(makePlayer(903, nil, PlayerType.PLAYER_JACOB_B), twinsStyle),
    false, "tainted Jacob pair exclusion")
assertEquals(api.IsStyleEligible(makePlayer(904), twinsStyle), false, "ordinary player pair exclusion")

local jacobResources = api.ResolveStyleResources(twinsStyle, "jacob")
local esauResources = api.ResolveStyleResources(twinsStyle, "esau")
assertEquals(jacobResources.costumes[1].id, 17503, "Daodao hair on Jacob")
assertEquals(jacobResources.costumes[2].id, 17504, "Daodao tissue tears on Jacob")
assertEquals(esauResources.costumes[1].id, 17501, "Tantan hair on Esau")
assertEquals(esauResources.costumes[2].id, 17502, "Tantan glasses on Esau")

local pairOnly = api.BuildStyleRegistry({ api.StyleSpecs[4] })
assertEquals(api.SelectStyle(makePlayer(905), nil, pairOnly), nil,
    "ordinary players cannot roll the pair style")
```

- [ ] **Step 2: Run the behavior test and verify red**

Run:

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
```

Expected: FAIL because registry size is still `3` and `GetNormalTwinRole` is absent.

- [ ] **Step 3: Add exact style specs**

Append these entries to `STYLE_SPECS` after Ringo:

```lua
{
    id = "tantan_daodao_twins",
    eligibility = "normal_jacob_esau_pair",
    pairRoles = {
        jacob = {
            slots = { "head", "face" },
            resources = {
                head = { costume = "gfx/characters/costume_daodao_hair.anm2" },
                face = { costume = "gfx/characters/costume_daodao_tissue_tears.anm2" },
            },
        },
        esau = {
            slots = { "head", "face" },
            resources = {
                head = { costume = "gfx/characters/costume_tantan_hair.anm2" },
                face = { costume = "gfx/characters/costume_tantan_glasses.anm2" },
            },
        },
    },
    full = false,
    metadata = { source = "tantan_daodao_normal_twins_accessories" },
},
{
    id = "yoontoons_storyteller",
    slots = { "head", "face" },
    resources = {
        head = { costume = "gfx/characters/costume_yoontoons_hair.anm2" },
        face = { costume = "gfx/characters/costume_yoontoons_glasses.anm2" },
    },
    full = false,
    metadata = { source = "yoontoons_hair_glasses_accessories" },
},
```

- [ ] **Step 4: Normalize regular and paired resource sets**

Extract the current slot/resource loop from `BuildStyleRegistry` into:

```lua
local function NormalizeStyleResourceSet(slots, resources, allowFull)
    if type(slots) ~= "table" or #slots == 0 then return nil, "missing slots" end
    if type(resources) ~= "table" then return nil, "missing resources" end
    local normalized = { slots = {}, resources = {} }
    local seen = {}
    for _, rawSlot in ipairs(slots) do
        local slot = tostring(rawSlot or "")
        local resource = resources[slot]
        if not ALLOWED_SLOTS[slot] then return nil, "unsupported slot " .. slot end
        if seen[slot] then return nil, "duplicate slot " .. slot end
        if type(resource) ~= "table" then return nil, "missing resource for slot " .. slot end
        if slot == "full" then
            if not allowFull then return nil, "paired roles cannot use the full slot" end
            if type(resource.anm2) ~= "string" or resource.anm2 == "" then
                return nil, "missing ANM2 resource for full slot"
            end
            normalized.resources[slot] = { anm2 = resource.anm2 }
        else
            if type(resource.costume) ~= "string" or resource.costume == "" then
                return nil, "missing costume resource for slot " .. slot
            end
            normalized.resources[slot] = { costume = resource.costume }
        end
        seen[slot] = true
        normalized.slots[#normalized.slots + 1] = slot
    end
    normalized.hasFull = seen.full == true
    return normalized
end
```

`BuildStyleRegistry` must accept exactly two shapes:

- regular: normalized `slots/resources`;
- paired: both `pairRoles.jacob` and `pairRoles.esau` normalize successfully with `allowFull=false`.

A normalized paired entry contains exactly `id`, `pairRoles`, `eligibility`, `full=false` and `metadata`. A normalized regular entry contains exactly `id`, `slots`, `resources`, `full` and `metadata`; `hasFull` remains an internal return value of `NormalizeStyleResourceSet` and is not stored on the registry entry.

- [ ] **Step 5: Add verified normal-twin discovery and candidate filtering**

Add:

```lua
local function GetNormalTwinRole(player)
    if not player or not player.GetPlayerType or type(PlayerType) ~= "table" then return nil end
    local ok, playerType = pcall(function() return player:GetPlayerType() end)
    if not ok then return nil end
    if playerType == PlayerType.PLAYER_JACOB then return "jacob" end
    if playerType == PlayerType.PLAYER_ESAU then return "esau" end
    return nil
end

local function GetNormalTwinPair(player)
    local role = GetNormalTwinRole(player)
    if not role or not player.GetOtherTwin then return nil end
    local ok, other = pcall(function() return player:GetOtherTwin() end)
    if not ok or not other or other == player then return nil end
    local otherRole = GetNormalTwinRole(other)
    if role == "jacob" and otherRole == "esau" then return { jacob=player, esau=other } end
    if role == "esau" and otherRole == "jacob" then return { jacob=other, esau=player } end
    return nil
end

local function IsStyleEligibleForPlayer(player, style)
    if not style then return false end
    if style.eligibility == "normal_jacob_esau_pair" then
        return GetNormalTwinPair(player) ~= nil
    end
    return true
end
```

Replace resource resolution and selection with the role-aware implementations below. The failure log includes the style, role, slot and path, while an empty eligible set returns before resolving collectible RNG:

```lua
local function ResolveStyleResources(style, role)
    if type(style) ~= "table" then return nil end
    local resourceSet = style
    if style.pairRoles then
        resourceSet = role and style.pairRoles[role] or nil
        if not resourceSet then
            DebugLog("[neverbirth] Everchanging style " .. tostring(style.id)
                .. " missing paired role " .. tostring(role))
            return nil
        end
    end
    local resolved = { playerAnm2 = nil, costumes = {} }
    for _, slot in ipairs(resourceSet.slots or {}) do
        local resource = resourceSet.resources and resourceSet.resources[slot]
        if slot == "full" then
            local anm2 = resource and resource.anm2
            if type(anm2) ~= "string" or anm2 == "" then return nil end
            resolved.playerAnm2 = anm2
        else
            local costumePath = resource and resource.costume
            local costumeId = costumePath and GetCostumeId(costumePath) or nil
            if not costumeId then
                DebugLog("[neverbirth] Everchanging style " .. tostring(style.id)
                    .. " role " .. tostring(role or "regular")
                    .. " failed at slot " .. tostring(slot)
                    .. " path " .. tostring(costumePath))
                return nil
            end
            resolved.costumes[#resolved.costumes + 1] = {
                id = costumeId,
                path = costumePath,
                slot = slot,
            }
        end
    end
    return resolved
end

local function ResolveStyleCostumes(style, role)
    local resolved = ResolveStyleResources(style, role)
    return resolved and resolved.costumes or nil
end

local function SelectStyle(player, currentStyleId, registry)
    registry = registry or STYLE_REGISTRY
    if type(registry) ~= "table" or #registry == 0 then
        if not emptyRegistryLogged then
            emptyRegistryLogged = true
            DebugLog("[neverbirth] Everchanging style registry is empty")
        end
        return nil
    end
    local eligible = {}
    for _, style in ipairs(registry) do
        if IsStyleEligibleForPlayer(player, style) then
            eligible[#eligible + 1] = style
        end
    end
    if #eligible == 0 then return nil end
    local candidates = {}
    for _, style in ipairs(eligible) do
        if #eligible == 1 or style.id ~= currentStyleId then
            candidates[#candidates + 1] = style
        end
    end
    if #candidates == 0 then return eligible[1] end
    if not player or not player.GetCollectibleRNG or not IsValidItemId(EVERCHANGING) then
        DebugLog("[neverbirth] Everchanging collectible RNG unavailable")
        return nil
    end
    local ok, rng = pcall(function() return player:GetCollectibleRNG(EVERCHANGING) end)
    if not ok or not rng or not rng.RandomInt then
        DebugLog("[neverbirth] Everchanging collectible RNG resolution failed")
        return nil
    end
    local rollOk, roll = pcall(function() return rng:RandomInt(#candidates) end)
    if not rollOk then
        DebugLog("[neverbirth] Everchanging collectible RNG draw failed")
        return nil
    end
    return candidates[(tonumber(roll) or 0) % #candidates + 1]
end
```

- [ ] **Step 6: Export test interfaces and verify green**

Add these to `Neverbirth.EverchangingTestAPI`:

```lua
GetNormalTwinRole = GetNormalTwinRole,
GetNormalTwinPair = GetNormalTwinPair,
IsStyleEligible = IsStyleEligibleForPlayer,
```

Run:

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
```

Expected: registry/eligibility/resource assertions pass; later pair synchronization assertions may still be red until Task 4.

- [ ] **Step 7: Commit the registry task**

```powershell
git add -- main.lua tests/everchanging_behavior_test.lua
git diff --cached --name-only
git commit -m "feat: add eligible creator styles"
```

Expected staged set: only `main.lua` and `tests/everchanging_behavior_test.lua`.

### Task 4: Synchronize the paired style without half-applied visuals

**Files:**
- Modify: `tests/everchanging_behavior_test.lua`
- Modify: `main.lua:18373-18910`

**Interfaces:**
- Produces: `UpdateEverchangingSelection(player) -> state,runtime,count,changed`.
- Produces: `ApplyEverchangingPair(pair, style) -> boolean`.
- Changes: runtime includes `appliedRole`.
- Changes: `ApplyEverchangingStyle(player, styleId, role)` handles regular or role-specific resources.
- Changes: `SyncEverchangingPlayer(player)` coordinates both verified twins before ordinary per-player visuals.

- [ ] **Step 1: Add failing pair lifecycle tests**

Extend `makePlayer` with a failure-injection value beside `rngCalls`, guard `AddNullCostume`, and expose a setter:

```lua
local failCostumeId = nil

-- Replace the mock's AddNullCostume member with this function.
AddNullCostume = function(self, costumeId)
    if costumeId == failCostumeId then
        error("injected costume failure " .. costumeId)
    end
    assertTruthy(costumeId >= 17495 and costumeId <= 17506, "added costume id")
    self.addedCostumes = self.addedCostumes + 1
    self.lastAddedCostumeId = costumeId
    self.addedCostumeIds[#self.addedCostumeIds + 1] = costumeId
end,

function player:SetFailCostumeId(value)
    failCostumeId = value
end
```

Then add a fresh pair and unrelated third player after the registry tests:

```lua
local jacob = makePlayer(1001, nil, PlayerType.PLAYER_JACOB)
local esau = makePlayer(1002, nil, PlayerType.PLAYER_ESAU)
local third = makePlayer(1003)
jacob:SetOtherTwin(esau)
esau:SetOtherTwin(jacob)
runtimePlayers = { jacob, esau, third }
api.ResetRunState()

third:SetEverchangingCount(1)
assertTruthy(api.ForceStyle(third, "yoontoons_storyteller"), "preload unrelated player style")
local thirdAdds = third.addedCostumes

esau:SetEverchangingCount(1)
assertTruthy(api.ForceStyle(esau, "yoontoons_storyteller"), "preload Esau local style")
assertEquals(esau.lastAddedCostumeId, 17506, "Yoontoons face is applied")

jacob:SetEverchangingCount(1)
esau:SetFailCostumeId(17502)
local failedPair, failedPairMessage = api.ForceStyle(jacob, "tantan_daodao_twins")
assertEquals(failedPair, false, "pair application failure propagates")
assertEquals(failedPairMessage, "style application failed", "pair failure message")
assertEquals(api.GetRuntime(jacob).appliedStyleId, nil, "Jacob half rolls back")
assertEquals(api.GetRuntime(esau).appliedStyleId, nil, "Esau half rolls back")
assertEquals(jacob.lastRemovedCostumeId, 17504, "Jacob partial pair resources removed")
assertEquals(esau.lastRemovedCostumeId, 17501, "Esau partial pair resources removed")
assertEquals(third.addedCostumes, thirdAdds, "pair rollback does not touch unrelated player")

esau:SetFailCostumeId(nil)
local rngBeforePair = jacob:GetRngCalls()
assertTruthy(api.ForceStyle(jacob, "tantan_daodao_twins"), "force pair style from Jacob")
assertEquals(jacob.addedCostumeIds[#jacob.addedCostumeIds-1], 17503, "Jacob receives Daodao hair")
assertEquals(jacob.addedCostumeIds[#jacob.addedCostumeIds], 17504, "Jacob receives Daodao tissue tears")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds-1], 17501, "Esau receives Tantan hair")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds], 17502, "Esau receives Tantan glasses")
assertEquals(jacob:GetRngCalls(), rngBeforePair, "debug force consumes no RNG")

local jacobAdds = jacob.addedCostumes
local esauAdds = esau.addedCostumes
api.SyncPlayer(jacob)
api.SyncPlayer(esau)
assertEquals(jacob.addedCostumes, jacobAdds, "ordinary pair sync is idempotent for Jacob")
assertEquals(esau.addedCostumes, esauAdds, "ordinary pair sync is idempotent for Esau")
assertEquals(third.addedCostumes, thirdAdds, "pair sync does not touch unrelated player")

api.Callbacks.NewRoom(nil)
api.Callbacks.PlayerUpdate(nil, jacob)
api.Callbacks.PlayerUpdate(nil, esau)
api.Callbacks.PlayerUpdate(nil, third)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "room change keeps Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "room change keeps Esau role")
assertEquals(third.addedCostumes, thirdAdds, "room sync leaves unrelated player idempotent")

api.Callbacks.NewLevel(nil)
api.Callbacks.PlayerUpdate(nil, jacob)
api.Callbacks.PlayerUpdate(nil, esau)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "level change keeps Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "level change keeps Esau role")

api.ClearRuntime(jacob, true)
api.ClearRuntime(esau, true)
api.Callbacks.GameStarted(nil, true)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "continue restores Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "continue restores Esau role")
assertEquals(jacob:GetRngCalls(), rngBeforePair, "lifecycle restore does not redraw")

jacob:SetEverchangingCount(0)
api.SyncPlayer(jacob)
assertEquals(api.GetPlayerState(jacob).styleId, nil, "pair owner style clears on item loss")
assertEquals(api.GetPlayerState(esau).styleId, "yoontoons_storyteller", "Esau saved local style survives")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds-1], 17505, "Esau restores Yoontoons hair")
assertEquals(esau.addedCostumeIds[#esau.addedCostumeIds], 17506, "Esau restores Yoontoons glasses")

jacob:SetEverchangingCount(1)
assertTruthy(api.ForceStyle(jacob, "tantan_daodao_twins"), "restore pair style")
local pairRng = jacob:GetRngCalls()
jacob:SetOtherTwin(nil)
esau:SetOtherTwin(nil)
api.SyncPlayer(jacob)
api.SyncPlayer(esau)
assertEquals(api.GetRuntime(jacob).appliedStyleId, nil, "missing partner clears Jacob half")
assertEquals(api.GetRuntime(esau).appliedStyleId, "yoontoons_storyteller", "Esau returns to local style")
jacob:SetOtherTwin(esau)
esau:SetOtherTwin(jacob)
api.SyncPlayer(jacob)
assertEquals(api.GetRuntime(jacob).appliedRole, "jacob", "rejoined Jacob role")
assertEquals(api.GetRuntime(esau).appliedRole, "esau", "rejoined Esau role")
assertEquals(jacob:GetRngCalls(), pairRng, "rejoin does not redraw")
assertEquals(api.GetRuntime(third).appliedStyleId, "yoontoons_storyteller",
    "unrelated player style survives pair separation and rejoin")
assertEquals(third.addedCostumes, thirdAdds,
    "unrelated player receives no duplicate costume applications")
```

- [ ] **Step 2: Run and verify red**

Run:

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
```

Expected: FAIL because forcing the paired style applies only to the selected player and `GetRuntime` is absent.

- [ ] **Step 3: Add role to runtime and resource matching**

Add `appliedRole = nil` to both runtime table constructors (`GetEverchangingRuntime` and `ClearEverchangingRuntime`), and set `runtime.appliedRole = nil` beside `runtime.appliedStyleId = nil` in `ClearEverchangingStyle`. Then replace `ApplyEverchangingStyle` with this complete function:

```lua
local function ApplyEverchangingStyle(player, styleId, role)
    local runtime = GetEverchangingRuntime(player)
    if not runtime then return false end
    local style = styleId and STYLE_REGISTRY.byId[styleId] or nil
    if not style or not IsStyleEligibleForPlayer(player, style) then
        ClearEverchangingStyle(player)
        return false
    end
    if not IsCompatiblePlayer(player, runtime) then
        ClearEverchangingStyle(player)
        runtime.failedStyleId = styleId
        runtime.dirty = false
        return false
    end
    local resources = ResolveStyleResources(style, role)
    if not resources then
        ClearEverchangingStyle(player)
        runtime.failedStyleId = styleId
        runtime.dirty = false
        return false
    end
    local styleStateMatches = runtime.appliedStyleId == styleId
        and runtime.appliedRole == role
        and runtime.appliedPlayerAnm2 == resources.playerAnm2
        and CostumeListsMatch(runtime.appliedCostumeIds, resources.costumes)
    if styleStateMatches and PlayerAnm2Matches(player, resources.playerAnm2) ~= false then
        runtime.failedStyleId = nil
        runtime.dirty = false
        return true
    end
    if styleStateMatches and resources.playerAnm2 then
        runtime.appliedPlayerAnm2 = nil
        if ApplyPlayerAnm2(player, runtime, resources.playerAnm2) then
            if not runtime.anm2DriftLogged then
                runtime.anm2DriftLogged = true
                DebugLog("[neverbirth] Everchanging repaired a player ANM2 reset for style "
                    .. tostring(styleId))
            end
            runtime.failedStyleId = nil
            runtime.dirty = false
            return true
        end
        runtime.failedStyleId = styleId
        runtime.dirty = false
        return false
    end
    ClearEverchangingStyle(player)
    if resources.playerAnm2 and not ApplyPlayerAnm2(player, runtime, resources.playerAnm2) then
        runtime.failedStyleId = styleId
        runtime.dirty = false
        return false
    end
    local applied = {}
    for _, costume in ipairs(resources.costumes) do
        if not player.AddNullCostume then break end
        local ok = pcall(function() player:AddNullCostume(costume.id) end)
        if not ok then break end
        applied[#applied + 1] = costume
    end
    if #applied ~= #resources.costumes then
        runtime.appliedCostumeIds = applied
        ClearEverchangingStyle(player)
        runtime.failedStyleId = styleId
        DebugLog("[neverbirth] Everchanging failed to apply style " .. tostring(styleId)
            .. " role " .. tostring(role or "regular"))
        return false
    end
    runtime.appliedStyleId = styleId
    runtime.appliedRole = role
    runtime.appliedCostumeIds = applied
    runtime.failedStyleId = nil
    runtime.dirty = false
    return true
end
```

- [ ] **Step 4: Split saved selection from visual synchronization**

Move lines currently responsible for count changes, drawing and `SaveMusicboxData()` into:

```lua
local function UpdateEverchangingSelection(player)
    local state = GetEverchangingPlayerState(player)
    local runtime = GetEverchangingRuntime(player)
    if not state or not runtime then return nil, nil, 0, false end
    local count = GetEverchangingCount(player)
    local changed = count ~= state.knownCopies
    local styleChanged = false
    if count <= 0 then
        if state.styleId ~= nil or state.knownCopies ~= 0 then
            state.styleId = nil
            state.knownCopies = 0
            SaveMusicboxData()
        end
        return state, runtime, 0, changed
    end
    local draws = math.max(0, count - state.knownCopies)
    if not state.styleId and draws == 0 then draws = 1 end
    for _ = 1, draws do
        local selected = SelectStyle(player, state.styleId, STYLE_REGISTRY)
        if selected then
            styleChanged = styleChanged or state.styleId ~= selected.id
            state.styleId = selected.id
            state.rollCount = state.rollCount + 1
        end
    end
    if changed or draws > 0 then
        state.knownCopies = count
        SaveMusicboxData()
    end
    if changed or styleChanged then runtime.dirty = true end
    return state, runtime, count, changed or styleChanged
end
```

Add the ordinary-style visual path as this function:

```lua
local function SyncEverchangingVisual(player, state, runtime, count)
    if not state or not runtime then return false end
    if count <= 0 then
        if runtime.appliedStyleId ~= nil
            or runtime.appliedRole ~= nil
            or #runtime.appliedCostumeIds > 0
            or runtime.appliedPlayerAnm2 ~= nil
            or runtime.failedStyleId ~= nil then
            ClearEverchangingStyle(player)
        else
            runtime.dirty = false
        end
        return false
    end
    local playerAnm2Drifted = false
    local currentStyle = state.styleId and STYLE_REGISTRY.byId[state.styleId] or nil
    local fullResource = currentStyle
        and not currentStyle.pairRoles
        and currentStyle.resources
        and currentStyle.resources.full
        or nil
    if runtime.appliedStyleId == state.styleId
        and runtime.appliedRole == nil
        and runtime.appliedPlayerAnm2
        and fullResource
        and fullResource.anm2 then
        playerAnm2Drifted = PlayerAnm2Matches(player, fullResource.anm2) == false
    end
    if runtime.dirty
        or playerAnm2Drifted
        or (runtime.appliedStyleId ~= state.styleId
            and runtime.failedStyleId ~= state.styleId) then
        ApplyEverchangingStyle(player, state.styleId, nil)
    end
    return playerAnm2Drifted
end
```

- [ ] **Step 5: Apply pair resources atomically**

Add:

```lua
local TWIN_STYLE_ID = "tantan_daodao_twins"

local function ApplyEverchangingPair(pair, style)
    local jacobRuntime = GetEverchangingRuntime(pair.jacob)
    local esauRuntime = GetEverchangingRuntime(pair.esau)
    local jacobResources = ResolveStyleResources(style, "jacob")
    local esauResources = ResolveStyleResources(style, "esau")
    if not jacobRuntime or not esauRuntime or not jacobResources or not esauResources
        or not IsCompatiblePlayer(pair.jacob, jacobRuntime)
        or not IsCompatiblePlayer(pair.esau, esauRuntime) then
        ClearEverchangingStyle(pair.jacob)
        ClearEverchangingStyle(pair.esau)
        return false
    end
    local jacobOk = ApplyEverchangingStyle(pair.jacob, style.id, "jacob")
    local esauOk = ApplyEverchangingStyle(pair.esau, style.id, "esau")
    if not jacobOk or not esauOk then
        ClearEverchangingStyle(pair.jacob)
        ClearEverchangingStyle(pair.esau)
        return false
    end
    return true
end
```

Replace `SyncEverchangingPlayer` with pair-first coordination:

```lua
local function SyncEverchangingPlayer(player)
    local pair = GetNormalTwinPair(player)
    if pair then
        local jacobState, jacobRuntime, jacobCount, jacobChanged = UpdateEverchangingSelection(pair.jacob)
        local esauState, esauRuntime, esauCount, esauChanged = UpdateEverchangingSelection(pair.esau)
        local pairActive =
            (jacobCount > 0 and jacobState and jacobState.styleId == TWIN_STYLE_ID)
            or (esauCount > 0 and esauState and esauState.styleId == TWIN_STYLE_ID)
        if pairActive then
            ApplyEverchangingPair(pair, STYLE_REGISTRY.byId[TWIN_STYLE_ID])
        else
            SyncEverchangingVisual(pair.jacob, jacobState, jacobRuntime, jacobCount)
            SyncEverchangingVisual(pair.esau, esauState, esauRuntime, esauCount)
        end
        return jacobChanged or esauChanged
    end

    local state, runtime, count, changed = UpdateEverchangingSelection(player)
    if state and state.styleId == TWIN_STYLE_ID then
        ClearEverchangingStyle(player)
        runtime.dirty = false
        return changed
    end
    SyncEverchangingVisual(player, state, runtime, count)
    return changed
end
```

- [ ] **Step 6: Make debug forcing use the coordinator**

After saving the forced style, replace the direct single-player apply with:

```lua
runtime.failedStyleId = nil
runtime.dirty = true
if not IsStyleEligibleForPlayer(player, STYLE_REGISTRY.byId[styleId]) then
    return false, "style is not eligible for the current player"
end
SyncEverchangingPlayer(player)
if GetEverchangingRuntime(player).appliedStyleId ~= styleId then
    return false, "style application failed"
end
return true, "forced style " .. styleId
```

Export `GetRuntime = GetEverchangingRuntime` and `ApplyPair = ApplyEverchangingPair` through the test API.

- [ ] **Step 7: Run pair lifecycle and regression tests**

Run:

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_full_anm2_contract_test.lua
```

Expected: both pass, including injected add failure rollback, room/level/continue restoration, item loss, local-style restoration, partner loss/rejoin, unrelated-player isolation and zero extra RNG calls.

- [ ] **Step 8: Commit the pair coordinator**

```powershell
git add -- main.lua tests/everchanging_behavior_test.lua
git diff --cached --name-only
git commit -m "feat: synchronize twin creator style"
```

Expected staged set: only the two listed files.

### Task 5: Add debug aliases and aggregate visual regression

**Files:**
- Modify: `main.lua:18918-18945`
- Modify: `tests/everchanging_behavior_test.lua`
- Modify: `tests/everchanging_full_anm2_contract_test.lua`
- Modify: `tests/everchanging_atlas_visual_test.ps1`

**Interfaces:**
- Produces debug aliases: `twins`, `tantan`, `daodao` -> `tantan_daodao_twins`; `yoon`, `yoontoons` -> `yoontoons_storyteller`.
- Produces one PowerShell visual entry point for Ringo and all six new accessory files.

- [ ] **Step 1: Add failing command and no-full-skin assertions**

Add Lua assertions:

```lua
assertEquals(api.Callbacks.ExecuteCommand(nil, "nb_everchanging", "yoontoons"),
    "[neverbirth] Everchanging: forced style yoontoons_storyteller",
    "Yoontoons debug alias")
assertEquals(api.Callbacks.ExecuteCommand(nil, "nb_everchanging", "twins"),
    "[neverbirth] Everchanging: style is not eligible for the current player",
    "pair alias rejects an ordinary player")
```

In `tests/everchanging_full_anm2_contract_test.lua`, assert the Everchanging block contains all six costume paths and contains none of these strings:

```lua
local forbidden = {
    "costume_tantan_player.anm2",
    "costume_daodao_player.anm2",
    "costume_yoontoons_player.anm2",
    'id = "tantan_only"',
    'id = "daodao_only"',
}
```

- [ ] **Step 2: Run and verify red**

Run:

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_full_anm2_contract_test.lua
```

Expected: FAIL on missing aliases and missing new path assertions.

- [ ] **Step 3: Add aliases and usage text**

Extend `styleAliases`:

```lua
twins = "tantan_daodao_twins",
tantan = "tantan_daodao_twins",
daodao = "tantan_daodao_twins",
yoon = "yoontoons_storyteller",
yoontoons = "yoontoons_storyteller",
```

Set usage text to:

```text
usage: nb_everchanging ringo|banana|tokarev|twins|yoontoons
```

- [ ] **Step 4: Extend the visual aggregate**

Append to `tests/everchanging_atlas_visual_test.ps1`:

```powershell
& (Join-Path $PSScriptRoot 'creator_accessory_atlas_visual_test.ps1') -Root $Root
& (Join-Path $PSScriptRoot 'creator_accessory_anm2_visual_test.ps1') -Root $Root
Write-Output 'Everchanging creator accessory visual contracts passed'
```

- [ ] **Step 5: Run aggregate regression and commit**

Run:

```powershell
pwsh -NoProfile -File tests/everchanging_atlas_visual_test.ps1 -Root .
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_full_anm2_contract_test.lua
```

Expected: all pass.

Commit:

```powershell
git add -- main.lua tests/everchanging_behavior_test.lua tests/everchanging_full_anm2_contract_test.lua tests/everchanging_atlas_visual_test.ps1
git diff --cached --name-only
git commit -m "test: cover creator accessory styles"
```

### Task 6: Run full static validation and prepare in-game verification

**Files:**
- Verify only: all files from Tasks 1-5.

**Interfaces:**
- Produces: static proof report plus a separate in-game checklist; does not convert static results into a game-verified claim.

- [ ] **Step 1: Verify deterministic art regeneration**

Run:

```powershell
$paths = Get-ChildItem resources/gfx/characters/costumes/costume_tantan_*.png,resources/gfx/characters/costumes/costume_daodao_*.png,resources/gfx/characters/costumes/costume_yoontoons_*.png
$before = @{}; foreach($path in $paths){$before[$path.FullName]=(Get-FileHash $path.FullName -Algorithm SHA256).Hash}
pwsh -NoProfile -File tools/generate-creator-accessory-atlases.ps1 -Root .
foreach($path in $paths){if((Get-FileHash $path.FullName -Algorithm SHA256).Hash -ne $before[$path.FullName]){throw "nondeterministic atlas: $($path.Name)"}}
```

Expected: no exception.

- [ ] **Step 2: Run all focused contracts**

```powershell
pwsh -NoProfile -File tests/creator_accessory_atlas_visual_test.ps1 -Root .
pwsh -NoProfile -File tests/creator_accessory_anm2_visual_test.ps1 -Root .
pwsh -NoProfile -File tests/everchanging_atlas_visual_test.ps1 -Root .
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_behavior_test.lua
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests/everchanging_full_anm2_contract_test.lua
```

Expected: every command exits `0`.

- [ ] **Step 3: Run project-wide Lua and validators**

```powershell
$lua='C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe'
Get-ChildItem tests -Filter '*.lua' | Sort-Object Name | ForEach-Object { & $lua $_.FullName; if($LASTEXITCODE -ne 0){throw "Lua test failed: $($_.Name)"} }
pwsh -NoProfile -File docs/skills/isaac-validators/scripts/validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth
pwsh -NoProfile -File docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1 -Root .
git diff --check
```

Expected: no Lua failure, no new validator failure and no whitespace error. Report pre-existing failures separately with their exact command output.

- [ ] **Step 4: Perform the in-game matrix**

Verify normal Jacob/Esau:

1. either twin owns Everchanging and `nb_everchanging twins` is forced;
2. Esau displays Tantan and Jacob displays Daodao in front/right/back/left;
3. moving, firing, entering a room, changing floor, taking damage, pickup/D6 animation, death and revival preserve role assignment;
4. separating twins and rejoining does not swap or duplicate layers;
5. removing the triggering copy clears both pair layers and restores the other twin's saved ordinary style.

Verify exclusions:

1. ordinary Isaac and tainted Jacob cannot force or roll the paired style;
2. unrelated co-op players retain their own Everchanging visuals.

Verify Yoontoons:

1. force `nb_everchanging yoontoons` on a compatible standard player;
2. black hair, orange-red glasses and one blue accent remain readable at gameplay size;
3. the vanilla face stays visible and no black/red dirty pixels appear around the head;
4. common item costumes do not cause permanent disappearance or duplicate Add/Remove cycles.

- [ ] **Step 5: Record final evidence**

Report:

- six PNG paths, six ANM2 paths and six costume IDs;
- exact Lua and PowerShell test results;
- generic/profile validator results;
- which in-game matrix rows passed;
- any visual row not yet checked as `not game verified`.
