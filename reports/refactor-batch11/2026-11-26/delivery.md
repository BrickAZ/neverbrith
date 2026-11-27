# 第十一批交付：焚尽郁结

2026-11-26，本批本地重构、冻结旧/新源码对照、原生场景及正式工作区检查已完成。焚尽郁结的玩法参数、运行状态和继续游戏语义保持基线，未提交、推送或发布。本结论仅覆盖下述范围，不代替整个 Mod 或人工体验验收。

## 结构与共同能力

原单文件的职责分别落到六个私有模块，入口只持有原配置、实例依赖、公开兼容引用和原回调安装顺序：

| 模块 | 责任 |
| --- | --- |
| queries | 生命、敌人/房间有效性、伤害来源与排除条件 |
| attributes | 属性刷新和原 cache 回调，保留直接减少 MaxFireDelay 的公式 |
| ledger | 玩家状态创建、房间记账、积层、楼层结算 |
| presentation | 状态 Sprite、爆发 Sprite/位置/年龄及视觉清理 |
| combat | 主动爆发、实际受伤确认、原生伤害与 burn、重入深度 |
| runtime | 更新、换房/换层、开始/退出/卸载，以及状态与引用清理协调 |

沿用 folk_world 的世界/持有/身份查询和 player_geometry 的头部位置；直接攻击 owner 的受保护 ToPlayer 转换接入既有 combat_source.TryPlayer。没有新增公共框架或无人消费的工具。共享方法合同未改，新增真实消费者及调用前后责任已写入[API 文档](../../../docs/api/shared-mechanics.md)。

柴刀的 active enemy、Position、friendly/dead 判定，incoming_damage 的 HasMortalDamage/异常传播，以及 fire_rate 的射速单位换算均与本件不同，因此保留本件规则。完整归属、公开兼容与保留差异见[消费者清单](consumer-inventory.md)，全量原入口清单更新了焚尽郁结一行，其他道具保持此前状态。

## 保持的行为与生命周期

- 保留初始 2 层、最多 6 层、普通清房 +1/Boss +2、房间去重和下一战斗房间的满层就绪规则。
- 保留满层直接玩家攻击爆发、3–6 层敌方伤害后的实际健康减少确认、3 次 update 等待窗口、献祭/支付等排除、一次楼层结算和原重入保护。
- 保留伤害/速度/射击间隔参数、90 帧 burn 参数、状态动画、爆发动画及 36 次 update 清理。动画完成、活跃爆发换房、移除本人及退出卸载的清理均有模拟断言。
- 本件楼层记录本来不序列化；新局和 Continue 都清空。没有加入 SaveData、存档版本或沙漏逻辑。公开 states/GetState/头部位置别名及三个具名回调保留动态访问，旧状态引用在清理时仍释放 player、Sprite 和 pendingHurtBurst。
- 原 WorldToScreen 失败后的世界坐标回退、严格布尔判断及异常吞吐边界保持；本批没有把这些既有行为改成新的修复政策。

## 基线、范围与审查

基线是开工时的真实脏工作区，包含前十批和已有生命周期修复：`baseline` 为 1163 个文件、171670518 字节，不以 Git HEAD 替代。冻结候选为 `candidate-runtime`，最终正式快照为 `final-runtime`（1172 个文件、171688183 字节）。

快照范围含根目录 Lua/XML/Markdown、scripts/content/resources/generated/tests/tools、docs/agent/api/architecture；不包含整个 Git 仓库、所有报告或 `.agents`。[范围报告](final-scope.json)确认只修改其中 6 个既有文件、新增 9 个文件，没有删除；两份计划另记哈希。705 个主入口/内容/资源/生成目录文件保持基线哈希，900 个运行代码/内容文件与原生测试候选逐字节一致。最终 LuaAll 在正式工作区验证当前权威 Skill 包及导航。

[提取核对](extraction-comparison.json)与[独立审查](review.md)确认：29 个原函数中 26 个仅改变模块引用/lifetime 名称，函数体保持一致；另外 3 个是 TryPlayer 复用、ClearPlayer/ ClearRuntime 中的视觉及重入深度清理下沉。审查没有遗留问题；提出的 P3 视觉测试覆盖不足已补齐，并获再次确认。

原有行为测试的全部断言保持，原 fixture 抽到 support 供新旧检查复用；既有生命周期断言保持，仅适配私有模块观察路径。生产代码没有为测试增加 TestAPI。登记比较对本件匿名回调逐体规范化模块名及 ClearBursts 提取，其他登记规则不变。

## 实际命令与结果

命令从仓库根目录执行。`lua.exe` 指 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`；`<版本>` 分别为 baseline、candidate-runtime。

| 检查 | 实际命令 / 证据 | 退出码与结果 |
| --- | --- | --- |
| 基线/候选/最终快照 | `node reports/refactor-batch11/2026-11-26/snapshot.mjs <baseline或candidate-runtime或final-runtime>` | 各 0，逐文件校验复制与 SHA256 |
| 旧行为和生命周期对照 | `lua.exe reports/refactor-batch11/2026-11-26/run-frozen-test.lua <版本> tests/<burn_away_resentment_behavior_test.lua或refactor_lifecycle_transient_test.lua>` | 4 次均 0；原行为和既有 19 场景生命周期在两版通过 |
| 新边界对照 | `lua.exe reports/refactor-batch11/2026-11-26/run-frozen-test.lua <版本> tests/batch11_boundaries_test.lua` | 两次 0，各 10 组；同一组冻结测试 fixture，无删减旧断言 |
| 加载及回滚 | `lua.exe tests/batch11_loading_test.lua`；`lua.exe tests/thin_entry_installation_test.lua` | 各 0；六模块一次创建、三个公开回调身份、9 个本件登记失败阶段回滚；完整入口 114 个真实导入失败、3 个登记失败检查通过 |
| 全入口登记 | `lua.exe reports/refactor-batch11/2026-11-26/compare-registration.lua` | 0；[520／534 条登记](registration-comparison.log)事件、过滤、优先级、处理器身份及顺序一致 |
| 状态/属性/视觉轨迹 | `lua.exe reports/refactor-batch11/2026-11-26/run-frozen-test.lua <版本> reports/refactor-batch11/2026-11-26/trace.lua` | 两次 0；[旧轨迹](trace-baseline.txt)与[新轨迹](trace-candidate-runtime.txt)各 12422 字节，7 组观测逐字节一致 |
| 函数与轨迹核对 | `node reports/refactor-batch11/2026-11-26/verify-extraction.mjs` | 0；26 个同体、3 个适配、7 组轨迹一致 |
| 原生基线 | `pwsh -NoProfile -File reports/refactor-batch11/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-02 -Baseline -TimeLimitSeconds 40` | 0；[结果](native-baseline-02/result.json)：5 场景、25 通过、0 失败 |
| 原生候选 | `pwsh -NoProfile -File reports/refactor-batch11/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 40` | 0；[结果](native-candidate-01/result.json)：5 场景、25 通过、0 失败 |
| 原生比较 | `node reports/refactor-batch11/2026-11-26/compare-native.mjs native-baseline-02 native-candidate-01` | 0；[25 个检查、5 组观测](native-comparison.json)完全一致，归档 probe 内容相同 |
| 正式全量 | `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch11/2026-11-26/final-checks.json` | 0；[报告](final-checks.json)：150 通过、0 失败/阻塞；142 个 Lua 测试、348 个 Lua 语法文件 |
| 最终范围/空白 | `node reports/refactor-batch11/2026-11-26/verify-final-scope.mjs`；`git -c core.safecrlf=false diff --check` | 各 0；正式源码、候选及允许变化范围一致。diff --check 只覆盖已跟踪文件，新文件另由语法/文档检查覆盖 |

所有最终对照日志在本目录。LuaAll 保留原有 6 条 generic 资源路径警告：三份 items XML 中的 `gfx/UI/NeverbirthDeathItems.anm2` 与 `Collectibles_025_Breakfast.png` 未被 generic 验证器解析；strict 和本批其他选中检查通过。相关内容/资源未修改。

## 原生场景、诊断与恢复

两版使用相同 seed `27182818` 和本机日志版本 `1.0.12a-yin-api1-dev`。场景验证初始两层及速度、真实清房/去重、满层条件下原生直接攻击爆发、敌人伤害后真实减血确认、换层清明、移除与重新获得。满层和受伤场景由探针设置 6/4 层作为测试前提，再调用真实 TakeDamage；不声称完整原生流程自然积满所有层数。Boss +2、继续游戏和更细失败边界由模拟测试覆盖。

观测结果：正常清房为 3 层；满层爆发对第二敌人造成 10.5 伤害，主目标损失 11.5（含原击中 1），友方损失 0；换层得到 6 清明，伤害约 5.6、MaxFireDelay 约 9.28；受伤实际减少 1 半心单位后，四层爆发伤害约 11.2；移除恢复伤害 3.5、射击间隔 10、速度 1，再获得恢复初始两层。保留引擎浮点原值用于比较，五组 JSON 数据逐项相等。状态 Sprite 的实际加载和动画名经过原生检查，未进行人工画面评价。

首次基线 `native-baseline-01` 返回 15 通过/9 失败，原始[结果](native-baseline-01/result.json)和日志保留。原因是探针将 NPC 的 EntityCollisionClass 设为 ENTCOLL_NONE，使其不符合原生 IsVulnerableEnemy 条件，清房和两种爆发不触发。删除这一探针设置、增加易伤目标断言后，同一冻结旧源码 25 项通过；没有修改生产筛选来迁就测试。

原生重跑前两次被运行器的共享进程保护阻止，尚未修改文件；当时同目录另一任务正在做跨进程 Continue。等其记录 `stateRestored=true`、完成进程退出和数据恢复后才继续。本批没有关闭对方或用户进程，也不把对方 Continue 结果计入焚尽郁结验收。

模拟轨迹最初记录了 fixture Vector 方法的 Lua 进程地址，导致文本差异；最终序列化保留函数类型标记及所有数值坐标，不比较跨进程函数地址。带地址的原输出仍保存为 `trace-*-addresses.txt`，生产逻辑未改变。初期生命周期测试也曾因旧 private 表观察方式报错，更新观察方式后原断言全部通过。

两次成功原生运行各备份 227 个存档/配置文件，恢复 6 个变化的既有文件，3 个确认由本次新生成的存档文件归档。游戏正常退出 0；入口和存档恢复均为 true，没有恢复错误或未知新增文件。日志在退出时刷新，因此轮询 40 秒后请求自身 PID 正常关闭，完整 DONE/25 项总结落盘，状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`；没有把未完成测试超时判为通过。没有桌面键鼠操作，临时入口已恢复。

## 边界与撤回

本批没有验证人工画面/声音/手感、多人原生、焚尽郁结跨进程 Continue、原生沙漏或所有第三方组合。运行状态的 Continue 重置已有模拟对照；本批不建立新的保存承诺。无运行源码、内容资源或存档格式的额外修复夹带。

撤回时先核对本批最终哈希，只将 final-scope.json 中本批修改文件恢复自 baseline，将列出的新增文件移出加载范围，并单独撤回两份计划的本批条目。不能整体覆盖工作区或其他任务的新改动；无需迁移存档格式。所有备份/日志保留在本报告目录。
