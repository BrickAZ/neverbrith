param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$atlasSpecs = @(
    @{
        Label = 'apple shell'
        Path = Join-Path $Root 'resources\gfx\characters\costumes\costume_ringotsuga_apple_shell.png'
        Width = 256
        Height = 64
        CellWidth = 32
        CellHeight = 64
        RequiredCells = @(0, 1, 2, 3, 4, 5, 6, 7)
        EmptyCells = @()
        MinimumPixels = 180
    },
    @{
        Label = 'face'
        Path = Join-Path $Root 'resources\gfx\characters\costumes\costume_ringotsuga_face.png'
        Width = 256
        Height = 32
        CellWidth = 32
        CellHeight = 32
        RequiredCells = @(0, 1, 2, 3, 6, 7)
        EmptyCells = @(4, 5)
        MinimumPixels = 220
    },
    @{
        Label = 'shirt'
        Path = Join-Path $Root 'resources\gfx\characters\costumes\costume_ringotsuga_hoodie.png'
        Width = 256
        Height = 256
        CellWidth = 32
        CellHeight = 32
        RequiredCells = @(
            0, 1, 2, 3, 4, 5, 6, 7, 8, 9,
            16, 17, 18, 19, 20, 21, 22, 23, 24, 25,
            32, 33, 34, 35, 36, 37, 38, 39, 40, 41,
            48, 49, 50, 51, 52, 53, 54, 55, 56, 57
        )
        EmptyCells = @(
            10, 11, 12, 13, 14, 15,
            26, 27, 28, 29, 30, 31,
            42, 43, 44, 45, 46, 47,
            58, 59, 60, 61, 62, 63
        )
        MinimumPixels = 70
    }
)

$palette = @(
    [System.Drawing.Color]::FromArgb(255, 51, 32, 38),
    [System.Drawing.Color]::FromArgb(255, 109, 52, 56),
    [System.Drawing.Color]::FromArgb(255, 169, 67, 62),
    [System.Drawing.Color]::FromArgb(255, 217, 102, 85),
    [System.Drawing.Color]::FromArgb(255, 240, 128, 104),
    [System.Drawing.Color]::FromArgb(255, 246, 160, 128),
    [System.Drawing.Color]::FromArgb(255, 240, 227, 202),
    [System.Drawing.Color]::FromArgb(255, 48, 38, 42),
    [System.Drawing.Color]::FromArgb(255, 114, 215, 215),
    [System.Drawing.Color]::FromArgb(255, 58, 42, 36),
    [System.Drawing.Color]::FromArgb(255, 111, 77, 50),
    [System.Drawing.Color]::FromArgb(255, 52, 88, 68),
    [System.Drawing.Color]::FromArgb(255, 86, 130, 93),
    [System.Drawing.Color]::FromArgb(255, 126, 163, 108),
    [System.Drawing.Color]::FromArgb(255, 40, 40, 44),
    [System.Drawing.Color]::FromArgb(255, 160, 157, 149),
    [System.Drawing.Color]::FromArgb(255, 211, 206, 194),
    [System.Drawing.Color]::FromArgb(255, 238, 230, 215),
    [System.Drawing.Color]::FromArgb(255, 58, 53, 57)
)
$allowedArgb = [System.Collections.Generic.HashSet[int]]::new()
$palette | ForEach-Object { [void]$allowedArgb.Add($_.ToArgb()) }

function Open-BitmapCopy {
    param([string]$Path)

    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $source = [System.Drawing.Bitmap]::FromStream($stream)
        try {
            return [System.Drawing.Bitmap]::new($source)
        }
        finally {
            $source.Dispose()
        }
    }
    finally {
        $stream.Dispose()
    }
}

function Get-CellOrigin {
    param(
        [hashtable]$Spec,
        [int]$Cell
    )

    $columns = [int]($Spec.Width / $Spec.CellWidth)
    return @{
        X = ($Cell % $columns) * $Spec.CellWidth
        Y = [math]::Floor($Cell / $columns) * $Spec.CellHeight
    }
}

function Get-VisibleCount {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [hashtable]$Spec,
        [int]$Cell
    )

    $origin = Get-CellOrigin -Spec $Spec -Cell $Cell
    $count = 0
    for ($y = 0; $y -lt $Spec.CellHeight; $y++) {
        for ($x = 0; $x -lt $Spec.CellWidth; $x++) {
            if ($Bitmap.GetPixel($origin.X + $x, $origin.Y + $y).A -gt 0) {
                $count++
            }
        }
    }
    return $count
}

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

function Get-ComponentCount {
    param(
        [System.Drawing.Bitmap]$Bitmap,
        [hashtable]$Spec,
        [int]$Cell
    )

    $origin = Get-CellOrigin -Spec $Spec -Cell $Cell
    $visited = [bool[,]]::new($Spec.CellWidth, $Spec.CellHeight)
    $components = 0
    $neighbors = @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))

    for ($startY = 0; $startY -lt $Spec.CellHeight; $startY++) {
        for ($startX = 0; $startX -lt $Spec.CellWidth; $startX++) {
            if ($visited[$startX, $startY]) { continue }
            $visited[$startX, $startY] = $true
            if ($Bitmap.GetPixel($origin.X + $startX, $origin.Y + $startY).A -eq 0) { continue }

            $components++
            $queue = [System.Collections.Generic.Queue[object]]::new()
            $queue.Enqueue(@($startX, $startY))
            while ($queue.Count -gt 0) {
                $point = $queue.Dequeue()
                foreach ($delta in $neighbors) {
                    $nextX = $point[0] + $delta[0]
                    $nextY = $point[1] + $delta[1]
                    if ($nextX -lt 0 -or $nextX -ge $Spec.CellWidth -or
                        $nextY -lt 0 -or $nextY -ge $Spec.CellHeight -or
                        $visited[$nextX, $nextY]) {
                        continue
                    }
                    $visited[$nextX, $nextY] = $true
                    if ($Bitmap.GetPixel($origin.X + $nextX, $origin.Y + $nextY).A -gt 0) {
                        $queue.Enqueue(@($nextX, $nextY))
                    }
                }
            }
        }
    }
    return $components
}

function Assert-Atlas {
    param([hashtable]$Spec)

    if (-not (Test-Path -LiteralPath $Spec.Path)) {
        throw "missing Ringo accessory atlas: $($Spec.Path)"
    }

    $bitmap = Open-BitmapCopy -Path $Spec.Path
    try {
        if ($bitmap.Width -ne $Spec.Width -or $bitmap.Height -ne $Spec.Height) {
            throw "$($Spec.Label) canvas must be $($Spec.Width)x$($Spec.Height), got $($bitmap.Width)x$($bitmap.Height)"
        }

        $semiTransparent = 0
        $dirtyTransparent = 0
        $unexpectedPalette = 0
        $pureBlack = 0
        for ($y = 0; $y -lt $bitmap.Height; $y++) {
            for ($x = 0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x, $y)
                if ($pixel.A -ne 0 -and $pixel.A -ne 255) { $semiTransparent++ }
                if ($pixel.A -eq 0) {
                    if ($pixel.R -ne 0 -or $pixel.G -ne 0 -or $pixel.B -ne 0) {
                        $dirtyTransparent++
                    }
                    continue
                }
                if (-not $allowedArgb.Contains($pixel.ToArgb())) { $unexpectedPalette++ }
                if ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0) { $pureBlack++ }
            }
        }

        if ($semiTransparent -ne 0) { throw "$($Spec.Label) semi-transparent pixels: $semiTransparent" }
        if ($dirtyTransparent -ne 0) { throw "$($Spec.Label) dirty transparent RGB pixels: $dirtyTransparent" }
        if ($unexpectedPalette -ne 0) { throw "$($Spec.Label) pixels outside approved palette: $unexpectedPalette" }
        if ($pureBlack -ne 0) { throw "$($Spec.Label) contains pure-black visible pixels: $pureBlack" }

        foreach ($cell in $Spec.RequiredCells) {
            $visible = Get-VisibleCount -Bitmap $bitmap -Spec $Spec -Cell $cell
            if ($visible -lt $Spec.MinimumPixels) {
                throw "$($Spec.Label) cell $cell is too sparse: $visible"
            }
            $components = Get-ComponentCount -Bitmap $bitmap -Spec $Spec -Cell $cell
            if ($components -ne 1) {
                throw "$($Spec.Label) cell $cell has $components detached visible components"
            }
        }
        foreach ($cell in $Spec.EmptyCells) {
            $visible = Get-VisibleCount -Bitmap $bitmap -Spec $Spec -Cell $cell
            if ($visible -ne 0) {
                throw "$($Spec.Label) cell $cell must be transparent, got $visible visible pixels"
            }
        }
    }
    finally {
        $bitmap.Dispose()
    }
}

foreach ($spec in $atlasSpecs) {
    Assert-Atlas -Spec $spec
}

$shell = Open-BitmapCopy -Path $atlasSpecs[0].Path
$face = Open-BitmapCopy -Path $atlasSpecs[1].Path
$hoodie = Open-BitmapCopy -Path $atlasSpecs[2].Path
try {
    foreach ($cell in @(0, 1, 2, 3, 6, 7)) {
        $cellX = $cell * 32
        $transparentOpening = 0
        for ($y = 25; $y -le 43; $y++) {
            for ($x = 7; $x -le 24; $x++) {
                if ($shell.GetPixel($cellX + $x, $y).A -eq 0) {
                    $transparentOpening++
                }
            }
        }
        if ($transparentOpening -lt 90) {
            throw "apple shell cell $cell does not preserve a usable face opening: $transparentOpening"
        }
    }
    foreach ($cell in @(4, 5)) {
        $cellX = $cell * 32
        $solidBack = 0
        for ($y = 25; $y -le 43; $y++) {
            for ($x = 7; $x -le 24; $x++) {
                if ($shell.GetPixel($cellX + $x, $y).A -eq 255) {
                    $solidBack++
                }
            }
        }
        if ($solidBack -lt 280) {
            throw "apple shell back cell $cell is not solid enough: $solidBack"
        }
    }

    $topRow = Get-VisibleXs -Bitmap $shell -Cell 0 -CellWidth 32 -Y 22
    $bellyRow = Get-VisibleXs -Bitmap $shell -Cell 0 -CellWidth 32 -Y 34
    $bottomRow = Get-VisibleXs -Bitmap $shell -Cell 0 -CellWidth 32 -Y 45
    if ($topRow -contains 15 -or $topRow -contains 16) {
        throw 'apple shell front lacks the approved top cleft'
    }
    $bellyWidth = if ($bellyRow.Count -eq 0) { 0 } else { $bellyRow[-1] - $bellyRow[0] + 1 }
    if ($bellyWidth -lt 27) {
        throw "apple shell front is not broad enough at the belly: $bellyWidth"
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

    for ($phase = 0; $phase -lt 10; $phase++) {
        $rightCell = if ($phase -lt 8) { $phase } else { 8 + ($phase - 8) }
        $leftCell = if ($phase -lt 8) { 32 + $phase } else { 40 + ($phase - 8) }
        $rightOrigin = Get-CellOrigin -Spec $atlasSpecs[2] -Cell $rightCell
        $leftOrigin = Get-CellOrigin -Spec $atlasSpecs[2] -Cell $leftCell
        for ($y = 0; $y -lt 32; $y++) {
            for ($x = 0; $x -lt 32; $x++) {
                $rightPixel = $hoodie.GetPixel($rightOrigin.X + $x, $rightOrigin.Y + $y).ToArgb()
                $leftPixel = $hoodie.GetPixel($leftOrigin.X + (31 - $x), $leftOrigin.Y + $y).ToArgb()
                if ($rightPixel -ne $leftPixel) {
                    throw "hoodie right/left phase $phase is not mirrored at $x,$y"
                }
            }
        }
    }
}
finally {
    $shell.Dispose()
    $face.Dispose()
    $hoodie.Dispose()
}

Write-Output 'Ringo accessory atlas visual contract passed'
