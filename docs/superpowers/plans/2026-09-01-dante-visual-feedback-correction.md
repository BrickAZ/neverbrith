# Dante Visual Feedback Correction Implementation Plan

> **For agentic workers:** Execute inline in the current `neverbrith` checkout. The user explicitly requested the correction in this checkout; do not create a worktree, delegate to a subagent, commit, push, or touch unrelated dirty files.

**Goal:** Correct the verified Dante visual feedback while preserving the registered character, the official player coordinate contract, and the Devil May Cry 5-only source boundary.

**Architecture:** Treat the player atlas as an original full skin, not a pure recolor. Generated raster outputs are visual candidates only; final assets must be reconstructed on their discovered native surfaces and rejected unless exact canvas/crop/alpha checks pass. Keep deterministic technical gates separate from native-1x visual review.

**Tech Stack:** PowerShell 7, `System.Drawing`, Isaac XML/ANM2 assets, project-local PowerShell tests, built-in image generation for portrait candidates.

## Global Constraints

- Use only the user attachment and verifiable official Devil May Cry 5 material for Dante semantics.
- Never use Devil May Cry 1-4, anime, remake/reboot, crossover, fan art, AI redesign references, reference mods, or other work/version designs.
- Do not add guns, sword attacks, weapon switching, projectiles, damage, items, stats, unlocks, or other gameplay.
- Preserve the official `001.000_player.anm2` crop order, pivots, facing, foot contact, and frame coverage.
- Do not scale a generated master image into unrelated native surfaces.
- Preserve unrelated working-tree changes and do not commit or push.

---

### Task 1: Make the verified name and full-skin regressions fail

**Files:**
- Modify: `tests/dante_character_contract_test.ps1`
- Modify: `tests/dante_character_geometry_test.ps1`

**Interfaces:**
- Consumes: current Dante PNGs and official Isaac player/name templates.
- Produces: hard gates for the 192x64 name palette/alpha contract and controlled non-head silhouette changes.

- [ ] Add a name assertion requiring visible RGB `#C7B299`, visible alpha values limited to `128` and `255`, at least one `128` edge pixel, and no dark outline color.
- [ ] Replace full-source-alpha equality with exact equality outside the discovered crop union.
- [ ] Require controlled alpha differences in representative normal body cells while preserving bottom foot-contact rows.
- [ ] Run both tests and confirm they fail for the intended current defects: outlined hard-alpha name and zero body-silhouette change.

### Task 2: Correct the 192x64 player name and original-full-skin body silhouette

**Files:**
- Modify: `resources/gfx/UI/boss/playername_dante.png`
- Modify: `resources/gfx/characters/costumes/character_dante.png`
- Create: `tools/rebuild-dante-visual-feedback.ps1`

**Interfaces:**
- Consumes: current Dante assets, official Isaac template, and the Task 1 gates.
- Produces: reproducible native-size PNG correction with no whole-image rescale.

- [ ] Rebuild the boss name from its current glyph mask: remove the dark outline, set all visible RGB to `#C7B299`, keep opaque interiors, and use alpha `128` only for attached corner/edge coverage.
- [ ] Expand the coat silhouette inside representative normal body crop owners, keep the red coat separated from black clothing and deepest outline, and preserve each crop's bottom contact row.
- [ ] Keep all new pixels inside the official crop union; do not alter unused atlas slots.
- [ ] Run both focused tests and confirm green.

### Task 3: Correct portrait proportions, eyes, and half-open mouth

**Files:**
- Modify: `resources/gfx/UI/stage/playerportrait_dante.png`
- Modify: `content/gfx/dante_character_menu_portrait.png`

**Interfaces:**
- Consumes: official Isaac portrait/menu baselines, current Dante portraits as edit targets, and the user-approved DMC5 attachment as semantic reference.
- Produces: independent native 144x144 and 96x96 portraits; neither is a resize of the other.

- [ ] Generate one corrected candidate per portrait with a larger Isaac-like head-to-shoulder ratio, bold readable eye clusters, and a clearly half-open mouth.
- [ ] Preserve DMC5 silver medium hair, deep-red coat, black inner clothing, mature calm identity, transparent background, and the existing surface-specific sword-hilt allowance.
- [ ] Reject generated canvas dimensions as final authority; reconstruct each selected candidate onto its own exact native canvas.
- [ ] Inspect raw alpha and reject baked checkerboards, background plates, halos, watermarks, or forbidden-version features.

### Task 4: Update evidence and process documentation

**Files:**
- Modify: `docs/skill-tests/dante-character-source-ledger.md`
- Modify: `tools/render-dante-character-evidence.ps1` only if a new evidence panel is required.
- Regenerate: `reports/dante-character/*.png`

**Interfaces:**
- Consumes: final native assets.
- Produces: raw, overlay, native-1x, 4x nearest-neighbor, background, and cross-surface evidence.

- [ ] Record that built-in image-generation canvases are candidates, not directly usable native outputs.
- [ ] Record the verified Isaac face/name corrections and the original-full-skin alpha rule.
- [ ] Regenerate all evidence from final workspace PNGs.
- [ ] Review native 1x before using the 4x view for pixel defects.

### Task 5: Fresh verification and status handoff

**Files:**
- Verify all files touched above; no additional implementation surfaces.

**Interfaces:**
- Consumes: corrected assets, tests, and evidence.
- Produces: separate technical, visual, in-game, and user-approval statuses.

- [ ] Run `tests/dante_character_contract_test.ps1`.
- [ ] Run `tests/dante_character_geometry_test.ps1`.
- [ ] Run the discovered general and neverbrith validator profiles.
- [ ] Run `git diff --check` only on the current checkout and inspect the scoped Dante diff/status without cleaning unrelated changes.
- [ ] Report exact generated-image prompts/candidate use, final saved paths, commands, results, remaining in-game checks, and pending user visual approval.

