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

$pairs = @(
    @{ Name = 'down-a'; HeadX = 0; BodyX = 0; BodyY = 32 },
    @{ Name = 'down-b'; HeadX = 32; BodyX = 32; BodyY = 32 },
    @{ Name = 'side-a'; HeadX = 64; BodyX = 0; BodyY = 64 },
    @{ Name = 'side-b'; HeadX = 96; BodyX = 32; BodyY = 64 },
    @{ Name = 'up-a'; HeadX = 128; BodyX = 0; BodyY = 32 },
    @{ Name = 'up-b'; HeadX = 160; BodyX = 32; BodyY = 32 }
)

$atlas = [Drawing.Bitmap]::new($atlasPath)
try {
    foreach ($pair in $pairs) {
        $brightCoat = 0
        $darkInner = 0
        for ($bodyY = 0; $bodyY -lt 32; $bodyY++) {
            for ($bodyX = 0; $bodyX -lt 32; $bodyX++) {
                $body = $atlas.GetPixel($pair.BodyX + $bodyX, $pair.BodyY + $bodyY)
                if ($body.A -eq 0) { continue }
                $headY = $bodyY + 10
                if ($headY -lt 32 -and $atlas.GetPixel($pair.HeadX + $bodyX, $headY).A -gt 0) { continue }
                $maximum = [Math]::Max($body.R, [Math]::Max($body.G, $body.B))
                if ($body.R -ge 135 -and $body.R -ge ($body.G + 30) -and $body.R -ge ($body.B + 15)) { $brightCoat++ }
                if ($maximum -le 78) { $darkInner++ }
            }
        }
        Assert-True ($brightCoat -ge 30) `
            "Dante native composite $($pair.Name) loses the burgundy coat behind the head: visible bright-coat pixels=$brightCoat"
        Assert-True ($darkInner -ge 40) `
            "Dante native composite $($pair.Name) loses the black inner-clothing separation: visible dark pixels=$darkInner"
    }
}
finally { $atlas.Dispose() }

Write-Output 'Dante native composite coat/inner readability contract passed'
