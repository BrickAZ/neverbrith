# Skill 来源与旧路径

有效 Isaac Skill 统一安装、维护在 [`.agents/skills`](../../.agents/skills/)。按任务读取相应包的 `SKILL.md`；项目内的选择与维护规则见[知识索引](../agent/index.md)。

原先这里的 28 个 Skill 包已移入 [`deprecated/skills`](../../deprecated/skills/)。它们都有有效包替代，保留用于追溯，不再安装、路由或同步维护。废弃目录中的规则不指导当前开发。

本目录只保留这份说明及三个旧命令转发入口：两个验证器转发到 [`tools/validators`](../../tools/validators/)，旧 skill-layer 检查转发到 [Skill 包检查](../../tests/skill_packages_test.ps1)。转发脚本不构成另一套 Skill。

复制 Skill 时，保留整个包的 `SKILL.md`、`references`、`evals` 及自带工具，统一放入目标项目的 `.agents/skills`。以 `isaac-neverbrith-*` 命名的包是本项目扩展；其他项目先用 `isaac-mod-context` 确认上下文。个人策略 `isaac-repentogon-user-policy` 按既有规则仅保留在本地，不进入仓库发布。

包检查：`pwsh -NoProfile -File tests/skill_packages_test.ps1`。该检查验证目录来源、元数据、JSON 和引用，不把样例文件视为已经运行的 AI 行为评估。
