# 第十二批：千变万化

2026-11-26，完成本地职责拆分、共同能力复用与旧/新对照。保持玩法、五个外观、存档格式和保存/抽选时机。未提交、推送或发布。

## 交付范围

`scripts/features/everchanging.lua` 负责创建七个私有实例、保留原 EverchangingTestAPI 和八个 callback 安装顺序。registry、state、selection、resources、player_anm2、presentation、runtime 分别拥有外观登记、存档与实体状态、抽选、资源、主动画、外观应用和生命周期。callback 处理器与绑定同文件相邻；依赖无环，每次安装仅创建一次。

复用既有 `null_costumes.GetCachedId(..., true)`，公共库源码没有改动。缓存重绑、失败诊断、双人半成功清理等策略仍在本件。详细职责、未合并能力的合同差异及公开 API 用法见[消费者清单](consumer-inventory.md)和[公共能力说明](../../../docs/api/shared-mechanics.md)。

初始冻结 `baseline/` 共 1172 文件。期间另一个任务修改了陈列室的显式依赖装配、相应测试和两份 API 文档；共 11 文件原样保留，逐文件哈希见[同期改动记录](concurrent-changes.json)。最终原生旧侧 `baseline-aligned/` 从最终候选复制其余代码，仅还原旧千变万化入口并去除七个新私有模块。这样正式对照中其余运行代码完全相同。`candidate-runtime/` 是独立审查修正前的中间快照，不作为最终候选；`candidate-final/` 才是实际原生验收对象。

## 验证结果

| 检查 | 实际结果与证据 |
| --- | --- |
| 当前工作区 LuaAll | 153 项通过，0 失败、0 阻塞，含 145 个 Lua 行为文件及 359 个 Lua 文件语法；严格验证 0 警告。[完整命令、输出与退出码](final-checks.json) |
| 旧/新行为合同 | 原行为、完整 ANM2 合同、九组新增边界、11 个生命周期用例，两侧均 exit 0。[对齐后记录](aligned-checks.json)；[初始基线记录](baseline-checks.json) |
| 模块与安装 | 七模块各加载一次，六个既有 TestAPI callback 的登记身份保持；八个安装阶段逐一注入失败，均回滚回调和导出，随后新加载成功。见 tests/batch12_loading_test.lua 与 LuaAll 输出 |
| 源码对照 | 50 个业务函数：49 个在限定所有权引用迁移后函数体完全相同，1 个为带边界验证的共享缓存适配；五个外观定义逐字相同。[结果](extraction-comparison.json) |
| 全入口回调 | 两种引擎夹具分别 520 / 534 个事件、顺序、优先级、过滤、函数身份完全一致。[结果](registration-comparison.txt) |
| 保存 / RNG / 外观轨迹 | 13 组旧/新序列逐字节相同，含每次 Save 内容、随机上界/次数、服装和动画操作、双人回滚、退出、Continue、新局和卸载。[结果](trace-comparison.json) |
| 资源合同 | 修复旧扫描入口后，Ringo 原 headgear-only 断言在对齐旧/新两侧均通过。[记录](resource-checks.json) |
| 原生对照 | 旧/新各 8 场景、31 项通过，8 组观测相同，探针文件字节相同。[比较](native-comparison.json)；[旧侧恢复证明](native-baseline-aligned-01/result.json)；[新侧恢复证明](native-candidate-01/result.json) |
| 独立审查 | 发现的缓存重入差异已修复，正/负结果测试均通过；最终无未解决问题。[审查记录](review.md) |
| 最终范围 | 本批在捕获范围内修改 7 文件、新增 10 文件、删除 0 文件；另更新两份计划。704 个 content/resources/generated 文件哈希不变，当前 907 个运行文件与原生候选完全相同；其余旧/新原生运行文件相同。[范围证明](final-scope.json) |

通用验证器仍有 6 条旧资源警告：三种语言登记各自的 `NeverbirthDeathItems.anm2` 与原生 `Collectibles_025_Breakfast.png` 路径没有被通用解析器解析。严格验证器 0 警告；资源未改动。LuaAll 的 `InGameVerified: false` 表示该运行器本身不执行游戏，原生证据在上表单独列出。

原生检查在固定种子、正常雅各/以扫开局执行。场景为首次获取、蓝香蕉皮、Tokarev、Ringo、Yoontoons、双人 Tantan/Daodao、多份/部分丢失/完全丢失/重获，以及真实换房。通过原生 `GetCostumeLayerMap` 和 `GetCostumeSpriteDescs` 核对实际服装层与资源路径，同时核对属性、玩家主 ANM2、选择及抽选历史。双人外观不会给以扫增加道具份数。

正式两侧均备份 227 个状态文件；游戏正常退出，恢复 6 个变更文件，并归档清除 3 个经核实为本次新建的状态文件；入口恢复，`stateRestored/mainRestored/cleanShutdown = true`，无恢复错误或未处理新文件。运行器只启动和关闭自己的隐藏游戏进程，无桌面鼠标键盘输入。

## 实际执行命令

以下命令均在模组根目录执行。最终命令退出码均为 0；早期失败单列在下一节。

```powershell
node reports/refactor-batch12/2026-11-26/verify-extraction.mjs
lua reports/refactor-batch12/2026-11-26/compare-registration.lua

# role 分别为 baseline-aligned、candidate-final；每项分别执行并保存退出码。
lua reports/refactor-batch12/2026-11-26/run-frozen-test.lua <role> tests/everchanging_behavior_test.lua
lua reports/refactor-batch12/2026-11-26/run-frozen-test.lua <role> tests/everchanging_full_anm2_contract_test.lua
lua reports/refactor-batch12/2026-11-26/run-frozen-test.lua <role> tests/batch12_boundaries_test.lua
lua reports/refactor-batch12/2026-11-26/run-frozen-test.lua <role> tests/refactor_lifecycle_runtime_test.lua
lua reports/refactor-batch12/2026-11-26/run-frozen-test.lua <role> reports/refactor-batch12/2026-11-26/trace.lua
pwsh -NoProfile -File tests/ringotsuga_accessory_anm2_visual_test.ps1 -Root reports/refactor-batch12/2026-11-26/<role>

pwsh -NoProfile -File reports/refactor-batch12/2026-11-26/run-native-isolated.ps1 -Attempt native-baseline-aligned-01 -Baseline -TimeLimitSeconds 40
pwsh -NoProfile -File reports/refactor-batch12/2026-11-26/run-native-isolated.ps1 -Attempt native-candidate-01 -TimeLimitSeconds 40
node reports/refactor-batch12/2026-11-26/compare-native.mjs native-baseline-aligned-01 native-candidate-01

pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/refactor-batch12/2026-11-26/final-checks.json
node reports/refactor-batch12/2026-11-26/snapshot.mjs final-runtime
node reports/refactor-batch12/2026-11-26/verify-final-scope.mjs
```

快照命令拒绝覆盖既有目录。`prepare.mjs`、`split.mjs` 是本次过程证据，不应对已完成工作区再次执行；正式快照不依赖 Git HEAD。源码与内容哈希、命令输出、探针副本和状态备份均保存在本目录。

## 发现、修正与限制

1. 原 Ringo PowerShell 检查在重构前 exit 1：仍从 main.lua 的旧标记块寻找资源。改成递归读取当前功能的字面 include 链，保留全部资源断言；旧/新通过。初始失败见[记录](baseline-resource-check.json)。两项原 Lua 源码合同也只更换扫描入口，没有减少断言。
2. 独立审查发现 GetCostumeIdByPath 重入卸载时，传给公共 helper 的旧 cache 与本件当前 cache 不同。修复为返回后向当前表发布结果，保留旧行为。新增正/负查询结果反例，两侧均通过。
3. `native-baseline-01` 为 27 通过 / 4 失败，失败来自探针对原生 `001.000_Player.anm2` 的小写字面假设。修正为与开局记录的真实原路径精确比较，生产逻辑不变。修正后 `native-baseline-02` 为 31/0；最终又以对齐后的旧侧重跑31/0。所有失败及探针副本保留。
4. 两次启动对齐基线的尝试因另一项原生检查占用共享游戏，被启动前 guard 以 exit 1 拒绝，未创建本次进程、未写入口。等待对方正常完成并恢复后才运行成功；没有关闭其他任务进程。
5. 独立审查曾遇工作区入口临时插入本次原生探针导致模拟夹具缺事件常量，随后改用冻结入口通过。该临时失败未用修改生产回调或削弱断言处理。

完整 ANM2 加载失败、漂移修复和第三方所有权在模拟测试中验证；当前五个正式外观都是附属服装，原生验收没有注入新的全身皮肤。原生双人范围是正常雅各/以扫，不代表多人合作或所有角色组合。Continue/新局/卸载有模拟合同与轨迹验证，未将本批标记为跨进程 Continue 验收。自动原生服装层检查不等于人工逐帧视觉、操作手感、其他 Mod 组合或沙漏回溯验收。
