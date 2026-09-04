param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'

function Assert-True {
    param([bool]$Condition, [string]$Message)
    if (-not $Condition) { throw $Message }
}

function Get-Animation {
    param([xml]$Document, [string]$Name)
    $animation = @($Document.AnimatedActor.Animations.Animation) |
        Where-Object { $_.Name -eq $Name } |
        Select-Object -First 1
    Assert-True ($null -ne $animation) "missing animation: $Name"
    return $animation
}

$headgearPath = Join-Path $Root 'resources\gfx\characters\costume_ringotsuga_headgear.anm2'
$removedShirtPath = Join-Path $Root 'resources\gfx\characters\costume_ringotsuga_white_tshirt.anm2'
Assert-True (Test-Path -LiteralPath $headgearPath) 'missing Ringo headgear ANM2'
Assert-True (-not (Test-Path -LiteralPath $removedShirtPath)) 'Ringo white T-shirt ANM2 must be removed'

[xml]$headgear = Get-Content -Raw -LiteralPath $headgearPath
$sheets = @($headgear.AnimatedActor.Content.Spritesheets.Spritesheet)
Assert-True ($sheets.Count -eq 1) 'headgear must use one spritesheet'
$sheetPath = [string]$sheets[0].Path -replace '\\', '/'
Assert-True ($sheetPath -eq 'costumes/costume_ringotsuga_headgear.png') "headgear spritesheet path: $sheetPath"
$layers = @($headgear.AnimatedActor.Content.Layers.Layer)
Assert-True ($layers.Count -eq 1 -and [string]$layers[0].Name -eq 'head4') 'headgear must use head4'
foreach ($animationName in @('HeadDown', 'HeadRight', 'HeadUp', 'HeadLeft')) {
    $frames = @((Get-Animation -Document $headgear -Name $animationName).LayerAnimations.LayerAnimation.Frame)
    Assert-True ($frames.Count -eq 2) "$animationName must have two headgear frames"
    foreach ($frame in $frames) {
        Assert-True ([int]$frame.Width -eq 32 -and [int]$frame.Height -eq 64) "$animationName headgear crop"
        Assert-True ([int]$frame.XPivot -eq 16 -and [int]$frame.YPivot -eq 44) "$animationName headgear pivot"
        Assert-True ([int]$frame.YPosition -eq -5) "$animationName headgear position"
        Assert-True ([int]$frame.Delay -eq 2) "$animationName headgear delay"
    }
}

[xml]$costumes = Get-Content -Raw -LiteralPath (Join-Path $Root 'content\costumes2.xml')
$ringoHeadgear = @($costumes.costumes.costume) |
    Where-Object { [string]$_.id -eq '17498' } |
    Select-Object -First 1
Assert-True ($null -ne $ringoHeadgear) 'missing Ringo headgear costume id 17498'
Assert-True ([string]$ringoHeadgear.anm2path -eq 'costume_ringotsuga_headgear.anm2') 'Ringo headgear costume path'
Assert-True ([string]$ringoHeadgear.type -eq 'none') 'Ringo headgear costume type'
Assert-True ([string]$ringoHeadgear.priority -eq '98') 'Ringo headgear costume priority'
foreach ($removedId in @('17499', '17500')) {
    $removed = @($costumes.costumes.costume) | Where-Object { [string]$_.id -eq $removedId }
    Assert-True ($removed.Count -eq 0) "removed Ringo costume id remains: $removedId"
}

$main = Get-Content -Raw -LiteralPath (Join-Path $Root 'main.lua')
$everchanging = [regex]::Match($main, '(?s)-- EVERCHANGING_BEGIN(.*?)-- EVERCHANGING_END').Groups[1].Value
Assert-True ($everchanging.Length -gt 0) 'missing Everchanging source block'
Assert-True ($everchanging.Contains('slots = { "head" }')) 'Ringo must use exactly the head slot'
Assert-True ($everchanging.Contains('head = { costume = "gfx/characters/costume_ringotsuga_headgear.anm2" }')) `
    'Ringo headgear resource'
foreach ($obsolete in @(
    'costume_ringotsuga_white_tshirt.anm2',
    'costume_ringotsuga_face.anm2',
    'costume_ringotsuga_apple_shell.anm2',
    'costume_ringotsuga_hoodie.anm2',
    'costume_ringotsuga_apple_storyteller.anm2',
    'slots = { "head", "body" }',
    'slots = { "head", "face", "body" }'
)) {
    Assert-True (-not $everchanging.Contains($obsolete)) "obsolete Ringo contract remains: $obsolete"
}

Write-Output 'Ringo headgear-only ANM2 and integration contract passed'
