# 七种招式演出 V2

2026-10-23后续反馈：用户明确不满意全身重画，要求保留原版以撒、只叠加特效手臂。本目录保留历史，当前评审改看[V3](../v3/README.md)。

2026-10-23用户反馈修订。此包是独立ANM2资源与演出预览，未接入真实招式、敌人抓取或镜头控制；观感仍待用户确认，不能当成游戏内已验收。上一版资源完整保留。

打开[预览页](preview.html)，或直接看各项GIF／分镜。[资源与预览ZIP](motion-preview-v2.zip)保留项目相对路径，解压后打开同路径的`preview.html`。360和720的MP4带本机街霸6重新提取的日语原音。所有画面由保存后的ANM2重新读取渲染，不用一段独立视频冒充动画文件。

| 招式 | 本轮修改 | 正常速度 | 分镜 |
| --- | --- | --- | --- |
| 波动 | 圆钝亮核、向后流动的蓝焰；蓄势／飞行／命中均不使用剑挥弧光 | [GIF](wave.gif) | [分镜](wave_strip.png) |
| 双波动 | 同一波体连续两发，各有推掌动作 | [GIF](double_wave.gif) | [分镜](double_wave_strip.png) |
| 反波动 | 紫色波体视觉候选；214不等于向后发射，未定义新玩法 | [GIF](reverse_qcf.gif) | [分镜](reverse_qcf_strip.png) |
| 升龙 | 参考肯OD的低位出拳、上举拳头、抬膝、火焰上冲和收势；使用专用姿势 | [GIF](dp.gif) | [分镜](dp_strip.png) |
| 后蓄前 | 保留此前独立金色弧刃候选，没有把它混入波动 | [GIF](charge_back_forward.gif) | [分镜](charge_back_forward_strip.png) |
| 360 | 抱举倒置、正／侧／背面切换、前后遮挡与纵轴横转、重摔 | [日语视频](circle_360_jpn.mp4)／[GIF](circle_360.gif) | [分镜](circle_360_strip.png) |
| 720 | 普通SA3方向：举臂起手、抓取、脸部近景、双臂发力、目标近景、横转升空、下坠、重摔、回房间 | [日语视频](circle_720_jpn.mp4)／[GIF](circle_720.gif) | [分镜](circle_720_strip.png) |

每项另有`_slow.gif`三倍慢放。正常预览30fps，720分镜展示13秒；这是资源评审节奏，不把演出总时长确认为玩法数值。俯视镜头用2D构图和纵向压缩模拟，当前没有3D摄影机，也未声称逐帧复刻原作模型动作。

## 资源与来源

原生资源目录：`resources/gfx/Effects/MotionShowcase/v2/`。七份ANM2均含`Preview`（人物、训练目标和全部演出）与`Effect`（隐藏示范人物与目标）；默认`Preview`。720的缩放、位置、遮幅、闪光和切镜直接烘入ANM2各图层，不依赖预览网页实现。

三张专用PNG由内置imagegen生成：`fighter_poses.png`、`hadoken_cels.png`、`uppercut_fire_cels.png`。生成原图逐字节复制入项目，脚本仅发现Alpha区域并在ANM2中裁切／缩放，不重画或擦除原图。动作表含12个姿势，波体4帧、火焰4帧；实际裁切见[crop-metadata.json](crop-metadata.json)，提示词见[generation-prompts.md](generation-prompts.md)。以撒、目标和冲击等原版贴图也保留来源SHA-256，见[manifest.json](manifest.json)。新动作是以撒风格的独立候选，不修改角色常驻服装。

参考观察记录见[references/observations.md](references/observations.md)。参考视频／分镜只供对照，不打进游戏贴图或交付资源ZIP。

## 日语声音

语言已由用户明确指定日语。两段配音预览选用`resources/sfx/zangief_v2/`原音；720选普通SA3的6330／6331效果轨，未混入CA的6350系列。六声道效果轨只在离线视频中另作立体声下混，原29份WAV和`sounds.xml`均与本轮开始时一致。

预览混音时间表保存在`manifest.json`，只用于分镜评审。720语音按动作数据的相对时序对齐候选镜头，但不移植其无敌、伤害或玩法时长；360的片段编排是离线试听编排。原音未变速或变调；混音WAV保留尾音，视频按画面长度结束。正式触发、取消、中断与真人听感仍随以后玩法接入核对。

## 检查与边界

构建：`python reports/motion-art/2026-10-23/v2/build_previews.py`。专项检查：`python reports/motion-art/2026-10-23/v2/verify_package.py`。实际命令、退出码和导航检查结果写入`checks.json`；每项XML、贴图路径、裁切、可见Alpha、图层时长、正常／慢放GIF时长、视频帧率、日语选择、音源SHA-256、基线文件一致性见[validation.json](validation.json)。逐裁切三底色检查图为`crops_checker.png`、`crops_white.png`和`crops_room.png`。

本轮不改共享输入、攻击限制、道具数值、道具池、正式注册与存档。自动资源检查和离线画面评审不证明Isaac引擎渲染、抓取稳定性或实际游戏镜头可用；这些仍未运行。

本轮最终构建与专项检查均退出0：7份ANM2、14段动画、14个GIF、41个可见裁切、2份日语配音预览；原29份音源与8个范围基线文件一致。导航检查退出0，99个本地链接可解析。已人工查看七份分镜和三种底色裁切；未进行玩家听感或游戏内验收。ZIP为可直接查看的资源包；源码重建仍需要本项目已有生成器和游戏原生素材。
