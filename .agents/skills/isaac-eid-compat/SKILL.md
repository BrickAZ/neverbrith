---
name: isaac-eid-compat
description: Add, review, or debug optional External Item Descriptions (EID) integration for Binding of Isaac Repentance mods. Use for EID item, trinket, card, pill, character, inline-icon, conditional-description, or language registration. Require discovery of a usable EID global/API first; EID must never be a default mod dependency. 中文触发：EID、道具描述、外置道具描述、EID 图标、EID 兼容、描述注册。
---

# Isaac EID Compatibility

## User Decisions and Technical Discovery

Read the [shared decision and evidence policy](../isaac-mod-context/references/tbd-disclosure.md).

EID is optional presentation integration. Core gameplay, XML localization, and
other description paths must work without it.

## First Move

1. Use `isaac-mod-context` to discover content IDs, real locales, bootstrap,
   existing optional-library guards, and description ownership.
2. Prove the current runtime exposes a usable EID global/API before calling it.
   A folder name, Workshop subscription, or reference-mod example is not proof.
3. Discover the installed API/version when it exists. Prefer the active runtime
   object and installed source for exact signatures; package metadata alone may
   be stale. Do not invent method names, inline-icon fields, or language codes.
4. Keep user-provided text, values, icons, and language choices locked; omitted
   presentation decisions stay `TBD`.

## Hard Rules

- Guard every EID registration. Missing EID means skip registration cleanly.
- Treat EID's own bootstrap, global interception, caches, and internal module
  loading as library implementation details. A content mod must not copy EID's
  internal `RegisterMod` override or mutate EID globals to register descriptions.
- Do not `require` EID, add it as a mandatory dependency, or make gameplay
  depend on description registration succeeding.
- Register only this mod's discovered IDs and languages; do not overwrite
  vanilla or another mod's descriptions without explicit authorization.
- Keep EID text consistent with actual mechanics. Route XML/base localization
  to `isaac-localization-runtime` and optional descriptions to
  `isaac-compat-descriptions`.
- Test both branches: EID absent causes no error; EID present receives only the
  expected registrations, once each.

## Bundled Offline Reference

Read `references/eid-api-contract.md` before choosing an EID registration or
late-load strategy. It records maintainer-documented common calls and their
guard boundaries, but the installed EID build remains authoritative.

For computed descriptions, shared item queries, modifier factories or language
changes, read `references/dynamic-descriptions.md`. Obtain the live gameplay
module through its existing owner; displaying a description must not execute
the item, consume gameplay RNG/pools or reload its registering module.
## Contract Reference

```markdown
## EID Compatibility Contract
- Discovered EID proof/version:
- Core behavior without EID:
- Registered content IDs and languages:
- API calls verified from installed docs/code:
- Duplicate/late-load policy:
- Dynamic query provider / result ownership / invalidation, if applicable:
- Failure/no-EID behavior:
- Tests and in-game checks:
```
