#requires -Version 7.0
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$pwsh = (Get-Process -Id $PID).Path
$sandbox = Join-Path ([IO.Path]::GetTempPath()) ('neverbrith skill source ' + [guid]::NewGuid().ToString('N'))
$utf8 = [Text.UTF8Encoding]::new($false)
$cases = 0
function Put([string]$Relative, [string]$Body) {
    $path = Join-Path $sandbox $Relative
    [IO.Directory]::CreateDirectory((Split-Path -Parent $path)) | Out-Null
    [IO.File]::WriteAllText($path, $Body, $utf8)
}
function Check([string]$Relative, [int]$Expected, [string[]]$Extra = @()) {
    $result = & $pwsh -NoProfile -File (Join-Path $rootPath $Relative) -Root $sandbox @Extra 2>&1 | Out-String
    $code = $LASTEXITCODE
    if ($code -ne $Expected) { throw "$Relative expected exit $Expected, got $code`n$result" }
    if ($Expected -eq 1 -and $result -notmatch 'Skill contains an absolute local path|Skill must be self-contained') {
        throw "Expected the skill-path failure, not an unrelated failure: $result"
    }
    $script:cases++
    Write-Output "PASS $Relative (expected=$Expected actual=$code)"
}
try {
    Put 'main.lua' 'return {}'
    Put 'content/items.xml' '<items />'
    Put 'tools/check-neverbrith.ps1' '# Fixture checkout marker for the installed strict adapter.'
    Put 'docs/agent/testing.md' '# Fixture checkout marker.'
    Put 'tools/generate-neverbirth-collectibles.ps1' 'param([string]$Root,[switch]$Check); if (-not $Check) { throw "Check mode required" }'
    Copy-Item -LiteralPath (Join-Path $rootPath 'tools/validators/validate-neverbrith.ps1') -Destination ([IO.Directory]::CreateDirectory((Join-Path $sandbox 'tools/validators')).FullName)
    # Deliberately broken old archive must not become the source of active checks.
    Put 'docs/skills/isaac-old/evals/evals.json' '{invalid old archive'
    $entry = "---`nname: isaac-fixture`ndescription: Fixture skill`n---`nOfficial source: https://example.org/docs`n"
    Put '.agents/skills/isaac-fixture/SKILL.md' $entry
    Put '.agents/skills/isaac-fixture/evals/evals.json' '{"evals":[]}'
    $generics = @(
        'tools/validators/validate-isaac-mod.ps1',
        'docs/skills/isaac-validators/scripts/validate-isaac-mod.ps1',
        '.agents/skills/isaac-validators/scripts/validate-isaac-mod.ps1'
    )
    $stricts = @(
        'tools/validators/validate-neverbrith.ps1',
        'docs/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1',
        '.agents/skills/isaac-neverbrith-validator-profile/scripts/validate-neverbrith.ps1'
    )
    foreach ($script in $generics) { Check $script 0 @('-SkillRoot', (Join-Path $sandbox '.agents/skills')) }
    foreach ($script in $stricts) { Check $script 0 }
    Put '.agents/skills/isaac-fixture/SKILL.md' ($entry + 'Local-only dependency: C:\private\dependency')
    foreach ($script in $generics) { Check $script 1 @('-SkillRoot', (Join-Path $sandbox '.agents/skills')) }
    foreach ($script in $stricts) { Check $script 1 }
    Write-Output "Skill source validation: $cases cases passed."
} finally {
    # The GUID-named fixture must resolve strictly beneath the system temp root.
    $tempRoot = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\','/') + [IO.Path]::DirectorySeparatorChar
    $resolved = [IO.Path]::GetFullPath($sandbox)
    if (-not $resolved.StartsWith($tempRoot, [StringComparison]::OrdinalIgnoreCase) -or
        (Split-Path -Leaf $resolved) -notlike 'neverbrith skill source *') { throw "Unsafe fixture cleanup: $resolved" }
    if (Test-Path -LiteralPath $resolved) { Remove-Item -LiteralPath $resolved -Recurse -Force }
}
