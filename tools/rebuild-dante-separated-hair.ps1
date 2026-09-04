param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$outputPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_dante_hair.png'
$basePath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
Add-Type -AssemblyName System.Drawing

$Outline = [Drawing.Color]::FromArgb(255, 38, 39, 48)
$Deep = [Drawing.Color]::FromArgb(255, 67, 70, 82)
$Shadow = [Drawing.Color]::FromArgb(255, 91, 96, 112)
$Cool = [Drawing.Color]::FromArgb(255, 122, 129, 147)
$Mid = [Drawing.Color]::FromArgb(255, 154, 162, 180)
$Light = [Drawing.Color]::FromArgb(255, 190, 197, 211)
$Shine = [Drawing.Color]::FromArgb(255, 222, 226, 235)

function New-Points {
    param([int[]]$Coordinates, [int]$OffsetX = 0, [int]$OffsetY = 0)
    if (($Coordinates.Count % 2) -ne 0) { throw 'point coordinate list must contain x/y pairs' }
    $points = [Collections.Generic.List[Drawing.Point]]::new()
    for ($index = 0; $index -lt $Coordinates.Count; $index += 2) {
        $points.Add([Drawing.Point]::new(
            $Coordinates[$index] + $OffsetX,
            $Coordinates[$index + 1] + $OffsetY
        ))
    }
    return $points.ToArray()
}

function Add-FillPiece {
    param(
        [Drawing.Graphics]$Graphics,
        [Drawing.Color]$Fill,
        [int[]]$Coordinates,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0
    )
    $brush = [Drawing.SolidBrush]::new($Fill)
    try {
        $points = [Drawing.Point[]](New-Points -Coordinates $Coordinates -OffsetX $OffsetX -OffsetY $OffsetY)
        $Graphics.FillPolygon(
            $brush,
            $points,
            [Drawing.Drawing2D.FillMode]::Winding
        )
    }
    finally { $brush.Dispose() }
}

function Add-Strand {
    param(
        [Drawing.Graphics]$Graphics,
        [Drawing.Color]$Color,
        [int[]]$Coordinates,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0
    )
    $pen = [Drawing.Pen]::new($Color, 1)
    $pen.StartCap = [Drawing.Drawing2D.LineCap]::Flat
    $pen.EndCap = [Drawing.Drawing2D.LineCap]::Flat
    try {
        $points = [Drawing.Point[]](New-Points -Coordinates $Coordinates -OffsetX $OffsetX -OffsetY $OffsetY)
        $Graphics.DrawLines($pen, $points)
    }
    finally { $pen.Dispose() }
}

function Add-Pixels {
    param(
        [Drawing.Bitmap]$Bitmap,
        [Drawing.Color]$Color,
        [int[]]$Coordinates,
        [int]$OffsetX = 0,
        [int]$OffsetY = 0
    )
    foreach ($point in (New-Points -Coordinates $Coordinates -OffsetX $OffsetX -OffsetY $OffsetY)) {
        if ($point.X -lt 0 -or $point.X -ge 64 -or $point.Y -lt 0 -or $point.Y -ge 64) {
            throw "hair detail pixel is outside its 64x64 frame: $($point.X),$($point.Y)"
        }
        $Bitmap.SetPixel($point.X, $point.Y, $Color)
    }
}

function Apply-SubjectBoundary {
    param([Drawing.Bitmap]$Frame)
    $visible = [bool[]]::new(4096)
    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 64; $x++) {
            $visible[$y * 64 + $x] = $Frame.GetPixel($x, $y).A -gt 0
        }
    }
    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 64; $x++) {
            if (-not $visible[$y * 64 + $x]) { continue }
            $boundary = $false
            foreach ($delta in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
                $nx = $x + $delta[0]
                $ny = $y + $delta[1]
                if ($nx -lt 0 -or $nx -ge 64 -or $ny -lt 0 -or $ny -ge 64 -or
                    -not $visible[$ny * 64 + $nx]) {
                    $boundary = $true
                    break
                }
            }
            if ($boundary) { $Frame.SetPixel($x, $y, $Outline) }
        }
    }
}

function Draw-DownHair {
    param([Drawing.Bitmap]$Bitmap, [Drawing.Graphics]$Graphics, [int]$Phase)

    if ($Phase -eq 0) {
        $crown = @(17,26, 16,23, 18,18, 23,13, 29,10, 36,11, 43,14, 47,19, 49,24, 48,27, 44,27, 42,23, 39,20, 35,17, 31,17, 27,19, 24,22, 22,27)
        $leftLock = @(17,23, 21,23, 21,29, 20,34, 20,41, 19,47, 16,44, 17,34)
        $rightLock = @(43,22, 47,23, 49,28, 48,34, 47,42, 44,47, 43,39)
        $shortBang = @(24,14, 29,12, 32,15, 31,19, 29,23, 28,27, 25,28, 26,22, 23,18)
        $sweepBang = @(31,13, 37,14, 41,17, 42,21, 40,25, 40,28, 36,28, 36,23, 33,20)
    }
    else {
        $crown = @(17,27, 16,24, 18,19, 23,14, 29,11, 36,12, 43,15, 47,20, 49,25, 48,28, 44,28, 42,24, 39,21, 35,18, 31,18, 27,20, 24,23, 22,28)
        $leftLock = @(17,24, 21,24, 21,30, 20,35, 20,42, 18,48, 16,45, 17,35)
        $rightLock = @(43,23, 47,24, 49,29, 48,35, 47,43, 44,48, 43,40)
        $shortBang = @(24,15, 29,13, 32,16, 31,20, 29,24, 28,28, 25,28, 26,23, 23,19)
        $sweepBang = @(31,14, 37,15, 41,18, 42,22, 40,26, 40,28, 36,28, 36,24, 33,21)
    }

    Add-FillPiece $Graphics $Deep $crown
    Add-FillPiece $Graphics $Shadow @(17,25, 18,19, 23,14, 29,11, 31,17, 28,21, 24,26, 21,28) -OffsetY $Phase
    Add-FillPiece $Graphics $Cool @(31,12, 36,12, 42,15, 47,20, 48,25, 44,27, 41,22, 36,18) -OffsetY $Phase
    Add-FillPiece $Graphics $Shadow $leftLock
    Add-FillPiece $Graphics $Cool $rightLock
    Add-FillPiece $Graphics $Mid $shortBang
    Add-FillPiece $Graphics $Light $sweepBang
    Apply-SubjectBoundary -Frame $Bitmap

    Add-Strand $Graphics $Deep @(23,17, 25,19, 25,21) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(25,24, 24,27) -OffsetY ([Math]::Min($Phase,1))
    Add-Strand $Graphics $Mid @(39,16, 42,18, 44,20) -OffsetY $Phase
    Add-Strand $Graphics $Light @(19,25, 18,29) -OffsetY $Phase
    Add-Strand $Graphics $Light @(18,34, 18,38) -OffsetY $Phase
    Add-Strand $Graphics $Mid @(46,26, 46,30) -OffsetY $Phase
    Add-Strand $Graphics $Mid @(46,35, 45,39) -OffsetY $Phase
    Add-Strand $Graphics $Shine @(27,14, 30,12, 32,13) -OffsetY $Phase
    Add-Strand $Graphics $Light @(34,14, 37,15, 39,17) -OffsetY $Phase
    Add-Pixels $Bitmap $Shine @(22,18, 30,14, 35,14, 43,19) -OffsetY $Phase
}

function Draw-RightHair {
    param([Drawing.Bitmap]$Bitmap, [Drawing.Graphics]$Graphics, [int]$Phase)

    if ($Phase -eq 0) {
        $crown = @(16,26, 16,22, 18,18, 23,14, 29,11, 36,11, 43,14, 47,18, 49,23, 49,27, 45,27, 42,24, 38,20, 33,18, 28,19, 24,22, 22,27)
        $rearLock = @(17,22, 25,21, 28,25, 27,32, 26,39, 24,47, 21,50, 18,46, 18,36)
        $frontSweep = @(34,14, 40,14, 46,18, 49,22, 50,27, 48,31, 44,35, 42,33, 44,28, 42,24, 38,21, 34,20)
    }
    else {
        $crown = @(16,27, 16,23, 18,19, 23,15, 29,12, 36,12, 43,15, 47,19, 49,24, 49,28, 45,28, 42,25, 38,21, 33,19, 28,20, 24,23, 22,28)
        $rearLock = @(17,23, 25,22, 28,26, 27,33, 26,40, 24,48, 21,51, 18,47, 18,37)
        $frontSweep = @(34,15, 40,15, 46,19, 49,23, 50,28, 48,32, 44,36, 42,34, 44,29, 42,25, 38,22, 34,21)
    }

    Add-FillPiece $Graphics $Deep $crown
    Add-FillPiece $Graphics $Shadow @(17,25, 19,19, 24,15, 30,12, 32,18, 28,22, 24,27, 21,29) -OffsetY $Phase
    Add-FillPiece $Graphics $Cool @(29,12, 36,12, 43,15, 47,19, 48,24, 44,27, 40,22, 35,18) -OffsetY $Phase
    Add-FillPiece $Graphics $Shadow $rearLock
    Add-FillPiece $Graphics $Light $frontSweep
    Add-FillPiece $Graphics $Mid @(31,16, 36,15, 41,18, 44,21, 43,24, 40,27, 37,27, 38,23, 34,21, 31,21) -OffsetY $Phase
    Apply-SubjectBoundary -Frame $Bitmap

    Add-Strand $Graphics $Light @(20,20, 23,17, 27,15) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(25,23, 25,27) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(24,31, 23,35) -OffsetY $Phase
    Add-Strand $Graphics $Mid @(22,39, 21,43) -OffsetY $Phase
    Add-Strand $Graphics $Mid @(43,18, 46,20, 48,23) -OffsetY $Phase
    Add-Strand $Graphics $Light @(46,26, 47,29) -OffsetY $Phase
    Add-Strand $Graphics $Shine @(28,14, 31,12, 34,13) -OffsetY $Phase
    Add-Pixels $Bitmap $Shine @(21,19, 29,13, 33,13, 44,19) -OffsetY $Phase
}

function Draw-UpHair {
    param([Drawing.Bitmap]$Bitmap, [Drawing.Graphics]$Graphics, [int]$Phase)

    if ($Phase -eq 0) {
        $mass = @(16,27, 16,23, 18,18, 23,14, 29,11, 36,11, 43,14, 48,20, 50,27, 48,34, 47,42, 44,48, 41,46, 39,50, 36,47, 33,51, 30,47, 27,50, 24,46, 21,48, 18,43, 18,34)
    }
    else {
        $mass = @(15,28, 16,24, 18,19, 23,15, 29,12, 36,12, 43,15, 48,21, 50,28, 49,35, 47,43, 44,49, 41,47, 39,52, 36,48, 33,53, 30,48, 27,52, 24,47, 21,50, 18,44, 17,35)
    }

    Add-FillPiece $Graphics $Deep $mass
    Add-FillPiece $Graphics $Shadow @(17,28, 18,20, 24,15, 29,12, 31,18, 28,25, 25,34, 24,44, 21,47, 19,41) -OffsetY $Phase
    Add-FillPiece $Graphics $Cool @(29,12, 36,12, 43,15, 48,21, 49,28, 46,35, 44,45, 41,47, 40,38, 38,28, 34,20) -OffsetY $Phase
    Add-FillPiece $Graphics $Mid @(23,16, 28,13, 32,15, 31,21, 29,28, 28,38, 27,47, 24,45, 25,35, 24,26) -OffsetY $Phase
    Add-FillPiece $Graphics $Light @(31,13, 36,13, 39,16, 38,22, 36,29, 35,39, 33,49, 30,46, 32,36, 31,27) -OffsetY $Phase
    Apply-SubjectBoundary -Frame $Bitmap

    Add-Strand $Graphics $Light @(20,21, 23,18, 27,16) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(24,27, 24,31) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(23,35, 23,39) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(29,29, 29,33) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(28,38, 28,42) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(35,28, 35,32) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(35,37, 34,41) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(41,29, 42,33) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(42,38, 42,42) -OffsetY $Phase
    Add-Strand $Graphics $Light @(40,17, 43,19, 46,22) -OffsetY $Phase
    Add-Strand $Graphics $Shine @(30,14, 33,13, 35,14) -OffsetY $Phase
    Add-Pixels $Bitmap $Shine @(22,18, 31,14, 34,14, 42,18) -OffsetY $Phase
}

function Draw-LeftHair {
    param([Drawing.Bitmap]$Bitmap, [Drawing.Graphics]$Graphics, [int]$Phase)

    if ($Phase -eq 0) {
        $crown = @(48,26, 48,22, 46,18, 41,14, 35,11, 28,12, 21,15, 17,20, 15,25, 15,27, 19,27, 22,24, 26,20, 31,18, 36,19, 40,22, 42,27)
        $rearLock = @(47,22, 39,21, 36,25, 37,32, 38,39, 40,47, 43,50, 46,46, 46,36)
        $frontSweep = @(30,14, 24,14, 18,18, 15,22, 14,27, 16,31, 20,35, 22,33, 20,28, 22,24, 26,21, 30,20)
    }
    else {
        $crown = @(48,27, 48,23, 46,19, 41,15, 35,12, 28,13, 21,16, 17,21, 15,26, 15,28, 19,28, 22,25, 26,21, 31,19, 36,20, 40,23, 42,28)
        $rearLock = @(47,23, 39,22, 36,26, 37,33, 38,40, 40,48, 43,51, 46,47, 46,37)
        $frontSweep = @(30,15, 24,15, 18,19, 15,23, 14,28, 16,32, 20,36, 22,34, 20,29, 22,25, 26,22, 30,21)
    }

    Add-FillPiece $Graphics $Deep $crown
    Add-FillPiece $Graphics $Shadow @(47,25, 45,19, 40,15, 34,12, 32,18, 36,22, 40,27, 43,29) -OffsetY $Phase
    Add-FillPiece $Graphics $Cool @(35,12, 28,13, 21,16, 17,20, 16,25, 20,27, 24,22, 29,18) -OffsetY $Phase
    Add-FillPiece $Graphics $Shadow $rearLock
    Add-FillPiece $Graphics $Light $frontSweep
    Add-FillPiece $Graphics $Mid @(33,16, 28,15, 23,18, 20,21, 21,24, 24,27, 27,27, 26,23, 30,21, 33,21) -OffsetY $Phase
    Apply-SubjectBoundary -Frame $Bitmap

    Add-Strand $Graphics $Light @(44,20, 41,17, 37,15) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(39,23, 39,27) -OffsetY $Phase
    Add-Strand $Graphics $Deep @(40,31, 41,35) -OffsetY $Phase
    Add-Strand $Graphics $Mid @(42,39, 43,43) -OffsetY $Phase
    Add-Strand $Graphics $Mid @(21,18, 18,20, 16,23) -OffsetY $Phase
    Add-Strand $Graphics $Light @(18,26, 17,29) -OffsetY $Phase
    Add-Strand $Graphics $Shine @(36,14, 33,12, 30,13) -OffsetY $Phase
    Add-Pixels $Bitmap $Shine @(43,19, 35,13, 31,13, 20,19) -OffsetY $Phase
}

function New-HairFrame {
    param(
        [ValidateSet('Down','Right','Up','Left')][string]$Direction,
        [ValidateSet(0,1)][int]$Phase
    )
    $frame = [Drawing.Bitmap]::new(64, 64, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics = [Drawing.Graphics]::FromImage($frame)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver
        $drawer = "Draw-$($Direction)Hair"
        & $drawer -Bitmap $frame -Graphics $graphics -Phase $Phase
        return $frame
    }
    catch {
        $frame.Dispose()
        throw
    }
    finally { $graphics.Dispose() }
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

function Get-ProtectedFaceViolations {
    param([Drawing.Bitmap]$Base, [Drawing.Bitmap]$Hair)
    $frames = @(
        [pscustomobject]@{ Name='Down A';  HairIndex=0; HeadX=0;  Mirror=$false },
        [pscustomobject]@{ Name='Down B';  HairIndex=1; HeadX=32; Mirror=$false },
        [pscustomobject]@{ Name='Right A'; HairIndex=2; HeadX=64; Mirror=$false },
        [pscustomobject]@{ Name='Right B'; HairIndex=3; HeadX=96; Mirror=$false },
        [pscustomobject]@{ Name='Left A';  HairIndex=6; HeadX=64; Mirror=$true  },
        [pscustomobject]@{ Name='Left B';  HairIndex=7; HeadX=96; Mirror=$true  }
    )
    $violations = [Collections.Generic.List[string]]::new()
    foreach ($frame in $frames) {
        for ($y = 0; $y -lt 32; $y++) {
            for ($x = 0; $x -lt 32; $x++) {
                $sourceX = if ($frame.Mirror) { 31 - $x } else { $x }
                $basePixel = $Base.GetPixel($frame.HeadX + $sourceX, $y)
                if (-not (Test-IsProtectedFacePixel -Pixel $basePixel -X $x -Y $y)) { continue }
                if ($Hair.GetPixel($frame.HairIndex * 64 + $x + 16, $y + 16).A -gt 0) {
                    $violations.Add("$($frame.Name): head=$x,$y hair=$($x+16),$($y+16)")
                }
            }
        }
    }
    return $violations.ToArray()
}

$directory = Split-Path -Parent $outputPath
if (-not (Test-Path -LiteralPath $directory)) { throw "missing costume output directory: $directory" }
if (-not (Test-Path -LiteralPath $basePath)) { throw "missing Dante base atlas for face gate: $basePath" }

$sheet = [Drawing.Bitmap]::new(512, 64, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
$sheetGraphics = [Drawing.Graphics]::FromImage($sheet)
$frames = [Collections.Generic.List[Drawing.Bitmap]]::new()
try {
    $sheetGraphics.Clear([Drawing.Color]::Transparent)
    $sheetGraphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
    $sheetGraphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
    $sheetGraphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
    $sheetGraphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceOver

    $directions = @('Down','Right','Up','Left')
    $frameIndex = 0
    foreach ($direction in $directions) {
        foreach ($phase in 0,1) {
            $frame = New-HairFrame -Direction $direction -Phase $phase
            $frames.Add($frame)
            $sheetGraphics.DrawImageUnscaled($frame, $frameIndex * 64, 0)
            $frameIndex++
        }
    }

    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 512; $x++) {
            $alpha = $sheet.GetPixel($x, $y).A
            if ($alpha -ne 0 -and $alpha -ne 255) {
                throw "Dante hair output contains non-binary alpha at ${x},${y}: $alpha"
            }
        }
    }

    $baseStream = [IO.File]::OpenRead($basePath)
    try {
        $baseSource = [Drawing.Bitmap]::FromStream($baseStream)
        try {
            $base = [Drawing.Bitmap]::new($baseSource)
            try {
                $violations = @(Get-ProtectedFaceViolations -Base $base -Hair $sheet)
                if ($violations.Count -gt 0) {
                    throw "refusing to publish Dante hair over protected eye/tear/mouth pixels:`n$($violations -join "`n")"
                }
            }
            finally { $base.Dispose() }
        }
        finally { $baseSource.Dispose() }
    }
    finally { $baseStream.Dispose() }

    $temporary = Join-Path $directory ('.codex-dante-hair-' + [guid]::NewGuid().ToString('N') + '.png')
    try {
        $sheet.Save($temporary, [Drawing.Imaging.ImageFormat]::Png)
        Move-Item -LiteralPath $temporary -Destination $outputPath -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}
finally {
    foreach ($frame in $frames) { $frame.Dispose() }
    $sheetGraphics.Dispose()
    $sheet.Dispose()
}

Write-Output "Rebuilt Dante eye-safe lively hair sheet: $outputPath"
