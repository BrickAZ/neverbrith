# RingoTsuga Accessory Atlases Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Produce three clean transparent hard-pixel RingoTsuga costume atlases and a review preview without integrating them into Lua, XML, or ANM2.

**Architecture:** A PowerShell/System.Drawing generator owns every visible pixel and emits the three fixed-size RGBA atlases plus a nearest-neighbor checkerboard preview. A separate PowerShell visual-contract test validates dimensions, binary alpha, zero RGB under transparency, palette membership, cell coverage, direction coverage, and head/face separation.

**Tech Stack:** PowerShell 7, `System.Drawing`, PNG RGBA assets, project-local visual contract tests.

## Global Constraints

- Do not modify `main.lua`, `content/costumes2.xml`, existing Ringo full-skin PNG, or existing Ringo full-skin ANM2.
- Apple shell is `256x64`, eight `32x64` cells ordered Down, Right, Up, Left.
- Face is `256x32`, eight `32x32` cells ordered Down, Right, Up, Left; Up cells are transparent.
- Hoodie is `256x256`, forty populated `32x32` cells: Right rows `0/32`, Down `64/96`, Left `128/160`, Up `192/224`.
- Visible alpha is exactly `255`; transparent pixels are exactly RGBA `0,0,0,0`.
- No antialiasing, gradients, dithering, semi-transparent pixels, detached black/red fringe, or cross-cell drawing.

---

### Task 1: Visual contract test

**Files:**
- Create: `tests/ringotsuga_accessory_atlas_visual_test.ps1`

**Interfaces:**
- Consumes: the three exact PNG paths and atlas mapping in the design spec.
- Produces: a failing-then-passing command-line contract for dimensions, alpha, palette, and cell coverage.

- [ ] **Step 1: Write the test before the generator**

The test must fail when any of the three target PNGs is absent, then inspect each atlas per cell rather than accepting a whole-canvas alpha result.

- [ ] **Step 2: Verify the RED state**

Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: non-zero exit with `missing Ringo accessory atlas`.

- [ ] **Step 3: Keep the test independent**

The test must not invoke the generator. It reads the files exactly as the game will read them.

### Task 2: Deterministic atlas generator

**Files:**
- Create: `tools/generate-ringotsuga-accessory-atlases.ps1`
- Create: `resources/gfx/characters/costumes/costume_ringotsuga_apple_shell.png`
- Create: `resources/gfx/characters/costumes/costume_ringotsuga_face.png`
- Create: `resources/gfx/characters/costumes/costume_ringotsuga_hoodie.png`

**Interfaces:**
- Consumes: the approved palette, direction maps, and per-cell hard-pixel shapes.
- Produces: three deterministic PNGs with only alpha `0/255`.

- [ ] **Step 1: Implement shared pixel helpers**

Create only integer-coordinate operations: set pixel, horizontal span, rectangle, cell copy, and cell mirror. Clear every canvas to transparent and normalize transparent RGB to zero before save.

- [ ] **Step 2: Draw the head shell**

Draw full-wrap front and side rings, solid back, brown stem, and green leaf in all eight `32x64` cells.

- [ ] **Step 3: Draw the face**

Draw the red face plane, cyan eyes, dark pupils/upper lids, cyan tear accents, and small mouth in Down/Right/Left; leave Up blank.

- [ ] **Step 4: Draw the hoodie**

Draw ten walking phases for each direction. Preserve a compact body silhouette and keep front-only drawstrings out of the Up frames.

- [ ] **Step 5: Generate PNGs**

Run:

```powershell
pwsh -NoProfile -File tools/generate-ringotsuga-accessory-atlases.ps1
```

Expected: three `generated ...png` lines.

- [ ] **Step 6: Verify GREEN**

Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: `Ringo accessory atlas visual contract passed`.

### Task 3: Review preview and final verification

**Files:**
- Create: `reports/ringotsuga_accessory_atlases_preview.png`

**Interfaces:**
- Consumes: the three passing atlases.
- Produces: one checkerboard contact sheet for human review.

- [ ] **Step 1: Generate the preview from the actual PNGs**

The generator must composite `body -> face -> shell` at the proven pivots and scale only with nearest-neighbor.

- [ ] **Step 2: Run the visual contract again**

Run:

```powershell
pwsh -NoProfile -File tests/ringotsuga_accessory_atlas_visual_test.ps1
```

Expected: `Ringo accessory atlas visual contract passed`.

- [ ] **Step 3: Confirm integration files were untouched**

Run:

```powershell
git diff -- main.lua content/costumes2.xml resources/gfx/characters/costume_ringotsuga_apple_storyteller.anm2 resources/gfx/characters/costumes/costume_ringotsuga_apple_storyteller.png
```

Expected: no new diff caused by this implementation. Existing user changes, if any, remain untouched.

- [ ] **Step 4: Report proof boundaries**

Report static PNG proof separately from in-game proof. The images are not game-loaded until later ANM2/XML/Lua integration.
