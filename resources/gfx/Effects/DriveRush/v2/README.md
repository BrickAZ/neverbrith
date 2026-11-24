# 绿冲动画候选 v2

2026-10-13。绿色角色残影＋任意角度光效。当前是动画资源，未接入玩法。

看完整效果请打开 `drive_rush_demo_v2.anm2`，播放默认 `TurnPreview`；`StraightPreview`提供直线对照。两者都是33帧，30 FPS，包含普通以撒、角色残影和光效。

组件分开提供：

- `drive_rush_v2.anm2`：Start 5f、Rush 6f循环、End 6f、Full 29f。以角色视觉中心为原点，默认向右，通过Sprite连续旋转支持任意方向。
- `drive_afterimage_isaac_v2.anm2`：四个朝向各4个姿势，名称如FadeRight0。每个渐隐动画10f，头身姿势和位置固定，第10帧隐藏；锚点为脚下。

四张PNG必须放在同目录，名称及大小写保持不变：trail_vanilla.png、arc_vanilla.png、impact_vanilla.png、isaac_vanilla.png。

这是普通以撒外观候选，其他角色及其服装的自动快照尚未实现。演示文件内的预设弯曲轨迹只用于展示，不代表正式转向灵敏度或移动规则。

项目内详细预览与证据：reports/drive-rush/2026-10-13/v2/。
