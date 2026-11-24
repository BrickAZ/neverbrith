#requires -Version 7.0
[CmdletBinding()]
param([ValidateRange(10,60)][int]$TimeLimitSeconds=40)
$ErrorActionPreference='Stop'
if(Get-Process -Name isaac-ng -ErrorAction SilentlyContinue){throw 'Isaac is running; refusing to interrupt the existing process.'}
$motionRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$motionGame=[IO.Path]::GetFullPath((Join-Path $motionRoot '../..'))
$motionReport=Join-Path $motionRoot 'reports/motion-runtime/2026-10-23/integration-v1/native'
New-Item -ItemType Directory -Force -Path $motionReport|Out-Null
$motionMain=Join-Path $motionRoot 'main.lua'
$motionOriginal=[IO.File]::ReadAllBytes($motionMain)
$motionHash=(Get-FileHash -LiteralPath $motionMain).Hash
$motionSuffix=[Text.Encoding]::UTF8.GetBytes("`n-- MOTION_NATIVE_ASSET_PROBE_TEMPORARY`ninclude(`"diagnostics/motion_assets_engine_probe`")(Neverbirth)`n")
$motionExpected=$motionOriginal+$motionSuffix
$motionLog=Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'My Games/Binding of Isaac Repentance/log.txt'
$motionUserRoot=Split-Path -Parent $motionLog
$motionBefore=@{}
foreach($motionFile in Get-ChildItem -LiteralPath $motionUserRoot -File){
    if($motionFile.Extension-in '.dat','.ini','.json' -or $motionFile.Name-eq 'cmd_history.txt'){
        $motionBefore[$motionFile.FullName]=(Get-FileHash -LiteralPath $motionFile.FullName).Hash
    }
}
$motionRecord=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');kind='menu-only native load/frame/render-layer check';status='NOT_RUN';mainBefore=$motionHash}
$motionProcess=$null
try{
    [IO.File]::WriteAllBytes($motionMain,$motionExpected)
    $motionProcess=Start-Process -FilePath (Join-Path $motionGame 'isaac-ng.exe') -WorkingDirectory $motionGame -WindowStyle Hidden -PassThru
    $motionRecord.pid=$motionProcess.Id
    $motionWatch=[Diagnostics.Stopwatch]::StartNew()
    while($motionWatch.Elapsed.TotalSeconds-lt $TimeLimitSeconds){
        Start-Sleep -Milliseconds 250
        $motionProcess.Refresh()
        if(Test-Path -LiteralPath $motionLog){
            $motionText=Get-Content -LiteralPath $motionLog -Raw
            if((Get-Item -LiteralPath $motionLog).LastWriteTimeUtc-ge [datetime]$motionRecord.startedUtc -and $motionText-match '\[Motion native probe\] (PASS|FAIL)'){
                $motionRecord.status=$Matches[1];break
            }
        }
        if($motionProcess.HasExited){$motionRecord.status='EXITED_BEFORE_RESULT';$motionRecord.gameExitCode=$motionProcess.ExitCode;break}
    }
    if($motionRecord.status-eq 'NOT_RUN'){$motionRecord.status='TIMEOUT'}
    if(Test-Path -LiteralPath $motionLog){
        $motionRecord.logFresh=(Get-Item -LiteralPath $motionLog).LastWriteTimeUtc-ge [datetime]$motionRecord.startedUtc
        Copy-Item -LiteralPath $motionLog -Destination (Join-Path $motionReport 'game-log.txt') -Force
    }
}finally{
    if($motionProcess-and -not $motionProcess.HasExited){
        Stop-Process -Id $motionProcess.Id
        $motionProcess.WaitForExit(5000)|Out-Null
        $motionRecord.teardown='Stopped only the owned menu-only test process.'
    }
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($motionMain))-ne [Convert]::ToBase64String($motionExpected)){
        throw 'Main changed during native check; refusing to overwrite external changes.'
    }
    [IO.File]::WriteAllBytes($motionMain,$motionOriginal)
    $motionRecord.mainRestored=(Get-FileHash -LiteralPath $motionMain).Hash-eq $motionHash
    $motionRecord.userStateChanges=@($motionBefore.Keys|Where-Object { -not (Test-Path -LiteralPath $_) -or (Get-FileHash -LiteralPath $_).Hash-ne $motionBefore[$_] })
    $motionRecord|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $motionReport 'result.json') -Encoding utf8
}
$motionRecord|ConvertTo-Json -Depth 6
if($motionRecord.status-ne 'PASS'){exit 2}
