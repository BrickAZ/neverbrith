#requires -Version 7.0
param([ValidatePattern('^[a-z0-9-]+$')][string]$Attempt='discovery-1',[int]$TimeLimitSeconds=55,[switch]$ExitDuringPlayback,
    [ValidateSet('presentation','combat','combat_fix','native_player','normal_targets','horizontal','sa_hud','fist_spd','dp_cinema','recovery_flow','slam_damage')][string]$Probe='presentation')
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'motion-native-state.ps1')
if(Get-Process -Name isaac-ng -ErrorAction SilentlyContinue){throw 'Isaac is already running; will not change or close it.'}
$motionRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$motionFolder=if($Probe-eq 'combat'){'combat-v1/native/'}else{'runtime-fix-v1/'}
$motionReport=if($Probe-eq 'slam_damage'){Join-Path $motionRoot ('reports/motion-items/2026-10-26/spd-splash-damage-v1/native/'+$Attempt)}elseif($Probe-eq 'recovery_flow'){Join-Path $motionRoot ('reports/motion-items/2026-10-25/recovery-control-v1/native/'+$Attempt)}elseif($Probe-eq 'dp_cinema'){Join-Path $motionRoot ('reports/motion-items/2026-10-25/dp-control-cinema-v1/native/'+$Attempt)}elseif($Probe-eq 'fist_spd'){Join-Path $motionRoot ('reports/motion-items/2026-10-25/fist-spd-shortcut-v1/native/'+$Attempt)}elseif($Probe-in 'normal_targets','horizontal'){Join-Path $motionRoot ('reports/motion-items/2026-10-25/horizontal-native-action-v1/native/'+$Attempt)}elseif($Probe-eq 'native_player'){Join-Path $motionRoot ('reports/motion-items/2026-10-25/native-player-free-direction-v1/native/'+$Attempt)}elseif($Probe-eq 'combat_fix'){Join-Path $motionRoot ('reports/motion-items/2026-10-25/grab-od-body-fix-v1/native/'+$Attempt)}elseif($Probe-eq 'sa_hud'){Join-Path $motionRoot ('reports/motion-sa-hud/2026-10-25/v1/native/'+$Attempt)}else{Join-Path $motionRoot ('reports/motion-items/2026-10-24/'+$motionFolder+$Attempt)}
if(Test-Path -LiteralPath $motionReport){throw 'Use a fresh attempt name'}
New-Item -ItemType Directory -Path $motionReport|Out-Null
$motionRoots=@('C:/Users/Anton/Documents/My Games/Binding of Isaac Repentance','C:/Users/Anton/AppData/Roaming/Goldberg SteamEmu Saves/250900','E:/Isaac - Repentance/data')
$motionFiles=@()
for($motionIndex=0;$motionIndex-lt $motionRoots.Count;$motionIndex++){
    $motionStateRoot=$motionRoots[$motionIndex]
    foreach($motionFile in Get-ChildItem -LiteralPath $motionStateRoot -File -Recurse){
        if($motionIndex-eq 0 -and $motionFile.Extension-notin '.dat','.ini','.json' -and $motionFile.Name-ne 'cmd_history.txt'){continue}
        $motionBackup=Join-Path $motionReport ('state/'+$motionIndex+'/'+[IO.Path]::GetRelativePath($motionStateRoot,$motionFile.FullName))
        New-Item -ItemType Directory -Path (Split-Path $motionBackup -Parent) -Force|Out-Null
        Copy-Item -LiteralPath $motionFile.FullName -Destination $motionBackup
        $motionFiles+=@{path=$motionFile.FullName;backup=$motionBackup;hash=(Get-FileHash -LiteralPath $motionFile.FullName).Hash}
    }
}
$motionMain=Join-Path $motionRoot 'main.lua'
$motionBytes=[IO.File]::ReadAllBytes($motionMain)
[IO.File]::WriteAllBytes((Join-Path $motionReport 'main.before.lua'),$motionBytes)
$motionLuaReport=$motionReport.Replace('\','/')
$motionExitFlag=if($ExitDuringPlayback){'true'}else{'false'}
$motionScript=if($Probe-eq 'normal_targets'){'diagnostics/motion_normal_targets_probe'}elseif($Probe-eq 'sa_hud'){'diagnostics/motion_sa_hud_acceptance'}elseif($Probe-in 'combat','combat_fix','native_player','horizontal','fist_spd','dp_cinema','recovery_flow','slam_damage'){'diagnostics/motion_combat_acceptance'}else{'diagnostics/motion_runtime_acceptance'}
$motionFixFlag=if($Probe-in 'combat_fix','native_player','horizontal','fist_spd','dp_cinema','recovery_flow','slam_damage'){'true'}else{'false'}
$motionPlayerFlag=if($Probe-in 'native_player','horizontal','fist_spd','dp_cinema','recovery_flow','slam_damage'){'true'}else{'false'}
$motionHorizontalFlag=if($Probe-in 'horizontal','fist_spd','dp_cinema','recovery_flow','slam_damage'){'true'}else{'false'}
$motionAdditionsFlag=if($Probe-in 'fist_spd','dp_cinema','recovery_flow','slam_damage'){'true'}else{'false'}
$motionControlFlag=if($Probe-in 'dp_cinema','recovery_flow','slam_damage'){'true'}else{'false'}
$motionResponsiveFlag=if($Probe-eq 'recovery_flow'){'true'}else{'false'}
$motionLandingFlag=if($Probe-eq 'slam_damage'){'true'}else{'false'}
$motionExpected=$motionBytes+[Text.Encoding]::UTF8.GetBytes("`n-- MOTION_NATIVE_ACCEPTANCE_TEMPORARY`ninclude(`"$motionScript`")(Neverbirth,{ReportPath=`"$motionLuaReport`",Attempt=`"$Attempt`",ExitDuringPlayback=$motionExitFlag,Fixes=$motionFixFlag,NativePlayer=$motionPlayerFlag,Horizontal=$motionHorizontalFlag,Additions=$motionAdditionsFlag,ControlCinema=$motionControlFlag,Responsiveness=$motionResponsiveFlag,LandingSplash=$motionLandingFlag})`n")
$motionLog='C:/Users/Anton/Documents/My Games/Binding of Isaac Repentance/log.txt'
$motionRecord=[ordered]@{startedUtc=[DateTime]::UtcNow.ToString('o');status='NOT_RUN';inputMethod='game callback only; no desktop mouse or keyboard';stateSnapshotFiles=$motionFiles.Count}
$motionFiles|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $motionReport 'state-manifest.json')
$motionProcess=$null
try{
    [IO.File]::WriteAllBytes($motionMain,$motionExpected)
    $motionOptions='C:/Users/Anton/Documents/My Games/Binding of Isaac Repentance/options.ini'
    $motionRgon='C:/Users/Anton/Documents/My Games/Binding of Isaac Repentance/Repentogon/options.ini'
    [IO.File]::WriteAllText($motionOptions,([IO.File]::ReadAllText($motionOptions)-replace 'PauseOnFocusLost=1','PauseOnFocusLost=0'),[Text.UTF8Encoding]::new($false))
    [IO.File]::WriteAllText($motionRgon,([IO.File]::ReadAllText($motionRgon)-replace '(?m)^SkipIntro\s*=\s*0','SkipIntro = 1'),[Text.UTF8Encoding]::new($false))
    $motionProcess=Start-Process -FilePath 'E:/Isaac - Repentance/isaac-ng.exe' -WorkingDirectory 'E:/Isaac - Repentance' -WindowStyle Hidden -PassThru
    $motionRecord.pid=$motionProcess.Id
    $motionTimer=[Diagnostics.Stopwatch]::StartNew()
    while($motionTimer.Elapsed.TotalSeconds-lt $TimeLimitSeconds){
        Start-Sleep -Milliseconds 250
        $motionProcess.Refresh()
        if($motionProcess.HasExited){$motionRecord.status='EARLY_EXIT';break}
        if(Test-Path -LiteralPath $motionLog){
            try{$motionFreshText=[IO.File]::ReadAllText($motionLog)}catch [IO.IOException]{continue}
            if($motionFreshText.Contains('START attempt='+$Attempt+' ') -and $motionFreshText.Contains('[Motion runtime probe] DONE')){$motionRecord.status='PROBE_DONE';break}
        }
    }
    if($motionRecord.status-eq 'NOT_RUN'){$motionRecord.status='TIMEOUT'}
    if(-not $motionProcess.HasExited){
        # Normal WM_CLOSE for this runner's hidden process, never a user window.
        # No mouse, key, focus or desktop-control API is used.
        Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class MotionProbeClose {
 public delegate bool WindowProc(IntPtr h,IntPtr p);
 [DllImport("user32.dll")]static extern bool EnumWindows(WindowProc f,IntPtr p);
 [DllImport("user32.dll")]static extern uint GetWindowThreadProcessId(IntPtr h,out uint p);
 [DllImport("user32.dll")]static extern bool PostMessage(IntPtr h,uint m,IntPtr w,IntPtr l);
 public static void Close(int pid){EnumWindows((h,p)=>{uint owner;GetWindowThreadProcessId(h,out owner);if(owner==pid)PostMessage(h,0x10,IntPtr.Zero,IntPtr.Zero);return true;},IntPtr.Zero);}
}
'@
        [MotionProbeClose]::Close($motionProcess.Id)
        $motionRecord.normalExit=$motionProcess.WaitForExit(8000)
        if(-not $motionRecord.normalExit){Stop-Process -Id $motionProcess.Id;$motionProcess.WaitForExit();$motionRecord.forcedStop=$true}
    }
    $motionRecord.exitCode=$motionProcess.ExitCode
}finally{
    if($motionProcess -and -not $motionProcess.HasExited){Stop-Process -Id $motionProcess.Id;$motionProcess.WaitForExit()}
    try { if(Test-Path -LiteralPath $motionLog){
        Copy-Item -LiteralPath $motionLog -Destination (Join-Path $motionReport 'game-log.txt')
        $motionCaptured=[IO.File]::ReadAllText((Join-Path $motionReport 'game-log.txt'))
        $motionSummaries=[regex]::Matches($motionCaptured,'SUMMARY checks=(\d+) passed fail=(\d+) cases=(\d+)')
        if($motionCaptured.Contains('START attempt='+$Attempt+' ') -and $motionSummaries.Count){
            $motionSummary=$motionSummaries[$motionSummaries.Count-1]
            $motionRecord.nativeChecksPassed=[int]$motionSummary.Groups[1].Value;$motionRecord.nativeChecksFailed=[int]$motionSummary.Groups[2].Value;$motionRecord.cases=[int]$motionSummary.Groups[3].Value
            if($motionRecord.status-eq 'TIMEOUT' -and $motionRecord.nativeChecksFailed-eq 0){
                $motionRecord.pollingTimedOut=$true;$motionRecord.status='COMPLETED_LOG_FLUSHED_ON_EXIT'
            }
        }
        $motionRecord.cleanShutdown=$motionCaptured.Contains('Isaac has shut down successfully') -and -not $motionCaptured.Contains('Caught exception')
    } } catch { $motionRecord.logCaptureError=$_.Exception.Message }
    $motionSavedSlots=@(3)
    $motionBootMissingSlots=@()
    if($motionCaptured -and $motionCaptured.Contains('START attempt='+$Attempt+' ')){
        $motionSavedSlots=@([regex]::Matches($motionCaptured,'Saving PersistentGameData to Steam Cloud: rep_persistentgamedata([123])\.dat\.')|ForEach-Object {[int]$_.Groups[1].Value}|Select-Object -Unique)
        $motionBootMissingSlots=@([regex]::Matches($motionCaptured,'could not find or open rep_gamestate([123])\.dat\. No Game State detected\.')|ForEach-Object {[int]$_.Groups[1].Value}|Select-Object -Unique)
    }
    $motionRecovery=Restore-MotionProbeState -Files $motionFiles -Roots $motionRoots -Main $motionMain -BeforeMain $motionBytes -ExpectedMain $motionExpected -Report $motionReport -StartedUtc ([datetime]$motionRecord.startedUtc) -ExitedUtc ([DateTime]::UtcNow) -OwnedProcessExited ($motionProcess -and $motionProcess.HasExited) -SavedSlots $motionSavedSlots -BootMissingSlots $motionBootMissingSlots
    foreach($motionField in $motionRecovery.Keys){$motionRecord[$motionField]=$motionRecovery[$motionField]}
    $motionRecord|ConvertTo-Json -Depth 6|Set-Content -LiteralPath (Join-Path $motionReport 'result.json') -Encoding utf8
}
$motionRecord|ConvertTo-Json -Depth 6
if($motionRecord.status-notin 'PROBE_DONE','COMPLETED_LOG_FLUSHED_ON_EXIT' -or $motionRecord.exitCode-ne 0 -or $motionRecord.nativeChecksFailed-ne 0 -or -not $motionRecord.cleanShutdown -or -not $motionRecord.stateRestored){exit 2}
