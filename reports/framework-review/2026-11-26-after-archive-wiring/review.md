# 已重构部分：整体框架复核

日期：2026-11-26。本次只审查已完成第一至第十二批的范围：第一至第九批38件，加未生证明、再契象、焚尽郁结、千变万化，共42件。依据当前源码、公共 API、各批消费者清单及目标架构的职责/依赖/状态要求。仅迁出入口、仍未完成本轮职责验收的调试控制器、柴刀、ACE及根目录旧模块不计入本轮缺陷清单。复核期间第十三批及后续批次陆续出现过程目录和代码，但收尾查询没有 delivery.md；这些进行中的迁移不据此计为完成。

本轮为结构扫描、重点源码核对和专项回归，不是逐件所有玩法及所有原生组合的穷尽审计。没有修改生产代码。

## 结论与整体结构

主体分层已经符合既定方向：main.lua 装配，catalog 管登记，features 管具体道具，systems 管实际共享机制，runtime 管运行基础，integrations 管外部接入。此次确认一处已重构道具之间仍未显式注入的依赖，复现一处有条件的玩家对象重绑风险；另有总进度文档仍需统一维护。

初始快照 main.lua 743行；scripts/catalog 5个Lua、runtime 13、systems 19、features 121、integrations 1。其他任务在复核期间接入了后续迁移和诊断入口，收尾抓取为 main.lua 749行，catalog 5、runtime 13、systems 21、features 215、integrations 1。数量只描述对应抓取时点，features 包含私有模块和进行中的条目，不等于已完成道具数，也不作为完成验收的证据。

```text
main.lua：前置检查、创建共享实例、依赖连接、原顺序安装
├─ catalog：道具ID、配置查询、拾取文本、EID描述
├─ runtime：安装事务、统一存档、旧格式适配、玩家/世界查询、新局清理工具
├─ features：简单道具单文件，复杂道具唯一入口+私有模块
│  ├─ 未生证明/再契象：ledger/gallery/flow/pickups/runtime
│  ├─ 焚尽郁结：queries/attributes/ledger/presentation/combat/runtime
│  ├─ 千变万化：registry/state/selection/resources/player_anm2/presentation/runtime
│  └─ 其他已完成道具：维持各自规则、状态和原生回调归属
├─ systems：射速、RNG、伤害来源、服装、主动槽、奖励、房间机关等
└─ integrations：EID发布
```

main 包含刚完成的明确两件配对装配；增加连接代码不等于玩法重新集中。原生事件仍由引擎调用本件处理器，安装事务不是运行时事件总线。两个 CarrierAPI 的五处公共字段查找已经退出实际消费者，原公开名字保留为同一实例别名。整体框架图描述正式装配职责；收尾新增的原生诊断脚本位于安装事务之后，另见下文验收阻断记录，不将其混入已完成道具的职责判断。

## F1：鸿运齐天蛊仍隐式读取虚空针尖配置（结构欠账）

位置：[audit.lua](../../../scripts/features/fortune_rivalling_heaven_gu/audit.lua:105)、[needletick.lua](../../../scripts/features/needletick.lua:22)、[registry.lua](../../../scripts/features/fortune_rivalling_heaven_gu/registry.lua:139)。

虚空针尖把阈值挂在 `Neverbirth.NeedletickLuckCap`，鸿运 audit 从这里读取并以10兜底，再经 registry 注册为实际幸运阈值。main 并没有给鸿运传入这项依赖。它不只是展示文字，因此仍存在道具间隐藏配置依赖，未完全满足目标架构3.2的显式连接要求。

诊断直接执行现有 audit：公共字段23会被读取为23，缺字段则得到10。当前正式阈值为10且加载顺序正确，本轮没有据此确认正常游戏数值出错；问题在依赖没有写入模块合同，缺依赖仍被默认值掩盖。可按实际语义显式传入阈值/查询或通过现有登记接口连接，不需要额外通用框架。

这是已完成的两件道具之间的范围内问题；本轮没有要求迁移未完成的根模块。

## R1：强力泻药的服装去重不校验玩家对象（有条件风险）

位置：[presentation.lua](../../../scripts/features/strong_laxative/presentation.lua:25)、[players.lua](../../../scripts/features/strong_laxative/players.lua:83)、[null_costumes.lua](../../../scripts/systems/null_costumes.lua:36)。

ApplyCostume 按玩家键和 active/none 去重，虽然更新 costumeOwners，却没有在同键实体改变时使视觉状态失效。实际 players.Update 调用路径中，用仍持有道具的新对象替换同键旧对象，旧对象 AddNullCostume 1次，新对象0次；触发 GAME_STARTED 清理后，新对象变为1次。

这证明同局无清理的对象替换边界会漏重建外观，不证明已经存在某个原生复活、变身或多人场景能稳定触发。新局清理是有效的，不将此风险描述成同种子新局缺陷复发。需要核实原生触发条件及既有玩家身份合同，再决定是否在本件表现层加入对象/代际失效；不能不加区分地改变所有服装消费者语义。

诊断见 [probe-boundaries.lua](probe-boundaries.lua) / [输出](probe-boundaries.txt)。退出0表示成功观察到条件行为，不表示问题已修复或原生验收通过。

## D1：总进度表仍依赖多个历史清单拼接（文档维护）

[薄入口计划](../../../docs/superpowers/plans/2026-11-25-thin-entry-refactor.md)明确保留历史状态，例如黑太岁、泻药、椰子仍列“已迁移待验收”；实际完成信息还要结合前九批共享清单、后续批次交付和生命周期报告。

历史报告不必回写，但目标架构12.1要求维护同一份逐道具当前状态表。建议单独维护唯一现状表，链接各批历史证据，区分“迁出main”“职责重构完成”“自动验收”“对应实机范围”；这是导航和验收状态管理欠账，不是运行代码缺陷。

## 已确认保持的边界

- 未生证明与再契象现在由 main 显式连接；初次7场景依赖回归通过。收尾重跑时前6场景通过，第7场景读取真实main后被新增的诊断脚本中断；两件道具源码未变。
- 单实例 persistence 仍拥有 JSON 读写及失败保护，本道具使用分区；本轮未发现新的道具直接绕过服务调用原生 SaveData/LoadData。
- 公共机制已有实际消费者及详细文档；未发现需要仅为缩短代码再建立一层总框架的理由。对保留独立的射速单位、RNG回退、存档恢复等差异维持既有合同。
- 千变万化的七个私有模块、接口传递和回调归属与第十二批记录一致；新局/Continue/退出/卸载仍由本件 runtime 持有。
- 具名callback、公开兼容接口、TestAPI被保留不自动等于隐藏生产依赖。涉及根旧模块的 AvadaKedavra 等桥接不扩展为本轮迁移任务。

## 本轮验证与范围

命令模式：

```powershell
& 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' tests/<专项名>.lua
& 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' reports/framework-review/2026-11-26-after-archive-wiring/probe-boundaries.lua
```

初次运行12个专项全部退出0，见 [targeted-results.json](targeted-results.json)：依赖配对、私有边界、安装事务、存档、共享能力、服装消费者、四组生命周期，以及第十二批加载和边界检查。诊断探针另行记录，不能混作正常行为验收。

发现并行集成变化后，用同样的命令再次执行这12项，最终7项退出0、5项退出1，见 [targeted-results-final.json](targeted-results-final.json) 和各 `*-final.txt`。五项为 archive_dependency_wiring、refactor_private_boundaries、refactor_lifecycle_runtime、refactor_lifecycle_transient、batch12_loading。共同中断位置为最新main末尾加载的 `diagnostics/drive_glove_mechanic_audit.lua:17`：测试环境没有全局 `TrinketType`，模块初始化时报错。archive配对测试前六个独立场景仍通过；第七个加载真实main时才被中断。

这是当前整合入口的自动验收阻断，不能据此判定五组道具玩法均出错，也不能继续声称当前全入口测试全绿。本轮不修改正在进行的诊断/迁移任务，更没有通过屏蔽诊断来制造通过记录。

初始源码与上一轮206个生产Lua一致；随后并行变化的中间快照记录在 [source-parity.json](source-parity.json)，因此上一轮完整结果不代表最新入口。进一步限定到此前已完成道具模块及既有 catalog/runtime/systems/integrations，共156个文件哈希仍全部一致，见 [scoped-parity.json](scoped-parity.json)；不含main、新增未完成文件及ACE/柴刀/调试控制器。

上一轮完整LuaAll为153项通过、0失败/阻塞、6条通用资源警告，严格0警告，见[原结果](../../refactor-fixes/2026-11-26-archive-dependencies/lua-all.json)，仅作为此前快照证据。本轮没有重复完整LuaAll，没有启动原生游戏；真实多人、热卸载、沙漏及全部角色外观组合不能由这些自动结果推定通过。
