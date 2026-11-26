> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-state-lifecycle/references/state-review-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# State Review Checklist

Before finalizing stateful work, verify:

- Each state field has exactly one owner.
- Each state table has a bounded lifetime or cleanup point.
- Player state is keyed safely for co-op and twins where relevant.
- Entity state disappears or is cleaned when the entity disappears.
- Room/floor/run/challenge reset behavior is explicit.
- Saved data contains only plain serializable data.
- Reload does not duplicate effects or lose required persistent state.
- Gameplay mutation does not live in render-only callbacks.
- Tests or manual checks include transition cases, not only first-use behavior.
