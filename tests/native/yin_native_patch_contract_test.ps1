#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$NativeRoot = (Join-Path $PSScriptRoot '../../worktrees/repentogon-yin-native/source'),
    [string]$BuildRoot = (Join-Path $PSScriptRoot '../../worktrees/repentogon-yin-native/build')
)
$ErrorActionPreference='Stop'
$yinModRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../..'))
$yinGame=Join-Path (Split-Path (Split-Path $yinModRoot -Parent) -Parent) 'isaac-ng.exe'
if((Get-FileHash -LiteralPath $yinGame).Hash -ne '530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627'){throw 'Audited game hash mismatch'}
if((git -C $NativeRoot rev-parse HEAD).Trim() -ne '4675b426d1ce7973595172984c366354e5bb66f9'){throw 'Pinned source mismatch'}
if('ISAAC_DIRECTORY:PATH=' -notin (Get-Content (Join-Path $BuildRoot 'CMakeCache.txt'))){throw 'Auto-deploy must remain disabled'}
$yinCtest=Join-Path $yinModRoot 'worktrees/repentogon-yin-native/tools/cmake-3.31.8-windows-x86_64/bin/ctest.exe'
& $yinCtest --test-dir $BuildRoot -C Release --output-on-failure
if($LASTEXITCODE -ne 0){exit $LASTEXITCODE}
Write-Output 'Native context, actual EXE site preflight, executable x86 stub, and real Lua stack tests passed. This command does not perform in-game acceptance.'
