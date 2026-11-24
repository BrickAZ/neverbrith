# Dante Separated Hair Redesign Implementation Plan

**Goal:** Replace the failed baked 32×32 normal-head hair with a DMC5-only, hand-shaped Null Costume while preserving the 512×512 base-skin contract and ordinary-Isaac gameplay.

**Architecture:** Keep `character_dante.png` as the 512×512 base skin. Restore its six normal head cells to the official Isaac template and render normal hair through a registered 512×64 `type="none"` costume. A small `dante_character.lua` module resolves the registered player type and costume path, then applies the costume per player on init and game start. Special-state hair remains baked in the base atlas.

**Tech Stack:** Isaac Repentance XML/ANM2/Lua, PowerShell, System.Drawing, project validators.

**Execution boundary:** Do not commit or push. Preserve unrelated dirty-worktree changes.

---

### Task 1: Lock the regression tests

**Files:**
- Create: `tests/dante_character_hair_costume_contract_test.ps1`
- Create: `tests/dante_character_hair_lifecycle_test.lua`
- Modify: `tests/dante_character_full_atlas_visual_test.ps1`
- Modify: `tests/dante_character_contract_test.ps1`
- Modify: `tests/dante_character_native_composite_test.ps1`
- Modify: `tests/dante_character_geometry_test.ps1`

1. Require one Dante costume registration, a 512×64 RGBA sheet, and eight exact 64×64 ANM2 crops.
2. Reject identical left/right frames, dense closed shells, missing face negative space, and insufficient shade/strand separation.
3. Require the six normal base-head cells to match official template pixels instead of containing baked silver hair.
4. Stub Lua APIs and prove per-player new-run/continue/co-op application with no gameplay mutation or hot-loop callback.
5. Run the new tests and retain the expected RED failures before implementation.

### Task 2: Author the hair resource

**Files:**
- Create: `tools/rebuild-dante-separated-hair.ps1`
- Create: `resources/gfx/characters/costumes/costume_dante_hair.png`
- Create: `resources/gfx/characters/costume_dante_hair.anm2`

1. Define each of the eight frames with intentional per-frame silhouettes and strand/shade maps.
2. Use a DMC5 silver-gray ramp whose highlights follow lock direction; do not use procedural modulo texture.
3. Generate the transparent 512×64 sheet deterministically.
4. Inspect raw 1× and 4× frames before integration.

### Task 3: Register and apply the costume

**Files:**
- Modify: `content/costumes2.xml`
- Create: `dante_character.lua`
- Modify: `main.lua`

1. Add one unique project-local costume registration using the existing head-hair priority convention.
2. Resolve `Dante` and the costume by registered names/paths.
3. Apply only to each actual Dante player on player init and game start.
4. Expose a narrow test API without adding SaveData or any combat callback.

### Task 4: Clean the 512×512 normal heads

**Files:**
- Modify: `tools/rebuild-dante-full-base-atlas.ps1`
- Modify: `resources/gfx/characters/costumes/character_dante.png`

1. Replace the six normal-head rebuild calls with exact official-template restoration.
2. Keep normal body and special-state ownership unchanged except for any necessary hair-quality cleanup.
3. Rebuild twice and confirm deterministic hashes.

### Task 5: Render evidence and update the audit

**Files:**
- Create: `tools/render-dante-hair-evidence.ps1`
- Create: `reports/dante-character/dante-hair-costume-contact-sheet.png`
- Modify: `tools/render-dante-full-atlas-contact-sheet.ps1`
- Modify: `reports/dante-character/dante-full-atlas-contact-sheet.png`
- Modify: `reports/dante-character/validation-report.md`
- Modify: `docs/skill-tests/dante-character-source-ledger.md`

1. Render eight raw frames, native 1× composites, and 4× nearest-neighbor views.
2. Record that the old green checks were insufficient and that no outside reference caused the failure.
3. Record Chusheng only as a read-only technical carrier comparison and explicitly state that no pixels/design were copied.
4. Keep in-game and user-approval status honest.

### Task 6: Verify

1. Run the new costume and lifecycle tests.
2. Run all Dante tests and the relevant neverbrith validation profile.
3. Inspect the generated PNGs directly.
4. Run `git diff --check` on touched text files and report scoped status.
5. Report static, native-1×, in-game, and user-approval status separately.

