> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-mod-architecture/references/shared-helpers.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Shared Helpers And Constants

Shared helpers are useful when they make repeated logic safer.

## Good Shared Helpers

- Stable id lookup tables.
- Player key helpers.
- State reset helpers.
- XML/language helper scripts.
- Validator scripts.
- Debug logging wrappers that can be disabled.

## Rules

- Keep helpers small and named by what they do.
- Avoid helper modules that import every content module.
- Do not create helpers for one-off behavior.
- Keep constants close to the content type unless many modules need them.
