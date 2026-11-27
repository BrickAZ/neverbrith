# Skill 权威来源

本项目的 Isaac Skill 安装位置和唯一有效指令来源是 [`.agents/skills/`](../../.agents/skills/)。该目录是普通目录，不是指向 `docs/skills` 的链接。用户级 `.agents/skills` 与本项目 `.agents/skills` 是不同路径；本规则针对这个 checkout 的 Isaac 技能，不迁移其他插件。

通用 Skill 的公开维护与发布仓库是 [BrickAZ/isaac-repentance-skills](https://github.com/BrickAZ/isaac-repentance-skills)，源码在该仓库的 `skills/`，正式分支为 `main`。本项目的 `.agents/skills` 是实际生效的安装副本；修改通用包后，应核对并同步到这个独立仓库，不能把向 `BrickAZ/neverbrith` 推送分支当作 Skill 发布。`isaac-neverbrith-*` 三个项目扩展保留在模组项目，个人策略 `isaac-repentogon-user-policy` 保留本地，不进入通用仓库。

| 内容 | 维护位置 | 使用规则 |
| --- | --- | --- |
| Isaac 通用及本项目 Skill | `.agents/skills/isaac-*` | 在这里修改入口、references、evals 和技能自带工具 |
| 项目事实、库用法和约定 | [知识索引](index.md)、[API 索引](../api/index.md)、[开发规范](development-conventions.md) | Skill 链接到这里，不复制同一份 API 手册 |
| 项目验证器 | [通用项目检查](../../tools/validators/validate-isaac-mod.ps1)、[严格项目检查](../../tools/validators/validate-neverbrith.ps1) | 它们是项目拥有的工具；指令来源仍是 Skills 和项目规范 |
| 废弃的旧 Skill | [`deprecated/skills`](../../deprecated/skills/README.md) | 原 `docs/skills` 的 28 个包，仅用于追溯，不再维护第二套 Skill 指令 |
| 原 `docs/skills` 路径 | [兼容说明](../skills/README.md) | 只保留说明和旧命令转发，不含 SKILL.md |

旧副本来自之前提交进仓库的技能材料和工具。后来 `.agents/skills` 发展出更多技能与修订，旧导航和验证入口仍使用 `docs/skills`，导致来源分裂。现在导航、评估上下文和检查包均改用 `.agents/skills`，不要求两个目录正文保持一致，也不从旧副本覆盖安装目录。

项目拥有的通用验证器保留本项目既有检查范围；`.agents/skills/isaac-validators/scripts` 中的可移植验证器另有资源目录和图像检查能力，供没有项目入口的 Mod 使用。它们不是要求双向同步的指令副本：本项目统一走 `tools/check-neverbrith.ps1`，更新通用 Skill 不自动改变项目验收范围。两者共享的路径判断错误应分别修复并验证。

`.gitignore` 允许本项目 `isaac-*` 技能纳入版本管理，其余 `.agents` 本地文件继续忽略；`isaac-repentogon-user-policy` 是个人策略，仍保持本地文件。更改忽略规则不是提交或推送。复制开发 checkout 时应包含有效技能；运行游戏只需要运行源码和资源，不需要把技能打入 Mod 发布包。

维护时先读当前 Skill，再改实际拥有者。更新项目库或 callback 写法时同步项目规范与 API 文档；通用技能只保存通用判断，不把 Neverbirth 私有接口写成所有模组的标准。历史文档的相对链接仍可查看，但其中指令已退役。

独立的[技能包检查](../../tests/skill_packages_test.ps1)检查有效包、引用与旧目录隔离；本项目的包与导航组合检查由[知识检查](../../tests/project_knowledge_test.ps1)执行。统一入口与实际验证范围见[检查与证据](testing.md)。静态检查不证明 AI 行为一定正确。
