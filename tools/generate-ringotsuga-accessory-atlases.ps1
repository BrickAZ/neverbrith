param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outputDir = Join-Path $Root 'resources\gfx\characters\costumes'
$previewDir = Join-Path $Root 'reports'
if (-not (Test-Path -LiteralPath $outputDir)) {
    [void](New-Item -ItemType Directory -Path $outputDir -Force)
}
if (-not (Test-Path -LiteralPath $previewDir)) {
    [void](New-Item -ItemType Directory -Path $previewDir -Force)
}

$shellPath = Join-Path $outputDir 'costume_ringotsuga_apple_shell.png'
$facePath = Join-Path $outputDir 'costume_ringotsuga_face.png'
$hoodiePath = Join-Path $outputDir 'costume_ringotsuga_hoodie.png'
$previewPath = Join-Path $previewDir 'ringotsuga_accessory_atlases_preview.png'

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
function New-TransparentBitmap {
    param(
        [int]$Width,
        [int]$Height
    )

    $bitmap = [System.Drawing.Bitmap]::new(
        $Width,
        $Height,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear($palette.Transparent)
    }
    finally {
        $graphics.Dispose()
    }
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
    if ($targetX -lt 0 -or $targetX -ge $Bitmap.Width -or
        $targetY -lt 0 -or $targetY -ge $Bitmap.Height) {
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

function Copy-Cell {
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
            $Bitmap.SetPixel($targetX + $x, $targetY + $y, $Bitmap.GetPixel($sourceX + $x, $sourceY + $y))
        }
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
            $Bitmap.SetPixel(
                $targetX + (31 - $x),
                $targetY + $y,
                $Bitmap.GetPixel($sourceX + $x, $sourceY + $y)
            )
        }
    }
}

function Normalize-TransparentPixels {
    param([System.Drawing.Bitmap]$Bitmap)

    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            if ($Bitmap.GetPixel($x, $y).A -eq 0) {
                $Bitmap.SetPixel($x, $y, $palette.Transparent)
            }
        }
    }
}

function Draw-AppleSilhouette {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Cell,
        [ValidateSet('front', 'side', 'back')]
        [string]$View
    )

    $originX = $Cell * 32
    $originY = 0
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
    foreach ($span in $edgeSpans) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.AppleEdge
        if (($span[2] - $span[1]) -ge 2) {
            Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 ($span[1] + 1) -X2 ($span[2] - 1) -Color $palette.Apple
        }
    }

    foreach ($span in @(
        @(24, 10, 17), @(25, 8, 16), @(26, 7, 14),
        @(27, 6, 12), @(28, 5, 9)
    )) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.AppleLight
    }
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 25 -X1 10 -X2 13 -Color $palette.AppleShine
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 38 -X1 3 -X2 6 -Color $palette.AppleDark
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 39 -X1 4 -X2 8 -Color $palette.AppleDark

    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 14 -Y1 14 -X2 17 -Y2 21 -Color $palette.StemDark
    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 15 -Y1 15 -X2 16 -Y2 21 -Color $palette.Stem
    foreach ($span in @(
        @(15, 20, 24), @(16, 18, 26), @(17, 17, 27),
        @(18, 17, 27), @(19, 18, 26), @(20, 19, 25),
        @(21, 21, 23)
    )) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.LeafDark
    }
    foreach ($span in @(
        @(16, 20, 23), @(17, 19, 25), @(18, 18, 25),
        @(19, 19, 24), @(20, 20, 23)
    )) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Leaf
    }
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 16 -X1 21 -X2 23 -Color $palette.LeafLight

    if ($View -eq 'back') {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 29 -X1 25 -X2 27 -Color $palette.AppleDark
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 30 -X1 26 -X2 28 -Color $palette.AppleDark
        return
    }

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

    foreach ($span in $holeSpans) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Transparent
        Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X ($span[1] - 1) -Y $span[0] -Color $palette.AppleInnerEdge
        Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X ($span[2] + 1) -Y $span[0] -Color $palette.AppleInnerEdge
    }
    $firstHole = $holeSpans[0]
    $lastHole = $holeSpans[-1]
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y ($firstHole[0] - 1) -X1 $firstHole[1] -X2 $firstHole[2] -Color $palette.AppleInnerEdge
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y ($lastHole[0] + 1) -X1 $lastHole[1] -X2 $lastHole[2] -Color $palette.AppleInnerEdge
}
function Draw-FacePlane {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Cell,
        [ValidateSet('front', 'side')]
        [string]$View
    )

    $originX = $Cell * 32
    $originY = 0
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
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.AppleInnerEdge
        if (($span[2] - $span[1]) -ge 2) {
            Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 ($span[1] + 1) -X2 ($span[2] - 1) -Color $palette.Apple
        }
    }
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 9 -X1 10 -X2 15 -Color $palette.AppleLight
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 10 -X1 8 -X2 12 -Color $palette.AppleLight

    if ($View -eq 'front') {
        foreach ($span in @(
            @(12, 9, 12), @(13, 7, 13), @(14, 7, 13),
            @(15, 7, 13), @(16, 7, 13), @(17, 7, 13), @(18, 9, 12),
            @(12, 19, 22), @(13, 18, 24), @(14, 18, 24),
            @(15, 18, 24), @(16, 18, 24), @(17, 18, 24), @(18, 19, 22)
        )) {
            Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.EyeCream
        }
        Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 10 -Y1 15 -X2 11 -Y2 16 -Color $palette.FaceDark
        Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 20 -Y1 14 -X2 21 -Y2 15 -Color $palette.FaceDark
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 21 -X1 14 -X2 17 -Color $palette.FaceDark
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 22 -X1 15 -X2 16 -Color $palette.FaceDark
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 19 -X1 9 -X2 10 -Color $palette.Tear
        Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X 9 -Y 20 -Color $palette.Tear
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 19 -X1 21 -X2 22 -Color $palette.Tear
        Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X 22 -Y 20 -Color $palette.Tear
    }
    else {
        foreach ($span in @(
            @(12, 19, 22), @(13, 17, 24), @(14, 17, 24),
            @(15, 17, 24), @(16, 17, 24), @(17, 17, 24), @(18, 19, 22)
        )) {
            Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.EyeCream
        }
        Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 20 -Y1 14 -X2 21 -Y2 15 -Color $palette.FaceDark
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 20 -X1 25 -X2 26 -Color $palette.FaceDark
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y 19 -X1 21 -X2 22 -Color $palette.Tear
        Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X 22 -Y 20 -Color $palette.Tear
    }
}
function Draw-HoodieFrame {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [int]$Cell,
        [ValidateSet('front', 'right', 'back')]
        [string]$View,
        [int]$Phase
    )

    $columns = 8
    $originX = ($Cell % $columns) * 32
    $originY = [math]::Floor($Cell / $columns) * 32
    $bobSequence = @(1, 1, 0, 0, 1, 2, 2, 1, 0, 0)
    $stepSequence = @(-1, 0, 1, 1, 0, -1, -1, 0, 1, 0)
    $bob = $bobSequence[$Phase]
    $step = $stepSequence[$Phase]

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

    foreach ($span in $edgeSpans) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y ($span[0] + $bob) -X1 $span[1] -X2 $span[2] -Color $palette.ShirtEdge
    }
    foreach ($span in $fillSpans) {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y ($span[0] + $bob) -X1 $span[1] -X2 $span[2] -Color $palette.Shirt
    }

    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 7 -Y1 (17 + $bob) -X2 9 -Y2 (21 + $bob) -Color $palette.Limb
    Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 22 -Y1 (17 + $bob) -X2 24 -Y2 (21 + $bob) -Color $palette.Limb
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (14 + $bob) -X1 11 -X2 18 -Color $palette.ShirtLight
    Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (23 + $bob) -X1 11 -X2 20 -Color $palette.ShirtShadow

    if ($View -eq 'front') {
        Fill-LocalSpan -Bitmap $Bitmap -OriginX $originX -OriginY $originY -Y (14 + $bob) -X1 14 -X2 17 -Color $palette.ShirtShadow
    }
    elseif ($View -eq 'back') {
        Set-LocalPixel -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X 12 -Y (14 + $bob) -Color $palette.ShirtLight
    }
    else {
        Fill-LocalRect -Bitmap $Bitmap -OriginX $originX -OriginY $originY -X1 22 -Y1 (18 + $bob) -X2 22 -Y2 (22 + $bob) -Color $palette.ShirtShadow
    }

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
}
function Save-Png {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [string]$Path
    )

    Normalize-TransparentPixels -Bitmap $Bitmap
    $Bitmap.Save($Path, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "generated $Path"
}

function Draw-Checkerboard {
    param([System.Drawing.Bitmap]$Bitmap)

    $graphics = [System.Drawing.Graphics]::FromImage($Bitmap)
    try {
        $light = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 214, 216, 221))
        $dark = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 184, 187, 194))
        try {
            for ($y = 0; $y -lt $Bitmap.Height; $y += 8) {
                for ($x = 0; $x -lt $Bitmap.Width; $x += 8) {
                    $brush = if (((($x / 8) + ($y / 8)) % 2) -eq 0) { $light } else { $dark }
                    $graphics.FillRectangle($brush, $x, $y, 8, 8)
                }
            }
        }
        finally {
            $light.Dispose()
            $dark.Dispose()
        }
    }
    finally {
        $graphics.Dispose()
    }
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
        [int]$Scale
    )

    $graphics = [System.Drawing.Graphics]::FromImage($Target)
    try {
        foreach ($y in 0..($Height - 1)) {
            foreach ($x in 0..($Width - 1)) {
                $pixel = $Source.GetPixel($SourceX + $x, $SourceY + $y)
                if ($pixel.A -eq 0) { continue }
                $brush = [System.Drawing.SolidBrush]::new($pixel)
                try {
                    $graphics.FillRectangle($brush, $TargetX + ($x * $Scale), $TargetY + ($y * $Scale), $Scale, $Scale)
                }
                finally {
                    $brush.Dispose()
                }
            }
        }
    }
    finally {
        $graphics.Dispose()
    }
}

function New-CompositeFrame {
    param(
        [System.Drawing.Bitmap]$Shell,
        [System.Drawing.Bitmap]$Face,
        [System.Drawing.Bitmap]$Hoodie,
        [int]$ShellCell,
        [int]$FaceCell,
        [int]$HoodieCell
    )

    $frame = New-TransparentBitmap -Width 64 -Height 64
    $hoodieOriginX = ($HoodieCell % 8) * 32
    $hoodieOriginY = [math]::Floor($HoodieCell / 8) * 32
    Draw-ScaledRegion -Source $Hoodie -Target $frame -SourceX $hoodieOriginX -SourceY $hoodieOriginY -Width 32 -Height 32 -TargetX 16 -TargetY 27 -Scale 1
    Draw-ScaledRegion -Source $Face -Target $frame -SourceX ($FaceCell * 32) -SourceY 0 -Width 32 -Height 32 -TargetX 16 -TargetY 17 -Scale 1
    Draw-ScaledRegion -Source $Shell -Target $frame -SourceX ($ShellCell * 32) -SourceY 0 -Width 32 -Height 64 -TargetX 16 -TargetY 1 -Scale 1
    return $frame
}

$shell = New-TransparentBitmap -Width 256 -Height 64
$face = New-TransparentBitmap -Width 256 -Height 32
$hoodie = New-TransparentBitmap -Width 256 -Height 256
try {
    Draw-AppleSilhouette -Bitmap $shell -Cell 0 -View front
    Copy-Cell -Bitmap $shell -SourceCell 0 -TargetCell 1 -CellWidth 32 -CellHeight 64
    Draw-AppleSilhouette -Bitmap $shell -Cell 2 -View side
    Copy-Cell -Bitmap $shell -SourceCell 2 -TargetCell 3 -CellWidth 32 -CellHeight 64
    Draw-AppleSilhouette -Bitmap $shell -Cell 4 -View back
    Copy-Cell -Bitmap $shell -SourceCell 4 -TargetCell 5 -CellWidth 32 -CellHeight 64
    Mirror-Cell -Bitmap $shell -SourceCell 2 -TargetCell 6 -CellWidth 32 -CellHeight 64
    Copy-Cell -Bitmap $shell -SourceCell 6 -TargetCell 7 -CellWidth 32 -CellHeight 64

    Draw-FacePlane -Bitmap $face -Cell 0 -View front
    Copy-Cell -Bitmap $face -SourceCell 0 -TargetCell 1 -CellWidth 32 -CellHeight 32
    Draw-FacePlane -Bitmap $face -Cell 2 -View side
    Copy-Cell -Bitmap $face -SourceCell 2 -TargetCell 3 -CellWidth 32 -CellHeight 32
    Mirror-Cell -Bitmap $face -SourceCell 2 -TargetCell 6 -CellWidth 32 -CellHeight 32
    Copy-Cell -Bitmap $face -SourceCell 6 -TargetCell 7 -CellWidth 32 -CellHeight 32

    for ($phase = 0; $phase -lt 10; $phase++) {
        $rightCell = if ($phase -lt 8) { $phase } else { 8 + ($phase - 8) }
        $downCell = if ($phase -lt 8) { 16 + $phase } else { 24 + ($phase - 8) }
        $leftCell = if ($phase -lt 8) { 32 + $phase } else { 40 + ($phase - 8) }
        $upCell = if ($phase -lt 8) { 48 + $phase } else { 56 + ($phase - 8) }
        Draw-HoodieFrame -Bitmap $hoodie -Cell $rightCell -View right -Phase $phase
        Draw-HoodieFrame -Bitmap $hoodie -Cell $downCell -View front -Phase $phase
        Draw-HoodieFrame -Bitmap $hoodie -Cell $upCell -View back -Phase $phase
        Mirror-Cell -Bitmap $hoodie -SourceCell $rightCell -TargetCell $leftCell -CellWidth 32 -CellHeight 32
    }

    Save-Png -Bitmap $shell -Path $shellPath
    Save-Png -Bitmap $face -Path $facePath
    Save-Png -Bitmap $hoodie -Path $hoodiePath

    $preview = [System.Drawing.Bitmap]::new(
        1280,
        960,
        [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    try {
        Draw-Checkerboard -Bitmap $preview
        Draw-ScaledRegion -Source $shell -Target $preview -SourceX 0 -SourceY 0 -Width 256 -Height 64 -TargetX 32 -TargetY 32 -Scale 3
        Draw-ScaledRegion -Source $face -Target $preview -SourceX 0 -SourceY 0 -Width 256 -Height 32 -TargetX 32 -TargetY 250 -Scale 3
        Draw-ScaledRegion -Source $hoodie -Target $preview -SourceX 0 -SourceY 0 -Width 256 -Height 256 -TargetX 32 -TargetY 380 -Scale 2

        $directions = @(
            @{ Shell = 0; Face = 0; Hoodie = 16 },
            @{ Shell = 2; Face = 2; Hoodie = 0 },
            @{ Shell = 4; Face = 4; Hoodie = 48 },
            @{ Shell = 6; Face = 6; Hoodie = 32 }
        )
        for ($index = 0; $index -lt $directions.Count; $index++) {
            $direction = $directions[$index]
            $composite = New-CompositeFrame -Shell $shell -Face $face -Hoodie $hoodie -ShellCell $direction.Shell -FaceCell $direction.Face -HoodieCell $direction.Hoodie
            try {
                Draw-ScaledRegion -Source $composite -Target $preview -SourceX 0 -SourceY 0 -Width 64 -Height 64 -TargetX 950 -TargetY (24 + ($index * 230)) -Scale 3
                Draw-ScaledRegion -Source $composite -Target $preview -SourceX 0 -SourceY 0 -Width 64 -Height 64 -TargetX 1160 -TargetY (76 + ($index * 230)) -Scale 1
            }
            finally {
                $composite.Dispose()
            }
        }

        $preview.Save($previewPath, [System.Drawing.Imaging.ImageFormat]::Png)
        Write-Output "generated $previewPath"
    }
    finally {
        $preview.Dispose()
    }
}
finally {
    $shell.Dispose()
    $face.Dispose()
    $hoodie.Dispose()
}
