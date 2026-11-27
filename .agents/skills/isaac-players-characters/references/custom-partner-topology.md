# Custom Partner Creation And Ownership

Use for a mod-created extra player body, paired character or controllable clone.
These are topology contracts, not a ready-made twin-character implementation.

## Classify The Bodies

| Role | Evidence needed |
| --- | --- |
| Independent co-op participant | Its own participation/input and identity contract |
| Native twin or subplayer | Matching-build native relationship/accessor behavior |
| Mod-created extra player | Discovered creation route, creation provenance and an explicit owner mapping |
| Familiar or visual clone | Its actual entity carrier; player creation APIs may be irrelevant |

Shared `ControllerIndex`, matching `PlayerType`, `Parent`, and player-list order
are different signals. None alone proves a complete native twin relationship or
authorizes removing, rebinding or overwriting another player. Distinguish the
body that owns input from the body that owns health, inventory and saved state.
Do not invent sharing rules that the character design has not approved.

## Creation And Rebinding Contract

1. Discover the game/extension build, registered types and current creation code.
   Record the actual API, its return/failure behavior and callback timing.
2. Observe the current players before creation. If a creation API returns a
   player, validate it against the expected creation and type; if a command does
   not, compare current live players before/after and account for any native
   secondary bodies created by the selected type.
3. Treat `GetPlayer(GetNumPlayers() - 1)` only as a candidate. A failed command,
   nested initialization or extra native body must not cause an existing co-op
   player to be adopted as the new child. Ambiguous results stop this binding;
   they do not authorize deleting every newly observed entity.
4. Establish the proven main/child mapping through the target project's owned
   data and supported native links. Bind the intended current controller, then
   refresh the native HUD when that route requires it. Check each postcondition
   separately: existence, identity, relationship, input and display.
5. Make repeated initialization/reconciliation idempotent for that exact pair.
   A second callback must not create a second child or rewrite another pair.
   Define recovery through `isaac-state-lifecycle` before claiming continue.

If creation cannot complete, preserve unrelated players and report the failed
phase. Missing-child replacement versus ending the mechanic is a gameplay choice,
not an automatic repair policy. A compensating cleanup requires a supported
removal route and proof of the exact owned child, not merely a count difference.

## API Evidence And Its Limits

Documentation checked on 2026-10-25:

- REPENTOGON documents
  [`PlayerManager.SpawnCoPlayer2(PlayerType)`](https://repentogon.com/PlayerManager.html#spawncoplayer2)
  returning an `EntityPlayer`, and `RemoveCoPlayer` for extra players with an
  explicit warning not to pass the main player. This does not document every
  device prompt, initialization side effect or save/continue behavior.
- [`SetControllerIndex(Idx, IncludePlayerOwned = false)`](https://repentogon.com/EntityPlayer.html#setcontrollerindex)
  changes input ownership; the optional flag includes a native subplayer/twin.
  Discover the selected build before relying on that parameter. It is not proof
  that setting `Parent` creates all native twin behavior.
- Base [`HUD:AssignPlayerHUDs()`](https://wofsauge.github.io/IsaacDocs/rep/HUD.html#assignplayerhuds)
  refreshes HUD assignment; the documented example says parented characters no
  longer show health in the main HUD. That does not prove a separate custom
  health display or correct input and persistence.

A project may use `Isaac.ExecuteCommand("addplayer ...")` after validating its
actual build/device conditions. Do not mandate that workaround, deprecate a
documented API based on a chat report, or silently require REPENTOGON in a
vanilla-only project. For a reported controller prompt, capture build, call site,
character type, connected devices, player count and a minimal reproduction.

## Required Handoff

- Body roles and expected topology, including native secondary bodies.
- Creation route, provenance and failure/non-duplication checks.
- Main/child identity, current controller binding and HUD ownership.
- Inventory/health sharing rules already approved by the project.
- Supported continuation/revival/removal boundaries and unavailable evidence.

Use `isaac-character-switching` only when actual live identity changes are part
of this feature. For save/continue, read
`../../isaac-state-lifecycle/references/paired-player-reconstruction.md`.
For targeted evidence, read
`../../isaac-testing-debugging/references/paired-player-regressions.md`.
