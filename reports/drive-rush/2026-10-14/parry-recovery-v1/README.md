# 蓝防松手与12f后摇资源 v1

**状态**：用户已确认3f撤光、6f收招、3f复原与脚下灰蓝残弧。资源已制作并完成离线检查，用户于2026-10-14确认“这个可以”，采用本版成品；未接入玩法，未进行游戏内验收。音效按用户要求暂缓。

本包只包含视觉资源、离线演示和说明，不修改主动道具注册、输入、伤害、斗气、力竭或音频文件。正式规则见[设计文档第20节](../../../../docs/superpowers/specs/2026-10-13-drive-parry-rush-active-item-design.md#20-蓝防松手与12f后摇表现)。

**2026-10-14规则补充**：用户确认普通蓝防／完美蓝防成功结算帧起6f内松手免12f后摇，含成功帧，允许越过最短6f且不增加成功硬直；继续空持不永久免后摇，见[设计第6.1节](../../../../docs/superpowers/specs/2026-10-13-drive-parry-rush-active-item-design.md#61-成功招架后的后摇取消2026-10-14补充)。本包仅用于实际需要后摇的退出；成功免后摇退出不播放本包12f姿态或灰蓝残弧，成功火花可独立消散。既有松手／提前松手演示视为未成功招架，后摇中普通方向防御仍不提前解除后摇。本轮未修改ANM2、PNG或预览。

## 查看

- [交互查看器](preview.html)：四种情形、30Hz正常播放、1/3慢放、暂停、重播、逐帧与原尺寸切换。
- [正常速度对比](preview_normal.gif)／[1/3慢放对比](preview_slow.gif)：左侧普通松手，右侧后摇中叠加普通防御。
- [完整12f逐帧图](preview_frame_strip.png)。
- 原尺寸：[房间底](preview_room_1x.png)、[白底](preview_white_1x.png)、[棋盘底](preview_checker_1x.png)；[房间底4倍最近邻放大](preview_room_4x.png)。
- [脚下残弧12f原尺寸](floor_frames_1x.png)／[4倍放大](floor_frames_4x.png)。

GIF按30／30／40毫秒分配正常速度帧，平均30Hz；慢放为每逻辑帧100毫秒。末尾额外停留仅为方便反复观看，不属于角色后摇。GIF会合并相同画面，精确逻辑帧数以ANM2和逐帧查看器为准。

## 分段与衔接

| 后摇帧 | 表现 | 结束边界 |
| --- | --- | --- |
| 1～3 | 第一帧撤去完整蓝色轮廓，少量蓝色碎片下沉消散，角色轻微收势；脚下出现灰蓝残弧 | 碎片只在这3f可见 |
| 4～9 | 固定站立脚部和收招姿态，正常身体颜色，低亮残弧逐步减弱 | 不播放走路帧 |
| 10～12 | 头身恢复普通站姿，残弧收缩淡出 | 第12f仍有残弧；后摇结束后的第一帧清空 |

总计12f＝0.4秒。灰蓝残弧采用开口弧形，提示收招尚未结束，不代表蓝防保护或可防伤害范围。普通防御叠加使用已采用的4f火花，原收招姿态和12f时间线完全不变。

演示还包含提前松手（先达到6f最短蓝防再收招）和有效蓝防耗尽斗气后的灰蓝碎光退出。后者的后摇结束不表示力竭结束。直接蓝防转绿冲依旧使用原有5f转场，绕过本次12f；本包没有改动该转场。

## 文件与动画合同

资源目录：`resources/gfx/Effects/DriveRecovery/v1/`。所有ANM2为30 FPS、不循环、Root位置固定、无动画事件或触发器。分段动画拼接与对应Full的逐帧图层数据完全一致。

| 文件 | 动画／时长 | 用途 |
| --- | --- | --- |
| [drive_parry_release.anm2](../../../../resources/gfx/Effects/DriveRecovery/v1/drive_parry_release.anm2) | `Release`3f、`Hold`6f、`Restore`3f、`Full`12f、`BurnoutFull`12f、`Clear`1f | 三片撤光碎片；正常退出蓝色，耗尽退出灰蓝色；第4f起隐藏 |
| [drive_parry_recovery_floor.anm2](../../../../resources/gfx/Effects/DriveRecovery/v1/drive_parry_recovery_floor.anm2) | `Release`3f、`Hold`6f、`Restore`3f、`Full`12f、`Clear`1f | 独立脚下灰蓝残弧，第12f仍有有效可见像素 |
| [drive_parry_recovery_isaac.anm2](../../../../resources/gfx/Effects/DriveRecovery/v1/drive_parry_recovery_isaac.anm2) | Right／Down／Left／Up各有`Release`3f、`Hold`6f、`Restore`3f、`Full`12f、`Idle`1f | 四向普通以撒头身姿态，脚部固定，不含有效蓝防轮廓 |
| [drive_parry_recovery_demo.anm2](../../../../resources/gfx/Effects/DriveRecovery/v1/drive_parry_recovery_demo.anm2) | `Release`、`GuardDuringRecovery`、`EarlyRelease`、`BurnoutRelease`各45f | 包含前置蓝防与结束后站立的完整演示；45f不是后摇长度 |

共4份ANM2、35段动画、4张PNG。`Full`与分段动画是两种播放入口，不能先播放Full再追加Release／Hold／Restore。`Clear`是后摇结束后的空白状态，不是额外1f操作限制；姿态文件在第12f达到Idle。

## 坐标、层次与未来接入

| 资源 | 本地原点与层次 | 尚未实现的适配 |
| --- | --- | --- |
| 灰蓝残弧 | 普通以撒脚底锚点；角色身体之前绘制；局部向下偏移保证末段不被脚部全部遮住 | 飞行／角色缩放与实际地面位置 |
| 头身姿态 | 同一脚底原点；body在head之前；头部允许轻微收势，身体锚点不走动 | 当前角色、动态服装、特殊身体与原生玩家渲染 |
| 撤光碎片 | 同一脚底原点，片段自带头身附近的局部偏移；角色之后绘制 | 实际角色高度和覆盖层次 |
| 普通防御火花 | 演示复用已采用成功反馈的Guard；位于人物前方的攻击来向处 | 实际方向、命中时点与正式伤害结算 |

演示从保存的ANM2读取分段、原v3蓝防和已采用的普通防御火花，不单独绘制近似版本。固定Root和站姿只证明资源没有位移，不能据此声称已实现输入锁定、普通防御、回气暂停或力竭。四向姿态不限制已确认的连续方向规则。

## 来源与检查

`trail_vanilla.png`、`arc_vanilla.png`、`impact_vanilla.png`、`isaac_vanilla.png`从已采用DriveRush/v3逐字节复制，未重绘PNG；通过ANM2裁切、变换与颜色参数组合。原版来源链见[v3检查记录](../v3/resource-checks.json)，本包逐字节比较与SHA-256见[resource_checks.json](resource_checks.json)。原版弧形裁切、角色头身与碎光已输出[棋盘底](crop_review_checker.png)、[白底](crop_review_white.png)、[房间底](crop_review_room.png)复核。

- 35段动画、5556个图层关键帧、11个独立裁切通过时长、边界、文件名大小写、透明度与非空裁切检查。
- 3＋6＋3与Full逐帧一致；四向第12f角色姿态均达到Idle，残弧合成到人物下面后仍有可见像素。
- 普通防御演示的非火花图层与普通松手逐帧一致，未重新开始后摇。
- 36项制作前快照保持一致，涵盖玩法／注册文件及已采用绿冲、HUD和成功反馈ANM2／PNG。
- [浏览器检查](preview_browser_checks.json)通过阶段边界、清空、提前松手、逐帧、原尺寸与播放控制检查，无页面错误。
- 实际命令与退出码见[checks.md](checks.md)。

预览由本地离线渲染器按保存的ANM2生成。游戏内ANM2播放、图层排序、像素取整、实际角色适配和机制同步仍需后续验收。本次没有启动游戏或接入玩法。
