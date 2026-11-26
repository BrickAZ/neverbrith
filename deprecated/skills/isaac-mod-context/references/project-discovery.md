> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-mod-context/references/project-discovery.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Project Discovery

## Stable Facts To Collect

| Surface | Inspect | Record |
| --- | --- | --- |
| Mod identity | `RegisterMod` call | Lua object variable, display name, bootstrap file |
| Code layout | bootstrap plus module folders | behavior owner and directories to scan |
| Content | existing XML files | exact file names, not assumed categories |
| Localization | file suffixes | every actual locale and matching content type |
| Verification | scripts and tests | command, runtime, and unavailable checks |

## Ambiguity Rules

- A `main.lua` file can be bootstrap, behavior owner, or both. Record which is
  observed; do not infer the destination for new code from its existence.
- A custom wrapper around `RegisterMod` or callback registration may hide the
  real object name. Record the wrapper and route to architecture/callback
  review rather than guessing.
- A missing XML file can mean the project does not use that content type, not
  that the file should be created.
- A missing translated file means localization scope is unknown until the user
  or project conventions decide it.
