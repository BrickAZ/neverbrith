#requires -Version 7.0
[CmdletBinding()]
param([ValidatePattern('^[a-z0-9-]+$')][string]$Attempt='native-01',[ValidateRange(10,60)][int]$Seconds=40,
    [ValidateSet('runtime','weapons','visual_contact','visual_baseline','visual_fixed','audio','audio_start_rush','burnout_input','mechanic_audit','controls','dot_ownership','dot_damage_contract','icon')][string]$Probe='runtime')
$ErrorActionPreference='Stop'
if(Get-Process isaac-ng -ErrorAction SilentlyContinue){throw 'Existing game session is left untouched; close it before the acceptance run.'}
$modRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$gameRoot=[IO.Path]::GetFullPath((Join-Path $modRoot '../..'))
$report=Join-Path $modRoot "reports/drive-rush/2026-10-14/implementation-v1/$Attempt"
if(Test-Path -LiteralPath $report){throw 'Use a fresh attempt name.'}
New-Item -ItemType Directory -Path $report | Out-Null
$localState='C:/Users/Anton/Documents/My Games/Binding of Isaac Repentance'
$remoteState='C:/Users/Anton/AppData/Roaming/Goldberg SteamEmu Saves/250900/remote'
# The main-menu preview loads all three persistent slots. Protect every named
# slot, even when the test does not select a save. New test files are archived,
# never recursively deleted. No dated historical backups are restored.
$paths=@("$localState/options.ini","$localState/Repentogon/options.ini")
foreach($slot in 1..3){
    $paths+=@("$localState/Repentogon/completionmarks$slot.json","$localState/Repentogon/customitempool_gamestate$slot.json",
        "$remoteState/rep_gamestate$slot.dat","$remoteState/rep_persistentgamedata$slot.dat",
        "$gameRoot/data/neverbrith/save$slot.dat")
}
$records=@()
foreach($path in $paths){
    $dest=Join-Path $report ('state-'+$records.Count)
    $existed=Test-Path -LiteralPath $path
    if($existed){Copy-Item -LiteralPath $path -Destination $dest}
    $records+=@{path=$path;backup=$dest;existed=$existed;hash=$(if($existed){(Get-FileHash -LiteralPath $path).Hash}else{$null})}
}
$records | ConvertTo-Json | Set-Content (Join-Path $report 'state-manifest.json')
$main=Join-Path $modRoot 'main.lua'; $original=[IO.File]::ReadAllBytes($main)
$expected=$original+[Text.Encoding]::UTF8.GetBytes("`ninclude(`"diagnostics/drive_glove_$Probe`")(Neverbirth)`n")
$process=$null; $found=$false; $startedUtc=[DateTime]::UtcNow
$log=Join-Path $localState 'log.txt'
try {
    $mainTemp=Join-Path $modRoot 'main.drive-glove-probe.tmp'
    if(Test-Path -LiteralPath $mainTemp){throw 'Probe temporary file already exists.'}
    [IO.File]::WriteAllBytes($mainTemp,$expected)
    Move-Item -LiteralPath $mainTemp -Destination $main -Force
    $enc=[Text.UTF8Encoding]::new($false)
    foreach($pair in @(@("$localState/options.ini",'PauseOnFocusLost=1','PauseOnFocusLost=0'),@("$localState/Repentogon/options.ini",'SkipIntro = 0','SkipIntro = 1'))){
        $text=[IO.File]::ReadAllText($pair[0]); [IO.File]::WriteAllText($pair[0],$text.Replace($pair[1],$pair[2]),$enc)
    }
    $process=Start-Process -FilePath (Join-Path $gameRoot 'isaac-ng.exe') -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while($timer.Elapsed.TotalSeconds -lt $Seconds){
        Start-Sleep -Milliseconds 300
        if((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).LastWriteTimeUtc -ge $startedUtc){
            if((Get-Content -LiteralPath $log -Raw) -match '\[Drive Glove runtime\] DONE'){$found=$true; break}
        }
        $process.Refresh(); if($process.HasExited){break}
    }
} finally {
    if($process -and -not $process.HasExited){Stop-Process -Id $process.Id; $process.WaitForExit(5000) | Out-Null}
    if(Test-Path -LiteralPath $log){Copy-Item -LiteralPath $log -Destination (Join-Path $report 'game-log.txt')}
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($main)) -eq [Convert]::ToBase64String($expected)){
        [IO.File]::WriteAllBytes($mainTemp,$original)
        Move-Item -LiteralPath $mainTemp -Destination $main -Force
    }
    foreach($record in $records){
        if(-not $record.existed){
            if(Test-Path -LiteralPath $record.path){Move-Item -LiteralPath $record.path -Destination ($record.backup+'-created')}
            continue
        }
        if((Get-FileHash -LiteralPath $record.path).Hash -ne $record.hash){Copy-Item -LiteralPath $record.backup -Destination $record.path}
        if((Get-FileHash -LiteralPath $record.path).Hash -ne $record.hash){throw "State hash not restored: $($record.path)"}
    }
    @{done=$found;restoredFiles=$records.Count;mainRestored=([Convert]::ToBase64String([IO.File]::ReadAllBytes($main)) -eq [Convert]::ToBase64String($original));startedUtc=$startedUtc} | ConvertTo-Json | Set-Content (Join-Path $report 'result.json')
}
Get-Content (Join-Path $report 'game-log.txt') | Select-String 'Drive Glove runtime|Error|error|drive_glove'
if(-not $found){exit 2}
if((Get-Content (Join-Path $report 'game-log.txt') -Raw) -match '\[Drive Glove runtime\] FAIL|Error in callback|Error in lua'){exit 1}
