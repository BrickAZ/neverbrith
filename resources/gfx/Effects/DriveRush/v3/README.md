# 蓝防转绿冲动画 v3（已采用）

2026-10-14。用户已确认采用的原生ANM2资源，当前未接入玩法。采纳记录与证据见`reports/drive-rush/2026-10-14/v3/README.md`。

直接查看完整动作：打开`drive_parry_rush_demo_v3.anm2`，默认播放`ParryToRush`。`ParryToTurn`展示平滑转弯。两者都是57f、30 FPS。

组件：

- `drive_parry_rush_v3.anm2`：Parry 12f循环、Transition 5f、Rush 6f循环、End 6f、Full 57f。光效原点为角色视觉中心。
- `drive_pose_isaac_v3.anm2`：四个方向各提供Parry、Transition、Launch、Rush、Idle，名称如TransitionRight。人物和轮廓原点为脚下。
- `drive_afterimage_isaac_v3.anm2`：名称如FadeRight0，四方向各4个冻结姿势，10f淡出，原点为脚下。

四张PNG必须与ANM2放在同一目录并保持名称：trail_vanilla.png、arc_vanilla.png、impact_vanilla.png、isaac_vanilla.png。它们均为原版纹理的原样复制，颜色在ANM2中设定。

演示的24f蓝防只是展示时长；Transition严格5f；Launch是前3个移动帧，不额外停顿；尾部10f只观察残影消散，不增加操作后摇。

本包只包含普通以撒的外观原型，未自动适配其他角色与服装，不包含移动、防御、斗气或实时输入控制。详细预览及证据见项目目录`reports/drive-rush/2026-10-14/v3/`。
