param([string]$Root = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

$Root = [IO.Path]::GetFullPath($Root)
$outputDir = Join-Path $Root 'resources\gfx\characters\costumes'
$previewDir = Join-Path $Root 'reports'
[void](New-Item -ItemType Directory -Path $outputDir -Force)
[void](New-Item -ItemType Directory -Path $previewDir -Force)

$isaacRoot = Split-Path -Parent (Split-Path -Parent $Root)
$vanillaHeadPath = Join-Path $isaacRoot 'resources\gfx\characters\costumes\Character_001_Isaac.png'
if(-not (Test-Path -LiteralPath $vanillaHeadPath)) {
    throw "missing vanilla Isaac atlas: $vanillaHeadPath"
}

$palette = @{
    Clear=[Drawing.Color]::FromArgb(0,0,0,0)
    Outline=[Drawing.ColorTranslator]::FromHtml('#35282C')
    TantanDark=[Drawing.ColorTranslator]::FromHtml('#92516B')
    Tantan=[Drawing.ColorTranslator]::FromHtml('#D97A9A')
    TantanLight=[Drawing.ColorTranslator]::FromHtml('#F0A7B8')
    TantanGlassDark=[Drawing.ColorTranslator]::FromHtml('#7A2D38')
    TantanGlass=[Drawing.ColorTranslator]::FromHtml('#B73C45')
    TantanGlassLight=[Drawing.ColorTranslator]::FromHtml('#E45A58')
    DaodaoOutline=[Drawing.ColorTranslator]::FromHtml('#293247')
    DaodaoDark=[Drawing.ColorTranslator]::FromHtml('#31486F')
    Daodao=[Drawing.ColorTranslator]::FromHtml('#4F6FA0')
    DaodaoLight=[Drawing.ColorTranslator]::FromHtml('#7E98BC')
    TissueDark=[Drawing.ColorTranslator]::FromHtml('#A9B0BA')
    Tissue=[Drawing.ColorTranslator]::FromHtml('#C7CCD2')
    TissueLight=[Drawing.ColorTranslator]::FromHtml('#F1F1E8')
    YoonDark=[Drawing.ColorTranslator]::FromHtml('#202536')
    Yoon=[Drawing.ColorTranslator]::FromHtml('#30384D')
    YoonLight=[Drawing.ColorTranslator]::FromHtml('#4C566D')
    YoonBlue=[Drawing.ColorTranslator]::FromHtml('#4A9BD1')
    YoonGlassDark=[Drawing.ColorTranslator]::FromHtml('#873A35')
    YoonGlass=[Drawing.ColorTranslator]::FromHtml('#B94D3F')
    YoonGlassLight=[Drawing.ColorTranslator]::FromHtml('#E87955')
}

$views = @(
    @{ Name='front'; Source=0; Phase=0 }, @{ Name='front'; Source=32; Phase=1 },
    @{ Name='right'; Source=64; Phase=0 }, @{ Name='right'; Source=96; Phase=1 },
    @{ Name='back'; Source=128; Phase=0 }, @{ Name='back'; Source=160; Phase=1 }
)

function New-TransparentBitmap([int]$Width,[int]$Height) {
    $bitmap = [Drawing.Bitmap]::new(
        $Width,
        $Height,
        [Drawing.Imaging.PixelFormat]::Format32bppArgb
    )
    $graphics = [Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear([Drawing.Color]::FromArgb(0,0,0,0))
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Open-BitmapCopy([string]$Path) {
    $stream = [IO.File]::OpenRead($Path)
    try {
        $source = [Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) }
        finally { $source.Dispose() }
    } finally {
        $stream.Dispose()
    }
}

function Set-LocalPixel(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$CellWidth,
    [int]$X,
    [int]$Y,
    [Drawing.Color]$Color
) {
    if($Cell -lt 0 -or $X -lt 0 -or $X -ge $CellWidth -or
       $Y -lt 0 -or $Y -ge $Bitmap.Height) {
        throw "pixel outside atlas cell=$Cell x=$X y=$Y"
    }
    $globalX = ($Cell * $CellWidth) + $X
    if($globalX -lt 0 -or $globalX -ge $Bitmap.Width) {
        throw "pixel outside atlas x=$globalX"
    }
    $Bitmap.SetPixel($globalX,$Y,$Color)
}

function Fill-LocalSpan(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$CellWidth,
    [int]$StartX,
    [int]$EndX,
    [int]$Y,
    [Drawing.Color]$Color
) {
    if($EndX -lt $StartX) { throw "reversed span $StartX..$EndX" }
    for($x=$StartX; $x -le $EndX; $x++) {
        Set-LocalPixel $Bitmap $Cell $CellWidth $x $Y $Color
    }
}

function Fill-LocalRect(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [int]$CellWidth,
    [int]$StartX,
    [int]$StartY,
    [int]$EndX,
    [int]$EndY,
    [Drawing.Color]$Color
) {
    for($y=$StartY; $y -le $EndY; $y++) {
        Fill-LocalSpan $Bitmap $Cell $CellWidth $StartX $EndX $y $Color
    }
}

function Mirror-Cell(
    [Drawing.Bitmap]$Bitmap,
    [int]$SourceCell,
    [int]$TargetCell,
    [int]$CellWidth,
    [int]$CellHeight
) {
    for($y=0; $y -lt $CellHeight; $y++) {
        for($x=0; $x -lt $CellWidth; $x++) {
            $sourceX = ($SourceCell * $CellWidth) + $x
            $targetX = ($TargetCell * $CellWidth) + (($CellWidth - 1) - $x)
            $Bitmap.SetPixel($targetX,$y,$Bitmap.GetPixel($sourceX,$y))
        }
    }
}

function Normalize-TransparentPixels([Drawing.Bitmap]$Bitmap) {
    for($y=0; $y -lt $Bitmap.Height; $y++) {
        for($x=0; $x -lt $Bitmap.Width; $x++) {
            $pixel = $Bitmap.GetPixel($x,$y)
            if($pixel.A -eq 0) {
                $Bitmap.SetPixel($x,$y,[Drawing.Color]::FromArgb(0,0,0,0))
            } elseif($pixel.A -ne 255) {
                throw "semi-transparent generated pixel at $x,$y alpha=$($pixel.A)"
            }
        }
    }
}

function Save-Png([Drawing.Bitmap]$Bitmap,[string]$Path) {
    $directory = Split-Path -Parent $Path
    if(-not (Test-Path -LiteralPath $directory)) {
        [void](New-Item -ItemType Directory -Path $directory)
    }
    Normalize-TransparentPixels $Bitmap
    $Bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
    Write-Output "generated $Path"
}

function Get-HairColor([string]$Persona,[bool]$Boundary,[int]$X,[int]$Y) {
    if($Persona -eq 'tantan') {
        if($Boundary){return $palette.Outline}
        if($X -le 6 -or $Y -ge 25){return $palette.TantanDark}
        if($Y -le 15){return $palette.TantanLight}
        return $palette.Tantan
    }
    if($Persona -eq 'daodao') {
        if($Boundary){return $palette.DaodaoOutline}
        if($X -le 6 -or $Y -ge 24){return $palette.DaodaoDark}
        if($Y -le 13){return $palette.DaodaoLight}
        return $palette.Daodao
    }
    if($Boundary){return $palette.YoonDark}
    if($X -le 6 -or $Y -ge 25){return $palette.Yoon}
    if($Y -le 14){return $palette.YoonLight}
    return $palette.Yoon
}

function Draw-OutlinedRows(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [object[]]$Rows,
    [string]$Persona,
    [int]$Phase
) {
    $mask=[bool[,]]::new(32,64)
    foreach($row in $Rows) {
        $y=[int]$row[0]+$Phase
        for($x=[int]$row[1]; $x -le [int]$row[2]; $x++) {
            $mask[$x,$y]=$true
        }
    }
    foreach($row in $Rows) {
        $y=[int]$row[0]+$Phase
        for($x=[int]$row[1]; $x -le [int]$row[2]; $x++) {
            $boundary=$x -eq 0 -or $x -eq 31 -or $y -eq 0 -or $y -eq 63 -or
                -not $mask[($x-1),$y] -or -not $mask[($x+1),$y] -or
                -not $mask[$x,($y-1)] -or -not $mask[$x,($y+1)]
            Set-LocalPixel $Bitmap $Cell 32 $x $y `
                (Get-HairColor $Persona $boundary $x $y)
        }
    }
}

function Get-HairRows([string]$Persona,[string]$View) {
    switch("$Persona/$View") {
        'tantan/front' { return @(
            @(11,12,15),@(12,9,18),@(13,7,21),@(14,6,24),@(15,5,26),
            @(16,5,27),@(17,6,27),@(18,6,26),@(19,7,25),@(20,7,23),
            @(21,6,13),@(21,17,24),@(22,5,11),@(22,18,24),
            @(23,5,9),@(23,19,25),@(24,5,8),@(24,20,25),
            @(25,4,7),@(25,22,26),@(26,4,7),@(26,23,26),
            @(27,4,6),@(27,24,27),@(28,4,6),@(28,25,27),
            @(29,4,6),@(29,25,27),@(30,5,6),@(30,26,27),
            @(31,5,6),@(31,26,27),@(32,5,6),@(32,26,27)
        ) }
        'tantan/right' { return @(
            @(11,14,18),@(12,11,20),@(13,9,23),@(14,8,26),@(15,7,28),
            @(16,7,29),@(17,8,29),@(18,9,29),@(19,10,28),@(20,11,27),
            @(21,5,12),@(21,22,27),@(22,5,11),@(22,23,28),
            @(23,5,10),@(23,24,29),@(24,4,9),@(24,25,29),
            @(25,4,8),@(25,26,29),@(26,4,8),@(26,27,29),
            @(27,4,7),@(27,27,29),@(28,4,7),@(29,4,7),
            @(30,4,7),@(31,4,7),@(32,4,7)
        ) }
        'tantan/back' { return @(
            @(11,12,16),@(12,9,20),@(13,7,23),@(14,6,25),@(15,5,26),
            @(16,5,27),@(17,6,27),@(18,6,26),@(19,7,25),@(20,7,24),
            @(21,6,13),@(21,18,25),@(22,5,11),@(22,14,18),@(22,21,26),
            @(23,5,10),@(23,13,17),@(23,22,26),@(24,5,9),@(24,14,18),
            @(24,23,27),@(25,4,8),@(25,15,19),@(25,24,27),
            @(26,4,8),@(26,16,19),@(26,25,27),@(27,4,7),@(27,25,27),
            @(28,4,7),@(28,25,27),@(29,4,7),@(29,25,27),
            @(30,5,7),@(30,25,26),@(31,5,6),@(31,25,26)
        ) }
        'daodao/front' { return @(
            @(9,7,9),@(9,15,17),@(9,23,25),@(10,6,10),@(10,14,18),
            @(10,22,26),@(11,5,11),@(11,13,19),@(11,21,27),
            @(12,5,27),@(13,5,27),@(14,5,27),@(15,6,26),@(16,6,25),
            @(17,7,24),@(18,6,13),@(18,18,25),@(19,6,12),@(19,19,25),
            @(20,5,11),@(20,20,26),@(21,5,10),@(21,21,26),
            @(22,4,8),@(22,23,27),@(23,4,7),@(23,24,27),
            @(24,4,7),@(24,24,27),@(25,4,6),@(25,25,27),
            @(26,4,6),@(26,25,27),@(27,4,6),@(27,25,27),
            @(28,5,6),@(28,26,27),@(29,5,6),@(29,26,27)
        ) }
        'daodao/right' { return @(
            @(9,13,15),@(9,22,25),@(10,11,16),@(10,21,27),
            @(11,9,18),@(11,20,28),@(12,8,28),@(13,7,29),@(14,7,29),
            @(15,8,29),@(16,9,28),@(17,10,27),@(18,5,12),@(18,21,28),
            @(19,5,11),@(19,22,29),@(20,4,10),@(20,23,29),
            @(21,4,9),@(21,24,29),@(22,4,8),@(22,25,29),
            @(23,4,7),@(23,26,29),@(24,4,7),@(24,27,29),
            @(25,4,6),@(25,27,29),@(26,4,6),@(27,4,6),@(28,5,6)
        ) }
        'daodao/back' { return @(
            @(9,7,9),@(9,15,17),@(9,23,25),@(10,6,10),@(10,14,18),
            @(10,22,26),@(11,5,11),@(11,13,19),@(11,21,27),
            @(12,5,27),@(13,5,27),@(14,5,27),@(15,6,26),@(16,6,25),
            @(17,7,24),@(18,5,11),@(18,14,18),@(18,21,27),
            @(19,5,10),@(19,15,19),@(19,22,27),@(20,4,9),@(20,23,28),
            @(21,4,8),@(21,24,28),@(22,4,7),@(22,25,28),
            @(23,4,7),@(23,25,28),@(24,4,6),@(24,26,28),
            @(25,4,6),@(25,26,28),@(26,5,6),@(26,26,27)
        ) }
        'yoontoons/front' { return @(
            @(11,9,13),@(11,18,22),@(12,7,15),@(12,17,24),
            @(13,6,25),@(14,5,26),@(15,5,27),@(16,6,27),@(17,6,26),
            @(18,7,25),@(19,5,12),@(19,16,20),@(19,23,27),
            @(20,4,11),@(20,16,19),@(20,24,28),@(21,4,10),@(21,25,28),
            @(22,3,9),@(22,25,29),@(23,3,8),@(23,26,29),
            @(24,3,7),@(24,26,29),@(25,3,7),@(25,26,29),
            @(26,3,6),@(26,27,29),@(27,3,6),@(27,27,29),
            @(28,3,6),@(28,27,29),@(29,4,6),@(29,27,28),
            @(30,4,6),@(30,27,28),@(31,4,5),@(31,27,28),
            @(32,3,6),@(32,26,29),@(33,2,5),@(33,27,30),
            @(34,1,4),@(34,28,30),@(35,1,4),@(35,28,30),
            @(36,2,5),@(36,27,29),@(37,3,6),@(37,26,28),
            @(38,4,7),@(38,25,27),@(39,5,7),@(39,25,26)
        ) }
        'yoontoons/right' { return @(
            @(11,12,16),@(11,20,23),@(12,9,18),@(12,19,26),
            @(13,7,27),@(14,6,28),@(15,6,29),@(16,7,29),@(17,8,29),
            @(18,9,28),@(19,4,11),@(19,23,29),@(20,3,10),@(20,24,29),
            @(21,3,9),@(21,25,30),@(22,3,8),@(22,26,30),
            @(23,3,7),@(23,27,30),@(24,3,7),@(24,27,30),
            @(25,3,6),@(25,28,30),@(26,3,6),@(26,28,30),
            @(27,3,6),@(28,3,6),@(29,4,6),@(30,4,6),@(31,4,5),
            @(32,3,6),@(32,28,30),@(33,2,5),@(33,28,30),
            @(34,1,4),@(34,28,30),@(35,1,4),@(35,28,30),
            @(36,2,5),@(36,27,29),@(37,3,6),@(37,26,28),
            @(38,4,7),@(38,25,27),@(39,5,7),@(39,25,26)
        ) }
        'yoontoons/back' { return @(
            @(11,9,13),@(11,18,22),@(12,7,15),@(12,17,24),
            @(13,6,25),@(14,5,26),@(15,5,27),@(16,6,27),@(17,6,26),
            @(18,7,25),@(19,4,11),@(19,14,18),@(19,22,28),
            @(20,3,10),@(20,15,19),@(20,23,29),@(21,3,9),@(21,24,29),
            @(22,3,8),@(22,25,29),@(23,3,7),@(23,26,29),
            @(24,3,7),@(24,26,29),@(25,3,6),@(25,27,29),
            @(26,3,6),@(26,27,29),@(27,3,6),@(27,27,29),
            @(28,4,6),@(28,27,28),@(29,4,6),@(29,27,28),
            @(30,3,6),@(30,26,29),@(31,2,5),@(31,27,30),
            @(32,1,4),@(32,28,30),@(33,1,4),@(33,28,30),
            @(34,2,5),@(34,27,29),@(35,3,6),@(35,26,28),
            @(36,4,7),@(36,25,27),@(37,5,7),@(37,25,26),
            @(38,5,7),@(38,25,26),@(39,6,7),@(39,25,25)
        ) }
        default { throw "missing authored hair rows for $Persona/$View" }
    }
}

function Draw-HairCell(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [string]$Persona,
    [string]$View,
    [int]$Phase
) {
    Draw-OutlinedRows $Bitmap $Cell (Get-HairRows $Persona $View) $Persona $Phase
    if($Persona -eq 'yoontoons' -and $View -in @('front','right')) {
        Fill-LocalSpan $Bitmap $Cell 32 7 9 (17+$Phase) $palette.YoonBlue
        Set-LocalPixel $Bitmap $Cell 32 8 (18+$Phase) $palette.YoonBlue
    }
}
function Draw-TantanFrontGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 9 11 $y $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 10 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 8 ($y+1) $palette.TantanGlass
    Fill-LocalSpan $Bitmap $Cell 32 20 22 $y $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 21 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 23 ($y+1) $palette.TantanGlass
}

function Draw-TantanSideGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 20 23 $y $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 21 $y $palette.TantanGlassLight
    Set-LocalPixel $Bitmap $Cell 32 24 ($y+1) $palette.TantanGlass
}
function Draw-DaodaoFrontTissues([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $left=@(@(11,6,7),@(12,5,7),@(13,5,6),@(14,4,6),
        @(15,4,5),@(16,3,5),@(17,3,4),@(18,2,4))
    foreach($row in $left) {
        Fill-LocalSpan $Bitmap $Cell 32 $row[1] $row[2] ($row[0]+$OffsetY) $palette.Tissue
        Set-LocalPixel $Bitmap $Cell 32 $row[1] ($row[0]+$OffsetY) $palette.TissueDark
        Set-LocalPixel $Bitmap $Cell 32 $row[2] ($row[0]+$OffsetY) $palette.TissueLight
    }
    foreach($row in $left) {
        $x1=31-$row[2]
        $x2=31-$row[1]
        Fill-LocalSpan $Bitmap $Cell 32 $x1 $x2 ($row[0]+$OffsetY) $palette.Tissue
        Set-LocalPixel $Bitmap $Cell 32 $x1 ($row[0]+$OffsetY) $palette.TissueLight
        Set-LocalPixel $Bitmap $Cell 32 $x2 ($row[0]+$OffsetY) $palette.TissueDark
    }
}

function Draw-DaodaoSideTissue([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $rows=@(@(11,12,14),@(12,11,14),@(13,11,13),@(14,10,13),
        @(15,10,12),@(16,9,12),@(17,9,11),@(18,8,11))
    foreach($row in $rows) {
        Fill-LocalSpan $Bitmap $Cell 32 $row[1] $row[2] ($row[0]+$OffsetY) $palette.Tissue
        Set-LocalPixel $Bitmap $Cell 32 $row[1] ($row[0]+$OffsetY) $palette.TissueDark
        Set-LocalPixel $Bitmap $Cell 32 $row[2] ($row[0]+$OffsetY) $palette.TissueLight
    }
}
function Draw-YoonFrontGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 9 11 $y $palette.YoonGlassDark
    Set-LocalPixel $Bitmap $Cell 32 10 $y $palette.YoonGlassLight
    Set-LocalPixel $Bitmap $Cell 32 8 ($y+1) $palette.YoonGlass
    Fill-LocalSpan $Bitmap $Cell 32 20 22 $y $palette.YoonGlassDark
    Set-LocalPixel $Bitmap $Cell 32 21 $y $palette.YoonGlassLight
    Set-LocalPixel $Bitmap $Cell 32 23 ($y+1) $palette.YoonGlass
}

function Draw-YoonSideGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $y=12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 20 23 $y $palette.YoonGlassDark
    Set-LocalPixel $Bitmap $Cell 32 21 $y $palette.YoonGlassLight
    Set-LocalPixel $Bitmap $Cell 32 24 ($y+1) $palette.YoonGlass
}

function Draw-FaceCell(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [string]$Persona,
    [string]$View,
    [int]$Phase
) {
    if($View -eq 'back') { return }
    if($Persona -eq 'daodao') { return }
    if($Persona -eq 'tantan') {
        if($View -eq 'front') { Draw-TantanFrontGlasses $Bitmap $Cell $Phase }
        else { Draw-TantanSideGlasses $Bitmap $Cell $Phase }
    } else {
        if($View -eq 'front') { Draw-YoonFrontGlasses $Bitmap $Cell $Phase }
        else { Draw-YoonSideGlasses $Bitmap $Cell $Phase }
    }
}

function Draw-ScaledRegion(
    [Drawing.Bitmap]$Source,
    [Drawing.Bitmap]$Target,
    [int]$SourceX,
    [int]$SourceY,
    [int]$Width,
    [int]$Height,
    [int]$TargetX,
    [int]$TargetY,
    [int]$Scale,
    [switch]$MirrorX
) {
    for($y=0; $y -lt $Height; $y++) {
        for($x=0; $x -lt $Width; $x++) {
            $pixel=$Source.GetPixel($SourceX+$x,$SourceY+$y)
            if($pixel.A -eq 0) { continue }
            $localX=if($MirrorX){$Width-1-$x}else{$x}
            for($dy=0; $dy -lt $Scale; $dy++) {
                for($dx=0; $dx -lt $Scale; $dx++) {
                    $Target.SetPixel($TargetX+($localX*$Scale)+$dx,$TargetY+($y*$Scale)+$dy,$pixel)
                }
            }
        }
    }
}

function New-CompositeFrame(
    [Drawing.Bitmap]$VanillaHead,
    [Drawing.Bitmap]$Hair,
    [Drawing.Bitmap]$Face,
    [int]$Cell,
    [string]$View
) {
    $frame=New-TransparentBitmap 64 64
    $sourceX=switch($View) {
        front {0}
        right {64}
        back {128}
        left {64}
    }
    Draw-ScaledRegion $VanillaHead $frame $sourceX 0 32 32 16 17 1 -MirrorX:($View -eq 'left')
    Draw-ScaledRegion $Hair $frame ($Cell*32) 0 32 64 16 1 1
    Draw-ScaledRegion $Face $frame ($Cell*32) 0 32 32 16 17 1
    return $frame
}

function Fill-PreviewBackground([Drawing.Bitmap]$Bitmap,[int]$Y,[string]$Kind) {
    $height=280
    $graphics=[Drawing.Graphics]::FromImage($Bitmap)
    try {
        if($Kind -eq 'checker') {
            $light=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,225,225,225))
            $dark=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,195,195,195))
            try {
                for($py=$Y; $py -lt $Y+$height; $py+=16) {
                    for($px=0; $px -lt $Bitmap.Width; $px+=16) {
                        $brush=if((( [math]::Floor($px/16)+[math]::Floor($py/16)) % 2) -eq 0) {
                            $light
                        } else {
                            $dark
                        }
                        $graphics.FillRectangle($brush,$px,$py,16,16)
                    }
                }
            } finally {
                $light.Dispose()
                $dark.Dispose()
            }
        } else {
            $color=if($Kind -eq 'white') {
                [Drawing.Color]::White
            } else {
                [Drawing.Color]::FromArgb(255,74,22,27)
            }
            $brush=[Drawing.SolidBrush]::new($color)
            try { $graphics.FillRectangle($brush,0,$Y,$Bitmap.Width,$height) }
            finally { $brush.Dispose() }
        }
    } finally {
        $graphics.Dispose()
    }
}

$vanillaHead=Open-BitmapCopy $vanillaHeadPath
$atlases=@{}
try {
    foreach($persona in @('tantan','daodao','yoontoons')) {
        $hair=New-TransparentBitmap 256 64
        $face=New-TransparentBitmap 256 32
        for($cell=0; $cell -lt 6; $cell++) {
            $view=$views[$cell]
            Draw-HairCell $hair $cell $persona $view.Name $view.Phase
            Draw-FaceCell $face $cell $persona $view.Name $view.Phase
        }
        Mirror-Cell $hair 2 6 32 64
        Mirror-Cell $hair 3 7 32 64
        Mirror-Cell $face 2 6 32 32
        Mirror-Cell $face 3 7 32 32
        $atlases["${persona}_hair"]=$hair
        $faceName=switch($persona) {
            tantan {'glasses'}
            daodao {'tissue_tears'}
            yoontoons {'glasses'}
        }
        $atlases["${persona}_$faceName"]=$face
    }

    foreach($entry in $atlases.GetEnumerator() | Sort-Object Key) {
        Save-Png $entry.Value (Join-Path $outputDir "costume_$($entry.Key).png")
    }

    $preview=New-TransparentBitmap 1408 2520
    try {
        $directions=@(
            @{Name='front';Cell=0},
            @{Name='right';Cell=2},
            @{Name='back';Cell=4},
            @{Name='left';Cell=6}
        )
        $personas=@(
            @{Name='tantan';Face='tantan_glasses'},
            @{Name='daodao';Face='daodao_tissue_tears'},
            @{Name='yoontoons';Face='yoontoons_glasses'}
        )
        $mattes=@('checker','white','darkred')
        for($personaIndex=0; $personaIndex -lt $personas.Count; $personaIndex++) {
            $persona=$personas[$personaIndex]
            foreach($matteIndex in 0..2) {
                $rowY=(($personaIndex*3)+$matteIndex)*280
                Fill-PreviewBackground $preview $rowY $mattes[$matteIndex]
                for($directionIndex=0; $directionIndex -lt $directions.Count; $directionIndex++) {
                    $direction=$directions[$directionIndex]
                    $frame=New-CompositeFrame $vanillaHead $atlases["$($persona.Name)_hair"] `
                        $atlases[$persona.Face] $direction.Cell $direction.Name
                    try {
                        Draw-ScaledRegion $frame $preview 0 0 64 64 `
                            (16+($directionIndex*264)) ($rowY+12) 4
                        Draw-ScaledRegion $frame $preview 0 0 64 64 `
                            (1080+($directionIndex*72)) ($rowY+108) 1
                    } finally {
                        $frame.Dispose()
                    }
                }
            }
        }
        $previewPath=Join-Path $previewDir 'creator_accessory_atlases_preview.png'
        $preview.Save($previewPath,[Drawing.Imaging.ImageFormat]::Png)
        Write-Output "generated $previewPath"
    } finally {
        $preview.Dispose()
    }
} finally {
    foreach($bitmap in $atlases.Values) { $bitmap.Dispose() }
    $vanillaHead.Dispose()
}
