# RingoTsuga Original Silhouette Rebuild Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the exact-alpha RingoTsuga recolor with a native-scale original apple-character atlas that remains compatible with the existing full-costume ANM2.

**Architecture:** Keep the existing `type="none"` costume registration, runtime selection, and ANM2 carrier. Change only the project-owned atlas and its visual contract: use the ANM2 crop manifest as the hard geometry boundary, while allowing per-frame alpha expansion inside those crops.

**Tech Stack:** Repentance ANM2/XML, transparent 512×512 PNG, PowerShell/System.Drawing validation, Lua behavior tests.

## Global Constraints

- Keep `resources/gfx/characters/costume_ringotsuga_apple_storyteller.anm2`, costume id `17496`, and the `full` style registry unchanged.
- Keep the atlas exactly `512x512` RGBA and preserve the current ANM2 crop coordinates, pivots, animation names, and frame order.
- Allow original alpha geometry only inside valid spritesheet-0 crop rectangles; reject every visible pixel outside their union.
- Preserve the approved identity: red apple head, brown stem, asymmetric green leaf, cyan eyes, dark navy hoodie.
- Do not create portraits, name art, menus, HUD art, or gameplay changes.
- Do not touch unrelated dirty-worktree files.

---

### Task 1: Replace the obsolete alpha-equality test

**Files:**
- Modify: `tests/everchanging_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: `resources/gfx/characters/costume_ringotsuga_apple_storyteller.anm2` and its sheet-0 crop records.
- Produces: a static gate for canvas size, crop containment, original silhouette divergence, palette identity, and nonempty animation coverage.

- [ ] Remove the fixed vanilla alpha hash equality assertion.
- [ ] Parse the ANM2 crop manifest and fail on visible pixels outside all sheet-0 crop rectangles.
- [ ] When the installed vanilla Isaac atlas is available, require a meaningful number of added silhouette pixels.
- [ ] Retain palette and near-white-background checks, adding a brown-stem check.
- [ ] Run the old atlas and confirm the new originality assertion fails before rebuilding the PNG.

### Task 2: Rebuild the complete atlas

**Files:**
- Modify: `resources/gfx/characters/costumes/costume_ringotsuga_apple_storyteller.png`

**Interfaces:**
- Consumes: current RingoTsuga atlas, current costume ANM2 crop records, and the approved design.
- Produces: one 512×512 transparent PNG used unchanged by costume id `17496`.

- [ ] Generate an original pixel-art pass using the current atlas as the edit target and the reference mods only as silhouette-quality references.
- [ ] Keep every sprite in its original crop and native pixel scale.
- [ ] Redraw all visible head states with an apple contour, stem, leaf, inset face, and cyan eyes.
- [ ] Redraw all visible body states with a hood opening, collar, shoulders, sleeves, and dark navy value separation.
- [ ] Reject any result that introduces a background, antialiasing, rescaling, missing states, or crop overflow.
- [ ] Install only the validated transparent PNG at the existing project path.

### Task 3: Static verification and handoff

**Files:**
- Test: `tests/everchanging_atlas_visual_test.ps1`
- Test: `tests/everchanging_behavior_test.lua`

**Interfaces:**
- Consumes: rebuilt atlas and unchanged costume registration/ANM2.
- Produces: static evidence plus an explicit list of remaining in-game checks.

- [ ] Run the atlas visual test and require PASS.
- [ ] Run the Everchanging behavior test and require PASS.
- [ ] Parse `content/costumes2.xml` and the costume ANM2 to confirm id/path/layer continuity.
- [ ] Run `git diff --check` on the touched text files.
- [ ] Report four-direction movement, firing, pickup, hurt, death, item-costume overlap, and non-Isaac body variants as in-game verification still required.
