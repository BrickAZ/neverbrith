# Repair ledger — plan: docs/superpowers/plans/2026-10-25-motion-native-player-free-direction.md

User overrides prior rules: separate items should not require a front/back reference; mirrored motion should work. Formal animations must not carry/reanimate Isaac. Supplied screenshot has3SA and No grabbable target; its exact boss state cannot be inferred from pixels alone.

Before current task edits:21 source/test/XML snapshots saved. Host process check found no isaac-ng; no user's live process was touched. No agents, commit, push, UI input or focus APIs.

Observed RED in this session:

- `lua tests/motion_any_direction_test.lua`: exit1 missing independent recognizer. New direction adapter reuses the original core with8 cardinal/roll bases and a single committed serial; tests38 pass for mirror/up/down/shortcuts, held dedupe, opposite next input after neutral, bufferedOD+direction and unchanged0.6s window.
- `lua tests/motion_combat_test.lua`: exit1 at behind-facing close360; removed the direction cone only, then pass. Added full-meter visible-invulnerable negative failed at generic reason, then corrected target-condition feedback; final76 assertions pass.
- `lua tests/motion_presentation_test.lua`: exit1 at formal player renderer still cancelled; formal source copying is now skipped and MC_PRE_PLAYER_RENDER passes through. Tests confirm no player asset loads/draws and unchanged native Hit frame across all four formal moves; explicit rehearsal retains its own preview. Final3523 assertions pass.
- Python resources: new FX-only criterion failed at old runtime layer count. First builder repair exposed inactive player/ghost and opaque preview shell still referring to isaac_vanilla; now both actors and shell/shadow removed from runtime, no actor texture references. Original offline source hashes unchanged; retainedFX tracks identical. Each rerun exit0.

Scope: native player gameplay movement/damage protections retain approved combat behavior; visual animation belongs to engine. 720 cinematic source metadata remains for source timing, but formal layout is anchored to live native actor with no opaque fake scene/player. OD uses SetColor duration2, not a cloned actor. Real grabbed NPC clone remains an actual target, no baked opponent.

Checks before native:

- LuaAll via `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-25/native-player-free-direction-v1/lua-all.json`: exit0,89passed/0failed/0blocked,129 syntax files,82 Lua tests; six old generic native path warnings, strict0warnings.
- New any-direction38; existingOD input18; presentation3523; combat76 assertions pass. Original core and its prior modifiers unchanged; explicit formal DP binding selects adapter.
- `tests/motion_presentation_resources_test.py` exit0; 4 FX-only copies,12 source animations,14900 original visible keys,15 audio events. Source V7/V9, retainedFX tracks preserved.

Native evidence (all runs owned hidden processes, exact save/config snapshots restored,224 original files):

- `-Probe native_player -Attempt free-native-1 -TimeLimitSeconds130`:24cases258passed/5failed; all five failures were OD-gold observation. Actual direction/damage, back-side grabs, native player post-render and native animation continuity passed. Failed run retained as TIMEOUT due buffered logs plus failed checks, not accepted as success.
- `-Attempt gold-trace-1 -TimeLimitSeconds40`: bounded5cases45passed/1failed while tracing. Engine reported Entity.Color.B=1 but live Sprite.Color.B=.43137255; queued same color had priority0/lifespan2 and1. Production gold was already composed into native Sprite. The test erroneously observed base entity tint. Read actual native Sprite color, retaining failure records; no production change to disguise failure.
- Tightened invulnerable negative to require90 remaining explicitly (the old diagnostic's broad OR also allowed0). Unit already asserted preservation.
- Final native `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe native_player -Attempt free-native-final-1 -TimeLimitSeconds110`: exit0,24cases263passed/0failed, normal engine exit0, cleanShutdown/mainRestored/stateRestored true,224 original files snapshotted, no unresolved new files. Log flush on exit explicitly reported as COMPLETED_LOG_FLUSHED_ON_EXIT. Logs prove opposite and up/down damage/facing, back/side360, native POST_PLAYER_RENDER firing,25 distinct native animation/frame states in the animation-continuity case, actual native Sprite OD gold and full-meter invulnerable no-cost rejection.

Post-native verification: `tests/motion_items_resources_test.py`, `tests/motion_sa_hud_resources_test.py`, `tools/build-motion-sa-hud.py --check` all exit0 through cached Python. `pwsh -NoProfile -File tests/motion_native_state_test.ps1` exit0. Current main.lua, both original pure cores and six item/pool XML files remain byte-identical to task-before snapshots; no temporary native include remains. Original V7/V9 source hashes, SA assets and audio unchanged; generated data and4 runtime projections intentionally changed toFX-only. No user-owned process, keys, mouse or focus touched.

Final read-only scope review: matcher bases are per-player instances; candidate commits synchronize neutral gating and serial, pending retains direction/OD, original core/window untouched. Radial selection uses original radius+entity sizes and excludes friendly/invulnerable targets. Native actor rendering is never cancelled for combat; no copied player allocated, actor SetFrame path only for explicit rehearsal. Short-lived SetColor changes no animation/frame; entity base tint is correctly distinguished from native rendered sprite tint. Removed inactive actor/shell refs as well as visible body/head. No unresolved in-scope finding; no commit/push/publication.
