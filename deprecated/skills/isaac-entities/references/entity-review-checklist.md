> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-entities/references/entity-review-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Entity Review Checklist

Before finalizing entity work, verify:

- The entity really needs registration or behavior ownership.
- XML registration and Lua id lookup match.
- Type/variant/subtype values are not guessed.
- ANM2 path, spritesheet paths, and animation names are real.
- Spawn/update/remove callbacks are all accounted for.
- Collision and damage cannot accidentally fire every frame without a guard.
- State stored in `GetData()` or local tables has a clear cleanup path.
- Persistent data, if any, is plain serialized data and not live userdata.
- In-game checks cover spawning, room transition, save/reload if relevant, and disappearance/removal.
