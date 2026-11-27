# 鸿运显式依赖与强力泻药身体缓存修复

日期：2026-11-26（Europe/Warsaw）。只修改虚空针尖—鸿运的依赖连接、强力泻药表现缓存及对应测试/文档。未开始迁移其他道具；不提交、推送或发布。多个窗口持续改动当前工作区，验收分别保留正式源码冻结结果与直接工作区检查结果。

## 修复结果与合同

虚空针尖工厂返回 `GetLuckCap()`，main 保存本次安装返回值并传给鸿运。鸿运入口要求 `GetNeedletickLuckCap` 函数，在发布本件状态与方法之前验证；审查表仅从此查询取值，不再读取另一件道具的公共字段，也没有缺依赖时默认10的隐藏分支。

原 `Neverbirth.NeedletickLuckCap`、`GetNeedletickChance`、5%起始/10幸运达到15%上限保留。查询读取虚空针尖自己拥有的兼容配置，原调用方修改阈值时仍影响自身概率；鸿运仍在原登记重建时读取一次，没有变成逐帧动态阈值。详细用法、时序、所有权和真实消费者见[API文档](../../../docs/api/luck-cap-wiring.md)。

强力泻药旧表现缓存使用与玩法计时相同的 InitSeed 字符串键，同种子新身体会跳过添加服装。修复后，本件外观缓存以身体的 GetData 表身份为键；只读表身份，不写实体数据字段、不写存档。无 GetData 的实体式测试/兼容调用方使用对象本身。同一身体的多个 Lua 包装继续去重；不同身体即使使用相同玩家键也各自应用；仍存活的已应用身体在生命周期清理时均被处理。已移除对象不调用原生移除。

玩法时钟、房间清理、随机数、毒水/大便规则、道具数量与联动均未修改。玩家键相同的逻辑计时仍按原合同保留；本次仅修正实际身体拥有的外观状态。没有改写公共服装工具或其他消费者的语义。原生身份依据[Entity.GetData文档](https://wofsauge.github.io/IsaacDocs/rep/Entity.html#getdata)；这不是某一种原生复活路线的实机验收证据。

## 精确范围与可恢复基线

生产修改仅6个文件：`main.lua`、`scripts/features/needletick.lua`、`scripts/features/fortune_rivalling_heaven_gu.lua`、其 `audit.lua`、`scripts/features/strong_laxative.lua`、其 `presentation.lua`。main 仅增加保存虚空针尖返回值和传入查询两处连接。玩家计时模块、存档服务、schema、物品定义与资源未因本轮修改。

- `baseline/` 与 `source-before.json` 保存本轮修改前文件；初次抓到其他任务的临时入口，另存 `observed-temporary-main.lua` 和 `source-first-capture.json`，正式main恢复后才记录装配前基线并应用补丁。
- `candidate/` 和 `final-frozen-inputs.json` 保存被检验的324个生产Lua和181个测试Lua，共505份。
- `baseline-aligned/` 从候选复制其他生产文件，仅还原上述6个本轮文件中的修改，避免把其他窗口的迁移当成本轮行为差异。
- 对齐后的324份生产Lua确实仅6份不同，见[范围核对](aligned-scope.json)；五组旧新专项均退出0，四组输出逐字节一致。泻药联动使用无序遍历输出12个PASS，旧新仅打印顺序不同，排序后的结果行一致，见[对照摘要](parity-summary.json)。回调登记轨迹单独按原顺序比较，没有排序。
- `apply-wiring.ps1` 在没有原生进程、没有临时入口标记且两处目标文本匹配时才应用补丁；不覆盖其他任务的探针或恢复数据。不执行整库 reset。

## 实际命令与结果

Lua运行器：`C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。以下路径均相对模组根目录，`R`表示本报告目录 `reports/refactor-fixes/2026-11-26-fortune-laxative`。

| 检查/实际命令 | 结果 | 证据 |
| --- | --- | --- |
| `lua R/run-frozen.lua baseline tests/fortune_laxative_boundaries_test.lua`（最初8场景版） | 退出1，复现隐藏依赖及同键新身体漏服装 | [修复前](boundaries-before.txt) |
| `lua R/run-frozen.lua candidate tests/fortune_laxative_boundaries_test.lua` | 退出0，最终9场景通过，含真实main装配 | [最终输出](fortune_laxative_boundaries_test.lua-final.txt) |
| `lua R/run-frozen.lua candidate tests/refactor_lifecycle_transient_test.lua` | 退出0，19场景通过；旧夹具补齐新增必需依赖，保留原断言 | [最终输出](refactor_lifecycle_transient_test.lua-final.txt) |
| 对冻结 `candidate/tests/*_test.lua` 逐文件执行 `lua R/run-frozen.lua candidate tests/<文件>` | 最终161项全部通过：159项首次结果，2项用上述最终复跑替换。初次160过/1失败系旧夹具漏传新依赖 | [最终汇总](frozen-lua-results-final.json)、[初次原始结果](frozen-lua-results.json) |
| `lua R/run-frozen.lua <baseline-aligned或candidate> tests/<专项>.lua` | 虚空针尖、鸿运custom cache、泻药行为/联动、共享服装消费者，旧新各5项全部退出0 | [前后对照](parity-tests.json) |
| `lua R/run-frozen.lua <baseline-aligned或candidate> R/registration-trace.lua` | 两侧退出0，520条登记的顺序、事件、优先级、参数、公开方法及所属文件记录逐字节相同 | [旧](callbacks-baseline-aligned.txt)、[新](callbacks-candidate.txt) |
| `lua R/check-syntax.lua R/syntax-inputs.txt` | 退出0，505份冻结Lua解析通过 | [输入列表](syntax-inputs.txt)、[文件哈希](final-frozen-inputs.json) |
| `pwsh -NoProfile -File tools/validators/validate-neverbrith.ps1` | 退出0，0警告/0失败 | [严格验证](strict-final.txt) |
| `lua tests/fortune_laxative_boundaries_test.lua`（正式入口恢复期间，直接工作区执行） | 退出0，9场景通过 | [工作区最终专项](boundaries-workspace-final.txt) |
| `pwsh -NoProfile -File tests/project_knowledge_test.ps1` / `tests/agent_wiki_navigation_test.ps1` | 分别退出0；新API和进度入口的导航/链接检查通过 | [知识检查](knowledge-final.txt)、[导航检查](navigation-final.txt) |
| `git -c core.safecrlf=false diff --check -- <本轮文件允许清单>` | 退出0；新增文件另由冻结语法/行为/知识检查覆盖 | 文件允许清单见上文范围与本轮源文件 |

直接工作区执行的 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath R/lua-all.json` 退出1：72项通过、97项失败。运行期间第十四批临时探针接管main，完整入口测试进入 `reports/refactor-batch14/2026-11-26/probe.lua` 后缺少其所需回调常量；原始结果完整保留在 [lua-all.json](lua-all.json)。不能把这次工作区检查写为通过，也不能用冻结结果声称仍在变化的整工作区已经最终验收。通用验证器保留6条资源警告，该次严格验证有1条警告；后续严格专项结果如上。

收尾再次发生第二十一批原生探针接管main；5个道具实现文件仍与已验收候选哈希一致，临时main不作为正式源码，见[拥有范围核对](owned-parity.json)。已核对该探针的 `native/slam-baseline-frozen-full/main.before.lua`：它是正式入口且包含本轮两处装配修改，原文件未修改，观察副本和哈希见[恢复备份记录](observed-restoration-backup.json)。本轮没有抢占或恢复别人的探针。前述直接工作区9场景通过发生在正式入口恢复期间，不能将其他任务随后装入的旧冻结版本误认为本轮修复丢失。

## 进度索引与证据边界

建立[统一进度入口](../../../docs/architecture/refactor-progress.md)：第一至第十二批42件逐件列出入口和交付；另外接入8份并行批次报告，保留其“验证中/原生未闭合”等原状态。知识索引和旧薄入口计划链接此页。它是部分可确认范围的统一入口，不假称完成全量清单或全量验收，也没有回写其他窗口的报告。

本轮没有启动实机。共享入口和游戏环境正在被其他窗口的原生探针使用，不抢占、不终止它们，也不复用它们的结果证明本轮修复。已确认并修正模拟可复现的身体身份边界；真实复活/角色切换/多人重建触发组合和人工外观观察仍需原生验证。最短检查：持有泻药后替换/重新取得玩家身体，确认新身体有外观、连续帧不闪烁；移除道具、退出续局与同种子新局后检查重建；同时持有虚空针尖与鸿运，确认默认幸运阈值10和原触发概率表现。
