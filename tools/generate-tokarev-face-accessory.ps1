param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$outputPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_tokarev_face.png'
$outputDir = Split-Path -Parent $outputPath
if (-not (Test-Path $outputDir)) {
    [void](New-Item -ItemType Directory -Path $outputDir -Force)
}

$palette = @{
    Edge      = [System.Drawing.Color]::FromArgb(255, 18, 18, 34)
    Navy      = [System.Drawing.Color]::FromArgb(255, 25, 28, 51)
    NavyLight = [System.Drawing.Color]::FromArgb(255, 34, 39, 68)
    Cyan      = [System.Drawing.Color]::FromArgb(255, 48, 205, 210)
    CyanLight = [System.Drawing.Color]::FromArgb(255, 105, 238, 232)
}

$bitmap = [System.Drawing.Bitmap]::new(
    256,
    32,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)

function Set-Pixel {
    param(
        [int]$Cell,
        [int]$X,
        [int]$Y,
        [System.Drawing.Color]$Color
    )
    $bitmap.SetPixel(($Cell * 32) + $X, $Y, $Color)
}

function Fill-Span {
    param(
        [int]$Cell,
        [int]$Y,
        [int]$X1,
        [int]$X2,
        [System.Drawing.Color]$Color
    )
    for ($x = $X1; $x -le $X2; $x++) {
        Set-Pixel -Cell $Cell -X $x -Y $Y -Color $Color
    }
}

function Draw-MaskBase {
    param([int]$Cell)

    $edgeSpans = @(
        @(6, 12, 19), @(7, 9, 22), @(8, 7, 24), @(9, 5, 26), @(10, 4, 27),
        @(11, 3, 28), @(12, 3, 28), @(13, 3, 28), @(14, 3, 28), @(15, 3, 28),
        @(16, 3, 28), @(17, 3, 28), @(18, 3, 28), @(19, 3, 28), @(20, 3, 28),
        @(21, 3, 28), @(22, 3, 28), @(23, 4, 27), @(24, 5, 26), @(25, 7, 24),
        @(26, 9, 22), @(27, 12, 19)
    )
    foreach ($span in $edgeSpans) {
        Fill-Span -Cell $Cell -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Edge
    }

    $lightSpans = @(@(7, 12, 19), @(8, 9, 22), @(9, 7, 24))
    foreach ($span in $lightSpans) {
        Fill-Span -Cell $Cell -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.NavyLight
    }

    $navySpans = @(
        @(10, 6, 25), @(11, 5, 26), @(12, 5, 26), @(13, 5, 26), @(14, 5, 26),
        @(15, 5, 26), @(16, 5, 26), @(17, 5, 26), @(18, 5, 26), @(19, 5, 26),
        @(20, 5, 26), @(21, 5, 26), @(22, 6, 25), @(23, 7, 24), @(24, 9, 22),
        @(25, 12, 19)
    )
    foreach ($span in $navySpans) {
        Fill-Span -Cell $Cell -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Navy
    }
}

function Draw-FrontFace {
    param([int]$Cell)
    Draw-MaskBase -Cell $Cell

    $leftEye = @(
        @(12, 6, 11), @(13, 6, 13), @(14, 7, 14),
        @(15, 8, 14), @(16, 9, 13), @(17, 10, 12)
    )
    $rightEye = @(
        @(12, 20, 25), @(13, 18, 25), @(14, 17, 24),
        @(15, 17, 23), @(16, 18, 22), @(17, 19, 21)
    )
    foreach ($span in $leftEye + $rightEye) {
        Fill-Span -Cell $Cell -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Cyan
    }
    Fill-Span -Cell $Cell -Y 13 -X1 7 -X2 9 -Color $palette.CyanLight
    Fill-Span -Cell $Cell -Y 13 -X1 22 -X2 24 -Color $palette.CyanLight
}

function Draw-RightFace {
    param([int]$Cell)
    Draw-MaskBase -Cell $Cell

    $mainEye = @(
        @(12, 17, 23), @(13, 14, 25), @(14, 13, 25),
        @(15, 14, 24), @(16, 15, 23), @(17, 17, 21)
    )
    foreach ($span in $mainEye) {
        Fill-Span -Cell $Cell -Y $span[0] -X1 $span[1] -X2 $span[2] -Color $palette.Cyan
    }
    Fill-Span -Cell $Cell -Y 13 -X1 21 -X2 23 -Color $palette.CyanLight
    Fill-Span -Cell $Cell -Y 14 -X1 8 -X2 9 -Color $palette.Cyan
    Fill-Span -Cell $Cell -Y 15 -X1 8 -X2 9 -Color $palette.Cyan
}

function Copy-Cell {
    param([int]$Source, [int]$Target)
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $bitmap.SetPixel(($Target * 32) + $x, $y, $bitmap.GetPixel(($Source * 32) + $x, $y))
        }
    }
}

function Mirror-Cell {
    param([int]$Source, [int]$Target)
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $bitmap.SetPixel(($Target * 32) + (31 - $x), $y, $bitmap.GetPixel(($Source * 32) + $x, $y))
        }
    }
}

try {
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [System.Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear([System.Drawing.Color]::FromArgb(0, 0, 0, 0))
    }
    finally {
        $graphics.Dispose()
    }

    Draw-FrontFace -Cell 0
    Copy-Cell -Source 0 -Target 1
    Draw-RightFace -Cell 2
    Copy-Cell -Source 2 -Target 3
    Mirror-Cell -Source 2 -Target 6
    Copy-Cell -Source 6 -Target 7

    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 256; $x++) {
            if ($bitmap.GetPixel($x, $y).A -eq 0) {
                $bitmap.SetPixel($x, $y, [System.Drawing.Color]::FromArgb(0, 0, 0, 0))
            }
        }
    }

    $bitmap.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $bitmap.Dispose()
}

Write-Output "generated $outputPath"
