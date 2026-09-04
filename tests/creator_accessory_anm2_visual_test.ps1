param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
$Root=[IO.Path]::GetFullPath($Root)
function Assert-True([bool]$Condition,[string]$Message){if(-not $Condition){throw $Message}}
$specs=@(
 @{Id='17501';Name='tantan_hair';Layer='head1';Width=64;Height=64;PivotX=32;PivotY=44;Priority='98'},
 @{Id='17502';Name='tantan_glasses';Layer='head2';Width=32;Height=32;PivotX=16;PivotY=28;Priority='97'},
 @{Id='17503';Name='daodao_hair';Layer='head1';Width=64;Height=64;PivotX=32;PivotY=44;Priority='98'},
 @{Id='17504';Name='daodao_tissue_tears';Layer='head2';Width=32;Height=32;PivotX=16;PivotY=28;Priority='97'},
 @{Id='17505';Name='yoontoons_hair';Layer='head1';Width=64;Height=64;PivotX=32;PivotY=44;Priority='98'},
 @{Id='17506';Name='yoontoons_glasses';Layer='head2';Width=32;Height=32;PivotX=16;PivotY=28;Priority='97'}
)
$animationStarts=@{HeadDown=0;HeadRight=2;HeadUp=4;HeadLeft=6}
[xml]$costumes=Get-Content -Raw -LiteralPath (Join-Path $Root 'content\costumes2.xml')
foreach($spec in $specs){
 $path=Join-Path $Root "resources\gfx\characters\costume_$($spec.Name).anm2"
 Assert-True (Test-Path -LiteralPath $path) "missing ANM2 $($spec.Name)"
 [xml]$anm2=Get-Content -Raw -LiteralPath $path
 $sheet=@($anm2.AnimatedActor.Content.Spritesheets.Spritesheet)
 $layer=@($anm2.AnimatedActor.Content.Layers.Layer)
 Assert-True ($sheet.Count -eq 1) "$($spec.Name) spritesheet count"
 Assert-True (([string]$sheet[0].Path -replace '\\','/') -eq "costumes/costume_$($spec.Name).png") "$($spec.Name) spritesheet path"
 Assert-True ($layer.Count -eq 1 -and [string]$layer[0].Name -eq $spec.Layer) "$($spec.Name) layer expected $($spec.Layer), got $([string]$layer[0].Name)"
 foreach($animationName in 'HeadDown','HeadRight','HeadUp','HeadLeft'){
  $animation=@($anm2.AnimatedActor.Animations.Animation)|Where-Object Name -eq $animationName|Select-Object -First 1
  Assert-True ($null -ne $animation) "$($spec.Name) $animationName"
  $frames=@($animation.LayerAnimations.LayerAnimation.Frame)
  Assert-True ($frames.Count -eq 2) "$($spec.Name) $animationName frame count"
  for($index=0;$index -lt 2;$index++){
   $frame=$frames[$index]
   $expectedCrop=($animationStarts[$animationName]+$index)*$spec.Width
   Assert-True ([int]$frame.Width -eq $spec.Width -and [int]$frame.Height -eq $spec.Height) "$($spec.Name) $animationName crop size"
   Assert-True ([int]$frame.XCrop -eq $expectedCrop -and [int]$frame.YCrop -eq 0) "$($spec.Name) $animationName crop expected $expectedCrop"
   Assert-True ([int]$frame.XPivot -eq $spec.PivotX -and [int]$frame.YPivot -eq $spec.PivotY) "$($spec.Name) $animationName pivot"
   Assert-True ([int]$frame.YPosition -eq -5 -and [int]$frame.Delay -eq 2) "$($spec.Name) $animationName timing"
  }
 }
 $entry=@($costumes.costumes.costume)|Where-Object {[string]$_.id -eq $spec.Id}|Select-Object -First 1
 Assert-True ($null -ne $entry) "missing costume id $($spec.Id)"
 Assert-True ([string]$entry.anm2path -eq "costume_$($spec.Name).anm2") "costume path $($spec.Id)"
 Assert-True ([string]$entry.type -eq 'none' -and [string]$entry.priority -eq $spec.Priority) "costume flags $($spec.Id)"
}
foreach($reserved in '17499','17500'){
 Assert-True ((@($costumes.costumes.costume)|Where-Object {[string]$_.id -eq $reserved}).Count -eq 0) "historical removed id reused: $reserved"
}
Write-Output 'creator accessory ANM2 contract passed'
