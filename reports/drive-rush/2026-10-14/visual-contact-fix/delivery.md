# 斗气拳套：缩放回归、灰白角色反馈与碰撞伤害调查

2026-10-14。修改已写入当前游戏加载的 `E:\Isaac - Repentance\mods\neverbrith`，未发布。

## 已修改

- 不再绘制 HUD 的 `BurnoutLabel`（“力竭”）字帧，保留灰白恢复条、断裂图标和原有 EMPTY 入场反馈。原始 PNG/ANM2 不改。
- 角色在 burnout 状态下持续去色，带轻微亮度起伏和最多 1.5% 的呼吸形变。离身冻结时继续显示；已经付费的绿冲中灰白优先；解除时还原。
- 原有蓝防／绿冲／后摇姿态在 POST、下一次 PRE、更新和清房均有对应还原路径，不再依赖每一次 PRE 都必定有 POST。另保存独立 Vector 和完整 Color 数值（含 alpha、offset、colorize），保留角色原有大小与颜色。
- 没有修改射击、防御范围、斗气数值、属性、击杀归属或跟班伤害规则。

## 根因与对照

**实际根因**：防御无敌帧产生的闪烁会跳过部分 `MC_POST_PLAYER_RENDER`，但仍调用 `MC_PRE_PLAYER_RENDER`。旧代码在 PRE 压缩 Y 后只在 POST 还原；POST 被跳过后，下一次 PRE 又把已经压扁的尺寸作为原尺寸，逐帧叠加。原生旧版对照在没有闪烁时 PRE/POST 为 80/80、尺寸仍为 1；加入防御同款 `SetMinDamageCooldown` 后累计 PRE/POST 为 260/170，高度降至 0.0253753，成功复现。

先前怀疑 getter 是可变引用，最初夹具也按引用模拟。但实际原生探针证明 `SpriteScale` getter 返回独立值（`aliases setter=false`）；该假说已否定，不作为根因。最终回归夹具按值复制建模，旧代码在“PRE 后没有 POST，再次 PRE”的真实失败序列中得到 `0.73728`（应为 `0.768`），退出码 1。当前修复通过连续 180 次配对蓝防渲染、漏掉 POST、90 次灰白状态、清房、禁用渲染模式及恢复检查。引用型适配器仅保留为额外防御性测试。

用户随后澄清“自动打怪”是怪物靠近就掉血。本局日志记录先获得 `797 Drive Glove`，后获得 `426 Obsessed Fan`；截图可见紫色跟班。[日志摘录](user-session-items.txt)保留这一证据。原游戏 `E:\Isaac - Repentance\resources-dlc3\entities2.xml:392` 的 Obsessed Fan（3.98）明确配置 `collisionDamage="2"`、`collisionInterval="2"`、`collisionRadius="13"`。原生对照进一步确认：只持拳套蓝防、单独无敌帧、单独禁射、两者叠加均为 0 次 NPC 伤害；蓝防加迷恋苍蝇产生 44 次伤害，每次 2 点，来源类型为跟班（3）。该对照把跟班持续置于敌人处以明确归因，不代表正常游玩的命中频率。本次未复现拳套自己反伤，保留原版跟班伤害。

原生对照 `diagnostics/drive_glove_visual_contact.lua` 已运行：普通碰撞、只持拳套蓝防、单独无敌帧、单独禁射、两者叠加、蓝防加迷恋苍蝇、灰白及回满。它统计实际 NPC 伤害回调／武器发射／渲染，不通过脚本直接对 NPC 扣血。正常加载入口不包含诊断。

## 本次检查

| 命令 | 退出码 | 证据 |
| --- | --- | --- |
| `lua tests/drive_glove_visuals_test.lua reports/drive-rush/2026-10-14/visual-contact-fix/before/drive_glove_visuals.lua` | 1 | 最终按值复制夹具：`unpaired PRE does not compound: 0.73728`，见 [render-before.txt](render-before.txt) |
| `lua tests/drive_glove_visuals_test.lua`（修复后） | 0 | 连续渲染与还原回归通过，2409 次断言（包含重复帧），见 [render-after.txt](render-after.txt) |
| `luac -p diagnostics/drive_glove_visual_contact.lua` | 0 | 诊断语法检查 |
| `pwsh -NoProfile -File tools/check-neverbrith.ps1 -Profile LuaAll -ReportPath reports/drive-rush/2026-10-14/visual-contact-fix/check-visuals.json` | 0 | 79 项通过、0 失败、0 未运行；通用资源解析 6 个已有警告，严格验证器 0 警告 |
| `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt visual-contact-01 -Probe visual_contact -Seconds 50` | 0 | 原生 8/8 通过；蓝防 180 次渲染尺寸稳定，灰白和回满清理通过，见 [实机日志](../implementation-v1/visual-contact-01/game-log.txt) |
| `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt visual-baseline-01 -Probe visual_baseline -Seconds 30` | 0 | 旧版预期缺陷复现 1/1；不是修复验收，见 [旧版日志](../implementation-v1/visual-baseline-01/game-log.txt) |
| `pwsh -NoProfile -File tools/accept-drive-glove.ps1 -Attempt visual-fixed-01 -Probe visual_fixed -Seconds 30` | 0 | 同样 PRE/POST 为 260/170；新版最低姿态 Y 为 0.96、更新后始终回到 1，修复验证 1/1，见 [新版日志](../implementation-v1/visual-fixed-01/game-log.txt) |

原生渲染参数、回调顺序和伤害归因已实测，具体灰白外观、多人布局仍需人工画面验收。用户表示已退出并允许测试后，发现旧窗口仍在，发送正常关闭请求并等到游戏自行退出；未强制结束该进程。独立启动器随后备份并核对恢复 17 个指定存档／配置路径及 `main.lua`，只终止自己启动的测试进程。

碰撞分支辅助检查保存了安装版 EXE 的离线反汇编；SHA-256 为 `530b4d2accef833b8dbf6f1a9f781fe1e051c1916ca5acdb579df05a34640627`。REA 单函数反编译在 330 秒后超时，无可用反编译结论，未据此修改玩法。

## 街霸 6

已核实完整安装位于 `F:\SteamLibrary\steamapps\common\Street Fighter 6`。`StreetFighter6.exe` 为 632,956,832 字节，`re_chunk_000.pak` 为 89,816,525,731 字节；Steam 清单 `F:\SteamLibrary\steamapps\appmanifest_1364780.acf` 的 buildid 为 25071972、StateFlags 为 4。原游戏包存在，单独三类成功音仍未提取，未加入音效文件或播放代码。

## 最短人工复核

完整退出并重启游戏以加载 Lua；仅重新进入房间不会重载脚本。长按蓝防并重复松手，确认头身不继续压扁；使用 `driveglove meter 0` 查看灰白角色与无文字 HUD，再用 `driveglove meter 6` 确认恢复。若旧局已经被压扁，重启后仍需检查原生继续是否恢复尺寸，不能擅自把所有角色尺寸硬设为 1（会破坏其他道具的大小效果）。
