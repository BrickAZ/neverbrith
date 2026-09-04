param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$gameRoot = Split-Path -Parent (Split-Path -Parent $Root)
$costumesXmlPath = Join-Path $Root 'content\costumes2.xml'
$anm2Path = Join-Path $Root 'resources\gfx\characters\costume_dante_hair.anm2'
$hairPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_dante_hair.png'
$basePath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
$officialPath = Join-Path $gameRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
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

Assert-True (Test-Path -LiteralPath $costumesXmlPath) "missing costumes2.xml: $costumesXmlPath"
[xml]$costumesXml = Get-Content -Raw -LiteralPath $costumesXmlPath
$entries = @($costumesXml.costumes.costume | Where-Object { $_.anm2path -eq 'costume_dante_hair.anm2' })
Assert-True ($entries.Count -eq 1) "costumes2.xml must register costume_dante_hair.anm2 exactly once, got $($entries.Count)"
Assert-True ($entries[0].type -eq 'none') 'Dante hair must be a type=none Null Costume'
Assert-True ($entries[0].priority -eq '98') 'Dante hair must use the project head-hair priority 98'
$allIds = @($costumesXml.costumes.costume | ForEach-Object { [int]$_.id })
Assert-True (($allIds | Sort-Object -Unique).Count -eq $allIds.Count) 'costumes2.xml costume ids must remain unique'

Assert-True (Test-Path -LiteralPath $anm2Path) "missing Dante hair ANM2: $anm2Path"
[xml]$anm2 = Get-Content -Raw -LiteralPath $anm2Path
$sheets = @($anm2.AnimatedActor.Content.Spritesheets.Spritesheet)
Assert-True ($sheets.Count -eq 1) "Dante hair ANM2 must use one spritesheet, got $($sheets.Count)"
Assert-True ($sheets[0].Path -eq 'costumes\costume_dante_hair.png') "unexpected Dante hair spritesheet path: $($sheets[0].Path)"
Assert-True ($anm2.AnimatedActor.Animations.DefaultAnimation -eq 'HeadDown') 'Dante hair default animation must be HeadDown'

$expectedAnimations = @('HeadDown','HeadRight','HeadUp','HeadLeft')
$animations = @($anm2.AnimatedActor.Animations.Animation)
Assert-True ($animations.Count -eq 4) "Dante hair ANM2 must expose exactly four directional animations, got $($animations.Count)"
$actualNames = @($animations | ForEach-Object { $_.Name })
Assert-True ((Compare-Object $expectedAnimations $actualNames).Count -eq 0) `
    "Dante hair animation names differ: $($actualNames -join ', ')"

$expectedCrops = @(0,64,128,192,256,320,384,448)
$actualCrops = [Collections.Generic.List[int]]::new()
foreach ($animation in $animations) {
    $frames = @($animation.LayerAnimations.LayerAnimation.Frame)
    Assert-True ($frames.Count -eq 2) "$($animation.Name) must contain exactly two hair frames"
    foreach ($frame in $frames) {
        Assert-True ($frame.Width -eq '64' -and $frame.Height -eq '64') "$($animation.Name) must use 64x64 crops"
        Assert-True ($frame.YCrop -eq '0') "$($animation.Name) must stay on the only spritesheet row"
        Assert-True ($frame.XPivot -eq '32' -and $frame.YPivot -eq '44') "$($animation.Name) pivot must be 32,44"
        Assert-True ($frame.XPosition -eq '0' -and $frame.YPosition -eq '-5') "$($animation.Name) position must be 0,-5"
        $actualCrops.Add([int]$frame.XCrop)
    }
}
Assert-True ((Compare-Object $expectedCrops @($actualCrops)).Count -eq 0) `
    "Dante hair crops must be 0..448 in 64px steps, got $($actualCrops -join ', ')"

$hair = Open-BitmapCopy -Path $hairPath
try {
    Assert-True ($hair.Width -eq 512 -and $hair.Height -eq 64) `
        "Dante hair sheet is $($hair.Width)x$($hair.Height), expected 512x64"
    Assert-True ($hair.PixelFormat.ToString().Contains('Argb')) 'Dante hair sheet must retain an RGBA pixel format'

    $signatures = [Collections.Generic.List[string]]::new()
    foreach ($frameIndex in 0..7) {
        $originX = $frameIndex * 64
        $alphaCount = 0
        $minX = 64; $minY = 64; $maxX = -1; $maxY = -1
        $colors = [Collections.Generic.HashSet[int]]::new()
        $signature = [Text.StringBuilder]::new()
        $broadFaceWindowTransparent = 0
        $broadFaceWindowPixels = 0
        for ($y = 0; $y -lt 64; $y++) {
            for ($x = 0; $x -lt 64; $x++) {
                $pixel = $hair.GetPixel($originX + $x, $y)
                Assert-True ($pixel.A -eq 0 -or $pixel.A -eq 255) "Dante hair frame $frameIndex contains non-binary alpha at $x,$y"
                if ($x -ge 24 -and $x -le 40 -and $y -ge 25 -and $y -le 43) {
                    $broadFaceWindowPixels++
                    if ($pixel.A -eq 0) { $broadFaceWindowTransparent++ }
                }
                if ($pixel.A -eq 0) { continue }
                $alphaCount++
                $minX = [Math]::Min($minX, $x); $maxX = [Math]::Max($maxX, $x)
                $minY = [Math]::Min($minY, $y); $maxY = [Math]::Max($maxY, $y)
                [void]$colors.Add($pixel.ToArgb())
                [void]$signature.AppendFormat('{0:D2},{1:D2},{2:X8};', $x, $y, $pixel.ToArgb())
            }
        }
        $backView = $frameIndex -in @(4,5)
        Assert-True ($alphaCount -ge 200) `
            "Dante hair frame $frameIndex visible area $alphaCount indicates a blank or nearly blank crop"
        $alphaDensityWarning = if ($backView) { 1200 } else { 1000 }
        if ($alphaCount -gt $alphaDensityWarning) {
            Write-Warning "Dante hair frame $frameIndex visible area $alphaCount is unusually dense; native-1x review is required"
        }
        $width = $maxX - $minX + 1; $height = $maxY - $minY + 1
        Assert-True ($width -ge 28 -and $width -le 44 -and $height -ge 25 -and $height -le 48) `
            "Dante hair frame $frameIndex visible bounds are ${width}x${height}; expected a controlled Isaac-scale hair overlay"
        $fillRatio = $alphaCount / [double]($width * $height)
        Assert-True ($fillRatio -ge 0.20 -and $fillRatio -le 0.95) `
            "Dante hair frame $frameIndex fill ratio $([Math]::Round($fillRatio,3)) indicates a blank crop or full backing plate"
        $densityWarning = if ($backView) { 0.84 } else { 0.75 }
        if ($fillRatio -gt $densityWarning) {
            Write-Warning "Dante hair frame $frameIndex fill ratio $([Math]::Round($fillRatio,3)) is unusually dense; native-1x review is required"
        }
        Assert-True ($colors.Count -ge 6) `
            "Dante hair frame $frameIndex uses only $($colors.Count) visible colors; strand groups are not separated"
        $broadFaceWindowTransparency = $broadFaceWindowTransparent / [double]$broadFaceWindowPixels
        if ($backView) {
            if ($broadFaceWindowTransparency -gt 0.35) {
                Write-Warning "Dante back hair broad face window may expose scalp: transparency=$([Math]::Round($broadFaceWindowTransparency,3))"
            }
        } else {
            if ($broadFaceWindowTransparency -lt 0.62) {
                Write-Warning "Dante hair frame $frameIndex has a dense broad face window: transparency=$([Math]::Round($broadFaceWindowTransparency,3)); use the exact face-protection test for eye/tear/mouth safety"
            }
        }
        $signatures.Add($signature.ToString())
    }
    Assert-True (($signatures | Sort-Object -Unique).Count -eq 8) 'all eight Dante hair frames must be intentionally authored and distinct'
    Assert-True ($signatures[2] -ne $signatures[6] -and $signatures[3] -ne $signatures[7]) `
        'Dante left and right hair directions must not reuse the same pixels'
}
finally { $hair.Dispose() }

$official = Open-BitmapCopy -Path $officialPath
$base = Open-BitmapCopy -Path $basePath
try {
    $differences = 0
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 192; $x++) {
            if ($official.GetPixel($x,$y).ToArgb() -ne $base.GetPixel($x,$y).ToArgb()) { $differences++ }
        }
    }
    Assert-True ($differences -eq 0) `
        "Dante base atlas still bakes hair into the six normal head cells: $differences differing pixels"
}
finally { $official.Dispose(); $base.Dispose() }

Write-Output 'Dante separated hair costume, negative-space and clean-base-head contract passed'

