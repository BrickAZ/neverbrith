# 720与升龙的多余硬直修复

2026-10-25。用户明确问题发生于720、普通升龙及OD升龙；OD保护再次确认为起手至第二段结束无敌、收招可受伤。修改已在当前游戏安装目录，未提交、推送或发布。没有接管桌面键鼠、焦点或用户游戏进程。

## 原因与实际变化

720原本在289帧已经释放真实目标，但战斗会话仍等待394帧V9结束；因此回到房间后还会继续约105个逻辑帧／3.5秒不能动、免敌人伤害。现在289帧释放目标时结束战斗会话，交还移动和下一招的执行资格，保护同时结束。V9源资源和21–288帧镜头不动，余下特效作为独立尾段播放到394帧；尾段不摆布玩家、不隐藏或重复绘制已释放NPC，新招可以覆盖它。

升龙原本每次新命中都会使会话停止推进两帧；多个敌人错开进入判定时，逻辑计时、位移控制和OD保护都会被反复拖长。现在升龙保留白拳、闪白及声音，取消该停表。普通／OD动作仍30／50逻辑帧，原命中窗口、伤害及OD冷却不变。

升龙最后落地后的空站段原本仍重复写回玩家位置。现在按照已确认源轨迹，最后落地时（当前普通23、OD41逻辑帧）交还WASD并停止覆盖原生玩家姿态；剩余收招占用与单条短缓存保留。升空及OD第一段落地至第二段之间仍强制水平移动，不允许提前自由控制。OD保护0–32帧保持，33–49帧收招可受伤，未延伸无敌。

战斗控制由`motion_combat.lua`拥有；独立尾段与原生姿态释放由`motion_presentation.lua`拥有。尾段暂停时不推进，死亡、失去道具、换房／换层、重开、退出、沙漏和卸载仍走既有清理，不写存档。没有通过`StopExtraAnimation`或全局`ControlsCooldown`重置掩盖问题。

## 本次检查

| 实际命令 | 退出码和结果 |
| --- | --- |
| `lua tests/motion_combat_test.lua`（修复前） | 1；`recovery-red.log`记录720释放后仍占用战斗会话的失败 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-25/recovery-control-v1/lua-all.json` | 0；91项通过、0失败、0阻塞；84份Lua行为测试、133份语法文件。通用检查6条既有资源路径告警，严格检查0告警0失败 |
| `lua tests/motion_combat_test.lua`（最终） | 0；273项断言，包括两侧升龙末次落地、OD两段衔接、多目标不拉长计时、720释放后移动／免伤／下一招资格 |
| `lua tests/motion_presentation_test.lua`（最终） | 0；3600项断言，包括独立尾段自然结束、新招替换、暂停恢复、失去道具／死亡和五种生命周期清理 |
| `lua -e "assert(loadfile('diagnostics/motion_combat_acceptance.lua'))"` | 0；本次诊断脚本语法可加载 |
| `python tests/motion_presentation_resources_test.py` | 0；4份源资源、12动画、14900裁剪键、15音效事件和生成投影一致，正式FX副本仍无预制以撒／敌人 |
| `python tests/motion_items_resources_test.py` | 0；四主动、三语言、原65条登记、其他798图集单元和三份池保持 |

Lua实际解释器为`C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`；Python为`C:/Users/Anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`。完整Lua检查在生产修复和首批回归写入后运行；随后仅增加尾段生命周期测试并同步文档，最终273／3600断言与诊断语法重新通过。导航检查另记录在`navigation-final.log`。

## 本轮后台实机

命令：`pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe recovery_flow -Attempt recovery-1 -TimeLimitSeconds 110`，退出0。当前REPENTOGON为`1.0.12a-yin-api1-dev`。见[结果](native/recovery-1/result.json)与[逐项日志](native/recovery-1/game-log.txt)。

**7场景、150项通过、0失败**：

- 普通／OD升龙各验证左右输入，包含连续加入多个敌人的命中和打空情况；升龙计时不再被命中反馈拉长。诊断在末次落地前施加横纵位移和速度，强制水平控制保持；落地后再施加纵向移动，原位置不再把它覆盖回去。普通／OD累计源位移仍为51／57。
- OD在逻辑1、9、23、31帧进行来源为空的普通尖刺伤害，真实生命损失为0；37、46帧各损失1。诊断先清除自己的测试角色受伤冷却，避免把普通挨打无敌误认成招式保护；生产代码不做这项清除。
- 两次720在289帧同时满足战斗会话结束、姿态释放和FX尾段存在；释放后移动不被拉回，常规敌人来源伤害实际扣1。一次完整保留尾段至V9末帧，另一次立即发动新招成功替换尾段。主目标／其他敌人仍按原30倍／10倍实际扣血，气量消费、无自回气及外部移除目标后的退款／清理均通过。
- 通过本机`MC_INPUT_ACTION`让测试进程实际读到主动键，并观测`MC_PRE_USE_ITEM`、原生额外动画和控制冷却；6个完整用例均没有出现主动键新增控制锁定。它没有复现为本轮额外原因，因此输入模块未作猜测性修改。

日志写缓冲使外层轮询到达110秒后才在正常退出时完整读到结果，记录状态为`COMPLETED_LOG_FLUSHED_ON_EXIT`，而非即时`PROBE_DONE`。结果包含完整150项断言和结束标记；测试进程正常WM_CLOSE、退出码0、`cleanShutdown=true`。主入口恢复；224个文件的快照状态恢复通过，`unresolvedNewFiles=[]`、`restoreErrors=[]`。两份本轮新增的槽3状态文件按既有窄范围证据归档，没有遗留未知新增文件。

## 保留与证据边界

`unchanged-files.json`逐文件核对了主入口、纯数值战斗核心、输入模块、道具文本及六份道具／池XML与本轮修改前相同。原V7／V9、美术、音效、白拳、720获取满三气、唯一720、普通360的1.8秒、OD360动作、气量规则及品质／池没有改动。

本轮验证的是正式道具输入路径、真实HP、控制恢复时点、原生渲染／姿态状态和恢复清理；没有用离线预览代替实机，也没有将自动化通过标成人工观感或键盘手感验收。更新需要完整退出并重启游戏加载Lua；单纯换房不能加载本轮代码。
