> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-mod-architecture/references/architecture-review-checklist.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Architecture Review Checklist

Before finalizing architecture work, verify:

- The change was needed for the current task.
- File boundaries follow content identity or real shared behavior.
- Load order is explicit.
- Callback ownership is easy to trace.
- No unrelated content was refactored.
- Existing tests still pass where runnable.
- Static validators run after moving paths or XML references.
- The final report names any cleanup intentionally left for later.
