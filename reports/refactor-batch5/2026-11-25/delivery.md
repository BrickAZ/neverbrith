# 第五批交付：黑太岁、肉块、净化迷幻菇

日期：2026-11-25（Europe/Warsaw）。本批已实施并完成范围内的源码、模拟、加载和原生前后对照。玩法、数值、品质、池、资源及旧存档格式沿用原实现。

## 结果与职责

| 所有者 | 职责 |
| --- | --- |
| `scripts/features/black_taisui.lua` | 配置既有公开常量，创建各模块，显式保持保命、缓存、净化和后段回调的安装顺序 |
| `black_taisui/growth.lua` | 寄生值、阶段、生命观察、阶段三的一次肉块奖励及属性缓存 |
| `black_taisui/survival.lua` | 伤害过滤、致命判断、保命消耗与恢复、孢子的地面效果和恐惧等玩法 |
| `black_taisui/purification.lua` | 诅咒移除、隐藏道具显形、原版迷幻菇效果处理与道具替换 |
| `black_taisui/presentation.lua` | 保命反馈和这一组道具的 HUD；不推进玩法计时、不消耗生命 |
| `black_taisui/lifecycle.lua` | 原逐玩家更新顺序、换层重置和后段登记；协调三件道具的正式接口 |
| `scripts/features/meat_lump.lua` | 保命与拾取事件入口、旧公开方法兼容 |
| `meat_lump/ledger.lua` | 取得计数、额外生命的读写和消费；每次访问当前存档数据，不缓存旧根引用 |
| `meat_lump/presentation.lua` | 通过生命查询和坐标接口绘制 HUD |
| `scripts/features/cleansed_wavy_cap.lua` | 保留自身充能、房间效果和衰减；属性应用及换层接口接受玩家，自行取得所属状态 |

黑太岁的实际消费者已切换到净化迷幻菇的玩家接口；原接受状态参数的接口保留为兼容适配。肉块的运行读写已切换到唯一账本，旧 Neverbirth 方法委托同一实例。黑太岁的阶段缓存实现也归成长模块，入口调用 `InstallCacheCallback()` 保持它原来夹在两段回调中的位置。

`folk_parasite_state.lua` 未改，继续适配旧 `blackTaisui` 存档与公开运行状态布局。三件道具的字段没有迁移到新格式，也没有改变旧公开引用及新局/继续语义。公共致命伤害查询、保命冷却及民俗效果服务继续使用既有实例；两种保命原有的不同恢复分支保持独立。

保持阶段阈值 8/16、原成长与属性公式、每层保命次数、肉块每份取得记账、原迷幻菇替换及充能政策。保留净化迷幻菇属性的原黑太岁持有条件；没有借独立接口扩大触发条件。原充能修正连续执行 3 次、原主动槽、换层保留 uses 和待处理充能等行为均保留。

## 基线与自动检查

基线 `baseline/` 为 1,045 文件、171,128,867 字节。准备脚本将其完整 SHA-256 清单与第四批候选清单逐项比较，完全相同，因此复用第四批全量证据（114 项通过、107 个 Lua 测试、242 个语法文件），没有把复用表述成本轮重新运行。另在修改前重新运行民俗完整行为、黑太岁/肉块 20 项、共享依赖和 REPENTOGON 实际登记伤害顺序 12 项，全部退出 0。

本批新增 3 个测试入口：

- `batch5_lifecycle_test.lua`：同一完整入口场景先在原始快照运行，再在候选运行。覆盖副主动槽充能与三次修正、渲染不推进计时、多人房间效果、换层保留原充能规则、未知字段、新局/继续引用变化、无黑太岁时的原属性条件和保命恢复。
- `batch5_dependencies_test.lua`：当前存档替换、取得去重、再次取得、写入失败时原修改/保存顺序、HUD 不消费生命、净化迷幻菇只重置自己的字段并跟随运行状态替换。
- `batch5_loading_test.lua`：10 个本组模块各加载一次，实际函数归属正确，关键回调只登记一次。

本批初步 LuaAll 为 117 项通过、110 个 Lua 测试、252 个语法文件。最终当前工作区 LuaAll 为 **119 项通过、0 失败、0 阻塞**，112 个 Lua 测试、254 个语法文件；多出的两个测试来自并行的前四批优化任务。通用验证器仍有基线已有的 6 条资源解析警告，项目专用严格检查为 0 警告、0 失败。

冻结候选 `candidate-runtime/` 为 1,056 文件、171,149,489 字节，含本批 10 个新增源码/测试文件，以及复制时已经出现的并行优化测试文件。这是验证副本，不是发布包。副本中选定以下 10 个检查入口实际运行并全部退出 0：

`batch5_lifecycle_test.lua`、`batch5_dependencies_test.lua`、`batch5_loading_test.lua`、`folk_modules_shared_dependencies_test.lua`、`black_taisui_meat_lump_behavior_test.lua`、`folk_horror_items_behavior_test.lua`、`damage_acceptance_test.lua`、`repentogon_damage_order_test.lua`、`thin_entry_installation_test.lua`、`persistence_test.lua`。

其中安装失败回滚覆盖 64 个实际模块加载失败、3 个登记失败变异。登记对照使用冻结的基线与候选：472 条原夹具记录完全一致；补齐清房枚举后 474 条记录完全一致，包含事件、优先级、过滤、函数身份和顺序。该结果描述第五批的影响，未把随后并行任务的新登记算作第五批改变。

## 原生对照

运行环境为 Repentance `1.7.9b.J835` / REPENTOGON `1.0.12a-yin-api1-dev`。最终有效对照是 `baseline-isolated` / `candidate-isolated`：**各 5 组场景、44 项通过、0 失败，6 组结构化观测完全一致**。

两次都从对应的完整 Lua 快照加载入口与全部同步 include，完成加载后恢复原 include，再安装临时探针。这样并行任务对春药、盒子、流量流程及入口接线的修改不会混入第五批比较。资源仍使用当前安装中的原资源，已通过文件哈希确认未变。

| 场景 | 两边一致的原生结果 |
| --- | --- |
| 黑太岁取得与成长 | 真实底座取得；原生红心治疗增加 2 寄生值；阶段二/三边界正确，阶段三只生成 1 个肉块 |
| 肉块实际取得 | 两次真实底座拾取得到 2 份生命；拾取事件与轮询不重复；旧取得计数、生命字段均保存为 2 |
| 致命伤害顺序 | 第一次原生伤害消耗黑太岁保命、保留 2 份肉块；同次接触的后续伤害不重复消费；冷却结束后下一次伤害消耗 1 份肉块，保持存活及半颗红心 |
| 原版迷幻菇替换与使用 | 原版道具被替换为净化迷幻菇并占用真实主动槽；一次使用、3 次充能修正后为 800，移动速度约 0.97，MaxFireDelay 为 9.25 |
| 换房与真实杀敌清房 | 未标记清房的宝箱房保留 0.06 移速惩罚和约 0.30 射速修正；进入实际战斗房并杀敌清房后只衰减一次，保留原浮点舍入结果 |
| 换层 | 黑太岁保命重新可用；肉块剩余 1 份；迷幻菇 uses 保持 1，房间效果归零，剩余肉块数保存为 1 |

阶段数值 8/16 通过既有诊断方法设置；真实治疗、缓存、阶段奖励底座、取得、TakeDamage、冷却、替换、主动使用、房间转换与清房走引擎。战斗房 NPC 由探针调用原生 Kill 清理，不能据此宣称人工战斗手感通过。

本轮原生检查未覆盖真实多人、退出进程后继续游戏、人工 HUD/音效/动画观感。多人、继续和状态替换已有 Lua 检查；原生保存字段与换层保持已有游戏检查，两种证据分别成立。

## 发现与处理

- 初次新生命周期测试把浮点衰减结果与整数 0 直接比较，得到约 `5.55e-17`。改为容差比较后，未改原计算。
- 初次原生基线及追加诊断各为 38 项通过、1 项失败。日志确认所选宝箱房 `IsClear=false`，原代码按条件保留残留效果；探针错误地将空房等同于清房。保留原探针和日志，追加真实战斗房清理后 44 项通过。没有修改生产玩法迎合该断言。
- 运行中发现并行优化任务增加测试并修改其他道具。范围检查曾正确报告这些额外改动；随后改为核对冻结候选中的本批精确变更，逐文件确认本批源码仍与候选一致，并单列当前工作区的并行差异与哈希。未覆盖或回退这些差异。

每次原生运行快照 227 个配置/存档文件，正常退出后恢复 6 个改变的原文件、归档移出 3 个运行期新增文件；恢复错误和未处理新增文件均为 0。完整日志在退出时刷出，运行器最终为 `COMPLETED_LOG_FLUSHED_ON_EXIT`，游戏退出码 0。所有本轮进程通过后台回调运行，无桌面键鼠输入；本轮探针挂载已经撤销。

## 实际检查命令

工作目录为 `E:\Isaac - Repentance\mods\neverbrith`；副本专项使用 `candidate-runtime` 为工作目录。Lua 路径为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。

| 命令 | 退出码 |
| --- | --- |
| `node reports/refactor-batch5/2026-11-25/snapshot.mjs` | 0 |
| `node reports/refactor-batch5/2026-11-25/prepare-verification.mjs` | 0 |
| `lua.exe tests/batch5_lifecycle_test.lua reports/refactor-batch5/2026-11-25/baseline/` | 0（浮点断言修正后） |
| `node reports/refactor-batch5/2026-11-25/snapshot.mjs candidate-runtime` | 0 |
| `lua.exe reports/refactor-batch5/2026-11-25/compare-registration.lua` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch5/2026-11-25/run-native-isolated.ps1 -Attempt baseline-isolated -Baseline -TimeLimitSeconds 55` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch5/2026-11-25/run-native-isolated.ps1 -Attempt candidate-isolated -TimeLimitSeconds 55` | 0 |
| `node reports/refactor-batch5/2026-11-25/compare-native.mjs baseline-isolated candidate-isolated` | 0 |
| `node reports/refactor-batch5/2026-11-25/verify-scope.mjs` | 0 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch5/2026-11-25/final-checks.json` | 0 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 0 |
| `git -c core.safecrlf=false diff --check` | 0 |

主要证据为 `baseline-evidence.json`、`preliminary-checks.json`、`final-checks.json`、`native-comparison.json`、`scope-parity.json` 及最终两次原生运行的 `result.json` / `game-log.txt`。

## 范围与回退

本批永久修改 3 个道具入口、1 个独立依赖测试夹具入口和项目地图；新增 7 个生产模块、3 个测试、本批计划和报告。`content/`、`resources/`、`generated/` 共 704 个基线文件字节一致。

并行任务对春药、天使盒、恶魔盒、奖励心、流量取得、入口接线及相关测试的修改按实际哈希单列在 `scope-parity.json`。本批没有改写这些生产逻辑。当前 main.lua 的流量取得绑定与本批基线不同，属于并行任务；本轮原生运行恢复的是各次启动前的入口字节，不能以旧基线覆盖当前入口。

若单独回退第五批，先确认目标文件未发生后续修改，仅恢复三个道具入口和 `tests/folk_modules_shared_dependencies_test.lua` 的本批差异，移除本批 7 个模块和 3 个新测试；项目地图只撤回第五批段落，保留其他任务追加内容。原存档无需迁移。不能整目录恢复基线、不能回退并行优化、不能把历史游戏存档快照覆盖到用户后来的游戏进度。

本批没有提交、推送、发布或升级依赖。全项目剩余道具重构和人工验收仍是后续工作。
