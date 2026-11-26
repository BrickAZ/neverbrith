#requires -Version 7.0
[CmdletBinding()]
param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [ValidateSet('Pilot', 'LuaAll')][string]$Profile = 'Pilot',
    [string]$LuaPath,
    [ValidateRange(1, 600)][int]$TimeoutSeconds = 60,
    [string]$ReportPath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$pwshPath = (Get-Process -Id $PID).Path
$checks = [Collections.Generic.List[object]]::new()
$startedAt = [DateTime]::UtcNow

function Record-Check([object]$Result) {
    $checks.Add($Result)
    Write-Host ('[{0}] {1} (exit={2}, warnings={3})' -f $Result.Status, $Result.Id, $Result.ExitCode, $Result.WarningCount)
    if ($Result.Status -in @('failed', 'blocked')) {
        if ($Result.Note) { Write-Host $Result.Note }
        $detail = ($Result.Stderr + "`n" + $Result.Stdout).Trim()
        if ($detail) { Write-Host (($detail -split '\r?\n' | Select-Object -First 8) -join "`n") }
    }
}

function New-Result([string]$Id, [string]$Status, [string]$Note = '') {
    return [pscustomobject][ordered]@{
        Id = $Id; Status = $Status; ExitCode = $null; TimedOut = $false
        DurationMs = 0; Executable = ''; Arguments = @()
        Stdout = ''; Stderr = ''; WarningCount = 0; Note = $Note
    }
}

function Invoke-Check([string]$Id, [string]$Executable, [string[]]$Arguments) {
    $result = New-Result $Id 'blocked'
    $result.Executable = $Executable
    $result.Arguments = $Arguments
    $watch = [Diagnostics.Stopwatch]::StartNew()
    $process = [Diagnostics.Process]::new()
    try {
        $info = [Diagnostics.ProcessStartInfo]::new()
        $info.FileName = $Executable
        $info.WorkingDirectory = $rootPath
        $info.UseShellExecute = $false
        $info.CreateNoWindow = $true
        $info.RedirectStandardOutput = $true
        $info.RedirectStandardError = $true
        $info.StandardOutputEncoding = [Text.UTF8Encoding]::new($false)
        $info.StandardErrorEncoding = [Text.UTF8Encoding]::new($false)
        foreach ($argument in $Arguments) { $info.ArgumentList.Add($argument) }
        $process.StartInfo = $info
        $null = $process.Start()
        # Drain both pipes asynchronously, including the verbose strict validator.
        $stdout = $process.StandardOutput.ReadToEndAsync()
        $stderr = $process.StandardError.ReadToEndAsync()
        if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
            $result.TimedOut = $true
            $result.Note = "Exceeded $TimeoutSeconds seconds; terminated child process tree."
            $process.Kill($true)
        }
        $process.WaitForExit()
        $result.Stdout = $stdout.GetAwaiter().GetResult()
        $result.Stderr = $stderr.GetAwaiter().GetResult()
        $result.ExitCode = $process.ExitCode
        $result.Status = if ($result.ExitCode -eq 0 -and -not $result.TimedOut) { 'passed' } else { 'failed' }
        $result.WarningCount = [regex]::Matches($result.Stdout, '(?m)^WARN\b').Count
    } catch {
        $result.Note = $_.Exception.Message
    } finally {
        $watch.Stop()
        $result.DurationMs = $watch.ElapsedMilliseconds
        $process.Dispose()
    }
    return $result
}

function Invoke-ScriptCheck([string]$Id, [string]$RelativePath, [string[]]$Arguments = @()) {
    $path = Join-Path $rootPath $RelativePath
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        Record-Check (New-Result $Id 'failed' "Required check script is missing: $RelativePath")
        return
    }
    Record-Check (Invoke-Check $Id $pwshPath (@('-NoProfile', '-File', $path) + $Arguments))
}

$pilotNames = @(
    'between_death_and_life_behavior_test.lua', 'dice_set_behavior_test.lua',
    'shredded_tarot_behavior_test.lua', 'sterilization_certificate_behavior_test.lua',
    'repentogon_bootstrap_test.lua', 'repentogon_dependency_guard_test.lua', 'localization_test.lua',
    'memory_disorder_behavior_test.lua', 'memory_disorder_health_regression_test.lua',
    'memory_disorder_pairs_regression_test.lua', 'memory_disorder_icons_test.lua'
)
$testsDirectory = Join-Path $rootPath 'tests'
$luaTests = if ($Profile -eq 'Pilot') {
    @($pilotNames | ForEach-Object { Join-Path $testsDirectory $_ })
} elseif (Test-Path -LiteralPath $testsDirectory) {
    @(Get-ChildItem -LiteralPath $testsDirectory -File -Filter '*_test.lua' | Sort-Object Name | ForEach-Object FullName)
} else { @() }
$luaTests = @($luaTests)
if ($luaTests.Count -eq 0) { Record-Check (New-Result 'lua-discovery' 'failed' 'No *_test.lua files were discovered; zero tests is not a pass.') }

# No installation, global PATH edit, or implicit replacement of an explicit path.
$candidates = if ($LuaPath) { @($LuaPath) } else {
    $found = Get-Command lua -CommandType Application -ErrorAction SilentlyContinue
    if ($found) { $found.Source }
    if ($env:LOCALAPPDATA) { Join-Path $env:LOCALAPPDATA 'Programs/Lua/bin/lua.exe' }
}
$luaExecutable = $null
foreach ($candidate in @($candidates | Select-Object -Unique)) {
    if (Test-Path -LiteralPath $candidate -PathType Leaf) { $luaExecutable = (Resolve-Path -LiteralPath $candidate).Path; break }
    $command = Get-Command $candidate -CommandType Application -ErrorAction SilentlyContinue
    if ($command) { $luaExecutable = $command.Source; break }
}
$runtime = if ($luaExecutable) { Invoke-Check 'lua-runtime' $luaExecutable @('-v') } else {
    New-Result 'lua-runtime' 'blocked' 'Lua was not found. Supply -LuaPath with an existing Lua 5.4 executable.'
}
if ($runtime.Status -eq 'passed' -and ($runtime.Stdout + $runtime.Stderr) -notmatch 'Lua 5\.4(?:\.|\s)') {
    $runtime.Status = 'blocked'
    $runtime.Note = 'This profile requires Lua 5.4; the discovered version does not match.'
}
Record-Check $runtime

$syntaxFiles = @(Get-ChildItem -LiteralPath $rootPath -File -Filter '*.lua' | Sort-Object Name | ForEach-Object FullName)
foreach ($directory in @('generated', 'tests')) {
    $path = Join-Path $rootPath $directory
    if (Test-Path -LiteralPath $path) { $syntaxFiles += @(Get-ChildItem -LiteralPath $path -File -Filter '*.lua' | Sort-Object Name | ForEach-Object FullName) }
}
if ($runtime.Status -eq 'passed') {
    # '-' occupies arg[0]; the explicit file list starts at arg[1]. Exit before
    # Lua attempts to execute stdin or any parsed file.
    $syntaxCode = 'assert(#arg>0,"no syntax inputs"); local n=0; for i=1,#arg do local f,e=loadfile(arg[i]); if not f then io.stderr:write(e,"\n"); os.exit(1) end; n=n+1 end; print("SYNTAX_FILES "..n); os.exit(0)'
    Record-Check (Invoke-Check 'lua-syntax' $luaExecutable (@('-e', $syntaxCode, '--', '-') + $syntaxFiles))
} else { Record-Check (New-Result 'lua-syntax' 'not_run' 'Lua runtime preflight did not pass.') }

foreach ($test in $luaTests) {
    $id = 'lua:' + (Split-Path -Leaf $test)
    if (-not (Test-Path -LiteralPath $test -PathType Leaf)) {
        Record-Check (New-Result $id 'failed' 'Required test file is missing.')
    } elseif ($runtime.Status -ne 'passed') {
        Record-Check (New-Result $id 'not_run' 'Lua runtime preflight did not pass.')
    } else { Record-Check (Invoke-Check $id $luaExecutable @($test)) }
}

Invoke-ScriptCheck 'static:generic' 'tools/validators/validate-isaac-mod.ps1' @('-Root', $rootPath, '-ModObjectName', 'Neverbirth', '-SkillRoot', (Join-Path $rootPath '.agents/skills'))
Invoke-ScriptCheck 'static:strict' 'tools/validators/validate-neverbrith.ps1' @('-Root', $rootPath)
Invoke-ScriptCheck 'static:mystuff' 'tools/validate_mystuff_local_ids.ps1'
Invoke-ScriptCheck 'docs:readme' 'tests/compatibility_docs_test.ps1' @('-Root', $rootPath, '-ReadmeOnly')
Invoke-ScriptCheck 'docs:agent-wiki' 'tests/agent_wiki_navigation_test.ps1' @('-Root', $rootPath)

$failed = @($checks | Where-Object Status -eq 'failed').Count
$blocked = @($checks | Where-Object { $_.Status -in @('blocked', 'not_run') }).Count
$exitCode = if ($failed) { 1 } elseif ($blocked) { 2 } else { 0 }
$report = [pscustomobject][ordered]@{
    SchemaVersion = 1; Root = $rootPath; Profile = $Profile
    StartedAtUtc = $startedAt.ToString('o'); FinishedAtUtc = [DateTime]::UtcNow.ToString('o')
    Passed = ($exitCode -eq 0); ExitCode = $exitCode; InGameVerified = $false
    LuaTestCount = $luaTests.Count; SyntaxFileCount = $syntaxFiles.Count
    Summary = [pscustomobject]@{Passed=@($checks | Where-Object Status -eq 'passed').Count;Failed=$failed;BlockedOrNotRun=$blocked;Warnings=($checks | Measure-Object WarningCount -Sum).Sum}
    Scope = 'Selected Lua behavior tests; root/generated/tests Lua syntax; repository generic/strict/My Stuff validators; README-only and agent navigation checks.'
    NotCovered = @('In-game execution, rendering, input, save/continue and mod combinations', 'Other PowerShell tests, Python/Node tests, full compatibility examples, and runner/strict-validator self-tests', 'Historical/release/worktree copies are not independently validated; strict Lua scope follows static literal loads from the selected main.lua and does not resolve loader aliases')
    Checks = @($checks.ToArray())
}
if ($ReportPath) {
    $outputPath = if ([IO.Path]::IsPathRooted($ReportPath)) { [IO.Path]::GetFullPath($ReportPath) } else { [IO.Path]::GetFullPath((Join-Path $rootPath $ReportPath)) }
    [IO.Directory]::CreateDirectory((Split-Path -Parent $outputPath)) | Out-Null
    [IO.File]::WriteAllText($outputPath, ($report | ConvertTo-Json -Depth 8), [Text.UTF8Encoding]::new($false))
    Write-Host "Report: $outputPath"
}
Write-Host ("Selected checks: {0} passed, {1} failed, {2} blocked/not run; {3} warnings. In-game: not verified." -f $report.Summary.Passed, $failed, $blocked, $report.Summary.Warnings)
exit $exitCode
