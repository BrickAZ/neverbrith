#requires -Version 7.0
[CmdletBinding()]
param(
    [ValidateSet('Verify','Install','Rollback')][string]$Mode='Verify',
    [string]$CandidateRoot=(Join-Path $PSScriptRoot '../release/yin-native-interface/2026-10-02/candidate'),
    [string]$GameRoot=(Join-Path $PSScriptRoot '../../..'),
    [string]$BackupDirectory
)
$ErrorActionPreference='Stop'
$yinCandidate=[IO.Path]::GetFullPath($CandidateRoot)
$yinGame=[IO.Path]::GetFullPath($GameRoot)
$yinRuntime=Join-Path $yinCandidate 'runtime'
$yinManifest=Get-Content -LiteralPath (Join-Path $yinCandidate 'candidate-manifest.json') -Raw|ConvertFrom-Json
function Get-YinChild([string]$Root,[string]$Relative) {
    if([IO.Path]::IsPathRooted($Relative)){throw "Absolute manifest path: $Relative"}
    $yinPath=[IO.Path]::GetFullPath((Join-Path $Root $Relative))
    $yinPrefix=$Root.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    if(-not $yinPath.StartsWith($yinPrefix,[StringComparison]::OrdinalIgnoreCase)){throw "Manifest path escaped root: $Relative"}
    $yinCheck=$yinPath
    while($yinCheck.Length -ge $Root.Length) {
        if(Test-Path -LiteralPath $yinCheck) {
            if((Get-Item -LiteralPath $yinCheck -Force).Attributes -band [IO.FileAttributes]::ReparsePoint){throw "Reparse path rejected: $yinCheck"}
        }
        $yinCheck=Split-Path $yinCheck -Parent
        if(-not $yinCheck){break}
    }
    return $yinPath
}
function Get-YinHash([string]$Path) {
    if(Test-Path -LiteralPath $Path -PathType Leaf){return (Get-FileHash -LiteralPath $Path).Hash}
    return $null
}
if($yinManifest.schemaVersion-ne 1 -or [IO.Path]::GetFullPath($yinManifest.gameRoot)-ine $yinGame){throw 'Manifest/game identity mismatch'}
if((Get-YinHash (Join-Path $yinGame 'isaac-ng.exe'))-ine $yinManifest.gameSha256){throw 'Audited game executable changed'}
if($Mode-ne 'Verify' -and (Get-Process -Name 'isaac-ng','REPENTOGONUpdater_Base' -ErrorAction SilentlyContinue)){throw 'Close Isaac and its updater before changing native files'}
$yinChanges=@($yinManifest.files|Where-Object action -ne 'unchanged')
foreach($yinEntry in $yinManifest.files) {
    $null=Get-YinChild $yinGame $yinEntry.path
    if($yinEntry.action -notin @('unchanged','replace','add')){throw 'Unknown manifest action'}
    if($Mode-ne 'Rollback') {
        $yinFile=Get-YinChild $yinRuntime $yinEntry.path
        if((Get-YinHash $yinFile)-ine $yinEntry.sha256){throw "Candidate checksum mismatch: $($yinEntry.path)"}
        if((Get-YinHash (Get-YinChild $yinGame $yinEntry.path))-ine $yinEntry.installedSha256){throw "Installed file changed since packaging: $($yinEntry.path)"}
    }
}
if($Mode-eq 'Verify'){Write-Output "Verified candidate, baseline and game checksum. $($yinChanges.Count) planned file changes; no files written.";return}
if(-not $BackupDirectory) {
    if($Mode-eq 'Rollback'){throw 'Rollback requires the exact backup directory printed by Install'}
    $BackupDirectory=Join-Path $PSScriptRoot ('../release/yin-native-interface/2026-10-02/backups/'+[DateTime]::UtcNow.ToString('yyyyMMdd-HHmmss')+'-'+[guid]::NewGuid().ToString('N'))
}
$yinBackup=[IO.Path]::GetFullPath($BackupDirectory)
$yinJournalPath=Join-Path $yinBackup 'restore-manifest.json'
function Save-YinJournal($Journal){$Journal|ConvertTo-Json -Depth 7|Set-Content -LiteralPath $yinJournalPath -Encoding utf8}
function Restore-YinFiles($Journal) {
    if([IO.Path]::GetFullPath($Journal.gameRoot)-ine $yinGame){throw 'Backup targets a different game directory'}
    foreach($yinEntry in $Journal.files) {
        $null=Get-YinChild $yinGame $yinEntry.path
        if($yinEntry.originalSha256 -and (Get-YinHash (Get-YinChild (Join-Path $yinBackup 'files') $yinEntry.path))-ine $yinEntry.originalSha256){throw "Backup checksum mismatch: $($yinEntry.path)"}
    }
    foreach($yinEntry in $Journal.files) {
        $yinTarget=Get-YinChild $yinGame $yinEntry.path
        if($yinEntry.originalSha256) {
            Copy-Item -LiteralPath (Get-YinChild (Join-Path $yinBackup 'files') $yinEntry.path) -Destination $yinTarget -Force
        } elseif(Test-Path -LiteralPath $yinTarget) {Remove-Item -LiteralPath $yinTarget -Force}
        if((Get-YinHash $yinTarget)-ine $yinEntry.originalSha256){throw "Restore verification failed: $($yinEntry.path)"}
    }
    $Journal.status='restored';Save-YinJournal $Journal
    Write-Output "Restored original native files and verified every original hash: $yinBackup"
}
if($Mode-eq 'Rollback') {
    $yinJournal=Get-Content -LiteralPath $yinJournalPath -Raw|ConvertFrom-Json
    # A later external edit must not be silently overwritten by a routine rollback.
    foreach($yinEntry in $yinJournal.files) {
        $yinCurrent=Get-YinHash (Get-YinChild $yinGame $yinEntry.path)
        if($yinCurrent-ine $yinEntry.candidateSha256 -and $yinCurrent-ine $yinEntry.originalSha256){throw "File changed after install; inspect before rollback: $($yinEntry.path)"}
    }
    Restore-YinFiles $yinJournal;return
}
if(Test-Path -LiteralPath $yinBackup){throw 'Use a fresh backup directory; existing backups are never overwritten'}
New-Item -ItemType Directory -Path (Join-Path $yinBackup 'files') -Force|Out-Null
$yinRecords=@(foreach($yinEntry in $yinChanges) {
    if($yinEntry.installedSha256) {
        $yinBackupFile=Get-YinChild (Join-Path $yinBackup 'files') $yinEntry.path
        New-Item -ItemType Directory -Path (Split-Path $yinBackupFile -Parent) -Force|Out-Null
        Copy-Item -LiteralPath (Get-YinChild $yinGame $yinEntry.path) -Destination $yinBackupFile
        if((Get-YinHash $yinBackupFile)-ine $yinEntry.installedSha256){throw "Backup verification failed: $($yinEntry.path)"}
    }
    [pscustomobject]@{path=$yinEntry.path;originalSha256=$yinEntry.installedSha256;candidateSha256=$yinEntry.sha256}
})
$yinJournal=[pscustomobject]@{schemaVersion=1;gameRoot=$yinGame;status='backed_up';files=$yinRecords}
Save-YinJournal $yinJournal
try {
    $yinJournal.status='installing';Save-YinJournal $yinJournal
    foreach($yinEntry in $yinChanges) {
        $yinTarget=Get-YinChild $yinGame $yinEntry.path
        New-Item -ItemType Directory -Path (Split-Path $yinTarget -Parent) -Force|Out-Null
        Copy-Item -LiteralPath (Get-YinChild $yinRuntime $yinEntry.path) -Destination $yinTarget -Force
        if((Get-YinHash $yinTarget)-ine $yinEntry.sha256){throw "Install verification failed: $($yinEntry.path)"}
    }
    $yinJournal.status='installed';Save-YinJournal $yinJournal
    Write-Output "Installed and verified $($yinChanges.Count) candidate files. Backup: $yinBackup"
} catch {
    $yinFailure=$_;$yinJournal.status='install_failed';Save-YinJournal $yinJournal
    Restore-YinFiles $yinJournal
    throw $yinFailure
}
