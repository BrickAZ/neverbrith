# 斗气拳套：蓝防启动与绿冲原音接入

2026-10-15。用户授权：“可以，把街霸蓝防启动和绿冲的原声音效也提取出来，接入斗气拳套。”已写入当前安装目录的音频模块、资源和注册表。本次不调整玩法、数值、动画或三种已交付的防御成功音。

## 成品与触发

| 声音 | 当前安装资源 | 时长与格式 | 接入时机 |
| --- | --- | --- | --- |
| 蓝防启动 | [blue_start.wav](../../../../resources/sfx/drive_glove/blue_start.wav) | 1.446秒；48kHz/16-bit PCM；单声道 | 成功进入蓝防的 `Blue` 事件；长按只播一次 |
| 蓝防转绿冲 | [rush_start.wav](../../../../resources/sfx/drive_glove/rush_start.wav) | 1.290秒；48kHz/16-bit PCM；双层立体声 | `RushStart` 事件，在5f启动停顿开始时播放 |

跟随以撒的 SFX 音量。沿用前三种声音的统一+6dB适配，保留原始音高、速度、声层比例和完整尾音；两种原版启动事件都没有额外初始延迟。开始实际位移、持续按住、转向、反向刹车或动作结束不重播。拒绝蓝防／绿冲不播启动声；已经付费的最后一次绿冲即使令斗气归零仍播放。新动作的声音不受射击奖励去重影响。防御成功声可以与启动尾音自然叠加。

接入文件：[drive_glove_audio.lua](../../../../drive_glove_audio.lua)、[sounds.xml](../../../../content/sounds.xml)。现有 `drive_glove.lua` 会在结算后排空事件队列，新增两项映射复用这一机制，无需修改核心玩法。

## 原音识别证据

原版来源：本机 `F:\SteamLibrary\steamapps\common\Street Fighter 6\re_chunk_000.pak`，Steam build `25071972`。只选择性提取小型声音库和请求表；未修改游戏文件。

| 用途 | 本机程序 TDB 枚举 | 请求表 TriggerId | Wwise事件 | 媒体 |
| --- | --- | --- | --- | --- |
| 蓝防启动 | `PARRY_START=290` | `3975993691` | `4280042251`；文字事件名未恢复 | `306795568` |
| 蓝防转绿冲 | `DRIVE_DASH_PARRY=292` | `2784585104` | `484561895` / `play_BTL_CMN_DRIVE_RUSH_NORMAL` | `366743517` + `415288339` |

识别链为：本机程序TDB v71枚举常量 → 原包 `snd_rdt_se_battle_base.user.2` 的 `UniqueID/TriggerId` → `snd_battle_cmn.user.2` 的 `_TriggerId/_EventId` → `battle_cmn_es.bnk` 事件 → `battle_cmn_m.bnk` 媒体。绿冲文字名另用Wwise FNV1哈希匹配。攻击取消绿冲是另一枚举 `DRIVE_DASH=294`／事件 `342895396`，没有使用它。排查过的 `ZONE_START` 也没有作为蓝防启动使用。

解析依据：[REFramework类型结构](https://github.com/praydog/REFramework/blob/master/shared/sdk/RETypeDB.hpp)、[枚举常量取值实现](https://github.com/praydog/REFramework/blob/master/shared/sdk/RETypeDB.cpp)、[RE_RSZ的SF6字段定义](https://github.com/alphazolam/RE_RSZ/blob/main/rszsf6.json)。这些源码只用于读取结构；实际枚举值、请求表、事件和媒体来自本机安装。历史Ryu动作数据只用于初步排查，没有用于最终音源判定。

完整编号、原始媒体及成品SHA-256见 [provenance.json](provenance.json)，声音层级配方见 [蓝防启动](event-recipes/blue_start.txtp) 与 [绿冲](event-recipes/rush_start.txtp)。蓝防原始节点-1.5dB；绿冲两层分别+0.5dB与0dB，统一适配后保持相对关系。生成工具版本与原有提取流程相同：wwiser v20260808、vgmstream r2117。

## 实际验证范围

- 资源检查：两份PCM WAV、XML路径、非静音、无削波通过；三种旧音的SHA-256与前次交付一致。见 [integrity.json](integrity.json)。
- 回调行为测试：`lua tests/drive_glove_behavior_test.lua`，退出码0，79条断言通过。包含长按不重复、实际输入双击触发、停顿转位移不重播、转向／刹车不重播、拒绝动作无启动音，以及付费归零的最后一次绿冲有声音；原有防御成功音测试保留。
- 原生引擎：两次 `audio_start_rush` 隔离测试，均43项通过／0失败；自定义音效ID解析为840、841，使用名称动态解析，代码没有硬编码这两个本地ID。每轮实际触发蓝防启动4次、绿冲2次，且SFX引擎声道处于播放状态。输入通过真实适配器推进，核对5f启动停顿、位移、转向、刹车和最后一次绿冲。见 [第一轮结果](../../2026-10-14/implementation-v1/audio-start-rush-01/result.json)、[第二轮结果](../../2026-10-14/implementation-v1/audio-start-rush-02/result.json) 及同目录 `game-log.txt`。
- 两轮都自动恢复17项存档／设置路径与 `main.lua` 临时测试入口；恢复时核对原有文件哈希。结束后又复核两轮共34个状态记录，全部保持原样，见 [state-restoration.json](state-restoration.json)。诊断文件没有接入日常加载。
- 回归命令 `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/drive-rush/2026-10-15/audio-start-rush/check-final.json`：退出码0，79项通过、0失败、0阻塞；6条通用验证器既有警告。实际命令与逐项输出记录在 [check-final.json](check-final.json)。它覆盖LuaAll配置选中的检查，不代表所有实机玩法与组合验收。

实机日志包含立体声样本无法应用单声道pan的提示；原版绿冲本来就是立体声，当前默认居中，不进行方位偏转。该提示不代表加载失败，两个原生播放检测均通过。

## 系统回录的边界

系统默认输出的两次回录都混入其他软件声音。第一轮其中一次蓝防启动完整波形相关性约0.947；其他样本和第二轮没有通过“所有样本相关性超过0.9”的检查。不能将本轮称为完整、干净的录音波形验证通过。

用户在获知这一限制后回复“先保留目前结果”，因此停止额外录音。保留原始录音和失败结果：[第一轮输出比较](audio-start-rush-01/output-match.json)、[第二轮输出比较](audio-start-rush-02/output-match.json)。引擎触发、播放声道与原音来源已有验证；最终主观音量、与其他战斗声音混合后的听感仍需用户游戏内体验。

可复用的隔离测试入口是 [accept-drive-glove.ps1](../../../../tools/accept-drive-glove.ps1) 的 `-Probe audio_start_rush`；对应 [诊断模块](../../../../diagnostics/drive_glove_audio_start_rush.lua) 只由备份恢复运行器临时加载。回录辅助脚本为 [capture_native.py](capture_native.py)、[check_output.py](check_output.py)。本次无提交、推送或发布。
