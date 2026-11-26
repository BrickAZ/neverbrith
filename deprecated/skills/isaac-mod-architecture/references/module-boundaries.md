> **历史归档，非有效 Skill 指令**：本文件保留旧仓库材料。开发时使用[当前权威来源](../../../../.agents/skills/isaac-mod-architecture/references/module-boundaries.md)；不得按本文件覆盖当前规则，也不从这里安装 Skill。

# Module Boundaries

Use module boundaries to reduce confusion, not to decorate the codebase.

## Good Boundaries

- One content type per module family: items, trinkets, cards, entities, challenges.
- Shared helpers only when at least two real call sites need them.
- Content registration separate from behavior when the file grows hard to scan.
- Test files named after behavior or content.

## Bad Boundaries

- Splitting every small item into a new architecture before patterns stabilize.
- Hiding callbacks behind generic magic.
- Moving code only because a file is long, without reducing repeated logic.
- Creating helpers that know about every item.

## Review Question

Can a future agent find the relevant code from the content identity in less than a minute?
