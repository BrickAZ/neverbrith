# Blue Banana Peel Pill Costume Design

## Scope

Replace the current automatic all-player blue banana peel costume grant with a player-owned, run-persistent unlock triggered by consuming a real pill. Do not change the PNG or ANM2.

## Locked Behavior

- A player does not start with the costume.
- The first real pill consumed by a player grants that player the costume immediately.
- The costume remains for that player for the rest of the run, including room and floor changes, revival, co-op rejoin, and continued saves.
- Each co-op player earns the costume independently.
- Pill effects simulated by Placebo or another mimic source do not grant the costume.
- Horse pills count as real pill consumption.
- Repeated pills are idempotent and do not stack duplicate null costumes.
- A new run clears all earned state.
- Keep the existing costume resource path, animations, XML registration, and high-priority `priority="98"` setting.

## Runtime Design

Use `MC_USE_PILL` as the ownership event. Its handler receives the pill effect, player, and use flags. If the use flags contain `USE_MIMIC`, return without changing state. Otherwise mark only the callback player as earned, save the run data, and apply the existing null costume immediately.

Store earned ownership in the existing run save structure, keyed by the project's stable per-player key based on `player.InitSeed`. On a fresh run, clear the map. On a continued run, preserve it.

Keep a lightweight lifecycle synchronization callback, but change its responsibility: it may restore the costume only for players whose earned flag is already true. It must never grant the costume merely because a player exists. Runtime/player data guards keep repeated updates idempotent.

## Callback Contract

- `MC_USE_PILL`: grant on real pill consumption; ignore mimic uses; return `nil` so the original pill effect remains untouched.
- `MC_POST_PEFFECT_UPDATE` or the existing fallback update path: restore only already-earned costumes after player entity recreation; return `nil`.
- `MC_POST_GAME_STARTED`: clear ownership for a new run, preserve and resynchronize on continue; return `nil`.
- `MC_PRE_GAME_EXIT`: persist the current run state if the project save owner requires it; return `nil`.

## Visual Contract

- Carrier: registered null costume.
- XML: `content/costumes2.xml`, local costume id `17495`.
- ANM2: `resources/gfx/characters/costume_blue_banana_peel.anm2`.
- PNG: `resources/gfx/characters/costumes/costume_blue_banana_peel.png`.
- Animations: existing `HeadDown`, `HeadRight`, `HeadUp`, and `HeadLeft` definitions.
- Priority remains `98`; no art files are modified.

## Tests

Add a focused behavior test proving:

1. New players do not receive the costume automatically.
2. A real pill grants the costume immediately to only the consuming player.
3. A mimic pill use does not grant it.
4. Repeated pills do not duplicate the costume.
5. A continued run restores only previously earned players.
6. A new run clears earned state.
7. Callback handlers return `nil` and do not replace or cancel the pill effect.
8. Costume XML, ANM2, PNG path, dimensions, alpha channel, animation names, and priority remain valid.

## Out of Scope

- New collectible or pill registration.
- Stat changes or gameplay effects beyond the costume.
- Changes to other costumes or items.
- PNG or ANM2 edits.
