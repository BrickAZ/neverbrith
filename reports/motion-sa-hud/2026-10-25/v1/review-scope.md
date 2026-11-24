# SA HUD review scope

User request: transplant the original SF6 SA gauge, replace ASCII SA text, animate gain/full flash/spend, preserve meter/OD/combat/pools/quality, verify in a real game without desktop input.

Read-only review only. No agent delegation and no edits. Checkout contains extensive unrelated uncommitted work; do not review the entire git diff. Before snapshots in `before/` identify the authoritative pre-task state. No commit was authorized.

Plan: `docs/superpowers/plans/2026-10-25-motion-sa-hud.md`.
Ledger and rulings: `reports/motion-sa-hud/2026-10-25/v1/progress.md`.

Production scope:

- New `motion_sa_hud.lua`, `generated/motion_sa_hud.lua` and `resources/gfx/UI/MotionSA/v1/*`.
- `motion_combat.lua` integration ONLY: inspect `combat-hud.diff` versus before; core combat unchanged.
- New converter `tools/build-motion-sa-hud.py`, local original GUI decoder `read_native.py`, native layout/UV/provenance in this report. Actual originals are under `work/re_chunk_000/natives/stm/product/gui/`; original .pak remains read-only.
- New unit/resource tests: `tests/motion_sa_hud_test.lua`, `tests/motion_sa_hud_resources_test.py`; combat fixture now injects a mock HUD.
- New diagnostic `diagnostics/motion_sa_hud_acceptance.lua`; runner `tools/test-motion-native.ps1` adds sa_hud probe routing, preserving existing owned process/state restoration.
- `preview.py`/`preview.png` are explicitly offline asset previews, never runtime proof.

Fresh runtime proof: `native/sa-initial-1/result.json`, `game-log.txt`: 24 checks passed, zero failed, actual HP damage charges the meter, full-loop draw path, 720 V9 consumes, interruption refunds, no-HUD suppresses, ownership clears, normal engine exit code0, main/config/save snapshots restored. Log is buffered until normal exit (status COMPLETED_LOG_FLUSHED_ON_EXIT, not a real test timeout).

Review focus: visible fill/counter at 0/30/60/90 and crossings; native crop/alpha/additive order; source60Hz vs Isaac30Hz time; read-only gameplay ownership; multiplayer/pause/repeated renders; cleanup/menu/HUD hiding; actual render assertions do not prove pixel-perfect visual match. Retain source files and report conversion adaptations honestly (procedural native gradients and nine-slice adapted; SF6 renderer itself not transplanted).

Return Critical/Important/Minor with file:line and observable consequence, plus Declined to judge. Judge ordinary expected behavior beyond the written spec. Do not reject due to pre-existing unrelated changes or absence of a commit. Final full LuaAll and delivery docs are still pending on the parent.
