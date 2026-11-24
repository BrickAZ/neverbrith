#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
if(Get-Process -Name isaac-ng -ErrorAction SilentlyContinue){throw 'Isaac must be closed before snapshotting test state'}
$yinMod=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$yinBackup=Join-Path $yinMod 'release/yin-native-interface/2026-10-02/backups/pre-runtime-state'
if(Test-Path -LiteralPath $yinBackup){throw 'Existing runtime state snapshot must not be overwritten'}
$yinRoots=@(
    @{key='my-games';path='C:\Users\Anton\Documents\My Games\Binding of Isaac Repentance'},
    @{key='cloud';path='C:\Users\Anton\AppData\Roaming\Goldberg SteamEmu Saves\250900'},
    @{key='mod-data';path='E:\Isaac - Repentance\data'}
)
$yinEntries=@()
foreach($yinRoot in $yinRoots){
    $yinFiles=Get-ChildItem -LiteralPath $yinRoot.path -File -Recurse
    if($yinRoot.key-eq 'my-games'){
        $yinFiles=$yinFiles|Where-Object { $_.Extension-in '.dat','.ini','.json' -or $_.Name-eq 'cmd_history.txt' }
    }
    foreach($yinFile in $yinFiles){
        if($yinFile.Attributes-band [IO.FileAttributes]::ReparsePoint){throw 'Reparse state file rejected'}
        $yinRelative=[IO.Path]::GetRelativePath($yinRoot.path,$yinFile.FullName)
        $yinDestination=Join-Path (Join-Path $yinBackup $yinRoot.key) $yinRelative
        New-Item -ItemType Directory -Path (Split-Path $yinDestination -Parent) -Force|Out-Null
        Copy-Item -LiteralPath $yinFile.FullName -Destination $yinDestination
        $yinHash=(Get-FileHash -LiteralPath $yinFile.FullName).Hash
        if((Get-FileHash -LiteralPath $yinDestination).Hash-ne $yinHash){throw 'State snapshot checksum failed'}
        $yinEntries+=[pscustomobject]@{path=$yinFile.FullName;backup=$yinDestination;sha256=$yinHash;lastWriteUtc=$yinFile.LastWriteTimeUtc.ToString('o')}
    }
}
$yinMain=Join-Path $yinMod 'main.lua'
$yinMainBackup=Join-Path $yinBackup 'main.before.lua'
Copy-Item -LiteralPath $yinMain -Destination $yinMainBackup
$yinMainHash=(Get-FileHash -LiteralPath $yinMain).Hash
$yinRecord=[ordered]@{createdUtc=[DateTime]::UtcNow.ToString('o');status='snapshotted';roots=$yinRoots;files=$yinEntries;mainPath=$yinMain;mainBackup=$yinMainBackup;mainSha256=$yinMainHash}
$yinRecord|ConvertTo-Json -Depth 7|Set-Content -LiteralPath (Join-Path $yinBackup 'state-manifest.json') -Encoding utf8
$yinSuffix=[Text.Encoding]::UTF8.GetBytes("`n-- YIN_RUNTIME_ACCEPTANCE_TEMPORARY_BEGIN`ninclude(`"diagnostics/yin_runtime_probe`")(Neverbirth)`n-- YIN_RUNTIME_ACCEPTANCE_TEMPORARY_END`n")
$yinBytes=[IO.File]::ReadAllBytes($yinMain)
[IO.File]::WriteAllBytes($yinMain,($yinBytes+$yinSuffix))
Write-Output "Verified $($yinEntries.Count) state files; original main hash $yinMainHash; snapshot $yinBackup"
