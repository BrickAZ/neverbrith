# RingoTsuga Atlas Geometry Repair Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the oversized, cross-cell RingoTsuga preview conversion with a native-scale 512×512 full-skin atlas whose alpha geometry exactly matches vanilla Isaac while retaining the approved apple identity.

**Architecture:** Keep the existing null-costume ANM2, XML registration, StyleRegistry entry, and runtime behavior unchanged. Build the PNG from the official `Character_001_Isaac.png` alpha mask and the existing player ANM2 layer crop rectangles; recolor head, body, and extra regions inside that immutable geometry. Strengthen the visual regression test with the vanilla alpha SHA-256 and identity-palette checks.

**Tech Stack:** PowerShell 7, System.Drawing, System.Xml, SHA-256, Lua 5.4.6, neverbrith validators.

## Global Constraints

- Output is the in-run full skin only; all portrait, name, select, co-op, death, and HUD surfaces remain unchanged.
- Output path stays `resources/gfx/characters/costumes/costume_ringotsuga_apple_storyteller.png`.
- Canvas remains 512×512 with an 8×8 grid of 64×64 source cells.
- Output alpha bytes must hash to `DF60C2F004A7636085E9356B86CAFD329CC4EC688DFC00331943084315129D1C`.
- Approved identity is red apple head, brown stem, green leaf, cyan eyes, and dark navy hoodie.
- Do not modify vanilla files, the existing ANM2, `content/costumes2.xml`, `main.lua`, or other project work.
- Static and Lua proof must be reported separately from required in-game visual proof.

---

### Task 1: Lock native geometry in the visual regression test

**Files:**
- Modify: `tests/everchanging_atlas_visual_test.ps1`
- Test: `tests/everchanging_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: the installed 512×512 RingoTsuga PNG.
- Produces: a geometry contract based on SHA-256 of all 262,144 alpha bytes.

- [ ] **Step 1: Add `Get-AlphaHash` and the expected vanilla hash**

```powershell
function Get-AlphaHash([System.Drawing.Bitmap]$Bitmap) {
    $bytes = [byte[]]::new($Bitmap.Width * $Bitmap.Height)
    $index = 0
    for ($y = 0; $y -lt $Bitmap.Height; $y++) {
        for ($x = 0; $x -lt $Bitmap.Width; $x++) {
            $bytes[$index] = $Bitmap.GetPixel($x, $y).A
            $index++
        }
    }
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try { return [Convert]::ToHexString($sha.ComputeHash($bytes)) }
    finally { $sha.Dispose() }
}

$expectedAlphaHash = 'DF60C2F004A7636085E9356B86CAFD329CC4EC688DFC00331943084315129D1C'
$actualAlphaHash = Get-AlphaHash $atlas
if ($actualAlphaHash -ne $expectedAlphaHash) {
    throw "RingoTsuga atlas alpha geometry drifted: expected $expectedAlphaHash, got $actualAlphaHash."
}
```

- [ ] **Step 2: Run the test and verify RED**

Run:

```powershell
& 'C:\Program Files (x86)\PowerShell\7\pwsh.exe' -ExecutionPolicy Bypass -File tests\everchanging_atlas_visual_test.ps1 -Root .
```

Expected: FAIL with current alpha `6C22B405C41914E09C9FB8982233D9B30E682000D4F9281BF73040E2B6383CEE`.

### Task 2: Repaint inside the official geometry

**Files:**
- Modify: `resources/gfx/characters/costumes/costume_ringotsuga_apple_storyteller.png`
- Reference only: `E:\Isaac - Repentance\resources\gfx\characters\costumes\Character_001_Isaac.png`
- Reference only: `resources/gfx/characters/costume_ringotsuga_apple_storyteller.anm2`

**Interfaces:**
- Consumes: vanilla RGBA pixels and ANM2 `LayerAnimation/Frame` crop rectangles.
- Produces: one 512×512 RGBA PNG with source alpha unchanged.

- [ ] **Step 1: Build layer masks from ANM2**

Use `XCrop`, `YCrop`, `Width`, and `Height` for layer `body` (3,439 visible source pixels), `head` (7,089), and `extra` (13,363). Never use the 1254×1254 concept image as an alpha source.

- [ ] **Step 2: Recolor only opaque vanilla pixels**

```text
outline -> near-black brown
head base/highlight/shadow -> apple red palette
head white features -> cyan eyes
body base/highlight/shadow -> dark navy hoodie palette
extra upper half of each 64px cell -> apple palette
extra lower half of each 64px cell -> navy palette
unclassified visible pixels -> apple palette
```

For each occupied head cell, recolor a small set of existing topmost opaque pixels to brown stem and green leaf; do not add alpha outside the source silhouette.

- [ ] **Step 3: Save only after candidate checks pass**

Require 512×512, exact expected alpha hash, near-white pixels no more than 3,000, green at least 40, cyan at least 80, navy at least 1,200, and red no more than 10,000 before overwriting the mod-owned PNG.

- [ ] **Step 4: Run the visual test and verify GREEN**

Expected: `RingoTsuga atlas visual test passed` and the exact vanilla alpha hash.

### Task 3: Regression validation

**Files:**
- Test: `tests/everchanging_behavior_test.lua`
- Test: `tests/everchanging_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: repaired PNG and unchanged costume registration.
- Produces: static confidence without claiming game-render proof.

- [ ] **Step 1: Run Lua behavior tests**

```powershell
& 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' tests\everchanging_behavior_test.lua
```

Expected: localization tests and Everchanging behavior tests pass.

- [ ] **Step 2: Run both validators**

```powershell
& 'C:\Program Files (x86)\PowerShell\7\pwsh.exe' -ExecutionPolicy Bypass -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .
& 'C:\Program Files (x86)\PowerShell\7\pwsh.exe' -ExecutionPolicy Bypass -File docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth
```

Expected: zero failures; report any existing unrelated `players.xml` warnings separately.

- [ ] **Step 3: In-game acceptance**

Verify pickup boundary, front/right/up/back movement, firing, pickup, hurt, and death. Acceptance requires vanilla-scale occupied bounds, no detached strip, no cross-cell bleed, stable pivots, and recognizable apple/hoodie identity.

## Self-Review

- Spec coverage: every repair clause is mapped to Tasks 1–3.
- Placeholder scan: no TBD/TODO or implicit implementation step remains.
- Type consistency: all test and rendering paths match the current mod-owned resources.
- Safety: the dirty worktree is preserved; implementation commits are deferred so unrelated changes cannot be staged accidentally.