param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outputDir = Join-Path $Root 'resources\gfx\characters\costumes'
$previewDir = Join-Path $Root 'reports'
[void](New-Item -ItemType Directory -Path $outputDir -Force)
[void](New-Item -ItemType Directory -Path $previewDir -Force)

$headgearPath = Join-Path $outputDir 'costume_ringotsuga_headgear.png'
$previewPath = Join-Path $previewDir 'ringotsuga_accessory_atlases_preview.png'
$isaacRoot = Split-Path -Parent (Split-Path -Parent $Root)
$vanillaHeadPath = Join-Path $isaacRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
if (-not (Test-Path -LiteralPath $vanillaHeadPath)) { throw "missing vanilla Isaac atlas: $vanillaHeadPath" }

$palette = @{
    Transparent = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    Outline = [System.Drawing.Color]::FromArgb(255, 53, 40, 44)
    AppleDark = [System.Drawing.Color]::FromArgb(255, 143, 63, 61)
    Apple = [System.Drawing.Color]::FromArgb(255, 216, 97, 80)
    AppleLight = [System.Drawing.Color]::FromArgb(255, 239, 128, 105)
    StemDark = [System.Drawing.Color]::FromArgb(255, 73, 52, 43)
    Stem = [System.Drawing.Color]::FromArgb(255, 117, 81, 58)
    LeafDark = [System.Drawing.Color]::FromArgb(255, 53, 93, 72)
    Leaf = [System.Drawing.Color]::FromArgb(255, 92, 145, 100)
    LeafLight = [System.Drawing.Color]::FromArgb(255, 138, 187, 117)
}

function New-TransparentBitmap {
    param([int]$Width, [int]$Height)
    $bitmap = [System.Drawing.Bitmap]::new($Width, $Height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear($palette.Transparent)
    }
    finally { $graphics.Dispose() }
    return $bitmap
}

function Set-LocalPixel {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$OriginX,
        [int]$OriginY,
        [int]$X,
        [int]$Y,
        [System.Drawing.Color]$Color
    )
    $targetX = $OriginX + $X
    $targetY = $OriginY + $Y
    if ($targetX -lt 0 -or $targetX -ge $Bitmap.Width -or $targetY -lt 0 -or $targetY -ge $Bitmap.Height) {
        throw "pixel escaped atlas at $targetX,$targetY"
    }
    $Bitmap.SetPixel($targetX, $targetY, $Color)
}

function Fill-LocalSpan {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$OriginX,
        [int]$OriginY,
        [int]$Y,
        [int]$X1,
        [int]$X2,
        [System.Drawing.Color]$Color
    )
    for ($x = $X1; $x -le $X2; $x++) {
        Set-LocalPixel -Bitmap $Bitmap -OriginX $OriginX -OriginY $OriginY -X $x -Y $Y -Color $Color
    }
}

function Fill-LocalRect {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$OriginX,
        [int]$OriginY,
        [int]$X1,
        [int]$Y1,
        [int]$X2,
        [int]$Y2,
        [System.Drawing.Color]$Color
    )
    for ($y = $Y1; $y -le $Y2; $y++) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $OriginX -OriginY $OriginY -Y $y -X1 $X1 -X2 $X2 -Color $Color
    }
}

function Mirror-Cell {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$SourceCell,
        [int]$TargetCell,
        [int]$CellWidth,
        [int]$CellHeight
    )
    $columns = [int]($Bitmap.Width / $CellWidth)
    $sourceX = ($SourceCell % $columns) * $CellWidth
    $sourceY = [math]::Floor($SourceCell / $columns) * $CellHeight
    $targetX = ($TargetCell % $columns) * $CellWidth
    $targetY = [math]::Floor($TargetCell / $columns) * $CellHeight
    for ($y = 0; $y -lt $CellHeight; $y++) {
        for ($x = 0; $x -lt $CellWidth; $x++) {
            $Bitmap.SetPixel($targetX + (31 - $x), $targetY + $y, $Bitmap.GetPixel($sourceX + $x, $sourceY + $y))
        }
    }
}

function Normalize-TransparentPixels {
    param([System.Drawing.Bitmap]$Bitmap)
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -eq 0) { $Bitmap.SetPixel($x, $y, $palette.Transparent) }
        }
    }
}

function Get-VanillaHeadSourceX {
    param([ValidateSet('front', 'side', 'back')][string]$View, [ValidateSet(0, 1)][int]$Phase)
    $base = switch ($View) {
        front { 0 }
        side { 64 }
        back { 128 }
    }
    return $base + ($Phase * 32)
}

function Test-VanillaHeadPixel {
    param([System.Drawing.Bitmap]$Bitmap, [int]$SourceX, [int]$X, [int]$Y)
    if ($X -lt 0 -or $X -ge 32 -or $Y -lt 0 -or $Y -ge 32) { return $false }
    return $Bitmap.GetPixel($SourceX + $X, $Y).A -gt 0
}

function Test-RingoFaceAperture {
    param([ValidateSet('front', 'side', 'back')][string]$View, [int]$X, [int]$Y)
    if ($View -eq 'front') {
        if ($Y -eq 22) { return $X -ge 8 -and $X -le 23 }
        return $X -ge 7 -and $X -le 24 -and $Y -ge 12 -and $Y -le 21
    }
    if ($View -eq 'side') {
        return $X -ge 15 -and $Y -ge 11 -and $Y -le 24
    }
    return $false
}

function Draw-RingoHeadgear {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [System.Drawing.Bitmap]$VanillaHead,
        [int]$Cell,
        [ValidateSet('front', 'side', 'back')][string]$View,
        [ValidateSet(0, 1)][int]$Phase
    )

    $originX = $Cell * 32
    $sourceX = Get-VanillaHeadSourceX -View $View -Phase $Phase
    $neighbors = @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            if (-not (Test-VanillaHeadPixel -Bitmap $VanillaHead -SourceX $sourceX -X $x -Y $y)) { continue }
            if (Test-RingoFaceAperture -View $View -X $x -Y $y) { continue }

            $isBoundary = $false
            foreach ($delta in $neighbors) {
                if (-not (Test-VanillaHeadPixel -Bitmap $VanillaHead -SourceX $sourceX -X ($x + $delta[0]) -Y ($y + $delta[1]))) {
                    $isBoundary = $true
                    break
                }
            }

            $color = if ($isBoundary) {
                $palette.Outline
            }
            elseif ($x -le 5 -or $y -ge 23) {
                $palette.AppleDark
            }
            elseif ($x -le 11 -and $y -le 10) {
                $palette.AppleLight
            }
            else {
                $palette.Apple
            }
            Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X $x -Y ($y + 16) -Color $color
        }
    }

    $stemShift = $Phase
    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 14 -Y1 (7 + $stemShift) -X2 17 -Y2 (18 + $stemShift) -Color $palette.StemDark
    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY 0 -X1 15 -Y1 (8 + $stemShift) -X2 16 -Y2 (17 + $stemShift) -Color $palette.Stem
    foreach ($span in @(
        @(8,8,11), @(9,6,14), @(10,5,14), @(11,5,14),
        @(12,6,14), @(13,8,14), @(14,10,14)
    )) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y ($span[0] + $stemShift) -X1 $span[1] -X2 $span[2] -Color $palette.LeafDark
    }
    foreach ($span in @(
        @(9,9,12), @(10,7,13), @(11,6,13), @(12,8,13), @(13,10,13)
    )) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y ($span[0] + $stemShift) -X1 $span[1] -X2 $span[2] -Color $palette.Leaf
    }
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY 0 -Y (10 + $stemShift) -X1 7 -X2 10 -Color $palette.LeafLight
}

function Save-Png {
    param([System.Drawing.Bitmap]$Bitmap, [string]$Path)
    Normalize-TransparentPixels -Bitmap $Bitmap
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "generated $Path"
}

function Draw-Checkerboard {
    param([System.Drawing.Bitmap]$Bitmap)
    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    try {
        $light = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 225, 225, 225))
        $dark = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 195, 195, 195))
        try {
            for ($y = 0; $y -lt $Bitmap.Height; $y += 16) {
                for ($x = 0; $x -lt $Bitmap.Width; $x += 16) {
                    $brush = if ((($x / 16) + ($y / 16)) % 2 -eq 0) { $light } else { $dark }
                    $graphics.FillRectangle($brush, $x, $y, 16, 16)
                }
            }
        }
        finally { $light.Dispose(); $dark.Dispose() }
    }
    finally { $graphics.Dispose() }
}

function Draw-ScaledRegion {
    param(
        [System.Drawing.Bitmap]$Source,
        [System.Drawing.Bitmap]$Target,
        [int]$SourceX,
        [int]$SourceY,
        [int]$Width,
        [int]$Height,
        [int]$TargetX,
        [int]$TargetY,
        [int]$Scale,
        [switch]$MirrorX
    )
    $graphics = [System.Drawing.Graphics]::FromImage($Target)
    try {
        for ($y = 0; $y -lt $Height; $y++) {
            for ($x = 0; $x -lt $Width; $x++) {
                $pixel = $Source.GetPixel($SourceX + $x, $SourceY + $y)
                if ($pixel.A -eq 0) { continue }
                $brush = [System.Drawing.SolidBrush]::new($pixel)
                $targetLocalX = if ($MirrorX) { $Width - 1 - $x } else { $x }
                try { $graphics.FillRectangle($brush, $TargetX + ($targetLocalX * $Scale), $TargetY + ($y * $Scale), $Scale, $Scale) }
                finally { $brush.Dispose() }
            }
        }
    }
    finally { $graphics.Dispose() }
}

function New-CompositeFrame {
    param(
        [System.Drawing.Bitmap]$Headgear,
        [System.Drawing.Bitmap]$VanillaHead,
        [int]$HeadgearCell,
        [ValidateSet('front', 'side', 'back', 'left')][string]$View
    )
    $frame = New-TransparentBitmap -Width 64 -Height 64
    $sourceX = switch ($View) {
        front { 0 }
        side { 64 }
        back { 128 }
        left { 64 }
    }
    $mirrorVanilla = $View -eq 'left'
    Draw-ScaledRegion -Source $VanillaHead -Target $frame -SourceX $sourceX -SourceY 0 -Width 32 -Height 32 -TargetX 16 -TargetY 17 -Scale 1 -MirrorX:$mirrorVanilla
    Draw-ScaledRegion -Source $Headgear -Target $frame -SourceX ($HeadgearCell * 32) -SourceY 0 -Width 32 -Height 64 -TargetX 16 -TargetY 1 -Scale 1
    return $frame
}
$vanillaHead = [System.Drawing.Bitmap]::FromFile($vanillaHeadPath)
$headgear = New-TransparentBitmap -Width 256 -Height 64
try {
    Draw-RingoHeadgear -Bitmap $headgear -VanillaHead $vanillaHead -Cell 0 -View front -Phase 0
    Draw-RingoHeadgear -Bitmap $headgear -VanillaHead $vanillaHead -Cell 1 -View front -Phase 1
    Draw-RingoHeadgear -Bitmap $headgear -VanillaHead $vanillaHead -Cell 2 -View side -Phase 0
    Draw-RingoHeadgear -Bitmap $headgear -VanillaHead $vanillaHead -Cell 3 -View side -Phase 1
    Draw-RingoHeadgear -Bitmap $headgear -VanillaHead $vanillaHead -Cell 4 -View back -Phase 0
    Draw-RingoHeadgear -Bitmap $headgear -VanillaHead $vanillaHead -Cell 5 -View back -Phase 1
    Mirror-Cell -Bitmap $headgear -SourceCell 2 -TargetCell 6 -CellWidth 32 -CellHeight 64
    Mirror-Cell -Bitmap $headgear -SourceCell 3 -TargetCell 7 -CellWidth 32 -CellHeight 64


    Save-Png -Bitmap $headgear -Path $headgearPath

    $preview = [System.Drawing.Bitmap]::new(1280, 960, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    try {
        Draw-Checkerboard -Bitmap $preview
        Draw-ScaledRegion -Source $headgear -Target $preview -SourceX 0 -SourceY 0 -Width 256 -Height 64 -TargetX 32 -TargetY 32 -Scale 3
        $directions = @(
            @{ Headgear = 0; View = 'front' },
            @{ Headgear = 2; View = 'side' },
            @{ Headgear = 4; View = 'back' },
            @{ Headgear = 6; View = 'left' }
        )
        for ($index = 0; $index -lt $directions.Count; $index++) {
            $direction = $directions[$index]
            $composite = New-CompositeFrame -Headgear $headgear -VanillaHead $vanillaHead -HeadgearCell $direction.Headgear -View $direction.View
            try {
                Draw-ScaledRegion -Source $composite -Target $preview -SourceX 0 -SourceY 0 -Width 64 -Height 64 -TargetX 950 -TargetY (24 + ($index * 230)) -Scale 3
                Draw-ScaledRegion -Source $composite -Target $preview -SourceX 0 -SourceY 0 -Width 64 -Height 64 -TargetX 1160 -TargetY (76 + ($index * 230)) -Scale 1
            }
            finally { $composite.Dispose() }
        }
        $preview.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "generated $previewPath"
    }
    finally { $preview.Dispose() }
}
finally {
    $headgear.Dispose()
    $vanillaHead.Dispose()
}
