# Condom 底座 7 → 99：原因与针对性修正

2026-11-26。在本机 `isaac-ng.exe` / REPENTOGON `1.0.12a-yin-api1-dev` 中完成真实原生进程诊断和购买验证。结论：上一轮回归中的 `7 → 99` 来自测试夹具构造的商店状态与引擎自动定价，非 Condom 回调写价，也不是 callback 布局整理引入的回归。修正回归探针与检查说明；181 个正式运行时 Lua 文件保持原样。

## 原因与定位证据

旧 [Pickup 探针](probe-pickup.before.lua) 在普通起始房间 `Isaac.Spawn` 一个底座，等待两帧后设置 `AutoUpdatePrice=false`、`Price=7`，再执行 `Morph(..., true, true, false)`。该底座的 `ShopItemId` 实际为默认值 `0`，并非真实商店生成的商品槽位。

本机实测事件顺序如下：

| 时点 | Price | AutoUpdatePrice | ShopItemId |
| --- | ---: | --- | ---: |
| 手工设价后、Morph 前 | 7 | false | 0 |
| Morph 刚返回 | 7 | true | 0 |
| 下一帧最后一个 PRE_PICKUP_UPDATE 观测 | 7 | true | 0 |
| 同帧第一个 POST_PICKUP_UPDATE 观测 | 99 | true | 0 |

`KeepPrice=true` 保住的是 Morph 返回时的立即价格；它没有阻止原生 Morph 重新开启自动定价。随后引擎根据该槽位状态计算出 99。把同一个测试的槽位设为 `-1`，下一帧会得到 15；不执行 Morph、保持 `AutoUpdatePrice=false` 时仍为 7。这两组对照排除了“Condom 主动把价格写成 99”的解释。

进一步分别运行：所有模组回调启用、移除 Condom 的 Init/Morph 两条回调、移除 669 个非测试原生事件绑定。三个环境各覆盖五种价格/槽位组合，结果完全符合相同的原生价格变化规律。最后一组仍在 PRE/POST Pickup 更新之间观察到 `7 → 99`。全部 15 组数据、事件时点和恢复校验见 [summary.json](summary.json)，原始逐事件日志见 [diagnose-02/game-log.txt](diagnose-02/game-log.txt)。

这里的“引擎行为”指本机当前原生游戏与 REPENTOGON 环境；没有切换原版无 REPENTOGON 的二进制，也没有逆向内部定价公式。[EntityPickup API 文档](https://wofsauge.github.io/IsaacDocs/rep/EntityPickup.html#shopitemid)也说明 Lua 生成底座的默认槽位及异常价格问题；本轮结论以实际隔离对照为依据。

## 实际修正

- 修改 [callback-native 的 Pickup 探针](../../callback-native/2026-11-26/probe-pickup.lua)：普通房间生成的免费底座按免费底座验证，要求 Init 后、Morph 刚返回和后续更新均保持价格 0，去掉人为设置 7 但保留默认槽位的错误场景。
- 新增 [价格专项探针](probe-verify.lua)：使用引擎生成的正常商店商品，验证 15 元原价、Steam Sale 后的 7 元、Condom 替换、原生槽位/种子与自动定价、资金不足以及真实购买扣款。
- 固定自定义价格单独作为夹具场景：明确非房间槽位 `-1`，由夹具在 Morph 后恢复自己的 `AutoUpdatePrice=false`。没有在 Condom 或全局回调里强行锁价，也没有更改原版折扣规则。
- 在 [检查与证据](../../../docs/agent/testing.md)补充价格测试注意点，并在 [此前回归报告](../../callback-native/2026-11-26/delivery.md)链接本次定位。原有日志、比较结果及“当时观察到 99”的事实保持不变。

没有修改正式道具代码、callback 绑定顺序/过滤/返回值、物品池、替换次数、RNG 策略、存档语义或游戏二进制。源码哈希核验见 [sources.json](sources.json)及 [check-evidence.cjs](check-evidence.cjs)。

## 最终验证

| 场景 | 实机结果 |
| --- | --- |
| 免费底座：Init 和 Morph | 保持免费；启用 Condom 时正确替换，guard 清理 |
| 固定自定义 7 元夹具 | 明确定价策略后跨帧保持 7 |
| 真实商店原价 | Morph 和 Condom 替换后仍为 15，槽位/种子不变 |
| Steam Sale 真实折扣 | 15 → 7，后续替换和更新仍为 7，自动定价保留 |
| 资金不足 | 持有 6 元时无法购买 7 元商品，没有扣款 |
| 实际购买 | 持有 20 元购买后剩 13 元，取得一次道具，继续接触不重复扣款 |
| 关闭 Condom 对照 | 同样通过原价、折扣、拒绝购买与成功扣款验证 |
| callback 整理前/后两版 Pickup 回归 | 两版各 5 场景、30 检查，全部观测一致；同时覆盖疯狂的椰子与鸿运 |

最终纳入验收的五次运行共 **35 个场景、137 项检查，0 失败**：隔离诊断 15/17；启用与关闭 Condom 的价格/购买测试各 5/30；两版 Pickup 测试各 5/30。这里是场景执行次数，不表示 35 个互不重复的设计场景。两版对比见 [comparison-pickup.json](comparison-pickup.json)。

四个相关离线 Lua 测试均退出 0：Condom/美工刀行为、batch9 结算与重入、batch9 加载及回滚、Condom/Coconut 新局与继续生命周期。原始输出见 [lua-checks.json](lua-checks.json)。三份探针语法、证据一致性与项目知识导航亦进行检查，结果记录在 [validation.json](validation.json)。正式源码未改，未重复执行全项目 LuaAll。

## 运行记录与恢复

八次原生启动都正常退出并完成恢复。两次中间探针失败不计入通过数：

1. `diagnose-01`：用 `cb.Mod:RemoveCallback` 移除系统拥有的回调时报错；改用当前游戏提供的 `Isaac.RemoveCallback(cb.Mod, ...)`，`diagnose-02` 完整通过。
2. `verify-disabled-01`：随机商店没有 15 元商品，场景前置断言失败；探针改为有界选择引擎生成的正常满价商品，不写入价格，后续启用/关闭两组均完整通过。

早期 `verify-enabled-01` 已通过 30 检查，最终统计使用更新后的 `verify-enabled-02`，没有重复计数。上述失败都是探针失败，记录保留；两次外层命令观测退出码为 1，游戏进程本身退出码为 0。

每次先备份存档、配置及临时入口，关闭本任务启动的隐藏进程后恢复。最终复核 **181 个正式 Lua 文件、227 个原存档/配置文件**的哈希全部相同；所有尝试 `restoreErrors=[]`、`unresolvedNewFiles=[]`，见 [summary.json](summary.json)。[进程检查](process-check.json)确认剩余游戏进程数 0。没有提交、推送或发布。

## 复现命令

在模组根目录执行。以下最终命令均退出 0；重复运行时应换新的 `Attempt` 名，运行器拒绝覆盖旧记录，并拒绝与共享存档的已有游戏进程并行。

```powershell
pwsh -NoProfile -File reports/condom-price/2026-11-26/run-native.ps1 -Attempt diagnose-02 -Suite diagnose -TimeLimitSeconds 25
pwsh -NoProfile -File reports/condom-price/2026-11-26/run-native.ps1 -Attempt verify-disabled-02 -Suite verify -DisableCondom -TimeLimitSeconds 35
pwsh -NoProfile -File reports/condom-price/2026-11-26/run-native.ps1 -Attempt verify-enabled-02 -Suite verify -TimeLimitSeconds 25

pwsh -NoProfile -File reports/callback-native/2026-11-26/run-native.ps1 -Attempt pickup-price-baseline-01 -Suite pickup -Baseline -TimeLimitSeconds 25
pwsh -NoProfile -File reports/callback-native/2026-11-26/run-native.ps1 -Attempt pickup-price-candidate-01 -Suite pickup -TimeLimitSeconds 25

node reports/condom-price/2026-11-26/compare-layout.cjs pickup pickup-price-baseline-01 pickup-price-candidate-01
node reports/condom-price/2026-11-26/check-evidence.cjs
lua tests/condom_utility_knife_behavior_test.lua
lua tests/batch9_settlement_test.lua
lua tests/batch9_loading_test.lua
lua tests/condom_coconut_run_lifecycle_test.lua
```

`COMPLETED_LOG_FLUSHED_ON_EXIT` 表示游戏在退出时才刷新完整日志；运行器同时检查本次 START、SUMMARY、DONE、游戏退出码、正常关闭日志与恢复结果，没有把单纯等待超时作为通过依据。
