param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$gameRoot = Split-Path -Parent (Split-Path -Parent $Root)
$officialAnm2Path = Join-Path $gameRoot 'resources\gfx\001.000_player.anm2'
$officialAtlasPath = Join-Path $gameRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
$danteAtlasPath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
Add-Type -AssemblyName System.Drawing

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Open-BitmapCopy {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path) "missing image: $Path"
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) }
        finally { $source.Dispose() }
    }
    finally { $stream.Dispose() }
}

Assert-True (Test-Path -LiteralPath $officialAnm2Path) "missing official player ANM2: $officialAnm2Path"
[xml]$officialAnm2 = Get-Content -Raw -LiteralPath $officialAnm2Path
Assert-True ($officialAnm2.AnimatedActor.Animations.DefaultAnimation -eq 'WalkDown') `
    'official player ANM2 default animation must remain WalkDown'
Assert-True (@($officialAnm2.AnimatedActor.Animations.Animation).Count -eq 38) `
    'unexpected official player animation count; refresh the Dante geometry test against the live template'

$sheetZeroLayerIds = @($officialAnm2.AnimatedActor.Content.Layers.Layer |
    Where-Object { $_.SpritesheetId -eq '0' } |
    ForEach-Object { [int]$_.Id })
$sheetZeroFrames = @($officialAnm2.SelectNodes('//LayerAnimation/Frame') | Where-Object {
    $_.HasAttribute('XCrop') -and $sheetZeroLayerIds -contains [int]$_.ParentNode.LayerId
})
Assert-True ($sheetZeroFrames.Count -ge 400) "official player ANM2 sheet-zero frame coverage is unexpectedly small: $($sheetZeroFrames.Count)"
$cropRects = @($sheetZeroFrames | ForEach-Object {
    [pscustomobject]@{
        X = [int]$_.XCrop
        Y = [int]$_.YCrop
        W = [int]$_.Width
        H = [int]$_.Height
    }
} | Sort-Object X, Y, W, H -Unique)
Assert-True ($cropRects.Count -ge 70) "official player ANM2 unique crop coverage is unexpectedly small: $($cropRects.Count)"

$cropMask = [bool[]]::new(512 * 512)
foreach ($rect in $cropRects) {
    Assert-True ($rect.X -ge 0 -and $rect.Y -ge 0 -and $rect.W -gt 0 -and $rect.H -gt 0) `
        "invalid official crop rectangle: $($rect | ConvertTo-Json -Compress)"
    Assert-True (($rect.X + $rect.W) -le 512 -and ($rect.Y + $rect.H) -le 512) `
        "official crop exceeds the 512x512 Dante atlas: $($rect | ConvertTo-Json -Compress)"
    for ($y = $rect.Y; $y -lt ($rect.Y + $rect.H); $y++) {
        for ($x = $rect.X; $x -lt ($rect.X + $rect.W); $x++) {
            $cropMask[$y * 512 + $x] = $true
        }
    }
}

$official = Open-BitmapCopy -Path $officialAtlasPath
$dante = Open-BitmapCopy -Path $danteAtlasPath
try {
    Assert-True ($official.Width -eq 512 -and $official.Height -eq 512) 'official player atlas must be 512x512'
    Assert-True ($dante.Width -eq 512 -and $dante.Height -eq 512) 'Dante player atlas must be 512x512'
    $outsideAlphaDifferences = 0
    $headAlphaDifferences = 0
    $normalBodyAlphaDifferences = 0
    for ($y = 0; $y -lt 512; $y++) {
        for ($x = 0; $x -lt 512; $x++) {
            $index = $y * 512 + $x
            $officialAlpha = $official.GetPixel($x, $y).A
            $danteAlpha = $dante.GetPixel($x, $y).A
            if (-not $cropMask[$index] -and $officialAlpha -ne $danteAlpha) { $outsideAlphaDifferences++ }
            if ($officialAlpha -eq $danteAlpha) { continue }
            if ($y -lt 32 -and $x -lt 256) { $headAlphaDifferences++ }
            elseif ($y -ge 32 -and $y -lt 96 -and $x -lt 192) { $normalBodyAlphaDifferences++ }
        }
    }
    Assert-True ($outsideAlphaDifferences -eq 0) `
        "Dante changed alpha outside the official crop union: $outsideAlphaDifferences pixels"
    Assert-True ($headAlphaDifferences -ge 0 -and $headAlphaDifferences -le 96) `
        "Dante top-row base-only silhouette difference is outside its expected range: $headAlphaDifferences"
    Assert-True ($normalBodyAlphaDifferences -ge 12 -and $normalBodyAlphaDifferences -le 240) `
        "Dante original-full-skin body silhouette must differ inside owned normal-body crops: $normalBodyAlphaDifferences"

    foreach ($cell in @(
        @{ X = 0; Y = 32 }, @{ X = 32; Y = 32 }, @{ X = 64; Y = 32 },
        @{ X = 96; Y = 32 }, @{ X = 128; Y = 32 }, @{ X = 160; Y = 32 },
        @{ X = 0; Y = 64 }, @{ X = 32; Y = 64 }, @{ X = 64; Y = 64 },
        @{ X = 96; Y = 64 }, @{ X = 128; Y = 64 }, @{ X = 160; Y = 64 }
    )) {
        $cellDifferences = 0
        $officialBottom = -1
        $danteBottom = -1
        for ($localY = 0; $localY -lt 32; $localY++) {
            for ($localX = 0; $localX -lt 32; $localX++) {
                $officialAlpha = $official.GetPixel($cell.X + $localX, $cell.Y + $localY).A
                $danteAlpha = $dante.GetPixel($cell.X + $localX, $cell.Y + $localY).A
                if ($officialAlpha -ne $danteAlpha) { $cellDifferences++ }
                if ($officialAlpha -gt 0) { $officialBottom = [Math]::Max($officialBottom, $localY) }
                if ($danteAlpha -gt 0) { $danteBottom = [Math]::Max($danteBottom, $localY) }
            }
        }
        Assert-True ($cellDifferences -ge 1 -and $cellDifferences -le 32) `
            "Dante body cell $($cell.X),$($cell.Y) must have a controlled silhouette change: $cellDifferences"
        Assert-True ($danteBottom -eq $officialBottom) `
            "Dante body cell $($cell.X),$($cell.Y) changed foot contact: official=$officialBottom Dante=$danteBottom"
    }
}
finally {
    $official.Dispose()
    $dante.Dispose()
}

$menuAnm2Path = Join-Path $Root 'content\gfx\CharacterMenu.anm2'
[xml]$menuAnm2 = Get-Content -Raw -LiteralPath $menuAnm2Path
$sheetById = @{}
foreach ($sheet in $menuAnm2.AnimatedActor.Content.Spritesheets.Spritesheet) {
    $sheetById[[int]$sheet.Id] = $sheet.Path
}
$layerSheetById = @{}
foreach ($layer in $menuAnm2.AnimatedActor.Content.Layers.Layer) {
    $layerSheetById[[int]$layer.Id] = [int]$layer.SpritesheetId
}
$danteAnimation = @($menuAnm2.AnimatedActor.Animations.Animation | Where-Object { $_.Name -eq 'Dante' })[0]
foreach ($layerAnimation in $danteAnimation.LayerAnimations.LayerAnimation) {
    $layerId = [int]$layerAnimation.LayerId
    $frames = @($layerAnimation.Frame)
    if ($frames.Count -eq 0) { continue }
    $sheetId = $layerSheetById[$layerId]
    $sheetPath = Join-Path (Split-Path -Parent $menuAnm2Path) $sheetById[$sheetId]
    $sheetBitmap = Open-BitmapCopy -Path $sheetPath
    try {
        foreach ($frame in $frames) {
            if (-not $frame.HasAttribute('XCrop')) { continue }
            $x = [int]$frame.XCrop
            $y = [int]$frame.YCrop
            $width = [int]$frame.Width
            $height = [int]$frame.Height
            Assert-True ($x -ge 0 -and $y -ge 0 -and $width -gt 0 -and $height -gt 0) `
                "invalid Dante CharacterMenu crop on layer $layerId"
            Assert-True (($x + $width) -le $sheetBitmap.Width -and ($y + $height) -le $sheetBitmap.Height) `
                "Dante CharacterMenu crop exceeds $($sheetById[$sheetId]): crop=${x},${y},${width},${height}; sheet=$($sheetBitmap.Width)x$($sheetBitmap.Height)"
        }
    }
    finally { $sheetBitmap.Dispose() }
}

$evidence = @{
    'dante-native-1x-transparent.png' = @(512, 64)
    'dante-native-1x-backgrounds.png' = @(560, 252)
    'dante-native-4x-inspection.png' = @(1024, 300)
    'dante-special-crops-1x.png' = @(432, 94)
    'dante-surface-overview.png' = @(600, 340)
    'dante-official-template-overlay.png' = @(1536, 548)
    'dante-full-atlas-contact-sheet.png' = @(1320, 1910)
    'dante-hair-costume-contact-sheet.png' = @(1180, 920)
}
foreach ($entry in $evidence.GetEnumerator()) {
    $path = Join-Path $Root (Join-Path 'reports\dante-character' $entry.Key)
    $bitmap = Open-BitmapCopy -Path $path
    try {
        Assert-True ($bitmap.Width -eq $entry.Value[0] -and $bitmap.Height -eq $entry.Value[1]) `
            "$($entry.Key) dimensions are $($bitmap.Width)x$($bitmap.Height), expected $($entry.Value[0])x$($entry.Value[1])"
    }
    finally { $bitmap.Dispose() }
}

Write-Output 'Dante official-ANM2 crop geometry and native evidence contract passed'
