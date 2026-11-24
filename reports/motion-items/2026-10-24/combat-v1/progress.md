# SDD ledger — plan: docs/superpowers/plans/2026-10-24-motion-combat.md

Spec approved by user: 2026-10-24. Implement all six attacks, V9 720; pools/quality unchanged; background native validation only, no OS input.

Ruling: Work directly in the user's installed mod checkout with allowlisted before snapshots, without commits or a worktree — this dirty main checkout contains the already-confirmed uncommitted assets and must be the actual tested installation. Isolation that omits them would test a different mod; no unrelated files are reset or published.

Pre-flight: input produces owner/facing/serial; existing item binding only plays presentation. Add a separate combat executor, preserve shared input recognition; external combat clock drives presentation so accelerated ordinary attacks do not retain preview timing. Use scoped damage provenance for delayed hits, not unmarked player damage.

Task 1: complete — `lua tests/motion_combat_core_test.lua` RED (missing implementation, exit 1) then GREEN (590 assertions, exit 0).

Task 2/3/4: implemented, final verification in progress. `motion_combat_test.lua` RED (missing executor), GREEN; added deferred-HP RED→GREEN after native evidence. Presentation external-clock RED→GREEN. Existing input, presentation and localization tests currently pass.

Ruling: Register a dedicated effect variant 3026 instead of native EFFECT_NULL — native log proved 1000.0 has no configuration and cannot serve as a projectile. Actor/FX resource remains the approved V7 runtime copy. Existing entity entries and all item metadata preserved.

Ruling: First native cases inadvertently picked up the unrelated starting Ring pedestal, which locks the primary active slot. The diagnostic now removes initial pickups in its own fresh test room before collisions; production Ring behavior is untouched. Earlier failures remain recorded.

Ruling: Native accepted-damage POST and TakeDamage return precede observable HP changes. Queue accepted hits, share one measured HP-loss budget per NPC, settle in a later callback; ignore cancelled hits and cap overkill. Unit tests include deferred HP. Grabbed targets require their original collision class temporarily during the exact damage call, then return to owned no-contact control.

Ruling: Compare native targets using GetPtrHash plus InitSeed, not Lua userdata equality. Separate Entity and EntityNPC wrappers for the same NPC compare differently; native pointer logs confirmed this. Splash exclusion uses this identity to avoid hitting the primary twice.

Task 5: full native verification in progress; first/second/third/trace attempt logs preserved, no desktop input.

Task 2/3/4: complete — world test61, presentation3494, input adapter62, localization; all exit0. Native full-1/final-1 confirmed all six HP outcomes and V9 last frame393. Independent review found preparation-position snapback and duplicate target drawing; both RED→GREEN and fixed with grab-time origin plus retained native pointer identity.

Task 6 checks: LuaAll86 selected checks passed,0 failed,6 historical generic-validator warnings (report final-checks.json); resources and preservation tests pass. Initial bootstrap failures were caused by eager wave-registration assertion in unrelated-item fixtures; changed to checked own-wave availability at cast time, no invalid fallback ID. Other modules no longer depend on registration lookup at bootstrap.

Task 5: combat-final-1 completed12 cases,115 checks,0 fail; exit-live-1 completed1 case,12 checks,0 fail, normal native exit0 and release confirmed. Raw recovery flags conservatively failed on new midnight backups; separate recovery/result.json documents exact cleanup. UTC/local DateTime comparison and dated auto-backup discovery have RED→GREEN restore tests. Dated copies only eligible when absent initially, within owned process time and native log explicitly saved that slot. Original223 files restored, unknown new files are never removed.

Final native batch combat-final-2 running against unchanged production Lua, to verify the full combat and updated restore path together.

Task 5: complete — combat-final-2 launcher exit0,12 cases115 passed0failed, native exit0/clean shutdown,223 state files restored,main restored,unknown additions0. Exit-live-1 native12 passed0failed and separate recovery/result.json confirms restored state. No OS input.

Task 6: complete — all86 automated checks and Python registration/presentation preservation checks pass; restore PowerShell tests pass. Independent reviewer confirmed production fixes and recovery fixes; remaining evidence limits are special NPC/Boss phase matrix, complex same-frame multiplayer mitigation attribution and human feel/pixels, not claimed verified.
