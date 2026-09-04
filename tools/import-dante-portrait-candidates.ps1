param(
    [Parameter(Mandatory = $true)]
    [string]$StageCandidate,

    [Parameter(Mandatory = $true)]
    [string]$MenuCandidate,

    [string]$StageOutput = 'resources\gfx\ui\stage\playerportrait_dante.png',

    [string]$MenuOutput = 'content\gfx\dante_character_menu_portrait.png'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

Add-Type -AssemblyName System.Drawing

function Resolve-OutputPath {
    param([Parameter(Mandatory = $true)][string]$Path)

    if ([IO.Path]::IsPathRooted($Path)) {
        return [IO.Path]::GetFullPath($Path)
    }

    return [IO.Path]::GetFullPath((Join-Path (Get-Location) $Path))
}

function Open-BitmapCopy {
    param([Parameter(Mandatory = $true)][string]$Path)

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $source = [Drawing.Bitmap]::new($resolved)
    try {
        return [Drawing.Bitmap]::new($source)
    }
    finally {
        $source.Dispose()
    }
}

function Get-BgraBuffer {
    param([Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap)

    $rect = [Drawing.Rectangle]::new(0, 0, $Bitmap.Width, $Bitmap.Height)
    $data = $Bitmap.LockBits(
        $rect,
        [Drawing.Imaging.ImageLockMode]::ReadOnly,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )

    try {
        $stride = [Math]::Abs($data.Stride)
        $bytes = [byte[]]::new($stride * $Bitmap.Height)
        [Runtime.InteropServices.Marshal]::Copy($data.Scan0, $bytes, 0, $bytes.Length)
        return [pscustomobject]@{
            Bytes          = $bytes
            Stride         = $stride
            BottomUp       = $data.Stride -lt 0
            Width          = $Bitmap.Width
            Height         = $Bitmap.Height
        }
    }
    finally {
        $Bitmap.UnlockBits($data)
    }
}

function Get-ForegroundBounds {
    param(
        [Parameter(Mandatory = $true)]$Buffer,
        [Parameter(Mandatory = $true)][ValidateSet('StageAlpha', 'MenuBackdrop')][string]$Mode
    )

    $minX = $Buffer.Width
    $minY = $Buffer.Height
    $maxX = -1
    $maxY = -1

    for ($y = 0; $y -lt $Buffer.Height; $y++) {
        $sourceY = if ($Buffer.BottomUp) { $Buffer.Height - 1 - $y } else { $y }
        $row = $sourceY * $Buffer.Stride

        for ($x = 0; $x -lt $Buffer.Width; $x++) {
            $offset = $row + ($x * 4)
            $blue = [int]$Buffer.Bytes[$offset]
            $green = [int]$Buffer.Bytes[$offset + 1]
            $red = [int]$Buffer.Bytes[$offset + 2]
            $alpha = [int]$Buffer.Bytes[$offset + 3]

            if ($Mode -eq 'StageAlpha') {
                $foreground = $alpha -ge 8
            }
            else {
                $minimum = [Math]::Min($red, [Math]::Min($green, $blue))
                $maximum = [Math]::Max($red, [Math]::Max($green, $blue))
                $backdrop = $alpha -gt 0 -and $minimum -ge 220 -and ($maximum - $minimum) -le 14
                $foreground = $alpha -gt 0 -and -not $backdrop
            }

            if (-not $foreground) { continue }
            if ($x -lt $minX) { $minX = $x }
            if ($x -gt $maxX) { $maxX = $x }
            if ($y -lt $minY) { $minY = $y }
            if ($y -gt $maxY) { $maxY = $y }
        }
    }

    if ($maxX -lt $minX -or $maxY -lt $minY) {
        throw "Portrait candidate has no accepted foreground pixels for mode $Mode"
    }

    return [Drawing.Rectangle]::FromLTRB($minX, $minY, $maxX + 1, $maxY + 1)
}

function New-FittedBitmap {
    param(
        [Parameter(Mandatory = $true)][Drawing.Bitmap]$Source,
        [Parameter(Mandatory = $true)][Drawing.Rectangle]$Bounds,
        [Parameter(Mandatory = $true)][int]$CanvasWidth,
        [Parameter(Mandatory = $true)][int]$CanvasHeight,
        [Parameter(Mandatory = $true)][int]$MaximumWidth,
        [Parameter(Mandatory = $true)][int]$MaximumHeight
    )

    $scale = [Math]::Min($MaximumWidth / [double]$Bounds.Width, $MaximumHeight / [double]$Bounds.Height)
    $drawWidth = [Math]::Max(1, [int][Math]::Round($Bounds.Width * $scale))
    $drawHeight = [Math]::Max(1, [int][Math]::Round($Bounds.Height * $scale))
    $drawX = [int](($CanvasWidth - $drawWidth) / 2)
    $drawY = $CanvasHeight - 2 - $drawHeight
    $drawRect = [Drawing.Rectangle]::new($drawX, $drawY, $drawWidth, $drawHeight)

    $output = [Drawing.Bitmap]::new(
        $CanvasWidth,
        $CanvasHeight,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [Drawing.Graphics]::FromImage($output)
    try {
        $graphics.Clear([Drawing.Color]::Transparent)
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.CompositingQuality = [Drawing.Drawing2D.CompositingQuality]::HighSpeed
        $graphics.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::NearestNeighbor
        $graphics.PixelOffsetMode = [Drawing.Drawing2D.PixelOffsetMode]::Half
        $graphics.SmoothingMode = [Drawing.Drawing2D.SmoothingMode]::None
        $graphics.DrawImage($Source, $drawRect, $Bounds, [Drawing.GraphicsUnit]::Pixel)
    }
    finally {
        $graphics.Dispose()
    }

    return $output
}

function Convert-ChannelToLimitedPalette {
    param([Parameter(Mandatory = $true)][int]$Value)

    return [byte]([Math]::Max(0, [Math]::Min(255, [int][Math]::Round($Value / 17.0) * 17)))
}

function Test-ConnectedBackdrop {
    param([Parameter(Mandatory = $true)][Drawing.Color]$Color)

    if ($Color.A -eq 0) { return $true }
    $minimum = [Math]::Min($Color.R, [Math]::Min($Color.G, $Color.B))
    $maximum = [Math]::Max($Color.R, [Math]::Max($Color.G, $Color.B))
    return $minimum -ge 220 -and ($maximum - $minimum) -le 14
}

function Add-BackdropPixel {
    param(
        [Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][byte[]]$State,
        [Parameter(Mandatory = $true)][int[]]$Queue,
        [Parameter(Mandatory = $true)][ref]$Tail,
        [Parameter(Mandatory = $true)][int]$X,
        [Parameter(Mandatory = $true)][int]$Y
    )

    if ($X -lt 0 -or $Y -lt 0 -or $X -ge $Bitmap.Width -or $Y -ge $Bitmap.Height) { return }
    $index = ($Y * $Bitmap.Width) + $X
    if ($State[$index] -ne 0) { return }

    if (Test-ConnectedBackdrop -Color $Bitmap.GetPixel($X, $Y)) {
        $State[$index] = 1
        $Queue[$Tail.Value] = $index
        $Tail.Value++
    }
    else {
        $State[$index] = 2
    }
}

function Clean-StageBitmap {
    param([Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap)

    $visible = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $color = $Bitmap.GetPixel($x, $y)
            if ($color.A -lt 8) {
                $Bitmap.SetPixel($x, $y, [Drawing.Color]::Transparent)
                continue
            }

            $Bitmap.SetPixel($x, $y, [Drawing.Color]::FromArgb(
                255,
                (Convert-ChannelToLimitedPalette $color.R),
                (Convert-ChannelToLimitedPalette $color.G),
                (Convert-ChannelToLimitedPalette $color.B)
            ))
            $visible++
        }
    }

    return $visible
}

function Clean-MenuBitmap {
    param([Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap)

    $count = $Bitmap.Width * $Bitmap.Height
    $state = [byte[]]::new($count)
    $queue = [int[]]::new($count)
    $tail = 0

    for ($x = 0; $x -lt $Bitmap.Width; $x++) {
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X $x -Y 0
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X $x -Y ($Bitmap.Height - 1)
    }
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X 0 -Y $y
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X ($Bitmap.Width - 1) -Y $y
    }

    $head = 0
    while ($head -lt $tail) {
        $index = $queue[$head]
        $head++
        $x = $index % $Bitmap.Width
        $y = [int][Math]::Floor($index / [double]$Bitmap.Width)
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X ($x - 1) -Y $y
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X ($x + 1) -Y $y
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X $x -Y ($y - 1)
        Add-BackdropPixel -Bitmap $Bitmap -State $state -Queue $queue -Tail ([ref]$tail) -X $x -Y ($y + 1)
    }

    $visible = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $index = ($y * $Bitmap.Width) + $x
            $color = $Bitmap.GetPixel($x, $y)
            if ($state[$index] -eq 1 -or $color.A -eq 0) {
                $Bitmap.SetPixel($x, $y, [Drawing.Color]::Transparent)
                continue
            }

            $Bitmap.SetPixel($x, $y, [Drawing.Color]::FromArgb(
                255,
                (Convert-ChannelToLimitedPalette $color.R),
                (Convert-ChannelToLimitedPalette $color.G),
                (Convert-ChannelToLimitedPalette $color.B)
            ))
            $visible++
        }
    }

    return $visible
}

function Save-PngSafely {
    param(
        [Parameter(Mandatory = $true)][Drawing.Bitmap]$Bitmap,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory) { [IO.Directory]::CreateDirectory($directory) | Out-Null }
    $temporary = "$Path.codex-dante-portrait-$([guid]::NewGuid().ToString('N')).png"
    try {
        $Bitmap.Save($temporary, [Drawing.Imaging.ImageFormat]::Png)
        [IO.File]::Copy($temporary, $Path, $true)
    }
    finally {
        if (Test-Path -LiteralPath $temporary) {
            Remove-Item -LiteralPath $temporary -Force
        }
    }
}

$stage = Open-BitmapCopy -Path $StageCandidate
$menu = Open-BitmapCopy -Path $MenuCandidate
$stageExact = $null
$menuExact = $null
try {
    $stageBounds = Get-ForegroundBounds -Buffer (Get-BgraBuffer -Bitmap $stage) -Mode StageAlpha
    $menuBounds = Get-ForegroundBounds -Buffer (Get-BgraBuffer -Bitmap $menu) -Mode MenuBackdrop
    $stageExact = New-FittedBitmap -Source $stage -Bounds $stageBounds -CanvasWidth 144 -CanvasHeight 144 -MaximumWidth 116 -MaximumHeight 116
    $menuExact = New-FittedBitmap -Source $menu -Bounds $menuBounds -CanvasWidth 96 -CanvasHeight 96 -MaximumWidth 92 -MaximumHeight 92

    $stageVisible = Clean-StageBitmap -Bitmap $stageExact
    $menuVisible = Clean-MenuBitmap -Bitmap $menuExact
    Save-PngSafely -Bitmap $stageExact -Path (Resolve-OutputPath $StageOutput)
    Save-PngSafely -Bitmap $menuExact -Path (Resolve-OutputPath $MenuOutput)

    "stage source=$($stage.Width)x$($stage.Height) bbox=$stageBounds output=144x144 visible=$stageVisible; menu source=$($menu.Width)x$($menu.Height) bbox=$menuBounds output=96x96 visible=$menuVisible"
}
finally {
    if ($stageExact) { $stageExact.Dispose() }
    if ($menuExact) { $menuExact.Dispose() }
    $stage.Dispose()
    $menu.Dispose()
}
