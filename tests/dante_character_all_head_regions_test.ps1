param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$atlasPath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
Add-Type -AssemblyName System.Drawing

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Test-IsExactDanteHair {
    param([Drawing.Color]$Pixel)
    return $Pixel.A -gt 0 -and (
        ($Pixel.R -eq 0x77 -and $Pixel.G -eq 0x7D -and $Pixel.B -eq 0x8B) -or
        ($Pixel.R -eq 0xAE -and $Pixel.G -eq 0xB4 -and $Pixel.B -eq 0xC1) -or
        ($Pixel.R -eq 0xD8 -and $Pixel.G -eq 0xDC -and $Pixel.B -eq 0xE4)
    )
}

function Test-IsFaceSkin {
    param([Drawing.Color]$Pixel)
    return $Pixel.A -gt 0 -and $Pixel.R -ge 150 -and $Pixel.G -ge 100 -and $Pixel.B -ge 90 -and
        $Pixel.R -ge ($Pixel.G + 15) -and $Pixel.R -le ($Pixel.G + 100)
}

$regions = @(@{ Name = 'pickup-head'; X = 256; Y = 128; W = 64; H = 64; Hair = 60; Skin = 30 })
$glitchIndex = 0
foreach ($origin in @(@(16,336),@(48,336),@(80,336),@(16,368),@(48,368),@(80,368),@(16,400))) {
    $regions += @{ Name = "glitch-$glitchIndex"; X = $origin[0]; Y = $origin[1]; W = 32; H = 32; Hair = 8; Skin = 0 }
    $glitchIndex++
}
$specialIndex = 0
foreach ($origin in @(
    @(0,128),@(64,128),@(128,128),@(192,130),
    @(0,192),@(64,192),@(128,192),@(192,192),
    @(0,256),@(64,256),@(128,256),@(192,256)
)) {
    $regions += @{ Name = "special-$specialIndex"; X = $origin[0]; Y = $origin[1]; W = 64; H = 64; Hair = 40; Skin = 18 }
    $specialIndex++
}
Assert-True ($regions.Count -eq 20) "expected pickup, seven glitch and twelve special head-bearing regions, got $($regions.Count)"

$atlas = [Drawing.Bitmap]::new($atlasPath)
try {
    foreach ($region in $regions) {
        $hair = 0
        $skin = 0
        for ($y = $region.Y; $y -lt ($region.Y + $region.H); $y++) {
            for ($x = $region.X; $x -lt ($region.X + $region.W); $x++) {
                $pixel = $atlas.GetPixel($x, $y)
                if (Test-IsExactDanteHair -Pixel $pixel) { $hair++ }
                if (Test-IsFaceSkin -Pixel $pixel) { $skin++ }
            }
        }
        Assert-True ($hair -ge $region.Hair) `
            "Dante $($region.Name) has no readable DMC5 silver-hair treatment: hair=$hair expected>=$($region.Hair)"
        Assert-True ($skin -ge $region.Skin) `
            "Dante $($region.Name) hair treatment erased the readable face: skin=$skin expected>=$($region.Skin)"
    }
}
finally { $atlas.Dispose() }

Write-Output 'Dante pickup, glitch and special-state head identity coverage contract passed'
