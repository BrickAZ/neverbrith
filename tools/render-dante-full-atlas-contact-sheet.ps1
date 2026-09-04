param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = 'reports\dante-character\dante-full-atlas-contact-sheet.png'
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$atlasPath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
$destination = Join-Path $Root $OutputPath
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path -LiteralPath $atlasPath)) { throw "Missing Dante atlas: $atlasPath" }
$atlas = [Drawing.Bitmap]::new($atlasPath)
$output = [Drawing.Bitmap]::new(1320, 1910, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($output)
$titleFont = [Drawing.Font]::new('Segoe UI', 16, [Drawing.FontStyle]::Bold)
$labelFont = [Drawing.Font]::new('Consolas', 8, [Drawing.FontStyle]::Regular)
$textBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 28, 28, 32))
$checkerA = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 226, 226, 226))
$checkerB = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 188, 188, 188))

function Draw-Checker {
    param([Drawing.Graphics]$Graphics, [Drawing.Rectangle]$Area, [int]$Size = 8)
    for ($y = $Area.Y; $y -lt $Area.Bottom; $y += $Size) {
        for ($x = $Area.X; $x -lt $Area.Right; $x += $Size) {
            $brush = if ((([int](($x - $Area.X) / $Size) + [int](($y - $Area.Y) / $Size)) % 2) -eq 0) { $checkerA } else { $checkerB }
            $Graphics.FillRectangle($brush, $x, $y, [Math]::Min($Size, $Area.Right - $x), [Math]::Min($Size, $Area.Bottom - $y))
        }
    }
}

function Draw-Group {
    param([string]$Title, [array]$Regions, [int]$Top)
    $graphics.DrawString($Title, $titleFont, $textBrush, 18, $Top)
    $gridTop = $Top + 34
    for ($index = 0; $index -lt $Regions.Count; $index++) {
        $region = $Regions[$index]
        $column = $index % 8
        $row = [Math]::Floor($index / 8)
        $left = 18 + $column * 162
        $cellTop = $gridTop + $row * 166
        $preview = [Drawing.Rectangle]::new($left, $cellTop, 128, 128)
        Draw-Checker -Graphics $graphics -Area $preview
        $scale = if ($region.W -eq 64) { 2 } else { 4 }
        $drawWidth = $region.W * $scale
        $drawHeight = $region.H * $scale
        $target = [Drawing.Rectangle]::new($left + [int]((128 - $drawWidth) / 2), $cellTop + [int]((128 - $drawHeight) / 2), $drawWidth, $drawHeight)
        $source = [Drawing.Rectangle]::new($region.X, $region.Y, $region.W, $region.H)
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
        $graphics.DrawImage($atlas, $target, $source, [Drawing.GraphicsUnit]::Pixel)
        $graphics.DrawString(("{0}: {1},{2} {3}x{4}" -f $region.Name, $region.X, $region.Y, $region.W, $region.H), $labelFont, $textBrush, $left, $cellTop + 132)
    }
    return $gridTop + [Math]::Ceiling($Regions.Count / 8) * 166
}

$heads = @()
foreach ($entry in @(@('down-a',0,0),@('down-b',32,0),@('side-a',64,0),@('side-b',96,0),@('up-a',128,0),@('up-b',160,0))) {
    $heads += @{ Name = $entry[0]; X = $entry[1]; Y = $entry[2]; W = 32; H = 32 }
}
$heads += @{ Name = 'pickup-head'; X = 256; Y = 128; W = 64; H = 64 }
$glitchIndex = 0
foreach ($origin in @(@(16,336),@(48,336),@(80,336),@(16,368),@(48,368),@(80,368),@(16,400))) {
    $heads += @{ Name = "glitch-$glitchIndex"; X = $origin[0]; Y = $origin[1]; W = 32; H = 32 }
    $glitchIndex++
}

$bodies = @(@{ Name = 'body-0'; X = 192; Y = 0; W = 32; H = 32 }, @{ Name = 'body-1'; X = 224; Y = 0; W = 32; H = 32 })
$bodyIndex = 2
foreach ($y in @(32,64)) { foreach ($x in @(0,32,64,96,128,160,192,224)) {
    $bodies += @{ Name = "body-$bodyIndex"; X = $x; Y = $y; W = 32; H = 32 }; $bodyIndex++
} }
$bodies += @{ Name = 'body-18'; X = 0; Y = 96; W = 32; H = 32 }, @{ Name = 'body-19'; X = 32; Y = 96; W = 32; H = 32 }

$extras = @(@{ Name = 'extra-0'; X = 448; Y = 0; W = 32; H = 32 }, @{ Name = 'extra-1'; X = 480; Y = 0; W = 32; H = 32 })
$extraIndex = 2
foreach ($y in @(32,64)) { foreach ($x in @(256,288,320,352,384,416,448,480)) {
    $extras += @{ Name = "extra-$extraIndex"; X = $x; Y = $y; W = 32; H = 32 }; $extraIndex++
} }
$extras += @{ Name = 'extra-18'; X = 256; Y = 96; W = 32; H = 32 }, @{ Name = 'extra-19'; X = 288; Y = 96; W = 32; H = 32 }
foreach ($origin in @(@(0,128),@(64,128),@(128,128),@(192,130),@(0,192),@(64,192),@(128,192),@(192,192),@(0,256),@(64,256),@(128,256),@(192,256))) {
    $extras += @{ Name = "extra-$extraIndex"; X = $origin[0]; Y = $origin[1]; W = 64; H = 64 }; $extraIndex++
}

try {
    $graphics.Clear([Drawing.Color]::FromArgb(255, 247, 247, 247))
    $next = Draw-Group -Title '14 BASE HEAD REGIONS - normal hair is a separate Null Costume' -Regions $heads -Top 16
    $next = Draw-Group -Title '20 NORMAL BODY REGIONS - 4x' -Regions $bodies -Top ($next + 10)
    [void](Draw-Group -Title '32 EXTRA / SPECIAL REGIONS - 4x for 32px / 2x for 64px' -Regions $extras -Top ($next + 10))
    $directory = Split-Path -Parent $destination
    New-Item -ItemType Directory -Force -Path $directory | Out-Null
    $output.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
}
finally {
    $checkerA.Dispose(); $checkerB.Dispose(); $textBrush.Dispose(); $labelFont.Dispose(); $titleFont.Dispose()
    $graphics.Dispose(); $output.Dispose(); $atlas.Dispose()
}

Write-Output "Rendered full Dante atlas contact sheet to $destination"
