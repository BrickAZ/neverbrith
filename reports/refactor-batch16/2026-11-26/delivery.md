# 第十六批：我即神明、神性过载、炸弹套装

2026-11-26，完成本地职责拆分和射击权限公共能力接入。三件根入口只连接各自私有模块、检查接口并按原顺序安装；玩法、资源、品质、池和存档字段保持。未提交、推送或发布。

## 实现与状态

三件各拆为 config 和五个私有职责模块，共 18 文件，仍由原根入口实际加载。回调处理与绑定紧邻；三件各持有自己的临时数据，不共享玩法状态机。模块、计时、取消、保存和公共能力逐项说明见[消费者清单](consumer-inventory.md)；公共库详见[shooting_scope 用法](../../../docs/api/shooting-scope.md)。

神性过载和炸弹套装改用无状态的 Block/Restore 操作，保留原先内外层 PRE/POST 优先级、第一次记录的 CanShoot 值与存在性检查。普通换房/换层继续炸弹套装引线；我即神明的禁疗房间账本、神性过载的上次形态记录沿用旧键与 Save 时机。

## 已执行证据

| 检查 | 结果 |
| --- | --- |
| 初始基线三件行为 | 21 + 30 + 35 = 86 个用例通过，命令 exit 0；[记录](baseline-checks.json) |
| 旧/新行为及神性过载资源 | 两侧行为测试、原 PNG/ANM2/登记合同均 exit 0；[记录](paired-checks.json) |
| 提取对照 | 133 个业务函数中 129 个仅调整私有状态限定，函数体一致；4 个为明确的共享射击适配；[记录](extraction-comparison.json) |
| 完整入口登记 | 冻结旧/新两个事件夹具分别 520 / 586 条回调的事件、顺序、优先级、过滤与具名/匿名处理器身份一致；compare-registration.lua 与 registrations-*.txt |
| 安装事务 | 18 私有模块各加载一次；24 + 26 + 21 = 71 个登记点逐一注入失败，回调与导出回滚，随后 fresh load 成功；tests/batch16_loading_test.lua |
| 公共射击操作 | 嵌套、初值 false、重复 PRE、无记录/失效实体、setter 报错前清记录通过；tests/shooting_scope_test.lua |
| 最终隔离 LuaAll | 155 项通过、0 失败、0 阻塞；147 个 Lua 行为测试文件、398 个 Lua 语法文件。命令 exit 0；[完整报告](isolated-final-checks.json) |
| 严格验证（明确游戏目录） | exit 0，0 警告、0 失败；[记录](strict-game-root-check.json) |
| 最终专项复查 | 提取、登记、71 次回滚、射击公共操作、当前神性过载资源及范围验证均 exit 0；[命令与输出](final-targeted-checks.json) |
| 最终范围 | 704 个 content/resources/generated 文件哈希不变；本批 22 个运行文件与隔离受测副本完全一致；捕获范围内本批 33 个变更文件，另有本批计划和总清单进度追加。同期其他变更另列；[逐文件证明](final-scope.json) |

隔离 LuaAll 的 9 条警告包括通用验证器的 6 条既有路径警告（三语言 deathanm2 与 Breakfast 原生贴图），以及隔离目录无法自动找到游戏根而产生的 3 条原生贴图未验证警告。额外给严格验证器传入真实 GameRoot 后为 0 警告、0 失败；只是文件存在性/静态证据，不是游戏渲染验收。

## 同期改动与过程失败

开工快照 baseline/ 为 1200 文件，来自用户实际未提交工作副本。其他批次在同一工作区继续实施，本任务没有覆盖它们。candidate-isolated/ 从冻结基线复制，叠加本批三件源码和测试；因此旧/新对照只改变本批内容。为运行统一入口另复制冻结导航所引用的现有支撑文档与有效 Skill 文件，未替换运行逻辑。

首次拆分后旧专项夹具缺少 include，三个测试均报缺失全局；补充真实文件加载器后通过，未删断言。抽取脚本遗漏了仅因同名注释而漏判的 6 个函数依赖，已补为显式依赖，并由原行为和函数体对照验证。完整入口夹具缺少我即神明/神性过载的必要事件，曾使门禁直接退出；新增 test-only 完整事件表后，测试才要求全部 71 回调实际安装，不能把未安装算作通过。

直接工作区首次 LuaAll 结果为 105 通过、59 失败、0 阻塞；[完整报告](workspace-checks.json)。运行期间其他任务将 main.lua 切为第十三批原生探针入口，导致大量完整入口夹具失败；另有第十七批暂未落盘的交付链接。此前短检查还遇到记忆紊乱拆分中的依赖缺口及第二十一批临时探针。之后单项知识检查还遇到同期新增 attack_ownership 暂未进入 API 索引。这些失败原样保留，未修改其他批次或削弱检查。冻结比较用于提供本批可复现证据；它不能替代共享工作区所有并行任务结束后的整体验收。

隔离目录首次 LuaAll 为 152 通过、3 失败：快照没有包含本地化测试读取的研究文档、阴的诅咒诊断脚本和 README 的许可证附件。补入当前已有文件后重新完整执行为 155/0，运行源码和测试断言不改；首次失败见 [isolated-checks.json](isolated-checks.json)。结构自审见 [review.md](review.md)，没有将其标作独立审查。

## 命令和范围

```powershell
lua reports/refactor-batch16/2026-11-26/run-frozen-test.lua baseline tests/i_am_a_god_behavior_test.lua
# 同样运行 god_complex_behavior_test.lua、bomb_suit_behavior_test.lua；role 另为 candidate-isolated。
pwsh -NoProfile -File tests/god_complex_resource_contract_test.ps1 -Root reports/refactor-batch16/2026-11-26/baseline
pwsh -NoProfile -File tests/god_complex_resource_contract_test.ps1 -Root reports/refactor-batch16/2026-11-26/candidate-isolated
node reports/refactor-batch16/2026-11-26/verify-extraction.mjs
lua reports/refactor-batch16/2026-11-26/compare-registration.lua
lua reports/refactor-batch16/2026-11-26/run-frozen-test.lua candidate-isolated tests/batch16_loading_test.lua
lua tests/shooting_scope_test.lua
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch16/2026-11-26/workspace-checks.json
pwsh -NoProfile -File tools/check-neverbrith.ps1 -Root reports/refactor-batch16/2026-11-26/candidate-isolated -Profile LuaAll -ReportPath ../isolated-final-checks.json
pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1 -Root reports/refactor-batch16/2026-11-26/candidate-isolated -GameRoot 'E:/Isaac - Repentance'
node reports/refactor-batch16/2026-11-26/verify-scope.mjs
```

snapshot、split、repair-dependencies、prepare-isolated、prepare-check-support 是一次性过程脚本，不应对已交付工作区重新执行。没有把 Git HEAD 或其他批次旧报告当成本轮行为基线。

本批未启动原生游戏，没有人工画面/操作、跨进程 Continue、多人原生组合或与其他 Mod 共存的新增验收证据。原 86 个用例里的模拟 co-op/Continue/沙漏只证明其模拟合同，不能写成实机通过。本批结构和公共能力在记录范围内完成；整轮 Mod 验收保持未完成。
