# 天使盒与恶魔盒的共享能力

来源：[shared.lua](../../scripts/features/boxes/shared.lua)、[active_charge.lua](../../scripts/features/boxes/active_charge.lua)、[reward_selection.lua](../../scripts/features/boxes/reward_selection.lua)。由 [main.lua](../../main.lua)创建共享对象，再传给[天使盒](../../scripts/features/boxes/angelbox.lua)和[恶魔盒](../../scripts/features/boxes/devilbox.lua)。三个模块本身都不登记 callback。

```lua
local shared = include("scripts.features.boxes.shared")({GetCurrentRunSeed = GetCurrentRunSeed})
local charge = shared.CreateCharge(itemId, maxCharge)
local slot = charge.FindSlot(player, preferredSlot)
```

## Shared 的点调用 API

| 方法 / 字段 | 合同 |
| --- | --- |
| `CreateCharge(itemId,maxCharge)` | 返回该 itemId/cap 的充能接口；不同盒子各有策略实例 |
| `CreateRewardSelector(policy)` | 返回 `selectReward(rewardIndex,selectedItems)`；policy 合同见下文 |
| `CreateRewardLedger(deps)` | 创建本盒的 live Store 账本接口，不登记回调，见下文 |
| `CreateRewardDelivery(deps)` | 创建本盒的发奖结算函数，不主动执行，见下文 |
| `GetGame()` / `GetLevel()` / `GetRoom()` | 返回当前原生对象或 nil；并非所有内层调用都被 pcall 包住 |
| `GetFloorKey()` | `runSeed:stage:stageType`；无楼层为 `runSeed:unknown`，不含 dimension |
| `GetSoulHeartRoom(player)` | 依据 HeartLimit（默认24）、有效红心容量/回退骨心容量、当前魂心估算非负剩余半心单位；不是通用自定义血量模型 |
| `IsCollectibleQuality(itemId,quality)` | 配置查询成功且品质相等才真；可能返回 nil，消费者按 truthiness 使用 |
| `IsRewardAlreadySelected(selectedItems,itemId)` | selectedItems 是 ID→true 的集合；可能返回 nil |
| `GetRewardSeed(baseSeed,rewardIndex,attempt)` | `(baseSeed或0)+(rewardIndex或1)*1000003+attempt*7919`，attempt 必须是数值；不调用 RNG |
| `ActiveSlots` | 原生主动槽数组，缺枚举时0/1/2/3；创建充能实例直接共用该表，不应由消费者原地修改 |
| `PickupEntity/HeartVariant/CollectibleVariant/NullItem` | 当前类型常量或5/10/100/0回退 |
| `RewardAttempts/RewardSeedStep` | 当前120/7919，属于两盒共用的现有策略，不自动推广到其他奖励 |

## 特殊充能

直接工厂为 `createCharge(itemId,maxCharge,activeSlots)`；正式两盒通过 shared 使用。返回点调用方法：

- `FindSlot(player, preferredSlot?)`：优先确认指定槽确实持有 itemId，再按数组查找；找不到 nil。
- `Get(player, slot)`：读主动充能，缺方法/无值返回0；不确认槽内 itemId。
- `Set(player, slot, charge)`：夹到0..maxCharge后写入；无 SetActiveCharge 时只尝试可表达的完全放电/完全充满。无返回回执，不能假设任意中间值回退成功；本方法不先验证槽内 itemId。
- `Add(player, slot, amount)`：确认槽内仍是本 itemId，调用 AddActiveCharge(amount,slot,true,false,true)，返回原生接受量数值或0；不会把请求量当成功量，不捕获原生异常。

调用者负责在事件发生时重新确认槽、owner 和所需 charge。接口不自行管理扣费政策、Continue 或沙漏。

## 奖励选择

工厂形状为 `createSelector(world)(policy)`，最终得到 `selectReward(rewardIndex, selectedItems)`。world 必须提供 GetGame/GetRoom/IsCollectibleQuality/IsRewardAlreadySelected/GetRewardSeed/RewardAttempts/NullItem；policy 提供 Pool、Quality、FallbackItems 数组、EmptyFallback、FinalFallback。

调用返回一个 itemId 或政策允许的空回退值；不生成实体、不写 selectedItems。真实选择使用当前房间 spawn seed，最多 RewardAttempts 次 GetCollectible(Pool,false,derivedSeed,NullItem)。优先品质匹配且未选中的 ID，耗尽后可接受先前遇到的重复品质候选，再按政策列表回退。空列表返回 EmptyFallback；最后回退也可能取列表当前项，不能承诺任何情况下都严格满足品质。

这是真实卡池接口调用，不是保证无副作用的 UI 预览函数。原生调用失败不被本层吞掉；奖励生成、selectedItems 更新、品质/池政策及无候选行为由两盒拥有。

检查：[box_reward_selection_test.lua](../../tests/box_reward_selection_test.lua)、[batch3_loading_test.lua](../../tests/batch3_loading_test.lua)、[batch3_lifecycle_test.lua](../../tests/batch3_lifecycle_test.lua)。

## 首用与待发奖励账本

[reward_ledger.lua](../../scripts/features/boxes/reward_ledger.lua) 导出工厂 `CreateRewardLedger(deps)`，也通过 Shared 同名字段导出。每盒创建一次并保存返回 Ledger；全部点调用，不注册 callback。实例只捕获依赖，所有方法重新 GetData，不缓存存档表，不自行 Save。deps 的函数为 GetData、GetRunSeed、GetFloorKey、GetRoom、GetLevel、ClearChance(target)；常量为 RoomType、EnteredField、LegacyChance。GetData 必须提供含 players、pendingRewards、EnteredField 对应表和 appliedChanceFloors 的当前区域。两盒分别使用自己的区域，禁止共用可写账本。

| 接口 | 参数、返回及副作用 |
| --- | --- |
| `PlayerRecord(player)` | InitSeed 转字符串，缺省空字符串；按当前 runSeed 建立 `{runSeed,firstUseDone=false}`，返回内部 record 与 key。调用者可更新 firstUseDone；换区域/换局后旧引用失效 |
| `Pending()` | 返回当前 floor 的内部玩家→true 表；旧数值奖励数转为 legacy1..N 键。是有初始化副作用的查询 |
| `Count()` / `HasPending()` | 通过 Pending 统计 truthy 值，返回数值/布尔；可能触发旧格式转换 |
| `IsCurrentRoom()` / `HasEntered()` | 前者检查原生房间类型；后者检查本层记录或当前房间。保留原 truthy/nil 结果，不保证所有路径都是严格布尔 |
| `MarkEntered()` | 未标记时写当前楼层 true 并返回 true，已经标记返回 false |
| `MarkPending(player)` | 已进入目标房间则 false，否则将该玩家键标 true 并返回 true；同玩家重复标记不增加奖励数 |
| `ClearPending()` | 删除当前 floor 的待发记录，无返回值；不保存 |
| `AppliedChance(data,floorKey)` | true 旧值映射 LegacyChance，数值原样返回，其余0 |
| `SetChance(target)` | 获取当前层，计算 target−已应用量；绝对差≤0.0001 或缺 API 返回 false。否则调用 AddAngelRoomChance，依 ClearChance 删除或记录 target，返回 true；原生异常传播，失败前不写账本 |

天使盒的 ClearChance 为 `target<=0`，恶魔盒为 `target>=0`；这是两件道具的正负概率政策，不在共同算法中按道具 ID 分支。新局清空、续局保留与实际 Save 由道具入口负责。ResetDevilboxRun 在该盒 InstallCallbacks 时发布并紧邻绑定；该安装点位于心奖励登记之后，保留旧回调顺序。构造后、安装前没有现有消费者调用该处理器。

## 奖励生成与结算

[reward_delivery.lua](../../scripts/features/boxes/reward_delivery.lua) 导出 `CreateRewardDelivery(deps)`，返回零参函数。deps 为 Shared、Ledger、RoomType、Select(index,selectedItems)、Log(message)、Name、Save()；Shared 的 GetGame/GetRoom 与 PickupEntity/CollectibleVariant 在创建时捕获。Ledger 使用本盒上面的实例，Select 使用本盒品质/池策略。

调用时没有 pending 或不在目标房间返回 false。否则按 Count 个奖励计算中心左右40世界单位间距，调用 FindFreePickupSpawnPosition，再 Select、更新内部 selectedItems、Game:Spawn、Log。所有奖励处理完后 ClearPending、Save，返回 true。selectedItems 是此次调用私有的临时表，只传给 selector，不跨调用保存。

这是真实世界操作，会请求道具池、生成实体、消费并保存奖励。保留旧语义：Spawn 返回 nil 仍完成此次结算；Spawn/Select/Log 抛异常会中断，尚未执行末尾清理/保存，前面已生成的实体不会自动撤回。不能把它当作原子事务或预览 API。调用者负责目标房间、楼层重置及多人奖励政策。

真实使用方式位于两盒的 `rewardLedger`、`deliverReward` 装配及 TrySpawn 兼容入口。新增检查：[shared_box_ledger_test.lua](../../tests/shared_box_ledger_test.lua)，另沿用上述真实消费者和加载测试。
