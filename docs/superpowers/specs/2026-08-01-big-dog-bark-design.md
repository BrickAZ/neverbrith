# 大狗叫与同步强化设计

日期：2026-08-01

## 目标与边界

本设计在普通 Repentance Lua 环境中实现主动道具“大狗叫”、被动强化“蓄风棒”“回响碎片”和自定义药丸“蓄风药剂”。不引入 StageAPI、REPENTOGON 或其他前置，不重构无关系统。

锁定注册：

- 大狗叫：主动，品质 3，`maxcharges="0"`，仅宝箱房池，`Weight="1" DecreaseBy="1" RemoveOn="1"`。
- 蓄风棒、回响碎片：注册为被动收藏品，但品质、池、权重按用户要求保持未指定；XML 不擅自写入品质，itempools 不加入条目。
- 蓄风药剂：注册为自定义 pill effect，不作为收藏品加入道具池。

## 已批准玩法常量

- 冲刺距离：320 像素。
- 冲刺速度：20 像素/更新帧。
- 冲撞检测半径：30 像素。
- 回响延迟：12 更新帧。
- 水迹基础半径：40 像素。
- 水迹生成间隔：4 更新帧。
- 水迹寿命：150 更新帧，正常更新率下约 5 秒。
- 强风推力：8；受击后敌人速度上限 12。
- 咀嚼追击速度：8 像素/更新帧；接触半径 28 像素。
- 从未有移动输入时，方向最终兜底为向右 `Vector(1, 0)`。
- 不同玩家的重叠水迹总伤害也不叠加；同帧取所有相交水迹中最高的所属玩家攻击力 1%。

## 文件与模块结构

- 新增 `big_dog_bark.lua`，集中拥有四个目标物的运行逻辑和 `Neverbirth.BigDogBarkTestAPI`。
- `main.lua` 只负责解析名称、包含模块、提供已有存档/玩家枚举接口以及可选 EID/横幅接入。
- XML 注册继续同步维护 `content/items.xml`、`content/items.en_us.xml`、`content/items.zh_cn.xml`、三套 itempools，以及新增三套 pocketitems。
- 实体继续走 `content/entities2.xml`；不建立 familiar 缓存体系。

## 视觉载体

大狗具有位置、AI、伤害和碰撞，所以使用已注册的 Effect 实体而不是手工渲染 Sprite。回响同样是独立 Effect。污染水迹使用自定义 Effect，以免借用原版 creep 时被无关系统识别或清除。

现有图集按 96×96 帧读取：

- `resources/gfx/Effects/BigDogBark/big_dog_entity.png`：12×12 帧网格。
  - 第 0–2 行：`FollowDown`、`FollowUp`、`FollowHorizontal`，每行 4 帧。
  - 第 3–5 行：`ChewDown`、`ChewUp`、`ChewHorizontal`，每行 6 帧。
  - 第 6–8 行：`DashDown`、`DashUp`、`DashHorizontal`，每行 4 帧。
  - 第 9–11 行：`ChargeDown`、`ChargeUp`、`ChargeHorizontal`，每行 12 帧。
- `resources/gfx/Effects/BigDogBark/big_dog_echo.png`：4×3 帧网格；`EchoDown`、`EchoUp`、`EchoHorizontal`。
- `resources/gfx/Effects/BigDogBark/big_dog_creep.png`：12×1 帧网格；`Appear` 后保持最大帧并按寿命淡出。

Horizontal 动画向左时用实体 Sprite 的水平翻转，不复制第二套图。

实体注册契约：

- Effect variant 3017：`Big Dog Bark Dog`，`Effects/BigDogBark/big_dog_entity.anm2`。
- Effect variant 3018：`Big Dog Bark Echo`，`Effects/BigDogBark/big_dog_echo.anm2`。
- Effect variant 3019：`Big Dog Bark Pollution`，`Effects/BigDogBark/big_dog_creep.anm2`。

## 玩家持久状态

存档只保存纯 Lua 数据，按 `tostring(player.InitSeed or "")` 隔离：

```lua
{
  runSeed = number,
  players = {
    [playerKey] = {
      foodPickups = number,
      chewUnlocked = boolean,
      potionArmed = boolean,
    },
  },
}
```

以上状态跨房、跨层和继续游戏保留；新开局按 run seed 清零。临时 Entity、Vector、命中表和输入 latch 不写入存档。

## 运行时状态机

每位玩家独立拥有一只大狗和以下状态：

```text
follow -> charging -> dash -> follow
                         -> echo_wait -> echo -> follow
follow -> chew_seek -> chew -> chew_pause(20) -> chew_seek/follow
```

- `charging`、`dash`、`echo_wait`、`echo`、`chew_seek`、`chew`、`chew_pause` 都阻止再次发射。
- 普通蓄力期间自动咀嚼暂停；提前松开回到 follow/chew，不消耗药剂。
- 本体冲刺完成后，大狗立即恢复 follow/咀嚼；若有回响，主动锁仍由独立 echo 状态保持到回响结束。
- 换房、换层、玩家死亡、失去主动或实体提前消失时清理临时状态；只要玩家仍持有大狗叫，新房间重建所属大狗。

## 主动输入

`MC_USE_ITEM` 的真实参数按 `(mod, itemId, rng, player, useFlags, activeSlot, customVarData)` 处理。

- 无蓄风棒：首次有效调用建立 charging latch，并返回 `{ Discharge=false, Remove=false, ShowAnim=false }`。
- `MC_POST_PLAYER_UPDATE` 根据 active slot 轮询对应主动动作是否仍按住。
- 当前射速使用 `30 / (MaxFireDelay + 1)`，蓄力时间为 `max(0.1, 0.5 * 2.73 / tears)`，帧数向上取整并按 30 更新帧/秒换算。
- 未到阈值松开为取消；达到阈值后松开才真正发射。
- 有蓄风棒：按下立即尝试发射，不建立 charging；方向取当前/最近有效移动方向的反方向。
- Car Battery 或同帧重复回调由 per-player launch latch 和 busy 状态去重。

方向只读取移动输入。当前非零移动输入优先并更新历史；静止时用最近有效方向；从未移动时向右。

## 冲刺、回响与伤害

每次成功发射冻结本次起点、方向、目标距离、药剂倍率和独立命中表。

- 本体基础伤害：`5 + target.MaxHitPoints * 0.05 + owner.Damage * 0.20`。
- 回响基础伤害：`2.5 + target.MaxHitPoints * 0.025 + owner.Damage * 0.10`。
- 药剂强化时，本体和由该本体产生的回响最终伤害均乘 1.5。
- 药剂强化时，本体冲刺距离从 320 增至 480；回响保存并重放这次实际 480 像素路径。
- 高速移动不依赖碰撞回调；每个更新帧只用 `Isaac.FindInRadius(dog.Position, 30, EntityPartition.ENEMY)` 检测局部合格敌人，并用 EntityPtrHash/InitSeed 命中表保证每次冲刺每目标一次。
- 本体结束时保存真实落点。持有回响碎片时，从原起点等待 12 帧后沿同一方向、同一实际路径和速度移动到落点；回响拥有独立命中表。
- 药剂强化的本体首次命中每个敌人时，沿冲刺方向额外施加推力 8，并将最终速度裁至 12；不创建额外伤害事件。

## 污染水迹

- 本体与回响沿路径每 4 更新帧请求生成一段水迹；起点和终点也生成。
- 任意玩家的既有水迹与新水迹邻近或相交时不新增实体，只刷新剩余寿命到 150 帧，并把半径保持为本次请求与既有值的最大值。Effect 保存所有贡献玩家的 owner seed，以便按当前面板攻击力选择唯一伤害值。
- 药剂强化发射生成半径 60 的水迹；该倍率随本次本体和回响保存，不影响以后发射。
- 每条水迹只用 `Isaac.FindInRadius` 查找局部敌人，不调用全房实体扫描。
- `MC_POST_EFFECT_UPDATE` 只把局部敌人和该水迹所有有效 owner 中最高的 `owner.Damage * 0.01` 提交到本帧候选表，不直接造成伤害。
- `MC_POST_UPDATE` 对每个敌人只取本帧最高候选并只调用一次 `TakeDamage` 和一次原生 `AddSlowing`。因此重叠水迹不会产生第二个受伤事件或重复减速调用。
- 查询分区只包含敌人，玩家永不受伤或减速。

## 大狗嚼与真实食物拾取

食物事件从新局开始监听，不要求当时已经持有大狗叫。

- `MC_PRE_PICKUP_COLLISION` 只处理 `PICKUP_COLLECTIBLE`，读取 ItemConfig 并确认 `TAG_FOOD`。
- 碰撞前记录玩家、底座身份、道具 ID 和拾取前数量；延迟结算时只在数量确实增加或项目现有 queued-item 契约证明该底座被该玩家拾取时加 1。
- 同一底座实例只结算一次；同一 ID 的另一个实际底座可再次计数。
- 初始道具、控制台直接加库存、继续读档、缓存重算和无来源库存变化都不计数。
- 第 4 次确认后永久将该玩家本局 `chewUnlocked=true`。

每房建立事件驱动目标表：进房仅初扫一次，后续 `MC_POST_NPC_INIT` 追加召唤、波次和分裂新实体。可受伤的普通敌人、召唤物、分裂体、Mini Boss 和 Boss 均合格。

- 每位玩家每房保存自己的已咀嚼实体集合。
- follow 状态下选择最近的未咀嚼目标，以 8 像素/帧追击。
- 进入 28 像素范围时造成 `target.MaxHitPoints * 0.10` 一次伤害，并标记已咀嚼。
- 随后暂停整整 20 更新帧，再寻找下一目标；无目标时回到所属玩家。

## 蓄风药剂

- 自定义 pill effect 使用 `content/pocketitems*.xml` 和按 pill effect ID 过滤的 `MC_USE_PILL`。
- 第一次服用设置该玩家 `potionArmed=true` 并保存；以后服用不叠加、不刷新倍率。
- 只有 `Launch` 成功切入 dash 后才原子地读取并清除该状态。
- 取消蓄力、busy 拒绝、主动已被换走或其他未发射路径不消费。

## 回调职责

- `MC_USE_ITEM`：开始蓄力或瞬发。
- `MC_POST_PLAYER_UPDATE`：记录移动方向、检测松开和 active slot 一致性。
- `MC_POST_EFFECT_UPDATE`：大狗、回响、水迹状态更新及水迹候选收集。
- `MC_POST_UPDATE`：食物延迟确认，以及每敌人每帧唯一一次的水迹伤害/减速结算。
- `MC_PRE_PICKUP_COLLISION`：真实 TAG_FOOD 拾取快照。
- `MC_POST_NPC_INIT`：房内新目标登记。
- `MC_USE_PILL`：设置一次性强化状态。
- `MC_POST_NEW_ROOM`、`MC_POST_NEW_LEVEL`、`MC_POST_GAME_STARTED`、`MC_PRE_GAME_EXIT`：生命周期和保存。

## 验证边界

静态/模拟测试覆盖注册、回调参数、输入状态机、公式、一次命中、回响路径、水迹刷新与非叠加、真实食物拾取、咀嚼顺序、药剂消费和合作隔离。

必须实机验证：键盘/手柄松开时序、Schoolbag/口袋槽动作映射、实体碰撞观感、正式 ANM2 播放速度与朝向、Boss/分段特殊实体表现、原生减速观感、继续游戏后的真实存档恢复，以及 `RemoveOn="1"` 在当前 Repentance 池抽取中的实际行为。
