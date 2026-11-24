#requires -Version 7.0
[CmdletBinding()]
param()
$ErrorActionPreference='Stop'
$yinRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$yinSource=Join-Path $yinRoot 'worktrees/repentogon-yin-native/source'
$yinBuild=Join-Path $yinRoot 'worktrees/repentogon-yin-native/build/Release'
$yinCandidate=Join-Path $yinRoot 'release/yin-native-interface/2026-10-02/candidate'
$yinReport=Join-Path $yinRoot 'reports/yins-curse/native-interface/2026-10-02'
$yinGame=Split-Path (Split-Path $yinRoot -Parent) -Parent
$yinRuntime=Join-Path $yinCandidate 'runtime'
New-Item -ItemType Directory -Path $yinRuntime,(Join-Path $yinCandidate 'source-patches') -Force | Out-Null
foreach($yinName in @('dsound.dll','libzhl.dll','zhlREPENTOGON.dll','Lua5.4.dll','freetype.dll')) {
    Copy-Item -LiteralPath (Join-Path $yinBuild $yinName) -Destination (Join-Path $yinRuntime $yinName)
}
foreach($yinName in @('resources','resources-repentogon')) {
    Copy-Item -LiteralPath (Join-Path $yinBuild $yinName) -Destination $yinRuntime -Recurse -Force
}
Copy-Item -LiteralPath (Join-Path $yinSource 'changelog.txt') -Destination (Join-Path $yinRuntime 'rgon_changelog.txt')
$yinPatchLines=@(& git -C $yinSource diff --binary HEAD -- . ':(exclude)libs/antlr4')
if($LASTEXITCODE -ne 0){throw 'Native diff failed'}
$yinNew=@(& git -C $yinSource ls-files --others --exclude-standard)
if($LASTEXITCODE -ne 0){throw 'Native new-file list failed'}
foreach($yinFile in $yinNew) {
    $yinParts=@(& git -C $yinSource diff --no-index -- /dev/null $yinFile)
    if($LASTEXITCODE -ne 1){throw "New source diff failed: $yinFile"}
    $yinPatchLines+=$yinParts
}
$yinPatch=Join-Path $yinCandidate 'source-patches/repentogon-yin.patch'
[IO.File]::WriteAllText($yinPatch,($yinPatchLines -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
$yinDependency=@(& git -C (Join-Path $yinSource 'libs/antlr4') diff --binary HEAD)
if($LASTEXITCODE -ne 0){throw 'Dependency diff failed'}
[IO.File]::WriteAllText((Join-Path $yinCandidate 'source-patches/antlr4-chrono.patch'),($yinDependency -join "`n")+"`n",[Text.UTF8Encoding]::new($false))
Copy-Item -LiteralPath (Join-Path $yinSource 'LICENSE') -Destination (Join-Path $yinCandidate 'REPENTOGON-LICENSE')
Copy-Item -LiteralPath (Join-Path $yinReport 'source-manifest.json') -Destination $yinCandidate
function Get-YinMachine([string]$path) {
    $yinBytes=[IO.File]::ReadAllBytes($path);$yinPE=[BitConverter]::ToInt32($yinBytes,0x3c)
    if([BitConverter]::ToUInt16($yinBytes,$yinPE+4)-ne 0x14c){throw "Expected Win32/x86 DLL: $path"}
    return 'x86'
}
$yinFiles=@(Get-ChildItem -LiteralPath $yinRuntime -File -Recurse | Sort-Object FullName | ForEach-Object {
    $yinRel=[IO.Path]::GetRelativePath($yinRuntime,$_.FullName).Replace('\','/')
    $yinExisting=Join-Path $yinGame $yinRel
    $yinHash=(Get-FileHash -LiteralPath $_.FullName).Hash
    $yinOriginal=if(Test-Path -LiteralPath $yinExisting -PathType Leaf){(Get-FileHash -LiteralPath $yinExisting).Hash}else{$null}
    $yinLineOnly=$false
    if($_.Extension-ne '.dll' -and $yinOriginal -and $yinHash-ne $yinOriginal) {
        $yinLineOnly=[IO.File]::ReadAllText($_.FullName).Replace("`r`n","`n") -ceq [IO.File]::ReadAllText($yinExisting).Replace("`r`n","`n")
    }
    [ordered]@{path=$yinRel;bytes=$_.Length;sha256=$yinHash;installedSha256=$yinOriginal;
        action=if($yinHash-eq $yinOriginal){'unchanged'}elseif($null-eq $yinOriginal){'add'}else{'replace'};
        onlyLineEndingsDiffer=$yinLineOnly;architecture=if($_.Extension-eq '.dll'){Get-YinMachine $_.FullName}else{$null}}
})
$yinManifest=[ordered]@{schemaVersion=1;status='candidate_built_not_installed';buildVersion='1.0.12a-yin-api1-dev';
    sourceCommit='4675b426d1ce7973595172984c366354e5bb66f9';gameSha256=(Get-FileHash (Join-Path $yinGame 'isaac-ng.exe')).Hash;
    apiVersionWhenFullyLoaded=1;capabilityRuntimeVerified=$false;inGameVerified=$false;
    candidateRoot=$yinCandidate;gameRoot=$yinGame;patchSha256=(Get-FileHash $yinPatch).Hash;files=$yinFiles}
$yinJSON=$yinManifest|ConvertTo-Json -Depth 8
[IO.File]::WriteAllText((Join-Path $yinCandidate 'candidate-manifest.json'),$yinJSON,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $yinReport 'candidate-manifest.json'),$yinJSON,[Text.UTF8Encoding]::new($false))
$yinFiles|ForEach-Object {"$($_.sha256)  runtime/$($_.path)"}|Set-Content (Join-Path $yinCandidate 'SHA256SUMS.txt') -Encoding utf8
Write-Output ("Packaged {0} runtime files; changed/additions: {1}. No installation performed." -f $yinFiles.Count,@($yinFiles|Where-Object action -ne 'unchanged').Count)
