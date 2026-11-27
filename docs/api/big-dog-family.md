# 大狗组三件的组内接口与实例合同

此页描述大狗叫、蓄风棒、回响碎片之间实际使用的组内能力，不把它们推广为全 Mod 的通用战斗框架。玩法、原公开名字和存档语义沿用原实现。

## 入口与加载

旧[根目录工厂](../../big_dog_bark.lua)返回[大狗叫入口](../../scripts/features/big_dog_bark.lua)的工厂。调用形状保持 `factory(Neverbirth, context)`；主入口仍在原位置只调用一次。返回值和 `Neverbirth.BigDogBarkTestAPI` 是原有同一张兼容观察表，不新增生产模块对 TestAPI 的依赖。

`context.ItemIds` 提供 `BigDogBark/WindChargeRod/EchoShard`，仍用 `tonumber(...) or -1`；`Variants.Dog/Echo/Trail` 仍缺省为 3017/3018/3019。`PillNames` 或 `PillName` 及中英文后备名称的查找顺序不变。

旧提供表的 `GetPlayers()`、`GetCollectibleConfig(id)`、`GetSaveRoot()`、`GetCurrentRunSeed()`、`Save()`、`DebugLog(text)` 按原错误处理调用。Queries、State、Input 保留原 context 引用；不能复制这些字段后永久捕获，因为旧合同允许事件执行前替换提供函数或存档根。每个模块仅读取自己的具名字段，不使用它查找其他玩法模块。

入口创建各实例、传入明确依赖并保留安装顺序。私有模块的安装函数不承诺幂等；在外层 feature_installation 事务中各调用一次。方法采用点调用，不传隐式 self。仅返回函数/创建私有表的步骤不会登记回调，安装方法才登记；药剂 ID 仍在创建时查询一次，未知 ID 时在使用事件中重试。

## 三件道具的实际职责

| 入口 | 导出和消费者 | 语义 |
| --- | --- | --- |
| [大狗叫](../../scripts/features/big_dog_bark.lua) | 原完整 TestAPI 兼容观察表；主入口创建 | 拥有配置、私有实例、依赖装配与原安装阶段。主体战斗和状态在同名目录内 |
| [蓄风棒](../../scripts/features/wind_charge_rod.lua) | `(itemId, hasCollectible) -> {ItemId, IsHeld(player)}`；input 的 useItem 调用两次 | ItemId 按旧数值规则解析；IsHeld 原样委托组内持有查询，缺方法/抛错/非 true 均不认为持有。两次查询时机保留，分别影响反向与立即发射，不缓存结果 |
| [回响碎片](../../scripts/features/echo_shard.lua) | `ItemId`、`computeEchoDamage(maxHP, damage, multiplier)`、`createEchoFromDash(dash)`、`spawnEchoEffect(state, echo)`、`updateEcho(_, effect)`、`Installers.updateEcho()`；dash 与入口消费 | 伤害规则、独立回响 hitMap、12 逻辑帧延迟、实体生成和更新属于本件；回响消费共同目标/伤害及水迹能力。只有其安装函数登记原生实体更新 |

`createEchoFromDash` 没有有效回响资格时返回 nil；有效时返回新表和复制的向量，但 owner 仍为当前运行时玩家引用。`spawnEchoEffect` 失败返回 nil，成功更新同一玩家的 echo 字段。`computeEchoDamage` 是纯数值计算；其余函数按原逻辑读取状态或操作引擎，不当作纯查询。

## 组内能力与真实消费者

| 私有模块 | 责任、实际消费者与副作用 |
| --- | --- |
| [queries](../../scripts/features/big_dog_bark/queries.lua) | 三件共享的向量运算、实体/玩家键、持有/配置和世界查询。保留原安全调用及回退；不产生 RNG 抽样或道具池请求 |
| [rules](../../scripts/features/big_dog_bark/rules.lua) | 大狗蓄力、方向、忙碌状态、冲刺/咀嚼伤害与冲量公式；input、dash、chew 消费。registerHit 会写入调用方 hitMap，其余主要是数值计算 |
| [state](../../scripts/features/big_dog_bark/state.lua) | 唯一 Runtime、存档根适配与玩家状态；输入、食物、冲刺、回响、水迹等共用一个实例。GetPlayerRecord 会规范化/创建数据，UseWindPill 会写状态并保存；查询名不代表纯度 |
| [audio](../../scripts/features/big_dog_bark/audio.lua) | 蓄力与释放声音、音高调度、私有音效 ID 缓存；input、dash、lifecycle 消费。调用可能播放声音，不负责扣费或伤害 |
| [effects](../../scripts/features/big_dog_bark/effects.lua) | 大狗/回响/水迹共用的效果生成、原 EntityRef 伤害调用、方向动画、碰撞关闭、跟随位置；实例不另持有玩家账本 |
| [targets](../../scripts/features/big_dog_bark/targets.lua) | 目标资格、EntityPtr/后备引用、房间目标目录、附近/线段查询和命中后去重；dash、echo、chew、trails 消费。只在原房间事件扫描全部实体，热路径按原方式使用局部查询 |
| [trails](../../scripts/features/big_dog_bark/trails.lua) | 冲刺/回响共用的水迹合并、节点表现、贡献者选择、每敌每帧候选结算、过期和移除；二者显式共享一个实例。最高伤害贡献者规则、同伤害遍历行为不变 |
| [food](../../scripts/features/big_dog_bark/food.lua) | 食物标签确认、碰撞快照、队列/库存确认、四份解锁与每次保存；lifecycle 推进结算。没有改用 POST_ADD_COLLECTIBLE 或全量配置扫描 |
| [dash](../../scripts/features/big_dog_bark/dash.lua) | 发射准入、药剂成功消费、前进、命中与回响交接；input 消费；复用原 Avada 攻击所有权查询 |
| [chew](../../scripts/features/big_dog_bark/chew.lua) | 大狗自动咀嚼、原网格寻路、目标接近、动画事件命中和恢复；input 的狗实体更新调用 |
| [hud](../../scripts/features/big_dog_bark/hud.lua) | 蓄力条动画与屏幕投影；input 设置显示阶段，渲染事件推进原视觉动画。玩法就绪仍由玩家更新决定 |
| [input](../../scripts/features/big_dog_bark/input.lua) | 主动槽输入、蓄力与松手、狗实体分派、药剂回调；调用 Rod、Dash、Chew 和 Hud 的实际实例 |
| [upgrade_pool](../../scripts/features/big_dog_bark/upgrade_pool.lua) | 两件升级共同的持有大狗门控、原池重抽和拒绝道具权重恢复；32 次上限、种子推进、局部重入保护与异常回退保持 |
| [lifecycle](../../scripts/features/big_dog_bark/lifecycle.lua) | 协调换房、开始、退出和 update。先结算当前帧水迹，再推进 frame，然后食物结算/过期清理；不创建新调度器 |

表中 Runtime、玩家 state、回响/冲刺/水迹表均为组内共享的可变运行对象，消费者不得另执行工厂来取得它们。State 始终保留 Runtime 外层表，清理时替换其内部集合；旧集合或房间实体不应跨重建持有。对外保留的 TestAPI 引用关系与原实现相同。

## 存档与边界

- 存档仍是 `root.bigDogBark = {runSeed, players}`，玩家键是原 `tostring(InitSeed)`。每人记录 `foodPickups/chewUnlocked/potionArmed`，未知根字段不覆盖。
- 食物记录按原顺序结算并保存；药剂成功武装保存，只有成功发射且未显式指定倍率时消费并保存；新局和退出保存点保持。普通保护查询/渲染不新增保存。
- Continue 取当前保存根并重建运行时；新局重置此区域；换房清除临时战斗、候选和水迹，保留食物与药剂；原 newLevel 空处理保持。
- 暂停/慢动作和动画事件按原时钟推进，回响延迟为 12 个 Runtime.frame 增量。没有新增沙漏捕获、卸载处理或跨进程身份映射政策。
- 蓄风棒/回响碎片在使用、发射等原时点取样，不新增失去升级后取消既有攻击的规则。

## 复用边界与检查

本组已经共享一份状态、目标、效果和水迹实现。未换用全局 active_slots：它对部分缺失枚举只返回存在项，而本组逐槽保留 0/1/2/3 后备；未换用 collectible_stats.Has：它可用数量兜底，而本组只接受 HasCollectible 的 true。原向量构造失败回退、实体资格及食物队列结算也有自己的合同。以上差异有源码依据，不能为了共享名称改变行为。

既有检查为 [完整大狗行为](../../tests/big_dog_bark_behavior_test.lua)、[升级池](../../tests/big_dog_upgrade_pool_behavior_test.lua)；新增[生命周期边界](../../tests/batch13_boundaries_test.lua)、[加载及安装回滚](../../tests/batch13_loading_test.lua)，完整缺失模块回滚沿用[真实入口检查](../../tests/thin_entry_installation_test.lua)。旧新函数、保存/伤害轨迹和原生证据见[第十三批交付](../../reports/refactor-batch13/2026-11-26/delivery.md)。
