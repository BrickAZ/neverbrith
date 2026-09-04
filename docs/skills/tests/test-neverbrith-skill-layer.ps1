param(
    [string]$ProjectRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..")),
    [string]$InstalledSkillRoot = (Join-Path $HOME ".codex\skills"),
    [switch]$SkipInstalledParity
)

$ErrorActionPreference = "Stop"
$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure([string]$message) {
    $failures.Add($message) | Out-Null
}

$sourceRoot = Join-Path $ProjectRoot "docs\skills"
$routerPath = Join-Path $sourceRoot "isaac-neverbrith-router\SKILL.md"
$devPath = Join-Path $sourceRoot "isaac-neverbrith-dev\SKILL.md"
$router = Get-Content -LiteralPath $routerPath -Raw -Encoding UTF8
$dev = Get-Content -LiteralPath $devPath -Raw -Encoding UTF8

foreach ($name in @(
    'isaac-collectible-registration',
    'isaac-passive-collectibles',
    'isaac-damage-health-contracts',
    'isaac-item-synergies',
    'isaac-reroll-removal-contracts',
    'isaac-rng-determinism',
    'isaac-character-art-surfaces',
    'isaac-reskins-resource-overrides',
    'isaac-localization-runtime',
    'isaac-eid-compat',
    'isaac-mcm-compat',
    'isaac-stageapi-compat',
    'isaac-repentogon-compat',
    'isaac-room-networks',
    'isaac-dimensions'
)) {
    if (-not $router.Contains($name)) {
        Add-Failure "Neverbrith router does not name current specialist: $name"
    }
}

foreach ($name in @('isaac-collectible-registration', 'isaac-passive-collectibles', 'isaac-damage-health-contracts')) {
    if (-not $dev.Contains($name)) {
        Add-Failure "Neverbrith item skill does not hand off to required specialist: $name"
    }
}

foreach ($name in @('isaac-neverbrith-dev', 'isaac-neverbrith-router', 'isaac-neverbrith-validator-profile')) {
    $evalPath = Join-Path $sourceRoot "$name\evals\evals.json"
    $evalDocument = Get-Content -LiteralPath $evalPath -Raw -Encoding UTF8 | ConvertFrom-Json
    if ([string]$evalDocument.skill_name -ne $name) {
        Add-Failure "Neverbrith eval skill_name mismatch: $name"
    }
    if (@($evalDocument.evals).Count -lt 2) {
        Add-Failure "Neverbrith skill needs at least two eval cases: $name"
    }
    $seenIds = @{}
    foreach ($evalCase in @($evalDocument.evals)) {
        if ($null -eq $evalCase.id -or $seenIds.ContainsKey([string]$evalCase.id)) {
            Add-Failure "Neverbrith eval id is missing or duplicated in ${name}: $($evalCase.id)"
        } else {
            $seenIds[[string]$evalCase.id] = $true
        }
        if ([string]::IsNullOrWhiteSpace([string]$evalCase.prompt) -or [string]::IsNullOrWhiteSpace([string]$evalCase.expected_output)) {
            Add-Failure "Neverbrith eval needs prompt and expected_output: $name/$($evalCase.id)"
        }
        if (@($evalCase.files).Count -eq 0) {
            Add-Failure "Neverbrith eval has no real context file: $name/$($evalCase.id)"
        }
        foreach ($contextPath in @($evalCase.files)) {
            $target = Join-Path $ProjectRoot ([string]$contextPath -replace '/', '\')
            if (-not (Test-Path -LiteralPath $target)) {
                Add-Failure "Neverbrith eval references missing context: $name/$($evalCase.id) -> $contextPath"
            }
        }
    }
}
if (-not $SkipInstalledParity) {
    foreach ($name in @('isaac-neverbrith-dev', 'isaac-neverbrith-router', 'isaac-neverbrith-validator-profile')) {
        $sourceDirectory = Join-Path $sourceRoot $name
        $installedDirectory = Join-Path $InstalledSkillRoot $name
        if (-not (Test-Path -LiteralPath $installedDirectory)) {
            Add-Failure "Installed Neverbrith skill is missing: $name"
            continue
        }
        foreach ($sourceFile in (Get-ChildItem -LiteralPath $sourceDirectory -Recurse -File)) {
            $relative = $sourceFile.FullName.Substring($sourceDirectory.Length).TrimStart('\')
            $installedFile = Join-Path $installedDirectory $relative
            if (-not (Test-Path -LiteralPath $installedFile)) {
                Add-Failure "Installed Neverbrith skill is missing file: $name/$relative"
                continue
            }
            $sourceHash = (Get-FileHash -LiteralPath $sourceFile.FullName -Algorithm SHA256).Hash
            $installedHash = (Get-FileHash -LiteralPath $installedFile -Algorithm SHA256).Hash
            if ($sourceHash -ne $installedHash) {
                Add-Failure "Installed Neverbrith skill differs from source: $name/$relative"
            }
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Output "Neverbrith skill-layer audit failed with $($failures.Count) issue(s):"
    $failures | ForEach-Object { Write-Output "FAIL $_" }
    exit 1
}

Write-Output "Neverbrith skill-layer audit passed."

