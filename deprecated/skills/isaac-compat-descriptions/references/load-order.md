> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-compat-descriptions/references/load-order.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Load Order And Module Organization

Use this when adding description or compatibility files.

## Rules

- Load core helpers before content modules that depend on them.
- Load text/description modules after ids exist or in the same style the repo already uses.
- Guard optional integration modules at the entry point or inside the module before API calls.
- Keep compatibility files separate from item mechanics when the integration is non-trivial.
- Do not spread one integration across many unrelated files unless the repo already has that structure.

## Review Checklist

- Include/require path matches the file location.
- Missing optional dependency does not crash.
- Re-loading does not register duplicate callbacks unnecessarily.
- Language files are only loaded when their APIs are available.

