# 千变万化（Everchanging）设计

日期：2026-07-20  
状态：已确认  
实现范围：neverbrith 普通 Repentance 环境，不新增第三方前置

## 1. 锁定需求

- 中文名：千变万化
- 英文名：Everchanging
- 被动道具，品质 0。
- 不进入任何常规道具池，只能通过控制台或测试取得。
- 不提供属性、伤害、攻击、掉落、房间或其他玩法效果。
- 每名持有者独立抽取、保存和显示一套样式；非持有者不受影响。
- 每次增加一个千变万化本体时抽取一次。重复取得时应换成与当前不同的样式；样式库只有一项时维持原样。
- 失去全部本体后移除样式并恢复正常外观。
- 样式持续到本局结束；切层、离房、死亡复活、退出继续不会重抽。
- 第一套正式样式为现有蓝色香蕉皮头饰；除此之外不制作、猜测或登记其他最终样式资源。空库保护仍作为公开注册表的故障边界保留。

## 2. 已确认的项目骨架

- 道具和回调的实际所有者是根目录 `main.lua`。
- 注册镜像为 `content/items.xml`、`content/items.en_us.xml`、`content/items.zh_cn.xml`。
- 道具池镜像为三个 `content/itempools*.xml`；本物品不写入其中任何一个。
- EID 描述由 `main.lua` 内的 `EID_DESCRIPTIONS` 可选注册，不把 EID 设为强依赖。
- 本局保存统一存放在 `musicboxSaveData`，通过 `EnsureMusicboxDataLoaded()` 与 `SaveMusicboxData()` 管理。
- 当前外观采用 `content/costumes2.xml` 注册的 null costume，并通过 `AddNullCostume` / `TryRemoveNullCostume` 应用和移除。已有资源优先级为 98。
- 当前 costume ANM2 证明了 `head2`、`head4` 等头部叠层可用，但项目没有通用的 head/face/body/legs/accessory/full 插槽实现。
- `content/players.xml` 当前只注册 Stranger；它必须作为项目已知不兼容角色排除。

## 3. 选定方案

采用组合式 null costume，不修改玩家基础 spritesheet。

一个样式条目只声明自己拥有的 slots，每个声明的 slot 映射到一个已注册的 costume ANM2。应用样式时只挂载这些 costume；未声明的部位不调用替换或清理，因此继续由角色基础外观和普通道具 costume 管理。

`full` 也使用专门制作的完整 null-costume ANM2；不得在运行时粗暴替换玩家基础 spritesheet。完整 ANM2 必须由美术/ANM2 流程保证方向、受伤闪白、无敌闪烁、武器锚点与角色可读性。

现有香蕉皮 costume 使用项目当前高优先级 98。未来样式沿用项目已经验证的高优先级约定；Lua 不会在每帧调用 `LoadGraphics` 或 `ReplaceSpritesheet`。

## 4. StyleRegistry

集中式登记区位于千变万化代码块顶部：

```lua
local STYLE_SPECS = {
    {
        id = "blue_banana_peel",
        slots = { "head" },
        resources = {
            head = { costume = "gfx/characters/costume_blue_banana_peel.anm2" },
        },
        full = false,
        metadata = { source = "existing_blue_banana_peel_costume" },
    },
}
```

允许的 slot 仅为：`full`、`head`、`face`、`body`、`legs`、`accessory`。

启动时把数组校验并索引为 `StyleRegistry.byId` 和稳定有序的 `StyleRegistry.entries`：

- `id` 必须是非空且唯一的稳定英文 ID。
- `slots` 必须是无重复的允许值数组。
- `full=true` 时必须声明 `full`，并且不得同时声明其他 slot。
- 每个 slot 必须在 `resources[slot].costume` 中提供 ANM2 路径。
- 资源通过 `Isaac.GetCostumeIdByPath` 延迟解析并缓存；解析失败时记录样式 ID、slot 和失败路径。
- 无效条目不进入抽取集合，不影响其他有效样式。
- 不在运行时扫描目录、`costumes2.xml` 或外部模组资源推断样式。

## 5. 每玩家本局状态

在 `musicboxSaveData.everchanging` 保存纯 Lua 数据：

```lua
{
    runSeed = "...",
    players = {
        [tostring(player.InitSeed)] = {
            knownCopies = 1,
            styleId = "blue_banana_peel",
            rollCount = 1,
        },
    },
}
```

运行时 `player:GetData()` 仅保存不可序列化的应用标记：当前已挂载的 style ID、已挂载 costume ID 列表以及 dirty 标记。保存文件不写入玩家 userdata、Sprite 或 costume 引用。

- 新开局：重建 `everchanging` 为当前 run seed 的空状态。
- 继续游戏：保留同 run seed 的玩家样式，重新构造运行时 costume 引用并应用原 style ID。
- 主菜单/不同 run seed：旧状态不可复用。
- 合作模式：以 `tostring(player.InitSeed or "")` 隔离玩家。

## 6. 获得、重抽和失去

普通 Repentance 不依赖未经确认的扩展回调。使用玩家更新回调只读取该玩家的 `GetCollectibleNum(Items.Everchanging)`，不扫描其全部库存，也不枚举 ItemConfig。

- `currentCopies > knownCopies`：按差值逐次执行抽取。
- 第一次取得：从全部有效样式均匀抽一个。
- 重复取得：有效样式超过一项时，从排除当前 style ID 后的集合抽取；只有一项时保持原样。
- `currentCopies < knownCopies` 且仍大于 0：保留当前样式，只同步数量。
- `currentCopies == 0`：移除本系统挂载的 costume，清除该玩家 style ID 和运行时标记。
- 空样式库：不设置 style ID，不改外观，按玩家/取得事件节流输出 `[neverbirth] Everchanging style registry is empty`。

抽取使用 `player:GetCollectibleRNG(Items.Everchanging):RandomInt(candidateCount)`。随机调用只发生在本体数量增加时；相同种子和相同取得顺序将得到稳定结果，不在每帧消耗 RNG。

## 7. 应用、优先级与性能

样式变化时：

1. 仅移除该玩家上一次由千变万化记录的 costume ID。
2. 校验新样式的全部声明资源。
3. 任一关键资源失败时，不挂载残缺样式，恢复正常外观并记录错误。
4. 全部资源有效后，逐个 `AddNullCostume`。
5. 保存已应用 style ID 和 costume ID，清除 dirty。

重应用触发点：

- 本体数量变化；
- `MC_POST_PLAYER_INIT`（若普通 Repentance 提供）；
- `MC_POST_GAME_STARTED`；
- `MC_POST_NEW_ROOM`；
- `MC_POST_NEW_LEVEL`；
- 玩家运行时 `GetData()` 标记消失（复活或实体重建）。

更新回调可以每帧做一次 O(1) 的“本物品数量 + dirty 标记”检查，但不得每帧无条件 AddNullCostume、LoadGraphics、ReplaceSpritesheet 或遍历样式资源。

## 8. 兼容性判定

兼容判定必须保守：

1. 从项目实际注册源解析 Stranger 的 PlayerType；命中时拒绝应用。
2. 读取 `player:GetSprite():GetFilename()`，仅接受原版标准玩家骨架文件；无法读取或文件不是标准骨架时拒绝应用。
3. 不改变 PlayerType、碰撞箱、尺寸、攻击方式、攻击方向、HUD 头像、名称或武器逻辑。
4. 被拒绝的玩家仍按取得顺序抽取并保存 style ID，但不应用 costume；如果角色之后变回可兼容骨架，则应用同一 style ID 而不重抽。日志按玩家节流，避免刷屏。

该规则会保守拒绝无法证明兼容的自定义角色，优先保证不污染其贴图。标准骨架识别需要在实现测试中由实际 Sprite filename 桩明确验证，不能仅凭角色显示名称判断。

## 9. 注册与本地化

- 追加本地 ID 38，不重排现有 ID。
- 三份 `items*.xml` 注册同一品质 0 被动道具。
- 三份 `itempools*.xml` 均不增加该道具。
- `ITEM_NAME_CANDIDATES` 和 `Items` 增加 Everchanging。
- 用户尚未提供拾取副标题或 EID 文案。三份 XML 暂用空 `description`，本次不擅自编写 `EID_DESCRIPTIONS`；未来获得确认文案后再接入可选 EID。
- `generated/neverbirth_collectibles.lua` 通过项目生成流程同步，不手改一份与 XML 脱节的私有列表。
- 正式道具图标已存在于 `resources/gfx/Items/Collectibles/Everchanging.png`，尺寸为 32×32、RGBA；三份 XML 使用大小写完全一致的 `gfx="Everchanging.png"`。

## 10. 测试

新增独立行为测试，至少覆盖：

1. XML 注册为品质 0 被动，且三个道具池均不存在该名称。
2. 空 `STYLE_SPECS` 保护不崩溃、不挂载 costume，并输出空库日志。
3. 首次获得会使用物品 RNG 抽取并应用 `blue_banana_peel`。
4. 第二个本体从非当前样式集合抽取；只有一项时不变化。
5. 失去全部本体只移除千变万化自己挂载的 costume。
6. 两名玩家的 InitSeed、样式和 costume 独立。
7. 新房、切层、复活/运行时标记丢失后恢复同一 style ID，不消耗 RNG。
8. 继续游戏恢复同一 style ID；新开局清理旧状态。
9. 局部样式只调用声明 slot 对应的 costume，不触碰未声明部位。
10. Stranger、非标准骨架和无法识别骨架不应用且不报错。
11. 缺失 costume 路径时整套样式回退，并记录 style ID、slot 和路径。
12. 更新热路径不调用 LoadGraphics 或 ReplaceSpritesheet，也不重复 AddNullCostume。

静态验证包括 Lua 语法、独立行为测试、本地化测试、XML 解析、项目 validator 和 `git diff --check`。

## 11. 实机边界

现有香蕉皮已经提供正式 ANM2/PNG 和 `costumes2.xml` 注册，因此本次可实机验证首次抽取、四方向头部动画、高优先级遮挡、未声明部位保留以及丢失道具后的移除。

受伤闪白、无敌闪烁、武器锚点、各标准角色体型、合作模式和复活后的视觉恢复仍必须在游戏内验证，静态测试不能替代这些结论。
