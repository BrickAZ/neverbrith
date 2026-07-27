param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Root = [IO.Path]::GetFullPath($Root)
$assets = @(
    @{ Name='tantan_hair'; Width=256; Height=64; Kind='hair'; Min=120; Max=300;
       Colors=@('#35282C','#92516B','#D97A9A','#F0A7B8') },
    @{ Name='tantan_glasses'; Width=256; Height=32; Kind='face'; Min=0; Max=130;
       Colors=@('#7A2D38','#B73C45','#E45A58') },
    @{ Name='daodao_hair'; Width=256; Height=64; Kind='hair'; Min=110; Max=300;
       Colors=@('#293247','#31486F','#4F6FA0','#7E98BC') },
    @{ Name='daodao_tissue_tears'; Width=256; Height=32; Kind='face'; Min=0; Max=150; AllowBlank=$true;
       Colors=@('#A9B0BA','#C7CCD2','#F1F1E8') },
    @{ Name='yoontoons_hair'; Width=256; Height=64; Kind='hair'; Min=110; Max=360;
       Colors=@('#202536','#30384D','#4C566D','#4A9BD1') },
    @{ Name='yoontoons_glasses'; Width=256; Height=32; Kind='face'; Min=0; Max=130;
       Colors=@('#873A35','#B94D3F','#E87955') }
)

function Assert-True([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw $Message }
}
function Open-BitmapCopy([string]$Path) {
    Assert-True (Test-Path -LiteralPath $Path) "missing atlas: $Path"
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) } finally { $source.Dispose() }
    } finally { $stream.Dispose() }
}
function Get-CellVisibleCount([Drawing.Bitmap]$Bitmap, [int]$Cell, [int]$CellHeight) {
    $count = 0
    for($y=0; $y -lt $CellHeight; $y++) {
        for($x=0; $x -lt 32; $x++) {
            if($Bitmap.GetPixel(($Cell*32)+$x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}
function Get-VisibleCount([Drawing.Bitmap]$Bitmap) {
    $count = 0
    for($y=0; $y -lt $Bitmap.Height; $y++) {
        for($x=0; $x -lt $Bitmap.Width; $x++) {
            if($Bitmap.GetPixel($x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}
function Get-RegionVisibleCount(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$StartX,
    [int]$EndX,
    [int]$StartY,
    [int]$EndY
) {
    $count=0
    for($y=$StartY; $y -le $EndY; $y++) {
        for($x=$StartX; $x -le $EndX; $x++) {
            if($Bitmap.GetPixel(($Cell*32)+$x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}

function Assert-RegionBlank(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$StartX,
    [int]$EndX,
    [int]$StartY,
    [int]$EndY,
    [string]$Message
) {
    Assert-True ((Get-RegionVisibleCount $Bitmap $Cell $StartX $EndX $StartY $EndY) -eq 0) $Message
}

foreach($asset in $assets) {
    $path = Join-Path $Root "resources\gfx\characters\costumes\costume_$($asset.Name).png"
    $bitmap = Open-BitmapCopy $path
    try {
        Assert-True ($bitmap.Width -eq $asset.Width -and $bitmap.Height -eq $asset.Height) `
            "$($asset.Name) canvas"
        $allowed = [Collections.Generic.HashSet[int]]::new()
        foreach($hex in $asset.Colors) {
            [void]$allowed.Add([Drawing.ColorTranslator]::FromHtml($hex).ToArgb())
        }
        for($y=0; $y -lt $bitmap.Height; $y++) {
            for($x=0; $x -lt $bitmap.Width; $x++) {
                $pixel = $bitmap.GetPixel($x,$y)
                Assert-True ($pixel.A -eq 0 -or $pixel.A -eq 255) "$($asset.Name) semi-alpha at $x,$y"
                if($pixel.A -eq 0) {
                    Assert-True ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0) `
                        "$($asset.Name) dirty transparent RGB at $x,$y"
                } else {
                    Assert-True ($allowed.Contains($pixel.ToArgb())) "$($asset.Name) palette at $x,$y"
                    Assert-True (-not ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0)) `
                        "$($asset.Name) pure black at $x,$y"
                }
            }
        }
        foreach($cell in 0..7) {
            $visible = Get-CellVisibleCount $bitmap $cell ($asset.Height)
            if($asset.Kind -eq 'hair') {
                Assert-True ($visible -ge $asset.Min -and $visible -le $asset.Max) `
                    "$($asset.Name) cell $cell coverage $visible"
            } elseif($asset.AllowBlank) {
                Assert-True ($visible -eq 0) "$($asset.Name) cell $cell must be blank"
            } elseif($cell -in 4,5) {
                Assert-True ($visible -eq 0) "$($asset.Name) back cell $cell must be blank"
            } else {
                Assert-True ($visible -gt 0 -and $visible -le $asset.Max) `
                    "$($asset.Name) cell $cell coverage $visible"
            }
        }
    } finally { $bitmap.Dispose() }
}

$tantanHair=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_tantan_hair.png')
$tantanGlasses=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_tantan_glasses.png')
$daodaoHair=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_daodao_hair.png')
$daodaoTissues=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_daodao_tissue_tears.png')
$yoonHair=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_yoontoons_hair.png')
$yoonGlasses=Open-BitmapCopy (Join-Path $Root 'resources\gfx\characters\costumes\costume_yoontoons_glasses.png')
try {
    Assert-True ((Get-VisibleCount $daodaoTissues) -eq 0) "Daodao tissue atlas must be fully transparent"
    foreach($cell in 0,1) {
        Assert-RegionBlank $tantanHair $cell 8 23 29 43 "Tantan front face must remain open"
        Assert-RegionBlank $daodaoHair $cell 8 23 29 43 "Daodao front face must remain open"
        Assert-RegionBlank $yoonHair $cell 8 23 29 43 "Yoontoons front face must remain open"
        Assert-True ((Get-CellVisibleCount $tantanGlasses $cell 32) -le 10) `
            "Tantan glasses cell $cell must remain a micro-rim cue"
        Assert-True ((Get-CellVisibleCount $yoonGlasses $cell 32) -le 10) `
            "Yoontoons glasses cell $cell must remain a micro-rim cue"
        Assert-RegionBlank $tantanGlasses $cell 13 18 10 18 `
            "Tantan glasses must not draw a center bridge"
        Assert-RegionBlank $yoonGlasses $cell 13 18 10 18 `
            "Yoontoons glasses must not draw a center bridge"
        Assert-True ((Get-RegionVisibleCount $yoonHair $cell 1 7 32 41) -gt 0) `
            "Yoontoons hair cell $cell needs a long left side lock"
        Assert-True ((Get-RegionVisibleCount $yoonHair $cell 24 30 32 41) -gt 0) `
            "Yoontoons hair cell $cell needs a long right side lock"
    }
} finally {
    $tantanHair.Dispose()
    $tantanGlasses.Dispose()
    $daodaoHair.Dispose()
    $daodaoTissues.Dispose()
    $yoonHair.Dispose()
    $yoonGlasses.Dispose()
}

Write-Output 'creator accessory atlas visual contract passed'
