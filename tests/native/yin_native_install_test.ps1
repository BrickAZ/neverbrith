#requires -Version 7.0
$ErrorActionPreference='Stop'
$yinRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$yinFixture=Join-Path $yinRoot ('reports/yins-curse/native-interface/2026-10-02/install-fixture-'+[guid]::NewGuid().ToString('N'))
$yinCandidate=Join-Path $yinFixture 'candidate';$yinGame=Join-Path $yinFixture 'game';$yinRuntime=Join-Path $yinCandidate 'runtime'
New-Item -ItemType Directory -Path $yinGame,$yinRuntime -Force|Out-Null
try {
    Set-Content (Join-Path $yinGame 'isaac-ng.exe') 'fake game fixture' -Encoding utf8
    Set-Content (Join-Path $yinGame 'zhlREPENTOGON.dll') 'original' -Encoding utf8
    Set-Content (Join-Path $yinRuntime 'zhlREPENTOGON.dll') 'candidate' -Encoding utf8
    Set-Content (Join-Path $yinRuntime 'new.txt') 'new' -Encoding utf8
    $yinOld=(Get-FileHash (Join-Path $yinGame 'zhlREPENTOGON.dll')).Hash
    $yinFiles=@(
        @{path='zhlREPENTOGON.dll';sha256=(Get-FileHash (Join-Path $yinRuntime 'zhlREPENTOGON.dll')).Hash;installedSha256=$yinOld;action='replace'},
        @{path='new.txt';sha256=(Get-FileHash (Join-Path $yinRuntime 'new.txt')).Hash;installedSha256=$null;action='add'})
    @{schemaVersion=1;gameRoot=$yinGame;gameSha256=(Get-FileHash (Join-Path $yinGame 'isaac-ng.exe')).Hash;files=$yinFiles}|ConvertTo-Json -Depth 5|Set-Content (Join-Path $yinCandidate 'candidate-manifest.json')
    $yinInstaller=Join-Path $yinRoot 'tools/install-yin-native.ps1'
    & $yinInstaller -Mode Verify -CandidateRoot $yinCandidate -GameRoot $yinGame
    if((Get-FileHash (Join-Path $yinGame 'zhlREPENTOGON.dll')).Hash -ne $yinOld){throw 'Verify wrote installed file'}
    & $yinInstaller -Mode Install -CandidateRoot $yinCandidate -GameRoot $yinGame -BackupDirectory (Join-Path $yinFixture 'backup')
    if((Get-FileHash (Join-Path $yinGame 'zhlREPENTOGON.dll')).Hash -ne $yinFiles[0].sha256){throw 'Candidate not installed'}
    & $yinInstaller -Mode Rollback -CandidateRoot $yinCandidate -GameRoot $yinGame -BackupDirectory (Join-Path $yinFixture 'backup')
    if((Get-FileHash (Join-Path $yinGame 'zhlREPENTOGON.dll')).Hash -ne $yinOld -or (Test-Path (Join-Path $yinGame 'new.txt'))){throw 'Rollback failed'}
    Set-Content (Join-Path $yinRuntime 'new.txt') 'corrupted' -Encoding utf8
    $yinRejected=$false
    try {& $yinInstaller -Mode Verify -CandidateRoot $yinCandidate -GameRoot $yinGame}catch{$yinRejected=$true}
    if(-not $yinRejected){throw 'Corrupted candidate accepted'}
    Write-Output 'PASS verify_is_read_only, install_backup_checksums, restore_original_and_remove_addition, reject_corruption'
} finally {
    $yinResolved=[IO.Path]::GetFullPath($yinFixture)
    if(-not $yinResolved.StartsWith(($yinRoot+[IO.Path]::DirectorySeparatorChar),[StringComparison]::OrdinalIgnoreCase)){throw 'Fixture cleanup escaped workspace'}
    Remove-Item -LiteralPath $yinResolved -Recurse -Force
}
