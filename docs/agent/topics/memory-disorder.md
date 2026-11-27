# 记忆紊乱：实现与验证地图

## 读取入口

- [memory_disorder.lua](../../../memory_disorder.lua)：保留旧工厂路径的薄兼容入口。
- [装配入口](../../../scripts/features/memory_disorder.lua)：创建十个私有实例，连接明确依赖，发布原接口并按原顺序安装回调。
- [main.lua](../../../main.lua)：搜索 `MEMORY_DISORDER_BEGIN`、`initializeMemoryDisorder`、`GetCollectibleConfigs`，核对道具 ID、共享存档和配置查询如何传入模块。
- [兼容指南](../../../COMPATIBILITY.zh-CN.md)：自定义角色候选接口；具体兼容约定在原指南维护。

`main.lua` 创建共享存档服务并组装各道具。完整加载它的测试可能调用记忆紊乱的更新、换房和开局回调，即使测试目标是另一个道具。遇到此类报错先沿调用栈确定缺失依赖，不立即归因于当前测试名称对应的玩法。

## 私有模块与兼容边界

| 模块 | 所有职责 |
| --- | --- |
| [player_access](../../../scripts/features/memory_disorder/player_access.lua) | 安全引擎访问、持久/运行时玩家键、原生主副体识别、确定性抽选 |
| [profiles](../../../scripts/features/memory_disorder/profiles.lua) | 原版候选、初始组件配置、解锁与自定义角色候选 |
| [health](../../../scripts/features/memory_disorder/health.lua) | 生命账本、健康类型投影、受伤差量、Lost 隐藏生命与骨魂血量 |
| [inventory](../../../scripts/features/memory_disorder/inventory.lua) | 临时初始组件、真实新增/移除识别、永久主动槽与口袋恢复 |
| [state](../../../scripts/features/memory_disorder/state.lua) | version 1 存档、玩家状态构造、纯数据持久化 |
| [pairs](../../../scripts/features/memory_disorder/pairs.lua) | 伙伴切换预检、暂存、持有权代理、重新枚举后移除与构筑归还 |
| [identity](../../../scripts/features/memory_disorder/identity.lua) | 切换顺序、失败补偿、持有/丢失处理及换房过渡计时 |
| [icons](../../../scripts/features/memory_disorder/icons.lua) | 图标配置、拾取历史排除、底座/举起/EID 伪装及相应回调 |
| [void_route](../../../scripts/features/memory_disorder/void_route.lua) | 本局虚空资格、终点判断、陷阱门与 NPC 死亡回调 |
| [lifecycle](../../../scripts/features/memory_disorder/lifecycle.lua) | 更新、换房、新局/继续及退出处理与相邻安装器 |

子模块返回工厂，导入本身不注册回调；同一道具实例的子模块只创建一次。装配入口在发布 `Neverbirth.MemoryDisorder` 后按旧顺序调用各自安装器，安装器不是幂等接口。正式启动继续由主入口已有安装事务负责失败回滚；独立直接调用工厂不额外承诺事务。

保留原工厂 `(Neverbirth, context)` 和返回表；`MemoryDisorderCharacterProfiles` 仍使用原数组。`Neverbirth.MemoryDisorder` 的历史辅助方法和 `Runtime` 保留原引用语义，查询中可能懒初始化、随机抽选、写存档或操作游戏；它们不因拆分而升级为公共通用库。正式跨 Mod 入口仍仅以兼容指南为准。

持久键仍为 `InitSeed:ControllerIndex`，运行时键优先原生指针加 InitSeed；不互换。`memoryDisorder` 存档字段、保存调用点、15/30 更新帧切换时序、新局重置与继续恢复沿用原实现。没有新增沙漏或跨进程恢复保证。第二十批的范围、复用核对及实际证据见[计划](../../superpowers/plans/2026-11-26-twentieth-batch-refactor.md)与[交付记录](../../../reports/refactor-batch20/2026-11-26/delivery.md)。

## 配置与图标边界

当前接入函数通过 `Isaac.GetItemConfig():GetCollectibles()` 提供配置列表。测试若执行完整加载链，需要显式提供所需接口；已有 `GetCollectible(id)` 不代表列表查询也已实现。

模块的 `buildIconCandidates` 对带 `Size` 的列表逐个使用 `GetCollectible(id)` 取配置，并保留隔离测试的 Lua 表路径。原生对象边界回归由专门图标测试维护，不能用普通 Lua 表通过来代替该证据。修改时同时查看当前代码和该测试，避免把这里当成完整 API 文档。

图标伪装与道具效果是两个表面；排错时保留当前机制。存档中的拾取排除历史、房间底座伪装和持有图标路径要分别检查，继续游戏与新局重置也应分别验收。

## 对应测试

| 测试 | 用途 |
| --- | --- |
| [memory_disorder_behavior_test.lua](../../../tests/memory_disorder_behavior_test.lua) | 主要行为与状态场景 |
| [memory_disorder_pockets_regression_test.lua](../../../tests/memory_disorder_pockets_regression_test.lua) | 原生同槽卡药互斥模型、双槽/空槽、重复切换和实际替换/消耗后的归还 |
| [memory_disorder_icons_test.lua](../../../tests/memory_disorder_icons_test.lua) | 图标候选、原生对象边界模拟、渲染调用与回退 |
| [memory_disorder_health_regression_test.lua](../../../tests/memory_disorder_health_regression_test.lua) | 生命值回归 |
| [memory_disorder_pairs_regression_test.lua](../../../tests/memory_disorder_pairs_regression_test.lua) | 配对角色回归 |
| [memory_disorder_loading_test.lua](../../../tests/memory_disorder_loading_test.lua) | 子模块加载、回调顺序/过滤、缺失模块与登记失败回滚、新实例隔离 |
| [localization_test.lua](../../../tests/localization_test.lua) | 本地化与描述相关断言 |

完整入口夹具的关联例子：[生死之间](../../../tests/between_death_and_life_behavior_test.lua)、[骰子套装](../../../tests/dice_set_behavior_test.lua)、[碎塔罗](../../../tests/shredded_tarot_behavior_test.lua)、[绝育证明](../../../tests/sterilization_certificate_behavior_test.lua)。这些测试维护自己的场景；不要在[共享 REPENTOGON 夹具](../../../tests/repentogon_test_fixture.lua)中无限补空接口来掩盖缺失依赖。

优先运行目标 Lua 文件；需要联动回归时使用[检查入口的 Pilot 范围](../testing.md)。这里不记录测试是否已通过，执行结果保存在带日期报告中。

## 实机验收边界

口袋恢复按同一个槽内的实际种类只调用一次 setter；`SetCard` 和 `SetPill` 的零值也会清空同一原生槽，不能在恢复卡牌后追加 `SetPill(0)`。本次根因、修复前后及双口袋原生证据见[生命周期缺陷修复](../../../reports/lifecycle-fixes/2026-11-27/delivery.md)。存档结构和真实替换/消耗的归属规则沿用原实现。

涉及此模块玩法或图标修改时，按受影响范围检查新局、继续游戏、换房和控制台／日志；分别检查底座、举起道具、EID 以及相关遮蔽状态。联机持有者和重掷路径在涉及它们时另验。右侧历史、暂停页、死亡页属于独立原生表面，不能用底座或 Lua 渲染测试代替。

仅补测试夹具不会新增这些表面的实机证据，也不改变它们现有的验收状态。
