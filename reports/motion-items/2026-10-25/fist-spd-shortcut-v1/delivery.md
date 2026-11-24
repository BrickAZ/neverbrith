# 升龙白拳、360节奏／OD动作和720快捷输入

2026-10-25，已写入当前游戏安装目录。未提交、推送或发布。

## 当前行为

- 升龙在真实玩家前上方显示半透明白色拳影，普通上挑和OD两段分别出现，衔接下降与收招不滞留；左右镜像跟随出招方向。没有增加手臂、复制以撒、额外攻击判定或演示敌人。
- 普通360按用户明确确认从36改为54逻辑帧／约1.8秒：抓取仍第6帧，横转延长，重摔42、释放44；已有命中停顿保留，因此命中时可有原来的短暂停顿。伤害4倍与抓距不变。
- OD360按官方完整动作重新安排金色发力、抱住倒置目标、共同腾空横转、急降一次重摔；具有独立姿态与目标轨迹，保留48帧、6倍伤害、原抓距和共用冷却。普通／OD的真实重摔时点分别对应源73帧的接触画面。原V7／V9文件和生成数据不覆盖。
- 720新增主动键＋同时按住↑↓射击箭头的快捷输入，不要求同一帧按下，持续保持只完成一次。原1.5秒两圈保留；共用完成序号、0.2秒收招缓存、失败消耗和清理。气不足、无目标不会等待恢复后自动施放，换房也不会把已按住的组合当作新输入。
- 720只有一个版本，Shift不产生OD720或消耗OD冷却；HUD仅在升龙／360显示OD操作提示。中英文拾取提示和EID说明已更新。获取720满3SA、V9、394帧、伤害及气量规则保持。

## 实现与资源

`motion_input_core.lua`在SOCD归一化前读取原始上下组合，共用原complete，不伪造两圈方向或额外时钟。仅新增明确标记的快捷分支；资源测试继续校验其余识别器与原基线一致。

`motion_combat_core.lua`只更新用户确认的普通360时序和重摔源帧映射。`motion_presentation_additions.lua`提供OD独立姿态及拳影阶段，`motion_presentation.lua`绘制补充效果，继续使用真实原生玩家及外部传入的真实NPC。

新增资源为`resources/gfx/Effects/MotionShowcase/additions_v1/dragon_fist.anm2`和同目录`dragon_fist.png`，动画名Punch、12帧、1图层。PNG由imagegen按用户白色透明拳影方向生成，1254×1254 RGBA，打包时逐字节保留，ANM2用3.8%缩放与明确腕部枢轴，Lua只在对应上挑阶段淡入淡出。构建入口`tools/build-motion-additions.py`。

[拳影定位图](fist-placement.png)是原比例两倍放大的离线合成，不是游戏截图；[Alpha审阅图](fist-alpha-review.png)检查同一裁剪在灰、白、房间色背景上的表现。12帧使用同一个透明裁剪，逐帧边界与Alpha经测试核对。官方SPD原片、来源、哈希和连续分镜见[参考观察](references/observations.md)。

## 实际验证

| 命令 | 退出码及结果 |
| --- | --- |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-items/2026-10-25/fist-spd-shortcut-v1/lua-all.json` | 0；90通过，0失败，0阻塞；6条既有通用告警，严格检查0告警／0失败 |
| `lua tests/localization_test.lua` | 0；最后同步的新720运行时拾取说明通过；道具XML保留原字节 |
| `python tests/motion_items_resources_test.py` | 0；四主动、三语言、旧65项、其余798图集格、三池保持；输入核心除批准的OD元数据／720快捷块外保持 |
| `python tests/motion_presentation_resources_test.py` | 0；四已确认源资源、12动画、14900可见裁剪键、15音频事件及生成投影一致；原件不改 |
| `python tests/motion_additions_resources_test.py` | 0；新增白拳12裁剪、透明Alpha、原PNG字节及完整347帧官方来源核对 |
| `python tests/motion_sa_hud_resources_test.py` | 0；22动画、638裁剪键，SA原件保持；战斗核心只豁免明确确认的360时序改动 |
| `pwsh -NoProfile -File tests/motion_native_state_test.ps1` | 0；存档恢复、并发改动保护、未知新增文件保护和运行器集成通过 |
| `pwsh -NoProfile -File tests/agent_wiki_navigation_test.ps1` | 0；导航检查通过 |

Lua实际路径为`C:/Users/Anton/AppData/Local/Programs/Lua/bin/lua.exe`；Python为`C:/Users/Anton/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe`。完整Lua检查在玩法代码完成后执行，随后只同步720拾取文本／对应本地化断言与文档，并补跑本地化和资源／导航。快捷输入、1.8秒时序、附加演出均保留先失败再修复的shortcut-red、timing-red、additions-red日志。

## 隐藏原生游戏

最终命令：`pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe fist_spd -Attempt additions-2 -TimeLimitSeconds 160`，退出码0。**30场景、387项通过、0失败**，原生Lua没有运行错误。见[结果JSON](native/additions-2/result.json)和[逐项游戏日志](native/additions-2/game-log.txt)。

- 保留原26场景的真实命中、抓取、HP变化、气量、OD、水平升龙、无效指令拒绝、原生玩家动作和清理检查。
- 普通及OD升龙白拳进入实际Sprite绘制；OD两段分别记录，半透明和收招清理有单测覆盖。
- OD360实际渲染到独立brace、horizontal-rise、dive、slam阶段，真实目标受到6倍伤害并正确释放。
- 新720快捷触发实际抓取／主目标30倍及其他房内敌人10倍伤害；持续按住跨演出结束不重复；Shift保持时仍为唯一版本，OD冷却不被消费。快捷气不足、空房负例不启动／不消耗；原圆周仍保留成功用例。

首轮additions-1为385通过、4失败，未作为交付成功。其三项拳影失败为测试把末尾Alpha零覆盖了之前已绘制的记录；空房用例则误生成了用于720房内伤害的第二个敌人。修正观测累计和空房生成条件后完整重跑，保留两轮原始记录。末尾拾取文本同步也曾命中旧本地化期望，已明确维护运行时字幕例外，不改XML冻结基线，并重跑通过。

两轮测试都仅使用自有隐藏进程和游戏回调，不发送桌面键鼠、不接管用户窗口；进程正常退出，main与224文件状态快照恢复成功，新增测试存档按拥有权归档处理，未留下临时诊断include。日志缓冲使用退出后落盘兜底，最终状态COMPLETED_LOG_FLUSHED_ON_EXIT。

## 保留与验收边界

品质／道具池／道具XML、主入口、原招式贴图与ANM2、波动、升龙判定、720数值／气量／版本保持。普通360延长使已确认的控制阶段随之延长，这是用户批准的节奏修改；不声称战斗时序完全没变。

实际引擎证据覆盖输入、渲染回调、Sprite绘制及真实HP；离线合成图和分镜不是用户实际游玩画面。新拳影与OD动作的艺术评价、实际物理键盘手感仍未标成人工验收。完整退出并重启游戏以加载新Lua；只换房不会更新模块。
