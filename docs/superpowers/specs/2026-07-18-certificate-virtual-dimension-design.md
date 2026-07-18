# Certificate of Neverbirth: Project-Owned Virtual Dimension

This approved design supersedes
`2026-07-17-certificate-of-neverbirth-design.md`.

## Status and constraints

Approved by the user on 2026-07-18: use a linear room chain with a central
reusable return mechanism in every room. The implementation must work in
ordinary Repentance without StageAPI, REPENTOGON, or another required mod.

Ordinary Repentance does not expose registration of a new engine Dimension.
Neverbirth therefore owns a virtual dimension identity,
`neverbirth:certificate_gallery`, and must not fabricate a numeric dimension,
use `MakeRedRoomDoor`, allocate Red Rooms, enter engine dimension 2, or invoke
the vanilla Death Certificate mechanic.

## Player-facing contract

- The Certificate remains a reusable quality-0 active item with zero charge.
- It remains outside all item pools and available through debug/console tools.
- Use enters a gallery that appears to contain multiple connected rooms.
- Each room contains at most 32 Neverbirth collectible pedestals.
- Players may take any number of collectibles; taken items stay absent when a
  room is revisited.
- Every room has a central reusable return mechanism that returns the whole
  party to the room in which the current session began.
- Nested Certificate uses remain supported and return to their parent session.

## Registry

`content/items.xml` remains the sole ownership source.
`tools/generate-neverbirth-collectibles.ps1` emits the sorted generated runtime
registry. Runtime name resolution must reject unresolved or duplicate entries.
No manual allowlist or denylist is permitted. The Certificate itself and all
hidden/debug collectibles remain included.

## Entry, isolation, and return

Before entry, store only plain stable values:

- initiating player key;
- origin room index and engine dimension;
- current stage and stage type;
- every co-op player's position;
- parent session token for nested use;
- collected local IDs and current virtual room index.

The controlled carrier may be entered only after registry, entity, layout, and
transition preconditions pass. Failure refuses use without discharge, creates
no session, and leaves the current room untouched.

Neverbirth owns only session-tagged gallery pedestals, navigation mechanisms,
the central return mechanism, and virtual map state. Origin entities, grids,
doors, rewards, descriptors, vanilla dimensions, and third-party state are
preserved. Persistent data must never contain live Player, Room, Level, Entity,
Door, GridEntity, or RoomDescriptor userdata.

## Linear virtual room chain

Resolved collectibles are partitioned into stable local-ID-ordered groups of
32. Nodes use the identities `neverbirth_gallery:1`, `:2`, and so on.

`virtualRoomCount = max(1, ceil(registeredCollectibleCount / 32))`.

The approved topology is:

```text
room 1 <-> room 2 <-> room 3 <-> ... <-> room N
```

- Room 1 has only a next mechanism when another node exists.
- Interior rooms have previous and next mechanisms.
- Room N has only a previous mechanism.
- Navigation uses Neverbirth-owned repeatable entities, never Red Room doors or
  one-shot grid buttons.
- A short arrival lockout prevents immediate reverse travel.

Switching nodes locks navigation, plays a bounded transition, removes only
entities owned by the active session, loads the target node's uncollected
pedestals and mechanisms, positions players at the matching entrance, then
re-arms navigation. Nodes remain distinct in Neverbirth state and are never
reported as separate engine room descriptors.

## Layout and mechanisms

- A node has 32 legal pedestal slots in an 8-by-4 grid.
- Default center spacing is 64 pixels on both axes, subject to live room bounds.
- The final node may be partially empty; no unrelated filler rewards appear.
- Capacity is validated before entry. Missing legal slots fail explicitly and
  never silently omit IDs.
- The center reserves a non-overlapping location for the registered
  `Certificate Return Portal`.
- Previous and next mechanisms use reserved side positions outside the grid.

The central return mechanism is session-tagged and recreated whenever missing.
It is not a pressure plate and does not depend on one-shot grid state. Returning
ends the current session; the next active-item use creates a fresh session and
fresh mechanism.

## Collection confirmation

Each pedestal stores the session token and Neverbirth local ID. Pre-collision
records the player's pre-pickup count and returns `nil`. Post-update marks the
local ID collected only after the pedestal disappears or the player's item
count increases. Collection does not return the player or remove other
pedestals.

## Lifecycle

- Pause leaves state unchanged.
- Normal return pops the session and restores origin room, engine dimension,
  and all saved player positions.
- Nested return restores the parent virtual node.
- Save-and-continue recreates the current virtual node from stable data.
- Unexpected room transition closes the session and attempts the recorded safe
  return without mutating the unexpected destination.
- Death clears transient session and entity state.
- New run and run end clear all virtual sessions and transition locks.
- Failed return restores the current virtual node and re-arms its return
  mechanism instead of stranding the party.

One use creates one party-wide session bound to the initiator. All players
navigate together; one use cannot duplicate room content per holder.

## Implementation scope

Only the Certificate subsystem in `main.lua` and its behavior test are changed.
The generated registry and existing return-portal entity are reused. Existing
real-map allocation constants, real gallery room-index maps,
`tryCreateConnectedRoom`, `buildGalleryNetwork`, and every `MakeRedRoomDoor`
call in this subsystem are removed. They are replaced with virtual room
index/count, owned previous/next mechanisms, node loading, and a virtual
transition state machine.

## Validation

Static and scripted checks must prove:

1. Registry sizes 1, 32, 33, and 65 yield 1, 1, 2, and 3 virtual rooms.
2. No node has more than 32 pedestals.
3. First, interior, and last nodes expose only valid linear edges.
4. Previous/next navigation loads the intended stable node.
5. Arrival lockout prevents immediate reversal.
6. Every node has a central return mechanism.
7. Repeated independent uses each receive a working return mechanism.
8. Collected IDs remain absent after revisiting a node.
9. Return restores exact origin room, dimension, and player positions.
10. Nested sessions restore their parent node.
11. Failed entry does not discharge or leave partial state.
12. Certificate code has no `MakeRedRoomDoor`, dimension-2, Death Certificate,
    StageAPI, or REPENTOGON dependency.
13. Normal callbacks return `nil`; only the active-item callback returns its
    explicit no-discharge contract.

In-game checks must cover ordinary rooms, co-op, save-and-continue, nested use,
unexpected teleport, repeated entry/return, and a same-run vanilla Death
Certificate use to prove isolation.
