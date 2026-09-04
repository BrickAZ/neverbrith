param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$headgearPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_ringotsuga_headgear.png'
$removedShirtPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_ringotsuga_white_tshirt.png'
$isaacRoot = Split-Path -Parent (Split-Path -Parent $Root)
$vanillaHeadPath = Join-Path $isaacRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
$spec = @{
    Width = 256
    Height = 64
    CellWidth = 32
    CellHeight = 64
    RequiredCells = @(0, 1, 2, 3, 4, 5, 6, 7)
    MinimumPixels = 170
    MaximumPixels = 760
}

$palette = @(
    [System.Drawing.Color]::FromArgb(255, 53, 40, 44),
    [System.Drawing.Color]::FromArgb(255, 143, 63, 61),
    [System.Drawing.Color]::FromArgb(255, 216, 97, 80),
    [System.Drawing.Color]::FromArgb(255, 239, 128, 105),
    [System.Drawing.Color]::FromArgb(255, 73, 52, 43),
    [System.Drawing.Color]::FromArgb(255, 117, 81, 58),
    [System.Drawing.Color]::FromArgb(255, 53, 93, 72),
    [System.Drawing.Color]::FromArgb(255, 92, 145, 100),
    [System.Drawing.Color]::FromArgb(255, 138, 187, 117)
)
$allowedArgb = [System.Collections.Generic.HashSet[int]]::new()
$palette | ForEach-Object { [void]$allowedArgb.Add($_.ToArgb()) }

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Open-BitmapCopy {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path) "missing Ringo headgear atlas: $Path"
    $stream = [System.IO.File]::OpenRead($Path)
    try {
        $source = [System.Drawing.Bitmap]::FromStream($stream)
        try { return [System.Drawing.Bitmap]::new($source) }
        finally { $source.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-CellOrigin {
    param([int]$Cell)
    return @{ X = $Cell * $spec.CellWidth; Y = 0 }
}

function Get-VisibleCount {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Cell)
    $origin = Get-CellOrigin -Cell $Cell
    $count = 0
    for ($y = 0; $y -lt $spec.CellHeight; $y++) {
        for ($x = 0; $x -lt $spec.CellWidth; $x++) {
            if ($Bitmap.GetPixel($origin.X + $x, $origin.Y + $y).A -gt 0) { $count++ }
        }
    }
    return $count
}

function Get-CellBounds {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Cell)
    $origin = Get-CellOrigin -Cell $Cell
    $minX = $spec.CellWidth
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $spec.CellHeight; $y++) {
        for ($x = 0; $x -lt $spec.CellWidth; $x++) {
            if ($Bitmap.GetPixel($origin.X + $x, $origin.Y + $y).A -eq 0) { continue }
            $minX = [math]::Min($minX, $x)
            $maxX = [math]::Max($maxX, $x)
            $maxY = [math]::Max($maxY, $y)
        }
    }
    return @{ MinX = $minX; MaxX = $maxX; MaxY = $maxY }
}

function Get-ComponentCount {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Cell)
    $origin = Get-CellOrigin -Cell $Cell
    $visited = [bool[,]]::new($spec.CellWidth, $spec.CellHeight)
    $components = 0
    $neighbors = @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))
    for ($startY = 0; $startY -lt $spec.CellHeight; $startY++) {
        for ($startX = 0; $startX -lt $spec.CellWidth; $startX++) {
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
                    if ($nextX -lt 0 -or $nextX -ge $spec.CellWidth -or
                        $nextY -lt 0 -or $nextY -ge $spec.CellHeight -or
                        $visited[$nextX, $nextY]) { continue }
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

function Get-ColorCount {
    param([System.Drawing.Bitmap]$Bitmap, [int[]]$Rgb)
    $count = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.A -eq 255 -and $pixel.R -eq $Rgb[0] -and
                $pixel.G -eq $Rgb[1] -and $pixel.B -eq $Rgb[2]) {
                $count++
            }
        }
    }
    return $count
}

function Get-CellDifferenceCount {
    param([System.Drawing.Bitmap]$Bitmap, [int]$FirstCell, [int]$SecondCell, [bool]$MirrorSecond = $false)
    $first = Get-CellOrigin -Cell $FirstCell
    $second = Get-CellOrigin -Cell $SecondCell
    $differences = 0
    for ($y = 0; $y -lt $spec.CellHeight; $y++) {
        for ($x = 0; $x -lt $spec.CellWidth; $x++) {
            $secondX = if ($MirrorSecond) { $spec.CellWidth - 1 - $x } else { $x }
            if ($Bitmap.GetPixel($first.X + $x, $first.Y + $y).ToArgb() -ne
                $Bitmap.GetPixel($second.X + $secondX, $second.Y + $y).ToArgb()) {
                $differences++
            }
        }
    }
    return $differences
}

function Get-VanillaPixel {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Cell, [int]$X, [int]$Y)
    $sourceCell = switch ($Cell) {
        0 { 0 }; 1 { 1 }; 2 { 2 }; 3 { 3 }; 4 { 4 }; 5 { 5 }; 6 { 2 }; 7 { 3 }
    }
    $sourceX = if ($Cell -ge 6) { 31 - $X } else { $X }
    return $Bitmap.GetPixel(($sourceCell * 32) + $sourceX, $Y)
}

function Get-ReferenceFit {
    param([System.Drawing.Bitmap]$Headgear, [System.Drawing.Bitmap]$Vanilla, [int]$Cell)
    $boundary = 0
    $coveredBoundary = 0
    $outside = 0
    $neighbors = @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $vanillaPixel = Get-VanillaPixel -Bitmap $Vanilla -Cell $Cell -X $x -Y $y
            $gearPixel = $Headgear.GetPixel(($Cell * 32) + $x, $y + 16)
            if ($gearPixel.A -gt 0 -and $vanillaPixel.A -eq 0 -and $y -ge 3) { $outside++ }
            if ($vanillaPixel.A -eq 0) { continue }
            $isBoundary = $false
            foreach ($delta in $neighbors) {
                $nextX = $x + $delta[0]
                $nextY = $y + $delta[1]
                if ($nextX -lt 0 -or $nextX -ge 32 -or $nextY -lt 0 -or $nextY -ge 32 -or
                    (Get-VanillaPixel -Bitmap $Vanilla -Cell $Cell -X $nextX -Y $nextY).A -eq 0) {
                    $isBoundary = $true
                    break
                }
            }
            if ($isBoundary) {
                $boundary++
                if ($gearPixel.A -gt 0) { $coveredBoundary++ }
            }
        }
    }
    return @{ Boundary = $boundary; CoveredBoundary = $coveredBoundary; Outside = $outside }
}

function Get-ProtectedFacePaint {
    param([System.Drawing.Bitmap]$Bitmap, [int]$Cell)
    if ($Cell -in @(0, 1)) {
        $x1 = 7; $x2 = 24; $y1 = 12; $y2 = 22
    }
    elseif ($Cell -in @(2, 3)) {
        $x1 = 15; $x2 = 29; $y1 = 11; $y2 = 22
    }
    else {
        $x1 = 2; $x2 = 16; $y1 = 11; $y2 = 22
    }
    $painted = 0
    for ($y = $y1; $y -le $y2; $y++) {
        for ($x = $x1; $x -le $x2; $x++) {
            if ($Bitmap.GetPixel(($Cell * 32) + $x, $y + 16).A -gt 0) { $painted++ }
        }
    }
    return $painted
}
Assert-True (-not (Test-Path -LiteralPath $removedShirtPath)) 'Ringo white T-shirt atlas must be removed'
Assert-True (Test-Path -LiteralPath $vanillaHeadPath) "missing vanilla Isaac head reference: $vanillaHeadPath"
$headgear = Open-BitmapCopy -Path $headgearPath
$vanillaHead = Open-BitmapCopy -Path $vanillaHeadPath
try {
    Assert-True ($headgear.Width -eq $spec.Width -and $headgear.Height -eq $spec.Height) `
        "Ringo headgear canvas must be 256x64, got $($headgear.Width)x$($headgear.Height)"

    $semiTransparent = 0
    $dirtyTransparent = 0
    $unexpectedPalette = 0
    $pureBlack = 0
    for ($y = 0; $y -lt $headgear.Height; $y++) {
        for ($x = 0; $x -lt $headgear.Width; $x++) {
            $pixel = $headgear.GetPixel($x, $y)
            if ($pixel.A -ne 0 -and $pixel.A -ne 255) { $semiTransparent++ }
            if ($pixel.A -eq 0) {
                if ($pixel.R -ne 0 -or $pixel.G -ne 0 -or $pixel.B -ne 0) { $dirtyTransparent++ }
                continue
            }
            if (-not $allowedArgb.Contains($pixel.ToArgb())) { $unexpectedPalette++ }
            if ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0) { $pureBlack++ }
        }
    }
    Assert-True ($semiTransparent -eq 0) "headgear semi-transparent pixels: $semiTransparent"
    Assert-True ($dirtyTransparent -eq 0) "headgear dirty transparent RGB pixels: $dirtyTransparent"
    Assert-True ($unexpectedPalette -eq 0) "headgear pixels outside approved palette: $unexpectedPalette"
    Assert-True ($pureBlack -eq 0) "headgear contains pure-black visible pixels: $pureBlack"

    foreach ($cell in $spec.RequiredCells) {
        $visible = Get-VisibleCount -Bitmap $headgear -Cell $cell
        Assert-True ($visible -ge $spec.MinimumPixels -and $visible -le $spec.MaximumPixels) `
            "headgear cell $cell coverage out of range: $visible"
        Assert-True ((Get-ComponentCount -Bitmap $headgear -Cell $cell) -eq 1) `
            "headgear cell $cell must be one connected component"
        $bounds = Get-CellBounds -Bitmap $headgear -Cell $cell
        Assert-True ($bounds.MinX -ge 2 -and $bounds.MaxX -le 29 -and $bounds.MaxY -le 43) `
            "headgear cell $cell escapes native head bounds"
    }
        $fit = Get-ReferenceFit -Headgear $headgear -Vanilla $vanillaHead -Cell $cell
        $minimumBoundaryCoverage = if ($cell -in @(2, 3, 6, 7)) { 0.60 } else { 0.80 }
        $boundaryCoverage = $fit.CoveredBoundary / $fit.Boundary
        Assert-True ($boundaryCoverage -ge $minimumBoundaryCoverage) `
            "headgear cell $cell covers only $([math]::Round($boundaryCoverage * 100, 1))% of the real Isaac head boundary"
        Assert-True ($fit.Outside -le 16) `
            "headgear cell $cell has $($fit.Outside) pixels floating outside the real Isaac head"

    $forbiddenFacePixels =
        (Get-ColorCount -Bitmap $headgear -Rgb @(241, 209, 174)) +
        (Get-ColorCount -Bitmap $headgear -Rgb @(216, 170, 138)) +
        (Get-ColorCount -Bitmap $headgear -Rgb @(45, 114, 91)) +
        (Get-ColorCount -Bitmap $headgear -Rgb @(87, 167, 126)) +
        (Get-ColorCount -Bitmap $headgear -Rgb @(114, 215, 215))
    Assert-True ($forbiddenFacePixels -eq 0) `
        "headgear must not contain face, iris, or tear pixels: $forbiddenFacePixels"
    $leafPixels =
        (Get-ColorCount -Bitmap $headgear -Rgb @(53, 93, 72)) +
        (Get-ColorCount -Bitmap $headgear -Rgb @(92, 145, 100)) +
        (Get-ColorCount -Bitmap $headgear -Rgb @(138, 187, 117))
    Assert-True ($leafPixels -ge 80 -and $leafPixels -le 480) "Ringo leaf coverage: $leafPixels"
    foreach ($cell in @(0, 1, 2, 3, 6, 7)) {
        $protectedPaint = Get-ProtectedFacePaint -Bitmap $headgear -Cell $cell
        Assert-True ($protectedPaint -le 4) `
            "headgear cell $cell intrudes into the real Isaac face safe zone: $protectedPaint"
    }

    foreach ($pair in @(@(0, 1), @(2, 3), @(4, 5), @(6, 7))) {
        $differences = Get-CellDifferenceCount -Bitmap $headgear -FirstCell $pair[0] -SecondCell $pair[1]
        Assert-True ($differences -ge 18) "headgear phase pair $($pair[0])/$($pair[1]) is static"
    }
    foreach ($pair in @(@(2, 6), @(3, 7))) {
        $differences = Get-CellDifferenceCount -Bitmap $headgear -FirstCell $pair[0] -SecondCell $pair[1] -MirrorSecond $true
        Assert-True ($differences -eq 0) "headgear side pair $($pair[0])/$($pair[1]) is not mirrored"
    }
}
finally {
    $vanillaHead.Dispose()
    $headgear.Dispose()
}

Write-Output 'Ringo headgear-only atlas visual contract passed'
