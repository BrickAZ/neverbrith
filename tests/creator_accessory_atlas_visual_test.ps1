param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
$Root = [IO.Path]::GetFullPath($Root)

$assets = @(
    @{ Name='tantan_hair'; Width=512; Height=64; CellWidth=64; Kind='hair'; Min=430; Max=850; BackMax=950; MinBoxWidth=34; MaxBoxWidth=38; MinBoxHeight=30; MaxBoxHeight=39;
       MinX=12; MaxX=51; MinY=7; MaxY=52;
       Colors=@('#000000','#4A2436','#8F4664','#D87498','#F1A0BA','#FFD0DA') },
    @{ Name='tantan_glasses'; Width=256; Height=32; CellWidth=32; Kind='glasses'; FrontMin=90; FrontMax=135; SideMin=70; SideMax=110;
       Colors=@('#35151B','#641E2A','#8F2635','#C94A57') },
    @{ Name='daodao_hair'; Width=512; Height=64; CellWidth=64; Kind='hair'; Min=440; Max=880; BackMax=1000; MinBoxWidth=34; MaxBoxWidth=39; MinBoxHeight=30; MaxBoxHeight=39;
       MinX=12; MaxX=51; MinY=7; MaxY=52;
       Colors=@('#000000','#1C2940','#2F4A70','#5779A8','#86A4CC','#B9CBE1') },
    @{ Name='daodao_tissue_tears'; Width=256; Height=32; CellWidth=32; Kind='face'; AllowBlank=$true;
       Colors=@('#A9B0BA','#C7CCD2','#F1F1E8') },
    @{ Name='yoontoons_hair'; Width=512; Height=64; CellWidth=64; Kind='hair'; Min=520; Max=1000; BackMax=1400; MinBoxWidth=36; MaxBoxWidth=40; MinBoxHeight=34; MaxBoxHeight=42;
       MinX=12; MaxX=51; MinY=7; MaxY=52;
       Colors=@('#000000','#111827','#263450','#3F5277','#657DA6','#49B6D8') },
    @{ Name='yoontoons_glasses'; Width=256; Height=32; CellWidth=32; Kind='glasses'; FrontMin=105; FrontMax=145; SideMin=80; SideMax=115;
       Colors=@('#181A21','#343943','#5C626C','#9A623B') }
)

function Assert-True([bool]$Condition, [string]$Message) {
    if(-not $Condition) { throw $Message }
}
function Open-BitmapCopy([string]$Path) {
    Assert-True (Test-Path -LiteralPath $Path) "missing atlas: $Path"
    $stream=[IO.File]::OpenRead($Path)
    try {
        $source=[Drawing.Bitmap]::FromStream($stream)
        try { return [Drawing.Bitmap]::new($source) } finally { $source.Dispose() }
    } finally { $stream.Dispose() }
}
function Get-CellVisibleCount([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth) {
    $count=0; $offset=$Cell*$CellWidth
    for($y=0;$y -lt $Bitmap.Height;$y++) {
        for($x=0;$x -lt $CellWidth;$x++) {
            if($Bitmap.GetPixel($offset+$x,$y).A -gt 0) { $count++ }
        }
    }
    return $count
}
function Get-VisibleCount([Drawing.Bitmap]$Bitmap) {
    $count=0
    for($y=0;$y -lt $Bitmap.Height;$y++) { for($x=0;$x -lt $Bitmap.Width;$x++) {
        if($Bitmap.GetPixel($x,$y).A -gt 0) { $count++ }
    }}
    return $count
}
function Get-RegionVisibleCount([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth,[int]$StartX,[int]$EndX,[int]$StartY,[int]$EndY) {
    $count=0; $offset=$Cell*$CellWidth
    for($y=$StartY;$y -le $EndY;$y++) { for($x=$StartX;$x -le $EndX;$x++) {
        if($Bitmap.GetPixel($offset+$x,$y).A -gt 0) { $count++ }
    }}
    return $count
}
function Get-Bounds([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth) {
    $minX=$CellWidth; $maxX=-1; $minY=$Bitmap.Height; $maxY=-1; $offset=$Cell*$CellWidth
    for($y=0;$y -lt $Bitmap.Height;$y++) { for($x=0;$x -lt $CellWidth;$x++) {
        if($Bitmap.GetPixel($offset+$x,$y).A -eq 0) { continue }
        if($x -lt $minX) { $minX=$x }; if($x -gt $maxX) { $maxX=$x }
        if($y -lt $minY) { $minY=$y }; if($y -gt $maxY) { $maxY=$y }
    }}
    return @{ MinX=$minX; MaxX=$maxX; MinY=$minY; MaxY=$maxY; Width=($maxX-$minX+1); Height=($maxY-$minY+1) }
}
function Get-ConnectedComponentCount([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth) {
    $seen=New-Object 'bool[,]' $CellWidth,$Bitmap.Height
    $components=0; $offset=$Cell*$CellWidth
    $directions=@([Drawing.Point]::new(-1,0),[Drawing.Point]::new(1,0),[Drawing.Point]::new(0,-1),[Drawing.Point]::new(0,1))
    for($y=0;$y -lt $Bitmap.Height;$y++) { for($x=0;$x -lt $CellWidth;$x++) {
        if($seen[$x,$y] -or $Bitmap.GetPixel($offset+$x,$y).A -eq 0) { continue }
        $components++; $queue=[Collections.Generic.Queue[Drawing.Point]]::new()
        $queue.Enqueue([Drawing.Point]::new($x,$y)); $seen[$x,$y]=$true
        while($queue.Count -gt 0) {
            $point=$queue.Dequeue()
            foreach($direction in $directions) {
                $nx=$point.X+$direction.X; $ny=$point.Y+$direction.Y
                if($nx -lt 0 -or $nx -ge $CellWidth -or $ny -lt 0 -or $ny -ge $Bitmap.Height) { continue }
                if($seen[$nx,$ny] -or $Bitmap.GetPixel($offset+$nx,$ny).A -eq 0) { continue }
                $seen[$nx,$ny]=$true; $queue.Enqueue([Drawing.Point]::new($nx,$ny))
            }
        }
    }}
    return $components
}
function Get-EnclosedTransparentCount([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth) {
    $bounds=Get-Bounds $Bitmap $Cell $CellWidth
    if($bounds.MaxX -lt $bounds.MinX) { return 0 }
    $seen=New-Object 'bool[,]' $CellWidth,$Bitmap.Height
    $queue=[Collections.Generic.Queue[Drawing.Point]]::new(); $offset=$Cell*$CellWidth
    foreach($x in $bounds.MinX..$bounds.MaxX) { foreach($y in @($bounds.MinY,$bounds.MaxY)) {
        if($Bitmap.GetPixel($offset+$x,$y).A -eq 0 -and -not $seen[$x,$y]) { $seen[$x,$y]=$true; $queue.Enqueue([Drawing.Point]::new($x,$y)) }
    }}
    foreach($y in $bounds.MinY..$bounds.MaxY) { foreach($x in @($bounds.MinX,$bounds.MaxX)) {
        if($Bitmap.GetPixel($offset+$x,$y).A -eq 0 -and -not $seen[$x,$y]) { $seen[$x,$y]=$true; $queue.Enqueue([Drawing.Point]::new($x,$y)) }
    }}
    $directions=@([Drawing.Point]::new(-1,0),[Drawing.Point]::new(1,0),[Drawing.Point]::new(0,-1),[Drawing.Point]::new(0,1))
    while($queue.Count -gt 0) {
        $point=$queue.Dequeue()
        foreach($direction in $directions) {
            $nx=$point.X+$direction.X; $ny=$point.Y+$direction.Y
            if($nx -lt $bounds.MinX -or $nx -gt $bounds.MaxX -or $ny -lt $bounds.MinY -or $ny -gt $bounds.MaxY) { continue }
            if($seen[$nx,$ny] -or $Bitmap.GetPixel($offset+$nx,$ny).A -gt 0) { continue }
            $seen[$nx,$ny]=$true; $queue.Enqueue([Drawing.Point]::new($nx,$ny))
        }
    }
    $enclosed=0
    foreach($y in $bounds.MinY..$bounds.MaxY) { foreach($x in $bounds.MinX..$bounds.MaxX) {
        if($Bitmap.GetPixel($offset+$x,$y).A -eq 0 -and -not $seen[$x,$y]) { $enclosed++ }
    }}
    return $enclosed
}
function Get-MultiSpanRowCount([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth,[int]$StartY,[int]$EndY) {
    $rows=0; $offset=$Cell*$CellWidth
    foreach($y in $StartY..$EndY) {
        $spans=0; $inside=$false
        for($x=0;$x -lt $CellWidth;$x++) {
            $visible=$Bitmap.GetPixel($offset+$x,$y).A -gt 0
            if($visible -and -not $inside) { $spans++; $inside=$true }
            if(-not $visible) { $inside=$false }
        }
        if($spans -ge 2) { $rows++ }
    }
    return $rows
}
function Get-CellBlackCount([Drawing.Bitmap]$Bitmap,[int]$Cell,[int]$CellWidth) {
    $count=0; $offset=$Cell*$CellWidth
    for($y=0;$y -lt $Bitmap.Height;$y++) { for($x=0;$x -lt $CellWidth;$x++) {
        $p=$Bitmap.GetPixel($offset+$x,$y)
        if($p.A -gt 0 -and $p.R -eq 0 -and $p.G -eq 0 -and $p.B -eq 0) { $count++ }
    }}
    return $count
}
function Get-FrameDifference([Drawing.Bitmap]$Bitmap,[int]$CellA,[int]$CellB,[int]$CellWidth) {
    $count=0; $offsetA=$CellA*$CellWidth; $offsetB=$CellB*$CellWidth
    for($y=0;$y -lt $Bitmap.Height;$y++) { for($x=0;$x -lt $CellWidth;$x++) {
        if($Bitmap.GetPixel($offsetA+$x,$y).ToArgb() -ne $Bitmap.GetPixel($offsetB+$x,$y).ToArgb()) { $count++ }
    }}
    return $count
}

$opened=@{}
try {
    foreach($asset in $assets) {
        $path=Join-Path $Root "resources\gfx\characters\costumes\costume_$($asset.Name).png"
        $bitmap=Open-BitmapCopy $path; $opened[$asset.Name]=$bitmap
        Assert-True ($bitmap.Width -eq $asset.Width -and $bitmap.Height -eq $asset.Height) "$($asset.Name) canvas expected $($asset.Width)x$($asset.Height), got $($bitmap.Width)x$($bitmap.Height)"
        $allowed=[Collections.Generic.HashSet[int]]::new()
        foreach($hex in $asset.Colors) { [void]$allowed.Add([Drawing.ColorTranslator]::FromHtml($hex).ToArgb()) }
        for($y=0;$y -lt $bitmap.Height;$y++) { for($x=0;$x -lt $bitmap.Width;$x++) {
            $pixel=$bitmap.GetPixel($x,$y)
            Assert-True ($pixel.A -eq 0 -or $pixel.A -eq 255) "$($asset.Name) semi-alpha at $x,$y"
            if($pixel.A -eq 0) {
                Assert-True ($pixel.R -eq 0 -and $pixel.G -eq 0 -and $pixel.B -eq 0) "$($asset.Name) dirty transparent RGB at $x,$y"
            } else {
                Assert-True ($allowed.Contains($pixel.ToArgb())) "$($asset.Name) palette at $x,$y"
            }
        }}
        foreach($cell in 0..7) {
            $visible=Get-CellVisibleCount $bitmap $cell $asset.CellWidth
            if($asset.Kind -eq 'hair') {
                $maxVisible=if($cell -in 4,5) { $asset.BackMax } else { $asset.Max }
                Assert-True ($visible -ge $asset.Min -and $visible -le $maxVisible) "$($asset.Name) cell $cell coverage $visible"
                $bounds=Get-Bounds $bitmap $cell $asset.CellWidth
                Assert-True ($bounds.Width -ge $asset.MinBoxWidth -and $bounds.Width -le $asset.MaxBoxWidth) "$($asset.Name) cell $cell width $($bounds.Width)"
                Assert-True ($bounds.Height -ge $asset.MinBoxHeight -and $bounds.Height -le $asset.MaxBoxHeight) "$($asset.Name) cell $cell height $($bounds.Height)"
                Assert-True ($bounds.MinX -ge $asset.MinX -and $bounds.MaxX -le $asset.MaxX) "$($asset.Name) cell $cell horizontal anchor $($bounds.MinX)..$($bounds.MaxX)"
                Assert-True ($bounds.MinY -ge $asset.MinY -and $bounds.MaxY -le $asset.MaxY) "$($asset.Name) cell $cell vertical anchor $($bounds.MinY)..$($bounds.MaxY)"
                Assert-True ((Get-ConnectedComponentCount $bitmap $cell $asset.CellWidth) -eq 1) "$($asset.Name) cell $cell disconnected debris"
                Assert-True ((Get-EnclosedTransparentCount $bitmap $cell $asset.CellWidth) -eq 0) "$($asset.Name) cell $cell enclosed transparent hole"
                Assert-True ((Get-CellBlackCount $bitmap $cell $asset.CellWidth) -ge 40) "$($asset.Name) cell $cell lacks attached black outline"
                if($cell -notin 4,5) {
                    Assert-True ((Get-MultiSpanRowCount $bitmap $cell $asset.CellWidth 25 48) -ge 5) "$($asset.Name) cell $cell reads as a solid plate"
                    Assert-True ((Get-RegionVisibleCount $bitmap $cell $asset.CellWidth 25 38 37 48) -le 4) "$($asset.Name) cell $cell closes the lower face"
                }
                if($cell -in 0,1) {
                    $leftEyeOverlap=Get-RegionVisibleCount $bitmap $cell $asset.CellWidth 22 27 29 35
                    $rightEyeOverlap=Get-RegionVisibleCount $bitmap $cell $asset.CellWidth 36 41 29 35
                    Assert-True ($leftEyeOverlap -le 4) "$($asset.Name) cell $cell covers the left eye band ($leftEyeOverlap/42)"
                    Assert-True ($rightEyeOverlap -le 4) "$($asset.Name) cell $cell covers the right eye band ($rightEyeOverlap/42)"
                    Assert-True (($leftEyeOverlap+$rightEyeOverlap) -le 6) "$($asset.Name) cell $cell hides the front expression ($($leftEyeOverlap+$rightEyeOverlap)/84)"
                } elseif($cell -in 2,3,6,7) {
                    $sideEyeOverlap=Get-RegionVisibleCount $bitmap $cell $asset.CellWidth 31 38 29 35
                    Assert-True ($sideEyeOverlap -le 6) "$($asset.Name) cell $cell covers the side eye band ($sideEyeOverlap/56)"
                }
            } elseif($asset.AllowBlank) {
                Assert-True ($visible -eq 0) "$($asset.Name) cell $cell must be blank"
            } elseif($cell -in 4,5) {
                Assert-True ($visible -eq 0) "$($asset.Name) back cell $cell must be blank"
            } elseif($cell -in 0,1) {
                Assert-True ($visible -ge $asset.FrontMin -and $visible -le $asset.FrontMax) "$($asset.Name) front cell $cell coverage $visible"
            } else {
                Assert-True ($visible -ge $asset.SideMin -and $visible -le $asset.SideMax) "$($asset.Name) side cell $cell coverage $visible"
            }
        }
        if($asset.Kind -eq 'hair') {
            foreach($pair in @(@(0,1),@(2,3),@(4,5),@(6,7))) {
                $diff=Get-FrameDifference $bitmap $pair[0] $pair[1] $asset.CellWidth
                Assert-True ($diff -ge 12) "$($asset.Name) pair $($pair[0])/$($pair[1]) is static ($diff differing pixels)"
            }
        }
    }
    Assert-True ((Get-VisibleCount $opened['daodao_tissue_tears']) -eq 0) 'Daodao tissue atlas must be fully transparent'
    foreach($cell in 0,1) {
        Assert-True ((Get-RegionVisibleCount $opened['tantan_glasses'] $cell 32 14 17 13 15) -ge 4) "Tantan glasses cell $cell needs a readable center bridge"
        Assert-True ((Get-RegionVisibleCount $opened['yoontoons_glasses'] $cell 32 14 17 13 15) -ge 4) "Yoontoons glasses cell $cell needs a readable center bridge"
        Assert-True ((Get-RegionVisibleCount $opened['tantan_glasses'] $cell 6 11 15 17) -le 3) "Tantan glasses cell $cell must leave the left lens open"
        Assert-True ((Get-RegionVisibleCount $opened['tantan_glasses'] $cell 20 25 15 17) -le 3) "Tantan glasses cell $cell must leave the right lens open"
        Assert-True ((Get-RegionVisibleCount $opened['yoontoons_glasses'] $cell 6 11 15 17) -le 4) "Yoontoons glasses cell $cell must leave the left lens open"
        Assert-True ((Get-RegionVisibleCount $opened['yoontoons_glasses'] $cell 20 25 15 17) -le 4) "Yoontoons glasses cell $cell must leave the right lens open"
    }
} finally {
    foreach($bitmap in $opened.Values) { $bitmap.Dispose() }
}
Write-Output 'creator accessory atlas visual contract passed'

