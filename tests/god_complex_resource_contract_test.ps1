param([string]$Root=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$rootPath=[IO.Path]::GetFullPath($Root)
function Assert-True($Condition,[string]$Message) { if(-not $Condition){throw $Message} }
foreach($locale in @('','en_us','zh_cn')) {
    $suffix=if($locale){'.'+$locale}else{''}
    [xml]$items=Get-Content -LiteralPath (Join-Path $rootPath "content/items$suffix.xml") -Raw
    $entries=@($items.items.ChildNodes | Where-Object {$_.LocalName -in @('active','passive','familiar')})
    Assert-True (($entries | Group-Object id | Where-Object Count -ne 1).Count -eq 0) 'duplicate local IDs'
    $entry=@($entries | Where-Object id -eq '60')
    Assert-True ($entry.Count -eq 1) "one ID 60 in $locale"
    $name=if($locale -eq 'zh_cn'){'神性过载'}else{'God Complex'}
    Assert-True ($entry[0].LocalName -eq 'active' -and $entry[0].name -eq $name -and $entry[0].quality -eq '3' -and $entry[0].maxcharges -eq '2') 'God Complex metadata'
    Assert-True ($entry[0].gfx -eq 'god_complex.png' -and $entry[0].description -eq 'Too much power for one body.') 'native icon and subtitle'
    $old=@($entries | Where-Object id -eq '59')[0]
    Assert-True ($old.gfx -eq 'i_am_a_god.png' -and $old.maxcharges -eq '8') 'I Am a God preserved'
    [xml]$pools=Get-Content -LiteralPath (Join-Path $rootPath "content/itempools$suffix.xml") -Raw
    $refs=@($pools.SelectNodes('/ItemPools/Pool/Item') | Where-Object { $_.GetAttribute('Name') -eq $name })
    Assert-True ($refs.Count -eq 1 -and $refs[0].ParentNode.GetAttribute('Name') -eq 'treasure' -and $refs[0].Weight -eq '1') 'only treasure pool, weight 1'
    Assert-True (@($pools.SelectNodes('/ItemPools/Pool/Item') | Where-Object { $_.GetAttribute('Name') -eq $old.name }).Count -eq 0) 'I Am a God remains outside pools'
}
Add-Type -AssemblyName System.Drawing
$lua=Get-Content -LiteralPath (Join-Path $rootPath 'god_complex.lua') -Raw
$haloBlock=[regex]::Match($lua,'(?s)local SOLAR_HALO_BOUNDS=\{(.*?)\n\s*\}')
Assert-True $haloBlock.Success 'solar halo alpha bounds contract missing'
$haloBounds=@([regex]::Matches($haloBlock.Groups[1].Value,'\{(\d+),(\d+),(\d+),(\d+)\}'))
Assert-True ($haloBounds.Count -eq 8) 'eight solar halo alpha bounds'
$specs=@(
    @{File='GodComplexState';Names=@('Solar','War','Eye');Width=64;Height=32;PX=32;PY=28;Loop='true'},
    @{File='GodComplexSolarHalo';Names=@('SolarHalo');Width=64;Height=64;PX=32;PY=32;Loop='true'},
    @{File='GodComplexEyeMark';Names=@('EyeMark');Width=64;Height=64;PX=32;PY=52;Loop='true'},
    @{File='GodComplexJudgment';Names=@('Judgment');Width=64;Height=96;PX=32;PY=88;Loop='false'}
)
$cropCount=0
foreach($spec in $specs) {
    $path=Join-Path $rootPath ('resources/gfx/Effects/GodComplex/'+$spec.File+'.anm2')
    [xml]$doc=Get-Content -LiteralPath $path -Raw
    Assert-True ($doc.AnimatedActor.Info.Fps -eq '30') '30 FPS animation'
    $png=Join-Path (Split-Path $path) $doc.AnimatedActor.Content.Spritesheets.Spritesheet.Path
    $bmp=[Drawing.Bitmap]::new($png)
    try {
        foreach($name in $spec.Names) {
            $a=@($doc.AnimatedActor.Animations.Animation | Where-Object Name -eq $name)
            Assert-True ($a.Count -eq 1 -and $a[0].Loop -eq $spec.Loop) "animation $name loop"
            $frames=@($a[0].LayerAnimations.LayerAnimation.Frame)
            Assert-True ((($frames | Measure-Object Delay -Sum).Sum) -eq [int]$a[0].FrameNum) "animation $name duration"
            $frameIndex=0
            foreach($frame in $frames) {
                Assert-True ([int]$frame.Width -eq $spec.Width -and [int]$frame.Height -eq $spec.Height -and [int]$frame.XPivot -eq $spec.PX -and [int]$frame.YPivot -eq $spec.PY) "crop/pivot $name"
                Assert-True ([int]$frame.XCrop -ge 0 -and [int]$frame.YCrop -ge 0 -and ([int]$frame.XCrop+$spec.Width) -le $bmp.Width -and ([int]$frame.YCrop+$spec.Height) -le $bmp.Height) "bounds $name"
                if($name -eq 'SolarHalo') {
                    Assert-True ($frames.Count -eq 8 -and [int]$frame.Delay -eq 3 -and [int]$frame.XCrop -eq $frameIndex*64) 'halo animation frame mapping'
                    foreach($node in @($a[0].RootAnimation.Frame)+@($frame)) {
                        Assert-True ([int]$node.XScale -eq 100 -and [int]$node.YScale -eq 100 -and [int]$node.XPosition -eq 0 -and [int]$node.YPosition -eq 0 -and [int]$node.Rotation -eq 0) 'halo frame transform must match Lua alpha calibration'
                    }
                    $minX=64; $minY=64; $maxX=0; $maxY=0
                    for($y=0;$y -lt 64;$y++){for($x=0;$x -lt 64;$x++){
                        if($bmp.GetPixel([int]$frame.XCrop+$x,[int]$frame.YCrop+$y).A -gt 0) {
                            $minX=[Math]::Min($minX,$x); $minY=[Math]::Min($minY,$y)
                            $maxX=[Math]::Max($maxX,$x+1); $maxY=[Math]::Max($maxY,$y+1)
                        }
                    }}
                    $expected=$haloBounds[$frameIndex].Groups
                    Assert-True ($minX -eq [int]$expected[1].Value -and $minY -eq [int]$expected[2].Value -and $maxX -eq [int]$expected[3].Value -and $maxY -eq [int]$expected[4].Value) "halo visible alpha bounds match Lua frame $frameIndex"
                }
                $frameIndex++
                $cropCount++
            }
        }
    } finally {$bmp.Dispose()}
}
$atlas=[Drawing.Bitmap]::new((Join-Path $rootPath 'resources/gfx/UI/NeverbirthDeathItems.png'))
$cell=[Drawing.Bitmap]::new((Join-Path $rootPath 'resources/gfx/UI/GodComplex_death_cell.png'))
try {
    for($y=0;$y -lt 16;$y++){for($x=0;$x -lt 16;$x++){
        Assert-True ($atlas.GetPixel($x,48+$y).ToArgb() -eq $cell.GetPixel($x,$y).ToArgb()) 'cell 60 matches supplied source'
    }}
} finally {$atlas.Dispose();$cell.Dispose()}
& (Join-Path $rootPath 'tools/generate-neverbirth-collectibles.ps1') -Root $rootPath -Check
& (Join-Path $rootPath 'tools/validate_mystuff_local_ids.ps1') -Root $rootPath
Write-Output "God Complex resource contract passed: 3 metadata/pool pairs, 6 animations, $cropCount crops, exact cell 60, generated registry. Native rendering remains unverified."
