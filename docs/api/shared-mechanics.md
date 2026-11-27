# 基础机制接口

## 攻击接管查询

[attack_ownership.lua](../../scripts/systems/attack_ownership.lua) 返回无状态表，唯一公开函数是 `AvadaOwnsAttack(mod, player)`，按点调用：

```lua
local AttackOwnership = include('scripts.systems.attack_ownership')
if AttackOwnership.AvadaOwnsAttack(Neverbirth, player) then return false end
```

`mod` 必须是可读取 `AvadaKedavra` 的当前 Mod；`player` 原样传给其公开的 `OwnsAttack(player)`。本函数保留原表达式 `mod.AvadaKedavra and mod.AvadaKedavra.OwnsAttack(player)`：字段为 nil/false 时原样短路；存在时再次动态读取字段并点调用方法，原样返回第一个结果，不强制转为布尔值。没有缓存字段、替换玩家、pcall 或缺方法回退；成员读取、无效 Mod、缺少方法及原生方法异常照常传播。不得把错误当作“允许普通攻击”。

模块没有回调、可变实例、RNG、世界查询或存档字段；每次 include 得到独立无状态表，不需退出或卸载清理。实际攻击拥有者仍由[阿瓦达查询模块](../../scripts/features/avada_kedavra/queries.lua)的 `held` 决定，并经根入口发布到 `mod.AvadaKedavra.OwnsAttack`。

当前实际消费者只有[诛的运行模块](../../scripts/features/annihilation/runtime.lua)的 `postFireTear`，以及[柴刀的战斗模块](../../scripts/features/cleaver/combat.lua)的 `UpdateSwing` / `TrySwing`：前者在有效玩家检查后让出眼泪替换，光环继续；后者取消已有挥砍或拒绝新挥砍。各自的外层资格检查、返回值和清理顺序继续由道具拥有。它不推导通用优先级，不参与命中归属或输入值处理；诛、阿瓦达和柴刀原有的实体来源追溯差异保留。

[加载与边界检查](../../tests/batch14_loading_test.lua)覆盖 nil/false、非布尔真值、动态替换、两次成员读取和异常传播；[组合检查](../../tests/batch14_boundaries_test.lua)使用真实阿瓦达公开查询验证两个消费者及队友隔离，并验证诛光环击杀不能冒充阿瓦达激光命中收据。原生验证与人工验收的边界见[本批交付](../../reports/refactor-batch14/2026-11-26/delivery.md)。

## entity_identity：瞬态实体键

[`entity_identity.lua`](../../scripts/systems/entity_identity.lua)返回纯函数，用 `local key = include('scripts/systems/entity_identity')` 加载，以 `key(entity)` 点调用。输入是能读取 `InitSeed` 的实体/测试对象；输出为 `tostring(GetPtrHash(entity)) .. ':' .. tostring(entity.InitSeed or 0)`。没有 GetPtrHash 时用 `tostring(entity)` 作前半段。函数每次读取当前全局 API，不缓存对象或键，不吞掉原生错误；API 存在但返回 nil 时前半段仍是字符串 `nil`，保持原表达式语义。

这是瞬态去重/匹配键，不是可跨进程保存的玩家身份；不合并 Lazarus form，不附加 ControllerIndex。它不登记回调、不抽 RNG、不访问存档或世界，没有可变实例状态。调用方拥有相应表的换房、新局、沙漏、移除和卸载清理责任。重复加载仅创建无状态函数，无重绑生命周期。

本批实际消费者为 [motion_input](../../motion_input.lua)、[motion_input_shooting](../../motion_input_shooting.lua)、[motion_items](../../motion_items.lua)、[motion_combat](../../motion_combat.lua)和 [motion_presentation](../../motion_presentation.lua)，取代六处相同算法。各处显式 Key/EntityKey 提供者仍优先，保留原来 `if provider` 和 `provider(...) or fallback` 的差别。战斗存档使用的 inventory/form 键、默认 InitSeed/ControllerIndex 键，以及只使用 pointer 的渲染隐藏比较，不改用本函数。真实消费者与 wrapper/新生成实体隔离测试见 [batch21_identity_test.lua](../../tests/batch21_identity_test.lua)，完整用法见[斗气拳套与搓招系统](drive-motion.md)。

本页记录当前工作区提取的基础模块；它们不注册 callback，也不独占某道具的保存状态。数值、身份、失败政策沿用调用者合同。

## 世界查询

[world_queries.lua](../../scripts/runtime/world_queries.lua) 返回 World 表，全部点调用。

| 接口 | 参数与行为 |
| --- | --- |
| `TryGame()` | pcall(Game)，返回取得值或 nil，不缓存 |
| `TryMethod(object,method)` | method 是字符串，查到成员后按冒号形式调用 `object[method](object)`，只返回首结果；成员缺失或调用失败 nil。不支持额外参数，成员索引访问本身不在 pcall 中 |
| `TryItemConfig()` | 受保护的 Isaac.GetItemConfig，失败 nil |
| `RunFloorKey(level,getRunSeed)` | 返回现有 `runSeed:stage:stageType`；level 缺失 `runSeed:unknown`，缺方法则该项 unknown。种子必须可拼接，不捕获直接楼层方法异常，不含维度 |
| `RoomIndexOrSeed(getLevel,getRoom)` | 优先受保护的当前房间索引 `idx:<值>`；无可用索引才查询 room spawn seed 为 `seed:<值>`，否则 unknown。两个 getter 自己抛错不被吞掉 |

RoomIndexOrSeed 不含楼层/局身份，不能直接当永久存档唯一键。真实消费者：[folk_world](../../scripts/systems/folk_world.lua)、[两盒共享](../../scripts/features/boxes/shared.lua)、[card_rewards](../../scripts/systems/card_rewards.lua)。要求错误直接传播的原路径不能为了复用而改成 TryMethod。

[ACE 查询模块](../../scripts/features/ace_anti_cheat_system/queries.lua)也调用 `World.TryGame()`：外层仍只接受 function 类型的 Game，并将 false 结果转为 nil，保留旧模块的容错合同。其他道具不受这层政策影响；查询不缓存对象，也不负责新局或退出清理。真实接入及错误、false、非函数边界由 [第十五批检查](../../tests/batch15_boundaries_test.lua)覆盖。

## 主动槽

[active_slots.lua](../../scripts/systems/active_slots.lua) 导出 `BuildActiveSlots()`。每次返回新的数组，按 PRIMARY、SECONDARY、POCKET、POCKET2 顺序仅保留实际枚举成员。整个 ActiveSlot 不存在才回退 `{0,1,2,3}`；部分枚举缺项时不补造缺项。既不检查玩家当前持有，也不读写充能。

消费者：[血颅蛊](../../scripts/features/blood_skull_gu.lua)、[剪碎塔罗](../../scripts/features/shredded_tarot.lua)、[两盒共享](../../scripts/features/boxes/shared.lua)。

## 道具随机数

[collectible_rng.lua](../../scripts/systems/collectible_rng.lua) 返回 Rolls 表，点调用：

- `Get(player,itemId,requiredMethod?)`：保护 GetCollectibleRNG；仅当 RNG 存在且所需成员存在才返回该 RNG，否则 nil。不抽数、不证明成员一定是 function。
- `IntOrMath(rng,max)`：尝试 RandomInt(max)，成功且非 nil 时 tonumber 并夹在0..max-1；不保证对返回浮点向下取整。失败回退 math.random(max)-1。max 需调用者保证合法正数范围，不能传0然后依赖回退。
- `IntOrRoomSeed(rng,max,getRoom)`：成功的数字结果先 floor 再夹取；失败改用当前 room spawn seed（缺失0）floor 后模 max。getRoom 和其 seed 方法异常不会自动吞掉。

随机流及回退策略不同，调用者应明确选择，不能用两者互换消除测试失败。实际抽取有副作用；房间种子回退是固定计算，不等于推进同一个道具 RNG。真实消费者：[folk_world](../../scripts/systems/folk_world.lua)、[血颅蛊](../../scripts/features/blood_skull_gu.lua)、[强力泻药大便](../../scripts/features/strong_laxative/poop.lua)。

## 战斗来源

[combat_source.lua](../../scripts/systems/combat_source.lua) 返回 Source 表：`Entity(source)` 有 source.Entity 时返回它，否则原样返回 source；`TryPlayer(entity)` 保护 ToPlayer，返回成功的玩家或 nil。两者均点调用。

不追溯炸弹/跟班/泪弹 owner，不判定伤害是否支付、不替道具授予击杀信用。仅转换当前值的形状。消费者：[生死一念间](../../scripts/features/between_death_and_life.lua)、[铜钱面具结算](../../scripts/features/coin_faced_mask/settlement.lua)。

[焚尽郁结查询](../../scripts/features/burn_away_resentment/queries.lua)也复用 `TryPlayer(owner)`：先在本件按泪弹/激光/刀/炸弹与 SpawnerEntity → Spawner → Parent 的原优先级选定 owner，再调用转换。转换失败后是否接受 `owner.Type == ENTITY_PLAYER` 仍由本件决定；不会继续向第二层 owner 搜索。来源解包保留原单次成员读取表达式，公共模块接口未扩展。

## 射速增量

[fire_rate.lua](../../scripts/systems/fire_rate.lua) 导出 `AddTears(maxFireDelay,amount)`，具体公式与边界见[属性换算](gameplay-queries.md)。它是纯数值变换，amount 非正不减速；不更新 player、不刷新 cache。`collectible_stats.AddTears` 现在委托此函数；[流量热度](../../scripts/features/traffic_heat.lua)也直接消费。原先直接减 MaxFireDelay 的不同玩法不应强行切换。

## Null costume

[null_costumes.lua](../../scripts/systems/null_costumes.lua) 返回 Costumes 表，全部点调用：

| 接口 | 合同 |
| --- | --- |
| `GetCachedId(cache,key,path,deferFailureCache?)` | cache 是调用者拥有的可变表；已有非 nil 结果直接返回（false→nil），首次失败写 false；只接受查得的正数 ID。默认在原生查询前写 false，铜钱面具和千变万化传 true 改为查询后才发布失败缓存，保留重入差异。始终写传入的表，不跟踪调用者重绑。不自动重试失败缓存，不验证动画画面 |
| `Add(player,id)` / `Remove(player,id)` | 有对象、ID、对应方法时 pcall 原生加/移服装；无成功返回值。失败被保留为原有静默行为，不能声称已显示/移除 |
| `Transition(getStates,key,visualState,apply)` | 当前状态相同直接返回；否则先 apply()，返回后再重新 getStates 写状态。apply 抛错时不写；如果 apply 内用 Add/Remove 吞异常，则仍可能记下状态 |

缓存及视觉状态表由各消费者拥有；Transition 不保存旧表引用，不自行清理失去道具、新局或玩家重建。不会写存档。真实消费者：[好女孩表现](../../scripts/features/good_girl_of_babylon/presentation.lua)、[面具表现](../../scripts/features/coin_faced_mask/presentation.lua)、[泻药表现](../../scripts/features/strong_laxative/presentation.lua)、[千变万化资源解析](../../scripts/features/everchanging/resources.lua)。

千变万化使用 `Costumes.GetCachedId(costumeIdCache, costumePath, costumePath, true)`。资源路径同时作为键，失败诊断仍由本件维护。原生查询可能重入卸载并替换本件缓存，因此该消费者返回后再把 `costumeId or false` 发布到当前缓存表，保持旧实现的写入时机。双人外观需要判断单次增删是否成功并清理已应用的一半，所以保留自己的 pcall 和回滚，不使用没有成功返回值的 Add/Remove。对应正/负缓存、同路径重入、查询中卸载重绑、双侧回滚及 ANM2 所有权检查见 [batch12_boundaries_test.lua](../../tests/batch12_boundaries_test.lua)。

强力泻药的表现层以当前身体的 `GetData()` 表身份作为本地视觉缓存键，同一原生身体的多个 Lua 包装共享去重，不同身体即使沿用相同玩家种子也分别应用外观。只读取表身份，不向 `GetData()` 写字段，也不保存到 JSON；无原生 GetData 的实体式调用方使用传入对象身份。所有仍存活且由本件持有外观的身体在新局、Continue、退出、卸载时清理，失效身体跳过原生移除。玩法计时仍使用原玩家键，普通换房仍只按原规则重置计时。此政策只属于泻药，不改变其他服装消费者的键或失效规则。原生数据生命周期依据 [Entity.GetData 文档](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#getdata)；本次模拟覆盖不等于某一种原生复活路线已经验收。

基础边界检查见 [shared_capabilities_contract_test.lua](../../tests/shared_capabilities_contract_test.lua)；三件服装消费者、负缓存、重入与状态表重绑见 [shared_costume_consumers_test.lua](../../tests/shared_costume_consumers_test.lua)；泻药的同键新身体、同身体多包装、退出清理及原计时保留见 [fortune_laxative_boundaries_test.lua](../../tests/fortune_laxative_boundaries_test.lua)。其余行为检查从各消费者和[统一检查入口](../agent/testing.md)选择；实际原生验证范围以日期化交付记录为准。
