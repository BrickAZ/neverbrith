param([string]$Root = ([IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../../..'))))
$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
$inventoryRoot = (Resolve-Path -LiteralPath $Root).Path
$inventoryDocument = Join-Path $inventoryRoot 'docs/architecture/refactor-inventory.md'
$sharedDocument = Join-Path $inventoryRoot 'docs/architecture/shared-capability-status.md'
$inventoryText = Get-Content -LiteralPath $inventoryDocument -Raw
$sharedText = Get-Content -LiteralPath $sharedDocument -Raw
[xml]$registration = Get-Content -LiteralPath (Join-Path $inventoryRoot 'content/items.xml') -Raw
$registered = @{}
foreach ($node in $registration.items.ChildNodes) {
    if ($node.NodeType -ne 'Element') { continue }
    if ($node.LocalName -notin @('passive','active','familiar','trinket')) { throw "Unexpected item node $($node.LocalName)" }
    $prefix = if ($node.LocalName -eq 'trinket') { 'T' } else { 'C' }
    $key = $prefix + ':' + $node.GetAttribute('id')
    if ($registered.ContainsKey($key)) { throw "Duplicate XML ID: $key" }
    $registered[$key] = $node.GetAttribute('name')
}
$rows = @{}
$entryFiles = @{}
foreach ($line in ($inventoryText -split '\r?\n')) {
    if ($line -notmatch '^\| ([CT]:\d+) \|') { continue }
    $cells = @($line.Trim().Trim('|').Split('|') | ForEach-Object { $_.Trim() })
    if ($cells.Count -ne 8) { throw "Malformed inventory row: $line" }
    $key = $cells[0]
    if ($rows.ContainsKey($key)) { throw "Duplicate inventory ID: $key" }
    if (-not $registered.ContainsKey($key)) { throw "Undeclared inventory ID: $key" }
    $displayNames = @($cells[1] -split '<br>')
    if ($registered[$key] -notin $displayNames) { throw "XML name differs at $key : $($cells[1])" }
    foreach ($cell in $cells) { if ([string]::IsNullOrWhiteSpace($cell)) { throw "Empty inventory field at $key" } }
    $rows[$key] = $cells
    if ($key -ne 'C:31') {
        $entryMatches = [regex]::Matches($cells[2], '\]\(([^)]+\.lua)\)')
        if ($entryMatches.Count -lt 1) { throw "Missing executable entry for $key" }
        foreach ($match in $entryMatches) {
            $target = [IO.Path]::GetFullPath((Join-Path (Split-Path $inventoryDocument -Parent) $match.Groups[1].Value))
            if (-not (Test-Path -LiteralPath $target -PathType Leaf)) { throw "Missing entry $target" }
            $entryFiles[[IO.Path]::GetRelativePath($inventoryRoot,$target).Replace('\','/')] = $true
        }
        if ($cells[7] -notmatch 'reports/refactor-batch\d+/[\d-]+/delivery\.md') { throw "Missing batch evidence at $key" }
    } elseif ($cells[6] -notmatch '仅登记') { throw 'ds4 must remain explicitly registration-only' }
}
foreach ($key in $registered.Keys) {
    if (-not $rows.ContainsKey($key)) { throw "Missing registered item: $key" }
}
$collectibles = @($rows.Keys | Where-Object { $_ -like 'C:*' }).Count
$trinkets = @($rows.Keys | Where-Object { $_ -like 'T:*' }).Count
if ($collectibles -ne 69 -or $trinkets -ne 2) { throw "Expected 69 collectibles and 2 trinkets; got $collectibles / $trinkets" }

# Check real literal include reachability of the listed entries. This is not full Lua dependency analysis.
$queue = [Collections.Generic.Queue[string]]::new()
$queue.Enqueue('main.lua')
$loaded = @{}
while ($queue.Count) {
    $relative = $queue.Dequeue()
    if ($loaded.ContainsKey($relative)) { continue }
    $loaded[$relative]=$true
    $source = Get-Content -LiteralPath (Join-Path $inventoryRoot $relative) -Raw
    foreach ($match in [regex]::Matches($source, '\binclude\s*\(\s*["'']([^"'']+)["'']')) {
        $path = $match.Groups[1].Value.Replace('.','/').Replace('\','/') + '.lua'
        if (Test-Path -LiteralPath (Join-Path $inventoryRoot $path) -PathType Leaf) { $queue.Enqueue($path) }
    }
}
foreach ($entry in $entryFiles.Keys) {
    if (-not $loaded.ContainsKey($entry)) { throw "Inventory entry not reached by literal include graph: $entry" }
}

$linkCount = 0
foreach ($document in @($inventoryDocument,$sharedDocument,(Join-Path $inventoryRoot 'docs/architecture/refactor-progress.md'))) {
    $text = Get-Content -LiteralPath $document -Raw
    foreach ($match in [regex]::Matches($text, '\[[^\]]*\]\(([^)#]+)(?:#[^)]*)?\)')) {
        $path = $match.Groups[1].Value
        if ($path -match '^[a-z]+://') { continue }
        $target = [IO.Path]::GetFullPath((Join-Path (Split-Path $document -Parent) $path))
        if (-not (Test-Path -LiteralPath $target)) { throw "Broken inventory link: $document -> $path" }
        $linkCount++
    }
}
$publicFiles = @(foreach ($directory in @('runtime','systems','catalog','integrations')) {
    Get-ChildItem -LiteralPath (Join-Path $inventoryRoot ('scripts/'+$directory)) -Recurse -File -Filter '*.lua'
})
$publicFiles += @(foreach ($name in @('shared','active_charge','reward_selection','reward_ledger','reward_delivery')) {
    Get-Item -LiteralPath (Join-Path $inventoryRoot ('scripts/features/boxes/'+$name+'.lua'))
})
foreach ($file in $publicFiles) {
    $relative = [IO.Path]::GetRelativePath($inventoryRoot,$file.FullName).Replace('\','/')
    if (-not $sharedText.Contains('../../'+$relative+')')) { throw "Shared capability module missing: $relative" }
}
$result = [ordered]@{
    exitCode=0
    collectibles=$collectibles
    gameplayCollectibles=68
    trinkets=$trinkets
    entryFiles=$entryFiles.Count
    literalReachableFiles=$loaded.Count
    sharedModules=$publicFiles.Count
    linksChecked=$linkCount
    verification='XML IDs/names, complete unique rows, entry/evidence existence, literal include reachability, shared-module coverage'
    limitations='Not full Lua dependency analysis; not behavior, performance or native validation.'
}
$result | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $PSScriptRoot 'checks.json') -Encoding utf8
$result | ConvertTo-Json -Depth 4
