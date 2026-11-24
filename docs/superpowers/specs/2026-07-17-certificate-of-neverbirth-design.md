# Certificate of Neverbirth Design

## Confirmed contract

- `Certificate of Neverbirth / 未生证明` is a quality-0 active collectible with zero charge requirement.
- It is absent from every item pool and is obtained only through console/debug tooling.
- Using it enters a dedicated gallery. The item is reusable and is not removed.
- The gallery contains exactly one pedestal for every collectible registered by this mod, including the certificate itself and hidden/debug collectibles.
- Players may take any number of displayed collectibles. A floor button returns the party to the room from which the active session began.
- Nested uses are allowed. Sessions retain their own initiator, origin room, dimension, position, remaining collectible IDs, and spawned-entity ownership.

## Registry architecture

`content/items.xml` is the only ownership source. `tools/generate-neverbirth-collectibles.ps1` parses its active/passive/familiar entries, sorts local IDs numerically, and emits `generated/neverbirth_collectibles.lua`. Runtime resolves the generated English names with `Isaac.GetItemIdByName`, rejects unresolved IDs, sorts resolved runtime IDs, and caches them at load/new-run boundaries. Tests compare the generated file with all item XML entries so additions cannot be silently omitted.

## Gallery lifecycle

The use callback records the originating descriptor and player position, validates registry/capacity, and transitions to the dimension-2 debug room carrier. `MC_POST_NEW_ROOM` spawns owned pedestals and one pressure plate only when the active session target is entered. Each pedestal receives a session token and local ID. Pickup collision removes that ID from the saved remaining set, allowing room reload to restore only uncollected entries. The update callback watches the owned pressure plate; activation removes owned gallery entities, pops the session, and transitions to the saved origin.

If the runtime cannot resolve all registered items, cannot enter the carrier room, or has fewer safe positions than registered items, it logs an explicit failure and does not silently omit IDs.

