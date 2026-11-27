# 临时复制、零分考卷、回声宝宝与背包选择器

这组实现由 [2026-10-02 批准合同](../../../reports/batch-completion/2026-10-02-proposed-contracts.md)补全原待开发记录的生命周期和交互规则。原设计文件保留历史；当前实现、限制和实际检查见[交付记录](../../../reports/batch-completion/2026-10-02-delivery.md)。ds4 已按用户后续指示排除。游戏验收独立于自动回归。

## 加载与归属

| 文件 | 责任 |
| --- | --- |
| [main.lua](../../../main.lua) | 名称、运行 ID、双语 EID、拾取横幅，`PENDING_CONTENT_COMPLETION_BEGIN` 加载点 |
| [pending_content_integration.lua](../../../pending_content_integration.lua) | 连接共享实例、各自存档分区与道具；名字/背包条目/提示实现已归属各自私有模块，详见[接口](../../api/shared-state.md) |
| [acquisition_state.lua](../../../scripts/systems/acquisition_state.lua) | 已完成实物拾取、物理实例迁移与沙漏槽接入；旧 pending_content_state.lua 仅转发，身份和快照参与者分别由明确模块拥有 |
| [divine_left_hand.lua](../../../divine_left_hand.lua) | 最后正常历史记录锁定、临时授予与历史索引精确移除、无法唯一证明时诊断 |
| [low_grade.lua](../../../low_grade.lua) | 滚动三层受伤窗口、最终头目奖励、每份耐久、普通/金色/吞下份数 |
| [echo_baby.lua](../../../echo_baby.lua) | 新宝宝来源组复制、永久本局奖励、普通跟班射击和归属、缓存顺序 |
| [inventory_selector.lua](../../../inventory_selector.lua) | 所属玩家的瞬时选择、输入释放保护、取消和调用者条件重查 |

保存字段位于现有共享根的 `pendingContent`、`pendingContentHourglass`、`divineLeftHand`、`lowGrade`、`echoBaby`。不要把角色规范化身份直接用于物理道具历史：里拉撒路的奖励/进度共享，但两种形态的原生背包需区分。

## 背包调用接口

`Neverbirth.InventorySelector.Open(player, request)` 返回是否成功打开。`request.execute(player, entry)` 是必填函数，返回严格的 `true` 才算执行成功。可选 `valid(player)`、`eligible(player, entry)` 均在确认时重查；`onCancel(reason)` 接收取消原因，`title` 指定操作文字。调用者在 `execute` 中负责效果、费用和精确份数选择。

条目包含 `id`、`count`、`temporaryCount`、`name`、`gfx`、`type`、`order`。选择器提供 `Close(player, reason)`、`GetSession(player)` 和包含关闭后按键释放保护的 `IsBlocking(player)`；不跨退出游戏持久化。调试控制台命令 `inventory_selector 0` 打开玩家 0 的菜单，确认只写所选 ID/份数日志。

凸眼鱼通过可选 `request.getEntries(player)` 提供按实物 UID 区分的储物列表，`confirmAction` 指定主动确认键，`controls` 指定操作提示。条目可附 `payload`、`spritePath`、`animation`、`frame`、`layer`，直接显示所存原生对象。旧调用沿用已持有道具列表和菜单确认键；储物存档及投掷仍由凸眼鱼模块负责，见[交付记录](../../../reports/blinky/2026-10-03/delivery.md)。

## 资源与检查入口

收藏品本地 ID 61/62、饰品 ID 2、跟班实体 `3.3000` 由当前 XML 声明；运行 ID 必须按加载后的名称查找。图标在 `resources/gfx/Items/`；跟班原生 ANM2 在 [003.3000_echo_baby.anm2](../../../resources/gfx/003.3000_echo_baby.anm2)，其贴图在 `gfx/Familiars/EchoBaby/`。My Stuff 只追加本地格 61/62，规则沿用[本地 ID 迁移表](../../mystuff_item_id_migration.md)。

五个 Lua 专项为 `pending_content_state_test.lua`、`divine_left_hand_behavior_test.lua`、`inventory_selector_behavior_test.lua`、`low_grade_behavior_test.lua`、`echo_baby_behavior_test.lua`，通过 [LuaAll](../testing.md)发现运行。额外资源检查为 [pending_content_resources_test.py](../../../tests/pending_content_resources_test.py)；My Stuff 反例为 [mystuff_resource_contract_test.ps1](../../../tests/mystuff_resource_contract_test.ps1)。原生输入、绘制、来源、历史索引、吞下移除和沙漏时序使用[实机测试卡](../../../reports/batch-completion/2026-10-02-ingame-test-card.md)验收。
