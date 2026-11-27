# 共享身份、获取、快照和显式装配

## 身份

[player_identity.lua](../../scripts/runtime/player_identity.lua) 返回无状态函数表，不访问存档、不注册回调。`PlayerKey(player)` 与 `InventoryPlayerKey(player)` 均为点调用，输出旧版字符串原样保留。逻辑身份仅对旧合同中的里拉撒路两身体归一，其余依旧用 InitSeed / ControllerIndex；背包身份附加 `:form:<InitSeed>`。PlayerKey(nil) 返回 `missing`，InventoryPlayerKey 仍要求玩家非 nil。原获取服务公开同一组函数作为兼容别名。

这些键继承现有身份保证，不扩展跨进程/联机保证；不要替换为 entity_identity 的瞬态指针键，也不要强行替代记忆紊乱等道具不同的旧身份合同。main 创建一份接口，显式交给获取服务、斗气拳套和搓招战斗。

## 快照参与者

[snapshot_participants.lua](../../scripts/runtime/snapshot_participants.lua) 导出工厂 `create(clone)`，每次产生独立注册表，无回调/存档副作用。clone 由所有者传入，沿原普通数据树复制语义，不支持循环或运行时对象。

- `Register(name, capture, restore)`：点调用；重复 name 抛错；保存两个回调，不立即捕获。
- `Capture()`：依原 `pairs` 无序枚举，返回以 name 为键的数据副本；nil 不进入返回表，错误直接传播。
- `Restore(values)`：依原无序枚举，对每个参与者调用 `restore(clone(values[name]))`，包括缺失值 nil；错误传播，不在这里保存或重置共享数据。

获取服务拥有该实例。参与者注册寿命与安装实例一致，新局不清掉登记；原所有者仍处理新局运行数据。快照先复制共享数据，再捕获参与者；恢复先替换共享数据和清掉待结算运行表，再恢复参与者，最后 Save。并未增加排序或新的恢复阶段。

## 获取服务与旧入口

[acquisition_state.lua](../../scripts/systems/acquisition_state.lua) 导出 `create(mod, context)`，负责原获取/实物记录和原生沙漏槽回调。context 明确接收 `Identity`、只拥有 pendingContent / pendingContentHourglass 的 `GetSaveRoot`、`GetCurrentRunSeed`、`GetPlayers`、可选 `Save` 和 `DebugLog`。调用工厂立即登记原有回调，因此正式入口只创建一次，保存返回实例。旧 [pending_content_state.lua](../../pending_content_state.lua) 只转发工厂；不得再次调用旧工厂取得同一个已安装实例。

旧公开 `mod.PendingContentState` 与工厂返回值是同一对象，API 未改：PlayerKey/InventoryPlayerKey、FloorKey/RoomKey、PickupToken、SubscribeAcquisition、IsTemporary/WithTemporary、GetAcquisitions、GetPendingReceipt、RegisterParticipant、Snapshot/Restore。碰撞只暂存候选，真正获取/临时份数与实物身份仍按原回调结算。GetAcquisitions 返回普通数据副本；GetPendingReceipt 返回内部待结算记录，只观察、不保留到后续生命周期。PickupToken 可能创建身份并增加序号；不能当纯查询重复预览。

| 点调用 | 参数与返回 | 时机、副作用与错误 |
| --- | --- | --- |
| `FloorKey()` / `RoomKey()` | 无参，返回当前楼层/房间字符串 | 依赖活跃 Game/Level；沿原 stage、stage type、placement seed、ListIndex/SafeGridIndex 组合，不写存档、不耗 RNG |
| `PickupToken(pickup)` | 原生 pickup，返回已有或新建的实物 token 字符串 | 读写该实体 GetData 及本服务 pickups/serial；要求活跃房间和有效 pickup，不立即 Save |
| `SubscribeAcquisition(fn)` | fn 为 `(player, id, token, physical, temporary, receipt)`，无返回 | 按登记顺序追加，无去重/取消；真实交付后同步调用，单个订阅异常记录日志并继续其他订阅。receipt 为运行期内部引用，不能写盘或跨生命周期保留 |
| `IsTemporary(player)` | 玩家，返回当前逻辑身份的临时调用计数是否大于零 | 不访问存档；身份查询仍需有效玩家合同 |
| `WithTemporary(player, fn)` | 同步无参 fn；成功返回 fn 全部返回值，失败返回 false、错误 | 计数支持嵌套，成功/失败均在调用后减一；失败记日志。不能跨异步调用持有临时标志 |
| `GetAcquisitions(player)` | 玩家，返回本逻辑身份获得记录的复制数组 | 首次可能按旧 seed 规则初始化共享保存区域，不自行 Save；修改返回值不改账本 |
| `GetPendingReceipt(player)` | 玩家，返回当前身体 PRE_ADD 栈顶引用或 nil | 只读观察，POST_ADD 和清理事件后失效 |
| `RegisterParticipant(name,capture,restore)` | 委托本实例参与者注册表，无返回 | 重名及回调错误合同见上节 |
| `Snapshot()` / `Restore(snapshot)` | 完整快照或成功布尔值，见下文 | 捕获/恢复会调用实际参与者；不把它们当作纯显示查询 |

Snapshot 返回 `{shared, participants}` 普通数据副本。Restore 仅接受原 seed 匹配条件，失败返回 false；成功重置运行期候选/队列、恢复所有参与者、保存并返回 true。换房、退出、新局、沙漏槽的既有处理位置与保存次数保持；同种子新局仍清掉两区。新增接口说明不扩大原错误容错或原生时序保证。

## 道具与界面装配

[pending_content_integration.lua](../../pending_content_integration.lua) 现在接收已安装 `State` 与三件道具各自的 `SaveScopes`，返回 `{State, Selector, DivineLeftHand}`。旧调用方未传 State 时仍按原工厂创建；正式入口始终显式传入，旧路径不是第二个实例。子 context 只传必要服务与自身分区，不再复制整份装配 context。

临时提示状态/绘制/清理归属 [notices.lua](../../scripts/features/divine_left_hand/notices.lua)，背包条目归属 [entries.lua](../../scripts/features/inventory_selector/entries.lua)，文字与字体操作归属 [text.lua](../../scripts/features/inventory_selector/text.lua)。这些是具体功能内部模块，未推广为通用 UI 框架。[low_grade_eid.lua](../../scripts/integrations/low_grade_eid.lua) 是可选集成工厂 `(mod, lowGradeId)`：安装原 POST_UPDATE 回调，EID 就绪且 ID 合法时按原顺序登记两种语言并标记一次完成，异常仍传播；随所属 Mod 安装生命周期结束，不另加注销政策。

凸眼鱼显式接收 `State` / `GetSelector`（提供者在本件构造时解析，缺失即报错；也接受直接 `Selector`）；斗气拳套接收 `Key` / `IsInventoryBlocking` 查询；motion_combat 接收 `Input` / `Presentation`，motion_items 接收 `Input` / `Presentation` / `Combat`。公开 Mod 字段仍发布供外部兼容，但正式内部连接使用当前安装保存的实例，不跟随外部重新赋值跳到另一实例。选择器提供者无计时等待、不重新初始化实例；适用于仅安装实际消费者的测试或装配。旧独立工厂未传新依赖时保留原 Mod 字段回退；后续若撤销旧工厂合同，才可移除此适配。

检查：[原获取/沙漏行为](../../tests/pending_content_state_test.lua)、[参与者隔离](../../tests/snapshot_participants_test.lua)、[真实装配、分区权限与失败回滚](../../tests/framework_shared_wiring_test.lua)，并沿用凸眼鱼、临时复制、零分考卷、回声宝宝、拳套和搓招专项。以上离线证据不等于原生多人、跨进程 Continue 或人工体验通过。
