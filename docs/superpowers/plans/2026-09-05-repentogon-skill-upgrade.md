# REPENTOGON Skill Suite Implementation Plan

> For agentic workers: execute approved work in this task. Skill-creator and
> writing-skills application tests authorize independent research/review agents.

**Goal:** Make REPENTOGON development a first-class, evidence-backed workflow and
install the verified skills for this user's future mods.

**Architecture:** Keep isaac-repentogon-compat as the shared dependency/version
contract. Add focused development, callbacks, content, world, and in-game UI
skills with small entry files and independently sourced references. General Isaac
domain skills retain mechanic ownership. A local personal profile records the
user's explicit future-new-mod REPENTOGON-required preference without imposing
that preference on other users of the public package.

**Tech stack:** Markdown/YAML/JSON skills, Lua 5.3-compatible pure helpers and Lua
5.4 tests, Python read-only static inventory, PowerShell repository checks.

## Constraints

- Authorized: skill changes, new skills, evaluation, local installation and local
  package documentation. No game code/assets/saves/settings changes; no public push.
- Preserve all existing unrelated workspace and installed-skill changes.
- Required dependencies are already authorized for the user's future new mods.
  Existing explicit project targets remain evidence, not silently migrated.
- Pin evidence to official sources and reference tag 1.1.2g, checked 2026-09-05.
  Do not equate that reference tag with a required minimum for every feature.
- Unknown facts trigger discovery; only real user choices trigger questions.
- Native API semantics need game evidence; no static/mock test claims in-game pass.

## Deliverables and checkpoints

- [x] Inspect maintenance repo, instructions, installed parity and prior audit.
- [x] Snapshot old compatibility/router/context/callback skills under the report.
- [x] Run old-skill application scenarios and record misses before authoring.
- [x] Repair compatibility contract and add tested full-release version helper
      plus a read-only symbol/XML inventory with explicit heuristic limitations.
- [x] Add and evaluate isaac-repentogon-dev as the development entry and source map.
- [x] Add and evaluate isaac-repentogon-callbacks for changed/new callbacks and lifecycle.
- [x] Add and evaluate isaac-repentogon-content for XML, stats/cache, nulls and progression.
- [x] Add and evaluate isaac-repentogon-world for Ambush/world/RNG and ownership.
- [x] Add and evaluate isaac-repentogon-ui for ImGui and engine presentation boundaries.
- [x] Update general routing and companion links, READMEs, evidence matrix and manifest.
- [x] Run repository, helper, inventory, skill schema and application evaluations;
      review assertions manually, repair failures, produce a reviewable results artifact.
- [x] Back up exact installed targets, install verified files and local personal
      profile, compare every installed byte/text and report activation requirements.

## Evaluation

Application prompts are in reports/repentogon-skill-upgrade/2026-09-05/scenarios.md.
Compare old and new on six representative cases without web access so the
bundled guidance is tested. Preserve outputs and manual assertion evidence;
report this as a small application evaluation, not statistical or in-game proof.

Pure helper tests cover release suffix ordering, invalid/dev strings, absent and
non-table globals, missing capabilities and no initialization side effects.
Inventory fixtures cover aliases/unguarded direct calls, changed vanilla symbols,
XML registration, known unsafe Ambush suggestions, and comments/string noise;
classify findings as heuristic review candidates, never runtime proof.

Run tests/test-skill-repository.ps1 with the bundled Python and UTF-8 enabled;
run plugin and individual frontmatter validation, all new helper tests, and final
tests/test-installed-skill-parity.ps1. Any pre-existing mismatch must be identified
and preserved, not overwritten merely to make a broad parity check green.
