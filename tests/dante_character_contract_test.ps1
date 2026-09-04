param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
Add-Type -AssemblyName System.Drawing

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Open-BitmapCopy {
    param([string]$Path)
    Assert-True (Test-Path -LiteralPath $Path) "missing Dante asset: $Path"
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) }
        finally { $source.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Get-AlphaStats {
    param([Drawing.Bitmap]$Bitmap)
    $visible = 0
    $semiTransparent = 0
    $dirtyTransparent = 0
    $minX = $Bitmap.Width
    $minY = $Bitmap.Height
    $maxX = -1
    $maxY = -1
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.A -eq 0) {
                if ($pixel.R -ne 0 -or $pixel.G -ne 0 -or $pixel.B -ne 0) { $dirtyTransparent++ }
                continue
            }
            $visible++
            if ($pixel.A -ne 255) { $semiTransparent++ }
            $minX = [Math]::Min($minX, $x)
            $minY = [Math]::Min($minY, $y)
            $maxX = [Math]::Max($maxX, $x)
            $maxY = [Math]::Max($maxY, $y)
        }
    }
    return @{
        Visible = $visible
        SemiTransparent = $semiTransparent
        DirtyTransparent = $dirtyTransparent
        MinX = $minX
        MinY = $minY
        MaxX = $maxX
        MaxY = $maxY
    }
}

function Get-IdentitySignalCounts {
    param([Drawing.Bitmap]$Bitmap, [int]$X, [int]$Y, [int]$Width, [int]$Height)
    $silver = 0
    $red = 0
    $dark = 0
    for ($py = $Y; $py -lt ($Y + $Height); $py++) {
        for ($px = $X; $px -lt ($X + $Width); $px++) {
            $pixel = $Bitmap.GetPixel($px, $py)
            if ($pixel.A -eq 0) { continue }
            $maximum = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
            $minimum = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
            if ($pixel.R -ge 145 -and $pixel.G -ge 145 -and $pixel.B -ge 150 -and ($maximum - $minimum) -le 55) { $silver++ }
            if ($pixel.R -ge 75 -and $pixel.R -ge ($pixel.G + 20) -and $pixel.R -ge ($pixel.B + 8)) { $red++ }
            if ($maximum -le 78) { $dark++ }
        }
    }
    return @{ Silver = $silver; Red = $red; Dark = $dark }
}

function Assert-PngSurface {
    param(
        [string]$Path,
        [int]$Width,
        [int]$Height,
        [int]$MinimumVisible,
        [int]$MaximumVisible,
        [bool]$RequireBinaryAlpha = $false
    )
    $bitmap = Open-BitmapCopy -Path $Path
    try {
        Assert-True ($bitmap.Width -eq $Width -and $bitmap.Height -eq $Height) `
            "$Path must be ${Width}x${Height}, got $($bitmap.Width)x$($bitmap.Height)"
        Assert-True (($bitmap.PixelFormat -band [Drawing.Imaging.PixelFormat]::Alpha) -ne 0) `
            "$Path must retain an alpha channel"
        $stats = Get-AlphaStats -Bitmap $bitmap
        Assert-True ($stats.Visible -ge $MinimumVisible -and $stats.Visible -le $MaximumVisible) `
            "$Path visible coverage out of range: $($stats.Visible)"
        Assert-True ($stats.DirtyTransparent -eq 0) "$Path has dirty RGB in transparent pixels: $($stats.DirtyTransparent)"
        if ($RequireBinaryAlpha) {
            Assert-True ($stats.SemiTransparent -eq 0) "$Path must use binary pixel-art alpha: $($stats.SemiTransparent) semi-transparent pixels"
        }
        return @{ Bitmap = $bitmap; Stats = $stats }
    }
    catch {
        $bitmap.Dispose()
        throw
    }
}

function Assert-VanillaPlayerNameStyle {
    param([Drawing.Bitmap]$Bitmap)

    $opaque = 0
    $halfAlpha = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x, $y)
            if ($pixel.A -eq 0) { continue }
            Assert-True ($pixel.R -eq 0xC7 -and $pixel.G -eq 0xB2 -and $pixel.B -eq 0x99) `
                ("Dante player-name visible RGB must be the vanilla #C7B299 only; " +
                 "found #{0:X2}{1:X2}{2:X2} at ({3},{4})" -f $pixel.R, $pixel.G, $pixel.B, $x, $y)
            Assert-True ($pixel.A -eq 128 -or $pixel.A -eq 255) `
                "Dante player-name alpha must be 128 or 255 at ($x,$y), got $($pixel.A)"
            if ($pixel.A -eq 128) { $halfAlpha++ }
            else { $opaque++ }
        }
    }
    Assert-True ($opaque -gt 0) 'Dante player-name must retain opaque letter interiors'
    Assert-True ($halfAlpha -gt 0) 'Dante player-name must use attached alpha-128 edge coverage'
}

$playersPath = Join-Path $Root 'content\players.xml'
Assert-True (Test-Path -LiteralPath $playersPath) "missing players.xml: $playersPath"
[xml]$playersXml = Get-Content -Raw -LiteralPath $playersPath
$dantePlayers = @($playersXml.players.player | Where-Object { $_.name -eq 'Dante' })
Assert-True ($dantePlayers.Count -eq 1) "players.xml must contain exactly one Dante registration, got $($dantePlayers.Count)"
$dante = $dantePlayers[0]
Assert-True (-not $dante.HasAttribute('id')) 'Dante must not hard-code a global PlayerType/local numeric id'
Assert-True ($dante.skin -eq 'character_dante.png') "Dante skin path: $($dante.skin)"
Assert-True ($dante.portrait -eq 'playerportrait_dante.png') "Dante portrait path: $($dante.portrait)"
Assert-True ($dante.nameimage -eq 'playername_dante.png') "Dante name image path: $($dante.nameimage)"
Assert-True ($dante.hp -eq '6' -and $dante.bombs -eq '1' -and $dante.skinColor -eq '-1') `
    'Dante must retain the official ordinary-Isaac hp=6, bombs=1, skinColor=-1 baseline'
foreach ($forbidden in @('items', 'trinket', 'card', 'pill', 'pocketActive', 'costume', 'achievement', 'hidden', 'bSkinParent')) {
    Assert-True (-not $dante.HasAttribute($forbidden)) "Dante must not declare unrequested '$forbidden'"
}

$characterRoot = Join-Path $Root ('resources\' + ($playersXml.players.root -replace '/', '\'))
$portraitRoot = Join-Path $Root ('resources\' + ($playersXml.players.portraitroot -replace '/', '\'))
$nameRoot = Join-Path $Root ('resources\' + ($playersXml.players.nameimageroot -replace '/', '\'))
$skinPath = Join-Path $characterRoot $dante.skin
$portraitPath = Join-Path $portraitRoot $dante.portrait
$namePath = Join-Path $nameRoot $dante.nameimage

$skinSurface = Assert-PngSurface -Path $skinPath -Width 512 -Height 512 -MinimumVisible 15000 -MaximumVisible 52000 -RequireBinaryAlpha $true
$skin = $skinSurface.Bitmap
try {
    foreach ($cell in @(
        @{ Name = 'body-down'; X = 0; Y = 32; W = 32; H = 32; Silver = 0; Red = 20 },
        @{ Name = 'body-side'; X = 0; Y = 64; W = 32; H = 32; Silver = 0; Red = 20 }
    )) {
        $signals = Get-IdentitySignalCounts -Bitmap $skin -X $cell.X -Y $cell.Y -Width $cell.W -Height $cell.H
        Assert-True ($signals.Red -ge $cell.Red) "Dante $($cell.Name) lacks a readable deep-red coat/body signal: $($signals.Red)"
        Assert-True ($signals.Dark -ge 20) "Dante $($cell.Name) lacks a readable dark-clothing/outline signal: $($signals.Dark)"
    }
}
finally { $skin.Dispose() }
& (Join-Path $PSScriptRoot 'dante_character_hair_costume_contract_test.ps1') -Root $Root | Out-Null


$portraitSurface = Assert-PngSurface -Path $portraitPath -Width 144 -Height 144 -MinimumVisible 2600 -MaximumVisible 10000
try {
    $signals = Get-IdentitySignalCounts -Bitmap $portraitSurface.Bitmap -X 0 -Y 0 -Width 144 -Height 144
    Assert-True ($signals.Silver -ge 100 -and $signals.Red -ge 180 -and $signals.Dark -ge 180) `
        "Dante stage portrait identity signals are too weak: silver=$($signals.Silver), red=$($signals.Red), dark=$($signals.Dark)"
}
finally { $portraitSurface.Bitmap.Dispose() }

$nameSurface = Assert-PngSurface -Path $namePath -Width 192 -Height 64 -MinimumVisible 500 -MaximumVisible 3600
$nameSurface.Bitmap.Dispose()
$nameStyleBitmap = [Drawing.Bitmap]::new($namePath)
try {
    Assert-VanillaPlayerNameStyle -Bitmap $nameStyleBitmap
}
finally { $nameStyleBitmap.Dispose() }

$menuAnm2Path = Join-Path $Root 'content\gfx\CharacterMenu.anm2'
Assert-True (Test-Path -LiteralPath $menuAnm2Path) "missing CharacterMenu.anm2: $menuAnm2Path"
[xml]$menuXml = Get-Content -Raw -LiteralPath $menuAnm2Path
$danteAnimations = @($menuXml.AnimatedActor.Animations.Animation | Where-Object { $_.Name -eq 'Dante' })
Assert-True ($danteAnimations.Count -eq 1) "CharacterMenu.anm2 must contain exactly one Dante animation, got $($danteAnimations.Count)"
Assert-True ($danteAnimations[0].FrameNum -eq '1') 'Dante CharacterMenu animation must be a stable one-frame native menu card'

$menuSheets = @($menuXml.AnimatedActor.Content.Spritesheets.Spritesheet)
$menuNameSheet = @($menuSheets | Where-Object { $_.Path -eq 'dante_character_menu_name.png' })
$menuPortraitSheet = @($menuSheets | Where-Object { $_.Path -eq 'dante_character_menu_portrait.png' })
Assert-True ($menuNameSheet.Count -eq 1) 'CharacterMenu.anm2 must reference Dante menu-name art exactly once'
Assert-True ($menuPortraitSheet.Count -eq 1) 'CharacterMenu.anm2 must reference Dante menu portrait art exactly once'
foreach ($sheet in @($menuNameSheet[0], $menuPortraitSheet[0])) {
    Assert-True (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $menuAnm2Path) $sheet.Path)) `
        "CharacterMenu spritesheet does not exist: $($sheet.Path)"
}

$menuNamePath = Join-Path $Root 'content\gfx\dante_character_menu_name.png'
$menuPortraitPath = Join-Path $Root 'content\gfx\dante_character_menu_portrait.png'
$menuNameSurface = Assert-PngSurface -Path $menuNamePath -Width 80 -Height 32 -MinimumVisible 250 -MaximumVisible 1600
$menuNameSurface.Bitmap.Dispose()
$menuPortraitSurface = Assert-PngSurface -Path $menuPortraitPath -Width 96 -Height 96 -MinimumVisible 1200 -MaximumVisible 7000
try {
    $signals = Get-IdentitySignalCounts -Bitmap $menuPortraitSurface.Bitmap -X 0 -Y 0 -Width 96 -Height 96
    Assert-True ($signals.Silver -ge 80 -and $signals.Red -ge 120 -and $signals.Dark -ge 120) `
        "Dante CharacterMenu portrait identity signals are too weak: silver=$($signals.Silver), red=$($signals.Red), dark=$($signals.Dark)"
}
finally { $menuPortraitSurface.Bitmap.Dispose() }

$ledgerPath = Join-Path $Root 'docs\skill-tests\dante-character-source-ledger.md'
Assert-True (Test-Path -LiteralPath $ledgerPath) "missing Dante source ledger: $ledgerPath"
$ledger = Get-Content -Raw -LiteralPath $ledgerPath
foreach ($required in @('附件直接可见', 'CAPCOM 官方', 'Isaac 化保守补全', '未采用')) {
    Assert-True ($ledger.Contains($required)) "Dante source ledger missing section/label: $required"
}
Assert-True ($ledger.Contains('绝对禁止参考')) 'Dante source ledger must retain the prohibited-version boundary'

Write-Output 'Dante character registration and visual-surface contract passed'
