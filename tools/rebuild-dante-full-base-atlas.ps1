param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$gameRoot = Split-Path -Parent (Split-Path -Parent $Root)
$officialAtlasPath = Join-Path $gameRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
$danteAtlasPath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
Add-Type -AssemblyName System.Drawing

function Assert-FileExists {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { throw "Missing required image: $Path" }
}

function Open-BitmapCopy {
    param([string]$Path)
    Assert-FileExists -Path $Path
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) }
        finally { $source.Dispose() }
    }
    finally { $stream.Dispose() }
}

function Save-PngAtomically {
    param([Drawing.Bitmap]$Bitmap, [string]$Path)
    $directory = Split-Path -Parent $Path
    $temporary = Join-Path $directory ('.codex-dante-atlas-' + [guid]::NewGuid().ToString('N') + '.png')
    try {
        $Bitmap.Save($temporary, [Drawing.Imaging.ImageFormat]::Png)
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

$Transparent = [Drawing.Color]::FromArgb(0, 0, 0, 0)
$HairOutline = [Drawing.Color]::FromArgb(255, 0x2B, 0x2B, 0x35)
$HairShadow = [Drawing.Color]::FromArgb(255, 0x77, 0x7D, 0x8B)
$HairMid = [Drawing.Color]::FromArgb(255, 0xAE, 0xB4, 0xC1)
$HairLight = [Drawing.Color]::FromArgb(255, 0xD8, 0xDC, 0xE4)
$CoatOutline = [Drawing.Color]::FromArgb(255, 0x2A, 0x1B, 0x23)
$CoatShadow = [Drawing.Color]::FromArgb(255, 0x72, 0x2B, 0x39)
$CoatMid = [Drawing.Color]::FromArgb(255, 0x98, 0x3D, 0x4B)
$CoatLight = [Drawing.Color]::FromArgb(255, 0xB1, 0x55, 0x60)
$InnerDark = [Drawing.Color]::FromArgb(255, 0x22, 0x20, 0x28)

function Add-SpanToMask {
    param([bool[]]$Mask, [int]$Y, [int]$StartX, [int]$EndX)
    if ($Y -lt 0 -or $Y -ge 32) { return }
    for ($x = [Math]::Max(0, $StartX); $x -le [Math]::Min(31, $EndX); $x++) {
        $Mask[$Y * 32 + $x] = $true
    }
}

function New-HairMask {
    param([ValidateSet('Down','Side','Up')][string]$Direction, [int]$Phase)

    $mask = [bool[]]::new(32 * 32)
    $cap = @(
        @(2, 13, 18), @(3, 10, 21), @(4, 8, 23), @(5, 7, 24),
        @(6, 6, 25), @(7, 5, 26), @(8, 5, 27), @(9, 5, 27),
        @(10, 5, 27)
    )
    foreach ($span in $cap) { Add-SpanToMask -Mask $mask -Y $span[0] -StartX $span[1] -EndX $span[2] }

    if ($Direction -eq 'Down') {
        foreach ($span in @(
            @(11, 5, 12), @(11, 18, 27), @(12, 5, 12), @(12, 17, 27),
            @(13, 5, 11), @(13, 16, 26), @(14, 5, 10), @(14, 15, 17), @(14, 23, 26),
            @(15, 5, 9), @(15, 14, 16), @(15, 24, 26), @(16, 5, 9), @(16, 13, 15), @(16, 24, 26),
            @(17, 5, 8), @(17, 12, 14), @(17, 24, 26), @(18, 5, 8), @(18, 12, 13), @(18, 24, 26),
            @(19, 5, 8), @(19, 24, 26), @(20, 5, 8), @(20, 24, 26),
            @(21, 5, 8), @(21, 24, 25), @(22, 5, 8), @(23, 6, 8), @(24, 7, 7)
        )) { Add-SpanToMask -Mask $mask -Y ($span[0] + $Phase) -StartX $span[1] -EndX $span[2] }
    }
    elseif ($Direction -eq 'Side') {
        foreach ($span in @(
            @(11, 5, 17), @(11, 22, 27), @(12, 5, 17), @(12, 21, 27),
            @(13, 5, 16), @(13, 21, 27), @(14, 5, 15), @(14, 20, 27),
            @(15, 5, 14), @(15, 20, 27), @(16, 5, 13), @(16, 20, 27),
            @(17, 5, 12), @(17, 21, 27), @(18, 5, 12), @(18, 21, 27),
            @(19, 5, 11), @(19, 22, 27), @(20, 5, 11), @(20, 22, 27),
            @(21, 5, 10), @(21, 23, 27), @(22, 5, 10), @(22, 23, 27),
            @(23, 5, 9), @(23, 24, 27), @(24, 6, 9), @(24, 24, 26),
            @(25, 7, 8), @(25, 25, 25)
        )) { Add-SpanToMask -Mask $mask -Y ($span[0] + $Phase) -StartX $span[1] -EndX $span[2] }
    }
    else {
        foreach ($span in @(
            @(11, 5, 27), @(12, 5, 27), @(13, 5, 27), @(14, 5, 27),
            @(15, 5, 27), @(16, 5, 27), @(17, 5, 27), @(18, 5, 27),
            @(19, 5, 26), @(20, 5, 26), @(21, 6, 25), @(22, 6, 25),
            @(23, 7, 24), @(24, 8, 12), @(24, 14, 17), @(24, 19, 23),
            @(25, 9, 11), @(25, 15, 17), @(25, 20, 22),
            @(26, 10, 10), @(26, 16, 16), @(26, 21, 21)
        )) { Add-SpanToMask -Mask $mask -Y ($span[0] + $Phase) -StartX $span[1] -EndX $span[2] }
        # Keep the back silhouette deliberately uneven: layered hair is not a helmet dome.
        Add-SpanToMask -Mask $mask -Y (19 + $Phase) -StartX 4 -EndX 4
        Add-SpanToMask -Mask $mask -Y (22 + $Phase) -StartX 4 -EndX 5
        Add-SpanToMask -Mask $mask -Y (24 + $Phase) -StartX 6 -EndX 6
        Add-SpanToMask -Mask $mask -Y (25 + $Phase) -StartX 23 -EndX 24
    }
    return $mask
}

function Rebuild-NormalHead {
    param(
        [Drawing.Bitmap]$Official,
        [Drawing.Bitmap]$Output,
        [int]$CellX,
        [ValidateSet('Down','Side','Up')][string]$Direction,
        [int]$Phase
    )

    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $Output.SetPixel($CellX + $x, $y, $Official.GetPixel($CellX + $x, $y))
        }
    }

    $hair = New-HairMask -Direction $Direction -Phase $Phase

    # Remove the vanilla circular lower rim outside the face/chin and the owned hair locks.
    for ($y = 23; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $keepChin = $x -ge 11 -and $x -le 21 -and $y -le 26
            if (-not $hair[$y * 32 + $x] -and -not $keepChin) {
                $Output.SetPixel($CellX + $x, $y, $Transparent)
            }
        }
    }

    # Outline only the hair silhouette. Interior face pixels remain the official Isaac-scale face.
    for ($y = 1; $y -lt 31; $y++) {
        for ($x = 1; $x -lt 31; $x++) {
            if ($hair[$y * 32 + $x]) { continue }
            $nearHair = $false
            foreach ($offset in @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))) {
                if ($hair[($y + $offset[1]) * 32 + ($x + $offset[0])]) { $nearHair = $true; break }
            }
            if ($nearHair -and $Output.GetPixel($CellX + $x, $y).A -eq 0) {
                $Output.SetPixel($CellX + $x, $y, $HairOutline)
            }
        }
    }

    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            if (-not $hair[$y * 32 + $x]) { continue }
            $shade = $HairMid
            if ($x -le 8 -or $x -ge 25 -or $y -ge 21) { $shade = $HairShadow }
            elseif ((($x + 2 * $y + $Phase) % 9) -le 1) { $shade = $HairLight }
            $Output.SetPixel($CellX + $x, $y, $shade)
        }
    }

    # Dark separation lines make the part and locks readable at native 1x without closing the face.
    if ($Direction -eq 'Down') {
        foreach ($point in @(@(16, 3), @(16, 4), @(16, 5), @(16, 6), @(16, 7), @(15, 8), @(15, 9), @(15, 10))) {
            $Output.SetPixel($CellX + $point[0], $point[1], $HairOutline)
        }
    }
    elseif ($Direction -eq 'Side') {
        foreach ($point in @(@(18, 5), @(19, 6), @(20, 7), @(21, 8), @(22, 9), @(22, 10), @(21, 11))) {
            $Output.SetPixel($CellX + $point[0], $point[1], $HairOutline)
        }
    }
    else {
        foreach ($point in @(@(16, 3), @(16, 4), @(16, 5), @(16, 6), @(16, 7), @(16, 8), @(16, 9), @(16, 10), @(16, 11), @(16, 12))) {
            $Output.SetPixel($CellX + $point[0], $point[1], $HairOutline)
        }
    }
}

function Rebuild-NormalBody {
    param([Drawing.Bitmap]$Official, [Drawing.Bitmap]$Output, [int]$CellX, [int]$CellY)

    $bottom = -1
    for ($y = 0; $y -lt 32; $y++) {
        for ($x = 0; $x -lt 32; $x++) {
            $source = $Official.GetPixel($CellX + $x, $CellY + $y)
            if ($source.A -eq 0) {
                $Output.SetPixel($CellX + $x, $CellY + $y, $Transparent)
                continue
            }
            $bottom = [Math]::Max($bottom, $y)
            $isBoundary = $false
            foreach ($offset in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
                $nearX = $x + $offset[0]
                $nearY = $y + $offset[1]
                if ($nearX -lt 0 -or $nearX -ge 32 -or $nearY -lt 0 -or $nearY -ge 32 -or
                    $Official.GetPixel($CellX + $nearX, $CellY + $nearY).A -eq 0) {
                    $isBoundary = $true
                    break
                }
            }
            $color = $InnerDark
            if ($isBoundary) { $color = $CoatOutline }
            elseif ($x -le 11 -or $x -ge 20) {
                $color = if ((($x + $y) % 7) -eq 0) { $CoatLight } else { $CoatMid }
            }
            $Output.SetPixel($CellX + $x, $CellY + $y, $color)
        }
    }

    if ($bottom -lt 22) { throw "Normal body cell $CellX,$CellY has no reveal band" }
    for ($y = 22; $y -le $bottom; $y++) {
        $first = -1
        $last = -1
        for ($x = 0; $x -lt 32; $x++) {
            if ($Official.GetPixel($CellX + $x, $CellY + $y).A -gt 0) {
                if ($first -lt 0) { $first = $x }
                $last = $x
            }
        }
        if ($first -lt 2 -or $last -gt 29) { throw "No safe coat-tail margin in $CellX,$CellY row $y" }
        $Output.SetPixel($CellX + $first - 2, $CellY + $y, $CoatMid)
        $Output.SetPixel($CellX + $first - 1, $CellY + $y, $CoatLight)
        $Output.SetPixel($CellX + $last + 1, $CellY + $y, $CoatLight)
        $Output.SetPixel($CellX + $last + 2, $CellY + $y, $CoatMid)
    }
}

function Add-RegionSilhouette {
    param(
        [Drawing.Bitmap]$Official,
        [Drawing.Bitmap]$Output,
        [int]$RegionX, [int]$RegionY, [int]$Width, [int]$Height,
        [bool]$PreferHair
    )

    $safeRows = @()
    for ($localY = 0; $localY -lt $Height; $localY++) {
        $first = -1
        $last = -1
        for ($localX = 0; $localX -lt $Width; $localX++) {
            if ($Official.GetPixel($RegionX + $localX, $RegionY + $localY).A -gt 0) {
                if ($first -lt 0) { $first = $localX }
                $last = $localX
            }
        }
        if ($first -ge 2 -and $last -le ($Width - 3)) {
            $safeRows += @{ Y = $localY; First = $first; Last = $last }
        }
    }

    $rowCount = if ($Width -eq 64) { 8 } else { 4 }
    if ($safeRows.Count -lt $rowCount) {
        throw "Region $RegionX,$RegionY,$Width,$Height has only $($safeRows.Count) safe silhouette rows"
    }

    $selected = [Collections.Generic.HashSet[int]]::new()
    for ($index = 0; $index -lt $rowCount; $index++) {
        $candidate = [int][Math]::Floor((($index + 1) * $safeRows.Count) / ($rowCount + 1))
        while ($selected.Contains($candidate) -and $candidate -lt ($safeRows.Count - 1)) { $candidate++ }
        [void]$selected.Add($candidate)
        $row = $safeRows[$candidate]
        $isHairRow = $PreferHair -and $index -lt [Math]::Ceiling($rowCount / 2)
        $inner = if ($isHairRow) { $HairShadow } else { $CoatShadow }
        $outer = if ($isHairRow) { $HairMid } else { $CoatOutline }
        $Output.SetPixel($RegionX + $row.First - 2, $RegionY + $row.Y, $outer)
        $Output.SetPixel($RegionX + $row.First - 1, $RegionY + $row.Y, $inner)
        $Output.SetPixel($RegionX + $row.Last + 1, $RegionY + $row.Y, $inner)
        $Output.SetPixel($RegionX + $row.Last + 2, $RegionY + $row.Y, $outer)
    }
}

function Test-IsFaceSkinPixel {
    param([Drawing.Color]$Pixel)
    return $Pixel.A -gt 0 -and $Pixel.R -ge 150 -and $Pixel.G -ge 100 -and $Pixel.B -ge 90 -and
        $Pixel.R -ge ($Pixel.G + 15) -and $Pixel.R -le ($Pixel.G + 100)
}

function Add-HairToLargestFace {
    param([Drawing.Bitmap]$Output, [int]$RegionX, [int]$RegionY, [int]$Width, [int]$Height)

    $candidate = [bool[]]::new($Width * $Height)
    for ($localY = 0; $localY -lt $Height; $localY++) {
        for ($localX = 0; $localX -lt $Width; $localX++) {
            $pixel = $Output.GetPixel($RegionX + $localX, $RegionY + $localY)
            $maximum = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
            $minimum = [Math]::Min($pixel.R, [Math]::Min($pixel.G, $pixel.B))
            $knownHair = ($pixel.R -eq 0x77 -and $pixel.G -eq 0x7D -and $pixel.B -eq 0x8B) -or
                ($pixel.R -eq 0xAE -and $pixel.G -eq 0xB4 -and $pixel.B -eq 0xC1) -or
                ($pixel.R -eq 0xD8 -and $pixel.G -eq 0xDC -and $pixel.B -eq 0xE4)
            $neutralGlitchFace = $pixel.A -gt 0 -and $maximum -ge 100 -and ($maximum - $minimum) -le 70 -and -not $knownHair
            $candidate[$localY * $Width + $localX] = (Test-IsFaceSkinPixel -Pixel $pixel) -or $neutralGlitchFace
        }
    }

    $visited = [bool[]]::new($Width * $Height)
    $largest = [Collections.Generic.List[int]]::new()
    for ($start = 0; $start -lt $candidate.Length; $start++) {
        if (-not $candidate[$start] -or $visited[$start]) { continue }
        $queue = [Collections.Generic.Queue[int]]::new()
        $component = [Collections.Generic.List[int]]::new()
        $queue.Enqueue($start)
        $visited[$start] = $true
        while ($queue.Count -gt 0) {
            $current = $queue.Dequeue()
            $component.Add($current)
            $cy = [int][Math]::Floor($current / $Width)
            $cx = $current % $Width
            foreach ($offset in @(@(-1,0),@(1,0),@(0,-1),@(0,1))) {
                $nx = $cx + $offset[0]
                $ny = $cy + $offset[1]
                if ($nx -lt 0 -or $nx -ge $Width -or $ny -lt 0 -or $ny -ge $Height) { continue }
                $next = $ny * $Width + $nx
                if ($candidate[$next] -and -not $visited[$next]) {
                    $visited[$next] = $true
                    $queue.Enqueue($next)
                }
            }
        }
        if ($component.Count -gt $largest.Count) { $largest = $component }
    }
    if ($largest.Count -lt 6) { throw "No usable face component in $RegionX,$RegionY,$Width,$Height" }

    $minX = $Width; $minY = $Height; $maxX = -1; $maxY = -1
    foreach ($index in $largest) {
        $y = [int][Math]::Floor($index / $Width)
        $x = $index % $Width
        $minX = [Math]::Min($minX, $x); $maxX = [Math]::Max($maxX, $x)
        $minY = [Math]::Min($minY, $y); $maxY = [Math]::Max($maxY, $y)
    }
    $faceWidth = $maxX - $minX + 1
    $faceHeight = $maxY - $minY + 1
    $centerX = [int][Math]::Floor(($minX + $maxX) / 2)

    $nearFace = [bool[]]::new($Width * $Height)
    foreach ($index in $largest) { $nearFace[$index] = $true }
    for ($pass = 0; $pass -lt 6; $pass++) {
        $expanded = [bool[]]$nearFace.Clone()
        for ($y = 1; $y -lt ($Height - 1); $y++) {
            for ($x = 1; $x -lt ($Width - 1); $x++) {
                if (-not $nearFace[$y * $Width + $x]) { continue }
                foreach ($offset in @(@(-1,0),@(1,0),@(0,-1),@(0,1),@(-1,-1),@(1,-1),@(-1,1),@(1,1))) {
                    $expanded[($y + $offset[1]) * $Width + ($x + $offset[0])] = $true
                }
            }
        }
        $nearFace = $expanded
    }

    $hair = [bool[]]::new($Width * $Height)
    $marginX = [Math]::Max(4, [int][Math]::Ceiling($faceWidth * 0.45))
    $marginTop = [Math]::Max(5, [int][Math]::Ceiling($faceHeight * 0.55))
    $outerLeft = [Math]::Max(1, $minX - $marginX)
    $outerRight = [Math]::Min($Width - 2, $maxX + $marginX)
    $capTop = [Math]::Max(1, $minY - $marginTop)
    $capBottom = [Math]::Min($Height - 2, $minY + [int][Math]::Ceiling($faceHeight * 0.25))
    for ($y = $capTop; $y -le $capBottom; $y++) {
        $inset = [Math]::Max(0, 2 - ($y - $capTop))
        for ($x = $outerLeft + $inset; $x -le $outerRight - $inset; $x++) {
            if ($nearFace[$y * $Width + $x]) { $hair[$y * $Width + $x] = $true }
        }
    }

    $lockBottom = [Math]::Min($Height - 2, $maxY + 4)
    for ($y = [Math]::Max($capTop, $minY - 1); $y -le $lockBottom; $y++) {
        $leftWidth = [Math]::Max(1, $marginX - [int][Math]::Floor(($y - $minY + 1) / 5))
        for ($x = [Math]::Max(1, $minX - $leftWidth); $x -le ($minX - 1); $x++) {
            if ($nearFace[$y * $Width + $x]) { $hair[$y * $Width + $x] = $true }
        }
        if ($y -le ($maxY + 2)) {
            for ($x = ($maxX + 1); $x -le [Math]::Min($Width - 2, $maxX + [Math]::Max(2, $marginX - 1)); $x++) {
                if ($nearFace[$y * $Width + $x]) { $hair[$y * $Width + $x] = $true }
            }
        }
    }

    $bangDepth = [Math]::Max(3, [int][Math]::Ceiling($faceHeight * 0.45))
    for ($step = 0; $step -lt $bangDepth; $step++) {
        $y = $minY + $step
        if ($y -ge $Height) { break }
        for ($x = [Math]::Max($minX, $centerX - 3 + [int][Math]::Floor($step / 3)); $x -le ($centerX - 1); $x++) {
            if ($nearFace[$y * $Width + $x]) { $hair[$y * $Width + $x] = $true }
        }
        for ($x = ($centerX + 2); $x -le [Math]::Min($maxX, $centerX + 3 - [int][Math]::Floor($step / 4)); $x++) {
            if ($nearFace[$y * $Width + $x]) { $hair[$y * $Width + $x] = $true }
        }
    }

    for ($y = 1; $y -lt ($Height - 1); $y++) {
        for ($x = 1; $x -lt ($Width - 1); $x++) {
            if (-not $hair[$y * $Width + $x]) { continue }
            $existing = $Output.GetPixel($RegionX + $x, $RegionY + $y)
            $maximum = [Math]::Max($existing.R, [Math]::Max($existing.G, $existing.B))
            $protectedFeature = $x -ge $minX -and $x -le $maxX -and $y -ge $minY -and $y -le $maxY -and $maximum -le 75
            if ($protectedFeature) { continue }
            $shade = $HairMid
            if ($x -le ($minX - 1) -or $x -ge ($maxX + 1) -or $y -ge ($maxY + 1)) { $shade = $HairShadow }
            elseif ((($x + 2 * $y) % 8) -le 1) { $shade = $HairLight }
            $Output.SetPixel($RegionX + $x, $RegionY + $y, $shade)
        }
    }

    for ($y = 1; $y -lt ($Height - 1); $y++) {
        for ($x = 1; $x -lt ($Width - 1); $x++) {
            if ($hair[$y * $Width + $x] -or $Output.GetPixel($RegionX + $x, $RegionY + $y).A -gt 0) { continue }
            $nearHair = $hair[$y * $Width + $x - 1] -or $hair[$y * $Width + $x + 1] -or
                $hair[($y - 1) * $Width + $x] -or $hair[($y + 1) * $Width + $x]
            if ($nearHair) { $Output.SetPixel($RegionX + $x, $RegionY + $y, $HairOutline) }
        }
    }
}

function Test-IsExactHairPalettePixel {
    param([Drawing.Color]$Pixel)
    return $Pixel.A -gt 0 -and (
        ($Pixel.R -eq 0x77 -and $Pixel.G -eq 0x7D -and $Pixel.B -eq 0x8B) -or
        ($Pixel.R -eq 0xAE -and $Pixel.G -eq 0xB4 -and $Pixel.B -eq 0xC1) -or
        ($Pixel.R -eq 0xD8 -and $Pixel.G -eq 0xDC -and $Pixel.B -eq 0xE4)
    )
}

function Reset-OwnedDanteRegion {
    param(
        [Drawing.Bitmap]$Official, [Drawing.Bitmap]$Output,
        [int]$RegionX, [int]$RegionY, [int]$Width, [int]$Height
    )
    for ($localY = 0; $localY -lt $Height; $localY++) {
        for ($localX = 0; $localX -lt $Width; $localX++) {
            $source = $Official.GetPixel($RegionX + $localX, $RegionY + $localY)
            $target = $Output.GetPixel($RegionX + $localX, $RegionY + $localY)
            if ($source.A -eq 0) {
                $Output.SetPixel($RegionX + $localX, $RegionY + $localY, $Transparent)
            }
            elseif (Test-IsExactHairPalettePixel -Pixel $target) {
                $Output.SetPixel($RegionX + $localX, $RegionY + $localY, $source)
            }
        }
    }
}

$official = Open-BitmapCopy -Path $officialAtlasPath
$output = Open-BitmapCopy -Path $danteAtlasPath
try {
    if ($official.Width -ne 512 -or $official.Height -ne 512 -or
        $output.Width -ne 512 -or $output.Height -ne 512) {
        throw 'Official and Dante player atlases must both remain 512x512'
    }

    $resetRegions = @()
    $resetRegions += ,@(448, 0, 32, 32)
    $resetRegions += ,@(480, 0, 32, 32)
    foreach ($y in @(32,64)) {
        foreach ($x in @(256,288,320,352,384,416,448,480)) { $resetRegions += ,@($x,$y,32,32) }
    }
    $resetRegions += ,@(256,96,32,32)
    $resetRegions += ,@(288,96,32,32)
    foreach ($origin in @(
        @(0,128),@(64,128),@(128,128),@(192,130),
        @(0,192),@(64,192),@(128,192),@(192,192),
        @(0,256),@(64,256),@(128,256),@(192,256)
    )) { $resetRegions += ,@($origin[0],$origin[1],64,64) }
    $resetRegions += ,@(256,128,64,64)
    foreach ($origin in @(@(16,336),@(48,336),@(80,336),@(16,368),@(48,368),@(80,368),@(16,400))) {
        $resetRegions += ,@($origin[0],$origin[1],32,32)
    }
    foreach ($region in $resetRegions) {
        Reset-OwnedDanteRegion -Official $official -Output $output `
            -RegionX $region[0] -RegionY $region[1] -Width $region[2] -Height $region[3]
    }

    # Normal movement hair now belongs to costume_dante_hair.anm2. Restore the six
    # base-head crops exactly so the independent overlay cannot double with baked hair.
    foreach ($cellX in @(0, 32, 64, 96, 128, 160)) {
        for ($localY = 0; $localY -lt 32; $localY++) {
            for ($localX = 0; $localX -lt 32; $localX++) {
                $output.SetPixel($cellX + $localX, $localY, $official.GetPixel($cellX + $localX, $localY))
            }
        }
    }

    foreach ($cell in @(
        @(192, 0), @(224, 0),
        @(0, 32), @(32, 32), @(64, 32), @(96, 32), @(128, 32), @(160, 32), @(192, 32), @(224, 32),
        @(0, 64), @(32, 64), @(64, 64), @(96, 64), @(128, 64), @(160, 64), @(192, 64), @(224, 64),
        @(0, 96), @(32, 96)
    )) {
        Rebuild-NormalBody -Official $official -Output $output -CellX $cell[0] -CellY $cell[1]
    }

    $extraRegions = @(
        @(448, 0, 32, 32, $true), @(480, 0, 32, 32, $true)
    )
    foreach ($y in @(32, 64)) {
        foreach ($x in @(256, 288, 320, 352, 384, 416, 448, 480)) {
            $extraRegions += ,@($x, $y, 32, 32, $false)
        }
    }
    $extraRegions += ,@(256, 96, 32, 32, $false)
    $extraRegions += ,@(288, 96, 32, 32, $false)
    foreach ($origin in @(
        @(0, 128), @(64, 128), @(128, 128), @(192, 130),
        @(0, 192), @(64, 192), @(128, 192), @(192, 192),
        @(0, 256), @(64, 256), @(128, 256), @(192, 256)
    )) {
        $extraRegions += ,@($origin[0], $origin[1], 64, 64, $true)
    }
    if ($extraRegions.Count -ne 32) { throw "Expected 32 extra/special owner regions, got $($extraRegions.Count)" }
    foreach ($region in $extraRegions) {
        Add-RegionSilhouette -Official $official -Output $output `
            -RegionX $region[0] -RegionY $region[1] -Width $region[2] -Height $region[3] -PreferHair $region[4]
    }

    $headBearingRegions = @()
    $headBearingRegions += ,@(256, 128, 64, 64)
    foreach ($origin in @(@(16,336),@(48,336),@(80,336),@(16,368),@(48,368),@(80,368),@(16,400))) {
        $headBearingRegions += ,@($origin[0], $origin[1], 32, 32)
    }
    foreach ($origin in @(
        @(0,128),@(64,128),@(128,128),@(192,130),
        @(0,192),@(64,192),@(128,192),@(192,192),
        @(0,256),@(64,256),@(128,256),@(192,256)
    )) {
        $headBearingRegions += ,@($origin[0], $origin[1], 64, 64)
    }
    foreach ($region in $headBearingRegions) {
        Add-HairToLargestFace -Output $output -RegionX $region[0] -RegionY $region[1] -Width $region[2] -Height $region[3]
    }

    Save-PngAtomically -Bitmap $output -Path $danteAtlasPath
}
finally {
    $official.Dispose()
    $output.Dispose()
}

Write-Output 'Rebuilt Dante full base atlas: 14 head regions, 20 normal body regions, 32 extra/special regions'
