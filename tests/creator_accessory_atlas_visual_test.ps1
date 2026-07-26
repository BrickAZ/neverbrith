param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Root = [IO.Path]::GetFullPath($Root)
$assets = @(
    @{ Name='tantan_hair'; Width=256; Height=64; Kind='hair'; Min=120; Max=700;
       Colors=@('#35282C','#92516B','#D97A9A','#F0A7B8') },
    @{ Name='tantan_glasses'; Width=256; Height=32; Kind='face'; Min=0; Max=130;
       Colors=@('#7A2D38','#B73C45','#E45A58') },
    @{ Name='daodao_hair'; Width=256; Height=64; Kind='hair'; Min=110; Max=680;
       Colors=@('#293247','#31486F','#4F6FA0','#7E98BC') },
    @{ Name='daodao_tissue_tears'; Width=256; Height=32; Kind='face'; Min=0; Max=150;
       Colors=@('#A9B0BA','#C7CCD2','#F1F1E8') },
    @{ Name='yoontoons_hair'; Width=256; Height=64; Kind='hair'; Min=110; Max=680;
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
            } elseif($cell -in 4,5) {
                Assert-True ($visible -eq 0) "$($asset.Name) back cell $cell must be blank"
            } else {
                Assert-True ($visible -gt 0 -and $visible -le $asset.Max) `
                    "$($asset.Name) cell $cell coverage $visible"
            }
        }
    } finally { $bitmap.Dispose() }
}

Write-Output 'creator accessory atlas visual contract passed'
