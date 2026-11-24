# 水平指令、正常AI抓取与真实玩家动作修复

日期：2026-10-25。已修改当前游戏安装目录；未提交、推送或发布。

## 本次确认与结果

用户澄清了两个问题：失败提示为`No grabbable target`；“动画又没用”为有特效但真实以撒没有起跳／旋转。用户要求上下不能替代前后，并明确批准：**360在完成指令时确认命中，第六帧执行抓取，期间目标移动不再导致抓空**。没有扩大抓距、伤害或演出时点。

本轮已实现水平升龙匹配、指令完成时确认360目标、真实玩家整体动作与更明确的失败提示。两轮自有隐藏游戏检查通过：正常Haunt AI复现修复后实际重摔扣血；完整26场景324项检查通过。没有接管桌面键鼠或操作用户游戏进程。原生回调／实际HP证据不替代用户的画面和键盘手感评价。

## 输入规则

| 项目 | 当前规则 |
| --- | --- |
| 升龙向右 | →↓↘，623；保留626、323简化输入 |
| 升龙向左 | ←↓↙，421；保留424、121简化输入 |
| 无效输入 | ↑→↗、↓→↘及其左侧对应；→↑↗、←↑↖等向上滚法 |
| 时间／缓冲 | 升龙0.6秒、360为0.8秒、720为1.5秒，原回中、0.2秒收招缓存、OD随指令携带不变 |
| 360／720 | 上下仍参与正反摇圈；上下不能用作升龙的前后方向 |
| 波动／OD | 唯一波动仍单击射击方向；OD升龙／OD360仍为主动键＋左Shift＋指令，共用6秒冷却 |

`motion_input_any_direction.lua`文件名保留兼容，但候选只剩水平镜像。复用原匹配核心，不增加第二套识别时钟或放宽乱序。

## 抓取复现和修复

开始前保存用户实际游戏日志为`user-game-before.log`，其中最近进入Haunt房间；没有仅凭截图判断目标状态。独立正常AI探针进入同一Boss房，不使用冻结NPC更新或修改其AI的回调。

- Haunt第一阶段真实属性为不可受伤，720拒绝并提示`Target invulnerable`，不扣SA；这项资格限制保持。
- 清理真实Lil Haunts后，主阶段Haunt恢复可受伤，720可选中真实Boss。
- 原规则下，完成360时敌人在28单位处，第六帧时相对距离已达到101.6457，当前有效抓距为52；重新检查导致`Grab missed`。见[修复前正常AI日志](native/natural-before-1/game-log.txt)。
- 用户批准新规则后，同一正常AI场景第六帧确实抓住，重摔后Haunt生命**200→186**，符合3.5×4的已确认普通360伤害。见[修复后日志](native/natural-confirmed-1/game-log.txt)。

完成指令时仍须在原抓距内确认合法目标。第六帧保留这个仍有效的目标，不因移动重新筛距离；若目标死亡、失效或已被其他玩家占用，才尝试当前合法近身替补。友军、无敌、Boss释放后抗抓等排除项保留。空房提示`No grabbable target`；近身范围外显示`Out of grab range (差距)`，诊断数据同时保留实际距离、有效抓距和差距；无敌与Boss恢复期单独解释。

## 原生玩家动作

之前清掉演示以撒时，也丢掉了源动作位移，所以只剩FX。现在正式路径保留引擎绘制的真实玩家，不克隆、不隐藏、不切换玩家动画帧，也不拆画头身。

- 从已确认V7／V9动作取得整体高度、缩放和旋转。源朝向分段转换为连续的整体宽度投影，形成横转的收窄和翻面，不把头和身体分别转动。
- 本机`resources/scripts/main_ex.lua`的`_RunPreRenderCallback`会累加Vector返回值；`MC_PRE_PLAYER_RENDER`只返回高度增量，不再加一次传入offset，也不改SpriteOffset。
- 整体SpriteScale／SpriteRotation只在原生绘制前临时生效；MC_POST_PLAYER_RENDER立即恢复，POST_RENDER处理后续回调取消绘制的兜底，Stop／换房／卸载同样恢复。
- 正常玩家动画帧、受伤动画与服饰由原生玩家继续推进。FX和被抓真实NPC的演出锚点随整体高度移动。
- 720仍为V9的FX／日语／声音／394帧时序；正式房间不恢复演示替身和遮挡真实玩家的假场景。

## 实际检查

所有下列命令退出码均为0。完整Lua检查在本轮生产逻辑修复后执行；之后只同步了360英文说明及文档，并补跑本地化、探针语法与导航检查。

| 命令 | 本次结果 |
| --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-25/horizontal-native-action-v1/lua-all-current.json` | 89通过，0失败，0阻塞，6条既有通用告警；严格检查0告警0失败 |
| 上述Lua套件中的水平输入／战斗／演出测试 | 分别31／77／3572项断言通过 |
| `lua tests/localization_test.lua` | 英文／中文说明更新后通过 |
| `lua -e "assert(loadfile('diagnostics/motion_combat_acceptance.lua')); assert(loadfile('diagnostics/motion_normal_targets_probe.lua'))"` | 原生探针语法通过 |
| `python tests/motion_presentation_resources_test.py` | 4资源、12动画、14900可见裁剪键、15音频事件；源哈希和运行转换一致，正式副本仅FX |
| `python tests/motion_items_resources_test.py` | 4正式道具、3语言、旧65项、其余798图集格和3道具池保持 |
| `python tests/motion_sa_hud_resources_test.py` | 22动画、638裁剪键与原始来源保持 |
| `python tools/build-motion-sa-hud.py --check` | SA转换文件一致 |
| `pwsh -NoProfile -File tests/motion_native_state_test.ps1` | 状态恢复、并发改动／缺失文件保护及运行器集成通过 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 文档导航检查通过 |

Python实际运行文件为`C:/Users/Anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`；Lua为`C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`。原输出见[lua-all-current.json](lua-all-current.json)、[resource-checks.json](resource-checks.json)、[final-checks.json](final-checks.json)。

缺陷修复前的失败证据保存在`horizontal-red.log`、`native-pose-red.log`、`spin-red.log`、`render-offset-red.log`、`range-red.log`、`confirmation-red.log`，不是只有修复后通过的测试。

## 原生游戏证据

| 实际命令 | 结果 |
| --- | --- |
| `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe normal_targets -Attempt natural-confirmed-1 -TimeLimitSeconds 40` | 正常Haunt AI，4项通过、0失败；实际360抓取和200→186扣血 |
| `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe horizontal -Attempt horizontal-actions-1 -TimeLimitSeconds 125` | 26场景、324项通过、0失败 |

正常AI探针结果见[natural-confirmed-1/result.json](native/natural-confirmed-1/result.json)；完整结果见[horizontal-actions-1/result.json](native/horizontal-actions-1/result.json)与[逐项游戏日志](native/horizontal-actions-1/game-log.txt)。TimeLimit使用原生日志退出后落盘兜底；两轮最终状态均为`COMPLETED_LOG_FLUSHED_ON_EXIT`，游戏正常退出码0，main和状态均恢复成功，无未处理新增文件。

26场景覆盖四正式道具、普通／OD、真实HP变化、720房内伤害、空目标／无敌／气不足、水平升龙和上下／向上滚法拒绝、360确认目标移动不丢失／目标死亡替补、Boss抗抓、中断退款、原生玩家渲染不取消、跳跃offset到达真实渲染链、整体翻转、正常动画帧持续与渲染后状态恢复。额外两场普通敌人使用正常AI，不冻结其起手前行为；专门Haunt探针也全程保留正常AI，直到真实抓取成立才由正式系统控制目标。

原生渲染观测器位于生产回调后，检查传到引擎的累计offset只有一次高度增量；不是只检查本系统变量。没有录制用户窗口或接管用户输入。真实键盘手感、艺术效果和其他Mod组合仍由实际游玩评价。

## 保留范围

[unchanged-hashes.json](unchanged-hashes.json)核对本轮开始时快照：`main.lua`、输入／战斗纯核心、输入接入、正式绑定和6份道具／池XML共11文件逐字节相同；临时诊断include已移除。伤害、抓距、气量、OD冷却、品质、池以及已确认源资源没有改动。资源原件与生成物另经资源检查核对。

自有测试从当前状态快照224文件；两轮均正常关闭且精确恢复，新增测试存档先归档再按拥有权证明移除。没有覆盖更早的用户存档基线，未关闭或向用户进程注入。

下一次游玩需完整退出并重新启动游戏以加载更新的Lua；只换房不会重新加载模块。
