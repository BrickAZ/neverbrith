# 第九批重构交付

本批为用户批准的避孕套、疯狂的椰子、鸿运齐天蛊。基线冻结于当前工作区，包含前八批和其他任务已有修改；不以 Git HEAD 替代当前实现。

## 实现归属

| 道具 | 入口与模块 | 说明 |
| --- | --- | --- |
| 避孕套 | `scripts/features/condom.lua`；同名目录下 `bans`、`replacement`、`presentation` | 本局禁用记录、目标选择与主动使用；底座替换及重入保护；名称、本地化与反馈。 |
| 疯狂的椰子 | `scripts/features/crazy_coconut.lua`；同名目录下 `ledger`、`attributes`、`acquisition` | 旧存档视图与持有数量记账；伤害应用与自然伤害查询；碰撞候选、取得确认、等待和同批结算。 |
| 鸿运齐天蛊 | `scripts/features/fortune_rivalling_heaven_gu.lua`；同名目录下 `audit`、`registry`、`runtime` | 原幸运需求条目；外部追加注册、条件、最高需求计算；每玩家依赖快照、失效与两阶段缓存刷新。 |

每件入口只构造一次组内模块，并返回原安装方法。main.lua 的交错登记位置未改变。子模块构造不登记回调；鸿运在三个模块构造完成后执行原需求表注册。旧公开方法保留动态调用，椰子的私有 Ledger 实例由入口注入取得结算模块，不重复创建状态。

椰子的长更新函数拆成 `TrackCopies`、`AdvanceCandidates`、`SettleCandidates`：取得确认后仍等待两个更新，同一批到期候选共享原来的一个自然伤害采样，结算期间的属性刷新不改变后续候选的比较基准。玩家字段、待确认字段、复制数快照、清理条件与 Store.Save 时点沿用旧实现。

避孕套的两个禁用目标、20 次替换尝试、失败移除和随机顺序保持原样；鸿运仍按最大需求补足幸运，保留独立的收藏品/饰品 ID 空间、追加注册、resolver 错误隔离和显式失效。没有新存档字段、共享玩法状态或新增公共机制抽象。

## 离线证据

- 重构前实际运行 `tests/batch9_settlement_test.lua`、`tests/condom_utility_knife_behavior_test.lua`、`tests/fortune_custom_cache_behavior_test.lua`、`tests/crazy_coconut_dependencies_test.lua`，均退出 0。日志见 `baseline-*.log`。
- `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch9/2026-11-26/final-checks.json`：退出 0；133 项通过、0 失败/阻塞，126 个 Lua 测试，301 个语法文件。
- 通用静态验证仍有原来的 6 条资源路径告警（三份 items XML 中的 `NeverbirthDeathItems.anm2` 与 `Collectibles_025_Breakfast.png`），严格验证 0 告警。
- `lua reports/refactor-batch9/2026-11-26/compare-registration.lua`：退出 0；475 条 legacy、489 条 complete 登记的事件、优先级、过滤条件、处理器身份及相对顺序逐项相同。Morph 分支另外由加载测试显式提供枚举覆盖。
- `lua reports/refactor-batch9/2026-11-26/run-frozen-test.lua <baseline|candidate-runtime> tests/batch9_settlement_test.lua`：两份冻结源码均退出 0。覆盖同批两个候选、去重、延后确认、失败队列、道具移除、多人状态、20 次替换失败、Morph 重入及保护标记释放。
- `batch9_dependencies_test.lua`：两份独立安装不共享存档或注册表；Store 替换后读取新视图，换种子不修改旧视图；其他存档区域保留，原安装点前无回调登记。
- `batch9_loading_test.lua`：12 个入口/子模块各导入一次，原回调数量及 7 个注册故障阶段回滚通过。完整入口另验证 96 个 feature 导入故障及 3 个登记故障后的恢复。
- `node reports/refactor-batch9/2026-11-26/verify-extraction.mjs`：退出 0；44 个公开方法名称全部保留，其中 43 个正文逐字相同，仅 `TrackCrazyCoconutCopies` 委托新私有步骤。幸运需求表正文相同，见 `extraction-review.json`。

开发中发现并修正了提取脚本把鸿运注册函数定义误当成调用的定位问题，以及独立夹具缺少 include / Morph 枚举的问题。新增测试首次模拟 Game 时遗漏种子接口会重置禁用区域，也已改成保留原 Game 的其他接口。最终完整回归在这些修正之后执行。

## 原生场景与边界

使用 `run-native-isolated.ps1` 启动自己的隐藏进程，冻结旧/新源码采用同一探针和新局种子。真实场景包括主动使用避孕套、被禁底座生成和 Morph、实际取得椰子/早餐/五芒星、复制数记账、存档读回、鸿运条件取得/移除、重复持有、空闲缓存、外部注册和显式失效。

最终运行：`pwsh -NoProfile -File reports/refactor-batch9/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-03 -Baseline -TimeLimitSeconds 55`；候选使用相同命令的 `-Attempt native-candidate-01` 且不加 `-Baseline`。两次运行器退出码均为 0，旧/新各 5 场景、30 项通过，0 失败。

`node reports/refactor-batch9/2026-11-26/compare-native.mjs native-baseline-03 native-candidate-01` 退出 0：30 条检查、5 组数值观测、10 条椰子碰撞/队列/确认/结算日志逐项相同，见 `native-comparison.json`。

最终及诊断运行均核验 227 个原有存档/配置文件，恢复 6 个发生变化的文件、归档 3 个确认由测试新建的存档，main.lua 恢复，未决新增文件和恢复错误为 0。日志在关闭时刷新，记录为 `COMPLETED_LOG_FLUSHED_ON_EXIT`；自己的游戏进程正常退出，游戏退出码 0。没有桌面鼠标/键盘输入，也未关闭用户的其他进程。逐次证据见对应目录的 `result.json`、`state-manifest.json` 和 `game-log.txt`。

首轮基线为 28 项通过、2 项失败：原生测试底座在变形后价格为 99，而非探针设定的 7；另把五芒星的伤害变化假设为显示伤害简单 +1。第二轮修正伤害检查为自然伤害实际增加，并关闭测试底座的 AutoUpdatePrice，得到 29 通过/1 失败，变形价格仍为 99。因此不能把该现象直接归因为自动定价，也不能声称价格保持 7 已通过。最终探针记录赋值后、Morph 返回时和两帧后的价格，用旧/新观测严格比较价格行为，并检查仍为有价底座。本批保留现有变形逻辑，不顺带修复价格机制。

第三轮基线记录为：赋值后 7、Morph 刚返回时 7、两帧后 99。这仅定位了变化发生在后续更新，未独立归因于引擎或某个回调。椰子非伤害奖励后的伤害为 9.5，实际五芒星提高伤害且不给椰子奖励，第二份椰子取得后总层数 3、伤害约 14.19134。鸿运条件值 5→10→5，外部阈值显式失效后 17→21，全部移除后回到 0；30 帧不变库存没有自定义缓存求值。

原生自动检查不代表人工画面/手感确认，也不覆盖完整一局和所有 mod 组合。多人、旧存档继续与新种子、缓存刷新期间再失效及错误重试的细分边界由模拟测试覆盖；本批原生场景为单玩家新局。

## 范围与回退

基线 1092 个文件，候选 1104 个文件。`node reports/refactor-batch9/2026-11-26/verify-scope.mjs` 退出 0：快照范围修改 6 个文件、新增 12 个文件、无删除；当前源码与候选哈希相同，704 个 `content`/`resources`/`generated` 文件以及 main.lua 与基线字节相同。精确清单见 `scope-parity.json`。计划及日期报告在快照范围外；回退只恢复本批修改文件并移除本批新增模块/测试，使用冻结基线保存的实际工作区字节，不执行整库 reset。

`git -c core.safecrlf=false diff --check` 退出 0，仅作为已跟踪差异检查；新模块另由快照允许清单和语法/行为检查验证。`pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` 退出 0。

本批没有提交、推送或发布。
