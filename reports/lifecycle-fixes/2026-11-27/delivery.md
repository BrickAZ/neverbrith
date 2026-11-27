# 记忆紊乱口袋与复活交接缺陷修复

日期：2026-11-27（Europe/Warsaw）。用户要求修复截图所列两项旧问题；当前安装目录直接修复，未提交、推送或发布。

两个原失败均已关闭：同一份未改动的 v2 探针从 **27 PASS / 2 FAIL** 变为 **29 PASS / 0 FAIL**；扩展专项 **46 PASS / 0 FAIL**。本次限定验收结果见 [native-result.json](native-result.json)，只覆盖下述场景。

## 修改与原因

- `scripts/features/memory_disorder/inventory.lua`：原生卡牌与药丸共享一个口袋，零值 setter 同样清槽。恢复时有卡只调用 SetCard，否则只调用 SetPill（含空槽），避免恢复卡牌后又被 SetPill(0) 清空并写回永久账本。存档字段、真实新增/替换/消耗归属均保留。
- `scripts/features/revive_my_love/runtime.lua`：复用私有 holdPresentation 维持位置、速度、控制、可见及无碰撞。死亡回调立即设置，PRE_PLAYER_UPDATE 持续维持并跳过玩家原生更新，POST_UPDATE 在原生死亡结算后补齐首帧交接。自然动画、90 次逻辑更新看门狗、一次消耗和生前状态恢复沿用原合同；没有增加回调或更改绑定顺序。
- 离线夹具的 SetCard/SetPill 改为共享槽互斥模型；新增五种双槽组合、临时卡牌覆盖、重复切换、失去道具、实际替换/消耗，以及死亡结算覆写和持续无碰撞回归。

## 首帧根因定位

首次补锁放在 POST_PLAYER_UPDATE，离线夹具通过，但原生仍有一帧失败。没有降低断言。[回调追踪](native/handoff-trace/game-log.txt)在 gameFrame 58 依次记录 POST_PLAYER_REVIVE、POST_UPDATE、PRE_RENDER、PRE_PLAYER_RENDER；该死亡路径未投递 POST_PLAYER_UPDATE，POST_UPDATE 时可见/控制仍为 true、碰撞仍为 4。下一玩家 PRE 更新才恢复锁。

因此去掉无效的 POST_PLAYER_UPDATE 补锁，改用已有的 POST_UPDATE。最终首 render 即 `dead=false, visible=false, controls=false, collision=0`，之后 47 次逻辑更新采样零异常。官方 [MC_PRE_PLAYER_UPDATE 合同](https://repentogon.com/enums/ModCallbacks.html#mc_pre_player_update)说明返回 true 跳过原生 AI；实际交接时序与游戏行为以本机原生日志为依据。

## 实际检查

所有命令均从模组根目录执行。Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，版本 5.4.6。

| 命令/记录 | 结果 |
| --- | --- |
| `lua tests/memory_disorder_behavior_test.lua`、`lua tests/memory_disorder_pockets_regression_test.lua`、`lua tests/revive_my_love_behavior_test.lua`，修复前 | 各退出 1，分别复现永久卡丢失、临时覆盖后原卡丢失、首帧及持续碰撞缺口；见 [unit-before.txt](unit-before.txt) |
| 八组定向测试，具体命令见 [unit-after.txt](unit-after.txt) | 各退出 0；包括记忆紊乱行为/口袋/加载/生命/配对、复活行为、第 17 批加载和边界 |
| 调整首帧测试为实际 POST_UPDATE 顺序，修复前 | 退出 1，见 [handoff-unit-before.txt](handoff-unit-before.txt)；修正生产代码后复活 16 场景、第 17 批加载/边界各退出 0 |
| `pwsh -NoProfile -File reports/framework-closure/2026-11-27/run-native.ps1 -Attempt lifecycle-fix-before -Probe lifecycle_v2 -TimeLimitSeconds 85` | 工具进程退出 1；未修改的旧探针复现 27 PASS / 2 FAIL；游戏退出 0，入口和状态恢复成功。见 [result](../../framework-closure/2026-11-27/native/lifecycle-fix-before/result.json) |
| `...run-native.ps1 -Attempt lifecycle-fix-after-v2 -Probe lifecycle_v2 -TimeLimitSeconds 85`（同上目录） | 退出 1：检测到用户游戏正在运行，在修改前停止。用户退出后继续，无测试状态写入 |
| `pwsh -NoProfile -File reports/lifecycle-fixes/2026-11-27/run-native.ps1 -Attempt after-01 -Probe lifecycle_v2 -TimeLimitSeconds 85` | 工具进程退出 1；45 PASS / 1 FAIL，剩首帧交接；[result](native/after-01/result.json) |
| 同运行器 `-Attempt handoff-trace -Probe lifecycle_v2 -TimeLimitSeconds 40` | 工具进程退出 1；45 PASS / 1 FAIL，追踪上述原生顺序；[result](native/handoff-trace/result.json) |
| 同运行器 `-Attempt after-02 -Probe lifecycle_v2 -TimeLimitSeconds 40` | 退出 0；6 场景 46 PASS / 0 FAIL；[result](native/after-02/result.json)、[日志](native/after-02/game-log.txt) |
| `pwsh -NoProfile -File reports/framework-closure/2026-11-27/run-native.ps1 -Attempt lifecycle-fix-final-v2 -Probe lifecycle_v2 -TimeLimitSeconds 40` | 退出 0；未改动的原 v2 探针 3 场景 29 PASS / 0 FAIL，原两项失败均转为通过；[result](../../framework-closure/2026-11-27/native/lifecycle-fix-final-v2/result.json)、[日志](../../framework-closure/2026-11-27/native/lifecycle-fix-final-v2/game-log.txt) |
| 首轮 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/lifecycle-fixes/2026-11-27/lua-all.json` | 退出 0；182 检查通过、0 失败/阻塞/警告，含 174 个 Lua 测试；[报告](lua-all.json)。该轮早于首帧 POST_UPDATE 修订，最终轮另记录 |
| 最终 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/lifecycle-fixes/2026-11-27/lua-all-final.json` | 退出 0；182 检查通过、0 失败/阻塞/警告，含 174 个 Lua 测试、544 文件语法解析及静态/导航检查；[报告](lua-all-final.json)、[日志](lua-all-final.log) |

最终生产/测试/专项探针 SHA-256 见 [source-hashes.json](source-hashes.json)；本次相对开始时快照的四个已有源码/测试差异见 [review.txt](review.txt)。最终 `main.lua` 与最后一次原生运行前快照 SHA-256 均为 `C25AC8216BE080BEA4065BBF4BBB8C6B9FA23B895997E1FEE3D270002CC6EFDE`，没有残留探针入口，复核时 Isaac 进程数为 0。

## 原生覆盖与状态恢复

- 复活首帧控制/可见/碰撞、47 次持续状态采样、实际 TakeDamage 两次被拒绝，注入方向与射击输入期间位置不变且不产生泪弹。解除后相同输入产生位移和 3 个泪弹，伤害调用恢复成功并实际扣血；不是只检查回调返回值。
- 原有死亡/消费/自然动画/血量/权限恢复、真实床接管/取消/再取得每层锁、记忆紊乱换房 15/30 帧及原身份/生命/主动槽断言保留。额外以真实取得→换房→移除验证两种卡药双槽组合及双空槽归还。
- 原生运行器只启动并关闭自有隐藏进程，未发送桌面键鼠；每次先快照状态及 main.lua，结束后按哈希恢复并归档本次新文件。after-02 的游戏退出码 0，`cleanShutdown/stateRestored/mainRestored=true`，`restoreErrors/unresolvedNewFiles=[]`。日志在关闭时完整刷新，运行器据最终 SUMMARY 判为 `COMPLETED_LOG_FLUSHED_ON_EXIT`，并保留 `pollingTimedOut=true`，没有伪称实时轮询成功。
- 历史 framework-closure 报告及其 `acceptancePassed=false` 原样保留；本次是用户另行授权的玩法缺陷修复，不是把旧失败改成通过。

## 范围

本次关闭这两项已复现问题。原生输入为引擎 callback 注入，不是人工键盘手感验收；没有新增多人/特殊身体的原生验收、全沙漏/跨进程 Continue、复合 Mod 或完整长周期睡眠证据。旧卡已在此前错误中丢失且账本已变空的存档不能凭本次修复重建未知卡牌。公共 API、资源、品质、道具池与存档结构未改。
