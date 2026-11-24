# SDD ledger — plan: docs/superpowers/plans/2026-10-25-motion-sa-hud.md

User approved original SA HUD, accumulation/full/spend animations, no rule/pool changes, native verification without desktop input.

Ruling: installed dirty checkout is the target; preserve unrelated work with before snapshots, no commit/push. Original SF6 source pak is read-only and reachable only through elevated file access; no SF6 executable is started.

Task1: extracted34 SA files plus3 referenced UV files and6 referenced shared textures. Selected only default ui30012 for the game asset; other skins remain research inputs. Native layout and source clips decoded into native-layout.json/native-uv.json.

Ruling: old REtool v0.221 converts DDS with wrong width for TEX241101895; correct exported DDS dimensions from the actual TEX width/height fields, not guessed storage length. BC7 payload remains unchanged. GUI compact-CLIP53 has56-byte properties, not the older template's72; verify all pointers/key bounds. Original asset dimensions and keyframes drive the conversion.

Task2: resource contract test written before builder. Gameplay/economy exact-byte preservation is mandatory.

Task 1: complete — original default GUI/UV/TEX decoded, source60Hz/native keyframes and 43 original hashes recorded. REtool successful extraction reports exit1; output files and texture/UV consistency verified rather than relabeling it as exit0.

Task 2: complete — missing-resource test observed RED before creation; ANM2 conversion 22 animations/638 crop keys and builder --check exit0; source RGBA composited offline on dark backgrounds and inspected, original number/frame silhouettes legible. `preview.py` first failed with a parent-path error (exit1); corrected to the actual workspace root and reran exit0. No production changes arose from that path correction.

Task 3: complete — missing-renderer/temporary-ASCII tests observed RED; HUD connected via combat read-only update/render/reset only. Original core/input/presentation/main and six item/pool XML snapshots match exactly. Initial unit20 assertions exit0.

Task 4: complete (initial native) — `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe sa_hud -Attempt sa-initial-1 -TimeLimitSeconds 40` ran in the host; result24 passed/0failed, native exit0, clean shutdown and state/main restored. Exact log/result retained. Log buffering until normal exit is reported, not disguised as timely live log output.

Task 5: complete (initial checks) — Python resource tests (HUD, presentation and formal items), native source converter --check, native state helper test exit0. `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-sa-hud/2026-10-25/v1/lua-all.json`: exit0,87 checks passed,0 failed,6 historical generic resource warnings; strict0warnings. Source V9/V7 hashes and gameplay-only actor/FX copies remain identical.

Final review: fresh read-only reviewer `sa_hud_final_review` under executing-plans final review instruction; no implementation delegation. Review scope is `review-scope.md` and pre-task `combat-hud.diff`, not the extensive unrelated dirty git diff. Returned one Important (adjacent-frame gains freeze interpolation), one Minor (same-level gains repeat two-times counter pop), no Critical. Full findings retained in `final-review.md`.

Final: Ruling: regrade repeated same-level counter pop as Important — original counter-upgrade animation belongs to a level increase, and sustained damage must leave a legible settled counter; this is part of the requested original SA feedback. Fix together with interpolation in one pass. Cost if wrong: fewer decorative pops on ordinary damage; gameplay is unaffected.

Final: fixed continuous interpolation — new adjacent-frame1..89 test first failed at 'must advance fill' (exit1; continuous-gain-red.log); advance the prior tween before retargeting; crossings30/60 and settling29/30 then pass.
Final: fixed repeated counter upgrade — same test next failed at 'must not restart upgrade' (exit1; counter-pop-red.log); independent counterAt only changes on increased level. `lua tests/motion_sa_hud_test.lua` exit0,26 assertions. Native diagnostic also checks steady same-level counter on actual wave damage.

Final: Ruling: SF6 shader/pixel equality set aside by reviewer — transfer original assets/UV/layout/keys and adapt procedural gradients/nine-slice/additive blending to Isaac; no pixel-identical engine claim. Cost if wrong: possible glow-softness difference; preview is explicitly offline, native proof is loading/state/render execution.
Final: Ruling: cooperative visual layout not covered by the single-player native case — private per-player state and left/right rendering tested in unit fixtures, retain manual/co-op picture acceptance boundary. Cost if wrong: real co-op could reveal a layout overlap requiring a later display-only adjustment.
Final: Ruling: unrelated dirty gameplay changes set aside — preserve before snapshots and never stage/reset/commit/publish unrelated work. Cost if wrong: out-of-scope pre-existing defects remain, not silently overwritten.
Final: Ruling: reviewer set final LuaAll/docs aside while pending — parent completes final suite and delivery after the fix, rather than inferring passage from the review. Cost if wrong: no completion until the actual result is inspected.

Final suite: `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-sa-hud/2026-10-25/v1/lua-all-final.json` exit0,87 passed/0 failed/0 blocked,126 parsed Lua files,80 Lua test files. Six pre-existing generic warnings (three locales' deathANM2/Breakfast native paths), strict0warnings. HUD26 assertions passed in that suite. No deferred minor findings remain after severity regrade/fix.

Final native: `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe sa_hud -Attempt sa-final-1 -TimeLimitSeconds 40` exit0; actual engine25 passed/0 failed/cases1; normalExit=true,exitCode0,cleanShutdown=true,mainRestored=true,stateRestored=true,223 original state files snapshotted,no unresolved files. Source game log confirms real wave HP2000→1910, energy90, native counter steady on same-level gains, V9 retained, actual720 consumption and real interruption refund. Log flushed on exit is explicitly recorded.

Post-native: cached Python `tests/motion_sa_hud_resources_test.py` and `tools/build-motion-sa-hud.py --check` both exit0 after main restoration. No temporary diagnostic include remains. Main/core/input/presentation/six registration-pool XML snapshots remain byte-identical. Native probe never used mouse/key/focus APIs. Installed checkout retained; no commits/pushes/worktree deletion/publishing.

Ruling: branch-finish commit/merge menu and deleting a plan workspace do not apply to this explicitly requested installed-directory change — no isolated branch was created, and the user authorized local implementation only. Preserve original source research, before snapshots, logs and previews as reviewable evidence. Cost if wrong: report/snapshot disk space remains occupied; nothing is discarded.
