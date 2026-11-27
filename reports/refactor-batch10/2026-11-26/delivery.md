# 第十批交付：未生证明、再契象与共同房间交互

2026-11-26，本批已完成本地重构、正式工作区检查和冻结旧/新版本的原生对照。两件已接入共同房间及机关能力，各自保留会话、存档和领取规则。未提交、推送或发布。本批验收范围与人工、多人原生及跨进程 Continue 的未验证边界分别记录如下；不据此宣布整个 Mod 重构完成。

## 基线与并行工作

- 初始工作区保存为 `baseline`（1141 个文件），包含既有未提交成果，没有以 Git HEAD 覆盖工作区。
- 实施期间另一任务修改了生命周期和私有边界，因此本批先在 `staged` 内完成。保留初始快照，并先建立 `baseline-lifecycle`，最后冻结包含该任务最终修复的 `baseline-final`（1145 个文件、171615638 字节）。最终对照使用 baseline-final；另一任务的修复不计为本批结构迁移成果。
- `candidate-runtime` 由 baseline-final 加本批运行代码构成。原生测试通过后，`apply-staged.mjs` 逐文件核对正式工作区与最终基线，再接回 24 个文件；发生并行改动会拒绝覆盖。随后更新目标架构与两份计划，没有删除正式文件。
- 最终快照 `final-runtime` 为 1163 个文件、171670518 字节。[范围校验](final-scope.json)确认快照范围内只修改 7 个既有文件、新增 18 个文件；两份计划额外记录哈希。705 个 `main.lua`、content、resources、generated 文件保持最终基线哈希；894 个运行代码/内容文件与原生测试候选版逐字节一致。
- 快照范围是根目录 Lua/XML/Markdown、scripts/content/resources/generated/tests/tools、docs/agent/api/architecture；不包含整个 Git 仓库、所有历史报告或 `.agents`。最终 LuaAll 在正式工作区执行，包含当前权威 Skill 包与文档检查。

## 实现与责任

两件各有一个入口和五个私有模块，入口只创建本实例的 state/config/lifetime 及私有模块，按原顺序安装回调：

| 私有模块 | 责任 |
| --- | --- |
| ledger | 未生证明目录与栈、再契象历史与候选；动态读取本件原 Store，保存调用点不变 |
| gallery | 本件底座、机关、布局合法性与动画政策 |
| flow | 进入、分页、接管、返回、房间事件及原 CarrierAPI 实现 |
| pickups | 未生证明领取后释放锁；再契象三份预留、队列确认与完成返回 |
| runtime | 更新、开始、退出、卸载及本实例运行门控 |

| 公共模块 | 两件实际接入的能力 | 保留在道具内的差异 |
| --- | --- | --- |
| [archive_room](../../../scripts/systems/archive_room.lua) | 原生方法调用、维度、玩家位置保存/恢复、分页邻接、边界与布局 | Certificate 位置过滤与诊断，House 不新增过滤；原 Game 查询合同不改用合同不同的 world_queries |
| [archive_controls](../../../scripts/systems/archive_controls.lua) | 动画调用、无碰撞设置、距离检测、触碰锁清理 | Certificate 的 requested/played marker、失败缓存；House 的 Variant 重试/0 值；生成/删除异常、机关计时与触发顺序 |

共享模块没有回调、会话、存档写入、RNG 或道具池请求。Room 实例只绑定自身玩家查询及诊断前缀，不缓存世界对象。回调处理函数与对应注册在私有模块中相邻，主装配及原安装顺序不变。

未生证明继续保留嵌套栈、页内容、父子返回和领取释放锁；再契象继续保留遇见记录、主动排除、早餐补足、全队三份预留及 Continue 中止选择并返回的策略。保留原存档字段、token 递增、Save 调用点和动态 Store.Replace 读取。CarrierAPI 与 TestAPI 的原名字、函数引用关系保留，业务实现已从入口移到 flow。

详细签名、用法、副作用、生命周期和真实消费者见[公共 API](../../../docs/api/archive-rooms.md)；逐道具及旧入口状态见[消费者清单](consumer-inventory.md)。原有两件行为测试的断言保留，只将源码检查改为沿实际 literal include 树读取；实际加载另由完整入口测试验证。

## 前后对照与最终检查

以下命令均从仓库根目录运行。`lua.exe` 指 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`；表中的 `<版本>` 分别为 baseline-final、candidate-runtime。

| 检查 | 实际命令 / 证据 | 结果 |
| --- | --- | --- |
| 冻结源码生成 | `node reports/refactor-batch10/2026-11-26/snapshot.mjs baseline-final`；`node reports/refactor-batch10/2026-11-26/split-items.mjs baseline-final` | 均退出 0，旧源码快照保留 |
| 原两件行为与新增联合场景 | `lua.exe reports/refactor-batch10/2026-11-26/run-frozen-test.lua <版本> tests/<certificate_of_neverbirth_behavior_test.lua或house_vs_elephant_behavior_test.lua或batch10_pair_lifecycle_test.lua>` | 6 次运行均退出 0；联合场景两版各 10 项通过，日志为 `final-<版本>-<测试名>.log` |
| 全入口登记 | `lua.exe reports/refactor-batch10/2026-11-26/compare-registration.lua` | 退出 0；[登记对照](final-registration-comparison.log)为 legacy 520、complete 534 条，事件、优先级、过滤器、可辨识处理器身份及顺序一致 |
| 提取体核对 | `node reports/refactor-batch10/2026-11-26/verify-extraction.mjs baseline-final` | 退出 0；[核对记录](extraction-review.json)：规范化 lifetime 变量转发后，55+56 个函数/安装器体保持一致；每件 8 个公共调用适配器、9 个公共函数迁出，CarrierAPI 业务体一致 |
| 存档/实体轨迹 | `lua.exe reports/refactor-batch10/2026-11-26/run-frozen-test.lua <版本> reports/refactor-batch10/2026-11-26/trace.lua` | 两版退出 0；[旧轨迹](trace-baseline-final.txt)与[新轨迹](trace-candidate-runtime.txt)各 405370 字节，7 组观测逐字节一致；比较由最终范围脚本断言 |
| 原生基线 | `pwsh -NoProfile -File reports/refactor-batch10/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-01 -Baseline -TimeLimitSeconds 55` | 退出 0；[基线结果](native-baseline-01/result.json)，3 场景、26 项通过、0 失败 |
| 原生候选 | `pwsh -NoProfile -File reports/refactor-batch10/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 55` | 退出 0；[候选结果](native-candidate-01/result.json)，3 场景、26 项通过、0 失败 |
| 原生比较 | `node reports/refactor-batch10/2026-11-26/compare-native.mjs native-baseline-01 native-candidate-01` | 退出 0；[26 项检查与 6 组观测](native-comparison.json)一致 |
| 接回正式工作区 | `node reports/refactor-batch10/2026-11-26/apply-staged.mjs` | 退出 0；[24 个文件及哈希](applied-files.json)，没有覆盖漂移文件 |
| 最终全量 | `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch10/2026-11-26/final-checks.json` | 退出 0；[机器报告](final-checks.json)：148 项通过、0 失败、0 阻塞；140 个 Lua 测试、339 个 Lua 语法文件 |
| 最终范围 | `node reports/refactor-batch10/2026-11-26/snapshot.mjs final-runtime`；`node reports/refactor-batch10/2026-11-26/verify-final-scope.mjs` | 均退出 0；正式运行文件与原生候选一致，资源/登记/生成目录与基线一致 |
| 空白检查 | `git -c core.safecrlf=false diff --check` | 退出 0；只检查已跟踪文件，新文件由上述语法、文档与范围检查覆盖 |

LuaAll 的 generic 验证器保留 6 条既有警告：三个 items XML 中的 `gfx/UI/NeverbirthDeathItems.anm2` 与 `Collectibles_025_Breakfast.png` 路径未被该验证器解析。strict、知识/公共 API、README、agent 导航及其他选中检查均通过；这些路径所在内容文件本批哈希不变。

联合生命周期 10 个场景包括：嵌套与接管恢复、返回失败重建重试、Continue 差异和同种子新局、三人同时预留并仅在实际授予后结算、Certificate 专有位置过滤、实例/Store 隔离及卸载门控、Variant 失败缓存/0 值差异、进入失败与 token 政策、Spawn 异常边界、动画缺失与已尝试播放的 marker 差异。公共边界测试另覆盖 nil/false/缺方法/抛错、维度、玩家重绑、布局、动画失败、距离及触碰锁；加载测试覆盖每个私有模块一次创建、回调所有者和 12 个失败注册阶段的完整回滚。

保存轨迹包含每次 Save 时的完整 plain-table 根数据、房间跳转、实体和诊断。最初让三次授予同时成熟时，Lua 不同进程的 `pairs(pending)` 顺序导致中间 Save 序列顺序不稳定；生产循环未改。精确轨迹用固定的逐帧授予顺序消除该测试不确定性，另由联合测试保留三份同时成熟的最终结果检查。

独立审查曾指出 CarrierAPI 业务仍在入口，已原样移入 flow 并复核函数体与回调引用；后续审查没有报告剩余阻塞问题。最终范围检查初稿将后补的导航/API 文档也错误要求与原生候选目录一致，核对实际差异后改为：文档/测试核对 reviewed stage，所有运行代码/内容核对原生候选；没有为通过检查修改候选运行源码。

## 原生场景与数据恢复

原生版本日志为 `1.0.12a-yin-api1-dev`，固定种子 `27182818`，两次使用同一 probe，只有源码快照前缀不同。无桌面键鼠输入；脚本以隐藏进程启动本机游戏，只向自己启动的 PID 请求正常关闭。

1. 真实使用未生证明，核对六个底座、三个机关、下一页/上一页与保存的会话栈。
2. 嵌套第二层未生证明后使用再契象，核对接管、机关互斥、接管时拒绝未生证明、返回子会话再返回父会话，最终回到原房间及原位置。
3. 原房间生成并记录普通道具，以再契象进入选择房间并分页；通过原生玩家碰撞实际领取三件，前两件仍留房间，第三件关闭会话并返回；遇见历史及未生证明保存区域仍存在。

6 组观测含页码、道具 ID/坐标、会话 token、栈深、原房间/玩家位置、候选数量和实际授予 `[1,4,8]`。两版一致。该观测不等于完整二进制游戏存档逐字节一致；完整 plain-table Save 轨迹是在模拟层比较。

两次启动前各备份 227 个配置/存档文件。日志存在退出时刷新，因此轮询达到 55 秒后请求正常关闭，完整 DONE/26 项总结随后落盘，状态记为 `COMPLETED_LOG_FLUSHED_ON_EXIT`；不是把未完成的场景超时视为通过。两次游戏均正常退出 0，`cleanShutdown`、`mainRestored`、`stateRestored` 均为 true，恢复错误和未知新增文件均为空。每次恢复 6 个变化的已有文件，将 3 个经确认本次新生成的存档文件归档到该尝试目录，原游玩数据已恢复。

## 验收边界与撤回

- 本批完成两件私有职责、共同能力、既有玩法/存档合同的模拟与上述原生对照。
- 未进行人工画面、声音及操作手感验收；未进行多人原生、跨进程退出后 Continue、沙漏原生回退或全部第三方组合验收。Continue、新局、Store 替换与三人预留只有上述模拟覆盖，不扩大原生结论。
- 不修改内容 ID、品质、道具池、资源或新存档格式。若需撤回，应先核对当前文件仍对应本次哈希，再仅将 `applied-files.json` 中原已存在的文件恢复自 baseline-final、将本批新增文件按清单移出加载范围，并单独撤回本批导航/计划条目；不能整体恢复旧快照而覆盖之后的其他工作。无需存档格式迁移。
- 原有 38 件及其他未纳入本批的道具仍按各自清单和证据维护。本批两件的完成不覆盖调试控制器、焚尽郁结、柴刀、千变万化、ACE 及根目录旧模块的剩余重构。
