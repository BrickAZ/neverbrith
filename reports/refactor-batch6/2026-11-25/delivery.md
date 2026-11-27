# 第六批交付：铜钱剑、铜钱面具

## 实现

用户授权的两件道具已按原方案拆分。没有改动游戏数值、道具池、品质、资源或存档格式。

- `coin_sewn_sword.lua` 负责组装。`rules.lua` 保存道具自己的模式参数；`aiming.lua` 提供输入向量转换、方向选择和目标查询；`input.lua` 管理持剑、取消、释放当次输入锁及清理；`attack.lua` 负责释放时的金币/血量代价、剑气组合与主动槽结算；`qi.lua` 管理真实剑气、追踪、碰撞、命中去重和挡弹；`presentation.lua` 管理动画、方向、消失表现及原有调试绘制。
- `coin_faced_mask.lua` 保留房间/楼层/更新协调。`state.lua` 是房间状态的唯一写入方；`settlement.lua` 负责伤害过滤、保护消耗、扣钱、幸运惩罚与混乱效果；`presentation.lua` 独占服装状态及资源 ID 缓存。
- 两件继续消费现有 `folk_world` 实例的金币接口。消费政策分别归各自道具，不创建通用支付系统。
- 子模块由各自入口创建一次；无依赖环。面具状态的 `Find`/`Replace` 返回仅供读取的借用视图，更新通过状态方法执行。新开局重置状态与服装运行缓存，服装资源 ID 缓存按原语义保留。
- 原 Neverbirth 公开方法/字段继续兼容。剑气与调试回调先登记，持剑回调仍由原入口稍后的 `InstallHoldCallbacks` 登记；面具的房间、楼层、更新回调仍先于伤害及缓存回调。`main.lua` 无永久修改。

## 自动检查

冻结基线为 `baseline/`，候选为 `candidate-runtime/`。实际 Lua 运行器为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。

| 检查 | 结果 |
| --- | --- |
| 原有 folk horror 道具行为、共享依赖检查 | 修改前后通过 |
| 新增 `batch6_lifecycle_test.lua` | 同一测试在旧源码和候选均通过；覆盖金币交互、释放时读取钱包、副槽、输入异常恢复、取消、多人、换房及运行状态重置 |
| 新增 `batch6_dependencies_test.lua` | 通过；覆盖扣款/生成/充能顺序、生成失败、其他攻击所有者、状态实例隔离、服装缓存 |
| 新增 `batch6_loading_test.lua` | 11 个模块各加载一次；8 个关键处理函数各登记一次；4 个登记阶段失败后完整回滚并可重新加载 |
| 完整入口回调对照 | 基础 475 条、扩展 477 条，事件、优先级、过滤参数、处理函数身份及全局登记次序一致 |
| 冻结候选独立目录的 7 个专项测试 | 全部退出码 0；包括 12 条伤害顺序检查、73 个模块导入失败和 3 个登记失败注入 |
| `LuaAll` | 122 项成功，0 失败，0 阻塞；115 个 Lua 行为测试、266 个 Lua 语法文件；退出码 0 |
| 静态检查 | 严格验证器 0 警告；通用验证器 6 条既有资源解析警告 |

完整 LuaAll 原始结果保留在 `preliminary-checks.json` / `.log`；该次检查后没有修改生产源码或行为测试。后续只补了项目地图、计划与本批诊断/交付材料。

通用验证器警告为三个语言版本各一条 `NeverbirthDeathItems.anm2` 和 `Collectibles_025_Breakfast.png` 路径解析提示；严格验证器、My Stuff 检查通过。没有借本批修改这些资源。

## 原生对照与证据限制

后台原生对照使用已安装的 REPENTOGON `1.0.12a-yin-api1-dev`。每次仅启动本次拥有的隐藏进程；加载冻结源码后恢复正常 include，再运行临时探针。

正式对照记录为 `baseline-timing/` 和 `candidate-native/`，汇总见 `native-comparison.json`。覆盖真实主动使用、剑气实体、NPC 伤害与去重、血量代价、实际面具底座取得、取消伤害/幸运惩罚、正常生成房间间的转场及下一层清理。

两次各 30 项通过、0 失败，5 个场景、5 组观测一致，30 条检查结果及数值也逐条相同：6 枚金币生成 6 道普通加 1 道强化剑气，强化命中将目标生命从 1000 减至 979 且不重复扣血；血剑代价 1 个半心；面具扣 5 枚挡伤，已消耗后不再扣钱；被剑花光金币后面具按原规则破碎、幸运减 2；换房恢复幸运并重新获得保护，换层清理持剑状态。

方向值由探针临时注入，释放经过实际玩家更新回调；输入锁在该玩家更新阶段观测。没有模拟桌面按键或鼠标。这能证明本次原生路径和前后等价，不能证明实体键盘/手柄手感。服装最终观感、真实多人、跨进程继续游戏和复杂第三方组合未在本轮人工验收。

首次旧实现探针 `baseline-native/` 有 1 个观测失败：在全局 POST_UPDATE 读取释放锁时已经错过了锁生效的玩家更新阶段。随后将观测放到生产 PRE_PLAYER_UPDATE 之后，同一旧实现通过；同时新增真实 NPC 命中检查。只修正探针，未修改生产行为以迎合检查。首次失败记录保留。

每次运行先快照 227 个状态/配置文件，退出后校验恢复；临时入口按启动前字节恢复。新生成且可证明属于本次运行的存档单独归档，其他文件不删除。结果中的 `COMPLETED_LOG_FLUSHED_ON_EXIT` 表示完成日志在正常退出时才刷盘，应结合完整 SUMMARY、正常退出码与恢复校验判断。

两次正式运行均正常退出码 0，恢复 6 个变化文件并归档 3 个本次新生成存档，恢复错误及未处理新文件均为 0。主入口恢复为启动前字节，最终源码与测试候选哈希一致。

## 命令与范围

工作目录为模组根目录，独立候选专项以 `candidate-runtime/` 为工作目录。

| 命令 | 退出码 |
| --- | --- |
| `node reports/refactor-batch6/2026-11-25/snapshot.mjs` | 0 |
| `lua.exe tests/folk_horror_items_behavior_test.lua` | 0 |
| `lua.exe tests/folk_modules_shared_dependencies_test.lua` | 0 |
| `lua.exe tests/batch6_lifecycle_test.lua reports/refactor-batch6/2026-11-25/baseline/` | 0 |
| `node reports/refactor-batch6/2026-11-25/split-items.mjs` | 0 |
| `lua.exe tests/batch6_lifecycle_test.lua` | 0 |
| `lua.exe tests/batch6_loading_test.lua` | 0 |
| `lua.exe tests/batch6_dependencies_test.lua` | 0（将缺少向量运算的通用夹具改为既有行为夹具后） |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch6/2026-11-25/preliminary-checks.json` | 0 |
| `node reports/refactor-batch6/2026-11-25/snapshot.mjs candidate-runtime` | 0 |
| `lua.exe reports/refactor-batch6/2026-11-25/compare-registration.lua` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch6/2026-11-25/run-native-isolated.ps1 -Attempt baseline-timing -Baseline -TimeLimitSeconds 55` | 0 |
| `pwsh -NoProfile -File reports/refactor-batch6/2026-11-25/run-native-isolated.ps1 -Attempt candidate-native -TimeLimitSeconds 55` | 0 |
| `node reports/refactor-batch6/2026-11-25/compare-native.mjs baseline-timing candidate-native` | 0 |
| `node reports/refactor-batch6/2026-11-25/verify-scope.mjs` | 0 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 0 |
| `git -c core.safecrlf=false diff --check` | 0 |

本批永久修改两个道具入口和项目地图，新增 9 个生产模块、3 个测试和计划/报告。`scope-parity.json` 核对完整候选仍与实际文件一致，并确认 `content/`、`resources/`、`generated/` 共 704 个文件字节未变，`main.lua` 与本批开始时一致。

## 回退

先确认目标未发生后续修改，再仅恢复两个道具入口的本批差异，移除本批 9 个子模块及 3 个测试；项目地图只撤回第六批段落。基线快照用于核对，不整体覆盖工作区，不覆盖用户后来的存档。无需存档迁移。

没有提交、推送或发布。整个模组剩余道具重构与人工验收继续按后续批次处理。
