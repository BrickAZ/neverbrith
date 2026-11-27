#requires -Version 7.0
param([string]$ReportPath)
$ErrorActionPreference='Stop'
$validator=Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/validators/validate-isaac-mod.ps1'
$pwsh=(Get-Process -Id $PID).Path
$tempRoot=[IO.Path]::GetFullPath([IO.Path]::GetTempPath())
$sandbox=Join-Path $tempRoot ('neverbrith asset checks '+[guid]::NewGuid().ToString('N'))
$results=[Collections.Generic.List[object]]::new()
function Put([string]$path,[string]$body) {
    $full=Join-Path $sandbox $path
    [IO.Directory]::CreateDirectory((Split-Path -Parent $full)) | Out-Null
    [IO.File]::WriteAllText($full,$body)
}
function Run([string]$name,[string]$root,[string[]]$extra,[int]$expected,[string]$required,[string]$forbidden='') {
    $arguments=@('-NoProfile','-File',$validator,'-Root',(Join-Path $sandbox $root))+$extra
    $output=(& $pwsh @arguments 2>&1 | Out-String)
    $code=$LASTEXITCODE
    $passed=$code -eq $expected -and $output -match $required -and (-not $forbidden -or $output -notmatch $forbidden)
    $results.Add([pscustomobject]@{Name=$name;Passed=$passed;ExitCode=$code;Arguments=$arguments;Output=$output})
    Write-Output "$(if($passed){'PASS'}else{'FAIL'}) $name"
}
try {
    $xml='<items gfxroot="gfx/Items/" deathanm2="gfx/UI/Death.anm2"><passive id="1" name="CurrentItem" gfx="Collectibles_025_Breakfast.png" /></items>'
    Put 'game/isaac-ng.exe' 'marker only, never executed'
    Put 'game/resources/gfx/Items/Collectibles/Collectibles_025_Breakfast.png' 'fixture'
    Put 'game/mods/demo/content/items.xml' $xml
    Put 'game/mods/demo/content/gfx/UI/Death.anm2' 'fixture'
    Put 'game/mods/demo/content/players.xml' '<players><!-- Deferred characters: no active registration. --></players>'
    Put 'game/mods/demo/deprecated/characters/players.xml' '<players><player name="Unused" skin="missing.png" /></players>'
    Run 'automatic game discovery and inactive archives' 'game/mods/demo' @() 0 '0 warning\(s\)' 'WARN |FAIL '
    Put 'copy/content/items.xml' $xml
    Put 'copy/content/gfx/UI/Death.anm2' 'fixture'
    Run 'explicit game resources' 'copy' @('-GameRoot',(Join-Path $sandbox 'game')) 0 'Native asset found' 'WARN |FAIL '
    Run 'unavailable native resource still warns' 'copy' @() 0 'WARN .*Breakfast' '0 warning\(s\)'
    Put 'wrong/content/items.xml' $xml
    Put 'wrong/resources/gfx/UI/Death.anm2' 'wrong location'
    Run 'resource copy cannot mask missing content deathanm2' 'wrong' @('-GameRoot',(Join-Path $sandbox 'game')) 0 'WARN .*deathanm2' 'WARN .*Breakfast'
    Put 'folder/content/items.xml' '<items><passive id="1" gfx="fake.png" /></items>'
    [IO.Directory]::CreateDirectory((Join-Path $sandbox 'folder/resources/fake.png')) | Out-Null
    Run 'directories cannot satisfy asset files' 'folder' @() 0 'WARN .*fake.png'
    Run 'invalid explicit game root fails' 'copy' @('-GameRoot',(Join-Path $sandbox 'absent')) 1 'FAIL Invalid GameRoot'
    if($ReportPath){$full=[IO.Path]::GetFullPath($ReportPath);[IO.Directory]::CreateDirectory((Split-Path -Parent $full))|Out-Null;$results|ConvertTo-Json -Depth 5|Set-Content -LiteralPath $full -Encoding utf8}
    if(@($results|Where-Object{-not $_.Passed}).Count){throw 'Generic asset validation regression'}
} finally {
    if(Test-Path -LiteralPath $sandbox){
        $resolved=(Resolve-Path -LiteralPath $sandbox).Path
        if(-not $resolved.StartsWith($tempRoot,[StringComparison]::OrdinalIgnoreCase) -or (Split-Path -Leaf $resolved) -notlike 'neverbrith asset checks *'){throw 'Unexpected temporary cleanup target'}
        Remove-Item -LiteralPath $resolved -Recurse -Force
    }
}
