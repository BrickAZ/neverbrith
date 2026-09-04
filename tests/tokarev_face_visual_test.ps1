param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$pngPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_tokarev_face.png'
$anm2Path = Join-Path $Root 'resources\gfx\characters\costume_tokarev_face.anm2'

if (-not (Test-Path $pngPath)) { throw "missing Tokarev face PNG: $pngPath" }
if (-not (Test-Path $anm2Path)) { throw "missing Tokarev face ANM2: $anm2Path" }

$allowedArgb = [System.Collections.Generic.HashSet[int]]::new()
@(
    [System.Drawing.Color]::FromArgb(255, 18, 18, 34).ToArgb(),
    [System.Drawing.Color]::FromArgb(255, 25, 28, 51).ToArgb(),
    [System.Drawing.Color]::FromArgb(255, 34, 39, 68).ToArgb(),
    [System.Drawing.Color]::FromArgb(255, 48, 205, 210).ToArgb(),
    [System.Drawing.Color]::FromArgb(255, 105, 238, 232).ToArgb()
) | ForEach-Object { [void]$allowedArgb.Add($_) }

$bitmap = [System.Drawing.Bitmap]::FromFile($pngPath)
try {
    if ($bitmap.Width -ne 256 -or $bitmap.Height -ne 32) {
        throw "Tokarev face must be 256x32, got $($bitmap.Width)x$($bitmap.Height)"
    }
    $visibleByCell = @(0, 0, 0, 0, 0, 0, 0, 0)
    $semiTransparent = 0
    $dirtyTransparent = 0
    $redDominant = 0
    $unexpectedPalette = 0
    $cyanPixels = 0

    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 256; $x++) {
            $pixel = $bitmap.GetPixel($x, $y)
            if ($pixel.A -ne 0 -and $pixel.A -ne 255) { $semiTransparent++ }
            if ($pixel.A -eq 0) {
                if ($pixel.R -ne 0 -or $pixel.G -ne 0 -or $pixel.B -ne 0) {
                    $dirtyTransparent++
                }
                continue
            }
            $cell = [math]::Floor($x / 32)
            $visibleByCell[$cell]++
            if (-not $allowedArgb.Contains($pixel.ToArgb())) { $unexpectedPalette++ }
            if ($pixel.R -gt ($pixel.G + 20) -and $pixel.R -gt ($pixel.B + 20)) {
                $redDominant++
            }
            if ($pixel.G -ge 180 -and $pixel.B -ge 180) { $cyanPixels++ }
        }
    }

    if ($semiTransparent -ne 0) { throw "semi-transparent pixels: $semiTransparent" }
    if ($dirtyTransparent -ne 0) { throw "dirty transparent RGB: $dirtyTransparent" }
    if ($redDominant -ne 0) { throw "red-dominant pixels: $redDominant" }
    if ($unexpectedPalette -ne 0) { throw "pixels outside approved palette: $unexpectedPalette" }
    if ($cyanPixels -lt 40) { throw "too few cyan identity pixels: $cyanPixels" }
    foreach ($cell in @(0, 1, 2, 3, 6, 7)) {
        if ($visibleByCell[$cell] -lt 180) {
            throw "face cell $cell is too sparse: $($visibleByCell[$cell])"
        }
    }
    if ($visibleByCell[4] -ne 0 -or $visibleByCell[5] -ne 0) {
        throw 'HeadUp cells must be blank'
    }

    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            if ($bitmap.GetPixel($x, $y).ToArgb() -ne $bitmap.GetPixel($x + 32, $y).ToArgb()) {
                throw "paired HeadDown cells differ at $x,$y"
            }
            if ($bitmap.GetPixel($x + 64, $y).ToArgb() -ne $bitmap.GetPixel($x + 96, $y).ToArgb()) {
                throw "paired HeadRight cells differ at $x,$y"
            }
            if ($bitmap.GetPixel($x + 192, $y).ToArgb() -ne $bitmap.GetPixel($x + 224, $y).ToArgb()) {
                throw "paired HeadLeft cells differ at $x,$y"
            }
            if ($bitmap.GetPixel($x + 64, $y).ToArgb() -ne $bitmap.GetPixel(255 - $x, $y).ToArgb()) {
                throw "HeadRight and HeadLeft are not mirrored at $x,$y"
            }
        }
    }
}
finally {
    $bitmap.Dispose()
}

$anm2 = Get-Content -Raw $anm2Path
if (-not $anm2.Contains('Layer Name="head2"')) { throw 'Tokarev face must use head2' }
if (-not $anm2.Contains('Path="costumes\costume_tokarev_face.png"')) {
    throw 'Tokarev face PNG path missing from ANM2'
}
foreach ($name in @('HeadDown', 'HeadRight', 'HeadUp', 'HeadLeft')) {
    if (-not $anm2.Contains('Animation Name="' + $name + '"')) {
        throw "missing animation $name"
    }
}

Write-Output 'Tokarev face visual contract passed'
