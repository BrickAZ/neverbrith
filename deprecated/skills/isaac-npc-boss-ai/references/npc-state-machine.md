> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-npc-boss-ai/references/npc-state-machine.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# NPC State Machine Contract

Use explicit states rather than a growing set of unrelated booleans.

For each state specify:

- Entry event and guard.
- Verified animation.
- Update behavior and target selection.
- Spawned owned entities, projectiles, or effects.
- Interruption and damage policy.
- Exit condition and next state.

For a Boss phase, also specify health threshold, one-time entry gate, room
clear/death behavior, and whether projectiles/minions survive the transition.

Keep visual animation, AI state, and room lifecycle separate. A visual frame
completion may trigger a transition only when the contract explicitly says so.

Treat labels such as “chase” and “charge” as contract vocabulary, not existing
Lua fields. Resolve actual fields, callbacks, and any stable entity-key helper
from the project. A user-provided threshold is locked; do not relabel it as
`TBD` merely because its implementation details are unknown.
