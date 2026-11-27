# 共享状态、存档分区与依赖收尾

日期：2026-11-27（Europe/Warsaw）。本轮已完成下述共享边界和资源路径检查修正；没有提交、推送或发布。保持现有玩法、存档字段、身份键、保存时机及回调顺序，没有升级用户存档格式。

## 本轮结果

1. **存档分区**：单实例 persistence 增加 Scope，以白名单字段代理旧根形状。15 个原根接口道具消费者加获取服务只获得自身授权区域，正式 main 不再传 `persistence.GetRoot`。缺失读取仍为 nil，nil 写入仍删除字段，旧标量由原所有者校验；区域替换动态生效。Save 仍写真实完整根，保留未知和其他模块字段。
2. **共享状态**：逻辑玩家/身体背包身份归属 player_identity；参与者登记、复制和恢复归属每实例 snapshot_participants；获取/实物身份/沙漏槽回调归属 acquisition_state。旧 pending_content_state.lua 只转发工厂，公开 PendingContentState 仍是正式返回实例。算法、字符串键与参与者恢复顺序政策保持。
3. **显式依赖与装配**：main 保存获取、选择器、输入、表现和战斗实例，传给凸眼鱼、斗气拳套、搓招和流量消费者。临时复制提示的状态/绘制/清理、背包条目/文本及饰品 EID 已从 pending_content_integration 分离；装配文件只连接模块。旧独立工厂的全局字段回退继续用于兼容调用。
4. **资源警告**：六条提示实际是三种语言 items 的 deathanm2 和原版 Breakfast 贴图。通用验证器改按声明 XML 的 content 相对位置及实际解包游戏资源定位，支持明确 GameRoot。实际工作区现在零警告；真正缺失、错误位置和目录冒充文件仍会警告。没有删除道具死亡图标或记忆紊乱资源。
5. **角色范围**：按用户决定暂不开发自定义角色。players.xml 仍为空登记，主入口仍不安装角色，旧源码/资源原位暂留；未被登记引用的历史内容不构成当前资源补全任务。

详细接口、实例和生命周期合同：[存档分区](../../../docs/api/persistence.md)、[共享状态与装配](../../../docs/api/shared-state.md)、[斗气拳套与搓招](../../../docs/api/drive-motion.md)。其中搓招同时拥有 motionCombat / motionCombatHourglass，获取服务同时拥有 pendingContent / pendingContentHourglass。

## 实际验证

工作目录均为模组根；Lua 为 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，Python 为 `C:/msys64/ucrt64/bin/python.exe`。完整命令和子退出码保存在 JSON；下表结果各自只覆盖其范围。

| 命令 / 检查 | 退出码与结果 | 证据 |
| --- | --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/framework-finish/2026-11-27/lua-all-final.json` | 0；172 项通过，0 失败、0 阻塞、0 警告；164 个 Lua 用例、513 个语法文件 | [JSON](lua-all-final.json)、[日志](lua-all-final.log) |
| `lua reports/framework-finish/2026-11-27/run-behavior.lua baseline tests/<name>_test.lua` | 17 组冻结旧版既有行为用例全部 0 | [初次记录](behavior-comparison.json)中的 baseline 行及各 baseline 日志 |
| 同上，mode 为 `scoped` | 最终 17 组全部 0；强制实际道具工厂消费 Scope，保留原用例断言，覆盖新局、继续、沙漏、保存和奖励等各自既有合同 | [最终分区回归](scoped-behavior-final.json)、各 final-scoped 日志 |
| `lua reports/framework-finish/2026-11-27/compare-registration.lua` | 0；旧新完整入口均 520 条；启用零分考卷后均 533 条；逐条事件、优先级和过滤顺序相同 | [脚本](compare-registration.lua) |
| LuaAll 中的新 scope / snapshot / wiring 用例 | 0；越权读写、nil/false、替换、未知字段、加载失败、参与者隔离及错误、15 个真实消费者、显式依赖和 7 个缺模块回滚反例 | [Scope](../../../tests/persistence_scope_test.lua)、[参与者](../../../tests/snapshot_participants_test.lua)、[真实接线](../../../tests/framework_shared_wiring_test.lua) |
| `pwsh -NoProfile -File tests/generic_validator_assets_test.ps1 -ReportPath reports/framework-finish/2026-11-27/generic-assets.json` | 0；6 个路径/缺失/停用归档反例通过 | [结果](generic-assets.json) |
| `pwsh -NoProfile -File tests/strict_validator_scope_test.ps1 -ReportPath reports/framework-finish/2026-11-27/strict-scope.json` | 0；22 个既有范围反例通过 | [结果](strict-scope.json) |
| `python reports/framework-finish/2026-11-27/scope-check.py` | 0；20 个已有文件修改、12 个新文件；基线覆盖的 content/生成登记未变化；两次原生恢复和日志比较通过 | [范围](scope-check.json)、[原生比较](native-comparison.json) |

首次完整回归为 146 通过、26 失败、0 阻塞、0 警告，保留为 [lua-all.json](lua-all.json)。本轮修正了漏授权的 motionCombatHourglass；对选择器使用显式提供者，使省略无关道具的既有专项夹具不必提前构造其实例，真实消费者仍在构造时验证依赖。两份直接加载旧共享路径的测试增加真实 include 加载，流量夹具改为定位新的实际回调所有者，八音盒夹具补齐共享拾取回调所需枚举。没有删除旧断言或用成功空实现替代被测行为。最终完整回归为上表结果；初次失败不写成旧有缺陷。

## 原生旧新对照

使用已有 recovery_flow 探针，后台运行冻结 baseline 与当前正式源码：

```powershell
pwsh -NoProfile -File reports/framework-finish/2026-11-27/run-native.ps1 -Attempt baseline-recovery -Runtime baseline -Probe recovery_flow -TimeLimitSeconds 60
pwsh -NoProfile -File reports/framework-finish/2026-11-27/run-native.ps1 -Attempt candidate-recovery -Probe recovery_flow -TimeLimitSeconds 60
```

两侧各 7 场景、150 项通过、0 失败，退出码均为 0；150 条 PASS 观测文本逐条相同，没有 Lua 回调错误或引擎异常。场景证明本次正式接线在实际游戏中的战斗/控制恢复路径可运行，不能扩大为所有存档与道具组合都经过原生验收。[基线](native/baseline-recovery/result.json)、[当前](native/candidate-recovery/result.json)、[逐条比较](native-comparison.json)。

每次先备份 229 个既有状态文件，结束后正常关闭自己的游戏进程，核验恢复主入口、存档和配置。两次 mainRestored/stateRestored/cleanShutdown 均为 true，restoreErrors 与 unresolvedNewFiles 均为空。仅本次运行产生且启动前不存在的文件按现有恢复工具核验后归档；未接管桌面键鼠。正常退出刷新完整日志后确认 150/0 和 DONE，状态为 COMPLETED_LOG_FLUSHED_ON_EXIT；没有将无汇总的超时当作通过。

## 兼容边界与剩余工作

- legacy_save_schema 保留旧首次保存即存在的默认区域，避免修改序列化形状。正式消费者的数据权限已经分区；进一步迁成所有者登记前，须另证首次保存形状保持。
- 旧工厂路径、公开 Mod 别名和独立工厂旧参数保留；它们不是另一份状态实例。删除旧路径需先确认外部消费者退出。
- 不统一其他道具不同的身份、控制占用、RNG、计时和恢复政策。本轮没有增加跨进程 Continue、真实多人、所有原生沙漏组合或人工画面/手感保证，也未声明整个 Mod 的全部批次和包级验收完成。
- 暂停角色开发只影响其开发/检查范围，没有把仍在使用的道具资源一起排除。

## 回退

baseline 保存开工时实际未提交工作区的 646 个源码/测试/工具/登记文件，见 [清单](baseline-manifest.json)。按 scope-check 的 changed 文件逐项恢复，撤去 added 模块及本轮引用；不要整目录覆盖当前工作区。所有写盘字段仍为旧格式，回退本批代码无需存档格式迁移。过程脚本 extract.py 只记录提取过程，不要对完成后的工作区再次执行。
