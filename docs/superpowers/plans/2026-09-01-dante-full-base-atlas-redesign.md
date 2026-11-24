# Dante Full Base Atlas Redesign Implementation Plan

> **For Codex:** Execute inline with test-driven development. Preserve the user's dirty worktree and do not commit or push.

**Goal:** Replace the visually invalid 512×512 Dante player atlas with a crop-locked full base-atlas reskin that reads as DMC5 Dante at native 1× while preserving the official player ANM2 coordinate contract.

**Architecture:** Parse the live official `001.000_player.anm2` instead of assuming a uniform grid. Add regression checks for open directional hair, full normal-body coverage, special-state coverage, crop containment and foot contact. Generate only a semantic four-direction pixel-language reference; build the installed atlas deterministically from the official Isaac atlas through a project-owned PowerShell/System.Drawing script.

**Tech Stack:** PowerShell 7 / Windows PowerShell 5.1, System.Drawing, XML, PNG RGBA, existing project evidence renderers.

**Global constraints:** DMC5 standard Dante only; no DMC1–4, anime, reboot/remake, crossover, fan design or other versions; no gameplay mechanics; preserve unrelated worktree changes; no commit/push; native 1× is the visual authority.

---

### Task 1: Freeze the failure as a regression test

**Files:**
- Modify: `tests/dante_character_geometry_test.ps1`
- Test: `tests/dante_character_geometry_test.ps1`

1. Add helpers that derive unique visible sheet-0 crop regions from the live official ANM2 and read decoded RGBA pixels.
2. Add a normal-head gate that requires directional hair color, protected face visibility, open negative-space notches and direction-specific asymmetry.
3. Add per-region body and special-state coverage gates instead of accepting a whole-atlas difference count.
4. Run the geometry test against the existing bad atlas.
5. Confirm it fails specifically on the head-shell/open-hair or incomplete-coverage assertion, not on syntax or missing files.

### Task 2: Build a reproducible full-atlas generator

**Files:**
- Create: `tools/rebuild-dante-full-base-atlas.ps1`
- Generate: `resources/gfx/characters/costumes/character_dante.png`
- Test: `tests/dante_character_geometry_test.ps1`

1. Load the official player atlas and ANM2, validate the 512×512 source and crop manifest.
2. Define a small DMC5-only palette and direction-aware hair/body drawing functions.
3. Rebuild ordinary heads with open, asymmetric silver hair while protecting eyes/mouth.
4. Rebuild all normal-body regions with burgundy outer coat, black inner layer/pants and crop-local coat tails while preserving foot bottoms.
5. Re-encode every visible special/extra region using the same palette and identity rules; preserve intentional transparent placeholders.
6. Save atomically with clean transparent RGB and binary alpha.
7. Run the new regression test; adjust production art only until it passes.

### Task 3: Use image generation as a bounded art-language reference

**Files:**
- Temporary/reference only: Codex-generated candidate outside the installed atlas
- Optional project evidence copy: `reports/dante-character/dante-dmc5-pixel-language-reference.png`

1. Supply the official Isaac pixel template as coordinate/pixel-language reference and the user DMC5 attachment as semantic identity reference.
2. Request four isolated directions with open asymmetric silver hair, burgundy long coat and black inner body; transparent background; no weapons or extra characters.
3. Inspect the returned candidate. Reject any free sprite sheet, closed hair shell, opaque/checkerboard background, non-DMC5 detail or unreadable native scale.
4. Use only accepted shape/color cues; never paste the candidate into the atlas or let it alter crop geometry.

### Task 4: Render and inspect native evidence

**Files:**
- Modify if needed: `tools/render-dante-character-evidence.ps1`
- Modify if needed: `tools/render-dante-template-overlay.ps1`
- Generate: `reports/dante-character/*.png`

1. Re-render the transparent native strip, background composites, 4× nearest-neighbor sheet, special-state contact sheet, surface overview and official overlay.
2. Add a labeled full crop-manifest contact sheet if the existing special sheet does not expose all normal and special regions.
3. Open and inspect the actual PNGs at original resolution.
4. If native 1× still reads as helmet Isaac, a generic anime chibi, or inconsistent states, return to Task 2 rather than weakening the tests.

### Task 5: Run focused and project validation

**Files:**
- Test: `tests/dante_character_geometry_test.ps1`
- Test: `tests/dante_character_contract_test.ps1`
- Test: `tests/cleaver_character_behavior_test.lua`

1. Run both Dante PowerShell tests and the related Lua behavior test.
2. Parse `players.xml` and `CharacterMenu.anm2` and run `luac -p main.lua` without changing gameplay code.
3. Run the current project generic and neverbrith validation scripts; distinguish existing unrelated warnings from Dante failures.
4. Run targeted `git diff --check` on files touched by this repair.

### Task 6: Update evidence ledger and completion boundary

**Files:**
- Modify: `docs/skill-tests/dante-character-source-ledger.md`
- Modify: `reports/dante-character/validation-report.md`

1. Record the new deterministic full-atlas route, accepted/rejected generated candidate role and DMC5-only source boundary.
2. Replace the obsolete 165-pixel provisional claim with fresh measured crop coverage and native evidence results.
3. State `Visual native-1x` from actual inspection only.
4. Keep `In-game technical` separate unless a real game run and credible screenshots are obtained.
5. Keep `User visual approval` pending until the user reviews the repaired evidence.
