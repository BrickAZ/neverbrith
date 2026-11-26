# Deferred Work Regressions

Use for one-shot callbacks, delayed initialization or a time-parameterized helper.
Select the actual support scope; do not require timers or hot reload when the
feature only promises an owned later-pump call.

## Execute The Real Path

Run the actual queue/factory and installed callback adapter. Directly calling a
task bypasses registration identity, batch ownership and native return handling.
The callback skill's `tests/test-deferred-tasks.lua` extracts both documented Lua
blocks; it uses a registration ledger, not the Isaac engine.

| Case | Observable invariant |
| --- | --- |
| Invalid task/guard before enqueue | Explicit rejection; no inert pending closure |
| Zero work and successful task | Correct invocation count; task return does not escape a void native callback |
| Task or validity check throws | Defined failed outcome, reporting and reference release; no implicit replay |
| Another task in the same batch | Failure isolation according to the declared policy |
| Nested enqueue and pump re-entry | Declared batch cutoff/order; no accidental same-drain recursion |
| Cancel before run, twice, or from a sibling | Pending task never runs; repeated cancellation is safe |
| Cancel already running/completed work | No false promise of interruption or rollback |
| Destroy during a drain | Pending and remaining not-started jobs cannot run; stale wrapper inert |
| Replacement instance and foreign registration | Old cleanup removes only the exact old handler |
| Diagnostic reporter throws | Error visible and dispatcher not permanently stuck in its drain state |

Use failure-injected/erroneous implementations to show the test rejects missing
validation, re-entrant draining or wrong wrapper removal. These are observable
checks, not matches against documentation wording.

## Extra Cases For A Real Timer Or Ready Wait

The bundled example has no time parameter and does not prove these cases. When
the target helper does, use its actual clock/serializer/event path to test:

- zero, fractional, negative, NaN/infinite or overshot deadlines according to the
  selected unit and input policy;
- pause, slow motion, transitions, no-run context and resume; render calls must
  not advance a logic clock merely because the fake fixture treats them alike;
- nested scheduling at the exact cutoff and repeated dispatch in one native
  frame; a later `Pump` invocation is not necessarily a later game tick;
- room/run/entity/provider generation replacement and stale captured objects;
- provider not-ready, ready later, absent, failed, timeout and teardown while
  waiting; an always-ready fake service cannot prove real readiness.

## Proof Boundary

Separate metadata/link audits, pure Lua queue checks, independent agent
application and actual matching-build game checks. Keep exact source evidence
for callback timing and native unload. Never report mock cancellation as proof
that old engine callbacks were removed, or a fixed-rate fake clock as proof of
seconds. Eval definitions are not executed tests; a correct no-skill control does
not justify an accuracy-uplift claim.
