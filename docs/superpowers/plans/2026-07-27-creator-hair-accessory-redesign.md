# Creator Hair Accessory Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the board-like Tantan, Daodao, and Yoontoons hair with reference-scale layered hair accessories.

**Architecture:** Keep the existing Null Costume ownership and registration, but enlarge only the three hair coordinate contracts to eight `64x64` cells. Hair renders on `head1`; existing glasses remain on `head2`. Tests establish the new atlas and crop manifest before the PNG and ANM2 implementation.

**Tech Stack:** PowerShell 7, System.Drawing, Isaac ANM2/XML, Lua contract tests.

## Global Constraints

- Modify only the three creator hair PNGs, their three ANM2 files, the two creator visual tests, and the approved design documents.
- Preserve all unrelated dirty-worktree changes.
- Do not modify glasses, face assets, base player assets, XML ids/priorities, Lua behavior, or gameplay.
- Do not commit from this dirty checkout.

---

### Task 1: Establish the reference-scale failing contracts

**Files:**
- Modify: `tests/creator_accessory_atlas_visual_test.ps1`
- Modify: `tests/creator_accessory_anm2_visual_test.ps1`

**Interfaces:**
- Consumes: three existing hair atlases and ANM2 files.
- Produces: exact `512x64`, `64x64`, `head1`, crop, pivot, alpha, silhouette, face-opening, and frame-variation requirements.

- [ ] **Step 1: Change hair atlas expectations**

Require a `512x64` canvas, `64px` cells, pure-black attached outlines, creator palettes, reference-informed coverage and bounding boxes, side expansion, open face regions, open tip notches, one connected mass, no enclosed holes, and non-identical paired frames. Keep glasses and the transparent Daodao face atlas on their existing `256x32` contracts.

- [ ] **Step 2: Change hair ANM2 expectations**

Require `head1`, `Width=64`, `Height=64`, `XPivot=32`, `YPivot=44`, `YPosition=-5`, and X crops `0,64,128,192,256,320,384,448`. Keep glasses and face layers unchanged.

- [ ] **Step 3: Run tests to verify RED**

```powershell
.\tests\creator_accessory_atlas_visual_test.ps1
.\tests\creator_accessory_anm2_visual_test.ps1
```

Expected: both fail because the current implementation is `256x64`, uses `32px` crops, and renders hair on `head4`.

### Task 2: Draw and connect the three new hair atlases

**Files:**
- Modify: `resources/gfx/characters/costumes/costume_tantan_hair.png`
- Modify: `resources/gfx/characters/costumes/costume_daodao_hair.png`
- Modify: `resources/gfx/characters/costumes/costume_yoontoons_hair.png`
- Modify: `resources/gfx/characters/costume_tantan_hair.anm2`
- Modify: `resources/gfx/characters/costume_daodao_hair.anm2`
- Modify: `resources/gfx/characters/costume_yoontoons_hair.anm2`

**Interfaces:**
- Consumes: the locked creator identities, reference silhouette metrics, animation order, and pivot contract.
- Produces: three hard-alpha `512x64` atlases with independently composed directions and compatible `head1` ANM2 files.

- [ ] **Step 1: Generate candidates from blank canvases**

Build each frame from connected crown, bang, side-lock, and rear-tip masks. Apply one-pixel black outline, four to five flat interior colors, irregular transparent tip notches, and one-pixel frame-pair motion. Do not rescale or reuse the old masks.

- [ ] **Step 2: Update the three ANM2 crop manifests**

Set the layer name to `head1`, every hair frame to `64x64`, `XPivot=32`, and the ordered X crops to multiples of `64`. Preserve animation names, delays, Y pivot, Y position, spritesheet paths, and XML registration.

- [ ] **Step 3: Run focused tests to verify GREEN**

```powershell
.\tests\creator_accessory_atlas_visual_test.ps1
.\tests\creator_accessory_anm2_visual_test.ps1
```

Expected: both creator visual contracts pass.

### Task 3: Produce an Isaac composite and run regressions

**Files:**
- Create outside production: `C:/Users/Anton/.codex/visualizations/2026/07/19/019f7a5e-0f2f-7a80-be4a-3f2362a07e6b/hair-redesign-v2/creator-hair-v2-on-isaac-preview.png`

**Interfaces:**
- Consumes: integrated atlases, ANM2 pivots, and the original Isaac head frames.
- Produces: four-direction nearest-neighbor composites plus static regression evidence.

- [ ] **Step 1: Render the preview**

Place the original Isaac `32x32` head at `(16,16)` inside each `64x64` logical crop, then alpha-composite the matching hair frame according to the shared pivot. Show Tantan, Daodao, and Yoontoons in down, right, up, and left directions.

- [ ] **Step 2: Run regressions**

```powershell
.\tests\creator_accessory_atlas_visual_test.ps1
.\tests\creator_accessory_anm2_visual_test.ps1
.\tests\everchanging_atlas_visual_test.ps1
lua .\tests\everchanging_full_anm2_contract_test.lua
```

Expected: all available static contracts pass.

- [ ] **Step 3: Review scope**

Confirm the intended three PNGs, three ANM2 files, two tests, and two design documents changed. Report unrelated pre-existing changes separately without modifying them, and label in-game verification as still pending.
