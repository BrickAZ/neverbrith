# 第十七批交付：复活吧，我的爱人！、健康睡眠

本批已完成本地结构迁移与脚本验证。玩法、数值、存档格式、资源和原生 callback 顺序保持原样；原生验收尚未闭合，不代表整轮重构或人工实机验收完成。

## 范围

- 复活：`scripts/features/revive_my_love.lua` 组装 state、presentation、runtime。
- 睡眠：`scripts/features/healthy_sleep.lua` 组装 state、presentation、input、runtime、lifecycle。
- 根目录两个旧路径仍是可调用工厂，主入口显式传入动态阿瓦达失败查询。旧 context 通过代理读取，已有 Save/GetSaveRoot 等依赖不会被复制冻结。
- 原回调 11 + 15 个，全部保持原相对顺序、过滤条件和返回语义。原 TestAPI 保留，生产代码不从 TestAPI 取依赖。
- 本批未修改 XML、道具池、品质、图像、动画、音频、阿瓦达或七咒的玩法源码。工作区其他任务的修改全部保留，无提交、推送或发布。

## 已取得证据

- 原复活行为 14 项与完整睡眠行为检查通过。
- [源码对照](source-equivalence.json)：89 个函数及紧邻绑定的函数体在恢复显式 runtime 字段名、阿瓦达依赖参数名后逐字一致。
- [旧轨迹](baseline-behavior.txt)与[新轨迹](candidate-behavior.txt)：16 场景的保存调用和内容、消耗、控制、生命、睡眠奖励、颜色和 HUD 观测完全一致。
- 冻结基线加本批源码的独立候选通过完整入口检查：8 个私有模块各加载一次、26 个回调顺序及过滤条件、26 个安装失败注入点全部回滚，再次启动可成功。
- 边界检查覆盖动态阿瓦达否决/替换、另一玩家不受影响、玩家对象移除、真实七咒模块与真实睡眠模块共同注册后的禁床、非七咒队友上床、妈妈床例外、换房/死亡/游戏结束/卸载恢复。
- 冻结集成快照的全部 156 个 `tests/*_test.lua` 最终通过：[合并结果](lua-snapshot-final.json)。第一次为 154/2，两个失败是快照漏复制既有文档和诊断脚本；补齐后只重跑这两项，均退出 0，未改生产代码或断言。[首次结果](lua-snapshot.json)、[复查](lua-snapshot-recheck.json)均保留。这不是完整 LuaAll：它不含 PowerShell/静态检查，也不包含随后其他任务新增的测试。

## 共享能力与状态

| 候选 | 消费者与结论 |
| --- | --- |
| 存档服务、运行种子 | 两件继续消费主入口的同一 persistence 和种子查询；没有第二份 LoadData/SaveData 权威。 |
| 玩家枚举、运行文本 | 睡眠继续复用 GetPlayers / RenderRuntimeText。复活的严格原生枚举没有容错回退，与公共枚举错误语义不同，保留。 |
| 玩家键与状态 | 两者均保留原 InitSeed 键，但 nil 守卫、种子字符串/原值比较和生命周期不同，不强并。复活序列/快照属于实例；睡眠记录属于旧持久区域，计时和覆盖层属于实例。 |
| 补血和控制恢复 | 复活设置一颗生存心、恢复生前控制/显示/碰撞；睡眠先补满红心再给三颗魂心，只暂停选中玩家 AI/输入。共同算法并不相同，保留道具政策。 |
| 计时 | 复活 30Hz POST_UPDATE 看门狗；睡眠 GetTime 实际时间、全局帧去重、暂停清 lastTime。无新增计时调度器。 |

## 验证限制与共享工作区

首次当前工作区 LuaAll 为 132 passed / 32 failed / 7 warnings，退出码 1。运行期间其他任务多次临时替换 main.lua 进行原生探针，失败包含对应探针在 Lua 夹具中无法加载；另有本批交付文件尚未建立造成的两项文档断链，现已建立本文件。保留原始 [JSON](luaall-live.json) 与 [日志](luaall-live.log)，不把这个结果写成全绿。

本批后续[专项检查记录](focused-checks.json)中的复活、睡眠、联动、独立快照安装、行为对照、源码对照及导航均退出 0。知识检查仍退出 1，实际原因是共享目录里其他批次新增的 `scripts/systems/attack_ownership.lua` 尚未在公共 API 索引登记；不属于本批新增模块，未改动其实现或接口文档。

随后最终导航复查又遇到另一项同期改动：`docs/agent/project-map.md` 已引用尚未生成的 `reports/refactor-batch13/2026-11-26/delivery.md`，该次退出 1。本批专题与交付链接已闭合；不改写其他任务正在生成的报告。因此共享工作区导航的最新结果也不能报告为通过。最终观察时主入口仍是第十八批原生基线临时入口；正常入口恢复由该探针任务负责，本批不覆盖它。

独立候选 `candidate-isolated/` 是开工冻结源码加本批文件和主入口依赖接线；`integration-snapshot/` 是检查时当前源码、资源和测试的复制，干净入口取自同期已有的 `reports/refactor-batch13/2026-11-26/native-baseline-01/main.before.lua`（含本批接线），不包含其临时探针。原工作区未因此被回退或覆盖。早先 `candidate-final/` 捕获了其他任务尚未装配完成的阿瓦达中间态，只保留为诊断材料，不作为通过证据。

本批原生旧新对照尚未运行：共享 main.lua 在本次检查期间先后被其他批次临时探针占用，未覆盖这些临时入口，也没有启动或终止任何游戏进程、修改游戏存档或配置。原生死亡复活时序、床碰撞和覆盖层、键盘/手柄手感、真实多人及跨进程 Continue 暂不作为本批验收通过项。

后续原生验收须覆盖：①正常死亡完整播放后复活、动画结束恢复控制；②阿瓦达空杀死亡不能由此道具救回，队友仍可正常复活；③七咒持有者不能在健康睡眠床进入睡眠，未受影响队友和妈妈床例外保持；④实际键盘/手柄加速、暂停不计时、睡满先补红心再加魂心；⑤睡眠和复活过程中退出/继续，无隐藏或控制锁残留。自动模拟的同种子新局、继续调用与多人对象并不替代上述实机证明。

## 实际命令与结果

Lua 运行器：`C:\Users\Anton\AppData\Local\Programs\Lua\bin\lua.exe`，版本 5.4.6。

| 命令（模组根目录） | 退出码 / 结果 |
| --- | --- |
| `lua tests/revive_my_love_behavior_test.lua` | 0，14 项 |
| `lua tests/healthy_sleep_behavior_test.lua` | 0 |
| `lua tests/batch17_boundaries_test.lua` | 0 |
| 设置 `BATCH17_TEST_ROOT=reports/refactor-batch17/2026-11-26/candidate-isolated/` 后 `lua tests/batch17_loading_test.lua` | 0，26 个顺序/过滤绑定及 26 个回滚点 |
| `lua reports/refactor-batch17/2026-11-26/compare-behavior.lua` | 0，16 场景旧新相同 |
| `node reports/refactor-batch17/2026-11-26/verify-source.mjs` | 0，89 个函数/绑定相同 |
| `pwsh -NoProfile -File reports/refactor-batch17/2026-11-26/run-lua-snapshot.ps1` | 初次 1，154/2；补齐快照后在快照 cwd 分别执行 `lua tests/localization_test.lua`、`lua tests/yin_explosion_diagnostics_test.lua` 均 0；最终 156/0 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch17/2026-11-26/luaall-live.json` | 1，132/32/7 warnings；共享入口受到临时探针影响，不能宣称全绿 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 专项记录 0；之后最新复查 1，其他批次新加的交付链接暂不存在，见上文 |
| `pwsh -NoProfile -File tests/project_knowledge_test.ps1` | 最终 1；其他批次共享模块文档缺口，见上文 |
| `git diff --check -- main.lua revive_my_love.lua healthy_sleep.lua tests/revive_my_love_behavior_test.lua tests/healthy_sleep_behavior_test.lua docs/agent/index.md` | 0 |

## 迁移清单和交付边界

| 道具 | 旧入口 | 本批归属 | 当前状态 |
| --- | --- | --- | --- |
| 复活吧，我的爱人！ | 根目录 `revive_my_love.lua` | 同名 feature 入口和三个私有模块 | 本地迁移/脚本验证完成；原生待验收 |
| 健康睡眠 | 根目录 `healthy_sleep.lua` | 同名 feature 入口和五个私有模块 | 本地迁移/脚本验证完成；原生待验收 |

阿瓦达、七咒仍由各自道具拥有，未在本批复制或改写其规则。其他已迁移与未迁移道具沿用各批记录，本批只改变上述两行；整轮清单、发布包与共享能力全局验收不因本批完成而关闭。撤回本批应使用冻结基线中的两件根模块并移除新增接线，不执行整仓回退；本批未改变存档格式，无新数据迁移要逆转。
