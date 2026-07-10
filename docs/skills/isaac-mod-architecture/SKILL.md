---
name: isaac-mod-architecture
description: Plan, review, or implement architecture-safe organization for the Binding of Isaac Repentance `neverbrith` mod. Use this whenever work risks making main.lua too large, duplicating callback logic, adding many items/entities/cards at once, creating shared helpers, moving code into modules, changing load order, creating registries, or deciding where constants, state tables, tests, validators, and content files should live. This skill protects project structure while preserving existing conventions.
---

# Isaac Mod Architecture

Use this skill when the task touches module organization, load order, shared helpers, or repeated patterns across multiple Isaac content types.

The goal is not to redesign the mod for its own sake. The goal is to keep future item/entity/card/challenge work easy to route, test, and debug without breaking current working patterns.

## First Move

Before moving code:

1. Read `main.lua` and identify the current registration/load pattern.
2. Read the closest existing helper or repeated block.
3. Decide whether the task needs architecture work or only a local implementation.
4. If the change is broad, write a short migration plan and keep it reversible.
5. Use `isaac-testing-debugging` and `isaac-validators` after structural changes.

## Route The Architecture Work

- **Module boundaries**: when to split item/card/entity/challenge code and what each module owns. Read `references/module-boundaries.md`.
- **Callback registration**: shared callback helpers, load order, duplicate callback prevention, per-content registration. Read `references/callback-registration.md`.
- **Shared helpers and constants**: id maps, state helpers, RNG helpers, language helpers, asset helpers. Read `references/shared-helpers.md`.
- **Architecture review**: before final answer, read `references/architecture-review-checklist.md`.

## Hard Rules

- Do not refactor unrelated content while implementing one item or card.
- Do not move working code without a verification plan.
- Do not create a new abstraction unless it removes real duplication or matches an existing pattern.
- Preserve existing public names and mod naming quirks unless the user explicitly asks to rename them.
- Keep callback ownership obvious. A future agent should be able to find who registers a callback and why.
- Keep tests close to behavior changes.

## Handoff Prompt Template

```markdown
## Architecture Spec

- Current pattern:
- Pain point:
- Proposed boundary:
- Files to move or create:
- Callback/load order:
- Shared helpers:
- Risks:
- Verification:
- Rollback path:
```

## Final Review

Before saying architecture work is complete, report:

- Structural changes made.
- Why each new file/helper exists.
- Load order and callback ownership.
- Tests and validators run.
- Any intentionally deferred cleanup.
