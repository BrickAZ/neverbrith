> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-trinkets/references/trinket-behavior.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Trinket Behavior

Route trinket behavior by what the trinket actually does.

## Routes

- Stat changes: cache flags and `MC_EVALUATE_CACHE`.
- Damage changes: damage interception rules.
- Drop or pickup changes: pickup/spawn callbacks.
- Room effects: room/floor/run state lifecycle.
- Entity interaction: entity skill plus state lifecycle.
- Visual/audio feedback: anm2 and audio/render skills.

## Caution

Trinket checks often run every frame. Avoid spawning, adding stats, or mutating state repeatedly without guards.
