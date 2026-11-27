# 内容专属的共享系统

这些模块放在 systems 中，但拥有已确认的玩法政策，不能作为无条件通用库推广。

## 骰子套装

来源：[dice_set.lua](../../scripts/systems/dice_set.lua)。`include(...)(mod,{Store=...,GetPlayers=...,GetCurrentRunSeed=...,IsValidItemId=...})` 创建套装实例、定义 mod 方法，返回 `{InstallCallbacks=function()...end}`。原生 ActiveSlot 等全局在创建时必须存在。Store 为现有 diceSet 区域。

| 冒号接口 | 参数、返回和副作用 |
| --- | --- |
| `mod:RegisterDiceItem(itemId, options?)` | 不合法 ID 返回 false；合法时保存 name、protectStats（默认true）并返回 true。登记不等于玩家已经取得，不写盘 |
| `mod:IsDiceActiveItem(itemId)` | 排除既有黑名单；优先显式登记，再检查原生主动配置、正充能和名称关键词。返回 boolean |
| `mod:PlayerHasDiceSet(player)` | nil 玩家 false，否则返回 unlocked；内部可能懒创建区域/玩家记录 |
| `mod:GetDiceSetProgress(player)` | 返回 `count, required, unlocked` 三项；required 当前3，count不超过3；nil玩家返回0,3,false。会懒初始化内部存档表，不是完全纯查询 |
| `mod:FormatDiceSetEID(player)` | 返回套装标题/正文标记字符串；通过进度路径读取状态；不应在没有所需 EID/本地化上下文时假设完整显示 |

```lua
mod:RegisterDiceItem(existingRuntimeId, {name = "Existing Dice", protectStats = true})
local count, required, unlocked = mod:GetDiceSetProgress(player)
```

点调用 `instance.InstallCallbacks()` 在主入口原位置执行一次，登记取得道具、使用前/使用、属性缓存、玩家持有追踪、延迟保护和 EID 接入、新局恢复等事件。内部 `TrackDiceSetPickup`、`TrackHeldDiceItems`、`RecordDiceSetPreUse`、`HandleDiceSetUse`、`EvaluateDiceSetStatProtection`、`UpdateDiceSetPendingState`、`ResetDiceSetState`、`TryRegisterDiceSetEIDModifier` 是 mod 上的回调兼容表面，其他模块不能通过调用它们模拟原生拾取/使用。

每个原生绑定紧贴对应处理器，放在实例私有的 `callbackInstallers` 方法中；`InstallCallbacks()` 仍无参数、无有用返回值，只按上述原顺序及原事件存在性守卫逐项调用，不能遍历该私有表安装。工厂执行时处理器已经可见，调用 `InstallCallbacks()` 才实际登记；重复调用会重复注册，不提供幂等保证。

saved players 以 InitSeed 字符串为键，当前运行保护表、基线、EID 注册状态由此实例持有。新局/继续与现有字段保持原义；创建第二个实例会覆盖 mod 方法并形成独立运行状态，不是查询当前套装的方式。第三方扩展继续使用当前公开接口，不通过 TestAPI 访问内部表。

检查：[dice_set_behavior_test.lua](../../tests/dice_set_behavior_test.lua)、[localization_test.lua](../../tests/localization_test.lua)、[thin_entry_installation_test.lua](../../tests/thin_entry_installation_test.lua)。

## 狗粮获取记账

来源：[dog_food_acquisition.lua](../../scripts/systems/dog_food_acquisition.lua)，由[狗粮组装](../../scripts/features/dog_food_series.lua)创建一次。依赖 Store、GetPlayers、GetCurrentRunSeed、IsValidItemId、Definitions、Stats、Combat 与 Log。虽 Log 的赋值没有 assert，但不兼容红心模型路径会直接调用它，应传有效函数。

Definitions 是七件道具提供的定义数组；每个 def 至少提供当前 itemId 和 Evaluate，部分含 soulHeartHalfUnits 等奖励参数。Stats 提供 Count/AddTears；Combat 来自 Dental Chew 定义，具体装配以源码为准，不编造一个缩减 def 替代完整消费者。

创建时立即注册属性缓存、更新、拾取碰撞、战斗、换房/换层及新局回调。返回 `{Evaluate=evaluate}`，其中 Evaluate 是原生 callback 形状（包括首个 mod 参数），仅供已有装配/测试需要，不是通用“发放狗粮效果”接口。

记账按玩家 InitSeed 和道具 ID 保存已处理数量；实际增量才发获取奖励，失去道具会降低基线以允许之后真实再取得。碰撞后的结算延后2次系统更新，库存对账间隔15次更新；不是2秒/15秒。Store 读到种子不匹配可能重置并保存，因此诊断 Getter 也不应被假定为纯读取。

继续时对未有记录的玩家按当前数量建立基线，避免重复发放获取奖励；新局重置保存区，换房/换层清理 pending。退出与本 Mod 卸载通过相邻处理器/安装函数登记 `MC_PRE_GAME_EXIT`、`MC_PRE_MOD_UNLOAD`，清空含玩家引用的 pending 与诊断去重表，停止碰撞记账和更新；退出不更改存档，继续可恢复追踪，卸载后的实例不可重启，其他 Mod 卸载无影响。清理可重复调用。部分红心奖励尝试通过 pcall，不能从函数返回 true 推导所有角色一定增加红心。

`mod.DogFoodSeriesTestAPI` 暴露 ItemDefs、ItemById、Runtime、AddTears、GrantPickupBenefits、ReconcilePlayerItem、GetProcessedCount、EligibleDentalTarget、ApplyDentalPush 和 Callbacks。它含内部可变表及效果函数，只供现有测试/诊断，不是生产消费者的新公共依赖。

检查：[dog_food_series_behavior_test.lua](../../tests/dog_food_series_behavior_test.lua)、[batch1_loading_test.lua](../../tests/batch1_loading_test.lua)、[退局与卸载引用检查](../../tests/refactor_lifecycle_food_test.lua)。
