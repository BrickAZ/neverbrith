# 第二十一批交付记录

本批范围为用户截图第二十一批五件：斗气拳套、360、720、波动、升龙。本地结构迁移、旧新原生对照、当前源码快照 LuaAll 和正式安装原生检查已完成。没有提交、推送或发布。

## 最终结构

- 根目录 `drive_glove.lua` 只保留兼容工厂；`scripts/features/drive_glove/init.lua` 组装 state、freeze、input、players、weapons、damage、attribution、lifecycle。每个处理函数与原生绑定同文件紧邻，显式安装顺序保留。既有规则/伤害/武器/声音/表现模块继续使用。
- `scripts/features/motion_items/` 中四件配置各自拥有身份、输入 profile、战斗数值和源帧映射。Core 加载一次，combat 保存并发布同一 Specifications，正式绑定实际消费该引用。没有复制四套输入/战斗/演出实现。
- `scripts/systems/entity_identity.lua` 取代输入、射击门禁两处、正式绑定、战斗实体、表现六处相同键算法。Key/EntityKey 提供者优先级与错误行为保持；持久化玩家身份不改。
- 正式 main 显式传入斗气拳套 Key。玩法、伤害、斗气/SA/OD、目标租约、控制恢复、存档字段、资源、池和品质未改。本次没有混入玩法修复。

逐件状态与共享差异见[消费者清单](consumer-inventory.md)，接口详细用法见[API 文档](../../../docs/api/drive-motion.md)与[基础机制](../../../docs/api/shared-mechanics.md)，实施范围见[计划](../../../docs/superpowers/plans/2026-11-26-twenty-first-batch-refactor.md)。

## 自动验证

Lua 运行器均为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，Python 为 `C:/msys64/ucrt64/bin/python.exe`；工作目录为模组根。下列次数只代表各自范围。

| 命令/检查 | 实际结果 |
| --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch21/2026-11-26/baseline-checks.json` | 开工基线退出 1：149 检查通过，4 个既有失败，6 警告；4 个失败均为七咒/阴的诅咒旧测试缺 include，与本批无关 |
| 逐个运行 `tests/drive_glove*_test.lua`、`tests/motion_*_test.lua` | 最终范围内 16 份均通过，合计 7,625 项既有断言；退出 0。core、presentation、shooting 三份测试只适配真实依赖加载，保留原行为断言 |
| `lua tests/batch21_identity_test.lua` | 退出 0；wrapper 指针同一性、InitSeed隔离、缺API/错误、实际射击门禁和自定义提供者 |
| `lua tests/batch21_loading_test.lua` | 退出 0；13 个道具私有/配置模块一次加载、4 个正式 owner、13 个缺模块故障、92 个登记后故障回滚及新实例。真实共享入口空档执行一次，冻结候选依赖集另执行一次 |
| `lua reports/refactor-batch21/2026-11-26/trace.lua baseline/candidate drive_glove_behavior/motion_combat <output>` | 四次退出 0；同一冻结行为场景下，拳套14,855行、战斗2,076行回调/状态/返回/保存轨迹分别字节一致。最后公共键提取后已复跑候选 |
| `lua reports/refactor-batch21/2026-11-26/callback-order.lua <runtime>/ <output>` | 旧新各退出 0；完整入口520条回调的顺序、优先级、过滤和逻辑所有者一致 |
| `pwsh -NoProfile -File tests/project_knowledge_test.ps1` | 退出 0；26 页可达、601个本地链接、46个共享模块有用法、59个有效技能入口（该次计数）。其他任务曾新增未登记 attack_ownership 导致中间失败，补齐后已复跑通过 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 退出 0；9个知识页可达、278个本地链接有效（该次计数） |
| 最终 `LuaAll`（当前完整源码快照） | 退出0：169项通过、0失败、0阻塞；包含161份Lua测试和503份Lua语法解析。结果为 `snapshot-final-checks.json`/`.log`，完整命令见下文 |
| `pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1 -Root .` | 当前真实目录退出0，0警告、0失败；日志 `live-strict.log` |

最终快照命令：`pwsh -NoProfile -File tools/check-neverbrith.ps1 -Root reports/refactor-batch21/2026-11-26/verification-workspace -Profile LuaAll -ReportPath "E:/Isaac - Repentance/mods/neverbrith/reports/refactor-batch21/2026-11-26/snapshot-final-checks.json"`。快照取得当前全部源码、测试、工具、文档和内容登记，复制时逐文件验证没有漂移；资源/技能/诊断均为普通副本，不含 junction。快照中的9条警告为通用验证器原有6条资源提示，以及因快照不在游戏 mods 直系目录而无法自动定位原版资源产生的3条提示；实际目录严格验证器已定位原版素材并零警告通过。

直接在共享目录运行的 `final-checks.json` 为143通过、26失败，因为中途另一个任务把 batch14 原生探针接入了 main（日志含其probe栈）；它没有被当作最终通过。初次验证快照也曾因资源目录准备时序及缺失README链接文件失败，已补齐普通文件副本，完整重跑为上面的169通过。原始记录保留为 `snapshot-checks.json`。早期创建的循环 reports 目录链接已精确删除，随后全部目录链接改为普通副本，未删除任何被引用的原文件。

轨迹哈希：拳套 `799261490BDE2AAD3CEB47AA8B758837F25AC7B427D3558C244169B66BA6B5B0`，战斗 `047717AC26C2DAB8DB5E21D1A127C65C41B5AB308133BF417DD5D41109A1E209`。独立只读审查未发现本批已确认缺陷，详见[审查记录](review.md)。

## 原生旧新对照

其他重构任务也在使用同一安装目录，期间出现过临时入口重叠和未接完的公共依赖。最终对照因此使用本批开工冻结的相同外围源码；candidate-runtime 只覆盖本批21个源码文件，并在同一 main 装配点加显式 Key。全部使用真实游戏/REPENTOGON、真实实体/伤害/音频事件/绘制回调；不接管键鼠。

统一命令为 `pwsh -NoProfile -File reports/refactor-batch21/2026-11-26/run-native.ps1 -Attempt <下表目录> -Runtime <baseline或candidate-runtime> -Probe <类型> -TimeLimitSeconds <时限>`。

| Probe / 时限 | 基线目录与结果 | 候选目录与结果 |
| --- | --- | --- |
| drive / 60秒 | drive-baseline-frozen：103通过、0失败、退出0 | drive-candidate-frozen：103通过、0失败、退出0 |
| recovery_flow / 60秒 | motion-baseline-frozen：7场景150通过、0失败、退出0 | motion-candidate-frozen：同样150通过、0失败、退出0 |
| slam_damage / 100秒 | slam-baseline-frozen-full：8场景248通过、0失败、退出0 | slam-candidate-frozen-full：同样248通过、0失败、退出0 |

每版共501项原生断言，三组PASS标签及数值逐行完全一致；`compare-native.py` 退出0，结果见 `native-comparison.json`。六次最终对照均正常关闭自己的游戏进程，`stateRestored/mainRestored/cleanShutdown=true`，没有 Lua 回调错误或崩溃。游戏日志在正常关闭时刷新，因此结果状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`；这不是把缺少汇总的超时判为通过。

失败/未完成尝试全部保留，不计入成功证据：首次 recovery 基线因外部修改入口未能自动恢复 main，随后只删除本任务精确探针尾部并保留外部改动；第一次拳套因残留探针重叠作废；clean 版本未在旧运行器强停前取得DONE；第一次当前候选因鸿运的外围依赖未接完而在加载本批前中止；slam 的60秒版本只跑到第七场景，延长到100秒后重新完整对照。每次都保留日志和恢复记录，没有以这些尝试的部分PASS冒充完整通过。

当前共享工作区正式装配原生检查：`run-native.ps1 -Attempt live-candidate-final-clean -Probe recovery_flow -TimeLimitSeconds 60`，不传 Runtime，实际加载当前安装目录源码；退出0，7场景150断言通过、0失败，日志没有Lua回调错误或引擎异常，入口/存档/配置恢复且正常退出。先前 `live-candidate-final` 曾在取得新探针日志前进程早退，未记通过；完成验证目录清理后已重新实际执行成功。本项证明当时的正式装配可运行，本批冻结对照仍单独维护，不代表其他批次全部玩法已验证。

## 完整性与限制

`baseline-manifest.json` 保存开工511个文件；`candidate-target-manifest.json` 保存本批21个候选运行文件；`scope-check.json` 显示这些候选未漂移、content零改动、679个资源文件零哈希变化。根目录兼容工厂、所有新 scripts 模块必须随未来发布包一起打包。

本批在原有合同上完成结构迁移和自动回归，逐件清单保留人工验收边界；不等于整轮重构完成。人工键盘/手柄手感、画面与声音体验、真实多人及跨进程 Continue 未在本次验收；未新增这些保证。未声称性能提升。既有不同身份、来源遍历、射速下界、控制政策与沙漏语义未强行合并。

如需撤回，只按本批候选清单恢复对应 baseline 文件，并移除这次新建的道具目录/公共键模块及它们的装配引用；main 只撤回本批 Key 接线，保留其他任务改动。不要把整个冻结目录覆盖当前共享工作区。
