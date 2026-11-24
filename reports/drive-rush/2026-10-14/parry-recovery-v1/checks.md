# 蓝防松手与12f后摇 v1 检查记录

日期：2026-10-14。工作目录：`E:\Isaac - Repentance\mods\neverbrith`。

## 实际执行

| 命令 | 退出码 | 结果 |
| --- | --- | --- |
| `& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'reports\drive-rush\2026-10-14\parry-recovery-v1\build_resources.py'` | 0 | 生成4份ANM2、PNG副本、时间线、GIF、原尺寸和多底色预览；最后一次修订是残弧收缩时的局部位置，保证最后一帧不藏在脚下 |
| `& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe' 'reports\drive-rush\2026-10-14\parry-recovery-v1\validate_resources.py'` | 0 | PASS；35段动画、5556个图层关键帧、11个裁切、36项保护快照；完整结果见resource_checks.json |
| `& 'C:\Users\Anton\.codex\skills\isaac-anm2-visuals\scripts\build-anm2-crop-manifest.ps1' -Path 'resources\gfx\Effects\DriveRecovery\v1\drive_parry_recovery_floor.anm2' -Json` | 0 | 25个脚下残弧图层关键帧，默认Full；输出保存在floor_crop_manifest.json |
| `& 'C:\Users\Anton\.cache\codex-runtimes\codex-primary-runtime\dependencies\node\bin\node.exe' 'reports\drive-rush\2026-10-14\parry-recovery-v1\check_preview.cjs'` | 0 | 独立临时配置的无界面Edge；阶段、最后一帧／清空、提前松手、场景选择、拖动、逐帧、原尺寸、慢放、重播／播放／暂停通过；零页面错误 |
| `& 'tests\agent_wiki_navigation_test.ps1'` | 0 | 5个知识页面可达、87个本地链接可解析 |
| `git diff --check -- 'docs/agent/index.md' 'docs/superpowers/specs/2026-10-13-drive-parry-rush-active-item-design.md' 'resources/gfx/Effects/DriveRecovery/v1' 'reports/drive-rush/2026-10-14/parry-recovery-v1'` | 0 | 无输出；这些新增／未跟踪文件仍需依靠独立文件检查，不能仅靠git diff判定 |

定向文档检查另对本包README、checks、SOURCES、设计文档和索引解析Markdown本地链接，结果保存为doc_checks.json；该检查还核对末尾空白与换行。已有工作区改动未清理或覆盖。

## 核对内容

- 每个分段和Full的Root／图层总时长正确；所有裁切在图集边界内，图层引用和大小写一致；无动画事件或游戏回调。
- 3f＋6f＋3f的关键帧与Full完全一致；6f中段姿态固定，四向身体锚点不变；第12f头身等于Idle。
- 完整蓝防轮廓在退出第一帧消失，碎片只保留3f；脚下残弧在12f内均可见，结束后立即清空。
- 原尺寸房间底合成后，四个朝向的第12f残弧均仍有12个满足亮度差阈值的可见像素；该值仅用于发现被人物完全遮挡的资源问题，不代表游戏画面对比度验收。
- 普通防御演示除火花层外，所有图层与普通松手逐帧一致；不会在离线演示中重置收招或延长后摇。
- 4张PNG与已采用v3源文件SHA-256一致；36项制作前保护快照一致。
- GIF实际解码、图集尺寸及浏览器逐帧控制通过。正常速度GIF／慢放GIF含结尾观看停留，不能用GIF总时长当作后摇时长。

## 视觉复核与修订

已查看四向房间底、原尺寸、多底色裁切、完整12f逐帧图和浏览器截图。初版残弧过扁，调整了弧度；复原末段曾因收缩而被身体遮住，调整局部纵向位置后，12f均保留有效提示。

首次独立检查把数值相同的`0`与`0.0`按字符串比较，误报身体锚点变化；检查改为数值比较后通过。该修订不涉及玩法。本记录中的PASS指最终保存资源。

## 证据范围

资源和浏览器离线检查已通过。没有启动以撒，没有实现输入限制、防御结算、斗气暂停、力竭或当前角色适配，没有修改音效。游戏内帧推进、层次、透明混合和实际角色外观仍待后续接入验收。

## 成品采用后的记录更新

2026-10-14用户确认“这个可以”，本版已采用。仅更新设计文档、知识索引及本包README／SOURCES的采用状态，未修改ANM2、PNG或玩法。重新执行`& 'tests\agent_wiki_navigation_test.ps1'`，退出码0，5个知识页面、87个本地链接通过；对上述四份状态文档执行定向`git diff --check`，退出码0。未跟踪文档的状态文字另作直接检查，git检查不替代文件内容复核。
