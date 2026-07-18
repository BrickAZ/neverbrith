---
name: isaac-testing-debugging
description: Debug and verify Binding of Isaac Repentance `neverbrith` mod changes. Use this whenever the user asks how to test, prove, debug, reproduce, diagnose, or verify an Isaac mod bug or change, including blank cards, items not triggering, callbacks not firing, missing visuals, challenge leakage, state persisting between rooms/runs, failing Lua tests, debug-console checks, or deciding what must be tested in-game versus statically.
---

# Isaac Testing And Debugging

Use this skill when the task is about proof, diagnosis, or verification.

The goal is to stop guessing. Isaac mod work needs a layered verification story: static checks, local behavior tests where possible, targeted logs or debug-console reproduction, then in-game checks for runtime-only surfaces.

## First Move

Before proposing a fix:

1. Classify the symptom using `references/symptom-triage.md`.
2. Decide which checks are static, scripted, or in-game.
3. Run `isaac-validators` for static surfaces when possible.
4. Read the closest existing test under `tests/` before writing new tests.
5. If the issue is stateful, also use `isaac-state-lifecycle`.

## Verification Layers

- **Static validation**: XML parse, missing assets, duplicate ids, language shape. Use `isaac-validators`.
- **Local behavior tests**: Lua or project test files under `tests/`; use these for pure logic, callback helper behavior, state transitions, and localization scripts.
- **Targeted instrumentation**: temporary debug output, debug console steps, or narrow reproduction commands.
- **In-game verification**: visuals, render order, input handling, shader safety, entity collision, pickup behavior, challenge starts, save/reload behavior.

Read `references/verification-layers.md` before planning verification. Read `references/debug-report-template.md` before final reporting.

## Hard Rules

- Do not claim an Isaac runtime behavior is fixed only because code looks right.
- Do not run broad refactors while debugging a specific symptom.
- Do not patch before identifying the most likely failing surface.
- Do not leave temporary debug prints or forced spawn hooks in final code unless the user asked for a debug mode.
- When a test cannot run in the current environment, say exactly what was not run and provide the shortest in-game check.

## Common Debug Routes

- Blank card or abnormal pickup: `isaac-cards-pockets` plus `isaac-validators`.
- Item does not trigger: item id lookup, callback registration, item ownership, active slot, charge/use return.
- Visual missing: `isaac-anm2-visuals`, asset path, animation name, load owner, render/update path.
- Entity not behaving: `isaac-entities`, callback route, type/variant/subtype, `GetData()`, spawn/remove logic.
- Challenge leaking: `isaac-challenges`, `Isaac.GetChallenge()` gate, state lifecycle cleanup.
- State persists or vanishes incorrectly: `isaac-state-lifecycle`, reset/save/reload plan.

## Final Review

Before saying debugging is complete, report:

- Symptom and suspected surface.
- Checks run and outputs summarized.
- Files inspected.
- Fix applied or recommended.
- Tests run.
- Manual in-game checks still required.
