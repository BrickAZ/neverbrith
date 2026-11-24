# Everchanging Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Register the quality-0 passive collectible Everchanging and give each compatible holder a deterministic, run-persistent appearance selected from the explicit style registry, initially containing the existing Blue Banana Peel head costume.

**Architecture:** Keep ownership in the existing monolithic `main.lua`. Store plain per-player run data under `musicboxSaveData.everchanging`, while runtime costume IDs and dirty flags live in `player:GetData()`. Detect only changes to the Everchanging copy count, draw only on copy increases through `player:GetCollectibleRNG(Items.Everchanging)`, and apply registered null costumes without replacing player spritesheets.

**Tech Stack:** Lua 5.4, Isaac Repentance callbacks, `content/items*.xml`, existing null-costume registration, PowerShell generation/validation scripts, standalone Lua behavior tests.

## Global Constraints

- Chinese name `千变万化`; English/internal name `Everchanging`; passive; quality 0; local id 38.
- Do not add the item to any `content/itempools*.xml` pool.
- No stat, damage, attack, pickup, drop, room, cache, or gameplay effect.
- First/current-only style: `blue_banana_peel` using `gfx/characters/costume_blue_banana_peel.anm2` in slot `head`.
- The legacy pill-earned Blue Banana Peel behavior is removed; keep its registered costume and assets as an Everchanging style resource.
- Do not add StageAPI, REPENTOGON, or another required dependency; keep EID integration optional through the project's existing guarded path.
- Do not call `LoadGraphics` or `ReplaceSpritesheet` in the update path.
- Preserve all unrelated uncommitted workspace changes.

---

### Task 1: Registration and failing behavior surface

**Files:**
- Create: `tests/everchanging_behavior_test.lua`
- Modify: `content/items.xml`
- Modify: `content/items.en_us.xml`
- Modify: `content/items.zh_cn.xml`
- Modify: `tests/localization_test.lua`
- Generate: `generated/neverbirth_collectibles.lua`

**Interfaces:**
- Consumes: `Isaac.GetItemIdByName("Everchanging")` and the existing collectible `gfxroot`.
- Produces: `Items.Everchanging` and generated row `{ localId = 38, englishName = "Everchanging", names = { "Everchanging", "千变万化" } }`.

- [ ] **Step 1: Write the failing XML/pool test**

In `tests/everchanging_behavior_test.lua`, read all three item XML files and assert:

```lua
local block = xml:match('<passive%s+[^>]-id="38"[^>]*/>')
assertTruthy(block, path .. " should register local id 38")
assertTruthy(block:find('quality="0"', 1, true), path .. " quality")
assertTruthy(block:find('gfx="Everchanging.png"', 1, true), path .. " gfx")
assertEquals(block:find('cache=', 1, true), nil, "no cache declaration")
```

Assert every `itempools*.xml` file contains neither `Everchanging` nor `千变万化`.

- [ ] **Step 2: Run the test and verify it fails**

Run: `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\everchanging_behavior_test.lua`

Expected: failure because local id 38 is absent.

- [ ] **Step 3: Register all locale variants**

Append before `</items>`:

```xml
<!-- Passive visual item: Everchanging -->
<passive name="Everchanging" description="A different look for this run" gfx="Everchanging.png" id="38" quality="0" />
```

Use `name="千变万化"` only in `content/items.zh_cn.xml`. Do not add `cache`, tags, hidden flags, or pool rows.

- [ ] **Step 4: Update localization expectations and regenerate discovery data**

Add id 38/name assertions to `tests/localization_test.lua`, then run:

`powershell -ExecutionPolicy Bypass -File tools\generate-neverbirth-collectibles.ps1 -Root .`

Expected: generated output adds exactly one row for id 38 with both names.

- [ ] **Step 5: Re-run registration tests**

Run the localization test and Everchanging test. Registration assertions pass; runtime assertions introduced in Task 2 fail until the Lua API exists.

### Task 2: Style registry, deterministic per-player state, and costume ownership

**Files:**
- Modify: `main.lua:7-96`
- Modify: `main.lua:1624-1769`
- Modify: `main.lua` near the existing visual systems
- Modify: `tests/everchanging_behavior_test.lua`

**Interfaces:**
- Consumes: `EnsureMusicboxDataLoaded()`, `SaveMusicboxData()`, `GetCurrentRunSeed()`, `GetPlayers()`.
- Produces: `Neverbirth.Everchanging.StyleRegistry` and `Neverbirth.EverchangingTestAPI`.

- [ ] **Step 1: Extend the test harness**

Player stubs expose `GetCollectibleNum`, `GetCollectibleRNG`, `AddNullCostume`, `TryRemoveNullCostume`, `GetPlayerType`, `GetSprite():GetFilename()`, `GetData`, and distinct `InitSeed` values. Stub the banana path to costume id 17495 and Stranger to PlayerType 777.

- [ ] **Step 2: Add failing lifecycle/RNG assertions**

Test: first pickup stores and applies `blue_banana_peel`; room/floor/continue restoration does not draw again; a second copy keeps the only style; zero copies removes it; two players have isolated state; new run clears state; continue keeps style; Stranger/nonstandard skeletons draw and save but do not apply; missing resources and empty registry safely fall back.

Key assertions:

```lua
first.collectibles[everchangingId] = 1
api.Callbacks.PlayerUpdate(nil, first)
assertEquals(api.GetPlayerState(first).styleId, "blue_banana_peel")
assertEquals(first.added[1], 17495)
api.Callbacks.NewRoom(nil)
api.Callbacks.PlayerUpdate(nil, first)
assertEquals(first.rng.calls, 1, "room change must not redraw")
```

- [ ] **Step 3: Add item lookup and saved-data initialization**

Add `Everchanging = { "Everchanging", "千变万化" }` to `ITEM_NAME_CANDIDATES`, resolve `Items.Everchanging`, ensure `musicboxSaveData.everchanging` is a table, and add mechanical text through the existing optional EID registration.

- [ ] **Step 4: Implement the explicit registry**

```lua
local STYLE_SPECS = {
    {
        id = "blue_banana_peel",
        slots = { "head" },
        resources = {
            head = { costume = "gfx/characters/costume_blue_banana_peel.anm2" },
        },
        full = false,
        metadata = { source = "existing_blue_banana_peel_costume" },
    },
}
```

Implement:

```lua
local function BuildStyleRegistry(specs) end
local function ResolveStyleCostumes(style) end
local function SelectStyle(player, currentStyleId, registry) end
```

`BuildStyleRegistry` rejects duplicate IDs, invalid/duplicate slots, mixed `full` layouts, and missing `resources[slot].costume`. Invalid rows are logged and excluded.

- [ ] **Step 5: Implement run-persistent player state**

Implement `ResetEverchangingRunState`, `GetEverchangingRunState`, `GetEverchangingPlayerKey`, and `GetEverchangingPlayerState`. Saved rows contain only `knownCopies`, `styleId`, and `rollCount`. Runtime `GetData` rows contain `appliedStyleId`, `appliedCostumeIds`, and `dirty`.

- [ ] **Step 6: Implement compatibility and costume ownership**

`IsCompatiblePlayer(player)` rejects the resolved Stranger PlayerType and accepts only normalized sprite filenames ending in `001.000_player.anm2`. Incompatible holders still draw/save a style.

Everchanging records every costume ID it applies and removes only those recorded IDs when its style is cleared. The removed pill-earned system no longer shares ownership of costume 17495.

- [ ] **Step 7: Implement copy-delta processing and finite reapplication**

Implement `ApplyEverchangingStyle`, `ClearEverchangingStyle`, `SyncEverchangingPlayer`, and `MarkAllEverchangingPlayersDirty`. `SyncEverchangingPlayer` reads only `GetCollectibleNum(Items.Everchanging)` and draws once per positive copy delta.

Register callbacks with the exact signatures:

```lua
local function OnEverchangingPlayerUpdate(_, player) return nil end
local function OnEverchangingPlayerInit(_, player) return nil end
local function OnEverchangingNewRoom(_) return nil end
local function OnEverchangingNewLevel(_) return nil end
local function OnEverchangingGameStarted(_, isContinued) return nil end
```

Use `MC_POST_PEFFECT_UPDATE` for per-player O(1) sync and mark dirty on player init/new room/new level/game start. Do not register `MC_EVALUATE_CACHE`.

- [ ] **Step 8: Expose the test API and pass the test**

Expose `StyleSpecs`, `Registry`, `BuildStyleRegistry`, `SelectStyle`, `IsCompatiblePlayer`, `GetPlayerState`, `SyncPlayer`, `ResetRunState`, and the five callback handlers under `Neverbirth.EverchangingTestAPI`.

Run the Everchanging behavior test. Expected: registry, RNG, state, compatibility, resource fallback, costume cleanup, and no-repeat-apply assertions pass.

### Task 3: Static validation and handoff

**Files:**
- Verify: `main.lua`, `content/items*.xml`, `content/itempools*.xml`, `generated/neverbirth_collectibles.lua`, the existing banana costume assets, `Everchanging.png`, and tests.

**Interfaces:**
- Consumes: completed Tasks 1-2.
- Produces: static evidence and a separate in-game checklist.

- [ ] **Step 1: Parse Lua and run focused tests**

```powershell
C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe -p main.lua
C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\everchanging_behavior_test.lua
C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\blue_banana_peel_skin_behavior_test.lua
C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\localization_test.lua
```

Expected: all four commands pass.

- [ ] **Step 2: Run generic and project validators**

```powershell
powershell -ExecutionPolicy Bypass -File docs\skills\isaac-validators\scripts\validate-isaac-mod.ps1 -Root . -ModObjectName Neverbirth
powershell -ExecutionPolicy Bypass -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .
```

Expected: no new missing-path, locale-parity, callback, or costume linkage failures.

- [ ] **Step 3: Parse XML and check diff hygiene**

Parse all six item/pool XML files with PowerShell `[xml]` and run the bundled Git `diff --check`. Expected: all parse and changed lines have no whitespace errors.

- [ ] **Step 4: Report proof and in-game boundaries**

Report modified files, local id 38, registry schema, callbacks, saved fields, deterministic draw boundary, banana costume cleanup, and every test result.

Keep these as in-game checks: console pickup, four facing directions, damage flash, invincibility blink, ordinary costume layering, item removal, death/revive, continue, co-op isolation, and Stranger/nonstandard-character safety.
