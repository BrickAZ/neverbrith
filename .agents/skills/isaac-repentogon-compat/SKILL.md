---
name: isaac-repentogon-compat
description: "Develop, review, or debug REPENTOGON dependency and capability gates for Isaac mods, required or optional. Use for exact release suffixes, dev builds, changed vanilla APIs, Lua/XML loading boundaries, version conflicts and extension inventories. 中文触发：忏悔龙版本、必需依赖、REPENTOGON 兼容、MeetsVersion、字母补丁、开发构建、能力门禁。"
---

# REPENTOGON Dependency and Capability Contract

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

## First Move

1. Discover mod root, game/build, bootstrap and dependency declarations with
   `isaac-mod-context`. An explicit standing user choice of required REPENTOGON
   is sufficient authorization; do not ask again or invent a vanilla replacement.
   An existing explicitly optional project stays optional.
2. Read `references/repentogon-contract.md`. Record game build, reported
   REPENTOGON release, feature minimum/fixes, signature evidence and runtime
   proof separately. The reference 1.1.2g is not every feature's minimum.
3. Read `references/version-and-bootstrap.md` before copying a gate.
   In reference 1.1.2g, `MeetsVersion` ignores suffixes and accepts dev builds;
   a true result cannot prove a suffix-specific fix.
4. For cross-surface development use `isaac-repentogon-dev`; select its exact
   callbacks/content/world/UI specialist. Do not stop at "look up docs" when
   bundled reference contracts already answer the question.

## Loading and Failure Boundaries

| Mode | Missing, insufficient, unknown build, or missing capability |
| --- | --- |
| Required | Stop this mod's extension initialization before callbacks, menus, shared registry edits or gameplay writes; report a localized dependency/build message. |
| Optional | Keep the proven vanilla core, omit only the enhancement, and do not evaluate unavailable symbols. |
| Undeclared | Discover project declarations and standing user intent; without either, preserve the existing core and do not impose a new requirement. |

A Lua gate cannot prevent engine parsing of already shipped XML/resources.
Inspect packaging and conditional content roots independently. Unsupported
version-specific XML cannot be hidden by a later `if REPENTOGON`.
Gated module loading matters too: top-level enum reads, syntax and side effects
can happen before registration. The pure gate module must need no engine symbols.

## Capability Rules

- Require a usable `REPENTOGON` table, not mere truthiness. Use static dot calls.
- Compare numeric components and documented suffix grammar, not whole strings.
  Include required fixes as well as introduction versions in the minimum.
- Anonymous dev builds need separately verified commit/build evidence; do not
  treat the label as newer than stable or relabel it as a release.
- Read-only probes run lazily after the release check. Never invoke gameplay
  mutations, Ambush, saving or spawning under pcall as an availability test.
- A vanilla callback symbol may exist without REPENTOGON's added arguments or
  return semantics. Presence is not semantic proof.
- Lua 5.4 is the documented extender runtime. Prefer portable syntax even in
  required mods; official guidance discourages gratuitous 5.4-only assumptions.

## Offline Tools

- `scripts/version-gate.lua`: pure release comparison and lazy capability gate.
- `tests/test-version-gate.lua`: suffix/dev/input/side-effect-boundary tests.
- `scripts/surface_inventory.py`: read-only heuristic Lua/XML review candidates.
- `tests/test_surface_inventory.py`: scan scope, masking, XML and path fixtures.
- Read `references/offline-tools.md` for commands and limitations.

The scan is neither a complete API catalog nor a guard verifier. A candidate
inside a valid guard remains a review candidate; zero findings is not an all-clear.

## Verify and Deliver

Cover required absent, old numeric/letter release, unknown/dev, missing
capability and supported branches. Optional mods also prove their vanilla path.
Check lazy module loading, repeated registration, cleanup and XML packaging.
Deliver the actual dependency policy, minimum and reason, exact surfaces,
ready/lifecycle ownership, executed tests and remaining game checks.
Static checks and mocks never establish native game behavior.
