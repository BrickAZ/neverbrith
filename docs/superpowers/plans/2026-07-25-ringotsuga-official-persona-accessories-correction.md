# RingoTsuga Official Persona Accessories Correction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the mistaken full-apple mascot artwork with three deterministic hard-pixel Null Costume atlases that preserve the existing game hookup while matching RingoTsuga's official anthropomorphic persona.

**Architecture:** Keep the existing `head4`, `head2`, and `body0` ANM2 carriers unchanged. Update the visual contract first, then rewrite the PowerShell atlas generator and regenerate the three PNGs plus the composite preview.

**Tech Stack:** PowerShell 7, `System.Drawing`, XML-backed Isaac ANM2 contracts, deterministic RGBA pixel tests.

## Global Constraints

- Do not edit the three Ringo ANM2 files, Costume IDs, priorities, Lua slots, or lifecycle.
- Preserve atlas sizes, crop cells, pivots, direction order, and body foot contact.
- Use only alpha `0` or `255`; transparent pixels must have zero RGB.
- Do not use antialiasing, semitransparency, pure black, gradients, dithering, or detached fringe pixels.
- The new identity must read as orange-red hair, cream side locks, green eyes, large leaf, and a loose grey-white shirt.

---

### Task 1: Replace the mistaken visual contract

**Files:**
- Modify: `tests/ringotsuga_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: the three existing PNG paths and fixed atlas cell maps.
- Produces: assertions for official-persona colors, face opening geometry, green irises, cream side locks, light shirt, green hem, and rejection of the old full-apple face.

- [ ] **Step 1: Update the approved palette and identity assertions**

Replace the mascot palette with the values in the correction design. Assert that front hair cells preserve a wide face opening, front face cells contain skin and green irises, hair cells contain cream side locks, body cells contain light shirt and green hem, and old red face fill is absent.

- [ ] **Step 2: Run the visual test to verify RED**

Run:

```powershell
pwsh -NoProfile -File tests\ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: FAIL because the existing images contain the old apple-shell and red-face palette instead of the official-persona palette.

### Task 2: Redraw the three atlases

**Files:**
- Modify: `tools/generate-ringotsuga-accessory-atlases.ps1`
- Regenerate: `resources/gfx/characters/costumes/costume_ringotsuga_apple_shell.png`
- Regenerate: `resources/gfx/characters/costumes/costume_ringotsuga_face.png`
- Regenerate: `resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png`
- Regenerate: `reports/ringotsuga_accessory_atlases_preview.png`

**Interfaces:**
- Consumes: fixed `32x64` head-hair cells, fixed `32x32` face cells, fixed four-direction body cells, and the correction palette.
- Produces: deterministic RGBA atlases and a nearest-neighbor preview with enlarged and native-size composites.

- [ ] **Step 1: Rewrite the palette and head-hair renderer**

Draw orange-red hair around an open face, cream side locks, a short stem, and a broad green leaf. Draw a solid back-hair view for Up.

- [ ] **Step 2: Rewrite the face renderer**

Draw a skin-colored face, cream sclera, green iris, dark pupil, brows, mouth, and minimal cyan tears. Keep Up face cells transparent.

- [ ] **Step 3: Rewrite the body renderer**

Draw a loose grey-white shirt, skin arms, a dark miniature chest mark, green hem, and dark feet while retaining ten walk phases and mirrored left/right cells.

- [ ] **Step 4: Generate assets**

Run:

```powershell
pwsh -NoProfile -File tools\generate-ringotsuga-accessory-atlases.ps1
```

Expected: four `generated ...` lines for the three atlases and preview.

- [ ] **Step 5: Run the visual test to verify GREEN**

Run:

```powershell
pwsh -NoProfile -File tests\ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: `Ringo accessory atlas visual contract passed`.

### Task 3: Verify integration and presentation

**Files:**
- Test: `tests/ringotsuga_accessory_anm2_visual_test.ps1`
- Review: `reports/ringotsuga_accessory_atlases_preview.png`

**Interfaces:**
- Consumes: regenerated PNGs and untouched ANM2/XML/Lua references.
- Produces: static hookup proof and a native-size visual acceptance decision.

- [ ] **Step 1: Run the ANM2 and integration contract**

Run:

```powershell
pwsh -NoProfile -File tests\ringotsuga_accessory_anm2_visual_test.ps1
```

Expected: `Ringo accessory ANM2 and integration contract passed`.

- [ ] **Step 2: Run project regressions**

Run the neverbrith validator profile and relevant Everchanging behavior tests. Report static pass/fail separately from in-game proof.

- [ ] **Step 3: Inspect enlarged and native-size composites**

Check all four directions for recognizable official-persona features, clean alpha edges, no detached pixels, no apple-helmet reading, and stable body proportions. Reject and iterate if the answer to “If Ringo came to Isaac, would this be them?” is no.
