# Tokarev Face Accessory Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a clean Tokarev face mask as an independent `head2` Null Costume and apply it together with the existing Tokarev cloak in Everchanging.

**Architecture:** Keep the current `body0 + head4` cloak unchanged. Add a mod-owned `256x32` hard-pixel face sheet and a four-direction ANM2 cloned from the proven coin-mask `head2` contract, register it as Null Costume `17497`, and extend `tokarev_cloak` from one resource to two (`accessory`, `face`). Existing resource resolution, atomic application, and cleanup already support multiple costumes and remain unchanged.

**Tech Stack:** Repentance Lua, `content/costumes2.xml`, ANM2 XML, native RGBA PNG, PowerShell/System.Drawing, Lua and PowerShell tests.

## Global Constraints

- Do not replace the base player skin, base face atlas, vanilla assets, or existing Tokarev cloak files.
- The face is a separate `type="none"` Null Costume on `head2`; the hood remains `head4`.
- Front: near-black navy mask, two broad cyan eye plates, no mouth. Sides: one main eye plus a small far-side hint. Back: fully transparent.
- Visible alpha is exactly `255`; transparent pixels are ARGB zero. No antialiasing, semitransparency, blur, red outline, or dirty transparent RGB.
- The face applies and removes with the cloak but keeps its own asset and Costume ID.
- Preserve all unrelated dirty-worktree changes. Do not commit shared dirty files in this live mod checkout.

## File Map

- Create `tools/generate-tokarev-face-accessory.ps1`: deterministic native-pixel generator.
- Create `resources/gfx/characters/costumes/costume_tokarev_face.png`: final `256x32` RGBA atlas.
- Create `resources/gfx/characters/costume_tokarev_face.anm2`: `head2` four-direction carrier.
- Create `tests/tokarev_face_visual_test.ps1`: alpha, palette, cells, mirroring, and ANM2 checks.
- Modify `tests/everchanging_behavior_test.lua`: asset, registry, resolution, add, and remove assertions.
- Modify `content/costumes2.xml`: register ID `17497`.
- Modify `main.lua`: add the `face` slot/resource only to `tokarev_cloak`.

---

### Task 1: Write failing asset and lifecycle tests

**Files:**
- Create: `tests/tokarev_face_visual_test.ps1`
- Modify: `tests/everchanging_behavior_test.lua:62-140,225-245,340-365`

**Interfaces:**
- Consumes: existing `tokarev_cloak`, `ResolveStyleResources`, and player costume stubs.
- Produces: expectations for path `gfx/characters/costume_tokarev_face.anm2`, ID `17497`, slot order `{ "accessory", "face" }`, and ordered add/remove of IDs `17496`, `17497`.

- [ ] **Step 1: Create the visual-contract test**

The PowerShell test loads the PNG through `System.Drawing.Bitmap`, requires `256x32`, counts visible pixels per `32x32` cell, and enforces:

```powershell
if ($semiTransparent -ne 0) { throw "semi-transparent pixels: $semiTransparent" }
if ($dirtyTransparent -ne 0) { throw "dirty transparent RGB: $dirtyTransparent" }
if ($redDominant -ne 0) { throw "red-dominant pixels: $redDominant" }
foreach ($cell in @(0,1,2,3,6,7)) {
    if ($visibleByCell[$cell] -lt 180) { throw "face cell $cell is too sparse" }
}
if ($visibleByCell[4] -ne 0 -or $visibleByCell[5] -ne 0) {
    throw 'HeadUp cells must be blank'
}
```

It compares cell `0` to `1`, cell `2` to `3`, cell `6` to `7`, and mirrors every pixel in cell `2` against cell `7`. It then requires `Layer Name="head2"`, PNG path `costumes\costume_tokarev_face.png`, and animations `HeadDown`, `HeadRight`, `HeadUp`, `HeadLeft` in the ANM2.

- [ ] **Step 2: Extend the Lua behavior test**

Add these exact registry/resource assertions:

```lua
local tokarevFaceAnm2Path = "gfx/characters/costume_tokarev_face.anm2"
assertEquals(api.StyleRegistry[2].slots[1], "accessory", "Tokarev cloak slot")
assertEquals(api.StyleRegistry[2].slots[2], "face", "Tokarev face slot")
assertEquals(api.StyleRegistry[2].resources.face.costume, tokarevFaceAnm2Path,
    "Tokarev face resource")
local tokarevResources = api.ResolveStyleResources(api.StyleRegistry[2])
assertEquals(#tokarevResources.costumes, 2, "Tokarev resolves two costumes")
assertEquals(tokarevResources.costumes[1].id, 17496, "Tokarev cloak id")
assertEquals(tokarevResources.costumes[2].id, 17497, "Tokarev face id")
```

Add lookup `['gfx/characters/costume_tokarev_face.anm2'] = 17497`. Change the player stub to accept `17495`, `17496`, or `17497`, append IDs to `addedCostumeIds` and `removedCostumeIds`, then assert Tokarev adds `17496` followed by `17497` and clears both when Everchanging is removed.

- [ ] **Step 3: Verify RED**

Run:

```powershell
lua tests/everchanging_behavior_test.lua
pwsh -NoProfile -File tests/tokarev_face_visual_test.ps1
```

Expected: failures specifically report the missing face PNG/ANM2, missing `17497`, or missing `face` resource. Fix test syntax before proceeding; do not weaken the assertions.

---

### Task 2: Build the clean face atlas and `head2` carrier

**Files:**
- Create: `tools/generate-tokarev-face-accessory.ps1`
- Create: `resources/gfx/characters/costumes/costume_tokarev_face.png`
- Create: `resources/gfx/characters/costume_tokarev_face.anm2`
- Test: `tests/tokarev_face_visual_test.ps1`

**Interfaces:**
- Consumes: approved A design and `costume_coin_faced_mask.anm2` coordinate contract.
- Produces: exact project paths consumed by Task 3.

- [ ] **Step 1: Generate one semantic reference with built-in image generation**

Use this preview-only prompt; it is not loaded by the mod:

```text
Use case: stylized-concept
Asset type: Binding of Isaac low-resolution face-accessory reference sheet
Primary request: complete near-black navy inner face mask for a hooded character, two broad cyan drooping eye plates, no mouth; right/left views show one main eye and a tiny far-side hint; back has no face
Style/medium: clean native pixel art, flat opaque colors, hard 1-pixel stair-step edges
Composition/framing: front, right, back, left views separated on a flat solid #ff00ff background
Color palette: near-black navy, two blue-black shades, cyan, small bright-cyan highlights
Constraints: no skin color, no red, no black-red outline, no antialiasing, no semitransparency, no text, no watermark
```

Use it only to check eye mood. The deterministic generator owns final coordinates and alpha.

- [ ] **Step 2: Implement the native-resolution generator**

Create a `256x32` `Format32bppArgb` bitmap and use only opaque pixels from:

```powershell
$Palette = @{
  Edge      = [Drawing.Color]::FromArgb(255,18,18,34)
  Navy      = [Drawing.Color]::FromArgb(255,25,28,51)
  NavyLight = [Drawing.Color]::FromArgb(255,34,39,68)
  Cyan      = [Drawing.Color]::FromArgb(255,48,205,210)
  CyanLight = [Drawing.Color]::FromArgb(255,105,238,232)
}
```

Draw the front silhouette in cells `0` and `1` across rows `y=6..27`, expanding from `x=12..19` to `x=3..28` and contracting symmetrically. Draw left eye spans inside `x=6..14,y=12..17` and right eye spans inside `x=17..25,y=12..17`, with outer ends one row higher. Draw the right-facing face in cells `2` and `3` with its main eye at `x=14..25` and a two-pixel far-eye hint at `x=8..9`. Mirror it exactly into cells `6` and `7`. Leave cells `4` and `5` untouched. Before saving, replace every `alpha=0` pixel with ARGB zero.

- [ ] **Step 3: Clone the proven ANM2 contract**

Copy `costume_coin_faced_mask.anm2` to `costume_tokarev_face.anm2` and change only:

```xml
<Spritesheet Id="0" Path="costumes\costume_tokarev_face.png" />
```

Keep `head2`, all crop rectangles, pivots, delays, Y positions, and animation names identical to the source template.

- [ ] **Step 4: Verify GREEN for the asset**

```powershell
pwsh -NoProfile -File tools/generate-tokarev-face-accessory.ps1
pwsh -NoProfile -File tests/tokarev_face_visual_test.ps1
```

Expected: `Tokarev face visual contract passed`.

---

### Task 3: Register and apply both Tokarev costumes atomically

**Files:**
- Modify: `content/costumes2.xml:32-39`
- Modify: `main.lua:17706-17714`
- Test: `tests/everchanging_behavior_test.lua`

**Interfaces:**
- Consumes: face ANM2/PNG from Task 2.
- Produces: `tokarev_cloak` resolving IDs `17496` and `17497` in that order.

- [ ] **Step 1: Register the face Null Costume**

Insert after ID `17496`:

```xml
<costume id="17497" anm2path="costume_tokarev_face.anm2" type="none" priority="97" />
```

- [ ] **Step 2: Extend only the Tokarev style declaration**

```lua
{
    id = "tokarev_cloak",
    slots = { "accessory", "face" },
    resources = {
        accessory = { costume = "gfx/characters/costume_tokarev_cloak.anm2" },
        face = { costume = "gfx/characters/costume_tokarev_face.anm2" },
    },
    full = false,
    metadata = { source = "tokarev_cloak_with_independent_head2_face" },
},
```

Do not modify the resolver or application/cleanup loops; they already implement ordered all-or-nothing multi-costume behavior.

- [ ] **Step 3: Verify GREEN for behavior**

Run `lua tests/everchanging_behavior_test.lua` and require all assertions to pass, including ordered application and cleanup of both IDs.

---

### Task 4: Regression verification and game handoff

**Files:**
- Test: `tests/everchanging_behavior_test.lua`
- Test: `tests/everchanging_full_anm2_contract_test.lua`
- Test: `tests/tokarev_cloak_candidate_visual_test.ps1`
- Test: `tests/tokarev_face_visual_test.ps1`
- Verify: `main.lua`, `content/costumes2.xml`, face ANM2/PNG.

**Interfaces:**
- Consumes: completed implementation.
- Produces: static evidence and an explicit user in-game checklist.

- [ ] **Step 1: Run focused checks**

```powershell
lua tests/everchanging_behavior_test.lua
lua tests/everchanging_full_anm2_contract_test.lua
pwsh -NoProfile -File tests/tokarev_cloak_candidate_visual_test.ps1
pwsh -NoProfile -File tests/tokarev_face_visual_test.ps1
luac -p main.lua
```

Expected: every command exits `0`; both PowerShell tests print `passed`; `luac -p` has no output.

- [ ] **Step 2: Run discovered generic and neverbrith validators**

Require zero new failures. Report pre-existing warnings separately and never attribute them to the face accessory.

- [ ] **Step 3: Review exact-path diffs only**

Verify only the seven planned paths changed. Confirm no base player atlas, existing cloak asset, or vanilla file changed. Do not stage or commit unrelated dirty files.

- [ ] **Step 4: Hand off in-game checks**

Ask the user to verify: front has a full navy face with two cyan eyes and no pink center; left/right show one main eye and mirror cleanly; back has no eye; hood stays above the face; tears originate sensibly; native item costumes may cover the mask; reroll, room transition, continue, and losing Everchanging neither duplicate nor leave either Costume.
