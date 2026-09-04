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

$normalBodyCells = @(@{ X = 192; Y = 0 }, @{ X = 224; Y = 0 })
foreach ($y in @(32, 64)) {
    foreach ($x in @(0, 32, 64, 96, 128, 160, 192, 224)) {
        $normalBodyCells += @{ X = $x; Y = $y }
    }
}
$normalBodyCells += @{ X = 0; Y = 96 }, @{ X = 32; Y = 96 }
Assert-True ($normalBodyCells.Count -eq 20) "expected the official 20 normal-body regions, got $($normalBodyCells.Count)"

$official = Open-BitmapCopy -Path $officialAtlasPath
$dante = Open-BitmapCopy -Path $danteAtlasPath
try {
    foreach ($cell in $normalBodyCells) {
        $alphaDifferences = 0
        $revealedCoatDifferences = 0
        $red = 0
        $dark = 0
        $officialBottom = -1
        $danteBottom = -1
        for ($localY = 0; $localY -lt 32; $localY++) {
            for ($localX = 0; $localX -lt 32; $localX++) {
                $source = $official.GetPixel($cell.X + $localX, $cell.Y + $localY)
                $target = $dante.GetPixel($cell.X + $localX, $cell.Y + $localY)
                if ($source.A -ne $target.A) {
                    $alphaDifferences++
                    if ($localY -ge 22) { $revealedCoatDifferences++ }
                }
                if ($source.A -gt 0) { $officialBottom = [Math]::Max($officialBottom, $localY) }
                if ($target.A -gt 0) { $danteBottom = [Math]::Max($danteBottom, $localY) }
                if ($target.A -eq 0) { continue }
                $maximum = [Math]::Max($target.R, [Math]::Max($target.G, $target.B))
                if ($target.R -ge 75 -and $target.R -ge ($target.G + 20) -and $target.R -ge ($target.B + 8)) { $red++ }
                if ($maximum -le 78) { $dark++ }
            }
        }
        $label = "$($cell.X),$($cell.Y)"
        Assert-True ($alphaDifferences -ge 12 -and $alphaDifferences -le 48) `
            "Dante normal body $label must have a readable crop-local coat silhouette, got $alphaDifferences alpha differences"
        Assert-True ($revealedCoatDifferences -ge 6) `
            "Dante normal body $label coat changes are hidden behind the head; reveal-band differences=$revealedCoatDifferences"
        Assert-True ($danteBottom -eq $officialBottom) `
            "Dante normal body $label changed foot contact: official=$officialBottom Dante=$danteBottom"
        Assert-True ($red -ge 30 -and $dark -ge 40) `
            "Dante normal body $label lacks the burgundy-coat/black-inner color split: red=$red dark=$dark"
    }
}
finally {
    $official.Dispose()
    $dante.Dispose()
}

Write-Output 'Dante 20-region normal-body coat coverage contract passed'
