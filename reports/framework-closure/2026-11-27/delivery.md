# 框架收尾：统一交付与验收边界

日期：2026-11-27（Europe/Warsaw）。用户授权三个子代理实施，主代理负责接线、交叉审查、完整回归、包验证及统一原生调度。对照开工时实际未提交工作区冻结的 [baseline-manifest.json](baseline-manifest.json)，没有把其他任务已有改动归入本轮，也没有提交、推送或发布。

## 本轮实现

| 工作 | 结果及真实消费者 | 证据 |
| --- | --- | --- |
| 共享控制状态 | 每次安装一个 CanShoot 所有者服务；神性过载、炸弹套装、斗气拳套持有独立句柄，支持乱序结束、失效身体、重复清理及有界异常/重入处理。原有输入、移动、抓取和复活表现合同保留各自所有者 | [控制交付](control-ownership/delivery.md)、[API](../../../docs/api/control-ownership.md) |
| 存档所有权 | 19 个旧区域的初始化声明移到各 feature/system，main 按原顺序组合；底座不再包含道具字段或反向加载玩法。沿用已落地的 Scope/Section，不改首次保存、未知字段、版本、键、Continue 或沙漏规则 | [存档交付](save-ownership/delivery.md)、[存档 API](../../../docs/api/persistence.md) |
| 第 19 批 | 四个相同普通数据复制消费者实际使用 plain_data；神的左手、回声宝宝、零分考卷及获取账本删除同合同重复实现。凸眼鱼的叶值限制与记忆紊乱的差异继续独立 | [批次交付](../../refactor-batch19/2026-11-27/delivery.md)、[API](../../../docs/api/plain-data.md) |
| 第 22 批 | 核验调试控制器既有独立职责，补真实加载、生命周期、失败安装和回滚检查；没有为了统一文件数量改写玩法 | [批次交付](../../refactor-batch22/2026-11-27/delivery.md) |
| 架构门禁 | 真实字面量 include/require 加载图、路径大小写、底座反向依赖、直接 TestAPI 读取、停用角色及临时探针检查，附反例；动态/别名数据流的限制明确保留 | [检查说明](../../../docs/agent/framework-verification.md)、[交叉审查](review/cross-review.md) |
| 全量登记 | 69 件 collectible（68 件已有玩法、ds4 仅登记）与 2 件饰品逐件记录入口、状态、依赖、旧入口和验收；53 个公共模块及私有共享组有实际消费者和保留差异说明 | [逐件清单](../../../docs/architecture/refactor-inventory.md)、[共享清单](../../../docs/architecture/shared-capability-status.md) |

正常路径、回调顺序和存档形状以旧新对照保持。控制早退是单列的旧缺陷修复：原始 CanShoot=true 时，炸弹套装先结束会提前解除仍活动的 Solar 禁火，随后又错误留成 false；当前两点均修复。它不能被描述为所有异常路径逐语句无变化。第三方绕过服务任意写 CanShoot 不在保证内。

Neverbirth 角色沿用用户的暂停决定，未重新登记或实现；此前六条资源定位警告继续为零。本轮不改内容登记、生成 ID 或资源。

## 自动验证与实际包

命令均从 Mod 根目录运行；Lua 使用 `C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`，Python 使用 `C:/msys64/ucrt64/bin/python.exe`。各专项命令及退出码见其 checks.json。

| 实际命令 / 检查 | 结果 |
| --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/framework-closure/2026-11-27/lua-all-final.json` | 退出 0；181 通过、0 失败、0 阻塞、0 警告；173 个 Lua 测试、543 个语法文件。见 [最终报告](lua-all-final.json) |
| `lua reports/framework-closure/2026-11-27/compare-registration.lua` | 普通入口 520、含零分考卷 533 条回调；事件、优先级、过滤条件及相对顺序旧新一致 |
| 存档旧新样本与加载轨迹 | 98 份旧/异常数据、196 组加载与保存序列相同；19 个缺 schema 回滚、首次保存及初始化失败禁写通过 |
| `python tools/architecture_check.py --report reports/framework-closure/2026-11-27/architecture-final.json` | 350 个静态可达文件、417 条边，无错误及未解析限制；10 个架构反例通过 |
| `python tools/package_mod.py --output reports/framework-closure/2026-11-27/package-03` | 不覆盖旧包，1060 个运行文件实际压缩/展开/逐文件哈希一致；350 个静态加载模块。2 个打包反例通过 |
| `pwsh -NoProfile -File reports/framework-closure/2026-11-27/verify-package.ps1 -Candidate package-03` | 5 组命令全部退出 0；从 extracted 加载 327 个生产 Lua，520 条回调一致；通用、严格资源及工具反例通过，见 [包检查](package-03-checks.json) |
| `pwsh -NoProfile -File tests/strict_package_generator_test.ps1` | 4 个包外开发生成器正反例均按预期；显式检查器只读取包内 XML/生成文件，未补入源码运行依赖 |
| `pwsh -NoProfile -File tests/strict_validator_scope_test.ps1 -ReportPath reports/framework-closure/2026-11-27/strict-scope-final.json` | 退出 0；22 个原严格扫描范围反例通过 |

最终产物为 [package-03/neverbrith.zip](package-03/neverbrith.zip)，SHA256：`19f5d32b96ada905d57a80d323fcc4105016a2f9b8f6b1f7a9e2c7c26f7d53b0`。package-01/02 是保留的中间产物，不应拿来安装。包不包含 reports、测试、开发工具、Git 或历史工作树。

实际包 Lua 的原生运行通过临时 include 映射指向 extracted；原生引擎仍使用已安装 Mod 的资源根，这些资源与包逐文件相同。本次不是另装第二个 Mod 副本；独立展开加载与包内资源检查另有证据，不将安装方式混淆。

## 原生执行

统一使用 `pwsh -NoProfile -File reports/framework-closure/2026-11-27/run-native.ps1 -Attempt <表中名称> -Runtime <baseline 或 package-03/extracted> -Probe <类型> -TimeLimitSeconds <时限>`。每次启动自己的隐藏进程，先快照 229 个状态文件和入口；正常关闭后恢复原字节，将本次新增文件归档；不向桌面发送按键。每次完整结果、日志及快照在 native/<名称>/。

| 探针 / 尝试 | 冻结基线 | 当前候选 | 判定 |
| --- | --- | --- | --- |
| `control`，control-baseline-01 / control-candidate-01，60 秒 | 28 通过、2 失败 | 30 通过、0 失败 | 四场景，除明确修复的两项外原通过观察保留；[比较](control-native-comparison.json) |
| `god`，god-baseline-01 / god-candidate-01，40 秒 | 29/0 | 29/0 | 我即神明真实使用/移除、属性、禁疗和自然 180 更新失败判决；观察逐条一致；[比较](god-native-comparison.json) |
| `recovery_flow`，recovery-baseline-plain / recovery-candidate-plain，60 秒 | 150/0 | 150/0 | 七个恢复流程场景，观察逐条一致；[比较](recovery-native-comparison.json) |
| `lifecycle_v2`，lifecycle-baseline-v2 / lifecycle-candidate-v2，85 秒 | 27 通过、2 失败 | 27 通过、2 失败 | 三场景的两项旧问题均复现；[诊断比较](lifecycle-native-comparison.json)明确 acceptancePassed=false，不计为原生验收通过 |

跨进程 Continue 单独使用 `pwsh -NoProfile -File reports/framework-closure/2026-11-27/background.ps1 -Attempt continue-01`：两个真实进程分别 9/0 与 34/0，合计 43/0，退出 0。七条获取记录、逻辑/身体身份与既有七件组合状态恢复，后续更新不重复发放。见 [结果](continue-01/result.json)。这不是全部道具或特殊角色的 Continue 验收。

生命周期 v2 已隔离七咒底座，主动槽 `34 / charge 3` 恢复通过；床的原生接管、自然推进、取消及重新取得后的楼层锁通过。睡眠实时时钟为 2.032/2.031 秒，床实体 seed 不要求字面相等，原值保留；其他记录的语义分量一致。仍有两项旧问题：

- 复活首个渲染帧控制/可见尚未锁定，下一 gameFrame 起两者实际锁定；动画期间碰撞类仍为 4，没有维持 NONE=0。旧实现已有此状态交接缺口，但本探针没有证明可受伤、移动或射击；仍有独立伤害与玩家更新保护。不能将字段异常扩大为整个保护失效。
- 记忆紊乱恢复口袋时，旧代码连续 SetCard(18) / SetPill(0) 清空同一原生口袋，随后空槽进入永久记录。拆分前同样存在；离线夹具的独立 card/pill 表未发现这个原生差异。本轮没有为框架重构改写卡牌/药丸归还语义，该旧缺陷保留未关闭。

正式性能使用同场景固定更新 61..1085，重复两组旧新对照。每次 POST_UPDATE 1025 样本、玩家效果更新 1024 样本；四次均为扫描 62、保存 34 次，归一化率相同。两组均未超过预先规定的均值/p95退化门槛。有无计时的 150 条功能观测逐条一致。见[测量结果](performance-result.md)、[第一组](performance-comparison-01.json)、[第二组](performance-comparison-02.json)及[扰动核对](instrumentation-equivalence.json)。这是指定回调窗口的比较，不宣称整个引擎 FPS 改善或全部性能验收。

15 次统一原生调用的完整参数、运行器/游戏各自退出码及原始结果位置见 [native-commands.json](native-commands.json)。含诊断失败的运行均正常关闭、恢复入口和游戏状态，没有未解决的新增文件。

## 过程失败与审查

- 初次 LuaAll 为 180/1/0：第 13 批夹具把新增 save_schema 算入玩法模块。修正夹具分类，仍精确要求原 17 个玩法模块、新 schema 单次加载和原回滚合同；最终 181/0/0。
- 控制服务交叉审查复现 setter 写入后异常、有效性查询重入释放、成功 setter 覆盖最后释放及身体换代边界，均补反例后修复。普通 setter/read 轨迹不变。扫描器长字符串加载和 bracket/colon TestAPI 漏检同批修复；[审查记录](review/cross-review.md)保留发现和复审。
- 旧 control 两个失败保留运行器原 TIMEOUT/退出 2 分类：正常关闭后日志有完整 SUMMARY 与 DONE，实际诊断已执行完；没有把基线故障写为通过。候选退出 0。原分类器只对零失败的退出刷盘升级为完成。
- lifecycle-baseline-01 为 26/3；其中主动槽被起始房七咒底座误拾干扰。v2 隔离这个测试前置，同时保留复活和口袋原断言并补分量记录。见 [调查](native-17-20-baseline-investigation.md)，原证据未覆盖。两个 v2 运行仍退出 2、完整 SUMMARY/DONE 与恢复均存在，失败保持失败。初次严格文本比较仅因真实计时相差 1ms 和运行实体 seed 不同而失败；最终比较显式保留这两类原值并核对其语义，不删除功能失败。
- 第一版性能统计包含场景完成后等待关闭的空闲帧，保留作探索，不能用于性能验收。代理交叉审查后改为场景 SUMMARY 即停采，并核对调用次数归一化。

## 最终一致性核对

执行 `pwsh -NoProfile -File reports/framework-closure/2026-11-27/final-checks.ps1`，检查本轮范围、最终包/当前源码逐文件哈希、全部原生状态恢复、清单/导航/知识和 diff 空白。实际命令与退出码见 [final-checks.json](final-checks.json)，包与原生清理结果见 [audit-final.json](audit-final.json)，资源/内容差异见 [scope-check.json](scope-check.json)。最终 181 项全量检查之后未再修改生产源码；之后只追加报告、探针测量方法及清单证据。

## 完成边界与后续顺序

这次已知的框架结构收尾有实现、消费者、合同及验证证据；原目标 9.6–9.8 的整轮验收仍需按未覆盖项继续，不将“结构完成”写成整个 Mod 全部实机通过。

1. 优先单独处理记忆紊乱的旧卡牌归还问题，并补原生同槽 card/pill 夹具；复活状态交接/碰撞维持另作定向核验，包含真正攻击与输入场景。这两项不能再归类为“仅未实机验收”，但也没有证据归为本轮回归。
2. 补尚缺的第 19/22 批逐件原生行为、我即神明成功清房等剩余分支、睡眠完整长周期及相关组合。
3. 补多人、特殊身体/角色转换、各相关道具的原生沙漏与更多 Continue 组合；当前普通 Isaac 样本不覆盖它们。
4. 扩展性能到高实体/特效、多人及换房/保存/沙漏峰值；现有固定恢复场景不替代整个引擎帧或 FPS 测量。
5. 人工确认输入手感、画面、音效和提示；通过后再根据授权安排版本提交或发布。

代码回退只针对本轮 manifest 对应文件和新增模块，不能整仓 reset。磁盘格式未升级，无需额外存档迁移；资源、内容与其他任务改动应保留。
