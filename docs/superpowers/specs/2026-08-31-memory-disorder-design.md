# 记忆紊乱设计说明

## 目标

在不引入 REPENTOGON、StageAPI 或其他第三方依赖的前提下，为 `neverbrith` 增加品质 0 被动收藏品“记忆紊乱 / Memory Disorder”。持有者从下一次实际入房开始，在 30 帧压暗过渡的第 15 帧切换为一个已解锁、可选的原版角色；每次实际入房重新抽取。角色类型、临时起始组件、主动/口袋槽和可承载生命都由每玩家可逆状态账本管理。失去道具时立即恢复拾取前角色并撤销临时身份组件；本局 The Void 入口资格保持不可逆。

## 已锁定的道具合同

- 名称：`记忆紊乱 / Memory Disorder`
- 副标题：`我是谁？ / Who am I?`
- 类型：被动
- 品质：0
- 多份行为：多份不增加切换次数；是否持有至少一份决定身份错乱是否继续。
- 获取房不切换；下一次 `MC_POST_NEW_ROOM` 才开始第一次过渡。
- 每次实际 `MC_POST_NEW_ROOM` 都重新抽取；波次刷新不触发。
- 过渡使用更新帧计时：0–14 帧加深，15 帧切换，16–29 帧恢复，第 30 帧清理。
- 失去最后一份本体：立即撤销临时组件、恢复原始 PlayerType、恢复可承载生命和槽位快照、停止后续切换。
- 曾拾取一次后，`memoryDisorderVoidUnlockedThisRun` 在本局内不可逆，继续游戏保留，新局重置。
- 道具池、标签和权重没有获批记录；源文件不写入任何池，也不补写 tags/weight。

## 项目落点

- `main.lua`：只增加名称查找、EID/横幅文本、统一存档根初始化、模块装载和上下文注入。
- `memory_disorder.lua`：拥有全部角色池、随机、转场、临时组件、槽位、生命、图标选择、Void 入口和回调。
- `tests/memory_disorder_behavior_test.lua`：Isaac API 桩环境和合同测试。
- `content/items*.xml`：本地 ID 55、三语言元数据、牛奶图标回退；不修改 `itempools*.xml`。
- `generated/neverbirth_collectibles.lua`：追加本地 ID 55 的稳定名称映射。

## 角色合同

### 原版候选

候选表显式覆盖 `players.xml` 中可选角色：0–10、13–16、18–19、21–37。内部派生形态 11、12、17、20、38、39、40 不作为独立候选。Isaac 默认可用；其他角色由 `Isaac.GetPersistentGameData():Unlocked(profile.achievement)` 判定。API 不可用或调用失败时只保留能被明确证明可用的 Isaac，不把未验证角色偷偷加入。

### 模组角色

`MemoryDisorderCharacterProfiles` 是公开、默认空的显式白名单。每个条目必须声明 PlayerType、兼容检查、临时组件、槽位、生命适配及创建/撤销钩子。未登记角色不进入随机池。

### 高风险角色

- Lost/Tainted Lost：活动生命清空，账本保留；受击仍走正常死亡。
- Keeper/Tainted Keeper：活动红心表面按当前类型承载，切出后把实际损失同步回账本。
- Forgotten/Tainted Forgotten：优先使用 `GetOtherTwin()` 同步对应 Soul 生命；是否由中途 `ChangePlayerType` 自动建立副体必须实机验证。
- Jacob & Esau：调用真实 Jacob PlayerType；Esau 是否由中途转换建立必须实机验证。若 `GetOtherTwin()` 不存在，记录兼容诊断而不伪造玩家实体。
- Tainted Jacob：原版 Dark Esau 的建立与撤销依赖引擎角色切换行为，必须实机验证。
- Eden/Tainted Eden：真实 PlayerType 和固有机制生效；中途切换不会擅自消耗 Eden Token。随机开局物品/初始属性是否由引擎建立必须实机验证，未观察到时不得伪称完整。

## 状态所有权

### 本局保存状态

`musicboxSaveData.memoryDisorder` 保存：

- 数据版本；
- 当前 run seed；
- `memoryDisorderVoidUnlockedThisRun`；
- 每玩家的原始 PlayerType、当前 profile id、生命账本、永久主动/口袋槽快照和确定性随机序号。

仅保存 number/string/boolean/table。玩家、Sprite、RNG、Room、Entity 等 userdata 只存在运行时表。

### 每玩家运行时状态

- 当前 player 引用及稳定键；
- 上次观测到的本体份数；
- 是否已经获得过本体；
- 原始 PlayerType；
- 当前身份 profile；
- 当前临时收藏品份数；
- 临时主动和口袋槽占用；
- 永久槽位快照；
- 生命账本；
- 入房过渡 phase/frame；
- 当前显示图标 collectible id；
- 当前房间身份和随机序号。

### 本房状态

- 本房已生成的 Memory Disorder Void 入口引用与成功标记；
- 本房是否已完成合法终局结算；
- 屏幕压暗状态由正在过渡的玩家派生，不保存。

## 临时组件账本

1. 切出身份时先读取当前总份数。
2. 对上一身份记录的临时份数只调用相同次数的 `RemoveCollectible`；不清空背包。
3. 永久同 ID 份额定义为 `max(0, currentTotal - temporaryCount)`，因此移除临时份额后永久份额仍保留。
4. 新身份组件按显式 profile 添加，并记录本次实际添加的份数。
5. 主动槽和口袋槽在第一次被临时身份占用前做快照；切出临时身份时恢复 item id、普通充能、电池充能和 pocket 内容。
6. `ChangePlayerType` 自动产生的组件通过切换前后计数差纳入临时账本，避免 profile 再发一次。

## 生命账本

账本分别记录 max red、red、soul/black 位图、bone、rotten、eternal、golden、broken，以及需要的双体分支。切换前把当前身份中实际可见的损失写回账本；切换后先清理活动生命表面，再按目标角色承载规则恢复。不可承载的生命保留在账本中，不显示、不提供保护；切回可承载角色时恢复。账本绝不把死亡改为复活，也不在进房时重置到开局血量。

## 随机与图标

- 使用 `RNG():SetSeed(runSeed + playerKeyHash + roomSerial, shiftIndex)`，不使用 `math.random`。
- 角色池每次切换时从当前已解锁 profile 重新构造轻量候选数组。
- 图标候选通过 `ItemConfig:GetCollectibles()` 在首次需要时缓存；排除自身、ID<=0、缺失配置和空 GfxFileName。
- 每玩家保存本次随机图标 ID。注册静态回退使用原版 ID 25 的 `Collectibles_025_Breakfast.png`，不复制图片。
- 当前项目没有每玩家独立的被动图标 HUD。不会新增显眼 HUD；只在确实可被模块安全控制的本道具拾取/说明载体上尝试应用，其他原生静态表面继续显示牛奶回退。

## 过渡渲染

游戏状态只在更新回调推进。渲染回调只读取所有玩家过渡进度，取最大暗度并绘制一次冷灰黑全屏矩形；HUD 之后的 UI 层不应被覆盖。若基础 API 的渲染顺序无法保证 HUD 不暗，则使用项目已验证的 `Game():Darken` 路线并在实机校准；无论采用何种载体，终止/换房/死亡/失去本体会把运行时遮罩进度清零。

## The Void 合同

- 本局资格由 pickup edge 建立，失去物品不清除。
- 入口只在显式验证的终局节点和房间清空后尝试。
- 使用原版 `EffectVariant.PORTAL_TELEPORT` 的 The Void 原生入口分支；不传送玩家、不删除现有原版入口。
- 生成前检查当前房间是否已有原版入口，避免重复。
- 原生 Portal subtype 和合法节点的最终正确性属于强制实机验收；静态测试只证明 eligibility 过滤、一次生成和非终局不生成。

## 兼容与完成边界

标准 Lua API 无法静态证明中途切换会正确创建 Jacob/Esau、Forgotten/Soul、Dark Esau 或 Eden 开局随机资源。实现会保留真实 PlayerType 路线和显式诊断，不用假实体伪造；这些角色必须在最终报告中按实机结果标记“已验证”“未验证”或“未完成”。同样，原生 The Void 门户的实际可进入性必须实机验证。
