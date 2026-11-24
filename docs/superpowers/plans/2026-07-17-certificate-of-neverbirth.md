# Certificate of Neverbirth Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a reusable zero-charge developer active item that displays every neverbrith collectible in a dedicated, safely returnable gallery.

**Architecture:** Generate the ownership registry from `content/items.xml`, resolve and cache runtime IDs, and drive a token-owned room session through item-use, room-entry, pickup-collision, update, and game-start callbacks. Persist only plain session data through the existing shared save-data structure.

**Tech Stack:** Repentance Lua API, XML item/localization files, PowerShell registry generation, Lua behavior tests.

## Global Constraints

- Ordinary Repentance only; no Repentance+, REPENTOGON, EID, or StageAPI dependency.
- No handwritten collectible whitelist or blacklist.
- The certificate itself and every registered hidden/debug collectible must be included.
- No item-pool entry.
- Reusable quality-0 active item with no charge requirement.

---

### Task 1: Registration and generated registry

**Files:**
- Modify: `content/items.xml`
- Modify: `content/items.en_us.xml`
- Modify: `content/items.zh_cn.xml`
- Create: `tools/generate-neverbirth-collectibles.ps1`
- Create: `generated/neverbirth_collectibles.lua`
- Test: `tests/certificate_of_neverbirth_behavior_test.lua`

**Interfaces:**
- Produces: generated rows `{ localId, englishName }`, sorted by `localId`.

- [ ] Add failing assertions for local ID 36, quality 0, zero charges, no pool entries, and complete generated ownership coverage.
- [ ] Run the new test and confirm failure before implementation.
- [ ] Register the item in every item XML and implement the deterministic generator.
- [ ] Generate the Lua registry and rerun registration tests.

### Task 2: Runtime registry and gallery session

**Files:**
- Modify: `main.lua`
- Test: `tests/certificate_of_neverbirth_behavior_test.lua`

**Interfaces:**
- Consumes: `include("generated.neverbirth_collectibles")` rows.
- Produces: `Neverbirth.CertificateOfNeverbirthTestAPI` helpers for registry validation, position capacity, session creation, pickup tracking, and return cleanup.

- [ ] Add failing callback/state tests with Isaac API stubs.
- [ ] Implement item lookup, EID/banner text, registry cache, session state, dedicated-room transition, owned pedestal spawning, pickup tracking, pressure-plate return, and save/load integration.
- [ ] Verify all callbacks return `nil` except the filtered `MC_USE_ITEM` result.
- [ ] Run the focused behavior test until green.

### Task 3: Integration validation

**Files:**
- Modify: `tests/localization_test.lua`
- Modify only if required: `tools/validate_mystuff_local_ids.ps1`

**Interfaces:**
- Produces: static evidence for XML parity, pool absence, complete scan, capacity failure reporting, and callback registration.

- [ ] Update localization counts/contracts for the new item.
- [ ] Run `luac -p main.lua` and all focused Lua tests.
- [ ] Parse every `content/*.xml` file.
- [ ] Run project validators and `git diff --check`.
- [ ] Report static results separately from remaining in-game transition/pressure-plate checks.

