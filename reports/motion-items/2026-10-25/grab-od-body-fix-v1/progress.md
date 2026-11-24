# Repair ledger — plan: docs/superpowers/plans/2026-10-25-motion-grab-od-body-fix.md

User scope: 360/720 fail after feedback, OD input, head/body separation on wave/DP with suspicion on grapples, actual 720 acquisition should default to3 SA. User confirmed failure has feedback; preserve desktop input boundary. No agents used for this repair.

Before snapshots preserve19 source/test/registration files in the dirty installed checkout. No commit/reset/push or resource rebuild was authorized or performed.

Root causes and RED evidence:

- Original native WalkRight layer1 Y+2 and HeadRight layer4 Y-5 were applied on top of authored body/head pivot positions (source first wave bodyY16/headY9). The mock previously ignored native layer displacement. `anchor-red.log` exit1 at 'position applied exactly once'. Private clones also retained live HeadDown overlay while setting a new main Head frame; `overlay-red.log` exit1.
- 360 chose an initial candidate then only rechecked that exact object at contact6. `grab-red.log` exit1 when original moves away but a second legal target remains; also covered original removal before contact.
- OD only read the current Shift at Execute and did not retain it through recognition/recovery. `od-input-red.log` exit1 on early Shift then release; first attempt exposed an incomplete Isaac mock and was corrected before taking the behavioral RED. `od-executor-red.log` exit1 on explicit captured modifier.
- Acquisition had no owned full-meter settlement/event. `acquire-core-red.log` exit1 missing OnAcquire; `acquire-native-event-red.log` exit1 when the real callback signature had no grant route.

Repairs and verification:

- Current native AnimationData→Layer→Frame.GetPos removed once from private render origin after actor scale/rotation; RemoveOverlay only on private split actor/costume clones. Original live sprite and target sprite overlays preserved. Four moves/six variants/3328 directional frames now assert effective anchors against approved source points, including cinema rotations/scales. HUD/animation source files untouched.
- 360 reselects eligible nearest target in its existing cone at tick6, no early cancellation for a non-held dead candidate; still whiffs outside approved range and honors Boss anti-grab.
- Input adapter latches Left Shift during held active, core carries a boolean with completed/pending command, combat uses that snapshot instead of execution-time Shift. Per-command consumption and next ordinary motion covered; no new key or OD cost.
- MC_POST_ADD_COLLECTIBLE exact6 native args routes actual720 additions to combat.OnAcquire. Early startup acquisitions defer until new-run initialization; continued-game reconstruction is ignored. No per-frame refill; OD unaffected. New-run starting acquisition, continuation, repeated updates and non720 no-grant tested.
- Old Python input-core hash assertion updated to strip ONLY the two OD field assignments and two appended command/pending metadata fields before exact recognizer text parity. Other recognition lines/windows untouched. SA resource scope retains main/core/XML exact bytes while permitting this approved input/presentation repair; HUD still cannot write combat data. These two maintenance changes followed expected old-scope failures, not hidden passing results.

Executed checks:

- `lua tests/motion_combat_test.lua`: exit0,72 assertions.
- `lua tests/motion_presentation_test.lua`: exit0,3498 assertions;3328 directional frames and real-offset-aware mock. An intermediate new assertion initially included intentional gold-rim copies; filtered to original actor color before judging base anchors; no gameplay code changed for that fixture correction.
- `lua tests/motion_od_input_test.lua`: exit0,18 assertions.
- `lua tests/motion_input_behavior_test.lua`: exit0,62 assertions; `lua tests/motion_input_core_test.lua`: exit0,90 assertions.
- `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-25/grab-od-body-fix-v1/lua-all.json`: exit0,88 passed/0 failed/0 blocked,127 syntax files/81 Lua test files. Six pre-existing generic asset-path warnings, strict0warnings.
- Cache Python running `tests/motion_items_resources_test.py`, `tests/motion_presentation_resources_test.py`, `tests/motion_sa_hud_resources_test.py`, `tools/build-motion-sa-hud.py --check`: each exit0. Original V7/V9 hashes/crops/timing and native projection unchanged; original SA resource parity intact.
- `pwsh -NoProfile -File tests/motion_native_state_test.ps1`: exit0.
- `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe combat_fix -Attempt repair-native-1 -TimeLimitSeconds 100`: exit0, native16cases179passed/0failed, normal exit0, stateRestored/mainRestored true,224 original state files snapshotted,0 unresolved files. Buffered log flush recorded as COMPLETED_LOG_FLUSHED_ON_EXIT. No mouse/key/focus APIs. Only owned hidden process closed by WM_CLOSE.

Final source invariants: main.lua, motion_combat_core.lua and6 item/pool XMLs exactly match current task before snapshots; no temporary native include remains. Default0 energy still applies to non-acquired players; acquiring720 specifically grants90 per user override. Original audio/art untouched. Manual physical keyboard feel/pixel judgment and unusual NPC/co-op combinations are not inferred from these checks.

Final read-only scope review: acquisition has active/live/720 gates and native callback membership guard; early add events deferred only for new runs, continued reconstruction discarded; OD metadata is captured at recognition and kept through pending; future Shift cannot upgrade an ordinary queued command; contact reselect honors eligibility/cone/Boss reservation; native frame/overlay changes touch private sprites only. No unresolved in-scope findings. Hashes saved in changed-source-hashes.json. After final description-only edits, localization test exit0; agent wiki navigation exit0 (107 links); git diff --check exit0 (existing CRLF conversion notices only).

