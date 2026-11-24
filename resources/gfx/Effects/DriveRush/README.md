# Drive Rush visual prototype v1

独立绿冲 ANM2 候选资源，2026-10-13。当前未接入游戏，不包含玩法代码。

`drive_rush_v1.anm2` 与三张 PNG 必须放在同一目录。默认动画 `FullRight`。资源图集来自原版，像素保持原样，绿色由 ANM2 染色实现。

30 FPS；八方向后缀为 Right、DownRight、Down、DownLeft、Left、UpLeft、Up、UpRight。

- `Start`＋方向：5f，不循环。
- `Rush`＋方向：6f，循环，仅移动光效。
- `End`＋方向：6f，不循环；最后一帧全隐藏。仅视觉收尾，不增加操作后摇。
- `Full`＋方向：完整预览段，水平 29f、垂直 21f、斜向 25f；均包含启动、移动光效和视觉收尾。

所有 RootAnimation 位置为 0，资源本身不移动玩家。锚点对应角色脚下，特效中心向上约 14 像素。建议作为玩家身后的独立 Sprite 特效；不包含角色皮肤，不是服装或实体登记文件。

PNG 文件：`trail_vanilla.png`、`arc_vanilla.png`、`impact_vanilla.png`。请保留名称大小写。

项目内完整预览、原版来源、检查证据与制作脚本：`reports/drive-rush/2026-10-13/v1/`。
