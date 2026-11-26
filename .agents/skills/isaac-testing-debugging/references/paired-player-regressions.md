# Paired-Player And Parked-Inventory Regressions

Select rows for the feature's declared support scope. A custom extra player,
native twin and independent co-op participant are separate roles, not synonymous
test fixtures. Do not require unsupported hot reload or invent gameplay policies.

## Record Before Choosing Tests

- Exact game/extension build and relevant dependency versions.
- Creation route, expected native and mod-owned bodies, input devices and call site.
- Actual owner/child mapping and demonstrated reattachment strategy.
- Supported boundaries, inventory slots/components and charging entitlements.
- The observable postconditions for each phase; mark unavailable evidence as
  unverified rather than silently granting a capability in a stub.

## Focused Matrix

| Scenario | Required observation |
| --- | --- |
| Create one pair | Exactly the expected owned bodies; intended input and HUD behavior |
| Failed or ambiguous creation | No existing participant adopted, rebound, overwritten or removed |
| Two independent owners with children, reversed creation order | No pair or inventory cross-talk; a shared controller is not identity |
| Repeated initialization/restore | No extra child, duplicated transfer or repeated grant |
| Both active-body states through supported exit/continue | Current roles reattach uniquely; current input route and HUD are reconstructed |
| Player reorder, missing/duplicate match, partial readiness | No old-index fallback; not-ready and failed reconstruction distinguished |
| Supported death/revive, removal, join/leave or identity switch | Correct owned cleanup/recovery; unrelated co-op remains intact |
| No-gain inventory round trip | Same body, items/counts, slots and supported charge/state components |
| Slot zero, sparse/empty records, supported pocket2 through JSON | Decoded mapping matches the real serializer, not an assumed array |
| Foreign items and occupied destination | Only approved content moves; no silent slot overwrite |
| Repeated/partial switch, failure during detach or restore | Uncommitted recovery retained; no loss/duplication or false atomicity claim |
| Ordinary/battery/partial/timed/item-specific charge cases | Exact supported components and approved increments, limits and clocks |
| Zero/one/repeated clear or wave entitlement through actual hooks | No missed or double credit; distinct legitimate waves still settle |
| Live spending/reroll/removal after restore | A stale ledger cannot resurrect old items or charges |
| Supported Genesis/rebuild from each body state | Intended inventory participates; old snapshots cannot restore destroyed content |

## Make Negative Controls Observable

Run the actual module entrypoint or callback adapter when available. A fixture
that directly calls the correct body method does not prove real event ownership.
Reject permissive fixture behavior: returning the requested child for any index,
treating every controller as unique, serializing arbitrary tables unchanged,
collapsing all charge into one number, or invoking only one of two overlapping
event sources hides precisely these failures.

Use concrete counterexamples, not wording matches:

- Creation fails while an unrelated player is last in the list.
- Continue reorders two pairs, or two candidates match the same owner.
- One logical entitlement reaches two adapters; another real wave has a new key.
- A destination becomes occupied after capture, or restoration stops midway.
- A restored item is spent/removed and an old recovery record is presented again.

These are model/test inputs, not assertions that every native build exhibits
each failure. Validate the test by showing an erroneous implementation fails the
observable invariant; do not claim an unevaluated eval definition has passed.

## Evidence Layers

1. Metadata/reference audits establish only readable skill structure and links.
2. Pure model tests can establish selected identity/ledger/event invariants.
3. Independent agent application can establish whether instructions are found
   and applied to supplied cases. Report controls and review criteria; do not
   infer an accuracy gain when the no-skill control was already correct.
4. Matching-build game checks establish actual spawning, device prompts, input,
   HUD, save/continue, charge APIs and item-hook/rebuild behavior for tested rows.

Do not turn layer 1-3 into layer 4. For a controller prompt, retain build, devices,
API arguments, call timing, before/after players and the reproduction log; one
chat report cannot certify that an API is always broken or always safe.
