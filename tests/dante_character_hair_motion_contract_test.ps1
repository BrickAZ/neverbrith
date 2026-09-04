param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
$Root = [IO.Path]::GetFullPath($Root)
$hairPath = Join-Path $Root 'resources\gfx\characters\costumes\costume_dante_hair.png'
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

function Measure-HairFrame {
    param([Drawing.Bitmap]$Bitmap, [int]$FrameIndex)
    $visible = [bool[]]::new(4096)
    $rowMin = [int[]]::new(64)
    $rowMax = [int[]]::new(64)
    for ($y = 0; $y -lt 64; $y++) { $rowMin[$y] = -1; $rowMax[$y] = -1 }

    $count = 0
    $sumX = 0.0
    $sumY = 0.0
    $originX = $FrameIndex * 64
    for ($y = 0; $y -lt 64; $y++) {
        for ($x = 0; $x -lt 64; $x++) {
            if ($Bitmap.GetPixel($originX + $x, $y).A -eq 0) { continue }
            $visible[$y * 64 + $x] = $true
            $count++
            $sumX += $x
            $sumY += $y
            if ($rowMin[$y] -eq -1 -or $x -lt $rowMin[$y]) { $rowMin[$y] = $x }
            if ($x -gt $rowMax[$y]) { $rowMax[$y] = $x }
        }
    }
    Assert-True ($count -gt 0) "Dante hair frame $FrameIndex is blank"

    return [pscustomobject]@{
        Visible = $visible
        Count = $count
        CentroidX = $sumX / $count
        CentroidY = $sumY / $count
        RowMin = $rowMin
        RowMax = $rowMax
    }
}

$pairs = @(
    [pscustomobject]@{ Name='Down';  A=0; B=1; MinAlphaXor=48; MinDeltaY=0.50; MaxDeltaY=2.25; MinRows=8  },
    [pscustomobject]@{ Name='Right'; A=2; B=3; MinAlphaXor=64; MinDeltaY=0.75; MaxDeltaY=2.50; MinRows=12 },
    [pscustomobject]@{ Name='Up';    A=4; B=5; MinAlphaXor=96; MinDeltaY=0.75; MaxDeltaY=2.75; MinRows=14 },
    [pscustomobject]@{ Name='Left';  A=6; B=7; MinAlphaXor=64; MinDeltaY=0.75; MaxDeltaY=2.50; MinRows=12 }
)

$hair = Open-BitmapCopy -Path $hairPath
try {
    Assert-True ($hair.Width -eq 512 -and $hair.Height -eq 64) `
        "Dante hair sheet is $($hair.Width)x$($hair.Height), expected 512x64"

    foreach ($pair in $pairs) {
        $a = Measure-HairFrame -Bitmap $hair -FrameIndex $pair.A
        $b = Measure-HairFrame -Bitmap $hair -FrameIndex $pair.B
        $alphaXor = 0
        for ($index = 0; $index -lt 4096; $index++) {
            if ($a.Visible[$index] -xor $b.Visible[$index]) { $alphaXor++ }
        }
        $centroidDeltaY = $b.CentroidY - $a.CentroidY
        $rowsWithEdgeChange = 0
        for ($y = 0; $y -lt 64; $y++) {
            if ($a.RowMin[$y] -ne $b.RowMin[$y] -or $a.RowMax[$y] -ne $b.RowMax[$y]) {
                $rowsWithEdgeChange++
            }
        }

        $summary = "$($pair.Name): alphaXor=$alphaXor centroidDeltaY=$([Math]::Round($centroidDeltaY,3)) rowsWithEdgeChange=$rowsWithEdgeChange"
        Write-Output $summary
        Assert-True ($alphaXor -ge $pair.MinAlphaXor) `
            "$summary; A/B silhouette is too rigid (minimum alphaXor=$($pair.MinAlphaXor))"
        Assert-True ($centroidDeltaY -ge $pair.MinDeltaY -and $centroidDeltaY -le $pair.MaxDeltaY) `
            "$summary; vertical motion must stay in $($pair.MinDeltaY)..$($pair.MaxDeltaY) pixels"
        Assert-True ($rowsWithEdgeChange -ge $pair.MinRows) `
            "$summary; too few silhouette rows change (minimum=$($pair.MinRows))"
    }
}
finally { $hair.Dispose() }

Write-Output 'Dante hair restrained-motion regression passed; native-1x visual review is still required'
