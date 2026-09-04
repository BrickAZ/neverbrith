param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$gameRoot = Split-Path -Parent (Split-Path -Parent $Root)
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

$extraRegions = @(@{ X = 448; Y = 0; W = 32; H = 32; Kind = 'pickup-overlay' },
    @{ X = 480; Y = 0; W = 32; H = 32; Kind = 'pickup-overlay' })
foreach ($y in @(32, 64)) {
    foreach ($x in @(256, 288, 320, 352, 384, 416, 448, 480)) {
        $extraRegions += @{ X = $x; Y = $y; W = 32; H = 32; Kind = 'pickup-overlay' }
    }
}
$extraRegions += @{ X = 256; Y = 96; W = 32; H = 32; Kind = 'pickup-overlay' }
$extraRegions += @{ X = 288; Y = 96; W = 32; H = 32; Kind = 'pickup-overlay' }
foreach ($origin in @(
    @(0, 128), @(64, 128), @(128, 128), @(192, 130),
    @(0, 192), @(64, 192), @(128, 192), @(192, 192),
    @(0, 256), @(64, 256), @(128, 256), @(192, 256)
)) {
    $extraRegions += @{ X = $origin[0]; Y = $origin[1]; W = 64; H = 64; Kind = 'special-action' }
}
Assert-True ($extraRegions.Count -eq 32) "expected 32 collapsed extra/special regions, got $($extraRegions.Count)"

$official = Open-BitmapCopy -Path $officialAtlasPath
$dante = Open-BitmapCopy -Path $danteAtlasPath
try {
    foreach ($region in $extraRegions) {
        $alphaDifferences = 0
        $silver = 0
        $red = 0
        $dark = 0
        for ($y = $region.Y; $y -lt ($region.Y + $region.H); $y++) {
            for ($x = $region.X; $x -lt ($region.X + $region.W); $x++) {
                $source = $official.GetPixel($x, $y)
                $target = $dante.GetPixel($x, $y)
                if ($source.A -ne $target.A) { $alphaDifferences++ }
                if ($target.A -eq 0) { continue }
                $maximum = [Math]::Max($target.R, [Math]::Max($target.G, $target.B))
                $minimum = [Math]::Min($target.R, [Math]::Min($target.G, $target.B))
                if ($target.R -ge 145 -and $target.G -ge 145 -and $target.B -ge 150 -and ($maximum - $minimum) -le 55) { $silver++ }
                if ($target.R -ge 75 -and $target.R -ge ($target.G + 20) -and $target.R -ge ($target.B + 8)) { $red++ }
                if ($maximum -le 78) { $dark++ }
            }
        }
        $label = "$($region.Kind) $($region.X),$($region.Y),$($region.W),$($region.H)"
        $maximumAlphaDifferences = if ($region.Kind -eq 'special-action') { 640 } else { 128 }
        Assert-True ($alphaDifferences -ge 8 -and $alphaDifferences -le $maximumAlphaDifferences) `
            "Dante $label lacks a controlled hair/coat silhouette: alpha differences=$alphaDifferences allowed=8..$maximumAlphaDifferences"
        if ($region.Kind -eq 'special-action') {
            Assert-True ($silver -ge 40 -and $red -ge 80 -and $dark -ge 160) `
                "Dante $label lacks full-state silver/red/dark identity coverage: silver=$silver red=$red dark=$dark"
        }
        else {
            Assert-True (($red -ge 50 -and $dark -ge 80) -or ($silver -ge 80 -and $red -ge 80 -and $dark -ge 60)) `
                "Dante $label lacks pickup-state coat/inner or hair/coat identity coverage: silver=$silver red=$red dark=$dark"
        }
    }
}
finally {
    $official.Dispose()
    $dante.Dispose()
}

Write-Output 'Dante 32-region extra and special-action coverage contract passed'
