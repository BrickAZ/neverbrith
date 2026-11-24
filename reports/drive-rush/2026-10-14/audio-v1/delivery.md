# 斗气拳套：街霸6三种防御成功原音

交付日期：2026-10-15（Europe/Warsaw）。本轮跨过午夜，沿用开工时的 `2026-10-14/audio-v1` 报告目录。

用户授权：提取街霸普通防御、蓝防和完美蓝防原声音效，接入斗气拳套。三种音效已安装在当前 `neverbrith`，下次启动游戏即可使用。

## 提取与成品

来源是本机 `F:\SteamLibrary\steamapps\common\Street Fighter 6\re_chunk_000.pak`，Steam build `25071972`。只读选择性提取，没有更改街霸安装文件。声音来自 `natives/stm/product/sound/wwise/dmg_cmn_es.sbnk.1.x64` 的事件和 `dmg_cmn_m.sbnk.1.x64` 的媒体；`init.sbnk.1.x64` 提供原版混音层级。

| 成品 | 原版事件 ID | 媒体 ID | 时长 / 声道 |
| --- | --- | --- | --- |
| [guard.wav](../../../../resources/sfx/drive_glove/guard.wav) | `1401491186` / `play_DMG_CMN_DRIVE_GUARD` | `66261563` | 0.977229秒 / 单声道 |
| [parry.wav](../../../../resources/sfx/drive_glove/parry.wav) | `459210530` / `play_DMG_CMN_PARRY` | `154474471` | 1.831208秒 / 单声道 |
| [perfect_parry.wav](../../../../resources/sfx/drive_glove/perfect_parry.wav) | `3446074231` / `play_DMG_CMN_PARRY_JUST` | `153255211` + `211212657` | 2.890313秒 / 立体声 |

普通防御固定采用声音事件的原版默认分支 `damagestrengthintensity=1104702398`，不根据以撒伤害改变样本。完美音使用原版层叠容器；第二层相对第一层 -2.5dB，不使用飞行道具专用 `PARRY_JUST_SHELL` 替代。三种成品保留原版16ms启动延迟、原始速度、音高和完整尾音，统一+6dB作响度适配。输出48kHz、16-bit PCM WAV；峰值分别约0.481、0.444、0.740，零削波。

工具来源：[REToolCustom](https://github.com/SlickAmogus/REToolCustom)、[Ekey文件名索引](https://github.com/Ekey/REE.PAK.Tool)、[wwiser](https://github.com/bnnm/wwiser)、[wwiser事件名映射](https://github.com/bnnm/wwiser-utils/blob/master/wwnames/Street%20Fighter%206%20(PS4).txt)、[vgmstream r2117](https://github.com/vgmstream/vgmstream/releases/tag/r2117)。映射中的事件名称经Wwise FNV编号与本机PC库核对，不仅凭文件名判断。提取的库、媒体及成品哈希见 [provenance.json](provenance.json)；原版层级和渲染参数见 [event-recipes](event-recipes/)。

## 接入行为

- `content/sounds.xml` 增加三个自定义声音注册。
- `drive_glove.lua` 在既有结算事件队列清空前调用 `drive_glove_audio.lua`；首次成功防御时才查询对应声音ID并取得SFX接口。
- 只接收 `Guard`、`Parry`、`PerfectParry`。单次有效防御只产生对应层级的声音；渲染、更新、蓝防启动、空持、松手、后摇和无敌帧内无效命中不重复播放。
- 后续有效完美蓝防仍播放，最早的射击奖励保持原来的去重规则。允许最后一次普通防御归零时照常响成功音。
- 固定 `SFXManager:Play(id,1,0,false,1)`，跟随游戏SFX音量，保留尾音；不占用音乐通道，不改变玩法规则和动画。

## 检查和证据

| 检查 | 命令 | 退出码 / 结果 |
| --- | --- | --- |
| 结算及声音触发 | `lua tests/drive_glove_behavior_test.lua` | 0；66项断言通过 |
| 机制、武器、视觉回归 | 分别运行 `drive_glove_core_test.lua`、`drive_glove_weapon_test.lua`、`drive_glove_visuals_test.lua` | 均0；61、23、2409项通过 |
| 原生声音加载与结算 | `python capture_native.py audio-native-02`（内部运行 `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Probe audio -Attempt audio-native-02 -Seconds 50`） | 0；27项检查通过 |
| 全项目最终回归 | `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/drive-rush/2026-10-14/audio-v1/check-audio-final.json` | 0；79通过、0失败、0未运行；6条既有通用资源警告，严格检查0警告 |

最终原生运行见 [游戏日志](../implementation-v1/audio-native-02/game-log.txt)和[状态恢复结果](../implementation-v1/audio-native-02/result.json)。实际ID为837/838/839（仅记录此安装环境，不写死到运行代码）。原生伤害触发普通防御一次、普通蓝防一次、完美蓝防两次；无敌帧内重复命中不多响；第二次完美保持原奖励仍播放声音。`IsPlaying`四次均为真，无缺失文件、解码或Lua回调错误。

额外完成默认输出设备的短时WASAPI回录：三种成品与游戏输出的波形相关系数分别0.9779、0.9661、0.9857，第二次完美同为0.9857；5ms响度包络吻合度均大于0.994。见 [output-match.json](output-match.json)，这证明实际音频输出含对应音效，不仅是接口调用。用户主观音量、混战时清晰度与街霸听感仍需正常游玩确认。

引擎对完美音会记录 `Attempting to set pan on non-mono source ... this will have no effect`：默认居中Pan不能作用于立体声文件。保留原版立体声，回录证实正常输出；此提示不是加载或解码失败。

早期检查记录保留：`check-audio.json` 曾发现初始化时依赖SFX接口的问题，已改为按需取得；`check-audio-concurrent-invalid.json` 是实机探针临时注入 `main.lua` 时并行运行离线检查的受干扰结果，不作为最终回归结论。最终回归在实机探针退出、入口恢复后串行进行。

两轮实机测试均由既有运行器先备份，结束后恢复17个存档／设置路径和原 `main.lua`；最终逐项哈希复核34/34一致，见 [integrity.json](integrity.json)。正常Mod加载链不包含诊断探针。未提交、推送或发布创意工坊。
