param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [string]$OutputPath = 'reports\dante-character\dante-hair-costume-contact-sheet.png'
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$basePath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
$hairPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_dante_hair.png'
$destination = Join-Path $Root $OutputPath
Add-Type -AssemblyName System.Drawing

foreach ($path in @($basePath, $hairPath)) {
    if (-not (Test-Path -LiteralPath $path)) { throw "Missing Dante visual resource: $path" }
}

function Open-BitmapCopy {
    param([string]$Path)
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) }
        finally { $source.Dispose() }
    }
    finally { $stream.Dispose() }
}

$base = Open-BitmapCopy -Path $basePath
$hair = Open-BitmapCopy -Path $hairPath
$output = [Drawing.Bitmap]::new(1180, 920, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$graphics = [Drawing.Graphics]::FromImage($output)
$titleFont = [Drawing.Font]::new('Segoe UI', 16, [Drawing.FontStyle]::Bold)
$sectionFont = [Drawing.Font]::new('Segoe UI', 11, [Drawing.FontStyle]::Bold)
$labelFont = [Drawing.Font]::new('Consolas', 9, [Drawing.FontStyle]::Regular)
$textBrush = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 28, 28, 32))
$checkerLight = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 226, 226, 226))
$checkerDark = [Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255, 188, 188, 188))
$borderPen = [Drawing.Pen]::new([Drawing.Color]::FromArgb(255, 94, 94, 102), 1)

function Draw-Checker {
    param([Drawing.Graphics]$Target, [Drawing.Rectangle]$Area, [int]$Size)
    for ($y = $Area.Y; $y -lt $Area.Bottom; $y += $Size) {
        for ($x = $Area.X; $x -lt $Area.Right; $x += $Size) {
            $parity = ([int](($x - $Area.X) / $Size) + [int](($y - $Area.Y) / $Size)) % 2
            $brush = if ($parity -eq 0) { $checkerLight } else { $checkerDark }
            $Target.FillRectangle($brush, $x, $y, [Math]::Min($Size, $Area.Right - $x), [Math]::Min($Size, $Area.Bottom - $y))
        }
    }
    $Target.DrawRectangle($borderPen, $Area)
}

function New-HeadComposite {
    param([int]$FrameIndex, [int]$HeadX, [bool]$MirrorHead)
    $composite = [Drawing.Bitmap]::new(64, 64, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($composite)
    $head = [Drawing.Bitmap]::new(32, 32, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $headGraphics = [Drawing.Graphics]::FromImage($head)
    try {
        $g.Clear([Drawing.Color]::Transparent)
        $headGraphics.Clear([Drawing.Color]::Transparent)
        $headGraphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $headGraphics.DrawImage($base, [Drawing.Rectangle]::new(0,0,32,32), [Drawing.Rectangle]::new($HeadX,0,32,32), [Drawing.GraphicsUnit]::Pixel)
        if ($MirrorHead) { $head.RotateFlip([Drawing.RotateFlipType]::RotateNoneFlipX) }
        $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
        # Official HeadDown uses pivot 16,28 at YPosition=-5.  The hair costume uses
        # pivot 32,44 at the same YPosition, so their crop origins differ by 16,16.
        $g.DrawImageUnscaled($head, 16, 16)
        $g.DrawImage($hair, [Drawing.Rectangle]::new(0,0,64,64), [Drawing.Rectangle]::new($FrameIndex * 64,0,64,64), [Drawing.GraphicsUnit]::Pixel)
        return $composite
    }
    finally {
        $headGraphics.Dispose()
        $head.Dispose()
        $g.Dispose()
    }
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

function Measure-ProtectedOverlap {
    param([int]$FrameIndex, [int]$HeadX, [bool]$MirrorHead, [bool]$FaceVisible)
    if (-not $FaceVisible) { return -1 }
    $overlap = 0
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $sourceX = if ($MirrorHead) { 31 - $x } else { $x }
            $basePixel = $base.GetPixel($HeadX + $sourceX, $y)
            if (-not (Test-IsProtectedFacePixel -Pixel $basePixel -X $x -Y $y)) { continue }
            if ($hair.GetPixel($FrameIndex * 64 + $x + 16, $y + 16).A -gt 0) { $overlap++ }
        }
    }
    return $overlap
}
$frames = @(
    @{ Name='Down A'; HeadX=0; Mirror=$false; FaceVisible=$true }, @{ Name='Down B'; HeadX=32; Mirror=$false; FaceVisible=$true },
    @{ Name='Right A'; HeadX=64; Mirror=$false; FaceVisible=$true }, @{ Name='Right B'; HeadX=96; Mirror=$false; FaceVisible=$true },
    @{ Name='Up A'; HeadX=128; Mirror=$false; FaceVisible=$false }, @{ Name='Up B'; HeadX=160; Mirror=$false; FaceVisible=$false },
    @{ Name='Left A'; HeadX=64; Mirror=$true; FaceVisible=$true }, @{ Name='Left B'; HeadX=96; Mirror=$true; FaceVisible=$true }
)
$composites = [Collections.Generic.List[Drawing.Bitmap]]::new()

try {
    $graphics.Clear([Drawing.Color]::FromArgb(255, 247, 247, 247))
    $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
    $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
    $graphics.DrawString('Dante separated hair - native 1x authority and 4x pixel inspection', $titleFont, $textBrush, 24, 14)

    $graphics.DrawString('Raw 64x64 costume crops at native 1x', $sectionFont, $textBrush, 24, 54)
    for ($index = 0; $index -lt $frames.Count; $index++) {
        $left = 24 + $index * 142
        $graphics.DrawString($frames[$index].Name, $labelFont, $textBrush, $left, 78)
        $area = [Drawing.Rectangle]::new($left, 98, 64, 64)
        Draw-Checker -Target $graphics -Area $area -Size 8
        $graphics.DrawImage($hair, $area, [Drawing.Rectangle]::new($index * 64,0,64,64), [Drawing.GraphicsUnit]::Pixel)
    }

    $graphics.DrawString('Base head plus Null Costume at native 1x - protected eye/tear/mouth overlap below', $sectionFont, $textBrush, 24, 184)
    for ($index = 0; $index -lt $frames.Count; $index++) {
        $composite = New-HeadComposite -FrameIndex $index -HeadX $frames[$index].HeadX -MirrorHead $frames[$index].Mirror
        $composites.Add($composite)
        $left = 24 + $index * 142
        $graphics.DrawString($frames[$index].Name, $labelFont, $textBrush, $left, 208)
        $area = [Drawing.Rectangle]::new($left, 228, 64, 64)
        Draw-Checker -Target $graphics -Area $area -Size 8
        $graphics.DrawImageUnscaled($composite, $left, 228)
        $overlap = Measure-ProtectedOverlap -FrameIndex $index -HeadX $frames[$index].HeadX -MirrorHead $frames[$index].Mirror -FaceVisible $frames[$index].FaceVisible
        $overlapLabel = if ($overlap -lt 0) { 'overlap: n/a' } else { "overlap: $overlap" }
        $graphics.DrawString($overlapLabel, $labelFont, $textBrush, $left, 294)
        if ($overlap -gt 0) { throw "$($frames[$index].Name) protected overlap is $overlap; refusing to publish evidence" }
    }

    $graphics.DrawString('4x nearest-neighbour pixel inspection', $sectionFont, $textBrush, 24, 316)
    for ($index = 0; $index -lt $composites.Count; $index++) {
        $column = $index % 4
        $row = [Math]::Floor($index / 4)
        $left = 24 + $column * 286
        $top = 364 + $row * 274
        $graphics.DrawString($frames[$index].Name, $labelFont, $textBrush, $left, $top - 22)
        $area = [Drawing.Rectangle]::new($left, $top, 256, 256)
        Draw-Checker -Target $graphics -Area $area -Size 16
        $graphics.DrawImage($composites[$index], $area, [Drawing.Rectangle]::new(0,0,64,64), [Drawing.GraphicsUnit]::Pixel)
    }

    $directory = Split-Path -Parent $destination
    if (-not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Force -Path $directory | Out-Null }
    $output.Save($destination, [Drawing.Imaging.ImageFormat]::Png)
}
finally {
    foreach ($composite in $composites) { $composite.Dispose() }
    $borderPen.Dispose(); $checkerDark.Dispose(); $checkerLight.Dispose(); $textBrush.Dispose()
    $labelFont.Dispose(); $sectionFont.Dispose(); $titleFont.Dispose()
    $graphics.Dispose(); $output.Dispose(); $hair.Dispose(); $base.Dispose()
}

Write-Output "Rendered Dante separated-hair evidence to $destination"

