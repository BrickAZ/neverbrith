# 再契象（House VS Elephant）设计

## 已锁定注册

- 主动道具，本地 ID 37，品质 4，`maxcharges=0`，拾取后立即可用。
- 中文名“再契象”，英文名“House VS Elephant”。
- 固定文案“谁不想急头白脸来一把房子VS大象呢？”。
- 仅进入隐藏房池，权重 0.1；标签为 `summonable offensive nochallenge`。
- 图标复用 `resources/gfx/Items/Collectibles/saikeissho.png`。

## 本局遇见记录

`MC_POST_NEW_ROOM` 只扫描进入房间时已经存在的 collectible pedestal。每个实例使用
`Stage|StageType|Dimension|SafeGridIndex|InitSeed` 作为唯一键，按首次遇见顺序保存
`itemId` 与实例序号；相同 collectible ID 的不同底座分别记录。再契象选择房生成的底座、
Milk 保底和其他非收藏品 pickup 不进入记录。

记录属于 run：新开局或 run seed 改变时清空；存档退出并继续同一局时保留。选择房临时会话
不会在继续游戏时恢复，读档时中止并尝试回到原房间，避免重复选择。

## 候选构造

使用时先遍历 encounter 中出现过的 ID，按所有玩家的当前 `HasCollectible` 结果建立持有集合。
任意玩家当前持有某 ID 时，该 ID 的全部 encounter 实例都被排除；其他实例保持原顺序、保留重复。
候选少于 3 个时在末尾补 ID 25（Milk）至 3 个，Milk 不写回 encounter，且不受当前持有状态影响。
候选不少于 3 个时不补 Milk；不随机、不去重、不截断、不分页。

## 特殊房与三次选择

复用项目现有 `ROOM_DEBUG_IDX (-3)` 载体，但由共享 owner stack 保证同一时刻只有栈顶系统能在载体
中生成或处理实体。再契象可从普通房或未生证明展厅启动；启动时保存 Stage、StageType、Dimension、
SafeGridIndex、玩家位置和主动栏位。若外层是未生证明，先仅清理其 session token 所属实体并暂停；
再契象结束后重建外层原页面和已领取状态。

选择房底座均带 House session token 与候选实例号。碰撞前建立快照，后续帧以底座消失或玩家持有数
增加确认一次选择；正常回调始终返回 nil，不取消拾取。全队共享 `selectedCount`，第三次有效选择后只清理
本 session 的剩余底座及因主动道具交换掉落的再契象，返回原房间并从发起者记录的主动栏移除再契象。
任何单个玩家都不能获得独立的三次额度。

## 中断与安全

- session token 隔离所有临时实体；无会话时绝不清空整个 -3 房间。
- 传送离开、楼层变化、死亡或读档恢复导致载体/原房不一致时，中止会话、清理本 session 并安全返回。
- encounter 与 session 使用现有 `musicboxSaveData`/`SaveMusicboxData()`，不引入第三方依赖。
- 候选数量没有上限；遵照当前需求全部生成。布局按房间边界动态缩放，因此极端大量候选仍可能视觉拥挤，
  但不会静默丢弃、随机抽样或自行分页。

## 验证边界

静态/模拟测试覆盖：实例去重、重复 ID、全队持有过滤、0/1/2 候选的 Milk 补足、三次共享选择、
返回与清理、继续游戏保留 encounter 但中止 session、与未生证明 owner stack 的暂停/恢复。
门/黑屏、主动栏交换、多人同时碰撞和真实房间回退仍需实机验证。
