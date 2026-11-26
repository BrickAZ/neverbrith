# Parked Active Inventory

Use only when the approved mechanic removes, transfers or simulates active items
for an inactive body. This is not the default implementation of a paired
character. Pair creation belongs to `isaac-players-characters`; persistence and
reattachment belong to `isaac-state-lifecycle`.

## Define The Supported Ledger

Record the semantic owner/pair and body role, slot, resolved item identity,
supported charge components, extra item state, transition generation and whether
the current authority is parked data or a verified live slot. Discover actual
member names and serializers from the project, not a reference mod.

Before removal, establish:

- Which items the design permits parking: this mod's registered items, an
  explicit capability/allowlist, or another approved set. `item > 733` is a
  build-dependent numerical shortcut, not a portable ownership or compatibility
  test; foreign mod items require the declared policy too.
- Which slots are supported. The documented
  [ActiveSlot enum](https://wofsauge.github.io/IsaacDocs/rep/enums/ActiveSlot.html)
  has primary `0`, secondary `1`, pocket `2` and pocket2 `3`. A loop over `0..2`
  may be an intentional restriction, but cannot claim all-slot coverage. Use
  discovered enum/API behavior rather than applying one restore path to all.
- What a charge helper actually returns: ordinary charge, battery/overflow,
  subcharge or other item-specific state may have different APIs. Read the
  helper and verify the corresponding setter/grant path; never infer complete
  preservation from one scalar named `Charges` or from boolean arguments.
- Whether item-specific state and obtained/removed hooks can be preserved.
  A successful `AddCollectible`/`SetPocketActiveItem` call does not by itself
  prove no starting grant, pickup effect, inventory notification or slot
  replacement side effect. Discover the matching-build contract.

Preflight every supported component before destructive removal. If the engine
does not expose a required state, report that limit and use only an approved
restriction or fallback. Do not hide it by clearing the slot and hoping to rebuild.

## Move Once, Restore Once

| Phase | Required check |
| --- | --- |
| Capture | Snapshot the actual body/slot and confirm required state is representable |
| Detach | Remove only approved owned items; retain recovery state for partial failure |
| Park | The ledger owns the absent content and only approved events may advance it |
| Restore | Validate target body, current generation and slot occupancy before mutation |
| Commit | Verify item, count, slot and supported charge/state; then supersede the parked record |

On occupied slots, lost owners, repeated calls or partial restoration, do not
silently overwrite, duplicate or discard content. Discover the approved conflict
policy and retain the uncommitted recovery facts. This is a compensating protocol,
not an engine-wide atomic transaction. Once a live slot commits, later spending,
rerolls and removal are authoritative; the parked record must not replay them.

## Simulated Charging Is An Explicit Mechanic

The absence of an item from a live slot means native charging may not apply.
Define the intended semantics before simulating it:

- Charge types and supported item-specific exceptions; a timed item is not
  automatically entitled to a full refill on room clear.
- The clock, increment, capacity, overflow/battery behavior and source of each
  modifier while parked. Do not infer these from `MaxCharges` alone.
- Which body receives a room/wave event and which ledger generation it can
  settle. Define a logical event identity for the actual room/dimension/wave
  context when overlapping hooks can represent the same entitlement.
- Map normal-clear, reward-generation and Greed-wave hooks by actual dispatch.
  They may miss clears, overlap, or denote different legitimate events. One
  shared function does not deduplicate them; a global once-per-room flag may
  instead suppress valid wave events. The deduplication key follows the approved
  entitlement, not callback names.
- Separate full/partial charge feedback from state mutation; sound playback
  cannot be the proof that charge was applied exactly once.

Route exact callback timing/returns to `isaac-callback-contracts`. For supported
Genesis or other destructive rebuilds, define whether parked items participate
and how old records become invalid; do not resurrect removed items afterward.

## Evidence Required

Test a no-gain park/restore round trip before any charging simulation. Include
every supported slot, empty slots, same item on different bodies, battery/partial
state, repeated switches, foreign items, occupied destinations and failure after
partial progress. Round-trip the real serializer if continue is supported.
Compare zero/one/repeated logical charging events, including overlapping hooks.
Native hooks, input, charge decomposition and Genesis behavior still require
matching-build in-game checks; a Lua model proves only its modeled ledger paths.
