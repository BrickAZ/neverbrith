# Certificate Virtual Dimension Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the Certificate's Red Room network with a dependency-free, project-owned linear virtual room chain using one debug-room carrier entry per outer session.

**Architecture:** The existing generated collectible registry, session stack, pickup confirmation, and registered return effect remain. External entry creates the carrier once with `goto s.default.2`; virtual nodes are stable page indices of 32 items, and previous/next mechanisms reload owned content inside the carrier without another command. Return uses the saved origin room and engine dimension.

**Tech Stack:** Repentance Lua API, project `main.lua`, Lua behavior test stubs, existing `Certificate Return Portal` entity.

## Global Constraints

- Ordinary Repentance is the supported runtime.
- No StageAPI, REPENTOGON, MinimapAPI, or other required dependency.
- Never call `MakeRedRoomDoor` from the Certificate subsystem.
- Never target or mutate engine dimension 2 and never invoke Death Certificate.
- Execute `goto s.default.2` once per outer entry and never during previous/next navigation.
- Use a linear chain and a central reusable return mechanism in every node.
- Maximum 32 collectible pedestals per virtual node.
- Preserve unrelated working-tree changes and do not refactor other systems.

---

### Task 1: Replace Red Room expectations with failing virtual-chain tests

**Files:**
- Modify: `tests/certificate_of_neverbirth_behavior_test.lua`

**Interfaces:**
- Consumes: `Neverbirth.CertificateOfNeverbirthTestAPI` from `main.lua`.
- Produces: required test API functions `GetVirtualEdges(session, pageIndex)` and existing callbacks `UseItem`, `NewRoom`, `PickupCollision`, `Update`.

- [ ] **Step 1: Change static assertions to require the approved carrier and forbid Red Rooms**

```lua
assertEquals(block:find("MakeRedRoomDoor", 1, true), nil, "Certificate must not allocate Red Rooms")
assertTruthy(block:find('goto s.default.2', 1, true), "outer entry must create the approved carrier")
assertTruthy(block:find("GetVirtualEdges", 1, true), "runtime exposes linear virtual edges")
assertEquals(block:find("galleryRoomIndices", 1, true), nil, "virtual nodes must not masquerade as engine rooms")
```

- [ ] **Step 2: Add page-count and edge tests**

```lua
local counts = { {1, 1}, {32, 1}, {33, 2}, {65, 3} }
for _, pair in ipairs(counts) do
    local rows = {}
    for index = 1, pair[1] do rows[index] = resolved[((index - 1) % #resolved) + 1] end
    local session = api.NewSession("edge-test", 10, 0, Vector(0, 0), rows)
    assertEquals(api.GetPageCount(session), pair[2], "virtual page count")
end
local first = api.GetVirtualEdges(sessionA, 1)
assertEquals(first.previous, nil, "first node has no previous edge")
assertEquals(first.next, 2, "first node links to node two")
local last = api.GetVirtualEdges(sessionA, 2)
assertEquals(last.previous, 1, "last node links to node one")
assertEquals(last.next, nil, "last node has no next edge")
```

- [ ] **Step 3: Replace the runtime Red Room stub with one command-backed carrier**

The test records `Isaac.ExecuteCommand` calls, sets `currentRoomIndex = -3` when
the command is `goto s.default.2`, and invokes `callbacks.NewRoom({})`. It must
not provide `level:MakeRedRoomDoor`.

- [ ] **Step 4: Add failing runtime assertions**

```lua
assertEquals(#executedCommands, 1, "outer entry creates the carrier once")
assertEquals(firstGallerySession.galleryPageIndex, 1, "entry starts on node one")
assertEquals(#activeGalleryPortals("return"), 1, "every node has a return mechanism")
assertEquals(#activeGalleryPortals("previous"), 0, "first node has no previous mechanism")
assertEquals(#activeGalleryPortals("next"), 1, "first node has a next mechanism")
armAndEnterPortal("next", playerA)
assertEquals(firstGallerySession.galleryPageIndex, 2, "next mechanism loads node two")
assertEquals(#executedCommands, 1, "virtual navigation does not execute goto")
assertEquals(#activeGalleryPortals("previous"), 1, "last node has a previous mechanism")
```

- [ ] **Step 5: Run the focused test and verify RED**

Run: `C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe tests\certificate_of_neverbirth_behavior_test.lua`

Expected: failure because current runtime still contains `MakeRedRoomDoor` and does not expose the approved virtual-chain behavior.

### Task 2: Implement pure virtual-node helpers and owned mechanisms

**Files:**
- Modify: `main.lua` inside `CERTIFICATE_OF_NEVERBIRTH_BEGIN/END` only.
- Test: `tests/certificate_of_neverbirth_behavior_test.lua`

**Interfaces:**
- Consumes: existing `getPageCount`, `getPageRows`, portal spawn/find helpers, session stack, and generated registry.
- Produces: `getVirtualEdges(session, pageIndex) -> { previous = integer|nil, next = integer|nil }`, `spawnGallery(session)`, and role-tagged `previous`, `next`, `return` mechanisms.

- [ ] **Step 1: Remove real-map allocation state**

Delete Red Room constants, `tryCreateConnectedRoom`, `buildGalleryNetwork`, `applyGalleryNetwork`, `galleryRoomIndices`, `galleryPageByRoom`, and the persistent `galleryNetwork` cache. Define:

```lua
local GALLERY_ROOM_INDEX = (GridRooms and GridRooms.ROOM_DEBUG_IDX) or -3
local GALLERY_ROOM_COMMAND = "goto s.default.2"
local VIRTUAL_TRANSITION_FRAMES = 6
local ARRIVAL_LOCKOUT_FRAMES = 10
```

- [ ] **Step 2: Implement stable linear edges**

```lua
local function getVirtualEdges(session, pageIndex)
    local count = getPageCount(session)
    pageIndex = math.max(1, math.min(count, math.floor(tonumber(pageIndex) or 1)))
    return {
        previous = pageIndex > 1 and pageIndex - 1 or nil,
        next = pageIndex < count and pageIndex + 1 or nil,
    }
end
```

- [ ] **Step 3: Spawn one central return mechanism plus legal side mechanisms**

`spawnGallery` clears the controlled carrier, spawns at most 32 page rows, then spawns `return` and only the roles returned by `getVirtualEdges`. Each entity is tagged with session token, role, and target page. Set `session.portalArmedFrame = state.frame + ARRIVAL_LOCKOUT_FRAMES`.

- [ ] **Step 4: Expose `GetVirtualEdges` through the existing test API**

```lua
GetVirtualEdges = getVirtualEdges,
```

- [ ] **Step 5: Run the focused test**

Expected: static/edge assertions pass; runtime navigation remains RED until Task 3 implements transition processing.

### Task 3: Implement carrier entry, virtual transitions, nested use, and return

**Files:**
- Modify: `main.lua` inside the Certificate block only.
- Test: `tests/certificate_of_neverbirth_behavior_test.lua`

**Interfaces:**
- Consumes: `GALLERY_ROOM_INDEX`, `GALLERY_ROOM_COMMAND`, `getVirtualEdges`, existing origin snapshot and return helpers.
- Produces: `executeGalleryCommand()`, `beginVirtualRoomChange(session, targetPage)`, and `processVirtualTransition()`.

- [ ] **Step 1: Add guarded outer carrier entry**

```lua
local function executeGalleryCommand()
    if not Isaac or type(Isaac.ExecuteCommand) ~= "function" then return false end
    return pcall(function() Isaac.ExecuteCommand(GALLERY_ROOM_COMMAND) end) == true
end
```

`useItem` validates registry, portal variant, room, player, and 32-slot layout before pushing the session. If the current top session is already active in `GALLERY_ROOM_INDEX`, create the nested session and call `spawnGallery` directly without `goto`; otherwise execute the command exactly once.

- [ ] **Step 2: Implement delayed in-carrier node changes**

```lua
local function beginVirtualRoomChange(session, targetPage)
    if not session or state.transition then return false end
    local edges = getVirtualEdges(session, session.galleryPageIndex)
    if targetPage ~= edges.previous and targetPage ~= edges.next then return false end
    state.transition = {
        mode = "virtual", token = session.token, targetPage = targetPage,
        readyFrame = state.frame + VIRTUAL_TRANSITION_FRAMES,
    }
    removeGalleryPortals(session)
    return true
end
```

`processVirtualTransition` verifies the same active token, sets the target page, spawns the target node, positions players at the opposite side, clears the transition, and saves. A guarded `game:Darken(1, VIRTUAL_TRANSITION_FRAMES)` may provide the bounded transition without another room command.

- [ ] **Step 3: Route role collision in `update`**

Return calls `beginReturn`. Previous and next call `beginVirtualRoomChange` with the stored target. Normal update returns `nil`.

- [ ] **Step 4: Make `newRoom` recognize only the controlled carrier**

Entering `GALLERY_ROOM_INDEX` with phase `entering` or an active saved session spawns the current virtual node. Returning to the saved origin finishes return. Unexpected destinations trigger the existing safe-return route rather than cleaning unrelated room content.

- [ ] **Step 5: Verify GREEN**

Run the focused Lua test. Expected: all virtual navigation, repeated return, nested session, collection persistence, and callback-return assertions pass.

### Task 4: Static isolation and regression verification

**Files:**
- Verify: `main.lua`
- Verify: `tests/certificate_of_neverbirth_behavior_test.lua`

**Interfaces:**
- Consumes: completed runtime and focused behavior test.
- Produces: fresh verification evidence and an in-game handoff list.

- [ ] **Step 1: Parse Lua**

Run: `C:\Users\Anton\AppData\Local\Programs\Lua\bin\luac.exe -p main.lua`

Expected: exit code 0 with no output.

- [ ] **Step 2: Run focused and localization tests**

Run the Certificate behavior test and `tests\localization_test.lua` with the installed Lua executable. Expected: both exit 0.

- [ ] **Step 3: Run all Lua behavior tests**

Run every `tests\*_test.lua` file individually. Expected: zero failures.

- [ ] **Step 4: Run XML and diff checks**

Parse every `content\*.xml`, run `git diff --check`, and inspect the Certificate block for `MakeRedRoomDoor`, Death Certificate calls, StageAPI, REPENTOGON, and extra `goto` command sites.

- [ ] **Step 5: Report runtime-only checks separately**

Require in-game confirmation of outer entry, room-one next mechanism, room-two previous mechanism, central return from every node, repeated reuse, nested use, co-op, save/continue, unexpected teleport, and same-run vanilla Death Certificate isolation. Do not label these statically verified.
