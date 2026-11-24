# 蓝绿露指拳套：道具图标与菜单草图 v1

**已确认的方向**：用户于2026-10-14选择蓝绿露指拳套，并明确射击奖励不需要额外视觉提示。一次满蓄力、3秒射速及力竭取消等玩法规则保持原设计。

**采纳状态**：用户于2026-10-14确认“可以，就用这版”，采用32×32彩色图标及16×16菜单草图v1成品；尚未注册、接入或完成游戏内验收。

本包仅制作独立美术资源。正式名称随后已确认为“斗气拳套／Drive Glove”，品质为0级；现有`drive_glove`资源文件名保持不变。完整名称与投放合同见[设计文档第22节](../../../../docs/superpowers/specs/2026-10-13-drive-parry-rush-active-item-design.md#22-正式名称拾取短句品质与投放)。没有分配道具ID、写入XML或替换共享菜单图集，音效按要求暂缓。

## 查看与文件

- [彩色图标与菜单草图对照](preview_board.png)：三种底色、4倍最近邻与底部原尺寸并排。
- [32×32彩色道具PNG](../../../../resources/gfx/Items/Collectibles/drive_glove_v1.png)。
- [16×16菜单草图PNG](../../../../resources/gfx/UI/DriveItem/v1/drive_glove_sketch.png)。
- [彩色生成源图](generated-item-source.png)、[采用的粗线草图源图](generated-sketch-source-v2.png)。

## 形象与跨表面处理

| 形象特征 | 彩色图标 | 菜单草图 |
| --- | --- | --- |
| 露指结构 | 四个短指口与侧面拇指口，空拳套，不包含角色手臂 | 简化的指端、拇指外突与内部留白 |
| 主体 | 蓝色拳背，少量明暗区分厚度 | 轮廓与大块透明内腔，删去材质高光 |
| 腕部 | 宽绿色腕带 | 粗线腕带分隔与底部封闭轮廓 |
| 主题色 | 蓝绿两大色块呼应已采用的蓝防／绿冲 | 使用项目已有红色墨线，不保留彩色版蓝绿填色 |

两张表面分别通过内置`image_gen.imagegen`制作。菜单草图以彩色拳套作形象参考单独绘制，没有将彩色图标直接缩小后当作草图。第一次细线草图在16×16下断裂，已使用图像生成工具重新绘制粗线版；旧版只保留在报告内作为检查记录。

## 技术依据与整理

- 参考项目已登记的`bomb_suit.png`：32×32 RGBA、二值Alpha。完整测量见[参考道具数据](reference-item-facts.json)。
- 菜单／死亡资源的现有入口是`content/gfx/UI/NeverbirthDeathItems.anm2`，图格16×16、轴心8,8，图集与帧使用XML本地ID映射。本次不分配ID，不修改该入口。
- [参考草图数据](reference-sketch-facts.json)记录现有16×16红墨图格，其三色为RGB(92,8,14)、(150,18,27)、(205,45,48)。
- 原始生成图实际尺寸与最终整理矩形见[导出审计](export-audit.json)。生成工具未直接返回32×32或16×16；[导出脚本](export-assets.ps1)仅作透明边界裁定、最近邻原尺寸整理、Alpha规范化和菜单墨色映射。
- 完整初始提示词见[generation-prompts.json](generation-prompts.json)，粗线修订提示词见[sketch-revision-prompt.json](sketch-revision-prompt.json)。

## 验收边界

原尺寸资源和多底色预览用于检查轮廓及像素清晰度，不能证明游戏已加载。具体静态结果、文件哈希和保护范围见[检查结果](asset-checks.json)及[命令记录](checks.md)。成品已获用户采用；底座、举起、主动栏、ESC／My Stuff和死亡界面均未进行实机验收。
