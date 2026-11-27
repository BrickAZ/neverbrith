# 第十三批：大狗叫、蓄风棒、回响碎片

日期：2026-11-26（Europe/Warsaw）。用户授权一起重构三件，并保持玩法与存档语义、做重构前后对照。本批为本地代码与证据交付，没有提交、推送或发布。

## 实现与范围

根 big_dog_bark.lua 从 2,933 行实现变为兼容入口，调用合同不变。scripts/features 下的三个实际入口负责大狗装配、蓄风棒持有/反向即发接入、回响伤害/数据/实体更新；大狗同名目录的 14 个私有模块拆开查询、规则、状态、音效、效果、目标、水迹、食物、生命周期、冲刺、咀嚼、HUD、输入和升级池。

同组消费者共用一个状态、目标、效果和水迹实例。所有 callback 处理器与原绑定同文件相邻，入口仅按原顺序安装。保留公开 TestAPI 名称与函数身份，没有为测试添加生产转发包装。用法、消费者、共享边界和副作用见[组内接口](../../../docs/api/big-dog-family.md)、[逐件清单](consumer-inventory.md)和[共享能力清单](shared-capability-inventory.md)。

冻结基线来自开工时的实际未提交工作区：baseline-manifest.json 共 1,183 个文件、171,723,621 字节。candidate-runtime 只在该基线上覆盖 owned-files.json 的 22 个文件（18 个运行文件、4 个测试文件）；不将其他批次正在迁移的文件混入本批因果对照。完整校验副本另外补入真实的 Skill/导航/测试辅助材料并修正加载夹具，来源见 validation-extra-inputs.json。

## 保持的合同

- 137 个原函数全部保留，136 个函数体逐字一致（统一换行后）；唯一 useItem 的两次持有判定委托给 Rod.IsHeld，内部仍使用原查询。常量相同，提取映射见 extraction-map.json，检查见 extraction-comparison.json。
- 存档仍为 bigDogBark.runSeed / players，以 InitSeed 为玩家键，每人 foodPickups / chewUnlocked / potionArmed。未知根字段、保存调用点和异常处理、食物碰撞后队列确认、四份食物解锁保持。
- context 为原活引用，事件执行前替换 GetSaveRoot、Save、GetCurrentRunSeed 等提供函数仍生效。玩家实体替换会重新绑定，Continue 重建临时状态，新局重置本区域，换房/失去主动保留食物与药剂进度。
- 蓄力/发射、反向即时发射、冲刺和回响各自去重、12 逻辑帧延迟、水迹每敌每帧最高贡献者、药剂只在成功发射时消费、Avada 优先级、升级池重抽和失败回退都保持。没有新增沙漏、卸载或跨进程恢复政策。

## 检查记录

下列路径除另注外相对于项目根。JSON 报告包含每个子命令、输出和退出码。

| 检查 | 实际命令 | 结果 / 证据 |
| --- | --- | --- |
| 开工基线完整检查 | pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch13/2026-11-26/baseline-checks.json | exit 0；153 项通过，0 失败；145 份 Lua 行为测试；6 条原有通用资源警告 |
| 提取一致性 | node reports/refactor-batch13/2026-11-26/verify-extraction.mjs | exit 0；137 / 136 / 1、常量及活 context 检查通过 |
| 同一夹具旧新对照 | node reports/refactor-batch13/2026-11-26/run-comparison.mjs | exit 0；两份既有测试、新生命周期测试、轨迹分别跑旧新，另跑新加载测试，共 9 次 exit 0；13,437 字节轨迹完全相同 |
| 全入口登记对照 | lua reports/refactor-batch13/2026-11-26/compare-registration.lua | exit 0；legacy 520 条、complete 536 条，事件、优先级、过滤、处理器身份与顺序完全相同 |
| 原生旧版 | pwsh -NoProfile -File reports/refactor-batch13/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-01 -Baseline -TimeLimitSeconds 40 -Suite smoke | 游戏 exit 0；6 场景、31 通过、0 失败。运行器因并行入口改动 exit 1；已按下文完成三方恢复，不隐去初次错误 |
| 原生新版 | pwsh -NoProfile -File reports/refactor-batch13/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 40 -Suite smoke | 运行器/游戏 exit 0；6 场景、31 通过、0 失败；入口与状态自动恢复 |
| 隔离完整回归 | pwsh -NoProfile -File tools/check-neverbrith.ps1 -Root reports/refactor-batch13/2026-11-26/validation -Profile LuaAll -ReportPath ../isolated-checks-02.json | exit 0；155 项通过、0 失败，含 147 份 Lua 行为测试、379 份 Lua 语法检查。6 条原有通用警告及 3 条隔离路径找不到原版早餐资源警告；首次 isolated-checks.json 的 3 个辅助资料遗漏已补齐真实文件后通过 |
| 显式原版资源严格检查 | pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1 -Root reports/refactor-batch13/2026-11-26/validation -GameRoot "E:/Isaac - Repentance" | exit 0，0 警告、0 失败；strict-game-root.log |
| 最终导航 | pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1 | exit 0；9 个 wiki 页面、271 个本地链接；navigation-final.log |
| 最终知识索引尝试 | pwsh -NoProfile -File tests/project_knowledge_test.ps1 | exit 1；本批新增链接已检查，停止于并行新增 scripts/systems/attack_ownership.lua 尚未列入公共索引；knowledge-final.log |
| 最终交付一致性 | node reports/refactor-batch13/2026-11-26/finalize-evidence.mjs | exit 0；当前 18 个运行文件与原生候选/完整回归副本一致、4 个测试与最终回归一致；704 个 content/resources/generated 文件在候选及当前工作区均与基线哈希相同；复核轨迹/登记/原生观测通过。见 final-scope-check.json 与 final-owned-manifest.json |
| 同期共享工作区尝试 | pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch13/2026-11-26/workspace-checks-01.json | exit 1；69 通过、96 失败。运行中入口被第十八批探针替换，另有并行公共模块索引尚未完成；不作为本批或最终整包全绿证据 |

comparison-checks-initial-fixture.json 保留加载测试初次失败：夹具缺 MC_POST_GET_COLLECTIBLE；已补事件并独立复核，未降低生产登记要求。独立审查没有发现阻塞问题，详细发现和解决见[审查记录](review.md)。缺失模块的真实入口回滚由隔离完整回归中的 thin_entry_installation_test.lua 覆盖。

## 原生对照与恢复

同一 probe.lua 对冻结旧版/候选运行。native-comparison.json 的 7 组观测逐字段相同：蓄力要求 16 帧；普通冲刺实际扣血约 55.700012；蓄风棒立即反向 X=-1；强化冲刺和回响各命中一次，水迹 66 次；4 次真实早餐底座拾取后解锁咀嚼；实际 JSON 保存包含 food=4、chew=true、potion=true；失去主动保留进度。

测试通过真实 UseActiveItem、实体伤害、食物底座碰撞/队列和 LoadData 验证引擎路径；部分场景由探针设置蓄力开始帧、直接调用 Launch 或生命周期回调，并非人工操作或实际跨房移动。回响延迟检查是引擎中生成数据的 readyFrame-createdFrame=12；没有把此值检查当作所有时钟异常下的独立精确时序证明。

两次均仅用游戏回调，不接管鼠标键盘；到 40 秒窗口正常关闭自己启动的进程后日志完整刷出，均无检查失败。每次备份 229 个存档/配置文件，恢复 7 个变化文件，测试新建的一个 Goldberg 存档文件归档而非覆盖原文件。

旧版期间别的批次给 main.lua 新增 DriveGlove.Key。运行器检测到入口已被外部更改，拒绝覆盖并记录恢复错误。随后对精确的临时前后缀进行三方核对：恢复 main.before.lua 并保留该 Key 增量，也保留运行前已有的 IsFailureDeath 接入；写入前再比对当前文件以防覆盖新改动。证据为 native-baseline-01/main.external.lua、main.external-inner.lua、main.recovered.lua、recovery.json。state-recheck.json 复核全部 229 个备份路径，仍不同的文件为 0。新版运行的入口与状态自动恢复成功。初始 result.json 的 false/错误保留，与后续恢复证据一起阅读。

## 验收边界与回退

本批行为/保存模型及原生自动对照已完成。双玩家最高水迹归属、Continue、提供函数替换和失败路径有离线证据；真实多人、跨进程 Continue、人工键盘手感/画面/可听声音和所有第三方组合未验收。共享工作区后续批次仍在变化，最终所有批次集成检查另行进行，不能把本批隔离通过写成当前整包全部通过。

回退必须只按本批 owned-files.json 处理，并先检查交付后是否又有修改。根 big_dog_bark.lua 与改动的既有测试可取 baseline 对应文件；本批新增模块/测试只在确认没有后续消费者后移除。禁止整目录覆盖 baseline、git reset 或恢复整个 main.lua，以免抹掉并行批次。原生测试临时入口已经撤销，本批不新增 main.lua 永久修改。
