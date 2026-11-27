---
name: isaac-neverbrith-validator-profile
description: "Use when verifying a confirmed neverbrith checkout or diagnosing its strict static checks for XML, entity assets, localized pools, generated collectible registration, or Neverbirth callbacks. 中文触发：neverbrith 检查、严格校验、实体链、道具池语言一致性、生成登记。"
---

> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../.agents/skills/isaac-neverbrith-validator-profile/SKILL.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Neverbrith Validator Profile

Read the repository's [project index](../../agent/index.md) and [verification guide](../../agent/testing.md).

From the confirmed mod root, use PowerShell 7:

```powershell
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile Pilot
```

Use `LuaAll` or targeted checks when the project's guide calls for them. The
unified entry runs the repository copies of the generic and strict validators
alongside the selected behavior checks. For a static-only investigation or an
explicit `-GameRoot`, use the repository script and documented invocation in
the guide. If the checkout or runner is unavailable, report the blocked check
and evidence gap.

The [strict script](scripts/validate-neverbrith.ps1) is maintained here. The
verification guide owns scan limitations, exit codes, and required evidence.
