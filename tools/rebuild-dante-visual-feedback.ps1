param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$gameRoot = Split-Path -Parent (Split-Path -Parent $Root)
$officialAtlasPath = Join-Path $gameRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
$danteAtlasPath = Join-Path $Root 'resources\gfx\characters\costumes\character_dante.png'
$danteNamePath = Join-Path $Root 'resources\gfx\UI\boss\playername_dante.png'
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
    $temporary = Join-Path $directory ('.codex-dante-feedback-' + [guid]::NewGuid().ToString('N') + '.png')
    try {
        $Bitmap.Save($temporary, [Drawing.Imaging.ImageFormat]::Png)
        Move-Item -LiteralPath $temporary -Destination $Path -Force
    }
    finally {
        if (Test-Path -LiteralPath $temporary) { Remove-Item -LiteralPath $temporary -Force }
    }
}

function Rebuild-PlayerName {
    param([string]$Path)

    $source = Open-BitmapCopy -Path $Path
    try {
        if ($source.Width -ne 192 -or $source.Height -ne 64) {
            throw "Dante player-name must be 192x64 before rebuild, got $($source.Width)x$($source.Height)"
        }
        $fill = [bool[]]::new($source.Width * $source.Height)
        for ($y = 0; $y -lt $source.Height; $y++) {
            for ($x = 0; $x -lt $source.Width; $x++) {
                $pixel = $source.GetPixel($x, $y)
                $maximum = [Math]::Max($pixel.R, [Math]::Max($pixel.G, $pixel.B))
                if ($pixel.A -gt 0 -and $maximum -gt 80) { $fill[$y * $source.Width + $x] = $true }
            }
        }

        $output = [Drawing.Bitmap]::new(192, 64, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        try {
            for ($y = 0; $y -lt $source.Height; $y++) {
                for ($x = 0; $x -lt $source.Width; $x++) {
                    if ($fill[$y * $source.Width + $x]) {
                        $output.SetPixel($x, $y, [Drawing.Color]::FromArgb(255, 0xC7, 0xB2, 0x99))
                        continue
                    }
                    $pixel = $source.GetPixel($x, $y)
                    if ($pixel.A -eq 0) { continue }

                    $orthogonal = 0
                    $diagonal = 0
                    foreach ($offset in @(@(-1, 0), @(1, 0), @(0, -1), @(0, 1))) {
                        $nearX = $x + $offset[0]
                        $nearY = $y + $offset[1]
                        if ($nearX -ge 0 -and $nearX -lt 192 -and $nearY -ge 0 -and $nearY -lt 64 -and
                            $fill[$nearY * 192 + $nearX]) { $orthogonal++ }
                    }
                    foreach ($offset in @(@(-1, -1), @(1, -1), @(-1, 1), @(1, 1))) {
                        $nearX = $x + $offset[0]
                        $nearY = $y + $offset[1]
                        if ($nearX -ge 0 -and $nearX -lt 192 -and $nearY -ge 0 -and $nearY -lt 64 -and
                            $fill[$nearY * 192 + $nearX]) { $diagonal++ }
                    }
                    if (($orthogonal -eq 0 -and $diagonal -gt 0) -or $orthogonal -ge 2) {
                        $output.SetPixel($x, $y, [Drawing.Color]::FromArgb(128, 0xC7, 0xB2, 0x99))
                    }
                }
            }
            Save-PngAtomically -Bitmap $output -Path $Path
        }
        finally { $output.Dispose() }
    }
    finally { $source.Dispose() }
}

function Expand-CoatSilhouette {
    param([string]$OfficialPath, [string]$DantePath)

    $official = Open-BitmapCopy -Path $OfficialPath
    $dante = Open-BitmapCopy -Path $DantePath
    try {
        if ($official.Width -ne 512 -or $official.Height -ne 512 -or
            $dante.Width -ne 512 -or $dante.Height -ne 512) {
            throw 'Official and Dante player atlases must both remain 512x512'
        }
        $outline = [Drawing.Color]::FromArgb(255, 0x27, 0x18, 0x1F)
        $coatShadow = [Drawing.Color]::FromArgb(255, 0x79, 0x2D, 0x3A)
        $cells = @(
            @{ X = 0; Y = 32 }, @{ X = 32; Y = 32 }, @{ X = 64; Y = 32 },
            @{ X = 96; Y = 32 }, @{ X = 128; Y = 32 }, @{ X = 160; Y = 32 },
            @{ X = 0; Y = 64 }, @{ X = 32; Y = 64 }, @{ X = 64; Y = 64 },
            @{ X = 96; Y = 64 }, @{ X = 128; Y = 64 }, @{ X = 160; Y = 64 }
        )

        foreach ($cell in $cells) {
            foreach ($localY in @(19, 20)) {
                $first = -1
                $last = -1
                for ($localX = 0; $localX -lt 32; $localX++) {
                    if ($official.GetPixel($cell.X + $localX, $cell.Y + $localY).A -gt 0) {
                        if ($first -lt 0) { $first = $localX }
                        $last = $localX
                    }
                }
                if ($first -le 0 -or $last -ge 31) {
                    throw "No safe coat-extension margin in body cell $($cell.X),$($cell.Y) row $localY"
                }
                $dante.SetPixel($cell.X + $first - 1, $cell.Y + $localY, $outline)
                $dante.SetPixel($cell.X + $last + 1, $cell.Y + $localY, $outline)
                $dante.SetPixel($cell.X + $first, $cell.Y + $localY, $coatShadow)
                $dante.SetPixel($cell.X + $last, $cell.Y + $localY, $coatShadow)
            }
        }
        Save-PngAtomically -Bitmap $dante -Path $DantePath
    }
    finally {
        $official.Dispose()
        $dante.Dispose()
    }
}

Rebuild-PlayerName -Path $danteNamePath
Expand-CoatSilhouette -OfficialPath $officialAtlasPath -DantePath $danteAtlasPath
Write-Output 'Rebuilt Dante player-name alpha style and controlled normal-body coat silhouette'
