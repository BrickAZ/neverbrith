# 第八批重构交付：巴比伦好女孩、月色真美

日期按用户时区为 2026-11-26。用户批准本批重构后，在当前工作区上冻结基线；未使用 Git HEAD 覆盖前七批和其他已有修改。

## 最终结构

| 道具/能力 | 归属 | 保留的合同 |
| --- | --- | --- |
| 巴比伦好女孩 | `scripts/features/good_girl_of_babylon.lua` 组装同名目录下 `state`、`combat`、`rewards`、`presentation` | 玩家房间状态、满红心资格、破碎及回声、属性刷新、恐惧/魅惑、清房只结算一次、服装和跟随效果。20 个旧全局导出仍交给安装事务管理。 |
| 月色真美 | `scripts/features/the_moon_is_beautiful.lua` 组装同名目录下 `room`、`combat`、`rewards`、`presentation` | 每房静默窗口、射击清零、成功/失败、标记、首次命中波动、Boss 额外伤害、死亡奖励去重、独立 Sprite 动画及坐标。旧 `Neverbirth.Moon` 动态方法调用保留。 |
| 卡牌公共算法 | `scripts/systems/card_rewards.lua` | 仅复用获取配置/卡池、显示字段检查、去重排序、两组 GetCard 参数。无状态、无回调；两件道具各自调用，不产生共享玩法状态。 |

好女孩保留 16 次重试及种子偏移 37，月色真美保留 8 次及偏移 53。EID 方法不存在、抛错、无描述、名称回退等分支仍按原道具执行；空候选时好女孩回退 Fool，月色真美可返回 nil 并从奖励列表排除卡牌。奖励的随机调用顺序不变。Boss 指令等其他道具没有接入新公共辅助。

各入口统一负责登记；子模块只安装实现。好女孩的状态工厂独占其玩法字段变化，表现代码继续管理自己的效果引用；月色真美通过原公开命名空间连接组内实现，不产生互相 include 的循环。新局、继续、换房、换层、道具丢失均沿用已有语义，没有新增存档字段。

## 静态和模拟证据

- `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch8/2026-11-26/final-checks.json`：退出码 0；129 项通过，0 失败/阻塞，122 个 Lua 测试，288 个 Lua 文件语法检查。
- 通用验证器保留 6 条既有资源解析告警：三份 items XML 中的 `NeverbirthDeathItems.anm2` 和 `Collectibles_025_Breakfast.png`；严格验证器 0 告警。它们不属于本批修改范围。
- `lua reports/refactor-batch8/2026-11-26/compare-registration.lua`：退出码 0；legacy 475 条、complete 489 条登记的事件、优先级、过滤参数、处理器身份及相对顺序逐项一致。
- `lua reports/refactor-batch8/2026-11-26/run-frozen-test.lua <baseline|candidate-runtime> tests/batch8_lifecycle_test.lua`：两份冻结源码均退出 0。涵盖 149/150 帧回声、结算消耗、失败后不重试、继续/新局、多玩家静默、Render 不走玩法时钟、两个死亡回调去重、射击重置及窗口最后一帧。
- 同一冻结运行器执行 `tests/batch8_card_policy_test.lua`：旧版、新版均退出 0；配置/EID 异常和缺失、合法 mod 卡、排序去重、随机种子/调用顺序、16/8 次重试、空候选差异、动态公开方法替换通过。
- `lua reports/refactor-batch8/2026-11-26/card-helper-installation-test.lua`：退出码 0；在两个消费者中的任一处注入公共辅助加载失败，均撤销新增回调并恢复原命名空间和全局导出。
- 全量内的 `batch8_loading_test.lua` 验证八个组内模块只安装一次、六个登记阶段失败回滚；`thin_entry_installation_test.lua` 验证 87 个实际 feature 导入失败以及三个变异登记失败。原好女孩、月色真美和民俗生命周期测试继续通过。
- `node reports/refactor-batch8/2026-11-26/verify-extraction.mjs`：退出码 0；56 个旧函数正文逐字相同，12 个函数进行了明确的状态/公共辅助委托，4 个函数改为公共配置/卡池查询别名。结果见 `extraction-review.json`。

初次专项检查发现提取脚本遗漏负数常量 `-2`，以及独立导出测试缺少真实 include 适配；二者已修复，随后专项和完整回归通过。没有将失败隐藏或改写为未执行。

## 原生引擎证据

通过 `run-native-isolated.ps1` 分别启动冻结基线和候选，固定新局种子，仅使用游戏回调操作后台实例。每次运行先备份配置/存档和正式 main.lua，结束后关闭自己启动的 PID 并逐文件恢复。测试逻辑只由临时入口接入，正式 main.lua 不保留探针。

最终基线 `native-baseline-03` 与候选 `native-candidate-01` 各 5 场景、26 项通过，失败为 0。`node reports/refactor-batch8/2026-11-26/compare-native.mjs native-baseline-03 native-candidate-01` 退出 0，26 条检查及五组数值观测一致；见 `native-comparison.json`。场景包括：实际满红心属性、红心受伤与 150 帧回声、清房结算及真实奖励、60 帧静默和标记、真实敌人 HP 波动、二次命中不重复波动、死亡回调消费资格、正常相邻房间转移后的状态清理。

最终执行命令为 `pwsh -NoProfile -File reports/refactor-batch8/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-03 -Baseline -TimeLimitSeconds 35` 与相同命令的 `-Attempt native-candidate-01`（不加 `-Baseline`）；两个运行器退出码均为 0。日志在关闭时刷新，状态记为 `COMPLETED_LOG_FLUSHED_ON_EXIT`，游戏本身正常退出、退出码 0。每次覆盖 227 个原有配置/存档文件的恢复核验，恢复 6 个发生变化的文件，归档 3 个确认由本次测试新建的存档；无未决新增文件和恢复错误，main.lua 已恢复。诊断轮也完成相同的恢复核验。

前两次基线探针没有通过：第一次为 24 通过/2 失败，第二次为 25 通过/1 失败。第一个原因是同帧移除的拾取物仍在查询结果内，改为检查 Exists 并隔一帧统计；第二个原因是等待静默期间原生敌人 AI 移到了 194 距离，超出既有 80 波动半径，改为在命中前设置并记录 40 距离。只修正探针，生产实现没有为探针改玩法。第三次基线为 5 场景、26 项通过。

原生死亡抽奖这次取样为未中奖，因此“实际中奖后两个死亡回调只生成一次”仍由模拟回归覆盖；原生实测覆盖资格消费和不重复发奖上限。Boss 泪弹分支由已有行为测试及正文相同性覆盖，本批原生场景没有单独进入 Boss 房。人工画面审美、键盘手感、完整一局和所有 mod 组合不在自动检查结论内。

## 范围与回退

基线包含 1079 个文件，候选包含 1091 个文件。`node reports/refactor-batch8/2026-11-26/verify-scope.mjs` 退出 0：快照范围内修改 6 个文件、新增 12 个文件、无删除，当前安装源码与候选哈希一致；最终结果见 `scope-parity.json`。全部 704 个 `content`、`resources`、`generated` 文件及主入口与基线逐字节相同。实施计划和带日期的报告另存于快照范围之外。

`git -c core.safecrlf=false diff --check` 退出 0；此项只检查 Git 已跟踪差异，无跟踪的新模块通过候选清单、语法/行为检查及正文提取审计验证。最终计划更新后另运行 `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1`，退出 0。

回退只恢复清单内已修改的文件并移除本批新模块/测试，使用 `baseline/` 中保存的当时工作区字节。不要执行整库 reset。本次未提交、推送或发布。
