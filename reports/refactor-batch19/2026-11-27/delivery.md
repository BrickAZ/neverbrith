# 第 19 批：获取、临时复制、回声与储物边界收尾

2026-11-27（Europe/Warsaw）。三件道具及零分考卷、选择器和获取服务的结构/共享能力核验完成，已落到当前工作区。原有独立入口和玩法所有权保留；只将四份同合同普通数据复制替换为真实复用的 plain_data.CopyTree。没有修改玩法、数值、池、品质、资源、身份键、存档字段、保存时机或回调次序。没有提交、推送或发布。

本批承接[上一轮共享边界](../../framework-finish/2026-11-27/delivery.md)，不把上一轮修改重复计算成本批产出。完整逐件所有权、生命周期、共享候选和保留差异见[消费者清单](consumer-inventory.md)；正式接口见[普通数据复制](../../../docs/api/plain-data.md)与[道具协作边界](../../../docs/api/batch19-content.md)。

## 改动与保留

- divine_left_hand.lua、echo_baby.lua、low_grade.lua、scripts/systems/acquisition_state.lua 改为取得公共 CopyTree；删除四份本地递归实现。
- 新公共模块纯加载、无状态，无 RNG/保存/游戏调用；保持 keys/叶值原样、table 值新建、pairs、元表不复制及错误传播行为。
- Blinky Core 的严格序列化叶值校验保持独立。各射速下界、角色/身体键、沙漏政策和保存包装保持原样。
- 新增公共合同和真实入口缺失/重复加载、每个注册失败点回滚检查。两份直接加载根模块的既有测试补真实 include 加载器，原断言全部保留。
- 已有根模块满足逐件所有权；选择器、条目、文字与提示已有明确边界，无需为目录风格再搬迁或拆成空壳。

## 实际检查

工作目录为模组根；Lua `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，Python `C:/msys64/ucrt64/bin/python.exe`。

| 命令 / 范围 | 实际退出码和结果 |
| --- | --- |
| `python reports/refactor-batch19/2026-11-27/run-checks.py` | 0；19 条检查全部通过；完整命令、子退出码及日志见 [checks.json](checks.json) |
| `lua reports/refactor-batch19/2026-11-27/run-behavior.lua baseline tests/<name>_test.lua`，candidate 同样运行 | 两侧 7 组全部 0：临时复制、回声、零分、获取、凸眼鱼、选择器及调试控制器；所有原断言保留 |
| `lua tests/plain_data_test.lua` | 0；副本、重复引用、键/叶值、元表、pairs 和异常合同，及 Blinky 校验差异通过 |
| `lua tests/batch19_loading_test.lua` | 0；11 个实际依赖路径、四个真实 CopyTree 消费者、66 个回调注册失败点均正确回滚，随后新实例可重新安装 |
| `lua reports/refactor-batch19/2026-11-27/compare-registration.lua` | 0；Echo、Low Grade 与 Debug 实际启用，完整入口旧新 543 条事件/优先级/过滤/相对顺序一致 |
| `python reports/refactor-batch19/2026-11-27/verify-scope.py` | 0；四处生产改动严格只有 helper 替换；Blinky/Core、选择器、装配及调试控制器五份源码未改；7 组旧新测试观测文本相同。[结果](source-and-behavior-parity.json) |

候选行为运行器包装实际公共模块，四个消费者的原用例确实执行 CopyTree，不以文件存在判断复用。逐组调用计数在 candidate-* 日志末尾。完整入口测试初版只观察到 3 次复制模块加载，原因是通用夹具未登记 Echo Familiar；补齐测试专属原生事件/变种后明确要求全部四个消费者安装。第 22 批初版同样漏计未提供 MC_POST_FIRE_TEAR 的夹具绑定；已补齐夹具事件。未为通过测试改动生产门禁或删去断言。

## 验收边界与回退

本批未启动游戏、未挂载原生探针、未写游戏存档。离线旧新通过不能视为原生历史实物移除、跟班 AI、储物原生恢复、多人、跨进程 Continue 或人工画面/输入体验通过；统一原生调度及最终包级检查由框架收尾主任务负责。

回退仅恢复本批四个消费者到 reports/framework-closure/2026-11-27/baseline 对应文件，撤回相应 CopyTree 引用和新模块；两份测试 loader 与新增专项/文档按本批清单处理。不恢复整个 main、目录或工作区；未改变写盘格式，不需要存档迁移。
