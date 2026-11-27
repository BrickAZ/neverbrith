# 第二批八件道具重构交付

日期：2026-11-25（Europe/Warsaw）。本地实施；无提交、推送或发布。

## 实现范围

八件完整玩法已迁入 scripts/features/：春药、美工刀、虚空针尖、绝育证明、剪碎的塔罗、血颅蛊、未剪断的脐带、空摇篮。

- 每件保留完整状态和回调所有者；小模块单文件，不引入新的全局事件总调度。
- 血颅蛊私有持有反噬深度，向脐带/空摇篮显式提供 IsBacklashActive 查询；脐带仍先登记，延迟查询只在全部装配完成后的伤害事件中运行。
- 美工刀使用现有 persistence.Section('utilityKnife')；原三处穿插登记继续留在 main.lua，旧字段、玩家键、保存时机、每次 POST_ADD 与库存核对行为保持。
- 空摇篮显式接收原 GetCurrentRunSeed，保留“局种子 + 章节 + 类型”的楼层状态键，避免迁移后误用同名全局。
- 现有 Neverbirth 公开方法和常量保留。玩法数值、XML、ID、品质、池和素材不变；未新增持久化或沙漏参与政策。

第一批后的入口为 19490 行；第二批迁移并完成依赖修正后为 16889 行，减少 2601 行。第一批已经提取的 9 份运行模块与本批基线哈希一致。

## 基线、环境与恢复

基线是任务开始时的实际工作区，包含第一批未提交成果，以及当时已经存在的八音盒测试/持久化改动。没有以 Git HEAD 覆盖当前文件。

- baseline/：1214 份源码、测试、工具、文档及资源，172421240 字节；复制时逐一 SHA256 校验，见 baseline-manifest.json。
- git-before.txt：实施前状态。
- 704 份 content/resources/generated 文件和 9 份首批运行模块共 713 份，哈希均未改变，见 content-and-batch1-unchanged.json。
- candidate-runtime/ 与 candidate-manifest.json 是独立审阅收到的初版快照，904 份文件；不得把它当最终修正版恢复入口。
- 最终候选为 candidate-runtime-final/，清单 candidate-final-manifest.json 共 905 份文件；原生测试恢复后再次逐一核对，与当前工作区相同。该副本 11 组专项全部退出 0，见 candidate-final-smoke.txt。
- Lua：C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe，5.4.6；原生日志确认游戏 v1.7.9b.J835、REPENTOGON 1.0.12a-yin-api1-dev，未升级运行环境。
- 原生启动器沿用本项目已有 tools/motion-native-state.ps1；每轮快照 227 份设置/存档，拒绝接管未知游戏进程，仅通过游戏回调驱动自有隐藏进程。恢复结果见每次 result.json。

## 检查记录

工作目录为 E:/Isaac - Repentance/mods/neverbrith。以下 lua 指向上面的绝对运行器路径。

| 实际命令/证据 | 退出码与结果 |
| --- | --- |
| pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -LuaPath 'C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe' -ReportPath reports/refactor-batch2/2026-11-25/baseline-checks.json | 0；96 项通过、89 Lua 测试、6 条原有通用警告 |
| 同命令，报告 final-checks.json | 0；修正审阅问题前 99 项通过、92 Lua 测试、159 Lua 语法文件；6 条原有警告 |
| 同命令，报告 final-checks-reviewed.json | 0；最终 100 项通过、93 Lua 测试、160 Lua 语法文件；0 失败/阻塞，6 条原有通用警告，严格验证器 0 警告 |
| lua tests/chunyao_behavior_test.lua | 迁移前后均 0；充能/代价、错时叠加、89/90 帧、多人与属性顺序 |
| lua tests/batch2_damage_synergy_test.lua | 0；安装版调度器合同、八音盒/脐带取消、反噬排除、普通/异常/嵌套深度恢复 |
| lua tests/empty_cradle_seed_boundary_test.lua | 修正前 1、修正后 0；同玩家同章节只改运行种子，旧加成与资格正确失效；原基线也通过 |
| lua tests/batch2_loading_test.lua | 迁移前 1、迁移后 0；八模块各一次、重复/缺失反例；新增死亡更新事件缺失反例先失败后通过 |
| lua reports/refactor-batch2/2026-11-25/compare-registration.lua | 0；最终 467 条事件、次序、公开所有者、过滤和优先级签名逐字相同 |
| lua reports/refactor-batch2/2026-11-25/check-negative-cases.lua needle | 0；内存删除针尖去重保护后，新增目标受到 3 次额外伤害，测试按预期失败 |
| lua reports/refactor-batch2/2026-11-25/check-negative-cases.lua damage | 0；内存删除八音盒取消返回后，后续回调被错误调用，组合断言按预期失败 |

旧专项测试的原断言保留。美工刀新增继续、移除再获得、保存区域替换与未知字段保留断言，分别在原基线和候选运行通过。针尖新增同一泪弹“碰撞 → 死亡更新两次 → 再碰撞”的效果及伤害去重检查。

最终修正后的 LuaAll 与独立副本结果如上。文档收尾另运行 `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` 及 `git -c core.safecrlf=false diff --check`，均退出 0。检查器本身没有修改，因此未重复其不受影响的独立自测。

## 原生对照及已知旧行为

启动命令模式：

```powershell
pwsh -NoProfile -File reports/refactor-batch2/2026-11-25/run-native.ps1 -Attempt baseline-native-verified -Baseline -TimeLimitSeconds 55
pwsh -NoProfile -File reports/refactor-batch2/2026-11-25/run-native.ps1 -Attempt candidate-native-verified -TimeLimitSeconds 55
```

最终探针覆盖：春药实际扣血/追踪/错时到期；美工刀直接取得和真实底座再取得的碎心、保存计数；针尖真实发射、变体/动画及碰撞杀敌；绝育证明的原生召唤物拦截、召唤者反伤、初始与友方排除；塔罗真实底座、原生幸运缓存、卡牌/符文和奖励转换；血颅蛊实际跟班来源移除、属性与黑心；三件道具的真实反噬、债务和空摇篮结算。

baseline-native-verified 与修正版 candidate-native-verified 均为 42 项通过、0 失败，启动器和游戏均退出 0，main 和设置/存档恢复，0 恢复错误、0 遗留新文件。`node reports/refactor-batch2/2026-11-25/compare-native.mjs` 退出 0，验证五组属性观测逐字段一致，正式入口与最终候选字节相同且没有探针后缀；详见 native-final-comparison.json。收尾确认没有游戏进程遗留。

前置失败全部保留，不能当作成功记录：

- baseline-native-01：29 通过 / 12 失败。探针移动玩家误拾取起始七咒之戒，且 UseActiveItem 未传 owned/slot 参数；改探针清理起始测试房掉落、显式槽 0，玩法未改。
- baseline-native-02：40 通过 / 1 失败。脚本授予塔罗后立即期待 +3 幸运的假设失败。
- baseline-native-final（名称为当时的尝试名，不是最终合格基线）：41 通过 / 1 失败。改为真实底座后，奖励计数误计入拾取后留下的 subtype=0 空底座；修正为只数正 subtype 收藏品。

**单独记录的既有问题**：基线中塔罗从实际底座取得后，原生 Luck 仍为 0；显式触发 CACHE_LUCK / EvaluateItems 后才为 3。此项原始拾取数值保留在 OBS tarot-picked-up 中，候选要逐字段比较。通过“主动缓存时加成正确”的检查不代表“自动刷新缺口已修复”。本批保留旧行为，没有以重构名义改变属性刷新语义。

原生探针日志完整结果在正常关闭时落盘，启动器状态 COMPLETED_LOG_FLUSHED_ON_EXIT 表示读取关闭后的完整日志。跨进程继续、多人原生和人工视听体验未作为本批新增完整验收；既有相关离线测试保留。

## 独立审阅与决策

一次独立审阅发现并在同一次修正中处理三项 Important：空摇篮种子依赖遗漏；伤害测试没有使用取消即终止的真实调度；针尖死亡更新与重复命中覆盖不足。失败用例、修正和反例结果见上表。未安排第二次审阅，修正版由实际测试和原生验证闭合。

审阅包曾沿用历史 463 条的计数，独立审阅核对该快照为 466 条；加入 MC_POST_TEAR_UPDATE 后最终对照为 467 条。本报告使用最终文件计数，历史审阅包保留其原快照说明。

执行决策：

1. 在用户指定工作区实施，使用实际文件副本与日志替代需要提交的技能脚本。原因是第一批尚未提交且本次无提交授权；恢复依据是本批哈希基线，不是旧 HEAD。
2. 美工刀每次送达 POST_ADD 的原行为保留。既有测试明确检查每次回调加一颗碎心；库存轮询和实际取得另行验证不会重复。擅自改成按数量去重会改变原获取合同。
3. 审阅者没有声称验证修正后的原生结果。最终原生验证由本次实施完成并独立记录，不能将审阅结论代替实机证据。

## 回退

先退出游戏并保留本批之后的其他修改，再从本批 baseline/main.lua 恢复第二批之前的入口；这是已经包含第一批的入口。旧入口不引用本批八个新模块，可暂留这些文件。测试/导航差异逐项处理，不运行全仓库 reset/clean，不覆盖已有首批模块。

存档格式没有升级，回退源码无需转换玩家存档。原生测试用设置/存档已按每次结果恢复；不要再把历史测试副本覆盖后来产生的游玩进度。
