# 第十五批交付记录

2026-11-26。三件道具的本地职责拆分、共享能力核对和冻结旧/新原生对照已完成。玩法、数值、品质、道具池、资源与存档语义保持。未提交、推送或发布；不代表整轮全部道具与人工体验验收完成。

## 交付与归属

| 道具 | 保留的唯一入口 | 五个私有模块 |
| --- | --- | --- |
| 阴的诅咒 | [yins_curse.lua](../../../yins_curse.lua) | state、queries、pedestals、acquisition、runtime |
| 七咒之戒 | [ring_of_the_seven_curses.lua](../../../ring_of_the_seven_curses.lua) | state、inventory、world、rewards、runtime |
| ACE 反作弊系统 | [ace_anti_cheat_system.lua](../../../scripts/features/ace_anti_cheat_system.lua) | state、queries、audit、combat、runtime |

入口创建同次安装的私有实例、发布原接口并按原顺序安装回调。状态、数值和实际 callback 全部由对应子模块拥有，handler 与 binding 相邻；没有把总实现搬进另一个单体文件。七咒的正式倍率查询保留原名，与测试接口分离。

ACE 的 Game 查询接入现有 world_queries.TryGame，保留 function 检查和 false→nil 边界。其他计数、存档、玩家键、底座/NPC 筛选及结算能力按语义核对后保留各自政策。没有新建无人消费的公共库。完整依据见[消费者清单](consumer-inventory.md)、[API 用法](../../../docs/api/shared-mechanics.md)和[源码复核](review.md)。

## 验证证据

| 范围 | 实际结果 |
| --- | --- |
| 冻结旧/新全部 Lua 行为测试 | 旧侧 145 项、新侧 147 项，均 0 失败、exit 0。新增两项为本批加载/回滚和边界检查。[旧侧](baseline-lua-suite.json)、[新侧](candidate-final-lua-suite.json)保存每条命令、输出及退出码 |
| Lua 解析 | 396 个冻结 Lua 文件全部可解析，exit 0。[输出](frozen-syntax.txt)、[完整输入](frozen-syntax-inputs.txt) |
| 提取源码对照 | 155 个函数中 148 个函数体原样保持，6 个仅迁移 ACE lifetime 引用，1 个为已测共享查询适配；七咒正式查询和测试 reset 另外原样迁入 state。[结果](extraction-comparison.json) |
| 完整入口回调 | 常规夹具 520 条；补齐原生相关能力后 539 条。事件、优先级、过滤、函数身份及相对顺序一致。[结果](registration-comparison.txt) |
| 模块与安装失败 | 15 个私有模块每次各加载一次；35 个回调登记阶段注入失败均撤销回调和导出，15 个缺模块反例均阻止半安装，随后可重新加载。见 tests/batch15_loading_test.lua |
| 状态与共享查询边界 | 不同安装的 ACE/Yin runtime 不串用；ACE 真实公共查询、异常、false、非函数、分数计数与 fallback 保持。见 tests/batch15_boundaries_test.lua；原存档/生命周期测试同时在旧/新两侧通过 |
| 原生旧/新对照 | 两侧各 14 场景、24 项通过，0 失败；14 组观测相同，探针字节相同。[对照](native-comparison.json)、[旧结果](native-baseline-06/result.json)、[新结果](native-candidate-01/result.json) |
| 静态检查 | 冻结候选严格检查 exit 0、0 警告；通用检查 exit 0、6 条已有资源解析警告。[严格](frozen-strict.txt)、[通用](frozen-generic.txt) |
| 检查器修复 | 文件数增长触发 Windows 命令行长度上限。改用临时 UTF-8 清单，finally 清理且报告保留 InputFiles。12 个入口自测通过，包含 400 个长路径文件和末项语法错误反例。[自测](runner-selftest.txt) |
| 最终范围 | 18 个本批运行文件与原生候选逐字节一致；704 个 content/resources/generated 文件哈希与开工基线相同。其他并行修改保留并另列。[范围与哈希](final-scope.json) |

原生场景包括普通受伤、ACE ×2、七咒 ×2、二者 ×4，阴的诅咒前后的 Pyromaniac 爆炸免疫和黑蜡烛恢复，首个 Q4 转 Ipecac，七咒资源上限/移除黑蜡烛/强制楼层诅咒，真实换房，以及三个原生 NPC 单击击杀、实际减速工作量和第三次团灭。伤害通过真正的 TakeDamage 和引擎伤害/死亡回调处理；没有手工派发原生伤害回调代替扣血。

两次正式运行各备份 229 个状态文件、恢复 7 个变化文件，归档本次新建且校验过的 1 个存档文件。均正常关闭自己的隐藏进程，mainRestored、stateRestored、cleanShutdown 为 true，恢复错误与未处理新文件为空。未发送桌面键鼠输入。日志最终缓冲在正常退出时刷新，因此 result 标记 COMPLETED_LOG_FLUSHED_ON_EXIT；退出后保存的日志具有完整 START、24/0 汇总和 DONE。

## 冻结边界与并行变化

baseline 保存开工时 1200 文件；candidate-final 从该基线复制，再覆盖本批文件。原生两侧因此具有相同的其他运行代码，避免把后续批次正在修改的记忆紊乱、战斗或共享模块差异归因于本批。已调整的测试加载适配保存在 staged/tests，由 run-frozen-test.lua 显式选择；生产源码仍严格来自对应快照。该运行器同时重定向 dofile、loadfile 与只读 io.open。

直接在持续变化的工作区执行 LuaAll 的初次记录是 76 通过、80 失败、1 阻塞，见[first-full-checks.json](first-full-checks.json)。其中包括其他批次的临时原生入口与尚未完成的记忆紊乱拆分、公共模块文档缺项，以及本批暴露的长命令限制和独立测试缺 include 适配。后两项已修复并在冻结完整套件与入口自测中通过；未替其他任务回滚或修正无关实现。再次综合运行[final-checks.json](final-checks.json)为 73 通过、96 失败、0 阻塞：95 项输出包含其他批次的 `FortuneRivallingHeavenGu requires GetNeedletickLuckCap` 未接入依赖，1 项为其并行公共模块文档缺项；503 个工作区 Lua 文件语法解析成功。此结果是共享工作区当时的观测，不取代上述冻结归因证据，也不构成整份工作区通过声明。

知识检查曾因其他批次新建的 shooting_scope/attack_ownership 尚未登记 API 索引而失败，见[记录](knowledge-check.txt)。不将这些无关缺项改写为本批通过，也不扩展修改其接口。本批最终导航检查为 9 个知识页可达、277 个本地链接有效，exit 0，见[导航记录](navigation-check.txt)。

最后一次当前入口加载复核又遇到其他批次临时注入的 drive_glove_mechanic_audit，其原生探针在模拟夹具中缺 TrinketType 而失败，见[current-loading-check.txt](current-loading-check.txt)。本批原生进程已结束并恢复成功；该临时入口属于随后继续工作的并行批次，本批保留其内容，没有将其清掉以制造当前工作区通过结果。

## 探针修正与限制

- 前几次原生启动在发现其他批次的临时入口，或备份期间发现另一任务刚恢复/移走存档时停止，尚未写入本次入口或启动本次游戏。随后增加入口与存档连续稳定五秒的启动条件；未关闭其他任务进程。
- native-baseline-04 实际跑到第三次击杀，但有两项探针错误：刚生成的 Q4 尚处于原生拾取等待期；团灭后 POST_UPDATE 停止，原探针无法输出结束汇总。探针延长等待并改从游戏结束画面的渲染阶段记录团灭。生产源码未修改。该次退出、状态和入口恢复仍通过；失败日志保留。
- 源码文本检查改为跟随本件真实字面 include 链，独立 Lua 夹具补上 include；保留原行为断言。首次加载检查发现夹具没有暴露两个七咒事件，随后补齐事件，再验证全部 35 个登记阶段，没有减少目标回调数。
- 模拟检查覆盖相关 Continue、新局、退出与 ACE 卸载边界；本批原生对照为固定种子单人正常 Isaac。没有将其写成跨进程 Continue、多人合作、所有角色、所有第三方 Mod、沙漏回溯或人工体验验收。完整发布包和广泛性能基准不在本批证据内。ACE 旧有 HP 观察结算并非逐原生伤害队列项的独立回执，此限制原样保留。

## 主要执行命令

均在模组根目录运行；每个检查的原始退出码见相应记录。冻结两侧、正式原生、源码与登记对照、静态检查、入口自测最终退出码均为 0。

```powershell
node reports/refactor-batch15/2026-11-26/snapshot.mjs baseline
node reports/refactor-batch15/2026-11-26/stage-candidate.mjs
node reports/refactor-batch15/2026-11-26/verify-extraction.mjs
lua reports/refactor-batch15/2026-11-26/compare-registration.lua
pwsh -NoProfile -File reports/refactor-batch15/2026-11-26/run-frozen-suite.ps1 -Role baseline
pwsh -NoProfile -File reports/refactor-batch15/2026-11-26/run-frozen-suite.ps1 -Role candidate-final
pwsh -NoProfile -File tests/check_neverbrith_runner_test.ps1
pwsh -NoProfile -File reports/refactor-batch15/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-06 -Baseline -TimeLimitSeconds 50
pwsh -NoProfile -File reports/refactor-batch15/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 50
node reports/refactor-batch15/2026-11-26/compare-native.mjs native-baseline-06 native-candidate-01
pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1 -Root reports/refactor-batch15/2026-11-26/candidate-final -GameRoot 'E:/Isaac - Repentance'
pwsh -NoProfile -File tools/validators/validate-isaac-mod.ps1 -Root reports/refactor-batch15/2026-11-26/candidate-final -ModObjectName Neverbirth -SkillRoot .agents/skills
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch15/2026-11-26/final-checks.json
node reports/refactor-batch15/2026-11-26/verify-scope.mjs
```

snapshot/stage/split 为过程证据，不应对已完成目录重新执行或覆盖已有快照。回退必须只处理本批拥有的文件，并以当前工作区核对后的范围为准，不能用 Git HEAD 覆盖并行未提交成果。
