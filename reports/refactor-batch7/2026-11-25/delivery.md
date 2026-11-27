# 第七批交付：强力泻药、通天塔

## 实现与所有权

本批按用户批准的范围实施，基于当前未提交工作区快照，而非 Git HEAD。强力泻药入口组装以下单实例：

- `players.lua`：玩家持有/数量查询、可修改的旧 `GetState` 接口、移动判断、液体冷却、大便计时与换房处理。
- `creep.lua`：生成时联动快照、真实液体更新、减速/状态/直接伤害、来源识别与玩家免伤。
- `poop.lua`：随机数取得、位置/类型选择、生成成功后提交计数、每房共享上限与换房计数重置。
- `presentation.lua`：服装 ID 缓存、玩家外观状态和拾取回调。
- `synergies.lua`：从根目录迁入，公式实现字节一致；根目录 `strong_laxative_synergies.lua` 只保留兼容工厂导出，不创建第二个实例。

通天塔保留简单入口与 `RemoveCreepIfActive` 接口，自己的 `creep_variants.lua` 管理类型合并、去重与顺序。它使用比强力泻药免伤更广的移除范围；两件的政策未合并。已有 `main.lua` 接线不变。

强力泻药的回调按原顺序登记：玩家更新 → 液体更新 → 玩家伤害 → 拾取 → 换房。通天塔保持每类效果的初始化/更新配对顺序。没有新存档字段，没有新增重置回调，也没有改变数值、品质、道具池或资源。

私有状态分别由对应模块持有；公开 `GetState` 仍返回原有可修改状态，公开方法仍动态派发，保留既有覆盖/替换语义。换房先重置房间数量再重置玩家计时；保留未知状态字段。失去道具停止生成新液体，已生成液体继续使用自己的联动快照；所有者死亡/无效时清除。通天塔移除新液体，大便继续生成。

## 自动验证

统一运行器结果：`final-checks.json` / `final-checks.log`，126 项通过、0 失败、0 阻塞；119 个 Lua 行为测试、276 个 Lua 语法文件，退出码 0。严格验证器无警告；通用验证器保留 6 条历史资源解析提示（3 个语言版本的死亡动画与原生 Breakfast 贴图），未修改相关资源。

本批补充：

- `batch7_lifecycle_test.lua` 在冻结旧源码和当前候选运行相同场景。覆盖生成失败不占名额、随机调用顺序、房间上限前后 RNG 消耗、多人共享房间上限但独立计时、换房/重进房、失去与重新取得、旧液体伤害快照、无效所有者、通天塔跨玩家影响及移除后的更新短路。
- `batch7_dependencies_test.lua` 覆盖兼容路径只返回工厂、类型目录独立副本、玩家更新/房间重置顺序、可修改状态和公开方法动态替换。
- `batch7_loading_test.lua` 验证 9 个相关模块各加载一次、5 个强力泻药回调各登记一次，以及 5 个登记阶段失败后的全入口回滚与重新加载。
- 完整入口登记对照：基础夹具 475 条，补齐液体类型/初始化事件的扩展夹具 489 条；事件、优先级、过滤参数、处理函数身份及相对顺序逐条一致。扩展夹具范围与第六批不同，数量不能直接作跨批增减比较。
- 冻结候选独立目录运行 8 个专项，全部退出码 0。其中既有联动测试 12 项、伤害顺序检查 12 项；入口故障注入覆盖 79 个模块导入、3 个已发生登记变更的失败点。

旧行为测试仅增加 `--fixture` 导出分支，原断言保留；联动测试直接读取新的所有者路径。新场景最初误用了两个相同玩家种子，修正测试数据后基线通过；不是生产修复。加载失败场景补全旧夹具缺失的液体枚举，确保确实触发通天塔登记故障。

## 原生证据

使用已安装 REPENTOGON `1.0.12a-yin-api1-dev`，对冻结旧源码与候选执行同一探针。正式证据见 `baseline-final/`、`candidate-native/` 和 `native-comparison.json`。

正式两次各 29 项通过、0 失败，5 个场景、5 组观测与逐项检查数值相同。实际液体变体为 54，原生碰撞伤害为 0，取样直接伤害为 0.35；原生伤害事件出现在液体 Age 10 与 20，单次浮点伤害约 0.349999994，目标生命约 999.300049。旧液体快照、失去道具后停止新生成、原生格子成功计数、通天塔保留旧液体并移除新液体/敌方液体、大便不受阻、移除通天塔后恢复生成，以及换房计数/计时清零均通过。

探针通过实际底座取得强力泻药；设置真实玩家速度以触发移动留痕，使用实际效果实体、NPC、原生伤害回调、格子实体与正常生成房间转场。为在有限时间内触发大便，实际取得 20 份道具并将公开计时置于判定前一刻；随机选位、生成与成功计数仍走生产实现。没有发送桌面键鼠输入。

两次早期基线诊断记录保留：`baseline-native/` 为通用 Entity 未先转 Effect 就读取 Timeout 导致探针中断；`baseline-effects/` 在已删除实体上读不到移除标记，其他 28 项通过。最终探针改为检查已删除液体不在真实房间实体列表中；标记先于删除、被移除液体不再更新的代码合同继续由迁移前后 Lua 测试覆盖。没有为了通过探针修改生产逻辑。

这不代表人工服装观感、键盘/手柄手感、真实多人、跨进程继续游戏及全部复杂联动已经验收。联动算法逐字保留并通过现有 12 项模拟检查，本轮原生检查聚焦本批拆分涉及的实体、伤害、生成、移除与转场。

每次探针启动前快照 227 个配置/状态文件，只启动本次拥有的隐藏进程；退出后恢复原入口、配置与存档，新生成且有进程/时间证据的存档归档保留。`COMPLETED_LOG_FLUSHED_ON_EXIT` 表示完成日志在正常退出时刷盘，应同时看检查汇总、正常退出码和恢复校验。

两次正式进程退出码均为 0，分别恢复 6 个变化文件、归档 3 个新文件；恢复错误与未处理新文件均为 0。最终主入口与冻结候选哈希一致，没有残留探针。

## 实际命令

默认工作目录为模组根目录；Lua 运行器为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。独立候选专项以 `candidate-runtime/` 为工作目录。

| 命令 | 退出码 |
| --- | --- |
| `node reports/refactor-batch7/2026-11-25/snapshot.mjs` | 0 |
| `lua.exe tests/strong_laxative_behavior_test.lua` | 0 |
| `lua.exe tests/tower_of_babel_behavior_test.lua` | 0 |
| `lua.exe tests/strong_laxative_synergies_test.lua` | 0 |
| `lua.exe tests/batch7_lifecycle_test.lua reports/refactor-batch7/2026-11-25/baseline/` | 0（修正新增场景的参数/玩家标识后） |
| `node reports/refactor-batch7/2026-11-25/split-items.mjs` | 0 |
| `lua.exe tests/batch7_lifecycle_test.lua` | 0 |
| `lua.exe tests/batch7_loading_test.lua` | 0（补全登记故障场景的效果枚举后） |
| `lua.exe tests/batch7_dependencies_test.lua` | 0 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch7/2026-11-25/final-checks.json` | 0 |
| `node reports/refactor-batch7/2026-11-25/snapshot.mjs candidate-runtime` | 0 |
| `lua.exe reports/refactor-batch7/2026-11-25/compare-registration.lua` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch7/2026-11-25/run-native-isolated.ps1 -Attempt baseline-final -Baseline -TimeLimitSeconds 45` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch7/2026-11-25/run-native-isolated.ps1 -Attempt candidate-native -TimeLimitSeconds 45` | 0 |
| `node reports/refactor-batch7/2026-11-25/compare-native.mjs baseline-final candidate-native` | 0 |
| `node reports/refactor-batch7/2026-11-25/verify-scope.mjs` | 0（在临时原生入口恢复后执行最终核对） |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 0 |
| `git -c core.safecrlf=false diff --check` | 0 |

## 范围与回退

本批改两个道具入口、一个旧路径兼容导出、三个既有测试的夹具/定位入口及项目地图；新增 6 个生产模块、3 个测试和计划/报告。完整清单及哈希见 `scope-parity.json`。核对包括 704 个登记与资源文件、主入口和未归入本批的运行源码。

基线 1070 个文件，候选 1079 个文件；现有文件仅上述 7 项发生变化。原联动实现与迁入版本字节一致，704 个登记/资源文件字节一致，未发生本批范围外的候选漂移。LuaAll 后仅补充导航/计划/报告及诊断材料，没有再次修改生产源码或行为测试。

回退前确认文件没有后续修改，仅恢复本批三个生产文件和测试差异、移除本批新模块/新测试、撤回地图第七批段落。不用整目录快照覆盖工作区，不用历史游戏存档覆盖之后的游戏进度。无需存档迁移。

本批没有提交、推送、发布或升级依赖。
