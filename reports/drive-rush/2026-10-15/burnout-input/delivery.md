# 斗气拳套：蓝防操作纠正与力竭原音

2026-10-15。用户明确要求补齐进入／退出力竭的街霸原音，并纠正为“蓝防期间不能移动、不能射击，按方向立即冲出去”。已写入当前安装的 Mod。此轮决定替代旧版“蓝防可移动、8f同方向双击绿冲”，旧报告仅作为历史证据保留。

## 当前操作

- 按住主动键，保持原地蓝防；行走与射击输入对原生角色更新屏蔽，并清零原有移动速度。
- 蓝防中一个有效移动方向立即转入绿冲，不需双击或等满6f；主动键与方向同时输入、进入蓝防前已经按住方向也适用。
- 支持斜向及摇杆真实角度。沿用0.2长度死区，微小摇杆漂移不会走动或触发绿冲；完全相反输入抵消时无冲刺方向。
- 转绿冲后依旧先执行5f启动停顿，再开始实际位移。原有0.5格绿冲费、平滑转向、4f后反向刹车、5f后射击取消、路径预算、12f松手后摇规则保留。
- 后摇中的移动输入仍只用于普通方向防御，不会转绿冲；斗气不足仍按既定规则进入力竭。

修改位置：[核心状态机](../../../../drive_glove_core.lua)、[原生输入／移动适配](../../../../drive_glove.lua)。中文与英文EID说明在 [main.lua](../../../../main.lua) 同步修正。HUD没有重新加入“力竭”文字。

## 新增原音

| 用途 | 成品 | 原版枚举→事件→媒体 | 时长 |
| --- | --- | --- | --- |
| 进入力竭 | [burnout_enter.wav](../../../../resources/sfx/drive_glove/burnout_enter.wav) | `EMPTY=298` → `2205839412` → `274289375` | 2.759625秒 |
| 回满解除力竭 | [burnout_exit.wav](../../../../resources/sfx/drive_glove/burnout_exit.wav) | `RECOVERY=299` → `4190282989` → `451738671` | 1.824秒 |

本机源文件为 `F:\SteamLibrary\steamapps\common\Street Fighter 6\re_chunk_000.pak`，build `25071972`。本次重新选择性提取战斗声音库；程序TDB v71枚举读取结果、原版请求表与Wwise事件映射相互核对，未靠候选音试听猜测来源。文字Wwise事件名尚未恢复，保留已核实的数字ID。具体映射及原始媒体／成品SHA-256见 [provenance.json](provenance.json)。

两份均为48kHz、16-bit PCM单声道。沿用此前统一+6dB适配，保留原版16ms延迟、音高、速度与完整尾音，恢复音节点原有-2dB关系保留。跟随以撒SFX音量，不循环、不硬切。配方见 [进入](event-recipes/burnout_enter.txtp) 与 [恢复](event-recipes/burnout_exit.txtp)。没有修改街霸文件。

`BurnoutEnter`仅在状态从非力竭变为力竭时播放。新增独立`BurnoutExit`事件，只在力竭结束时播放；原有`Refill`继续负责HUD回满反馈，因此完美蓝防不会误播恢复音。部分回气、重复扣到零、状态保持、正常满槽和首次拿到道具均不重复播放；已付费最后一次绿冲可以同时播放绿冲与进入力竭音。

注册与播放：[sounds.xml](../../../../content/sounds.xml)、[drive_glove_audio.lua](../../../../drive_glove_audio.lua)。之前五种声音保持字节一致，本次总计接入七种。

## 验证

核心回归首先在旧代码上复现失败：`single direction enters rush on the same tick`，退出码1。修复后同一测试通过。

- `lua tests/drive_glove_core_test.lua`：退出码0，73条断言。覆盖一次方向、同帧按住方向、模拟摇杆连续角度／死区、费用不重复及力竭状态事件分离。
- `lua tests/drive_glove_behavior_test.lua`：退出码0，95条断言。覆盖原生输入拦截与原始方向读取并存、蓝防速度清零、结束后移动恢复、原有防御成功音、力竭两种声音去重及完美回满不误播恢复音。
- 资源完整性与旧资源保留见 [integrity.json](integrity.json)。
- `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Probe burnout_input -Attempt burnout-input-01 -Seconds 60`：退出码0，**38项通过／0失败**。完整日志及恢复信息见 [原生结果](../../2026-10-14/implementation-v1/burnout-input-01/result.json) 与同目录 `game-log.txt`。
- `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/drive-rush/2026-10-15/burnout-input/check-final.json`：退出码0，**79项通过／0失败／0阻塞**，包括72份Lua测试、107份Lua语法检查和静态／文档检查。保留6条既有通用资源警告：三份语言配置各自引用的死亡图鉴ANM2与原版Breakfast图标未被通用检查器解析。完整结果及每条实际命令见 [check-final.json](check-final.json)。自动化检查不代表所有特殊角色、武器组合和多人手感均获人工验收。

本轮原生检查实际观察到：蓝防保持原位置并消除预设速度；持续射击不生成眼泪，已满蓄力的硫磺火也没有发射；方向只输入一次即可启动绿冲，同帧主动＋已按住的斜向也可启动；5f停顿后位移，反向刹车正常。读取到蓝防原生射击许可与移动／射击输入均被阻止。

力竭音效解析为本机ID842与843，代码按名称动态获取。进入音在frame281播放一次；后摇结束frame293开始自然回气，frame892回满，恰好600个可回气逻辑帧。恢复音播放一次，满槽后不重播；两种SFX引擎声道均检测为播放中，没有新增资源打开／解码错误。完美蓝防回满没有触发恢复音。

本轮按已有选择保留引擎播放验证，不再进行系统回录；不宣称干净的回录波形或主观听感已验收。原版绿冲立体声的pan提示仍属此前已记录的提示，与本次两个单声道资源无关。

隔离测试自动恢复17项存档／设置路径与临时`main.lua`入口，复核记录见 [state-restoration.json](state-restoration.json)。日常入口不加载 [诊断脚本](../../../../diagnostics/drive_glove_burnout_input.lua)。无提交、推送或发布。
