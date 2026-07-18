# State Ownership

Every piece of Isaac mod state needs one owner.

## Owner Types

- **Player state**: keyed by `player.InitSeed` or an existing helper. Use for item stacks, per-player cooldowns, delayed damage, selected modes, or held input.
- **Entity state**: `entity:GetData()` for fields that should disappear with the entity.
- **Room state**: local tables reset on new room for room-only spawned effects, one-room cooldowns, and temporary hazards.
- **Floor state**: tables reset on new level for once-per-floor effects or active item modes.
- **Run state**: tables reset on new run for unlock-like run mechanics or long-lived counters.
- **Challenge state**: state that only exists while a specific challenge is active and must be cleaned outside it.
- **UI state**: runtime-only mode/selection state tied to render/input callbacks.
- **Saved mod data**: plain serialized data that must survive save/reload.

## Keying Strategy

- Prefer stable player or entity identifiers used by the current repo.
- Keep owner keys visible near the code that creates and clears them.
- Avoid global booleans for player-specific or entity-specific behavior.
- For co-op-sensitive mechanics, state whether all players share state or each player owns one copy.

## Warning Signs

- A table grows forever.
- State is written in update callbacks but never cleared.
- A challenge callback changes normal runs.
- A render callback mutates gameplay.
- A saved table contains userdata or function references.
