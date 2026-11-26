#requires -Version 7.0
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$skillRoot = Join-Path $rootPath '.agents/skills'
$packages = @(Get-ChildItem -LiteralPath $skillRoot -Directory -Filter 'isaac-*')
if (-not $packages.Count) { throw 'Authoritative Isaac skill package is missing.' }
$legacyRoot = Join-Path $rootPath 'docs/skills'
if (Test-Path -LiteralPath $legacyRoot) {
    $oldEntries = @(Get-ChildItem -LiteralPath $legacyRoot -Recurse -File -Filter 'SKILL.md')
    if ($oldEntries.Count) { throw 'Retired SKILL.md files belong in deprecated/skills, not docs/skills.' }
}
$referenceCount = 0
$evalCount = 0
foreach ($package in $packages) {
    $entry = Join-Path $package.FullName 'SKILL.md'
    $body = Get-Content -LiteralPath $entry -Raw -Encoding utf8
    if ($body -notmatch '(?s)\A---\r?\n(?<metadata>.*?)\r?\n---') { throw "Missing skill frontmatter: $entry" }
    $metadata = $Matches.metadata
    if ($metadata -notmatch '(?m)^name:\s*(?<name>[a-z0-9-]+)\s*$' -or $Matches.name -ne $package.Name) { throw "Skill name does not match directory: $entry" }
    if ($metadata -notmatch '(?m)^description:\s*\S') { throw "Missing skill description: $entry" }
    foreach ($file in Get-ChildItem -LiteralPath $package.FullName -Recurse -File) {
        if ($file.Extension -notin @('.md','.json')) { continue }
        $source = Get-Content -LiteralPath $file.FullName -Raw -Encoding utf8
        if ($source -match '(?i)(?:(?<![A-Za-z0-9])[A-Za-z]:[\\/]|file://)') { throw "Skill contains an absolute local path: $($file.FullName)" }
        if ($file.Name -eq 'evals.json') {
            $evaluation = $source | ConvertFrom-Json
            $evalCount++
            if ($package.Name -in @('isaac-neverbrith-dev','isaac-neverbrith-router','isaac-neverbrith-validator-profile')) {
                foreach ($case in $evaluation.evals) {
                    foreach ($relative in $case.files) {
                        if (-not (Test-Path -LiteralPath (Join-Path $rootPath $relative))) { throw "Missing eval context: $($package.Name) -> $relative" }
                    }
                }
            }
        }
        if ($file.Extension -eq '.md') {
            $pattern = '(?:`|\]\()(?<reference>(?:\.\.[\\/]|references[\\/])[^`)\s]+?\.md)(?:`|\))'
            foreach ($match in [regex]::Matches($source, $pattern)) {
                $reference = $match.Groups['reference'].Value
                if (-not (Test-Path -LiteralPath (Join-Path $file.DirectoryName $reference))) { throw "Skill reference does not exist: $reference in $($file.FullName)" }
                $referenceCount++
            }
        }
    }
}
Write-Output "Skill packages passed: $($packages.Count) authoritative packages, $evalCount evaluation JSON files, $referenceCount local references; no SKILL.md remains in docs/skills. AI behavior is not evaluated by this check."
