# Deferred Task Lifetime And Clocks

Use for deferred initialization, a delayed effect or a pending closure. Callback
selection and one-shot mechanics belong to
`../../isaac-callback-contracts/references/deferred-one-shot-callbacks.md`.
Loading and provider readiness belong to `isaac-mod-architecture`.

## Task Contract

Record only fields relevant to the actual feature; these are semantic concepts,
not a mandatory Lua table schema:

| Concern | Required decision or discovered fact |
| --- | --- |
| Owner | Module generation, player, entity, room, run or presentation surface |
| Readiness | Proven prerequisite and the boundary that can observe it |
| Eligibility | Current context/owner validity checked before mutation |
| Schedule | Selected callback/clock, due boundary and eligible batch |
| Terminal outcome | Succeeded, failed, cancelled or expired, not merely removed from a list |
| Retry | None or an explicit bounded/idempotent policy; no silent error loop |
| Cancellation | Handle/owner, lifecycle triggers and release of captured references |
| Diagnostics | Task/context identity and error details through the discovered error path |

Transient function closures and handles are not saved gameplay data. If an
approved delayed entitlement must survive continue, persist plain semantic facts
and reconstruct current work; do not serialize a function, entity or room.

## Time Is Not Callback Count

Before adding `delay`, identify whether it means update ticks, render
opportunities, elapsed game time or elapsed wall time. Do not map 60 render calls
to one second without evidence. Specify pause, slow-motion, transition and
no-run behavior for the selected clock. A real-time deadline is serviced only
when the chosen dispatcher next gets an opportunity to run.

Validate finite, nonnegative inputs. Tick counts additionally need their declared
integer/fraction policy; seconds may legitimately be fractional. Define zero,
the first decrement/check edge, overshoot and nested enqueue explicitly. A
decrement followed only by `== 0` may strand zero/fractional/missed deadlines.
Check deadline crossing according to the chosen clock, not a copied countdown.

Keep "after this batch", "after this callback", "next logic tick" and "after N
seconds" separate. A batch snapshot alone proves only its own batch cutoff.
Do not silently impose a timing or persistence policy the user has not approved.

## Cancellation And Reconstruction

- Name boundaries for the feature's declared scope: room/level transition,
  player/entity removal, item loss, run exit or module/provider replacement.
  Surviving a boundary versus cancelling there follows the approved mechanic.
- At execution, resolve current objects from proven ownership/context facts and
  verify their generation. Keeping a userdata reference alive does not prove it
  still denotes the current room, player wrapper or provider instance.
- Disposal cancels pending work and makes stale saved pump callbacks inert.
  Cancellation of pending work is idempotent; already running synchronous code
  cannot be preempted or atomically rolled back by a cancellation flag.
- Release pending/in-flight-but-not-started closures when cancelled/disposed.
  An invalid guard is not automatically a retry request. Separate not-ready
  dependencies from invalid/expired task context and missing capability.
- If waiting for a dependency is required, use its discovered ready event or a
  bounded wait with explicit timeout/failure behavior. Do not repeatedly poll a
  permanently missing provider or treat exceptions as "not ready" forever.
- Verify native unload behavior for supported operations. Restart-only scope
  does not require a hot-reload manager; a Lua mock disposal does not prove the
  engine's actual shutdown/save order.

Test fake clocks and invalidated context tokens through the actual scheduling
path. Native timing, pause/menu behavior, object validity and cleanup hooks need
matching-build evidence separate from pure Lua queue tests.
