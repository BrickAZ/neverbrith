> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-testing-debugging/references/verification-layers.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Verification Layers

Use the cheapest reliable proof first.

## Static

Run validators for XML, paths, ids, language shape, and skill metadata.

## Scripted

Use tests under `tests/` for logic that can be isolated from Isaac runtime. Add a focused test when a bug is likely to regress.

## Instrumented

Use temporary logs or debug flags only when the symptom cannot be reproduced by static or local tests. Remove temporary instrumentation before final handoff.

## In-Game

Required for:

- Render order and screen/world coordinates.
- Shader behavior.
- Input interception.
- Collision and physics.
- Pickup visuals.
- Challenge start conditions.
- Save/reload behavior.

Report in-game checks as concrete steps, not vague advice.
