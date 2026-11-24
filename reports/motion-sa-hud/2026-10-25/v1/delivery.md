# 街霸6原版SA HUD接入

当前安装目录已接入原版SA贴图、数字、边框、底图和关键帧转换的ANM2，替换临时SA字符显示。积攒、数字升级、满三气进入闪光、满气循环发光、720消耗淡出及中断退款均连接真实战斗气量。OD文字仍显示既有冷却信息。

## 来源与转换

- 只读提取本机`F:/SteamLibrary/steamapps/common/Street Fighter 6/re_chunk_000.pak`的默认`ui30012.gui.530035`及其引用资源。共43个原始GUI／PFB／UV／TEX文件，SHA-256、UV裁切及转换说明保存在[provenance.json](provenance.json)，原始布局／关键帧在[native-layout.json](native-layout.json)。其他SA皮肤只作文件调查，运行时使用默认样式。
- 从原始BC7纹理读取RGBA，按实际TEX尺寸修正旧REtool导出DDS的宽度字段；不改压缩像素载荷。REtool成功提取的惯例退出码为1，来源判定依据实际文件、尺寸、哈希和解码，而非将其当成退出码0。
- 保留原版数字、框线、九宫格遮罩与配色；原作程序绘制的渐变条和九宫格布局在以撒贴图中重建。FULL13帧、LOOP25帧、数字升级10帧及FADE_OUT5帧使用原版60Hz关键帧；以撒30Hz逻辑时钟选择对应源帧。消耗淡出把原版FADE_OUT时间应用到旧满条。SF6的渲染引擎和着色器并未移植，适配结果不宣称逐像素一致。
- 原始文件格式以[RE Engine原生模板](https://github.com/alphazolam/RE-Engine-010-Templates)辅助定位，实际尺寸、UV和关键帧均核对本机文件。

## 显示与边界

- 持有任一已注册的波动／升龙／360／720显示；主玩家固定屏幕左下。合作玩家独立Sprite和气量，左右分别采用原版粉色／蓝色方向。
- 显示0–3数字及当前一格进度。满90点显示3和满条，循环发光；720扣气立即反映实际值，旧条短暂淡出。真实中断退款回满时重新闪光。
- HUD隐藏／无HUD种子不绘制；暂停冻结视觉时钟；反复Render不推进动画。失去系列道具、换房／回溯重建、退出和卸载清理显示状态。视觉状态不存档，不写战斗气量。
- `motion_combat_core.lua`、输入模块、演出模块、`main.lua`、六份道具注册／池XML与任务前快照完全一致。30有效伤害一气、90满槽、720消耗与退款、6秒OD规则、V9及其他招式资源均保留。

## 实际引擎证据

[最终sa-final-1结果](native/sa-final-1/result.json)、[原始游戏日志](native/sa-final-1/game-log.txt)：25项通过、0失败，退出码0，`cleanShutdown=true`，223个原有状态文件纳入快照，`mainRestored=true`、`stateRestored=true`。日志在正常退出时才刷新，原始状态如实记录`COMPLETED_LOG_FLUSHED_ON_EXIT`。[首次24项结果](native/sa-initial-1/result.json)保留；最终版本额外验证同等级回气不反复播放数字升级。

通过正式波动对真实Gaper造成90点实际HP损失并回满；观察0／1／2数字和部分进度，满气进入／循环的实际Render路径；换持720、箭头指令启动V9并扣气，观察消耗路径；中断后退款回满；无HUD种子隐藏／恢复，移除道具清理。检查真实引擎对象、资源加载与状态／渲染调用，不等于人工逐像素验收或多人实机验收。

后台自有隐藏新测试局只在游戏Lua回调中输入指令，未使用桌面鼠标／键盘／焦点操作。测试生成的少量新存档按精确路径归档，原存档和配置逐文件恢复。运行入口是[tools/test-motion-native.ps1](../../../../tools/test-motion-native.ps1)的`-Probe sa_hud`分支。

## 资源预览

![原版资源离线合成预览](preview.png)

上图是同一ANM2资源的离线放大预览，明确不是游戏截图。生成脚本[preview.py](preview.py)不修改运行资源。

检查命令、退出码及最终审查结果见[progress.md](progress.md)。

## 最终检查

| 实际命令 | 结果 |
| --- | --- |
| `lua tests/motion_sa_hud_test.lua` | exit0，26断言；含连续1..89回气、跨格、停止回气收敛、数字升级与条插值分离 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/motion-sa-hud/2026-10-25/v1/lua-all-final.json` | exit0，87项通过／0失败／0阻塞，126个Lua语法文件；严格验证器0警告 |
| 缓存Python运行器执行`tests/motion_sa_hud_resources_test.py` | exit0，22动画／638裁切关键帧、43源文件哈希和任务前玩法／池／入口文件一致 |
| 同一Python执行`tools/build-motion-sa-hud.py --check` | exit0，生成资源逐字节一致 |
| 同一Python执行`tests/motion_presentation_resources_test.py`及`tests/motion_items_resources_test.py` | 均exit0，已确认V7／V9资源和四道具登记／三语言池保留 |
| `pwsh -NoProfile -File tests/motion_native_state_test.ps1` | exit0，原存档／缺失文件／新文件归属／并发编辑／跨日恢复边界通过 |
| `pwsh -NoProfile -File tools/test-motion-native.ps1 -Probe sa_hud -Attempt sa-final-1 -TimeLimitSeconds 40` | exit0，真实引擎25／0，正常退出及恢复通过 |

LuaAll中的6条警告来自旧通用验证器无法解析三语言的死亡页ANM2和原生Breakfast图标；严格验证器已找到实际资源。本次没有新警告。独立审查发现的连续回气停滞和同级数字重复放大已通过失败测试→修复→26断言→最终LuaAll及后台引擎复验闭合；记录见[final-review.md](final-review.md)。
