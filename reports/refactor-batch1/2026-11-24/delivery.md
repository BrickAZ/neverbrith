# 第一批十件道具重构交付

日期：2026-11-24（Europe/Warsaw）。本地源码重构；无提交、推送或发布。

## 范围与结构

- 风油精、芜湖：各自一个完整功能模块，保留原属性回调和覆盖顺序。
- 七件狗粮：高蛋白肉条、活力狗饼干、轻盈低脂罐头、DHA 鱼油、护齿磨牙骨、幸运肝粒、羊奶布丁，整体迁入 `scripts/features/dog_food_series.lua`。
- 八音盒及其 C 计划联动：迁入 `scripts/features/musicbox/`；普通数据规则、引擎接入与音乐/精灵/倒计时绘制分开。
- `scripts/runtime/persistence.lua` 保有唯一懒加载存档实例。旧主文件通过原函数委托，新功能只取得自己的区域接口；区域替换后下一次读取取得新表。
- `scripts/runtime/legacy_save_schema.lua` 保留旧格式的初始化，底层读写服务不识别具体道具。
- 原致命伤害查询还被黑太岁、肉块使用，因此提入 `scripts/systems/incoming_damage.lua`，由入口显式接入。
- 公共完整入口夹具从本地化测试分离；原消费者直接使用公共夹具。语法检查新增递归覆盖 `scripts/` 和 `tests/support/`。

`main.lua` 从 20882 行减至 19490 行，减少 1392 行；本批新增 9 份运行模块，完整接回实际入口。

没有改变 XML、ID、品质、道具池、图像/音频资源、玩家键、保存频率或沙漏政策。704 份 content/resources/generated 文件与基线逐一哈希相同，见 `content-unchanged.json`。

## 环境与恢复点

- 开始时工作区干净，基线提交 `315e1635cf0068f510b9dce2bead85bc11b65f34`。
- 开发/离线检查目录与游戏实际模组目录都是 `E:\Isaac - Repentance\mods\neverbrith`，不是链接目录。
- 游戏的 `savedatapath.txt` 确认 Modding Data Path 为 `E:\Isaac - Repentance/mods/`。
- 实际游戏：Repentance `v1.7.9b.J835`；原生探针输出 REPENTOGON `1.0.12a-yin-api1-dev`。未升级或修改运行时。
- 游戏 exe SHA256：`530B4D2ACCEF833B8DBF6F1A9F781FE1E051C1916CA5ACDB579DF05A34640627`。
- zhlREPENTOGON.dll SHA256：`A053418AD4851C91203F2E6A7F09E6D1A96FBC8A3294AE31D615FA40EA990B5F`。
- Lua 运行器：`C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe`，5.4.6。
- `baseline/` 保留 878 份实际运行源码、登记、资源及测试，共 170525042 字节；全部与 `baseline-manifest.json` 比对。恢复副本的完整八音盒入口测试退出码 0。
- `candidate-runtime/` 保留最终候选的 893 份运行、资源和测试文件，与当前工作区逐一哈希相同，清单为 `candidate-manifest.json`。在该独立目录直接运行八音盒、狗粮、模块加载和基本属性四份测试，退出码均为 0，见 `candidate-smoke.txt`；候选入口没有临时原生探针。
- 原生测试沿用现有备份/恢复帮助程序，每次快照 227 份设置/存档，在独立新局运行自有隐藏进程，结束后恢复并比对哈希；新增测试数据移入对应测试记录。没有键鼠接管。

## 保留的状态合同

| 内容 | 所有者与保存 | 推进与清理 |
| --- | --- | --- |
| 风油精、芜湖属性 | 当前持有数量，无自有持久状态 | 原缓存回调顺序；每次从引擎提供的属性基础上计算 |
| 狗粮已结算数量 | 旧 `dogFoodSeries`、runSeed 与 InitSeed 玩家键 | 真正增量取得后发放一次；移除后降低基准；继续不重复奖励 |
| 狗粮待拾取队列 | 模块运行时 | 原碰撞确认后两帧结算，15 帧库存核对；换房/换层清队列 |
| 磨牙骨击退 | 泪弹标记、敌人按玩家键的冷却 | 原 8 帧冷却、1.25 每份推力及 4.5 速度上限 |
| 八音盒死亡债务 | 旧 `musicboxDeathDebt.debts`；runSeed/InitSeed | 原更新回调推进 600 逻辑帧；每次原有结算点保存；未加入共享沙漏快照 |
| C 计划等待死亡 | 八音盒运行时 | 原 90 逻辑帧，八音盒启动时取消；不新增持久化 |
| 八音盒表现 | 模块持有精灵、玩家引用、前一音乐 ID | 读取效果计时；原 150/60 帧警告边界；结束清理并恢复音乐 |

继续游戏、同种子新局、死亡后的重试、角色切换等沿用原实现；没有借重构改变它们的策略。某些原实现尚未被原生全面验收，不以本批重构宣称已完善。

## 自动检查

以下工作目录均为模组根目录；Lua 路径见上文。

| 实际命令/记录 | 退出码 | 结果 |
| --- | --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe' -ReportPath reports/refactor-batch1/2026-11-24/baseline-checks.json` | 0 | 91 项通过，84 Lua 测试；6 条原有通用资源警告 |
| 同命令，报告为 `final-checks.json` | 0 | 96 项通过，89 Lua 测试，148 Lua 语法文件；0 失败，0 阻塞；同样 6 条警告，严格验证器 0 警告 |
| `pwsh -NoProfile -File tests/check_neverbrith_runner_test.ps1 -LuaPath 'C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe'` | 0 | 11 场景；新增嵌套模块及公共夹具语法错误反例；见 `runner-green.txt` |
| `lua tests/batch1_loading_test.lua` | 0 | 真实入口加载、每实例一次、过滤参数/优先级、缺失模块及重复注册反例；覆盖磨牙骨碰撞注册 |
| `lua tests/dog_food_series_behavior_test.lua` | 0 | 保留原断言，增加实际注册回调的两帧结算、重复碰撞、未取得道具反例 |
| `lua tests/musicbox_idle_query_test.lua` | 0 | 空债务下属性/PRE/晚期伤害查询不访问原生种子；修复前为 4 次并失败 |
| `lua reports/refactor-batch1/2026-11-24/compare-registration.lua` | 0 | 公共夹具覆盖的 463 条真实入口登记在事件、顺序、公开所有者、过滤和优先级上与基线相同 |

新增持久化测试验证懒加载、同一根实例、旧字段及未知字段保留、区域替换和编码失败不写盘。新增简单属性测试验证叠加、组合、重复刷新和移除；规则核心测试验证计时和阶段边界。这些都包含在最终 LuaAll 中。

针对狗粮拾取延迟，在内存中将模块常量分别变为 0 和 15，新的实际回调测试分别在第 1 帧和第 2 帧断言失败；没有改动磁盘上的玩法常量。

## 原生对照

`run-native.ps1` 只作为本批报告中的测试启动器；正常入口没有加载它或探针。状态恢复结果保存在对应 `result.json`。最终执行命令如下，两条均退出 0：

```powershell
pwsh -NoProfile -File reports/refactor-batch1/2026-11-24/run-native.ps1 -Attempt baseline-native-final -Baseline -TimeLimitSeconds 75
pwsh -NoProfile -File reports/refactor-batch1/2026-11-24/run-native.ps1 -Attempt candidate-native-final -TimeLimitSeconds 75
```

- `baseline-native-01`：22 项通过，因测试脚本用了非当前 XML 名称 `Musicbox` 而中止；不是玩法失败。
- `baseline-native-02/03`：分别因沙漏后的复活道具状态和死亡动画完成时刻的测试假设失败；修正探针等待条件，没有修改玩法。
- `baseline-native-04`：原有固定场景 33/33，通过，游戏退出 0，主文件/存档/设置均恢复。
- `candidate-native-01`：相同 33/33，通过，游戏退出 0，主文件/存档/设置均恢复。
- `native-comparison.json`：五组实际属性观测逐字段一致（七狗粮、重复刷新、芜湖组合、组合刷新、移除芜湖）。
- `baseline-native-final` 与 `candidate-native-final`：均 41/41 通过、0 失败，游戏正常退出 0；主文件、存档和设置均恢复，没有遗留新文件或恢复错误。
- 最终场景补充真实底座拾取及只结算一次、主题音乐 ID 119、ContractIdle/FinalWindup/FinalBeat 实际播放状态及结束恢复音乐 ID 1。三个动画阶段均在真实引擎观察到；五组属性仍逐字段相同，见 `native-final-comparison.json`。

游戏日志在退出时才完整刷新，因此启动器的最终状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`；上述通过数来自正常关闭后读取的完整日志，并核对了恢复哈希。收尾确认自有游戏进程已退出，正式入口未残留探针代码。

原生验证不等同人工审美或听感验收。跨进程继续游戏、多人与特殊角色切换没有新增完整原生验收；相关既有离线继续/多人测试保留并通过。

## 独立审阅与兼容例外

按执行技能完成一次独立审阅。审阅发现的空债务额外种子查询已修复，并先看到计数测试失败、再通过；其余注册/拾取延迟证据缺口已补测试。

临时保留 `legacy_save_schema` 对八音盒/狗粮空字段的初始化，保证任意旧消费者先保存时仍有原来的首次序列化形状。删除条件是功能默认值能在第一次加载前集中登记，并通过首次保存形状和所有旧消费者对照；不为了移走两段默认值改变旧存档。

旧 `EnsureMusicboxDataLoaded`、`SaveMusicboxData` 和根表别名仍为未迁移消费者保留；后续迁完各自数据区域再逐项退出。主文件仍拥有其他道具，本批没有宣称全模组重构完成。

## 回退

本批不升级数据格式，代码回退无需转换存档。要撤回运行实现，先确认游戏已退出并保留本批之后的其他修改，然后用 `baseline/main.lua` 恢复首批之前的入口；旧入口不加载 `scripts/`，这些新文件可先保留。核对基线哈希并执行基线相关检查。不要使用全仓库 reset/clean。

测试文件、工具与文档的回退按本批差异逐项处理。原生测试用备份已由启动器恢复，不应再用历史测试副本覆盖后来产生的游玩进度。
