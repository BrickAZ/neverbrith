# Neverbirth public compatibility documentation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Promote the approved Neverbirth playable update to the default GitHub branch and publish accurate English and Simplified Chinese guides for its Fortune Rivalling Heaven Gu and Dice Set compatibility hooks.

**Architecture:** Rebase the isolated release branch onto the clean remote playable commit `fcd6a8e`, then add a permanent PowerShell documentation contract test before writing each public surface. Keep the English guide, Chinese guide, README entry points, and source API checks in one release branch; finish with full mod tests, static validation, a fast-forward push to `main`, and live GitHub tree verification.

**Tech Stack:** Markdown, Lua source contracts, PowerShell 7, Git worktrees, Git, GitHub CLI.

## Global constraints

- Public documentation covers only Fortune Rivalling Heaven Gu luck thresholds and Dice Set custom dice active items.
- Memory Disorder is not a public integration in this release. Do not add `memory_disorder.lua`, `tests/memory_disorder_behavior_test.lua`, or `MemoryDisorderCharacterProfiles`.
- Use clean remote commit `fcd6a8e` from `origin/multiple-language-support`; do not copy uncommitted files or later local-only commits from the dirty `multiple-language-support` checkout.
- Promote the complete approved playable update. Do not cherry-pick or rewrite its gameplay changes.
- Keep `COMPATIBILITY.md` and `COMPATIBILITY.zh-CN.md` at the repository root with matching structure and executable Lua examples.
- Examples use the caller's existing `MyMod` object and never call `RegisterMod`.
- Luck thresholds describe the highest possible activation chance, which may be below 100%.
- Dice Set progress means collecting, holding, or using a recognized dice item. Merely seeing a pedestal does not count.
- `RegisterDiceItem` documentation must state that `options` is a table or `nil`, and only `protectStats = false` disables stat protection.
- EID remains optional. Do not change Lua mechanics, EID behavior, XML, resources, or localization XML.
- README links must be repository-relative so they resolve on the default branch.
- Static checks do not count as in-game two-mod verification.

---

### Task 1: Align the isolated release branch with the approved playable update

**Files:**
- Preserve: `docs/superpowers/specs/2026-09-04-neverbirth-public-compatibility-docs-design.md`
- Preserve: `docs/superpowers/plans/2026-09-04-neverbirth-public-compatibility-docs.md`
- Verify: `main.lua:1999-2030`
- Verify: `main.lua:14843-14859`

**Interfaces:**
- Consumes: `origin/main` at or descended from `7350157`; approved playable base `origin/multiple-language-support` at `fcd6a8e`.
- Produces: `codex/compatibility-docs-release` with `fcd6a8e` as an ancestor and both planning commits replayed on top.

- [ ] **Step 1: Fetch the exact remote branch tips**

Run:

```powershell
$git = 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\native\git\cmd\git.exe'
& $git fetch origin main multiple-language-support
& $git rev-parse origin/main
& $git rev-parse origin/multiple-language-support
```

Expected: the playable branch resolves to `fcd6a8e...`. If it moved, inspect the new commits and stop before rebasing until the user confirms the replacement base.

- [ ] **Step 2: Verify that the playable update can fast-forward the current default branch**

Run:

```powershell
& $git merge-base --is-ancestor origin/main origin/multiple-language-support
if ($LASTEXITCODE -ne 0) { throw 'origin/main is not an ancestor of the approved playable branch' }
```

Expected: exit code `0`.

- [ ] **Step 3: Rebase the planning commits onto the playable update**

Run from `E:\Isaac - Repentance\mods\neverbrith\.worktrees\compatibility-docs-release`:

```powershell
& $git rebase --onto origin/multiple-language-support origin/main
```

Expected: the design and implementation-plan commits are replayed without touching the dirty primary checkout.

- [ ] **Step 4: Verify branch ancestry and required source APIs**

Run:

```powershell
& $git merge-base --is-ancestor fcd6a8e HEAD
if ($LASTEXITCODE -ne 0) { throw 'approved playable commit is missing from release history' }

$required = @(
    'function Neverbirth:RegisterLuckCap(',
    'function Neverbirth:RegisterLuckCapResolver(',
    'function Neverbirth:RegisterTrinketLuckCap(',
    'function Neverbirth:RegisterTrinketLuckCapResolver(',
    'function Neverbirth:RegisterDiceItem('
)
$main = Get-Content -Raw -LiteralPath 'main.lua'
foreach ($signature in $required) {
    if (-not $main.Contains($signature)) { throw "Missing public API: $signature" }
}
```

Expected: no output and exit code `0`.

- [ ] **Step 5: Run the playable-update baseline tests**

Run:

```powershell
$failed = @()
$luaTests = Get-ChildItem -LiteralPath 'tests' -Filter '*_test.lua' | Sort-Object Name
foreach ($test in $luaTests) {
    & lua $test.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $test.Name }
}
foreach ($test in @('tests/language_entrypoint_test.ps1', 'tests/switch_items_language_test.ps1')) {
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $test
    if ($LASTEXITCODE -ne 0) { $failed += $test }
}
if ($failed.Count -gt 0) { throw "Baseline failures: $($failed -join ', ')" }
"Lua tests: $($luaTests.Count); PowerShell tests: 2; failures: 0"
```

Expected: `Lua tests: 23; PowerShell tests: 2; failures: 0`.

- [ ] **Step 6: Record the existing static-validator baseline**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'docs/skills/isaac-validators/scripts/validate-neverbrith.ps1' -Root '.'
```

Expected: `Static validation completed with 3 warning(s) and 0 failure(s).` The three existing warnings refer to vanilla Isaac skin, name image, and portrait paths in `content/players.xml`. Any new warning or any failure blocks the release.

### Task 2: Add the English public guide under a permanent source-of-truth test

**Files:**
- Create: `tests/compatibility_docs_test.ps1`
- Create: `COMPATIBILITY.md`
- Verify: `main.lua:1999-2030`
- Verify: `main.lua:14843-14922`
- Verify: `tests/condom_utility_knife_behavior_test.lua`
- Verify: `tests/dice_set_behavior_test.lua`

**Interfaces:**
- Consumes: the five public Lua functions verified in Task 1.
- Produces: an English guide and a reusable `tests/compatibility_docs_test.ps1` entry point that returns exit code `0` only when the guide matches the released source tree.

- [ ] **Step 1: Write the failing English documentation contract test**

Create `tests/compatibility_docs_test.ps1` with this content:

```powershell
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
        Require (Test-Path -LiteralPath $resolved) "broken relative link in $DocumentPath: $target"
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
```

- [ ] **Step 2: Run the contract test and verify the red state**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: FAIL with `COMPATIBILITY.md does not exist`.

- [ ] **Step 3: Write the English guide with the approved section map**

Create `COMPATIBILITY.md` with these headings in this order and capitalization:

```markdown
# Neverbirth compatibility guide
## What another mod can add
## Terms used in this guide
## API status and stability
## Finding Neverbirth and using runtime IDs
### Names and global object
### Runtime IDs, not XML-local IDs
## Load order
## Fortune Rivalling Heaven Gu
### What the integration does
### Functions and parameters
### Fixed-threshold example
### Dynamic-threshold example
## Dice Set
### What the integration does
### Function and parameters
### Registration example
### Automatic detection and EID
## Interfaces that are not public
## Maintainer appendix
```

The opening table must contain exactly the two released integrations:

```markdown
| Neverbirth item | What another mod can add | Status | Entry points |
| --- | --- | --- | --- |
| Fortune Rivalling Heaven Gu | Luck thresholds for custom collectibles and trinkets | Provisional and unversioned | `RegisterLuckCap`, `RegisterLuckCapResolver`, `RegisterTrinketLuckCap`, `RegisterTrinketLuckCapResolver` |
| Dice Set | Custom dice-themed active items | Provisional and unversioned | `RegisterDiceItem` |
```

Immediately after the table, include this exact availability note:

```markdown
Memory Disorder does not expose a public compatibility API in the published version.
```

Define the public terms before using them:

- A Luck threshold is the Luck value where an effect reaches its highest possible activation chance. That chance is not necessarily 100%.
- An active item is a collectible the player activates manually from an active-item slot, such as the D6.
- A dice-themed active item is an active item presented as a die or built around a dice-like effect. It does not mean a die that is currently active.

Use this load-order warning before any example:

```markdown
The examples below assume that your mod already has its own `MyMod` object. Do not call `RegisterMod` again just to add Neverbirth compatibility.
```

Use these executable Lua blocks without adding another `RegisterMod` call:

```lua
local neverbirth = _G and rawget(_G, "Neverbirth")
if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
    return
end
```

```lua
local myItemId = Isaac.GetItemIdByName("My Mod Item")
```

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap)
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn)
Neverbirth:RegisterTrinketLuckCap(trinketId, fixedCap)
Neverbirth:RegisterTrinketLuckCapResolver(trinketId, resolverFn)
```

```lua
local fortuneCompatRegistered = false

local function tryRegisterFortuneCompat()
    if fortuneCompatRegistered then
        return true
    end

    local neverbirth = _G and rawget(_G, "Neverbirth")
    if not neverbirth or type(neverbirth.RegisterLuckCap) ~= "function" then
        return false
    end

    local myLuckyItem = Isaac.GetItemIdByName("My Lucky Item")
    if type(myLuckyItem) ~= "number" or myLuckyItem <= 0 then
        return false
    end

    fortuneCompatRegistered = neverbirth:RegisterLuckCap(myLuckyItem, 10) == true
    return fortuneCompatRegistered
end

tryRegisterFortuneCompat()
MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, tryRegisterFortuneCompat)
```

```lua
fortuneCompatRegistered = neverbirth:RegisterLuckCapResolver(myLuckyItem, function(player, itemId, count)
    if count >= 2 then
        return 8
    end
    return 12
end) == true
```

```lua
Neverbirth:RegisterDiceItem(itemId, options)
```

```lua
local diceCompatRegistered = false

local function tryRegisterDiceCompat()
    if diceCompatRegistered then
        return true
    end

    local neverbirth = _G and rawget(_G, "Neverbirth")
    if not neverbirth or type(neverbirth.RegisterDiceItem) ~= "function" then
        return false
    end

    local myDice = Isaac.GetItemIdByName("My Custom Dice")
    if type(myDice) ~= "number" or myDice <= 0 then
        return false
    end

    diceCompatRegistered = neverbirth:RegisterDiceItem(myDice, {
        name = "My Custom Dice",
        protectStats = true,
    }) == true
    return diceCompatRegistered
end

tryRegisterDiceCompat()
MyMod:AddCallback(ModCallbacks.MC_POST_GAME_STARTED, tryRegisterDiceCompat)
```

Document these exact source-backed rules in plain prose:

- Luck registration returns `true` for a positive runtime ID with a numeric fixed threshold or function resolver. Negative thresholds may register but are ignored during evaluation, so callers must not use them.
- Resolver calls are protected; errors, non-numeric results, and negative results are ignored. Multiple applicable entries use the highest threshold, and Neverbirth never lowers higher existing Luck.
- Duplicate Luck registrations create duplicate resolver calls. Callers must make registration idempotent. Resolver functions run in the Luck cache path and must remain fast, deterministic, and free of side effects.
- Dice Set counts recognized dice items that the player has collected, held, or used. Merely seeing a pedestal does not count.
- `itemId` is a positive runtime collectible ID. `options` must be a table or `nil`. `options.name` is stored but does not change player-facing text. Only `protectStats = false` disables stat protection for that die.
- `RegisterDiceItem` returns `true` for a valid positive ID and `false` for an invalid ID. Re-registering an ID replaces its options. The caller must ensure the ID belongs to an active item.
- Crooked Penny and Glitched Crown remain excluded. There is no unregister API. `refundCharges` is not supported.
- Name-based dice detection is a fallback. Explicit registration is preferred. EID is optional and does not control core registration or Dice Set behavior.

The non-public section must list test APIs, carrier APIs, runtime state, `RegisterPickupBannerText`, `RegisterFortuneLuckEntry`, and any unlisted helper or callback. Do not call this list a versioned public contract.

The maintainer appendix must link only to files present in the release tree:

```markdown
| Integration | Implementation | Main tests |
| --- | --- | --- |
| Fortune Rivalling Heaven Gu | `RegisterLuckCap*` and `RegisterTrinketLuckCap*` in [`main.lua`](main.lua) | [`tests/condom_utility_knife_behavior_test.lua`](tests/condom_utility_knife_behavior_test.lua) |
| Dice Set | Dice Set functions in [`main.lua`](main.lua) | [`tests/dice_set_behavior_test.lua`](tests/dice_set_behavior_test.lua) |
```

- [ ] **Step 4: Run the English documentation contract test and verify green**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: `compatibility docs tests passed`.

- [ ] **Step 5: Commit the English guide and its source contract**

Run:

```powershell
& $git add -- COMPATIBILITY.md tests/compatibility_docs_test.ps1
& $git diff --cached --check
& $git commit -m 'docs: publish English compatibility guide'
```

Expected: one commit containing only `COMPATIBILITY.md` and `tests/compatibility_docs_test.ps1`.

### Task 3: Add the synchronized Simplified Chinese guide

**Files:**
- Modify: `tests/compatibility_docs_test.ps1`
- Modify: `COMPATIBILITY.md:1-3`
- Create: `COMPATIBILITY.zh-CN.md`

**Interfaces:**
- Consumes: the English heading-level sequence and seven executable Lua blocks from Task 2.
- Produces: a Chinese guide with the same heading-level sequence and executable code, plus bidirectional language links.

- [ ] **Step 1: Extend the contract test before creating the Chinese guide**

Add these helpers after `CheckRelativeLinks` in `tests/compatibility_docs_test.ps1`:

```powershell
function GetHeadingLevels([string]$Text) {
    return @([regex]::Matches($Text, '(?m)^(#{1,6})\s+') | ForEach-Object {
        $_.Groups[1].Value.Length
    })
}

function GetExecutableLuaBlocks([string]$Text) {
    return @([regex]::Matches($Text, '(?ms)^```lua\s*\r?\n(.*?)^```\s*$') | ForEach-Object {
        $lines = $_.Groups[1].Value -split '\r?\n' | ForEach-Object {
            ($_ -replace '--.*$', '').TrimEnd()
        } | Where-Object { $_ -ne '' }
        $lines -join "`n"
    })
}
```

Add these assertions before the final success message:

```powershell
$chinesePath = Join-Path $Root 'COMPATIBILITY.zh-CN.md'
Require (Test-Path -LiteralPath $chinesePath) 'COMPATIBILITY.zh-CN.md does not exist'
$chinese = Get-Content -Raw -LiteralPath $chinesePath

RequireContains $english '[简体中文](COMPATIBILITY.zh-CN.md)' 'COMPATIBILITY.md'
RequireContains $chinese '[English](COMPATIBILITY.md)' 'COMPATIBILITY.zh-CN.md'

foreach ($required in @(
    '# Neverbirth 兼容接口指南',
    '鸿运齐天蛊',
    '骰子套装',
    '最高触发概率不一定是 100%',
    '主动道具',
    '骰子类主动道具',
    '拾取、持有或使用',
    '`options` 必须是表或 `nil`',
    '临时公开，尚未版本化',
    '当前公开版本没有为记忆紊乱提供兼容接口。'
)) {
    RequireContains $chinese $required 'COMPATIBILITY.zh-CN.md'
}

foreach ($forbidden in @(
    'RegisterMod(',
    '满概率',
    '兼容表面',
    '目标能力',
    '候选池',
    '见过或使用过',
    'MemoryDisorderCharacterProfiles',
    'memory_disorder.lua',
    'memory_disorder_behavior_test.lua',
    '公共兼容版本'
)) {
    RequireNotContains $chinese $forbidden 'COMPATIBILITY.zh-CN.md'
}

$englishLevels = GetHeadingLevels $english
$chineseLevels = GetHeadingLevels $chinese
Require (($englishLevels -join ',') -eq ($chineseLevels -join ',')) 'English and Chinese heading levels differ'

$englishBlocks = GetExecutableLuaBlocks $english
$chineseBlocks = GetExecutableLuaBlocks $chinese
Require ($englishBlocks.Count -eq $chineseBlocks.Count) 'English and Chinese Lua block counts differ'
for ($index = 0; $index -lt $englishBlocks.Count; $index++) {
    Require ($englishBlocks[$index] -eq $chineseBlocks[$index]) "Lua block $($index + 1) differs between languages"
}

CheckRelativeLinks $chinesePath $chinese
```

- [ ] **Step 2: Run the extended test and verify the red state**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: FAIL with `COMPATIBILITY.zh-CN.md does not exist`.

- [ ] **Step 3: Add bidirectional language links and write the Chinese guide**

Add this line below the English title:

```markdown
[简体中文](COMPATIBILITY.zh-CN.md)
```

Create `COMPATIBILITY.zh-CN.md` with this matching heading-level sequence:

```markdown
# Neverbirth 兼容接口指南
## 其他 Mod 可以接入什么
## 本文术语
## 接口状态与稳定性
## 获取 Neverbirth 与运行时 ID
### 名称与全局对象
### 使用运行时 ID，不要使用 XML 本地 ID
## 加载顺序
## 鸿运齐天蛊
### 这项兼容有什么用
### 函数与参数
### 固定阈值示例
### 动态阈值示例
## 骰子套装
### 这项兼容有什么用
### 函数与参数
### 注册示例
### 自动识别与 EID
## 不公开的接口
## 维护者附录
```

Put this link below the Chinese title:

```markdown
[English](COMPATIBILITY.md)
```

Use this Chinese opening table:

```markdown
| Neverbirth 道具 | 其他 Mod 可以添加什么 | 状态 | 入口 |
| --- | --- | --- | --- |
| 鸿运齐天蛊 | 自定义收藏品和饰品的幸运阈值 | 临时公开，尚未版本化 | `RegisterLuckCap`、`RegisterLuckCapResolver`、`RegisterTrinketLuckCap`、`RegisterTrinketLuckCapResolver` |
| 骰子套装 | 自定义骰子类主动道具 | 临时公开，尚未版本化 | `RegisterDiceItem` |
```

Immediately after the table, include:

```markdown
当前公开版本没有为记忆紊乱提供兼容接口。
```

The Chinese terminology section must state all of the following in ordinary language:

- “幸运阈值”是某项效果达到最高触发概率时所需的幸运值。最高触发概率不一定是 100%。
- “主动道具”是放在主动道具槽里、由玩家按键使用的收藏品，例如 D6。
- “骰子类主动道具”是外观或效果以骰子为主题的主动道具，不是“当前处于激活状态的骰子”。

The Dice Set purpose paragraph must say that it counts recognized dice items the player has `拾取、持有或使用` and that merely seeing a pedestal does not count.

The Chinese guide must contain the same seven executable Lua blocks, in the same order, as the English guide. Translate explanatory prose and Lua comments only; do not translate identifiers, string values, function names, callback names, or executable statements. The test added in Step 1 strips comments and rejects any executable difference.

Translate every English source-backed rule from Task 2 without changing numeric or behavioral meaning. In particular, include the exact sentence `` `options` 必须是表或 `nil` `` and explain that only `protectStats = false` disables protection.

The Chinese maintainer table must link to the same three existing files as the English table: `main.lua`, `tests/condom_utility_knife_behavior_test.lua`, and `tests/dice_set_behavior_test.lua`.

- [ ] **Step 4: Run the bilingual contract test and verify green**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: `compatibility docs tests passed` with equal heading-level sequences and equal executable Lua blocks.

- [ ] **Step 5: Commit the synchronized Chinese guide**

Run:

```powershell
& $git add -- COMPATIBILITY.md COMPATIBILITY.zh-CN.md tests/compatibility_docs_test.ps1
& $git diff --cached --check
& $git commit -m 'docs: add Chinese compatibility guide'
```

Expected: one commit containing the Chinese guide, the English language link, and bilingual test assertions.

### Task 4: Add default-branch discovery links to README

**Files:**
- Modify: `tests/compatibility_docs_test.ps1`
- Modify: `README.md:11-15`

**Interfaces:**
- Consumes: root-level `COMPATIBILITY.md` and `COMPATIBILITY.zh-CN.md` from Tasks 2 and 3.
- Produces: two repository-relative README links that resolve on GitHub's default branch.

- [ ] **Step 1: Add failing README assertions to the documentation contract test**

Add these assertions before the final success message in `tests/compatibility_docs_test.ps1`:

```powershell
$readmePath = Join-Path $Root 'README.md'
$readme = Get-Content -Raw -LiteralPath $readmePath
RequireContains $readme '[English compatibility guide](COMPATIBILITY.md)' 'README.md'
RequireContains $readme '[简体中文兼容指南](COMPATIBILITY.zh-CN.md)' 'README.md'
```

- [ ] **Step 2: Run the test and verify the README red state**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: FAIL with `README.md is missing: [English compatibility guide](COMPATIBILITY.md)`.

- [ ] **Step 3: Add the compatibility guide section after the README About section**

Insert this block after `neverbrith is a local mod project for The Binding of Isaac: Repentance.` and before `## Localization status`:

```markdown
## Compatibility guides

- [English compatibility guide](COMPATIBILITY.md)
- [简体中文兼容指南](COMPATIBILITY.zh-CN.md)
```

Use relative links exactly as shown. Do not link to `codex/compatibility-docs`, `codex/compatibility-docs-release`, a local file path, or a commit-specific URL.

- [ ] **Step 4: Run the documentation contract test and verify green**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: `compatibility docs tests passed`.

- [ ] **Step 5: Commit the README discovery links**

Run:

```powershell
& $git add -- README.md tests/compatibility_docs_test.ps1
& $git diff --cached --check
& $git commit -m 'docs: link compatibility guides from README'
```

Expected: one commit containing only `README.md` and the README assertions in `tests/compatibility_docs_test.ps1`.

### Task 5: Verify and publish the playable update plus documentation to `main`

**Files:**
- Verify: `COMPATIBILITY.md`
- Verify: `COMPATIBILITY.zh-CN.md`
- Verify: `README.md`
- Verify: `tests/compatibility_docs_test.ps1`
- Verify: the complete repository tree inherited from `fcd6a8e`

**Interfaces:**
- Consumes: a clean `codex/compatibility-docs-release` branch containing `fcd6a8e`, the approved spec and plan, the two guides, the test, and README links.
- Produces: GitHub default branch `main` at the exact verified release commit, with the feature branch retained remotely for recovery.

- [ ] **Step 1: Run the permanent documentation contract test**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'tests/compatibility_docs_test.ps1'
```

Expected: `compatibility docs tests passed`.

- [ ] **Step 2: Run all playable-update Lua and PowerShell tests**

Run:

```powershell
$failed = @()
$luaTests = Get-ChildItem -LiteralPath 'tests' -Filter '*_test.lua' | Sort-Object Name
foreach ($test in $luaTests) {
    Write-Output "RUN $($test.Name)"
    & lua $test.FullName
    if ($LASTEXITCODE -ne 0) { $failed += $test.Name }
}
foreach ($test in @('tests/language_entrypoint_test.ps1', 'tests/switch_items_language_test.ps1')) {
    Write-Output "RUN $test"
    & pwsh -NoProfile -ExecutionPolicy Bypass -File $test
    if ($LASTEXITCODE -ne 0) { $failed += $test }
}
if ($failed.Count -gt 0) { throw "Release test failures: $($failed -join ', ')" }
"Lua tests: $($luaTests.Count); PowerShell tests: 2; failures: 0"
```

Expected: `Lua tests: 23; PowerShell tests: 2; failures: 0`.

- [ ] **Step 3: Run the project static validator and compare with the recorded baseline**

Run:

```powershell
pwsh -NoProfile -ExecutionPolicy Bypass -File 'docs/skills/isaac-validators/scripts/validate-neverbrith.ps1' -Root '.'
```

Expected: 0 failures and only the three recorded vanilla Isaac asset warnings. Any extra warning blocks publication until explained or fixed.

- [ ] **Step 4: Audit the exact release diff and repository cleanliness**

Run:

```powershell
& $git diff --check origin/multiple-language-support..HEAD
& $git status --short
& $git diff --name-status origin/multiple-language-support..HEAD
& $git log --oneline --decorate origin/main..HEAD
```

Expected:

- `git diff --check` prints nothing.
- `git status --short` prints nothing.
- The diff beyond `fcd6a8e` contains only the approved spec, implementation plan, two compatibility guides, README, and `tests/compatibility_docs_test.ps1`.
- The history also contains the two pre-existing playable-update commits between the old `main` and `fcd6a8e`; no commits from the dirty local checkout appear.

- [ ] **Step 5: Re-fetch and prove the push is a fast-forward**

Run:

```powershell
& $git fetch origin main multiple-language-support
& $git merge-base --is-ancestor origin/main HEAD
if ($LASTEXITCODE -ne 0) { throw 'Remote main changed incompatibly; do not push' }
& $git merge-base --is-ancestor origin/multiple-language-support HEAD
if ($LASTEXITCODE -ne 0) { throw 'Approved playable update is not an ancestor of the release' }
```

Expected: both ancestry checks exit `0`.

Task 5 ends here. Do not push or remove the worktree until the per-task review and the broad whole-branch review both approve the release.

## Post-review publication

Execute this section only after all task reviews are clean, the broad whole-branch review is clean, and every review finding has been resolved.

- [ ] **Publication step 1: Push the recoverable release branch, then fast-forward the default branch**

Run:

```powershell
& $git push -u origin codex/compatibility-docs-release
if ($LASTEXITCODE -ne 0) { throw 'Feature branch push failed' }
& $git push origin HEAD:main
if ($LASTEXITCODE -ne 0) { throw 'Default branch push failed' }
```

Expected: both pushes succeed without `--force`.

- [ ] **Publication step 2: Verify GitHub's default branch and published tree**

Run:

```powershell
& $git fetch origin main
$localHead = (& $git rev-parse HEAD).Trim()
$remoteMain = (& $git rev-parse origin/main).Trim()
if ($localHead -ne $remoteMain) { throw "Remote main mismatch: $remoteMain" }

$repo = gh api 'repos/BrickAZ/neverbrith' | ConvertFrom-Json
if ($repo.default_branch -ne 'main') { throw "Unexpected default branch: $($repo.default_branch)" }
$tree = gh api ('repos/BrickAZ/neverbrith/git/trees/' + $remoteMain + '?recursive=1') | ConvertFrom-Json
$paths = @($tree.tree | ForEach-Object { $_.path })
foreach ($path in @('README.md', 'COMPATIBILITY.md', 'COMPATIBILITY.zh-CN.md', 'main.lua', 'tests/compatibility_docs_test.ps1')) {
    if ($paths -notcontains $path) { throw "Published path missing: $path" }
}
foreach ($path in @('memory_disorder.lua', 'tests/memory_disorder_behavior_test.lua')) {
    if ($paths -contains $path) { throw "Unapproved Memory Disorder path published: $path" }
}
```

Expected: no exception and `origin/main` equals the locally verified release commit.

- [ ] **Publication step 3: Verify the published README links and API functions from GitHub blobs**

Run:

```powershell
function ReadGitHubText([string]$Path) {
    $result = gh api ("repos/BrickAZ/neverbrith/contents/$Path" + '?ref=main') | ConvertFrom-Json
    [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String(($result.content -replace '\s', '')))
}

$publishedReadme = ReadGitHubText 'README.md'
$publishedMain = ReadGitHubText 'main.lua'
foreach ($link in @('[English compatibility guide](COMPATIBILITY.md)', '[简体中文兼容指南](COMPATIBILITY.zh-CN.md)')) {
    if (-not $publishedReadme.Contains($link)) { throw "Published README link missing: $link" }
}
foreach ($signature in @('RegisterLuckCap', 'RegisterLuckCapResolver', 'RegisterTrinketLuckCap', 'RegisterTrinketLuckCapResolver', 'RegisterDiceItem')) {
    if (-not $publishedMain.Contains($signature)) { throw "Published API missing: $signature" }
}
```

Expected: no exception. This proves that the default branch, README links, documents, and documented API functions are published together.

- [ ] **Publication step 4: Preserve evidence and clean up only the worktree created for this release**

Record the final commit hash and test counts in the completion report. Keep `origin/codex/compatibility-docs-release` and `origin/codex/compatibility-docs` unless the user separately asks to delete them.

After all remote checks pass, run from `E:\Isaac - Repentance\mods\neverbrith`:

```powershell
$target = 'E:\Isaac - Repentance\mods\neverbrith\.worktrees\compatibility-docs-release'
$resolved = (Resolve-Path -LiteralPath $target).Path
if ($resolved -ne $target) { throw 'Unexpected worktree path' }
$worktreeStatus = @(& $git -C $resolved status --short)
if ($LASTEXITCODE -ne 0) { throw 'Cannot inspect release worktree' }
if ($worktreeStatus.Count -gt 0) { throw "Release worktree is not clean: $($worktreeStatus -join ', ')" }
& $git worktree remove $resolved
if ($LASTEXITCODE -ne 0) { throw 'Worktree cleanup failed' }
& $git worktree prune
```

Expected: the release worktree is removed only after the default-branch publication is verified. Do not remove the user's primary checkout or the unrelated `anm2gif-exporter` worktree.
