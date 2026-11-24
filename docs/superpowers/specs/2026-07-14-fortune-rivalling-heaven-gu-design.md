# 鸿运齐天蛊设计

## 已确认的物品定义

- 中文名：鸿运齐天蛊
- 英文名：Fortune Rivalling Heaven Gu
- 英文副标题：The world bends your way.
- 类型：被动收藏品；品质 4。
- 道具池：项目当前所有池均以 `Weight="0.1" DecreaseBy="1" RemoveOn="0.1"` 登记。
- 标签：`TBD`，本次不臆造。

## 范围与非目标

本期先实现收藏品机制。幸运阈值审查表覆盖截图中的收藏品、饰品、组合、版本变体与反向幸运条目；它直接生成运行时注册。收藏品使用 `RegisterLuckCap` / `RegisterLuckCapResolver`，饰品使用独立的类型命名空间并读取 `GetTrinketMultiplier` 以覆盖持有、吞下和金色饰品。旧版本与反向条目保留在同一表中，但普通 Repentance 运行时只激活当前正向条目。

所有世界事件按“玩家是否拥有至少一枚鸿运齐天蛊”判定。多枚蛊不会增加 10%、1% 或 5% 的掷骰次数；多人合作中，每位持有者各自进行一次独立判定。

未知外部模组的奖励来源和自定义道具池一律失败保留：没有显式注册来源，就不复制奖励或生成同池底座，绝不退化为全局池。

## 公开 API

在 `Neverbirth` 上提供：

```lua
Neverbirth:RegisterLuckCap(itemId, fixedCap)
Neverbirth:RegisterLuckCapResolver(itemId, resolverFn)
Neverbirth:RegisterFortuneRewardSource(sourceKey, resolverFn)
Neverbirth:RegisterFortunePedestalPoolSource(pickupOrKey, poolId)
```

前两个接口分别登记固定满概率幸运阈值和动态阈值。`resolverFn` 在对应玩家拥有该收藏品时计算当前阈值。后两个接口只为可验证的外部来源提供显式接入；参数与返回契约将写在代码注释和行为测试中。

## 天运加护

每次 `CACHE_LUCK` 结算时：

1. 读取当前回调链给出的 `player.Luck`，将其作为原始幸运基线。
2. 遍历注册表中有限的、已登记的 Collectible ID；只对玩家实际拥有的 ID 求固定阈值或 resolver 阈值。
3. `requiredLuck` 是全部当前有效阈值的最大值。
4. 仅当玩家持有鸿运齐天蛊时，写回 `max(player.Luck, requiredLuck)`。

不存储补偿层数，不在 `CACHE_LUCK` 外直接写幸运，因此反复 EvaluateItems 不会累加。该计算完全以玩家实例为单位，合作模式互不影响。

原版条目只登记有可靠满概率阈值资料支持的 Collectible；没有可验证阈值的物品不猜测、不登记。neverbrith 后续物品通过同一 API 接入。

## 双喜临门：奖励事件账本

对房间通关、Boss、宝箱、乞丐成功、机器成功建立短时“原始奖励事件”上下文。原版奖励先完整发生；账本归集该次原始事件产生的非 Collectible Pickup。每位持有者各有一次 10% 判定；成功时在原奖励已出现后复制本次归集的非底座结果，并标记复制结果不可再次触发双喜临门。

Collectible pedestal 不会进入本规则；它只由下述 1% 规则处理。若来源无法确认或无法完整归集，账本丢弃该次额外奖励机会，保留原奖励。

## 同池额外底座

每个首次更新的、可拾取 Collectible pedestal 只对自身进行一次检查。持有者存在时掷一次 1%。成功后：

1. 从原生来源映射或显式注册记录取得该 pedestal 的来源道具池。
2. 先调用“额外底座出现”视觉钩子。
3. 用同一个来源池生成并生成第二个真实可拾取 pedestal，不创建二选一选项。

若来源池未知，不生成额外 pedestal。生成出的第二底座没有防链标记；它作为新实体也会独立进行自己的 1% 检查，链条不设上限。

## 幸运币外溢

每个首次更新的 Coin Pickup 使用自身数据标记为已检查，确保每枚币只完成一次后置判定。原币的变种、类型、消失和数值都不改动。持有者存在时掷一次固定 5%：成功先调用幸运币视觉钩子，然后在原币附近生成原版 Lucky Penny。

Lucky Penny 是新的 Coin Pickup，因而同样只检查自己一次并可自然继续 5% 链；幸运值不会参与此概率。

## 回调与性能约束

- 使用现有项目认可的 `MC_EVALUATE_CACHE` 和 Pickup 生命周期回调；每个实体通过 `GetData()` 一次性标记。
- 奖励事件仅在相关原生回调期间建立短时账本，不做每帧全房间或全场扫描。
- 不使用 `MC_POST_ADD_COLLECTIBLE`，不使用全局物品枚举，不把未知来源替换成全局道具池。
- 所有不需要阻止原版行为的回调均返回 `nil`。

## 视觉分阶段接入

当前美术资源尚未提供。第一阶段定义并调用四个安全空钩子：玩家鸿运印、命线分岔、底座虫影/命线、幸运币效果；不登记不存在的 `.anm2` 路径或效果实体。

当资源 bot 交付下列资源后，第二阶段在不改变机制的前提下接入实体/动画：collectible icon、`fortune_mark.anm2`、`fortune_fork.anm2`、`fortune_pedestal.anm2`、`fortune_coin.anm2`。在图标到位前，物品 XML/pool 注册不能安全完成，避免静态校验出现悬空资源。

## 验证

行为测试覆盖：固定/动态幸运上限与幂等性、合作模式隔离、单持有者一次掷骰、多枚蛊不增加掷骰、事件级 10% 防递归、同池 pedestal 链、所有币种原样保留、Lucky Penny 链、未知来源失败保留和所有回调 `nil`。

静态验证包括 Lua 语法、现有行为测试、语言测试、全部 content XML 解析、项目验证器和 `git diff --check`。资源交付前，物品配置静态接入作为明确待办，而不是伪造资源路径。
