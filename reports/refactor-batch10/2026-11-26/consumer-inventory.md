# 第十批迁移与共同能力清单

本批只处理未生证明和再契象。此前 38 件的归属与保留差异继续见[第九批后消费者清单](../../refactor-shared/2026-11-26/consumer-inventory.md)；既有薄入口全量迁出清单见[原清单](../../../docs/superpowers/plans/2026-11-25-thin-entry-refactor.md)。已有独立入口不等于已完成本轮逐件重构。

| 道具 | 正式入口 | 私有模块与状态所有者 | 共同能力实际消费者 | 旧入口退出 / 兼容 | 状态 |
| --- | --- | --- | --- | --- | --- |
| 未生证明 / CertificateOfNeverbirth | scripts/features/certificate_of_neverbirth.lua | ledger：生成目录/会话与 live Store；gallery：本件底座/机关；flow：进入/分页/父子会话返回；pickups：领取释放锁；runtime：更新/开始/退出/卸载。入口持有该实例的 state/config/lifetime | archive_room：两维边界、维度、玩家位置、布局/邻接；archive_controls：动画、无碰撞、触碰距离/锁 | main.lua 原调用不动；CarrierAPI 与 TestAPI 原名保留，前者的业务由 flow 持有。旧运行状态视图因现有测试保留；没有第二份旧算法 | 已验收（本批模拟与原生范围）；人工/多人原生/跨进程 Continue 见交付 |
| 再契象 / HouseVsElephant | scripts/features/house_vs_elephant.lua | ledger：历史/候选/本局账本与拾取更新；gallery：选择房间/机关；flow：接管/返回/房间事件；pickups：三份预留与实际授予确认；runtime：更新/继续/退出/卸载 | 同上，各自 Room 实例绑定自己的玩家查询；Controls 无状态 | main.lua 原调用不动；CarrierAPI 和 TestAPI 保留；无新增私有状态挂载，不通过另一道具 TestAPI 生产调用 | 已验收（本批模拟与原生范围）；人工/多人原生/跨进程 Continue 见交付 |

## 同批共同能力

| 能力 | 归属 | 迁移的真实消费者 | 保留差异与理由 |
| --- | --- | --- | --- |
| 方法调用、维度、玩家位置、分页邻接、边界与布局 | scripts/systems/archive_room.lua | 两件 ledger/gallery/flow，入口分别创建一个只绑定依赖的 Room 实例 | 与 world_queries 的 Game 可调用表/false 合同不同；Certificate 过滤位置且诊断，House 不新增位置过滤；页内容和已领取过滤由各自 ledger 承担 |
| 机关动画、无碰撞设置、距离与触碰锁 | scripts/systems/archive_controls.lua | 两件 gallery | Certificate 保留 requested/played 标记及诊断；House 无这些字段。控件归属/缓存、Variant 0/失败缓存、Spawn/Remove 异常处理和计时不统一 |
| 会话、存档及领取结算 | 两件的私有模块 | 各自原 Store，事件时动态 CarrierAPI | Certificate 的嵌套栈与 House 的三份预留/继续中止合同不同；不以新共同状态机替代。旧字段、序列 token、Save 时点不变 |

未纳入本批的焚尽郁结、ACE、调试控制器、柴刀、千变万化及根目录旧模块继续保留其已有状态；另一个生命周期任务的修复不计为本批新增重构成果。详细共同接口、实际用法和检查入口见[API](../../../docs/api/archive-rooms.md)，完成证据与人工/跨进程边界见[交付记录](delivery.md)。
