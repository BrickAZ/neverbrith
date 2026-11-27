# GitHub 重构分支上传检查

日期：2026-11-27（Europe/Warsaw）。

用户授权将当前重构提交并推送到对应 GitHub 分支，并从当前 main 创建「未重构」分支。

- 仓库：https://github.com/BrickAZ/neverbrith
- 重构分支：codex/neverbirth-refactor
- main 与新建「未重构」的基准提交：315e1635cf0068f510b9dce2bead85bc11b65f34
- 提交范围：现有重构源码、共享服务、测试、文档、Skill 来源迁移及文档直接引用的 60 份交付/检查文件。
- 临时工作树、个人策略、打包副本等遵循已有忽略规则。报告中进一步引用的本地原始产物没有批量上传。

## 本次实际检查

| 命令 | 退出码 | 结果 |
| --- | --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/github-upload/2026-11-27/lua-all.json` | 0 | 182 passed、0 failed、0 blocked/not run、0 warnings；含 174 个 Lua 测试、544 个 Lua 文件语法解析及选定静态/文档检查 |
| `& 'C:/msys64/ucrt64/bin/python.exe' tools/architecture_check.py --report reports/github-upload/2026-11-27/architecture.json` | 0 | 350 个 runtime 文件、417 个字面量加载边；无错误与覆盖限制 |
| `& 'C:/msys64/ucrt64/bin/python.exe' tests/architecture_check_test.py` | 0 | 10 个反例/正例测试通过 |
| `& 'C:/msys64/ucrt64/bin/python.exe' tests/package_mod_test.py` | 0 | 2 个打包测试通过 |
| `pwsh -NoProfile -File tests/skill_source_validation_test.ps1` | 0 | 12 个来源/转发用例通过 |
| `git diff --cached --check` | 2 | 现有 Skill/归档、一个 ANM2 夹具、文档及两份源码的末尾空行/空白/CRLF 提示；保留上传前内容，未混入格式重写 |

首次使用 PATH 中的 `python` 命中了不可执行的 WindowsApps 别名，没有运行测试；随后显式使用已有 MSYS2 Python，以上 Python 检查实际完成。

本次没有运行游戏原生验收，也没有扩大已有验收结论。GitHub 分支上传与 main 合并、创意工坊发布分别处理；本次只上传重构分支并保存 main 快照。
