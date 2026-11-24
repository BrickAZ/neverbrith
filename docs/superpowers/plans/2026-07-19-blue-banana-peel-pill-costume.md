# Blue Banana Peel Pill Costume Implementation Plan

> **For Codex:** Implement this plan inline with test-driven development. Do not use subagents unless the user explicitly asks for delegation.

**Goal:** Replace the current automatic all-player Blue Banana Peel costume grant with a run-persistent, per-player unlock earned by actually consuming any normal or horse pill. Mimicked pill effects do not count.

**Architecture:** Store earned player keys under the existing `musicboxSaveData` run data, keyed by `tostring(player.InitSeed or "")`. `MC_USE_PILL` is the only earning event. Existing player lifecycle callbacks merely synchronize the already-earned costume after continuation, room changes, revive, or player reconstruction; they never create entitlement.

**Tech Stack:** Repentance Lua callbacks, existing save helpers in `main.lua`, existing `costumes2.xml` null costume registration, Lua behavior tests.

---

## Locked behavior and non-goals

- Only the player who actually consumed the pill earns the costume.
- Normal pills and horse pills count.
- `UseFlag.USE_MIMIC` usages, including Placebo-like effects, do not count.
- The unlock persists for the current run, including room/floor changes, revival, co-op rejoin, and continued saves.
- A fresh run clears all Blue Banana Peel entitlements.
- Repeated qualifying pill uses are idempotent.
- Keep the existing costume asset, costume XML id `17495`, and `priority="98"` unchanged.
- Do not modify unrelated items, costume art, ANM2 layers, or localization.

## Task 1: Add the failing behavior contract

**Files:**

- Modify: `tests/localization_test.lua`
- Create: `tests/blue_banana_peel_skin_behavior_test.lua`

### Step 1: Extend the shared test callback surface

Add only the callback/constants needed to load and exercise the production block:

```lua
ModCallbacks.MC_USE_PILL = ModCallbacks.MC_USE_PILL or 10
ModCallbacks.MC_POST_PEFFECT_UPDATE = ModCallbacks.MC_POST_PEFFECT_UPDATE or 11
ModCallbacks.MC_POST_GAME_STARTED = ModCallbacks.MC_POST_GAME_STARTED or 12
ModCallbacks.MC_PRE_GAME_EXIT = ModCallbacks.MC_PRE_GAME_EXIT or 13

UseFlag = UseFlag or {
    USE_MIMIC = 1,
}
```

Do not change existing callback numbers or unrelated test stubs.

### Step 2: Add a focused player/costume test harness

Create `tests/blue_banana_peel_skin_behavior_test.lua`. Load the existing project harness, provide a deterministic costume id, and create independent players:

```lua
dofile("tests/localization_test.lua")

Isaac.GetCostumeIdByPath = function(path)
    assert(path == "gfx/characters/costume_blue_banana_peel.anm2")
    return 17495
end

local function makePlayer(seed)
    local data = {}
    return {
        InitSeed = seed,
        addedCostumes = 0,
        removedCostumes = 0,
        GetData = function()
            return data
        end,
        AddNullCostume = function(self, costumeId)
            assert(costumeId == 17495)
            self.addedCostumes = self.addedCostumes + 1
        end,
        TryRemoveNullCostume = function(self, costumeId)
            assert(costumeId == 17495)
            self.removedCostumes = self.removedCostumes + 1
        end,
    }
end
```

Use `Neverbirth.BlueBananaPeelSkinTestAPI` rather than reaching into unrelated state.

### Step 3: Assert the complete behavior contract

The test must prove all of the following:

```lua
local api = assert(Neverbirth.BlueBananaPeelSkinTestAPI)
local first = makePlayer(101)
local second = makePlayer(202)

api.ResetRunState()
assert(api.Callbacks.PlayerUpdate(nil, first) == nil)
assert(first.addedCostumes == 0, "costume must not be granted automatically")

assert(api.Callbacks.UsePill(nil, 1, first, 0) == nil)
assert(api.IsEarned(first))
assert(not api.IsEarned(second))
assert(first.addedCostumes == 1)
assert(second.addedCostumes == 0)

assert(api.Callbacks.UsePill(nil, 1, second, UseFlag.USE_MIMIC) == nil)
assert(not api.IsEarned(second), "mimicked pill effects must not count")

assert(api.Callbacks.UsePill(nil, 2049, first, 0) == nil)
assert(first.addedCostumes == 1, "horse/repeated pill use must be idempotent")

api.ClearRuntimeCostumeFlag(first)
assert(api.Callbacks.GameStarted(nil, true) == nil)
assert(first.addedCostumes == 2, "continue must restore earned costume")
assert(second.addedCostumes == 0)

assert(api.Callbacks.GameStarted(nil, false) == nil)
api.ClearRuntimeCostumeFlag(first)
assert(api.Callbacks.PlayerUpdate(nil, first) == nil)
assert(not api.IsEarned(first), "fresh run must clear entitlement")
assert(first.addedCostumes == 2)
```

Also read the existing resource files and assert:

- `content/costumes2.xml` still registers id `17495`, the Blue Banana Peel ANM2, and `priority="98"`.
- `costume_blue_banana_peel.anm2` still references the existing PNG and has all four head directions.
- PNG IHDR remains `256x32`, RGBA color type 6.

### Step 4: Run the new test and confirm it fails for the current automatic implementation

Run:

```powershell
C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\blue_banana_peel_skin_behavior_test.lua
```

Expected before production changes: failure because the existing player update callback grants the costume without pill consumption and there is no qualifying `MC_USE_PILL` entitlement path.

## Task 2: Add run-persistent per-player entitlement

**Files:**

- Modify: `main.lua`

### Step 1: Initialize the save namespace with the existing save data

Inside `EnsureMusicboxDataLoaded()`, add only this namespace initialization near the other run-state tables:

```lua
if type(musicboxSaveData.blueBananaPeel) ~= "table" then
    musicboxSaveData.blueBananaPeel = {}
end
```

### Step 2: Replace the automatic-grant block with entitlement helpers

Within `-- BLUE_BANANA_PEEL_SKIN_BEGIN` / `END`, keep the existing asset path and lazy costume-id lookup. Replace the automatic award logic with:

```lua
local function GetBlueBananaPeelPlayerKey(player)
    return tostring(player and player.InitSeed or "")
end

local function ResetBlueBananaPeelRunState()
    EnsureMusicboxDataLoaded()
    musicboxSaveData.blueBananaPeel = {
        runSeed = GetCurrentRunSeed(),
        players = {},
    }
    SaveMusicboxData()
    return musicboxSaveData.blueBananaPeel
end

local function GetBlueBananaPeelRunState()
    EnsureMusicboxDataLoaded()
    local state = musicboxSaveData.blueBananaPeel
    if type(state) ~= "table"
        or tostring(state.runSeed or "") ~= tostring(GetCurrentRunSeed() or "") then
        return ResetBlueBananaPeelRunState()
    end
    if type(state.players) ~= "table" then
        state.players = {}
    end
    return state
end

local function IsBlueBananaPeelEarned(player)
    local key = GetBlueBananaPeelPlayerKey(player)
    return key ~= "" and GetBlueBananaPeelRunState().players[key] == true
end

local function EarnBlueBananaPeel(player)
    local key = GetBlueBananaPeelPlayerKey(player)
    if key == "" then
        return false
    end
    local state = GetBlueBananaPeelRunState()
    if state.players[key] == true then
        return false
    end
    state.players[key] = true
    SaveMusicboxData()
    return true
end
```

This uses the project’s established player key and existing run-save mechanism. It does not scan players’ inventories or add a second save file.

### Step 3: Make costume synchronization entitlement-only and idempotent

```lua
local function ApplyBlueBananaPeelSkin(player)
    if not player or not IsBlueBananaPeelEarned(player) then
        return false
    end
    local data = player:GetData()
    if data[BLUE_BANANA_PEEL_PLAYER_FLAG] then
        return false
    end
    local costumeId = GetBlueBananaPeelCostumeId()
    if not costumeId then
        return false
    end
    player:AddNullCostume(costumeId)
    data[BLUE_BANANA_PEEL_PLAYER_FLAG] = true
    return true
end

local function ClearBlueBananaPeelRuntimeCostumeFlag(player, removeCostume)
    if not player then
        return
    end
    local data = player:GetData()
    data[BLUE_BANANA_PEEL_PLAYER_FLAG] = nil
    if removeCostume then
        local costumeId = GetBlueBananaPeelCostumeId()
        if costumeId and player.TryRemoveNullCostume then
            player:TryRemoveNullCostume(costumeId)
        end
    end
end
```

`MC_POST_PEFFECT_UPDATE` may call `ApplyBlueBananaPeelSkin(player)` repeatedly, but the entitlement check and runtime flag make it stable.

### Step 4: Register the real-pill callback with the correct argument order

The Repentance callback method signature used here is:

```lua
function(mod, pillEffect, player, useFlags)
```

Implement:

```lua
local function HasBlueBananaPeelUseFlag(useFlags, flag)
    useFlags = tonumber(useFlags) or 0
    flag = tonumber(flag) or 0
    return flag > 0 and (useFlags & flag) ~= 0
end

local function OnBlueBananaPeelUsePill(_, pillEffect, player, useFlags)
    local mimicFlag = UseFlag and UseFlag.USE_MIMIC or 0
    if not player or HasBlueBananaPeelUseFlag(useFlags, mimicFlag) then
        return nil
    end
    EarnBlueBananaPeel(player)
    ApplyBlueBananaPeelSkin(player)
    return nil
end

Neverbirth:AddCallback(ModCallbacks.MC_USE_PILL, OnBlueBananaPeelUsePill)
```

Do not filter by pill effect id: horse pill variants must count. The callback must always return `nil` so it does not interfere with the pill effect.

### Step 5: Reset on fresh runs and restore on continuations

```lua
local function OnBlueBananaPeelGameStarted(_, isContinued)
    if not isContinued then
        ResetBlueBananaPeelRunState()
    else
        GetBlueBananaPeelRunState()
    end

    for _, player in ipairs(GetPlayers()) do
        ClearBlueBananaPeelRuntimeCostumeFlag(player, not IsBlueBananaPeelEarned(player))
        ApplyBlueBananaPeelSkin(player)
    end
    return nil
end
```

Keep the existing `MC_POST_PEFFECT_UPDATE` path (or its project fallback) only as a synchronization path:

```lua
local function OnBlueBananaPeelPlayerUpdate(_, player)
    ApplyBlueBananaPeelSkin(player)
    return nil
end
```

Expose only focused test hooks:

```lua
Neverbirth.BlueBananaPeelSkinTestAPI = {
    CostumePath = BLUE_BANANA_PEEL_COSTUME_PATH,
    IsEarned = IsBlueBananaPeelEarned,
    Earn = EarnBlueBananaPeel,
    Apply = ApplyBlueBananaPeelSkin,
    ResetRunState = ResetBlueBananaPeelRunState,
    ClearRuntimeCostumeFlag = ClearBlueBananaPeelRuntimeCostumeFlag,
    Callbacks = {
        UsePill = OnBlueBananaPeelUsePill,
        PlayerUpdate = OnBlueBananaPeelPlayerUpdate,
        GameStarted = OnBlueBananaPeelGameStarted,
    },
}
```

## Task 3: Verify the implementation and inspect the patch boundary

**Files:**

- Verify: `main.lua`
- Verify: `tests/blue_banana_peel_skin_behavior_test.lua`
- Verify unchanged contracts: `content/costumes2.xml`, `resources/gfx/characters/costume_blue_banana_peel.anm2`, `resources/gfx/characters/costumes/costume_blue_banana_peel.png`

### Step 1: Run Lua syntax validation

```powershell
C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe -p main.lua
```

Expected: exit code 0 and no output.

### Step 2: Run the focused test

```powershell
C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\blue_banana_peel_skin_behavior_test.lua
```

Expected: all Blue Banana Peel behavior and asset assertions pass.

### Step 3: Run existing regression validators

```powershell
C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\localization_test.lua
powershell -ExecutionPolicy Bypass -File docs\skills\isaac-neverbrith-validator-profile\scripts\validate-neverbrith.ps1 -Root .
git diff --check
```

Expected: no new failures. Existing unrelated warnings must be reported separately and not silently attributed to this feature.

### Step 4: Review exact callback and mutation boundaries

Confirm from the final diff:

- `MC_USE_PILL` is the only path that changes entitlement from false to true.
- Mimic use flags return `nil` without earning.
- Player update callbacks only synchronize already-earned costumes.
- Fresh run clears the saved player map; continuation preserves it.
- No inventory scans, all-player awards, unrelated item edits, ANM2 edits, or PNG edits were introduced.
- All callback handlers return `nil` unless their callback contract requires otherwise.

### Step 5: Do not commit unrelated dirty work

The shared checkout already contains unrelated user changes, especially in `main.lua`. Stage or commit nothing unless the final diff can isolate only this feature’s hunks without including pre-existing changes. Report the modified files and leave the worktree intact.

## Required in-game checks after static verification

1. One player consumes a normal pill: only that player receives the head costume immediately.
2. Placebo/mimic activation does not grant it.
3. A horse pill grants it.
4. Room/floor transitions, revival, and co-op rejoin preserve it.
5. Save/continue restores it to the correct player.
6. Starting a fresh run does not inherit it.
7. Priority 98 visually places the headwear above competing costumes as intended; this cannot be fully proven by static tests alone.
