# Neverbirth 重构前基线检查

日期：2026-11-24（Europe/Warsaw）。用户要求检查现有代码、上传 GitHub main，再建立重构分支。本次保存现有玩法与资源，不开始结构迁移。

## 范围与代码结论

- 检查根入口的前置版本门、模块加载与装配；严格扫描沿静态 include/require 找到 46 个运行文件。133 个 Lua 文件通过语法解析，84 个 Lua 测试通过。
- 核对新增道具、三份语言 XML、生成登记、实体资源链和原生 My Stuff 入口。生成表含 69 个道具；角色禁用状态检查通过。
- 查看 main、依赖保护、七咒之戒、阴的诅咒等相对旧 main 的差异，以及搓招战斗、资源构建器和测试的关联。该审阅不是对所有道具逐行证明正确。
- main 仍集中承载启动、共享存档及部分玩法；正式斗气拳套接入读取 `RingOfSevenCursesTestAPI`；玩家身份查询仍经 `PendingContentState` 提供。这些是既有架构耦合，迁移方向见[目标架构](../../../docs/architecture/2026-11-24-neverbirth-target-architecture.md)与[整体重构计划](../../../docs/superpowers/plans/2026-11-24-neverbrith-runtime-refactor.md)。
- 本次没有修改伤害、cache、道具池、品质、语言文案、存档或玩法实现。现有未提交代码和资源作为重构前状态保存。

## 本次实际检查

| 命令 | 退出码 | 结果 |
| --- | --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/pre-refactor/2026-11-24/check-lua-all.json` | 0 | 91 项通过，含 84 个 Lua 测试、133 个 Lua 文件语法解析；0 失败、0 阻塞，通用检查 6 条警告 |
| `pwsh -NoProfile -File tests/strict_validator_scope_test.ps1 -ReportPath reports/pre-refactor/2026-11-24/check-strict-scope.json` | 0 | 22 个范围与资源反例通过 |
| `pwsh -NoProfile -File tests/check_neverbrith_runner_test.ps1 -LuaPath C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe` | 0 | 9 个进程、退出码、错误、缺失运行器与超时场景通过 |
| 7 个额外 PowerShell 检查，逐条命令见下方 JSON | 每条 0 | My Stuff、God Complex、角色禁用、Dante 契约及几何、完整兼容文档、隔离恢复测试通过 |
| 7 个 Python 资源检查，逐条命令见下方 JSON | 3 条 0；4 条 1 | 具体失败保留在下一节 |

完整原始输出：[LuaAll](check-lua-all.json)、[严格验证器反例](check-strict-scope.json)、[额外 PowerShell](check-extra-powershell.json)、[Python 资源检查](check-extra-python.json)。Python 使用 Codex 提供的 Python 3.12.14、Pillow 13.0.0，完整解释器路径记在 JSON；PATH 中 WindowsApps 的 python 启动别名在沙箱内不可用。运行器自测首次使用被沙箱重映射的 LOCALAPPDATA 路径失败，随后通过 Get-Command 定位实际 Lua 5.4 路径并重跑成功，未改测试。

通用验证器的 6 条警告是三份 items XML 分别报告 deathanm2 与原版 Breakfast 图标找不到。项目严格验证器和 My Stuff 专项已核实 `content/gfx/UI/NeverbirthDeathItems.anm2` 的正确解析位置；Breakfast 在当前游戏已解包资源中实际存在。严格检查退出 0、0 警告。此结论仅证明解析和文件存在，不能代替原生画面验收。

## 重构前仍失败的资源检查

1. `tests/pending_content_resources_test.py`：旧图集快照预期只有 61、62 两格变化；当前还有 1–7、9–16、25、27–31 等旧格变化。当前 My Stuff 专项通过，但历史逐像素不变断言未通过。
2. `tests/blinky_resource_contract_test.py`：旧快照只允许 63、64 变化；当前包括上述旧格及后续 65–69。不能把历史快照失配当作 Blinky 运行失败，也不能删除断言后宣称资源回归已通过。
3. `tests/motion_items_resources_test.py`：`tools/build-motion-item-icons.py` 的 check 模式报告 `motion_dp.png stale`。在本次 Pillow 13.0.0 环境中，当前升龙图标像素与生成结果不完全一致；尚未证明是图标被编辑、生成源变化还是图片库版本差异，保留原件待查。
4. `tests/motion_sa_hud_resources_test.py`：战斗核心比该测试保存的旧快照多了普通 360 的 3 倍伤害、半径 80 的 3 倍溅射，以及 720 主目标 15 倍伤害。当前实现与[2026-10-26 已确认计划](../../../docs/superpowers/plans/2026-10-26-motion-slam-splash.md)一致；这个测试只豁免了此前的时序变更，尚未更新合同。

通过的 Python 检查为 `motion_presentation_resources_test.py`、`motion_additions_resources_test.py`、`motion_cinematic_resources_test.py`。失败项属于本次发现并明确记录的基线状态，不标成全部测试通过，也不为消除失败而重画资源或回退已确认玩法。

## 暂存内容导出复核

从 Git index 用 `git checkout-index --all --prefix=.../tmp/pre-refactor-snapshot/` 导出隔离副本，再运行该副本的统一 LuaAll 入口，退出码 0：91 项通过、0 失败、0 阻塞，详见[隔离副本报告](check-staged-snapshot.json)。隔离目录无法自动推断游戏位置，因此另有 3 条 Breakfast 原生资源警告；明确传入 `-GameRoot 'E:/Isaac - Repentance'` 重跑严格验证器后，退出 0、0 警告、0 失败。

导出副本的导航检查通过：5 个知识页、115 条本地链接。对 content、resources、generated 以及测试快照作字节比对，48 个文件仅有 LF/CRLF 差异，没有其他内容差异，见[字节差异分类](check-staged-byte-differences.json)。这些已存在的行尾差异不影响语法；新纳入哈希合同的资源和快照已通过 Git 属性保留原始字节。

`git diff --cached --check` 仍返回 2。允许 CRLF 后，剩余提示来自 Markdown 的双空格换行、历史文件尾空行、补丁文件自身的上下文前缀，以及 `motion_combat_test.lua`、`render-motion-fist-preview.py` 的末尾空行。本次保留历史证据字节，不将格式告警混同于玩法测试失败。

## Git 与交付范围

- 任务开始的本地 main：`1e1ba43`。远端随后核实为 `9400e9e932813f4ad3a3b1fbab8c192994459dad`，新增许可证、版权、资产清单与 README 说明。集成时保留这些远端内容，不强制覆盖远端历史。
- 保存源码、必要资源、生成表、测试与工具、项目知识与设计文档，以及导航实际引用的 Markdown 证据、资源测试所需的小型快照和元数据。
- 历史工作树、编译器下载、发布副本、视频、原始素材工作目录、旧 MotionShowcase v1–v6、任务补丁碎片和备份留在本机。`.gitignore` 明确区分这些产物；已有跟踪文件继续保留。必要 reports 文件显式加入版本控制。
- 精确哈希使用的 ANM2、内容 XML、reports 快照禁止 Git 自动转换行尾，生成 Lua 固定 LF，避免提交/检出本身改变资源证据。
- 本地原生构建和部分资源重建工具仍需要对应游戏安装、解包资源、REPENTOGON 源树或素材原件；它们不是新克隆仓库即独立可运行的工具。尤其 SA HUD 来源检查会读取本地提取的原始 SF6 素材；此类大型中间产物没有随基线上传。
- 许可证和旧资产清单保持远端决定；旧清单并不自动覆盖本次新增资源。此报告没有对新增素材作版权归属或许可重新判定。

本次不启动游戏、不重建原生 DLL、不改玩家存档，也不发布创意工坊。自动检查只代表列出的覆盖范围。本次没有新的实机或人工游玩验收。
