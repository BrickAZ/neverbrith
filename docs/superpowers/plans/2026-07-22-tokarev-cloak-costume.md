# Tokarev Cloak Costume Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce a non-destructive Tokarev cloak candidate on the exact vanilla c216 body/head costume canvases.

**Architecture:** Treat the original c216 PNGs as coordinate and alpha contracts. Generate candidate colors and interior details only inside their visible masks, save sibling candidate files, then validate dimensions, RGBA mode, binary alpha, and alpha equality before making a nearest-neighbor preview.

**Tech Stack:** PNG/RGBA, PowerShell, bundled Python/Pillow, Repentance costume ANM2 contracts.

## Global Constraints

- Do not overwrite vanilla or existing mod assets.
- Do not edit `content/costumes2.xml`, `main.lua`, or the Everchanging registry in this pass.
- Body output is exactly `256x256`; head output is exactly `256x32`.
- Preserve every source c216 alpha value exactly. Body remains binary-alpha; head retains only its source-native `77/153` shadow-alpha pixels and adds no new semitransparency.
- Use a near-black navy exterior, blue-black shadows, and sparse cyan lining; no red fringe.

---

### Task 1: Produce the two candidate costume sheets

**Files:**
- Reference: `E:/Isaac - Repentance/resources/gfx/characters/costumes/costume_216_ceremonialrobes_body.png`
- Reference: `E:/Isaac - Repentance/resources/gfx/characters/costumes/costume_216_ceremonialrobes_head.png`
- Create: `resources/gfx/characters/costumes/costume_tokarev_cloak_body_candidate.png`
- Create: `resources/gfx/characters/costumes/costume_tokarev_cloak_head_candidate.png`

**Interfaces:**
- Consumes: c216 body/head RGBA pixels and Tokarev semantic color reference.
- Produces: two candidate PNGs with source-identical canvas and alpha masks.

- [ ] **Step 1: Generate or derive the Tokarev navy/cyan pixel treatment using the two c216 sheets as edit targets.**
- [ ] **Step 2: Quantize visible pixels to a compact hard-edged palette and restore the exact source alpha channel.**
- [ ] **Step 3: Save the results only under the two candidate filenames.**

### Task 2: Validate and render an enlarged review sheet

**Files:**
- Test: `tests/tokarev_cloak_candidate_visual_test.ps1`
- Create: `reports/tokarev_cloak_candidate_preview.png`

**Interfaces:**
- Consumes: the two candidate PNGs from Task 1.
- Produces: pass/fail output and a nearest-neighbor review image.

- [ ] **Step 1: Assert body/head dimensions are `256x256` and `256x32`.**
- [ ] **Step 2: Assert every candidate alpha equals the corresponding c216 source alpha; body remains `0/255`, while head preserves only its existing `0/77/153/255` values.**
- [ ] **Step 3: Assert no visible pixel falls outside the source mask and no visible red-dominant fringe color exists.**
- [ ] **Step 4: Render both sheets at integer nearest-neighbor scale into `reports/tokarev_cloak_candidate_preview.png`.**
- [ ] **Step 5: Run the validation script and require a passing result before presenting the preview.**
