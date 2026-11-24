#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidatePattern('^yin_[a-z_]+$')][string]$Script='yin_runtime_probe',
    [ValidatePattern('^[a-z0-9-]+$')][string]$Stage='runtime-attempt-2',
    [string]$StopOn='\[Yin runtime probe\] main-menu-render',
    [ValidateRange(10,120)][int]$TimeLimitSeconds=30
)
$ErrorActionPreference='Stop'
if(Get-Process -Name isaac-ng -ErrorAction SilentlyContinue){throw 'Close Isaac before starting this isolated acceptance process'}
$yinMod=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$yinGame='E:\Isaac - Repentance'
$yinState=Get-Content -LiteralPath (Join-Path $yinMod 'release/yin-native-interface/2026-10-02/backups/pre-runtime-state/state-manifest.json') -Raw|ConvertFrom-Json
if($yinState.status-ne 'snapshotted'){throw 'This runtime snapshot is closed; prepare a fresh state snapshot before another acceptance session'}
if((Get-FileHash -LiteralPath $yinState.mainPath).Hash-ne $yinState.mainSha256){throw 'main changed after state snapshot; inspect before adding loader'}
$yinReport=Join-Path $yinMod ('reports/yins-curse/native-interface/2026-10-02/'+$Stage)
if(Test-Path -LiteralPath $yinReport){throw 'Use a fresh runtime attempt directory'}
New-Item -ItemType Directory -Path $yinReport|Out-Null
$yinOriginal=[IO.File]::ReadAllBytes($yinState.mainBackup)
$yinSuffix=[Text.Encoding]::UTF8.GetBytes("`n-- YIN_RUNTIME_ACCEPTANCE_TEMPORARY_BEGIN`ninclude(`"diagnostics/$Script`")(Neverbirth)`n-- YIN_RUNTIME_ACCEPTANCE_TEMPORARY_END`n")
$yinStageMarker=[Text.Encoding]::UTF8.GetBytes("`nNEVERBIRTH_YIN_TEST_STAGE=`"$Stage`"`n")
$yinExpected=$yinOriginal+$yinStageMarker+$yinSuffix
[IO.File]::WriteAllBytes($yinState.mainPath,$yinExpected)
$yinProcess=$null;$yinMatched=$false;$yinRecord=[ordered]@{script=$Script;startedUtc=[DateTime]::UtcNow.ToString('o');stopOn=$StopOn;timeLimitSeconds=$TimeLimitSeconds}
try{
    $yinLog='C:\Users\Anton\Documents\My Games\Binding of Isaac Repentance\log.txt'
    $yinProcess=Start-Process -FilePath (Join-Path $yinGame 'isaac-ng.exe') -WorkingDirectory $yinGame -WindowStyle Hidden -PassThru
    $yinRecord.pid=$yinProcess.Id
    $yinTimer=[Diagnostics.Stopwatch]::StartNew()
    while($yinTimer.Elapsed.TotalSeconds-lt $TimeLimitSeconds){
        Start-Sleep -Milliseconds 300
        $yinProcess.Refresh()
        if(Test-Path -LiteralPath $yinLog){
            $yinText=Get-Content -LiteralPath $yinLog -Raw
            if($yinText.Contains("YIN_RUNTIME_STAGE=$Stage") -and $yinText-match $StopOn){$yinMatched=$true;break}
        }
        if($yinProcess.HasExited){break}
    }
    $yinRecord.markerFound=$yinMatched
    $yinRecord.exitedBeforeTeardown=$yinProcess.HasExited
    if($yinProcess.HasExited){$yinRecord.gameExitCode=$yinProcess.ExitCode}
    else{Stop-Process -Id $yinProcess.Id; $yinProcess.WaitForExit(5000)|Out-Null;$yinRecord.teardown='terminated owned test process after evidence or timeout'}
    Copy-Item -LiteralPath $yinLog -Destination (Join-Path $yinReport 'game-log.txt')
    foreach($yinName in 'repentogon.log','zhl.log','dsound.log'){
        Copy-Item -LiteralPath (Join-Path $yinGame $yinName) -Destination (Join-Path $yinReport $yinName)
    }
    Copy-Item -LiteralPath (Join-Path $yinMod 'release/yin-native-interface/2026-10-02/candidate/candidate-manifest.json') -Destination (Join-Path $yinReport 'candidate-manifest.json')
}finally{
    if($yinProcess -and -not $yinProcess.HasExited){Stop-Process -Id $yinProcess.Id -ErrorAction SilentlyContinue}
    if([Convert]::ToBase64String([IO.File]::ReadAllBytes($yinState.mainPath))-ne [Convert]::ToBase64String($yinExpected)){throw 'main was changed externally; temporary loader requires manual inspection'}
    [IO.File]::WriteAllBytes($yinState.mainPath,$yinOriginal)
    $yinRecord.mainRestored=(Get-FileHash -LiteralPath $yinState.mainPath).Hash-eq $yinState.mainSha256
    $yinRecord|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $yinReport 'run.json') -Encoding utf8
}
$yinRecord|ConvertTo-Json -Depth 6
if(-not $yinMatched){exit 2}
