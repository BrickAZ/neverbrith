#requires -Version 7.0
# Startup/resource smoke only: never starts/continues a run or restores/deletes saves.
[CmdletBinding()]
param([string]$Attempt='startup-01',[ValidateRange(10,60)][int]$Seconds=30)
$ErrorActionPreference='Stop'
if(Get-Process isaac-ng -ErrorAction SilentlyContinue){throw 'Isaac is already running; leave the existing session untouched.'}
$modRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$gameRoot=[IO.Path]::GetFullPath((Join-Path $modRoot '../..'))
$report=Join-Path $modRoot "reports/drive-rush/2026-10-14/implementation-v1/$Attempt"
if(Test-Path -LiteralPath $report){throw 'Use a fresh attempt name.'}
New-Item -ItemType Directory -Path $report | Out-Null
$main=Join-Path $modRoot 'main.lua'; $original=[IO.File]::ReadAllBytes($main)
$suffix=[Text.Encoding]::UTF8.GetBytes("`ninclude(`"diagnostics/drive_glove_startup`")(Neverbirth)`n")
$expected=$original+$suffix
[IO.File]::WriteAllBytes($main,$expected)
$process=$null; $found=$false
$startedUtc=[DateTime]::UtcNow
$log='C:/Users/Anton/Documents/My Games/Binding of Isaac Repentance/log.txt'
try {
    $process=Start-Process -FilePath (Join-Path $gameRoot 'isaac-ng.exe') -WorkingDirectory $gameRoot -WindowStyle Hidden -PassThru
    $timer=[Diagnostics.Stopwatch]::StartNew()
    while($timer.Elapsed.TotalSeconds -lt $Seconds){
        Start-Sleep -Milliseconds 300
        if((Test-Path -LiteralPath $log) -and (Get-Item -LiteralPath $log).LastWriteTimeUtc -ge $startedUtc){$text=Get-Content -LiteralPath $log -Raw; if($text -match '\[Drive Glove startup\] DONE'){$found=$true; break}}
        $process.Refresh(); if($process.HasExited){break}
    }
} finally {
    if($process -and -not $process.HasExited){Stop-Process -Id $process.Id; $process.WaitForExit(5000) | Out-Null}
    if(Test-Path -LiteralPath $log){Copy-Item -LiteralPath $log -Destination (Join-Path $report 'game-log.txt')}
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($main)) -eq [Convert]::ToBase64String($expected)){
        [IO.File]::WriteAllBytes($main,$original)
    }else{throw 'Main changed during smoke test; refusing to overwrite concurrent edits.'}
    @{done=$found;mainRestored=$true;startedUtc=$startedUtc;processExitCode=$(if($process){$process.ExitCode});freshLog=((Get-Item -LiteralPath $log).LastWriteTimeUtc -ge $startedUtc);scope='main menu and assets only; no run started; no save restore/delete'} | ConvertTo-Json | Set-Content (Join-Path $report 'result.json')
}
Get-Content (Join-Path $report 'game-log.txt') | Select-String 'Drive Glove startup|Error|error|drive_glove'
if(-not $found){exit 2}
if((Get-Content (Join-Path $report 'game-log.txt') -Raw) -match '\[Drive Glove startup\] FAIL'){exit 1}
