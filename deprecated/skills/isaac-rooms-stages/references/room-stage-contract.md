> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-rooms-stages/references/room-stage-contract.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Room And Stage Contract

Before code, make these facts explicit:

- How the room/stage is registered or discovered.
- Which official callbacks establish entry, exit, and level transitions.
- Exact selection predicate and whether it is deterministic.
- Which grids, doors, entities, or rewards the mechanic owns.
- Room-local, floor-local, run-local, and saved state boundaries.
- Required and optional third-party libraries, with official fallback when
  possible.

For a replacement route, validate all targets before mutating the original
room content. On failure preserve the original content or skip only the owned
addition.

Track selection attempt, mutation success, and optional retry policy as
separate facts. Set a once-per-room/floor success marker only after the owned
mutation is complete; missing or vanished targets do not consume it by
default.
