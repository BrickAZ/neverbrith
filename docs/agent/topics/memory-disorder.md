# 记忆紊乱：实现与验证地图

## 读取入口

- [memory_disorder.lua](../../../memory_disorder.lua)：行为、图标候选、拾取历史与模块自有回调。
- [main.lua](../../../main.lua)：搜索 `MEMORY_DISORDER_BEGIN`、`initializeMemoryDisorder`、`GetCollectibleConfigs`，核对道具 ID、共享存档和配置查询如何传入模块。
- [兼容指南](../../../COMPATIBILITY.zh-CN.md)：自定义角色候选接口；具体兼容约定在原指南维护。

`main.lua` 仍承载共享存档及其他道具。完整加载它的测试可能调用记忆紊乱的更新、换房和开局回调，即使测试目标是另一个道具。遇到此类报错先沿调用栈确定缺失依赖，不立即归因于当前测试名称对应的玩法。

## 配置与图标边界

当前接入函数通过 `Isaac.GetItemConfig():GetCollectibles()` 提供配置列表。测试若执行完整加载链，需要显式提供所需接口；已有 `GetCollectible(id)` 不代表列表查询也已实现。

模块的 `buildIconCandidates` 对带 `Size` 的列表逐个使用 `GetCollectible(id)` 取配置，并保留隔离测试的 Lua 表路径。原生对象边界回归由专门图标测试维护，不能用普通 Lua 表通过来代替该证据。修改时同时查看当前代码和该测试，避免把这里当成完整 API 文档。

图标伪装与道具效果是两个表面；排错时保留当前机制。存档中的拾取排除历史、房间底座伪装和持有图标路径要分别检查，继续游戏与新局重置也应分别验收。

## 对应测试

| 测试 | 用途 |
| --- | --- |
| [memory_disorder_behavior_test.lua](../../../tests/memory_disorder_behavior_test.lua) | 主要行为与状态场景 |
| [memory_disorder_icons_test.lua](../../../tests/memory_disorder_icons_test.lua) | 图标候选、原生对象边界模拟、渲染调用与回退 |
| [memory_disorder_health_regression_test.lua](../../../tests/memory_disorder_health_regression_test.lua) | 生命值回归 |
| [memory_disorder_pairs_regression_test.lua](../../../tests/memory_disorder_pairs_regression_test.lua) | 配对角色回归 |
| [localization_test.lua](../../../tests/localization_test.lua) | 本地化与描述相关断言 |

完整入口夹具的关联例子：[生死之间](../../../tests/between_death_and_life_behavior_test.lua)、[骰子套装](../../../tests/dice_set_behavior_test.lua)、[碎塔罗](../../../tests/shredded_tarot_behavior_test.lua)、[绝育证明](../../../tests/sterilization_certificate_behavior_test.lua)。这些测试维护自己的场景；不要在[共享 REPENTOGON 夹具](../../../tests/repentogon_test_fixture.lua)中无限补空接口来掩盖缺失依赖。

优先运行目标 Lua 文件；需要联动回归时使用[检查入口的 Pilot 范围](../testing.md)。这里不记录测试是否已通过，执行结果保存在带日期报告中。

## 实机验收边界

涉及此模块玩法或图标修改时，按受影响范围检查新局、继续游戏、换房和控制台／日志；分别检查底座、举起道具、EID 以及相关遮蔽状态。联机持有者和重掷路径在涉及它们时另验。右侧历史、暂停页、死亡页属于独立原生表面，不能用底座或 Lua 渲染测试代替。

仅补测试夹具不会新增这些表面的实机证据，也不改变它们现有的验收状态。
