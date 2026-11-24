#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
if(Get-Process -Name isaac-ng -ErrorAction SilentlyContinue){throw 'Close the test game before restoring its state snapshot'}
$yinMod=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$yinBackup=Join-Path $yinMod 'release/yin-native-interface/2026-10-02/backups/pre-runtime-state'
$yinManifest=Get-Content -LiteralPath (Join-Path $yinBackup 'state-manifest.json') -Raw|ConvertFrom-Json
$yinReport=Join-Path $yinMod 'reports/yins-curse/native-interface/2026-10-02/state-restoration.json'
$yinOriginals=@{};$yinRestored=@();$yinCreated=@()
foreach($yinEntry in $yinManifest.files){
    if((Get-FileHash -LiteralPath $yinEntry.backup).Hash-ne $yinEntry.sha256){throw "State backup changed: $($yinEntry.path)"}
    $yinOriginals[$yinEntry.path]=$yinEntry
}
foreach($yinRoot in $yinManifest.roots){
    $yinResolved=[IO.Path]::GetFullPath($yinRoot.path)
    $yinPrefix=$yinResolved.TrimEnd('\','/')+[IO.Path]::DirectorySeparatorChar
    $yinCurrent=Get-ChildItem -LiteralPath $yinResolved -Recurse -File
    if($yinRoot.key-eq 'my-games'){$yinCurrent=$yinCurrent|Where-Object { $_.Extension-in '.dat','.ini','.json' -or $_.Name-eq 'cmd_history.txt' }}
    foreach($yinFile in $yinCurrent){
        if(-not [IO.Path]::GetFullPath($yinFile.FullName).StartsWith($yinPrefix,[StringComparison]::OrdinalIgnoreCase) -or ($yinFile.Attributes-band [IO.FileAttributes]::ReparsePoint)){throw 'State restore path escaped or is a reparse point'}
        if(-not $yinOriginals.ContainsKey($yinFile.FullName)){
            if($yinFile.LastWriteTimeUtc-lt [datetime]$yinManifest.createdUtc){throw "Untracked state predates the test: $($yinFile.FullName)"}
            $yinRelative=[IO.Path]::GetRelativePath($yinResolved,$yinFile.FullName)
            $yinPreserved=Join-Path (Join-Path $yinBackup ('test-created/'+$yinRoot.key)) $yinRelative
            New-Item -ItemType Directory -Path (Split-Path $yinPreserved -Parent) -Force|Out-Null
            Copy-Item -LiteralPath $yinFile.FullName -Destination $yinPreserved -Force
            $yinHash=(Get-FileHash -LiteralPath $yinFile.FullName).Hash
            if((Get-FileHash -LiteralPath $yinPreserved).Hash-ne $yinHash){throw 'New test file preservation failed'}
            Remove-Item -LiteralPath $yinFile.FullName
            $yinCreated+=[pscustomobject]@{path=$yinFile.FullName;preserved=$yinPreserved;sha256=$yinHash}
        }
    }
}
foreach($yinEntry in $yinManifest.files){
    $yinHash=if(Test-Path -LiteralPath $yinEntry.path){(Get-FileHash -LiteralPath $yinEntry.path).Hash}else{$null}
    $yinChanged=$yinHash-ne $yinEntry.sha256
    if($yinChanged){
        Copy-Item -LiteralPath $yinEntry.backup -Destination $yinEntry.path -Force
        (Get-Item -LiteralPath $yinEntry.path).LastWriteTimeUtc=[datetime]$yinEntry.lastWriteUtc
    }
    $yinActual=(Get-FileHash -LiteralPath $yinEntry.path).Hash
    if($yinActual-ne $yinEntry.sha256){throw "Restored state differs: $($yinEntry.path)"}
    $yinRestored+=[pscustomobject]@{path=$yinEntry.path;sha256=$yinActual;restored=$yinChanged}
}
if((Get-FileHash -LiteralPath $yinManifest.mainPath).Hash-ne $yinManifest.mainSha256){throw 'Temporary main loader is still present or main changed'}
[ordered]@{checkedUtc=[DateTime]::UtcNow.ToString('o');status='restored_and_verified';originalFiles=$yinRestored;testCreatedFiles=$yinCreated;mainSha256=$yinManifest.mainSha256}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $yinReport -Encoding utf8
$yinManifest.status='restored_and_verified'
$yinManifest|ConvertTo-Json -Depth 8|Set-Content -LiteralPath (Join-Path $yinBackup 'state-manifest.json') -Encoding utf8
Write-Output "All $($yinRestored.Count) original state hashes verified; $(@($yinRestored|Where-Object restored).Count) changed files restored; $($yinCreated.Count) test-created files preserved then removed."
