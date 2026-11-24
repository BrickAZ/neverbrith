# 实际参考观察

2026-10-23。已查看抽帧／公开视频分镜，以下是本轮可用的观测；不从视频抄录伤害、无敌或战斗帧数。

- [官方肯角色指南](https://www.youtube.com/watch?v=1SX2m7sqbtA)：10秒附近波动为明亮圆钝波头、蓝色拖尾；不是剑挥弧光。
- [Ken Masters Move List](https://www.youtube.com/watch?v=8LqYLR5UIaA)：23～39秒为各档升龙，35～38秒字幕明确显示Overdrive Special Shoryuken，能看到向上出拳、抬膝和身体周围的火焰。录像直链返回403，成功保存同一视频公开分镜`8LqYLR5UIaA.mhtml`；本轮按分镜观察，不声称已逐帧观看OD全部过程。
- [Zangief Move List](https://www.youtube.com/watch?v=awrqhUgcUbk)：约69～91秒为不同Screw Piledriver，目标倒置，双人绕纵轴旋转。约229～245秒为普通Bolshoi Storm Buster：起手举臂仰视、抓住目标、脸与上身特写、发力、抱举、旋转和重摔，后续为CA段落。本轮选择普通SA3。该录像也用公开分镜核对，视频直链403。
- [官方桑吉尔夫角色指南](https://www.youtube.com/watch?v=zj213DBy0TY)：可核对普通摔投的轴向。43～48秒的近景是展示／挑衅内容，不能当作SA3参考。

两份官方指南MP4已成功获取，另两份招式表使用原视频分镜。`read_storyboards.py`从MHTML读取图像并按视频元数据时间生成对照图，不把分镜低采样率包装为完整动作分析。查看图：`8LqYLR5UIaA_14-42_contact.jpg`、`awrqhUgcUbk_60-95_contact.jpg`和`awrqhUgcUbk_230-270_contact.jpg`。

原生声音请求与事件以本机build25071972的提取来源为准；上游MMDK动作数据只辅助音频相对阶段排序。用户确认的是以撒版本尽量还原的方向和切镜范围，当前2D候选并非原作3D逐帧拷贝。
