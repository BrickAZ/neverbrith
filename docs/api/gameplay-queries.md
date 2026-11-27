# 卡牌、属性与伤害查询

## 卡牌候选和卡池请求

来源：[card_rewards.lua](../../scripts/systems/card_rewards.lua)，`include("scripts.systems.card_rewards")` 返回 table。无模块状态和自动回调；以下全部点调用。

| 接口 | 精确合同 |
| --- | --- |
| `GetItemPool()` / `GetItemConfig()` | 返回实时引擎对象或 nil；池方法和 ItemConfig 查询有保护。GetItemPool 内层获取 Game 的调用本身未包 pcall，不能承诺所有异常都变 nil。对象不是快照 |
| `HasDisplayData(itemConfig, subtype)` | 如果有 GetCard：调用失败/无配置/Name、Description、GfxFileName、HudAnim 均空时 false，至少一项非空为 true。没有 itemConfig 或 GetCard 时返回 true，这是现有兼容行为，不是已证实有效卡牌 |
| `AddCandidate(candidates, seen, subtype, isKnown)` | subtype 先 tonumber + floor，非数字当 0；仅 >=1、未 seen 且 isKnown(subtype) 为真时原地更新 seen 和数组。没有返回值 |
| `CollectCandidates(addCandidate,first?,last?)` | 创建 candidates/seen，先枚举 first（缺省1）到 last（缺省为当前 RUNE_HAGALAZ-1 或31），再枚举 Card 表数值，调用 `addCandidate(candidates, seen, subtype)`，最后升序排序并返回新数组。老大的指令传安装时捕获的范围；回调自己负责过滤和去重 |
| `RollPool(itemPool, seed, isKnown)` | 依次尝试 GetCard(seed,true,true,false) 与 GetCard(seed,true,false,false)，第一项通过就 floor 后返回；两次都失败/未知则 nil。GetCard 抛错被捕获，isKnown 自己抛错不被吞掉 |
| `RewardSeed(player,attempt,getRoom,salt)` | 玩家 InitSeed 数值化（缺省0）加受保护的房间 SpawnSeed，再加 attempt（缺省0）×101 和必需数值 salt，floor 后取绝对值。好女孩 salt=37、月色=53；不推进 RNG。getRoom 本身的错误传播 |
| `HasEIDDescription(entityType,getVariant,subtype,allowObjectName)` | EID 缺失返回 true；依次保护调用两个描述接口，允许时才用 getObjectName 兜底。拒绝空表/空文本/占位文字和类型数字占位名；两个查询都抛错而未完成检查时保留原兼容放行。getVariant 是无参查询，可保持动态枚举或捕获的常量；不把返回 true 当作图像有效证明 |

```lua
local Cards = include("scripts.systems.card_rewards")
local candidates = Cards.CollectCandidates(function(ids, seen, id)
    Cards.AddCandidate(ids, seen, id, isKnownCard)
end)
```

`isKnownCard` 由消费道具提供。候选算法没有自己的 RNG，但传入函数可能有副作用；RollPool 实际请求卡池，不应当作显示预览的纯计算。种子、重试上限、无候选回退、发放奖励属于道具；不要在库里替所有消费者统一。

消费者：[好女孩奖励](../../scripts/features/good_girl_of_babylon/rewards.lua)、[月色真美目录](../../scripts/features/the_moon_is_beautiful/)、[老大的指令](../../scripts/features/boss_order.lua)。好女孩禁用名字兜底，另外两件允许；各自重试/空候选政策留在道具。检查：[batch8_card_policy_test.lua](../../tests/batch8_card_policy_test.lua)、[boss_order_behavior_test.lua](../../tests/boss_order_behavior_test.lua)。

## 道具数量与射速换算

来源：[collectible_stats.lua](../../scripts/systems/collectible_stats.lua)，`include(...)(IsValidItemId)` 返回 `{Count, Has, AddTears}`。

- `Count(player, itemId)`：点调用，返回非负整数；player/方法/ID 不满足或原生调用失败时 0。读当前持有数量，不分配永久状态。
- `Has(player,itemId)`：点调用，先检查有效玩家/ID，再查 HasCollectible；该调用成功时以结果严格等于 true 为准，不再用数量覆盖它。调用不可用/抛错时才回退 GetCollectibleNum>0；最终 false。
- `AddTears(maxFireDelay, amount)`：点调用，按当前公式将正的“每秒发射次数增量”换算回 MaxFireDelay；amount 非正则返回数值化 delay。内部使用 `30 / max(0.0001, delay+1)`，不是直接减 delay；不支持负增量造成的减速。只返回数，不改玩家或刷新 cache。

真实消费者：[狗粮组装](../../scripts/features/dog_food_series.lua)及它加载的逐件道具。检查：[dog_food_series_behavior_test.lua](../../tests/dog_food_series_behavior_test.lua)。

## 预期致命伤害

来源：[incoming_damage.lua](../../scripts/systems/incoming_damage.lua)，导出 `IsIncomingDamageLethal(player, amount)` 函数。player 必须有效；若 HasMortalDamage 为真立即 true，否则比较 amount 与 `红心 + 魂心 + 骨心数量×2`，总值 >0 且 amount 非 nil 并达到总值才 true。amount 按现有 TakeDamage / 半心相关数值语义传入，不在这里做单位换算。

这是旧玩法共用的预判，不是模拟所有角色、护盾、伤害标记、取消链或后续其他 Mod 的最终伤害结果；函数不扣血、不取消回调。实际保命政策和顺序由八音盒、黑太岁、肉块拥有。没有完整 nil/异常保护。检查：[damage_acceptance_test.lua](../../tests/damage_acceptance_test.lua)、[batch5_lifecycle_test.lua](../../tests/batch5_lifecycle_test.lua)。

## 玩家头部位置

来源：[player_geometry.lua](../../scripts/systems/player_geometry.lua)，导出 table 的 `GetPlayerHeadWorldPosition(player)` 点调用。返回世界坐标 Vector：Position + PositionOffset + 可用的 GetFlyingOffset + 向上 `max(18, Size+4)`；缺少玩家/Position 时 Vector(320,280)，Size 默认20。

同表还导出 `GetRenderOffset(player)`：返回新 Vector，合并 PositionOffset 与受保护的 GetFlyingOffset，缺玩家时零向量。这个方法不含玩家 Position 或头部高度，不是已完成 WorldToScreen 的屏幕位置；调用者避免再重复加同一偏移。

这是近似世界锚点，不是屏幕坐标或精确动画头层位置；渲染消费者负责一次正确的坐标转换。函数不改玩家、不缓存实体、不注册回调。消费者通过 main 注入到民俗道具；相关检查：[folk_horror_items_behavior_test.lua](../../tests/folk_horror_items_behavior_test.lua)。
