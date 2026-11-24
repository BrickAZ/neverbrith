# Drive Gauge HUD v2（已采用）

斗气槽体为 60×8 px；PNG 与 ANM2 资源，尚未接入玩法。30 FPS，100% 原始缩放，无动画事件、无根位移。

2026-10-14用户确认采用本版HUD及反馈动画；实机渲染与布局仍待接入后验证。

- `drive_gauge.anm2`：`Full`，以及 `GreenFill`／`BrownFill`／`BurnoutFill` 三条 61 帧数值查表。
- `drive_gauge_feedback.anm2`：6f `Spend`／`Gain` 遮罩、6f `Refill`，18f `BurnoutEnter`，以及可直接播放的 6f `SpendExample`／`GainExample`。
- `drive_gauge_icons.anm2`：8×8 的箭头、暂停、警告、断裂和锁；独立 24×12 的中文“力竭”。
- `drive_gauge_demo.anm2`：可独立查看的静态状态与循环演示，默认 `Cost`。
- `states/`：7 个独立 60×8 PNG。

填充轨道不是恢复计时器；扣费／回气遮罩必须按实际变化区间裁切。状态颜色按真实数值与力竭状态决定。附属图标和文字不计入 60×8 槽体尺寸。

[完整资源说明与离线预览](../../../../../reports/drive-rush/2026-10-14/hud-v2/README.md)。
