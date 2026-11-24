# Restore must survive concurrent main edits, missing originals and unknown additions.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot '../tools/motion-native-state.ps1')
$testRoot=[IO.Path]::GetFullPath((Join-Path $PSScriptRoot ('../reports/motion-items/2026-10-24/combat-v1/restore-fixtures/'+[guid]::NewGuid().ToString('N'))))
New-Item -ItemType Directory -Path $testRoot -Force|Out-Null
$roots=@();for($i=0;$i-lt 3;$i++){$roots+=Join-Path $testRoot "root$i";New-Item -ItemType Directory -Path $roots[-1] -Force|Out-Null}
New-Item -ItemType Directory -Path (Join-Path $roots[1] 'remote')|Out-Null
$main=Join-Path $testRoot 'main.lua';$before=[Text.Encoding]::UTF8.GetBytes('original');$expected=[Text.Encoding]::UTF8.GetBytes('instrumented')
[IO.File]::WriteAllText($main,'external edit')
$files=@();$started=[DateTime]::UtcNow.AddSeconds(-2)
foreach($relative in @('root0/options.ini','root1/remote/rep_gamestate1.dat','root1/remote/rep_persistentgamedata1.dat')) {
    $path=Join-Path $testRoot $relative;[IO.File]::WriteAllText($path,'user data')
    $backup=$path+'.backup';Copy-Item -LiteralPath $path -Destination $backup
    $files+=@{path=$path;backup=$backup;hash=(Get-FileHash -LiteralPath $path).Hash}
}
# Keep backups outside the inventoried state roots.
foreach($entry in $files){$target=Join-Path $testRoot ([IO.Path]::GetFileName($entry.backup));Move-Item -LiteralPath $entry.backup -Destination $target;$entry.backup=$target}
[IO.File]::WriteAllText($files[0].path,'test options')
Remove-Item -LiteralPath $files[1].path
$created=Join-Path $roots[1] 'remote/rep_persistentgamedata3.dat';[IO.File]::WriteAllText($created,'test slot')
$foreign=Join-Path $roots[2] 'foreign.dat';[IO.File]::WriteAllText($foreign,'unrelated new data')
$result=Restore-MotionProbeState -Files $files -Roots $roots -Main $main -BeforeMain $before -ExpectedMain $expected -Report $testRoot -StartedUtc $started -ExitedUtc ([DateTime]::UtcNow) -OwnedProcessExited $true
if([IO.File]::ReadAllText($main)-ne 'external edit'){throw 'concurrent main overwritten'}
foreach($entry in $files){if((Get-FileHash -LiteralPath $entry.path).Hash-ne $entry.hash){throw 'original not recovered'}}
if(-not(Test-Path -LiteralPath $foreign)-or $result.stateRestored){throw 'unknown additions must be preserved and reported'}
if((Test-Path -LiteralPath $created)-or -not(Test-Path -LiteralPath (Join-Path $testRoot 'test-generated-state/rep_persistentgamedata3.dat'))){throw 'owned new slot not archived'}
Remove-Item -LiteralPath $foreign
[IO.File]::WriteAllBytes($main,$expected)
$result=Restore-MotionProbeState -Files $files -Roots $roots -Main $main -BeforeMain $before -ExpectedMain $expected -Report $testRoot -StartedUtc $started -ExitedUtc ([DateTime]::UtcNow) -OwnedProcessExited $true
if(-not $result.stateRestored -or [IO.File]::ReadAllText($main)-ne 'original'){throw 'clean recovery failed'}
# The runner parses ISO UTC timestamps into local-kind DateTimes. Compare UTC
# instants, and include the exact dated slot-3 backup created across midnight.
[IO.File]::WriteAllBytes($main,$expected)
[IO.File]::WriteAllText($created,'new test slot')
$daily=Join-Path $roots[0] ([DateTime]::Now.ToString('yyyyMMdd')+'.rep_persistentgamedata3.dat')
[IO.File]::WriteAllText($daily,'dated test backup')
$dailyUserCopy=Join-Path $roots[0] ([DateTime]::Now.ToString('yyyyMMdd')+'.rep_persistentgamedata1.dat')
[IO.File]::WriteAllText($dailyUserCopy,'user data')
$phase2=Join-Path $testRoot 'phase2';New-Item -ItemType Directory -Path $phase2|Out-Null
$result=Restore-MotionProbeState -Files $files -Roots $roots -Main $main -BeforeMain $before -ExpectedMain $expected -Report $phase2 -StartedUtc $started.ToLocalTime() -ExitedUtc ([DateTime]::Now) -OwnedProcessExited $true -SavedSlots @(1,3)
if(-not $result.stateRestored -or (Test-Path -LiteralPath $daily)-or (Test-Path -LiteralPath $dailyUserCopy)-or (Test-Path -LiteralPath $created)){throw 'local-kind timestamp or hash-proven dated backup recovery failed'}
$bootstrap=Join-Path $roots[1] 'remote/rep_gamestate2.dat';[IO.File]::WriteAllText($bootstrap,'owned bootstrap state')
$phase3=Join-Path $testRoot 'phase3';New-Item -ItemType Directory -Path $phase3|Out-Null
$result=Restore-MotionProbeState -Files $files -Roots $roots -Main $main -BeforeMain $before -ExpectedMain $expected -Report $phase3 -StartedUtc $started -ExitedUtc ([DateTime]::UtcNow) -OwnedProcessExited $true -SavedSlots @(2,3)
if(-not(Test-Path -LiteralPath $bootstrap)-or $result.stateRestored){throw 'new other-slot save needs explicit missing-at-boot proof'}
$phase4=Join-Path $testRoot 'phase4';New-Item -ItemType Directory -Path $phase4|Out-Null
$result=Restore-MotionProbeState -Files $files -Roots $roots -Main $main -BeforeMain $before -ExpectedMain $expected -Report $phase4 -StartedUtc $started -ExitedUtc ([DateTime]::UtcNow) -OwnedProcessExited $true -SavedSlots @(2,3) -BootMissingSlots @(2)
if(-not $result.stateRestored -or(Test-Path -LiteralPath $bootstrap)){throw ('proven new bootstrap state not archived: '+($result|ConvertTo-Json -Depth 3))}
$runner=[IO.File]::ReadAllText((Join-Path $PSScriptRoot '../tools/test-motion-native.ps1'))
if(-not $runner.Contains('Restore-MotionProbeState')){throw 'native runner still bypasses resilient recovery'}
'motion_native_state: PASS (concurrent edit, missing original, exact owned addition, unknown addition, clean restoration, runner integration)'
