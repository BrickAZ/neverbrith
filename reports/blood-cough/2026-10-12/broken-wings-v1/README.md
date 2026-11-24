# 原版 AZ 折翼动画资源 v1

制作日期：2026-10-12。当前为**独立动画资源初版与离线预览**，未接入道具逻辑，未进行游戏内验收。

## 看效果

- [四向正常速度预览](preview_four_directions.gif)：原版扑翼三秒，接折翼、断开、翼片掉落，再停留片刻后循环。
- [折翼慢放](preview_break_slow.gif)：只播放折翼部分，便于看关节和分离过程。
- [四向关键帧](keyframes.png)、[原尺寸 1×](preview_native_1x.png)、[最近邻 4×](preview_native_4x.png)。

预览中的原版以撒仅作位置和遮挡参照，不包含在新图集中。预览由 ANM2 的实际帧、裁切、pivot、位移、旋转与透明度离线合成；它不是游戏录像。当前预览只展示翅膀，角色下落、假死和咳血属于后续接入。

## 游戏资源

| 文件 | 用途 |
| --- | --- |
| [broken_azazel_wings_v1.anm2](../../../../resources/gfx/Effects/BrokenAzazelWings/broken_azazel_wings_v1.anm2) | 四向扑翼对照与四向折翼的一次性动画 |
| [azazel_wings_vanilla.png](../../../../resources/gfx/Effects/BrokenAzazelWings/azazel_wings_vanilla.png) | 从原版复制的 352×144 RGBA 翅膀图集，像素及文件字节均未改动 |

模组资源路径为 `gfx/Effects/BrokenAzazelWings/broken_azazel_wings_v1.anm2`，其 sheet 0 相对引用同目录 `azazel_wings_vanilla.png`。PNG 的原版来源为 `E:/Isaac - Repentance/resources/gfx/characters/costumes/costume_082_lord of the pit.png`；原版普通 AZ 的翅膀图层使用的就是这套图集。

路线为：保留原版翅膀像素，用独立 ANM2 拆分外翼与关节残段，完成弯折、分离、旋转掉落和隐藏。没有重新绘制一对替代翅膀，也没有沿用图集里的黑色躯干覆盖以撒。

当前没有 XML 或 Lua 文件加载新资源，没有新增服装／实体登记。资源中的 `Walk…` 提供四向衔接对照；它们不代表已经注册的玩家服装。正常飞行服装与折翼瞬间的 Sprite 状态交接，需在后续开发中接入。

## 动画清单

ANM2 使用 30 FPS，`DefaultAnimation="WalkDown"`。下面所有名称均已实际写入文件。

| 方向 | 扑翼循环 | 折翼动画 |
| --- | --- | --- |
| 正面 | `WalkDown`：12 帧、循环 | `BreakDown`：24 帧、不循环 |
| 背面 | `WalkUp`：12 帧、循环 | `BreakUp`：24 帧、不循环 |
| 朝左 | `WalkLeft`：12 帧、循环 | `BreakLeft`：24 帧、不循环 |
| 朝右 | `WalkRight`：12 帧、循环 | `BreakRight`：24 帧、不循环 |

折翼资源初版长 0.8 秒：

1. 帧 0–5：原版展翼姿态开始从关节向下弯折。
2. 帧 6：外翼与靠近身体的关节残段分开。
3. 帧 6–17：外翼向侧下方移动并翻转。
4. 帧 18–22：掉落翼片逐渐消失。
5. 帧 23：所有翼片与残段隐藏，动画结束。

这是本轮用于审阅的动画节奏；三秒飞行保持原设计。当前没有把 0.8 秒写成游戏结算等待，也没有改变咳血和扣心时序。侧面保留原版单侧可见翅膀，不额外绘制第二只。

没有新增 ANM2 事件或以动画事件调用伤害。图层分别为 `wing_l`、`wing_r`、`root_l`、`root_r`。所有关键帧使用明确的逐帧变换，无关键帧之间的插值；不用的图层也写入隐藏帧，避免动画切换残留。

## 检查证据

[实际命令与退出码](checks.md)、[资源检查 JSON](resource-checks.json)、[独立裁切清单](anm2-crop-manifest.json)、[GIF 解码与时长](preview-checks.json)。

本轮检查通过：8 个动画、350 个关键帧条目、35 种唯一裁切；裁切全部在图集内且含有效像素。三秒预览最后的扑翼姿态与折翼首帧在四个方向均连续，折翼最后一帧全部隐藏。35 种裁切已在[棋盘底](crop_review_checker.png)、[白底](crop_review_white.png)、[房间色底](crop_review_room.png)上目视检查。

原版来源与交付 PNG 的 SHA-256 相同：

`677c8dd4ecf309249ee457f25f5ae054b912da46c32807dcd0acddae5f65c61c`

尚需实机验证：Isaac 引擎里的旋转与像素采样、角色与服装遮挡顺序、已有外观叠加、三秒临时状态切换与清理。离线预览中的角色遮挡顺序由预览器编排，不能作为引擎已验证的结论。

## 重新生成

[build_resources.py](build_resources.py) 负责从本机原版读取图集和 ANM2，生成本轮独立资源与预览。它会覆盖本轮自己的 v1 产物，不修改原版文件、现有道具代码或其他资源。本轮没有使用外部 ANM2 编辑器，没有生成替代翅膀美术。

相关玩法依据见[道具设计文档](../../../../docs/superpowers/specs/2026-10-12-azazel-broken-wings-active-item-design.md)。
