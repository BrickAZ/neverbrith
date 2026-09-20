param(
    [string]$Root = (Split-Path -Parent $PSScriptRoot),
    [switch]$ReadmeOnly,
    [string]$MemorySourcePath
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

function Require([bool]$Condition, [string]$Message) {
    if (-not $Condition) { throw "compatibility docs test failed: $Message" }
}

function RequireContains([string]$Text, [string]$Needle, [string]$Surface) {
    Require $Text.Contains($Needle) "$Surface is missing: $Needle"
}

function CheckRelativeLinks([string]$DocumentPath, [string]$Text) {
    foreach ($match in [regex]::Matches($Text, '\[[^\]]+\]\(([^)]+)\)')) {
        $target = $match.Groups[1].Value
        if ($target -match '^(https?://|#)') { continue }
        $pathOnly = $target.Split('#')[0]
        if ([string]::IsNullOrWhiteSpace($pathOnly)) { continue }
        $resolved = Join-Path (Split-Path -Parent $DocumentPath) $pathOnly
        Require (Test-Path -LiteralPath $resolved) "broken link in ${DocumentPath}: $target"
    }
}

function ReadDocument([string]$Name) {
    $path = Join-Path $Root $Name
    Require (Test-Path -LiteralPath $path) "$Name does not exist"
    $body = Get-Content -Raw -Encoding utf8 -LiteralPath $path
    CheckRelativeLinks $path $body
    return $body
}

$readme = ReadDocument 'README.md'
$readmeChinese = ReadDocument 'README.zh-CN.md'
RequireContains $readme 'English | [简体中文](README.zh-CN.md)' 'README.md'
RequireContains $readmeChinese '[English](README.md) | 简体中文' 'README.zh-CN.md'
RequireContains $readme '(COMPATIBILITY.md)' 'README.md'
RequireContains $readmeChinese '(COMPATIBILITY.zh-CN.md)' 'README.zh-CN.md'
foreach ($name in @('Fortune Rivalling Heaven Gu', 'Dice Set', 'Memory Disorder')) {
    RequireContains $readme $name 'README.md'
}
foreach ($name in @('鸿运齐天蛊', '骰子套装', '记忆紊乱')) {
    RequireContains $readmeChinese $name 'README.zh-CN.md'
}
Require (-not $readme.Contains('Memory Disorder has no public compatibility API')) 'README has outdated Memory Disorder scope'
Require (-not $readmeChinese.Contains('记忆紊乱没有公开兼容 API')) 'Chinese README has outdated Memory Disorder scope'
if ($ReadmeOnly) {
    Write-Host 'README docs tests passed'
    return
}

$english = ReadDocument 'COMPATIBILITY.md'
$chinese = ReadDocument 'COMPATIBILITY.zh-CN.md'
RequireContains $english '(COMPATIBILITY.zh-CN.md)' 'COMPATIBILITY.md'
RequireContains $chinese '(COMPATIBILITY.md)' 'COMPATIBILITY.zh-CN.md'
$main = Get-Content -Raw -LiteralPath (Join-Path $Root 'main.lua')
foreach ($name in @('RegisterLuckCap', 'RegisterTrinketLuckCap', 'RegisterLuckCapResolver',
    'RegisterTrinketLuckCapResolver', 'InvalidateFortuneLuck', 'RegisterDiceItem')) {
    RequireContains $main "function Neverbirth:$name(" 'main.lua'
    RequireContains $english "Neverbirth:$name(" 'COMPATIBILITY.md'
    RequireContains $chinese "Neverbirth:$name(" 'COMPATIBILITY.zh-CN.md'
}
foreach ($token in @('MemoryDisorderCharacterProfiles', '`id`', '`playerType`', '`isCompatible`',
    '`protectStats`', '`name`', 'CACHE_LUCK', 'Isaac.GetPlayerTypeByName')) {
    RequireContains $english $token 'COMPATIBILITY.md'
    RequireContains $chinese $token 'COMPATIBILITY.zh-CN.md'
}

function LuaBlocks([string]$Text) {
    return @([regex]::Matches($Text, '(?ms)^```lua\s*\r?\n(.*?)^```\s*$') | ForEach-Object {
        $_.Groups[1].Value -replace "`r`n?", "`n"
    })
}

# Compare executable contracts, not prose, headings, or a fixed block count.
$englishBlocks = @(LuaBlocks $english)
$chineseBlocks = @(LuaBlocks $chinese)
Require ($englishBlocks.Count -gt 0) 'no Lua examples found'
Require ($englishBlocks.Count -eq $chineseBlocks.Count) 'bilingual Lua example counts differ'
$lua = (Get-Command lua -CommandType Application -ErrorAction Stop).Source
$tempPrefix = Join-Path ([IO.Path]::GetTempPath()) ('neverbirth-docs-' + [guid]::NewGuid().ToString('N'))
$blockPath = "$tempPrefix-block.lua"
$harnessPath = "$tempPrefix-harness.lua"
try {
    for ($i = 0; $i -lt $englishBlocks.Count; $i++) {
        Require ($englishBlocks[$i] -eq $chineseBlocks[$i]) "Lua example $($i + 1) differs between languages"
        [IO.File]::WriteAllText($blockPath, $englishBlocks[$i], [Text.UTF8Encoding]::new($false))
        & $lua -e 'assert(loadfile(assert(arg[0]), "t")); os.exit(0)' $blockPath
        Require ($LASTEXITCODE -eq 0) "Lua example $($i + 1) has invalid syntax"
    }

    $examples = @($englishBlocks | Where-Object { $_.Contains('local function registerMemoryDisorderCompat()') })
    Require ($examples.Count -eq 1) 'one complete Memory Disorder registration example is required'
    [IO.File]::WriteAllText($blockPath, $examples[0], [Text.UTF8Encoding]::new($false))
    if (-not $MemorySourcePath) { $MemorySourcePath = Join-Path $Root 'memory_disorder.lua' }
    Require (Test-Path -LiteralPath $MemorySourcePath) 'Memory Disorder source is missing'
    $harness = @"
local initialize = assert(loadfile(arg[2]))()
local holder, context = {}, { IsAchievementUnlocked = function() return false end }
local function newMod()
    local mod = {}
    local api = initialize(mod, context)
    return mod, api
end
local function exampleEnvironment(mod, typeId)
    local callbacks = {}
    local env = setmetatable({ Neverbirth = mod, MyMod = {},
        ModCallbacks = { MC_POST_GAME_STARTED = 15 } }, { __index = _G })
    env._G = env
    env.Isaac = { GetPlayerTypeByName = function(name, tainted)
        assert(name == 'My Character' and tainted == false, 'character lookup arguments')
        return typeId
    end }
    function env.MyMod:AddCallback(id, fn)
        assert(id == 15, 'registration retry callback')
        callbacks[#callbacks + 1] = fn
    end
    assert(loadfile(arg[1], 't', env))()
    return env, function() for _, fn in ipairs(callbacks) do fn(env.MyMod, true) end end
end
local function contains(api, id)
    for _, p in ipairs(api.BuildAllCandidates(holder)) do if p.id == id then return true end end
    return false
end
local mod, api = newMod()
local profiles = mod.MemoryDisorderCharacterProfiles
assert(type(profiles) == 'table' and #profiles == 0, 'profiles start empty')
local env, retry = exampleEnvironment(nil, 9001)
assert(#profiles == 0, 'missing Neverbirth skips registration')
env.Neverbirth = mod
retry(); retry()
assert(#profiles == 1 and profiles == mod.MemoryDisorderCharacterProfiles, 'retry appends once without replacing array')
local profile = profiles[1]
assert(profile.id == 'my_mod:my_character' and profile.playerType == 9001, 'registered identity fields')
assert(contains(api, profile.id), 'registered character becomes a candidate')
assert(api.FindProfile(profile.id) == profile, 'stable id supports profile lookup')
profile.isCompatible = function(player, ctx)
    assert(player == holder and ctx == context, 'eligibility callback arguments')
    return true
end
assert(contains(api, profile.id), 'true permits candidate')
profile.isCompatible = function() return false end
assert(not contains(api, profile.id), 'false excludes candidate')
profile.isCompatible = function() return 1 end
assert(not contains(api, profile.id), 'truthy non-boolean excludes candidate')
profile.isCompatible = function() error('test error') end
assert(not contains(api, profile.id), 'callback error excludes candidate')
profile.isCompatible, profile.achievement = nil, 999999
assert(contains(api, profile.id), 'mod achievement does not replace explicit eligibility check')
local badMod = newMod()
exampleEnvironment(badMod, -1)
assert(#badMod.MemoryDisorderCharacterProfiles == 0, 'failed lookup is not registered')
print('Memory Disorder example and candidate contract passed')
"@
    [IO.File]::WriteAllText($harnessPath, $harness, [Text.UTF8Encoding]::new($false))
    & $lua $harnessPath $blockPath $MemorySourcePath
    Require ($LASTEXITCODE -eq 0) 'Memory Disorder example does not satisfy the implemented contract'
}
finally {
    foreach ($path in @($blockPath, $harnessPath)) {
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Force }
    }
}
Write-Host "compatibility docs tests passed ($($englishBlocks.Count) matching Lua blocks per language)"
