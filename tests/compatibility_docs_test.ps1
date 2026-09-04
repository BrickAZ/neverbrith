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
