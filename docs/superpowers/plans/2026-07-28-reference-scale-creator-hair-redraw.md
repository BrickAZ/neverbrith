# Reference-Scale Creator Hair Redraw Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the three oversized creator hair shells with deterministic native-scale hair atlases while preserving the existing Null Costume integration.

**Architecture:** Keep the current `512x64`/`64x64`/`head1` carrier contract. Change the atlas test from edge-filling requirements to reference-envelope limits, then rewrite only the hair portion of the deterministic PowerShell generator to draw one-pixel-native crown, bang, and side-lock masks. Regenerate a vanilla-head composite for visual review.

**Tech Stack:** PowerShell 7, System.Drawing, Isaac ANM2/XML, hard-alpha PNG.

## Global Constraints

- Preserve all unrelated dirty-worktree changes.
- Do not edit the three hair ANM2 files unless verification proves their existing contract drifted.
- Do not change glasses, tissue/face PNGs, XML ids, priorities, Lua behavior, or gameplay.
- Do not commit from this dirty checkout.
- Treat in-game verification as pending until the user tests it.

---

### Task 1: Replace the oversized atlas contract

**Files:**
- Modify: `tests/creator_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: decoded `512x64` RGBA hair PNGs.
- Produces: persona-specific reference bounds, position limits, face-clearance checks, hard-alpha checks, and pair-variation checks.

- [ ] **Step 1: Remove edge-fill assertions**

Delete the requirements for visible pixels in X bands `8..15` and `48..55`.

- [ ] **Step 2: Add reference-envelope limits**

Require Tantan `34..38 x 30..39`, Daodao `34..39 x 30..39`, and Yoontoons
`36..40 x 34..42`; require bounds inside X `12..51`, Y `7..52`.

- [ ] **Step 3: Run the focused test**

```powershell
pwsh -NoProfile -File tests/creator_accessory_atlas_visual_test.ps1 -Root .
```

Expected: FAIL because the current assets measure roughly `44x45`, `47x47`,
and `49x52`.

### Task 2: Redraw the three atlases at native pixel scale

**Files:**
- Modify: `tools/generate-creator-accessory-atlases.ps1`
- Regenerate: `resources/gfx/characters/costumes/costume_tantan_hair.png`
- Regenerate: `resources/gfx/characters/costumes/costume_daodao_hair.png`
- Regenerate: `resources/gfx/characters/costumes/costume_yoontoons_hair.png`

**Interfaces:**
- Consumes: persona row masks and the existing eight-cell direction order.
- Produces: three deterministic hard-alpha `512x64` atlases.

- [ ] **Step 1: Draw directly in `64x64` cells**

Replace the old `32px` mask/upscale route with authored `64px` row masks.
Build each frame from connected crown, tapered bangs, and side locks.

- [ ] **Step 2: Preserve unrelated accessories**

Do not save or rewrite glasses or face/tissue PNGs. Open the existing files
only as preview inputs.

- [ ] **Step 3: Regenerate the hair PNGs**

```powershell
pwsh -NoProfile -File tools/generate-creator-accessory-atlases.ps1 -Root .
```

Expected: only the three hair PNGs and the creator preview are regenerated.

- [ ] **Step 4: Run focused tests**

```powershell
pwsh -NoProfile -File tests/creator_accessory_atlas_visual_test.ps1 -Root .
pwsh -NoProfile -File tests/creator_accessory_anm2_visual_test.ps1 -Root .
```

Expected: PASS.

### Task 3: Review native-scale composites and regressions

**Files:**
- Regenerate: `reports/creator_accessory_atlases_preview.png`
- Create: `C:/Users/Anton/.codex/visualizations/2026/07/19/019f7a5e-0f2f-7a80-be4a-3f2362a07e6b/hair-redesign-v3/creator-hair-reference-scale-preview.png`

**Interfaces:**
- Consumes: original Isaac head crops, current glasses/face PNGs, and the three new hair atlases.
- Produces: front/right/back/left `1x` and `4x` comparisons on checker, white, and room-red backgrounds.

- [ ] **Step 1: Render the composite preview**

Use the existing ANM2 pivot relationship; do not scale the hair independently.

- [ ] **Step 2: Verify deterministic regeneration**

Hash the three hair PNGs, run the generator again, and require identical
SHA-256 hashes.

- [ ] **Step 3: Run regressions**

```powershell
pwsh -NoProfile -File tests/everchanging_atlas_visual_test.ps1 -Root .
pwsh -NoProfile -File tests/creator_accessory_anm2_visual_test.ps1 -Root .
```

Run available Lua contracts only if the local Lua runtime is present.

- [ ] **Step 4: Scope review**

Confirm that production changes are limited to the three hair PNGs, their
generator, the focused atlas test, and the preview. Report in-game validation
as pending.
