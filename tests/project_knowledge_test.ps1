#requires -Version 7.0
param([string]$Root = (Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$documents = @((Join-Path $rootPath 'AGENTS.md')) + @(
    Get-ChildItem -LiteralPath (Join-Path $rootPath 'docs/agent'),(Join-Path $rootPath 'docs/api') -Recurse -File -Filter '*.md' | ForEach-Object FullName
)
$graph = @{}
$links = 0
foreach ($document in $documents) {
    $body = Get-Content -LiteralPath $document -Raw -Encoding utf8
    # Code examples such as object[method](object) are not Markdown links.
    $body = [regex]::Replace($body, '(?ms)^\s*(`{3,}|~{3,})[^\r\n]*\r?\n.*?^\s*\1\s*$', '')
    $body = [regex]::Replace($body, '(`+)[^\r\n]*?\1', '')
    $targets = [Collections.Generic.List[string]]::new()
    foreach ($match in [regex]::Matches($body, '\[[^\]]*\]\(([^)]+)\)')) {
        $link = $match.Groups[1].Value.Trim().Trim('<','>')
        if ($link -match '^(https?://|mailto:|#)') { continue }
        $relative = [Uri]::UnescapeDataString($link.Split('#')[0])
        if ([IO.Path]::IsPathRooted($relative)) { throw "Use portable repository links: $document -> $link" }
        $target = [IO.Path]::GetFullPath((Join-Path (Split-Path $document -Parent) $relative))
        if (-not (Test-Path -LiteralPath $target)) { throw "Broken knowledge link: $document -> $link" }
        $targets.Add($target)
        $links++
    }
    $graph[$document] = @($targets.ToArray())
}
$visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue((Join-Path $rootPath 'AGENTS.md'))
while ($queue.Count) {
    $current = $queue.Dequeue()
    if (-not $visited.Add($current)) { continue }
    foreach ($target in $graph[$current]) { if ($graph.ContainsKey($target)) { $queue.Enqueue($target) } }
}
foreach ($document in $documents) { if (-not $visited.Contains($document)) { throw "Unreachable knowledge page: $document" } }

# Discover the agreed public-module surface; new files in these directories must be documented.
$shared = @(foreach ($directory in @('scripts/runtime','scripts/systems','scripts/catalog','scripts/integrations')) {
    Get-ChildItem -LiteralPath (Join-Path $rootPath $directory) -File -Recurse -Filter '*.lua' | ForEach-Object FullName
}) + @('scripts/features/boxes/shared.lua','scripts/features/boxes/active_charge.lua','scripts/features/boxes/reward_selection.lua','scripts/features/boxes/reward_ledger.lua','scripts/features/boxes/reward_delivery.lua' | ForEach-Object { Join-Path $rootPath $_ })
$apiIndex = Join-Path $rootPath 'docs/api/index.md'
$apiPages = @($documents | Where-Object { $_ -ne $apiIndex -and $_.StartsWith((Join-Path $rootPath 'docs/api') + [IO.Path]::DirectorySeparatorChar) })
foreach ($module in $shared) {
    if ($module -notin $graph[$apiIndex]) { throw "Shared module missing from API index: $module" }
    if (-not @($apiPages | Where-Object { $module -in $graph[$_] }).Count) { throw "Shared module lacks a usage page linked to its source: $module" }
}

$skillRoot = Join-Path $rootPath '.agents/skills'
$packages = @(Get-ChildItem -LiteralPath $skillRoot -Directory -Filter 'isaac-*')
if (-not $packages.Count) { throw 'Authoritative Isaac skill package is missing.' }
foreach ($package in $packages) {
    $entry = Join-Path $package.FullName 'SKILL.md'
    $text = Get-Content -LiteralPath $entry -Raw -Encoding utf8
    if ($text -notmatch '(?s)\A---\r?\n(?<metadata>.*?)\r?\n---') { throw "Missing skill frontmatter: $entry" }
    if ($Matches.metadata -notmatch '(?m)^name:\s*(?<name>[a-z0-9-]+)\s*$' -or $Matches.name -ne $package.Name) { throw "Skill name does not match directory: $entry" }
    foreach ($evaluation in @(Get-ChildItem -LiteralPath $package.FullName -Recurse -File -Filter 'evals.json')) {
        $data = Get-Content -LiteralPath $evaluation.FullName -Raw -Encoding utf8 | ConvertFrom-Json
        # Project-specific cases use real checkout paths; generic cases may describe supplied fixtures.
        if ($package.Name -in @('isaac-neverbrith-dev','isaac-neverbrith-router','isaac-neverbrith-validator-profile')) {
            foreach ($case in $data.evals) {
                foreach ($relative in $case.files) {
                    if (-not (Test-Path -LiteralPath (Join-Path $rootPath $relative))) { throw "Missing eval context: $($package.Name) -> $relative" }
                }
            }
        }
    }
}
Write-Output "Project knowledge passed: $($documents.Count) reachable pages, $links local links, $($shared.Count) shared modules with usage pages, $($packages.Count) authoritative skill entries. Semantic accuracy and agent behavior require review."
