param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$basePath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
$hairPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_dante_hair.png'
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

function Test-IsProtectedFacePixel {
    param([Drawing.Color]$Pixel, [int]$X, [int]$Y)
    if ($Pixel.A -eq 0) { return $false }
    $darkFeature = $X -ge 6 -and $X -le 25 -and $Y -ge 11 -and $Y -le 20 -and
        (($Pixel.R + $Pixel.G + $Pixel.B) -le 210)
    $tearFeature = $X -ge 5 -and $X -le 26 -and $Y -ge 15 -and $Y -le 27 -and
        ($Pixel.G -ge ($Pixel.R + 20)) -and ($Pixel.B -ge ($Pixel.R + 20))
    return $darkFeature -or $tearFeature
}

$frames = @(
    [pscustomobject]@{ Name='Down A';  HairIndex=0; HeadX=0;  Mirror=$false },
    [pscustomobject]@{ Name='Down B';  HairIndex=1; HeadX=32; Mirror=$false },
    [pscustomobject]@{ Name='Right A'; HairIndex=2; HeadX=64; Mirror=$false },
    [pscustomobject]@{ Name='Right B'; HairIndex=3; HeadX=96; Mirror=$false },
    [pscustomobject]@{ Name='Left A';  HairIndex=6; HeadX=64; Mirror=$true  },
    [pscustomobject]@{ Name='Left B';  HairIndex=7; HeadX=96; Mirror=$true  }
)

$base = Open-BitmapCopy -Path $basePath
$hair = Open-BitmapCopy -Path $hairPath
try {
    Assert-True ($base.Width -eq 512 -and $base.Height -eq 512) `
        "Dante base atlas is $($base.Width)x$($base.Height), expected 512x512"
    Assert-True ($hair.Width -eq 512 -and $hair.Height -eq 64) `
        "Dante hair sheet is $($hair.Width)x$($hair.Height), expected 512x64"

    $violations = [Collections.Generic.List[string]]::new()
    foreach ($frame in $frames) {
        for ($y = 0; $y -lt 32; $y++) {
            for ($x = 0; $x -lt 32; $x++) {
                $sourceX = if ($frame.Mirror) { 31 - $x } else { $x }
                $basePixel = $base.GetPixel($frame.HeadX + $sourceX, $y)
                if (-not (Test-IsProtectedFacePixel -Pixel $basePixel -X $x -Y $y)) { continue }

                $hairX = $frame.HairIndex * 64 + $x + 16
                $hairY = $y + 16
                if ($hair.GetPixel($hairX, $hairY).A -gt 0) {
                    $violations.Add("$($frame.Name): head=$x,$y hair=$($x+16),$($y+16)")
                }
            }
        }
    }

    Assert-True ($violations.Count -eq 0) (
        "Dante hair overlaps protected eye/tear/mouth pixels:`n" + ($violations -join "`n")
    )
}
finally {
    $hair.Dispose()
    $base.Dispose()
}

Write-Output 'Dante hair face-protection contract passed: protected overlap=0 for six visible-face frames'
