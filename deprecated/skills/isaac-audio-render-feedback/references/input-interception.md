> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-audio-render-feedback/references/input-interception.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Input Interception

Use this when feedback temporarily blocks controls, consumes input, or creates a modal popup/menu.

## Hard Rules

- Do not block all controls unless the design explicitly says the game should pause or modal-lock.
- Use Isaac action constants where possible.
- Define release conditions: timer, confirmation, cancellation, room transition, game end.
- Be careful with priority callbacks; state why early/late priority is needed.
- Restore normal input even if the player changes room or exits the run.

## Prompt Checklist

- Action(s) to intercept.
- Hook mode.
- Priority.
- Owner state.
- Release condition.
- Multiplayer behavior.

