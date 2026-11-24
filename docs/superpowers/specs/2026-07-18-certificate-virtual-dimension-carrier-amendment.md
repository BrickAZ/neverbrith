# Certificate Virtual Dimension Carrier Amendment

This user-approved amendment is part of
`2026-07-18-certificate-virtual-dimension-design.md`.

- From an ordinary room, the Certificate executes `goto s.default.2` exactly
  once to create and enter the empty debug-room carrier.
- Registry, return-entity, layout, and transition prerequisites are validated
  before the command runs.
- Nested use while already in the carrier does not execute `goto`.
- Previous/next virtual-room navigation never executes `goto`; it is handled by
  the Neverbirth-owned virtual-node state machine inside the carrier.
- Return uses `StartRoomTransition` to the saved origin room and origin engine
  dimension.
- No code targets engine dimension 2, calls `MakeRedRoomDoor`, or invokes the
  vanilla Death Certificate mechanic.
- Tests must count the approved command: once for each outer entry and zero
  times for virtual previous/next navigation.
