#requires -Version 7.0
$ErrorActionPreference='Stop'
$taskReport='reports/drive-rush/2026-10-15/dot-ownership'
$taskCandidate="$taskReport/candidate-original"
$taskBackup="$taskReport/comparison-restore"
pwsh -NoProfile -File tools/install-yin-native.ps1 -Mode Install -CandidateRoot $taskCandidate -BackupDirectory $taskBackup
if($LASTEXITCODE-ne 0){throw 'Original comparison DLL installation failed'}
try {
    pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt dot-damage-original-01 -Probe dot_damage_contract -Seconds 35
    if($LASTEXITCODE-ne 0){throw 'Original comparison probe failed'}
} finally {
    pwsh -NoProfile -File tools/install-yin-native.ps1 -Mode Rollback -CandidateRoot $taskCandidate -BackupDirectory $taskBackup
    if($LASTEXITCODE-ne 0){throw 'Attribution DLL restore failed'}
}
pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt dot-damage-patched-01 -Probe dot_damage_contract -Seconds 35
if($LASTEXITCODE-ne 0){throw 'Patched comparison probe failed'}
$taskLogs='reports/drive-rush/2026-10-14/implementation-v1'
$taskBefore=@(Get-Content "$taskLogs/dot-damage-original-01/game-log.txt" | Where-Object {$_ -match '\[Drive Glove runtime\] MEASURE'})
$taskAfter=@(Get-Content "$taskLogs/dot-damage-patched-01/game-log.txt" | Where-Object {$_ -match '\[Drive Glove runtime\] MEASURE'})
$taskEqual=$taskBefore.Count-eq 8 -and (($taskBefore -join "`n") -ceq ($taskAfter -join "`n"))
@{equal=$taskEqual;original=$taskBefore;patched=$taskAfter} | ConvertTo-Json -Depth 4 | Set-Content "$taskReport/native-damage-comparison.json"
if(-not $taskEqual){throw 'Native status damage or duration differed; inspect the comparison JSON'}
Write-Output 'All eight native HP/countdown results are identical.'
