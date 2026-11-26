# Paired-Player Reconstruction

Use when an approved paired-body feature must survive exit/continue, body
replacement or another explicitly supported reconstruction boundary. Creation
and native versus mod-owned topology belong to
`../../isaac-players-characters/references/custom-partner-topology.md`.

## Identity Is A Reattachment Contract

For each pair, identify the persistent main owner, body roles, current live
mapping, state authority and reconstruction phase. These are semantic fields,
not prescribed Lua member names.

- A runtime userdata reference is not serialized identity.
- A current array index can be a lookup hint, not proof of the same body after
  reordering, join/revive or continue. A field named `TwinIndex` does not reveal
  whether the helper behind it uses an array index or a stable project key.
- `ControllerIndex` identifies an input route and may be shared by bodies.
- A seed, UUID or other saved token is useful only if the target project proves
  how the matching live/restored body carries or recovers it. Storing a new UUID
  only in JSON does not create that link.

Discover the actual player-data/key helper, serializer and restoration route.
Demonstrate identity under the supported reorder/continue cases. If reattachment
cannot be proved, report the missing technical capability; do not invent a
stable key or redirect a potentially unrelated player's controller.

## Separate Stored Facts From Live Authority

| State | Authority and handling |
| --- | --- |
| Approved durable pairing facts | Versioned plain data with a demonstrated live reattachment route |
| Current Player/Parent/controller/HUD links | Current live objects; rebuild and verify when available |
| Parked inventory or unfinished transition | Recovery ledger while no verified live restoration has committed |
| Restored, spent or rerolled inventory | Current live state; an older snapshot must not resurrect removed content |
| Temporary timers and presentation | Reconstruct/reset only according to the approved lifecycle |

Round-trip the actual serializer, including empty records and active slot zero.
Numeric/sparse table keys can be encoded differently by different JSON helpers;
verify the decoded slot-to-record mapping rather than assuming an array layout.
Do not add SaveData for a runtime-only feature.

## Reconstruction Sequence

1. Decode and validate shape/version and the approved run ownership.
2. At the discovered player-ready boundary, reacquire live wrappers and resolve
   the main/child mapping uniquely. Distinguish not-ready from a proven missing
   body; do not treat the first player-init callback as universal readiness.
3. Reconcile only this feature's pair. Repeated callbacks must not duplicate a
   child, transfer inventory twice or bind a foreign player. If creation is
   needed, follow the project's approved missing-body policy and creation guard.
4. Restore supported links, the main owner's current input route and native HUD
   assignment through the discovered APIs. Check expected types/roles and keep
   independent co-op players unchanged.
5. Restore approved parked state once and verify readable postconditions. Make
   live state authoritative only after that restoration commits; retain recovery
   records and diagnostics when it cannot be proved.

On missing, duplicate or ambiguous matches, stop that pair's destructive work.
Waiting for readiness is different from guessing a replacement. Do not silently
select a new gameplay rule such as deleting, respawning or merging bodies.

## Exit And Destructive Transitions

Some projects normalize the active body before exit or before Genesis. Treat
this as a project-specific transition protocol, not a universal callback recipe:

- Discover callback timing/priority, save ordering and re-entrancy behavior in
  the selected build and actual state store.
- Define which identity and inventory the engine must see at that boundary,
  including parked content and any still-uncommitted restoration.
- Record exit reason and whether the supported path saves, ends a run, switches
  identity or enters a destructive inventory process. Do not write a new
  persistence policy merely because one callback is convenient.
- On the supported return/continue path, resolve current players again. A stored
  pre-exit controller number or live body reference is not permanent authority.
- Verify that old snapshots cannot restore items removed by Genesis, rerolls or
  another committed inventory change. An explicit unsupported feature is a
  declared limitation; a blanket item ban is not a compatibility fix.

New run, continue, both active-body states, repeated restore, death/revive and
co-op join/leave need separate rows when supported. Do not claim that testing
the single-player exit path proves all of them. Inventory details belong to
`../../isaac-active-item-mechanics/references/parked-active-inventory.md`.
