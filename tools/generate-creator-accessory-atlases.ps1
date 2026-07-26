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

function Test-FaceAperture([string]$View,[int]$X,[int]$Y) {
    if($View -eq 'front') {
        return $X -ge 7 -and $X -le 24 -and $Y -ge 12 -and $Y -le 23
    }
    if($View -eq 'right') {
        return $X -ge 15 -and $X -le 29 -and $Y -ge 11 -and $Y -le 23
    }
    return $false
}

function Test-SourceAlpha(
    [Drawing.Bitmap]$Bitmap,
    [int]$SourceX,
    [int]$X,
    [int]$Y
) {
    if($X -lt 0 -or $X -ge 32 -or $Y -lt 0 -or $Y -ge 32) { return $false }
    return $Bitmap.GetPixel($SourceX+$X,$Y).A -gt 0
}

function Get-HairColor([string]$Persona,[bool]$Boundary,[int]$X,[int]$Y) {
    if($Persona -eq 'tantan') {
        if($Boundary){return $palette.Outline}
        if($X -le 7 -or $Y -ge 22){return $palette.TantanDark}
        if($Y -le 8){return $palette.TantanLight}
        return $palette.Tantan
    }
    if($Persona -eq 'daodao') {
        if($Boundary){return $palette.DaodaoOutline}
        if($X -le 7 -or $Y -ge 22){return $palette.DaodaoDark}
        if($Y -le 7){return $palette.DaodaoLight}
        return $palette.Daodao
    }
    if($Boundary){return $palette.YoonDark}
    if($X -le 6 -or $Y -ge 22){return $palette.Yoon}
    return $palette.YoonLight
}

function Draw-TantanTufts([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$Phase) {
    $shift = $Phase
    Fill-LocalSpan $Bitmap $Cell 32 9 13 (29+$shift) $palette.Outline
    Fill-LocalSpan $Bitmap $Cell 32 9 12 (30+$shift) $palette.Tantan
    Fill-LocalSpan $Bitmap $Cell 32 10 12 (31+$shift) $palette.TantanLight
    Fill-LocalSpan $Bitmap $Cell 32 11 13 (32+$shift) $palette.TantanDark
    Fill-LocalSpan $Bitmap $Cell 32 20 23 (29+$shift) $palette.Outline
    Fill-LocalSpan $Bitmap $Cell 32 20 22 (30+$shift) $palette.Tantan
    Fill-LocalSpan $Bitmap $Cell 32 21 23 (31+$shift) $palette.TantanLight
    Fill-LocalSpan $Bitmap $Cell 32 20 22 (32+$shift) $palette.TantanDark
}

function Draw-DaodaoSpikes([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$Phase) {
    $shift = $Phase
    foreach($point in @(
        @(6,8),@(7,7),@(8,6),@(9,7),@(10,8),
        @(22,8),@(23,7),@(24,5),@(25,6),@(26,8)
    )) {
        $color = if($point[1] -le 6){$palette.DaodaoLight}else{$palette.DaodaoOutline}
        Set-LocalPixel $Bitmap $Cell 32 $point[0] ($point[1]+16+$shift) $color
    }
}

function Draw-YoonSignature([Drawing.Bitmap]$Bitmap,[int]$Cell,[string]$View,[int]$Phase) {
    $shift = $Phase
    foreach($point in @(@(4,20),@(3,21),@(3,22),@(4,23),@(27,20),@(28,21),@(28,22),@(27,23))) {
        Set-LocalPixel $Bitmap $Cell 32 $point[0] ($point[1]+16+$shift) $palette.YoonDark
    }
    if($View -in @('front','right')) {
        foreach($point in @(@(9,9),@(10,9),@(10,10))) {
            Set-LocalPixel $Bitmap $Cell 32 $point[0] ($point[1]+16+$shift) $palette.YoonBlue
        }
    }
}

function Draw-HairCell(
    [Drawing.Bitmap]$Bitmap,
    [Drawing.Bitmap]$VanillaHead,
    [int]$Cell,
    [string]$Persona,
    [string]$View,
    [int]$SourceX,
    [int]$Phase
) {
    $neighbors = @(@(-1,0),@(1,0),@(0,-1),@(0,1))
    for($y=0; $y -lt 32; $y++) {
        for($x=0; $x -lt 32; $x++) {
            if(-not (Test-SourceAlpha $VanillaHead $SourceX $x $y)) { continue }
            if(Test-FaceAperture $View $x $y) { continue }
            $boundary = $false
            foreach($delta in $neighbors) {
                if(-not (Test-SourceAlpha $VanillaHead $SourceX ($x+$delta[0]) ($y+$delta[1]))) {
                    $boundary = $true
                    break
                }
            }
            Set-LocalPixel $Bitmap $Cell 32 $x ($y+16) (Get-HairColor $Persona $boundary $x $y)
        }
    }

    if($Persona -eq 'tantan' -and $View -eq 'front') {
        Draw-TantanTufts $Bitmap $Cell $Phase
    } elseif($Persona -eq 'daodao') {
        Draw-DaodaoSpikes $Bitmap $Cell $Phase
    } elseif($Persona -eq 'yoontoons') {
        Draw-YoonSignature $Bitmap $Cell $View $Phase
    }
}

function Draw-TantanFrontGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $top = 12+$OffsetY
    foreach($range in @(@(8,12),@(19,23))) {
        $x1=$range[0]; $x2=$range[1]
        Fill-LocalSpan $Bitmap $Cell 32 $x1 $x2 $top $palette.TantanGlassLight
        Fill-LocalSpan $Bitmap $Cell 32 ($x1-1) $x1 ($top+1) $palette.TantanGlassDark
        Fill-LocalSpan $Bitmap $Cell 32 $x2 ($x2+1) ($top+1) $palette.TantanGlassDark
        Set-LocalPixel $Bitmap $Cell 32 ($x1-1) ($top+2) $palette.TantanGlass
        Set-LocalPixel $Bitmap $Cell 32 ($x2+1) ($top+2) $palette.TantanGlass
        Fill-LocalSpan $Bitmap $Cell 32 $x1 $x2 ($top+3) $palette.TantanGlass
        Fill-LocalSpan $Bitmap $Cell 32 ($x1+1) ($x2-1) ($top+4) $palette.TantanGlassDark
    }
    Fill-LocalSpan $Bitmap $Cell 32 14 17 ($top+2) $palette.TantanGlass
}

function Draw-TantanSideGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $top = 12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 17 26 $top $palette.TantanGlassLight
    Fill-LocalSpan $Bitmap $Cell 32 16 18 ($top+1) $palette.TantanGlassDark
    Fill-LocalSpan $Bitmap $Cell 32 25 27 ($top+1) $palette.TantanGlassDark
    Set-LocalPixel $Bitmap $Cell 32 16 ($top+2) $palette.TantanGlass
    Set-LocalPixel $Bitmap $Cell 32 27 ($top+2) $palette.TantanGlass
    Fill-LocalSpan $Bitmap $Cell 32 17 26 ($top+3) $palette.TantanGlass
    Fill-LocalSpan $Bitmap $Cell 32 18 25 ($top+4) $palette.TantanGlassDark
}

function Draw-DaodaoFrontTissues([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    foreach($x1 in @(9,21)) {
        Fill-LocalSpan $Bitmap $Cell 32 $x1 ($x1+2) (15+$OffsetY) $palette.TissueLight
        for($y=16+$OffsetY; $y -le 24+$OffsetY; $y++) {
            Set-LocalPixel $Bitmap $Cell 32 $x1 $y $palette.TissueDark
            Set-LocalPixel $Bitmap $Cell 32 ($x1+1) $y $palette.TissueLight
            Set-LocalPixel $Bitmap $Cell 32 ($x1+2) $y $palette.Tissue
        }
        Set-LocalPixel $Bitmap $Cell 32 ($x1+1) (25+$OffsetY) $palette.TissueLight
    }
}

function Draw-DaodaoSideTissue([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    Fill-LocalSpan $Bitmap $Cell 32 21 23 (15+$OffsetY) $palette.TissueLight
    for($y=16+$OffsetY; $y -le 24+$OffsetY; $y++) {
        Set-LocalPixel $Bitmap $Cell 32 21 $y $palette.TissueDark
        Set-LocalPixel $Bitmap $Cell 32 22 $y $palette.TissueLight
        Set-LocalPixel $Bitmap $Cell 32 23 $y $palette.Tissue
    }
    Set-LocalPixel $Bitmap $Cell 32 22 (25+$OffsetY) $palette.TissueLight
}

function Draw-YoonFrontGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $top=12+$OffsetY
    foreach($range in @(@(7,13),@(18,24))) {
        $x1=$range[0]; $x2=$range[1]
        Fill-LocalSpan $Bitmap $Cell 32 ($x1+1) ($x2-1) $top $palette.YoonGlassLight
        Set-LocalPixel $Bitmap $Cell 32 $x1 ($top+1) $palette.YoonGlassDark
        Set-LocalPixel $Bitmap $Cell 32 $x2 ($top+1) $palette.YoonGlassDark
        Set-LocalPixel $Bitmap $Cell 32 $x1 ($top+2) $palette.YoonGlass
        Set-LocalPixel $Bitmap $Cell 32 $x2 ($top+2) $palette.YoonGlass
        Set-LocalPixel $Bitmap $Cell 32 $x1 ($top+3) $palette.YoonGlassDark
        Set-LocalPixel $Bitmap $Cell 32 $x2 ($top+3) $palette.YoonGlassDark
        Fill-LocalSpan $Bitmap $Cell 32 ($x1+1) ($x2-1) ($top+4) $palette.YoonGlass
    }
    Fill-LocalSpan $Bitmap $Cell 32 14 17 ($top+2) $palette.YoonGlassDark
}

function Draw-YoonSideGlasses([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$OffsetY) {
    $top=12+$OffsetY
    Fill-LocalSpan $Bitmap $Cell 32 17 26 $top $palette.YoonGlassLight
    Set-LocalPixel $Bitmap $Cell 32 16 ($top+1) $palette.YoonGlassDark
    Set-LocalPixel $Bitmap $Cell 32 27 ($top+1) $palette.YoonGlassDark
    Set-LocalPixel $Bitmap $Cell 32 16 ($top+2) $palette.YoonGlass
    Set-LocalPixel $Bitmap $Cell 32 27 ($top+2) $palette.YoonGlass
    Set-LocalPixel $Bitmap $Cell 32 16 ($top+3) $palette.YoonGlassDark
    Set-LocalPixel $Bitmap $Cell 32 27 ($top+3) $palette.YoonGlassDark
    Fill-LocalSpan $Bitmap $Cell 32 17 26 ($top+4) $palette.YoonGlass
}

function Draw-FaceCell(
    [Drawing.Bitmap]$Bitmap,
    [int]$Cell,
    [string]$Persona,
    [string]$View,
    [int]$Phase
) {
    if($View -eq 'back') { return }
    if($Persona -eq 'tantan') {
        if($View -eq 'front') { Draw-TantanFrontGlasses $Bitmap $Cell $Phase }
        else { Draw-TantanSideGlasses $Bitmap $Cell $Phase }
    } elseif($Persona -eq 'daodao') {
        if($View -eq 'front') { Draw-DaodaoFrontTissues $Bitmap $Cell $Phase }
        else { Draw-DaodaoSideTissue $Bitmap $Cell $Phase }
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
            Draw-HairCell $hair $vanillaHead $cell $persona $view.Name $view.Source $view.Phase
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
