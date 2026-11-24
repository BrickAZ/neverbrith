# File-only helpers; no process or input control. Dot-sourced by the native runner.
function Get-MotionStateFiles([string[]]$Roots) {
    for($index=0;$index-lt $Roots.Count;$index++) {
        if(-not(Test-Path -LiteralPath $Roots[$index])){continue}
        foreach($file in Get-ChildItem -LiteralPath $Roots[$index] -File -Recurse) {
            if($index-eq 0 -and $file.Extension-notin '.dat','.ini','.json' -and $file.Name-ne 'cmd_history.txt'){continue}
            $file
        }
    }
}
function Restore-MotionProbeState {
    param([object[]]$Files,[string[]]$Roots,[string]$Main,[byte[]]$BeforeMain,[byte[]]$ExpectedMain,
        [string]$Report,[datetime]$StartedUtc,[datetime]$ExitedUtc,[bool]$OwnedProcessExited,[int[]]$SavedSlots=@(3),[int[]]$BootMissingSlots=@())
    $StartedUtc=$StartedUtc.ToUniversalTime();$ExitedUtc=$ExitedUtc.ToUniversalTime()
    $restoreErrors=[Collections.Generic.List[string]]::new()
    $archived=[Collections.Generic.List[object]]::new()
    $restored=0;$mainRestored=$false
    # A conflicting source edit is never overwritten, and never skips save recovery.
    try {
        if((Test-Path -LiteralPath $Main)-and [Convert]::ToBase64String([IO.File]::ReadAllBytes($Main))-eq [Convert]::ToBase64String($ExpectedMain)) {
            [IO.File]::WriteAllBytes($Main,$BeforeMain);$mainRestored=$true
        } elseif((Test-Path -LiteralPath $Main)-and [Convert]::ToBase64String([IO.File]::ReadAllBytes($Main))-eq [Convert]::ToBase64String($BeforeMain)) {
            $mainRestored=$true
        } else {$restoreErrors.Add('Main changed externally; preserved external contents.')}
    } catch {$restoreErrors.Add('Main restore: '+$_.Exception.Message)}
    foreach($entry in $Files) {
        try {
            if(-not(Test-Path -LiteralPath $entry.path)-or (Get-FileHash -LiteralPath $entry.path).Hash-ne $entry.hash) {
                New-Item -ItemType Directory -Path (Split-Path $entry.path -Parent) -Force|Out-Null
                Copy-Item -LiteralPath $entry.backup -Destination $entry.path;$restored++
            }
            if((Get-FileHash -LiteralPath $entry.path).Hash-ne $entry.hash){throw 'hash mismatch'}
        } catch {$restoreErrors.Add('State restore '+$entry.path+': '+$_.Exception.Message)}
    }
    $original=@{};foreach($entry in $Files){$original[[IO.Path]::GetFullPath($entry.path)]=$true}
    # Exact slot-3 files, plus dated backups for slots whose save was proven by
    # this owned process's log. Original files always stay under snapshot restore.
    $remote=[IO.Path]::GetFullPath((Join-Path $Roots[1] 'remote'))
    $candidates=@()
    foreach($name in @('rep_gamestate3.dat','rep_persistentgamedata3.dat')){$candidates+=@{path=(Join-Path $remote $name);root=$remote}}
    # A menu bootstrap can create a missing slot-1/2 run file before our slot-3
    # probe. Require both explicit missing-at-boot and saved-slot log evidence;
    # never broaden the allowlist to every new remote save.
    foreach($slot in $BootMissingSlots|Where-Object {$_-in 1,2 -and $_-in $SavedSlots}|Select-Object -Unique){
        $candidates+=@{path=(Join-Path $remote ('rep_gamestate'+$slot+'.dat'));root=$remote;requireCreated=$true}
    }
    $localSaves=[IO.Path]::GetFullPath($Roots[0])
    foreach($day in @($StartedUtc.ToLocalTime().ToString('yyyyMMdd'),$ExitedUtc.ToLocalTime().ToString('yyyyMMdd'))|Select-Object -Unique){
        foreach($slot in $SavedSlots|Where-Object {$_-in 1,2,3}|Select-Object -Unique){
            $candidates+=@{path=(Join-Path $localSaves ($day+'.rep_persistentgamedata'+$slot+'.dat'));root=$localSaves}
        }
    }
    foreach($candidate in $candidates) {
        $path=[IO.Path]::GetFullPath($candidate.path);$name=[IO.Path]::GetFileName($path)
        if($original.ContainsKey($path)-or -not(Test-Path -LiteralPath $path)){continue}
        try {
            if([IO.Path]::GetFullPath((Split-Path $path -Parent))-ne $candidate.root){throw 'target escaped exact candidate directory'}
            $file=Get-Item -LiteralPath $path
            if(-not $OwnedProcessExited -or $file.LastWriteTimeUtc-lt $StartedUtc.AddSeconds(-2)-or $file.LastWriteTimeUtc-gt $ExitedUtc.AddSeconds(5)){throw 'owned process/time proof missing'}
            if($candidate.ContainsKey('requireCreated') -and $candidate.requireCreated -and ($file.CreationTimeUtc-lt $StartedUtc.AddSeconds(-2)-or $file.CreationTimeUtc-gt $ExitedUtc.AddSeconds(5))){throw 'new bootstrap file creation proof missing'}
            $hash=(Get-FileHash -LiteralPath $path).Hash
            $archive=Join-Path $Report 'test-generated-state';New-Item -ItemType Directory -Path $archive -Force|Out-Null
            $destination=Join-Path $archive $name
            if(Test-Path -LiteralPath $destination){throw 'archive destination already exists'}
            # Verify the exact leaf once more before the non-recursive move.
            if((Get-FileHash -LiteralPath $path).Hash-ne $hash){throw 'state changed during verification'}
            Move-Item -LiteralPath $path -Destination $destination
            if((Get-FileHash -LiteralPath $destination).Hash-ne $hash){throw 'archive hash mismatch'}
            $archived.Add(@{path=$path;hash=$hash;absentBefore=$true;writtenUtc=$file.LastWriteTimeUtc.ToString('o')})
        } catch {$restoreErrors.Add('New state preserved '+$path+': '+$_.Exception.Message)}
    }
    $unknown=@(Get-MotionStateFiles $Roots | Where-Object {-not $original.ContainsKey([IO.Path]::GetFullPath($_.FullName))} | ForEach-Object FullName)
    if($unknown.Count){$restoreErrors.Add('Unresolved new state files were preserved.')}
    $archived|ConvertTo-Json -Depth 5|Set-Content -LiteralPath (Join-Path $Report 'archived-state.json')
    return @{stateRestored=($restoreErrors.Count-eq 0);mainRestored=$mainRestored;restoredFiles=$restored;
        restoreErrors=@($restoreErrors);unresolvedNewFiles=$unknown;archivedNewFiles=@($archived)}
}
