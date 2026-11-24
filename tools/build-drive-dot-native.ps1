#requires -Version 7.0
$ErrorActionPreference='Stop'
$taskRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot '..'))
$taskBase=Join-Path $taskRoot 'worktrees/repentogon-yin-native'
$taskCmake=Join-Path $taskBase 'tools/cmake-3.31.8-windows-x86_64/bin/cmake.exe'
$taskReport=Join-Path $taskRoot 'reports/drive-rush/2026-10-15/dot-ownership'
if ((& git -C "$taskBase/source" rev-parse HEAD).Trim() -ne '4675b426d1ce7973595172984c366354e5bb66f9') {throw 'Unexpected native base'}
if ('ISAAC_DIRECTORY:PATH=' -notin (Get-Content "$taskBase/build/CMakeCache.txt")) {throw 'Native auto-deploy must be disabled'}
& $taskCmake -S "$taskBase/source" -B "$taskBase/build" *> "$taskReport/native-configure.log"
if($LASTEXITCODE -ne 0){Get-Content "$taskReport/native-configure.log" -Tail 30;exit $LASTEXITCODE}
& $taskCmake --build "$taskBase/build" --config Release --target zhlREPENTOGON --parallel 4 *> "$taskReport/native-build.log"
$taskExit=$LASTEXITCODE
Get-Content "$taskReport/native-build.log" -Tail 25
exit $taskExit
