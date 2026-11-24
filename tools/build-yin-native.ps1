#requires -Version 7.0
[CmdletBinding()]
param([ValidateSet('Baseline','Candidate')][string]$Stage = 'Candidate')
$ErrorActionPreference = 'Stop'
$yinRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$yinBase = Join-Path $yinRoot 'worktrees/repentogon-yin-native'
$yinSource = Join-Path $yinBase 'source'
$yinBuild = Join-Path $yinBase 'build'
$yinTools = Join-Path $yinBase 'tools'
$yinReport = Join-Path $yinRoot 'reports/yins-curse/native-interface/2026-10-02'
$yinCommit = '4675b426d1ce7973595172984c366354e5bb66f9'
$yinCmake = Join-Path $yinTools 'cmake-3.31.8-windows-x86_64/bin/cmake.exe'
New-Item -ItemType Directory -Path $yinBase,$yinTools,$yinReport -Force | Out-Null
if (-not (Test-Path -LiteralPath $yinSource)) {
    & git clone --branch 1.0.12a --single-branch https://github.com/TeamREPENTOGON/REPENTOGON.git $yinSource
    if ($LASTEXITCODE -ne 0) { throw 'Native source clone failed' }
}
$yinHead = (& git -C $yinSource rev-parse HEAD).Trim()
if ($LASTEXITCODE -ne 0 -or $yinHead -ne $yinCommit) { throw 'Native source identity mismatch' }
if (-not (Test-Path -LiteralPath $yinCmake)) {
    $yinRelease = 'https://github.com/Kitware/CMake/releases/download/v3.31.8/'
    $yinZip = Join-Path $yinTools 'cmake-3.31.8-windows-x86_64.zip'
    $yinHashes = Join-Path $yinTools 'cmake-3.31.8-SHA-256.txt'
    Invoke-WebRequest ($yinRelease+'cmake-3.31.8-SHA-256.txt') -OutFile $yinHashes
    Invoke-WebRequest ($yinRelease+'cmake-3.31.8-windows-x86_64.zip') -OutFile $yinZip
    $yinExpected = ((Get-Content $yinHashes | Select-String 'cmake-3.31.8-windows-x86_64.zip$').Line -split '\s+')[0]
    if ((Get-FileHash $yinZip).Hash -ine $yinExpected) { throw 'CMake checksum mismatch' }
    Expand-Archive -LiteralPath $yinZip -DestinationPath $yinTools
}
& git -C $yinSource -c 'url.https://github.com/.insteadOf=git@github.com:' submodule update --init --recursive --depth 1 --jobs 4 *> (Join-Path $yinReport 'dependency-refresh.log')
if ($LASTEXITCODE -ne 0) { throw 'Pinned submodule initialization failed' }
if ($Stage -eq 'Candidate' -and -not (Test-Path -LiteralPath (Join-Path $yinSource 'repentogon/Patches/PlayerExplosionImmunity.cpp'))) {
    throw 'Apply source-patches/repentogon-yin.patch and source-patches/antlr4-chrono.patch before building this candidate; see delivery.md.'
}
if ($Stage -eq 'Baseline' -and (Test-Path -LiteralPath (Join-Path $yinSource 'repentogon/Patches/PlayerExplosionImmunity.cpp'))) {
    throw 'Baseline requires the pinned source without the interface patch; existing baseline evidence must not be overwritten with this candidate.'
}
$yinTests = if ($Stage -eq 'Candidate') { 'ON' } else { 'OFF' }
$yinVersion = if ($Stage -eq 'Candidate') { '1.0.12a-yin-api1-dev' } else { 'dev' }
$yinConfigure = @('-S',$yinSource,'-B',$yinBuild,'-G','Visual Studio 17 2022','-A','Win32',
    '-DCMAKE_BUILD_TYPE=Release','-DISAAC_DIRECTORY:PATH=',
    "-DCMAKE_REPENTOGON_VERSION=$yinVersion", "-DREPENTOGON_EXPLOSION_IMMUNITY_TESTS=$yinTests")
$yinRecords = [Collections.Generic.List[object]]::new()
function Invoke-YinBuildCommand([string]$Name,[string[]]$Arguments) {
    $yinLog = Join-Path $yinReport ($Stage.ToLowerInvariant()+'-'+$Name+'.log')
    & $yinCmake @Arguments *> $yinLog
    $yinCode = $LASTEXITCODE
    $yinRecords.Add([ordered]@{name=$Name; executable=$yinCmake; arguments=$Arguments; exitCode=$yinCode; log=$yinLog})
    $yinRecords | ConvertTo-Json -Depth 5 | Set-Content (Join-Path $yinReport ($Stage.ToLowerInvariant()+'-commands.json')) -Encoding utf8
    Get-Content $yinLog -Tail 12
    if ($yinCode -ne 0) { throw "$Name failed (exit $yinCode); see $yinLog" }
}
Invoke-YinBuildCommand 'configure' $yinConfigure
$yinCache = Get-Content (Join-Path $yinBuild 'CMakeCache.txt')
if ('ISAAC_DIRECTORY:PATH=' -notin $yinCache) { throw 'Auto-deploy must remain disabled' }
Invoke-YinBuildCommand 'build' @('--build',$yinBuild,'--config','Release','--parallel','4')
$yinArtifacts = Get-ChildItem (Join-Path $yinBuild 'Release') -File -Filter '*.dll' | ForEach-Object {
    [ordered]@{name=$_.Name; sha256=(Get-FileHash $_.FullName).Hash; bytes=$_.Length}
}
$yinArtifacts | ConvertTo-Json -Depth 3 | Set-Content (Join-Path $yinReport ($Stage.ToLowerInvariant()+'-artifacts.json')) -Encoding utf8
Write-Output 'Isolated native build complete; no installed files changed.'
