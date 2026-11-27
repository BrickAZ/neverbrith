# 第十四批：诛、阿瓦达啃大瓜、柴刀

2026-11-26，本批结构重构与前后对照已完成，保留原有玩法、注册状态、资源和存档语义。修改保存在本地工作区；没有提交、推送或发布。

三个入口分别装配 5、7、8 个私有职责模块；提取一个无状态共享攻击接管查询。独立对照确认 163 个业务函数及完整事件集合中的 49 条绑定保持语义和次序。冻结旧版、仅叠加本批改动的新版、当前整合版，均通过同一原生探针的 **6 个场景、32 项断言**，**7 组观测数据完全相同**。

## 修改内容

| 道具 | 主要职责 | 保持项 |
| --- | --- | --- |
| 诛 | 事实查询、目标/状态登记、表现、伤害与充能、运行生命周期 | 原持续时间、光环/冲击波、击杀延时、车载电池充能、属性及清理时机 |
| 阿瓦达啃大瓜 | 查询、原生 Weapon、施法账本、弹体标记、命中/死亡收据、输入/属性、生命周期 | 原生充能与释放、直接击杀判据、落空本人死亡、复活阻断、解除时武器与属性恢复 |
| 柴刀 | 资格查询、属性换算、几何、表现、影子、输入/归属、挥砍、生命周期 | 原 22 tick A/B 挥砍、影子伤害、原生 Knife 载体、公开方法动态读取、禁用 Stranger 注册政策 |

[职责清单](consumer-inventory.md)记录模块与状态所有者。[attack_ownership 用法](../../../docs/api/shared-mechanics.md#攻击接管查询)记录实际消费者、返回值、动态读取和异常合同：阿瓦达接管时，诛让出眼泪替换但保留光环；柴刀取消/拒绝挥砍。原本不同的来源追溯、敌人筛选及命中归属政策保持，不引入新的统一判定。

没有新增存档字段或写入路径，没有修改道具池、品质、数值或资源。柴刀正式 Registered 仍为 false；原生探针中的临时启用仅用于测试潜在角色机制，不构成角色开放或正式可玩验收。

## 冻结范围与并发修改

- 初始 `baseline` 冻结 1200 个文件，以开始时的工作区为准，没有用 Git HEAD 替代已有重构成果。
- `candidate-final` 由 baseline 复制，仅叠加本批 **24 个生产文件**：3 个入口修改、20 个私有模块及 1 个公共模块新增。独立审查遍历目录确认只有这 24 处差异，没有其他差异或删除。
- `final-runtime` 冻结 1333 个文件，包含其他任务同期改动。本批 24 个生产文件与候选哈希完全相同；本批核对范围共 36 个源码/测试/共享文档文件，另外 155 个其他任务文件变化单独列在 [final-scope.json](final-scope.json)。共享文档中其他任务的补充保留。
- **704 个 content/resources/generated 文件哈希保持不变**；无原有文件删除。当前正式 main.lua 与 LuaAll 使用的正式入口副本哈希一致：`29194e763aa995c1e6c006af6a177d5d5b5a750168a1831ef4101e6700463f0a`。

## 实际检查

以下命令均在模组根目录执行；完整参数和输出保存在相应 JSON 或报告文件中。

| 命令/检查 | 实际结果与退出码 |
| --- | --- |
| `node reports/refactor-batch14/2026-11-26/run-offline.mjs` | 退出 0。冻结旧/新分别通过三件原行为测试、19 场景临时生命周期测试及 7 组组合测试；两侧组合输出全文相同。新版另外通过加载/共享查询检查。见 [offline-results.json](offline-results.json)。 |
| `lua reports/refactor-batch14/2026-11-26/run-frozen-test.lua candidate-final tests/batch14_loading_test.lua` | 退出 0。20 个私有模块各加载一次；49 个 callback 安装失败点逐一注入后回滚完整；公共查询的 nil/false/真值、动态替换、两次读取、缺方法、无效 Mod、nil 玩家和异常传播边界通过。 |
| `node reports/refactor-batch14/2026-11-26/review-functions.mjs` | 退出 0。163 个业务函数在明确状态/模块引用重命名后相等；三份旧测试断言尾部全文相等；缺失导出 0。见 [结果](review-functions-results.json)。 |
| `node reports/refactor-batch14/2026-11-26/review-functions.mjs reports/refactor-batch14/2026-11-26/candidate-final` | 退出 0，冻结候选的独立函数对照同样通过，结果保存在 [候选结果](review-functions-candidate-results.json)。 |
| `lua reports/refactor-batch14/2026-11-26/review-registration.lua reports/refactor-batch14/2026-11-26/candidate-final` | 退出 0。默认夹具 47 条、补齐两枚 Knife 事件后 49 条；全局和同事件次序、事件、priority、filter、处理函数身份一致。见 [注册结果](review-registration-results.txt)。 |
| `pwsh -NoProfile -File reports/refactor-batch14/2026-11-26/run-luaall-formal-entry.ps1` | 退出 0。**169 项通过、0 失败、0 阻塞**；其中 161 个 Lua 测试、503 个 Lua 语法文件，通用验证器 6 条资源警告，严格验证器 0 警告。见 [LuaAll 报告](luaall-formal-entry.json)。 |
| `node reports/refactor-batch14/2026-11-26/compare-native.mjs native-baseline-verified native-candidate-verified native-current-verified` | 退出 0。三次均 32/32，逐条检查及 7 组观测完全相同，探针哈希相同，恢复状态均通过。见 [原生对照](native-comparison.json)。 |
| `node reports/refactor-batch14/2026-11-26/verify-final-scope.mjs` | 退出 0。本批生产文件与原生候选相同，资源哈希、当前文件、正式入口及并发范围核对通过。 |
| `git diff --check --` 本批已有的源码/测试及共享文档 | 退出 0；Git 提示当前 LF 文件以后可能按仓库设置转为 CRLF，没有空白错误。 |

LuaAll 运行时其他任务临时占用了 main.lua。测试通过仅作用于子进程的 LUA_INIT 重定向读取其已保存的正式入口，其余代码和测试均读当前工作区；没有跳过回调或测试。恢复后的 main.lua 已与该副本逐字节核对相同。LuaAll 后新增的三项公共查询边界单独重跑并纳入最终 offline-results；没有生产变化需要重跑全部检查。

独立审查未发现本批生产代码的 P0–P2 回归；详见 [初审](review-notes.md)与[最终增量审查](review-final.md)。函数文本对照不是通用 Lua AST 或原生引擎证明，与行为、注册及原生检查共同构成本次证据。

## 原生结果与恢复

实际版本为 Repentance v1.7.9b.J835、REPENTOGON `1.0.12a-yin-api1-dev`。运行器命令如下，三个命令实际退出码均为 **0**：

```powershell
pwsh -NoProfile -File reports/refactor-batch14/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-verified -Baseline -TimeLimitSeconds 40
pwsh -NoProfile -File reports/refactor-batch14/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-verified -TimeLimitSeconds 40
pwsh -NoProfile -File reports/refactor-batch14/2026-11-26/run-native-isolated.ps1 -Attempt native-current-verified -CandidateRole final-runtime -TimeLimitSeconds 40
```

每次均 6 场景、32 断言通过，游戏正常退出码 0、cleanShutdown=true、mainRestored=true、stateRestored=true，无恢复错误。每次备份 229 个状态文件，恢复 7 个被改写文件，将唯一新增且启动前不存在的状态文件归档后清除。最终无测试入口残留。日志在正常退出时完整刷新，故状态为 `COMPLETED_LOG_FLUSHED_ON_EXIT`。

原生覆盖诛的实际扣血/充能/延时/清理、柴刀影子和真实 Knife、两件向阿瓦达让出射击、原生满蓄力保持与松键、激光/漩涡、直接击杀确认、落空本人死亡、实际 Ankh 复活尝试阻断以及解除恢复。阿瓦达从有效战斗输入到阈值的观测为 30 个逻辑帧，三份源码相同；这不代表所有变速或输入设备下墙钟时间保证。

原生 Ankh 会在复活被阻断前消耗，并将玩家类型切换为 4；三次观测均为 Ankh=0、PlayerType=4、失败标记=true、持续死亡 120 次渲染、复活尝试 1 次。这些既有原生副作用原样保留，没有为了测试改写玩法。

早期原生失败最终定位到探针输入在同帧插值 pass 提前切换、死亡画面停止 POST_UPDATE，以及额外假设 Ankh 库存保留。修正的是探针，不是道具业务；最终不再有这四项施法链失败。原始失败、启动异常、夹具修正及其边界完整保留在 [验证过程](validation-notes.md)；方法详见 [native-method.md](native-method.md)。

## 未覆盖的验收

没有人工键鼠/手柄手感、画面或音效验收，没有真实多人、跨进程 Continue 或所有武器组合的完整覆盖。自动原生检查不能扩大这些保证；柴刀仍保留原角色禁用政策。本地检查完成不代表发布授权。
