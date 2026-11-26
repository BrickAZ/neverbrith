> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-trinkets/references/trinket-registration.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Trinket Registration

Use this when adding or reviewing trinket XML.

## Check First

- Does `content/trinkets.xml` exist?
- Do language variants exist?
- Is the internal name stable and English-style like the rest of the mod?
- Is the display text present in every language surface the repo uses?
- Does the trinket need an icon, costume, or EID entry?

## Rules

- Keep trinket XML separate from collectible item XML.
- Do not reuse collectible ids or item pool assumptions.
- If the repo has no trinket pattern yet, keep the first trinket minimal and document the new convention.
