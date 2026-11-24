# V5：特效位置校正，普通／OD两档

历史版本：当前评审为[V7](../v7/README.md)。其他波动候选文件已删除，旧预览已撤下；当前只有一种波动，OD升龙已改成两段。本页保留V5历史记录。

2026-10-23用户要求调整特效位置，并给OD波加入街霸式人物金光；随后纠正普通／OD是每个招式各自的档位，不能把双波动等同OD。本包为七种招式各提供普通与OD，共14种演出预览。

打开[同步对照页](preview.html)。每段视频左侧普通、右侧OD，逐帧同步，可暂停或拖动。页面默认展示OD金光关键帧，不需要等动画循环才看得到区别。单独GIF、三倍慢放与位置分镜也在每项下方。

## 位置调整

- 人物与目标都按实际Alpha轮廓和脚底定位。地面高度由原版站立身体的实际下缘求出，避免头、身体和实体pivot不一致导致错位。
- 影子跟随人物横坐标；角色在空中时仍投到地面，落地后回到脚底，不再留在起跳处。
- 蓄力光贴在头部前缘，波体从同一高度出发。波体前缘到达目标时消失，同帧在目标接触边缘出现命中光效。
- 升龙火焰的底端绑定实际脚底，不再使用为较大人物姿势预留的头顶偏移。目标在前方受击，减少头部互相遮住。
- 摔技倒置目标置于以撒上方并保留间隙；下坠先转到侧面，再落到地面，避免两个大头相互挤入。砸地光效绑定目标实际接地点。
- 720近景按当前人物／目标包围盒重新构图，目标不再被旧镜头无意裁掉；保留用户要求的特写、切镜、横转、重摔及日语。

这是独立资源的展示编排，不决定实际抓取、伤害、命中判定或战斗时长。

## OD金光

OD金光来自同一原版PNG的当前头／身裁切：外层暖金轮廓、浅金人物闪光，起手点亮后淡出；普通版没有该层。轮廓与人物使用同一帧、同一朝向和同一次镜头变换。没有重画角色，没有增加手臂，也没有把金光做成悬浮在脚下的圆环。

参考实际查看过的[肯OD波动／升龙录像](https://www.youtube.com/watch?v=8LqYLR5UIaA)分镜中的人物泛金外缘。原录像的动作、伤害、气量和本模组OD规则并不因本轮美术借鉴而一并采用。

本轮所有普通／OD版本采用相同动作轨迹，OD只增加所要求的金光。OD的输入、消耗和强化行为不从视觉资源中推定，未写入共享输入或正式玩法。

## 文件

游戏侧为`resources/gfx/Effects/MotionShowcase/v5/`，七份ANM2各含四段：`Preview`、`Effect`、`ODPreview`、`ODEffect`。前两段普通，后两段OD；Effect隐藏示范人物和目标，保留特效。正式游戏中的人物金光仍需绑定真实玩家外观，当前仅以原版以撒作展示。

| 招式 | 普通 | OD | 同步视频 |
| --- | --- | --- | --- |
| 波动 | [GIF](wave.gif) | [GIF](wave_od.gif) | [对照](wave_compare.mp4) |
| 双波动 | [GIF](double_wave.gif) | [GIF](double_wave_od.gif) | [对照](double_wave_compare.mp4) |
| 反波动 | [GIF](reverse_qcf.gif) | [GIF](reverse_qcf_od.gif) | [对照](reverse_qcf_compare.mp4) |
| 升龙 | [GIF](dp.gif) | [GIF](dp_od.gif) | [对照](dp_compare.mp4) |
| 后蓄前 | [GIF](charge_back_forward.gif) | [GIF](charge_back_forward_od.gif) | [对照](charge_back_forward_compare.mp4) |
| 360 | [GIF](circle_360.gif) | [GIF](circle_360_od.gif) | [日语对照](circle_360_compare.mp4) |
| 720 | [GIF](circle_720.gif) | [GIF](circle_720_od.gif) | [日语对照](circle_720_compare.mp4) |

每段另有`_slow.gif`三倍慢放。`*_key.png`为同一帧普通／OD对照，`*_strip.png`为位置分镜。两段日语混音与V3逐字节一致，不重新提取或变更原音。V4保留历史。

## 检查与证据

构建：`python reports/motion-art/2026-10-23/v5/build_resources.py`。导出：`python reports/motion-art/2026-10-23/v5/render_previews.py`。专项检查：`python reports/motion-art/2026-10-23/v5/verify_package.py`。

[anchors.json](anchors.json)记录相机变换前的头／身／脚底／影子／火焰／接触点与OD包络；[manifest.json](manifest.json)记录PNG来源与SHA-256及四段动画名；[validation.json](validation.json)从保存后的XML独立复核坐标、轮廓跟随、接触时刻、镜头裁切、正常／OD区分、GIF时长、视频帧率、原版人物与8个范围基线文件。

本轮构建、导出和专项检查退出0：7份ANM2、28段动画、14种演出、28个GIF及7段同步对照视频；3552个人物关键帧、3120个金光跟随关键帧与1880项位置检查通过。具体命令与退出码见`checks.json`。三底色裁切见`crops_checker.png`、`crops_white.png`、`crops_room.png`。

浏览器自动跳转本地`file://`链接被浏览器安全策略拒绝，因此没有替用户切换现有V4标签页；未通过其他协议或浏览器绕过。新版文件可由用户点击本地链接打开。此浏览器操作未完成不影响已保存的资源及媒体检查。

这是离线候选，尚未做Isaac内的真实渲染、抓取或OD输入验收；用户观感待反馈。没有更改共享输入、攻击限制、正式登记、数值、道具池或存档。
