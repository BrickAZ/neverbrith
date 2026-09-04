param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$Output = "resources/gfx/characters/costumes/costume_ringotsuga_apple_storyteller_native_candidate.png"
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing

function Convert-HexColor([string]$Hex) {
    return [System.Drawing.ColorTranslator]::FromHtml($Hex)
}

function Get-RgbHex([System.Drawing.Color]$Color) {
    return "#{0:X2}{1:X2}{2:X2}" -f $Color.R, $Color.G, $Color.B
}

$basePath = Join-Path $Root "resources/gfx/characters/costumes/_backups/ringotsuga-20260721-before-original-silhouette.png"
$currentPath = Join-Path $Root "resources/gfx/characters/costumes/costume_ringotsuga_apple_storyteller.png"
$anm2Path = Join-Path $Root "resources/gfx/characters/costume_ringotsuga_apple_storyteller.anm2"
$outputPath = Join-Path $Root $Output

$palette = @{
    outline = Convert-HexColor "#130D12"
    redDeep = Convert-HexColor "#79242B"
    redShadow = Convert-HexColor "#A43036"
    redBase = Convert-HexColor "#D34342"
    redHigh = Convert-HexColor "#F15F52"
    hoodDeep = Convert-HexColor "#071624"
    hoodShadow = Convert-HexColor "#0D273F"
    hoodBase = Convert-HexColor "#163E60"
    hoodHigh = Convert-HexColor "#285A84"
    greenDark = Convert-HexColor "#17492D"
    greenBase = Convert-HexColor "#2B8B49"
    greenHigh = Convert-HexColor "#5BC96F"
    brownDark = Convert-HexColor "#4A251E"
    brownHigh = Convert-HexColor "#704127"
    cyanDark = Convert-HexColor "#125767"
    cyanBase = Convert-HexColor "#35B1C2"
    cyanHigh = Convert-HexColor "#7EE8EB"
    cream = Convert-HexColor "#EFE6D3"
}

$baseMap = @{
    "#050D15" = $palette.hoodDeep
    "#DA4643" = $palette.redBase
    "#190B10" = $palette.outline
    "#224154" = $palette.hoodBase
    "#132B3C" = $palette.hoodShadow
    "#F16756" = $palette.redHigh
    "#AE2F39" = $palette.redShadow
    "#2DBFCD" = $palette.cyanBase
    "#2AB1BE" = $palette.cyanDark
    "#84EEEC" = $palette.cyanHigh
    "#4B9139" = $palette.greenBase
    "#5B371D" = $palette.brownDark
    "#3A5B6C" = $palette.hoodHigh
}

# Semantic groups: 1 apple, 2 hoodie, 3 outline, 4 leaf, 5 stem,
# 6 cyan face detail, 7 cream detail.
$currentGroups = @{}
$currentColors = @{}

function Add-CurrentColors([int]$Group, [System.Drawing.Color]$Target, [string[]]$Hexes) {
    foreach ($hex in $Hexes) {
        $script:currentGroups[$hex] = $Group
        $script:currentColors[$hex] = $Target
    }
}

Add-CurrentColors 1 $palette.redBase @("#D34342", "#DA4643")
Add-CurrentColors 1 $palette.redShadow @("#A43036", "#AE2F39")
Add-CurrentColors 1 $palette.redDeep @("#79242B")
Add-CurrentColors 1 $palette.redHigh @("#F15F52", "#F16756")
Add-CurrentColors 2 $palette.hoodBase @("#163E60", "#224154")
Add-CurrentColors 2 $palette.hoodShadow @("#0D273F", "#132B3C")
Add-CurrentColors 2 $palette.hoodDeep @("#071624", "#050D15")
Add-CurrentColors 2 $palette.hoodHigh @("#285A84", "#477EA4", "#3A5B6C")
Add-CurrentColors 3 $palette.outline @("#0A0A0F", "#190B10", "#191016", "#140D12")
Add-CurrentColors 4 $palette.greenBase @("#2B8B49", "#4B9139")
Add-CurrentColors 4 $palette.greenDark @("#17492D")
Add-CurrentColors 4 $palette.greenHigh @("#5BC96F")
Add-CurrentColors 5 $palette.brownDark @("#4A251E", "#5B371D")
Add-CurrentColors 5 $palette.brownHigh @("#704127")
Add-CurrentColors 6 $palette.cyanBase @("#35B1C2", "#2AB1BE", "#2DBFCD")
Add-CurrentColors 6 $palette.cyanDark @("#125767")
Add-CurrentColors 6 $palette.cyanHigh @("#7EE8EB", "#84EEEC")
Add-CurrentColors 7 $palette.cream @("#EFE6D3")

$base = [System.Drawing.Bitmap]::FromFile($basePath)
$current = [System.Drawing.Bitmap]::FromFile($currentPath)
$destination = [System.Drawing.Bitmap]::new(
    $base.Width,
    $base.Height,
    [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
)

try {
    $width = $base.Width
    $height = $base.Height
    $pixelCount = $width * $height
    $baseVisible = [bool[]]::new($pixelCount)
    $added = [bool[]]::new($pixelCount)
    $group = [byte[]]::new($pixelCount)
    $mapped = [System.Drawing.Color[]]::new($pixelCount)
    [xml]$actor = Get-Content -Raw -LiteralPath $anm2Path
    $sheetZeroLayers = @{}
    foreach ($layer in $actor.SelectNodes('//Content/Layers/Layer')) {
        if ([int]$layer.SpritesheetId -eq 0) {
            $sheetZeroLayers[[string]$layer.Id] = $true
        }
    }
    $cropAllowed = [bool[]]::new($pixelCount)
    foreach ($layerAnimation in $actor.SelectNodes('//LayerAnimation')) {
        if (-not $sheetZeroLayers.ContainsKey([string]$layerAnimation.LayerId)) {
            continue
        }
        foreach ($frame in $layerAnimation.SelectNodes('./Frame')) {
            if ([string]$frame.Visible -eq 'false') {
                continue
            }
            $cropX = [int]$frame.XCrop
            $cropY = [int]$frame.YCrop
            $cropWidth = [int]$frame.Width
            $cropHeight = [int]$frame.Height
            if ($cropWidth -le 0 -or $cropHeight -le 0) {
                continue
            }
            for ($cropPixelY = $cropY; $cropPixelY -lt $cropY + $cropHeight; $cropPixelY++) {
                for ($cropPixelX = $cropX; $cropPixelX -lt $cropX + $cropWidth; $cropPixelX++) {
                    $cropAllowed[$cropPixelY * $width + $cropPixelX] = $true
                }
            }
        }
    }
    $baseVisibleCount = 0

    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $index = $y * $width + $x
            $basePixel = $base.GetPixel($x, $y)

            if ($basePixel.A -gt 0 -and $cropAllowed[$index]) {
                $baseVisible[$index] = $true
                $baseVisibleCount++
                $baseHex = Get-RgbHex $basePixel
                $baseColor = $baseMap[$baseHex]
                if ($null -eq $baseColor) {
                    throw "Unmapped base color $baseHex at $x,$y"
                }
                $destination.SetPixel(
                    $x,
                    $y,
                    [System.Drawing.Color]::FromArgb(255, $baseColor.R, $baseColor.G, $baseColor.B)
                )
            } else {
                $destination.SetPixel($x, $y, [System.Drawing.Color]::Transparent)
            }

            $currentPixel = $current.GetPixel($x, $y)
            if ($currentPixel.A -gt 0 -and $cropAllowed[$index]) {
                $currentHex = Get-RgbHex $currentPixel
                if (-not $currentGroups.ContainsKey($currentHex)) {
                    throw "Unmapped current color $currentHex at $x,$y"
                }
                $group[$index] = [byte]$currentGroups[$currentHex]
                $mapped[$index] = $currentColors[$currentHex]
            }
        }
    }

    # Retain only coherent one-pixel silhouette additions from the original pass.
    # Signature leaf/stem pixels may attach with one neighbor; apple/hoodie need
    # at least three native-base neighbors so AI-generated detached noise is lost.
    for ($y = 1; $y -lt $height - 1; $y++) {
        for ($x = 1; $x -lt $width - 1; $x++) {
            $index = $y * $width + $x
            if ($baseVisible[$index] -or $group[$index] -eq 0) {
                continue
            }

            $baseNeighbors = 0
            for ($dy = -1; $dy -le 1; $dy++) {
                for ($dx = -1; $dx -le 1; $dx++) {
                    if ($dx -eq 0 -and $dy -eq 0) {
                        continue
                    }
                    if ($baseVisible[($y + $dy) * $width + ($x + $dx)]) {
                        $baseNeighbors++
                    }
                }
            }

            $isBodyExpansion = ($group[$index] -eq 1 -or $group[$index] -eq 2) -and $baseNeighbors -ge 3

            $isSignature = $false
            if ($group[$index] -eq 4 -or $group[$index] -eq 5) {
                # A stem or leaf often sits several pixels above the vanilla
                # round-head alpha. Retain it only when it remains close to the
                # native sprite, so detached generated debris is still rejected.
                for ($radiusY = -5; $radiusY -le 5 -and -not $isSignature; $radiusY++) {
                    for ($radiusX = -5; $radiusX -le 5; $radiusX++) {
                        $nearX = $x + $radiusX
                        $nearY = $y + $radiusY
                        if ($nearX -lt 0 -or $nearX -ge $width -or $nearY -lt 0 -or $nearY -ge $height) {
                            continue
                        }
                        if ($baseVisible[$nearY * $width + $nearX]) {
                            $isSignature = $true
                            break
                        }
                    }
                }
            }
            if ($isBodyExpansion -or $isSignature) {
                $added[$index] = $true
            }
        }
    }

    # Keep a single coherent outline around newly accepted silhouette pixels.
    for ($pass = 0; $pass -lt 2; $pass++) {
        for ($y = 1; $y -lt $height - 1; $y++) {
            for ($x = 1; $x -lt $width - 1; $x++) {
                $index = $y * $width + $x
                if ($baseVisible[$index] -or $added[$index] -or $group[$index] -ne 3) {
                    continue
                }

                $touchesAddition = $false
                for ($dy = -1; $dy -le 1 -and -not $touchesAddition; $dy++) {
                    for ($dx = -1; $dx -le 1; $dx++) {
                        if ($dx -eq 0 -and $dy -eq 0) {
                            continue
                        }
                        $neighbor = ($y + $dy) * $width + ($x + $dx)
                        if ($added[$neighbor] -and $group[$neighbor] -ne 3) {
                            $touchesAddition = $true
                            break
                        }
                    }
                }

                if ($touchesAddition) {
                    $added[$index] = $true
                }
            }
        }
    }

    $addedCount = 0
    for ($y = 0; $y -lt $height; $y++) {
        for ($x = 0; $x -lt $width; $x++) {
            $index = $y * $width + $x
            if (-not $added[$index]) {
                continue
            }
            $color = $mapped[$index]
            $destination.SetPixel(
                $x,
                $y,
                [System.Drawing.Color]::FromArgb(255, $color.R, $color.G, $color.B)
            )
            $addedCount++
        }
    }

    $destination.Save($outputPath, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Output "RingoTsuga native candidate created"
    Write-Output "base_visible=$baseVisibleCount added=$addedCount visible=$($baseVisibleCount + $addedCount)"
    Write-Output "output=$outputPath"
} finally {
    $base.Dispose()
    $current.Dispose()
    $destination.Dispose()
}
