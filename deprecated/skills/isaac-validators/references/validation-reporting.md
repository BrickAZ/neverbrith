> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-validators/references/validation-reporting.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Validation Reporting

Use concise, factual reporting.

## Template

```markdown
## Validation

- Command:
- Result:
- Failures:
- Warnings:
- Pre-existing/unrelated:
- Manual checks:
```

## Language

- Say "static validation passed" only when the validator exits successfully.
- Say "in-game verification still needed" for render, input, collision, shader, and callback-timing behavior.
- If failures are outside the current task, do not hide them. Mark them as unrelated so the user is not surprised later.
