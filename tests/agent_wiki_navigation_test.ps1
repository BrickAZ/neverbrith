#requires -Version 7.0
param([string]$Root = (Split-Path -Parent $PSScriptRoot))

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$rootPath = (Resolve-Path -LiteralPath $Root).Path
$entry = Join-Path $rootPath 'AGENTS.md'
$wikiRoot = Join-Path $rootPath 'docs/agent'
$index = Join-Path $wikiRoot 'index.md'
foreach ($path in @($entry, $index)) {
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { throw "Missing navigation entry: $path" }
}
$documents = @($entry) + @(Get-ChildItem -LiteralPath $wikiRoot -File -Recurse -Filter '*.md' | ForEach-Object FullName)
$graph = @{}
$linkCount = 0
foreach ($document in $documents) {
    $targets = [Collections.Generic.List[string]]::new()
    $body = Get-Content -Raw -LiteralPath $document -Encoding utf8
    foreach ($match in [regex]::Matches($body, '\[[^\]]*\]\(([^)]+)\)')) {
        $link = $match.Groups[1].Value.Trim().Trim('<', '>')
        if ($link -match '^(https?://|mailto:|#)') { continue }
        $relative = [Uri]::UnescapeDataString($link.Split('#')[0])
        if ([IO.Path]::IsPathRooted($relative) -or $relative -match '^\w+:') { throw "Use repository-relative links in ${document}: $link" }
        $target = [IO.Path]::GetFullPath((Join-Path (Split-Path -Parent $document) $relative))
        if (-not (Test-Path -LiteralPath $target)) { throw "Broken link in ${document}: $link" }
        $targets.Add($target)
        $linkCount++
    }
    $graph[$document] = @($targets.ToArray())
}
if ($index -notin $graph[$entry]) { throw 'AGENTS.md must link directly to docs/agent/index.md.' }
$visited = [Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue($index)
while ($queue.Count -gt 0) {
    $current = $queue.Dequeue()
    if (-not $visited.Add($current)) { continue }
    foreach ($target in $graph[$current]) {
        if ($graph.ContainsKey($target)) { $queue.Enqueue($target) }
    }
}
foreach ($document in $documents | Where-Object { $_ -ne $entry }) {
    if (-not $visited.Contains($document)) { throw "Unreachable knowledge document: $document" }
}
Write-Output "Agent navigation passed: $($documents.Count - 1) wiki pages reachable; $linkCount local links resolve. Content freshness and source semantics still require review."
