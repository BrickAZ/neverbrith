param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot)
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Fail([string]$Message) {
    throw "compatibility docs test failed: $Message"
}

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { Fail $Message }
}

function RequireContains([string]$Text, [string]$Needle, [string]$Surface) {
    Require $Text.Contains($Needle) "$Surface is missing: $Needle"
}

function RequireNotContains([string]$Text, [string]$Needle, [string]$Surface) {
    Require (-not $Text.Contains($Needle)) "$Surface contains forbidden text: $Needle"
}

function CheckRelativeLinks([string]$DocumentPath, [string]$Text) {
    $directory = Split-Path -Parent $DocumentPath
    foreach ($match in [regex]::Matches($Text, '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value
        if ($target -match '^(https?://|#)') { continue }
        $pathOnly = $target.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($pathOnly)) { continue }
        $resolved = Join-Path $directory $pathOnly
        Require (Test-Path -LiteralPath $resolved) "broken relative link in ${DocumentPath}: $target"
    }
}

$englishPath = Join-Path $Root 'COMPATIBILITY.md'
Require (Test-Path -LiteralPath $englishPath) 'COMPATIBILITY.md does not exist'

$english = Get-Content -Raw -LiteralPath $englishPath
$main = Get-Content -Raw -LiteralPath (Join-Path $Root 'main.lua')

$normalizedEnglish = $english -replace "`r`n", "`n"
$requiredHeadings = @(
    '# Neverbirth compatibility guide',
    '## What another mod can add',
    '## Terms used in this guide',
    '## API status and stability',
    '## Finding Neverbirth and using runtime IDs',
    '### Names and global object',
    '### Runtime IDs, not XML-local IDs',
    '## Load order',
    '## Fortune Rivalling Heaven Gu',
    '### What the integration does',
    '### Functions and parameters',
    '### Fixed-threshold example',
    '### Dynamic-threshold example',
    '## Dice Set',
    '### What the integration does',
    '### Function and parameters',
    '### Registration example',
    '### Automatic detection and EID',
    '## Interfaces that are not public',
    '## Maintainer appendix'
)
$previousHeadingOffset = -1
foreach ($heading in $requiredHeadings) {
    $headingOffset = $normalizedEnglish.IndexOf($heading, $previousHeadingOffset + 1, [System.StringComparison]::Ordinal)
    Require ($headingOffset -ge 0) "COMPATIBILITY.md is missing required heading: $heading"
    Require ($headingOffset -gt $previousHeadingOffset) "COMPATIBILITY.md headings are out of order at: $heading"
    $previousHeadingOffset = $headingOffset
}

$openingLines = @('# Neverbirth compatibility guide', '', '| Neverbirth item | What another mod can add | Status | Entry points |', '| --- | --- | --- | --- |', '| Fortune Rivalling Heaven Gu | Luck thresholds for custom collectibles and trinkets | Provisional and unversioned | `RegisterLuckCap`, `RegisterLuckCapResolver`, `RegisterTrinketLuckCap`, `RegisterTrinketLuckCapResolver` |', '| Dice Set | Custom dice-themed active items | Provisional and unversioned | `RegisterDiceItem` |', '', 'Memory Disorder does not expose a public compatibility API in the published version.')
$openingPattern = '\A' + [regex]::Escape($openingLines[0]) + '\r?\n\r?\n' + [regex]::Escape($openingLines[2]) + '\r?\n' + [regex]::Escape($openingLines[3]) + '\r?\n' + [regex]::Escape($openingLines[4]) + '\r?\n' + [regex]::Escape($openingLines[5]) + '\r?\n\r?\n' + [regex]::Escape($openingLines[7])
Require ([regex]::IsMatch($english, $openingPattern)) 'COMPATIBILITY.md opening integration table is missing or differs from the two released integrations'
Require (([regex]::Matches($normalizedEnglish, [regex]::Escape('| Neverbirth item | What another mod can add | Status | Entry points |'))).Count -eq 1) 'COMPATIBILITY.md must contain exactly one public integration table'

foreach ($sourceAnchor in @(
    'options = options or {}',
    'protectStats = options.protectStats ~= false',
    'if (ownerKind ~= "collectible" and ownerKind ~= "trinket") or itemId <= 0 then',
    'if not fixedCap and type(resolverFn) ~= "function" then',
    'buckets[itemId][#buckets[itemId] + 1] = {',
    'local ok, resolvedCap = pcall(entry.resolverFn, player, itemId, count)',
    'if cap and cap >= 0 then',
    'and (tonumber(player:GetCollectibleNum(Items.FortuneRivallingHeavenGu)) or 0) > 0',
    'player.Luck = math.max(tonumber(player.Luck) or 0, self:GetFortuneRivallingHeavenGuRequiredLuck(player))'
)) {
    RequireContains $main $sourceAnchor 'main.lua source anchor'
}

foreach ($sourceBackedGuideRule in @(
    'The effect applies only while the player has Fortune Rivalling Heaven Gu and owns the matching registered owner collectible or trinket.',
    'Luck registration returns `true` for a positive runtime ID with a numeric fixed threshold or function resolver. Negative thresholds may register but are ignored during evaluation, so callers must not use them.',
    'Resolver calls are protected; errors, non-numeric results, and negative results are ignored. Multiple applicable entries use the highest threshold, and Neverbirth never lowers higher existing Luck.',
    'Duplicate Luck registrations create duplicate resolver calls. Callers must make registration idempotent.',
    '`itemId` is a positive runtime collectible ID. `options` must be a table or `nil`.',
    'Only `protectStats = false` disables stat protection for that die.',
    '`RegisterDiceItem` returns `true` for a valid positive ID and `false` for an invalid ID. Re-registering an ID replaces its options.',
    'The caller must ensure the ID belongs to an active item.',
    'EID is optional and does not control core registration or Dice Set behavior.',
    'Memory Disorder does not expose a public compatibility API in the published version.',
    'This list is not a versioned public contract; do not integrate against these surfaces.',
    'They verify the released source contracts, but they do not prove in-game load order, third-party-mod interaction, gameplay balance, or visual behavior.'
)) {
    RequireContains $english $sourceBackedGuideRule 'COMPATIBILITY.md source-backed rule'
}

$dynamicHeading = '### Dynamic-threshold example'
$dynamicHeadingOffset = $english.IndexOf($dynamicHeading, [System.StringComparison]::Ordinal)
Require ($dynamicHeadingOffset -ge 0) 'COMPATIBILITY.md is missing the dynamic Fortune heading'
$dynamicFenceStart = $english.IndexOf('```lua', $dynamicHeadingOffset + $dynamicHeading.Length, [System.StringComparison]::Ordinal)
Require ($dynamicFenceStart -ge 0) 'COMPATIBILITY.md is missing the dynamic Fortune Lua block'
$dynamicFenceEnd = $english.IndexOf('```', $dynamicFenceStart + 6, [System.StringComparison]::Ordinal)
Require ($dynamicFenceEnd -ge 0) 'COMPATIBILITY.md has an unterminated dynamic Fortune Lua block'
$dynamicFortuneBlock = $english.Substring($dynamicFenceStart, $dynamicFenceEnd - $dynamicFenceStart + 3)

foreach ($dynamicRequirement in @(
    'local fortuneResolverCompatRegistered = false',
    'local function tryRegisterFortuneResolverCompat()',
    'local myLuckyItem = Isaac.GetItemIdByName("My Lucky Item")',
    'neverbirth:RegisterLuckCapResolver(myLuckyItem, function(',
    'MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, tryRegisterFortuneResolverCompat)'
)) {
    RequireContains $dynamicFortuneBlock $dynamicRequirement 'dynamic Fortune Lua block'
}

Require ([regex]::IsMatch($dynamicFortuneBlock, 'if type\(myLuckyItem\) ~= "number" or myLuckyItem <= 0 then\r?\n\s+return false')) 'dynamic Fortune Lua block must return false for a missing or non-positive runtime ID'
Require ([regex]::IsMatch($dynamicFortuneBlock, '(?m)^tryRegisterFortuneResolverCompat\(\)\r?$')) 'dynamic Fortune Lua block must attempt registration immediately'


foreach ($signature in @(
    'function Neverbirth:RegisterLuckCap(',
    'function Neverbirth:RegisterLuckCapResolver(',
    'function Neverbirth:RegisterTrinketLuckCap(',
    'function Neverbirth:RegisterTrinketLuckCapResolver(',
    'function Neverbirth:RegisterDiceItem('
)) {
    RequireContains $main $signature 'main.lua'
}

foreach ($required in @(
    '# Neverbirth compatibility guide',
    'Fortune Rivalling Heaven Gu',
    'Dice Set',
    'not necessarily 100%',
    'active item',
    'dice-themed active item',
    'collected, held, or used',
    '`options` must be a table or `nil`',
    'Provisional and unversioned',
    'Memory Disorder does not expose a public compatibility API in the published version.',
    '[`main.lua`](main.lua)',
    '[`tests/condom_utility_knife_behavior_test.lua`](tests/condom_utility_knife_behavior_test.lua)',
    '[`tests/dice_set_behavior_test.lua`](tests/dice_set_behavior_test.lua)'
)) {
    RequireContains $english $required 'COMPATIBILITY.md'
}

foreach ($forbidden in @(
    'RegisterMod(',
    'seen or used',
    'MemoryDisorderCharacterProfiles',
    'memory_disorder.lua',
    'memory_disorder_behavior_test.lua',
    'public compatibility version'
)) {
    RequireNotContains $english $forbidden 'COMPATIBILITY.md'
}

CheckRelativeLinks $englishPath $english
Write-Host 'compatibility docs tests passed'
