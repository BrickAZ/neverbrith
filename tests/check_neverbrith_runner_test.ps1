#requires -Version 7.0
param([string]$LuaPath)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$runner = Join-Path (Split-Path -Parent $PSScriptRoot) 'tools/check-neverbrith.ps1'
if (-not (Test-Path -LiteralPath $runner)) { throw 'Unified check runner is missing.' }
if (-not $LuaPath) { $LuaPath = (Get-Command lua -CommandType Application -ErrorAction Stop).Source }
$pwsh = (Get-Process -Id $PID).Path
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('neverbrith runner ' + [guid]::NewGuid().ToString('N'))
$report = Join-Path $sandbox 'result.json'
$utf8 = [Text.UTF8Encoding]::new($false)
$cases = 0

function Put([string]$RelativePath, [string]$Content) {
    $path = Join-Path $sandbox $RelativePath
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [IO.File]::WriteAllText($path, $Content, $utf8)
}
function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "Runner contract failed: $Message" }
}
function Run([string]$Executable = $LuaPath, [int]$Timeout = 30) {
    # A previous report must never make a failed invocation look successful.
    if (Test-Path -LiteralPath $report) { Remove-Item -LiteralPath $report }
    $output = & $pwsh -NoProfile -File $runner -Root $sandbox -Profile LuaAll -LuaPath $Executable -TimeoutSeconds $Timeout -ReportPath $report 2>&1
    $code = $LASTEXITCODE
    Require (Test-Path -LiteralPath $report) "report missing; exit=$code; $output"
    return [pscustomobject]@{Code=$code;Data=(Get-Content -Raw -LiteralPath $report | ConvertFrom-Json)}
}

try {
    # These controlled PowerShell children isolate the real runner's process and
    # status handling; actual repository validators run separately in Pilot/LuaAll.
    $stub = 'param([string]$Root,[string]$ModObjectName,[string]$SkillRoot,[switch]$ReadmeOnly); exit 0'
    foreach ($path in @(
        'docs/skills/isaac-validators/scripts/validate-isaac-mod.ps1',
        'docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1',
        'tools/validate_mystuff_local_ids.ps1',
        'tests/compatibility_docs_test.ps1',
        'tests/agent_wiki_navigation_test.ps1'
    )) { Put $path $stub }
    Put 'main.lua' 'return {}'
    Put 'tests/a_test.lua' 'SHOULD_NOT_LEAK=99; assert(io.open("main.lua", "r")):close(); print("first child ran")'
    Put 'tests/b_test.lua' 'error("intentional behavior failure")'
    $result = Run
    Require ($result.Code -eq 1) 'a failed Lua child must fail the command'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'lua:a_test.lua' -and $_.Status -eq 'passed' }).Count -eq 1) 'successful child must still be recorded'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'lua:b_test.lua' -and $_.Status -eq 'failed' -and $_.Stderr -match 'intentional behavior failure' }).Count -eq 1) 'original error must be retained'
    $cases++

    Put 'tests/b_test.lua' 'assert(SHOULD_NOT_LEAK==nil); print("second child ran")'
    $result = Run
    Require ($result.Code -eq 0 -and $result.Data.Passed) 'all selected checks should pass'
    Require ($result.Data.LuaTestCount -eq 2 -and -not $result.Data.InGameVerified) 'scope and in-game boundary must be explicit'
    $cases++

    Put 'main.lua' 'local = invalid'
    $result = Run
    Require ($result.Code -eq 1) 'real source syntax failure must fail the command'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'lua-syntax' -and $_.Status -eq 'failed' }).Count -eq 1) 'syntax check must parse main.lua, not empty stdin'
    $cases++
    Put 'main.lua' 'return {}'

    Put 'docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1' 'Write-Output "intentional static failure"; exit 7'
    $result = Run
    Require ($result.Code -eq 1) 'PowerShell validator failure must propagate'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'static:strict' -and $_.ExitCode -eq 7 }).Count -eq 1) 'validator exit code must survive aggregation'
    $cases++
    Put 'docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1' $stub

    $result = Run (Join-Path $sandbox 'missing-lua.exe')
    Require ($result.Code -eq 2 -and -not $result.Data.Passed) 'explicit missing runner must be blocked, with no fallback'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'lua:b_test.lua' -and $_.Status -eq 'not_run' }).Count -eq 1) 'unrun Lua tests must not pass'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'static:generic' -and $_.Status -eq 'passed' }).Count -eq 1) 'independent static work must still run'
    $cases++

    $result = Run $pwsh
    Require ($result.Code -eq 2 -and -not $result.Data.Passed) 'a non-Lua version must not qualify as the Lua runtime'
    $cases++

    Put 'tests/b_test.lua' 'while true do end'
    $result = Run -Timeout 2
    Require ($result.Code -eq 1) 'timeout must fail'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'lua:b_test.lua' -and $_.TimedOut }).Count -eq 1) 'timeout must be distinguishable'
    $cases++

    Remove-Item -LiteralPath (Join-Path $sandbox 'tests/a_test.lua'), (Join-Path $sandbox 'tests/b_test.lua')
    $result = Run
    Require ($result.Code -eq 1 -and $result.Data.LuaTestCount -eq 0) 'zero discovered tests must fail'
    $cases++

    Put 'tests/a_test.lua' 'print("restored test")'
    Remove-Item -LiteralPath (Join-Path $sandbox 'tools/validate_mystuff_local_ids.ps1')
    $result = Run
    Require ($result.Code -eq 1) 'a missing required check must fail'
    Require (@($result.Data.Checks | Where-Object { $_.Id -eq 'static:mystuff' -and $_.Status -eq 'failed' }).Count -eq 1) 'missing validator must not be silently skipped'
    $cases++
    Write-Output "Runner contract tests passed: $cases cases."
} finally {
    # Delete only this test's verified, uniquely named temporary directory.
    $resolved = [IO.Path]::GetFullPath($sandbox)
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd([IO.Path]::DirectorySeparatorChar) + [IO.Path]::DirectorySeparatorChar
    if ($resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -and (Split-Path -Leaf $resolved) -like 'neverbrith runner *') {
        if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
    } else { throw "Unsafe temporary cleanup path: $resolved" }
}
