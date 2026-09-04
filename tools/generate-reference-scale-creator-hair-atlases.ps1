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
    Outline=[Drawing.Color]::FromArgb(255,0,0,0)
    TantanDark=[Drawing.ColorTranslator]::FromHtml('#8F4664')
    Tantan=[Drawing.ColorTranslator]::FromHtml('#D87498')
    TantanLight=[Drawing.ColorTranslator]::FromHtml('#F1A0BA')
    TantanSpark=[Drawing.ColorTranslator]::FromHtml('#FFD0DA')
    DaodaoDark=[Drawing.ColorTranslator]::FromHtml('#2F4A70')
    Daodao=[Drawing.ColorTranslator]::FromHtml('#5779A8')
    DaodaoLight=[Drawing.ColorTranslator]::FromHtml('#86A4CC')
    DaodaoSpark=[Drawing.ColorTranslator]::FromHtml('#B9CBE1')
    YoonShadow=[Drawing.ColorTranslator]::FromHtml('#111827')
    YoonDark=[Drawing.ColorTranslator]::FromHtml('#263450')
    Yoon=[Drawing.ColorTranslator]::FromHtml('#3F5277')
    YoonLight=[Drawing.ColorTranslator]::FromHtml('#657DA6')
    YoonBlue=[Drawing.ColorTranslator]::FromHtml('#49B6D8')
}

$views = @(
    @{ Name='front'; Phase=0 }, @{ Name='front'; Phase=1 },
    @{ Name='right'; Phase=0 }, @{ Name='right'; Phase=1 },
    @{ Name='back'; Phase=0 }, @{ Name='back'; Phase=1 }
)

function New-TransparentBitmap([int]$Width,[int]$Height) {
    $bitmap=[Drawing.Bitmap]::new($Width,$Height,[Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $graphics=[Drawing.Graphics]::FromImage($bitmap)
    try {
        $graphics.CompositingMode=[Drawing.Drawing2D.CompositingMode]::SourceCopy
        $graphics.Clear($palette.Clear)
    } finally {
        $graphics.Dispose()
    }
    return $bitmap
}

function Open-BitmapCopy([string]$Path) {
    if(-not (Test-Path -LiteralPath $Path)) { throw "missing bitmap: $Path" }
    $stream=[IO.File]::OpenRead($Path)
    try {
        $source=[Drawing.Bitmap]::FromStream($stream)
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
    if($X -lt 0 -or $X -ge $CellWidth -or $Y -lt 0 -or $Y -ge $Bitmap.Height) {
        throw "pixel outside atlas cell=$Cell x=$X y=$Y"
    }
    $Bitmap.SetPixel(($Cell*$CellWidth)+$X,$Y,$Color)
}

function Mirror-Cell(
    [Drawing.Bitmap]$Bitmap,
    [int]$SourceCell,
    [int]$TargetCell,
    [int]$CellWidth,
    [int]$CellHeight
) {
    for($y=0;$y -lt $CellHeight;$y++) {
        for($x=0;$x -lt $CellWidth;$x++) {
            $sourceX=($SourceCell*$CellWidth)+$x
            $targetX=($TargetCell*$CellWidth)+(($CellWidth-1)-$x)
            $Bitmap.SetPixel($targetX,$y,$Bitmap.GetPixel($sourceX,$y))
        }
    }
}

function Normalize-TransparentPixels([Drawing.Bitmap]$Bitmap) {
    for($y=0;$y -lt $Bitmap.Height;$y++) {
        for($x=0;$x -lt $Bitmap.Width;$x++) {
            $pixel=$Bitmap.GetPixel($x,$y)
            if($pixel.A -eq 0) {
                $Bitmap.SetPixel($x,$y,$palette.Clear)
            } elseif($pixel.A -ne 255) {
                throw "semi-transparent generated pixel at $x,$y alpha=$($pixel.A)"
            }
        }
    }
}

function Save-Png([Drawing.Bitmap]$Bitmap,[string]$Path) {
    Normalize-TransparentPixels $Bitmap
    $Bitmap.Save($Path,[Drawing.Imaging.ImageFormat]::Png)
    Write-Output "generated $Path"
}

function Get-HairRows([string]$Persona,[string]$View) {
    switch("$Persona/$View") {
        'tantan/front' { return @(
            @(10,29,34),@(11,25,38),@(12,22,41),@(13,20,43),
            @(14,18,45),@(15,17,46),@(16,16,47),@(17,15,48),
            @(18,14,49),@(19,14,49),@(20,15,48),@(21,15,48),
            @(22,16,47),@(23,17,46),@(24,18,45),
            @(25,17,27),@(25,30,45),@(26,16,26),@(26,31,47),
            @(27,15,24),@(27,33,48),@(28,14,21),@(28,43,49),
            @(29,14,19),@(29,43,49),@(30,14,18),@(30,44,49),
            @(31,14,18),@(31,45,49),@(32,14,18),@(32,45,49),
            @(33,14,18),@(33,46,49),@(34,14,18),@(34,46,49),
            @(35,15,18),@(35,46,48),@(36,15,18),@(36,46,48),
            @(37,16,18),@(37,46,47),@(38,16,18),@(38,46,47),
            @(39,17,18),@(39,46,47)
        ) }
        'tantan/right' { return @(
            @(11,29,34),@(12,25,39),@(13,22,42),@(14,20,44),
            @(15,18,46),@(16,17,47),@(17,16,48),@(18,15,48),
            @(19,15,48),@(20,16,48),@(21,17,47),@(22,18,47),
            @(23,19,46),@(24,20,46),
            @(25,16,23),@(25,39,47),@(26,15,22),@(26,40,48),
            @(27,15,21),@(27,41,48),@(28,15,20),@(28,42,48),
            @(29,15,19),@(29,43,48),@(30,15,19),@(30,44,48),
            @(31,15,19),@(31,44,48),@(32,15,19),@(32,45,48),
            @(33,15,19),@(33,45,48),@(34,15,19),@(34,46,48),
            @(35,15,19),@(36,15,19),@(37,15,19),@(38,16,19),
            @(39,16,18),@(40,17,18)
        ) }
        'tantan/back' { return @(
            @(10,29,34),@(11,25,38),@(12,22,41),@(13,20,43),
            @(14,18,45),@(15,17,46),@(16,16,47),@(17,15,48),
            @(18,14,49),@(19,14,49),@(20,14,49),@(21,15,48),
            @(22,15,48),@(23,16,47),@(24,16,47),@(25,16,47),
            @(26,15,48),@(27,15,48),@(28,14,49),@(29,14,49),
            @(30,14,49),@(31,14,49),@(32,14,49),@(33,14,49),
            @(34,14,49),@(35,15,48),@(36,15,22),@(36,24,31),
            @(36,33,40),@(36,42,48),@(37,16,21),@(37,25,30),
            @(37,34,39),@(37,43,47),@(38,17,20),@(38,26,29),
            @(38,35,38),@(38,44,46),@(39,18,19),@(39,27,28),
            @(39,36,37),@(39,45,46)
        ) }
        'daodao/front' { return @(
            @(8,19,21),@(8,30,33),@(8,43,45),
            @(9,18,22),@(9,29,34),@(9,42,46),
            @(10,17,24),@(10,27,36),@(10,40,47),
            @(11,16,48),@(12,15,49),@(13,15,49),@(14,14,50),
            @(15,14,50),@(16,15,49),@(17,15,49),@(18,16,48),
            @(19,16,48),@(20,17,47),@(21,17,47),@(22,18,46),
            @(23,17,28),@(23,35,47),@(24,16,27),@(24,36,48),
            @(25,15,25),@(25,37,49),@(26,14,23),@(26,39,50),
            @(27,14,21),@(27,41,50),@(28,14,19),@(28,43,50),
            @(29,14,18),@(29,45,50),@(30,14,18),@(30,45,50),
            @(31,14,18),@(31,46,50),@(32,14,18),@(32,46,50),
            @(33,14,18),@(33,46,50),@(34,15,18),@(34,46,49),
            @(35,15,18),@(35,46,49),@(36,16,18),@(36,46,48),
            @(37,16,18),@(37,46,48),@(38,17,18),@(38,47,48),
            @(39,17,18),@(39,47,48)
        ) }
        'daodao/right' { return @(
            @(8,21,23),@(8,32,35),@(8,43,45),
            @(9,20,24),@(9,31,36),@(9,42,46),
            @(10,19,26),@(10,29,38),@(10,40,47),
            @(11,18,48),@(12,17,49),@(13,16,50),@(14,15,50),
            @(15,15,50),@(16,16,49),@(17,17,49),@(18,18,48),
            @(19,19,47),@(20,20,47),@(21,20,46),@(22,21,46),
            @(23,16,25),@(23,39,47),@(24,15,24),@(24,40,48),
            @(25,14,22),@(25,42,49),@(26,14,21),@(26,43,49),
            @(27,14,20),@(27,44,49),@(28,14,19),@(28,45,49),
            @(29,14,18),@(29,46,49),@(30,14,18),@(30,46,49),
            @(31,14,18),@(31,46,49),@(32,14,18),@(32,47,49),
            @(33,14,18),@(33,47,49),@(34,15,18),@(34,47,49),
            @(35,15,18),@(36,16,18),@(37,16,18),@(38,17,18),
            @(39,17,18)
        ) }
        'daodao/back' { return @(
            @(8,19,21),@(8,30,33),@(8,43,45),
            @(9,18,22),@(9,29,34),@(9,42,46),
            @(10,17,24),@(10,27,36),@(10,40,47),
            @(11,16,48),@(12,15,49),@(13,15,49),@(14,14,50),
            @(15,14,50),@(16,14,50),@(17,15,49),@(18,15,49),
            @(19,16,48),@(20,16,48),@(21,16,48),@(22,15,49),
            @(23,15,49),@(24,14,50),@(25,14,50),@(26,14,50),
            @(27,14,50),@(28,14,50),@(29,14,50),@(30,14,50),
            @(31,14,50),@(32,15,49),@(33,15,24),@(33,26,37),
            @(33,39,49),@(34,16,23),@(34,27,36),@(34,40,48),
            @(35,16,22),@(35,28,35),@(35,41,48),
            @(36,17,21),@(36,29,34),@(36,42,47),
            @(37,18,20),@(37,30,33),@(37,43,46),
            @(38,19,20),@(38,31,32),@(38,44,45),
            @(39,19,20),@(39,44,45)
        ) }
        'yoontoons/front' { return @(
            @(9,29,34),@(10,25,38),@(11,22,41),@(12,19,44),
            @(13,17,46),@(14,15,48),@(15,14,49),@(16,13,50),
            @(17,12,51),@(18,12,51),@(19,13,50),@(20,13,50),
            @(21,14,49),@(22,14,49),@(23,15,48),@(24,16,47),
            @(25,14,25),@(25,29,36),@(25,40,49),
            @(26,13,24),@(26,28,35),@(26,41,50),
            @(27,12,22),@(27,27,34),@(27,42,51),
            @(28,12,20),@(28,28,32),@(28,44,51),
            @(29,12,18),@(29,46,51),@(30,12,18),@(30,46,51),
            @(31,12,18),@(31,46,51),@(32,12,18),@(32,46,51),
            @(33,12,18),@(33,46,51),@(34,12,18),@(34,46,51),
            @(35,12,18),@(35,46,51),@(36,12,18),@(36,46,51),
            @(37,12,18),@(37,46,51),@(38,12,18),@(38,46,51),
            @(39,12,18),@(39,46,51),@(40,13,18),@(40,46,50),
            @(41,13,18),@(41,46,50),@(42,13,18),@(42,46,50),
            @(43,14,18),@(43,46,49),@(44,14,18),@(44,46,49),
            @(45,15,18),@(45,46,48),@(46,15,18),@(46,46,48),
            @(47,16,18),@(47,46,47),@(48,16,18),@(48,46,47),
            @(49,17,18),@(49,46,47)
        ) }
        'yoontoons/right' { return @(
            @(10,30,35),@(11,26,39),@(12,22,42),@(13,20,44),
            @(14,18,46),@(15,16,48),@(16,15,49),@(17,14,50),
            @(18,13,50),@(19,13,50),@(20,14,50),@(21,15,49),
            @(22,16,48),@(23,17,47),@(24,18,47),
            @(25,14,24),@(25,40,48),@(26,13,23),@(26,41,49),
            @(27,13,21),@(27,43,50),@(28,13,19),@(28,45,50),
            @(29,13,18),@(29,46,50),@(30,13,18),@(30,46,50),
            @(31,13,18),@(31,46,50),@(32,13,18),@(32,46,50),
            @(33,13,18),@(33,46,50),@(34,13,18),@(34,46,50),
            @(35,13,18),@(35,46,50),@(36,13,18),@(36,46,50),
            @(37,13,18),@(37,46,50),@(38,13,18),@(38,46,50),
            @(39,13,18),@(39,46,50),@(40,14,18),@(40,46,49),
            @(41,14,18),@(41,46,49),@(42,14,18),@(42,46,49),
            @(43,15,18),@(43,46,48),@(44,15,18),@(44,46,48),
            @(45,16,18),@(45,46,47),@(46,16,18),@(46,46,47),
            @(47,17,18),@(47,46,47),@(48,17,18),@(48,46,47),
            @(49,17,18),@(49,46,47)
        ) }
        'yoontoons/back' { return @(
            @(9,29,34),@(10,25,38),@(11,22,41),@(12,19,44),
            @(13,17,46),@(14,15,48),@(15,14,49),@(16,13,50),
            @(17,12,51),@(18,12,51),@(19,12,51),@(20,13,50),
            @(21,13,50),@(22,14,49),@(23,14,49),@(24,14,49),
            @(25,13,50),@(26,13,50),@(27,12,51),@(28,12,51),
            @(29,12,51),@(30,12,51),@(31,12,51),@(32,12,51),
            @(33,12,51),@(34,12,51),@(35,12,51),@(36,12,51),
            @(37,12,51),@(38,12,51),@(39,12,51),@(40,12,51),
            @(41,13,50),@(42,13,50),@(43,13,24),@(43,26,37),
            @(43,39,50),@(44,14,23),@(44,27,36),@(44,40,49),
            @(45,14,22),@(45,28,35),@(45,41,49),
            @(46,15,21),@(46,29,34),@(46,42,48),
            @(47,15,20),@(47,30,33),@(47,43,48),
            @(48,16,19),@(48,31,32),@(48,44,47),
            @(49,17,18),@(49,45,46),@(50,17,18),@(50,45,46)
        ) }
        default { throw "missing authored hair rows for $Persona/$View" }
    }
}

function Get-InteriorColor([string]$Persona,[int]$X,[int]$Y) {
    if($Persona -eq 'tantan') {
        if($X -le 19 -or $Y -ge 32) { return $palette.TantanDark }
        if($Y -le 17 -and $X -ge 25 -and $X -le 38) { return $palette.TantanLight }
        return $palette.Tantan
    }
    if($Persona -eq 'daodao') {
        if($X -le 19 -or $Y -ge 32) { return $palette.DaodaoDark }
        if($Y -le 16 -and $X -ge 27 -and $X -le 41) { return $palette.DaodaoLight }
        return $palette.Daodao
    }
    if($X -le 18 -or $Y -ge 35) { return $palette.YoonDark }
    if($Y -le 17 -and $X -ge 29 -and $X -le 42) { return $palette.YoonLight }
    return $palette.Yoon
}

function Draw-HairCell(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [string]$Persona,
    [string]$View,
    [int]$Phase
) {
    $mask=[bool[,]]::new(64,64)
    foreach($row in (Get-HairRows $Persona $View)) {
        $y=[int]$row[0]+$Phase
        for($x=[int]$row[1];$x -le [int]$row[2];$x++) {
            $mask[$x,$y]=$true
        }
    }
    for($y=0;$y -lt 64;$y++) {
        for($x=0;$x -lt 64;$x++) {
            if(-not $mask[$x,$y]) { continue }
            $boundary=$x -eq 0 -or $x -eq 63 -or $y -eq 0 -or $y -eq 63 -or
                -not $mask[($x-1),$y] -or -not $mask[($x+1),$y] -or
                -not $mask[$x,($y-1)] -or -not $mask[$x,($y+1)]
            $color=if($boundary){$palette.Outline}else{Get-InteriorColor $Persona $x $y}
            Set-LocalPixel $Bitmap $Cell 64 $x $y $color
        }
    }
    $spark=if($Persona -eq 'tantan'){$palette.TantanSpark}elseif($Persona -eq 'daodao'){$palette.DaodaoSpark}else{$palette.YoonBlue}
    $accent=if($Persona -eq 'yoontoons'){@(@(18,18),@(19,18),@(18,19),@(19,19),@(20,19))}else{@(@(31,13),@(32,13),@(33,13),@(31,14),@(32,14))}
    foreach($point in $accent) {
        $x=[int]$point[0];$y=[int]$point[1]+$Phase
        if($mask[$x,$y] -and $Bitmap.GetPixel(($Cell*64)+$x,$y).ToArgb() -ne $palette.Outline.ToArgb()) {
            Set-LocalPixel $Bitmap $Cell 64 $x $y $spark
        }
    }
}

function Draw-Region(
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
    for($y=0;$y -lt $Height;$y++) {
        for($x=0;$x -lt $Width;$x++) {
            $pixel=$Source.GetPixel($SourceX+$x,$SourceY+$y)
            if($pixel.A -eq 0) { continue }
            $localX=if($MirrorX){$Width-1-$x}else{$x}
            for($dy=0;$dy -lt $Scale;$dy++) {
                for($dx=0;$dx -lt $Scale;$dx++) {
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
    $sourceX=switch($View) { front {0}; right {64}; back {128}; left {64} }
    Draw-Region $VanillaHead $frame $sourceX 0 32 32 16 17 1 -MirrorX:($View -eq 'left')
    Draw-Region $Hair $frame ($Cell*64) 0 64 64 0 0 1
    Draw-Region $Face $frame (($Cell%8)*32) 0 32 32 16 17 1
    return $frame
}

function Fill-PreviewBackground([Drawing.Bitmap]$Bitmap,[int]$Y,[string]$Kind) {
    $graphics=[Drawing.Graphics]::FromImage($Bitmap)
    try {
        if($Kind -eq 'checker') {
            $light=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,225,225,225))
            $dark=[Drawing.SolidBrush]::new([Drawing.Color]::FromArgb(255,195,195,195))
            try {
                for($py=$Y;$py -lt $Y+280;$py+=16) {
                    for($px=0;$px -lt $Bitmap.Width;$px+=16) {
                        $brush=if((([math]::Floor($px/16)+[math]::Floor($py/16))%2) -eq 0) {
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
            try { $graphics.FillRectangle($brush,0,$Y,$Bitmap.Width,280) }
            finally { $brush.Dispose() }
        }
    } finally {
        $graphics.Dispose()
    }
}

$atlases=@{}
try {
    foreach($persona in @('tantan','daodao','yoontoons')) {
        $hair=New-TransparentBitmap 512 64
        for($cell=0;$cell -lt 6;$cell++) {
            Draw-HairCell $hair $cell $persona $views[$cell].Name $views[$cell].Phase
        }
        Mirror-Cell $hair 2 6 64 64
        Mirror-Cell $hair 3 7 64 64
        Save-Png $hair (Join-Path $outputDir "costume_${persona}_hair.png")
        $atlases[$persona]=$hair
    }

    $vanilla=Open-BitmapCopy $vanillaHeadPath
    $faces=@{
        tantan=Open-BitmapCopy (Join-Path $outputDir 'costume_tantan_glasses.png')
        daodao=Open-BitmapCopy (Join-Path $outputDir 'costume_daodao_tissue_tears.png')
        yoontoons=Open-BitmapCopy (Join-Path $outputDir 'costume_yoontoons_glasses.png')
    }
    try {
        $preview=New-TransparentBitmap 1408 2520
        try {
            $directions=@(
                @{Name='front';Cell=0},@{Name='right';Cell=2},
                @{Name='back';Cell=4},@{Name='left';Cell=6}
            )
            $personas=@('tantan','daodao','yoontoons')
            $mattes=@('checker','white','darkred')
            for($personaIndex=0;$personaIndex -lt $personas.Count;$personaIndex++) {
                $persona=$personas[$personaIndex]
                foreach($matteIndex in 0..2) {
                    $rowY=(($personaIndex*3)+$matteIndex)*280
                    Fill-PreviewBackground $preview $rowY $mattes[$matteIndex]
                    for($directionIndex=0;$directionIndex -lt $directions.Count;$directionIndex++) {
                        $direction=$directions[$directionIndex]
                    $frame=New-CompositeFrame $vanilla $atlases[$persona] $faces[$persona] $direction.Cell $direction.Name
                    try {
                            Draw-Region $frame $preview 0 0 64 64 (16+($directionIndex*264)) ($rowY+12) 4
                            Draw-Region $frame $preview 0 0 64 64 (1080+($directionIndex*72)) ($rowY+108) 1
                    } finally {
                        $frame.Dispose()
                    }
                    }
                }
            }
            Save-Png $preview (Join-Path $previewDir 'creator_accessory_atlases_preview.png')
        } finally {
            $preview.Dispose()
        }
    } finally {
        foreach($face in $faces.Values){$face.Dispose()}
        $vanilla.Dispose()
    }
} finally {
    foreach($atlas in $atlases.Values){$atlas.Dispose()}
}
