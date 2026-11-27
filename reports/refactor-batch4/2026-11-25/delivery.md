# 第四批重构交付：小皮鞋与三件流量奖励

日期：2026-11-25（Europe/Warsaw）。本批已写入当前 mod 工作区。范围为小皮鞋、流量：开箱、流量：曝光、流量：热度的内部职责整理，沿用已确认玩法和既有独立道具入口。

## 实际修改

| 文件 | 当前职责 |
| --- | --- |
| `scripts/features/little_leather_shoes/init.lua` | 保留 NPC 死亡链、返场、流量与延迟清房结算、回调顺序；组装组内模块 |
| `scripts/features/little_leather_shoes/rules.lua` | 原概率、流量最大值、档位和奖励选择的纯计算 |
| `scripts/features/little_leather_shoes/rewards.lua` | 底座追踪、二选一、实际库存取得确认、消费与奖励派发 |
| `scripts/features/little_leather_shoes/presentation.lua` | HUD、字体缓存、连线、拾取动画与完成通知；不直接发奖励或刷新属性 |
| `scripts/features/little_leather_shoes/runtime_views.lua` | 限制各所有者可读写的状态字段，同时保留旧公开平面状态的字段和表替换语义 |
| `scripts/features/traffic_heat.lua` | 保存永久热度，拥有临时刷新队列；通过 `GetFrame` 查询原逻辑时钟，不再接收整个小皮鞋运行状态 |

开箱、曝光仍分别调用原 `traffic_unboxing.lua`、`traffic_exposure.lua`，两文件字节未改。开箱和曝光的不同奖励/回退政策没有合并。`main.lua` 字节与本批开始时一致；模块只创建一次，没有新增全局调度器或回调总线。

原 `LittleLeatherShoesState`、`LittleLeatherShoesTestAPI` 及 `littleLeatherShoes.heatByPlayer` 存档结构保留。各视图是运行期对象，不写入存档；读取旧状态字段会跟随外部表替换，未捕获失效队列。旧存档中的未知字段继续保留。

保持返场 33/22/11%、6/8/12 流量档位、每层热度原射速公式、玩家键和更新次序。新取得的热度下一逻辑帧刷新。开箱在动画完成或第 8 次更新发箱；渲染不会推进拾取动画寿命。原无 Sprite 即时回退、构造/加载异常不发奖，以及发奖出错时先前的队列移除顺序均保留。

## 自动检查

基线快照 `baseline/`：1,037 文件，171,103,149 字节。候选快照 `candidate-runtime/`：1,045 文件，171,128,867 字节；复制时逐字节核对，最终再核对 SHA-256。

基线 LuaAll：111 项通过、0 失败、0 阻塞，104 个 Lua 测试、234 个语法文件。最终 LuaAll：**114 项通过、0 失败、0 阻塞**，107 个 Lua 测试、242 个语法文件。两次均有相同的 6 条通用资源解析警告，涉及三份 XML 中的死亡图标 ANM2 路径和原版早餐图标；项目专用严格验证器为 0 警告、0 失败。

新增的生命周期测试先对未改基线运行，再对候选运行：多人多份取得、开箱第八次更新/提前结束、换房保持旧动画、换层取消旧动画并重建热度刷新、二选一底座消失后的库存确认、Sprite 失败路径、未知存档字段、重新加载入口继续游戏以及失效玩家队列清理。

新增依赖测试覆盖越界字段访问、旧公开表重新绑定、动态存档替换、动态时钟读取、渲染无奖励副作用、发奖抛错时的移除顺序。加载测试检查 8 个模块只加载一次，实际函数归属，以及该组 11 条回调各登记一次。原真实入口回滚测试覆盖 57 个模块加载失败与 3 个变异登记失败。

完整登记对照：旧夹具的 472 条记录一致；补齐原夹具缺少的清房回调枚举后，474 条记录仍一致。比较事件、优先级、过滤参数、处理函数身份和相对顺序；该组的 11 个原生回调均被覆盖。

候选独立副本中实际运行了以下 7 个入口，全部退出 0：

- `tests/little_leather_shoes_behavior_test.lua`
- `tests/box_and_shoes_repentogon_regression_test.lua`（24 项通过）
- `tests/batch4_traffic_lifecycle_test.lua`
- `tests/batch4_traffic_dependencies_test.lua`
- `tests/batch4_loading_test.lua`
- `tests/thin_entry_installation_test.lua`
- `tests/persistence_test.lua`

## 原生游戏对照

本机 Repentance `1.7.9b.J835` / REPENTOGON `1.0.12a-yin-api1-dev`。最终两次运行是 `baseline-b` 和 `candidate-b`：各 **6 组场景、33 项通过、0 失败**；6 组结构化观测完全一致。基线仅把小皮鞋旧入口与热度旧模块重定向到快照；两边均保留并行任务的其他修复。

| 场景 | 两边一致的实际结果 |
| --- | --- |
| 小皮鞋真实底座取得 | 当层等待，下层启用返场与流量 |
| 原生敌人死亡与返场 | 观察到 5 次返场；最大死亡链为 3，房间累计 3 流量；只结算一次 |
| 开箱真实取得 | 道具消费后等待 7 次后续更新（包含取得帧共 8 次），生成 1 个真实宝箱，不重复 |
| 曝光二选一 | 取得曝光后删除热度底座、清除连线；实际宝箱房池生成 1 个奖励，两边运行时 ID 均为 795 |
| 热度真实取得 | 消费道具，永久层数存为 1，下一逻辑帧刷新；真实 MaxFireDelay 为 8.2957744598389 |
| 丢失与换层 | 丢失后当层停止返场；下一层停用小皮鞋；热度永久层数及射速继续保留，临时队列换新 |

输入控制说明：首轮 `baseline-a` / `candidate-a` 各自 33 项均通过，但额外测试怪物由 `Isaac.Spawn` 产生了不同的实体种子，返场总数不一致，因此首轮结果比较退出 1，未当作完全相同的输入。初版探针保存为 `probe-unseeded.lua`。最终探针只为测试 Gaper 的生成与返场提供固定种子序列，调用原生 `Game:Spawn` 创建真实实体；登记、死亡、返场判定、清房和奖励仍走正式模块。生产代码的 RNG、概率和发奖政策未因此改变。

最高档位二选一由诊断接口创建，实际底座碰撞、库存确认、消费、选项删除和池抽取在引擎内运行。本轮没有把完整一层自然积攒至 12 流量再击败 Boss 当作已实测。敌人由探针调用原生 Kill 触发死亡，不代表人工战斗手感验收。

所有原生运行仅通过游戏回调操作本轮隐藏进程，无桌面键鼠输入。每次快照 227 个配置/存档文件，正常关闭游戏、恢复 6 个改变的旧文件，将 3 个运行期新文件归档移出原位置；恢复错误和未处理新文件均为 0。日志在正常退出时完整刷出，运行器最终状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`，不是未完成的超时。主入口已恢复，无遗留游戏进程或探针挂载。

真实多人、退出进程后继续游戏、人工 HUD/连线/动画观感未在本轮原生场景覆盖。多人和重新加载入口的继续行为已有 Lua 行为证据；原生存档字段写入及换层保持已有游戏证据，两者不等同于跨进程继续游戏验收。

## 命令与退出码

工作目录除独立副本检查外均为 `E:\Isaac - Repentance\mods\neverbrith`。Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`（5.4.6）。

| 实际命令 | 退出码 |
| --- | --- |
| `node reports/refactor-batch4/2026-11-25/snapshot.mjs` | 0 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch4/2026-11-25/baseline-checks.json` | 0 |
| `lua.exe tests/batch4_traffic_lifecycle_test.lua reports/refactor-batch4/2026-11-25/baseline/` | 0 |
| `node reports/refactor-batch4/2026-11-25/snapshot.mjs candidate-runtime` | 0 |
| `lua.exe reports/refactor-batch4/2026-11-25/compare-registration.lua` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch4/2026-11-25/run-native.ps1 -Attempt baseline-b -Baseline -TimeLimitSeconds 55` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch4/2026-11-25/run-native.ps1 -Attempt candidate-b -TimeLimitSeconds 55` | 0 |
| `node reports/refactor-batch4/2026-11-25/compare-native.mjs baseline-b candidate-b` | 0 |
| `node reports/refactor-batch4/2026-11-25/verify-scope.mjs` | 0 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch4/2026-11-25/final-checks.json` | 0 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 0 |
| `git -c core.safecrlf=false diff --check` | 0 |

首轮未完成的检查也保留：新增加载测试最初预期 11 回调，旧夹具缺少清房枚举只登记 10，退出 1；在本批专用夹具补齐枚举后通过，未减少生产登记或放宽数量断言。首轮原生输出比较的不同种子问题见上文。最终生产代码不含为通过这些检查而改变玩法的修补。

主要机器可读证据：`final-checks.json`、`native-comparison.json`、`scope-parity.json`、两次最终原生运行的 `result.json` / `game-log.txt`。

## 范围与回退

本批开始时已有大量未提交的前三批/薄入口重构，全部保留。与本批快照相比，本批改动 4 个已有文件，新增 4 个生产模块、3 个测试和 1 个测试夹具；另新增本批计划与交付材料。`content/`、`resources/`、`generated/` 共 704 个文件字节一致；其余未涉及的运行 Lua 共 124 个文件字节一致。

并行任务修改了 `scripts/features/between_death_and_life.lua` 和对应行为测试以修复原生拾取，已在范围报告中单列，未覆盖、回退或计入本批实现。

若需要单独回退第四批，应先确认回退时文件没有新改动，再仅从 `baseline/` 恢复本批 4 个旧文件（小皮鞋入口、热度、旧小皮鞋行为测试、项目地图），移除本批 4 个模块和 4 个新测试/夹具，并处理本批计划/报告链接。不能整目录覆盖基线，也不能恢复生死一念间的并行修复。原生配置和存档已经恢复，不需要把游戏状态快照再次整份覆盖到当前用户存档。

本批无提交、推送、发布或依赖升级。
