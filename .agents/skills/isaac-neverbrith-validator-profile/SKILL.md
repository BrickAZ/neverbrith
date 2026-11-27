---
name: isaac-neverbrith-validator-profile
description: "Use when verifying a confirmed neverbrith checkout or diagnosing its strict static checks for XML, entity assets, localized pools, generated collectible registration, or Neverbirth callbacks. 中文触发：neverbrith 检查、严格校验、实体链、道具池语言一致性、生成登记。"
---

# Neverbrith Validator Profile

Confirm the target checkout with `isaac-mod-context`. Read its `AGENTS.md`,
`docs/agent/index.md` and `docs/agent/testing.md`. The target repository owns
the current commands, profiles, scanner, and regression coverage.

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

The installed script path exists for legacy callers only and forwards to
`tools/validators/validate-neverbrith.ps1` in the supplied checkout. The project
runner checks the authoritative `.agents/skills` package, never the archived
`docs/skills` copy. Consult the repository guide for scan limitations, exit codes,
and any required in-game evidence.
