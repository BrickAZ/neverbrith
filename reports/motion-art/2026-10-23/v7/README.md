# V7：OD升龙两段，波动只留一种

当前资源为[V8](../v8/README.md)：只优化720镜头，其余三项沿用本版。下文保留V7历史记录。

[打开当前预览](preview.html)。第一项左侧为已认可的普通升龙，右侧为两段OD升龙；另有[OD单独视频](dp_od.mp4)、[OD GIF](dp_od.gif)、[三倍慢放](dp_od_slow.gif)和[两段分镜](dp_od_strip.png)。

OD升龙现在有两个明确的起势：第一段短上挑，落回地面衔接，再接第二段更高的火焰升龙。两次起势分别带金光与命中停顿，第二段火焰更强。普通升龙仍无火，原版以撒的头、脸、身体和腿保留，没有新增手臂。

| 当前招式 | 版本 | 动画 |
| --- | --- | --- |
| 波动 | 唯一版本 | [GIF](wave.gif)、[视频](wave.mp4) |
| 升龙 | 普通无火／OD两段火焰 | [同步对照](dp_compare.mp4)、[普通GIF](dp.gif)、[OD GIF](dp_od.gif) |
| 360 | 普通／OD | [日语同步对照](circle_360_compare.mp4) |
| 720 | 单一版本 | [日语视频](circle_720_jpn.mp4)、[切镜分镜](circle_720_strip.png) |

双波动、反波动及后蓄前远程候选已实际删除129个同名ANM2／媒体文件，清单见[removed-assets.json](removed-assets.json)。7个旧预览页已撤下，改为当前V7入口。此前报告保留为历史；当前资源与页面没有这些分支。

游戏侧候选目录为`resources/gfx/Effects/MotionShowcase/v7/`，共4份ANM2、12段动画、6种演出；波动／720仅`Preview`和`Effect`，升龙／360另有`ODPreview`和`ODEffect`。媒体为12个GIF、6段单独视频与2段同步视频。`Effect`隐藏示范人物和目标，保留特效；正式绑定仍需实际玩家外观和战斗状态。

## 检查与范围

专项检查直接读取保存的XML，验证两次上升、中间接地、第二段高度更高、两次命中停顿、金光再亮、火焰脚底定位、实际命中闪光与镜头边界。唯一波动、普通升龙、360两档、720单一版共10条已认可动画与V6序列化内容逐字节一致。原音与8个玩法／注册基线文件未变。

实际构建、媒体导出、删除候选、资源检查和文档导航命令及退出码见[checks.json](checks.json)，资源详情见[validation.json](validation.json)。31个实际裁切在[crops_checker.png](crops_checker.png)、[crops_white.png](crops_white.png)、[crops_room.png](crops_room.png)上复核；源PNG和SHA-256见[manifest.json](manifest.json)，世界锚点和两段时间点见[anchors.json](anchors.json)。

这是已保存的离线演出候选，未做游戏内渲染或正式玩法验收。本轮仅修改OD升龙和删除其他波动资源；未修改共享输入、原生攻击限制、伤害／消耗、道具池、注册或存档。两段动作及命中闪光不等于已实现两段攻击机制。
