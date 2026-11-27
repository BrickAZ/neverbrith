# 第十八批交付：胆小鬼之夜、神风特攻队

本批两件道具已完成本地职责拆分、旧新行为对照与专项原生验证。未提交、推送或发布。它是整轮重构的阶段性交付；其他并行批次及整工作区最终验收不由本批代替。

## 变化与保持项

| 道具 | 当前入口 | 本批职责拆分 | 结果 |
| --- | --- | --- | --- |
| 胆小鬼之夜 | `night_of_the_cowards.lua` → `scripts/features/night_of_the_cowards.lua` | 查询与 NPC 资格、c20 赠予账本、变形与光环、玩家禁射与恐惧显示、生命周期 | 已迁移；旧新模拟和专项原生通过 |
| 神风特攻队 | `kamikaze_squad.lua` → `scripts/features/kamikaze_squad.lua` | 实体身份/世界查询、敌人索引、持有者与自爆单位、回调生命周期 | 已迁移；旧新模拟和专项原生通过 |

两件根工厂保留兼容路径、返回值与 main.lua 原装配位置。每个入口只创建一次私有实例，各 callback 的处理函数和绑定同文件紧邻，事件/过滤/顺序不变。83 个函数体及相邻安装方法与冻结旧代码逐字一致；常量及默认值块保持一致，13 个本批生产文件与原生候选快照哈希一致。

胆小鬼保留三种 Host 变体、冠军参数、原生死亡之首排除、48 半径、单实例光环与 c20 每玩家一次记录；`nightOfTheCowards.runSeed/c20Granted` 的字段、种子比较、玩家键和 Save 调用点不变。神风保留每持有者 90 更新帧、最多两只、玩家来源/友方标记、重选目标、爆炸预检→摘引用→Remove→爆炸、失败不重复及换房等边界静默清理。爆炸传参仍为伤害 40、半径倍数 2，没有借重构修改平衡或声称它等同原生自带死亡爆炸。

22 个 content 文件与开工快照相同；两件图标及旧 CowardsNight 资源与 Git HEAD 哈希相同。品质、道具池、资源和存档语义未改。公共 GetPlayers 与 persistence 继续复用原装配实例；其他看似相近的数量查询、实体筛选、头部坐标和种子处理因合同不同保留私有实现，详见[消费者与状态清单](consumer-inventory.md)。本批没有新公共 API。

## 验证证据

| 范围 | 实际结果 | 证据 |
| --- | --- | --- |
| 原行为与新增边界旧新对照 | 两份原行为测试保持全部断言；19 组边界在旧/新均通过；注册描述与状态/保存/爆炸轨迹文本一致；9 条命令 exit 0 | [comparison-checks.json](comparison-checks.json)、[轨迹](candidate-trace.lua.txt) |
| 完整入口与安装失败 | 11 个新入口/私有模块各加载一次；20 条原生绑定；11 个缺模块反例和 20 个逐位置登记失败反例全部回滚 | `tests/batch18_loading_test.lua`，上述比较报告最后一条 |
| 冻结候选全部 Lua 行为测试 | 147/147 通过；392 个语法输入通过，exit 0 | [最终冻结检查](frozen-final-checks.json)、[完整首次输出](frozen-lua-checks.json) |
| 静态验证 | 通用 exit 0，6 项既有资源解析警告；严格 exit 0，0 警告/失败 | [通用输出](frozen-generic.txt)、[严格输出](frozen-strict.txt) |
| 原生最终对照 | 旧/新各 8 场景、28 项通过、0 失败；6 组观察值完全一致 | [native-comparison.json](native-comparison.json) |
| 源码与内容范围 | 83 函数与相邻绑定、两组常量、13 个本批生产文件、22 content 文件及 4 资源哈希核对通过 | [extraction-comparison.json](extraction-comparison.json)、[scope-verification.json](scope-verification.json) |
| 工作区文档导航 | 导航 exit 0；知识检查 exit 1，原因是其他批次的 `scripts/systems/attack_ownership.lua` 尚未进入 API 索引 | [knowledge-checks.json](knowledge-checks.json) |

冻结候选是开工时保存的完整生产 Lua 加上本批变更；它与两侧原生测试使用的其他道具版本一致，避免并行任务半写入的模块或临时主入口污染本批对照。原有 145 份 Lua 测试加本批 2 份，资源、验证工具、文档和 Skill 为检查时复制。冻结检查没有把其他并行批次新增的测试计入本批 147 项。

原生场景覆盖：c20 首次赠予和重获防重复、真实 NPC Morph 与稳定变体选择、单实例原生光环/Parent/Spawner/跟随、Boss/原生死亡之首边界、半径禁射及释放、失效所有者清光环、原生 Mulliboom 生成/玩家归属/友方魅惑、真实爆炸扣除目标 40 HP 且只结算一次、丢失/重获和真实房间切换。

最终两侧使用相同固定种子探针。测试敌人的生成采用原生 `Game:Spawn` 的明确 seed 参数，区别于随机种子的 `Isaac.Spawn`，签名依据[Game API 文档](https://wofsauge.github.io/IsaacDocs/rep/Game.html#spawn)。生产道具的生成方式没有变。探针冻结测试 NPC，并取消测试角色受伤以避免场景被敌人击杀中断；因此本次伤害证明是目标扣血，不包含持有者被爆炸伤害的实机验收。

最终两次均备份 229 个状态文件、正常结束本次隐藏进程、恢复 7 个变更文件，并归档本次新建且经来源/时间/路径/哈希检查确认的一个存档文件。`mainRestored/stateRestored/cleanShutdown=true`，没有恢复错误或未处理新文件。全程没有桌面键鼠输入；没有停止其他任务的游戏进程。

## 实际命令与退出码

在模组根目录执行；Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe` 5.4.6，Node 为 v24.22.1。

```powershell
# exit 0：函数、常量、内容与候选哈希
node reports/refactor-batch18/2026-11-26/verify-extraction.mjs
node reports/refactor-batch18/2026-11-26/verify-scope.mjs

# exit 0：内部记录每条旧/新 Lua 命令和输出
node reports/refactor-batch18/2026-11-26/check-comparison.mjs

# 最终各 exit 0：同一固定种子探针
pwsh -NoProfile -File reports/refactor-batch18/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-03 -Baseline -TimeLimitSeconds 30
pwsh -NoProfile -File reports/refactor-batch18/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-02 -TimeLimitSeconds 30
node reports/refactor-batch18/2026-11-26/compare-native.mjs native-baseline-03 native-candidate-02

# 全冻结 Lua 首轮因漏复制两份测试依赖 exit 1；补齐后仅重跑失败项并解析全部语法，exit 0
node reports/refactor-batch18/2026-11-26/check-frozen-lua.mjs
node reports/refactor-batch18/2026-11-26/final-frozen-checks.mjs

# 各 exit 0
pwsh -NoProfile -File tools/validators/validate-isaac-mod.ps1 -Root reports/refactor-batch18/2026-11-26/verification -ModObjectName Neverbirth -SkillRoot .agents/skills
pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1 -Root reports/refactor-batch18/2026-11-26/verification -GameRoot 'E:/Isaac - Repentance'
pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1

# exit 1：其他批次 attack_ownership 公共 API 登记尚未补齐
pwsh -NoProfile -File tests/project_knowledge_test.ps1
```

## 失败记录与修正

- 开工工作区 LuaAll 为 148 通过/5 失败，exit 1：运行期间其他批次正在改动七诅咒之戒、阴的诅咒和 shooting_scope 文档。保留[基线报告](baseline-checks.json)。冻结源码显示这两根模块当时仍是完整实现，因此该运行过程中途变更的结果不能当作不可变基线。
- 后一次共享工作区 LuaAll 为 68 通过/97 失败，exit 1，主要加载到第十五批临时原生探针；当时第十三批交付文档链接也尚未落盘。保留[受干扰的工作区报告](final-checks.json)。没有修改其他批次来消除这些失败，也没有把该报告写成全量通过。
- 安装检查最初随共享入口加载到了第二十一批临时原生探针，随后使用冻结入口/其他模块完成本批检查；夹具补齐本批涉及的 InputHook 和清房事件常量，不修改生产守卫。
- 夹具迁出后原颜色断言所需 ColorMt 未导出，已补回；旧断言未删除。冻结目录第一次缺少 `read_lua_module_tree.lua` 和原阴的诅咒诊断测试依赖，复制这两个实际依赖后仅重跑失败项，147/147 通过。目录 junction 被环境以 EPERM 拒绝，改用普通文件副本。
- 首次状态轨迹使用生成数组第一只，受到 `pairs` 顺序影响；改为选择同一玩家的第一只单位后逐字一致，保留两侧首次轨迹。生产循环顺序没有改变。
- `native-baseline-01` 为 23 通过/4 失败：立即移动后的空间索引未更新，后半段测试玩家被 Gaper 击杀。加入两帧等待及测试角色伤害取消后，`native-baseline-02` 和 `native-candidate-01` 都为 28/0；但随机 Spawn 的 NPC 种子不同，Host 变体观察不同。改为相同明确种子后，最终 `native-baseline-03` 与 `native-candidate-02` 均为 28/0 且六组观察全部一致。所有原始日志保留；未据此修改玩法。
- 若其他游戏进程或临时主入口占用环境，原生运行器在写入前退出；本批等待空闲后才运行。日志轮询有缓冲，最终结果由正常退出后带本次 attempt 标记的完整日志及总结确认，记录为 `COMPLETED_LOG_FLUSHED_ON_EXIT`。

## 验收边界与撤回

人工画面/操作手感、多人成员变化与合作、跨进程 Continue、全部第三方 Mod 组合和沙漏回溯没有在本批作实机验收；没有新增这些行为的承诺。模块和原游戏接口的基本合约、局内状态边界、失败路径、实际 NPC/爆炸/房间行为已有上述证据。稳定工作区上汇总全部并行批次的 LuaAll 仍需在整轮收口时执行。

回退时仅恢复 `baseline/night_of_the_cowards.lua`、`baseline/kamikaze_squad.lua` 与本批对应测试/导航变化，并移除本批新私有模块及测试文件；不要覆盖其他并行任务的整个 main.lua 或整个 scripts 目录。存档结构未迁移，无存档转换。基线、提取映射、候选和检查快照都在本目录；准备/拆分脚本是过程证据，不应对已交付工作区再次执行。
