param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$gameRoot = Split-Path -Parent (Split-Path -Parent $Root)
$basePath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
$officialPath = Join-Path $gameRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
$hairContract = Join-Path $Root 'tests\dante_character_hair_costume_contract_test.ps1'
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

Assert-True (Test-Path -LiteralPath $hairContract) "missing separated-hair contract: $hairContract"
& $hairContract -Root $Root | Out-Null

$official = Open-BitmapCopy -Path $officialPath
$base = Open-BitmapCopy -Path $basePath
try {
    Assert-True ($base.Width -eq 512 -and $base.Height -eq 512) 'Dante base player atlas must remain 512x512'
    $normalHeadDifferences = 0
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 192; $x++) {
            if ($official.GetPixel($x,$y).ToArgb() -ne $base.GetPixel($x,$y).ToArgb()) {
                $normalHeadDifferences++
            }
        }
    }
    Assert-True ($normalHeadDifferences -eq 0) `
        "normal Dante base-head crops must stay clean beneath the hair costume: differences=$normalHeadDifferences"
}
finally { $official.Dispose(); $base.Dispose() }

$generator = Get-Content -Raw -LiteralPath (Join-Path $Root 'tools\rebuild-dante-full-base-atlas.ps1')
Assert-True ($generator.Contains('Normal movement hair now belongs to costume_dante_hair.anm2')) `
    'the base-atlas generator must document separated normal-hair ownership'
foreach ($forbiddenCall in @(
    'Rebuild-NormalHead -Official $official -Output $output -CellX 0',
    'Rebuild-NormalHead -Official $official -Output $output -CellX 32',
    'Rebuild-NormalHead -Official $official -Output $output -CellX 64',
    'Rebuild-NormalHead -Official $official -Output $output -CellX 96',
    'Rebuild-NormalHead -Official $official -Output $output -CellX 128',
    'Rebuild-NormalHead -Official $official -Output $output -CellX 160'
)) {
    Assert-True (-not $generator.Contains($forbiddenCall)) `
        "base-atlas generator must not reintroduce baked normal hair: $forbiddenCall"
}

Write-Output 'Dante full-atlas base plus separated-hair native visual regression contract passed'

